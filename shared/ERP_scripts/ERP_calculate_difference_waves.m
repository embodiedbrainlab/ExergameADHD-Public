% CALCULATING DIFFERENCE WAVES OF .ERP SETS
% In addition to comparing peaks across distinct tasks, we may want to
% visualize the difference between these tasks and compare them across our
% experimental groups.
%
% The following script loads .erp sets for each task (wcst,stroop,gonogo)
% and calculates specified differences between specific bins.
%
% Datasets are then saved to new directories specified by session and task
% for further group analysis across tasks.
%
% Edit on 9/23/25: Added more difference waves to go/no-go and stroop.
%
% Edited by Noor Tasnim on September 23, 2025

%% Import EEGLAB functions
eeglab
close 
clear

%% Directory of Pre-processed .erp datasets
erp_dir = '../data/erp/9_average_erp/';

%% Set Directory for Saving files
base_path = '../data/erp/10_difference_waves';
% Create base directory if it doesn't exist
if ~exist(base_path, 'dir')
    mkdir(base_path);
end

%% Initiate Parallel Processing

if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

%% Process all WCST Datasets

% Gather datasets
wcst_files = dir([erp_dir '*wcst.erp']);

parfor wcst_idx = 1:length(wcst_files)
    % Load ERP Set
    ERP = pop_loaderp('filename', wcst_files(wcst_idx).name, 'filepath',erp_dir);
    % Add New Bin
    ERP = pop_binoperator(ERP, {'b3 = b1 - b2 label Correct minus Incorrect Difference Wave'});
    % Save to Difference Wave Folder
    base_name = erase(wcst_files(wcst_idx).name,'.erp');
    erp_name = [base_name '_diffwave'];
    filename = [erp_name '.erp'];
    ERP = pop_savemyerp(ERP,'erpname',erp_name,...
        'filename',filename, 'filepath',base_path);
end

%% Load All Stroop Sets

% Gather datasets
stroop_files = dir([erp_dir '*stroop.erp']);

parfor stroop_idx = 1:length(stroop_files)
    % Load ERP Set
    ERP = pop_loaderp('filename', stroop_files(stroop_idx).name, 'filepath',erp_dir);
    % Add New Bin
    ERP = pop_binoperator(ERP,{'b4 = b1 - b2 label Incongruent minus Control Difference Wave'});
    ERP = pop_binoperator(ERP,{'b5 = b3 - b2 label Congruent minus Control Difference Wave'});
    ERP = pop_binoperator(ERP,{'b6 = b1 - b3 label Incongruent minus Congruent Difference Wave'});
    % Save to Difference Wave Folder
    base_name = erase(stroop_files(stroop_idx).name,'.erp');
    erp_name = [base_name '_diffwave'];
    filename = [erp_name '.erp'];
    ERP = pop_savemyerp(ERP,'erpname',erp_name,...
        'filename',filename, 'filepath',base_path);
end

%% Load All Go/No-Go Sets

% Gather datasets
gonogo_files = dir([erp_dir '*gonogo.erp']);

parfor gonogo_idx = 1:length(gonogo_files)
    % Load ERP Set
    ERP = pop_loaderp('filename', gonogo_files(gonogo_idx).name, 'filepath',erp_dir);
    % Add New Bin
    ERP = pop_binoperator(ERP,{'b5 = b3 - b1 label GO Unrelated minus Related Difference Wave'});
    ERP = pop_binoperator(ERP,{'b6 = b2 - b4 label NOGO Unrelated minus Related Difference Wave'});
    ERP = pop_binoperator(ERP,{'b7 = b4 - b1 label NoGo minus Go Related Difference Wave'});
    ERP = pop_binoperator(ERP,{'b8 = b2 - b3 label NoGo minus Go Unrelated Difference Wave'});
    ERP = pop_binoperator(ERP,{'b9 = b1 - b4 label Go minus NoGo Related Difference Wave'});
    ERP = pop_binoperator(ERP,{'b10 = b3 - b2 label Go minus NoGo Unrelated Difference Wave'});
    % Save to Difference Wave Folder
    base_name = erase(gonogo_files(gonogo_idx).name,'.erp');
    erp_name = [base_name '_diffwave'];
    filename = [erp_name '.erp'];
    ERP = pop_savemyerp(ERP,'erpname',erp_name,...
        'filename',filename, 'filepath',base_path);
end