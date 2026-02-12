% RUN ERP MEASUREMENTS
% At this point, ERP datasets have been fully pre-processed, averaged,
% organized into folders based on whether they were taking stimulant
% medications, and low-pass filtered. The following script will go through
% select folders and conduct the following analyses for each component of
% interest:
%
% 1. Mean Amplitude - use UNFILTERED data
% 2. Peak Amplitude - use FILTERED data
% 3. Peak Latency - use FILTERED data
% 4. Fractional Area Latency (50%) - use UNFILTERED data
% 5. Fractional Peak Latency (Onset Latency) - use FILTERED data
%
% Measurements 1 and 4 can use unfiltered data. Measurements 2,3,5 should
% use filtered data because they are sensitive to high frequency noise.
%
% For each task, we will measure the following components:
%   1. Go/No-Go
%       a. P3b in Pz (ch. 13) in Go minus NoGo Related Difference Wave (Bin 9)
%       b. P3b in Cz (ch. 24) in Rare-Frequent Difference waves for Go and No/Go
%       (Bins 5 & 6)
%       c. Anterior N2 in Fz (ch. 2) in NoGo minus Go Related Difference
%       Wave (Bin 7)
%   2. Stroop
%       a. Anterior N2 in Fz (ch. 2) in Incongruent minus Control and
%       Congruent minus Control Difference Waves (Bins 4 and 5)
%       b. P3b in Pz (ch. 13) in Incongruent minus Control and
%       Congruent minus Control Difference Waves (Bins 4 and 5)
%   3. WCST
%       a. Event-related Negativity (ERN) in Fz (ch. 2) in Incorrect minus
%       Correct Difference Wave (Bin 3)
%       b. Feedback-related Negativity (FRN) in Fz (ch. 2) in Incorrect minus
%       Correct Difference Wave (Bin 3)
%
% Each component will have 5 measurements, meaning that this script will
% produce 35 .txt files (7 components x 5 measurements).
%
% The .txt outputs should then be stacked and final results should be
% appended to our main dataframe for statistical analysis.
%
% IMPORTANT NOTE: This script relies on the function `loadERPDatasets`,
% which uses relative paths. Assuming you cloned this repo and used the
% provided ERP scripts for your analysis/organization, it should work. But
% if you run into issues and you get blank sturctures for your datasets,
% you should debug the function.
%
% Written by Noor Tasnim on September 26, 2025

%% Gather Files and Directories for Each Analysis
% We will want filtered and unfiltered directories separate to run separate
% analyses

% Call the function to load all datasets
erpData = loadERPDatasets();

% Access your data using the structure fields
gonogo_unfilt = erpData.gonogo_unfilt;
gonogo_filt = erpData.gonogo_filt;
stroop_unfilt = erpData.stroop_unfilt;
stroop_filt = erpData.stroop_filt;
wcst_unfilt = erpData.wcst_unfilt;
wcst_filt = erpData.wcst_filt;

% Directory to save .txt results
results_dir = '../results/erp/measurements/';

%% Go/No-Go
% 1a. Go/No-Go P3b in Pz (ch. 13) in Go minus NoGo Related Difference Wave (Bin 9)
performERPMeasurements(gonogo_unfilt, [225 600], 9, 13, 'P3b', 'gonogo', results_dir);
performERPMeasurements(gonogo_filt, [225 600], 9, 13, 'P3b', 'gonogo', results_dir);

% 1b. Go/No-Go P3b in Cz (ch. 24) in Rare-Frequent Difference waves for Go and No/Go
% (Bins 5 & 6)
performERPMeasurements(gonogo_unfilt, [250 500], [5,6], 24, 'P3b', 'gonogo', results_dir);
performERPMeasurements(gonogo_filt, [250 500], [5,6], 24, 'P3b', 'gonogo', results_dir);

% c. Go/No-Go Anterior N2 in Fz (ch. 2) in NoGo minus Go Related Difference
% Wave (Bin 7)
performERPMeasurements(gonogo_unfilt, [160 275], 7, 2, 'N2', 'gonogo', results_dir);
performERPMeasurements(gonogo_filt, [160 275], 7, 2, 'N2', 'gonogo', results_dir);

%% Stroop
% 2a. Stroop Anterior N2 in Fz (ch. 2) in Incongruent minus Control and
% Congruent minus Control Difference Waves (Bins 4 and 5)
performERPMeasurements(stroop_unfilt, [160 275], [4,5], 2, 'N2', 'stroop', results_dir);
performERPMeasurements(stroop_filt, [160 275], [4,5], 2, 'N2', 'stroop', results_dir);

% 2b. Stroop P3b in Pz (ch. 13) in Incongruent minus Control and
% Congruent minus Control Difference Waves (Bins 4 and 5)
performERPMeasurements(stroop_unfilt, [225 425], [4,5], 13, 'P3b', 'stroop', results_dir);
performERPMeasurements(stroop_filt, [225 425], [4,5], 13, 'P3b', 'stroop', results_dir);

%% WCST
% 3a. WCST Event-related Negativity (ERN) in Fz (ch. 2) in Incorrect minus
% Correct Difference Wave (Bin 3)
performERPMeasurements(wcst_unfilt,[-10 110], 3, 2, 'ERN', 'wcst', results_dir);
performERPMeasurements(wcst_filt,[-10 110], 3, 2, 'ERN', 'wcst', results_dir);

% 3b. WCST Feedback-related Negativity (FRN) in Fz (ch. 2) in Incorrect minus
% Correct Difference Wave (Bin 3)
performERPMeasurements(wcst_unfilt,[250 365], 3, 2, 'FRN', 'wcst', results_dir);
performERPMeasurements(wcst_filt,[250 365], 3, 2, 'FRN', 'wcst', results_dir);
