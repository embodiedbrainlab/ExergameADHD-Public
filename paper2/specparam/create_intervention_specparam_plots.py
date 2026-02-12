"""
SpecParam Intervention Task Plotting Script
Creates power spectral density plots comparing interventions during the 'intervention' task.
Each cluster has 2 plots: combined fits and peak fits.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os

# Intervention mapping
INTERVENTION_MAP = {
    'A': 'Dance_Exergaming',
    'B': 'Biking',
    'C': 'Music_Listening'
}

# Color scheme using first 3 colors from Dark2 colormap
INTERVENTION_COLORS = {
    'Dance_Exergaming': '#1b9e77',  # Dark2 color 0 - teal green
    'Biking': '#d95f02',  # Dark2 color 1 - orange
    'Music_Listening': '#7570b3'  # Dark2 color 2 - purple
}


def load_intervention_assignments(filepath):
    """
    Load intervention assignments from Excel file.

    Parameters
    ----------
    filepath : str
        Path to the intervention assignments Excel file

    Returns
    -------
    pd.DataFrame
        DataFrame with 'id' and 'intervention' columns
    """
    df_interventions = pd.read_excel(filepath, usecols=['id', 'intervention'])
    # Map intervention codes to full names
    df_interventions['intervention_name'] = df_interventions['intervention'].map(INTERVENTION_MAP)
    return df_interventions


def extract_fits_for_indices(fg, indices):
    """
    Extract peak fits and aperiodic fits for given indices from SpectralGroupModel.

    Parameters
    ----------
    fg : SpectralGroupModel
        Fitted spectral group model object
    indices : list
        List of indices to extract fits for

    Returns
    -------
    peak_fits : np.ndarray
        Array of peak fits (shape: n_subjects x n_frequencies)
    ap_fits : np.ndarray
        Array of aperiodic fits (shape: n_subjects x n_frequencies)
    """
    peak_fits = []
    ap_fits = []

    for index in indices:
        fm = fg.get_model(ind=index, regenerate=True)
        peak_fits.append(fm._peak_fit)
        ap_fits.append(fm._ap_fit)

    return np.array(peak_fits), np.array(ap_fits)


def compute_cluster_ylimits(df_cluster, fg, interventions):
    """
    Compute y-axis limits for plots across all interventions in a cluster.

    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster
    fg : SpectralGroupModel
        Fitted spectral group model object
    interventions : list
        List of all interventions to consider

    Returns
    -------
    dict
        Dictionary with 'combined_min', 'combined_max', and 'peak_max' values
    """
    all_combined_db = []
    peak_max = 0

    for intervention in interventions:
        df_intervention = df_cluster[df_cluster['intervention_name'] == intervention]
        indices = df_intervention.index.tolist()

        if len(indices) > 0:
            peak_fits, ap_fits = extract_fits_for_indices(fg, indices)
            combined_fits = peak_fits + ap_fits

            # Combined data for min/max
            combined_db = combined_fits * 10
            all_combined_db.append(combined_db)

            # Peak data for max
            peak_db = peak_fits * 10
            mean_peak = np.mean(peak_db, axis=0)

            if len(peak_db) > 1:
                sem_peak = np.std(peak_db, axis=0) / np.sqrt(len(peak_db))
                intervention_peak_max = np.max(mean_peak + 2 * sem_peak)
            else:
                intervention_peak_max = np.max(mean_peak)

            peak_max = max(peak_max, intervention_peak_max)

    if all_combined_db:
        all_combined_db = np.vstack(all_combined_db)
        combined_min = np.min(all_combined_db)
        combined_max = np.max(all_combined_db)
    else:
        combined_min, combined_max = 0, 1

    return {
        'combined_min': combined_min,
        'combined_max': combined_max,
        'peak_max': peak_max
    }


def extract_intervention_data(df_cluster, fg, interventions):
    """
    Extract spectral data for all interventions in a cluster.

    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster
    fg : SpectralGroupModel
        Fitted spectral group model object
    interventions : list
        List of intervention names

    Returns
    -------
    dict
        Dictionary with intervention names as keys and fit data as values
    """
    intervention_data = {}

    for intervention in interventions:
        df_intervention = df_cluster[df_cluster['intervention_name'] == intervention]
        indices = df_intervention.index.tolist()

        if len(indices) > 0:
            peak_fits, ap_fits = extract_fits_for_indices(fg, indices)
            intervention_data[intervention] = {
                'peak_fits': peak_fits,
                'ap_fits': ap_fits,
                'combined_fits': peak_fits + ap_fits,
                'n_subjects': len(indices)
            }

    return intervention_data


def plot_combined_fits(intervention_data, colors, cluster, save_path, freq_axis, y_limits):
    """
    Create combined fits plot (aperiodic + peaks) comparing interventions.

    Parameters
    ----------
    intervention_data : dict
        Dictionary containing fit data for each intervention
    colors : dict
        Color mapping for interventions
    cluster : int
        Cluster number
    save_path : str
        Path to save the plot (without extension)
    freq_axis : np.ndarray
        Frequency axis values
    y_limits : dict
        Dictionary with 'combined_min' and 'combined_max' values
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    for intervention, data in intervention_data.items():
        if intervention in colors:
            combined_db = data['combined_fits'] * 10
            ap_db = data['ap_fits'] * 10

            mean_combined = np.mean(combined_db, axis=0)
            mean_ap = np.mean(ap_db, axis=0)

            # Create label with intervention and sample size
            label = f"{intervention} (n={data['n_subjects']})"

            # Plot combined fit (solid line)
            ax.plot(freq_axis, mean_combined, color=colors[intervention],
                    linewidth=1, label=label)

            # Plot aperiodic fit (dashed line)
            ax.plot(freq_axis, mean_ap, color=colors[intervention],
                    linewidth=2, linestyle='--', alpha=0.7)

            # Plot SEM shading
            if len(combined_db) > 1:
                sem = np.std(combined_db, axis=0) / np.sqrt(len(combined_db))
                ax.fill_between(freq_axis,
                                mean_combined - sem,
                                mean_combined + sem,
                                color=colors[intervention], alpha=0.15)

    # Styling
    ax.set_xlabel('Frequency (Hz)', fontsize=24, fontweight='bold')
    ax.set_ylabel('Power (dB)', fontsize=24, fontweight='bold')
    ax.set_title(f'Cluster {cluster} - Intervention Task - Combined Fits',
                 fontsize=14, fontweight='bold')
    ax.legend(loc='upper right', fontsize=12, framealpha=0.9)
    ax.set_xlim(1, 55)
    ax.set_ylim(y_limits['combined_min'], y_limits['combined_max'])

    # Remove gridlines, top and right spines
    ax.grid(False)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    # Thicken remaining spines
    ax.spines['left'].set_linewidth(2)
    ax.spines['bottom'].set_linewidth(2)

    # Thicken tick marks
    ax.tick_params(width=2, length=6, labelsize=20)

    plt.tight_layout()
    plt.savefig(f'{save_path}.svg', bbox_inches='tight')
    plt.close()


