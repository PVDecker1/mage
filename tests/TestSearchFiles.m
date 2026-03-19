classdef TestSearchFiles < matlab.unittest.TestCase
    % TestSearchFiles Tests for tools/SearchFiles.m

    properties
        TempDir
        MatchFile
        NoMatchFile
    end

    methods (TestMethodSetup)
        function createTempEnv(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);

            % Match file
            testCase.MatchFile = fullfile(testCase.TempDir, 'file1.m');
            fid = fopen(testCase.MatchFile, 'w');
            fprintf(fid, 'function test()\n  disp("UNIQUE_PATTERN");\nend');
            fclose(fid);

            % No Match file
            testCase.NoMatchFile = fullfile(testCase.TempDir, 'file2.txt');
            fid = fopen(testCase.NoMatchFile, 'w');
            fprintf(fid, 'Some other text\n');
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
        function testSearchPatternFound(testCase)
            args = struct('pattern', 'UNIQUE_PATTERN', 'dir', testCase.TempDir);
            res = SearchFiles([], args);

            testCase.verifyTrue(contains(res, 'Found pattern'));
            testCase.verifyTrue(contains(res, 'file1.m'));
            testCase.verifyFalse(contains(res, 'file2.txt'));
        end

        function testSearchPatternNotFound(testCase)
            args = struct('pattern', 'GIBBERISH_123', 'dir', testCase.TempDir);
            res = SearchFiles([], args);

            testCase.verifyTrue(contains(res, 'No files found'));
        end

        function testMissingArgs(testCase)
            args = struct('dir', testCase.TempDir); % missing pattern
            testCase.verifyError(@() SearchFiles([], args), 'mage:SearchFiles:missingArgs');
        end
    end
end
