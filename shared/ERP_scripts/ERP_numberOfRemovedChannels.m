% CALCULATE NUMBER OF REMOVED CHANNELS FOR ERP
% This script will load up the latest .mat file that documented
% the number of EEG electrodes that were removed/interpolated
% from all datasets so that we can report them accordingly in our
% methods section
%
% Written by Noor Tasnim on October 16, 2025

%% Load .mat file
% this will load the cell array `removed_channels_data`
load '/Users/noor/Library/CloudStorage/GoogleDrive-ntasnim@vt.edu/Shared drives/Embodied Brain Lab/Exergame and ADHD (IRB 23-811)/! ERP'/extrachannels2interp_ICAtuning_v2.mat

%% Modify Cell Arrays
% Task 1: Add lengths to column 5
num_rows = size(removed_channels_data, 1);
for i = 1:num_rows
    removed_channels_data{i, 5} = length(removed_channels_data{i, 4});
end

% Task 2: Filter for 's1' rows
s1_mask = strcmp(removed_channels_data(:, 2), 's1');
session1_only = removed_channels_data(s1_mask, :);

%% Calculate Mean and Standard Deviation
% For original array
col5_values = cell2mat(removed_channels_data(:, 5));
mean_original = mean(col5_values);
std_original = std(col5_values);
min_original = min(col5_values);
max_original = max(col5_values);

% For filtered array
col5_values_filtered = cell2mat(session1_only(:, 5));
mean_filtered = mean(col5_values_filtered);
std_filtered = std(col5_values_filtered);
min_filtered = min(col5_values_filtered);
max_filtered = max(col5_values_filtered);

% Display results
fprintf('Sessions 1 AND 2 - Mean: %.2f, Std: %.2f, Min: %d, Max: %d\n', ...
    mean_original, std_original, min_original, max_original);
fprintf('Session 1 ONLY - Mean: %.2f, Std: %.2f, Min: %d, Max: %d\n', ...
    mean_filtered, std_filtered, min_filtered, max_filtered);