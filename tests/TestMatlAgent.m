classdef TestMatlAgent < matlab.unittest.TestCase
    % TestMatlAgent Tests for the main matl_agent.m entry point.

    properties
        OriginalDir
        TempDir
    end

    methods (TestMethodSetup)
        function createSandbox(testCase)
            testCase.OriginalDir = pwd;
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);

            % Navigate to the temp directory so `matl_agent()` logic
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
            % Call matl_agent with output argument so it doesn't call run()
            % and block the test execution

            agent = matl_agent();

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
            fprintf(fid, '{"model": "test-model-xyz", "max_tokens": 1234}');
            fclose(fid);

            agent = matl_agent();

            % Verify config was loaded
            testCase.verifyEqual(agent.Config.model, 'test-model-xyz');
            testCase.verifyEqual(agent.Config.max_tokens, 1234);
            testCase.verifyEqual(agent.Client.Model, 'test-model-xyz');
        end

        function testAgentReadsAgentMdIfPresent(testCase)
            % Create mock AGENT.md
            mdPath = fullfile(testCase.TempDir, 'AGENT.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, 'Mock AGENT rules here.');
            fclose(fid);

            agent = matl_agent();

            % Verify context manager pushed T1 config
            testCase.verifyNotEmpty(agent.Context.T1_Config);
            testCase.verifyEqual(agent.Context.T1_Config{1}.role, 'system');
            testCase.verifyEqual(agent.Context.T1_Config{1}.content, 'Mock AGENT rules here.');
        end
    end
end
