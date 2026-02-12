import numpy as np
from nilearn import datasets
from nilearn.image import coord_transform
import nibabel as nib
from scipy.spatial.distance import cdist


def query_eeglab_coordinates(coordinates, atlas_version='3v2'):
    """
    Query brain region labels for MNI coordinates using AAL3 atlas.
    Updated to automatically detect voxel size from atlas.

    Parameters:
    -----------
    coordinates : list or array-like
        MNI coordinates in format [[x1, y1, z1], [x2, y2, z2], ...]
    atlas_version : str
        '3v2' (latest AAL3) or 'SPM12' (older version)

    Returns:
    --------
    results : list
        List of dictionaries containing coordinate info and region labels
    """
    # Convert coordinates to numpy array
    coords = np.array(coordinates)
    if coords.ndim == 1:
        coords = coords.reshape(1, -1)

    # Validate input dimensions
    if coords.shape[1] != 3:
        raise ValueError('Input must be a N by 3 matrix of coordinates')

    results = []

    # Fetch AAL3 atlas with specified version
    try:
        if atlas_version == '3v2':
            atlas = datasets.fetch_atlas_aal(version='3v2')
            print(f"Using AAL3 version 3v2 with {len(atlas.labels)} regions")
        else:
            atlas = datasets.fetch_atlas_aal(version='SPM12')
            print(f"Using AAL3 version SPM12 with {len(atlas.labels)} regions")

        atlas_img = atlas.maps
        labels = atlas.labels

    except Exception as e:
        print(f"Error loading atlas version {atlas_version}: {e}")
        print("Falling back to SPM12 version...")
        atlas = datasets.fetch_atlas_aal(version='SPM12')
        atlas_img = atlas.maps
        labels = atlas.labels

    # Load the atlas image and get voxel size
    atlas_nii = nib.load(atlas_img)
    atlas_data = atlas_nii.get_fdata()
    atlas_affine = atlas_nii.affine

    # Calculate actual voxel size from affine matrix
    voxel_sizes = np.sqrt(np.sum(atlas_affine[:3, :3] ** 2, axis=0))
    avg_voxel_size = np.mean(voxel_sizes)
    print(f"Atlas voxel size: {voxel_sizes} mm (average: {avg_voxel_size:.2f} mm)")

    # Query each coordinate
    for i, coord in enumerate(coords):
        result = {
            #'mni_coordinate': coord.tolist(), # shows same info as line below
            'x': coord[0], 'y': coord[1], 'z': coord[2],
            'regions': []
        }

        # Convert MNI coordinates to voxel indices using atlas affine
        vox_coords = coord_transform(coord[0], coord[1], coord[2],
                                     np.linalg.inv(atlas_affine))

        # Round to nearest voxel
        vox_coords = np.round(vox_coords).astype(int)

        # Check if coordinates are within atlas bounds
        if (0 <= vox_coords[0] < atlas_data.shape[0] and
                0 <= vox_coords[1] < atlas_data.shape[1] and
                0 <= vox_coords[2] < atlas_data.shape[2]):

            # Get the atlas value at this coordinate
            atlas_value = int(atlas_data[vox_coords[0], vox_coords[1], vox_coords[2]])

            if atlas_value > 0:  # 0 typically means no label
                if atlas_value <= len(labels):
                    region_name = labels[atlas_value - 1]  # Atlas indices usually start at 1
                    result['regions'].append({
                        'label_index': atlas_value,
                        'region_name': region_name,
                        'confidence': 'exact_match'
                    })

            # If no exact match, find nearest labeled regions within 10mm radius
            if not result['regions']:
                result['regions'] = find_nearby_regions(vox_coords, atlas_data, labels,
                                                        atlas_affine, avg_voxel_size, max_distance=10)

        else:
            result['regions'].append({
                'region_name': 'Outside atlas bounds',
                'confidence': 'error'
            })

        results.append(result)

    return results


def find_nearby_regions(vox_coords, atlas_data, labels, affine, voxel_size, max_distance=10):
    """
    Find nearby labeled regions within max_distance (mm) if exact coordinate has no label.
    """
    nearby_regions = []

    # Convert max_distance from mm to voxels using actual voxel size
    search_radius = int(np.ceil(max_distance / voxel_size))

    # Create a search box around the coordinate
    x, y, z = vox_coords
    x_range = range(max(0, x - search_radius), min(atlas_data.shape[0], x + search_radius + 1))
    y_range = range(max(0, y - search_radius), min(atlas_data.shape[1], y + search_radius + 1))
    z_range = range(max(0, z - search_radius), min(atlas_data.shape[2], z + search_radius + 1))

    found_labels = {}

    for xi in x_range:
        for yi in y_range:
            for zi in z_range:
                # Calculate actual distance in mm
                distance = np.sqrt((xi - x) ** 2 + (yi - y) ** 2 + (zi - z) ** 2) * voxel_size

                if distance <= max_distance:
                    atlas_value = int(atlas_data[xi, yi, zi])
                    if atlas_value > 0 and atlas_value <= len(labels):
                        region_name = labels[atlas_value - 1]
                        if region_name not in found_labels:
                            found_labels[region_name] = distance
                        else:
                            # Keep the closest distance for each region
                            found_labels[region_name] = min(found_labels[region_name], distance)

    # Sort by distance and create results
    for region_name, distance in sorted(found_labels.items(), key=lambda x: x[1]):
        nearby_regions.append({
            'region_name': region_name,
            'distance_mm': round(distance, 2),
            'confidence': 'nearby_match'
        })

    return nearby_regions[:5]  # Return top 5 closest regions


