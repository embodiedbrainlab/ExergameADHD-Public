# General Imports to work with files
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import io
import h5py
import os

# Loading from EEGLAB Datasets
def load_matlab_spectra(mat_file_path):
    """
    Load the MATLAB .mat file containing EEG spectra results
    Supports both regular .mat files and v7.3 (HDF5) format

    Parameters:
    mat_file_path (str): Path to the .mat file created by the MATLAB script

    Returns:
    dict or h5py.File: Dictionary or HDF5 file object containing all the loaded data
    """
    try:
        # First try to load as regular .mat file
        try:
            mat_data = io.loadmat(mat_file_path)
            print(f"Successfully loaded as regular .mat file: {mat_file_path}")
            return mat_data, 'scipy'
        except NotImplementedError:
            # If it fails with NotImplementedError, it's likely a v7.3 file
            print("File appears to be MATLAB v7.3 format, loading with h5py...")
            mat_data = h5py.File(mat_file_path, 'r')
            print(f"Successfully loaded as HDF5/v7.3 file: {mat_file_path}")

            # Display available variables in the HDF5 file
            print("Available variables in .mat file:")
            for key in mat_data.keys():
                print(f"  - {key}: {type(mat_data[key])}")

            return mat_data, 'h5py'

    except FileNotFoundError:
        print(f"Error: File not found - {mat_file_path}")
        return None, None
    except Exception as e:
        print(f"Error loading .mat file: {e}")
        return None, None

# Extracting data from the .mat file
def extract_spectra_data(mat_data, format_type='scipy'):
    """
    Extract and organize spectra data from the loaded MATLAB structure

    Parameters:
    mat_data (dict or h5py.File): Data from scipy.io.loadmat or h5py
    format_type (str): Either 'scipy' or 'h5py' to indicate data format

    Returns:
    pandas.DataFrame: Organized spectra data
    """

    if format_type == 'h5py':
        return extract_spectra_data_h5py(mat_data)
    else:
        return extract_spectra_data_scipy(mat_data)


def extract_spectra_data_scipy(mat_data):
    """Original scipy-based extraction function"""
    # Your existing code here (keep the original implementation)
    # ... (all the existing code from your original extract_spectra_data function)


