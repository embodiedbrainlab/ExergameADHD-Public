#!/bin/bash
#SBATCH --job-name=xgb_tuning
#SBATCH --output=logs/xgb_tuning.out
#SBATCH --error=logs/xgb_tuning.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48          # Request 48 cores (adjust up to 64 if needed)
#SBATCH --mem=32G                    # Memory for the job (adjust as needed)
#SBATCH --time=02:00:00              # Adjust based on expected runtime
#SBATCH --partition=standard         # Adjust to your partition name

# Create directories if they don't exist
mkdir -p logs
mkdir -p results/hyperparameter_tuning

# Load R module (adjust to your cluster's module system)
# module load R/4.2.0  # Uncomment and adjust version as needed

# Print job information
echo "Job started at $(date)"
echo "Running on host: $(hostname)"
echo "Using $SLURM_CPUS_PER_TASK cores"

# Set environment variable for OpenMP (if XGBoost uses it)
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Run the R script
Rscript 08_xgboost_hyperparam_tuning_HPC.R

# Check exit status
if [ $? -eq 0 ]; then
    echo "Job completed successfully at $(date)"
else
    echo "Job failed at $(date)"
    exit 1
fi

# Optional: Send notification email (uncomment if you want email notifications)
# echo "XGBoost hyperparameter tuning complete" | mail -s "Job Complete" your.email@example.com
