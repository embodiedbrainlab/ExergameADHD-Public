import numpy as np
import pandas as pd
from scipy import io

# Load existing cleaned dataframe
df_existing = pd.read_pickle('../results/specparam/final_model/df_final.pkl')
print(f"Existing data: {len(df_existing)} models")

# Load the new .mat file with 5 spectra
mat_file_path = '../results/exgm169_s1_gonogo_recovery.mat'  # UPDATE THIS PATH
mat_data = io.loadmat(mat_file_path)

# Extract the results structure
results = mat_data['results'][0]  # 1x5 struct

# Create list to hold the 5 new entries
new_data = []

# Extract each of the 5 spectra
for i in range(len(results)):
    print(f"\n--- Processing spectrum {i + 1}/5 ---")

    # Extract spectra field
    raw_spectra = results[i]['spectra']
    print(f"Initial shape: {raw_spectra.shape}, dtype: {raw_spectra.dtype}")

    # For MATLAB structures, spectra is often nested as (1, 1) containing the actual array
    # We need to recursively unwrap until we get the actual data
    spectra_unwrapped = raw_spectra
    unwrap_count = 0

    while isinstance(spectra_unwrapped, np.ndarray) and spectra_unwrapped.shape == (1, 1):
        print(f"  Unwrapping level {unwrap_count + 1}: {spectra_unwrapped.shape}")
        spectra_unwrapped = spectra_unwrapped[0, 0]
        unwrap_count += 1
        if unwrap_count > 5:  # Safety check
            print("  ERROR: Too many unwrap levels!")
            break

    # Now flatten to 1D
    if isinstance(spectra_unwrapped, np.ndarray):
        spectra_flat = spectra_unwrapped.flatten()
    else:
        spectra_flat = np.array(spectra_unwrapped).flatten()

    print(f"Final shape: {spectra_flat.shape}")

    # Validate we got 251 points
    if spectra_flat.shape[0] != 251:
        print(f"ERROR: Expected 251 points, got {spectra_flat.shape[0]}")
        print("Skipping this spectrum...")
        continue

    # Extract other fields
    entry = {
        'subject': str(results[i]['subject'][0]),
        'session': str(results[i]['session'][0]),
        'experience': str(results[i]['experience'][0]),
        'component': int(results[i]['component'][0, 0]),
        'cluster': int(results[i]['cluster'][0, 0]),
        'spectra': spectra_flat,
    }

    # Add any other fields
    for field in results.dtype.names:
        if field not in ['subject', 'session', 'experience', 'component', 'cluster', 'spectra']:
            try:
                entry[field] = results[i][field]
            except:
                pass

    new_data.append(entry)
    print(f"✓ Spectrum {i + 1} added successfully")

if len(new_data) != 5:
    print(f"\nWARNING: Expected 5 spectra, only got {len(new_data)}")

# Create dataframe from new data
df_new = pd.DataFrame(new_data)
print(f"\n✓ Successfully extracted {len(df_new)} spectra")

# Test that we can convert to numpy array
try:
    test_array = np.array([spec for spec in df_new['spectra']])
    print(f"✓ Validation passed: new spectra shape is {test_array.shape}")
except ValueError as e:
    print(f"✗ ERROR: {e}")
    exit(1)

# Append to existing dataframe
df_combined = pd.concat([df_existing, df_new], ignore_index=True)

# Final test on combined data
try:
    test_array = np.array([spec for spec in df_combined['spectra']])
    print(f"✓ Combined data validation passed: shape is {test_array.shape}")
except ValueError as e:
    print(f"✗ ERROR in combined data: {e}")
    exit(1)

# Save combined dataframe
df_combined.to_pickle('../results/specparam/final_model/df_final_with_additional_spectra.pkl')

# Save log
df_new[['subject', 'session', 'experience', 'component', 'cluster']].to_csv(
    '../results/specparam/final_model/added_spectra_log.csv', index=False
)

print(f"\n✓ Success! Saved to df_final_with_additional_spectra.pkl")
print(f"Total models: {len(df_combined)}")