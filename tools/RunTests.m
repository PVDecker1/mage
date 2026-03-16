function result = RunTests(~, args)
    % RunTests Executes MATLAB tests in a specified directory or file.
    %   args may optionally contain 'path' (default: 'tests').

    if nargin > 1 && isfield(args, 'path')
        testPath = args.path;
    else
        testPath = 'tests';
    end

    if ~isfolder(testPath) && ~isfile(testPath)
        error('matl_agent:RunTests:pathNotFound', 'Path not found: %s', testPath);
    end

    try
        % Using evalc to capture test runner output
        % And matlab.unittest for execution
        code = sprintf('import matlab.unittest.TestSuite;\nsuite = TestSuite.fromFolder("%s");\nimport matlab.unittest.TestRunner;\nrunner = TestRunner.withTextOutput;\nres = runner.run(suite);', testPath);

        output = evalc(code);

        % In a real implementation we would format `res` properly.
        % For now we just return the captured output.
        result = sprintf('Test execution output:\n%s', output);
    catch ME
        result = sprintf('Failed to run tests:\n%s', ME.message);
    end
end
