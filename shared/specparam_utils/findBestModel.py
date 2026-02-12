# General Imports to work with files
from scipy import io
import numpy as np
import os
import pandas as pd
import matplotlib.pyplot as plt
import pickle
import h5py

# Specparam Functions
from specparam import SpectralGroupModel
from specparam.measures.error import compute_pointwise_error_group

# Custom Functions for Data Import and Cleaning
from cleanmodel_functions import *


def assess_model_fit(mat_file_path,
                            peak_width_limits=[2, 8],
                            min_peak_height=0.2,
                            peak_threshold=2,
                            max_n_peaks=6,
                            freq_range=[2, 55],
                            underfit_threshold=0.8,
                            error_threshold=0.1):
    """
    Analyze spectral models using specparam and generate quality control plots.

    Parameters:
    -----------
    mat_file_path : str
        Path to the .mat file containing PowerSpectrumResults
    peak_width_limits : list, default [2, 8]
        Min and max peak width limits for SpectralGroupModel
    min_peak_height : float, default 0.2
        Minimum peak height for SpectralGroupModel
    peak_threshold : float, default 2
        Peak threshold for SpectralGroupModel
    max_n_peaks : int, default 6
        Maximum number of peaks for SpectralGroupModel
    freq_range : list, default [2, 55]
        Frequency range for model fitting [min_freq, max_freq]
    underfit_threshold : float, default 0.8
        R² threshold below which models are considered underfit
    error_threshold : float, default 0.1
        Error threshold above which models are considered high error

    Returns:
    --------
    fg : SpectralGroupModel
        Fitted spectral group model object
    model_directory : str
        Path to the created model directory
    """

    # Load and process data (handles both regular and v7.3 formats)
    mat_data, format_type = load_matlab_spectra(mat_file_path)
    if mat_data is None:
        raise ValueError(f"Failed to load mat file: {mat_file_path}")

    df = extract_spectra_data(mat_data, format_type)

    # If using h5py, close the file after extraction to free memory
    if format_type == 'h5py':
        mat_data.close()

    # Access your spectra data
    all_spectra = np.array([spec for spec in df['spectra']])
    freqs = np.arange(251)

    # Double check shapes
    print(f"Frequency arrays shape is {freqs.shape}")
    print(f"Spectrum array shape is {all_spectra.shape}")

    # Initialize a SpectralGroupModel object, with desired settings
    fg = SpectralGroupModel(peak_width_limits=peak_width_limits,
                            min_peak_height=min_peak_height,
                            peak_threshold=peak_threshold,
                            max_n_peaks=max_n_peaks,
                            verbose=False)

    # Create directory name based on SpectralGroupModel parameters and frequency range
    model_name = (f"pw{peak_width_limits[0]}-{peak_width_limits[1]}_"
                  f"mph{min_peak_height}_pt{peak_threshold}_mnp{max_n_peaks}_"
                  f"fr{freq_range[0]}-{freq_range[1]}")

    modelDirectory = f"E:/Tasnim_Dissertation_Analysis/specparam_analysis/results/model_eval/{model_name}"

    # Create the directory if it doesn't exist
    os.makedirs(modelDirectory, exist_ok=True)

    # Fit the power spectrum model across all components
    fg.fit(freqs, all_spectra, freq_range)

    # Fit power spectrum models and report on the group
    fg.print_results()
    fg.plot()

    # Check the overall results of the group fits and save as PDF
    fg.save_report(f"{modelDirectory}/GroupReport")

    # Plot frequency-by-frequency error
    compute_pointwise_error_group(fg, plot_errors=True)
    plt.savefig(f"{modelDirectory}/frequencyError.png")

    # Extract all fits that are below R² threshold (underfit models)
    underfit_check = []
    underfit_original_indices = []
    for ind, res in enumerate(fg):
        if res.r_squared < underfit_threshold:
            underfit_check.append(fg.get_model(ind, regenerate=True))
            underfit_original_indices.append(ind)

    print(f"Total Number of Models with R² < {underfit_threshold}: {len(underfit_check)}")

    # Create Directory for Low R² Values
    lowR2_dir = f"{modelDirectory}/lowR2_{underfit_threshold}/"
    os.makedirs(lowR2_dir, exist_ok=True)

    # Loop through each underfit model
    for i, fm in enumerate(underfit_check):
        # Get the original index
        original_ind = int(underfit_original_indices[i])

        # Extract subject, session, experience, and component from dataframe using original index
        subject = df.loc[original_ind, 'subject']
        session = df.loc[original_ind, 'session']
        experience = df.loc[original_ind, 'experience']
        component = df.loc[original_ind, 'component']

        # Create the plot
        fig = fm.plot()

        # Create filename with extracted information
        filename = f"{subject}_{session}_{experience}_IC{component}"

        # Save the figure
        plt.savefig(f"{lowR2_dir}/{filename}.png", dpi=300, bbox_inches='tight')

        # Close the figure to free memory
        plt.close(fig)

        # Print progress for underfit models
        if (i + 1) % 10 == 0:
            print(f"Processed {i + 1}/{len(underfit_check)} underfit models")

    print(f"All {len(underfit_check)} underfit models saved to: {lowR2_dir}")

    # Extract all fits that are above error threshold (high error models)
    error_check = []
    error_original_indices = []
    for ind, res in enumerate(fg):
        if res.error > error_threshold:
            error_check.append(fg.get_model(ind, regenerate=True))
            error_original_indices.append(ind)

    print(f"Total Number of Models with Error > {error_threshold}: {len(error_check)}")

    # Create Directory for High Error Values
    error_dir = f"{modelDirectory}/highError_{error_threshold}/"
    os.makedirs(error_dir, exist_ok=True)

    # Loop through each high error model
    for i, fm in enumerate(error_check):
        # Get the original index
        original_ind = int(error_original_indices[i])

        # Extract subject, session, experience, and component from dataframe using original index
        subject = df.loc[original_ind, 'subject']
        session = df.loc[original_ind, 'session']
        experience = df.loc[original_ind, 'experience']
        component = df.loc[original_ind, 'component']

        # Create the plot
        fig = fm.plot()

        # Create filename with extracted information
        filename = f"{subject}_{session}_{experience}_IC{component}"

        # Save the figure
        plt.savefig(f"{error_dir}/{filename}.png", dpi=300, bbox_inches='tight')

        # Close the figure to free memory
        plt.close(fig)

        # Print progress for high error models
        if (i + 1) % 10 == 0:
            print(f"Processed {i + 1}/{len(error_check)} high error models")

    print(f"All {len(error_check)} high error models saved to: {error_dir}")

    # Extract all fits that are above R² threshold (possivle overfit models)
    goodfit_threshold = 0.99
    goodfit_check = []
    goodfit_original_indices = []
    for ind, res in enumerate(fg):
        if res.r_squared > goodfit_threshold:
            goodfit_check.append(fg.get_model(ind, regenerate=True))
            goodfit_original_indices.append(ind)

    print(f"Total Number of Models with R² > 0.99: {len(goodfit_check)}")

    # Create Directory for Good Fit Models
    goodfit_dir = f"{modelDirectory}/overfit_{goodfit_threshold}/"
    os.makedirs(goodfit_dir, exist_ok=True)

    # Loop through each good fit model
    for i, fm in enumerate(goodfit_check):
        # Get the original index
        original_ind = int(goodfit_original_indices[i])

        # Extract subject, session, experience, and component from dataframe using original index
        subject = df.loc[original_ind, 'subject']
        session = df.loc[original_ind, 'session']
        experience = df.loc[original_ind, 'experience']
        component = df.loc[original_ind, 'component']

        # Create the plot
        fig = fm.plot()

        # Create filename with extracted information
        filename = f"{subject}_{session}_{experience}_IC{component}"

        # Save the figure
        plt.savefig(f"{goodfit_dir}/{filename}.png", dpi=300, bbox_inches='tight')

        # Close the figure to free memory
        plt.close(fig)

        # Print progress for good fit models
        if (i + 1) % 10 == 0:
            print(f"Processed {i + 1}/{len(goodfit_check)} good fit models")

    print(f"All {len(goodfit_check)} good fit models saved to: {goodfit_dir}")

    return fg, modelDirectory


# Example usage:
if __name__ == "__main__":
    # Example function call with default parameters
    fg, model_dir = assess_model_fit("../../results/PowerSpectrumResults.mat")

    # Example function call with custom parameters
    # fg, model_dir = analyze_spectral_models(
    #     mat_file_path="../../results/PowerSpectrumResults.mat",
    #     peak_width_limits=[1, 10],
    #     min_peak_height=0.15,
    #     peak_threshold=1.5,
    #     max_n_peaks=8,
    #     freq_range=[1, 50],
    #     underfit_threshold=0.75,
    #     error_threshold=0.15
    # )