def validate_dipfit_coordinates(coordinates, verbose=True):
    """
    Validate that coordinates from DIPFIT are reasonable MNI coordinates.

    Parameters:
    -----------
    coordinates : array-like
        Coordinates to validate
    verbose : bool
        Print validation results

    Returns:
    --------
    dict : Validation results
    """
    coords = np.array(coordinates)
    if coords.ndim == 1:
        coords = coords.reshape(1, -1)

    validation = {
        'total_coords': len(coords),
        'valid_coords': 0,
        'warnings': [],
        'recommendations': []
    }

    for i, coord in enumerate(coords):
        x, y, z = coord

        # Check if coordinates are in reasonable MNI range
        if -100 <= x <= 100 and -120 <= y <= 90 and -80 <= z <= 100:
            validation['valid_coords'] += 1
        else:
            validation['warnings'].append(f"Coordinate {i + 1} ({x}, {y}, {z}) outside typical MNI range")

    # Add recommendations based on validation
    if validation['valid_coords'] < validation['total_coords']:
        validation['recommendations'].append("Some coordinates are outside typical MNI brain space")
        validation['recommendations'].append("Verify that DIPFIT is set to 'MNI' coordinate format")
        validation['recommendations'].append("Check that standard_BEM model is properly loaded")

    if verbose:
        print(f"Coordinate Validation Results:")
        print(f"- Total coordinates: {validation['total_coords']}")
        print(f"- Valid coordinates: {validation['valid_coords']}")
        for warning in validation['warnings']:
            print(f"- Warning: {warning}")
        for rec in validation['recommendations']:
            print(f"- Recommendation: {rec}")

    return validation


def batch_process_dipole_coordinates(dipole_file_path, validate_coords=True):
    """
    Process MNI coordinates from a CSV file with validation.
    """
    import pandas as pd

    try:
        df = pd.read_csv(dipole_file_path)

        # Check if required columns exist
        required_cols = ['x', 'y', 'z']
        if not all(col in df.columns for col in required_cols):
            raise ValueError(f"CSV file must contain columns: {required_cols}")

        coordinates = df[['x', 'y', 'z']].values.tolist()

        # Validate coordinates if requested
        if validate_coords:
            print("\n=== Validating DIPFIT Coordinates ===")
            validation = validate_dipfit_coordinates(coordinates)

            if validation['valid_coords'] != validation['total_coords']:
                response = input("\nSome coordinates may be invalid. Continue anyway? (y/n): ")
                if response.lower() != 'y':
                    return None

        # Process coordinates using AAL3
        print("\n=== Processing with AAL3 Atlas ===")
        results = query_eeglab_coordinates(coordinates, atlas_version='3v2')

        # Add results back to dataframe
        region_names = []
        confidence_levels = []
        distances = []

        for result in results:
            if result['regions']:
                # Take the first (best) match
                best_match = result['regions'][0]
                region_names.append(best_match['region_name'])
                confidence_levels.append(best_match['confidence'])

                if 'distance_mm' in best_match:
                    distances.append(best_match['distance_mm'])
                else:
                    distances.append(0.0)  # Exact match
            else:
                region_names.append('Unknown')
                confidence_levels.append('no_match')
                distances.append(np.nan)

        df['brain_region'] = region_names
        df['match_confidence'] = confidence_levels
        df['distance_mm'] = distances

        # Save results
        output_path = dipole_file_path.replace('.csv', '_with_regions.csv')
        df.to_csv(output_path, index=False)
        print(f"\nResults saved to: {output_path}")

        # Print summary
        print(f"\n=== Summary ===")
        print(f"Total dipoles processed: {len(df)}")
        print(f"Exact matches: {sum(df['match_confidence'] == 'exact_match')}")
        print(f"Nearby matches: {sum(df['match_confidence'] == 'nearby_match')}")
        print(f"No matches: {sum(df['match_confidence'] == 'no_match')}")

        return df

    except Exception as e:
        print(f"Error processing file: {e}")
        return None


# Example usage
if __name__ == "__main__":
    # Example MNI coordinates (typical DIPFIT output ranges)
    example_coordinates = [
        [-45, -20, 10],  # Left temporal
        [45, -20, 10],  # Right temporal
        [0, -30, 45],  # Midline parietal
        [-30, 20, -15],  # Left frontal
        [25, -85, 5]  # Right occipital
    ]

    print("=== AAL3 Atlas Mapping for DIPFIT Coordinates ===")

    # Validate example coordinates
    validate_dipfit_coordinates(example_coordinates)

    # Process with AAL3
    aal3_results = query_eeglab_coordinates(example_coordinates, atlas_version='3v2')

    for i, result in enumerate(aal3_results):
        print(f"\nDipole {i + 1}:")
        print(f"  MNI coordinates: [{result['x']:.1f}, {result['y']:.1f}, {result['z']:.1f}]")
        if result['regions']:
            for j, region in enumerate(result['regions']):
                if region['confidence'] == 'exact_match':
                    print(f"  → {region['region_name']} (exact match)")
                else:
                    print(f"  → {region['region_name']} ({region['distance_mm']}mm away)")
                if j == 0:  # Only show first match for clean output
                    break
        else:
            print("  → No regions found")

    print(f"\n=== Atlas Information ===")
    print(f"Atlas: AAL3 (Automated Anatomical Labeling)")
    print(f"Version: 3v2 (Rolls et al., 2020)")
    print(f"Coordinate system: MNI152")
    print(f"Compatible with: EEGLAB DIPFIT standard_BEM model")

# Uncomment to process your actual dipole file:
# df_with_regions = batch_process_dipole_coordinates('your_dipole_coordinates.csv')