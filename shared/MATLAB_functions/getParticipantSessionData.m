function [digitforward, digitbackward, gonogo, stroop, wcst] = getParticipantSessionData(dataTable, participantID, sessionNum)
    % getParticipantSessionData retrieves the values for a specific participant
    % and session from the table.
    %
    % Inputs:
    %   dataTable: The MATLAB table containing the data
    %   participantID: The ID number of the participant
    %   sessionNum: The session number for the participant
    %
    % Outputs:
    %   digitforward: Value for digit forward task
    %   digitbackward: Value for digit backward task
    %   gonogo: Value for Go/No-Go task
    %   stroop: Value for Stroop task
    %   wcst: Value for WCST task

    % Find the row in the table that matches the participant ID and session
    rowIndex = strcmp(dataTable.participant_id, participantID) & dataTable.session == sessionNum;

    % If no matching row is found, throw an error
    if ~any(rowIndex)
        error('No data found for the given participant ID and session number.');
    end

    % Setting Index Values
    % We add 1 to Baseline Session values because only 1 pre-baseline
    % recording will be preprocess with datasets.
    %
    % We add 2 to Intervention Session values because a pre-baseline and
    % post-baseline recording are preprocessed with datasets

    if sessionNum == 1 % Baseline Session
        % Extract the values from the matching row
        digitforward = dataTable.digitforward(rowIndex) + 1;
        digitbackward = dataTable.digitbackward(rowIndex) + 1;
        gonogo = dataTable.gonogo(rowIndex) + 1;
        stroop = dataTable.stroop(rowIndex) + 1;
        wcst = dataTable.wcst(rowIndex) + 1;
    elseif sessionNum == 2
        % Extract the values from the matching row
        digitforward = dataTable.digitforward(rowIndex) + 2;
        digitbackward = dataTable.digitbackward(rowIndex) + 2;
        gonogo = dataTable.gonogo(rowIndex) + 2;
        stroop = dataTable.stroop(rowIndex) + 2;
        wcst = dataTable.wcst(rowIndex) + 2;
    else
        error('A session number other than 1 or 2 was entered into this function.')
    end

end
