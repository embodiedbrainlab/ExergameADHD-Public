% ERP PROCESSING
% Takes raw .set files that have been combined using `combineERPdatasets.m`
% and processes them through the pipeline recommended by Steve Luck. Note
% that the pipeline is slightly adjusted to account for datasets being
% appended and needing to be split before epoch averaging/analysis.
%
% For a preview of Steve Luck's suggested pipeline, review the following
% page (without '...'): https://socialsci.libretexts.org/Bookshelves/Psychology/...
% Biological_Psychology/Applied_Event-Related_Potential_Data_Analysis_(Luck)/...
% 14%3A_Appendix_3%3A_Example_Processing_Pipeline

%% Import EEGLAB functions
eeglab
close
clear

%% Define File Paths
erpDir = '../data/erp/';
rawDataDir = '../data/erp/1_raw_data/';
preICADataDir = '../data/erp/2_pre_ICA_data/';
preICA_PSD_Dir = '../data/erp/2_pre_ICA_data/psd/';
icaArtifactCorrectionDir = '../data/erp/3_ICA_decomposition_data/';
icaDataDir = '../data/erp/4_ICA_weights_data/';
postICADataDir = '../data/erp/5_post_ICA_data/';
processPostICADir = '../data/erp/6_processing_post_ICA/';
postICA_PSD_Dir = '../data/erp/6_processing_post_ICA/psd/';
splitEpochDir = '../data/erp/7_split_and_epoch/';
eeglab_path = 'C:\Users\ntasnim\Documents\eeglab2025.0.0\';
elc_file = append(eeglab_path,'plugins/dipfit/standard_BEM/elec/standard_1005.elc');
removed_channels_output_file = '../docs/channels_to_interp_FOR_ERP.csv';

%% Step 1: Preprocessing before ICA-based artifact correction
% Parallel computing is saved for FFT in cleanline()

% Gather List of Datasets
rawDataFiles = dir([rawDataDir '*.set']);

% Preallocate temporary arrays for collecting results
temp_ids = cell(length(rawDataFiles), 1);
temp_sessions = cell(length(rawDataFiles), 1);
temp_removed_channels = cell(length(rawDataFiles), 1);
temp_removed_channels_indices = cell(length(rawDataFiles), 1);

% Initialize Parallel Pool for Cleanline
if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

% Process each dataset in rawDataDir
for dataset_index = 1:length(rawDataFiles)
    % Dataset information
    loadName = rawDataFiles(dataset_index).name;
    dataName = loadName(1:10);
    % Split components of file name
    parts = split(dataName, '_');
    id = parts{1};
    session = parts{2};
    % Load Dataset and change dataset name
    EEG = pop_loadset(loadName,rawDataDir);
    % Remove Accelerometer Channels 
    EEG = pop_select(EEG, 'rmchannel',{'x_dir','y_dir','z_dir'});
    % Filter Dataset
    EEG  = pop_basicfilter(EEG, 1:EEG.nbchan,'Boundary','boundary','Cutoff',[0.1 30],...
        'Design','butter','Filter','bandpass','Order',2,'RemoveDC','on');
    % Cleanline to remove Line Noise 
    EEG = pop_cleanline(EEG, 'bandwidth', 2, 'chanlist', 1:EEG.nbchan,...
        'computepower', 1, 'linefreqs', 60, 'newversion', 1, 'normSpectrum', 0,...
        'p', 0.01, 'pad', 2, 'plotfigures', 0, 'scanforlines', 0, 'sigtype',...
        'Channels', 'taperbandwidth', 2, 'tau', 100, 'verb', 1, 'winsize', 4, 'winstep', 1);
    % Add channel locations
    EEG = pop_chanedit(EEG, 'lookup',elc_file,'eval','chans = pop_chancenter( chans, [],[]);');
    % Save Pre-ICA dataset
    EEG.setname = [dataName '_preICA'];
    EEG = pop_saveset(EEG,'filename',[dataName '_preICA'],'filepath',preICADataDir);

    % Plot pre-ICA dataset to get visual on data quality
    figure;
    pop_spectopo(EEG, 1, [0  EEG.pnts*2], 'EEG' , 'freq', [6 10 22], 'freqrange',[1 250],'electrodes','off');
    saveas(gcf,[preICA_PSD_Dir dataName '_preICA_PSD.png'])
    close

    % Identify channels that should be interpolated after ICA
    EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion',5,'ChannelCriterion',0.8,...
        'LineNoiseCriterion',4,'Highpass','off','BurstCriterion','off',...
        'WindowCriterion','off','BurstRejection','off','Distance','Euclidian');

    % Look for channels that have outlier PSDs
    [~, outlier_labels] = detect_eeg_outliers(EEG);
    % Remove channels with outlier PSDs (if they exist)
    if ~isempty(outlier_labels)
        EEG = pop_select(EEG, 'rmchannel', outlier_labels);
    end

    % Identify Removed Channels
    if length(EEG.chaninfo.removedchans) > 3
        % Extract labels directly using cell indexing
        removed_labels = {EEG.chaninfo.removedchans(4:end).labels}; % Skip 3 ACC chanels
        removed_channels_str = strjoin(removed_labels, ';');
        removed_channels_matrix = cell2mat({EEG.chaninfo.removedchans(4:end).urchan});
    else
        disp('EEGLAB did not identify any bad channels beyond Fp1 and Fp2.');
        removed_channels_str = '';
        removed_channels_matrix = [];
    end

    % Store in temporary variables (as in your original code)
    temp_ids{dataset_index} = id;
    temp_sessions{dataset_index} = session;
    temp_removed_channels{dataset_index} = removed_channels_str;
    temp_removed_channels_indices{dataset_index} = removed_channels_matrix;
