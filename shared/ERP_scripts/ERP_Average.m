% ERP DATASET CREATION AND ERP AVERAGE
% Once the ERP datasets have been fully pre-processed and split, we will
% need to add events, shift markers, create bins, and calculate a grand
% average for each dataset.
%
% This will eventually create a `.erp` (NOT .set) file, which can then be
% used for group analysis on ERPLAB.
%
% Written by Noor Tasnim on 08/03/2025

%% Import EEGLAB Functions
eeglab
close 
clear

%% Create Necessary Directories
splitFiles_dir = '../data/erp/7_split_and_epoch/';
erpSets_dir = '../data/erp/8_ERP_datasets/';
elist_dir = '../data/erp/8_ERP_datasets/elist/';
erp_dir = '../data/erp/9_average_erp/';

%% Gather list of datasets
erp_files = dir([splitFiles_dir '*.set']);

%% Preallocate Bin Numbering Table

bincount = table('Size', [length(erp_files), 7], ...
                          'VariableTypes', {'string', 'string', 'string', 'double', 'double', 'double', 'double'}, ...
                          'VariableNames', {'SubjectID', 'Session', 'Task', 'Bin1', 'Bin2', 'Bin3', 'Bin4'});

%% Process All Split Datasets

for file_idx = 1:length(erp_files)

    % Extract File Information
    filename = erp_files(file_idx).name;
    fileparts = split(filename,'_');
    id = fileparts{1};
    session = fileparts{2};
    task = erase(fileparts{4},'.set');

    % Task dependent variables
    switch task
        case 'gonogo'
            event_codes = { 'S  7' 'S  9' 'S 13' 'S 15' };
            timeshift = -12;
            bdf_path = '../docs/BDF_GONOGO.txt';
        case 'stroop'
            event_codes = { 'S  3' 'S 13' 'S 15' };
            timeshift = 28;
            bdf_path = '../docs/BDF_STROOP.txt';
        case 'wcst'
            event_codes = { 'S 15' };
            timeshift = 26;
            bdf_path = '../docs/BDF_WCST.txt';
    end

    % Load Dataset
    EEG = pop_loadset('filename',filename,'filepath',splitFiles_dir);

    % Shift Event Codes based on task
    EEG = pop_erplabShiftEventCodes(EEG ,'DisplayEEG',0,'DisplayFeedback','both',...
                'Eventcodes',event_codes, 'Rounding', 'earlier',...
                'Timeshift',timeshift);

    % Create Numeric Events and Generate Elist
    elist_path = [elist_dir id '_' session '_' task '_elist.txt'];
    EEG  = pop_creabasiceventlist(EEG,'AlphanumericCleaning','on','BoundaryNumeric',{ -99 },...
        'BoundaryString',{ 'boundary' },'Eventlist',elist_path);

    % Assign Bins
    EEG = pop_binlister(EEG ,'BDF', bdf_path ,'IndexEL', 1,'SendEL2','EEG',...
        'UpdateEEG', 'on', 'Voutput', 'EEG' );

    % Count Bin Assignments
    bini_values = [EEG.event.bini];
    bincount.SubjectID(file_idx) = id;
    bincount.Session(file_idx) = session;
    bincount.Task(file_idx) = task;

    switch task
        case 'gonogo'
            edges = [0.5, 1.5, 2.5, 3.5, 4.5];
            counts = histcounts(bini_values, edges);
            bincount.Bin1(file_idx) = counts(1);
            bincount.Bin2(file_idx) = counts(2);
            bincount.Bin3(file_idx) = counts(3);
            bincount.Bin4(file_idx) = counts(4);
        case 'stroop'
            edges = [0.5, 1.5, 2.5, 3.5];
            counts = histcounts(bini_values, edges);
            bincount.Bin1(file_idx) = counts(1);
            bincount.Bin2(file_idx) = counts(2);
            bincount.Bin3(file_idx) = counts(3);
            bincount.Bin4(file_idx) = NaN;
        case 'wcst'
            edges = [0.5, 1.5, 2.5];
            counts = histcounts(bini_values, edges);
            bincount.Bin1(file_idx) = counts(1);
            bincount.Bin2(file_idx) = counts(2);
            bincount.Bin3(file_idx) = NaN;
            bincount.Bin4(file_idx) = NaN;
    end

    % Epoching with Baseline correction
    EEG = pop_epochbin(EEG,[-200.0  800.0],'pre');

    % Save Epoched Dataset
    EEG = pop_saveset(EEG,'filename',[id '_' session '_' task '_bin.set'],...
        'filepath',erpSets_dir);

