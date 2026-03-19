function result = MatlabEval(~, args)
    % MatlabEval Evaluates MATLAB code as a string.
    %   args must contain 'code'.

    if ~isfield(args, 'code')
        error('mage:MatlabEval:missingArgs', 'Missing code argument');
    end

    code = args.code;

    try
        % Using evalc to capture output
        output = evalc(code);
        if isempty(output)
            result = 'Execution successful. No output.';
        else
            result = sprintf('Execution output:\n%s', output);
        end
    catch ME
        result = sprintf('Execution failed:\n%s\n%s', ME.message, ME.stack(1).name);
    end
end
