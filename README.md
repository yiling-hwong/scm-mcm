# Implementation of forcing experiments for SCM-MCM comparison in WRF

## 1. Temperature and moisture perturbations
* Perturbations to temperature ```(dT/dt)``` and moisture tendencies ```(dq/dt)``` take the form of the sum of a delta and Gaussian functions as per ```Equation 4``` in HK13
* The perturbations (i.e. forcing) are enabled by setting ```scm_force = 1``` in the namelist
* To perturb ```dT/dt```, set the flag ```perturb_t = 1``` in the namelist, and the amplitude of the perturbation can be set using the namelist option ```TtendAmp```
* To perturb ```dq/dt```, set the flat ```perturb_q = 1``` in the namelist, and the amplitude of the perturbation can be set using the namelist option ```QtendAmp```
* To set the model level to apply the perturbation, use the ```j_pert``` option in the namelist
* Modules involved:
  * [module_first_rk_step_part1.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_force_scm.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/module_force_scm.F)

## 2. Fixed radiative cooling profile
* Fixed radiative cooling profile of -1.5 K/d from the surface to near 200 hPa and decreases linearly to zero near 100 hPa (see ```Figure 1``` in HK13)
* Fixed radiative cooling profile is enabled by setting ```ideal_fix_rad_flag = 1``` in the namelist
* When fixed radiative cooling profile is enabled, call to interactive radiation driver is skipped and radiative cooling profile is prescribed by calling a separate module (```module_ideal_radiation.F```)
* Modules involved (ideal fixed radiative cooling profile):
  * [module_first_rk_step_part1.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_ideal_radiation.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/module_ideal_radiation.F)
* *Note:* When fixed radiative cooling profile is disabled (```ideal_fix_rad_flag = 0```), the interactive radiation driver is called and radiation is set
for an RCE simulation. Under this setting, the RRTMG schemes for both LW and SW radiation are used. The diurnal and seasonal cycles are removed. The coriolis force is set to ```f = 0```.
A fixed cosine of the solar zenith angle of 0.8 and a solar constant of 544 W/m^2 are used. 
* Modules involved (interactive radiation for RCE simulation):
  * [module_radiation_driver.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/phys/module_radiation_driver.F)
  * [module_ra_rrtmg_sw.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/phys/module_ra_rrtmg_sw.F)

  
## 3. Ideal surface fluxes  
* Surface sensible and latent heat fluxes are computed using a bulk aerodynamic formula with constant exchange coefficient (0.001) and a constant surface wind speed (4.8 m/s)
* Ideal surface fluxes are enabled by setting ```ideal_evap_flag = 1``` in the namelist
* Modules involved:
  * [module_surface_driver.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/phys/module_surface_driver.F)
  * [module_sf_sfclayrev.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/phys/module_sf_sfclayrev.F)
  * [module_sf_myjsfc.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/phys/module_sf_myjsfc.F) (for the Zhang-McFarlane convection scheme only)
  
## 4. Wind nudging
* Zonal wind profile is nudged to ```U = 4.8 m/s``` and meridional wind profile to ```V = 0 m/s``` with a relaxation timescale of 3 hrs
* Wind nudging is enabled by setting ```relax_uv = 1``` in the namelist
* The windspeed to nudged to for U and V can be set using the ```u_target``` and ```v_target``` options in the namelist
* The relaxation timescale can also be set using the ```tau_relax``` option in the namelist
* Modules involved:
  * [module_first_rk_step_part1.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_relax_winds.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/module_relax_winds.F)

## 5. Stratospheric relaxation of T and qv
* Temperature and moisture are relaxed to the RCE profile of a previous run at and above tropopause
* The relaxation timescale increases from zero near a height of 160 hPa to a constant value of 0.5 day^-1 at and above the tropopause (~ 100 hPa) (see ```Figure 1``` in HK13)
* Stratospheric ```T``` and ```qv``` relaxation is enabled by setting ```relax_t_qv = 1``` in the namelist
* Modules involved:
  * [solve_em.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/solve_em.F)
  * [module_relax_t_qv.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/module_relax_t_qv.F)
  
## 6. Surface type and sea surface temperature
* Simulation is set over water surface by modifying the landmask and landuse indexs in the initialisation module:```grid%landmask = 0```(water surface) and ```grid%lu_index = 16``` (water landuse)
* For SCM, the landmask and land use indices can also be set in the namelist: ```scm_lu_index = 16``` and ```scm_isltyp = 14```
* Sea surface temperature is set to 28 degree Celsius by setting ```sst_ideal = 301.15``` in the namelist
* Modules involved:
  * [module_initialize_scm_xy.F](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/dyn_em/module_initialize_scm_xy.F)
 
## 7. Namelists
* Three namelists are required for this experiment:
  * [namelist.lrf.rce.input](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/runtime/namelist.lrf.rce.input) - namelist for first RCE run
  * [namelist.lrf.restart.ctrl.input](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/runtime/namelist.lrf.restart.ctrl.input) - namelist for CONTROL run from restart file
  * [namelist.lrf.restart.perturbation.input](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/runtime/namelist.lrf.restart.perturbation.input) -  namelist for PERTURBATION run from restart file
  
## 8. Initial sounding
* The initial sounding of the RCEMIP project (Wing et al., 2018) is used
* Initial profile:
  * [input_sounding](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/runtime/input_sounding)
  
## 9. Registry
* New entries for the Registry are added to:
  * [Registry.EM_COMMON](https://github.com/climate-enigma/wrf_lrf_scm/blob/V4.0.2/WRFV3/Registry/Registry.EM_COMMON)

  
