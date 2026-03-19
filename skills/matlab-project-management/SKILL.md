---
name: matlab-project-management
description: CRITICAL: Essential rules for programmatic project manipulation. Load this BEFORE creating/opening projects or adding files to avoid corrupting project metadata.
license: MIT (see LICENSE)
metadata:
  author: Austin Decker
  version: "1.0"
---

# MATLAB Project Management

## Must-Follow Rules

- **Use `currentProject` when a project is already open** — Use `openProject` only when loading a project from disk. Never call `matlab.project.createProject` on a folder that already contains a `.prj` file — it will error.
- **Call `reload` after structural changes** — After adding/removing files, moving files, or adding references, call `reload(proj)` before querying `proj.Files` or `proj.Dependencies`. Otherwise the object reflects stale state.
- **Use `matlab.project.rootProject` to check if a project is loaded** — `currentProject` throws if no project is open. Use `matlab.project.rootProject` for safe existence checks.
- **Never hardcode absolute paths** — Always build paths with `fullfile(proj.RootFolder, ...)` or relative strings. Absolute paths break when the project moves or is cloned.
- **Do not guess** — If the project location, folder structure, or desired label category is unclear, **ask**.

---

## Opening and Creating Projects

```matlab
% Get the currently open project
proj = currentProject;

% Open an existing project from disk
proj = openProject("path/to/project.prj");
proj = openProject("path/to/projectFolder");   % also works with folder path

% Check for startup issues after opening
issues = listStartupIssues(proj);
if ~isempty(issues)
    disp(issues);
end

% Create a new blank project
proj = matlab.project.createProject("path/to/newProjectFolder");
proj.Name = "My Project";
proj.Description = "A description of my project.";

% Safe check — does not throw if no project is open
rootProj = matlab.project.rootProject;
if ~isempty(rootProj)
    proj = currentProject;
end

% Close a project (runs shutdown scripts, checks for unsaved files)
close(proj);
issues = listShutdownIssues(proj);
```

---

## Managing Files and Folders

```matlab
% Add a single file (path relative to project root)
addFile(proj, "src/myFunction.m");

% Add a folder and all its children recursively
addFolderIncludingChildFiles(proj, "src");
addFolderIncludingChildFiles(proj, "tests");

% Remove a file from the project (does not delete from disk)
removeFile(proj, "src/oldFunction.m");

% Find a file by partial path — returns ProjectFile object
f = findFiles(proj, "src/myFunction.m", OutputFormat="ProjectFile");

% Inspect a file's properties
f.Path
f.Revision                  % Git SHA or SVN revision
f.SourceControlStatus       % Unmodified / Modified / Added / Deleted / etc.
f.Labels

% Iterate all project files
for i = 1:numel(proj.Files)
    disp(proj.Files(i).Path);
end
```

Always call `reload(proj)` after adding or removing files if you intend to immediately query `proj.Files`.

---

## Managing the Project Path

Folders added to the project path are automatically added to the MATLAB search path when the project opens.

```matlab
% Add a folder to the project path
addPath(proj, "src");
addPath(proj, proj.RootFolder);          % add root itself

% Add folder and all subfolders
addPath(proj, "src");                    % single folder only
% For subfolders, add each explicitly or use addFolderIncludingChildFiles first

% Remove a folder from the project path
removePath(proj, "src/legacy");

% Inspect current path folders
proj.ProjectPath                         % array of PathFolder objects
{proj.ProjectPath.Folder}'               % cell array of folder strings
```

---

## Project References

References allow one project to depend on another. Files in referenced projects are accessible when the parent project is open.

```matlab
% Create a referenced project
refFolder = fullfile(proj.RootFolder, "..", "SharedLibrary");
refProj = matlab.project.createProject(refFolder);
refProj.Name = "Shared Library";

addFolderIncludingChildFiles(refProj, "src");
addPath(refProj, refProj.RootFolder);
reload(refProj);

% Add the reference to the parent project
reload(proj);
addReference(proj, refProj);            % pass project object
% or by path:
addReference(proj, "path/to/SharedLibrary");

% Remove a reference
removeReference(proj, "path/to/SharedLibrary");

% Inspect references
proj.ProjectReferences                   % array of ProjectReference objects
```

