% PLOT PSDs BEFORE/AFTER ICA
% Combined sedentary datasets from Session 1 and 2 were preprocessed using
% exergamePreprocess.m; however, we never checked their data quality any
% time during the pre-processing process.
%
% The following scripts take the combined pre-ICA datasets and plots their
% respective PSDs to ensure no faulty channels were included in the ICA,
% given how much they can affect ICA decomposition.

%% Import EEGLAB Functions

eeglab;
close
clear

%% Gather files
% session1_postICA_files = dir('..\preprocessed_data\session1\postICA\*.set');
% session2_postICA_files = dir('..\preprocessed_data\session2\sedentary\postICA\*.set');
% postICA_files = [session1_postICA_files; session2_postICA_files];

preICA_files = dir('..\preprocessed_eeg_data\session_2\intervention\preICA\*.set');

%% Activate parallel processing
if isempty(gcp('nocreate'))
    parpool('local', min(8, feature('numcores'))); % Use up to 8 workers
end

%% Go through each path and create PSDs

parfor dataset_Idx = 1:length(preICA_files)
    EEG = pop_loadset(preICA_files(dataset_Idx).name,preICA_files(dataset_Idx).folder)
    dataName = erase(preICA_files(dataset_Idx).name,'.set');
    figure;
    pop_spectopo(EEG, 1, [0  EEG.pnts*2], 'EEG' , 'freq', [6 10 22 35 45], 'freqrange',[1 60],'electrodes','off');
    saveas(gcf,[preICA_files(dataset_Idx).folder '\psd\' dataName '_preICA_PSD.png'])
    close
end