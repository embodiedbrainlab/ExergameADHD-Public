function segment_erp_datasets(input_file_path, output_directory)
% SEGMENT_ERP_DATASETS - Segments ERP datasets based on 'New Segment' markers
% 
% Usage: segment_erp_datasets('path/to/file.set', 'output/directory/')
%
% This function loads an EEGLAB .set file, finds 'New Segment' markers,
% and creates three separate datasets based on stimulus types for ERP
% analysis.

    try
        % Load the EEGLAB .set file
        fprintf('Loading dataset: %s\n', input_file_path);
        EEG = pop_loadset(input_file_path);
        
        % Step 2: Extract all latency values associated with 'New Segment'
        new_segment_indices = find(strcmp({EEG.event.code}, 'New Segment'));
        new_segment_latencies = [EEG.event(new_segment_indices).latency];
        
        fprintf('Found %d "New Segment" markers\n', length(new_segment_latencies));
        
        % Step 3: Check if exactly 3 'New Segment' codes are found
        if length(new_segment_latencies) ~= 3
            warning('Dataset %s has %d "New Segment" markers instead of 3. Skipping dataset.', ...
                input_file_path, length(new_segment_latencies));
            
            % Write error to log file
            error_log_file = fullfile(output_directory, 'skipped_datasets.txt');
            fid = fopen(error_log_file, 'a');
            if fid ~= -1
                fprintf(fid, '%s: Dataset %s has %d "New Segment" markers instead of 3. Skipped.\n', ...
                    datetime("now"), input_file_path, length(new_segment_latencies));
                fclose(fid);
            end
            return;
        end
        
        % Step 4: Order the extracted latency values in ascending order
        new_segment_latencies = sort(new_segment_latencies);
        fprintf('New Segment latencies (sorted): [%.0f, %.0f, %.0f]\n', new_segment_latencies);
        
        % Step 5: Create paired values for segmentation
        segment_ranges = [
            new_segment_latencies(1), new_segment_latencies(2)-1;
            new_segment_latencies(2), new_segment_latencies(3)-1;
            new_segment_latencies(3), EEG.pnts
        ];
        
        fprintf('Segment ranges:\n');
        fprintf('  Segment 1: %.0f - %.0f\n', segment_ranges(1,1), segment_ranges(1,2));
        fprintf('  Segment 2: %.0f - %.0f\n', segment_ranges(2,1), segment_ranges(2,2));
        fprintf('  Segment 3: %.0f - %.0f\n', segment_ranges(3,1), segment_ranges(3,2));
        
        % Step 6: Create three new datasets using pop_select
        for i = 1:3
            fprintf('\nProcessing segment %d...\n', i);
            
            % Extract the segment
            EEG_temp = pop_select(EEG, 'point', segment_ranges(i,:));
            
            % Step 7: Determine filename based on stimulus types
            stimulus_indices = find(strcmp({EEG_temp.event.code}, 'Stimulus'));
            
            if isempty(stimulus_indices)
                fprintf('Warning: No stimulus events found in segment %d\n', i);
                dataset_name = sprintf('unknown_segment_%d', i);
            else
                stimulus_types = {EEG_temp.event(stimulus_indices).type};
                unique_stimulus_types = unique(stimulus_types);
                
                % Sort for consistent comparison
                unique_stimulus_types = sort(unique_stimulus_types);
                
                % Determine dataset name using switch/case
                dataset_name = determine_dataset_name(unique_stimulus_types);
                
                fprintf('Unique stimulus types in segment %d: %s\n', i, strjoin(unique_stimulus_types, ', '));
                fprintf('Dataset type: %s\n', dataset_name);
            end
            
            % Step 8: Save the dataset
            [~, original_filename, ~] = fileparts(input_file_path);
            output_filename = sprintf('%s_%s.set', original_filename, dataset_name);
            output_filepath = fullfile(output_directory, output_filename);
            
            % Update dataset info
            EEG_temp.setname = sprintf('%s_%s', original_filename, dataset_name);
            EEG_temp.filename = output_filename;
            EEG_temp.filepath = output_directory;
            
            % Save using pop_saveset
            pop_saveset(EEG_temp, output_filename, output_directory);
            fprintf('Saved: %s\n', output_filepath);
        end
        
        fprintf('\nSegmentation completed successfully!\n');
        
    catch ME
        error_msg = sprintf('Error processing %s: %s', input_file_path, ME.message);
        fprintf('ERROR: %s\n', error_msg);
        
        % Write error to log file
        error_log_file = fullfile(output_directory, 'processing_errors.txt');
        fid = fopen(error_log_file, 'a');
        if fid ~= -1
            fprintf(fid, '%s: %s\n', datetime("now"), error_msg);
            fclose(fid);
        end
        rethrow(ME);
    end
end

function dataset_name = determine_dataset_name(unique_stimulus_types)
% DETERMINE_DATASET_NAME - Determines dataset name based on stimulus types
%
% Input: unique_stimulus_types - cell array of unique stimulus type strings
% Output: dataset_name - string indicating the dataset type

    % Check for the presence of specific markers
    % Note that single digit markers have a double space, while double
    % digit markers have a single space.
    has_S15 = any(strcmp(unique_stimulus_types, 'S 15'));
    has_S3 = any(strcmp(unique_stimulus_types, 'S  3'));
    has_S13 = any(strcmp(unique_stimulus_types, 'S 13'));
    has_S1 = any(strcmp(unique_stimulus_types, 'S  1'));
    has_S7 = any(strcmp(unique_stimulus_types, 'S  7'));
    has_S9 = any(strcmp(unique_stimulus_types, 'S  9'));
    
    % Determine dataset type based on marker presence
    % Priority order: check for unique markers first
    if has_S1 && has_S7 && has_S9
        % gonogo: has the unique markers S 1, S 7, and S 9 (may have S15, S3, S13 too)
        dataset_name = 'gonogo';
    elseif has_S15 && has_S3 && has_S13 && ~has_S1 && ~has_S7 && ~has_S9
        % stroop: has S 15, S 3, and S 13, but NOT the gonogo-specific markers
        dataset_name = 'stroop';
    elseif has_S15 && ~has_S3 && ~has_S13 && ~has_S1 && ~has_S7 && ~has_S9
        % wcst: only has S 15 (and no other specific markers)
        dataset_name = 'wcst';
    else
        dataset_name = 'unknown';
        fprintf('Warning: Unrecognized stimulus pattern. Found markers: %s\n', ...
            strjoin(unique_stimulus_types, ', '));
    end
end