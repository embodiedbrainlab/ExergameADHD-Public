% DETERMINING DELAY IN STIMULI FOR ERP ANALYSIS
% Executive function was assessed through a series of computer task
% administered through Inquisit Lab. An ERP analysis will be conducted for
% the following three tasks:
%   1. Wisconsin Card Sort Task
%   2. Stroop Task
%   3. Go/No-Go Task
%
% It is likely that the computer delivered an stimulus ('S') signal to 
% our EEG triggerbox before the actual stimulus appeared on the screen.
% This is an expected lag and typically accounted for in robust ERP
% studies.
%
% Thus, I used a photodiode provided by BrainVision (Photo Sensor) to track
% changes in color on the screen during the tasks. They recorded data as
% AUX1 and AUX2 on the provided dataset.
%   - AUX1 was located on the middle of the monitor to pick up changes in 
%   light for Go/No-Go and Stroop
%   - AUX2 was located on the middle of the left border of the presented 
%   stimulus card. This was done because the middle of most stimulus was white
%   and we would not be able to detect a color change. Note that screen 
%   flashed white after each trial and then all cards reappeared, 
%   so the photosensor should have picked up when the stimulus appeared 
%   on the screen. Vertical placement of the photodiode affects lag, but
%   placing it on the middle of the left border vertically aligns with the
%   center of the card.
%
% Total recordings:
%   - WCST: 6
%   - Stroop: 6
%   - Go/No-Go: 4
%
% Edited by Noor Tasnim on July 22, 2025

%% Import EEGLAB functions
eeglab;
close
clear

%% WCST
% We are mainly interested in the data collected from AUX2 (Channel 34)

wcst_files = dir('../data/photoTesting/wcst/set_format/*.set');

wcst_lag_arrays = cell(1,length(wcst_files));

for wcst_idx = 1:length(wcst_files)
    % Photo Diode PSD (to confirm Refresh Rate of 50 Hz)
    plotPhotoDiodePSD(wcst_files(wcst_idx).name, wcst_files(wcst_idx).folder);
    % Load EEG Dataset for Processing
    EEG = pop_loadset(wcst_files(wcst_idx).name, wcst_files(wcst_idx).folder);
    % Plot PhotoDiode Signal with Stimuli
    plotPhotoSignalWithEvents(EEG.data(34,:), EEG, EEG.srate);
    % Save Plot and Close
    savefig(['../results/erp/photodiode_testing/wcst_diodeStimuli_' num2str(wcst_idx) '.fig']);
    close
    % Calculate Lags between PhotoDiode Drop and Stimuli
    wcst_lag_arrays{wcst_idx} = calculatePhotoDiodeLag(EEG.data(34,:), EEG, EEG.srate, 1.26e5);
end

% Compile Lags for a Comprehensive Historgram
wcst_lags = vertcat(wcst_lag_arrays{:});
figure
histogram(wcst_lags, 50, 'FaceColor', 'blue', 'EdgeColor', 'black');
title('Histogram of All WCST Lag Arrays Combined ');
xlabel('Lags (ms)');
ylabel('Frequency');
saveas(gcf, '../results/erp/photodiode_testing/wcst_lag_histogram.png')
close

% Calculate Average of Histogram
fprintf('Total number of WCST lags calculated: %d\n', length(wcst_lags));
fprintf('Mean: %.3f, Std: %.3f, Mode: %.3f\n\n', mean(wcst_lags), std(wcst_lags), mode(wcst_lags));

%% Stroop
% We are mainly interested in the data collected from AUX1 (Channel 33)

stroop_files = dir('../data/photoTesting/stroop/set_format/*.set');

stroop_lag_arrays = cell(1,length(stroop_files));

