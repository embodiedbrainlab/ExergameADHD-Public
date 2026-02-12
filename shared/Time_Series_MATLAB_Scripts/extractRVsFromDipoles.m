% PULLING RESIDUAL VALUES
% Because we are modelling our analysis methods after the Salminen et al.
% (2025) paper, another criteria we need to record is the amount of "brain"
% ICs that meet the 15% residual variance criteria.
%
% The Salminen paper excluded ICs that were less than 50% brain and had an
% r.v. of 15%+> If a dataset had less than 5 total ICs, it was excluded
% from analysis.
%
% At this point, we already have datasets that only contain 50% brain ICs.
% So we now need to count the amount of ICs that have an r.v. less than
% 0.15.
%
% Written by Noor Tasnim on 8.25.2025

%% Import EEGLAB Functions
eeglab
close
clear

%% Set Paths and collect files
session1_datasets_dir = '..\data\preprocessed\session_1\50percentBrainIC\';
session2_datasets_dir = '..\data\preprocessed\session_2\sedentary\50percentBrainIC\';
dipole_list = '..\docs\rv15dipoles_after_50BrainCutoff.csv';

session1_datasets = dir([session1_datasets_dir '*.set']);
session2_datasets = dir([session2_datasets_dir '*.set']);

datasets = [session1_datasets; session2_datasets];

%% Start parallel pool with 8 workers
if isempty(gcp('nocreate'))
    parpool('local', 8);
end

%% Preallocate
% id, session, ICs, Dipoles RV under 0.15
dipoles_rvs = cell(length(datasets), 4);

% Create temporary cell arrays for parfor (each column as separate variable)
temp_ids = cell(length(datasets), 1);
temp_sessions = cell(length(datasets), 1);
temp_ics = cell(length(datasets), 1);
temp_dipoles = cell(length(datasets), 1);

parfor i = 1:length(datasets)  % Fixed: should start from 1, not length(datasets)
    
    % Extract Dataset Characteristics
    filename = datasets(i).name;
    id = filename(1:7);  % Fixed: MATLAB uses 1-based indexing, not 0-based
    session = str2double(filename(10));

    % Load dataset
    EEG = pop_loadset(filename, session2_datasets_dir);

    % Pull number of ICs
    IC_n = size(EEG.icaweights, 1);

    % Total number of Dipoles with R.V. under 15%
    rv_values = [EEG.dipfit.model.rv];
    dipoles_under_015 = sum(rv_values < 0.15);

    % Add values to separate temporary arrays (parfor compatible)
    temp_ids{i} = id;
    temp_sessions{i} = session;
    temp_ics{i} = IC_n;
    temp_dipoles{i} = dipoles_under_015;
end

% Combine results into final array
dipoles_rvs(:,1) = temp_ids;
dipoles_rvs(:,2) = temp_sessions;
dipoles_rvs(:,3) = temp_ics;
dipoles_rvs(:,4) = temp_dipoles;

%% Export Cell Array
writecell(dipoles_rvs, dipole_list)