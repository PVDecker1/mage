classdef TestListDir < matlab.unittest.TestCase
    % TestListDir Tests for tools/ListDir.m

    properties
        TempDir
        TempFile
    end

    methods (TestMethodSetup)
        function createTempEnv(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);

            % Create a dummy file and a subfolder inside it
            testCase.TempFile = fullfile(testCase.TempDir, 'dummy.txt');
            fid = fopen(testCase.TempFile, 'w');
            fprintf(fid, 'test');
            fclose(fid);

            mkdir(fullfile(testCase.TempDir, 'subdir'));
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
        function testListDirSuccess(testCase)
            args = struct('path', testCase.TempDir);
            res = ListDir([], args);

            testCase.verifyTrue(contains(res, 'dummy.txt'));
            testCase.verifyTrue(contains(res, 'subdir/'));
        end

        function testListDirDefaultPath(testCase)
            args = struct(); % no path given
            res = ListDir([], args);

            % Should just list pwd without crashing
            testCase.verifyTrue(ischar(res));
            testCase.verifyTrue(contains(res, pwd) || contains(res, 'Contents'));
        end

        function testListDirInvalidDir(testCase)
            args = struct('path', 'some/fake/dir/xyz123');
            testCase.verifyError(@() ListDir([], args), 'mage:ListDir:notDir');
        end
    end
end
