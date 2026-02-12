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
preICADataDir = '../data/erp/2_pre_ICA_data/';
icaArtifactCorrectionDir = '../data/erp/3_ICA_decomposition_data/';
icaDataDir = '../data/erp/4_ICA_weights_data/';
postICADataDir = '../data/erp/5_post_ICA_data/';
processPostICADir = '../data/erp/6_processing_post_ICA/';
postICA_PSD_Dir = '../data/erp/6_processing_post_ICA/psd/';
splitEpochDir = '../data/erp/7_split_and_epoch/';

% Load removed_channels_data variable
load ../data/erp/extrachannels2interp.mat

%% Step 2: ICA-based artifact correction

% Gather List of Datasets
preICADataFiles = dir([preICADataDir '*.set']);

for preICAdata_idx = 1:length(preICADataFiles)

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

% Initialize Parallel Pool for Cleanline
if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

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