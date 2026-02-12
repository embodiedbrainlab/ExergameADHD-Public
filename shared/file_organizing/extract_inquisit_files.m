% Use relative paths based on current folder being "MATLAB scripts"
sourceDir = fullfile('..', 'data');
destDir = fullfile('..', 'InquisitForAnalysis');
baselineDest = fullfile(destDir, 'baseline');
interventionDest = fullfile(destDir, 'intervention');

% Create destination folders if they don't exist
if ~exist(baselineDest, 'dir')
    mkdir(baselineDest);
end
if ~exist(interventionDest, 'dir')
    mkdir(interventionDest);
end

% Get a list of all subject folders in "../data"
subjectFolders = dir(sourceDir);
subjectFolders = subjectFolders([subjectFolders.isdir] & ~startsWith({subjectFolders.name}, '.'));

% Loop through each subject folder
for i = 1:length(subjectFolders)
    subjectID = subjectFolders(i).name;
    subjectPath = fullfile(sourceDir, subjectID);

    % Define inquisit paths
    baselineInquisit = fullfile(subjectPath, 'baseline_session', 'inquisit');
    interventionInquisit = fullfile(subjectPath, 'intervention_session', 'inquisit');

    % Copy baseline files
    if exist(baselineInquisit, 'dir')
        files = dir(fullfile(baselineInquisit, '*'));
        files = files(~[files.isdir]);  % exclude folders
        for j = 1:length(files)
            copyfile(fullfile(baselineInquisit, files(j).name), ...
                     fullfile(baselineDest, files(j).name));
        end
    end

    % Copy intervention files
    if exist(interventionInquisit, 'dir')
        files = dir(fullfile(interventionInquisit, '*'));
        files = files(~[files.isdir]);  % exclude folders
        for j = 1:length(files)
            copyfile(fullfile(interventionInquisit, files(j).name), ...
                     fullfile(interventionDest, files(j).name));
        end
    end
end

disp('All files copied successfully using relative paths!');

%% Organize All Files

