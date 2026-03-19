classdef TestLLMClient < matlab.unittest.TestCase
    % TestLLMClient Tests for LLMClient handle class.

    methods (Test)
        function testInitialization(testCase)
            cfg = struct('endpoint', 'https://generativelanguage.googleapis.com/v1beta/openai/', ...
                         'model', 'gemini-1.5-flash', ...
                         'secrets', struct('api_key', 'test-key'));
            client = LLMClient(cfg);
            testCase.verifyEqual(client.Model, 'gemini-1.5-flash');
            testCase.verifyTrue(contains(client.BaseURL, 'generativelanguage'));
        end

        function testCustomConfig(testCase)
            cfg = struct('endpoint', 'http://localhost:11434/v1', ...
                         'model', 'qwen2.5');

            client = LLMClient(cfg);
            testCase.verifyEqual(client.Model, 'qwen2.5');
            testCase.verifyEqual(client.BaseURL, 'http://localhost:11434/v1');
        end

        function testChatCompletionThrowsIfNoKeyAndNotLocalhost(testCase)
            % Should fail since no API key and BaseURL defaults to Gemini
            cfg = struct('endpoint', 'https://generativelanguage.googleapis.com/v1beta/openai/', ...
                         'model', 'gemini-1.5-flash');
            % Clear env var to ensure it fails
            setenv('MAGE_API_KEY', '');
            
            testCase.verifyError(@() LLMClient(cfg), 'mage:LLMClient:missingKey');
        end

        function testChatCompletionSuccessLocalhost(testCase)
            % Since we can't reliably run webwrite to a local endpoint in tests
            % without a real server, we just test that the key validation allows it.
            cfg = struct('endpoint', 'http://localhost:11434/v1', ...
                         'model', 'qwen2.5');
            client = LLMClient(cfg);
            client.ApiKey = ''; % Ensure empty key to bypass auth error

            messages = {struct('role', 'user', 'content', 'hi')};

            % Assert it throws an requestFailed error (because nothing is listening on port 11434)
            % but NOT a missingKey error.
            try
                client.chatCompletion(messages);
                testCase.verifyFail('Should have thrown requestFailed error');
            catch ME
                testCase.verifyEqual(ME.identifier, 'mage:LLMClient:requestFailed');
            end
        end
    end
end