def extract_spectra_data_h5py(mat_data):
    """
    Extract spectra data from HDF5/v7.3 MATLAB file

    Parameters:
    mat_data (h5py.File): HDF5 file object

    Returns:
    pandas.DataFrame: Organized spectra data
    """
    # Check for either 'results' or 'results_filtered'
    if 'results' in mat_data:
        results = mat_data['results']
    elif 'results_filtered' in mat_data:
        results = mat_data['results_filtered']
    else:
        print("Error: Neither 'results' nor 'results_filtered' found in .mat file")
        print(f"Available variables: {list(mat_data.keys())}")
        return None

    # Initialize lists to store extracted data
    data_list = []

    # Check if results is a Group (structured array) or Dataset
    if isinstance(results, h5py.Group):
        # It's a structured array - fields are stored as separate datasets
        print("Results is a structured array (Group)")
        print(f"Available fields in results: {list(results.keys())}")

        # Get the number of entries from one of the fields
        # We need to check different fields to find the correct dimension
        num_entries = None
        sample_field_name = None

        # Try to find a reliable field to determine the number of entries
        for field_name in ['subject', 'session', 'component', 'spectra']:
            if field_name in results:
                sample_field = results[field_name]
                sample_field_name = field_name
                if isinstance(sample_field, h5py.Dataset):
                    print(f"Checking field '{field_name}' with shape: {sample_field.shape}")
                    # MATLAB stores struct arrays in different ways:
                    # - For scalar fields: shape might be (1, n) or (n, 1) or (n,)
                    # - For array fields: shape might be (m, n) where n is number of entries

                    if len(sample_field.shape) == 1:
                        num_entries = sample_field.shape[0]
                    elif len(sample_field.shape) == 2:
                        # In MATLAB, struct arrays often store data with entries as first dimension
                        # But sometimes it's transposed
                        # We need to determine which dimension represents entries

                        # Check if this is likely a spectra field (should have many frequency points)
                        if field_name == 'spectra':
                            # Spectra typically has shape (freq_points, num_entries) or (num_entries, freq_points)
                            # Frequency points are typically 251 or similar
                            if sample_field.shape[0] > 100 and sample_field.shape[1] < 100:
                                # Likely (freq_points, num_entries)
                                num_entries = sample_field.shape[1]
                            elif sample_field.shape[1] > 100 and sample_field.shape[0] > 1000:
                                # Likely (num_entries, freq_points)
                                num_entries = sample_field.shape[0]
                            else:
                                # Default to second dimension for spectra
                                num_entries = sample_field.shape[1]
                        else:
                            # For other fields, entries are typically in the first dimension
                            # Check both dimensions and use the larger one as entries count
                            if sample_field.shape[0] > sample_field.shape[1]:
                                num_entries = sample_field.shape[0]
                            else:
                                num_entries = sample_field.shape[1]

                    if num_entries is not None and num_entries > 1:
                        print(f"Determined {num_entries} entries from field '{field_name}'")
                        break

        # If we still haven't found the number of entries, try all fields
        if num_entries is None or num_entries == 1:
            print("Trying to determine number of entries from all fields...")
            max_dim = 1
            for field_name in results.keys():
                field_data = results[field_name]
                if isinstance(field_data, h5py.Dataset):
                    for dim_size in field_data.shape:
                        if dim_size > max_dim:
                            max_dim = dim_size
                            sample_field_name = field_name
            num_entries = max_dim
            print(f"Found maximum dimension of {num_entries} in field '{sample_field_name}'")

        if num_entries is None:
            print("Error: Could not determine number of entries")
            return None

        print(f"Processing {num_entries} entries in results")

        # Helper function to read HDF5 data
        def read_h5_data(data):
            """Helper function to read and convert HDF5 data"""
            if isinstance(data, h5py.Reference):
                dereferenced = mat_data[data]
                return read_h5_data(dereferenced)
            elif isinstance(data, h5py.Dataset):
                value = data[()]
                # Handle string data
                if value.dtype == np.uint16:
                    return ''.join(chr(c) for c in value.flatten() if c != 0)
                elif value.dtype == np.uint8:
                    return ''.join(chr(c) for c in value.flatten() if c != 0)
                return value
            elif isinstance(data, np.ndarray):
                if data.dtype == 'O':
                    if data.size == 1:
                        return read_h5_data(data.item())
                return data
            else:
                return data

        # Extract data for each entry
        for i in range(num_entries):
            entry = {}

            # Process each field
            for field_name in results.keys():
                try:
                    field_data = results[field_name]

                    if isinstance(field_data, h5py.Dataset):
                        # Determine how to index based on field shape
                        if len(field_data.shape) == 1:
                            # 1D array
                            if field_data.shape[0] > i:
                                raw_value = field_data[i]
                            else:
                                print(
                                    f"Warning: Field '{field_name}' has only {field_data.shape[0]} elements, requesting index {i}")
                                raw_value = field_data[0]

                        elif len(field_data.shape) == 2:
                            # 2D array - need to determine correct indexing
                            # Check which dimension matches our expected number of entries
                            if field_data.shape[0] == num_entries:
                                # Entries are in first dimension
                                raw_value = field_data[i, :]
                            elif field_data.shape[1] == num_entries:
                                # Entries are in second dimension (MATLAB column-major)
                                raw_value = field_data[:, i]
                            else:
                                # Neither dimension matches exactly, use best guess
                                if field_data.shape[1] > i:
                                    raw_value = field_data[:, i]
                                elif field_data.shape[0] > i:
                                    raw_value = field_data[i, :]
                                else:
                                    print(
                                        f"Warning: Cannot index field '{field_name}' with shape {field_data.shape} at index {i}")
                                    continue
                        else:
                            # Higher dimensional array
                            if field_data.shape[-1] == num_entries:
                                raw_value = field_data[..., i]
                            elif field_data.shape[0] == num_entries:
                                raw_value = field_data[i, ...]
                            else:
                                print(
                                    f"Warning: Unsure how to index field '{field_name}' with shape {field_data.shape}")
                                continue

                        # Process based on field type
                        if field_name in ['subject', 'session', 'experience', 'filename']:
                            # Handle string fields
                            if raw_value.dtype == 'O':  # Object array (reference)
                                str_ref = raw_value.flatten()[0] if raw_value.size > 0 else raw_value
                                if isinstance(str_ref, h5py.Reference):
                                    str_data = mat_data[str_ref][()]
                                    if str_data.dtype in [np.uint16, np.uint8]:
                                        entry[field_name] = ''.join(chr(c) for c in str_data.flatten() if c != 0)
                                    else:
                                        entry[field_name] = str(str_data)
                                else:
                                    entry[field_name] = str(str_ref)
                            elif raw_value.dtype in [np.uint16, np.uint8]:
                                entry[field_name] = ''.join(chr(c) for c in raw_value.flatten() if c != 0)
                            else:
                                entry[field_name] = str(raw_value) if raw_value.size > 0 else ''

                        elif field_name in ['component', 'cluster']:
                            # Handle numeric scalars
                            if raw_value.dtype == 'O':
                                ref_data = read_h5_data(raw_value.flatten()[0] if raw_value.size > 0 else raw_value)
                                entry[field_name] = int(ref_data) if np.isscalar(ref_data) else int(
                                    ref_data.flatten()[0])
                            else:
                                entry[field_name] = int(raw_value.flatten()[0]) if raw_value.size > 0 else 0

                        elif field_name in ['freqs', 'spectra', 'icaact']:
                            # Handle arrays
                            if raw_value.dtype == 'O':
                                ref_data = read_h5_data(raw_value.flatten()[0] if raw_value.size > 0 else raw_value)
                                entry[field_name] = np.array(ref_data).flatten()
                            else:
                                entry[field_name] = raw_value.flatten()
                        else:
                            # Default handling
                            if raw_value.dtype == 'O' and raw_value.size > 0:
                                entry[field_name] = read_h5_data(raw_value.flatten()[0])
                            else:
                                entry[field_name] = raw_value

                    else:
                        print(f"Warning: Field '{field_name}' is not a Dataset: {type(field_data)}")
                        entry[field_name] = None

                except Exception as e:
                    print(f"Warning: Could not extract field '{field_name}' for entry {i}: {e}")
                    entry[field_name] = None

            data_list.append(entry)

            # Progress indicator
            if (i + 1) % 500 == 0:
                print(f"Processed {i + 1}/{num_entries} entries...")

    else:
        print("Results is a Dataset (not a Group)")
        print("This structure is unexpected for MATLAB struct arrays.")
        return None

    # Convert to DataFrame
    df = pd.DataFrame(data_list)

    print(f"\nExtracted data summary:")
    print(f"  Total entries: {len(df)}")
    if 'subject' in df.columns and df['subject'].notna().any():
        print(f"  Unique subjects: {df['subject'].nunique()}")
    if 'session' in df.columns and df['session'].notna().any():
        print(f"  Unique sessions: {df['session'].nunique()}")
    if 'experience' in df.columns and df['experience'].notna().any():
        print(f"  Unique experiences: {df['experience'].nunique()}")
    if 'cluster' in df.columns and df['cluster'].notna().any():
        print(f"  Unique clusters: {df['cluster'].nunique()}")

    # Verify we got all the data
    print(f"\nVerification: Extracted {len(df)} entries")

    return df

