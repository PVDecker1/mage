classdef TestSkillRegistry < matlab.unittest.TestCase
    % TestSkillRegistry Tests for skills/SkillRegistry.m

    properties
        TempDir
        SkillName
    end

    methods (TestMethodSetup)
        function createMockEnv(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);

            % Create two skills
            testCase.SkillName = 'my_test_skill';
            skillDir = fullfile(testCase.TempDir, testCase.SkillName);
            mkdir(skillDir);

            skillFile = fullfile(skillDir, 'SKILL.md');
            fid = fopen(skillFile, 'w');
            fprintf(fid, 'This is a mock skill instruction.');
            fclose(fid);

            % Second empty/broken skill (no file)
            skillDir2 = fullfile(testCase.TempDir, 'broken_skill');
            mkdir(skillDir2);
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
        function testConstructorAndDiscovery(testCase)
            cfg = struct();
            registry = SkillRegistry(cfg);

            % Force path to temp env and clear global path for isolation
            registry.SkillPath = testCase.TempDir;
            registry.GlobalPath = 'non_existent_folder_xyz';
            registry.Available = containers.Map('KeyType', 'char', 'ValueType', 'char');
            registry.discoverSkills();

            testCase.verifyTrue(isKey(registry.Available, testCase.SkillName));
            testCase.verifyFalse(isKey(registry.Available, 'broken_skill'));

            list = registry.listSkills();
            testCase.verifyEqual(length(list), 1);
            testCase.verifyEqual(list{1}, testCase.SkillName);
        end

        function testLoadSkillSuccess(testCase)
            cfg = struct();
            registry = SkillRegistry(cfg);
            registry.SkillPath = testCase.TempDir;
            registry.GlobalPath = 'non_existent_folder_xyz';
            registry.Available = containers.Map('KeyType', 'char', 'ValueType', 'char');
            registry.discoverSkills();

            content = registry.loadSkill(testCase.SkillName);
            testCase.verifyEqual(content, 'This is a mock skill instruction.');
        end

        function testLoadSkillNotFound(testCase)
            cfg = struct();
            registry = SkillRegistry(cfg);

            content = registry.loadSkill('nonexistent');
            testCase.verifyEmpty(content);
        end
    end
end
