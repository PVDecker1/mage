classdef TestWriteFile < matlab.unittest.TestCase
    % TestWriteFile Tests for tools/WriteFile.m

    properties
        TempFile
    end

    methods (TestMethodSetup)
        function generateTempName(testCase)
            testCase.TempFile = [tempname, '.txt'];
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
        function testWriteFileSuccess(testCase)
            args = struct('filepath', testCase.TempFile, 'content', 'Hello World');
            res = WriteFile([], args);

            testCase.verifyTrue(isfile(testCase.TempFile));
            content = fileread(testCase.TempFile);
            testCase.verifyEqual(content, 'Hello World');
            testCase.verifyTrue(contains(res, 'Successfully wrote'));
        end

        function testWriteFileMissingArgs(testCase)
            args = struct('filepath', testCase.TempFile); % Missing content
            testCase.verifyError(@() WriteFile([], args), 'matl_agent:WriteFile:missingArgs');
        end
    end
end
