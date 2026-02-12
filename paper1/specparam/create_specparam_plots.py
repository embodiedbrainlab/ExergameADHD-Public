"""
Simplified SpecParam Plotting Script
Creates power spectral density plots for each cluster, grouped by task type.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os


# Task groupings
TASK_GROUPS = {
    'baseline': ['prebaseline'],
    'cognitive': ['digitforward', 'digitbackward', 'gonogo', 'wcst', 'stroop'],
    'motor': ['shoulder_1', 'shoulder_2', 'shoulder_3', 'tandem_1', 'tandem_2', 'tandem_3']
}

# Color scheme for all tasks
TASK_COLORS = {
    "prebaseline": '#1f77b4',
    "gonogo": '#ff7f0e',
    "stroop": '#2ca02c',
    "wcst": '#d62728',
    "digitforward": '#9467bd',
    "digitbackward": '#8c564b',
    "shoulder_1": '#e377c2',
    "shoulder_2": '#7f7f7f',
    "shoulder_3": '#bcbd22',
    "tandem_1": '#17becf',
    "tandem_2": '#aec7e8',
    "tandem_3": '#ffbb78',
}


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


def compute_cluster_ylimits(df_cluster, fg, tasks):
    """
    Compute y-axis limits for plots across all tasks in a cluster.
    
    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster
    fg : SpectralGroupModel
        Fitted spectral group model object
    tasks : list
        List of all tasks to consider
        
    Returns
    -------
    dict
        Dictionary with 'combined_min', 'combined_max', and 'peak_max' values
    """
    # Get all data for combined fits min/max
    all_indices = df_cluster.index.tolist()
    peak_fits, ap_fits = extract_fits_for_indices(fg, all_indices)
    combined_fits = peak_fits + ap_fits
    combined_db = combined_fits * 10
    
    combined_min = np.min(combined_db)
    combined_max = np.max(combined_db)
    
    # Compute peak_max as max(mean + 2*SEM) across all tasks
    peak_max = 0
    for task in tasks:
        df_task = df_cluster[df_cluster['experience'] == task]
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
    
    return {
        'combined_min': combined_min,
        'combined_max': combined_max,
        'peak_max': peak_max
    }


def extract_task_data(df_cluster, fg, tasks):
    """
    Extract spectral data for specified tasks from a cluster.
    
    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster
    fg : SpectralGroupModel
        Fitted spectral group model object
    tasks : list
        List of task names to extract
        
    Returns
    -------
    dict
        Dictionary with task names as keys and fit data as values
    """
    task_data = {}
    
    for task in tasks:
        df_task = df_cluster[df_cluster['experience'] == task]
        indices = df_task.index.tolist()
        
        if len(indices) > 0:
            peak_fits, ap_fits = extract_fits_for_indices(fg, indices)
            task_data[task] = {
                'peak_fits': peak_fits,
                'ap_fits': ap_fits,
                'combined_fits': peak_fits + ap_fits,
                'n_subjects': len(indices)
            }
    
    return task_data


def plot_combined_fits(task_data, tasks, colors, cluster, session, group_name, 
                      save_path, freq_axis, y_limits):
    """
    Create combined fits plot (aperiodic + peaks).
    
    Parameters
    ----------
    task_data : dict
        Dictionary containing fit data for each task
    tasks : list
        List of tasks to plot
    colors : dict
        Color mapping for tasks
    cluster : int
        Cluster number
    session : str
        Session identifier
    group_name : str
        Name of task group (e.g., 'baseline', 'cognitive', 'motor')
    save_path : str
        Path to save the plot (without extension)
    freq_axis : np.ndarray
        Frequency axis values
    y_limits : dict
        Dictionary with 'combined_min' and 'combined_max' values
    """
    fig, ax = plt.subplots(figsize=(10, 6))
    
    for task in tasks:
        if task in task_data and task in colors:
            data = task_data[task]
            combined_db = data['combined_fits'] * 10
            ap_db = data['ap_fits'] * 10
            
            mean_combined = np.mean(combined_db, axis=0)
            mean_ap = np.mean(ap_db, axis=0)
            
            # Plot combined fit (solid line)
            label = f"{task} (n={data['n_subjects']})"
            ax.plot(freq_axis, mean_combined, color=colors[task],
                   linewidth=1, label=label)
            
            # Plot aperiodic fit (dashed line)
            ax.plot(freq_axis, mean_ap, color=colors[task],
                   linewidth=2, linestyle='--', alpha=0.7)
            
            # Plot SEM shading
            if len(combined_db) > 1:
                sem = np.std(combined_db, axis=0) / np.sqrt(len(combined_db))
                ax.fill_between(freq_axis, 
                               mean_combined - sem, 
                               mean_combined + sem,
                               color=colors[task], alpha=0.15)
    
    # Styling
    ax.set_xlabel('Frequency (Hz)', fontsize=24, fontweight='bold')
    ax.set_ylabel('Power (dB)', fontsize=24, fontweight='bold')
    ax.set_title(f'Cluster {cluster} - {session} - {group_name.capitalize()} Tasks - Combined Fits',
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
    ax.tick_params(width=2, length=6, labelsize = 20)
    
    plt.tight_layout()
    plt.savefig(f'{save_path}.png', dpi=300, bbox_inches='tight')
    plt.close()


def plot_peak_fits(task_data, tasks, colors, cluster, session, group_name,
                  save_path, freq_axis, y_limits):
    """
    Create peak fits plot (peaks only, no aperiodic component).
    
    Parameters
    ----------
    task_data : dict
        Dictionary containing fit data for each task
    tasks : list
        List of tasks to plot
    colors : dict
        Color mapping for tasks
    cluster : int
        Cluster number
    session : str
        Session identifier
    group_name : str
        Name of task group (e.g., 'baseline', 'cognitive', 'motor')
    save_path : str
        Path to save the plot (without extension)
    freq_axis : np.ndarray
        Frequency axis values
    y_limits : dict
        Dictionary with 'peak_max' value
    """
    fig, ax = plt.subplots(figsize=(10, 6))
    
    for task in tasks:
        if task in task_data and task in colors:
            data = task_data[task]
            peak_db = data['peak_fits'] * 10
            
            mean_peak = np.mean(peak_db, axis=0)
            
            # Plot peak fit
            label = f"{task} (n={data['n_subjects']})"
            ax.plot(freq_axis, mean_peak, color=colors[task],
                   linewidth=1, label=label)
            
            # Plot SEM shading
            if len(peak_db) > 1:
                sem = np.std(peak_db, axis=0) / np.sqrt(len(peak_db))
                ax.fill_between(freq_axis,
                               mean_peak - sem,
                               mean_peak + sem,
                               color=colors[task], alpha=0.15)
    
    # Styling
    ax.set_xlabel('Frequency (Hz)', fontsize=24, fontweight='bold')
    ax.set_ylabel('Power (dB)', fontsize=24, fontweight='bold')
    ax.set_title(f'Cluster {cluster} - {session} - {group_name.capitalize()} Tasks - Peak Fits',
                fontsize=14, fontweight='bold')
    ax.legend(loc='upper right', fontsize=9, framealpha=0.9)
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
    ax.tick_params(width=2, length=6, labelsize = 20)
    
    plt.tight_layout()
    
    # Save both PNG and SVG
    plt.savefig(f'{save_path}.png', dpi=300, bbox_inches='tight')
    plt.savefig(f'{save_path}.svg', bbox_inches='tight')
    plt.close()


def create_cluster_plots(df_cluster, fg, cluster, session, save_dir):
    """
    Create all plots for a specific cluster and session.
    
    Parameters
    ----------
    df_cluster : pd.DataFrame
        DataFrame subset for specific cluster
    fg : SpectralGroupModel
        Fitted spectral group model object
    cluster : int
        Cluster number
    session : str
        Session identifier
    save_dir : str
        Directory to save plots
    """
    # Frequency axis
    freq_axis = np.arange(1, 56)
    
    # Get all unique tasks in this cluster
    all_tasks = []
    for tasks in TASK_GROUPS.values():
        all_tasks.extend(tasks)
    
    # Compute cluster-wide y-limits
    y_limits = compute_cluster_ylimits(df_cluster, fg, all_tasks)
    
    # Process each task group
    for group_name, tasks in TASK_GROUPS.items():
        # Extract task data
        task_data = extract_task_data(df_cluster, fg, tasks)
        
        if not task_data:
            print(f"  Warning: No data found for {group_name} tasks")
            continue
        
        # Generate save paths
        base_name = f'cluster_{cluster}_{session}_{group_name}'
        combined_path = os.path.join(save_dir, f'{base_name}_combined')
        peak_path = os.path.join(save_dir, f'{base_name}_peaks')
        
        # Create combined fits plot (PNG only)
        plot_combined_fits(task_data, tasks, TASK_COLORS, cluster, session,
                          group_name, combined_path, freq_axis, y_limits)
        
        # Create peak fits plot (PNG + SVG)
        plot_peak_fits(task_data, tasks, TASK_COLORS, cluster, session,
                      group_name, peak_path, freq_axis, y_limits)
        
        print(f"  Created {group_name} plots")



def create_all_plots(df, fg):
    """
    Main function to create all plots for all clusters and sessions.
    
    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with spectral data including 'cluster', 'session', and 'experience' columns
    fg : SpectralGroupModel
        Fitted SpectralGroupModel object
        
    Notes
    -----
    Creates 6 plots per cluster:
    - Baseline: combined (PNG) + peaks (PNG + SVG)
    - Cognitive: combined (PNG) + peaks (PNG + SVG)
    - Motor: combined (PNG) + peaks (PNG + SVG)
    """
    # Create base results directory
    base_dir = "../results/specparam/final_model/"
    os.makedirs(base_dir, exist_ok=True)
    
    # Get unique clusters and sessions
    clusters = sorted(df['cluster'].unique())
    sessions = ['s1']  # Add 's2' for paper 2 analysis
    
    print("Starting plot generation...")
    print(f"Clusters: {clusters}")
    print(f"Sessions: {sessions}\n")
    
    for cluster in clusters:
        # Create cluster directory
        cluster_dir = os.path.join(base_dir, f'cluster{cluster}')
        os.makedirs(cluster_dir, exist_ok=True)
        
        # Filter dataframe for this cluster
        df_cluster = df[df['cluster'] == cluster]
        
        for session in sessions:
            # Filter for this session
            df_cluster_session = df_cluster[df_cluster['session'] == session]
            
            if len(df_cluster_session) > 0:
                print(f"Processing Cluster {cluster}, Session {session}:")
                create_cluster_plots(df_cluster_session, fg, cluster, 
                                   session, cluster_dir)
            else:
                print(f"No data found for Cluster {cluster}, Session {session}")
        
        print()  # Blank line between clusters
    
    print("All plots have been created and saved!")
    print(f"Output directory: {base_dir}")


if __name__ == "__main__":
    """
    Usage:
    ------
    Make sure df and fg are defined in your environment, then run:
    
    from create_specparam_plots import create_all_plots
    create_all_plots(df, fg)
    
    Or run directly if df and fg are in the script's namespace.
    """
    # Assuming df and fg are already defined in your environment
    create_all_plots(df, fg)
