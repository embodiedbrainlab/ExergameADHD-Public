% PREPARING PREPROCESSED DATA FOR SPECPARAM ANALYSIS
% At this point, the EEG data has been run through AMICA, and only 50%
% Brain ICs remain. Whole datasets were put through the EEGLAB Study
% function, where ICs were clustered based on dipole locations ONLY (so we
% did NOT use dipole positioning or scalp maps).
%
% Note that this clustering DID NOT include dipoles with r.v.'s over 15%
% nor those that were located outside of the brain template.
%
% The goal of this script is to use the .csv files produced after
% clustering ('../results/IC_clusters/pruned_clusters') to calculate the 
% power spectrum of each clustered independent components across all 
% experiences. The result should be a MATLAB structure with the following 
% pieces of information that could be extracted by SciPy, and then SpecParam:
%   1. Subject
%   2. Session
%   3. Experience
%   4. Component (IC)
%   5. Cluster
%   6. Freqs (from pwelch)
%   7. icaSpectra (from pwelch)
%   8. icaAct
%   9. Filename
%
% The .mat file will then be processed through SpecParam, where all
% icaSpectra will be used to evaluate the best fitting model. However, our
% analysis will involve splitting the datasets up by cluster, which should
% be manageable if all of the information above is stored in a structure.
% (which should transfer over as a dictionary/list on Python)
%
% Edited by Noor Tasnim on August 27, 2025

clear; clc;

% Add EEGLAB to path if not already added
eeglab; % Uncomment if EEGLAB needs to be initialized
close 
clear

%% Define paths
dataset_dir = '..\data\preprocessed\session_1\split\';
cluster_dir = '../results/IC_clusters/pruned_clusters/';
output_dir = '../results/';

%% Get list of datasets
datasets = dir(fullfile(dataset_dir, '*.set'));

%% Get list of cluster CSV files
cluster_files = dir(fullfile(cluster_dir, 'Cls_*_prune.csv'));
fprintf('Found %d cluster files\n', length(cluster_files));

%% Initialize results structure
results = struct();
result_idx = 1;

%% Process each cluster file
for cluster_idx = 1:length(cluster_files)
    cluster_file = cluster_files(cluster_idx);
    cluster_filepath = fullfile(cluster_dir, cluster_file.name);
    
    % Extract cluster number from filename (e.g., 'Cls_3_prune.csv' -> 3)
    cluster_name_parts = split(cluster_file.name, '_');
    cluster_num = str2double(cluster_name_parts{2});
    
    fprintf('\nProcessing cluster %d (%s)...\n', cluster_num, cluster_file.name);
    
    % Read cluster CSV file
    try
        cluster_data = readtable(cluster_filepath);
        fprintf('  Found %d components in cluster\n', height(cluster_data));
    catch ME
        fprintf('  Error reading cluster file: %s\n', ME.message);
        continue;
    end
    
    % Validate required columns
    required_cols = {'subject', 'session', 'comp'};
    if ~all(ismember(required_cols, cluster_data.Properties.VariableNames))
        fprintf('  Warning: Missing required columns in %s\n', cluster_file.name);
        continue;
    end
    
    %% Process each component in the cluster
    for comp_idx = 1:height(cluster_data)
        subject = cluster_data.subject(comp_idx);
        session = cluster_data.session(comp_idx);
        comp = cluster_data.comp(comp_idx);
        
        % Convert to appropriate data types if needed
        if iscell(subject)
            subject = subject{1};
        end
        if iscell(session)
            session = session{1};
        end
        
        fprintf('    Processing subject %s, session %s, component %d\n', ...
                string(subject), string(session), comp);
        
        % Find matching datasets for this subject-session combination
        pattern = sprintf('%s_%s_', string(subject), string(session));
        matching_datasets = {};
        
        for dataset_idx = 1:length(datasets)
            if startsWith(datasets(dataset_idx).name, pattern)
                matching_datasets{end+1} = datasets(dataset_idx).name;
            end
        end
        
        if isempty(matching_datasets)
            fprintf('      Warning: No datasets found for %s\n', pattern);
            continue;
        end
        
        %% Process each matching dataset
        for i = 1:length(matching_datasets)
            dataset_name = matching_datasets{i};
            dataset_path = fullfile(dataset_dir, dataset_name);
            
            % Extract experience from filename
            name_parts = split(dataset_name, '_');
            if length(name_parts) == 3
                experience_part = name_parts{3};
                % Remove .set extension
                experience = strrep(experience_part, '.set', '');
            elseif length(name_parts) == 4 % shoulder or tandem
                balance_task = name_parts{3};
                trial = strrep(name_parts{4}, '.set', '');
                experience = [balance_task '_' trial];
            else
                experience = 'unknown';
            end
            
            fprintf('      Loading dataset: %s (experience: %s)\n', ...
                    dataset_name, experience);
            
            try
                % Load EEG dataset using EEGLAB
                EEG = pop_loadset('filename', dataset_name, 'filepath', dataset_dir);
                
                % Check if component index is valid
                if comp > size(EEG.icaact, 1)
                    fprintf('        Warning: Component %d exceeds available components (%d)\n', ...
                            comp, size(EEG.icaact, 1));
                    continue;
                end
                
                % Extract ICA activation for the specified component
                icaact = EEG.icaact(comp, :);
                
                % Calculate power spectrum using pwelch
                NFFT = EEG.srate;
                OVERLAP = EEG.srate/2;
                WINDOW = EEG.srate;
                
                [spectra, freqs] = pwelch(icaact, WINDOW, OVERLAP, NFFT, EEG.srate);
                
                % Store results in structure
                results(result_idx).subject = subject;
                results(result_idx).session = session;
                results(result_idx).experience = experience;
                results(result_idx).component = comp;
                results(result_idx).cluster = cluster_num;
                results(result_idx).freqs = freqs;
                results(result_idx).spectra = spectra;
                results(result_idx).icaact = icaact;
                results(result_idx).filename = dataset_name;
                
                fprintf('        Successfully processed component %d\n', comp);
                result_idx = result_idx + 1;
                
            catch ME
                fprintf('        Error processing dataset %s: %s\n', ...
                        dataset_name, ME.message);
                continue;
            end
        end
    end
end

%% Save results
if ~isempty(results)
    output_filename = fullfile(output_dir, 'exergame_session1_PowerSpectrumResults.mat');
    save(output_filename, 'results','-v7.3');
    fprintf('\nResults saved to: %s\n', output_filename);
    fprintf('Total processed entries: %d\n', length(results));
    
    % Display summary statistics
    fprintf('\nSummary:\n');
    fprintf('  Unique subjects: %d\n', length(unique(string({results.subject}))));
    fprintf('  Unique sessions: %d\n', length(unique(string({results.session}))));
    fprintf('  Unique experiences: %d\n', length(unique(string({results.experience}))));
    fprintf('  Unique clusters: %d\n', length(unique([results.cluster])));
    
else
    fprintf('\nNo results to save.\n');
end

fprintf('\nScript completed.\n');