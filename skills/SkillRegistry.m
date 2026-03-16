classdef SkillRegistry < handle
    % SkillRegistry Discovers, manages, and lazy-loads skills.
    %   Scans `.agent/skills/` for SKILL.md packs to be dynamically loaded.

    properties
        Config       % Reference to project config
        SkillPath    % Root path for skills (e.g. .agent/skills/)
        Available    % List/map of discovered skills
    end

    methods
        function obj = SkillRegistry(cfg)
            % SkillRegistry Constructor initializing discovery logic.

            if nargin < 1
                cfg = struct();
            end

            obj.Config = cfg;
            obj.SkillPath = fullfile(pwd, '.agent', 'skills');
            obj.Available = containers.Map('KeyType', 'char', 'ValueType', 'char');

            obj.discoverSkills();
        end

        function discoverSkills(obj)
            % discoverSkills Scans .agent/skills/ for subdirectories containing SKILL.md

            if ~isfolder(obj.SkillPath)
                return; % No skills folder exists
            end

            items = dir(obj.SkillPath);
            for i = 1:length(items)
                item = items(i);
                if item.isdir && ~ismember(item.name, {'.', '..'})
                    skillPackDir = fullfile(obj.SkillPath, item.name);
                    skillFile = fullfile(skillPackDir, 'SKILL.md');
                    if isfile(skillFile)
                        % Store path in map keyed by skill name
                        obj.Available(item.name) = skillFile;
                    end
                end
            end
        end

        function content = loadSkill(obj, skillName)
            % loadSkill Reads a skill's markdown file.
            %   Returns empty string if skill does not exist.

            content = '';

            if isKey(obj.Available, skillName)
                try
                    skillFile = obj.Available(skillName);
                    content = fileread(skillFile);
                catch ME
                    error('matl_agent:SkillRegistry:loadFailed', 'Failed to read skill %s: %s', skillName, ME.message);
                end
            end
        end

        function list = listSkills(obj)
            % listSkills Returns a cell array of discovered skill names.
            list = obj.Available.keys();
        end
    end
end
