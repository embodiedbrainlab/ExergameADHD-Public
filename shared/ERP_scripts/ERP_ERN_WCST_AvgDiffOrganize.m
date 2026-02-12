% Calculate Bins, Averaging, and Difference Waves for WCST ERN
% We need to re-bin datasets from WCST and because our original scripts did not
% create response-locked bins. Plus, based on the standards set by
% Kappenman et al. (2021), the baseline period and epoch windows differ for
% ERN (event-related negativity) and the response markers technically DO
% NOT need to be shifted because signals synchronously transfer from
% keyboard/mouse responses to the EEG triggerbox.
%
% Based on our pre-processing steps, we should have 128 WCST datasets:
%   - 63 participants * 2 sessions
%   - 4 additional participants from session 1
%   - 2 WCST datasets removed (145_s1 and 132_s2 did not deliver signals)
%
% Once the average ERPs are calculated for all WCST ERN datasets, a
% difference wave is calculated using the following forumula:
%
% Bin 3 = Bin 2 (Incorrect) - Bin 1 (Correct)
%
% Lastly, the script organizes the .erp datasets with difference waves into
% their respective session 1 folders based on medication status for further
% group analysis.
%
% NOTE: We originally wanted to test ERN in Stroop, but most participants had
% less than 6 errors and could not be assessed. Previously identified bins 
% can be found in the ERP Data folder on the Google Drive.
%
% Written by Noor Tasnim on September 18, 2025

%% Set Directories
wcst_dir = '../data/erp/7.2_split_and_epoch_WCST/';
erpSets_dir = '../data/erp/ERN/8_ERP_datasets/';
elist_dir = '../data/erp/ERN/8_ERP_datasets/elist/';
erp_dir = '../data/erp/ERN/9_average_erp/';
diffwave_path = '../data/erp/ERN/10_difference_waves/';
groupanalysis_path = '../data/erp/ERN/11_group_analysis/';

%% Gather List of Datasets
% We should have 128 for WCST

if length(dir([wcst_dir '*.set'])) ~= 128
    error('There should be 128 WCST files. Double check Google Drive to see if you have all the datasets.')
else
    erp_files = dir([wcst_dir '*.set']);
end

%% Preallocate Bin Numbering Table

bincount = table('Size', [length(erp_files), 5], ...
                          'VariableTypes', {'string', 'string', 'string', 'double', 'double'}, ...
                          'VariableNames', {'SubjectID', 'Session', 'Task', 'Bin1', 'Bin2'});

%% Process All Split Datasets

for file_idx = 1:length(erp_files)

    % Extract File Information
    filename = erp_files(file_idx).name;
    fileparts = split(filename,'_');
    id = fileparts{1};
    session = fileparts{2};
    task = erase(fileparts{4},'.set');

    % Stimulus and BINLISTER Information
    event_codes = { 'S 15' };
    timeshift = 26;
    bdf_path = '../docs/BDF_ERN_WCST.txt';

    % Load Dataset
    filepath = erp_files(file_idx).folder;
    EEG = pop_loadset('filename',filename,'filepath',filepath);

    % Shift Event Codes based on task
    EEG = pop_erplabShiftEventCodes(EEG ,'DisplayEEG',0,'DisplayFeedback','both',...
                'Eventcodes',event_codes, 'Rounding', 'earlier',...
                'Timeshift',timeshift);

    % Create Numeric Events and Generate Elist
    elist_path = [elist_dir id '_' session '_' task '_ERN_elist.txt'];
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

    % Counting
    edges = [0.5, 1.5, 2.5];
    counts = histcounts(bini_values, edges);
    bincount.Bin1(file_idx) = counts(1);
    bincount.Bin2(file_idx) = counts(2);

    % Epoching with Baseline correction
    EEG = pop_epochbin(EEG,[-600.0  400.0],[-400.0 -200.0]);

    % Save Epoched Dataset
    EEG = pop_saveset(EEG,'filename',[id '_' session '_' task '_ERN_bin.set'],...
        'filepath',erpSets_dir);

end

