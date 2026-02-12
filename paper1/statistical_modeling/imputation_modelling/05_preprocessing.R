# DATA PRE-PROCESSING
# Multicolinearity can cause a significant issue when it comes to modelling your
# data. The predictive models that you are designing are being overfit, and any
# reduntant variables should be removed to make an accurate prediction.


# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(car)
library(corrplot)
library(lme4)
library(lmerTest)
library(effectsize)

# Load Data and Filter Out Irrelevant Variables ---------------------------
exergame <- readRDS("results/imputed_complete_data.RDS")

exergame_filt <- exergame %>%
  select(-(race:education)) %>% # our sample was fairly homogenous
  select(-adhd_med_type) %>% # stimulant variable already covers this information
  select(-asset_inattentive,-asset_hyperactive) %>% # not relevant to model
  select(-contains("gamma")) %>% # gamma cannot be reliably measured through scalp EEG
  select(-contains("peakamp")) %>% # mean amplitude is more reliable for ERP
  select(-contains("peaklat")) # less reliable than fractional area and onset latency for ERP

# Split into data domains -------------------------------------------------

demographic <- exergame_filt %>%
  select(asrs_18_total,(stimulant:time))

executiveFunction <- exergame_filt %>%
  select(asrs_18_total,(gonogo_errorrate:digit_bMS))

erp <- exergame_filt %>%
  select(asrs_18_total,(Fz_N2_FracAreaLat_nogo_go_related:Pz_P3b_OnsetLat_congruent_control))

balance <- exergame_filt %>%
  select(asrs_18_total,(shoulder_rdist_trial1:tandem_mvelo_trial3)) %>%
  # shoulder mean velocity had high multicolinearity
  select(-shoulder_mvelo_trial1,-shoulder_mvelo_trial2,-shoulder_mvelo_trial3)

specparam <- exergame_filt %>%
  select(asrs_18_total,(ic_in_cluster3:cluster13_tandem_3_high_beta)) %>%
  select(-contains("theta")) %>% # didn't really see peak
  select(-contains("beta")) %>% # account for harmonic/fake beta
  select(-(ic_in_cluster3:ic_in_cluster13)) %>%
  select(-contains("_2_")) %>% # remove stances trial 2
  select(-contains("_3_")) %>% # remove stances trial 3
  select(asrs_18_total,contains("cluster3") | contains("cluster11")) #contain at least 85% of participants

fc <- exergame_filt %>%
  select(asrs_18_total,(DMN_digitbackward_theta:DMN_DAN_wcst_high_beta)) %>%
  select(-contains("DMN_DAN_")) %>%
  select(-contains("_2_")) %>% # 30s of data is not enough for FC calculations
  select(-contains("_3_")) %>% # 30s of data is not enough for FC calculations
  select(asrs_18_total,contains("alpha"))

# DEMOGRPAHIC --------------------------------------------
demographic_model <- lm(asrs_18_total ~ ., data = demographic)
demographic_vif <- vif(demographic_model)
print(sort(demographic_vif, decreasing = TRUE))

# Overall, variables look good to go. BDI has a bit of a higher colinearity, 
# but it's worth keeping.

# EXECUTIVE FUNCTION ------------------------------------------
# We would expect colinearity to only exist within each task, so we need to split 
# the EF dataset into its respective tasks

#### Create Task EF Data ####
gonogo <- executiveFunction %>%
  select(asrs_18_total,contains("gonogo")) %>%
  select(-(gonogo_errorrate:gonogo_error_horizontalcue)) %>% #keeps unique error rates
  select(-gonogo_meanrt) # value is dependent upon meant rt with vertical/horizontal cues

# For WCST, we mainly care about participants persisting to make errors,
# not general errors (percent_errors) or a metric that includes them ambiguously 
# getting something right through persistence (percent_p_responses)
# Miles et al. (2021) describes how percent_p_errors represents both metrics
wcst <- executiveFunction %>%
  select(asrs_18_total,contains("wcst")) %>%
  select(-wcst_percent_p_responses,-wcst_percent_errors)

digitspan <- executiveFunction %>%
  select(asrs_18_total,contains("digit")) %>%
  # keep traditional measures of digitspan given high colinearity
  select(asrs_18_total,digit_fTE_ML,digit_bTE_ML)

stroop <- executiveFunction %>%
  select(asrs_18_total,contains("stroop")) %>%
  # we already have proportions and RT segmented
  select(-stroop_propcorrect,-stroop_meanRT)

#### Model for Each Task ####

##### Go/NoGo #####
gonogo_matrix <- cor(gonogo %>% select(-asrs_18_total))
corrplot(gonogo_matrix, method = "color", type = "upper")
gonogo_model <- lm(asrs_18_total ~ ., data = gonogo)
gonogo_vif <- vif(gonogo_model)
print(sort(gonogo_vif, decreasing = TRUE))

##### WCST #####
wcst_matrix <- cor(wcst %>% select(-asrs_18_total))
corrplot(wcst_matrix, method = "color", type = "upper")
wcst_model <- lm(asrs_18_total ~ ., data = wcst)
wcst_vif <- vif(wcst_model)
print(sort(wcst_vif, decreasing = TRUE))

