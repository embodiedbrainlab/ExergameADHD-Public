%% Split All EEG Datasets Script (Parallel Processing Version)
% This script splits all FULLY PRE-PROCESSED (including ICA pruning) 
% .set files from both session 1 and session 2 using parallel processing

%% Import EEGLAB Functions
eeglab
close
clear

%% Initialize Parallel Pool
if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

%% Session 1 Processing
fprintf('=== Processing Session 1 Datasets ===\n');

% Define paths for session 1
session1_input_dir = '../data/preprocessed/session_1/50percentBrainIC/';
session1_output_dir = '../data/preprocessed/session_1/split/';
task_order_csv = '../docs/exergame_eeg_task_order.csv';

% Create output directory if it doesn't exist
if ~exist(session1_output_dir, 'dir')
    mkdir(session1_output_dir);
    fprintf('Created output directory: %s\n', session1_output_dir);
end

% Get all .set files in session 1 directory
session1_files = dir(fullfile(session1_input_dir, '*.set'));

fprintf('Found %d .set files in session 1 directory\n', length(session1_files));

% Process each session 1 file
parfor i = 1:length(session1_files)
    input_filepath = fullfile(session1_files(i).folder, session1_files(i).name);
    % add if clause for exgm164_s1 and exgm169_s1
    fprintf('\n--- Processing Session 1 file: %s ---\n', session1_files(i).name);
    
    try
        split_preprocessed_eeg_datasets(input_filepath, session1_output_dir, task_order_csv);
        fprintf('Successfully processed: %s\n', session1_files(i).name);
    catch ME
        fprintf('ERROR processing %s: %s\n', session1_files(i).name, ME.message);
        continue; % Continue with next file
    end
end

fprintf('\n=== Session 1 Processing Complete ===\n');

%% Session 2 Processing
fprintf('\n=== Processing Session 2 Datasets ===\n');

% Define paths for session 2
session2_input_dir = '../data/preprocessed/session_2/sedentary/50percentBrainIC/';
session2_output_dir = '../data/preprocessed/session_2/sedentary/split/';

% Create output directory if it doesn't exist
if ~exist(session2_output_dir, 'dir')
    mkdir(session2_output_dir);
    fprintf('Created output directory: %s\n', session2_output_dir);
end

% Get all .set files in session 2 directory
session2_files = dir(fullfile(session2_input_dir, '*.set'));

fprintf('Found %d .set files in session 2 directory\n', length(session2_files));

% Process each session 2 file
parfor i = 1:length(session2_files)
    input_filepath = fullfile(session2_files(i).folder, session2_files(i).name);
    fprintf('\n--- Processing Session 2 file: %s ---\n',session2_files(i).name);
    try
        split_preprocessed_eeg_datasets(input_filepath, session2_output_dir, task_order_csv);
        fprintf('Successfully processed: %s\n', session2_files(i).name);
    catch ME
        fprintf('ERROR processing %s: %s\n', session2_files(i).name, ME.message);
        continue; % Continue with next file
    end
end

fprintf('\n=== Session 2 Processing Complete ===\n');

%% Summary
fprintf('\n=== Processing Summary ===\n');
fprintf('Session 1: Processed %d files\n', length(session1_files));
fprintf('Session 2: Processed %d files\n', length(session2_files));
fprintf('Total files processed: %d\n', length(session1_files) + length(session2_files));
fprintf('\nCheck the output directories and log files for any errors.\n');