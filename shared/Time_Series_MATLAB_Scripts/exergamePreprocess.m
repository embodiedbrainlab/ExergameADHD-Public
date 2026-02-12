% PREPROCESS EXERGAME AND ADHD DATA
% This script was developed based on Makoto's suggested pre-processing
% pipeline. Note that in addition to using AMICA, it still attempts 
% to perform dipole fitting through the information gained through ICA.

%% Import EEGLAB Functions
eeglab;
clear
close

%% Define File Paths
combinedDatasetsDir = '../data/combined_datasets/';
eeglab_path = 'C:\Users\ntasnim\Documents\eeglab2025.0.0\';
elc_file = append(eeglab_path,'plugins/dipfit/standard_BEM/elec/standard_1005.elc');
removed_channels_output_file = '../docs/removed_channels.csv';
session1_preICA_path = '../preprocessed_eeg_data/session_1/preICA/';
session1_postICA_path = '../preprocessed_eeg_data/session_1/postICA/';
session2_preICA_path = '../preprocessed_eeg_data/session_2/sedentary/preICA/';
session2_postICA_path = '../preprocessed_eeg_data/session_2/sedentary/postICA/';

%% Begin Preprocessing

% Gather List of Datasets
rawDataFiles = dir([combinedDatasetsDir '*.set']);

% Preallocate temporary arrays for collecting results
temp_ids = cell(length(rawDataFiles), 1);
temp_sessions = cell(length(rawDataFiles), 1);
temp_removed_channels = cell(length(rawDataFiles), 1);

% Initialize Parallel Pool
if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

