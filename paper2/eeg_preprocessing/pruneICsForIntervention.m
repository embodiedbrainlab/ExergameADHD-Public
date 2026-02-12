% PRUNING INDEPENDENT COMPONENTS FOR INTERVENTION - EXERGAME AND ADHD STUDY
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
% analysis later (ROI connect or if reviewers are unsatisfied with the 50%
% cutoff) 
%
% Written by Noor Tasnim on 09.12.2025

%% Import EEGLAB Functions
eeglab
close 
clear

%% Set Directories

input_dir = '..\data\preprocessed\session_2\intervention\postICA\';
fiftyPercent_output_dir = '..\data\preprocessed\session_2\intervention\50percentBrainIC\';
nintyPercent_output_dir = '..\data\preprocessed\session_2\intervention\Remove90PercentNoise\';

% Remaining ICs .txt file
fifty_brainIC_file = '../docs/INTERVENTION_remaining_ICs_after_50BrainCutoff.csv';
ninty_brainIC_file = '../docs/INTERVENTION_remaining_ICs_after_90NoiseCutoff.csv';

%% Extract files
intervention_files = dir([input_dir '*.set']);

%% Initialize Parallel Pool
if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

%% Pre-process for 50% Brain IC

% Preallocate Brain IC Document
num_files = length(intervention_files);
fiftybrainIC_data = cell(num_files, 3); % Final storage: id, orig_IC_weights, new_IC_weights

% Loop through each dataset
parfor fifty_idx = 1:num_files

    % Temporary storage for this iteration
    temp_row = cell(1, 3);

    % Define Dataset and Data Folder
    dataset = intervention_files(fifty_idx).name;
    datafolder = intervention_files(fifty_idx).folder;

    % Load Dataset
    EEG = pop_loadset(dataset, datafolder);

    % Extract Dataset Information
    temp_row{1} = dataset(1:7); % id
    temp_row{2} = size(EEG.icaweights, 1); % orig_IC_weights

    % Flag ICs with Brain % less than 50
    EEG = pop_icflag(EEG, [0 0.5; NaN NaN; NaN NaN; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);

    % Remove Flagged ICs
    EEG = pop_subcomp(EEG, [], 0);

    % New IC weights
    temp_row{3} = size(EEG.icaweights, 1); % new_IC_weights

    % Save Dataset Based on Session Number
    EEG = pop_saveset(EEG, 'filename', dataset, 'filepath', fiftyPercent_output_dir);

    % Assign to main array
    fiftybrainIC_data(fifty_idx, :) = temp_row;
end

% Convert to table and write to CSV
fiftybrainIC_table = cell2table(fiftybrainIC_data, 'VariableNames', {'ID', 'Original # of IC Weights', 'New # of IC Weights'});
writetable(fiftybrainIC_table, fifty_brainIC_file);

%% Pre-process for 90% Brain IC

% Preallocate Brain IC Document
nintybrainIC_data = cell(num_files, 3); % Final storage: id, orig_IC_weights, new_IC_weights

% Loop through each dataset
parfor ninty_idx = 1:num_files

    % Temporary storage for this iteration
    temp_row = cell(1, 3);

    % Define Dataset and Data Folder
    dataset = intervention_files(ninty_idx).name;
    datafolder = intervention_files(ninty_idx).folder;

    % Load Dataset
    EEG = pop_loadset(dataset, datafolder);

    % Extract Dataset Information
    temp_row{1} = dataset(1:7); % id
    temp_row{2} = size(EEG.icaweights, 1); % orig_IC_weights

    % Flag ICs with Noise %90+
    EEG = pop_icflag(EEG, [NaN NaN; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0.9 1]);

    % Remove Flagged ICs
    EEG = pop_subcomp(EEG, [], 0);

    % New IC weights
    temp_row{3} = size(EEG.icaweights, 1); % new_IC_weights

    % Save Dataset Based on Session Number
    EEG = pop_saveset(EEG, 'filename', dataset, 'filepath', nintyPercent_output_dir);

    % Assign to main array
    nintybrainIC_data(ninty_idx, :) = temp_row;
end

% Convert to table and write to CSV
nintybrainIC_table = cell2table(nintybrainIC_data, 'VariableNames', {'ID', 'Original # of IC Weights', 'New # of IC Weights'});
writetable(nintybrainIC_table, ninty_brainIC_file);
