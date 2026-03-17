classdef AgentLoop < handle
    % AgentLoop Core engine for MATL-AGENT.
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
                % Small delay to respect rate limits
                pause(1.0);

                % Prepend T1 (System config) and T2 (Session state) to the payload
                t3Messages = obj.Context.T3_Conversation;
                fullMessages = [obj.Context.T1_Config, t3Messages];
                
                fprintf('[DEBUG] Interaction turn. Messages in context: %d\n', length(fullMessages));

                % Execute the LLM Call with tool schemas
                toolSchemas = obj.Tools.getToolSchemas();
                response = obj.Client.chatCompletion(fullMessages, toolSchemas);

                % Process response
                if isfield(response, 'choices') && ~isempty(response.choices)
                    replyMsg = response.choices(1).message;
                    
                    % Ensure tool_calls is a cell array (for jsonencode to produce a list)
                    if isfield(replyMsg, 'tool_calls') && isstruct(replyMsg.tool_calls)
                        replyMsg.tool_calls = {replyMsg.tool_calls};
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
                            toolCalls = {toolCalls};
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

        function handleCommand(obj, cmdLine)
            % handleCommand Processes local /commands.
            parts = strsplit(cmdLine);
            cmd = parts{1};

            switch cmd
                case {'/exit', '/quit'}
                    obj.IsRunning = false;
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', 'Exiting MATL-AGENT...')));

                case '/mode'
                    if length(parts) > 1
                        obj.setMode(parts{2});
                        notify(obj, 'ResponseReceived', AgentEventData(struct('text', sprintf('Mode set to: %s', obj.Mode))));
                    else
                        notify(obj, 'ResponseReceived', AgentEventData(struct('text', sprintf('Current mode: %s', obj.Mode))));
                    end

                case '/compact'
                    obj.Context.maybeCompact(); % In a real app, maybe force it here
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', 'Manual compaction triggered.')));

                case '/save'
                    obj.Context.saveSession();
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', 'Session state saved to .agent/session.json.')));

                case '/history'
                    histText = 'Conversation History:\n';
                    for i = 1:length(obj.Context.T3_Conversation)
                        m = obj.Context.T3_Conversation{i};
                        histText = [histText, sprintf('[%s]: %s\n', m.role, m.content(1:min(end, 50)))]; %#ok<AGROW>
                    end
                    notify(obj, 'ResponseReceived', AgentEventData(struct('text', histText)));

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
