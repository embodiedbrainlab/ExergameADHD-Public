import pandas as pd
import numpy as np
from scipy import signal
import os
import re
from pathlib import Path
from dataclasses import dataclass
from typing import Dict, List, Tuple
import warnings


@dataclass
class TrialData:
    """Data structure to store processed trial information"""
    subject_id: str
    trial_name: str
    session: str  # 'baseline' or 'intervention'
    sampling_rate: int
    time_raw: np.ndarray
    ml_raw: np.ndarray
    ap_raw: np.ndarray
    time_trimmed: np.ndarray
    ml_filtered: np.ndarray
    ap_filtered: np.ndarray


class ForcePlateProcessor:
    def __init__(self, baseline_dir: str = 'data/baseline/',
                 intervention_dir: str = 'data/intervention/'):
        """
        Initialize the processor with data directories

        Parameters:
        -----------
        baseline_dir : str
            Path to baseline data directory
        intervention_dir : str
            Path to intervention data directory
        """
        self.baseline_dir = Path(baseline_dir)
        self.intervention_dir = Path(intervention_dir)
        self.expected_sampling_rate = 1500
        self.filter_cutoff = 5  # Hz
        self.filter_order = 4
        self.start_time = 10  # seconds
        self.end_time = 30  # seconds
        self.processed_data = {}

    def validate_subject_id(self, subject_id: str) -> bool:
        """
        Validate that subject ID follows the pattern 'exgm' + 3 digits

        Parameters:
        -----------
        subject_id : str
            Subject ID to validate

        Returns:
        --------
        bool
            True if valid, False otherwise
        """
        pattern = r'^exgm\d{3}$'
        return bool(re.match(pattern, subject_id))

    def validate_trial_name(self, trial_name: str) -> bool:
        """
        Validate that trial name follows expected patterns

        Parameters:
        -----------
        trial_name : str
            Trial name to validate

        Returns:
        --------
        bool
            True if valid, False otherwise
        """
        # Pattern for Shoulder or Tandem trials with session and trial numbers
        pattern = r'^(Shoulder|Tandem)\s+[12]-[123]$'
        return bool(re.match(pattern, trial_name, re.IGNORECASE))

    def apply_butterworth_filter(self, data: np.ndarray, sampling_rate: int) -> np.ndarray:
        """
        Apply 4th-order zero-phase low-pass Butterworth filter

        Parameters:
        -----------
        data : np.ndarray
            Input signal to filter
        sampling_rate : int
            Sampling frequency in Hz

        Returns:
        --------
        np.ndarray
            Filtered signal
        """
        nyquist = sampling_rate / 2
        normalized_cutoff = self.filter_cutoff / nyquist

        # Design the filter
        b, a = signal.butter(self.filter_order, normalized_cutoff,
                             btype='low', analog=False)

        # Apply zero-phase filtering (forward and backward)
        filtered_data = signal.filtfilt(b, a, data)

        return filtered_data

    def process_csv_file(self, filepath: Path, session: str) -> TrialData:
        """
        Process a single CSV file

        Parameters:
        -----------
        filepath : Path
            Path to the CSV file
        session : str
            'baseline' or 'intervention'

        Returns:
        --------
        TrialData
            Processed trial data
        """
        print(f"Processing: {filepath.name}")

        try:
            # Read the entire file without any parsing first
            # This handles the mixed structure better
            all_data = []
            with open(filepath, 'r', encoding='utf-8-sig') as f:  # utf-8-sig handles BOM if present
                for line in f:
                    # Split by comma and strip whitespace
                    row = [cell.strip() for cell in line.strip().split(',')]
                    all_data.append(row)

            # Now we have all rows as lists of strings
            print(f"  Total rows read: {len(all_data)}")

            # Extract metadata from the first few rows
            # Based on your Excel image:
            # Row 2 (index 1): Contains the actual metadata values
            metadata_row = all_data[1] if len(all_data) > 1 else []

            # 1. Check sampling rate (Cell C2 - index 2)
            try:
                sampling_rate_str = metadata_row[2] if len(metadata_row) > 2 else ""
                # Extract just the number (in case it has units like "Hz")
                sampling_rate_match = re.search(r'(\d+)', sampling_rate_str)
                if sampling_rate_match:
                    sampling_rate = int(sampling_rate_match.group(1))
                else:
                    sampling_rate = self.expected_sampling_rate
                    print(f"  Warning: Could not parse sampling rate, using default {self.expected_sampling_rate}")
            except (ValueError, IndexError) as e:
                print(f"  Warning: Could not read sampling rate, using default {self.expected_sampling_rate}")
                sampling_rate = self.expected_sampling_rate

            if sampling_rate != self.expected_sampling_rate:
                warnings.warn(
                    f"Sampling rate {sampling_rate} Hz does not match expected {self.expected_sampling_rate} Hz")

            # 2. Get subject ID (Cell H2 - index 7)
            try:
                subject_id = metadata_row[7] if len(metadata_row) > 7 else ""
                subject_id = subject_id.strip()
            except (IndexError, KeyError):
                print(f"  Warning: Could not read subject ID from expected location")
                subject_id = "unknown"

            if not self.validate_subject_id(subject_id):
                warnings.warn(f"Invalid subject ID format: {subject_id}")
                # Try to extract from filename as backup
                filename_match = re.search(r'exgm\d{3}', filepath.name)
                if filename_match:
                    subject_id = filename_match.group()
                    print(f"  Using subject ID from filename: {subject_id}")

            # 3. Get trial name (Cell M2 - index 12)
            try:
                trial_name = metadata_row[12] if len(metadata_row) > 12 else ""
                trial_name = trial_name.strip()
            except (IndexError, KeyError):
                print(f"  Warning: Could not read trial name from expected location")
                trial_name = "unknown"

            if not self.validate_trial_name(trial_name):
                warnings.warn(f"Unexpected trial name format: {trial_name}")

            # Now process the actual data starting from row 5 (index 4)
            data_rows = all_data[4:] if len(all_data) > 4 else []

            # Convert to numpy arrays
            time_data = []
            ml_data = []
            ap_data = []

            for row in data_rows:
                try:
                    # Make sure row has enough columns
                    if len(row) >= 28:  # Need at least 28 columns for column AB (index 27)
                        # Column A (index 0) - Time
                        time_val = float(row[0]) if row[0] else np.nan
                        # Column AA (index 26) - ML
                        ml_val = float(row[26]) if row[26] else np.nan
                        # Column AB (index 27) - AP
                        ap_val = float(row[27]) if row[27] else np.nan

                        time_data.append(time_val)
                        ml_data.append(ml_val)
                        ap_data.append(ap_val)
                except (ValueError, IndexError):
                    # Skip rows that can't be parsed
                    continue

            # Convert to numpy arrays
            time_data = np.array(time_data)
            ml_data = np.array(ml_data)
            ap_data = np.array(ap_data)

            print(f"  Data rows parsed: {len(time_data)}")

            # Remove any NaN values
            #valid_indices = ~(np.isnan(time_data) | np.isnan(ml_data) | np.isnan(ap_data))
            #time_data = time_data[valid_indices]
            #ml_data = ml_data[valid_indices]
            #ap_data = ap_data[valid_indices]

            #print(f"  Valid samples after NaN removal: {len(time_data)}")

            # Extract data from 10 to 30 seconds
            time_mask = (time_data >= self.start_time) & (time_data <= self.end_time)
            time_trimmed = time_data[time_mask]
            ml_trimmed = ml_data[time_mask]
            ap_trimmed = ap_data[time_mask]

            print(f"  Samples in 10-30s window: {len(time_trimmed)}")

            if len(time_trimmed) == 0:
                warnings.warn(f"No data found in the {self.start_time}-{self.end_time} second window")
                ml_filtered = np.array([])
                ap_filtered = np.array([])
            else:
                # Apply Butterworth filter to trimmed data
                ml_filtered = self.apply_butterworth_filter(ml_trimmed, sampling_rate)
                ap_filtered = self.apply_butterworth_filter(ap_trimmed, sampling_rate)
                print(f"  Filtering completed successfully")

            # Create TrialData object
            trial_data = TrialData(
                subject_id=subject_id,
                trial_name=trial_name,
                session=session,
                sampling_rate=sampling_rate,
                time_raw=time_data,
                ml_raw=ml_data,
                ap_raw=ap_data,
                time_trimmed=time_trimmed,
                ml_filtered=ml_filtered,
                ap_filtered=ap_filtered
            )

            return trial_data

        except Exception as e:
            print(f"  Error details: {str(e)}")
            raise

    def process_all_files(self) -> Dict[str, List[TrialData]]:
        """
        Process all CSV files in both directories

        Returns:
        --------
        Dict[str, List[TrialData]]
            Dictionary with subject IDs as keys and lists of TrialData as values
        """
        all_files = []

        # Collect baseline files
        if self.baseline_dir.exists():
            baseline_files = list(self.baseline_dir.glob('*.csv'))
            all_files.extend([(f, 'baseline') for f in baseline_files])
            print(f"Found {len(baseline_files)} baseline files")
        else:
            warnings.warn(f"Baseline directory not found: {self.baseline_dir}")

        # Collect intervention files
        if self.intervention_dir.exists():
            intervention_files = list(self.intervention_dir.glob('*.csv'))
            all_files.extend([(f, 'intervention') for f in intervention_files])
            print(f"Found {len(intervention_files)} intervention files")
        else:
            warnings.warn(f"Intervention directory not found: {self.intervention_dir}")

        if not all_files:
            print("No CSV files found in the specified directories!")
            return self.processed_data

        # Process each file
        successful = 0
        failed = 0

        for filepath, session in all_files:
            try:
                trial_data = self.process_csv_file(filepath, session)

                # Organize by subject ID
                if trial_data.subject_id not in self.processed_data:
                    self.processed_data[trial_data.subject_id] = []

                self.processed_data[trial_data.subject_id].append(trial_data)
                successful += 1

            except Exception as e:
                print(f"ERROR processing {filepath.name}: {str(e)}")
                failed += 1
                continue

        print(f"\n" + "=" * 50)
        print(f"Processing complete!")
        print(f"Successfully processed: {successful} files")
        print(f"Failed: {failed} files")
        print(f"Total subjects: {len(self.processed_data)}")
        print("=" * 50)

        return self.processed_data

    def get_summary(self) -> pd.DataFrame:
        """
        Generate a summary DataFrame of all processed trials

        Returns:
        --------
        pd.DataFrame
            Summary of all trials
        """
        summary_data = []

        for subject_id, trials in self.processed_data.items():
            for trial in trials:
                summary_data.append({
                    'Subject_ID': trial.subject_id,
                    'Trial_Name': trial.trial_name,
                    'Session': trial.session,
                    'Sampling_Rate': trial.sampling_rate,
                    'Total_Samples': len(trial.time_raw),
                    'Trimmed_Samples': len(trial.time_trimmed),
                    'ML_Mean': np.mean(trial.ml_filtered) if len(trial.ml_filtered) > 0 else np.nan,
                    'ML_Std': np.std(trial.ml_filtered) if len(trial.ml_filtered) > 0 else np.nan,
                    'AP_Mean': np.mean(trial.ap_filtered) if len(trial.ap_filtered) > 0 else np.nan,
                    'AP_Std': np.std(trial.ap_filtered) if len(trial.ap_filtered) > 0 else np.nan
                })

        return pd.DataFrame(summary_data)


