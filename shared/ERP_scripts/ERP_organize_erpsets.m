% For further analysis, we will want to organize our final ERPsets into the
% following directories:
%
% 11_group_analysis/
%   session/
%       task/
%           asrs_6_total_category/
%
% This should then make it easier for us to go into each directory,
% load datasets into ERPlab and create grand averages.
%
% ---- Documentation edited on September 23, 2025
% ---- Code edited on October 26, 2025 so that files for sessions are organized
% by asrs_6_total category instead of medication status.

%% Difference Wave File Path
diffwave_path = '../data/erp/10_difference_waves/';

%% Import exergame .csv and determine asrs and intervention groupings
exergame = readtable('../demographicsPsych/data/tidy/exergame_DemoBaselineMH_TOTALS.csv');
id_asrsCat = exergame(:,{'participant_id', 'asrs_6_total_category'});

%% Create directories
% Define the base path and directory structure
base_path = '../data/erp/11_group_analysis/';
sessions = {'session1', 'session2'};
task = {'wcst','stroop','gonogo'};
asrs_cat = {'low_negative', 'high_negative', 'low_positive','high_positive'};

% Create base directory if it doesn't exist
if ~exist(base_path, 'dir')
    mkdir(base_path);
end

% Create session and task directories
for i = 1:length(sessions)
    session_path = fullfile(base_path, sessions{i});
    % Create session directory if it doesn't exist
    if ~exist(session_path, 'dir')
        mkdir(session_path);
    end
    % Create task directories within each session
    for j = 1:length(task)
        task_path = fullfile(session_path, task{j});
        if ~exist(task_path, 'dir')
            mkdir(task_path);
        end
        % Create asrs_6_total_category directories within each task
        for k = 1:length(asrs_cat)
            asrs_cat_path = fullfile(task_path, asrs_cat{k});
            if ~exist(asrs_cat_path, 'dir')
                mkdir(asrs_cat_path);
            end
        end
    end
end

%% Copy files to appropriate directories
% Get list of all .erp files in the diffwave directory
file_list = dir(fullfile(diffwave_path, '*_diffwave.erp'));

for f = 1:length(file_list)
    filename = file_list(f).name;
    
    % Parse filename to extract components
    % Format: {participant_id}_{session}_{task}_diffwave.erp
    parts = split(filename, '_');
    
    if length(parts) >= 3
        % Extract participant ID (remove 'exgm' prefix and leading zeros)
        participant_id_str = parts{1};
        if startsWith(participant_id_str, 'exgm')
            participant_id_num = str2double(participant_id_str(5:end));
        else
            fprintf('Warning: Unexpected participant ID format in file %s\n', filename);
            continue;
        end
        
        % Extract session (convert s1/s2 to session1/session2)
        session_str = parts{2};
        if strcmp(session_str, 's1')
            session_full = 'session1';
        elseif strcmp(session_str, 's2')
            session_full = 'session2';
        else
            fprintf('Warning: Unexpected session format in file %s\n', filename);
            continue;
        end
        
        % Extract task
        task_str = parts{3};
        
        % Find ASRS-6 Category from id_asrsCat table
        cat_row = id_asrsCat.participant_id == participant_id_num;
        if sum(cat_row) == 1
            participant_asrs_type = id_asrsCat.asrs_6_total_category{cat_row};
        elseif sum(cat_row) == 0
            fprintf('Warning: Participant ID %d not found in id_asrsCat table for file %s\n', participant_id_num, filename);
            continue;
        else
            fprintf('Warning: Multiple entries for participant ID %d in id_asrsCat table for file %s\n', participant_id_num, filename);
            continue;
        end
        
        % Construct destination path
        dest_path = fullfile(base_path, session_full, task_str, participant_asrs_type);
        
        % Verify destination directory exists
        if ~exist(dest_path, 'dir')
            fprintf('Warning: Destination directory does not exist: %s\n', dest_path);
            continue;
        end
        
        % Copy file to destination
        source_file = fullfile(diffwave_path, filename);
        dest_file = fullfile(dest_path, filename);
        
        try
            copyfile(source_file, dest_file);
            fprintf('Copied: %s -> %s\n', filename, dest_path);
        catch ME
            fprintf('Error copying file %s: %s\n', filename, ME.message);
        end
    else
        fprintf('Warning: Filename %s does not match expected format\n', filename);
    end
end

fprintf('\nFile organization complete!\n');