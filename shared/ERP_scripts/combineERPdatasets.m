%% Combining Datasets from Exergame and ADHD Study - ERP ONLY!
% Datasets from each session will need to be combined before they are
% pre-processed. This script goes through the data directory and combines
% each participant's EEG datasets from the tasks that will be part of the
% ERP analysis: WCST, Stroop, and Go/No-Go.
%
% Note that two groups of datasets are manually combined at the end of this
% script because of inconsistencies in their recording process:
%   1. EXGM164 - Session 1
%   2. EXGM169 - Session 1
%
% For details on their inconsistencies, please review `! File Ordering and
% Renaming.xlsx` in the Exergame and ADHD Folder on the Google Drive
%
% Written by Noor Tasnimon 7.22.2025

% Load Directories and tasks
dataSource = '../data';
taskorder = readtable("../docs/exergame_eeg_task_order.csv");
sessions = {'baseline_session','intervention_session'};
EF_tasks = {'gonogo', 'stroop', 'wcst'};

% Add "exgm" before participant IDs on `taskorder`
taskorder.participant_id = arrayfun(@(x) sprintf('exgm%03d', x), ...
    taskorder.participant_id, 'UniformOutput', false);

% Make a folder to store combined datasets in "../data" folder
if ~exist('../data/ERP_combined_datasets', 'dir')
    mkdir('../data/ERP_combined_datasets');
    fprintf('Created directory: ../data/ERP_combined_datasets\n');
else
    fprintf('Directory already exists: ../data/ERP_combined_datasets\n');
end

%% Loop through participants for combining
for subjectIdx = 1:2:height(taskorder)
    % Loop Through Baseline and Intervention Session
    for sessionIdx = 1:length(sessions)
        if (strcmp(taskorder.participant_id{subjectIdx}, 'exgm164') && strcmp(sessions{sessionIdx}, 'baseline_session')) || ...
                (strcmp(taskorder.participant_id{subjectIdx}, 'exgm169') && strcmp(sessions{sessionIdx}, 'baseline_session'))
            fprintf('datasets from participant_id{%s} - sessions{%s} were skipped because they will be manually combined\n',...
                taskorder.participant_id{subjectIdx}, sessions{sessionIdx});
        else
            % Define Participant Directory
            participant_dir = fullfile(dataSource,taskorder.participant_id{subjectIdx}, ...
            sessions{sessionIdx},'eeg/');
        
            % Baseline Session (Session 1)
            if strcmp(sessions{sessionIdx},'baseline_session')
                % Import EEGLAB Functions
                eeglab;
                close;
    
                % Pull Executive Function Task Ordering for Dataset
                [digitforward, digitbackward, gonogo, stroop, wcst] = getParticipantSessionData(taskorder, ...
                    taskorder.participant_id{subjectIdx}, 1);
                indices = [digitforward, digitbackward, gonogo, stroop, wcst] - 1; % subtract 1 because we won't use the baseline dataset
                
                % Remove Digit Span and Reorder
                new_indices = renumber_ERP_task_indices(indices);

                % Load and store Executive Function EEG data
                for EF_idx = 1:length(EF_tasks)
                    eeg_data = pop_loadbv(fullfile(participant_dir,'executive_function_eeg/'), ...
                        [taskorder.participant_id{subjectIdx} '_s1_' EF_tasks{EF_idx} '.vhdr']);
                    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, eeg_data, new_indices(EF_idx));
                end
    
                % Merge and save
                session1 = pop_mergeset(ALLEEG, 1:3);
                [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, session1, 4);
                EEG = pop_saveset(session1, 'filename', append(taskorder.participant_id{subjectIdx},'_s1.set'), 'filepath', '../data/ERP_combined_datasets');
    
                % Clear Up Workspace for Intervention Datasets to Load
                clearvars -except dataSource taskorder sessions EF_tasks subjectIdx sessionIdx
            
            % Intervention Session
            else
                % Import EEGLAB Functions
                eeglab;
                close;

                % Pull Executive Function Task Ordering for Dataset
                [digitforward, digitbackward, gonogo, stroop, wcst] = getParticipantSessionData(taskorder, ...
                    taskorder.participant_id{subjectIdx}, 2);
                indices = [digitforward, digitbackward, gonogo, stroop, wcst]-2; %subtract 2 becuase we wont use pre/post baseline datasets
                
                % Remove Digit Span and Reorder
                new_indices = renumber_ERP_task_indices(indices);
                
                % Load and store Executive Function EEG data
                for EF_idx = 1:length(EF_tasks)
                    eeg_data = pop_loadbv(fullfile(participant_dir,'executive_function_eeg/'), ...
                        [taskorder.participant_id{subjectIdx} '_s2_' EF_tasks{EF_idx} '.vhdr']);
                    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, eeg_data, new_indices(EF_idx));
                end

                % Merge and save
                session2 = pop_mergeset(ALLEEG, 1:3);
                [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, session2, 4);
                EEG = pop_saveset(session2, 'filename', append(taskorder.participant_id{subjectIdx},'_s2.set'), 'filepath', '../data/ERP_combined_datasets');
    
                % Clear Up Workspace for Next Participant's Datasets to Load
                clearvars -except dataSource taskorder sessions EF_tasks subjectIdx sessionIdx
            end
        end
    end
end

%% Manually Merge EXGM164
clearvars -except dataSource % clear variables from earlier for loop

% Subject ID information
subjectID = 'exgm164';
subject_dir = fullfile(dataSource,subjectID,'baseline_session','eeg/');

% Import EEGLAB Functions
eeglab;
close;

% Stroop and Go/No-Go
stroop_gonogo = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_stroop_gonogo.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, stroop_gonogo, 1);
% Wisconsin Card Sort Task
wcst = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_wcst.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, wcst, 2);

% Merge datasets and save
exgm164_session1 = pop_mergeset(ALLEEG, 1:2);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, exgm164_session1, 3);
EEG = pop_saveset(exgm164_session1, 'filename', 'exgm164_s1.set', 'filepath', '../data/ERP_combined_datasets');

% Clear Up Workspace for EXGM169
clearvars -except dataSource

%% Manually Merge EXGM169

% Subject ID information
subjectID = 'exgm169';
subject_dir = fullfile(dataSource,subjectID,'baseline_session','eeg/');

% Import EEGLAB Functions
eeglab;
close;

% Wisconsin Card Sort Task
wcst = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_wcst.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, wcst, 1);
% Go/No-Go - PART 1
gonogo_1 = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_gonogo_1.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, gonogo_1, 2);
% Go/No-Go - PART 2
gonogo_2 = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_gonogo_2.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, gonogo_2, 3);
% Stroop
stroop = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_stroop.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, stroop, 4);

% Merge datasets and save
exgm169_session1 = pop_mergeset(ALLEEG, 1:4);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, exgm169_session1, 5);
EEG = pop_saveset(exgm169_session1, 'filename', 'exgm169_s1.set', 'filepath', '../data/ERP_combined_datasets');