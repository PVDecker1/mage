function result = RunScript(~, args)
    % RunScript Executes a MATLAB script (.m file).
    %   args must contain 'script_path'.

    if ~isfield(args, 'script_path')
        error('matl_agent:RunScript:missingArgs', 'Missing script_path argument');
    end

    scriptPath = args.script_path;

    if ~isfile(scriptPath)
        error('matl_agent:RunScript:fileNotFound', 'Script file not found: %s', scriptPath);
    end

    try
        [~, name, ext] = fileparts(scriptPath);
        if ~strcmp(ext, '.m')
            error('matl_agent:RunScript:notMFile', 'File must be a .m script');
        end

        % We use evalc to capture output, and run it.
        % Adding path temporarily just in case.
        code = sprintf('addpath(fileparts("%s"));\n%s;\nrmpath(fileparts("%s"));', scriptPath, name, scriptPath);

        output = evalc(code);

        if isempty(output)
            result = sprintf('Successfully ran script %s. No output.', name);
        else
            result = sprintf('Successfully ran script %s. Output:\n%s', name, output);
        end
    catch ME
        result = sprintf('Failed to run script %s: %s', scriptPath, ME.message);
    end
end
