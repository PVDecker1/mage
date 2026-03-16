classdef TestRunScript < matlab.unittest.TestCase
    % TestRunScript Tests for tools/RunScript.m

    properties
        TempDir
        ScriptFile
    end

    methods (TestMethodSetup)
        function createTempEnv(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);

            testCase.ScriptFile = fullfile(testCase.TempDir, 'myScript.m');
            fid = fopen(testCase.ScriptFile, 'w');
            fprintf(fid, 'disp("Script Executed");\n');
            fclose(fid);
        end
    end

    methods (TestMethodTeardown)
        function cleanupTempEnv(testCase)
            if isfolder(testCase.TempDir)
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)
        function testRunScriptSuccess(testCase)
            args = struct('script_path', testCase.ScriptFile);
            res = RunScript([], args);

            testCase.verifyTrue(contains(res, 'Successfully ran script myScript'));
            testCase.verifyTrue(contains(res, 'Script Executed'));
        end

        function testRunScriptFileNotFound(testCase)
            args = struct('script_path', fullfile(testCase.TempDir, 'fake.m'));
            testCase.verifyError(@() RunScript([], args), 'matl_agent:RunScript:fileNotFound');
        end

        function testRunScriptNotMFile(testCase)
            txtFile = fullfile(testCase.TempDir, 'myScript.txt');
            fid = fopen(txtFile, 'w');
            fprintf(fid, 'disp("Hello");');
            fclose(fid);

            args = struct('script_path', txtFile);
            testCase.verifyError(@() RunScript([], args), 'matl_agent:RunScript:notMFile');
        end

        function testMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() RunScript([], args), 'matl_agent:RunScript:missingArgs');
        end
    end
end
