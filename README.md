# separating-balanced

This is the code repository for Jones, C. S., Xiao, Q. , Abernathey, R. P. , Smith, K. S. Separating balanced and unbalanced flow at the surface of the Agulhas region using Lagrangian filtering (in prep). 

Plotting scripts are in the folder `python/plotting_scripts`. 

Code for running particles offline in the MITgcm and for Lagrangian filtering is given in the `particle_code` directory. 
`particle_code/time_2weeks/make_dir` and `particle_code/time_75days/make_dir` automatically set up the directory structure and submit jobs to run particles forwads and backwards in time. 
The files in `particle_code/process` are used for processing particle trajectory output. 
If you wish to recreate these runs, you will likely need to modify some of the paths in these files. 
