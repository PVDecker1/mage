function result = ListDir(~, args)
    % ListDir Lists the contents of a directory.
    %   args must contain 'path'.

    if ~isfield(args, 'path')
        args.path = pwd;
    end

    dirPath = args.path;

    if ~isfolder(dirPath)
        error('matl_agent:ListDir:notDir', 'Directory not found: %s', dirPath);
    end

    try
        listing = dir(dirPath);
        names = {listing.name};

        % Filter out . and ..
        validIdx = ~ismember(names, {'.', '..'});
        listing = listing(validIdx);

        resStr = sprintf('Contents of %s:\n', dirPath);
        for i = 1:length(listing)
            if listing(i).isdir
                resStr = sprintf('%s%s/\n', resStr, listing(i).name);
            else
                resStr = sprintf('%s%s\n', resStr, listing(i).name);
            end
        end
        result = resStr;
    catch ME
        result = sprintf('Failed to list %s: %s', dirPath, ME.message);
    end
end
