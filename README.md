# vpeers-score
Viral Pneumonia ECMO-Eligible Risk Score 

## Abstract
Respiratory complications due to coronavirus 
have claimed tens of thousands of lives in 2020.
Extracorporeal membranous oxygenation (ECMO) is 
a life-sustaining oxygenation and ventilation therapy 
that may be used 
when mechanical ventilation is insufficient to sustain life. 
While early planning and surgical cannulation for ECMO 
can increase survival,
clinicians report the lack of a risk score 
hinders these efforts.
In this paper, we leverage machine learning techniques
to develop a 
score to 
highlight critically ill patients 
with viral or unspecified pneumonia 
at high risk of mortality or decompensation 
in a subpopulation eligible for ECMO.
Finally, we offer both quantitative and qualitative analysis of our score's performance across two critical care datasets.

## Data extraction
- Use the scripts in `src/data_processing` for data extraction.
- place the extracted data in path `"../data/final_split"` or change the `DATA_DIR` variable in `preprocess.py` to make sure that the data can be read by the scripts.

## Model and Results
- use the scripts in `src/paper_code`
- `pipeline.py`: contains code for grid search of penalizer level. To run the grid search do:
    
        bash run.sh
    
- `show_grid_plots.ipynb`: creates figures for showing the grid search results.
- `model_results.ipynb`: runs our model with best hyperparameter level selected from grid search and produces the results in our paper. It also includes code that calls the `comparison_risk_scores.R` to compare our risk score with the baseline risk scores listed in our paper.

