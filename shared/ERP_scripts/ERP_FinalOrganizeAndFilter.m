% Final Organization of Filtering of ERP Datasets for Analysis
%
% This script will go into our latest ERP folder (Folder 11 Group Analysis)
% and perform the following actions:
%
% 1. Organize datasets as either "stimulant" or "non-stimulant" users by
% placing the datasets into 1 of these 2 subdirectories:
%   - e.g. '../data/erp/11_group_analysis/session1/gonogo/stimulants/'
%   - To organize, the script uses the function `organize_erp_datasets`
% 2. Run a 20 Hz low-pass non-causal Butterworth impulse response filter
% with a half amplitude cutoff at 20 Hz, 48 db/oc roll-off.
%   - Some measures conducted in `ERP_MeasureComponents` are sensitive to
%   high noise, ERP data needs to be low-pass filtered to obtain clean
%   measurements.
%
% The final measurement/analyses through `ERP_MeasureComponents` will use
% both the unfiltered and filtered datasets from these directories.
% 
% Written by Noor Tasnim on September 23, 2025

%% Copy Files to Stimulant and Non-Stimulant Folders

% Process multiple directories in a loop
base_dirs = {'../data/erp/11_group_analysis/session1/gonogo',...
    '../data/erp/11_group_analysis/session1/stroop',...
    '../data/erp/11_group_analysis/session1/wcst',...
    '../data/erp/ERN/11_group_analysis/session1/wcst',...
    '../data/erp/11_group_analysis/session2/gonogo',...
    '../data/erp/11_group_analysis/session2/stroop',...
    '../data/erp/11_group_analysis/session2/wcst',...
    '../data/erp/ERN/11_group_analysis/session2/wcst'
    };

for i = 1:length(base_dirs)
    organize_erp_datasets(base_dirs{i});
end

%% Create Filtered and Unfiltered Folders for Analysis
% Some meaurements (mean amplitude and positive 50% area latency) do not
% need to be filtered, so we'll create a folder for filtered datasets for
% other metrics.

% Define the subdirectories to process
subdirs_to_process = {'stimulants', 'non-stimulants'};

% Loop through each base directory
for i = 1:length(base_dirs)
    base_dir = base_dirs{i};
    
    % Loop through stimulants and non-stimulants folders
    for j = 1:length(subdirs_to_process)
        current_subdir = fullfile(base_dir, subdirs_to_process{j});
        
        % Check if the subdirectory exists
        if exist(current_subdir, 'dir')
            fprintf('Processing: %s\n', current_subdir);
            
            % Create filtered directory
            filtered_dir = fullfile(current_subdir, 'filtered');
            if ~exist(filtered_dir, 'dir')
                mkdir(filtered_dir);
                fprintf('Created directory: %s\n', filtered_dir);
            end
            
            % Get all .erp files in the current subdirectory
            erp_files = dir(fullfile(current_subdir, '*.erp'));
            
            % Process each .erp file
            for k = 1:length(erp_files)
                % Confirmation Message
                fprintf('Processing file: %s\n', erp_files(k).name);
                % Load ERP dataset
                ERP = pop_loaderp('filename', erp_files(k).name,'filepath',current_subdir);
                % Low Pass Filter
                ERP = pop_filterp(ERP, 1:64 , 'binArray', 1:length(ERP.bindescr), 'Cutoff', 20,...
                    'Design', 'butter', 'Filter', 'lowpass', 'Order', 8);
                % Save to new directory
                ERP = pop_savemyerp(ERP,'erpname',[erp_files(k).name(1:end-4), '_filt'],...
                    'filename',[erp_files(k).name(1:end-4), '_filt.erp'], 'filepath',filtered_dir);
                % Filter complete
                fprintf('Saved to: %s\n', filtered_dir);
            end
            fprintf(' Processed %d files in %s\n\n', length(erp_files), subdirs_to_process{j});
        else
            fprintf('Warning: Directory does not exist: %s\n', current_subdir);
        end
    end
end

fprintf('Processing complete!\n');
