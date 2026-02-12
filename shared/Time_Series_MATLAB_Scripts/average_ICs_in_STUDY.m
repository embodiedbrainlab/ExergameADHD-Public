% FIND AVERAGE NUMBER OF ICs FOR CLUSTERING
% To conduct optimal k-means clustering, we need to set min vs. max numbers
% of ICs that will be in each cluster.
% 
% Once you have created the EEGLAB study, this script will run through all
% your datasets, detect how many components are in each, and calculate the
% average number of components in your study.

%% MAKE SURE YOUR EEGLAB STUDY IS LOADED BEFORE RUNNING THIS SCRIPT!!!

% Get number of rows in STUDY.datasetinfo
num_rows = length(STUDY.datasetinfo);

% Initialize array to store vector lengths
vector_lengths = zeros(num_rows, 1);

% Calculate length of each vector from each row
for i = 1:num_rows
    comps_vector = STUDY.datasetinfo(i).comps;
    if ~isempty(comps_vector)
        vector_lengths(i) = length(comps_vector);
    else
        vector_lengths(i) = 0;  % Handle empty vectors
    end
end

% Calculate average length
avg_length = mean(vector_lengths);
% Calculate standard deviation
std_length = std(vector_lengths);

% Calculate Minimum and Maximum (for reporting)
min_length = min(vector_lengths);
max_length = max(vector_lengths);

% Display results
fprintf('Total number of vectors: %d\n', num_rows);
fprintf('Average vector length: %.2f\n', avg_length);
fprintf('Standard Deviation of vector length: %.2f\n', std_length);
fprintf('Minimum vector length: %.2f\n', min_length);
fprintf('Maximum vector length: %.2f\n', max_length);