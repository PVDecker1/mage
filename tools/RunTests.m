function result = RunTests(~, args)
    % RunTests Executes MATLAB tests in a specified directory or file.
    %   args may optionally contain 'path' (default: 'tests').

    if nargin > 1 && isfield(args, 'path')
        testPath = args.path;
    else
        testPath = 'tests';
    end

    % Robustness: if it doesn't exist, try prepending 'tests/' or adding '.m'
    if ~exist(testPath, 'file') && ~exist(testPath, 'dir')
        % Try prepending 'tests/'
        if ~startsWith(testPath, ['tests', filesep]) && ~startsWith(testPath, 'tests/')
            altPath = fullfile('tests', testPath);
            if exist(altPath, 'file') || exist(altPath, 'dir')
                testPath = altPath;
            elseif exist([altPath, '.m'], 'file')
                testPath = [altPath, '.m'];
            end
        end
        
        % Try adding '.m' if still not found
        if ~exist(testPath, 'file') && ~exist(testPath, 'dir') && ~endsWith(testPath, '.m')
            if exist([testPath, '.m'], 'file')
                testPath = [testPath, '.m'];
            end
        end
    end

    if ~isfolder(testPath) && ~isfile(testPath)
        result = sprintf('Error: Path not found: %s. Please ensure the path is correct relative to the project root.', testPath);
        return;
    end

    try
        % Using evalc to capture test runner output
        % And matlab.unittest for execution
        if isfile(testPath)
            code = sprintf('import matlab.unittest.TestSuite;\nsuite = TestSuite.fromFile("%s");\nimport matlab.unittest.TestRunner;\nrunner = TestRunner.withTextOutput;\nres = runner.run(suite);', testPath);
        else
            code = sprintf('import matlab.unittest.TestSuite;\nsuite = TestSuite.fromFolder("%s");\nimport matlab.unittest.TestRunner;\nrunner = TestRunner.withTextOutput;\nres = runner.run(suite);', testPath);
        end

        output = evalc(code);

        % In a real implementation we would format `res` properly.
        % For now we just return the captured output.
        result = sprintf('Test execution output:\n%s', output);
    catch ME
        result = sprintf('Failed to run tests:\n%s', ME.message);
    end
end
