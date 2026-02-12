function organize_erp_datasets(base_directory)
% ORGANIZE_ERP_DATASETS Organizes processed ERP datasets into stimulant and
% non-stimulant folders.
%
% Usage: organize_erp_datasets(base_directory)
%
% Input:
%   base_directory - Path to the directory containing the source folders
%                   (amphetamine, methylphenidate, none, other)
%
% The function will create 'stimulants' and 'non-stimulants' folders in the
% specified base directory and organize files according to medication type.
%
% Written by Noor Tasnim on September 23, 2025

% Validate input
if nargin < 1
    error('Please provide a base directory path');
end

if ~exist(base_directory, 'dir')
    error('Base directory does not exist: %s', base_directory);
end

% Define source and destination folders
source_folders = {'amphetamine', 'methylphenidate', 'none', 'other'};
stimulant_folder = fullfile(base_directory, 'stimulants');
non_stimulant_folder = fullfile(base_directory, 'non-stimulants');

fprintf('Processing directory: %s\n', base_directory);

% Create destination folders if they don't exist
if ~exist(stimulant_folder, 'dir')
    mkdir(stimulant_folder);
    fprintf('Created folder: %s\n', stimulant_folder);
end

if ~exist(non_stimulant_folder, 'dir')
    mkdir(non_stimulant_folder);
    fprintf('Created folder: %s\n', non_stimulant_folder);
end

% Copy files from amphetamine and methylphenidate folders to stimulants
for i = 1:2
    source_path = fullfile(base_directory, source_folders{i});
    if exist(source_path, 'dir')
        files = dir(fullfile(source_path, '*'));
        files = files(~[files.isdir]); % Remove directories from list
        
        fprintf('Processing %s folder (%d files)...\n', source_folders{i}, length(files));
        
        for j = 1:length(files)
            source_file = fullfile(source_path, files(j).name);
            dest_file = fullfile(stimulant_folder, files(j).name);
            copyfile(source_file, dest_file);
            fprintf('  Copied %s to stimulants\n', files(j).name);
        end
    else
        fprintf('Warning: Folder %s does not exist in %s\n', source_folders{i}, base_directory);
    end
end

% Copy files from none folder to non-stimulants
none_path = fullfile(base_directory, 'none');
if exist(none_path, 'dir')
    files = dir(fullfile(none_path, '*'));
    files = files(~[files.isdir]); % Remove directories from list
    
    fprintf('Processing none folder (%d files)...\n', length(files));
    
    for j = 1:length(files)
        source_file = fullfile(none_path, files(j).name);
        dest_file = fullfile(non_stimulant_folder, files(j).name);
        copyfile(source_file, dest_file);
        fprintf('  Copied %s to non-stimulants\n', files(j).name);
    end
else
    fprintf('Warning: Folder none does not exist in %s\n', base_directory);
end

% Handle files from other folder with specific conditions
other_path = fullfile(base_directory, 'other');
if exist(other_path, 'dir')
    files = dir(fullfile(other_path, '*'));
    files = files(~[files.isdir]); % Remove directories from list
    
    fprintf('Processing other folder (%d files)...\n', length(files));
    
    % Define IDs for stimulants and non-stimulants from "Other" Folder
    stimulant_patterns = {'exgm051', 'exgm164', 'exgm182'};
    non_stimulant_patterns = {'exgm108', 'exgm146', 'exgm169'};
    
    for j = 1:length(files)
        filename = files(j).name;
        source_file = fullfile(other_path, filename);
        
        % Check if file should go to stimulants folder
        is_stimulant = false;
        for k = 1:length(stimulant_patterns)
            if startsWith(filename, stimulant_patterns{k})
                dest_file = fullfile(stimulant_folder, filename);
                copyfile(source_file, dest_file);
                fprintf('  Copied %s to stimulants\n', filename);
                is_stimulant = true;
                break;
            end
        end
        
        % If not stimulant, check if it should go to non-stimulants folder
        if ~is_stimulant
            for k = 1:length(non_stimulant_patterns)
                if startsWith(filename, non_stimulant_patterns{k})
                    dest_file = fullfile(non_stimulant_folder, filename);
                    copyfile(source_file, dest_file);
                    fprintf('  Copied %s to non-stimulants\n', filename);
                    break;
                end
            end
        end
    end
else
    fprintf('Warning: Folder other does not exist in %s\n', base_directory);
end

fprintf('File organization complete for %s!\n\n', base_directory);

end