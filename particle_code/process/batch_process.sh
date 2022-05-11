#!/bin/sh
#
# Simple "Hello World" submit script for Slurm.
#
# Replace <ACCOUNT> with your account name before submitting.
#
#SBATCH --account=abernathey            # The account name for the job.
#SBATCH --job-name=JOB-NAME    # The job name.
#SBATCH -N 1                     # The number of nodes to use
                                 #(note there are 32 cores per node)
#SBATCH --exclusive                                 
#SBATCH --time=04:00:00              # The time the job will take to run.
#SBATCH --dependency=afterok:job1:job2

load anaconda/3-2020.11

./process.sh

# End of script