end

% Export Bin Count Tables to Results Folder
writetable(bincount, '../results/erp/erp_bincounts.csv');

%% Artifact Detection with Epoched Dataset
% Gather List of Epoched Datasets
epoched_datasets = dir([erpSets_dir '*.set']);

% Preallocate ERP Data Quality Metrics
n_datasets = length(epoched_datasets);
data_quality = struct('id', cell(n_datasets, 1), ...
                       'session', cell(n_datasets, 1), ...
                       'task', cell(n_datasets, 1), ...
                       'ntrials_accepted', cell(n_datasets, 1), ...
                       'ntrials_reject', cell(n_datasets, 1), ...
                       'pexcluded', cell(n_datasets, 1), ...
                       'dataquality_aSME', cell(n_datasets, 1));

for epochset_idx = 1:length(epoched_datasets)
    
    % Extract Dataset Information
    filename = epoched_datasets(epochset_idx).name;
    fileparts = split(filename,'_');
    id = fileparts{1};
    session = fileparts{2};
    task = fileparts{3};

    % Load Epoched Dataset
    EEG = pop_loadset(filename,erpSets_dir);

    % Detect and Flag Epochs with Eye Blinks (only looking at Fp1 and Fp2)
    EEG = pop_artstep(EEG, 'Channel', [ 1 32], 'Flag',  1, 'LowPass',  -1,...
        'Threshold',  50, 'Twindow', [ -200 798], 'Windowsize',  200, 'Windowstep', 10);
    % Detect and Flag Epochs with Eye Movement (only looking at Fp1 and Fp2)
    EEG = pop_artstep(EEG, 'Channel', [ 1 32], 'Flag',  1, 'LowPass',  -1,...
        'Threshold',  32, 'Twindow', [ -200 798], 'Windowsize',  200, 'Windowstep', 10);
    % Detect and Flag Epochs that Surpass 100uV Threshold (Absolute Voltage Threshold)
    EEG = pop_artextval(EEG, 'Channel',  1:64, 'Flag',  1, 'LowPass',  -1,...
        'Threshold', [ -100 100], 'Twindow', [ -200 798] );
    % Detect and Flag Epochs using moving window peak-to-peak
    EEG = pop_artmwppth(EEG , 'Channel',  1:64, 'Flag',  1, 'LowPass',  -1,...
        'Threshold',  100, 'Twindow', [ -200 798], 'Windowsize',  200, 'Windowstep',100);
    % Compute Average ERPs
    ERP = pop_averager(EEG, 'Criterion', 'good', 'DQ_custom_wins', 0,...
        'DQ_flag', 1, 'DQ_preavg_txt', 0, 'ExcludeBoundary', 'on', 'SEM', 'on' );

    % Add Data Quality Metrics to Preallocated Structure
    data_quality(epochset_idx).id = id;
    data_quality(epochset_idx).session = session;
    data_quality(epochset_idx).task = task;
    data_quality(epochset_idx).ntrials_accepted = ERP.ntrials.accepted;
    data_quality(epochset_idx).ntrials_rejected = ERP.ntrials.rejected;
    data_quality(epochset_idx).pexcluded = ERP.pexcluded;
    data_quality(epochset_idx).dataquality_aSME = ERP.dataquality(3).data;

    % Save Dataset
    ERP = pop_savemyerp(ERP, 'erpname', [id '_' session '_' task '_erp'],...
        'filename', [id '_' session '_' task '.erp'],...
        'filepath', erp_dir);

end

% Export ERP Data Quality Metrics
% CSV files of All Metrics Except aSME
data_quality_table = table({data_quality.id}', {data_quality.session}', {data_quality.task}', ...
                     {data_quality.ntrials_accepted}', {data_quality.ntrials_rejected}', {data_quality.pexcluded}', ...
                     'VariableNames', {'id', 'session', 'task', ...
                                      'ntrials_accepted', 'ntrials_reject', 'pexcluded'});
% Write to CSV file
writetable(data_quality_table, '../results/erp/ERP_DataQuality_Metrics.csv');

% Export structure as MAT file with aSME values
save('../results/erp/ERP_DataQuality.mat','data_quality')