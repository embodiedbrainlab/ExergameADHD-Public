import os
import shutil
import csv
from datetime import datetime

# Define your base directory where the participant folders are located
base_dir = '../participants_only_included_for_baseline'
target_dir = '../balance_data'

# Define expected file endings for each session type
expected_files = {
    'baseline_session': [
        'shoulder 1-1.csv', 'shoulder 1-2.csv', 'shoulder 1-3.csv',
        'tandem 1-1.csv', 'tandem 1-2.csv', 'tandem 1-3.csv'
    ],
    'intervention_session': [
        'shoulder 2-1.csv', 'shoulder 2-2.csv', 'shoulder 2-3.csv',
        'tandem 2-1.csv', 'tandem 2-2.csv', 'tandem 2-3.csv'
    ]
}

# Create target directories if they don't exist
baseline_target = os.path.join(target_dir, 'baseline')
intervention_target = os.path.join(target_dir, 'intervention')

for dir_path in [target_dir, baseline_target, intervention_target]:
    if not os.path.exists(dir_path):
        os.makedirs(dir_path)
        print(f"Created directory: {dir_path}")

# Initialize logging
log_file = os.path.join(target_dir, f'file_copy_log_{datetime.now().strftime("%Y%m%d_%H%M%S")}.txt')
missing_files_log = os.path.join(target_dir, f'missing_files_{datetime.now().strftime("%Y%m%d_%H%M%S")}.txt')

# Get all participant folders (those starting with 'exgm')
participants = [p for p in os.listdir(base_dir)
                if os.path.isdir(os.path.join(base_dir, p)) and p.startswith('exgm')]

print(f"Found {len(participants)} participant folders")
print("-" * 50)

# Track overall statistics
total_copied = 0
total_skipped = 0
participants_with_missing = []

with open(log_file, 'w') as log, open(missing_files_log, 'w') as missing_log:
    log.write(f"Force Plate File Copy Log - {datetime.now()}\n")
    log.write("=" * 50 + "\n\n")

    missing_log.write(f"Missing Files Report - {datetime.now()}\n")
    missing_log.write("=" * 50 + "\n\n")

    # Iterate over each participant folder
    for participant in sorted(participants):
        participant_dir = os.path.join(base_dir, participant)
        print(f"\nProcessing participant: {participant}")
        log.write(f"\nParticipant: {participant}\n")
        log.write("-" * 30 + "\n")

        participant_has_missing = False

        # Process both baseline and intervention sessions
        for session_type in ['baseline_session', 'intervention_session']:
            session_dir = os.path.join(participant_dir, session_type)
            force_plate_dir = os.path.join(session_dir, 'force_plate')

            # Determine target directory based on session type
            if session_type == 'baseline_session':
                target_session_dir = baseline_target
                session_label = 'baseline'
            else:
                target_session_dir = intervention_target
                session_label = 'intervention'

            # Check if force_plate directory exists
            if not os.path.exists(force_plate_dir):
                print(f"  ⚠ No force_plate folder found in {session_type}")
                log.write(f"  WARNING: No force_plate folder in {session_type}\n")
                missing_log.write(f"{participant} - {session_type}: force_plate folder missing\n")
                participant_has_missing = True
                continue

            # Get all CSV files in the force_plate directory, excluding hidden files
            all_files = os.listdir(force_plate_dir)
            csv_files = [f for f in all_files if f.endswith('.csv') and not f.startswith('._')]
            hidden_files = [f for f in all_files if f.startswith('._')]

            # Log if hidden files were found and skipped
            if hidden_files:
                print(f"  ℹ Skipping {len(hidden_files)} hidden file(s) in {session_type}")
                log.write(f"  INFO: Skipped {len(hidden_files)} hidden files (._*)\n")
                total_skipped += len(hidden_files)

            # Check for expected files
            found_files = []
            missing_files = []

            for expected_ending in expected_files[session_type]:
                file_found = False
                for csv_file in csv_files:
                    if csv_file.endswith(expected_ending):
                        found_files.append(csv_file)
                        file_found = True
                        break

                if not file_found:
                    missing_files.append(expected_ending)
                    participant_has_missing = True

            # Log missing files
            if missing_files:
                print(f"  ⚠ Missing files in {session_type}:")
                missing_log.write(f"{participant} - {session_type} missing files:\n")
                for mf in missing_files:
                    print(f"    - {mf}")
                    missing_log.write(f"  - {mf}\n")

            # Copy found files (excluding hidden files)
            copied_count = 0
            for csv_file in csv_files:
                src_path = os.path.join(force_plate_dir, csv_file)
                # Create new filename with participant ID prefix
                new_filename = f"{participant}_{csv_file}"
                dst_path = os.path.join(target_session_dir, new_filename)

                try:
                    shutil.copy2(src_path, dst_path)
                    copied_count += 1
                    total_copied += 1
                    print(f"  ✓ Copied: {csv_file} -> {session_label}/{new_filename}")
                    log.write(f"  COPIED: {csv_file} -> {session_label}/{new_filename}\n")
                except Exception as e:
                    print(f"  ✗ Error copying {csv_file}: {e}")
                    log.write(f"  ERROR: Failed to copy {csv_file}: {e}\n")

            # Summary for this session
            print(f"  Summary: {copied_count} files copied from {session_type}")
            log.write(f"  Session summary: {copied_count} files copied, {len(missing_files)} files missing\n")

        if participant_has_missing:
            participants_with_missing.append(participant)

# Print final summary
print("\n" + "=" * 50)
print("COPY OPERATION COMPLETE")
print(f"Total files copied: {total_copied}")
print(f"Total hidden files skipped: {total_skipped}")
print(f"Participants processed: {len(participants)}")
print(f"Participants with missing files: {len(participants_with_missing)}")

if participants_with_missing:
    print("\nParticipants with missing files:")
    for p in participants_with_missing:
        print(f"  - {p}")

print(f"\nLogs saved to:")
print(f"  - {log_file}")
print(f"  - {missing_files_log}")

# Create a summary CSV file for easier review
summary_csv = os.path.join(target_dir, f'file_status_summary_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv')
with open(summary_csv, 'w', newline='') as csvfile:
    fieldnames = ['Participant', 'Session', 'File_Type', 'Status']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

    for participant in sorted(participants):
        participant_dir = os.path.join(base_dir, participant)

        for session_type in ['baseline_session', 'intervention_session']:
            session_dir = os.path.join(participant_dir, session_type)
            force_plate_dir = os.path.join(session_dir, 'force_plate')

            if os.path.exists(force_plate_dir):
                # Exclude hidden files when checking
                csv_files = [f for f in os.listdir(force_plate_dir)
                             if f.endswith('.csv') and not f.startswith('._')]

                for expected_ending in expected_files[session_type]:
                    file_found = any(f.endswith(expected_ending) for f in csv_files)
                    writer.writerow({
                        'Participant': participant,
                        'Session': session_type,
                        'File_Type': expected_ending,
                        'Status': 'Found' if file_found else 'Missing'
                    })
            else:
                for expected_ending in expected_files[session_type]:
                    writer.writerow({
                        'Participant': participant,
                        'Session': session_type,
                        'File_Type': expected_ending,
                        'Status': 'Folder Missing'
                    })

print(f"  - {summary_csv}")