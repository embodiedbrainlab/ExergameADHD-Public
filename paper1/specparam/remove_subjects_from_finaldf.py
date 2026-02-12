# General Imports to work with files
import numpy as np
import pandas as pd
import pickle
import os

# Load the final dataframe created from the previous cleaning script
print("Loading df_final.pkl...")
df_final = pd.read_pickle('../results/specparam/final_model/df_final.pkl')

print(f"Original df_final shape: {df_final.shape}")
print(f"Original number of models: {len(df_final)}")

# Get unique subjects in the dataset
unique_subjects = df_final['subject'].unique()
print(f"\nUnique subjects in dataset: {sorted(unique_subjects)}")
print(f"Total number of unique subjects: {len(unique_subjects)}")

# ============================================================================
# DEFINE SUBJECT-CLUSTER COMBINATIONS TO REMOVE
# ============================================================================
# Define specific subject × cluster combinations to remove
# These combinations highlight and subject/cluster combination that had to be removed because of poor fits to their
# power spectral density plots. Towards the bottom of the list, you'll also find the list of subject IDs associated
# with the two participants who performed go/no-go incorrectly.
# Each tuple should be (subject_id, cluster_number)
subject_cluster_combinations_to_remove = [
    ('exgm016', 3),
    ('exgm079', 3),
    ('exgm107', 3),
    ('exgm108', 3),
    ('exgm111', 3),
    ('exgm132', 3),
    ('exgm152', 3),
    ('exgm154', 3),
    ('exgm171', 3),
    ('exgm047', 4),
    ('exgm105', 4),
    ('exgm121', 4),
    ('exgm132', 4),
    ('exgm146', 4),
    ('exgm154', 4),
    ('exgm160', 4),
    ('exgm188', 4),
    ('exgm023', 5),
    ('exgm047', 5),
    ('exgm057', 5),
    ('exgm097', 5),
    ('exgm132', 5),
    ('exgm144', 5),
    ('exgm152', 5),
    ('exgm169', 5),
    ('exgm018', 6),
    ('exgm043', 6),
    ('exgm082', 6), # this subject already had all of their PSDs flagged for removal
    ('exgm084', 6),
    ('exgm120', 6),
    ('exgm133', 6),
    ('exgm136', 6),
    ('exgm144', 6),
    ('exgm146', 6),
    ('exgm171', 6),
    ('exgm172', 6),
    ('exgm182', 6),
    ('exgm184', 6),
    ('exgm190', 6),
    ('exgm018', 7),
    ('exgm020', 7),
    ('exgm048', 7),
    ('exgm109', 7),
    ('exgm111', 7),
    ('exgm121', 7),
    ('exgm133', 7),
    ('exgm136', 7),
    ('exgm160', 7),
    ('exgm175', 7),
    ('exgm004', 8),
    ('exgm025', 8),
    ('exgm043', 8),
    ('exgm107', 8),
    ('exgm136', 8),
    ('exgm156', 8),
    ('exgm160', 8),
    ('exgm164', 8),
    ('exgm182', 8),
    ('exgm079', 9),
    ('exgm082', 9),
    ('exgm109', 9),
    ('exgm122', 9),
    ('exgm152', 9),
    ('exgm057', 10),
    ('exgm107', 10),
    ('exgm121', 10),
    ('exgm132', 10),
    ('exgm133', 10),
    ('exgm152', 10),
    ('exgm190', 10),
    ('exgm023', 11),
    ('exgm025', 11),
    ('exgm031', 11),
    ('exgm102', 11),
    ('exgm152', 11),
    ('exgm188', 11),
    ('exgm025', 13),
    ('exgm031', 13),
    ('exgm087', 13),
    ('exgm117', 13),
    ('exgm156', 13),
    ('exgm164', 13),
    ('exgm185', 13),
    # GO/NO-GO PARTICIPANTS BELOW
    ('exgm108', 10), ('exgm136', 11), ('exgm136', 12), ('exgm108', 13), ('exgm136', 13), ('exgm108', 3), ('exgm136', 3),
    ('exgm136', 4), ('exgm108', 5), ('exgm136', 5), ('exgm136', 6), ('exgm108', 7), ('exgm136', 7), ('exgm136', 8),
    ('exgm136', 9),
]

print(f"\nSubject-Cluster combinations to remove:")
for subj, clust in subject_cluster_combinations_to_remove:
    print(f"  - Subject: {subj}, Cluster: {clust}")

