function plotPhotoDiodePSD(fileName, filePath)
%plotPhotoDiodePSD Loads an EEG .set file, calculates the Power Spectral
%Density (PSD) for two auxiliary channels, plots the result, and saves it.
%
%   INPUTS:
%   fileName    (string) - The name of the .set file (e.g., 'gonogo_1.set').
%   filePath    (string) - The path to the directory containing the file.
%
%   EXAMPLE USAGE:
%   plotPhotoDiodePSD('gonogo_1.set', '../data/photoTesting/gonogo/set_format/');

% --- Load Data ---
% Use the pop_loadset function from EEGLAB to load the dataset
EEG = pop_loadset('filename', fileName, 'filepath', filePath);

% --- Extract Signals ---
% Extract the signal data from auxiliary channels 33 and 34
aux1_signal = EEG.data(33, :);
aux2_signal = EEG.data(34, :);

% --- Calculate Power Spectral Density ---
% Use Welch's method to estimate the PSD for each signal
[psd1, f1] = pwelch(aux1_signal, [], [], [], EEG.srate);
[psd2, f2] = pwelch(aux2_signal, [], [], [], EEG.srate);

% --- Plotting ---
% Create a new figure to avoid overwriting existing plots
figure;

% Plot the PSD for both signals on a semi-logarithmic scale
semilogy(f1, psd1, 'LineWidth', 1.5);
hold on;
semilogy(f2, psd2, 'LineWidth', 1.5);
hold off;

% --- Customize Plot ---
% Use fileparts to get the base name of the file for the title
[~, name, ~] = fileparts(fileName);
% Use strrep to prevent underscores from being interpreted as subscripts
title(['PhotoDiode Power Spectral Density: ', strrep(name, '_', ' ')]);
xlabel('Frequency (Hz)');
ylabel('Power Spectral Density ($V^2/Hz$)');
legend('AUX1', 'AUX2');
grid on;

% --- Save Figure ---
% Define the output directory
outputDir = '../results/erp/photodiode_testing/';

% Create the directory if it does not already exist
if ~exist(outputDir, 'dir')
   mkdir(outputDir);
end

% Construct the full path for the output .png file
outputFileName = fullfile(outputDir, [name, '_PSD.png']);

% Save the current figure
saveas(gcf, outputFileName);

% Close the figure window
close;

% Display a confirmation message to the user
fprintf('Plot saved successfully to: %s\n', outputFileName);

end