To extract MIMIC csvs:
```
1. Create folders ../../data/mimic/mimic3 and ../../data/mimic/anypna
2. Download raw MIMIC-III csvs from Physionet website and put them into ../../data/mimic/mimic3. Also download smoking.tsv and codx.tsv from 
3. Check the paths the in code so that it matches your setup.
2. Run mimic3buildtimeline.R
3. Run mimic_make_flfv.R
4. Run mimic_cleaner.R
5. Run mimic_cleanup.py
```