---

## Source Control

```matlab
% Get all modified files (added, modified, deleted, conflicted, etc.)
modified = listModifiedFiles(proj);
for i = 1:numel(modified)
    fprintf('%s: %s\n', modified(i).SourceControlStatus, modified(i).Path);
end

% Refresh source control status before querying individual files
% (not needed before listModifiedFiles — it refreshes automatically)
refreshSourceControl(proj);

% Filter files by status
allFiles = proj.Files;
unmodified = allFiles(ismember( ...
    [allFiles.SourceControlStatus], ...
    matlab.sourcecontrol.Status.Unmodified));

% Check a single file's status
f = findFiles(proj, "src/myFunction.m", OutputFormat="ProjectFile");
f.SourceControlStatus
```

### SourceControlStatus Values

| Value | Meaning |
| :--- | :--- |
| `Unmodified` | No changes since last commit |
| `Modified` | Changed but not staged/committed |
| `Added` | New file, not yet committed |
| `Deleted` | Deleted from disk, tracked by source control |
| `Conflicted` | Merge conflict |
| `Unknown` | Status not yet resolved |

---

## Dependency Analysis

Dependencies are stored as a MATLAB `digraph` on `proj.Dependencies`. Run `updateDependencies` to refresh before querying.

```matlab
% Refresh the dependency graph
updateDependencies(proj);
g = proj.Dependencies;          % digraph object

% Files required by a specific file (downstream dependencies)
targetFile = which("src/myFunction.m");
requiredFiles = bfsearch(g, targetFile);

% Files impacted by a change to a specific file (upstream)
transposed = flipedge(g);
impactedFiles = bfsearch(transposed, targetFile);

% Top-level entry points (nothing depends on them)
entryPoints = g.Nodes.Name(indegree(g) == 0);

% Entry points that have dependencies (files with dependents)
entryPointsWithDeps = g.Nodes.Name(indegree(g) == 0 & outdegree(g) > 0);

% Orphaned files (no dependencies in either direction)
orphans = g.Nodes.Name(indegree(g) + outdegree(g) == 0);

% Topological order (bottom-up build order)
buildOrder = g.Nodes.Name(flip(toposort(g)));

% Summary stats
fprintf('Files: %d\n', numnodes(g));
fprintf('Dependencies: %d\n', numedges(g));
fprintf('Orphans: %d\n', sum(indegree(g) + outdegree(g) == 0));
fprintf('Avg dependencies per file: %.1f\n', mean(outdegree(g)));

% List required files for the whole project (all files needed to run)
required = listRequiredFiles(proj);

% List files impacted by current modifications
impacted = listImpactedFiles(proj);
```

---

## Labels

Labels classify and tag project files. All projects have a built-in `Classification` category with read-only labels (`Design`, `Test`, `Artifact`, `Derived`). Custom categories and labels are fully editable.

```matlab
% Create a custom label category
cat = createCategory(proj, "Status", "char");   % DataType: 'char', 'double', or 'none'

% Create a label in the category
category = findCategory(proj, "Status");
createLabel(category, "InReview");
createLabel(category, "Approved");

% Attach a label to a file
f = findFiles(proj, "src/myFunction.m", OutputFormat="ProjectFile");
addLabel(f, "Status", "InReview");

% Attach a label with data
addLabel(f, "Status", "Approved", "Reviewed by Alice on 2026-03-18");

% Read label data back
lbl = findLabel(f, "Status", "Approved");
lbl.Data

% Find all files with a given label
reviewFiles = findFiles(proj, Label="InReview");

% Remove a label from a file
removeLabel(f, "Status", "InReview");

% Remove an entire label category
removeCategory(proj, "Status");
```

### Built-in Classification Labels (Read-Only)

| Label | Auto-applied to |
| :--- | :--- |
| `Design` | `.m`, `.mlx`, `.mlapp`, `.slx`, `.mdl`, `.mat`, `.c`, `.h`, `.cpp` |
| `Test` | `matlab.unittest.TestCase` subclasses, `.mldatx` |
| `Artifact` | `.html`, `.pdf`, `.doc`, `.docx` |
| `Derived` | `.mex*`, `.dll`, `.so`, `.exe`, generated code |

---

