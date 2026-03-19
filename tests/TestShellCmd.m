classdef TestShellCmd < matlab.unittest.TestCase
    % TestShellCmd Tests for tools/ShellCmd.m

    methods (Test)
        function testShellCmdSuccess(testCase)
            % Simple echo command works cross-platform (mostly)
            args = struct('command', 'echo "Hello from shell"');
            res = ShellCmd([], args);

            testCase.verifyTrue(contains(res, 'executed successfully'));
            testCase.verifyTrue(contains(res, 'Hello from shell'));
        end

        function testShellCmdFail(testCase)
            args = struct('command', 'command_that_does_not_exist_xyz123');
            res = ShellCmd([], args);

            testCase.verifyTrue(contains(res, 'failed with status'));
        end

        function testMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() ShellCmd([], args), 'mage:ShellCmd:missingArgs');
        end
    end
end
