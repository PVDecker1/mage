function result = GitOp(~, args)
    % GitOp Runs git operations via shell command.
    %   args must contain 'command' (e.g., 'status', 'diff').

    if ~isfield(args, 'command')
        error('matl_agent:GitOp:missingArgs', 'Missing command argument');
    end

    subcmd = args.command;

    % Ensure no malicious commands appended
    if contains(subcmd, ';') || contains(subcmd, '&') || contains(subcmd, '|')
        error('matl_agent:GitOp:invalidChars', 'Invalid characters in git command.');
    end

    gitCmd = sprintf('git %s', subcmd);

    try
        [status, cmdout] = system(gitCmd);

        if status == 0
            if isempty(cmdout)
                result = sprintf('Successfully ran `git %s` (no output).', subcmd);
            else
                result = sprintf('Output of `git %s`:\n%s', subcmd, cmdout);
            end
        else
            result = sprintf('`git %s` failed with status %d:\n%s', subcmd, status, cmdout);
        end
    catch ME
        result = sprintf('Failed to run `git %s`: %s', subcmd, ME.message);
    end
end
