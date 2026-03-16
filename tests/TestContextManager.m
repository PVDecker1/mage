classdef TestContextManager < matlab.unittest.TestCase
    % TestContextManager Tests for ContextManager handle class.

    methods (Test)
        function testPushValidMessage(testCase)
            cm = ContextManager();
            msg = struct('role', 'user', 'content', 'Test message');
            cm.push(msg);

            testCase.verifyEqual(length(cm.T3_Conversation), 1);
            testCase.verifyEqual(cm.T3_Conversation{1}.role, 'user');
        end

        function testPushInvalidMessage(testCase)
            cm = ContextManager();
            msg = struct('wrong', 'data');

            testCase.verifyError(@() cm.push(msg), 'matl_agent:ContextManager:invalidFormat');
        end

        function testCompactionLogic(testCase)
            % Set tiny budget to force compaction quickly
            cfg.context_budget = 100;
            cfg.compact_threshold = 0.5;

            cm = ContextManager(cfg);

            % Each push checks compaction
            msg1 = struct('role', 'user', 'content', 'This is a test string to use some tokens.');
            cm.push(msg1);

            % Verify T3 still holds it (not enough chars for 50 tokens)
            testCase.verifyEqual(length(cm.T3_Conversation), 1);

            % Push large content
            msg2 = struct('role', 'assistant', 'content', repmat('A', 1, 300));
            cm.push(msg2);

            % Since tokens = round(300 / 4) = 75 > 50, it should have compacted
            testCase.verifyEmpty(cm.T3_Conversation);
            testCase.verifyNotEmpty(cm.T2_Session.ledger);
        end

        function testEstimateTokens(testCase)
            cm = ContextManager();

            % Push ~40 chars -> ~10 tokens
            msg = struct('role', 'user', 'content', repmat('x', 1, 40));
            cm.push(msg);

            tokens = cm.estimateTokens();
            testCase.verifyEqual(tokens, 10);
        end
    end
end
