function result = AskHuman(agent, args)
    % AskHuman Asks the user a question directly during tool execution.
    %   args must contain 'question'.

    if ~isfield(args, 'question')
        error('mage:AskHuman:missingArgs', 'Missing question argument');
    end

    question = args.question;

    try
        % Fire an event to the UI adapter requesting input.
        % The listener must somehow supply an answer (e.g. blocking input or setting a variable)

        evtData = struct('prompt', [question, ' '], 'input', '');
        evt = AgentEventData(evtData);
        notify(agent, 'UserInputRequired', evt);

        % Retrieve response from the event data (filled by adapter)
        if ~isempty(evt.Response)
            result = char(evt.Response);
        else
            result = 'No response provided by user.';
        end
    catch ME
        result = sprintf('Failed to ask user "%s": %s', question, ME.message);
    end
end
