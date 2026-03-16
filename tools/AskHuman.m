function result = AskHuman(agent, args)
    % AskHuman Asks the user a question directly during tool execution.
    %   args must contain 'question'.

    if ~isfield(args, 'question')
        error('matl_agent:AskHuman:missingArgs', 'Missing question argument');
    end

    question = args.question;

    try
        % Fire an event to the UI adapter requesting input.
        % The listener must somehow supply an answer (e.g. blocking input or setting a variable)

        evtData = struct('prompt', [question, ' '], 'input', '');
        notify(agent, 'UserInputRequired', AgentEventData(evtData));

        % In a real setup, input would be captured from the listener.
        % For simulation/scaffold, return a dummy string if not set.
        % Real UI adapters should mutate shared state or use drawnow/waitfor.
        result = sprintf('User answered question: (This is a mock answer for scaffolding)');
    catch ME
        result = sprintf('Failed to ask user "%s": %s', question, ME.message);
    end
end
