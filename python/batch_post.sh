#!/bin/sh
#
# Simple "Hello World" submit script for Slurm.
#
# Replace <ACCOUNT> with your account name before submitting.
#SBATCH --account=ocp
#SBATCH -J python-job
#SBATCH --time=6:00:00
#SBATCH --exclusive

# Setup Environment
module load anaconda
source activate test_scipy

export XDG_RUNTIME_DIR=""

TIMESTEP="19008"

sed -i "1s/.*timestep.*=.*/timestep=${TIMESTEP}/" out_of_core_float_to_zarr.py

python out_of_core_float_to_zarr.py

sed -i "1s/.*timestep.*=.*/timestep=${TIMESTEP}/" out_of_core_reshape.py

python out_of_core_reshape.py

sed -i "1s/.*timestep.*=.*/timestep=${TIMESTEP}/" out_of_core_rechunk.py

rm -rf ../intermediate.zarr

python out_of_core_rechunk.py

# End of script
