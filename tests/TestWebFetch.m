classdef TestWebFetch < matlab.unittest.TestCase
    % TestWebFetch Tests for tools/WebFetch.m

    methods (Test)
        function testWebFetchSuccess(testCase)
            % Use a reliable, fast endpoint (e.g. example.com)
            args = struct('url', 'http://example.com');
            res = WebFetch([], args);

            testCase.verifyTrue(contains(res, 'Successfully fetched'));
            testCase.verifyTrue(contains(res, 'Example Domain'));
        end

        function testWebFetchFail(testCase)
            % Use an invalid endpoint
            args = struct('url', 'http://this-url-is-fake-and-will-fail.xyz');
            res = WebFetch([], args);

            testCase.verifyTrue(contains(res, 'Failed to fetch'));
        end

        function testMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() WebFetch([], args), 'mage:WebFetch:missingArgs');
        end
    end
end
