% EXTRACT INTERVENTION DATASETS
% Intervention datasets were first pulled from their respective folders and
% converted to .set files for pre-processing and adjustments (if needed)
% according to the '! File Order and Renaming' spreadsheet.
%
% Note that there was a typo that was transferred to all datasets during
% data collection and that the intervention eeg files are saved under a
% folder called "intevention_eeg" rather than "intervention_eeg"
%
% Writted by Noor Tasnim on 7.29.2025

% Import EEGLAB functions
eeglab
close
clear

% Define paths
base_data_dir = 'C:\repos\ExergameADHD\data';
output_dir = 'C:\repos\ExergameADHD\data\intervention_datasets';

% Create output directory if it doesn't exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
    fprintf('Created output directory: %s\n', output_dir);
end

% Find all folders that begin with "exgm" in the base directory
fprintf('Searching for folders starting with "exgm" in: %s\n', base_data_dir);

% Get all items in the base directory
dir_contents = dir(fullfile(base_data_dir, 'exgm*'));

% Filter for directories only
exgm_folders = dir_contents([dir_contents.isdir]);

if isempty(exgm_folders)
    fprintf('No folders starting with "exgm" found in %s\n', base_data_dir);
    return;
end

fprintf('Found %d folders starting with "exgm"\n', length(exgm_folders));

% Initialize counters
total_processed = 0;
total_errors = 0;

% Process each exgm folder
for i = 1:length(exgm_folders)
    folder_name = exgm_folders(i).name;
    fprintf('\n--- Processing folder: %s ---\n', folder_name);
    
    % Construct path to EEG data
    eeg_data_path = fullfile(base_data_dir, folder_name, ...
                            'intervention_session', 'eeg', 'intevention_eeg');
    
    % Check if the EEG data path exists
    if ~exist(eeg_data_path, 'dir')
        fprintf('Warning: EEG data path does not exist: %s\n', eeg_data_path);
        fprintf('Skipping folder: %s\n', folder_name);
        continue;
    end
    
    % Find all .vhdr files in this directory
    vhdr_files = dir(fullfile(eeg_data_path, '*.vhdr'));
    
    if isempty(vhdr_files)
        fprintf('No .vhdr files found in: %s\n', eeg_data_path);
        continue;
    end
    
    fprintf('Found %d .vhdr file(s) in %s\n', length(vhdr_files), folder_name);
    
    % Process each .vhdr file
    for j = 1:length(vhdr_files)
        vhdr_filename = vhdr_files(j).name;
        vhdr_filepath = vhdr_files(j).folder;
        
        fprintf('  Processing: %s\n', vhdr_filename);
        
        try

            % Load the dataset
            EEG = pop_loadbv(vhdr_filepath, vhdr_filename);
            
            % Set dataset information
            dataset_name = erase(vhdr_filename,'.vhdr');
            subject_id = dataset_name(1:7);
            condition = 'intervention';
            EEG = pop_editset(EEG,'setname',dataset_name,'subject',subject_id,...
                'condition',condition);
            
            % Generate output filename
            output_filename = [dataset_name '.set'];
            
            % Save as EEGLAB .set file
            EEG = pop_saveset(EEG, 'filename', output_filename, 'filepath', output_dir);
            
            fprintf('    Successfully converted and saved: %s\n', output_filename);
            total_processed = total_processed + 1;
            
        catch ME
            fprintf('    Error processing %s: %s\n', vhdr_filename, ME.message);
            total_errors = total_errors + 1;
        end
    end
end

% Summary
fprintf('\n=== CONVERSION SUMMARY ===\n');
fprintf('Total files processed successfully: %d\n', total_processed);
fprintf('Total errors encountered: %d\n', total_errors);
fprintf('Output directory: %s\n', output_dir);

if total_processed > 0
    fprintf('\nConversion completed successfully!\n');
else
    fprintf('\nNo files were converted. Please check your directory structure and file paths.\n');
end
