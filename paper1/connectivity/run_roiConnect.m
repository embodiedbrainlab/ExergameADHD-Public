% CALCULATING ROI CONNECT FOR SESSION 1 OF EXERGAME & ADHD STUDY
% This script will loop through all split datasets to generate connectivity
% matrices across all participants and experiences.
%
% Before running this script, make sure that calc_roiConnect.m is in your
% path (it stores the function you need to calculate the matrices).
%
% The end result will be two key variables:
%   1. A cell array of all connectivity matrices with the following columns
%   of information:
%       a. Participant ID
%       b. Session
%       c. Experience
%       d. Frequency Band
%       e. 68x68 Connectivity Matrix
%
%   2. A cell array of connectivity vectors to be used for a machine
%   learning classifier
%       a. Participant ID
%       b. Session
%       c. Experience
%       d. Frequency Band
%       e. 2278x1 Connectivity Vector
%
% IMPORTANT: Make sure you import the .csv file tracking the locations
% connecting to each other in the 2278 matrix.
%
% Also note that the calc_roiConnect function produces figures for each
% connectivity matrix. Images will be saved to the results folder in
% ROI_connect/.
%
% Written by Noor Tasnim on September 5, 2025

%% Import EEGLAB functions
eeglab
close
clear

%% Directories and Presets
data_dir = '../data/preprocessed/session_1/split_Remove90PercentNoise/';
results_dir = 'results/mat_files/';
roiConnect_atlaslabels_dir = '../docs/roiConnectAtlasWHOLE.csv';
long_atlasLabels_output = '../docs/roiConnectVectorLabels.csv';
frequency_bands = {'theta','alpha','low_beta','high_beta','gamma'};

%% Export .csv file of labels
% Load .csv file of ROIs
regions_table = readtable(roiConnect_atlaslabels_dir);
region_names = regions_table.roi;

% Create the connectivity labels in the same order as triu extracts them
num_regions = 68;
upper_tri_indices = triu(true(num_regions), 1);  % logical mask, excluding diagonal
[row_indices, col_indices] = find(upper_tri_indices);  % finds in column-wise order

% Initialize cell array for region pair labels
num_connections = length(row_indices);  % Should be 2278
connectivity_labels = cell(num_connections, 1);

% Create the labels
for i = 1:num_connections
    connectivity_labels{i} = sprintf('%s-%s', ...
        region_names{row_indices(i)}, region_names{col_indices(i)});
end

% Export labels
writecell(connectivity_labels,long_atlasLabels_output)

%% Calculate ROI Connect for All Datasets

% Grab files for calculation
datasets = dir([data_dir '*.set']);
total_iterations = length(datasets) * length(frequency_bands);
connectivity_matrices = cell(total_iterations, 5);
connectivity_vectors = cell(total_iterations, 5);
tic
% Loop through each dataset
row_idx = 1; % Initialize row counter
for dataset_idx = 1:length(datasets)
    % Dataset Information
    filename = datasets(dataset_idx).name;
    id = filename(1:7);
    session = filename(10);
    experience = filename(12:end-4);
    
    % Calculate Connectivity for Each Frequency Band
    for freq_idx = 1:length(frequency_bands)
        % Calculate Matrix
        [FCmatrixdata, connectivity_vector] = calc_roiConnect(filename,...
            data_dir, frequency_bands{freq_idx});
        
        % Fill in Connectivity Matrix Array
        connectivity_matrices{row_idx, 1} = id;
        connectivity_matrices{row_idx, 2} = session;
        connectivity_matrices{row_idx, 3} = experience;
        connectivity_matrices{row_idx, 4} = frequency_bands{freq_idx};
        connectivity_matrices{row_idx, 5} = FCmatrixdata;
        
        % Fill in Connectivity Vector Array
        connectivity_vectors{row_idx, 1} = id;
        connectivity_vectors{row_idx, 2} = session;
        connectivity_vectors{row_idx, 3} = experience;
        connectivity_vectors{row_idx, 4} = frequency_bands{freq_idx};
        connectivity_vectors{row_idx, 5} = connectivity_vector;
        
        row_idx = row_idx + 1; % Increment row counter
    end
end
toc
save connectivity_matrices.mat connectivity_matrices
save connectivity_vectors.mat connectivity_vectors