function split_preprocessed_eeg_datasets(input_file_path, output_directory, task_order_csv_path)
% SPLIT_PREPROCESSED_EEG_DATASETS - Splits merged EEG datasets based on 'New Segment' markers
% 
% Usage: split_preprocessed_eeg_datasets('path/to/exgm175_s2.set', 'output/directory/', '../docs/exergame_eeg_task_order.csv')
%
% This function loads a merged EEGLAB .set file, finds 'New Segment' markers,
% and creates separate datasets for each task based on session type and task order.

    try
        % Load the EEGLAB .set file
        fprintf('Loading dataset: %s\n', input_file_path);
        EEG = pop_loadset(input_file_path);
        
        % Extract participant ID and session from filename
        [~, filename, ~] = fileparts(input_file_path);
        [participant_id, session] = parse_filename(filename);
        fprintf('Participant ID: %s, Session: %s\n', participant_id, session);
        
        % Load task order from CSV
        task_order = load_task_order(task_order_csv_path, participant_id, session);
        fprintf('Task order loaded successfully\n');
        
        % Extract all latency values associated with 'New Segment'
        new_segment_indices = find(strcmp({EEG.event.code}, 'New Segment'));
        new_segment_latencies = [EEG.event(new_segment_indices).latency];
        
        fprintf('Found %d "New Segment" markers\n', length(new_segment_latencies));
        
        % Sort latencies in ascending order
        new_segment_latencies = sort(new_segment_latencies);
        fprintf('New Segment latencies (sorted): %s\n', mat2str(new_segment_latencies));
        
        % Determine expected number of segments and task list
        if strcmp(session, 's1')
            expected_segments = 12; % prebaseline + 5 executive tasks + 6 motor tasks
            task_list = get_s1_task_list(task_order);
        else % s2
            expected_segments = 13; % prebaseline + postbaseline + 5 executive tasks + 6 motor tasks
            task_list = get_s2_task_list(task_order);
        end
        
        % Check if we have the expected number of segments
        actual_segments = length(new_segment_latencies); % Number of segments equals number of 'New Segment' markers
        if actual_segments ~= expected_segments
            warning('Dataset %s has %d segments instead of expected %d. Proceeding anyway.', ...
                filename, actual_segments, expected_segments);
        end
        
        % Create segment ranges
        segment_ranges = create_segment_ranges(new_segment_latencies, EEG.pnts);
        
        % Process each segment
        num_segments = min(length(task_list), size(segment_ranges, 1));
        for i = 1:num_segments
            fprintf('\nProcessing segment %d: %s...\n', i, task_list{i});
            
            % Extract the segment using pop_select
            EEG_temp = pop_select(EEG, 'point', segment_ranges(i,:));
            
            % Determine run number for motor tasks
            run_number = get_run_number(task_list{i});
            
            % Determine condition name (remove _X suffix for motor tasks)
            if contains(task_list{i}, 'shoulder_') || contains(task_list{i}, 'tandem_')
                % For motor tasks, use just the base name (shoulder or tandem)
                parts = split(task_list{i}, '_');
                condition_name = parts{1};
            else
                % For other tasks, use the full name
                condition_name = task_list{i};
            end
            
            % Update dataset metadata using pop_editset
            session_num = str2double(session(2)); % Extract numeric part (1 or 2)
            EEG_temp = pop_editset(EEG_temp, 'subject', participant_id, ...
                                          'session', session_num, ...
                                          'condition', condition_name, ...
                                          'run', run_number);
            
            % Create output filename
            output_filename = sprintf('%s_%s_%s.set', participant_id, session, task_list{i});
            output_filepath = fullfile(output_directory, output_filename);
            
            % Update dataset info
            EEG_temp.setname = sprintf('%s_%s_%s', participant_id, session, task_list{i});
            EEG_temp.filename = output_filename;
            EEG_temp.filepath = output_directory;
            
            % Save using pop_saveset
            pop_saveset(EEG_temp, output_filename, output_directory);
            fprintf('Saved: %s\n', output_filepath);
            
            fprintf('Segment %d (%s) - Points: %.0f to %.0f (duration: %.0f points)\n', ...
                i, task_list{i}, segment_ranges(i,1), segment_ranges(i,2), ...
                segment_ranges(i,2) - segment_ranges(i,1) + 1);
        end
        
        fprintf('\nDataset splitting completed successfully!\n');
        fprintf('Total segments processed: %d\n', num_segments);
        
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

function [participant_id, session] = parse_filename(filename)
% PARSE_FILENAME - Extracts participant ID and session from filename
% Input: filename - string like 'exgm175_s2'
% Output: participant_id - string like 'exgm175', session - string like 's2'
    
    % Use regular expression to extract parts
    pattern = '^(exgm\d{3})_(s[12])$';
    tokens = regexp(filename, pattern, 'tokens');
    
    if isempty(tokens)
        error('Invalid filename format: %s. Expected format: exgmXXX_sX', filename);
    end
    
    participant_id = tokens{1}{1};
    session = tokens{1}{2};
end

