% ERP PROCESSING TO REMOVE ADDITIONAL CHANNELS
% Once ERP_processing.m was run, the PSDs for the final datasets for each
% participant/session were plotting. I noticed that there were additional
% faulty channels that were missed during the automated pre-processing
% stages, which negatively impact the ICA decomposition, and thus, the
% final signal for our analysis.
%
% The PSD for each participant/session was reviewed and an excel
% spreadsheet documented additional electrodes that needed to be discounted
% for the extended Infomax ICA and eventually be interpolated after the ICA
% weights are added to the "preICA" dataset with the 0.1-30 Hz filter.
%
% The following script will read the excel spreadsheet, add the additional
% labels to the `removed_channels_data` cell array from
% channels2interp.mat and re-preprocess those selected files.
%
% Written by Noor Tasnim on July 28, 2025

%% Read spreadsheet and load channels2interp.mat

more_channels = readtable('../docs/additional_channels_removed_ERP.csv');
load ../data/erp/channels2interp.mat

%% merge files
% save as new .mat file with new name

% preprocess the remaining datasets
% dont forget to activate parallel processing

% Script to merge channel removal data from cell array and table
% Author: Generated script for EEG channel removal data merging

% Initialize variables
fprintf('Starting channel removal data merge process...\n');

% Get the number of rows in more_channels table
num_new_entries = height(more_channels);

% Loop through each row in more_channels table
for i = 1:num_new_entries
    % Extract current ID and session from more_channels
    current_id = more_channels.id{i};
    current_session = more_channels.session{i};
    
    fprintf('Processing ID: %s, Session: %s\n', current_id, current_session);
    
    % Find matching row in removed_channels_data
    match_found = false;
    
    for j = 1:size(removed_channels_data, 1)
        % Check if ID and session match
        if strcmp(removed_channels_data{j, 1}, current_id) && ...
           strcmp(removed_channels_data{j, 2}, current_session)
            
            match_found = true;
            fprintf('  Match found at row %d in removed_channels_data\n', j);
            
            % Get existing channel names and indices
            existing_channels = removed_channels_data{j, 3};
            existing_indices = removed_channels_data{j, 4};
            
            % Get new channel names and indices from more_channels
            new_channels = more_channels.channels_removed{i};
            new_indices_str = more_channels.channels_removed_indices{i};
            
            % Parse the new indices string (remove brackets and convert to vector)
            new_indices_str = strrep(new_indices_str, '[', '');
            new_indices_str = strrep(new_indices_str, ']', '');
            new_indices = str2num(new_indices_str);
            
            % Combine channel names
            combined_channels = [existing_channels ';' new_channels];
            
            % Combine indices (ensure they're unique and sorted)
            combined_indices = unique([existing_indices, new_indices]);
            combined_indices = sort(combined_indices);
            
            % Update the cell array with combined data
            removed_channels_data{j, 3} = combined_channels;
            removed_channels_data{j, 4} = combined_indices;
            
            fprintf('  Updated channels: %s\n', combined_channels);
            fprintf('  Updated indices: [%s]\n', num2str(combined_indices));

            break; % Exit inner loop once match is found
        end
    end
    
    fprintf('\n');
end

save ../data/erp/extrachannels2interp.mat removed_channels_data

fprintf('Channel removal data merge completed successfully!\n');
fprintf('extrachannels2interp.mat saved in ..data/erp/\n');
fprintf('Final removed_channels_data has %d rows\n', size(removed_channels_data, 1));

