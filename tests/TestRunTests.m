classdef TestRunTests < matlab.unittest.TestCase
    % TestRunTests Tests for tools/RunTests.m

    properties
        TempDir
        TestFile
    end

    methods (TestMethodSetup)
        function createTempEnv(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);

            % Create a dummy test file
            testCase.TestFile = fullfile(testCase.TempDir, 'TestDummy.m');
            fid = fopen(testCase.TestFile, 'w');
            fprintf(fid, 'classdef TestDummy < matlab.unittest.TestCase\n');
            fprintf(fid, '  methods (Test)\n');
            fprintf(fid, '    function testPass(testCase)\n');
            fprintf(fid, '      testCase.verifyTrue(true);\n');
            fprintf(fid, '    end\n');
            fprintf(fid, '  end\n');
            fprintf(fid, 'end\n');
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
        function testRunTestsSuccess(testCase)
            args = struct('path', testCase.TempDir);
            res = RunTests([], args);

            % It should capture runner output indicating 1 test run
            testCase.verifyTrue(contains(res, 'Test execution output'));
            testCase.verifyTrue(contains(res, 'Done TestDummy'));
            testCase.verifyTrue(contains(res, '1 Passed'));
        end

        function testInvalidPath(testCase)
            args = struct('path', 'some/fake/folder');
            testCase.verifyError(@() RunTests([], args), 'matl_agent:RunTests:pathNotFound');
        end
    end
end
