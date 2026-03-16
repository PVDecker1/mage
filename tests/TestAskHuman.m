classdef TestAskHuman < matlab.unittest.TestCase
    % TestAskHuman Tests for tools/AskHuman.m

    properties
        AgentLoop % Mock agent for events
    end

    methods (TestMethodSetup)
        function createMockAgent(testCase)
            testCase.AgentLoop = AgentLoop();
        end
    end

    methods (Test)
        function testAskHumanFiresEvent(testCase)
            fired = false;
            addlistener(testCase.AgentLoop, 'UserInputRequired', @(~,~) assignin('caller', 'fired', true));

            args = struct('question', 'What is 2+2?');
            res = AskHuman(testCase.AgentLoop, args);

            testCase.verifyTrue(fired);
            testCase.verifyTrue(contains(res, 'User answered question'));
        end

        function testMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() AskHuman(testCase.AgentLoop, args), 'matl_agent:AskHuman:missingArgs');
        end
    end
end
