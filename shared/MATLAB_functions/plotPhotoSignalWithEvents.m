function plotPhotoSignalWithEvents(photo_signal, event_struct, fs)
% PLOTPHOTOSIGNALWITHEVENTS - Plots the photodiode signal with stimulus markers.
% This function is designed to help visualize the photodiode signal and
% the timing of stimulus events to aid in selecting an appropriate drop threshold.
%
% Inputs:
%   photo_signal - The raw photodiode signal time series.
%   event_struct - EEG structure (e.g., EEG) containing event info.
%   fs           - The sampling frequency in Hz.

    %% --- Parameters ---
    STIMULUS_CODE = 'Stimulus'; % The event code for the stimulus onset.

    %% --- Extract Stimulus Latencies ---
    % Get all event codes and their corresponding latencies from the structure
    all_codes = {event_struct.event.code};
    all_latencies = [event_struct.event.latency];
    
    % Find the latencies that specifically match the 'Stimulus' code
    stimulus_latencies = all_latencies(strcmp(all_codes, STIMULUS_CODE));

    %% --- Create Plot ---
    % Create a new figure window with a specific name and size
    figure('Name', 'Photodiode Signal Inspector', 'Position', [100, 100, 1200, 600]);
    
    % Create a time axis in seconds for the x-axis of the plot
    time_axis = (0:length(photo_signal)-1) / fs;
    
    % Plot the main photodiode signal
    plot(time_axis, photo_signal, 'b-');
    hold on; % Keep the plot active to add more elements
    
    % Mark each stimulus event with a vertical red dashed line
    % This loop iterates through all found stimulus latencies
    for i = 1:length(stimulus_latencies)
        % xline creates a vertical line at the specified x-position
        % We convert the latency from samples to seconds by dividing by fs
        xline(stimulus_latencies(i)/fs, 'r--', 'LineWidth', 1.5);
    end
    
    %% --- Finalize Plot ---
    % Add labels and a title for clarity
    xlabel('Time (s)');
    ylabel('Photodiode Signal Value');
    title('Photodiode Signal with Stimulus Event Markers');
    
    % Add a legend to identify the plotted lines
    legend('Photodiode Signal', 'Stimulus Events', 'Location', 'best');
    
    % Add a grid for easier reading of values
    grid on;
    
    % Release the plot
    hold off;

end