% Export Bin Count Tables to Results Folder
writetable(bincount, '../results/erp/erp_ERN_bincounts.csv');

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
        'Threshold',  50, 'Twindow', [ -600 400], 'Windowsize',  200, 'Windowstep', 10);
    % Detect and Flag Epochs with Eye Movement (only looking at Fp1 and Fp2)
    EEG = pop_artstep(EEG, 'Channel', [ 1 32], 'Flag',  1, 'LowPass',  -1,...
        'Threshold',  32, 'Twindow', [ -600 400], 'Windowsize',  200, 'Windowstep', 10);
    % Detect and Flag Epochs that Surpass 100uV Threshold (Absolute Voltage Threshold)
    EEG = pop_artextval(EEG, 'Channel',  1:64, 'Flag',  1, 'LowPass',  -1,...
        'Threshold', [ -100 100], 'Twindow', [ -600 400] );
    % Detect and Flag Epochs using moving window peak-to-peak
    EEG = pop_artmwppth(EEG , 'Channel',  1:64, 'Flag',  1, 'LowPass',  -1,...
        'Threshold',  100, 'Twindow', [ -600 400], 'Windowsize',  200, 'Windowstep',100);
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
        'filename', [id '_' session '_' task '_ERN.erp'],...
        'filepath', erp_dir);

end

%% Export ERP Data Quality Metrics
% CSV files of All Metrics Except aSME
data_quality_table = table({data_quality.id}', {data_quality.session}', {data_quality.task}', ...
                     {data_quality.ntrials_accepted}', {data_quality.ntrials_rejected}', {data_quality.pexcluded}', ...
                     'VariableNames', {'id', 'session', 'task', ...
                                      'ntrials_accepted', 'ntrials_reject', 'pexcluded'});
% Write to CSV file
writetable(data_quality_table, '../results/erp/ERP_ERN_DataQuality_Metrics.csv');

% Export structure as MAT file with aSME values
save('../results/erp/ERP_ERN_DataQuality.mat','data_quality')

%% Calculate Difference Wave for WCST Datasets

% Gather datasets
wcst_files = dir([erp_dir '*wcst_ERN.erp']);

for wcst_idx = 1:length(wcst_files)
    % Load ERP Set
    ERP = pop_loaderp('filename', wcst_files(wcst_idx).name, 'filepath',erp_dir);
    % Add New Bin
    ERP = pop_binoperator(ERP, {'b3 = b2 - b1 label Incorrect minus Correct Difference Wave'});
    % Save to Difference Wave Folder
    base_name = erase(wcst_files(wcst_idx).name,'.erp');
    erp_name = [base_name '_diffwave'];
    filename = [erp_name '.erp'];
    ERP = pop_savemyerp(ERP,'erpname',erp_name,...
        'filename',filename, 'filepath',diffwave_path);
end

%% Organize ERN Datasets

% Define the base path and directory structure
sessions = {'session1', 'session2'};
tasksForOrganizing = {'wcst'};
med_type = {'amphetamine', 'methylphenidate', 'none','other'};

% Create base directory if it doesn't exist
if ~exist(groupanalysis_path, 'dir')
    mkdir(groupanalysis_path);
end

% Create session and task directories
for i = 1:length(sessions)
    session_path = fullfile(groupanalysis_path, sessions{i});
    % Create session directory if it doesn't exist
    if ~exist(session_path, 'dir')
        mkdir(session_path);
    end
    % Create task directories within each session
    for j = 1:length(tasksForOrganizing)
        task_path = fullfile(session_path, tasksForOrganizing{j});
        if ~exist(task_path, 'dir')
            mkdir(task_path);
        end
        % Create med_type directories within each task
        for k = 1:length(med_type)
            med_type_path = fullfile(task_path, med_type{k});
            if ~exist(med_type_path, 'dir')
                mkdir(med_type_path);
            end
        end
    end
end

%% Import exergame_tidy and determine medication status grouping
exergame = readtable('../demographicsPsych/data/tidy/exergame_tidy.csv');
id_medType = exergame(:,{'participant_id', 'adhd_med_type'});

%% Copy files to appropriate directories
% Get list of all .erp files in the diffwave directory
file_list = dir(fullfile(diffwave_path, '*ERN_diffwave.erp'));

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
        
        % Find medication type from id_medType table
        med_row = id_medType.participant_id == participant_id_num;
        if sum(med_row) == 1
            participant_med_type = id_medType.adhd_med_type{med_row};
        elseif sum(med_row) == 0
            fprintf('Warning: Participant ID %d not found in id_medType table for file %s\n', participant_id_num, filename);
            continue;
        else
            fprintf('Warning: Multiple entries for participant ID %d in id_medType table for file %s\n', participant_id_num, filename);
            continue;
        end
        
        % Construct destination path
        dest_path = fullfile(groupanalysis_path, session_full, task_str, participant_med_type);
        
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