for prefix in 'any'
do
 for outcome in 'deceased'
 do
  for day in 2 
   do
    for impute in -1
     do
      for seed in 499 88 95 128 424 77 22 49 356 274
       do
	     echo "seed:$seed, prefix:$prefix, outcome:$outcome, day:$day, impute:$impute"
	     python pipeline.py --seed=$seed --prefix=$prefix --outcome=$outcome --day=$day --impute=$impute
       done 
     done
   done
 done
done