end

% Combine temporary results of removed channels into final cell array
removed_channels_data = cell(length(rawDataFiles), 4);
for i = 1:length(rawDataFiles)
    removed_channels_data{i, 1} = temp_ids{i};
    removed_channels_data{i, 2} = temp_sessions{i};
    removed_channels_data{i, 3} = temp_removed_channels{i};
    removed_channels_data{i, 4} = temp_removed_channels_indices{i};
end

% Export Cell Array of Removed Channels to '../docs/' as .csv file
removed_channels_table = cell2table(removed_channels_data(:,1:3), ...
    'VariableNames', {'id', 'session', 'removed_channels'});
writetable(removed_channels_table, removed_channels_output_file, 'QuoteStrings', true);
% Export Cell Array at .mat file to access for interpolation after ICA
save ../data/erp/channels2interp.mat removed_channels_data

%% Step 2: ICA-based artifact correction

% Gather List of Datasets
preICADataFiles = dir([preICADataDir '*.set']);

parfor preICAdata_idx = 1:length(preICADataFiles)

    % Dataset Info
    loadName = preICADataFiles(preICAdata_idx).name;
    dataName = loadName(1:10);
    parts = split(dataName, '_');
    id = parts{1};
    session = parts{2};

    % Load Pre-ICA dataset
    EEG = pop_loadset('filename',loadName,'filepath',preICADataDir);
    % Extreme Filter (1-30, 48 dB/Octave rolloff)
    EEG  = pop_basicfilter(EEG, 1:EEG.nbchan, 'Boundary', 'boundary',...
        'Cutoff', [1 30], 'Design', 'butter', 'Filter', 'bandpass', 'Order', 8);
    % Remove Segments of Dataset (5s) with no significant data
    EEG  = pop_erplabDeleteTimeSegments(EEG,'afterEventcodeBufferMS',...
        1500, 'beforeEventcodeBufferMS', 500, 'displayEEG', 0,...
        'ignoreBoundary',  1, 'ignoreUseType', 'ignore', 'timeThresholdMS', 5000);
    % Save dataset 
    EEG.setname = [dataName '_ICApreproc'];
    EEG = pop_saveset(EEG,'filename', [dataName '_ICApreproc'],'filepath',icaArtifactCorrectionDir);

    % Run Extended Infomax ICA
    % Find channels that needed to be removed from ICA calculation
    row_idx = [];

    for i = 1:size(removed_channels_data, 1)
        if strcmp(removed_channels_data{i, 1}, id) && strcmp(removed_channels_data{i, 2}, session)
            row_idx = i;
            break;
        end
    end

    % Get the matrix from the 4th column of the matching row
    if ~isempty(row_idx)
        channels_matrix = removed_channels_data{row_idx, 4};
    else
        channels_matrix = [];
        warning('No matching id and session found in removed_channels_data');
    end

    % Remove specified channels from ICA calculation
    chanind = setdiff(1:64, channels_matrix);
    EEG = pop_runica(EEG, 'icatype', 'runica', 'chanind', chanind,...
        'extended',1,'rndreset','yes','interrupt','on');
    weights = EEG.icaweights;
    sphere = EEG.icasphere;
    icachansind = EEG.icachansind;

    % Run IC Label and save classification
    EEG = iclabel(EEG, 'default');
    ic_classification = EEG.etc.ic_classification;

    % Save Post-ICA Data
    EEG.setname = [dataName '_ICA'];
    EEG = pop_saveset(EEG,'filename',[dataName '_ICA'],'filepath',icaDataDir);

    % Transfer ICA weights and labels to pre-ICA dataset
    EEG = pop_loadset('filename',[dataName '_preICA.set'],'filepath',preICADataDir);
    EEG = pop_editset(EEG, 'icaweights', weights, 'icasphere', sphere, 'icachansind', icachansind);
    EEG.etc.ic_classification = ic_classification;
    
    % Flag Eye Labels 90%+
    EEG = pop_icflag(EEG,[NaN NaN;NaN NaN;0.9 1;NaN NaN;NaN NaN;NaN NaN;NaN NaN]);
    % Remove Flagged ICs
    EEG = pop_subcomp( EEG, [], 0);
    % Save Post-ICA dataset
    EEG.setname = [dataName '_postICA'];
    EEG = pop_saveset(EEG,'filename',[dataName '_postICA'],'filepath',postICADataDir);

