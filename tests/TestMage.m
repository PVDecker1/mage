classdef TestMage < matlab.unittest.TestCase
    % TestMage Tests for the main mage.m entry point.

    properties
        OriginalDir
        TempDir
    end

    methods (TestMethodSetup)
        function createSandbox(testCase)
            testCase.OriginalDir = pwd;
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);

            % Navigate to the temp directory so `mage()` logic
            % operates in an isolated environment (like .agent/ creation)
            cd(testCase.TempDir);
        end
    end

    methods (TestMethodTeardown)
        function cleanupSandbox(testCase)
            % Restore path and delete temp dir
            cd(testCase.OriginalDir);

            if isfolder(testCase.TempDir)
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)
        function testAgentInitializationSuccess(testCase)
            % Call mage with output argument so it doesn't call run()
            % and block the test execution

            agent = mage();

            % Verify that all components have been instantiated
            testCase.verifyClass(agent, 'AgentLoop');
            testCase.verifyClass(agent.Context, 'ContextManager');
            testCase.verifyClass(agent.Client, 'LLMClient');
            testCase.verifyClass(agent.Tools, 'ToolEngine');
            testCase.verifyClass(agent.Skills, 'SkillRegistry');

            % Verify the .agent directory was created automatically
            testCase.verifyTrue(isfolder(fullfile(testCase.TempDir, '.agent')));
        end

        function testAgentReadsConfigIfPresent(testCase)
            % Create mock .agent directory and config.json
            agentFolder = fullfile(testCase.TempDir, '.agent');
            mkdir(agentFolder);
            cfgPath = fullfile(agentFolder, 'config.json');

            fid = fopen(cfgPath, 'w');
            fprintf(fid, '{"model": "test-model-xyz", "max_tokens": 1234, "endpoint": "http://localhost"}');
            fclose(fid);

            agent = mage();

            % Verify config was loaded
            testCase.verifyEqual(agent.Config.model, 'test-model-xyz');
            testCase.verifyEqual(agent.Config.max_tokens, 1234);
            testCase.verifyEqual(agent.Client.Model, 'test-model-xyz');
        end

        function testAgentReadsAgentMdIfPresent(testCase)
            % AGENTS.md
            mdFile = fullfile(testCase.TempDir, 'AGENTS.md');
            fid = fopen(mdFile, 'w');
            fprintf(fid, 'Mock AGENT rules here.');
            fclose(fid);


            agent = mage();

            % Verify context manager pushed T1 config
            testCase.verifyNotEmpty(agent.Context.T1_Config);
            testCase.verifyEqual(agent.Context.T1_Config{1}.role, 'system');
            testCase.verifyTrue(contains(agent.Context.T1_Config{1}.content, 'Mock AGENT rules here.'));
        end
    end
end
