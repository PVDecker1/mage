function result = WebFetch(~, args)
    % WebFetch Fetches content from a URL via HTTP GET.
    %   args must contain 'url'.

    if ~isfield(args, 'url')
        error('mage:WebFetch:missingArgs', 'Missing url argument');
    end

    url = args.url;

    try
        options = weboptions('Timeout', 30);
        content = webread(url, options);

        if isstruct(content) || iscell(content)
            % If it's JSON that got decoded, turn it back to a string for
            % the tool output
            content = jsonencode(content);
        end

        if ischar(content) || isstring(content)
            % Truncate if very long
            if length(content) > 10000
                content = [content(1:10000), sprintf('\n...[truncated]...')];
            end
            result = sprintf('Successfully fetched %s:\n%s', url, char(content));
        else
            result = sprintf('Successfully fetched %s but content type not string/json.', url);
        end

    catch ME
        result = sprintf('Failed to fetch %s: %s', url, ME.message);
    end
end