##### Digit Span #####
digit_matrix <- cor(digitspan %>% select(-asrs_18_total))
corrplot(digit_matrix, method = "color", type = "upper")
digit_model <- lm(asrs_18_total ~ ., data = digitspan)
digit_vif <- vif(digit_model)
print(sort(digit_vif, decreasing = TRUE))

##### Stroop #####
stroop_matrix <- cor(stroop %>% select(-asrs_18_total))
corrplot(stroop_matrix, method = "color", type = "upper")
stroop_model <- lm(asrs_18_total ~ ., data = stroop)
stroop_vif <- vif(stroop_model)
print(sort(stroop_vif, decreasing = TRUE))


# ERP ------------------------------------------------------
# Overall, looks like very little colinearity!
erp_matrix <- cor(erp %>% select(-asrs_18_total))
corrplot(erp_matrix, method = "color", type = "upper")
erp_model <- lm(asrs_18_total ~ ., data = erp)
erp_vif <- vif(erp_model)
print(sort(erp_vif, decreasing = TRUE))


# BALANCE -----------------------------------------------------------------
# shoulder_mvelo's values fall right between tandem_rdist and shoulder_rdist,
# thus having high multicolinearity and causing issues

#### Now Assess Multicolinearity ####
balance_matrix <- cor(balance %>% select(-asrs_18_total))
corrplot(balance_matrix, method = "color", type = "upper")
balance_model <- lm(asrs_18_total ~ ., data = balance)
balance_vif <- vif(balance_model)
print(sort(balance_vif, decreasing = TRUE))


# SPECPARAM ---------------------------------------------------------------
# shoulder width alpha has a lot of multicolinearity, it's pretty much like
# baseline, but standing
specparam_matrix <- cor(specparam %>% select(-asrs_18_total))
corrplot(specparam_matrix, method = "color", type = "upper")
specparam_model <- lm(asrs_18_total ~ ., data = specparam)
specparam_vif <- vif(specparam_model)
print(sort(specparam_vif, decreasing = TRUE))
print(sort(specparam_vif, decreasing = TRUE))
na_predictors <- names(coef(specparam_model)[is.na(coef(specparam_model))])
print(na_predictors)


# FUNCTIONAL CONNECTIVITY -------------------------------------------------
fc_matrix <- cor(fc %>% select(-asrs_18_total))
corrplot(fc_matrix, method = "color", type = "upper")
fc_model <- lm(asrs_18_total ~ ., data = fc)
fc_vif <- vif(fc_model)
print(sort(fc_vif, decreasing = TRUE))

# CREATE DATAFRAME FOR MODEL ----------------------------------------------

exergame_final <- exergame %>%
  select(-(race:education)) %>% # our sample was fairly homogenous
  select(-adhd_med_type) %>% # stimulant variable already covers this information
  select(-asset_inattentive,-asset_hyperactive) %>% # not relevant to model
  select(-contains("gamma")) %>% # gamma cannot be reliably measured through scalp EEG
  select(-contains("peakamp")) %>% # mean amplitude is more reliable for ERP
  select(-contains("peaklat")) %>% # less reliable than fractional area and onset latency for ERP
  # GO/NO-GO
  select(-(gonogo_errorrate:gonogo_error_horizontalcue)) %>% #keeps unique error rates
  select(-gonogo_meanrt) %>% # value is dependent upon meant rt with vertical/horizontal cues
  # WCST
  select(-wcst_percent_p_responses,-wcst_percent_errors) %>%
  # STROOP
  select(-stroop_propcorrect,-stroop_meanRT) %>%
  # DIGIT SPAN
  select(-(digit_fTE_TT:digit_fMS),-(digit_bTE_TT:digit_bMS)) %>%
  # BALANCE
  select(-shoulder_mvelo_trial1,-shoulder_mvelo_trial2,-shoulder_mvelo_trial3) %>%
  # SPECPARAM/FC
  select(-contains("theta")) %>% # didn't really see peak
  select(-contains("beta")) %>% # account for harmonic/fake beta
  select(-(ic_in_cluster3:ic_in_cluster13)) %>% # remove cluster identification
  select(-contains("_2_")) %>% # remove stances trial 2 
  select(-contains("_3_")) %>% # remove stances trial 3
  # REMOVE CLUSTERS WITH LESS THAN 85% OF PARTICIPANTS
  select(-contains("cluster5")) %>%
  select(-contains("cluster9")) %>%
  select(-contains("cluster10")) %>%
  select(-contains("cluster12")) %>%
  select(-contains("cluster13")) %>%
  # REMOVE DMN-DAN INTERCONNECTIVITY
  select(-contains("DMN_DAN_"))


# Export Final Dataframe for Modeling -------------------------------------

# RDS File
saveRDS(exergame_final, file = "results/exergame_forModel.rds")  
# CSV file
write.csv(exergame_final, file = "results/exergame_forModel.csv", row.names = FALSE)



