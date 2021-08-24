# Implementation of forcing experiments for SCM-MCM comparison in WRF

Fortran modules and run time files required to run the experiments for comparing the behaviour of single-column model (SCM) vs. multi-column model (MCM) in WRF (v4.0.2). The behaviour of the SCMs and MCMs are assessed by comparing their responses to two types of forcings:
* small tendency perturbations (following the linear response function [LRF] framework of Kuang, 2010)
* doubling of CO<sub>2</sub> in the atmosphere

## 1. Temperature and moisture tendency perturbations
* Based on the LRF framework, referred to here as the ```PerturbLRF``` simulations
* Perturbations to temperature ```(dT/dt)``` and moisture tendencies ```(dq/dt)``` take the form of the sum of a delta and Gaussian functions as per ```Equation 4``` in Herman and Kuang (2010)
* The perturbations (i.e. forcing) are enabled by setting ```force_lrf_flag = .true.``` in the namelist
* To perturb ```dT/dt```, set the flag ```perturb_t_flag = .true.``` in the namelist, and the amplitude of the perturbation can be set using the namelist option ```TtendAmp```
* To perturb ```dq/dt```, set the flat ```perturb_q_flag = .true.``` in the namelist, and the amplitude of the perturbation can be set using the namelist option ```QtendAmp```
* To set the model level to apply the perturbation, use the ```j_pert``` option in the namelist
* Modules involved:
  * [module_first_rk_step_part1.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_force_lrf.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_force_lrf.F)

## 2. Fixed radiative cooling profile
* Fixed radiative cooling profile of -1.5 K/d from the surface to near 200 hPa and decreases linearly to zero near 100 hPa (see ```Figure 1``` in HK13)
* Fixed radiative cooling profile is enabled by setting ```ideal_fix_rad_flag = .true.``` in the namelist
* When fixed radiative cooling profile is enabled, call to interactive radiation driver is skipped and radiative cooling profile is prescribed by calling a separate module (```module_ideal_radiation.F```)
* Modules involved (ideal fixed radiative cooling profile):
  * [module_first_rk_step_part1.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_ideal_radiation.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_ideal_radiation.F)
* *Note:* When fixed radiative cooling profile is disabled (```ideal_fix_rad_flag = .false.```), the interactive radiation driver is called and radiation is set
for an RCE simulation. Under this setting, the RRTMG schemes for both LW and SW radiation are used. The diurnal and seasonal cycles are removed. The coriolis force is set to ```f = 0```.
A fixed cosine of the solar zenith angle of 0.8 and a solar constant of 544 W/m^2 are used. 
* Modules involved (interactive radiation for RCE simulation):
  * [module_radiation_driver.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/phys/module_radiation_driver.F)
  * [module_ra_rrtmg_sw.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/phys/module_ra_rrtmg_sw.F)
 
## 3. Ideal surface fluxes  
* Surface sensible and latent heat fluxes are computed using a bulk aerodynamic formula with constant exchange coefficient (0.001) and a constant surface wind speed (4.8 m/s)
* Ideal surface fluxes are enabled by setting ```ideal_evap_flag = .true.``` in the namelist
* Modules involved:
  * [module_surface_driver.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/phys/module_surface_driver.F)
  * [module_sf_sfclayrev.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/phys/module_sf_sfclayrev.F)
  
## 4. Wind nudging
* Zonal and meridional winds are nudged to ```U = V = 0 m/s``` with a relaxation timescale of 3 hrs
* Wind nudging is enabled by setting ```relax_uv_flag = .true.``` in the namelist
* The windspeed to nudged to for U and V can be set using the ```u_target``` and ```v_target``` options in the namelist
* The relaxation timescale can also be set using the ```tau_relax_winds``` option in the namelist
* Modules involved:
  * [module_first_rk_step_part1.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_relax_winds.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_relax_winds.F)

## 5. Wind shear
* Apply vertical wind shear following the profile in Tompkins (2001)
* Wind shear option is enabled by setting ```relax_u_shear_flag = .true.``` and ```relax_v_shear_flag = .true.``` in the namelist
* The relaxation timescale can be set using the ```tau_relax_winds_shear``` option in the namelist
* The U wind shear profile is read in from the ```u_shear_profile``` in the run folder
* The V wind is relaxed to 0 (```v_shear_profile```)
* *Note:* When applying wind shear (```relax_u_shear_flag = .true.```), wind nudging must be disabled, i.e. set ```relax_uv_flag = .false.``` in the namelist
* Modules involved:
  * [module_first_rk_step_part1.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_relax_winds_shear.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_relax_winds_shear.F)
