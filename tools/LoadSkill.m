function result = LoadSkill(agent, args)
    % LoadSkill Dynamically loads a markdown skill pack.
    %   args must contain 'skill_name'.

    if ~isfield(args, 'skill_name')
        error('matl_agent:LoadSkill:missingArgs', 'Missing skill_name argument');
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
            result = sprintf('Skill `%s` not found or empty.', skillName);
        else
            result = sprintf('Successfully loaded skill `%s`:\n%s', skillName, loadedContent);
        end
    catch ME
        result = sprintf('Failed to load skill `%s`: %s', skillName, ME.message);
    end
end
