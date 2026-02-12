function [all_lags_ms, stimulus_specific_lags] = calculateGoNoGoLag(photo_signal, event_struct, fs, drop_threshold)
%CALCULATEGONOGOLAG - Finds the lag between a stimulus marker and a photodiode drop.
%
% This function is specifically designed for cases where the photodiode drop
% might occur slightly BEFORE or AFTER the stimulus marker. It searches in a
% symmetric window around each stimulus event. Now also calculates
% stimulus-specific lags for Go/No-Go task stimuli.
%
% A positive lag means the drop occurred AFTER the stimulus marker.
% A negative lag means the drop occurred BEFORE the stimulus marker.
%
% Inputs:
%   photo_signal    - The raw photodiode signal time series.
%   event_struct    - EEG event structure with .event.code and .event.latency fields.
%   fs              - The sampling frequency in Hz.
%   drop_threshold  - A numeric threshold value for detecting the drop.
%
% Outputs:
%   all_lags_ms           - A vector of all individual lags found (in ms).
%   stimulus_specific_lags - A structure containing lags for each stimulus type:
%                           .S7 (Horizontal No-Go)
%                           .S9 (Vertical No-Go)  
%                           .S13 (Vertical Go)
%                           .S15 (Horizontal Go)

%% --- Parameters ---
% Define a symmetric search window around the stimulus marker (e.g., +/- 20ms)
SEARCH_RADIUS_MS = 20; 
STIMULUS_CODE = 'Stimulus'; 

% Define the stimulus types we're interested in
TARGET_STIMULUS_TYPES = {'S  7', 'S  9', 'S 13', 'S 15'};
STIMULUS_LABELS = {'S7_HorizontalNoGo', 'S9_VerticalNoGo', 'S13_VerticalGo', 'S15_HorizontalGo'};

%% --- Extract Stimulus Latencies ---
search_radius_samples = round(SEARCH_RADIUS_MS * fs / 1000);

all_codes = {event_struct.event.code};
all_latencies = [event_struct.event.latency];
all_types = {event_struct.event.type};

% Find stimulus events
stimulus_mask = strcmp(all_codes, STIMULUS_CODE);
stimulus_latencies = all_latencies(stimulus_mask);
stimulus_types = all_types(stimulus_mask);

fprintf('Found %d ''%s'' events to analyze.\n', length(stimulus_latencies), STIMULUS_CODE);

%% --- Initialize storage for stimulus-specific results ---
stimulus_specific_lags = struct();
for i = 1:length(TARGET_STIMULUS_TYPES)
    field_name = STIMULUS_LABELS{i};
    stimulus_specific_lags.(field_name) = [];
end

%% --- Find Lags for Each Stimulus ---
all_lags_samples = []; 

for i = 1:length(stimulus_latencies)
    stim_sample = stimulus_latencies(i);
    stim_type = stimulus_types{i};
    
    % Define the search window centered on the stimulus sample
    search_start = stim_sample - search_radius_samples;
    search_end = stim_sample + search_radius_samples;
    
    % Ensure the search window is within the bounds of the signal
    if search_start < 1 || search_end > length(photo_signal)
        fprintf('Warning: Stimulus %d (%s) is too close to the edge of the recording. Skipping.\n', i, stim_type);
        continue;
    end
    
    signal_window = photo_signal(search_start:search_end);
    
    % Find the first sample that drops BELOW the threshold within the window
    drop_index_in_window = find(signal_window(1:end-1) > drop_threshold & signal_window(2:end) < drop_threshold, 1, 'first');
    
    if ~isempty(drop_index_in_window)
        % The stimulus marker is at the center of our window. The index for the
        % center is search_radius_samples + 1.
        % The lag is the difference between the drop's position and the center.
        lag_in_samples = drop_index_in_window - (search_radius_samples + 1);
        all_lags_samples = [all_lags_samples; lag_in_samples];
        
        % Store stimulus-specific lag
        stimulus_idx = find(strcmp(TARGET_STIMULUS_TYPES, stim_type));
        if ~isempty(stimulus_idx)
            field_name = STIMULUS_LABELS{stimulus_idx};
            lag_in_ms = (lag_in_samples / fs) * 1000;
            stimulus_specific_lags.(field_name) = [stimulus_specific_lags.(field_name); lag_in_ms];
        end
    else
        fprintf('Warning: No drop found for stimulus %s at sample %d within the +/- %d ms window.\n', stim_type, stim_sample, SEARCH_RADIUS_MS);
    end
end

%% --- Calculate and Display Results ---
if ~isempty(all_lags_samples)
    all_lags_ms = (all_lags_samples / fs) * 1000;
    
    mean_lag_ms = mean(all_lags_ms);
    std_lag_ms = std(all_lags_ms);
    median_lag_ms = median(all_lags_ms);
    
    fprintf('\n--- Go/No-Go Lag Analysis Summary ---\n');
    fprintf('Successfully calculated lag for %d events.\n', length(all_lags_ms));
    fprintf('Overall Average Lag: %.2f ms\n', mean_lag_ms);
    fprintf('Overall Standard Deviation: %.2f ms\n', std_lag_ms);
    fprintf('Overall Median Lag: %.2f ms\n', median_lag_ms);
    fprintf('Overall Lag Range: %.2f ms to %.2f ms\n', min(all_lags_ms), max(all_lags_ms));
    
    %% --- Display Stimulus-Specific Results ---
    fprintf('\n--- Stimulus-Specific Lag Analysis ---\n');
    stimulus_descriptions = {'Horizontal No-Go (S  7)', 'Vertical No-Go (S  9)', ...
                           'Vertical Go (S 13)', 'Horizontal Go (S 15)'};
    
    for i = 1:length(STIMULUS_LABELS)
        field_name = STIMULUS_LABELS{i};
        lags = stimulus_specific_lags.(field_name);
        
        if ~isempty(lags)
            fprintf('%s:\n', stimulus_descriptions{i});
            fprintf('  Count: %d\n', length(lags));
            fprintf('  Mean: %.2f ms\n', mean(lags));
            fprintf('  Std: %.2f ms\n', std(lags));
            fprintf('  Range: %.2f to %.2f ms\n', min(lags), max(lags));
        else
            fprintf('%s: No valid lags found\n', stimulus_descriptions{i});
        end
    end

    % Plot the distribution of positive and negative lags
    % figure('Name', 'Go/No-Go Lag Distribution');
    % histogram(all_lags_ms);
    % hold on;
    % xline(0, 'k--', 'LineWidth', 2, 'Label', 'Stimulus Onset');
    % xline(mean_lag_ms, 'r--', 'LineWidth', 2, 'Label', sprintf('Mean Lag: %.2f ms', mean_lag_ms));
    % title('Distribution of Photodiode Lags (Positive & Negative)');
    % xlabel('Lag (ms)');
    % ylabel('Frequency');
    % grid on;
    % legend('', '', 'Mean Lag', 'Location', 'best');
    
else
    fprintf('\n--- No valid lags were found. ---\n');
    all_lags_ms = [];
end

end