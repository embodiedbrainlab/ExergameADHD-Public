function [outlier_indices, outlier_labels] = detect_eeg_outliers(EEG, varargin)
% DETECT_EEG_OUTLIERS - GPU-accelerated power spectrum analysis with outlier detection
%
% Syntax:
%   [outlier_indices, outlier_labels] = detect_eeg_outliers(EEG)
%   [outlier_indices, outlier_labels] = detect_eeg_outliers(EEG, 'Parameter', Value)
%
% Inputs:
%   EEG - EEGLAB data structure with fields:
%         .data - [channels x time points] EEG data
%         .chanlocs - channel location structure with .label field
%         .srate - sampling rate
%
% Optional Parameters:
%   'outlier_method' - Method for outlier detection ('zscore', 'iqr', 'mad')
%                      Default: 'zscore'
%   'threshold' - Threshold for outlier detection (default: 3 for zscore, 1.5 for iqr)
%   'freq_range' - Frequency range for analysis [f_min f_max] (default: [1 50])
%
% Outputs:
%   outlier_indices - Row indices of outlier channels
%   outlier_labels - Cell array of channel labels for outliers

    % Parse input arguments
    p = inputParser;
    addRequired(p, 'EEG', @isstruct);
    addParameter(p, 'outlier_method', 'zscore', @ischar);
    addParameter(p, 'threshold', [], @isnumeric);
    addParameter(p, 'freq_range', [1 50], @isnumeric);
    
    parse(p, EEG, varargin{:});
    
    % Extract parameters
    outlier_method = p.Results.outlier_method;
    threshold = p.Results.threshold;
    freq_range = p.Results.freq_range;
    
    % Set default threshold values
    if isempty(threshold)
        switch outlier_method
            case 'zscore'
                threshold = 3;
            case 'iqr'
                threshold = 1.5;
            case 'mad'
                threshold = 3;
        end
    end
    
    % Validate inputs
    if ~isfield(EEG, 'data') || ~isfield(EEG, 'chanlocs') || ~isfield(EEG, 'srate')
        error('EEG structure must contain data, chanlocs, and srate fields');
    end
    
    [n_channels, n_timepoints] = size(EEG.data);
    
    if length(EEG.chanlocs) ~= n_channels
        error('Number of channels in data does not match chanlocs');
    end
    
    fprintf('Processing %d channels with %d time points...\n', n_channels, n_timepoints);
    
    % Check GPU availability
    if gpuDeviceCount > 0
        gpu_available = true;
        fprintf('GPU detected and will be used for processing.\n');
    else
        gpu_available = false;
        warning('No GPU detected. Falling back to CPU processing.');
    end
    
    % Set pwelch parameters as specified
    NFFT = EEG.srate;
    OVERLAP = EEG.srate/2;
    WINDOW = EEG.srate;
    
    fprintf('Using pwelch parameters: WINDOW=%d, OVERLAP=%d, NFFT=%d\n', WINDOW, OVERLAP, NFFT);
    fprintf('Data length per channel: %d samples\n', n_timepoints);
    
    % Check if window length is appropriate
    if WINDOW > n_timepoints
        warning('Window length (%d) is greater than data length (%d). This will cause pwelch to fail.', WINDOW, n_timepoints);
        fprintf('Consider using a shorter window or more data.\n');
        outlier_indices = [];
        outlier_labels = {};
        return;
    end
    
    % Transfer data to GPU if available
    if gpu_available
        try
            eeg_data_gpu = gpuArray(EEG.data);
            fprintf('Data successfully transferred to GPU.\n');
        catch ME
            warning('Failed to transfer data to GPU: %s. Using CPU.', ME.message);
            gpu_available = false;
        end
    end
    
    % Calculate power spectra for each channel
    fprintf('Calculating power spectra for %d channels...\n', n_channels);
    
    % Process first channel to get frequency vector and initialize arrays
    if gpu_available
        [psd_temp, freqs] = pwelch(eeg_data_gpu(1, :), WINDOW, OVERLAP, NFFT, EEG.srate);
        freqs = gather(freqs);
        psd_temp = gather(psd_temp);
    else
        [psd_temp, freqs] = pwelch(EEG.data(1, :), WINDOW, OVERLAP, NFFT, EEG.srate);
    end
    
    % Initialize spectra matrix [frequencies x channels]
    spectra = zeros(length(freqs), n_channels);
    spectra(:, 1) = psd_temp;
    
    % Process remaining channels
    for ch = 2:n_channels
        if mod(ch, 10) == 0
            fprintf('Processing channel %d/%d\n', ch, n_channels);
        end
        
        if gpu_available
            [psd, ~] = pwelch(eeg_data_gpu(ch, :), WINDOW, OVERLAP, NFFT, EEG.srate);
            spectra(:, ch) = gather(psd);
        else
            [psd, ~] = pwelch(EEG.data(ch, :), WINDOW, OVERLAP, NFFT, EEG.srate);
            spectra(:, ch) = psd;
        end
    end
    
    fprintf('Power spectra calculated for all channels.\n');
    
    % Filter frequency range of interest
    freq_idx = freqs >= freq_range(1) & freqs <= freq_range(2);
    spectra_analysis = spectra(freq_idx, :);  % [frequencies x channels]
    freq_analysis = freqs(freq_idx);
    
    fprintf('Analyzing frequency range: %.1f - %.1f Hz (%d frequency bins)\n', ...
        freq_range(1), freq_range(2), sum(freq_idx));
    
    % Calculate total power in frequency band for each channel
    % spectra is [frequencies x channels], so sum along frequency dimension
    total_power = sum(spectra_analysis, 1)';  % Transpose to get [channels x 1]
    
    % Detect outliers based on chosen method
    fprintf('Detecting outliers using %s method (threshold: %.2f)...\n', outlier_method, threshold);
    
    switch outlier_method
        case 'zscore'
            % Z-score method
            z_scores = abs(zscore(total_power));
            outlier_mask = z_scores > threshold;
            
        case 'iqr'
            % Interquartile range method
            Q1 = prctile(total_power, 25);
            Q3 = prctile(total_power, 75);
            IQR = Q3 - Q1;
            lower_bound = Q1 - threshold * IQR;
            upper_bound = Q3 + threshold * IQR;
            outlier_mask = total_power < lower_bound | total_power > upper_bound;
            
        case 'mad'
            % Median absolute deviation method
            median_power = median(total_power);
            mad_power = mad(total_power, 1);
            outlier_mask = abs(total_power - median_power) > threshold * mad_power;
            
        otherwise
            error('Unknown outlier detection method: %s', outlier_method);
    end
    
    % Extract outlier information
    outlier_indices = find(outlier_mask);
    outlier_labels = cell(length(outlier_indices), 1);
    
    for i = 1:length(outlier_indices)
        idx = outlier_indices(i);
        if idx <= length(EEG.chanlocs) && isfield(EEG.chanlocs, 'labels')
            outlier_labels{i} = EEG.chanlocs(idx).labels;
        elseif idx <= length(EEG.chanlocs) && isfield(EEG.chanlocs, 'label')
            outlier_labels{i} = EEG.chanlocs(idx).label;
        else
            outlier_labels{i} = sprintf('Channel_%d', idx);
        end
    end
    
    % Display results
    fprintf('\n=== Outlier Detection Results ===\n');
    fprintf('Method: %s (threshold: %.2f)\n', outlier_method, threshold);
    fprintf('Frequency range: %.1f - %.1f Hz\n', freq_range(1), freq_range(2));
    fprintf('Total outliers found: %d out of %d channels (%.1f%%)\n', ...
        length(outlier_indices), n_channels, 100*length(outlier_indices)/n_channels);
    
    if ~isempty(outlier_indices)
        fprintf('\nOutlier channels:\n');
        for i = 1:length(outlier_indices)
            fprintf('  Index %2d: %-10s (Total Power: %.2e)\n', ...
                outlier_indices(i), outlier_labels{i}, total_power(outlier_indices(i)));
        end
    else
        fprintf('No outlier channels detected.\n');
    end
    
    % Clean up GPU memory
    if gpu_available && exist('eeg_data_gpu', 'var')
        clear eeg_data_gpu;
    end
    
    fprintf('\nAnalysis complete.\n');
end