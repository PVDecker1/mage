function result = ListDir(~, args)
    % ListDir Lists the contents of a directory.
    %   args should contain 'dir' (or 'path' for backward compatibility).

    if isfield(args, 'dir')
        dirPath = args.dir;
    elseif isfield(args, 'path')
        dirPath = args.path;
    else
        dirPath = pwd;
    end

    if ~isfolder(dirPath)
        error('mage:ListDir:notDir', 'Directory not found: %s', dirPath);
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
