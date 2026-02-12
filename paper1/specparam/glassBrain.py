import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from nilearn import plotting
from nilearn.datasets import load_mni152_template
import re
import os
from pathlib import Path

# Import the AAL3 mapping function from your existing script
# Assuming the mapToAAL3.py file is in the same directory or accessible
try:
    from mapToAAL3 import query_eeglab_coordinates, validate_dipfit_coordinates

    AAL3_AVAILABLE = True
except ImportError:
    print("Warning: mapToAAL3.py not found. AAL3 mapping will be disabled.")
    AAL3_AVAILABLE = False

def load_asrs6_data(exergame_csv_path):
    """
    Load and process asrs6 data from exergame_DemoBaselineMH_TOTALS.csv file.

    Parameters:
    -----------
    exergame_csv_path : str
        Path to exergame_DemoBaselineMH_TOTALS.csv file

    Returns:
    --------
    dict : Dictionary mapping participant_id to asrs_6_total_category
    """
    try:
        asrs6_df = pd.read_csv(exergame_csv_path)

        # Check if required columns exist
        if 'participant_id' not in asrs6_df.columns or 'asrs_6_total_category' not in asrs6_df.columns:
            raise ValueError("Input .csv file must contain 'participant_id' and 'asrs_6_total_category' columns")

        # Create mapping dictionary
        asrs6_mapping = dict(zip(asrs6_df['participant_id'], asrs6_df['asrs_6_total_category']))

        print(f"Loaded asrs6 data for {len(asrs6_mapping)} participants")
        print(f"asrs6 types found: {set(asrs6_mapping.values())}")

        return asrs6_mapping

    except Exception as e:
        print(f"Error loading asrs6 data: {e}")
        return {}


def convert_subject_id(subject_id):
    """
    Convert subject ID from exgmXXX format to numeric format for matching.

    Parameters:
    -----------
    subject_id : str
        Subject ID in format 'exgmXXX'

    Returns:
    --------
    int : Numeric participant ID
    """
    # Remove 'exgm' prefix and convert to int (this removes leading zeros)
    if subject_id.startswith('exgm'):
        return int(subject_id[4:])
    else:
        # Try to extract numeric part if format is different
        numeric_part = re.search(r'\d+', subject_id)
        if numeric_part:
            return int(numeric_part.group())
    return None


def get_asrs6_colors():
    """
    Define color scheme for different asrs6 types.

    Returns:
    --------
    dict : Dictionary mapping asrs6 types to colors
    """
    color_map = {
        'low_negative': '#75787b',  # Hokie Stone
        'high_negative': '#E5751F',  # Burnt Orange
        'low_positive': '#508590',  # Sustainable Teal
        'high_positive': '#861F41',  # Chicago Maroon
        'unknown': '#999999'
    }
    return color_map


def parse_mni_coordinates(coord_string):
    """
    Parse MNI coordinates from string format '[x y z]' to numpy array.

    Parameters:
    -----------
    coord_string : str
        String in format '[x y z]' or 'x y z'

    Returns:
    --------
    numpy.ndarray : Array of [x, y, z] coordinates
    """
    # Remove brackets and split by whitespace
    coord_clean = re.sub(r'[\[\]]', '', str(coord_string))
    coords = [float(x) for x in coord_clean.split()]

    if len(coords) != 3:
        raise ValueError(f"Invalid coordinate format: {coord_string}")

    return np.array(coords)


