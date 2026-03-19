function result = ReadFile(~, args)
    % ReadFile Reads the contents of a file and returns them as a string.
    %   args must contain 'filepath' (a string).

    if ~isfield(args, 'filepath')
        error('mage:ReadFile:missingArgs', 'Missing filepath argument');
    end

    filepath = args.filepath;

    if ~isfile(filepath)
        error('mage:ReadFile:fileNotFound', 'File not found: %s', filepath);
    end

    try
        content = fileread(filepath);
        result = sprintf('Successfully read %s:\n%s', filepath, content);
    catch ME
        result = sprintf('Failed to read %s: %s', filepath, ME.message);
    end
end