# Test function to check a single file
def test_single_file(filepath):
    """
    Test processing of a single file for debugging
    """
    processor = ForcePlateProcessor()
    session = 'baseline' if '1-' in filepath else 'intervention'

    try:
        trial_data = processor.process_csv_file(Path(filepath), session)
        print(f"\nSuccessfully processed!")
        print(f"Subject ID: {trial_data.subject_id}")
        print(f"Trial Name: {trial_data.trial_name}")
        print(f"Sampling Rate: {trial_data.sampling_rate} Hz")
        print(f"Total samples: {len(trial_data.time_raw)}")
        print(f"Samples in 10-30s window: {len(trial_data.time_trimmed)}")
        return trial_data
    except Exception as e:
        print(f"Failed to process: {e}")
        return None


# Main function
def main():
    """
    Main function to run the processing pipeline
    """
    # Initialize processor
    processor = ForcePlateProcessor(
        baseline_dir='data/baseline/',
        intervention_dir='data/intervention/'
    )

    # Process all files
    processed_data = processor.process_all_files()

    if processed_data:
        # Get summary
        summary_df = processor.get_summary()
        print("\nSummary of processed data:")
        print(summary_df.to_string())

        # Save summary to CSV
        summary_df.to_csv('data/force_plate_summary.csv', index=False)
        print("\nSummary saved to 'data/force_plate_summary.csv'")

        # Access specific trial data example
        for subject_id, trials in processed_data.items():
            print(f"\nSubject {subject_id} has {len(trials)} trials:")
            for trial in trials:
                print(f"  - {trial.trial_name} ({trial.session}): "
                      f"{len(trial.time_trimmed)} samples in analysis window")
    else:
        print("\nNo data was successfully processed!")

    return processed_data


# Run the processing
if __name__ == "__main__":
    # Option 1: Process all files
    processed_data = main()

    # Option 2: Test a single file first (uncomment to use)
    # test_data = test_single_file('../data/baseline/your_file.csv')