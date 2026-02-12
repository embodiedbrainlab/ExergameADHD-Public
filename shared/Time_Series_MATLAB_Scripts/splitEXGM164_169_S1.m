%% Split EXGM164_S1 and EXGM169_S1
% This script splits the two manually merged datasets: exgm164_s1 and exgm169_s1
% These datasets have unique segment structures due to recording irregularities

%% Import EEGLAB Functions
eeglab
close
clear

%% Define Paths
input_dir = '..\data\preprocessed\session_1';
output_dir = '../data/preprocessed/session_1/special_split/';

% Create output directory if it doesn't exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
    fprintf('Created output directory: %s\n', output_dir);
end

%% Process exgm164_s1
fprintf('=== Processing exgm164_s1 ===\n');
process_exgm164_s1(input_dir, output_dir);

%% Process exgm169_s1  
fprintf('\n=== Processing exgm169_s1 ===\n');
process_exgm169_s1(input_dir, output_dir);

fprintf('\n=== Processing Complete ===\n');

%% Function to process exgm164_s1
function process_exgm164_s1(input_dir, output_dir)
    try
        % Load the dataset
        input_file = fullfile(input_dir, 'exgm164_s1.set');
        fprintf('Loading: %s\n', input_file);
        EEG = pop_loadset(input_file);
        
        % Extract 'New Segment' markers
        new_segment_indices = find(strcmp({EEG.event.code}, 'New Segment'));
        new_segment_latencies = [EEG.event(new_segment_indices).latency];
        new_segment_latencies = sort(new_segment_latencies);
        
        fprintf('Found %d "New Segment" markers\n', length(new_segment_latencies));
        
        % Expected: 11 segments total
        if length(new_segment_latencies) ~= 11
            warning('Expected 11 segments for exgm164_s1, found %d', length(new_segment_latencies));
        end
        
        % Define task order for exgm164_s1 based on manual merge script
        % Order: prebaseline, digitforward, digitbackward, stroop_gonogo, wcst, shoulder_1, shoulder_2, shoulder_3, tandem_1, tandem_2, tandem_3
        task_list = {
            'prebaseline',      % segment 1
            'digitforward',     % segment 2  
            'digitbackward',    % segment 3
            'stroop_gonogo',    % segment 4 (combined)
            'wcst',             % segment 5
            'shoulder_1',       % segment 6
            'shoulder_2',       % segment 7
            'shoulder_3',       % segment 8
            'tandem_1',         % segment 9
            'tandem_2',         % segment 10
            'tandem_3'          % segment 11
        };
        
        % Create segment ranges
        segment_ranges = create_segment_ranges(new_segment_latencies, EEG.pnts);
        
        % Process each segment
        num_segments = min(length(task_list), size(segment_ranges, 1));
        for i = 1:num_segments
            fprintf('Processing segment %d: %s\n', i, task_list{i});
            
            % Extract the segment
            EEG_temp = pop_select(EEG, 'point', segment_ranges(i,:));
            
            % Determine condition and run for metadata
            [condition_name, run_number] = parse_task_info(task_list{i});
            
            % Update dataset metadata
            EEG_temp = pop_editset(EEG_temp, 'subject', 'exgm164', ...
                                          'session', 1, ...
                                          'condition', condition_name, ...
                                          'run', run_number);
            
            % Create output filename
            output_filename = sprintf('exgm164_s1_%s.set', task_list{i});
            output_filepath = fullfile(output_dir, output_filename);
            
            % Update dataset info
            EEG_temp.setname = sprintf('exgm164_s1_%s', task_list{i});
            EEG_temp.filename = output_filename;
            EEG_temp.filepath = output_dir;
            
            % Save dataset
            pop_saveset(EEG_temp, output_filename, output_dir);
            fprintf('Saved: %s\n', output_filepath);
        end
        
        fprintf('exgm164_s1 processing completed successfully!\n');
        
    catch ME
        fprintf('ERROR processing exgm164_s1: %s\n', ME.message);
        rethrow(ME);
    end
end

