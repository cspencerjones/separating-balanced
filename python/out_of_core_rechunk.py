timestep=14688
iters = 74

#Set up dask cluster

from dask.distributed import Client, LocalCluster
if __name__ == '__main__':
    cluster = LocalCluster(n_workers=1, threads_per_worker=24)
    client = Client(cluster)
    main(client)

# Import packages
import dask.dataframe as dd
import xarray as xr
from rechunker import rechunk
import numpy as np
import zarr

#define files for loading
source = zarr.open('/rigel/ocp/users/csj2114/swot/agulhas/reshaped_' + str(timestep) + '.zarr')
intermediate = f'/rigel/ocp/users/csj2114/swot/agulhas/intermediate.zarr'
target = f'/rigel/ocp/users/csj2114/swot/agulhas/rechunked_' + str(timestep) + '.zarr'

r = rechunk(source, target_chunks={'eta':{'niter': iters, 'x0': 180, 'y0': 180,'z0' : 1},
                                   's':{'niter': iters, 'x0': 180, 'y0': 180,'z0' : 1},
                                   't':{'niter': iters, 'x0': 180, 'y0': 180,'z0' : 1},
                                   'u':{'niter': iters, 'x0': 180, 'y0': 180,'z0' : 1},
                                   'v':{'niter': iters, 'x0': 180, 'y0': 180,'z0' : 1},
                                   'x':{'niter': iters, 'x0': 180, 'y0': 180,'z0' : 1},
                                   'y':{'niter': iters, 'x0': 180, 'y0': 180,'z0' : 1},
                                   'z':{'niter': iters, 'x0': 180, 'y0': 180,'z0' : 1},
                                   'niter':None,
                                   'x0':None,
                                   'y0':None,
                                   'z0':None
                                  }, max_mem='1GB',
            target_store=target, temp_store=intermediate, executor='dask')

r.execute()
