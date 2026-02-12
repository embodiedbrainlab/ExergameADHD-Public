function new_ERP_indices = renumber_ERP_task_indices(indices)
    % Function to remove digitforward and digitbackward from indices matrix
    % and renumber the remaining tasks (gonogo, stroop, wcst) to values 1-3
    % to concatenate data for ERP analysis.
    %
    % Input:
    %   indices - matrix with columns [digitforward, digitbackward, gonogo, stroop, wcst]
    % Output:
    %   new_indices - matrix with 3 columns [gonogo, stroop, wcst] renumbered to 1-3
    %
    % Written by Noor Tasnim on July 22, 2025
    
    % Extract only the tasks we want to keep (columns 3, 4, 5)
    remaining_tasks = indices(:, 3:5); % gonogo, stroop, wcst

    % Create a mapping to renumber the values 1-3 based on their relative order
    % We need to handle each row independently since the order might vary per participant
    new_ERP_indices = zeros(size(remaining_tasks));

    for row = 1:size(remaining_tasks, 1)
        % Get the current row values
        current_row = remaining_tasks(row, :);
        
        % Sort the unique values to establish the new mapping
        unique_vals = unique(current_row);
        unique_vals = unique_vals(unique_vals > 0); % Remove any zeros if present
        
        % Create new indices based on the sorted order
        for col = 1:size(remaining_tasks, 2)
            if current_row(col) > 0
                % Find the position of this value in the sorted unique values
                new_ERP_indices(row, col) = find(unique_vals == current_row(col));
            else
                new_ERP_indices(row, col) = 0; % Keep zeros as zeros
            end
        end
    end
end