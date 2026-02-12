"""
Simplified SpecParam Plotting Script
Creates power spectral density plots for each cluster and intervention, with both sessions combined.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os

# Task groupings for plotting (combining both sessions)
PLOT_GROUPS = {
    'baseline': {
        's1': ['prebaseline'],
        's2': ['prebaseline', 'postbaseline']
    },
    'gonogo_stroop': {
        's1': ['gonogo', 'stroop'],
        's2': ['gonogo', 'stroop']
    },
    'wcst_digit': {
        's1': ['wcst', 'digitforward', 'digitbackward'],
        's2': ['wcst', 'digitforward', 'digitbackward']
    },
    'shoulder': {
        's1': ['shoulder_1', 'shoulder_2', 'shoulder_3'],
        's2': ['shoulder_1', 'shoulder_2', 'shoulder_3']
    },
    'tandem': {
        's1': ['tandem_1', 'tandem_2', 'tandem_3'],
        's2': ['tandem_1', 'tandem_2', 'tandem_3']
    }
}

# Color scheme - different colors for each task, with session indicated in legend
TASK_SESSION_COLORS = {
    "prebaseline_s1": '#1b9e77',    # Dark2
    "prebaseline_s2": '#d95f02',    # Dark2
    "postbaseline_s2": '#7570b3',   # Dark2
    "gonogo_s1": '#e7298a',         # Dark2
    "gonogo_s2": '#66a61e',         # Dark2
    "stroop_s1": '#e6ab02',         # Dark2
    "stroop_s2": '#a6761d',         # Dark2
    "wcst_s1": '#666666',           # Dark2
    "wcst_s2": '#1f77b4',           # Tab10
    "digitforward_s1": '#ff7f0e',   # Tab10
    "digitforward_s2": '#2ca02c',   # Tab10
    "digitbackward_s1": '#d62728',  # Tab10
    "digitbackward_s2": '#9467bd',  # Tab10
    "shoulder_1_s1": '#8c564b',     # Tab10
    "shoulder_1_s2": '#e377c2',     # Tab10
    "shoulder_2_s1": '#7f7f7f',     # Tab10
    "shoulder_2_s2": '#bcbd22',     # Tab10
    "shoulder_3_s1": '#17becf',     # Tab10
    "shoulder_3_s2": '#66c2a5',     # Set2
    "tandem_1_s1": '#fc8d62',       # Set2
    "tandem_1_s2": '#8da0cb',       # Set2
    "tandem_2_s1": '#e78ac3',       # Set2
    "tandem_2_s2": '#a6d854',       # Set2
    "tandem_3_s1": '#ffd92f',       # Set2
    "tandem_3_s2": '#e5c494',       # Set2
}

# Intervention mapping
INTERVENTION_MAP = {
    'A': 'Dance_Exergaming',
    'B': 'Biking',
    'C': 'Music_Listening'
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


def compute_cluster_peak_ylimit(df_cluster, fg, intervention_name):
    """
    Compute peak y-axis limit for all plots in a cluster (across all interventions).
    This should be called once per cluster to ensure consistent y-axis across all peak plots.

    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster and intervention
    fg : SpectralGroupModel
        Fitted spectral group model object
    intervention_name : str
        Name of the intervention (not used in calculation, but for clarity)

    Returns
    -------
    float
        Maximum y-value for peak plots
    """
    peak_max = 0

    # Iterate through all plot groups and sessions
    for group_name, session_tasks in PLOT_GROUPS.items():
        for session, tasks in session_tasks.items():
            for task in tasks:
                df_task = df_cluster[
                    (df_cluster['experience'] == task) &
                    (df_cluster['session'] == session)
                    ]
                indices = df_task.index.tolist()

                if len(indices) > 0:
                    task_peak_fits, _ = extract_fits_for_indices(fg, indices)
                    peak_db = task_peak_fits * 10

                    mean_peak = np.mean(peak_db, axis=0)
                    if len(peak_db) > 1:
                        sem_peak = np.std(peak_db, axis=0) / np.sqrt(len(peak_db))
                        task_max = np.max(mean_peak + 2 * sem_peak)
                    else:
                        task_max = np.max(mean_peak)

                    peak_max = max(peak_max, task_max)

    return peak_max


def compute_group_ylimits(df_cluster, fg, group_name, session_tasks):
    """
    Compute y-axis limits for a specific plot group (e.g., baseline, gonogo_stroop).

    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster and intervention
    fg : SpectralGroupModel
        Fitted spectral group model object
    group_name : str
        Name of the plot group
    session_tasks : dict
        Dictionary mapping sessions to task lists

    Returns
    -------
    dict
        Dictionary with 'combined_min' and 'combined_max' values
    """
    all_combined_db = []

    for session, tasks in session_tasks.items():
        for task in tasks:
            df_task = df_cluster[
                (df_cluster['experience'] == task) &
                (df_cluster['session'] == session)
                ]
            indices = df_task.index.tolist()

            if len(indices) > 0:
                peak_fits, ap_fits = extract_fits_for_indices(fg, indices)
                combined_fits = peak_fits + ap_fits
                combined_db = combined_fits * 10
                all_combined_db.append(combined_db)

    if all_combined_db:
        all_combined_db = np.vstack(all_combined_db)
        combined_min = np.min(all_combined_db)
        combined_max = np.max(all_combined_db)
    else:
        combined_min, combined_max = 0, 1

    return {
        'combined_min': combined_min,
        'combined_max': combined_max
    }


def extract_group_data(df_cluster, fg, session_tasks):
    """
    Extract spectral data for all tasks in a plot group across both sessions.

    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster and intervention
    fg : SpectralGroupModel
        Fitted spectral group model object
    session_tasks : dict
        Dictionary mapping sessions to task lists

    Returns
    -------
    dict
        Dictionary with task_session keys and fit data as values
    """
    task_data = {}

    for session, tasks in session_tasks.items():
        for task in tasks:
            df_task = df_cluster[
                (df_cluster['experience'] == task) &
                (df_cluster['session'] == session)
                ]
            indices = df_task.index.tolist()

            if len(indices) > 0:
                peak_fits, ap_fits = extract_fits_for_indices(fg, indices)
                task_session_key = f"{task}_{session}"
                task_data[task_session_key] = {
                    'peak_fits': peak_fits,
                    'ap_fits': ap_fits,
                    'combined_fits': peak_fits + ap_fits,
                    'n_subjects': len(indices),
                    'task': task,
                    'session': session
                }

    return task_data


def plot_combined_fits(task_data, colors, cluster, intervention, group_name,
                       save_path, freq_axis, y_limits):
    """
    Create combined fits plot (aperiodic + peaks) for both sessions.

    Parameters
    ----------
    task_data : dict
        Dictionary containing fit data for each task_session
    colors : dict
        Color mapping for task_session combinations
    cluster : int
        Cluster number
    intervention : str
        Intervention name
    group_name : str
        Name of task group (e.g., 'baseline', 'gonogo_stroop')
    save_path : str
        Path to save the plot (without extension)
    freq_axis : np.ndarray
        Frequency axis values
    y_limits : dict
        Dictionary with 'combined_min' and 'combined_max' values
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    for task_session_key, data in task_data.items():
        if task_session_key in colors:
            combined_db = data['combined_fits'] * 10
            ap_db = data['ap_fits'] * 10

            mean_combined = np.mean(combined_db, axis=0)
            mean_ap = np.mean(ap_db, axis=0)

            # Create label with task, session, and sample size
            task = data['task']
            session = data['session'].upper()
            label = f"{task} {session} (n={data['n_subjects']})"

            # Plot combined fit (solid line)
            ax.plot(freq_axis, mean_combined, color=colors[task_session_key],
                    linewidth=1, label=label)

            # Plot aperiodic fit (dashed line)
            ax.plot(freq_axis, mean_ap, color=colors[task_session_key],
                    linewidth=2, linestyle='--', alpha=0.7)

            # Plot SEM shading
            if len(combined_db) > 1:
                sem = np.std(combined_db, axis=0) / np.sqrt(len(combined_db))
                ax.fill_between(freq_axis,
                                mean_combined - sem,
                                mean_combined + sem,
                                color=colors[task_session_key], alpha=0.15)

    # Styling
    ax.set_xlabel('Frequency (Hz)', fontsize=24, fontweight='bold')
    ax.set_ylabel('Power (dB)', fontsize=24, fontweight='bold')
    ax.set_title(f'Cluster {cluster} - {intervention} - {group_name.replace("_", " ").title()} - Combined Fits',
                 fontsize=14, fontweight='bold')
    ax.legend(loc='upper right', fontsize=9, framealpha=0.9)
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


