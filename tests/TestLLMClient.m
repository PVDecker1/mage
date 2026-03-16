classdef TestLLMClient < matlab.unittest.TestCase
    % TestLLMClient Tests for LLMClient handle class.

    methods (Test)
        function testInitialization(testCase)
            client = LLMClient();
            % Since env var might not be set in test environment, we just check
            % default fields.
            testCase.verifyEqual(client.Model, 'gemini-2.5-pro');
            testCase.verifyTrue(contains(client.BaseURL, 'generativelanguage'));
        end

        function testCustomConfig(testCase)
            cfg = struct();
            cfg.endpoint = 'http://localhost:11434/v1';
            cfg.model = 'qwen2.5';

            client = LLMClient(cfg);
            testCase.verifyEqual(client.Model, 'qwen2.5');
            testCase.verifyEqual(client.BaseURL, 'http://localhost:11434/v1');
        end

        function testChatCompletionThrowsIfNoKeyAndNotLocalhost(testCase)
            % Should fail since no API key and BaseURL defaults to Gemini
            client = LLMClient();
            client.ApiKey = ''; % Ensure empty

            messages = {struct('role', 'user', 'content', 'hi')};

            testCase.verifyError(@() client.chatCompletion(messages), 'matl_agent:LLMClient:missingKey');
        end

        function testChatCompletionSuccessLocalhost(testCase)
            % Since we can't reliably run webwrite to a local endpoint in tests
            % without a real server, we just test that the key validation allows it.
            % The actual webwrite will throw a connection refused error, which is expected.
            cfg = struct();
            cfg.endpoint = 'http://localhost:11434/v1';
            client = LLMClient(cfg);
            client.ApiKey = ''; % Ensure empty key to bypass auth error

            messages = {struct('role', 'user', 'content', 'hi')};

            % Assert it throws an HTTP error (because nothing is listening on port 11434)
            % but NOT a missingKey error.
            try
                client.chatCompletion(messages);
                testCase.verifyFail('Should have thrown HTTP error');
            catch ME
                testCase.verifyEqual(ME.identifier, 'matl_agent:LLMClient:httpError');
            end
        end
    end
end
