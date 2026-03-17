function agent = matl_agent()
    % matl_agent Entry point for MATL-AGENT.
    %   Initializes AgentLoop, adapters, reads config, and starts the REPL.

    % Add necessary subdirectories to the path dynamically
    agentDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(agentDir, 'io'));
    addpath(fullfile(agentDir, 'skills'));
    addpath(fullfile(agentDir, 'tools'));

    % Ensure .agent/ exists
    agentFolder = fullfile(pwd, '.agent');
    if ~isfolder(agentFolder)
        mkdir(agentFolder);
    end

    % Define configuration search paths
    localCfgPath = fullfile(pwd, '.agent', 'config.json');
    sourceCfgPath = fullfile(agentDir, '.agent', 'config.json');

    if isfile(localCfgPath)
        cfgPath = localCfgPath;
    elseif isfile(sourceCfgPath)
        cfgPath = sourceCfgPath;
        fprintf('Using configuration from agent source: %s\n', cfgPath);
    else
        % If neither exists, we'll create a local template
        cfgPath = localCfgPath;
        fprintf('Config file not found. Creating a template at %s\n', cfgPath);

        defaultCfg = struct(...
            'endpoint', 'https://generativelanguage.googleapis.com/v1beta/openai/', ...
            'model', 'gemini-1.5-flash', ...
            'compaction_model', 'gemini-1.5-flash', ...
            'max_tokens', 8192, ...
            'context_budget', 100000, ...
            'compact_threshold', 0.70, ...
            'secrets', struct(...
                'api_key', 'YOUR_KEY_HERE', ...
                'gitlab_token', 'glpat-xxxxxxxxxxxx', ...
                'gitlab_url', 'https://gitlab.yourorg.com' ...
            )...
        );

        try
            if ~isfolder(fullfile(pwd, '.agent')), mkdir(fullfile(pwd, '.agent')); end
            fid = fopen(cfgPath, 'w');
            if fid ~= -1
                fprintf(fid, '%s', jsonencode(defaultCfg, 'PrettyPrint', true));
                fclose(fid);
            end
            fprintf('Please edit %s with your API key and settings.\n', cfgPath);
        catch ME
            fprintf(2, 'Warning: Could not create config.json. Error: %s\n', ME.message);
        end

        cfg = defaultCfg;
    end

    % Read the chosen config
    if isfile(cfgPath) && ~exist('cfg', 'var')
        try
            cfgText = fileread(cfgPath);
            cfg = jsondecode(cfgText);
        catch ME
            fprintf(2, 'Warning: Could not read config.json. Error: %s\n', ME.message);
            cfg = struct();
        end
    end

    % Read AGENT.md (Project Context T1)
    agentMdPath = fullfile(pwd, 'AGENT.md');
    agentMdContent = '';
    if isfile(agentMdPath)
        agentMdContent = fileread(agentMdPath);
    end

    % Create Core Loop
    agent = AgentLoop(cfg);

    % Initialize and Inject Dependencies
    agent.Context = ContextManager(cfg, agent);
    agent.Context.T1_Config = {struct('role', 'system', 'content', agentMdContent)};

    agent.Client = LLMClient(cfg);
    agent.Tools = ToolEngine(agent);
    agent.Skills = SkillRegistry(cfg);

    % Diagnostic Output
    fprintf('--- Configuration Diagnostic ---\n');
    fprintf('Model: %s\n', agent.Client.Model);
    if isempty(agent.Client.ApiKey)
        fprintf('API Key: [MISSING]\n');
    else
        fprintf('API Key: [LOADED] (starts with %s...)\n', agent.Client.ApiKey(1:min(end,4)));
    end
    fprintf('--------------------------------\n');

    % Attach I/O Adapter (Command Window REPL)
    CmdWindowAdapter(agent); % Handles setup on construction

    fprintf('MATL-AGENT initialized successfully in directory: %s\n', pwd);
    fprintf('Type /exit to quit.\n');

    % Optional: return handle without running if nargout > 0
    if nargout == 0
        agent.run();
    end
end
