timestep = 6048
num_particles = 4665600*4

#Set up dask cluster

from dask.distributed import Client, LocalCluster
if __name__ == '__main__':
    cluster = LocalCluster(n_workers=1, threads_per_worker=24)
    client = Client(cluster)
    main(client)

# Import packages
from glob import glob
import re
import shutil

import numpy as np
import pandas as pd
import dask.dataframe as dpd
import dask
import zarr
import xarray as xr
from tqdm import tqdm

#define files for loading
ddir = '/rigel/ocp/users/csj2114/swot/agulhas/36hrs_multi/fwd_'+ str(timestep)
fnames = sorted(glob(f'{ddir}/*.csv'))
fnames[:4]

ddir_back = '/rigel/ocp/users/csj2114/swot/agulhas/36hrs_multi/back_'+ str(timestep)
fnames_back = sorted(glob(f'{ddir_back}/*.csv'))
fnames_back[:4]

#define time iterations
pattern = '.*\.(\d{10})\.(\d{3})\.(\d{3})\.csv'
r = re.compile(pattern)
file_data = np.array(
    [(int(m.group(1)), int(m.group(2)), int(m.group(3)))
     for m in map(r.match, fnames)]
)
niters, ntile_x, ntile_y = file_data.transpose()
niter_unique = np.unique(niters)
len(niter_unique)

pattern = '.*\.(\d{10})\.(\d{3})\.(\d{3})\.csv'
r = re.compile(pattern)
file_data_back = np.array(
    [(int(m.group(1)), int(m.group(2)), int(m.group(3)))
     for m in map(r.match, fnames_back)]
)
niters_b, ntile_xb, ntile_yb = file_data_back.transpose()
niter_uniqueb = np.unique(niters_b)
len(niter_uniqueb)


def make_index(ddir, num_particles):
    fnames = sorted(glob(f'{ddir}/float_trajectories.0000000000.*.csv'))
    df = dpd.read_csv(fnames)
    
    # load it all into memory
    df = df.compute()
    df = df.drop('time', axis=1)
    
    # much faster than dask for small dataframes
    df = df.set_index(['x', 'y','z'])
    df = df.rename_axis(index={'x': 'x0','y':'y0','z':'z0'})
    return df[['npart']]

indexit = make_index(ddir, num_particles)

indexit = indexit.sort_values(by=['npart'])

dsx=xr.open_zarr('/rigel/ocp/users/csj2114/swot/agulhas/run_' + str(timestep) + '.zarr')

ds_reshape =dsx.assign(npart=indexit.index).unstack('npart')

niter_fb = np.concatenate([-niter_uniqueb[:0:-1], niter_unique])

target = '/rigel/ocp/users/csj2114/swot/agulhas/reshaped_' + str(timestep) + '.zarr'
for n in tqdm(niter_fb):
    ds_reshape.sel(niter=[n]).to_zarr(target, append_dim='niter')