* Required files (U and V profile):
  * [u_shear_profile](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/u_shear_profile)
  * [v_shear_profile](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/v_shear_profile)

## 6. Stratospheric relaxation of T in ```PreRCE``` runs
* Relax T above 100  hPa to 200 K in ```PreRCE``` runs
* Enable stratospheric T relaxation by setting ```relax_t_strato_flag = .true.``` in the namelist
* The relaxation timescale is set using the ```tau_relax_t_strato``` option in the namelist
* Modules involved:
  * [module_first_rk_step_part1.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_relax_t_strato.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_relax_t_strato.F)

## 7. Stratospheric relaxation of T and QV in ```CTRL``` and ```PerturbLRF``` runs
* Temperature and moisture are relaxed to the ```PreRCE``` profiles at and above tropopause
* Stratospheric ```T``` and ```qv``` relaxation is enabled by setting ```relax_t_qv_strato_flag = .true.``` in the namelist
* The relaxation timescale increases from zero near a height of 160 hPa to a constant value of 0.5 day^-1 at and above the tropopause (~ 100 hPa) (see ```Figure 1``` in HK13)
* Modules involved:
  * [module_first_rk_step_part1.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_relax_t_qv_strato.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_relax_t_qv_strato.F)

## 8. Free tropospheric QV homogenisation
* Homogenise free tropospheric (above 2 km) water vapor field to the domain mean value at every model level, following Grabowski and Moncrieff (2004)
* QV homogenisation is enabled by setting ```homogenise_qv_flag = .true.``` in the namelist
* The relaxation timescale is set using the ```tau_homogenise_qv``` option in the namelist
* Modules involved:
  * [module_first_rk_step_part1.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_first_rk_step_part1.F)
  * [module_homogenise_qv.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_homogenise_qv.F)
  
## 9. Surface type and sea surface temperature
* Simulation is set over water surface by modifying the landmask and landuse indexs in the initialisation module:```grid%landmask = 0```(water surface) and ```grid%lu_index = 16``` (water landuse)
* For SCM, the landmask and land use indices can also be set in the namelist: ```scm_lu_index = 16``` and ```scm_isltyp = 14```
* For experiments with fixed sea surface temperature (SST), SST is set to 28 degree Celsius by setting ```use_variable_sst_flag = .false.``` and ```sst_ideal = 301.15``` in the namelist
* For experiments with variable SST (hotspot in middle of domain for MCM runs), the variable SST is enabled by setting ```use_variable_sst_flag = .true.``` in the namelist, the SST values will be read in from the ```sst_hotspot_input.txt``` file in the run folder
* Modules involved:
  * [module_initialize_scm_xy.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/dyn_em/module_initialize_scm_xy.F)
* Required file (SST hotspot):
  * [sst_hotspot_input.txt](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/sst_hotspot_input.txt)

## 10. Doubled-CO<sub>2</sub> forcing
* Increase CO<sub>2</sub> amount in the atmosphere by doubling the concentration from 379 to 758 ppm for the ```PerturbCO2``` simulations
* Modules involved:
  * [module_ra_rrtmg_sw.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/phys/module_ra_rrtmg_sw_2xco2.F)
  * [module_ra_rrtmg_lw.F](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/phys/module_ra_rrtmg_lw_2xco2.F)

## 11. Namelists
* Three namelists are required for this experiment and for the SCM and MCM runs, respectively:
  * Namelist for the ```PreRCE``` runs:
    * [namelist.input.scm.rce](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/namelist.input.scm.rce)
    * [namelist.input.mcm.rce](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/namelist.input.mcm.rce)
  * Namelist for the ```CTRL``` runs (restarted from ```PreRCE``` runs):
    * [namelist.input.scm.ctrl](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/namelist.input.scm.ctrl)
    * [namelist.input.mcm.ctrl](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/namelist.input.mcm.ctrl)
  * Namelist for the ```PerturbLRF``` runs (restarted from ```PreRCE``` runs):
    * [namelist.input.scm.perturbation](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/namelist.input.scm.perturbation)
    * [namelist.input.mcm.perturbation](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/namelist.input.mcm.perturbation)
  
## 12. Initial sounding
* The initial sounding of the RCEMIP project (Wing et al., 2018) is used
* Initial profile:
  * [input_sounding](https://github.com/yiling-hwong/scm-mcm/blob/main/runtime/input_sounding)
  
## 13. Registry
* New entries for the Registry are added to:
  * [Registry.EM_COMMON](https://github.com/yiling-hwong/scm-mcm/blob/main/WRFV3/Registry/Registry.EM_COMMON)

  
