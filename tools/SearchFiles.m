 function result = SearchFiles(~, args)
    % SearchFiles Search for a regex pattern across files.
    %   args must contain 'pattern', and optionally 'dir'.

    if ~isfield(args, 'pattern')
        error('mage:SearchFiles:missingArgs', 'Missing pattern argument');
    end

    pattern = args.pattern;
    if isfield(args, 'dir')
        searchDir = args.dir;
    else
        searchDir = '.';
    end

    if ~isfolder(searchDir)
        result = sprintf('Error: Directory not found: %s', searchDir);
        return;
    end

    try
        % Get all files recursively
        allFiles = dir(fullfile(searchDir, '**', '*'));
        allFiles = allFiles(~[allFiles.isdir]);
        
        foundFiles = {};
        for i = 1:length(allFiles)
            file = fullfile(allFiles(i).folder, allFiles(i).name);
            [~, ~, ext] = fileparts(file);
            
            % Only search text-like files
            if ismember(ext, {'.m', '.txt', '.md', '.json', '.xml', '.jsonl'})
                try
                    fid = fopen(file, 'r');
                    if fid == -1, continue; end

                    lineNum = 0;
                    fileMatches = {};
                    while ~feof(fid)
                        line = fgetl(fid);
                        lineNum = lineNum + 1;
                        if ~ischar(line), continue; end

                        if ~isempty(regexpi(line, pattern, 'once'))
                            fileMatches{end+1} = sprintf('%d: %s', lineNum, line); %#ok<AGROW>
                        end
                    end
                    fclose(fid);

                    if ~isempty(fileMatches)
                        foundFiles{end+1} = sprintf('--- %s ---\n%s', file, strjoin(fileMatches, newline)); %#ok<AGROW>
                    end
                catch
                    % Ignore read errors on individual files
                end
            end
        end

        if isempty(foundFiles)
            result = sprintf('No files found matching pattern: %s', pattern);
        else
            result = sprintf('Found pattern "%s" in:\n\n%s', pattern, strjoin(foundFiles, [newline, newline]));
        end
    catch ME
        result = sprintf('Failed to search files: %s', ME.message);
    end
end
