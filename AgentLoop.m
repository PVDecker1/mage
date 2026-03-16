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

                    % Check if the last message was from user. If not, don't ping LLM.
                    if ~strcmp(t3Messages{end}.role, 'user') && ~strcmp(t3Messages{end}.role, 'tool')
                        continue;
                    end

                    % Prepend T1 (System config) and T2 (Session state) to the payload
                    fullMessages = [obj.Context.T1_Config, t3Messages];

                    % Execute the LLM Call
                    % (We don't pass tool schemas in Phase 1's mock tools just yet,
                    % but the engine supports it.)
                    response = obj.Client.chatCompletion(fullMessages);

                    % Process response
                    if isfield(response, 'choices') && ~isempty(response.choices)
                        replyMsg = response.choices(1).message;
                        obj.Context.push(replyMsg);

                        % Notify listener that text was received
                        if isfield(replyMsg, 'content') && ~isempty(replyMsg.content)
                            notify(obj, 'ResponseReceived', AgentEventData(struct('text', replyMsg.content)));
                        end

                        % Check for tool calls (OpenAI format)
                        if isfield(replyMsg, 'tool_calls')
                            for tIdx = 1:length(replyMsg.tool_calls)
                                tCall = replyMsg.tool_calls(tIdx);
                                toolName = tCall.function.name;
                                toolArgsJSON = tCall.function.arguments;

                                % Dispatch tool execution
                                resultStr = obj.Tools.dispatch(toolName, toolArgsJSON);

                                % Push tool result back to context
                                toolResultMsg = struct('role', 'tool', ...
                                    'tool_call_id', tCall.id, ...
                                    'name', toolName, ...
                                    'content', resultStr);
                                obj.Context.push(toolResultMsg);
                            end

                            % Note: A real implementation would loop back to LLM here
                            % automatically after tool completion until it finishes.
                            % For scaffolding, we just wait for next REPL loop.
                        end
                    end

                catch ME
                    % Fire error event instead of printing
                    errData = struct('message', ME.message, 'identifier', ME.identifier);
                    notify(obj, 'AgentError', AgentEventData(errData));
                    % We don't exit the loop on error, just let the user try again
                end
            end
        end

        function setMode(obj, newMode)
            % setMode Change the agent mode.
            obj.Mode = newMode;
        end
    end
end
