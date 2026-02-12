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


def load_intervention_data(excel_path):
    """
    Load and process intervention assignment data from Excel file.

    Parameters:
    -----------
    excel_path : str
        Path to intervention_assignments.xlsx file

    Returns:
    --------
    dict : Dictionary mapping subject_id to intervention name
    """
    try:
        # Read Excel file
        intervention_df = pd.read_excel(excel_path)

        # Check if required columns exist
        if 'id' not in intervention_df.columns or 'intervention' not in intervention_df.columns:
            raise ValueError("Excel file must contain 'id' and 'intervention' columns")

        # Map intervention codes to full names
        intervention_mapping = {
            'A': 'Dance Exergaming',
            'B': 'Biking',
            'C': 'Music Listening'
        }

        # Create mapping dictionary with intervention names
        subject_intervention_map = {}
        for idx, row in intervention_df.iterrows():
            subject_id = str(row['id']).strip()
            intervention_code = str(row['intervention']).strip().upper()
            intervention_name = intervention_mapping.get(intervention_code, 'Unknown')
            subject_intervention_map[subject_id] = intervention_name

        print(f"Loaded intervention data for {len(subject_intervention_map)} participants")
        print(f"Interventions found: {set(subject_intervention_map.values())}")

        # Print distribution
        intervention_counts = pd.Series(list(subject_intervention_map.values())).value_counts()
        print("\nIntervention distribution:")
        for intervention, count in intervention_counts.items():
            print(f"  {intervention}: {count}")

        return subject_intervention_map

    except Exception as e:
        print(f"Error loading intervention data: {e}")
        return {}


def get_intervention_colors():
    """
    Define color scheme for different interventions.

    Returns:
    --------
    dict : Dictionary mapping intervention types to colors
    """
    color_map = {
        'Dance Exergaming': '#E5751F',  # Burnt Orange
        'Biking': '#508590',  # Sustainable Teal
        'Music Listening': '#861F41',  # Chicago Maroon
        'Unknown': '#999999'  # Gray for unknown
    }
    return color_map


def get_session_markers():
    """
    Define marker shapes for different sessions.

    Returns:
    --------
    dict : Dictionary mapping session types to marker shapes
    """
    marker_map = {
        's1': 'o',  # Circle for session 1
        's2': '^',  # Triangle for session 2
    }
    return marker_map


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


def load_dipole_data(csv_file_path, intervention_mapping=None):
    """
    Load and parse dipole data from CSV file, including intervention and session information.

    Parameters:
    -----------
    csv_file_path : str
        Path to CSV file containing dipole data
    intervention_mapping : dict, optional
        Dictionary mapping subject IDs to intervention types

    Returns:
    --------
    pandas.DataFrame : DataFrame with parsed coordinates, intervention, and session info
    numpy.ndarray : Array of MNI coordinates (n_dipoles, 3)
    list : List of intervention types for each coordinate
    list : List of session types for each coordinate
    list : List of colors for each coordinate
    """
    # Load the CSV file
    df = pd.read_csv(csv_file_path)

    # Check if required columns exist
    required_cols = ['MNI_coord', 'subject', 'session']
    if not all(col in df.columns for col in required_cols):
        raise ValueError(f"CSV file must contain columns: {required_cols}")

    # Get color mapping
    color_map = get_intervention_colors()

    # Parse MNI coordinates, intervention, and session info
    coordinates = []
    intervention_types = []
    session_types = []
    colors = []
    valid_rows = []

    for idx, row in df.iterrows():
        try:
            # Parse coordinates
            coord = parse_mni_coordinates(row['MNI_coord'])

            # Get session type
            session = str(row['session']).strip().lower()

            # Get intervention type
            if intervention_mapping:
                subject_id = str(row['subject']).strip()
                intervention = intervention_mapping.get(subject_id, 'Unknown')
                if intervention == 'Unknown':
                    print(f"Warning: No intervention data found for subject {subject_id}")
            else:
                intervention = 'Unknown'

            # Get color for this intervention
            color = color_map.get(intervention, color_map['Unknown'])

            coordinates.append(coord)
            intervention_types.append(intervention)
            session_types.append(session)
            colors.append(color)
            valid_rows.append(idx)

        except Exception as e:
            print(f"Warning: Could not parse data at row {idx}: {e}")

    # Filter dataframe to only valid rows and add intervention/session info
    df_valid = df.iloc[valid_rows].copy()
    df_valid['intervention'] = intervention_types
    df_valid['session'] = session_types
    df_valid['plot_color'] = colors

    coordinates = np.array(coordinates)

    print(f"Loaded {len(coordinates)} valid dipole coordinates from {len(df)} total rows")

    # Print intervention distribution
    if intervention_types:
        intervention_counts = pd.Series(intervention_types).value_counts()
        print("\nIntervention distribution in dipole data:")
        for intervention, count in intervention_counts.items():
            print(f"  {intervention}: {count}")

    # Print session distribution
    if session_types:
        session_counts = pd.Series(session_types).value_counts()
        print("\nSession distribution:")
        for session, count in session_counts.items():
            print(f"  {session}: {count}")

    return df_valid, coordinates, intervention_types, session_types, colors


