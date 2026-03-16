function result = ShellCmd(~, args)
    % ShellCmd Executes a shell command and returns output.
    %   args must contain 'command'.

    if ~isfield(args, 'command')
        error('matl_agent:ShellCmd:missingArgs', 'Missing command argument');
    end

    command = args.command;

    try
        [status, cmdout] = system(command);

        if status == 0
            if isempty(cmdout)
                result = sprintf('Command `%s` executed successfully. No output.', command);
            else
                result = sprintf('Command `%s` executed successfully:\n%s', command, cmdout);
            end
        else
            result = sprintf('Command `%s` failed with status %d:\n%s', command, status, cmdout);
        end
    catch ME
        result = sprintf('Failed to execute command `%s`: %s', command, ME.message);
    end
end
