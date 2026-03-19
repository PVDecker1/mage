classdef CmdWindowAdapter < handle
    % CmdWindowAdapter Handles Command Window I/O for Mage.
    %   Subscribes to AgentLoop events and uses fprintf/input to interact
    %   with the user.

    properties
        AgentLoop % Reference to the core loop
        Listeners % Array of listener handles
    end

    methods
        function obj = CmdWindowAdapter(agentLoop)
            % CmdWindowAdapter Constructor

            if nargin < 1 || isempty(agentLoop)
                error('mage:CmdWindowAdapter:missingAgent', 'Requires an AgentLoop instance.');
            end

            obj.AgentLoop = agentLoop;
            obj.attachListeners();
        end

        function attachListeners(obj)
            % attachListeners Subscribes to agent events.

            % For response, tool start/end, compaction, and errors: just print
            obj.Listeners = [
                addlistener(obj.AgentLoop, 'ResponseReceived', @obj.onResponseReceived)
                addlistener(obj.AgentLoop, 'ToolCallStarted', @obj.onToolCallStarted)
                addlistener(obj.AgentLoop, 'ToolCallCompleted', @obj.onToolCallCompleted)
                addlistener(obj.AgentLoop, 'ContextCompacted', @obj.onContextCompacted)
                addlistener(obj.AgentLoop, 'AgentError', @obj.onAgentError)
                addlistener(obj.AgentLoop, 'UserInputRequired', @obj.onUserInputRequired)
            ];
        end

        % Event Handlers
        function onResponseReceived(~, ~, eventData)
            if isfield(eventData.Data, 'text')
                fprintf('\n%s\n', eventData.Data.text);
            end
        end

        function onToolCallStarted(~, ~, eventData)
            name = eventData.Data.name;
            fprintf('[Agent is calling tool: %s...]\n', name);
        end

        function onToolCallCompleted(~, ~, eventData)
            % Optionally print result length or a checkmark
            name = eventData.Data.name;
            fprintf('[Tool %s completed.]\n', name);
        end

        function onContextCompacted(~, ~, ~)
            fprintf('[Context auto-compacted to save tokens.]\n');
        end

        function onAgentError(~, ~, eventData)
            fprintf(2, '\nError: %s\n', eventData.Data.message);
        end

        function onUserInputRequired(obj, ~, eventData)
            % Blocks and asks user for input via the Command Window
            promptStr = eventData.Data.prompt;
            userInput = input(promptStr, 's');
            
            % Store the response for tools to access
            eventData.Response = userInput;

            % Check for special commands to terminate the loop before pushing
            if strcmp(userInput, '/exit') || strcmp(userInput, '/quit')
                obj.AgentLoop.IsRunning = false;
                fprintf('Exiting Mage...\n');
                return;
            end

            % Push user input to the AgentLoop's context
            if ~isempty(obj.AgentLoop.Context)
                msg = struct('role', 'user', 'content', userInput);
                obj.AgentLoop.Context.push(msg);
            else
                fprintf(2, 'Warning: AgentLoop context is not initialized. Input ignored.\n');
            end
        end
    end
end