def load_dipole_data(csv_file_path, asrs6_mapping=None):
    """
    Load and parse dipole data from CSV file, including asrs6 information.

    Parameters:
    -----------
    csv_file_path : str
        Path to CSV file containing dipole data
    asrs6_mapping : dict, optional
        Dictionary mapping participant IDs to asrs6 types

    Returns:
    --------
    pandas.DataFrame : DataFrame with parsed coordinates and asrs6 info
    numpy.ndarray : Array of MNI coordinates (n_dipoles, 3)
    list : List of asrs6 types for each coordinate
    list : List of colors for each coordinate
    """
    # Load the CSV file
    df = pd.read_csv(csv_file_path)

    # Check if required columns exist
    required_cols = ['MNI_coord', 'subject']
    if not all(col in df.columns for col in required_cols):
        raise ValueError(f"CSV file must contain columns: {required_cols}")

    # Get color mapping
    color_map = get_asrs6_colors()

    # Parse MNI coordinates and asrs6 info
    coordinates = []
    asrs6_types = []
    colors = []
    valid_rows = []

    for idx, row in df.iterrows():
        try:
            # Parse coordinates
            coord = parse_mni_coordinates(row['MNI_coord'])

            # Get asrs6 type
            if asrs6_mapping:
                participant_id = convert_subject_id(row['subject'])
                if participant_id and participant_id in asrs6_mapping:
                    asrs6_type = asrs6_mapping[participant_id]
                else:
                    asrs6_type = 'unknown'
                    print(f"Warning: No asrs6 data found for subject {row['subject']}")
            else:
                asrs6_type = 'unknown'

            # Get color for this asrs6 type
            color = color_map.get(asrs6_type, color_map['unknown'])

            coordinates.append(coord)
            asrs6_types.append(asrs6_type)
            colors.append(color)
            valid_rows.append(idx)

        except Exception as e:
            print(f"Warning: Could not parse data at row {idx}: {e}")

    # Filter dataframe to only valid rows and add asrs6 info
    df_valid = df.iloc[valid_rows].copy()
    df_valid['asrs6_type'] = asrs6_types
    df_valid['plot_color'] = colors

    coordinates = np.array(coordinates)

    print(f"Loaded {len(coordinates)} valid dipole coordinates from {len(df)} total rows")

    # Print asrs6 distribution
    if asrs6_types:
        asrs6_counts = pd.Series(asrs6_types).value_counts()
        print("asrs6 type distribution:")
        for asrs6_type, count in asrs6_counts.items():
            print(f"  {asrs6_type}: {count}")

    return df_valid, coordinates, asrs6_types, colors