end

%% Step 3: ICA-based artifact correction

% Gather List of Datasets
postICADataFiles = dir([postICADataDir '*.set']);

parfor postICAdata_idx = 1:length(postICADataFiles)

    % Extract Dataset Info to Pull Channels to Remove
    loadName = postICADataFiles(postICAdata_idx).name;
    dataName = loadName(1:10);
    % Split components of file name
    parts = split(dataName, '_');
    id = parts{1};
    session = parts{2};

    % Load Dataset
    EEG = pop_loadset(loadName,postICADataDir);

    % Channel Interpolation (using matrix in removed_channels_data)
    % Find the matching row in removed_channels_data
    row_idx = [];

    for i = 1:size(removed_channels_data, 1)
        if strcmp(removed_channels_data{i, 1}, id) && strcmp(removed_channels_data{i, 2}, session)
            row_idx = i;
            break;
        end
    end

    % Get the matrix from the 4th column of the matching row
    if ~isempty(row_idx)
        channels_matrix = removed_channels_data{row_idx, 4};
    else
        channels_matrix = [];
        warning('No matching id and session found in removed_channels_data');
    end
    
    % Channel Interpolation (using the found matrix)
    EEG = pop_interp(EEG, channels_matrix, 'spherical');
    % Common Average Re-reference Data
    EEG = pop_reref(EEG, []);
    % Save Data to Folder 6
    EEG.setname = [dataName '_postICApreprocess'];
    EEG = pop_saveset(EEG,'filename',[dataName '_postICApreprocess'],'filepath',processPostICADir)
    % Plot PSD of processed data and save
    figure;
    pop_spectopo(EEG, 1, [0  EEG.pnts*2], 'EEG' , 'freq', [6 10 22], 'freqrange',[1 250],'electrodes','off');
    saveas(gcf,[postICA_PSD_Dir dataName '_postICA_PSD.png'])
    close
end

%% Split Datasets
% Segment out pre-processed ERP datasets and save them to their
% respective folders in splitEpochDir

erp_files = dir(fullfile(processPostICADir, '*.set'));

if isempty(erp_files)
    fprintf('No .set files found in %s\n', processPostICADir);
    return;
end

% Create output directory if it doesn't exist
if ~exist(splitEpochDir, 'dir')
    mkdir(splitEpochDir);
end

fprintf('Found %d .set files to process\n', length(erp_files));

% Process each file
parfor i = 1:length(erp_files)
    input_file = fullfile(processPostICADir, erp_files(i).name);
    fprintf('\n=== Processing file %s ===\n', erp_files(i).name);
    try
        segment_erp_datasets(input_file, splitEpochDir);
    catch ME
        fprintf('Failed to process %s: %s\n', erp_files(i).name, ME.message);
        continue;
    end
end

fprintf('\n=== All datasets have been processed and segmented ===\n');