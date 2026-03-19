classdef SkillRegistry < handle
    % SkillRegistry Discovers, manages, and lazy-loads skills.
    %   Scans `.agent/skills/` for SKILL.md packs to be dynamically loaded.

    properties
        Config       % Reference to project config
        SkillPath    % Root path for skills (e.g. .agent/skills/)
        GlobalPath   % Global skills directory (e.g. relative to mage.m)
        Available    % List/map of discovered skills
    end

    methods
        function obj = SkillRegistry(cfg)
            % SkillRegistry Constructor initializing discovery logic.

            if nargin < 1
                cfg = struct();
            end

            obj.Config = cfg;
            
            % Local skills in project .agent/skills/
            obj.SkillPath = fullfile(pwd, '.agent', 'skills');
            
            % Global skills relative to SkillRegistry location (../skills/)
            registryDir = fileparts(mfilename('fullpath'));
            obj.GlobalPath = fullfile(registryDir, '..', 'skills');
            
            obj.Available = containers.Map('KeyType', 'char', 'ValueType', 'char');

            obj.discoverSkills(obj.GlobalPath);
            obj.discoverSkills(obj.SkillPath);
        end

        function discoverSkills(obj, rootPath)
            % discoverSkills Scans a directory for subdirectories containing SKILL.md

            if nargin < 2
                % If no path provided, rediscover both global and local
                obj.discoverSkills(obj.GlobalPath);
                obj.discoverSkills(obj.SkillPath);
                return;
            end

            if ~isfolder(rootPath)
                return;
            end

            items = dir(rootPath);
            for i = 1:length(items)
                item = items(i);
                if item.isdir && ~ismember(item.name, {'.', '..'})
                    skillPackDir = fullfile(rootPath, item.name);
                    skillFile = fullfile(skillPackDir, 'SKILL.md');
                    if isfile(skillFile)
                        % Store path in map keyed by skill name
                        % Local project skills will overwrite global ones if name conflict
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
                    error('mage:SkillRegistry:loadFailed', 'Failed to read skill %s: %s', skillName, ME.message);
                end
            end
        end

        function list = listSkills(obj)
            % listSkills Returns a cell array of discovered skill names.
            list = obj.Available.keys();
        end

        function descMap = getSkillDescriptions(obj)
            % getSkillDescriptions Returns a containers.Map of skill names to descriptions.
            %   Attempts to extract the 'description' from YAML frontmatter or first lines.
            
            names = obj.listSkills();
            descMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
            
            for i = 1:length(names)
                name = names{i};
                path = obj.Available(name);
                desc = 'No description available.';
                
                try
                    fid = fopen(path, 'r');
                    if fid ~= -1
                        % Read first 20 lines to find description
                        for lineIdx = 1:20
                            line = fgetl(fid);
                            if ~ischar(line), break; end
                            
                            % Look for "description: ..."
                            match = regexp(line, 'description:\s*(.*)', 'tokens', 'once');
                            if ~isempty(match)
                                desc = strtrim(match{1});
                                % Remove surrounding quotes if present
                                if startsWith(desc, '"') && endsWith(desc, '"')
                                    desc = desc(2:end-1);
                                elseif startsWith(desc, "'") && endsWith(desc, "'")
                                    desc = desc(2:end-1);
                                end
                                break;
                            end
                        end
                        fclose(fid);
                    end
                catch
                    % Fallback to default
                end
                descMap(name) = desc;
            end
        end
    end
end
