% Check for outlier average microvoltage
% Some of our datasets may have had a problem with grounding and
% referencing. This script will load all of the datasets from a specified
% directory, do minimal pre-processing, and calculate average microvoltage
% from EEG.data
%
% Written by Noor Tasnim on 7.30.2025

% Import EEGLAB functions
eeglab
close
clear

% Set directory of files
filepath = '../data/combined_datasets/';
datasets = dir([filepath '*.set']);
datasets_length = length(datasets);

% Preallocate table with correct types
dataset_names = cell(datasets_length, 1);
uV_means = NaN(datasets_length, 1);          

% Activate Parallel Processing
if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

% Use parfor for parallel processing
parfor dataset_idx = 1:datasets_length
    try
        % Load dataset
        EEG = pop_loadset(datasets(dataset_idx).name, datasets(dataset_idx).folder);
        if contains(filepath, 'combined_datasets')
            subject_id = datasets(dataset_idx).name(1:10);
        else
            subject_id = datasets(dataset_idx).name(1:7);
        end

        % Remove ACC channels - check if channels exist first
        EEG = pop_select(EEG, 'nochannel', {'x_dir','y_dir','z_dir'});
        
        % Filter the dataset - only if not already filtered
        % (Add check for existing filter if applicable)
        EEG = pop_eegfiltnew(EEG, 'locutoff', 1, 'hicutoff', 55);
        
        % Calculate mean more efficiently
        dataset_names{dataset_idx} = subject_id;
        uV_means(dataset_idx) = mean(EEG.data(:));  % Vectorized mean
        
    catch ME
        warning('Error processing dataset %d: %s', dataset_idx, ME.message);
        dataset_names{dataset_idx} = datasets(dataset_idx).name(1:7);
        uV_means(dataset_idx) = NaN;
    end
end

% Create table after processing (more efficient)
data = table(dataset_names, uV_means, 'VariableNames', {'DatasetName', 'uV_mean'});

% Remove any failed processing entries
valid_idx = ~isnan(data.uV_mean);
data = data(valid_idx, :);

% Find outliers using built-in functions
outlier_idx = isoutlier(data.uV_mean, 'mean');

% Extract outliers
outlier_table = data(outlier_idx, :);

fprintf('Outliers found:\n');
disp(outlier_table);

%% Plot
% Plot histogram of uV_mean values
figure;
histogram(data.uV_mean, 20);
xlabel('Mean uV');
ylabel('Frequency');
title('Distribution of Mean uV Values');
grid on;