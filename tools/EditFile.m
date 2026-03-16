function result = EditFile(~, args)
    % EditFile Patches a file by replacing old_str with new_str.
    %   args must contain 'filepath', 'old_str', and 'new_str'.

    if ~isfield(args, 'filepath') || ~isfield(args, 'old_str') || ~isfield(args, 'new_str')
        error('matl_agent:EditFile:missingArgs', 'Missing filepath, old_str, or new_str arguments');
    end

    filepath = args.filepath;

    try
        content = fileread(filepath);
        if contains(content, args.old_str)
            content = strrep(content, args.old_str, args.new_str);
            fid = fopen(filepath, 'w');
            if fid == -1
                error('matl_agent:EditFile:openFailed', 'Could not open file for writing.');
            end
            fprintf(fid, '%s', content);
            fclose(fid);
            result = sprintf('Successfully edited %s.', filepath);
        else
            result = sprintf('old_str not found in %s.', filepath);
        end
    catch ME
        result = sprintf('Failed to edit %s: %s', filepath, ME.message);
    end
end
