classdef AgentLoop < handle
    % AgentLoop Core engine for Mage.
    %   Orchestrates the LLM chat loop, contexts, tools, and events.
    %   No I/O happens directly here; it fires events caught by adapters.

    events
        ResponseReceived   % Fired when text arrives from LLM
        ToolCallStarted    % Fired right before executing a tool
        ToolCallCompleted  % Fired when a tool finishes successfully
        UserInputRequired  % Fired when asking the user for input
        ContextCompacted   % Fired when the context is auto-summarized
        AgentError         % Fired when an internal exception occurs
    end

    properties
        Config          % struct holding project config (.agent/config.json)
        Context         % ContextManager instance
        Client          % LLMClient instance
        Tools           % ToolEngine instance
        Skills          % SkillRegistry instance
        IsRunning       % Logical flag to control the run loop
        Mode            % e.g., 'code', 'architect', 'ask', 'doc', 'test'
    end

    methods
        function obj = AgentLoop(cfg)
            % AgentLoop Initialize the loop with a configuration struct

            if nargin < 1
                cfg = struct();
            end

            obj.Config = cfg;
            obj.IsRunning = false;
            obj.Mode = 'code'; % Default mode
            
            % Ensure .agent folder exists for logging
            if ~isfolder('.agent'), mkdir('.agent'); end
        end

        function logEvent(obj, type, data)
            % logEvent Appends an event to .agent/events.jsonl
            try
                event = struct('timestamp', datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFF'), ...
                               'type', type, ...
                               'data', data);
                fid = fopen(fullfile('.agent', 'events.jsonl'), 'a');
                if fid ~= -1
                    fprintf(fid, '%s\n', jsonencode(event));
                    fclose(fid);
                end
            catch
                % Fail silently on logging errors
            end
        end

        function run(obj)
            % run Starts the REPL interaction loop.
            %   Repeatedly asks for input and processes it until exit.

            obj.IsRunning = true;

            while obj.IsRunning
                try
                    % Ask user for input via event.
                    % Listeners must synchronously push user input to obj.Context.
                    evtData = struct('prompt', [obj.Mode, '> '], 'input', '');
                    notify(obj, 'UserInputRequired', AgentEventData(evtData));

                    lastMsg = obj.Context.T3_Conversation{end};
                    if ~strcmp(lastMsg.role, 'user') || isempty(strtrim(lastMsg.content))
                        continue;  % Don't process empty or non-user messages
                    end

                    % If the user typed /exit or adapter stopped the loop, break early
                    if ~obj.IsRunning
                        break;
                    end

                    % Fetch full context history
                    t3Messages = obj.Context.T3_Conversation;
                    if isempty(t3Messages)
                        continue;
                    end

                    % Only process if the last message was from user
                    lastMsg = t3Messages{end};
                    if ~strcmp(lastMsg.role, 'user')
                        continue;
                    end

                    % Log user input
                    obj.logEvent('user_input', struct('content', lastMsg.content));

                    % Check for special commands
                    if startsWith(lastMsg.content, '/')
                        obj.Context.pop(); % Remove command from history
                        obj.handleCommand(lastMsg.content);
                        continue;
                    end

                    % Execute the agent interaction (LLM + Tools)
                    obj.processInteraction();

                catch ME
                    % Fire error event instead of printing
                    errData = struct('message', ME.message, 'identifier', ME.identifier);
                    notify(obj, 'AgentError', AgentEventData(errData));
                end
            end
        end

        function processInteraction(obj)
            % processInteraction Handles the multi-turn LLM <-> Tool loop.
            
            interacting = true;
            while interacting
                % Prepend T1 (System config) and T2 (Session state) to the payload
                fullMessages = obj.Context.getPayload();
                
                fprintf('[DEBUG] Interaction turn. Messages in context: %d\n', length(fullMessages));

                % Execute the LLM Call with tool schemas
                toolSchemas = obj.Tools.getToolSchemas();
                response = obj.Client.chatCompletion(fullMessages, toolSchemas);

                % Process response
                if isfield(response, 'choices') && ~isempty(response.choices)
                    replyMsg = response.choices(1).message;
                    
                    % Ensure tool_calls is a cell array (for jsonencode to produce a list)
                    if isfield(replyMsg, 'tool_calls') && isstruct(replyMsg.tool_calls)
                        replyMsg.tool_calls = num2cell(replyMsg.tool_calls);
                    end
                    
                    % Ensure 'content' exists even if null (for ContextManager compatibility)
                    if ~isfield(replyMsg, 'content') || isempty(replyMsg.content)
                        replyMsg.content = ''; 
                    end
                    
                    obj.Context.push(replyMsg);

                    % Log the assistant's reply
                    obj.logEvent('assistant_reply', struct('content', replyMsg.content));

                    % Notify listener that text was received
                    if ~isempty(replyMsg.content)
                        notify(obj, 'ResponseReceived', AgentEventData(struct('text', replyMsg.content)));
                    end

                    % Check for tool calls (OpenAI format)
                    if isfield(replyMsg, 'tool_calls') && ~isempty(replyMsg.tool_calls)
                        % Log the tool calls
                        obj.logEvent('tool_calls', struct('calls', replyMsg.tool_calls));

                        toolCalls = replyMsg.tool_calls;
                        if isstruct(toolCalls)
                            toolCalls = num2cell(toolCalls);
                        end

                        for tIdx = 1:length(toolCalls)
                            tCall = toolCalls{tIdx}; % Use curly braces for cell indexing
                            toolName = tCall.function.name;
                            toolArgsJSON = tCall.function.arguments;

                            % Dispatch tool execution
                            resultStr = obj.Tools.dispatch(toolName, toolArgsJSON);
                            
                            % Log the tool result
                            obj.logEvent('tool_result', struct('name', toolName, 'result', resultStr));

                            % Push tool result back to context
                            toolResultMsg = struct('role', 'tool', ...
                                'tool_call_id', tCall.id, ...
                                'name', toolName, ...
                                'content', resultStr);
                            obj.Context.push(toolResultMsg);
                        end
                        % Continue loop to let LLM see tool results
                    else
                        % No more tool calls, interaction finished
                        interacting = false;
                    end
                else
                    interacting = false;
                end
            end
        end

        function modes = getAllowedModes(~)
            % getAllowedModes Returns a cell array of supported agent modes.
            modes = {'code', 'architect', 'ask', 'doc', 'test', 'report'};
        end

        function handleCommand(obj, cmdLine)
            % handleCommand Processes local /commands.
            parts = strsplit(cmdLine);
            cmd = parts{1};
            allowedModes = obj.getAllowedModes();
            modesStr = strjoin(allowedModes, ', ');

            switch cmd
                case {'/exit', '/quit'}
                    obj.IsRunning = false;
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', 'Exiting Mage...')));

                case '/mode'
                    if length(parts) > 1
                        newMode = parts{2};
                        if ismember(newMode, allowedModes)
                            obj.setMode(newMode);
                            notify(obj, 'ResponseReceived', AgentEventData(struct('text', sprintf('Mode set to: %s', obj.Mode))));
                        else
                            notify(obj, 'ResponseReceived', AgentEventData(struct('text', ...
                                sprintf('Invalid mode: %s. Allowed: %s', newMode, modesStr))));
                        end
                    else
                        notify(obj, 'ResponseReceived', AgentEventData(struct('text', ...
                            sprintf('Current mode: %s. Allowed: %s', obj.Mode, modesStr))));
                    end

                case '/model'
                    if length(parts) > 1
                        newModel = parts{2};
                        obj.Client.Model = newModel;
                        notify(obj, 'ResponseReceived', AgentEventData(struct('text', sprintf('Model set to: %s', obj.Client.Model))));
                    else
                        try
                            availableModels = obj.Client.listModels();
                            modelsStr = strjoin(availableModels, newline);
                            notify(obj, 'ResponseReceived', AgentEventData(struct('text', ...
                                sprintf('Current model: %s\nAvailable models:\n%s', obj.Client.Model, modelsStr))));
                        catch ME
                            notify(obj, 'ResponseReceived', AgentEventData(struct('text', ...
                                sprintf('Current model: %s\nFailed to list available models: %s', obj.Client.Model, ME.message))));
                        end
                    end

                case '/compact'
                    obj.Context.maybeCompact(); % In a real app, maybe force it here
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', 'Manual compaction triggered.')));

                case '/save'
                    obj.Context.saveSession();
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', 'Session state saved to .agent/session.json.')));

                case '/history'
                    histText = sprintf('Conversation History:\n');
                    for i = 1:length(obj.Context.T3_Conversation)
                        m = obj.Context.T3_Conversation{i};
                        % Escape % in content for sprintf
                        content = strrep(m.content, '%', '%%');
                        histText = [histText, sprintf('[%s]: %s\n', m.role, content(1:min(end, 50)))]; %#ok<AGROW>
                    end
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', histText)));

                case '/help'
                    helpText = ['Available Commands:\n', ...
                               '/exit, /quit   - Exit the agent\n', ...
                               sprintf('/mode [mode]   - Set or get the current mode (Allowed: %s)\n', modesStr), ...
                               '/model [model] - Set or get the LLM model (Lists available if no arg)\n', ...
                               '/compact       - Trigger context compaction\n', ...
                               '/save          - Save current session state\n', ...
                               '/history       - Show conversation history\n', ...
                               '/help          - Show this help message'];
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', sprintf(helpText))));

                otherwise

                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', sprintf('Unknown command: %s', cmd))));
            end
        end

        function setMode(obj, newMode)
            % setMode Change the agent mode.
            obj.Mode = newMode;
        end
    end
end
