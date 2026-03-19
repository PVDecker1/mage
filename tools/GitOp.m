function result = GitOp(~, args)
    % GitOp Runs git operations via shell command.
    %   args must contain 'op', and optionally 'args' (arguments string).

    if isfield(args, 'command') % backward compatibility
        fullGitCmd = sprintf('git %s', args.command);
        displayCmd = args.command;
    elseif isfield(args, 'op')
        if isfield(args, 'args')
            fullGitCmd = sprintf('git %s %s', args.op, args.args);
            displayCmd = sprintf('%s %s', args.op, args.args);
        else
            fullGitCmd = sprintf('git %s', args.op);
            displayCmd = args.op;
        end
    else
        error('mage:GitOp:missingArgs', 'Missing op or command argument');
    end

    % Ensure no malicious commands appended
    if contains(fullGitCmd, ';') || contains(fullGitCmd, '&') || contains(fullGitCmd, '|')
        error('mage:GitOp:invalidChars', 'Invalid characters in git command.');
    end

    try
        [status, cmdout] = system(fullGitCmd);

        if status == 0
            if isempty(cmdout)
                result = sprintf('Successfully ran `git %s` (no output).', displayCmd);
            else
                result = sprintf('Output of `git %s`:\n%s', displayCmd, cmdout);
            end
        else
            result = sprintf('`git %s` failed with status %d:\n%s', displayCmd, status, cmdout);
        end
    catch ME
        result = sprintf('Failed to run `git %s`: %s', displayCmd, ME.message);
    end
end
