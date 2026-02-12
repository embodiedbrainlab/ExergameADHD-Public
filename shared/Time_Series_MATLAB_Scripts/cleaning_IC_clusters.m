% CLEANING IC CLUSTERS
% MATLAB Script for Processing EEG Independent Component Cluster CSV Files
% This script works with the outputs generated from extractICclusters.m
% It processes CSV files containing EEG IC cluster data by:
% 1. Replacing session numbers with descriptive names (e.g. 'baseline','intervention')
% 2. Handling bipolar dipole coordinates by removing the furthest coordinate
% 3. Keeping only one component per dataset (highest IC_brain_label)
% 4. Saving processed files to '../results/IC_clusters/pruned_clusters/'
%
% Edited by Noor Tasnim on August 27, 2025

%% Setup directories
input_dir = '../results/IC_clusters';
output_dir = '../results/IC_clusters/pruned_clusters';

% Create output directory if it doesn't exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
    fprintf('Created output directory: %s\n', output_dir);
end

%% Get list of CSV files
csv_files = dir(fullfile(input_dir, '*.csv'));
fprintf('Found %d CSV files to process\n', length(csv_files));

%% Process each CSV file
for file_idx = 1:length(csv_files)
    filename = csv_files(file_idx).name;
    input_filepath = fullfile(input_dir, filename);
    [~, name, ~] = fileparts(filename);
    output_filepath = fullfile(output_dir, [name '_prune.csv']);
    
    fprintf('\nProcessing file %d/%d: %s\n', file_idx, length(csv_files), filename);
    
    try
        % Read the CSV file
        data = readtable(input_filepath);
        fprintf('  - Loaded %d rows\n', height(data));
        
        % Step 2: Replace session values
        data = replace_session_values(data);
        
        % Step 3: Handle bipolar coordinates
        data = process_bipolar_coordinates(data);
        
        % Step 4: Keep only one component per dataset
        data = keep_best_component_per_dataset(data);
        
        % Save processed data
        writetable(data, output_filepath);
        fprintf('  - Saved processed file with %d rows\n', height(data));
        
    catch ME
        fprintf('  - ERROR processing %s: %s\n', filename, ME.message);
        continue;
    end
end

fprintf('\nProcessing complete!\n');

%% Function to replace session values
function data = replace_session_values(data)
    % Replace session numbers with descriptive names
    
    % Check if session column is numeric or cell/string
    if isnumeric(data.session)
        % Convert numeric session values to cell array of strings
        new_session = cell(height(data), 1);
        for i = 1:height(data)
            switch data.session(i)
                case 1
                    new_session{i} = 's1';
                case 2
                    new_session{i} = 's2';
                otherwise
                    new_session{i} = sprintf('session_%d', data.session(i));
            end
        end
        data.session = new_session;
    else
        % Handle case where session is already cell/string array
        for i = 1:height(data)
            current_val = data.session(i);
            if iscell(current_val)
                current_val = current_val{1};
            end
            
            % Convert to number if it's a string representation
            if ischar(current_val) || isstring(current_val)
                num_val = str2double(current_val);
                if ~isnan(num_val)
                    current_val = num_val;
                end
            end
            
            switch current_val
                case 1
                    data.session{i} = 's1';
                case 2
                    data.session{i} = 's2';
                otherwise
                    if isnumeric(current_val)
                        data.session{i} = sprintf('session_%d', current_val);
                    else
                        data.session{i} = char(current_val);
                    end
            end
        end
    end
    
    fprintf('  - Replaced session values\n');
end

%% Function to process bipolar coordinates
function data = process_bipolar_coordinates(data)
    bipolar_count = 0;
    
    % Ensure MNI_coord is a cell array
    if ~iscell(data.MNI_coord)
        if isstring(data.MNI_coord) || ischar(data.MNI_coord)
            data.MNI_coord = cellstr(data.MNI_coord);
        else
            error('MNI_coord column format not recognized');
        end
    end
    
    for i = 1:height(data)
        coord_str = data.MNI_coord{i};
        
        % Convert to string if it's not already
        if ~ischar(coord_str) && ~isstring(coord_str)
            coord_str = char(coord_str);
        end
        
        % Check if this is a bipolar coordinate (contains semicolon)
        if contains(coord_str, ';')
            bipolar_count = bipolar_count + 1;
            
            % Parse the bipolar coordinates
            coords = parse_bipolar_coordinates(coord_str);
            
            if size(coords, 1) == 2
                % Calculate which coordinate to keep based on cluster average
                best_coord = select_best_coordinate(coords, data, i);
                
                % Format back to string
                data.MNI_coord{i} = sprintf('[%.3f %.3f %.3f]', best_coord(1), best_coord(2), best_coord(3));
            end
        end
    end
    
    if bipolar_count > 0
        fprintf('  - Processed %d bipolar coordinates\n', bipolar_count);
    end