# Step 3: Save compiled data as a structured NumPy array or exportable format
def save_compiled_data(compiled_data, output_file):
    # Convert compiled data to a DataFrame
    df = pd.DataFrame(compiled_data)
    df.to_csv(output_file, index=False)  # Save as a CSV file

# Removing remaining spectra
def remove_spectra(cleaned_data, identifiers):
    """
    Remove spectra from cleaned_data based on a list of identifiers.

    Parameters:
    - cleaned_data (list): The list of dictionaries to remove spectra from.
    - identifiers (list): A list of strings in the format '{id}_{experience}_IC{component_number}'.

    Returns:
    - list: The updated cleaned_data with specified spectra removed.
    """
    updated_data = [
        entry for entry in cleaned_data
        if f"{entry['id']}_{entry['experience']}_IC{int(entry['component_number'].item())}" not in identifiers
    ]
    return updated_data

# Debugging Function
def explore_mat_structure(mat_file_path, max_depth=3):
    """
    Explore the structure of a MATLAB v7.3 file to understand its organization

    Parameters:
    mat_file_path (str): Path to the .mat file
    max_depth (int): Maximum depth to explore
    """
    with h5py.File(mat_file_path, 'r') as f:
        print(f"Top-level keys: {list(f.keys())}")

        def print_structure(name, obj, depth=0):
            if depth >= max_depth:
                return
            indent = "  " * depth
            if isinstance(obj, h5py.Dataset):
                print(f"{indent}{name}: Dataset, shape={obj.shape}, dtype={obj.dtype}")
            elif isinstance(obj, h5py.Group):
                print(f"{indent}{name}: Group")
                for key in obj.keys():
                    print_structure(key, obj[key], depth + 1)

        f.visititems(lambda name, obj: print_structure(name, obj))