# vpeers-score
Viral Pneumonia ECMO-Eligible Risk Score 

# Data extraction
- place the extracted data in path `"../data/final_split"` or change the `DATA_DIR` variable in `preprocess.py` to make sure that the data can be read by the scripts.
# Model and Results
- `pipeline.py`: contains code for grid search of penalizer level. To run the grid search do:
    
        bash bash.sh
    
- `show_grid_plots.ipynb`: creates figures for showing the grid search results.
- `model_results.ipynb`: runs our model with best hyperparameter level selected from grid search and produces the results in our paper. It also includes code that calls the `comparison_risk_scores.R` to compare our risk score with the baseline risk scores listed in our paper.

