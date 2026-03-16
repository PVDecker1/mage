classdef TestLoadSkill < matlab.unittest.TestCase
    % TestLoadSkill Tests for tools/LoadSkill.m

    properties
        AgentLoop % Mock agent for dependencies
        TempDir
        SkillName
    end

    methods (TestMethodSetup)
        function createMockEnv(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);

            % Create a mock skill directory structure
            testCase.SkillName = 'my_test_skill';
            skillDir = fullfile(testCase.TempDir, testCase.SkillName);
            mkdir(skillDir);

            skillFile = fullfile(skillDir, 'SKILL.md');
            fid = fopen(skillFile, 'w');
            fprintf(fid, 'This is a mock skill instruction.');
            fclose(fid);

            % Mock registry and point its path to our tempdir
            cfg = struct();
            registry = SkillRegistry(cfg);
            registry.SkillPath = testCase.TempDir;
            registry.discoverSkills();

            testCase.AgentLoop = AgentLoop();
            testCase.AgentLoop.Skills = registry;
        end
    end

    methods (TestMethodTeardown)
        function cleanupMockEnv(testCase)
            if isfolder(testCase.TempDir)
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)
        function testLoadSkillSuccess(testCase)
            args = struct('skill_name', testCase.SkillName);
            res = LoadSkill(testCase.AgentLoop, args);

            testCase.verifyTrue(contains(res, 'Successfully loaded skill `my_test_skill`'));
            testCase.verifyTrue(contains(res, 'This is a mock skill instruction.'));
        end

        function testLoadSkillNotFound(testCase)
            args = struct('skill_name', 'fake_skill_xyz');
            res = LoadSkill(testCase.AgentLoop, args);

            testCase.verifyTrue(contains(res, 'not found or empty'));
        end

        function testMissingArgs(testCase)
            args = struct();
            testCase.verifyError(@() LoadSkill(testCase.AgentLoop, args), 'matl_agent:LoadSkill:missingArgs');
        end

        function testMissingRegistry(testCase)
            agent = AgentLoop(); % Missing Skills registry setup
            args = struct('skill_name', testCase.SkillName);

            res = LoadSkill(agent, args);
            testCase.verifyTrue(contains(res, 'SkillRegistry not initialized'));
        end
    end
end
