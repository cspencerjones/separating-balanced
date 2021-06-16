def auto_filter(indir,window_width):
    #set up dask cluster
    from dask.distributed import Client, LocalCluster
    if __name__ == '__main__':
        cluster = LocalCluster(n_workers=1, threads_per_worker=24)
        client = Client(cluster)
        main(client)

    # import packages
    import xarray as xr
    from glob import glob
    import numpy as np


    #find f
    YC =np.fromfile(f'{indir}/fwd_6048/YC.data', dtype='>f4')
    f = 2*2*np.pi/24/3600*np.sin(YC.reshape(2160,2160)[:,0]*np.pi/180)

    fnames = sorted(glob(f'{indir}/process_*/rechunked_*.zarr'))

    def lanczos(x, a):
        return np.sinc(x/a)
    def sinc2(x, a):
        return np.sinc(x/a)

    weight = xr.DataArray(sinc2(np.expand_dims(np.arange(-window_width/2,window_width/2),1),np.expand_dims(np.pi/f/3600,0)), dims=['window','y0'])


    target_unf = indir + 'unfiltered_vels.zarr'
    target_filt = indir + 'filtered_vels.zarr'

    nofiles = len(fnames)
    for fileno in range(0,nofiles):#
        iterno = 6048+144*fileno
        print('/burg/abernathey/users/csj2114/agulhas-offline/time_1/process_'+ str(iterno) + '/rechunked_' 
              + str(iterno) + '.zarr')
        ds = xr.open_zarr('/burg/abernathey/users/csj2114/agulhas-offline/time_1/process_'+ str(iterno) + '/rechunked_' 
              + str(iterno) + '.zarr')
        ds = ds.isel(niter=slice(1,74))
        ds['time'] = ds['niter']*3600/144
        ds = ds.assign_coords({"time": ds.time})
        ds = ds.swap_dims({"niter": "time"})
        ds = ds.where((ds.u!=-999).all(dim='time'))
        weight = xr.DataArray(sinc2(np.expand_dims(np.arange(-window_width/2,window_width/2),1),np.expand_dims(np.pi/f/3600,0)), dims=['window','y0'])
        windowed_u = ds.u.rolling(time=window_width, center=True).construct('window').dot(weight,dims='window')/weight.sum('window')
        windowed_v = ds.v.rolling(time=window_width, center=True).construct('window').dot(weight,dims='window')/weight.sum('window')
        u_piece = windowed_u.sel(time=0).isel(z0=3)
        v_piece = windowed_v.sel(time=0).isel(z0=3)
        u_piece2 = ds.u.sel(time=0).isel(z0=3)
        v_piece2 = ds.v.sel(time=0).isel(z0=3)
        u_piece["time"] = fileno*3600
        v_piece["time"] = fileno*3600
        u_piece2["time"] = fileno*3600
        v_piece2["time"] = fileno*3600
        unfiltered_vels = u_piece2.to_dataset(name='u')
        unfiltered_vels['v'] = v_piece2
        unfiltered_vels.time.attrs['units']='time in seconds'
        unfiltered_vels.u.attrs['units']='m/s'
        unfiltered_vels.v.attrs['units']='m/s'
        unfiltered_vels.y0.attrs['long_name']='latitude'
        unfiltered_vels.x0.attrs['units']='longitude'
        unfiltered_vels = unfiltered_vels.rename_dims({"x0":"i"})
        unfiltered_vels = unfiltered_vels.rename_dims({"y0":"j"})
        unfiltered_vels.expand_dims('time').chunk().to_zarr(target_unf, append_dim='time')
        filtered_vels = u_piece.to_dataset(name='u')
        filtered_vels['v'] = v_piece
        filtered_vels.time.attrs['units']='time in seconds'
        filtered_vels.u.attrs['units']='m/s'
        filtered_vels.v.attrs['units']='m/s'
        filtered_vels.y0.attrs['long_name']='latitude'
        filtered_vels.x0.attrs['units']='longitude'
        filtered_vels = filtered_vels.rename_dims({"x0":"i"})
        filtered_vels = filtered_vels.rename_dims({"y0":"j"})
        filtered_vels.expand_dims('time').chunk().to_zarr(target_filt, append_dim='time')



    target_unf = indir + 'unfiltered_eta_nom.zarr'
    target_filt = indir + 'filtered_eta_nom.zarr'
    nofiles = len(fnames)
    for fileno in range(0,nofiles):#nofiles
        iterno = 6048+144*fileno
        print('/burg/abernathey/users/csj2114/agulhas-offline/time_1/process_'+ str(iterno) + '/rechunked_' 
              + str(iterno) + '.zarr')
        ds = xr.open_zarr('/burg/abernathey/users/csj2114/agulhas-offline/time_1/process_'+ str(iterno) + '/rechunked_' 
              + str(iterno) + '.zarr')
        ds = ds.isel(niter=slice(1,74))
        ds['time'] = ds['niter']*3600/144
        ds = ds.assign_coords({"time": ds.time})
        ds = ds.swap_dims({"niter": "time"})
        ds = ds.where((ds.u!=-999).all(dim='time'))
        mask_roundx = abs(ds.x.diff('time')).max('time')
        mask_roundy = abs(ds.y.diff('time')).max('time')
        ds = ds.where(mask_roundx<30)
        ds = ds.where(mask_roundy<30)
        weight = xr.DataArray(sinc2(np.expand_dims(np.arange(-window_width/2,window_width/2),1),np.expand_dims(np.pi/f/3600,0)), dims=['window','y0'])
        windowed_eta = ds.eta.rolling(time=window_width, center=True).construct('window').dot(weight,dims='window')/weight.sum('window')
        eta_piece = windowed_eta.sel(time=0).isel(z0=3)
        eta_piece2 = ds.eta.sel(time=0).isel(z0=3)
        eta_piece["time"] = fileno*3600
        eta_piece2["time"] = fileno*3600
        unfiltered_eta = eta_piece2.to_dataset(name='eta')
        unfiltered_eta.time.attrs['units']='time in seconds'
        unfiltered_eta.y0.attrs['long_name']='latitude'
        unfiltered_eta.x0.attrs['units']='longitude'
        unfiltered_eta = unfiltered_eta.rename_dims({"x0":"i"})
        unfiltered_eta = unfiltered_eta.rename_dims({"y0":"j"})
        unfiltered_eta.expand_dims('time').chunk().to_zarr(target_unf, append_dim='time')
        filtered_eta = eta_piece.to_dataset(name='eta')
        filtered_eta.time.attrs['units']='time in seconds'
        filtered_eta.y0.attrs['long_name']='latitude'
        filtered_eta.x0.attrs['units']='longitude'
        filtered_eta = filtered_eta.rename_dims({"x0":"i"})
        filtered_eta = filtered_eta.rename_dims({"y0":"j"})
        filtered_eta.expand_dims('time').chunk().to_zarr(target_filt, append_dim='time')