def plot_peak_fits(intervention_data, colors, cluster, save_path, freq_axis, y_limits):
    """
    Create peak fits plot (peaks only, no aperiodic component) comparing interventions.

    Parameters
    ----------
    intervention_data : dict
        Dictionary containing fit data for each intervention
    colors : dict
        Color mapping for interventions
    cluster : int
        Cluster number
    save_path : str
        Path to save the plot (without extension)
    freq_axis : np.ndarray
        Frequency axis values
    y_limits : dict
        Dictionary with 'peak_max' value
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    for intervention, data in intervention_data.items():
        if intervention in colors:
            peak_db = data['peak_fits'] * 10

            mean_peak = np.mean(peak_db, axis=0)

            # Create label with intervention and sample size
            label = f"{intervention} (n={data['n_subjects']})"

            # Plot peak fit
            ax.plot(freq_axis, mean_peak, color=colors[intervention],
                    linewidth=1, label=label)

            # Plot SEM shading
            if len(peak_db) > 1:
                sem = np.std(peak_db, axis=0) / np.sqrt(len(peak_db))
                ax.fill_between(freq_axis,
                                mean_peak - sem,
                                mean_peak + sem,
                                color=colors[intervention], alpha=0.15)

    # Styling
    ax.set_xlabel('Frequency (Hz)', fontsize=24, fontweight='bold')
    ax.set_ylabel('Power (dB)', fontsize=24, fontweight='bold')
    ax.set_title(f'Cluster {cluster} - Intervention Task - Peak Fits',
                 fontsize=14, fontweight='bold')
    ax.legend(loc='upper right', fontsize=12, framealpha=0.9)
    ax.set_xlim(1, 55)
    ax.set_ylim(0, y_limits['peak_max'])

    # Remove gridlines, top and right spines
    ax.grid(False)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    # Thicken remaining spines
    ax.spines['left'].set_linewidth(2)
    ax.spines['bottom'].set_linewidth(2)

    # Thicken tick marks
    ax.tick_params(width=2, length=6, labelsize=20)

    plt.tight_layout()
    plt.savefig(f'{save_path}.svg', bbox_inches='tight')
    plt.close()


def create_cluster_plots(df_cluster, fg, cluster, save_dir):
    """
    Create intervention comparison plots for a specific cluster.

    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster (intervention task only, s2 only)
    fg : SpectralGroupModel
        Fitted spectral group model object
    cluster : int
        Cluster number
    save_dir : str
        Directory to save plots
    """
    # Frequency axis
    freq_axis = np.arange(1, 56)

    # Get unique interventions
    interventions = sorted(df_cluster['intervention_name'].dropna().unique())

    if not interventions:
        print(f"  Warning: No intervention data found for cluster {cluster}")
        return

    # Extract intervention data
    intervention_data = extract_intervention_data(df_cluster, fg, interventions)

    if not intervention_data:
        print(f"  Warning: No valid data extracted for cluster {cluster}")
        return

    # Compute y-limits
    y_limits = compute_cluster_ylimits(df_cluster, fg, interventions)

    # Generate save paths
    combined_path = os.path.join(save_dir, f'cluster_{cluster}_intervention_combined')
    peak_path = os.path.join(save_dir, f'cluster_{cluster}_intervention_peaks')

    # Create combined fits plot
    plot_combined_fits(intervention_data, INTERVENTION_COLORS, cluster,
                       combined_path, freq_axis, y_limits)

    # Create peak fits plot
    plot_peak_fits(intervention_data, INTERVENTION_COLORS, cluster,
                   peak_path, freq_axis, y_limits)

    print(f"  Created intervention comparison plots for cluster {cluster}")


def create_all_plots(df, fg, intervention_file='../demographicsPsych/data/intervention_assignments.xlsx'):
    """
    Main function to create intervention comparison plots for all clusters.

    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with spectral data including 'cluster', 'session', 'experience', and 'subject' columns
    fg : SpectralGroupModel
        Fitted SpectralGroupModel object
    intervention_file : str
        Path to intervention assignments Excel file

    Notes
    -----
    Creates 2 plots per cluster:
    - Combined fits (SVG)
    - Peak fits (SVG)

    Only processes 'intervention' task data from session 2.
    """
    # Load intervention assignments
    print(f"Loading intervention assignments from {intervention_file}...")
    df_interventions = load_intervention_assignments(intervention_file)
    print(f"Loaded {len(df_interventions)} intervention assignments\n")

    # Merge intervention data with main dataframe
    df = df.merge(df_interventions[['id', 'intervention_name']],
                  left_on='subject', right_on='id', how='left')

    # Filter for intervention task and session 2 only
    df_intervention_task = df[
        (df['experience'] == 'intervention') &
        (df['session'] == 's2')
        ].copy()

    print(f"Filtered to {len(df_intervention_task)} rows for 'intervention' task in session 2\n")

    # Check for missing interventions
    missing = df_intervention_task['intervention_name'].isna().sum()
    if missing > 0:
        print(f"Warning: {missing} rows have missing intervention assignments\n")

    # Create base results directory
    base_dir = "E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/intervention/results/final_model/"
    os.makedirs(base_dir, exist_ok=True)

    # Get unique clusters
    clusters = sorted(df_intervention_task['cluster'].unique())

    print("Starting plot generation...")
    print(f"Clusters: {clusters}\n")

    for cluster in clusters:
        # Create cluster directory
        cluster_dir = os.path.join(base_dir, f'cluster{cluster}')
        os.makedirs(cluster_dir, exist_ok=True)

        # Filter dataframe for this cluster
        df_cluster = df_intervention_task[df_intervention_task['cluster'] == cluster]

        print(f"Processing Cluster {cluster} ({len(df_cluster)} observations):")

        # Display intervention breakdown
        intervention_counts = df_cluster['intervention_name'].value_counts()
        for intervention, count in intervention_counts.items():
            print(f"  {intervention}: {count} observations")

        # Create plots
        create_cluster_plots(df_cluster, fg, cluster, cluster_dir)

        print()  # Blank line between clusters

    print("All plots have been created and saved!")
    print(f"Output directory: {base_dir}")
    print(f"\nTotal plots created: {len(clusters) * 2}")
    print(f"  - {len(clusters)} combined plots")
    print(f"  - {len(clusters)} peak plots")


if __name__ == "__main__":
    """
    Usage:
    ------
    Make sure df and fg are defined in your environment, then run:

    from create_intervention_plots import create_all_plots
    create_all_plots(df, fg)

    Or run directly if df and fg are in the script's namespace.
    """
    # Assuming df and fg are already defined in your environment
    create_all_plots(df, fg)