#!/usr/bin/env python
# coding: utf-8

import numpy as np
import pandas as pd
from scipy.stats import multivariate_normal


# wage groups - per hour

wage = [10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000, 50000,
            60000, 75000, 100000, 125000, 150000, 200000, 250000]
wage = np.array(wage)/(12*30*24)
wage


# simulation model parameters

modelParams = {'beta':0.74, #np.linspace(0.3, 1.5, 20), #rationality adjustment for the cost of time estimate
               'sigma':0.33, #standard deviation for the individual random factor
               'corTFS':list(np.linspace(0.05, 1, 20)), #correlation coefficient between random factors within taxi+FHV+SFHV nest
               'corrFS':list(np.linspace(0.05, 1, 20)), #correlation coefficient between random factors within taxi+FHV+SFHV nest
               }

# simulation function

def modeChoiceSimulation (travelTime, travelCost, wage, modelParams, i, j, travelTime_std, travelCost_std):
    #travelTime, travelCost - 1xM array, where M=6 is the number of modes

    #modelParams - model parameters

    N = travelTime.shape[0]; M = 1
    #compute estimated utility with respect to uncertainty in the travel times and consts, individual wages and rationality of the choices
    U = modelParams['beta']*np.random.normal(loc=travelTime, scale=travelTime_std
                                            )*wage+np.random.normal(loc=travelCost, scale=travelCost_std)
    cov=np.eye(6) #covariance matrix
    cov[1:3, 0] = cov[0, 1:3] = modelParams['corTFS'][i]#correlation between taxi (1) and FHV/SFHV
    cov[1, 2] = cov[2, 1] = modelParams['corrFS'][j] #correlation between FHV and SFHV
    cov *= modelParams['sigma']**2 #convert correlation to covariance matrix

    F = multivariate_normal.rvs(mean=np.ones(6), cov=cov,size=6) #individual preference random correction factors (multiplicative, but can be additive too) to utility of the transportation modes
    
    x = np.array(U+F)
    x[np.isnan(x)] = np.inf
    x[np.isneginf(x)] = np.inf
    
    modeChoice=np.argmin(x,axis=1) #mode choice based on the smallest utility with respect to individual correction factors
    return modeChoice


# data - travel time and price on o-d level for 6 modes

data = pd.read_csv('/Data/trip_data_c2smart_after_fhv_updated.csv')
data.head()


sample = data[(data.pulocationid == 3) & (data.dolocationid == 7)]
sample_duration = sample.sort_values(by='tmode')['duration'].values/60
sample_price = sample.sort_values(by='tmode')['price'].values
sample_wage = sample.sort_values(by='tmode')['w10000'].values

print(modeChoiceSimulation(sample_duration, sample_price, sample_wage, modelParams, 0, 0, 0, 0))






