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
            dummyAnswer = '42';
            addlistener(testCase.AgentLoop, 'UserInputRequired', @(~,evt) setResponse(evt, dummyAnswer));

            args = struct('question', 'What is the meaning of life?');
            res = AskHuman(testCase.AgentLoop, args);

            testCase.verifyEqual(res, dummyAnswer);
            
            function setResponse(evt, ans)
                evt.Response = ans;
            end
        end

        function testMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() AskHuman(testCase.AgentLoop, args), 'mage:AskHuman:missingArgs');
        end
    end
end