def plot_peak_fits(task_data, colors, cluster, intervention, group_name,
                   save_path, freq_axis, peak_ylimit):
    """
    Create peak fits plot (peaks only, no aperiodic component) for both sessions.

    Parameters
    ----------
    task_data : dict
        Dictionary containing fit data for each task_session
    colors : dict
        Color mapping for task_session combinations
    cluster : int
        Cluster number
    intervention : str
        Intervention name
    group_name : str
        Name of task group (e.g., 'baseline', 'gonogo_stroop')
    save_path : str
        Path to save the plot (without extension)
    freq_axis : np.ndarray
        Frequency axis values
    peak_ylimit : float
        Maximum y-value for consistent scaling across all peak plots in cluster
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    for task_session_key, data in task_data.items():
        if task_session_key in colors:
            peak_db = data['peak_fits'] * 10

            mean_peak = np.mean(peak_db, axis=0)

            # Create label with task, session, and sample size
            task = data['task']
            session = data['session'].upper()
            label = f"{task} {session} (n={data['n_subjects']})"

            # Plot peak fit
            ax.plot(freq_axis, mean_peak, color=colors[task_session_key],
                    linewidth=1, label=label)

            # Plot SEM shading
            if len(peak_db) > 1:
                sem = np.std(peak_db, axis=0) / np.sqrt(len(peak_db))
                ax.fill_between(freq_axis,
                                mean_peak - sem,
                                mean_peak + sem,
                                color=colors[task_session_key], alpha=0.15)

    # Styling
    ax.set_xlabel('Frequency (Hz)', fontsize=24, fontweight='bold')
    ax.set_ylabel('Power (dB)', fontsize=24, fontweight='bold')
    ax.set_title(f'Cluster {cluster} - {intervention} - {group_name.replace("_", " ").title()} - Peak Fits',
                 fontsize=14, fontweight='bold')
    ax.legend(loc='upper right', fontsize=9, framealpha=0.9)
    ax.set_xlim(1, 55)
    ax.set_ylim(0, peak_ylimit)

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


def create_intervention_plots(df_intervention, fg, cluster, intervention, save_dir, peak_ylimit):
    """
    Create all plots for a specific cluster and intervention.

    Parameters
    ----------
    df_intervention : pd.DataFrame
        DataFrame subset for specific cluster and intervention
    fg : SpectralGroupModel
        Fitted spectral group model object
    cluster : int
        Cluster number
    intervention : str
        Intervention name
    save_dir : str
        Directory to save plots
    peak_ylimit : float
        Maximum y-value for all peak plots in this cluster
    """
    # Frequency axis
    freq_axis = np.arange(1, 56)

    # Process each plot group
    for group_name, session_tasks in PLOT_GROUPS.items():
        # Extract task data for this group
        task_data = extract_group_data(df_intervention, fg, session_tasks)

        if not task_data:
            print(f"  Warning: No data found for {group_name} in {intervention}")
            continue

        # Compute y-limits for combined plots
        y_limits = compute_group_ylimits(df_intervention, fg, group_name, session_tasks)

        # Generate save paths
        base_name = f'cluster_{cluster}_{intervention}_{group_name}'
        combined_path = os.path.join(save_dir, f'{base_name}_combined')
        peak_path = os.path.join(save_dir, f'{base_name}_peaks')

        # Create combined fits plot (SVG only)
        plot_combined_fits(task_data, TASK_SESSION_COLORS, cluster, intervention,
                           group_name, combined_path, freq_axis, y_limits)

        # Create peak fits plot (SVG only, with consistent y-axis)
        plot_peak_fits(task_data, TASK_SESSION_COLORS, cluster, intervention,
                       group_name, peak_path, freq_axis, peak_ylimit)

        print(f"  Created {group_name} plots for {intervention}")


def create_all_plots(df, fg, intervention_file='../demographicsPsych/data/intervention_assignments.xlsx'):
    """
    Main function to create all plots for all clusters and interventions.

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
    Creates 10 plots per intervention per cluster (30 total per cluster):
    - 5 combined plots (baseline, gonogo_stroop, wcst_digit, shoulder, tandem)
    - 5 peak plots (same groups)
    All saved as SVG only.
    """
    # Load intervention assignments
    print(f"Loading intervention assignments from {intervention_file}...")
    df_interventions = load_intervention_assignments(intervention_file)
    print(f"Loaded {len(df_interventions)} intervention assignments\n")

    # Merge intervention data with main dataframe
    df = df.merge(df_interventions[['id', 'intervention_name']],
                  left_on='subject', right_on='id', how='left')

    # Check for missing interventions
    missing = df['intervention_name'].isna().sum()
    if missing > 0:
        print(f"Warning: {missing} rows have missing intervention assignments\n")

    # Create base results directory
    base_dir = "E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/results/final_model/"
    os.makedirs(base_dir, exist_ok=True)

    # Get unique clusters and interventions
    clusters = sorted(df['cluster'].unique())
    interventions = sorted(df['intervention_name'].dropna().unique())

    print("Starting plot generation...")
    print(f"Clusters: {clusters}")
    print(f"Interventions: {interventions}\n")

    for cluster in clusters:
        # Create cluster directory
        cluster_dir = os.path.join(base_dir, f'cluster{cluster}')
        os.makedirs(cluster_dir, exist_ok=True)

        # Filter dataframe for this cluster
        df_cluster = df[df['cluster'] == cluster]

        # Compute peak y-limit once for this cluster (across all interventions)
        # We need to check all interventions to get the global max
        cluster_peak_ylimit = 0
        for intervention in interventions:
            df_cluster_intervention = df_cluster[df_cluster['intervention_name'] == intervention]
            if len(df_cluster_intervention) > 0:
                intervention_peak_ylimit = compute_cluster_peak_ylimit(df_cluster_intervention, fg, intervention)
                cluster_peak_ylimit = max(cluster_peak_ylimit, intervention_peak_ylimit)

        print(f"Cluster {cluster} - Peak y-limit: {cluster_peak_ylimit:.2f}")

        # Create plots for each intervention
        for intervention in interventions:
            df_cluster_intervention = df_cluster[df_cluster['intervention_name'] == intervention]

            if len(df_cluster_intervention) > 0:
                print(f"\nProcessing Cluster {cluster}, Intervention {intervention}:")
                create_intervention_plots(df_cluster_intervention, fg, cluster,
                                          intervention, cluster_dir, cluster_peak_ylimit)
            else:
                print(f"No data found for Cluster {cluster}, Intervention {intervention}")

        print("\n" + "=" * 60 + "\n")

    print("All plots have been created and saved!")
    print(f"Output directory: {base_dir}")


if __name__ == "__main__":
    """
    Usage:
    ------
    Make sure df and fg are defined in your environment, then run:

    from create_specparam_plots_updated import create_all_plots
    create_all_plots(df, fg)

    Or run directly if df and fg are in the script's namespace.
    """
    # Assuming df and fg are already defined in your environment
    create_all_plots(df, fg)
