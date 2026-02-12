function [all_lags_ms] = calculatePhotoDiodeLag(photo_signal, event_struct, fs, drop_threshold)
% CALCULATEPHOTODIODELAG - A simple function to find the lag between a 
% stimulus marker and a photodiode signal drop.
%
% Inputs:
%   photo_signal - The raw photodiode signal time series.
%   event_struct - EEG event structure (e.g., EEG) with .event.code and .event.latency fields.
%   fs           - The sampling frequency in Hz.
%   drop_threshold - A numeric threshold value that the photodiode signal 
%                    must cross in a downward direction to be identified as a drop event.
%                    Ex. 1.15e5
%
% Outputs:
%   all_lags_ms  - A vector of all individual lags found (in ms).

%% --- Parameters ---
SEARCH_WINDOW_S = 0.05;     % Search for the drop within 50 ms after the stimulus marker.
STIMULUS_CODE = 'Stimulus'; % The event code for the stimulus onset.

%% --- Extract Stimulus Latencies ---
search_window_samples = round(SEARCH_WINDOW_S * fs);

% Extract all event codes and latencies
all_codes = {event_struct.event.code};
all_latencies = [event_struct.event.latency];

% Find the latencies corresponding to the stimulus code
stimulus_latencies = all_latencies(strcmp(all_codes, STIMULUS_CODE));
num_stimuli = length(stimulus_latencies);

fprintf('Found %d ''%s'' events.\n', num_stimuli, STIMULUS_CODE);

%% --- Find Lags for Each Stimulus ---
all_lags_samples = []; % Initialize an empty array for lags in samples

for i = 1:num_stimuli
    stim_sample = stimulus_latencies(i);
    
    % Define the search window for this specific stimulus
    search_start = stim_sample;
    search_end = min(stim_sample + search_window_samples, length(photo_signal));
    
    % Extract the signal segment in the search window
    signal_window = photo_signal(search_start:search_end);
    
    % Find the first sample that drops BELOW the threshold
    % We look for the point where the previous sample was above the threshold
    % and the current one is below.
    drop_index = find(signal_window(1:end-1) > drop_threshold & signal_window(2:end) < drop_threshold, 1, 'first');
    
    if ~isempty(drop_index)
        % The drop_index is relative to the start of the signal_window.
        % The lag is simply this index, as the window starts at the stimulus onset.
        lag_in_samples = drop_index;
        all_lags_samples = [all_lags_samples; lag_in_samples];
    else
        fprintf('Warning: No drop found for stimulus at sample %d.\n', stim_sample);
    end
end

%% --- Calculate and Display Results ---
if ~isempty(all_lags_samples)
    % Convert lags from samples to milliseconds
    all_lags_ms = (all_lags_samples / fs) * 1000;
    
    % Calculate summary statistics
    mean_lag_ms = mean(all_lags_ms);
    std_lag_ms = std(all_lags_ms);
    median_lag_ms = median(all_lags_ms);
    
    fprintf('\n--- Lag Analysis Summary ---\n');
    fprintf('Successfully calculated lag for %d / %d events.\n', length(all_lags_ms), num_stimuli);
    fprintf('Average Lag: %.2f ms\n', mean_lag_ms);
    fprintf('Standard Deviation: %.2f ms\n', std_lag_ms);
    fprintf('Median Lag: %.2f ms\n', median_lag_ms);
    fprintf('Lag Range: %.2f ms to %.2f ms\n', min(all_lags_ms), max(all_lags_ms));

    % Plot the distribution of lags
    % figure;
    % histogram(all_lags_ms);
    % title('Distribution of Photodiode Lags');
    % xlabel('Lag (ms)');
    % ylabel('Frequency');
    % grid on;
    
else
    fprintf('\n--- No valid lags were found. ---\n');
    mean_lag_ms = NaN;
    all_lags_ms = [];
end

end