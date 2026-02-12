% RESHAPING ROICONNECT MATRICES FOR STATISTICAL ANALYSIS
% ROIconnect by default provides a 68x68 connectivity matrix across 34 ROIs
% definied by the Desikan-Killany atlas for each hemisphere.
%
% During the calculation for Session 1, we included a .mat file that
% contained this 68x68 matrix for each participant x freq_band x
% experience. However, By creating the long form of this matrix, for each
% frequency band and experience, LASSO (L1 Regularization) won't be able to
% handle this many features for our small sample size.
%
% So we needed an intentional way to reduce the dimensionality of this
% matrix. Kabbara et al. (2017) grouped regions from the DK atlas into the
% DMN and DAN for their analysis. We will omit FPN from our analysis
% because its regions overlap with DMN and DAN (Dixon et al. 2018)
%
% Thus, we will need to select specific rows from the matrix and create a
% 26x26 matrix. To review the documentation on new row numbers, go to the !
% Statisitcal Modelling folder in the Exergame and ADHD Google Drive
% Folder.
%
% Our initial hypothesis discussed connectivity between the DMN and DAN
% regions. Thus, we'll create averages using the raw MIM for the following
% 3 measures for each frequency_band x experience combination:
%   1. Within DMN connectivity
%   2. Within DAN connectivity
%   3. DMN-DAN connectivity
%
% So when we have a wide formatted data frame for our participants, columns
% will have the following naming convention:
%   {measure}_{frequencyBand}_{experience}
%
% So in total, we should have 3*5*12 columns from this computation.
%
% We should also summarize these values in a grpah before putting them into
% a model. X-axis can be experiencies, y-axis can be ONE of the three
% measures, fill can be frequency bands. So we can have three plots total
% for summarizing purposes (also good for checking if we should average
% across the balance tasks).
%
% Another output should be the new 26x26 matrix for each frequency band x
% experience combination saved to Google Drive.
%
% Note: As valuable as graph theory metrics are for individual points, you
% never collected an MRI for your participants, so all of these values are
% approximations. Thus, it would be best to simply average values for each
% network and only present the three measurements stated above.
%
% Author: Noor Tasnim
% Written on: October 2, 2025
% Last Edited: November 2, 2025 to account for exgm169_s1_gonogo IC weights

%% Load ROIconnect matrices
load ../data/roiconnect/session1/session1_vectors/connectivity_matrices_updated.mat

%% Load ROI information
% Read the ROI mapping information from CSV
roi_table = readtable('../docs/DMN_DAN_ROIs.csv');
roi_names = roi_table.roi_names;
original_indices = roi_table.original_index;
new_indices = roi_table.new_index;

% Verify the ROI mapping
fprintf('Loaded %d ROIs for extraction\n', height(roi_table));
fprintf('DMN regions (indices 1-14): %d regions\n', sum(new_indices <= 14));
fprintf('DAN regions (indices 15-26): %d regions\n', sum(new_indices > 14));

%% Initialize the new cell array
num_rows = size(connectivity_matrices, 1);

% Create new cell array with additional columns
% Original: id, session, task, freq_band, 68x68_matrix
% New: id, session, task, freq_band, 68x68_matrix, 26x26_matrix, DMN_conn, DAN_conn, DMN_DAN_conn
new_connectivity_data = cell(num_rows, 9);

% Copy original data
new_connectivity_data(:, 1:5) = connectivity_matrices;

%% Set output directory for plots
output_dir = '/Users/noor/Library/CloudStorage/GoogleDrive-ntasnim@vt.edu/Shared drives/Embodied Brain Lab/Exergame and ADHD (IRB 23-811)/! ROI Connect/session1/session1_figures/figures/roiconnect/DMN_DAN_matrices/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% Process each connectivity matrix
fprintf('\nProcessing %d connectivity matrices...\n', num_rows);

