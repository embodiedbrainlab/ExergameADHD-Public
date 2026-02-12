# QUICK REFERENCE: INTERPRETING YOUR RESULTS

## After Running the Updated Script

### Step 1: Check Console Output

Look for this section:
```
=== OVERFITTING ASSESSMENT ===
✓ EXCELLENT: Minimal overfitting detected
```

**Good signs:**
- Train R² < 0.70
- Test R² between 0.20-0.35
- R² Gap < 0.20

**Bad signs:**
- Train R² > 0.90 (still overfitting!)
- Test R² < 0.10 (underfitting or severe overfitting)
- R² Gap > 0.30 (severe overfitting)

### Step 2: Review the CSV Files

**File: `results/all_hyperparameter_results.csv`**

Key columns to check:
- `train_r2_median` - Should be 0.30-0.60
- `test_r2_median` - Should be 0.20-0.30
- `r2_gap_median` - Should be < 0.20
- `combined_score` - Higher is better overall

Sort by different metrics:
```r
results <- read.csv("results/all_hyperparameter_results.csv")

# Best combined score
best_overall <- results[order(-results$combined_score), ][1, ]

# Lowest overfitting
best_gap <- results[order(results$r2_gap_median), ][1, ]

# Best test performance with acceptable gap
best_safe <- results[results$r2_gap_median < 0.20, ]
best_safe <- best_safe[order(-best_safe$test_r2_median), ][1, ]
```

### Step 3: Review Visualizations

**File: `results/train_vs_test_r2.png`**
- X-axis: Train R²
- Y-axis: Test R²
- Diagonal line: Perfect generalization
- **Good:** Points close to diagonal
- **Bad:** Points far above diagonal (high train, low test)

**File: `results/overfitting_assessment.png`**
- X-axis: Test R²
- Y-axis: R² Gap (Train - Test)
- Horizontal lines at 0.1 and 0.2
- **Good:** Points below the 0.1 or 0.2 line
- **Bad:** Points high up (large gap)

**File: `results/hyperparameter_performance_stability.png`**
- X-axis: Test R²
- Y-axis: Test R² standard deviation
- **Good:** High X (good performance), Low Y (stable)
- Red triangles show top 10 models

### Step 4: Load Recommended Parameters

```r
# Load recommendations
params <- readRDS("results/recommended_xgboost_params.rds")

# View all options
print(params)

# Most conservative (least overfitting)
print(params$least_overfitting)

# Best overall score
print(params$best_overall)

# Most stable
print(params$most_stable)

# Appears in multiple top lists (RECOMMENDED)
print(params$robust_choice)
```

### Step 5: Verify Your Choice

Before using parameters in final model, check:

```r
results <- read.csv("results/all_hyperparameter_results.csv")

# Find your chosen parameter set (example: param_id = 42)
chosen <- results[results$param_id == 42, ]

cat("Train R²:", chosen$train_r2_median, "\n")
cat("Test R²:", chosen$test_r2_median, "\n")
cat("Gap:", chosen$r2_gap_median, "\n")

# Checklist:
# [ ] Gap < 0.20 (acceptable overfitting)
# [ ] Train R² < 0.70 (not memorizing)
# [ ] Test R² > 0.15 (has some predictive power)
# [ ] Test R² SD < 0.10 (reasonably stable)
```

## Parameter Interpretation Guide

### What makes parameters "anti-overfitting"?

**nrounds:**
- Lower = Less overfitting
- 10-20: Very conservative
- 30-40: Moderate
- 50+: Risky with your data size

**max_depth:**
- 2: Very shallow (good for small data)
- 3: Moderate
- 4+: Deep (risky with 67 observations)

**gamma:**
- Higher = More pruning = Less overfitting
- 1: Minimal pruning
- 2-5: Moderate to strong pruning
- 0: No pruning (avoid!)

**lambda (L2 regularization):**
- Higher = Stronger regularization
- 2: Minimal
- 5-10: Moderate
- 20: Very strong

**alpha (L1 regularization):**
- Higher = Stronger regularization + feature selection
- 0.5: Minimal
- 1-2: Moderate
- 5: Very strong

**min_child_weight:**
- Higher = Larger leaves = Less overfitting
- 5: Moderate
- 10-15: Conservative

**subsample:**
- Lower = More regularization
- 0.6: Strong subsampling
- 0.7-0.85: Moderate
- 1: No subsampling

**colsample_bytree:**
- Lower = Fewer features per tree = Less overfitting
- 0.5: Strong feature subsampling
- 0.6-0.8: Moderate
- 1: All features (avoid!)

## Red Flags to Watch For

🚩 **All parameter combinations show gap > 0.30**
→ Your problem may be too difficult for this sample size
→ Consider feature selection or simpler models

🚩 **Best parameters have nrounds = 10 and gap still > 0.20**
→ Even minimal complexity overfits
→ Need more data or fewer features

🚩 **Train R² < Test R² (negative gap)**
→ Something went wrong (check data leakage, imputation issues)

🚩 **Test R² < 0.10 across all parameters**
→ Features may not be predictive
→ Or severe overfitting making test performance collapse

## Decision Matrix

| Scenario | Recommended Choice |
|----------|-------------------|
| Gap < 0.15, Test R² > 0.25 | Use `best_overall` |
| Gap 0.15-0.20, Test R² > 0.20 | Use `robust_choice` |
| Gap 0.20-0.30, any Test R² | Use `least_overfitting` |
| All gaps > 0.30 | Abandon XGBoost, try simpler model |
| Test R² < 0.15 consistently | Check data quality, features |

## Example Good Result

```
Best Parameter Set:
  nrounds: 30
  max_depth: 2
  eta: 0.05
  gamma: 2
  lambda: 10
  alpha: 2
  subsample: 0.7
  colsample_bytree: 0.6
  min_child_weight: 10

Performance:
  Train R²: 0.45 ✓
  Test R²: 0.28 ✓
  Gap: 0.17 ✓
  Test R² SD: 0.08 ✓
```

This shows:
- Modest train R² (not memorizing)
- Decent test R² (has predictive power)
- Acceptable gap (reasonable generalization)
- Low variability (stable predictions)

## Example Bad Result

```
Best Parameter Set:
  nrounds: 50
  max_depth: 3
  eta: 0.1
  gamma: 0
  lambda: 1
  alpha: 0
  ...

Performance:
  Train R²: 0.95 ✗
  Test R²: 0.15 ✗
  Gap: 0.80 ✗
  Test R² SD: 0.15 ✗
```

This shows:
- Very high train R² (memorizing)
- Low test R² (no generalization)
- Huge gap (severe overfitting)
- High variability (unstable)

## Next Steps After Finding Good Parameters

1. **Copy the parameters** to your final model script
2. **Run with 50 splits** to get robust uncertainty estimates
3. **Monitor train-test gap** in final model (should match tuning)
4. **Calculate SHAP values** for interpretation
5. **Report both train and test performance** in papers/presentations

## Contact for Help

If after running this script:
- All parameters show gap > 0.30
- Test R² consistently < 0.10
- Results don't make sense

Then you may need to:
- Reduce number of features (feature selection)
- Use linear models instead (Ridge, Elastic Net)
- Collect more data
- Revisit feature engineering
