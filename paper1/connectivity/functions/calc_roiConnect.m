function [FCmatrixdata,connectivity_vector] = calc_roiConnect(filename,filepath,freqBand)
%CALC_ROICONNECT Use ROIconnect EEGLAB Add-On to calculate MIM FC
%   For ROIconnect to work best, we need as many dipoles
%   identified within the dataset as possible. Thus, we are using exergame
%   datasets where 90% noise classification was removed (muslce, eye, line noise,
%   other, etc.). 
%
%   IMPORTANT: This function should only be used on datasets that have already had
%   noisy ICs removed and have been split into their respective
%   experiences. 
%
%   This script runs the ROIconnect calculation, which, by default, plots
%   the 68x68 connectivity matrix using the Colin Head model
%   (Desikan-Killany atlas). 
%
%   Once plotted, the function pulls the numeric values from the figure and
%   store them as [FCmatrixdata], which the researcher can save or plot
%   elsewhere.
%
%   Inputs:
%       - [filename] - string value of EEG dataset name (.set file)
%       - [filepath] - where the dataset is located
%       - [freqBand] - the frequency band whose connectivity you would like
%                      to calculate. Acceptable values are:
%                           - 'theta' (4 to 8 Hz)
%                           - 'alpha' (8 to 12 Hz)
%                           - 'low_beta' (12 to 20 Hz)
%                           - 'high_beta' (20 to 30 Hz)
%                           - 'gamma' (30 to 50 Hz)
%
%   Written by Noor Tasnim on September 5, 2025

%% Load Dataset
EEG = pop_loadset('filepath',filepath,'filename',filename);
dataName = filename(1:end-4);

%% Calculate Leadfield
EEG = pop_leadfield(EEG, 'sourcemodel','C:/Users/ntasnim/Documents/eeglab2025.0.0/functions/supportfiles/head_modelColin27_5003_Standard-10-5-Cap339.mat',...
    'sourcemodel2mni',[0 -24 -45 0 0 -1.5708 1000 1000 1000] ,'downsample',1);

%% ROI Activity (Source Reconstruction)
EEG = pop_roi_activity(EEG, 'resample',100,'model','LCMV','modelparams',...
    {0.05},'atlas','Desikan-Kilianny','nPCA',3);

%% ROI Connectivity
EEG = pop_roi_connect(EEG, 'morder',20,'methods',{'MIM'});

%% Visualizations - Connectivity
% FC as region-to-region matrix
% We will plot whole connectome as a 68 x 68 matrix
% Once the matrix is plotted, we'll extract the data as FCmatrixdata for
% comparison

% Determine Frequency Band for calculation
switch freqBand
    case 'theta'
        freqrange = [4 8];
    case 'alpha'
        freqrange = [8 12];
    case 'low_beta'
        freqrange = [12 20];
    case 'high_beta'
        freqrange = [20 30];
    case 'gamma'
        freqrange = [30 50];
    otherwise
        error('Invalid frequency band entered. Please check documentation for proper inputs.')
end

% Plotting Connectivity Matrix
pop_roi_connectplot(EEG, 'measure', 'mim', 'plotcortex', 'off',...
    'plotmatrix', 'on', 'freqrange', freqrange, 'grouphemispheres', 'on');
% Save Matrix as .fig and .png
savefig(append('results/figures/roiconnect/MATLABfig/',dataName,'_',freqBand,'.fig'))
saveas(gcf,append('results/figures/roiconnect/png/',dataName,'_',freqBand,'.png'))

% Extract Connectivity Values
fig = gcf;
ax = fig.CurrentAxes;
img = findobj(ax, 'Type', 'Image');
FCmatrixdata = img.CData; % 68x68 connectivity matrix

% Create Vector of Unique Connectivity Values for ML Algorithm
upper_tri_indices = triu(true(68, 68), 1);  % logical mask, k=1 excludes diagonal
connectivity_vector = FCmatrixdata(upper_tri_indices);  % 2278x1 vector

close