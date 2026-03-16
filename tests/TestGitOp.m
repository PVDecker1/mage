classdef TestGitOp < matlab.unittest.TestCase
    % TestGitOp Tests for tools/GitOp.m

    methods (Test)
        function testGitStatus(testCase)
            % Assuming tests are run inside a git repo (which MATL-AGENT is)
            args = struct('command', 'status');
            res = GitOp([], args);

            testCase.verifyTrue(contains(res, 'Output of `git status`'));
        end

        function testGitFail(testCase)
            args = struct('command', 'fake-command-xyz');
            res = GitOp([], args);

            testCase.verifyTrue(contains(res, 'failed with status'));
        end

        function testSecurityCheck(testCase)
            % Should block command chaining
            args = struct('command', 'status; rm -rf /');
            testCase.verifyError(@() GitOp([], args), 'matl_agent:GitOp:invalidChars');

            args = struct('command', 'status & echo hack');
            testCase.verifyError(@() GitOp([], args), 'matl_agent:GitOp:invalidChars');
        end

        function testMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() GitOp([], args), 'matl_agent:GitOp:missingArgs');
        end
    end
end
