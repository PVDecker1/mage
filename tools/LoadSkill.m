function result = LoadSkill(agent, args)
    % LoadSkill Dynamically loads a markdown skill pack.
    %   args must contain 'skill_name'.

    if ~isfield(args, 'skill_name')
        error('mage:LoadSkill:missingArgs', 'Missing skill_name argument');
    end

    skillName = args.skill_name;

    if isempty(agent) || isempty(agent.Skills)
        result = sprintf('Failed to load skill `%s`: SkillRegistry not initialized.', skillName);
        return;
    end

    try
        registry = agent.Skills;
        % loadSkill returns true/false or the loaded content
        loadedContent = registry.loadSkill(skillName);

        if isempty(loadedContent)
            available = strjoin(registry.listSkills(), ', ');
            result = sprintf('Skill `%s` not found or empty. Available skills: %s', skillName, available);
        else
            result = sprintf('Successfully loaded skill `%s`:\n%s', skillName, loadedContent);
        end
    catch ME
        result = sprintf('Failed to load skill `%s`: %s', skillName, ME.message);
    end
end
