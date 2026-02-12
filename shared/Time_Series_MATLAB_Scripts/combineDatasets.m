%% Combining Datasets from Exergame and ADHD Study
% Datasets from each session will need to be combined before they are
% pre-processed. This script goes through the data directory and combines
% each participant's EEG datasets.
%
% Note that the intervention datasets were excluded from this combination
% because they will be pre-processed separately. Participants randomized to
% dance showed significant artifacts in their data that may contaminate the
% ICA decomposition of the rest of the datasets.
%
% Also note that two groups of datasets will later be manually combined
% because of inconsistencies in their recording process:
%   1. EXGM164 - Session 1
%   2. EXGM169 - Session 2
%
% For details on their inconsistencies, please review `! File Ordering and
% Renaming.xlsx` in the Exergame and ADHD Folder on the Google Drive
%
% Written by Noor Tasnimon 6.26.2025

% Load Directories and tasks
dataSource = '../data';
taskorder = readtable("../docs/exergame_eeg_task_order.csv");
sessions = {'baseline_session','intervention_session'};
EF_tasks = {'digitforward', 'digitbackward', 'gonogo', 'stroop', 'wcst'};
balance_tasks = {'shoulder_1', 'shoulder_2', 'shoulder_3', 'tandem_1', 'tandem_2', 'tandem_3'};
% Add "exgm" before participant IDs on `taskorder`
taskorder.participant_id = arrayfun(@(x) sprintf('exgm%03d', x), ...
    taskorder.participant_id, 'UniformOutput', false);

% Make a folder to store combined datasets in "../data" folder
if ~exist('../data/combined_datasets', 'dir')
    mkdir('../data/combined_datasets');
    fprintf('Created directory: ../data/combined_datasets\n');
else
    fprintf('Directory already exists: ../data/combined_datasets\n');
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
        
            % Baseline Session
            if strcmp(sessions{sessionIdx},'baseline_session')
                % Import EEGLAB Functions
                eeglab;
                close;
    
                % Load Pre-Baseline
                pre_baseline = pop_loadbv(fullfile(participant_dir,'baseline_eeg/'), ...
                    [taskorder.participant_id{subjectIdx} '_s1_prebaseline.vhdr']);
                [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, pre_baseline, 1);
    
                % Pull Executive Function Task Ordering for Dataset
                [digitforward, digitbackward, gonogo, stroop, wcst] = getParticipantSessionData(taskorder, ...
                    taskorder.participant_id{subjectIdx}, 1);
                indices = [digitforward, digitbackward, gonogo, stroop, wcst];
                % Load and store Executive Function EEG data
                for EF_idx = 1:length(EF_tasks)
                    eeg_data = pop_loadbv(fullfile(participant_dir,'executive_function_eeg/'), ...
                        [taskorder.participant_id{subjectIdx} '_s1_' EF_tasks{EF_idx} '.vhdr']);
                    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, eeg_data, indices(EF_idx));
                end
    
                % Load Balance Tasks
                balance_indices = 7:12; % starts at 7 after 1 pre-baseline and 5 EF tasks
                for balance_idx = 1:length(balance_tasks)
                    eeg_data = pop_loadbv(fullfile(participant_dir,'balance_eeg/'), ...
                        [taskorder.participant_id{subjectIdx} '_s1_' balance_tasks{balance_idx} '.vhdr']);
                    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, eeg_data, balance_indices(balance_idx));
                end
    
                % Merge and save
                session1 = pop_mergeset(ALLEEG, 1:12);
                [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, session1, 13);
                EEG = pop_saveset(session1, 'filename', append(taskorder.participant_id{subjectIdx},'_s1.set'), 'filepath', '../data/combined_datasets');
    
                % Clear Up Workspace for Intervention Datasets to Load
                clearvars -except dataSource taskorder sessions EF_tasks balance_tasks subjectIdx sessionIdx
            
            % Intervention Session
            else
                % Import EEGLAB Functions
                eeglab;
                close;
    
                % Load Pre-Baseline
                pre_baseline = pop_loadbv(fullfile(participant_dir,'pre_baseline_eeg/'), ...
                    [taskorder.participant_id{subjectIdx} '_s2_prebaseline.vhdr']);
                [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, pre_baseline, 1);
                % Load Post-Baseline
                post_baseline = pop_loadbv(fullfile(participant_dir,'post_baseline_eeg/'), ...
                    [taskorder.participant_id{subjectIdx} '_s2_postbaseline.vhdr']);
                [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, post_baseline, 2);
    
                % Pull Executive Function Task Ordering for Dataset
                [digitforward, digitbackward, gonogo, stroop, wcst] = getParticipantSessionData(taskorder, ...
                    taskorder.participant_id{subjectIdx}, 2);
                indices = [digitforward, digitbackward, gonogo, stroop, wcst];
                % Load and store Executive Function EEG data
                for EF_idx = 1:length(EF_tasks)
                    eeg_data = pop_loadbv(fullfile(participant_dir,'executive_function_eeg/'), ...
                        [taskorder.participant_id{subjectIdx} '_s2_' EF_tasks{EF_idx} '.vhdr']);
                    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, eeg_data, indices(EF_idx));
                end
    
                % Load Balance Tasks
                balance_indices = 8:13; % starts at 8 after 2 baselines and 5 EF tasks
                for balance_idx = 1:length(balance_tasks)
                    eeg_data = pop_loadbv(fullfile(participant_dir,'balance_eeg/'), ...
                        [taskorder.participant_id{subjectIdx} '_s2_' balance_tasks{balance_idx} '.vhdr']);
                    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, eeg_data, balance_indices(balance_idx));
                end
    
                % Merge and save
                session2 = pop_mergeset(ALLEEG, 1:13);
                [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, session2, 14);
                EEG = pop_saveset(session2, 'filename', append(taskorder.participant_id{subjectIdx},'_s2.set'), 'filepath', '../data/combined_datasets');
    
                % Clear Up Workspace for Next Participant's Datasets to Load
                clearvars -except dataSource taskorder sessions EF_tasks balance_tasks subjectIdx sessionIdx
            end
        end
    end
end