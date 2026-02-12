% CHECK SPECPARAM COMPLETENESS
% Run this script to ensure the .mat file produced by SpecParamPrep lists
% all PSDs needed for analysis.
%
% For context, we found that exgm169 - gonogo was missing data, so we ran
% this script to identify other missing datasets (if there were any).
%
% This script shecks for missing and duplicate subject x experience 
% combinations per cluster.
% Outputs missing combinations to CSV file

%% Load .mat file

load("exergame_session1_PowerSpectrumResults.mat")

%% Define expected experiences
expected_experiences = {
    'digitbackward'
    'digitforward'
    'gonogo'
    'prebaseline'
    'shoulder_1'
    'shoulder_2'
    'shoulder_3'
    'stroop'
    'tandem_1'
    'tandem_2'
    'tandem_3'
    'wcst'
};

%% Extract data from structure
subjects = {results.subject}';
experiences = {results.experience}';
clusters = [results.cluster]';

% Convert to table for easier manipulation
data_table = table(subjects, experiences, clusters, ...
    'VariableNames', {'subject', 'experience', 'cluster'});

fprintf('Total records in dataset: %d\n\n', height(data_table));

%% Get unique values
unique_subjects = unique(subjects);
unique_clusters = unique(clusters);

fprintf('Number of unique subjects: %d\n', length(unique_subjects));
fprintf('Number of unique clusters: %d\n', length(unique_clusters));
fprintf('Number of expected experiences: %d\n\n', length(expected_experiences));

%% Check for duplicates
fprintf('=== CHECKING FOR DUPLICATES ===\n');
duplicate_found = false;

for c = 1:length(unique_clusters)
    cluster_id = unique_clusters(c);
    cluster_data = data_table(clusters == cluster_id, :);
    
    % Create composite key for subject x experience
    composite_key = strcat(cluster_data.subject, '_', cluster_data.experience);
    
    % Find duplicates
    [unique_keys, ~, idx] = unique(composite_key);
    counts = accumarray(idx, 1);
    duplicate_keys = unique_keys(counts > 1);
    
    if ~isempty(duplicate_keys)
        duplicate_found = true;
        fprintf('\nCluster %d: Found %d duplicate subject x experience combinations:\n', ...
            cluster_id, length(duplicate_keys));
        for i = 1:length(duplicate_keys)
            parts = split(duplicate_keys{i}, '_');
            dup_subject = parts{1};
            dup_experience = parts{2};
            num_occurrences = counts(strcmp(unique_keys, duplicate_keys{i}));
            fprintf('  Subject: %s, Experience: %s (appears %d times)\n', ...
                dup_subject, dup_experience, num_occurrences);
        end
    end
end

if ~duplicate_found
    fprintf('No duplicates found. ✓\n');
end

%% Check for missing combinations
fprintf('\n=== CHECKING FOR MISSING DATA ===\n');

% Initialize array to store missing combinations
missing_data = {};
missing_count = 0;

for c = 1:length(unique_clusters)
    cluster_id = unique_clusters(c);
    cluster_data = data_table(clusters == cluster_id, :);
    
    % Get subjects present in THIS cluster only
    subjects_in_cluster = unique(cluster_data.subject);
    
    fprintf('Cluster %d: %d subjects\n', cluster_id, length(subjects_in_cluster));
    
    for s = 1:length(subjects_in_cluster)
        subject_id = subjects_in_cluster{s};
        
        % Check which experiences this subject has in this cluster
        subject_experiences = cluster_data.experience(strcmp(cluster_data.subject, subject_id));
        
        % Check for missing experiences
        for e = 1:length(expected_experiences)
            experience_name = expected_experiences{e};
            
            if ~any(strcmp(subject_experiences, experience_name))
                missing_count = missing_count + 1;
                missing_data{missing_count, 1} = cluster_id;
                missing_data{missing_count, 2} = subject_id;
                missing_data{missing_count, 3} = experience_name;
            end
        end
        
        % Report if subject has wrong number of experiences
        num_experiences = length(subject_experiences);
        if num_experiences ~= 12
            fprintf('  ⚠ Subject %s has %d experiences (expected 12)\n', ...
                subject_id, num_experiences);
        end
    end
end

%% Report and save results
if missing_count == 0
    fprintf('No missing data found. All subject x experience combinations are present for all clusters. ✓\n');
    
    % Create empty CSV with headers
    missing_table = table([], {}, {}, ...
        'VariableNames', {'cluster', 'subject', 'experience'});
    writetable(missing_table, 'missing_data.csv');
    fprintf('\nEmpty CSV file created: missing_data.csv\n');
else
    fprintf('Found %d missing subject x experience combinations.\n', missing_count);
    
    % Convert to table
    missing_table = cell2table(missing_data, ...
        'VariableNames', {'cluster', 'subject', 'experience'});
    
    % Sort by cluster, then subject, then experience
    missing_table = sortrows(missing_table, {'cluster', 'subject', 'experience'});
    
    % Save to CSV
    writetable(missing_table, 'missing_data.csv');
    fprintf('\nMissing data saved to: missing_data.csv\n');
    
    % Display summary by cluster
    fprintf('\nSummary by cluster:\n');
    for c = 1:length(unique_clusters)
        cluster_id = unique_clusters(c);
        cluster_missing = sum(missing_table.cluster == cluster_id);
        if cluster_missing > 0
            fprintf('  Cluster %d: %d missing combinations\n', cluster_id, cluster_missing);
        end
    end
end

%% Summary statistics
fprintf('\n=== SUMMARY ===\n');

% Calculate expected total based on subjects present in each cluster
expected_total = 0;
for c = 1:length(unique_clusters)
    cluster_id = unique_clusters(c);
    cluster_data = data_table(clusters == cluster_id, :);
    subjects_in_cluster = unique(cluster_data.subject);
    expected_total = expected_total + (length(subjects_in_cluster) * length(expected_experiences));
end

actual_total = height(data_table);
fprintf('Expected total records: %d\n', expected_total);
fprintf('Actual total records: %d\n', actual_total);
fprintf('Completeness: %.2f%%\n', (actual_total / expected_total) * 100);

if duplicate_found
    fprintf('\n⚠ WARNING: Duplicates detected! Review output above.\n');
end

if missing_count > 0
    fprintf('⚠ WARNING: Missing data detected! Check missing_data.csv\n');
end

if ~duplicate_found && missing_count == 0
    fprintf('\n✓ Data validation passed: No duplicates or missing data.\n');
end