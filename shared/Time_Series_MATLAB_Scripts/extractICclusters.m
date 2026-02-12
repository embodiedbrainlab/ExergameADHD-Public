% EXTRACTING IC CLUSTERS FROM EEGLAB STUDY
%
% We used optimal k-means clustering to cluster all independent components
% identified from the 67 datasets (67 participants). 
% For the clustering algorithm, we set a minimum of 7 and maximum of 21
% (because we found about 14 ICs per dataset). ICs were clustered based on 
% dipole location. Outliers were defined as ICs at least 3 SD away from
% clusters.
%
% Some clusters may seem to have outliers in their clusters, but based on
% our previous analyses, these dipoles are most likely bipolar dipoles.
%
% The purpose of this script is to load the ALLEEG datasets and the STUDY
% outputs and identify which ICs were clustered together. The output should
% be a .csv file for each cluster showing each components:
% 1. Subject
% 2. Session
% 3. Component
% 4. MNI Coordinates
% 5. IC Label Brain Percentage
%
% All .csv files are saved in '../results/IC_clusters/'
%
% Edited by Noor Tasnim 08.27.2025

%% Load Output variables from EEGLAB Study
load ..\data\preprocessed\session_1\exergame_session1_studyData.mat

%% Ensure ALLEEG Indices are the same as STUDY.datasetinfo

assert(isequal({STUDY.datasetinfo.filename}, {ALLEEG.filename}), ...
       'Filename order mismatch between STUDY and ALLEEG structures');

%% Loop through clusters to export datasets and components

% Get the number of clusters
num_clusters = length(STUDY.cluster);

fprintf('Found %d clusters to process\n', num_clusters);

% Process each cluster
for cluster_idx = 2:num_clusters %skip parent cluster (row 1)
    
    % Get cluster information
    cluster_name = STUDY.cluster(cluster_idx).name;
    cluster_sets = STUDY.cluster(cluster_idx).sets;
    cluster_comps = STUDY.cluster(cluster_idx).comps;
    
    % Skip if cluster is empty
    if isempty(cluster_sets) || isempty(cluster_comps)
        fprintf('Skipping empty cluster: %s\n', cluster_name);
        continue;
    end
    
    % Get the number of components in this cluster
    num_components = length(cluster_comps);
    
    fprintf('Processing cluster: %s (%d components)\n', cluster_name, num_components);
    
    % Initialize cell arrays to store data
    subjects = cell(num_components, 1);
    sessions = zeros(num_components, 1);
    comps = zeros(num_components, 1);
    mni_coords = cell(num_components, 1);
    ic_brain_labels = zeros(num_components, 1);
    
    % Extract data for each component in the cluster
    for comp_idx = 1:num_components
        
        dataset_num = cluster_sets(comp_idx);
        component_num = cluster_comps(comp_idx);
        
        try
            % Extract subject
            if isfield(ALLEEG(dataset_num), 'subject') && ~isempty(ALLEEG(dataset_num).subject)
                subjects{comp_idx} = ALLEEG(dataset_num).subject;
            else
                subjects{comp_idx} = sprintf('Subject_%d', dataset_num);
                fprintf('Warning: No subject field found for dataset %d, using default name\n', dataset_num);
            end
            
            % Extract session
            if isfield(ALLEEG(dataset_num), 'session') && ~isempty(ALLEEG(dataset_num).session)
                sessions(comp_idx) = ALLEEG(dataset_num).session;
            else
                sessions(comp_idx) = 1; % Default session number
                fprintf('Warning: No session field found for dataset %d, using default value 1\n', dataset_num);
            end
            
            % Extract component number
            comps(comp_idx) = component_num;
            
            % Extract MNI coordinates
            if isfield(ALLEEG(dataset_num), 'dipfit') && ...
               isfield(ALLEEG(dataset_num).dipfit, 'model') && ...
               length(ALLEEG(dataset_num).dipfit.model) >= component_num && ...
               isfield(ALLEEG(dataset_num).dipfit.model(component_num), 'posxyz') && ...
               ~isempty(ALLEEG(dataset_num).dipfit.model(component_num).posxyz)
                
                coords = ALLEEG(dataset_num).dipfit.model(component_num).posxyz;
                
                % Handle both single dipoles and bipolar dipoles
                if size(coords, 1) == 1
                    % Single dipole: [x y z]
                    mni_coords{comp_idx} = sprintf('[%.3f %.3f %.3f]', coords(1), coords(2), coords(3));
                elseif size(coords, 1) == 2
                    % Bipolar dipole: [x1 y1 z1; x2 y2 z2]
                    mni_coords{comp_idx} = sprintf('[%.3f %.3f %.3f;%.3f %.3f %.3f]', ...
                        coords(1,1), coords(1,2), coords(1,3), coords(2,1), coords(2,2), coords(2,3));
                else
                    % Handle unexpected coordinate matrix sizes
                    coord_str = mat2str(coords, 3);
                    mni_coords{comp_idx} = coord_str;
                end
            else
                mni_coords{comp_idx} = '[NaN NaN NaN]';
                fprintf('Warning: No dipfit coordinates found for dataset %d, component %d\n', dataset_num, component_num);
            end
            
            % Extract IC brain label
            if isfield(ALLEEG(dataset_num), 'etc') && ...
               isfield(ALLEEG(dataset_num).etc, 'ic_classification') && ...
               isfield(ALLEEG(dataset_num).etc.ic_classification, 'ICLabel') && ...
               isfield(ALLEEG(dataset_num).etc.ic_classification.ICLabel, 'classifications') && ...
               size(ALLEEG(dataset_num).etc.ic_classification.ICLabel.classifications, 1) >= component_num
                
                ic_brain_labels(comp_idx) = ALLEEG(dataset_num).etc.ic_classification.ICLabel.classifications(component_num, 1);
            else
                ic_brain_labels(comp_idx) = NaN;
                fprintf('Warning: No ICLabel classification found for dataset %d, component %d\n', dataset_num, component_num);
            end
            
        catch ME
            fprintf('Error processing dataset %d, component %d: %s\n', dataset_num, component_num, ME.message);
            % Fill with default/empty values
            subjects{comp_idx} = sprintf('Subject_%d', dataset_num);
            sessions(comp_idx) = 1;
            comps(comp_idx) = component_num;
            mni_coords{comp_idx} = '[NaN NaN NaN]';
            ic_brain_labels(comp_idx) = NaN;
        end
    end
    
    % Create table
    cluster_table = table(subjects, sessions, comps, mni_coords, ic_brain_labels, ...
                         'VariableNames', {'subject', 'session', 'comp', 'MNI_coord', 'IC_brain_label'});
    
    % Create output directory path
    output_dir = '../results/IC_clusters/';
    
    % Create filename with full path
    safe_cluster_name = regexprep(cluster_name, '[^\w\-_]', '_');
    filename = fullfile(output_dir, sprintf('%s.csv', safe_cluster_name));
    
    % Ensure the directory exists (optional but recommended)
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Write to CSV file
    try
        writetable(cluster_table, filename);
        fprintf('Successfully exported cluster "%s" to %s\n', cluster_name, filename);
    catch ME
        fprintf('Error writing file %s: %s\n', filename, ME.message);
    end
end

fprintf('\nCluster export completed!\n');