## Shortcuts

Shortcuts are saved entry points for frequent tasks — launch files, run scripts, open apps.

```matlab
% Add a shortcut
addShortcut(proj, "src/myApp.mlapp",   Name="Launch App",   Group="Launch Points");
addShortcut(proj, "tests/runAll.m",    Name="Run All Tests", Group="Testing");

% Inspect shortcuts
proj.Shortcuts                          % array of Shortcut objects
shortcuts = proj.Shortcuts;
{shortcuts.Name}'
{shortcuts.File}'
{shortcuts.Group}'

% Run a shortcut by name
sc = proj.Shortcuts(strcmp({proj.Shortcuts.Name}, "Run All Tests"));
run(sc.File);

% Remove a shortcut
removeShortcut(proj, "tests/runAll.m");
```

---

## Startup and Shutdown Tasks

Startup files run automatically when the project opens. Shutdown files run when it closes.

```matlab
% Add startup and shutdown scripts
addStartupFile(proj,  "scripts/startup.m");
addShutdownFile(proj, "scripts/shutdown.m");

% Inspect registered files
proj.StartupFiles    % string array of paths
proj.ShutdownFiles   % string array of paths

% Remove a startup or shutdown file
removeStartupFile(proj,  "scripts/startup.m");
removeShutdownFile(proj, "scripts/shutdown.m");
```

The project startup folder (where MATLAB's working directory is set on open) defaults to the project root. Set it in Project Settings → Startup Folder, or read it via `proj.StartupFolder`.

---

## Exporting and Packaging

```matlab
% Export project to a zip archive (includes all project files)
export(proj, "MyProject_export.zip");

% Extract a previously exported project
matlab.project.extractProject("MyProject_export.zip", "path/to/destination");
```

---

## Complete Setup Pattern

Use this pattern when bootstrapping a new project from scratch in a script.

```matlab
function proj = setupProject(projectFolder, projectName)
% SETUPPROJECT  Creates and configures a MATLAB project programmatically.

    % Create project
    proj = matlab.project.createProject(projectFolder);
    proj.Name        = projectName;
    proj.Description = sprintf('%s — created %s', projectName, datestr(now, 'yyyy-mm-dd'));

    % Standard folder structure
    folders = {'src', 'tests', 'data', 'docs', 'scripts'};
    for i = 1:numel(folders)
        folder = fullfile(projectFolder, folders{i});
        if ~exist(folder, 'dir'), mkdir(folder); end
        addFolderIncludingChildFiles(proj, folders{i});
    end

    % Add src and tests to path
    addPath(proj, 'src');
    addPath(proj, 'tests');

    % Startup/shutdown
    addStartupFile(proj,  'scripts/startup.m');
    addShutdownFile(proj, 'scripts/shutdown.m');

    % Shortcuts
    addShortcut(proj, 'tests/runAll.m', Name='Run All Tests', Group='Testing');

    % Initial dependency analysis
    reload(proj);
    updateDependencies(proj);

    fprintf('Project "%s" created at %s\n', proj.Name, proj.RootFolder);
end
```

---

## Troubleshooting

**`currentProject` throws "No project is currently open"**
Use `matlab.project.rootProject` to check first, or wrap in `try/catch`. Only call `currentProject` when you know a project is loaded.

**`proj.Files` appears stale after `addFile` or `removeFile`**
Call `reload(proj)` before querying `proj.Files`. The object does not auto-refresh after mutations.

**`addReference` errors with "project already referenced"**
Check `proj.ProjectReferences` first. If the reference already exists, skip — do not attempt to add it again.

**`findFiles` returns empty even though the file exists on disk**
The file must be added to the project with `addFile` or `addFolderIncludingChildFiles` first. Files on disk but not added to the project are not tracked.

**`updateDependencies` is slow on first run**
Expected — the first analysis builds the full graph. Subsequent calls are incremental. For very large projects, schedule `updateDependencies` in a startup script so the graph is always current when the project opens.

**`listModifiedFiles` shows unexpected files**
Call `refreshSourceControl(proj)` first if the project was modified outside MATLAB (e.g. by a git pull in terminal). `listModifiedFiles` refreshes automatically but `proj.Files(i).SourceControlStatus` does not.