def plot_dipoles_glass_brain(csv_file_path, exergame_csv_path=None, output_dir=None, figure_size=(15, 5)):
    """
    Plot EEG dipole coordinates on a glass brain colored by ADHD asrs6 type.

    Parameters:
    -----------
    csv_file_path : str
        Path to CSV file containing dipole data
    exergame_csv_path : str, optional
        Path to exergame_DemoBaselineMH_TOTALS.csv file containing asrs6 data
    output_dir : str, optional
        Directory to save output files. If None, uses same directory as input file
    figure_size : tuple
        Figure size for the plot (width, height)

    Returns:
    --------
    dict : Dictionary containing analysis results
    """
    # Set up output directory
    if output_dir is None:
        output_dir = Path(csv_file_path).parent
    else:
        output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True)

    # Load asrs6 data if provided
    asrs6_mapping = {}
    if exergame_csv_path:
        asrs6_mapping = load_asrs6_data(exergame_csv_path)

    # Load dipole data with asrs6 information
    df, coordinates, asrs6_types, colors = load_dipole_data(csv_file_path, asrs6_mapping)

    # Check if we have any valid coordinates
    if len(coordinates) == 0:
        raise ValueError("No valid coordinates found in the CSV file. Please check the 'MNI_coord' column format.")

    print(f"Successfully loaded {len(coordinates)} coordinates")

    # Validate coordinates using your existing function
    if AAL3_AVAILABLE:
        print("\n=== Validating Dipole Coordinates ===")
        validation = validate_dipfit_coordinates(coordinates, verbose=True)

    # Calculate average coordinate
    average_coord = np.mean(coordinates, axis=0)
    print(f"\nAverage MNI coordinate: [{average_coord[0]:.2f}, {average_coord[1]:.2f}, {average_coord[2]:.2f}]")

    # Map average coordinate to AAL3 atlas
    aal3_result = None
    if AAL3_AVAILABLE:
        print("\n=== Mapping Average Coordinate to AAL3 Atlas ===")
        aal3_results = query_eeglab_coordinates([average_coord], atlas_version='3v2')
        aal3_result = aal3_results[0] if aal3_results else None

        if aal3_result and aal3_result['regions']:
            best_match = aal3_result['regions'][0]
            print(f"Best match: {best_match['region_name']}")
            print(f"Confidence: {best_match['confidence']}")
            if 'distance_mm' in best_match:
                print(f"Distance: {best_match['distance_mm']} mm")
        else:
            print("No AAL3 region found for average coordinate")

    # Create the glass brain plot
    display = plotting.plot_glass_brain(
        None,  # No statistical map, just the glass brain
        title=f'EEG Dipole Locations by asrs6 Type (n={len(coordinates)})',
        figure=None,
        black_bg=False,
        colorbar=False,
        display_mode='ortho'
    )

    # Get the figure and adjust size
    fig = display.frame_axes.figure
    fig.set_size_inches(figure_size)

    # Plot dipoles by asrs6 type
    color_map = get_asrs6_colors()
    unique_asrs6_types = list(set(asrs6_types))

    for asrs6_type in unique_asrs6_types:
        # Get coordinates for this asrs6 type
        asrs6_indices = [i for i, mt in enumerate(asrs6_types) if mt == asrs6_type]
        if asrs6_indices:
            asrs6_coordinates = coordinates[asrs6_indices]
            asrs6_color = color_map.get(asrs6_type, color_map['unknown'])

            # Add markers for this asrs6 type
            display.add_markers(
                asrs6_coordinates,
                marker_color=asrs6_color,
                marker_size=200,
                marker='o',
                edgecolors='black',
                linewidths=1
            )

            print(f"Plotted {len(asrs6_coordinates)} dipoles for {asrs6_type} asrs6 type")

    # Add the average coordinate as a larger, distinct marker
    display.add_markers(
        [average_coord],
        marker_color='#F7EA48',  # Triumphant Yellow
        marker_size=450,
        marker='o',
        edgecolors='black',
        linewidths=2,
    )

    # Add text annotation for average coordinate
    avg_text = f"Average: [{average_coord[0]:.1f}, {average_coord[1]:.1f}, {average_coord[2]:.1f}]"
    if aal3_result and aal3_result['regions']:
        best_match = aal3_result['regions'][0]
        region_text = f"Region: {best_match['region_name']}"
        if best_match['confidence'] == 'exact_match':
            confidence_text = "(exact match)"
        else:
            confidence_text = f"({best_match.get('distance_mm', 'N/A')}mm away)"
        avg_text += f"\n{region_text} {confidence_text}"

    # Add text box with average coordinate info
    fig.text(0.02, 0.02, avg_text, fontsize=10,
             bbox=dict(boxstyle="round,pad=0.3", facecolor="white", alpha=0.8))

    # Create legend for asrs6 types
    from matplotlib.lines import Line2D
    legend_elements = []

    # Add asrs6 type legend entries
    for asrs6_type in sorted(unique_asrs6_types):
        if asrs6_type in color_map:
            legend_elements.append(
                Line2D([0], [0], marker='o', color='w',
                       markerfacecolor=color_map[asrs6_type],
                       markersize=8, linewidth=1,
                       label=f'{asrs6_type.title()} (n={asrs6_types.count(asrs6_type)})')
            )

    # Add average marker to legend
    legend_elements.append(
        Line2D([0], [0], marker='o', color='w',
               markerfacecolor='#F7EA48', # Triumphant Yellow
               markersize=8, linewidth=1,
               label='Average location')
    )

    fig.legend(handles=legend_elements, loc='upper right', bbox_to_anchor=(0.98, 0.98))

    # Save plots
    csv_filename = Path(csv_file_path).stem
    svg_path = output_dir / f"{csv_filename}_dipoles_by_asrs6.svg"
    plt.savefig(svg_path, format='svg', dpi=300, bbox_inches='tight')
    print(f"\nPlot saved as: {svg_path}")

    png_path = output_dir / f"{csv_filename}_dipoles_by_asrs6.png"
    plt.savefig(png_path, format='png', dpi=300, bbox_inches='tight')
    print(f"Plot also saved as: {png_path}")

    plt.show()

    # Prepare results dictionary
    results = {
        'average_mni': average_coord.tolist(),
        'aal3_mapping': aal3_result,
        'n_dipoles': len(coordinates),
        'asrs6_distribution': dict(pd.Series(asrs6_types).value_counts()),
        'svg_path': str(svg_path),
        'png_path': str(png_path),
        'coordinates': coordinates.tolist(),
        'asrs6_types': asrs6_types,
        'input_file': csv_file_path,
        'asrs6_file': exergame_csv_path
    }

    # Save results summary
    results_path = output_dir / f"{csv_filename}_dipole_asrs6_analysis.txt"
    with open(results_path, 'w') as f:
        f.write(f"EEG Dipole Analysis Results (Colored by asrs6 Type)\n")
        f.write(f"==========================================================\n\n")
        f.write(f"Input files:\n")
        f.write(f"  - Dipole data: {csv_file_path}\n")
        f.write(f"  - asrs6 data: {exergame_csv_path}\n\n")
        f.write(f"Number of dipoles: {len(coordinates)}\n")
        f.write(f"Average MNI coordinate: [{average_coord[0]:.2f}, {average_coord[1]:.2f}, {average_coord[2]:.2f}]\n\n")

        # asrs6 distribution
        f.write(f"asrs6 Type Distribution:\n")
        asrs6_counts = pd.Series(asrs6_types).value_counts()
        for asrs6_type, count in asrs6_counts.items():
            f.write(f"  - {asrs6_type.title()}: {count} dipoles\n")
        f.write(f"\n")

        # Color scheme
        f.write(f"Color Scheme:\n")
        for asrs6_type, color in color_map.items():
            if asrs6_type in unique_asrs6_types:
                f.write(f"  - {asrs6_type.title()}: {color}\n")
        f.write(f"\n")

        if aal3_result and aal3_result['regions']:
            f.write(f"AAL3 Atlas Mapping (Average Coordinate):\n")
            for i, region in enumerate(aal3_result['regions'][:3]):
                f.write(f"  {i + 1}. {region['region_name']}\n")
                f.write(f"     Confidence: {region['confidence']}\n")
                if 'distance_mm' in region:
                    f.write(f"     Distance: {region['distance_mm']} mm\n")
                f.write(f"\n")
        else:
            f.write(f"AAL3 Atlas Mapping: No regions found\n\n")

        f.write(f"Output files:\n")
        f.write(f"  - SVG plot: {svg_path.name}\n")
        f.write(f"  - PNG plot: {png_path.name}\n")
        f.write(f"  - Results: {results_path.name}\n")

    print(f"Analysis summary saved as: {results_path}")

    return results


