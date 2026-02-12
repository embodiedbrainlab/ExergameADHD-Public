#! /bin/bash
#
#SBATCH --account=embodiedbrainlab
#SBATCH --partition=normal_q
#SBATCH --time=72:00:00
#SBATCH --output=logs/xgb_tuning.out
#SBATCH --error=logs/xgb_tuning.err
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=96
#SBATCH --job-name=xgb_tuning

# Create directories if they don't exist
mkdir -p logs
mkdir -p results

# Load R module
module reset
module load R-bundle-CRAN/2024.11-foss-2024a

# Print job information
echo "Job started at $(date)"
echo "Running on host: $(hostname)"
echo "Using $SLURM_CPUS_PER_TASK cores"

# Set environment variable for OpenMP (if XGBoost uses it)
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Run the R script
Rscript 08_xgboost_hyperparam_tuning_HPC_UPDATED.R

exit 0