function task_order = load_task_order(csv_path, participant_id, session)
% LOAD_TASK_ORDER - Loads task order from CSV file
% Input: csv_path - path to CSV file, participant_id - string like 'exgm175', session - string like 's2'
% Output: task_order - struct with task orders
    
    % Extract numeric participant ID (remove 'exgm' prefix and leading zeros)
    numeric_id = str2double(participant_id(5:end));
    numeric_session = str2double(session(2));
    
    % Read CSV file
    if ~exist(csv_path, 'file')
        error('Task order CSV file not found: %s', csv_path);
    end
    
    % Read the CSV file
    data = readtable(csv_path);
    
    % Find the row for this participant and session
    row_idx = find(data.participant_id == numeric_id & data.session == numeric_session);
    
    if isempty(row_idx)
        error('No task order found for participant %d, session %d in %s', ...
            numeric_id, numeric_session, csv_path);
    end
    
    if length(row_idx) > 1
        warning('Multiple entries found for participant %d, session %d. Using first entry.', ...
            numeric_id, numeric_session);
        row_idx = row_idx(1);
    end
    
    % Extract task orders
    task_order.digitforward = data.digitforward(row_idx);
    task_order.digitbackward = data.digitbackward(row_idx);
    task_order.gonogo = data.gonogo(row_idx);
    task_order.stroop = data.stroop(row_idx);
    task_order.wcst = data.wcst(row_idx);
    
    fprintf('Task order for participant %s, session %s:\n', participant_id, session);
    fprintf('  digitforward: %d, digitbackward: %d, gonogo: %d, stroop: %d, wcst: %d\n', ...
        task_order.digitforward, task_order.digitbackward, task_order.gonogo, ...
        task_order.stroop, task_order.wcst);
end

function task_list = get_s1_task_list(task_order)
% GET_S1_TASK_LIST - Creates ordered task list for session 1
% Input: task_order - struct with task orders
% Output: task_list - cell array of task names in order
    
    % Initialize task list for s1: prebaseline + 5 executive tasks + 6 motor tasks
    task_list = cell(1, 12);
    
    % First task is always prebaseline
    task_list{1} = 'prebaseline';
    
    % Create mapping of task orders to task names
    executive_tasks = {'digitforward', 'digitbackward', 'gonogo', 'stroop', 'wcst'};
    
    % Place executive tasks based on their order (positions 2-6)
    for i = 1:5
        task_name = executive_tasks{i};
        task_position = task_order.(task_name) + 1; % +1 because prebaseline is position 1
        task_list{task_position} = task_name;
    end
    
    % Add motor tasks (positions 7-12)
    motor_tasks = {'shoulder_1', 'shoulder_2', 'shoulder_3', 'tandem_1', 'tandem_2', 'tandem_3'};
    for i = 1:6
        task_list{6 + i} = motor_tasks{i};
    end
end

function task_list = get_s2_task_list(task_order)
% GET_S2_TASK_LIST - Creates ordered task list for session 2
% Input: task_order - struct with task orders
% Output: task_list - cell array of task names in order
    
    % Initialize task list for s2: prebaseline + postbaseline + 5 executive tasks + 6 motor tasks
    task_list = cell(1, 13);
    
    % First two tasks are always prebaseline and postbaseline
    task_list{1} = 'prebaseline';
    task_list{2} = 'postbaseline';
    
    % Create mapping of task orders to task names
    executive_tasks = {'digitforward', 'digitbackward', 'gonogo', 'stroop', 'wcst'};
    
    % Place executive tasks based on their order (positions 3-7)
    for i = 1:5
        task_name = executive_tasks{i};
        task_position = task_order.(task_name) + 2; % +2 because prebaseline and postbaseline are positions 1-2
        task_list{task_position} = task_name;
    end
    
    % Add motor tasks (positions 8-13)
    motor_tasks = {'shoulder_1', 'shoulder_2', 'shoulder_3', 'tandem_1', 'tandem_2', 'tandem_3'};
    for i = 1:6
        task_list{7 + i} = motor_tasks{i};
    end
end

function segment_ranges = create_segment_ranges(new_segment_latencies, total_points)
% CREATE_SEGMENT_RANGES - Creates start and end points for each segment
% Input: new_segment_latencies - array of latency values, total_points - total data points
% Output: segment_ranges - Nx2 matrix of [start, end] points
    
    num_segments = length(new_segment_latencies);
    segment_ranges = zeros(num_segments, 2);
    
    % Each segment starts at a 'New Segment' marker and goes to the next one (or end)
    for i = 1:length(new_segment_latencies)
        segment_ranges(i, 1) = new_segment_latencies(i);
        
        if i < length(new_segment_latencies)
            % End at the point before the next 'New Segment' marker
            segment_ranges(i, 2) = new_segment_latencies(i+1) - 1;
        else
            % Last segment goes to the end of the data
            segment_ranges(i, 2) = total_points;
        end
    end
    
    fprintf('Created %d segment ranges:\n', num_segments);
    for i = 1:num_segments
        fprintf('  Segment %d: %.0f - %.0f\n', i, segment_ranges(i,1), segment_ranges(i,2));
    end
end

function run_number = get_run_number(task_name)
% GET_RUN_NUMBER - Extracts run number for motor tasks
% Input: task_name - string like 'shoulder_1' or 'tandem_3'
% Output: run_number - integer (1-3) or empty for non-motor tasks
    
    if contains(task_name, 'shoulder_') || contains(task_name, 'tandem_')
        % Extract the number after the underscore
        parts = split(task_name, '_');
        run_number = str2double(parts{2});
    else
        run_number = []; % Empty for non-motor tasks
    end
end


% Example usage:
% split_preprocessed_eeg_datasets('exgm175_s2.set', 'output_directory', '../docs/exergame_eeg_task_order.csv')