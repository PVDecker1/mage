function result = WriteFile(~, args)
    % WriteFile Writes content to a file, replacing entirely.
    %   args must contain 'filepath' and 'content'.

    if ~isfield(args, 'filepath') || ~isfield(args, 'content')
        error('mage:WriteFile:missingArgs', 'Missing filepath or content arguments');
    end

    filepath = args.filepath;
    content = args.content;

    try
        % Create snapshot before overwriting
        SnapshotFile(filepath);

        fid = fopen(filepath, 'w');
        if fid == -1
            error('mage:WriteFile:openFailed', 'Could not open file for writing.');
        end
        fprintf(fid, '%s', content);
        fclose(fid);
        result = sprintf('Successfully wrote %s.', filepath);
    catch ME
        result = sprintf('Failed to write %s: %s', filepath, ME.message);
    end
end
