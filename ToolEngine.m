classdef ToolEngine < handle
    % ToolEngine Central dispatch system for MATL-AGENT tools.
    %   Loads, registers, and executes tool handlers based on tool_call JSON.

    properties
        Handlers % A containers.Map linking tool names to handler function handles.
        Agent    % Reference to AgentLoop
    end

    methods
        function obj = ToolEngine(agentLoop)
            % ToolEngine Constructor
            %   Initializes the engine with an AgentLoop reference.

            if nargin < 1
                error('matl_agent:ToolEngine:missingAgent', 'ToolEngine requires an AgentLoop instance.');
            end

            obj.Agent = agentLoop;
            obj.Handlers = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % Register built-in tool handlers automatically upon instantiation
            obj.registerHandlers();
        end

        function registerHandlers(obj)
            % registerHandlers Maps tool names to their corresponding functions.
            %   All tool functions should accept (agent, args) and return a string.

            % Using strings to ensure matching with expected tool names in JSON
            obj.Handlers('read_file') = @ReadFile;
            obj.Handlers('write_file') = @WriteFile;
            obj.Handlers('edit_file') = @EditFile;
            obj.Handlers('list_dir') = @ListDir;
            obj.Handlers('search_files') = @SearchFiles;
            obj.Handlers('matlab_eval') = @MatlabEval;
            obj.Handlers('run_tests') = @RunTests;
            obj.Handlers('run_script') = @RunScript;
            obj.Handlers('shell_cmd') = @ShellCmd;
            obj.Handlers('git_op') = @GitOp;
            obj.Handlers('web_fetch') = @WebFetch;
            obj.Handlers('ask_human') = @AskHuman;
            obj.Handlers('load_skill') = @LoadSkill;
            obj.Handlers('search_docs') = @SearchDocs;
        end

        function result = dispatch(obj, toolName, argsJSON)
            % dispatch Executes a tool based on its name and string JSON args.
            %   Returns a string result representing the tool's output.

            if ~isKey(obj.Handlers, toolName)
                error('matl_agent:ToolEngine:unknownTool', 'Unknown tool: %s', toolName);
            end

            % Parse arguments if provided
            if nargin > 2 && ~isempty(argsJSON)
                try
                    args = jsondecode(argsJSON);
                catch ME
                    error('matl_agent:ToolEngine:invalidArgs', 'Invalid JSON arguments for tool %s: %s', toolName, ME.message);
                end
            else
                args = struct();
            end

            % Fire ToolCallStarted event
            startData = struct('name', toolName, 'args', args);
            notify(obj.Agent, 'ToolCallStarted', AgentEventData(startData));

            % Execute the tool
            try
                handlerFunc = obj.Handlers(toolName);
                result = handlerFunc(obj.Agent, args);
            catch ME
                % Propagate errors up or format them as tool output strings
                result = sprintf('Error executing tool %s: %s', toolName, ME.message);
            end

            % Fire ToolCallCompleted event
            endData = struct('name', toolName, 'result', result);
            notify(obj.Agent, 'ToolCallCompleted', AgentEventData(endData));
        end
    end
end
