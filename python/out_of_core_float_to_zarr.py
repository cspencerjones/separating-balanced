timestep=14688
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

def timestep_to_ds_lazy(ddir, niter, npartitions=1):
    """
    Read CSV files for one timestep and turn into an xarray dataset.
    This function is *lazy* using dask throughout.
    """
    niter_abs = abs(niter)
    fnames = sorted(glob(f'{ddir}/float_trajectories.{niter_abs:010d}.*.csv'))
    print(fnames[0])
    df = dpd.read_csv(fnames)
    
    # don't need time, since all the files have the same time
    df = df.drop('time', axis=1)

    # this is like rechunking
    # it will consolidate all the rows into one in-memory block
    df = df.repartition(npartitions=npartitions)
    
    # the more partitions, the slow this goes
    df = df.set_index('npart')
    
    #dfi = indexit.merge(df,on='npart')
    
    # convert to xarray dataset
    dim = df.index.name
    
    # takes time, needs to read data
    index_data = df.index.compute()
    lengths = len(index_data)

    coords = {dim: ([dim], index_data)}
    data_vars = {v: ([dim], df[v].to_dask_array(lengths=([lengths/npartitions] * npartitions)))
                 for v in df.columns}
    ds = xr.Dataset(data_vars, coords)
    
    # now add time as a dimension
    ds = ds.expand_dims('niter', axis=0)
    ds.coords['niter'] = ('niter', [niter])

    return ds

target = '/rigel/ocp/users/csj2114/swot/agulhas/run_' + str(timestep) + '.zarr'
niter_fb = np.concatenate([-niter_unique[:0:-1], niter_unique])

#read each timestep and write to zarr 
for n in tqdm(niter_fb):
    if n<0:
        ds = timestep_to_ds_lazy(ddir_back, n, 1)
    else:
        ds = timestep_to_ds_lazy(ddir, n, 1)
    ds.chunk().to_zarr(target, append_dim='niter')
