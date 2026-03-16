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

    % Read or default .agent/config.json
    cfgPath = fullfile(agentFolder, 'config.json');
    if isfile(cfgPath)
        try
            cfgText = fileread(cfgPath);
            cfg = jsondecode(cfgText);
        catch ME
            fprintf(2, 'Warning: Could not read config.json. Using defaults. Error: %s\n', ME.message);
            cfg = struct();
        end
    else
        fprintf('Config file not found at %s. Proceeding with defaults.\n', cfgPath);
        cfg = struct();
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

    % Attach I/O Adapter (Command Window REPL)
    CmdWindowAdapter(agent); % Handles setup on construction

    fprintf('MATL-AGENT initialized successfully in directory: %s\n', pwd);
    fprintf('Type /exit to quit.\n');

    % Optional: return handle without running if nargout > 0
    if nargout == 0
        agent.run();
    end
end
