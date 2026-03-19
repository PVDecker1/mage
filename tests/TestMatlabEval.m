classdef TestMatlabEval < matlab.unittest.TestCase
    % TestMatlabEval Tests for tools/MatlabEval.m

    methods (Test)
        function testEvalSuccessWithOutput(testCase)
            args = struct('code', 'disp("Hello from agent"); a = 5;');
            res = MatlabEval([], args);

            testCase.verifyTrue(contains(res, 'Hello from agent'));
        end

        function testEvalSuccessNoOutput(testCase)
            args = struct('code', 'b = 10;'); % Semicolon suppresses output
            res = MatlabEval([], args);

            testCase.verifyTrue(contains(res, 'No output'));
        end

        function testEvalError(testCase)
            % Should fail because fakeFunc doesnt exist
            args = struct('code', 'fakeFuncThatDoesNotExist()');
            res = MatlabEval([], args);

            % Should catch error and return as a string
            testCase.verifyTrue(contains(res, 'Execution failed'));
            testCase.verifyTrue(contains(res, 'Unrecognized function or variable'));
        end

        function testEvalMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() MatlabEval([], args), 'mage:MatlabEval:missingArgs');
        end
    end
end