for i = 1:num_rows
    % Get the current 68x68 matrix
    matrix_68 = connectivity_matrices{i, 5};
    
    % Extract the 26x26 matrix using specified indices
    matrix_26 = zeros(26, 26);
    
    % Map from original to new indices
    for row_idx = 1:26
        for col_idx = 1:26
            % Get original indices for this position
            orig_row = original_indices(new_indices == row_idx);
            orig_col = original_indices(new_indices == col_idx);
            
            % Extract the value from the 68x68 matrix
            matrix_26(row_idx, col_idx) = matrix_68(orig_row, orig_col);
        end
    end
    
    % Store the 26x26 matrix
    new_connectivity_data{i, 6} = matrix_26;
    
    %% Calculate network connectivity measures
    
    % 1. Within-DMN connectivity (rows/cols 1:14)
    dmn_submatrix = matrix_26(1:14, 1:14);
    % Extract upper triangle (excluding diagonal) for within-network connectivity
    dmn_upper = triu(dmn_submatrix, 1);
    dmn_connectivity = mean(dmn_upper(dmn_upper ~= 0));
    
    % 2. Within-DAN connectivity (rows/cols 15:26)
    dan_submatrix = matrix_26(15:26, 15:26);
    dan_upper = triu(dan_submatrix, 1);
    dan_connectivity = mean(dan_upper(dan_upper ~= 0));
    
    % 3. DMN-DAN connectivity (rows 1:14, cols 15:26)
    dmn_dan_submatrix = matrix_26(1:14, 15:26);
    dmn_dan_connectivity = mean(dmn_dan_submatrix(:));
    
    % Store connectivity measures
    new_connectivity_data{i, 7} = dmn_connectivity;
    new_connectivity_data{i, 8} = dan_connectivity;
    new_connectivity_data{i, 9} = dmn_dan_connectivity;
    
    %% Plot and save the 26x26 matrix
    fig = figure('Position', [100, 100, 1200, 1000], 'Visible','off');
    
    % Create heatmap with ROI labels
    h = heatmap(matrix_26);
    
    % Set labels - reorder based on new indices
    ordered_labels = cell(26, 1);
    for j = 1:26
        idx = find(new_indices == j);
        ordered_labels{j} = roi_names{idx};
    end
    
    h.XDisplayLabels = ordered_labels;
    h.YDisplayLabels = ordered_labels;
    
    % Set colormap to jet
    colormap(jet);
    
    % Add grid lines to separate DMN and DAN
    h.GridVisible = 'on';
    
    % Save the figure
    filename = sprintf('%s/%s_s%s_%s_%s.png', ...
        output_dir, ...
        num2str(new_connectivity_data{i, 1}), ...
        num2str(new_connectivity_data{i, 2}), ...
        num2str(new_connectivity_data{i, 3}), ...
        num2str(new_connectivity_data{i, 4}));
    
    saveas(fig, filename);
    close(fig); % closing the invisible figure
    
    % Progress indicator
    if mod(i, 10) == 0
        fprintf('Processed %d/%d matrices\n', i, num_rows);
    end
end

fprintf('Completed processing all matrices\n');

%% Create CSV output (without matrices)
% Prepare data for CSV export
csv_data = cell(num_rows, 7);
csv_data(:, 1:4) = new_connectivity_data(:, 1:4);  % id, session, task, freq_band
csv_data(:, 5:7) = new_connectivity_data(:, 7:9);  % DMN, DAN, DMN-DAN connectivity

% Convert to table with proper column names
output_table = cell2table(csv_data, ...
    'VariableNames', {'id', 'session_number', 'task', 'frequency_band', ...
                      'DMN_connectivity', 'DAN_connectivity', 'DMN_DAN_connectivity'});

% Write to CSV
output_filename = 'results/connectivity_analysis_results.csv';
writetable(output_table, output_filename);
fprintf('\nResults exported to %s\n', output_filename);

%% Save New Cell Array of Connectivity Data
save results/DMN_DAN_connectivity.mat new_connectivity_data

%% Summary statistics
fprintf('\n=== Summary Statistics ===\n');
dmn_values = cell2mat(new_connectivity_data(:, 7));
dan_values = cell2mat(new_connectivity_data(:, 8));
dmn_dan_values = cell2mat(new_connectivity_data(:, 9));

fprintf('Within-DMN Connectivity:\n');
fprintf('  Mean: %.4f, SD: %.4f, Range: [%.4f, %.4f]\n', ...
    mean(dmn_values), std(dmn_values), min(dmn_values), max(dmn_values));

fprintf('Within-DAN Connectivity:\n');
fprintf('  Mean: %.4f, SD: %.4f, Range: [%.4f, %.4f]\n', ...
    mean(dan_values), std(dan_values), min(dan_values), max(dan_values));

fprintf('DMN-DAN Connectivity:\n');
fprintf('  Mean: %.4f, SD: %.4f, Range: [%.4f, %.4f]\n', ...
    mean(dmn_dan_values), std(dmn_dan_values), min(dmn_dan_values), max(dmn_dan_values));

%% Code Completion Messages
fprintf('\n=== Script completed successfully ===\n');
fprintf('Output files:\n');
fprintf('  - CSV results: %s\n', output_filename);
fprintf('  - Plots saved in: %s/\n', output_dir);
fprintf('  - Workspace variable: new_connectivity_data\n');