% Loop through each dataset for pre-processing using parallel processing
parfor dataset_index = 1:length(rawDataFiles) 
    loadName = rawDataFiles(dataset_index).name;
    dataName = loadName(1:end-4);

    % Step 1: Split components of file name
    parts = split(dataName, '_');
    id = parts{1};
    session = str2double(erase(parts{2},'s'));

    % Step 2: Import data and edit dataset information
    EEG = pop_loadset('filename',loadName,'filepath',combinedDatasetsDir);
    % add information to dataset for EEGLAB Study
    EEG = pop_editset(EEG,'subject',id,'session',session);
    EEG.setname = dataName;

    % Step 3: Remove Accelerometer Channels 
    EEG = pop_select( EEG, 'nochannel',{'x_dir','y_dir','z_dir'});
    
    % Step 4: Bandpass filter 1-55 Hz
    EEG = pop_eegfiltnew(EEG, 'locutoff',1,'hicutoff',55);

    % Step 5: Import Channel Locations
    EEG = pop_chanedit(EEG, 'lookup',elc_file,'eval','chans = pop_chancenter( chans, [],[]);');
    chanlocs = EEG.chanlocs; % saving channel locations for later use

    % Step 6: Remove Bad Channels
    EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion',5,'ChannelCriterion',0.8,...
        'LineNoiseCriterion',4,'Highpass','off','BurstCriterion','off',...
        'WindowCriterion','off','BurstRejection','off','Distance','Euclidian');

    % Identify Removed Channels
    if length(EEG.chaninfo.removedchans) > 3
        % Extract labels directly using cell indexing
        removed_labels = {EEG.chaninfo.removedchans(4:end).labels}; % Skip first 3 (acc channels)
        removed_channels_str = strjoin(removed_labels, ';');
    else
        disp('EEGLAB did not identify any bad channels.');
        removed_channels_str = '';
    end

    % Store in temporary variables
    temp_ids{dataset_index} = id;
    temp_sessions{dataset_index} = session;
    temp_removed_channels{dataset_index} = removed_channels_str;

    % Step 7: Correct Data with ASR
    EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion','off','ChannelCriterion','off',...
        'LineNoiseCriterion','off','Highpass','off','BurstCriterion',20,...
        'WindowCriterion','off','BurstRejection','off','Distance','Euclidian');

    % Step 8: Interpolate all the removed channels if channel rejection is applied. Otherwise, this line does not do anything.
    EEG = pop_interp(EEG, chanlocs, 'spherical');
 
    % Step 9: Re-reference the data to average
    % We ideally want to keep as many ICs as possible for ICA
    % So we had a "zero" channel to represented FCz before re-referencing
    % This prevents us from losing 1 rank value

    EEG.nbchan = EEG.nbchan+1;
    EEG.data(end+1,:) = zeros(1, EEG.pnts);
    EEG.chanlocs(1,EEG.nbchan).labels = 'initialReference';
    EEG = pop_reref(EEG, []);
    EEG = pop_select( EEG,'nochannel',{'initialReference'}); % removes the zero channel we created

    % Save the dataset before AMICA
    if session == 1
        EEG = pop_saveset(EEG, 'filename', dataName, 'filepath', session1_preICA_path);
    elseif session == 2
        EEG = pop_saveset(EEG, 'filename', dataName, 'filepath', session2_preICA_path);
    else
        error('Incompatible session number entered. Should be 1 or 2')
    end

    % Step 10: Run AMICA using calculated data rank with 'pcakeep' option
    dataRank = sum(eig(cov(double(EEG.data'))) > 1E-6); % 1E-6 follows pop_runica() line 531, changed from 1E-7.
    numprocs = 1; % # of nodes
    max_threads = 1; % # of threads
    num_models = 1; % # of models of mixture ICA

    % run amica - will iterate 2000 times (default value)
    [weights,sphere,mods] = runamica15(EEG.data, 'num_models',num_models,...
        'numprocs', numprocs, 'max_threads',max_threads,'outdir',dataName,'pcakeep',dataRank,...
        'do_reject', 1, 'numrej', 15, 'rejsig', 3, 'rejint', 1);

    % Load Temporary AMICA Output to Save with Dataset
    EEG.etc.amica  = loadmodout15(dataName);
    EEG.icaweights = weights;
    EEG.icasphere  = sphere;
    EEG = eeg_checkset(EEG, 'ica');

    % Step 11: Estimate single equivalent current dipoles
    % Note: if ft_datatype_raw() complains about channel numbers, comment out (i.e. put % letter in the line top) line 88 as follows
    % assert(size(data.trial{i},1)==length(data.label), 'inconsistent number of channels in trial %d', i);
    EEG = pop_dipfit_settings( EEG, 'hdmfile','standard_vol.mat','mrifile','standard_mri.mat','chanfile','standard_1005.elc',...
    'coordformat','MNI','coord_transform',[0.942769 -16.9024 1.46263 2.88665e-07 -2.19759e-08 -1.5708 1 1 1]);
    EEG = pop_multifit(EEG, 1:EEG.nbchan,'threshold', 100, 'dipplot','off','plotopt',{'normlen' 'on'});

    % % Step 12: Search for and estimate symmetrically constrained bilateral dipoles
    % % Note this is from Piazza et al. (2016), which has insights on the
    % % value of using ICs for source localization
    EEG = fitTwoDipoles(EEG, 'LRR', 35);

    % Step 13: Run ICLabel (Pion-Tonachini et al., 2019)
    EEG = iclabel(EEG, 'default');

    % Step 15: Save the dataset
    if session == 1
        EEG = pop_saveset(EEG, 'filename', dataName, 'filepath', session1_postICA_path);
    elseif session == 2
        EEG = pop_saveset(EEG, 'filename', dataName, 'filepath', session2_postICA_path);
    else
        error('Incompatible session number entered. Should be 1 or 2')
    end

end

%% Combine temporary results into final cell array
removed_channels_data = cell(length(rawDataFiles), 3);
for i = 1:length(rawDataFiles)
    removed_channels_data{i, 1} = temp_ids{i};
    removed_channels_data{i, 2} = temp_sessions{i};
    removed_channels_data{i, 3} = temp_removed_channels{i};
end

%% Export Cell Array of Removed Channels to '../docs/'
removed_channels_table = cell2table(removed_channels_data, ...
    'VariableNames', {'id', 'session', 'removed_channels'});
writetable(removed_channels_table, removed_channels_output_file, 'QuoteStrings', true);