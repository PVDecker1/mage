function result = SearchDocs(~, args)
    % SearchDocs Fetches built-in MATLAB documentation using `help` or `docsearch`.
    %   args must contain 'query'.

    if ~isfield(args, 'query')
        error('mage:SearchDocs:missingArgs', 'Missing query argument');
    end

    query = args.query;

    try
        docText = evalc(sprintf('help %s', query));
        if isempty(docText) || contains(docText, 'not found')
            result = sprintf('No documentation found for `%s`.', query);
        else
            result = sprintf('Documentation for `%s`:\n%s', query, docText);
        end
    catch ME
        result = sprintf('Failed to search docs for `%s`: %s', query, ME.message);
    end
end