%% Function to process exgm169_s1
function process_exgm169_s1(input_dir, output_dir)
    try
        % Load the dataset
        input_file = fullfile(input_dir, 'exgm169_s1.set');
        fprintf('Loading: %s\n', input_file);
        EEG = pop_loadset(input_file);
        
        % Extract 'New Segment' markers
        new_segment_indices = find(strcmp({EEG.event.code}, 'New Segment'));
        new_segment_latencies = [EEG.event(new_segment_indices).latency];
        new_segment_latencies = sort(new_segment_latencies);
        
        fprintf('Found %d "New Segment" markers\n', length(new_segment_latencies));
        
        % Expected: 13 segments total
        if length(new_segment_latencies) ~= 13
            warning('Expected 13 segments for exgm169_s1, found %d', length(new_segment_latencies));
        end
        
        % Define task order for exgm169_s1 based on manual merge script
        % Order: prebaseline, wcst, digitforward, digitbackward, gonogo (merged from parts 1&2), stroop, shoulder_1, shoulder_2, shoulder_3, tandem_1, tandem_2, tandem_3
        task_list = {
            'prebaseline',      % segment 1
            'wcst',             % segment 2
            'digitforward',     % segment 3
            'digitbackward',    % segment 4
            'gonogo',           % segments 5&6 (merged)
            'stroop',           % segment 7
            'shoulder_1',       % segment 8
            'shoulder_2',       % segment 9
            'shoulder_3',       % segment 10
            'tandem_1',         % segment 11
            'tandem_2',         % segment 12
            'tandem_3'          % segment 13
        };
        
        % Create segment ranges
        segment_ranges = create_segment_ranges(new_segment_latencies, EEG.pnts);
        
        % Process each segment (with special handling for gonogo merge)
        segment_counter = 1;
        for i = 1:length(task_list)
            fprintf('Processing task %d: %s\n', i, task_list{i});
            
            if strcmp(task_list{i}, 'gonogo')
                % Special case: merge gonogo segments 5 and 6
                fprintf('  Merging gonogo parts (segments %d and %d)\n', segment_counter, segment_counter+1);
                
                % Extract first gonogo segment
                EEG_gonogo1 = pop_select(EEG, 'point', segment_ranges(segment_counter,:));
                % Extract second gonogo segment  
                EEG_gonogo2 = pop_select(EEG, 'point', segment_ranges(segment_counter+1,:));
                
                % Merge the two gonogo segments
                EEG_temp = pop_mergeset(EEG_gonogo1, EEG_gonogo2);
                
                % Skip ahead since we processed two segments
                segment_counter = segment_counter + 2;
            else
                % Normal processing for other tasks
                EEG_temp = pop_select(EEG, 'point', segment_ranges(segment_counter,:));
                segment_counter = segment_counter + 1;
            end
            
            % Determine condition and run for metadata
            [condition_name, run_number] = parse_task_info(task_list{i});
            
            % Update dataset metadata
            EEG_temp = pop_editset(EEG_temp, 'subject', 'exgm169', ...
                                          'session', 1, ...
                                          'condition', condition_name, ...
                                          'run', run_number);
            
            % Create output filename
            output_filename = sprintf('exgm169_s1_%s.set', task_list{i});
            output_filepath = fullfile(output_dir, output_filename);
            
            % Update dataset info
            EEG_temp.setname = sprintf('exgm169_s1_%s', task_list{i});
            EEG_temp.filename = output_filename;
            EEG_temp.filepath = output_dir;
            
            % Save dataset
            pop_saveset(EEG_temp, output_filename, output_dir);
            fprintf('Saved: %s\n', output_filepath);
        end
        
        fprintf('exgm169_s1 processing completed successfully!\n');
        
    catch ME
        fprintf('ERROR processing exgm169_s1: %s\n', ME.message);
        rethrow(ME);
    end
end

%% Helper function to create segment ranges
function segment_ranges = create_segment_ranges(new_segment_latencies, total_points)
    num_segments = length(new_segment_latencies);
    segment_ranges = zeros(num_segments, 2);
    
    % Each segment starts at a 'New Segment' marker and goes to the next one (or end)
    for i = 1:length(new_segment_latencies)
        segment_ranges(i, 1) = new_segment_latencies(i);
        
        if i < length(new_segment_latencies)
            segment_ranges(i, 2) = new_segment_latencies(i+1) - 1;
        else
            segment_ranges(i, 2) = total_points;
        end
    end
    
    fprintf('Created %d segment ranges\n', num_segments);
end

%% Helper function to parse task information for metadata
function [condition_name, run_number] = parse_task_info(task_name)
    % Handle special cases and motor tasks
    if contains(task_name, 'shoulder_') || contains(task_name, 'tandem_')
        % For motor tasks, extract base name and run number
        parts = split(task_name, '_');
        condition_name = parts{1};
        run_number = str2double(parts{2});
    elseif strcmp(task_name, 'stroop_gonogo')
        % Special case for combined task
        condition_name = 'stroop_gonogo';
        run_number = [];
    else
        % Other tasks (prebaseline, digitforward, gonogo, etc.)
        condition_name = task_name;
        run_number = [];
    end
end