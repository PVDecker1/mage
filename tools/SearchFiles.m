function result = SearchFiles(~, args)
    % SearchFiles Searches for a pattern across files in a directory.
    %   args must contain 'pattern', and optionally 'dir'.

    if ~isfield(args, 'pattern')
        error('matl_agent:SearchFiles:missingArgs', 'Missing pattern argument');
    end

    pattern = args.pattern;
    if isfield(args, 'dir')
        searchDir = args.dir;
    else
        searchDir = pwd;
    end

    try
        % Basic implementation using recursive dir and regexpi
        allFiles = getAllFiles(searchDir);
        foundFiles = {};

        for i = 1:length(allFiles)
            file = allFiles{i};
            % Only search .m or text files for simplicity, skip mat/mex
            [~, ~, ext] = fileparts(file);
            if ismember(ext, {'.m', '.txt', '.md', '.json'})
                try
                    content = fileread(file);
                    if ~isempty(regexpi(content, pattern, 'once'))
                        foundFiles{end+1} = file; %#ok<AGROW>
                    end
                catch
                    % Ignore read errors on individual files
                end
            end
        end

        if isempty(foundFiles)
            result = sprintf('No files found matching pattern: %s', pattern);
        else
            result = sprintf('Found pattern "%s" in:\n%s', pattern, strjoin(foundFiles, newline));
        end
    catch ME
        result = sprintf('Failed to search files: %s', ME.message);
    end
end

function fileList = getAllFiles(dirName)
    dirData = dir(dirName);
    dirIndex = [dirData.isdir];
    fileList = {dirData(~dirIndex).name}';

    if ~isempty(fileList)
        fileList = fullfile(dirName, fileList);
    end

    subDirs = {dirData(dirIndex).name};
    validIndex = ~ismember(subDirs, {'.', '..', '.git', '.agent', 'codegen', 'slprj'});

    for i = find(validIndex)
        nextDir = fullfile(dirName, subDirs{i});
        fileList = [fileList; getAllFiles(nextDir)]; %#ok<AGROW>
    end
end
