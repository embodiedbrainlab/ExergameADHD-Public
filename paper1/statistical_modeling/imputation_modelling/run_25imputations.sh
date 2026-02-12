#! /bin/bash
#
#SBATCH --account=embodiedbrainlab
#SBATCH --partition=normal_q
#SBATCH --array=1-25
#SBATCH --time=10:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --output=logs/slurm_%A_%a.out
#SBATCH --error=logs/slurm_%A_%a.err
#SBATCH --job-name=mice_impute
#
# Create necessary directories
mkdir -p logs
mkdir -p results

# Print job information
echo "========================================="
echo "SLURM Job Array ID: $SLURM_ARRAY_JOB_ID"
echo "SLURM Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Running on node: $(hostname)"
echo "Start time: $(date)"
echo "========================================="

# Load necessary module
module reset
module load R-bundle-CRAN/2024.11-foss-2024a

# Run R script
Rscript 02_batchImputation.R

exit 0
