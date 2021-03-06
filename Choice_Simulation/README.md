Code for individual mode choice simulation model

These files contains code for implementation for individual choice simulation model. This is a two step implementation - first step optimizing for parameters beta and sigma from trips estimation for 4 modes and second step optimizing for the correlation parameters in the model. The code prints out an output for a sample origin-destination-wage.

- 'choice_simulation_step1.py' contains python code for step 1 of individual choice simulation model. The code performs choice simulation modeling for 4 travel modes - taxi, transit, walking and driving and takes 2 parameters, beta and sigma. 
This code reads data 'trip_data_4modes.csv' from the data folder. 

- 'choice_simulation_step2.py' contains code for step 2 of individual choice simulation model. The code performs choice simulation modeling for all 6 travel modes - taxi, FHV, shared FHV, transit, walking and driving. The parameters beta and sigma remain fixed and the code takes in iterations of correlation parameters 'corTFS' and 'corFS' to find their oprimal values.
This code reads data 'trip_data_6modes.csv' from the data folder.
