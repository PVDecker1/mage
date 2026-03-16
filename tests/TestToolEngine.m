classdef TestToolEngine < matlab.unittest.TestCase
    % TestToolEngine Tests for ToolEngine class.

    properties
        AgentLoop % mock agent for events
    end

    methods (TestMethodSetup)
        function createAgentLoop(testCase)
            testCase.AgentLoop = AgentLoop();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            engine = ToolEngine(testCase.AgentLoop);

            testCase.verifyTrue(isKey(engine.Handlers, 'read_file'));
            testCase.verifyTrue(isKey(engine.Handlers, 'matlab_eval'));
        end

        function testUnknownTool(testCase)
            engine = ToolEngine(testCase.AgentLoop);

            testCase.verifyError(@() engine.dispatch('bad_tool', '{}'), 'matl_agent:ToolEngine:unknownTool');
        end

        function testDispatchFiresEvents(testCase)
            engine = ToolEngine(testCase.AgentLoop);

            % Add custom dummy handler
            engine.Handlers('dummy') = @(~, args) sprintf('Result: %s', args.val);

            started = false;
            completed = false;

            addlistener(testCase.AgentLoop, 'ToolCallStarted', @(~,~) assignin('caller', 'started', true));
            addlistener(testCase.AgentLoop, 'ToolCallCompleted', @(~,~) assignin('caller', 'completed', true));

            res = engine.dispatch('dummy', '{"val": "ok"}');

            testCase.verifyEqual(res, 'Result: ok');
            testCase.verifyTrue(started);
            testCase.verifyTrue(completed);
        end
    end
end
