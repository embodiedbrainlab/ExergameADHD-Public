% Replace EXGM169 S1 Go/No-Go ROIconnect values
% The weights from the original dataset could not transfer to specparam,
% however, ROIconnect was still able to create matrices for the dataset.
%
% On Nov. 1, 2025, we resplit the original pre-processed dataset and 
% ran ROIconnect again. The script will replace values of exgm169_gonogo_s1
% in connectivity_matrices with the corrected values from the double-check
% run, so that we can run `reshapeROIconnect.m` in preparation for statistical
% analysis.
%
% Written by Noor Tasnim on November 1, 2025
% Updated on November 2, 2025

%% Load .mat files
fprintf('Loading connectivity matrices...\n');
load('../data/roiconnect/session1/session1_vectors/connectivity_matrices.mat')
load('../data/roiconnect/session1/session1_vectors/exgm169_gonogo_s1_matrices_DoubleCheck.mat')

% Rename the mislabeled variable
exgm169matrices = s2_intervention_connectivity_matrices;
clear s2_intervention_connectivity_matrices;

% Define the search criteria
subject_id = 'exgm169';
session = '1';
experience = 'gonogo';
frequency_bands = {'theta', 'alpha', 'low_beta', 'high_beta', 'gamma'};

fprintf('Replacing connectivity matrices for %s, session %s, experience %s...\n', ...
    subject_id, session, experience);

% Counter for successful replacements
num_replaced = 0;

% Replace matrices for each frequency band
for i = 1:length(frequency_bands)
    freq_band = frequency_bands{i};
    
    % Find matching row in connectivity_matrices (destination)
    idx_dest = find_matching_row(connectivity_matrices, subject_id, session, experience, freq_band);
    
    % Find matching row in exgm169matrices (source)
    idx_source = find_matching_row(exgm169matrices, subject_id, session, experience, freq_band);
    
    % Check if both rows were found
    if isempty(idx_dest)
        warning('Row not found in connectivity_matrices for frequency band: %s', freq_band);
        continue;
    end
    if isempty(idx_source)
        warning('Row not found in exgm169matrices for frequency band: %s', freq_band);
        continue;
    end
    
    % Extract connectivity matrices
    old_matrix = connectivity_matrices{idx_dest, 5};
    new_matrix = exgm169matrices{idx_source, 5};
    
    % Verify dimensions (should be 68x68)
    if ~isequal(size(old_matrix), size(new_matrix)) || ~isequal(size(old_matrix), [68, 68])
        warning('Matrix dimension mismatch for frequency band: %s (expected 68x68)', freq_band);
        fprintf('  Old matrix size: %dx%d\n', size(old_matrix, 1), size(old_matrix, 2));
        fprintf('  New matrix size: %dx%d\n', size(new_matrix, 1), size(new_matrix, 2));
        continue;
    end
    
    % Replace the matrix
    connectivity_matrices{idx_dest, 5} = new_matrix;
    num_replaced = num_replaced + 1;
    
    fprintf('  ✓ Replaced %s band (row %d)\n', freq_band, idx_dest);
end

fprintf('\nReplacement complete: %d out of %d frequency bands replaced.\n', ...
    num_replaced, length(frequency_bands));

%% Save the updated connectivity_matrices
output_filename = '../data/roiconnect/session1/session1_vectors/connectivity_matrices_updated.mat';
fprintf('\nSaving updated connectivity matrices to: %s\n', output_filename);

save(output_filename, 'connectivity_matrices');

fprintf('✓ File saved successfully!\n');
fprintf('\nSummary:\n');
fprintf('  - Original file: connectivity_matrices.mat\n');
fprintf('  - Updated file: connectivity_matrices_updated.mat\n');
fprintf('  - Subject: %s\n', subject_id);
fprintf('  - Session: %s\n', session);
fprintf('  - Experience: %s\n', experience);
fprintf('  - Frequency bands replaced: %d/%d\n', num_replaced, length(frequency_bands));

%% Helper function to find matching row
function idx = find_matching_row(cellArray, subject_id, session, experience, freq_band)
    % Find row that matches all criteria
    idx = [];
    
    for i = 1:size(cellArray, 1)
        if strcmp(cellArray{i, 1}, subject_id) && ...
           strcmp(cellArray{i, 2}, session) && ...
           strcmp(cellArray{i, 3}, experience) && ...
           strcmp(cellArray{i, 4}, freq_band)
            idx = i;
            return;
        end
    end
end
