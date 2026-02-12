% PRUNING INDEPENDENT COMPONENTS FOR EXERGAME AND ADHD STUDY
% The automated pre-processing pipeline conducted all steps of our
% pre-processing pipeline except for pruning "bad"/contaminated independent
% components.
% 
% So this script takes all the "postICA" datasets and removes ICs that were
% labeled by ICLabel as less than 50% likely to be a brain.
%
% This script will load each combined dataset and keep 50% brain ICs for
% further analysis. It will also create a .csv file that reports how many
% ICs were kept for analysis for each participant/session.
%
% NOTE: We also ran this using a 90% threshold for noise (not brain) and
% saved the datasets. We may use them for a different version of our
% analysis later.
%
% Written by Noor Tasnim on 8.22.2025

%% Import EEGLAB Functions
eeglab
close 
clear

%% Set Directories
% Session 1
session1_input_dir = '../data/preprocessed/session_1/automated_pipeline/';
session1_output_dir = '../data/preprocessed/session_1/50percentBrainIC/';
%session1_output_dir = '../data/preprocessed/session_1/Remove90PercentNoise/';

% Session 2
session2_input_dir = '../data/preprocessed/session_2/sedentary/automated_pipeline/';
session2_output_dir = '../data/preprocessed/session_2/sedentary/50percentBrainIC/';
%session2_output_dir = '../data/preprocessed/session_2/sedentary/Remove90PercentNoise/';

% Remaining ICs .txt file
brainIC_file = '../docs/remaining_ICs_after_50BrainCutoff.csv';
%brainIC_file = '../docs/remaining_ICs_after_90NoiseCutoff.csv';

%% Extract files
session1_files = dir([session1_input_dir '*.set']);
session2_files = dir([session2_input_dir '*.set']);
preprocessed_files = [session1_files; session2_files];

%% Preallocate Brain IC Document
num_files = length(preprocessed_files);
brainIC_data = cell(num_files, 4); % Final storage: id, session, orig_IC_weights, new_IC_weights

%% Pre-process

% Initialize Parallel Pool
if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

% Loop through each dataset
parfor dataset_idx = 1:num_files

    % Temporary storage for this iteration
    temp_row = cell(1, 4);

    % Define Dataset and Data Folder
    dataset = preprocessed_files(dataset_idx).name;
    datafolder = preprocessed_files(dataset_idx).folder;

    % Load Dataset
    EEG = pop_loadset(dataset, datafolder);

    % Extract Dataset Information
    temp_row{1} = dataset(1:7); % id
    temp_row{2} = str2double(dataset(10)); % session
    temp_row{3} = size(EEG.icaweights, 1); % orig_IC_weights

    % Flag ICs with Brain % less than 50
    EEG = pop_icflag(EEG, [0 0.5; NaN NaN; NaN NaN; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);

    % Flag ICs with Noise %90+
    %EEG = pop_icflag(EEG, [NaN NaN; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0.9 1]);

    % Remove Flagged ICs
    EEG = pop_subcomp(EEG, [], 0);

    % New IC weights
    temp_row{4} = size(EEG.icaweights, 1); % new_IC_weights

    % Save Dataset Based on Session Number
    if contains(datafolder, 'session_1')
        EEG = pop_saveset(EEG, 'filename', dataset, 'filepath', session1_output_dir);
    elseif contains(datafolder, 'session_2')
        EEG = pop_saveset(EEG, 'filename', dataset, 'filepath', session2_output_dir);
    end

    % Assign to main array
    brainIC_data(dataset_idx, :) = temp_row;
end

% Convert to table and write to CSV
brainIC_table = cell2table(brainIC_data, 'VariableNames', {'ID', 'Session', 'Original # of IC Weights', 'New # of IC Weights'});
writetable(brainIC_table, brainIC_file);
