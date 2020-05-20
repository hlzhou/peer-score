"""Shuffle and split data into train/validation and test sets.

eICU is split into train/test. 
MIMIC is the same except for shuffling and filtering out age >= 18.
"""

import pandas as pd
from sklearn.utils import shuffle


SPLIT_PROP = 0.7

eicu_df = pd.read_csv('../../data/eicu/eicu_cleaned/eicu_anypna_2_days_post_inicu.csv')
mimic_df = pd.read_csv('../../data/mimic/mimic_cleaned/cleaner_mimic_anypna_timeline_flfv_2_days_post_inicu.csv', sep='|')
mimic_df = mimic_df[mimic_df['age'] >= 18]

eicu_df = shuffle(eicu_df)
mimic_df = shuffle(mimic_df)

split_idx = int(len(eicu_df) * SPLIT_PROP)
train_eicu_df = eicu_df[:split_idx]
test_eicu_df = eicu_df[split_idx:]

train_eicu_df.to_csv('../../data/final_splits/eicu_any2_train.csv', index=False)
test_eicu_df.to_csv('../../data/final_splits/eicu_any2_test.csv', index=False)
mimic_df.to_csv('../../data/final_splits/mimic_any2_test.csv', index=False, sep=',')
