classdef TestSearchDocs < matlab.unittest.TestCase
    % TestSearchDocs Tests for tools/SearchDocs.m

    methods (Test)
        function testSearchDocsSuccess(testCase)
            % Use a common function guaranteed to exist (e.g. 'disp')
            args = struct('query', 'disp');
            res = SearchDocs([], args);

            testCase.verifyTrue(contains(res, 'Documentation for `disp`'));
            % Check that some common text from disp's doc exists
            testCase.verifyTrue(contains(res, 'array'));
        end

        function testSearchDocsNotFound(testCase)
            args = struct('query', 'function_that_does_not_exist_xyz123');
            res = SearchDocs([], args);

            testCase.verifyTrue(contains(res, 'No documentation found for'));
        end

        function testMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() SearchDocs([], args), 'mage:SearchDocs:missingArgs');
        end
    end
end
