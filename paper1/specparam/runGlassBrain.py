from glassBrain import *

csv_files = ['../results/IC_clusters/final_model_clusters/Cls_3_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_4_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_5_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_6_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_7_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_8_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_9_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_10_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_11_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_12_prune_clean.csv',
             '../results/IC_clusters/final_model_clusters/Cls_13_prune_clean.csv']

all_results = batch_process_dipole_files(csv_files,
                                         '../demographicsPsych/data/tidy/exergame_DemoBaselineMH_TOTALS.csv',
                                         output_dir='../results/specparam/Cluster Mapping for Paper 1/')