classdef TestCmdWindowAdapter < matlab.unittest.TestCase
    % TestCmdWindowAdapter Tests for io/CmdWindowAdapter.m

    properties
        AgentLoop % mock agent to emit events
    end

    methods (TestMethodSetup)
        function createAgentLoop(testCase)
            testCase.AgentLoop = AgentLoop();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            adapter = CmdWindowAdapter(testCase.AgentLoop);

            % Assert it has listeners attached
            testCase.verifyNotEmpty(adapter.Listeners);
            testCase.verifyEqual(length(adapter.Listeners), 6); % 6 events subscribed to
        end

        function testConstructorThrowsWithoutAgent(testCase)
            testCase.verifyError(@() CmdWindowAdapter(), 'matl_agent:CmdWindowAdapter:missingAgent');
        end

        function testEventsTriggerHandlers(testCase)
            % Use evalc to catch print statements from the adapter
            adapter = CmdWindowAdapter(testCase.AgentLoop);

            % Test ResponseReceived
            evtData = AgentEventData(struct('text', 'Hello User'));
            output = evalc('notify(testCase.AgentLoop, "ResponseReceived", evtData)');
            testCase.verifyTrue(contains(output, 'Hello User'));

            % Test ToolCallStarted
            evtData = AgentEventData(struct('name', 'test_tool'));
            output = evalc('notify(testCase.AgentLoop, "ToolCallStarted", evtData)');
            testCase.verifyTrue(contains(output, 'Agent is calling tool: test_tool'));

            % Test ContextCompacted
            output = evalc('notify(testCase.AgentLoop, "ContextCompacted", AgentEventData())');
            testCase.verifyTrue(contains(output, 'Context auto-compacted'));

            % Test AgentError
            evtData = AgentEventData(struct('message', 'A bad error'));
            output = evalc('notify(testCase.AgentLoop, "AgentError", evtData)');
            testCase.verifyTrue(contains(output, 'Error: A bad error'));
        end
    end
end
