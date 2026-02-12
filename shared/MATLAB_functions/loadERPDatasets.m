function erpData = loadERPDatasets()
    % Define base paths
    basePath = '../data/erp/11_group_analysis';
    basePathERN = '../data/erp/ERN/11_group_analysis';
    
    % Define experiment configurations
    experiments = {
        'gonogo', basePath;
        'stroop', basePath;
        'wcst',   basePathERN
    };
    
    % Define common parameters
    sessions = {'session1', 'session2'};
    conditions = {'non-stimulants', 'stimulants'};
    filterStates = {'', 'filtered'};  % empty for unfiltered, 'filtered' for filtered
    
    % Initialize output structure
    erpData = struct();
    
    % Loop through all combinations
    for expIdx = 1:size(experiments, 1)
        expName = experiments{expIdx, 1};
        expBasePath = experiments{expIdx, 2};
        
        for filterIdx = 1:length(filterStates)
            % Determine filter state and field name
            if isempty(filterStates{filterIdx})
                filterLabel = 'unfilt';
                filterPath = '';
            else
                filterLabel = 'filt';
                filterPath = 'filtered/';
            end
            
            % Collect all files for this experiment and filter state
            allFiles = [];
            
            for sessionIdx = 1:length(sessions)
                for condIdx = 1:length(conditions)
                    % Build path
                    if isempty(filterPath)
                        % Unfiltered path
                        fullPath = fullfile(expBasePath, sessions{sessionIdx}, ...
                                          expName, conditions{condIdx}, '*.erp');
                    else
                        % Filtered path
                        fullPath = fullfile(expBasePath, sessions{sessionIdx}, ...
                                          expName, conditions{condIdx}, filterPath, '*.erp');
                    end
                    
                    % Get files and concatenate
                    files = dir(fullPath);
                    allFiles = [allFiles; files];
                end
            end
            
            % Store in output structure
            fieldName = sprintf('%s_%s', expName, filterLabel);
            erpData.(fieldName) = allFiles;
        end
    end
end
