# vpeers-score
**V**iral **P**neumonia **E**CMO-**E**ligible **R**isk **S**core 

## Abstract
Respiratory complications due to coronavirus disease COVID-19
have claimed tens of thousands of lives in 2020. 
Many cases of COVID-19 escalate from Severe Acute Respiratory Syndrome (SARS-CoV-2) to viral pneumonia to acute respiratory distress syndrome (ARDS) to death. Extracorporeal membranous oxygenation (ECMO) is 
a life-sustaining oxygenation and ventilation therapy 
that may be used for patients with severe ARDS
when mechanical ventilation is insufficient to sustain life. 
While early planning and surgical cannulation for ECMO 
can increase survival \citep{combes2018extracorporeal},
clinicians report the lack of a risk score 
hinders these efforts \citep{liang2020handbook,acchub}.
In this work, we leverage machine learning techniques
to develop a score to highlight critically ill patients 
with viral or unspecified pneumonia 
at high risk of mortality or decompensation 
in a subpopulation eligible for ECMO.
Our risk score is validated on two large, 
publicly available critical care databases
and predicts mortality at least as well as other existing risk scores. Stratifying our cohorts into low-risk and high-risk groups, we find that the high-risk group also has a higher proportion of decompensation indicators such as vasopressor and ventilator use. Finally, the risk score is provided in the form of a nomogram 
for direct calculation of patient risk, and can be used to highlight at-risk patients among critical care patients eligible for ECMO.

## Data extraction
- Follow the instructions in the README in `src/data_processing` to extract csv files for the eICU and MIMIC cohorts (stored in `data/final_splits`). These contain viral or unspecified pneumonia patients who are filtered for ECMO-eligibility.

## Model and Results
The `src/` folder contains code for training the model and analyzing results. For the following explanation: `cd src/`

**Grid search:** In order to examine the performance across various penalizer levels:

- run `bash run_grid_search.sh`, which will call `pipeline.py` 
- run `jupyter notebook` and open `show_grid_plots.ipynb`. This creates the figures displaying the grid search results in the appendix of the paper.

**Model evaluation/ analysis:** To analyze and evaluate the chosen model:

- run `jupyter notebook` and open `model_results.ipynb`. This notebook runs our model with best hyperparameter level selected from grid search and produces the results in our paper. It uses `preprocess.py` to standardize and impute the data, and also calls `comparison_risk_scores.R` to compare our risk score with the baseline risk scores listed in our paper.

**Additional information:** Table 1 of the paper is created by `eicu_eda.py`


