classdef TestReadFile < matlab.unittest.TestCase
    % TestReadFile Tests for tools/ReadFile.m

    properties
        TempFile
    end

    methods (TestMethodSetup)
        function createTempFile(testCase)
            testCase.TempFile = [tempname, '.txt'];
            fid = fopen(testCase.TempFile, 'w');
            fprintf(fid, 'Line1\nLine2');
            fclose(fid);
        end
    end

    methods (TestMethodTeardown)
        function cleanupTempFile(testCase)
            if isfile(testCase.TempFile)
                delete(testCase.TempFile);
            end
        end
    end

    methods (Test)
        function testReadFileSuccess(testCase)
            args = struct('filepath', testCase.TempFile);
            res = ReadFile([], args);
            testCase.verifyTrue(contains(res, 'Line1'));
            testCase.verifyTrue(contains(res, 'Line2'));
        end

        function testReadFileMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() ReadFile([], args), 'matl_agent:ReadFile:missingArgs');
        end

        function testReadFileFileNotFound(testCase)
            args = struct('filepath', 'nonexistent_file_xyz.m');
            testCase.verifyError(@() ReadFile([], args), 'matl_agent:ReadFile:fileNotFound');
        end
    end
end