for stroop_idx = 1:length(stroop_files)
    % Photo Diode PSD (to confirm Refresh Rate of 50 Hz)
    plotPhotoDiodePSD(stroop_files(stroop_idx).name, stroop_files(stroop_idx).folder);
    % Load EEG Dataset for Processing
    EEG = pop_loadset(stroop_files(stroop_idx).name, stroop_files(stroop_idx).folder);
    % Plot PhotoDiode Signal with Stimuli
    plotPhotoSignalWithEvents(EEG.data(33,:), EEG, EEG.srate);
    % Save Plot and Close
    savefig(['../results/erp/photodiode_testing/stroop_diodeStimuli_' num2str(stroop_idx) '.fig']);
    close
    % Calculate Lags between PhotoDiode Drop and Stimuli
    stroop_lag_arrays{stroop_idx} = calculatePhotoDiodeLag(EEG.data(33,:), EEG, EEG.srate, 1.4e5);
end

% Compile Lags for a Comprehensive Historgram
stroop_lags = vertcat(stroop_lag_arrays{:});
figure
histogram(stroop_lags, 50, 'FaceColor', 'blue', 'EdgeColor', 'black');
title('Histogram of All STROOP Lag Arrays Combined ');
xlabel('Lags (ms)');
ylabel('Frequency');
saveas(gcf, '../results/erp/photodiode_testing/stroop_lag_histogram.png')
close

% Calculate Average of Histogram
fprintf('Total number of STROOP lags calculated: %d\n', length(stroop_lags));
fprintf('Mean: %.3f, Std: %.3f, Mode: %.3f\n\n', mean(stroop_lags), std(stroop_lags), mode(stroop_lags));


%% Go/No-Go
% The cues were also marked as stimuli, but because they were blank white
% rectangles, we can't tell when their onset was on the photo diode. Thus,
% we'll only focus the actual color presentation of green and blue.
%
% We will still use the data from AUX1 (center of the screen)

gonogo_files = dir('../data/photoTesting/gonogo/set_format/*.set');

gonogo_lag_arrays = cell(1,length(gonogo_files));
gonogo_stimulus_specific_arrays = cell(1,length(gonogo_files));

for gonogo_idx = 1:length(gonogo_files)
    
    % Photo Diode PSD (to confirm Refresh Rate of 50 Hz)
    plotPhotoDiodePSD(gonogo_files(gonogo_idx).name, gonogo_files(gonogo_idx).folder);

    % Load EEG Dataset for Processing
    EEG = pop_loadset(gonogo_files(gonogo_idx).name, gonogo_files(gonogo_idx).folder);

    % Remove Cue Stimuli
    cleaned_gonogo = EEG;
    all_codes = {cleaned_gonogo.event.code};
    all_types = {cleaned_gonogo.event.type};
    % Find all events that are 'Stimulus'
    isStimulusEvent = strcmp(all_codes, 'Stimulus');
    % Find all events with type 'S  1' or 'S  3'
    isUnwantedType = strcmp(all_types, 'S  1') | strcmp(all_types, 'S  3');
    % Combine the masks: an event is removed if it is a 'Stimulus' AND has an unwanted type
    events_to_remove_mask = isStimulusEvent & isUnwantedType;
    % Invert the mask to get the events to KEEP
    events_to_keep_mask = ~events_to_remove_mask;
    % Apply the mask to the event structure
    % This keeps only the elements where the mask is true (1)
    EEG.event = cleaned_gonogo.event(events_to_keep_mask); 
    fprintf('Go/No-Go Stimulus Cleaning Summary:\n');
    fprintf('-----------------------\n');
    fprintf('Original number of events: %d\n', length(all_codes));
    fprintf('Number of cue stimuli removed: %d\n', sum(events_to_remove_mask));
    fprintf('Remaining number of events: %d\n', length(EEG.event));

    % Plot PhotoDiode Signal with Stimuli
    plotPhotoSignalWithEvents(EEG.data(33,:), EEG, EEG.srate);
    % Save Plot and Close
    savefig(['../results/erp/photodiode_testing/gonogo_diodeStimuli_' num2str(gonogo_idx) '.fig']);
    close

    % Calculate Lags between PhotoDiode Drop and Stimuli (now with stimulus-specific analysis)
    [gonogo_lag_arrays{gonogo_idx}, gonogo_stimulus_specific_arrays{gonogo_idx}] = ...
        calculateGoNoGoLag(EEG.data(33,:), EEG, EEG.srate, 1.4e5);
end

