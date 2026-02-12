# XGBoost Hyperparameter Tuning for Small Sample Size
## Robust Approach for N=67 observations with 109 predictors

This repository contains a comprehensive hyperparameter tuning pipeline for XGBoost, specifically designed for small sample sizes with high-dimensional data.

## Overview

Given the challenging scenario of 67 observations with 109 predictors, this pipeline implements:
- Extensive hyperparameter grid search
- Nested cross-validation for unbiased evaluation
- Repeated train-test splits for stability assessment
- Bootstrap confidence intervals
- SHAP-based feature importance with uncertainty quantification

## Files

### Core Scripts

1. **`08_xgboost_hyperparam_tuning_HPC.R`**
   - Main hyperparameter tuning script for HPC execution
   - Tests comprehensive parameter grid
   - Implements nested CV with repeated train-test splits
   - Designed for parallel execution across cluster nodes

2. **`09_combine_hyperparam_results.R`**
   - Combines results from all HPC jobs
   - Calculates composite scores balancing performance and stability
   - Identifies robust parameter sets
   - Generates comprehensive visualizations

3. **`10_final_xgboost_model.R`**
   - Trains final model with optimal parameters
   - Performs extensive evaluation with 50 train-test splits
   - Calculates bootstrap confidence intervals
   - Generates SHAP values and feature importance

### HPC Submission

4. **`submit_xgb_tuning.sh`**
   - SLURM job submission script
   - Configures array job for parallel execution
   - Adjust parameters based on your cluster

## Hyperparameter Search Space

Given the small sample size, the grid focuses on regularization:

| Parameter | Range | Rationale |
|-----------|-------|-----------|
| `nrounds` | 20-150 | Fewer rounds to prevent overfitting |
| `max_depth` | 2-5 | Shallow trees for small data |
| `eta` | 0.01-0.2 | Various learning rates |
| `gamma` | 0-5 | Higher values for conservative splitting |
| `min_child_weight` | 3-15 | Higher values for small samples |
| `lambda` | 0.5-10 | Strong L2 regularization |
| `alpha` | 0-5 | L1 regularization for sparsity |
| `subsample` | 0.5-1 | Row subsampling |
| `colsample_bytree` | 0.4-1 | Feature subsampling |

## Usage

### Step 1: Run Hyperparameter Tuning on HPC

```bash
# Submit array job to cluster
sbatch submit_xgb_tuning.sh

# Monitor job progress
squeue -u $USER
```

### Step 2: Combine Results

After all jobs complete:

```R
# Run locally or on a single node
Rscript 09_combine_hyperparam_results.R
```

This generates:
- `results/all_hyperparameter_results.csv` - Complete results
- `results/top20_*.csv` - Best parameter sets by different metrics
- `results/recommended_xgboost_params.rds` - Recommended parameters
- Visualizations showing performance vs stability trade-offs

### Step 3: Train Final Model

```R
Rscript 10_final_xgboost_model.R
```

This produces:
- Final performance metrics with confidence intervals
- Feature importance rankings with uncertainty
- Diagnostic plots (predictions, residuals)
- `results/final_xgboost_model_results.RData` - Complete results

## Evaluation Methodology

### Nested Cross-Validation
- **Outer loop**: 5-fold CV for unbiased performance estimation
- **Inner loop**: 5-fold CV for hyperparameter selection
- Prevents overfitting in parameter selection

### Repeated Train-Test Splits
- 20-50 random 70/30 splits per parameter set
- Assesses stability across different data partitions
- Critical for small sample sizes

### Composite Scoring
Parameters are ranked by a weighted combination of:
- **Performance** (50%): Median test R²
- **Stability** (30%): Low variance across splits
- **Robustness** (20%): Narrow IQR of performance

## Key Features for Small Sample Size

1. **Strong Regularization Focus**
   - Higher lambda and alpha values in grid
   - Larger min_child_weight values
   - Shallow trees (max_depth 2-5)

2. **Stability Assessment**
   - Multiple metrics for variation
   - Identifies parameters appearing in multiple "top" lists
   - Bootstrap confidence intervals

3. **Conservative Approach**
   - Early stopping to prevent overfitting
   - Multiple validation strategies
   - Extensive cross-validation

## Output Interpretation

### Performance Metrics
- **R²**: Proportion of variance explained (consider >0.3 reasonable for this data size)
- **RMSE**: Root mean squared error in original units
- **MAE**: Mean absolute error
- **Stability scores**: Lower is better

### Feature Importance
- Based on SHAP values
- Includes uncertainty (IQR, SD)
- Stability score indicates consistency across models

### Recommendations
The pipeline provides multiple parameter sets:
- `best_overall`: Highest composite score
- `most_stable`: Lowest variance
- `best_r2`: Highest median R²
- `robust_choice`: Appears in multiple top lists

## Customization

### Adjusting for Your HPC System

Edit `submit_xgb_tuning.sh`:
```bash
#SBATCH --array=1-100        # Number of parallel jobs
#SBATCH --cpus-per-task=4    # CPUs per job
#SBATCH --mem=8G             # Memory per job
#SBATCH --time=02:00:00      # Expected runtime
```

### Modifying Parameter Grid

Edit the `param_grid` in `08_xgboost_hyperparam_tuning_HPC.R`:
```R
param_grid <- expand.grid(
  nrounds = c(20, 50, 100),  # Add/remove values
  max_depth = c(2, 3, 4),    # Adjust range
  # ... etc
)
```

### Changing Evaluation Criteria

In `10_final_xgboost_model.R`, select different parameters:
```R
PARAM_CHOICE <- "most_stable"  # Or "best_r2", "robust_choice"
```

## Troubleshooting

### Memory Issues
- Reduce `N_TRAIN_TEST_SPLITS` (default: 20)
- Decrease number of SHAP calculations
- Use fewer parameter combinations

### Runtime Issues
- Increase time limit in SLURM script
- Reduce parameter grid size
- Use more parallel jobs

### Poor Performance
- Consider feature engineering
- Try dimensionality reduction first
- Collect more data if possible

## Expected Runtime

With 100 parallel jobs on a standard cluster:
- Hyperparameter tuning: 1-2 hours
- Result combination: 5-10 minutes
- Final model training: 20-30 minutes

## Citation

If you use this pipeline, please cite:
- XGBoost: Chen & Guestrin (2016)
- SHAP: Lundberg & Lee (2017)
- Your research publication

## Notes on Statistical Power

With N=67 and p=109:
- Effective degrees of freedom are limited
- Cross-validation folds are small (~13 observations)
- Results should be interpreted with caution
- Consider this as exploratory analysis
- Validate findings with additional data when possible

## Contact

For questions or issues with the pipeline, please open an issue in the repository.
