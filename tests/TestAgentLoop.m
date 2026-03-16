classdef TestAgentLoop < matlab.unittest.TestCase
    % TestAgentLoop Tests for AgentLoop handle class.

    methods (Test)
        function testInstantiation(testCase)
            agent = AgentLoop();
            testCase.verifyFalse(agent.IsRunning);
            testCase.verifyEqual(agent.Mode, 'code');
        end

        function testSetMode(testCase)
            agent = AgentLoop();
            agent.setMode('architect');
            testCase.verifyEqual(agent.Mode, 'architect');
        end

        function testRunFiresEventAndExits(testCase)
            % Ensure the loop breaks immediately upon asking for user input
            % to avoid an infinite loop in the test runner.

            agent = AgentLoop();

            % Mock listener to catch the event and explicitly kill the loop
            fired = false;
            addlistener(agent, 'UserInputRequired', @(~,~) setAndExit());

            function setAndExit()
                fired = true;
                agent.IsRunning = false; % Break loop
            end

            agent.run();

            testCase.verifyTrue(fired);
            testCase.verifyFalse(agent.IsRunning);
        end
    end
end