# ============================================================================
# IDENTIFY ROWS TO REMOVE
# ============================================================================
# Find indices of all rows that match the subject-cluster combinations
indices_to_remove = []
for subject_id, cluster_id in subject_cluster_combinations_to_remove:
    # Find rows where both subject AND cluster match
    matching_indices = df_final[
        (df_final['subject'] == subject_id) & 
        (df_final['cluster'] == cluster_id)
    ].index.tolist()
    indices_to_remove.extend(matching_indices)

# Remove any duplicate indices (shouldn't happen, but just in case)
indices_to_remove = list(set(indices_to_remove))
indices_to_remove.sort()

print(f"\nNumber of models to remove: {len(indices_to_remove)}")

# ============================================================================
# CREATE DOCUMENTATION OF REMOVED DATA
# ============================================================================
if len(indices_to_remove) > 0:
    # Extract information for removed models
    removed_data = df_final.loc[indices_to_remove, ['subject', 'session', 'experience', 'component', 'cluster']].copy()
    
    # Add removal reason for documentation
    removed_data['removal_reason'] = 'subject_cluster_exclusion'
    
    # Reset index to preserve original indices for traceability
    removed_data = removed_data.reset_index().rename(columns={'index': 'original_df_final_index'})
    
    # Create a summary by subject-cluster combination
    removal_summary = removed_data.groupby(['subject', 'cluster']).size().reset_index(name='models_removed')
    
    # Export detailed removal log to CSV
    removed_data.to_csv('../results/specparam/final_model/removed_subject_clusters_log.csv', index=False)
    print(f"\nRemoved data documentation saved to 'removed_subject_clusters_log.csv'")
    
    # Export summary to CSV
    removal_summary.to_csv('../results/specparam/final_model/removed_subject_clusters_summary.csv', index=False)
    print(f"Removal summary saved to 'removed_subject_clusters_summary.csv'")
    
    print(f"\nRemoved data preview:")
    print(removed_data.head(10))
    
    print(f"\nRemoval summary by subject-cluster combination:")
    print(removal_summary)
    
else:
    print("\nNo subject-cluster combinations matched the removal list - no models will be removed.")

# ============================================================================
# REMOVE ROWS FROM DATAFRAME
# ============================================================================
# Remove rows corresponding to excluded subjects
df_final_cleaned = df_final.drop(index=indices_to_remove).reset_index(drop=True)

print(f"\nCleaned dataframe shape: {df_final_cleaned.shape}")
print(f"Removed {df_final.shape[0] - df_final_cleaned.shape[0]} rows from dataframe")
print(f"Models retained: {len(df_final_cleaned)}")

# Verify the subjects were removed
remaining_subjects = df_final_cleaned['subject'].unique()
print(f"\nRemaining unique subjects: {sorted(remaining_subjects)}")
print(f"Total number of remaining subjects: {len(remaining_subjects)}")

# Verify the subject-cluster combinations were removed
print(f"\nVerification: Checking if specified subject-cluster combinations were removed...")
combinations_still_present = []
for subject_id, cluster_id in subject_cluster_combinations_to_remove:
    still_exists = df_final_cleaned[
        (df_final_cleaned['subject'] == subject_id) & 
        (df_final_cleaned['cluster'] == cluster_id)
    ]
    if len(still_exists) > 0:
        combinations_still_present.append((subject_id, cluster_id))

if len(combinations_still_present) > 0:
    print(f"\nWARNING: The following subject-cluster combinations are still present:")
    for subj, clust in combinations_still_present:
        print(f"  - Subject: {subj}, Cluster: {clust}")
else:
    print(f"✓ All specified subject-cluster combinations successfully removed from dataframe.")

# ============================================================================
# SAVE CLEANED DATAFRAME
# ============================================================================
# Save the cleaned final dataframe
df_final_cleaned.to_pickle('../results/specparam/final_model/df_final_cleaned.pkl')
print(f"\nCleaned dataframe saved to 'df_final_cleaned.pkl'")

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================
print(f"\n{'='*60}")
print("FINAL SUMMARY")
print(f"{'='*60}")
print(f"Original df_final models: {len(df_final)}")
print(f"Subject-cluster combinations removed: {len(subject_cluster_combinations_to_remove)}")
print(f"Models removed: {len(indices_to_remove)}")
print(f"Final models retained: {len(df_final_cleaned)}")
print(f"Percentage of data retained: {100 * len(df_final_cleaned) / len(df_final):.2f}%")
print(f"{'='*60}")