%% Compile Overall Lags for Comprehensive Histogram
gonogo_lags = vertcat(gonogo_lag_arrays{:});
figure
histogram(gonogo_lags, 50, 'FaceColor', 'blue', 'EdgeColor', 'black');
title('Histogram of All GO/NO-GO Lag Arrays Combined ');
xlabel('Lags (ms)');
ylabel('Frequency');
saveas(gcf, '../results/erp/photodiode_testing/gonogo_lag_histogram.png')
close

% Calculate Average of Overall Histogram
fprintf('Total number of GO/NO-GO lags calculated: %d\n', length(gonogo_lags));
fprintf('Overall Mean: %.3f, Std: %.3f, Mode: %.3f\n\n', mean(gonogo_lags), std(gonogo_lags), mode(gonogo_lags));

%% Compile and Analyze Stimulus-Specific Lags
stimulus_labels = {'S7_HorizontalNoGo', 'S9_VerticalNoGo', 'S13_VerticalGo', 'S15_HorizontalGo'};
stimulus_descriptions = {'Horizontal No-Go (S  7)', 'Vertical No-Go (S  9)', ...
                        'Vertical Go (S 13)', 'Horizontal Go (S 15)'};

% Initialize combined stimulus-specific arrays
combined_stimulus_lags = struct();
for i = 1:length(stimulus_labels)
    combined_stimulus_lags.(stimulus_labels{i}) = [];
end

% Combine lags across all files for each stimulus type
for gonogo_idx = 1:length(gonogo_files)
    if ~isempty(gonogo_stimulus_specific_arrays{gonogo_idx})
        for i = 1:length(stimulus_labels)
            field_name = stimulus_labels{i};
            if isfield(gonogo_stimulus_specific_arrays{gonogo_idx}, field_name)
                combined_stimulus_lags.(field_name) = [combined_stimulus_lags.(field_name); ...
                    gonogo_stimulus_specific_arrays{gonogo_idx}.(field_name)];
            end
        end
    end
end

%% Display Combined Stimulus-Specific Results
fprintf('\n=== COMBINED STIMULUS-SPECIFIC LAG ANALYSIS ===\n');
fprintf('================================================\n');

stimulus_means = [];
stimulus_stds = [];

for i = 1:length(stimulus_labels)
    field_name = stimulus_labels{i};
    lags = combined_stimulus_lags.(field_name);
    
    if ~isempty(lags)
        fprintf('\n%s:\n', stimulus_descriptions{i});
        fprintf('  Total Count: %d\n', length(lags));
        fprintf('  Mean: %.3f ms\n', mean(lags));
        fprintf('  Std: %.3f ms\n', std(lags));
        fprintf('  Median: %.3f ms\n', median(lags));
        fprintf('  Range: %.3f to %.3f ms\n', min(lags), max(lags));
        
        stimulus_means = [stimulus_means; mean(lags)];
        stimulus_stds = [stimulus_stds; std(lags)];
    else
        fprintf('\n%s: No valid lags found\n', stimulus_descriptions{i});
        stimulus_means = [stimulus_means; NaN];
        stimulus_stds = [stimulus_stds; NaN];
    end
end

%% Create Stimulus-Specific Visualization
figure('Position', [100, 100, 1200, 800]);

% Individual histograms for each stimulus type
colors = {'red', 'blue', 'green', 'magenta'};
hold on;
for i = 1:length(stimulus_labels)
    field_name = stimulus_labels{i};
    lags = combined_stimulus_lags.(field_name);
    if ~isempty(lags)
        histogram(lags, 'FaceColor', colors{i}, 'FaceAlpha', 0.6, 'EdgeColor', 'black');
    end
end
title('Stimulus-Specific Lag Distributions');
xlabel('Lag (ms)');
ylabel('Frequency');
legend(stimulus_descriptions, 'Location', 'best');
grid on;

% Save the combined figure
saveas(gcf, '../results/erp/photodiode_testing/gonogo_stimulus_specific.png');
close;

%% Save Lags
save ../results/erp/photodiode_testing/photodiodeLags.mat wcst_lags stroop_lags gonogo_lags...
    gonogo_stimulus_specific_arrays