def plot_dipoles_glass_brain(csv_file_path, intervention_excel_path=None, output_dir=None, figure_size=(15, 5)):
    """
    Plot EEG dipole coordinates on a glass brain colored by intervention and shaped by session.

    Parameters:
    -----------
    csv_file_path : str
        Path to CSV file containing dipole data
    intervention_excel_path : str, optional
        Path to intervention_assignments.xlsx file
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

    # Load intervention data if provided
    intervention_mapping = {}
    if intervention_excel_path:
        intervention_mapping = load_intervention_data(intervention_excel_path)

    # Load dipole data with intervention and session information
    df, coordinates, intervention_types, session_types, colors = load_dipole_data(csv_file_path, intervention_mapping)

    # Print basic statistics
    print(f"\n=== Dipole Statistics ===")
    print(f"Total dipoles: {len(coordinates)}")
    print(f"MNI coordinate range:")
    print(f"  X: [{coordinates[:, 0].min():.2f}, {coordinates[:, 0].max():.2f}]")
    print(f"  Y: [{coordinates[:, 1].min():.2f}, {coordinates[:, 1].max():.2f}]")
    print(f"  Z: [{coordinates[:, 2].min():.2f}, {coordinates[:, 2].max():.2f}]")

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
        title=f'EEG Dipole Locations by Intervention (n={len(coordinates)})',
        figure=None,
        black_bg=False,
        colorbar=False,
        display_mode='ortho'
    )

    # Get the figure and adjust size
    fig = display.frame_axes.figure
    fig.set_size_inches(figure_size)

    # Get color and marker mappings
    color_map = get_intervention_colors()
    marker_map = get_session_markers()

    # Get unique combinations of intervention and session
    unique_interventions = list(set(intervention_types))
    unique_sessions = list(set(session_types))

    # Plot dipoles by intervention and session
    for intervention in unique_interventions:
        for session in unique_sessions:
            # Get coordinates for this intervention-session combination
            indices = [i for i in range(len(intervention_types))
                       if intervention_types[i] == intervention and session_types[i] == session]

            if indices:
                combo_coordinates = coordinates[indices]
                combo_color = color_map.get(intervention, color_map['Unknown'])
                combo_marker = marker_map.get(session, 'o')

                # Add markers for this combination
                display.add_markers(
                    combo_coordinates,
                    marker_color=combo_color,
                    marker_size=200,
                    marker=combo_marker,
                    edgecolors='black',
                    linewidths=1
                )

                print(f"Plotted {len(combo_coordinates)} dipoles for {intervention} - {session}")

    # Add the average coordinate as a larger, distinct marker
    display.add_markers(
        [average_coord],
        marker_color='#F7EA48',  # Triumphant Yellow
        marker_size=450,
        marker='*',  # Star for average
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

    # Create legend
    from matplotlib.lines import Line2D
    legend_elements = []

    # Add intervention color legend entries (with sample sizes)
    for intervention in sorted(unique_interventions):
        if intervention in color_map:
            count = intervention_types.count(intervention)
            legend_elements.append(
                Line2D([0], [0], marker='s', color='w',
                       markerfacecolor=color_map[intervention],
                       markersize=10, linewidth=0,
                       label=f'{intervention} (n={count})')
            )

    # Add a separator
    legend_elements.append(
        Line2D([0], [0], color='none', label='')
    )

    # Add session shape legend entries
    for session in sorted(unique_sessions):
        if session in marker_map:
            count = session_types.count(session)
            legend_elements.append(
                Line2D([0], [0], marker=marker_map[session], color='w',
                       markerfacecolor='gray',
                       markersize=8, linewidth=1,
                       markeredgecolor='black',
                       label=f'{session.upper()} (n={count})')
            )

    # Add another separator
    legend_elements.append(
        Line2D([0], [0], color='none', label='')
    )

    # Add average marker to legend
    legend_elements.append(
        Line2D([0], [0], marker='*', color='w',
               markerfacecolor='#F7EA48',  # Triumphant Yellow
               markersize=12, linewidth=1,
               markeredgecolor='black',
               label='Average location')
    )

    fig.legend(handles=legend_elements, loc='upper right', bbox_to_anchor=(0.98, 0.98))

    # Save plots
    csv_filename = Path(csv_file_path).stem
    svg_path = output_dir / f"{csv_filename}_dipoles_by_intervention.svg"
    plt.savefig(svg_path, format='svg', dpi=300, bbox_inches='tight')
    print(f"\nPlot saved as: {svg_path}")

    png_path = output_dir / f"{csv_filename}_dipoles_by_intervention.png"
    plt.savefig(png_path, format='png', dpi=300, bbox_inches='tight')
    print(f"Plot also saved as: {png_path}")

    plt.show()

    # Prepare results dictionary
    results = {
        'average_mni': average_coord.tolist(),
        'aal3_mapping': aal3_result,
        'n_dipoles': len(coordinates),
        'intervention_distribution': dict(pd.Series(intervention_types).value_counts()),
        'session_distribution': dict(pd.Series(session_types).value_counts()),
        'svg_path': str(svg_path),
        'png_path': str(png_path),
        'coordinates': coordinates.tolist(),
        'intervention_types': intervention_types,
        'session_types': session_types,
        'input_file': csv_file_path,
        'intervention_file': intervention_excel_path
    }

    # Save results summary
    results_path = output_dir / f"{csv_filename}_dipole_intervention_analysis.txt"
    with open(results_path, 'w') as f:
        f.write(f"EEG Dipole Analysis Results (Colored by Intervention, Shaped by Session)\n")
        f.write(f"==========================================================================\n\n")
        f.write(f"Input files:\n")
        f.write(f"  - Dipole data: {csv_file_path}\n")
        f.write(f"  - Intervention data: {intervention_excel_path}\n\n")
        f.write(f"Number of dipoles: {len(coordinates)}\n")
        f.write(f"Average MNI coordinate: [{average_coord[0]:.2f}, {average_coord[1]:.2f}, {average_coord[2]:.2f}]\n\n")

        # Intervention distribution
        f.write(f"Intervention Distribution:\n")
        intervention_counts = pd.Series(intervention_types).value_counts()
        for intervention, count in intervention_counts.items():
            f.write(f"  - {intervention}: {count} dipoles\n")
        f.write(f"\n")

        # Session distribution
        f.write(f"Session Distribution:\n")
        session_counts = pd.Series(session_types).value_counts()
        for session, count in session_counts.items():
            f.write(f"  - {session.upper()}: {count} dipoles\n")
        f.write(f"\n")

        # Color scheme
        f.write(f"Color Scheme:\n")
        for intervention, color in color_map.items():
            if intervention in unique_interventions:
                f.write(f"  - {intervention}: {color}\n")
        f.write(f"\n")

        # Marker scheme
        f.write(f"Marker Scheme:\n")
        for session, marker in marker_map.items():
            if session in unique_sessions:
                f.write(f"  - {session.upper()}: {marker}\n")
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


def batch_process_dipole_files(csv_files, intervention_excel_path=None, output_dir=None):
    """
    Process multiple dipole CSV files in batch with intervention coloring and session shaping.

    Parameters:
    -----------
    csv_files : list
        List of paths to CSV files
    intervention_excel_path : str, optional
        Path to intervention_assignments.xlsx file
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
            results = plot_dipoles_glass_brain(csv_file, intervention_excel_path, output_dir)
            all_results[csv_file] = results
        except Exception as e:
            print(f"Error processing {csv_file}: {e}")
            all_results[csv_file] = {'error': str(e)}

    return all_results