end

%% Function to parse bipolar coordinates
function coords = parse_bipolar_coordinates(coord_str)
    % Remove brackets and split by semicolon
    coord_str = strrep(coord_str, '[', '');
    coord_str = strrep(coord_str, ']', '');
    coord_parts = split(coord_str, ';');
    
    coords = zeros(length(coord_parts), 3);
    
    for i = 1:length(coord_parts)
        coord_values = str2num(coord_parts{i}); %#ok<ST2NM>
        if length(coord_values) == 3
            coords(i, :) = coord_values;
        end
    end
end

%% Function to select the best coordinate from bipolar pair
function best_coord = select_best_coordinate(coords, data, current_idx)
    % Strategy: Keep the coordinate that's closer to the average of all other
    % coordinates in the same cluster/file
    
    % Collect all other coordinates in the dataset for comparison
    all_coords = [];
    
    for j = 1:height(data)
        if j ~= current_idx
            coord_str = data.MNI_coord{j};
            
            % Parse single coordinates (not bipolar)
            if ~contains(coord_str, ';')
                coord_values = parse_single_coordinate(coord_str);
                if ~isempty(coord_values)
                    all_coords = [all_coords; coord_values]; %#ok<AGROW>
                end
            end
        end
    end
    
    if isempty(all_coords)
        % If no other coordinates available, just take the first one
        best_coord = coords(1, :);
        return;
    end
    
    % Calculate centroid of all other coordinates
    centroid = mean(all_coords, 1);
    
    % Calculate distances from each bipolar coordinate to centroid
    dist1 = norm(coords(1, :) - centroid);
    dist2 = norm(coords(2, :) - centroid);
    
    % Keep the coordinate closer to the centroid
    if dist1 <= dist2
        best_coord = coords(1, :);
    else
        best_coord = coords(2, :);
    end
end

%% Function to parse single coordinate
function coord_values = parse_single_coordinate(coord_str)
    try
        % Remove brackets and parse
        coord_str = strrep(coord_str, '[', '');
        coord_str = strrep(coord_str, ']', '');
        coord_values = str2num(coord_str); %#ok<ST2NM>
        
        if length(coord_values) ~= 3
            coord_values = [];
        end
    catch
        coord_values = [];
    end
end

%% Function to keep only the best component per dataset
% Note that this calculation is made only with the single coordinate
% dipoles. Bipolar dipoles are excluded from this centroid calculation.

function data = keep_best_component_per_dataset(data)
    original_rows = height(data);
    
    % Convert subject and session to strings for comparison
    subject_str = cellstr(string(data.subject));
    
    % Handle session column - it should now be a cell array of strings
    if iscell(data.session)
        session_str = data.session;
    else
        session_str = cellstr(string(data.session));
    end
    
    % Create unique identifier for each dataset
    dataset_id = strcat(subject_str, "_", session_str);
    
    % Find unique combinations of subject and session
    [~, ~, group_idx] = unique(dataset_id, 'stable');
    
    % For each group, keep only the row with highest IC_brain_label
    rows_to_keep = false(height(data), 1);
    
    for group = 1:max(group_idx)
        group_rows = find(group_idx == group);
        
        if length(group_rows) == 1
            % Only one component for this dataset
            rows_to_keep(group_rows) = true;
        else
            % Multiple components - keep the one with highest IC_brain_label
            [~, max_idx] = max(data.IC_brain_label(group_rows));
            rows_to_keep(group_rows(max_idx)) = true;
        end
    end
    
    data = data(rows_to_keep, :);
    
    removed_rows = original_rows - height(data);
    if removed_rows > 0
        fprintf('  - Removed %d duplicate components (kept highest IC_brain_label)\n', removed_rows);
    end
end