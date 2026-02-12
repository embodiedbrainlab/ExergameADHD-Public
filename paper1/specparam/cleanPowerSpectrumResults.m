% CLEANING POWER SPECTRUM RESULTS FOR SPECPARAM - SESSION 1
% Power spectra for independent components that were successfully clustered
% were saved to `../results/exergame_session1_PowerSpectrumResults.mat`
%
% However, it is important to only include datasets where participants
% conducted the task according to instructions. Based on ERP analyses, all
% participants seemed to have performed according to instructions provided
% for the Stroop and WCST tasks. An initial review of the digit span tasks
% shows that most people were trying their best on either backward/forward
% task.
% 
% 2 participants did not follow instructions on the Go/No-Go task and 
% these specfic datasets will need to be removed from analysis.
%
% These participants include:
%   - exgm108
%   - exgm136
% 
% Written by Noor Tasnim on 8.29.2025

%% Import EEGLAB Functions
eeglab
close
clear

%% Load .mat File
load ../results/exergame_session1_PowerSpectrumResults.mat

%% Find Row of data that has
% Remove rows where subject is 'exgm108' or 'exgm136' AND experience is 'gonogo'
% Create logical index for rows to keep (inverse of rows to remove)
rows_to_remove = (strcmp({results.subject}, 'exgm108') | strcmp({results.subject}, 'exgm136')) & ...
                 strcmp({results.experience}, 'gonogo');

% Keep all rows that don't match the removal criteria
rows_to_keep = ~rows_to_remove;

% Create new filtered structure
results_filtered = results(rows_to_keep);

% Save removed rows to separate structure for inspection
results_removed = results(rows_to_remove);

% Display summary
fprintf('Original structure had %d rows\n', length(results));
fprintf('Filtered structure has %d rows\n', length(results_filtered));
fprintf('Removed %d rows\n', sum(rows_to_remove));

% Display details of removed rows
if sum(rows_to_remove) > 0
    fprintf('\nRemoved rows details:\n');
    for i = 1:length(results_removed)
        fprintf('Row %d: subject = %s, experience = %s\n', i, results_removed(i).subject, results_removed(i).experience);
    end
else
    fprintf('No rows were removed\n');
end

%% Save .mat file with different name to be processed through specparam

save('../results/exergame_session1_PowerSpectrumResults_FILTERED.mat',...
    'results_filtered', '-v7.3')