# Example usage
if __name__ == "__main__":
    # Example: Process a single CSV file with intervention coloring
    # results = plot_dipoles_glass_brain(
    #     'cluster1_dipoles.csv',
    #     '../demographicsPsych/data/intervention_assignments.xlsx'
    # )

    # Example: Process multiple CSV files with intervention coloring
    # csv_files = ['cluster1_dipoles.csv', 'cluster2_dipoles.csv', 'cluster3_dipoles.csv']
    # all_results = batch_process_dipole_files(
    #     csv_files,
    #     '../demographicsPsych/data/intervention_assignments.xlsx',
    #     'output_dir'
    # )

    print("\nExample usage with intervention coloring and session shaping:")
    print("results = plot_dipoles_glass_brain(")
    print("    'cluster1_dipoles.csv',")
    print("    '../demographicsPsych/data/intervention_assignments.xlsx'")
    print(")")
    print("\nintervention_dist = results['intervention_distribution']")
    print("session_dist = results['session_distribution']")
    print("svg_file = results['svg_path']")

    print("\nColor scheme:")
    colors = get_intervention_colors()
    for intervention, color in colors.items():
        print(f"  {intervention}: {color}")

    print("\nMarker scheme:")
    markers = get_session_markers()
    for session, marker in markers.items():
        print(f"  {session.upper()}: {marker}")