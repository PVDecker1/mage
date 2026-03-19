classdef TestEditFile < matlab.unittest.TestCase
    % TestEditFile Tests for tools/EditFile.m

    properties
        TempFile
    end

    methods (TestMethodSetup)
        function createTempFile(testCase)
            testCase.TempFile = [tempname, '.txt'];
            fid = fopen(testCase.TempFile, 'w');
            fprintf(fid, 'Hello World\nLine2');
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
        function testEditFileSuccess(testCase)
            args = struct('filepath', testCase.TempFile, 'old_str', 'World', 'new_str', 'MATLAB');
            res = EditFile([], args);

            content = fileread(testCase.TempFile);
            testCase.verifyEqual(content, sprintf('Hello MATLAB\nLine2'));
            testCase.verifyTrue(contains(res, 'Successfully edited'));
        end

        function testEditFileStringNotFound(testCase)
            args = struct('filepath', testCase.TempFile, 'old_str', 'XYZ', 'new_str', 'MATLAB');
            res = EditFile([], args);

            content = fileread(testCase.TempFile);
            testCase.verifyEqual(content, sprintf('Hello World\nLine2')); % Unchanged
            testCase.verifyTrue(contains(res, 'not found'));
        end

        function testEditFileMissingArgs(testCase)
            args = struct('filepath', testCase.TempFile, 'old_str', 'World'); % Missing new_str
            testCase.verifyError(@() EditFile([], args), 'mage:EditFile:missingArgs');
        end
    end
end
