% CONVERT PHOTOSENSOR DATA TO EEGLAB .SET FILES
% Files were bulk converted from .DAT files, so they need to be renamed and
% converted to .set files for organizational purposes.
%
% Written by Noor Tasnim on July 22, 2025

%% Import EEGLAB function

eeglab;
close;
clear

%% Convert Tasks

tasks = {'gonogo','stroop','wcst'};

for task_idx = 1:length(tasks)
    files = dir(['../data/photoTesting/' tasks{task_idx} '/bv_format/*.vhdr']);
    for i = 1:length(files)
        EEG = pop_loadbv(['../data/photoTesting/' tasks{task_idx} '/bv_format/'],files(i).name);
        EEG = pop_saveset(EEG,'filename',[tasks{task_idx} '_' num2str(i) '.set'],...
            'filepath',['../data/photoTesting/' tasks{task_idx} '/set_format/']);
    end
end