classdef ToolEngine < handle
    % ToolEngine Central dispatch system for MATL-AGENT tools.
    %   Loads, registers, and executes tool handlers based on tool_call JSON.

    properties
        Handlers % A containers.Map linking tool names to handler function handles.
        Schemas  % A struct array containing OpenAI-compatible function definitions.
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
            obj.Schemas = [];

            % Register built-in tool handlers automatically upon instantiation
            obj.registerHandlers();
            obj.defineSchemas();
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

        function defineSchemas(obj)
            % defineSchemas populates the Schemas property with OpenAI-style tool definitions.

            % Helper to create a function schema
            f = @(name, desc, params) struct('type', 'function', 'function', ...
                struct('name', name, 'description', desc, 'parameters', params));

            % Parameters helper (simple object with properties)
            p = @(props, required) struct('type', 'object', 'properties', props, 'required', {required});

            % Define individual tool schemas
            s = [];
            
            s = [s, f('read_file', 'Read the content of a file from disk.', ...
                p(struct('filepath', struct('type', 'string', 'description', 'Path to the file')), {'filepath'}))];
                
            s = [s, f('write_file', 'Write content to a file, overwriting existing content.', ...
                p(struct('filepath', struct('type', 'string', 'description', 'Path to the file'), ...
                         'content', struct('type', 'string', 'description', 'Content to write')), {'filepath', 'content'}))];

            s = [s, f('edit_file', 'Edit a file by replacing an old string with a new string.', ...
                p(struct('filepath', struct('type', 'string', 'description', 'Path to the file'), ...
                         'old_str', struct('type', 'string', 'description', 'The literal string to find'), ...
                         'new_str', struct('type', 'string', 'description', 'The string to replace it with')), {'filepath', 'old_str', 'new_str'}))];

            s = [s, f('list_dir', 'List files and directories in a given path.', ...
                p(struct('dir', struct('type', 'string', 'description', 'Path to list (defaults to .)'), ...
                         'recursive', struct('type', 'boolean', 'description', 'Whether to list recursively')), {}))];

            s = [s, f('search_files', 'Search for a regex pattern across files.', ...
                p(struct('pattern', struct('type', 'string', 'description', 'Regex pattern to search for'), ...
                         'dir', struct('type', 'string', 'description', 'Directory to search in')), {'pattern'}))];

            s = [s, f('matlab_eval', 'Evaluate arbitrary MATLAB code and return Command Window output.', ...
                p(struct('code', struct('type', 'string', 'description', 'MATLAB code to execute')), {'code'}))];

            s = [s, f('run_tests', 'Run the project test suite using matlab.unittest.', ...
                p(struct('path', struct('type', 'string', 'description', 'Path to tests folder (defaults to tests/)')), {}))];

            s = [s, f('run_script', 'Execute a MATLAB script file.', ...
                p(struct('script_path', struct('type', 'string', 'description', 'Path to the .m script')), {'script_path'}))];

            s = [s, f('shell_cmd', 'Run a system shell command (e.g., git, npm, ls).', ...
                p(struct('command', struct('type', 'string', 'description', 'The shell command to run')), {'command'}))];

            s = [s, f('git_op', 'Perform a git operation (status, diff, commit, push, pull, branch, log).', ...
                p(struct('op', struct('type', 'string', 'enum', {{'status', 'diff', 'commit', 'push', 'pull', 'branch', 'log'}}, 'description', 'The git operation'), ...
                         'args', struct('type', 'string', 'description', 'Arguments for the git operation')), {'op'}))];

            s = [s, f('web_fetch', 'Fetch the content of a URL (useful for docs or research).', ...
                p(struct('url', struct('type', 'string', 'description', 'URL to fetch')), {'url'}))];

            s = [s, f('ask_human', 'Ask the user a question or for clarification.', ...
                p(struct('question', struct('type', 'string', 'description', 'The question to ask the user')), {'question'}))];

            s = [s, f('load_skill', 'Load a specialized skill pack from .agent/skills/.', ...
                p(struct('skill_name', struct('type', 'string', 'description', 'Name of the skill to load')), {'skill_name'}))];

            s = [s, f('search_docs', 'Search for MATLAB or project documentation.', ...
                p(struct('query', struct('type', 'string', 'description', 'The search query')), {'query'}))];

            obj.Schemas = s;
        end

        function schemas = getToolSchemas(obj)
            % getToolSchemas Returns the struct array of OpenAI-compatible function definitions.
            schemas = obj.Schemas;
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
