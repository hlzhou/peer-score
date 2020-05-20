The code in this folder is used to create csv files with fixed-length feature vectors for patient stays in [eICU](https://eicu-crd.mit.edu/) and [MIMIC-III](https://mimic.physionet.org/).

To extract eICU csvs:
```
1. Set up eICU database according to [eICU setup instructions](https://github.com/MIT-LCP/eicu-code/tree/master/build-db/postgres)
2. cd into src/data_processing/mimic
3. Run the sql script: psql -d eicu -a -f eicu_extraction.sql
4. Run the python script: python tables.py
```

To extract MIMIC csvs:
```
1. Create folders ../../data/mimic/mimic3 and ../../data/mimic/anypna and ../../data/mimic/mimic_cleaned
2. Download raw MIMIC-III csvs from Physionet website and put them into ../../data/mimic/mimic3. Also download smoking.tsv and codx.tsv from 
3. For all of the following scripts, check the paths the in code so that it is compatible with your setup.
4. cd into src/data_processing/mimic
5. Run mimic3buildtimeline.R
6. Run mimic_make_flfv.R
7. Run mimic_cleaner.R
8. Run mimic_cleanup.py
```

Once you have completed the above steps, you should be able to run the notebook model_results.ipynb.
