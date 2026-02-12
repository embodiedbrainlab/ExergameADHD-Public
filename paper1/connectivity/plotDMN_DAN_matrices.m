% PLOT ROI CONNECT MATRICES
% The final plot showcasing ROIconnect results will have minimized matrices
% showing average alpha power for each experience. 
%
% When we initially created the DMN/DAN values from ROIconnect, we only
% saved plots as .pngs. So we will load in the .mat file produced by the
% script ('statistical_modeling/reshapeROIconnect.m') and process the files
% accoridngly.
%
% The output should be 12 .fig (for reference) and 12 .svg figures to edit
% on illustrator. 
%
% If there is a way to add thick lines to the matrix to show distinct areas
% associated with the DMN/DAN, that would be great!
%
% Written by Noor Tasnim on November 1, 2025

%% Load .mat file
load('../statistical_modeling/results/DMN_DAN_connectivity.mat')

%% Replace EXGM108 and EXGM136 Go/No-Go Values with NaN
% These participants performed the task incorrectly, so their values will
% need to be replaced because it does not represent brain activity in
% response to the task.

% Find rows where column 1 is 'exgm108' OR 'exgm136' AND column 3 is 'gonogo'
for i = 1:size(new_connectivity_data, 1)
    % Check if first column matches either 'exgm108' or 'exgm136'
    first_col_match = strcmp(new_connectivity_data{i, 1}, 'exgm108') || ...
                      strcmp(new_connectivity_data{i, 1}, 'exgm136');
    
    % Check if third column matches 'gonogo'
    third_col_match = strcmp(new_connectivity_data{i, 3}, 'gonogo');
    
    % If both conditions are met, replace columns 7, 8, 9 with NaN
    if first_col_match && third_col_match
        new_connectivity_data{i, 7} = NaN;
        new_connectivity_data{i, 8} = NaN;
        new_connectivity_data{i, 9} = NaN;
    end
end

%% Create Figures

% Process connectivity data excluding diagonal (self-connectivity) values
% This reveals off-diagonal connectivity patterns by removing zeros on the diagonal

% Define the 12 unique experiences
experiences = {'digitbackward', 'digitforward', 'gonogo', 'prebaseline', ...
               'shoulder_1', 'shoulder_2', 'shoulder_3', 'stroop', ...
               'tandem_1', 'tandem_2', 'tandem_3', 'wcst'};

% Initialize storage for averaged matrices
averaged_matrices = cell(12, 1);

% Step 1: Calculate averaged matrices for each experience in alpha band
fprintf('Processing data and calculating averages...\n');
for i = 1:length(experiences)
    exp_name = experiences{i};
    
    % Find rows matching this experience AND alpha frequency
    mask = strcmp(new_connectivity_data(:, 3), exp_name) & ...
           strcmp(new_connectivity_data(:, 4), 'alpha');
    
    % Extract the 26x26 matrices for this condition
    matrices_for_exp = new_connectivity_data(mask, 6);
    
    if isempty(matrices_for_exp)
        warning('No data found for %s in alpha band', exp_name);
        averaged_matrices{i} = nan(26, 26);
        continue;
    end
    
    % Stack matrices and compute mean
    num_matrices = length(matrices_for_exp);
    matrix_stack = cat(3, matrices_for_exp{:});
    averaged_matrices{i} = mean(matrix_stack, 3);
    
    fprintf('  %s: averaged %d matrices\n', exp_name, num_matrices);
end

% Step 2: Create and save figures excluding diagonal values
fprintf('\nGenerating figures (diagonal excluded from visualization)...\n');
for i = 1:length(experiences)
    exp_name = experiences{i};
    
    if any(isnan(averaged_matrices{i}(:)))
        fprintf('  Skipping %s (no data)\n', exp_name);
        continue;
    end
    
    % Create a copy of the matrix and set diagonal to NaN
    matrix_no_diag = averaged_matrices{i};
    matrix_no_diag(logical(eye(26))) = NaN;
    
    % Get min and max EXCLUDING diagonal (for colorbar scaling)
    off_diag_values = matrix_no_diag(~isnan(matrix_no_diag));
    matrix_min = min(off_diag_values);
    matrix_max = max(off_diag_values);
    
    % Create figure
    fig = figure('Position', [100, 100, 800, 700], 'Color', 'white');
    
    % Plot the connectivity matrix (diagonal will appear white/gray)
    imagesc(matrix_no_diag);
    colormap('jet'); % Options: 'parula', 'hot', 'cool', 'viridis'
    
    % Set color limits based on off-diagonal values only
    clim([matrix_min, matrix_max]);
    
    % Create horizontal colorbar with minimal text
    cb = colorbar('Location', 'southoutside');
    cb.Label.String = '';  % No label
    cb.FontSize = 14;      % Larger font for readability
    
    % Show only min and max values
    cb.Ticks = [matrix_min, matrix_max];
    cb.TickLabels = {sprintf('%.3f', matrix_min), sprintf('%.3f', matrix_max)};
    
    % Add labels and title
    title(sprintf('%s (Alpha)', strrep(exp_name, '_', ' ')), ...
          'FontSize', 14, 'FontWeight', 'bold');
    xlabel('ROI', 'FontSize', 11);
    ylabel('ROI', 'FontSize', 11);
    axis square;
    
    % Set tick labels (1-26)
    set(gca, 'XTick', 1:26, 'YTick', 1:26, 'FontSize', 8);
    
    % Add thick black line after row/column 14 to divide matrix
    hold on;
    % Vertical line after column 14
    plot([14.5, 14.5], [0.5, 26.5], 'k-', 'LineWidth', 2.5);
    % Horizontal line after row 14
    plot([0.5, 26.5], [14.5, 14.5], 'k-', 'LineWidth', 2.5);
    hold off;
    
    % Save as .fig file
    fig_filename = sprintf('../results/DMN_DAN_plotting/%s_alpha_connectivity.fig', exp_name);
    savefig(fig, fig_filename);
    fprintf('  Saved: %s (off-diag range: %.4f to %.4f)\n', ...
            fig_filename, matrix_min, matrix_max);
    
    % Save as .svg file (high quality for publication)
    svg_filename = sprintf('../results/DMN_DAN_plotting/%s_alpha_connectivity.svg', exp_name);
    print(fig, svg_filename, '-dsvg', '-r300', '-vector');
    fprintf('  Saved: %s\n', svg_filename);
    
    % Close figure to free memory
    close(fig);
end

fprintf('\nProcessing complete!\n');
fprintf('All figures exclude diagonal (self-connectivity) values.\n');
fprintf('Each figure uses its own color scale based on off-diagonal connectivity.\n');

% Save the averaged matrices to a .mat file for future use
save('../results/DMN_DAN_plotting/averaged_connectivity_matrices.mat', 'averaged_matrices', 'experiences');
fprintf('Averaged matrices saved to: averaged_connectivity_matrices.mat\n');