def batch_process_dipole_files(csv_files, exergame_csv_path=None, output_dir=None):
    """
    Process multiple dipole CSV files in batch with asrs6 coloring.

    Parameters:
    -----------
    csv_files : list
        List of paths to CSV files
    exergame_csv_path : str, optional
        Path to exergame_DemoBaselineMH_TOTALS.csv file
    output_dir : str, optional
        Directory to save all output files

    Returns:
    --------
    dict : Dictionary with results for each file
    """
    all_results = {}

    for csv_file in csv_files:
        print(f"\n{'=' * 60}")
        print(f"Processing: {csv_file}")
        print(f"{'=' * 60}")

        try:
            results = plot_dipoles_glass_brain(csv_file, exergame_csv_path, output_dir)
            all_results[csv_file] = results
        except Exception as e:
            print(f"Error processing {csv_file}: {e}")
            all_results[csv_file] = {'error': str(e)}

    return all_results


# Example usage
if __name__ == "__main__":
    # Example: Process a single CSV file with asrs6 coloring
    # results = plot_dipoles_glass_brain('cluster1_dipoles.csv', 'exergame_DemoBaselineMH_TOTALS.csv')

    # Example: Process multiple CSV files with asrs6 coloring
    # csv_files = ['cluster1_dipoles.csv', 'cluster2_dipoles.csv', 'cluster3_dipoles.csv']
    # all_results = batch_process_dipole_files(csv_files, 'exergame_DemoBaselineMH_TOTALS.csv', 'output_dir')

    print("\nExample usage with asrs6 coloring:")
    print("results = plot_dipoles_glass_brain('cluster1_dipoles.csv', 'exergame_DemoBaselineMH_TOTALS.csv')")
    print("asrs6_dist = results['asrs6_distribution']")
    print("svg_file = results['svg_path']")

    print("\nColor scheme:")
    colors = get_asrs6_colors()
    for asrs6_type, color in colors.items():
        print(f"  {asrs6_type.title()}: {color}")