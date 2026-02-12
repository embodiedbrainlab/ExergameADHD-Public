import os
import shutil

# Define your base directory where the participant folders are located
base_dir = 'E:\Tasnim_Dissertation_Analysis\data'

# Create lists to store target folders and file types for each type of data
folders_to_create = {
    "baseline_EEG": ("eeg/baseline_eeg", [".eeg", ".vhdr", ".vmrk"]),
    "balance_EEG": ("eeg/balance_eeg", [".eeg", ".vhdr", ".vmrk"]),
    "EF_eeg": ("eeg/executive_function_eeg", [".eeg", ".vhdr", ".vmrk"]),
    "force": ("force_plate", [".csv"]),
    "inquisit": ("inquisit", None),  # Inquisit takes all files
}

# Get all participant folders in the base directory
participants = [p for p in os.listdir(base_dir) if os.path.isdir(os.path.join(base_dir, p))]

# Iterate over each participant folder
for participant in participants:
    participant_dir = os.path.join(base_dir, participant)
    baseline_session_dir = os.path.join(participant_dir, "baseline_session")

    # Ensure the baseline_session folder exists
    if not os.path.exists(baseline_session_dir):
        print(f"Skipping {participant}: No baseline_session folder")
        continue

    # Create the new target folders for each participant in the base directory
    for new_folder, (source_subfolder, file_types) in folders_to_create.items():
        new_folder_path = os.path.join(base_dir, new_folder)
        if not os.path.exists(new_folder_path):
            os.makedirs(new_folder_path)

        source_folder = os.path.join(baseline_session_dir, source_subfolder)

        # If the source folder exists, copy the relevant files
        if os.path.exists(source_folder):
            for root, dirs, files in os.walk(source_folder):
                for file in files:
                    # If file types are specified (for EEG and force), filter them
                    if file_types:
                        if any(file.endswith(ft) for ft in file_types):
                            src_file_path = os.path.join(root, file)
                            dst_file_path = os.path.join(new_folder_path, f"{file}")
                            shutil.copy2(src_file_path, dst_file_path)
                            print(f"Copied {file} to {new_folder_path}")
                    # For inquisit, copy all files
                    else:
                        src_file_path = os.path.join(root, file)
                        dst_file_path = os.path.join(new_folder_path, f"{file}")
                        shutil.copy2(src_file_path, dst_file_path)
                        print(f"Copied {file} to {new_folder_path}")
        else:
            print(f"Skipping {source_subfolder} for {participant}: Folder does not exist")
