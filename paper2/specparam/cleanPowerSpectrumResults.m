% CLEANING POWER SPECTRUM RESULTS FOR SPECPARAM - SESSION 1 and 2
% Power spectra for independent components that were successfully clustered
% were saved to `E:\Tasnim_Dissertation_Analysis\specparam_analysis\Paper 2\sedentary\results`
%
% However, it is important to only include datasets where participants
% conducted the task according to instructions. Based on ERP analyses, all
% participants seemed to have performed according to instructions provided
% for the Stroop and WCST tasks. An initial review of the digit span tasks
% shows that most people were trying their best on either backward/forward
% task.
% 
% 3 participants did not follow instructions on the Go/No-Go task and 
% these specfic datasets will need to be removed from analysis.
%
% These participants include:
%   - exgm108_s1
%   - exgm136_s1
%   - exgm021_s2
% 
% Written by Noor Tasnim on 8.29.2025
% -----------------------------------
% Edited by Noor on 11.14.2025 for Paper 2 analysis

%% Import EEGLAB Functions
eeglab
close
clear

%% Load .mat File
load 'E:\Tasnim_Dissertation_Analysis\specparam_analysis\Paper 2\sedentary\results\exergame_Paper2sedentary_PowerSpectrumResults.mat'

%% Remove rows with specific subject/session/experience combinations:
% Participants below did not perform Go/No-Go correctly
% - exgm108, s1, gonogo
% - exgm136, s1, gonogo
% - exgm021, s2, gonogo

% Create logical index for each specific combination to remove
remove_exgm108 = strcmp({results.subject}, 'exgm108') & ...
                 strcmp({results.session}, 's1') & ...
                 strcmp({results.experience}, 'gonogo');

remove_exgm136 = strcmp({results.subject}, 'exgm136') & ...
                 strcmp({results.session}, 's1') & ...
                 strcmp({results.experience}, 'gonogo');

remove_exgm021 = strcmp({results.subject}, 'exgm021') & ...
                 strcmp({results.session}, 's2') & ...
                 strcmp({results.experience}, 'gonogo');

% Combine all removal criteria
rows_to_remove = remove_exgm108 | remove_exgm136 | remove_exgm021;

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
        fprintf('Row %d: subject = %s, session = %s, experience = %s\n', ...
                i, results_removed(i).subject, results_removed(i).session, results_removed(i).experience);
    end
else
    fprintf('No rows were removed\n');
end

%% Save .mat file with different name to be processed through specparam

save('E:\Tasnim_Dissertation_Analysis\specparam_analysis\Paper 2\sedentary\results\exergame_Paper2sedentary_PowerSpectrumResults_FILTERED.mat',...
    'results_filtered', '-v7.3')