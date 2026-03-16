classdef TestAgentEventData < matlab.unittest.TestCase
    % TestAgentEventData Tests for AgentEventData class.

    methods (Test)
        function testEmptyConstructor(testCase)
            evt = AgentEventData();
            testCase.verifyTrue(isstruct(evt.Data));
            testCase.verifyEmpty(fieldnames(evt.Data));
        end

        function testStructConstructor(testCase)
            s = struct('message', 'Hello world');
            evt = AgentEventData(s);
            testCase.verifyEqual(evt.Data.message, 'Hello world');
        end
    end
end
