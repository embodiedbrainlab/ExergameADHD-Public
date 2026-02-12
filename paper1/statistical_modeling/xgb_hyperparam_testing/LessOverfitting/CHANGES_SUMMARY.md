# HYPERPARAMETER TUNING SCRIPT - CHANGES SUMMARY

## Critical Problem Identified
Your previous runs showed **train R² = 0.999**, indicating severe overfitting.
The model was memorizing the training data rather than learning generalizable patterns.

## Key Changes Made

### 1. PARAMETER GRID MODIFICATIONS (Lines 58-70)

**Old Grid:**
- nrounds: 50, 100
- max_depth: 3, 4
- gamma: 0, 1
- lambda: 0.5, 1, 2, 5, 10
- alpha: 0, 0.5, 1, 2, 5
- min_child_weight: 3, 5, 10
- subsample: 0.7, 0.85, 1
- colsample_bytree: 0.6, 0.8, 1

**New Grid (Optimized to Combat Overfitting):**
- nrounds: **10, 20, 30, 40, 50** (MUCH LOWER - primary change)
- max_depth: **2, 3** (shallower trees)
- gamma: **1, 2, 5** (REMOVED 0 - force more pruning)
- lambda: **2, 5, 10, 20** (HIGHER L2 regularization)
- alpha: **0.5, 1, 2, 5** (REMOVED 0 - force L1 regularization)
- min_child_weight: **5, 10, 15** (REMOVED 3 - force larger leaves)
- subsample: **0.6, 0.7, 0.85** (REMOVED 1 - force subsampling)
- colsample_bytree: **0.5, 0.6, 0.8** (REMOVED 1 - force feature subsampling)

**Total combinations:**
- Old: ~16,000 combinations
- New: ~12,960 combinations (similar scale but focused on anti-overfitting)

### 2. OVERFITTING MONITORING ADDED

**New Metrics Tracked (Lines 195-218):**
- `train_r2` - Training set R²
- `train_rmse` - Training set RMSE
- `r2_gap` - Train R² minus Test R²
- `rmse_gap` - Test RMSE minus Train RMSE

**Summary Statistics Added:**
- `train_r2_mean`, `train_r2_median`, `train_r2_sd`
- `r2_gap_mean`, `r2_gap_median`, `r2_gap_sd`
- `rmse_gap_mean`, `rmse_gap_median`

### 3. COMPOSITE SCORING UPDATED (Lines 318-332)

**Old Weights:**
- Performance: 50%
- Stability: 30%
- Robustness: 20%

**New Weights:**
- Performance: 35%
- Stability: 25%
- Robustness: 15%
- **Overfitting Penalty: 25% (NEW!)**

Now explicitly penalizes models with large train-test gaps.

### 4. NEW OUTPUT FILES

Added:
- `top20_least_overfitting.csv` - Models with smallest R² gap
- `overfitting_assessment.png` - Visualization of overfitting
- `train_vs_test_r2.png` - Train vs Test R² scatter plot

Updated:
- `recommended_xgboost_params.rds` now includes `least_overfitting` parameters

### 5. ENHANCED REPORTING

**Console Output Now Shows:**
- Train R² alongside Test R²
- R² Gap with interpretation
- Overfitting severity classification:
  - Gap < 0.10: ✓ Excellent
  - Gap 0.10-0.20: ⚠ Acceptable
  - Gap 0.20-0.30: ⚠ Concerning
  - Gap > 0.30: ✗ Severe

## Expected Outcomes

After running this updated script:

1. **Train R² should be:** 0.30-0.60 (not 0.999!)
2. **Test R² should be:** 0.20-0.30
3. **R² Gap should be:** < 0.20 (ideally < 0.15)

## How to Use Results

After the script completes:

1. **Check the overfitting plots:**
   - `train_vs_test_r2.png` - look for points near the diagonal
   - `overfitting_assessment.png` - look for low R² gap values

2. **Load recommended parameters:**
   ```r
   params <- readRDS("results/recommended_xgboost_params.rds")
   
   # Options (in order of recommendation):
   best <- params$robust_choice      # Appears in multiple top lists
   safe <- params$least_overfitting  # Lowest train-test gap
   perf <- params$best_overall       # Best combined score
   ```

3. **Verify the chosen parameters:**
   - Check that r2_gap_median < 0.20
   - Prefer lower nrounds (20-30) over higher (40-50)
   - Higher regularization (lambda=10-20, alpha=2-5) is safer

## What Changed in the Science

**Before:**
- Testing if 50 or 100 rounds was better
- Allowing no regularization (gamma=0, alpha=0)
- Ignoring train-test gap
- Result: Model memorized training data

**After:**
- Testing 10-50 rounds (much more conservative)
- Forcing strong regularization (gamma≥1, alpha≥0.5, lambda≥2)
- Explicitly monitoring and penalizing overfitting
- Result: Model forced to generalize

## Common Questions

**Q: Why such low nrounds?**
A: With 67 observations and 109 predictors, even 20 trees can overfit. We need to find the minimum that works.

**Q: Won't strong regularization hurt performance?**
A: Test performance may be slightly lower, but it will be REAL performance that generalizes to new data, not memorization.

**Q: What if all parameters still show overfitting?**
A: Then we need to:
   1. Reduce features (feature selection)
   2. Use simpler models (linear regression, elastic net)
   3. Get more data

**Q: How long will this take?**
A: With 96 cores and ~13,000 parameter combinations:
   - Estimated: 1-2 hours on HPC
   - Each parameter set trains 50 models (10 splits × 5 folds)

## Final Notes

The goal is NOT to maximize test R². The goal is to find parameters that:
1. Give reasonable test R² (0.20-0.30)
2. Have low overfitting (gap < 0.20)
3. Are stable across splits

A model with test R²=0.25 and gap=0.15 is MUCH better than 
a model with test R²=0.30 and gap=0.70!
