%% Joining EXGM164_S1 and EXGM169_S1 Datasets
% EXGM164 and EXGM169 had some inconsistencies with their recordings from
% session 1. Instead of trying to find a way to uniquely merge them in the
% combineDatasets.m script, they will be manually merged through the script
% below.

% Define data source and presets
dataSource = '../data';
balance_tasks = {'shoulder_1', 'shoulder_2', 'shoulder_3', 'tandem_1', 'tandem_2', 'tandem_3'};

%% EXGM164
% We ended up recording stroop and gonogo together.
% Order: DF, DB, stroop, gonogo, wcst

% Import EEGLAB Functions
eeglab;
close;

% Subject ID information
subjectID = 'exgm164';
subject_dir = fullfile(dataSource,subjectID,'baseline_session','eeg/');

% Pre-baseline
pre_baseline = pop_loadbv(fullfile(subject_dir,'baseline_eeg/'), ...
                [subjectID '_s1_prebaseline.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, pre_baseline, 1);

% Digit Forward
digit_forward = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_digitforward.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, digit_forward, 2);
% Digit Backward
digit_backward = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_digitbackward.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, digit_backward, 3);
% Stroop and Go/No-Go
stroop_gonogo = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_stroop_gonogo.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, stroop_gonogo, 4);
% Wisconsin Card Sort Task
wcst = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_wcst.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, wcst, 5);

% Load Balance Tasks
balance_indices = 6:11; % starts at 6 after 1 pre-baseline and 4 EF datasets
for balance_idx = 1:length(balance_tasks)
    eeg_data = pop_loadbv(fullfile(subject_dir,'balance_eeg/'), ...
        ['exgm164_s1_' balance_tasks{balance_idx} '.vhdr']);
    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, eeg_data, balance_indices(balance_idx));
end

% Merge datasets and save
exgm164_session1 = pop_mergeset(ALLEEG, 1:11);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, exgm164_session1, 12);
EEG = pop_saveset(exgm164_session1, 'filename', 'exgm164_s1.set', 'filepath', '../data/combined_datasets');

% Clear Up Workspace for EXGM169
clearvars -except dataSource balance_tasks

%% EXGM169
% This session had 2 go/no-go datasets that need to be merged
% Order: WCST, DF, DB, Go/No-Go, Stroop

% Import EEGLAB Functions
eeglab;
close;

% Subject ID information
subjectID = 'exgm169';
subject_dir = fullfile(dataSource,subjectID,'baseline_session','eeg/');

% Pre-baseline
pre_baseline = pop_loadbv(fullfile(subject_dir,'baseline_eeg/'), ...
                [subjectID '_s1_prebaseline.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, pre_baseline, 1);

% Wisconsin Card Sort Task
wcst = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_wcst.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, wcst, 2);
% Digit Forward
digit_forward = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_digitforward.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, digit_forward, 3);
% Digit Backward
digit_backward = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_digitbackward.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, digit_backward, 4);
% Go/No-Go - PART 1
gonogo_1 = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_gonogo_1.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, gonogo_1, 5);
% Go/No-Go - PART 2
gonogo_2 = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_gonogo_2.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, gonogo_2, 6);
% Stroop
stroop = pop_loadbv(fullfile(subject_dir,'executive_function_eeg/'), ...
                [subjectID '_s1_stroop.vhdr']);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, stroop, 7);


% Load Balance Tasks
balance_indices = 8:13; % starts at 8 after 1 pre-baseline and 6 EF datasets
for balance_idx = 1:length(balance_tasks)
    eeg_data = pop_loadbv(fullfile(subject_dir,'balance_eeg/'), ...
        ['exgm169_s1_' balance_tasks{balance_idx} '.vhdr']);
    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, eeg_data, balance_indices(balance_idx));
end

% Merge datasets and save
exgm169_session1 = pop_mergeset(ALLEEG, 1:13);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, exgm169_session1, 14);
EEG = pop_saveset(exgm169_session1, 'filename', 'exgm169_s1.set', 'filepath', '../data/combined_datasets');