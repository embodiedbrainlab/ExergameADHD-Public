from glassBrain import *

csv_files = ['E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_3_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_4_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_5_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_6_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_7_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_8_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_9_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_10_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_11_prune.csv',
             'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/IC_clusters/pruned_clusters/Cls_12_prune.csv']

all_results = batch_process_dipole_files(csv_files,
                                         '../demographicsPsych/data/intervention_assignments.xlsx',
                                         'E:/Tasnim_Dissertation_Analysis/specparam_analysis/Paper 2/sedentary/clusterMapping/')