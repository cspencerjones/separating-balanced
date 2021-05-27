def flt_process(timestep,indir):
    flt_to_zarr(timestep,indir)
    flt_reshape(timestep,indir)
    flt_rechunk(timestep,indir)
    delete_garbage(timestep,indir)
    
def delete_garbage(timestep,indir):
    import xarray as xr
    imoort os
    target = indir + '/process_' + str(timestep) + '/rechunked_' + str(timestep) + '.zarr'
    test_open = xr.open_zarr(target)
    if (test_open.niter.size==74):
        fnames = glob(f'{indir}/*_'+ str(timestep)+ '/*.csv')
        os.remove(fnames)
        fnames2 = indir + '/process_' + str(timestep) + '/run_' + str(timestep) + '.zarr'
        os.remove(fnames2)
        fnames2 = indir + '/process_' + str(timestep) + '/reshaped_' + str(timestep) + '.zarr'
        os.remove(fnames2)
        fnames2 = indir + '/process_' + str(timestep) + '/intermediate_' + str(timestep) + '.zarr'
        os.remove(fnames2)
    
def flt_to_zarr(timestep,indir):
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
    ddir = indir + '/fwd_'+ str(timestep)
    fnames = sorted(glob(f'{ddir}/*.csv'))
    fnames[:4]
    assert(len(fnames)/144==37)

    ddir_back = indir + '/back_'+ str(timestep)
    fnames_back = sorted(glob(f'{ddir_back}/*.csv'))
    fnames_back[:4]
    assert(len(fnames_back)/144==37)

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

    target = indir + '/process_' + str(timestep) + '/run_' + str(timestep) + '.zarr'
    niter_fb = np.concatenate([-niter_unique[:0:-1], niter_unique])

    #read each timestep and write to zarr 
    for n in tqdm(niter_fb):
        if n<0:
            ds = timestep_to_ds_lazy(ddir_back, n, 1)
        else:
            ds = timestep_to_ds_lazy(ddir, n, 1)
        ds.chunk().to_zarr(target, append_dim='niter')

def flt_rechunk(timestep,indir):
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
    source = zarr.open(indir + '/process_' + str(timestep) + '/reshaped_' + str(timestep) + '.zarr')
    intermediate = indir + '/process_' + str(timestep) + '/intermediate'+ str(timestep) + '.zarr'
    target = indir + '/process_' + str(timestep) + '/rechunked_' + str(timestep) + '.zarr'

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

def flt_reshape(timestep,indir):
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
    ddir = indir + '/fwd_'+ str(timestep)
    fnames = sorted(glob(f'{ddir}/*.csv'))
    fnames[:4]

    ddir_back = indir +'/back_'+ str(timestep)
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
        df = dpd.read_csv(fnames,header=0)
    
        # load it all into memory
        df = df[['npart','time','x','y','z']].compute()
        df = df.drop('time', axis=1)
    
        # much faster than dask for small dataframes
        df = df.set_index(['x', 'y','z'])
        df = df.rename_axis(index={'x': 'x0','y':'y0','z':'z0'})
        return df[['npart']]

    indexit = make_index(ddir, num_particles)

    indexit = indexit.sort_values(by=['npart'])

    dsx=xr.open_zarr(indir + '/process_' + str(timestep) + '/run_' + str(timestep) + '.zarr')

    ds_reshape =dsx.assign(npart=indexit.index).unstack('npart')

    niter_fb = np.concatenate([-niter_uniqueb[:0:-1], niter_unique])

    target = indir + '/process_' + str(timestep) + '/reshaped_' + str(timestep) + '.zarr'
    for n in tqdm(niter_fb):
        ds_reshape.sel(niter=[n]).to_zarr(target, append_dim='niter')
