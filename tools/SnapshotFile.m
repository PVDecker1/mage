function SnapshotFile(filepath)
    % SnapshotFile Creates a backup of a file in .agent/snapshots/.
    %   Used before any write/edit operation.

    if ~isfile(filepath)
        return; % Nothing to snapshot
    end

    agentFolder = fullfile(pwd, '.agent');
    snapshotFolder = fullfile(agentFolder, 'snapshots');
    
    if ~isfolder(snapshotFolder)
        mkdir(snapshotFolder);
    end

    [~, name, ext] = fileparts(filepath);
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    snapshotName = sprintf('%s_%s%s', name, timestamp, ext);
    snapshotPath = fullfile(snapshotFolder, snapshotName);

    try
        copyfile(filepath, snapshotPath);
    catch
        % Fail silently if snapshot fails, don't block the main tool
    end
end
