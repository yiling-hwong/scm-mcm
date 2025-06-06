!IDEAL:MODEL_LAYER:INITIALIZATION
!

!  This MODULE holds the routines which are used to perform various initializations
!  for the individual domains.  

!  This MODULE CONTAINS the following routines:

!  initialize_field_test - 1. Set different fields to different constant
!                             values.  This is only a test.  If the correct
!                             domain is not found (based upon the "id")
!                             then a fatal error is issued.               

!-----------------------------------------------------------------------

MODULE module_initialize_ideal

   USE module_domain
   USE module_io_domain
   USE module_state_description
   USE module_model_constants
   USE module_bc
   USE module_timing
   USE module_configure
   USE module_init_utilities
   USE module_soil_pre
#ifdef DM_PARALLEL
   USE module_dm
#endif


CONTAINS


!-------------------------------------------------------------------
! this is a wrapper for the solver-specific init_domain routines.
! Also dereferences the grid variables and passes them down as arguments.
! This is crucial, since the lower level routines may do message passing
! and this will get fouled up on machines that insist on passing down
! copies of assumed-shape arrays (by passing down as arguments, the 
! data are treated as assumed-size -- ie. f77 -- arrays and the copying
! business is avoided).  Fie on the F90 designers.  Fie and a pox.
! NOTE:  Modified to remove all but arrays of rank 4 or more from the 
!        argument list.  Arrays with rank>3 are still problematic due to the 
!        above-noted fie- and pox-ities.  TBH 20061129.  

   SUBROUTINE init_domain ( grid )

   IMPLICIT NONE

   !  Input data.
   TYPE (domain), POINTER :: grid 
   !  Local data.
   INTEGER :: idum1, idum2

   CALL set_scalar_indices_from_config ( head_grid%id , idum1, idum2 )

     CALL init_domain_rk( grid &
!
#include "actual_new_args.inc"
!
                        )
   END SUBROUTINE init_domain

!-------------------------------------------------------------------

   SUBROUTINE init_domain_rk ( grid &
!
# include "dummy_new_args.inc"
!
)

   USE module_optional_input
   IMPLICIT NONE

   !  Input data.
   TYPE (domain), POINTER :: grid

# include "dummy_new_decl.inc"

   TYPE (grid_config_rec_type)              :: config_flags

   !  Local data
   INTEGER                             ::                       &
                                  ids, ide, jds, jde, kds, kde, &
                                  ims, ime, jms, jme, kms, kme, &
                                  its, ite, jts, jte, kts, kte, &
                                  i, j, k

! JPH should add a read to a config file with:
! ----- check to make sure everything is initialized from the LU index, etc.
! ----- need to make a dummy category?
! cen_lat, cen_lon
! land-use category
! soil category

   ! Local data
   INTEGER, PARAMETER :: nl_max = 1000
   REAL, DIMENSION(nl_max) :: zk, p_in, theta, rho, u, v, qv, pd_in
   INTEGER :: nl_in

   INTEGER :: ii, im1, jj, jm1, loop, error, fid, lm
   INTEGER :: icm, jcm, nxc, nyc ! YLH
   REAL    :: B1, B2, B3, B4, B5
   REAL    :: u_mean,v_mean, f0, p_surf, p_level, qvf, z_at_v, z_at_u
   REAL    :: xrad, yrad, zrad, rad, cof1, cof2
   REAL    :: z_scale,delt ! YLH
   REAL    :: pi, rnd

!  stuff from original initialization that has been dropped from the Registry 
   REAL    :: vnu, xnu, xnus, dinit0, cbh, p0_temp, t0_temp, zd
   REAL    :: qvf1, qvf2, pd_surf
   REAL    :: theta_surf ! YLH
   INTEGER :: it
   real :: thtmp, ptmp, temp(3)
   real :: zsfc

   LOGICAL :: moisture_init
   LOGICAL :: stretch_grid ! YLH
   LOGICAL :: dry_sounding
   character (len=256) :: mminlu2

! soil input
   INTEGER :: ns_input
   REAL    :: tmn_input, tsk_input
   REAL    :: zs_input(100),tslb_input(100),smois_input(100)
   LOGICAL :: real_soil = .false. ! YLH

   REAL    :: zrwa(200), zwa(200)

 ! YLH
   real, dimension(:,:), allocatable :: sst_array
   
#ifdef DM_PARALLEL
#    include "data_calls.inc"
#endif


   SELECT CASE ( model_data_order )
         CASE ( DATA_ORDER_ZXY )
   kds = grid%sd31 ; kde = grid%ed31 ;
   ids = grid%sd32 ; ide = grid%ed32 ;
   jds = grid%sd33 ; jde = grid%ed33 ;

   kms = grid%sm31 ; kme = grid%em31 ;
   ims = grid%sm32 ; ime = grid%em32 ;
   jms = grid%sm33 ; jme = grid%em33 ;

   kts = grid%sp31 ; kte = grid%ep31 ;   ! note that tile is entire patch
   its = grid%sp32 ; ite = grid%ep32 ;   ! note that tile is entire patch
   jts = grid%sp33 ; jte = grid%ep33 ;   ! note that tile is entire patch
         CASE ( DATA_ORDER_XYZ )
   ids = grid%sd31 ; ide = grid%ed31 ;
   jds = grid%sd32 ; jde = grid%ed32 ;
   kds = grid%sd33 ; kde = grid%ed33 ;

   ims = grid%sm31 ; ime = grid%em31 ;
   jms = grid%sm32 ; jme = grid%em32 ;
   kms = grid%sm33 ; kme = grid%em33 ;

   its = grid%sp31 ; ite = grid%ep31 ;   ! note that tile is entire patch
   jts = grid%sp32 ; jte = grid%ep32 ;   ! note that tile is entire patch
   kts = grid%sp33 ; kte = grid%ep33 ;   ! note that tile is entire patch
         CASE ( DATA_ORDER_XZY )
   ids = grid%sd31 ; ide = grid%ed31 ;
   kds = grid%sd32 ; kde = grid%ed32 ;
   jds = grid%sd33 ; jde = grid%ed33 ;

   ims = grid%sm31 ; ime = grid%em31 ;
   kms = grid%sm32 ; kme = grid%em32 ;
   jms = grid%sm33 ; jme = grid%em33 ;

   its = grid%sp31 ; ite = grid%ep31 ;   ! note that tile is entire patch
   kts = grid%sp32 ; kte = grid%ep32 ;   ! note that tile is entire patch
   jts = grid%sp33 ; jte = grid%ep33 ;   ! note that tile is entire patch

   END SELECT

!----------------------
! YLH


  ! pi = 2.*asin(1.0)
  ! write(6,*) ' pi is ',pi

   stretch_grid = .false.
   delt = 1.
!   z_scale = .50
   z_scale = .32
   pi = 2.*asin(1.0)
   write(6,*) ' pi is ',pi
   nxc = (ide-ids)/2
   nyc = jde/2
   icm = ide/2
! lm is the half width of the land in terms of grid points
   lm = 25
   write(6,*) 'lm,icm-lm,icm+lm = ', lm,icm-lm,icm+lm

!----------------------

   CALL model_to_grid_config_rec ( grid%id , model_config_rec , config_flags )

! here we check to see if the boundary conditions are set properly

   CALL boundary_condition_check( config_flags, bdyzone, error, grid%id )

   moisture_init = .true.

    grid%itimestep=0

    mminlu2 = ' '
    mminlu2(1:4) = 'USGS'
    CALL nl_set_mminlu(1, mminlu2)
!   CALL nl_set_mminlu(1, 'USGS')
    CALL nl_set_iswater(1,16)
    CALL nl_set_isice(1,3)
    CALL nl_set_truelat1(1,0.)
    CALL nl_set_truelat2(1,0.)
    CALL nl_set_moad_cen_lat (1,0.)
    CALL nl_set_stand_lon(1,0.)
    CALL nl_set_pole_lon (1,0.)
    CALL nl_set_pole_lat (1,90.)
    CALL nl_set_map_proj(1,0)
!   CALL model_to_grid_config_rec(1,model_config_rec,config_flags)
    CALL nl_get_iswater(1,grid%iswater)

!  here we initialize data that currently is not initialized 
!  in the input data

    DO j = jts, jte
      DO i = its, ite
         grid%msft(i,j)     = 1.
         grid%msfu(i,j)     = 1.
         grid%msfv(i,j)     = 1.
         grid%msftx(i,j)    = 1.
         grid%msfty(i,j)    = 1.
         grid%msfux(i,j)    = 1.
         grid%msfuy(i,j)    = 1.
         grid%msfvx(i,j)    = 1.
         grid%msfvx_inv(i,j)    = 1.
         grid%msfvy(i,j)    = 1.
         grid%sina(i,j)     = 0.
         grid%cosa(i,j)     = 1.
         !grid%e(i,j)        = 2.0*EOMEG*cos(config_flags%scm_lat*DEGRAD)
         grid%e(i,j)        = 0. ! YLH
         !grid%f(i,j)        = 2.0*EOMEG*sin(config_flags%scm_lat*DEGRAD)
         !grid%f(i,j)        = 2.5e-5 ! YLH (following em_convrad)
         grid%f(i,j)        = 0. ! YLH (following Maxime)
         !grid%xlat(i,j)     = config_flags%scm_lat
         !grid%xlat(i,j)     = 10. ! YLH (following em_convrad)
         grid%xlat(i,j)     = 0.
         !grid%xlong(i,j)    = config_flags%scm_lon
         grid%xlong(i,j)     = 0. ! YLH
         grid%xland(i,j)     = 2. ! YLH
         grid%landmask(i,j)  = 0. ! 1 = land; 0 = water ! YLH
         !grid%lu_index(i,j)  = config_flags%scm_lu_index
         grid%lu_index(i,j)  = 16 ! see LANDUSE.TBL, 16 is water surface ! YLH
      END DO
   END DO

! for LSM, additional variables need to be initialized

!  other_masked_fields : SELECT CASE ( model_config_rec%sf_surface_physics(grid%id) )

!     CASE (SLABSCHEME)

!     CASE (LSMSCHEME)

! JPH free of snow and ice, and only valid over land
        DO j = jts , MIN(jde-1,jte)
           DO i = its , MIN(ide-1,ite)
              !grid%vegfra(i,j) = config_flags%scm_vegfra
              grid%vegfra(i,j) = 0. ! YLH
              !grid%canwat(i,j) = config_flags%scm_canwat
              grid%canwat(i,j) = 0. ! YLH
              !grid%isltyp(i,j)  = config_flags%scm_isltyp
              grid%isltyp(i,j) = 14 ! soil category, see SOILPARM.TBL, 14 is water
              !grid%ivgtyp(i,j)  = config_flags%scm_lu_index
              grid%ivgtyp(i,j) = 16 ! YLH
              grid%xice(i,j) = 0.
              grid%snow(i,j) = 0.
           END DO
        END DO

!     CASE (RUCLSMSCHEME)

!  END SELECT other_masked_fields

   grid%step_number = 0
!
!   IF ( real_soil ) THEN ! from input file ! YLH (UNCOMMENTED the whole if statement)
!
!      IF (config_flags%sf_surface_physics .NE. 2) WRITE (6, *)   &
!         'If using LSM option other than Noah, must edit input_soil file in test/em_scm_xy/ directory'
    
!      CALL read_soil(100,ns_input,tmn_input,tsk_input,zs_input,tslb_input,smois_input)

!      CALL init_module_optional_input(grid,config_flags)
!      num_st_levels_input = ns_input
!      num_sm_levels_input = ns_input
!      num_sw_levels_input = ns_input
!      DO k = 1,ns_input
!         st_levels_input(k) = zs_input(k)*100.0 ! to cm
!         sm_levels_input(k) = zs_input(k)*100.0 ! to cm
!         sw_levels_input(k) = zs_input(k)*100.0 ! to cm
!         st_input(:,k+1,:) = tslb_input(k)
!         sm_input(:,k+1,:) = smois_input(k)
!         sw_input(:,k+1,:) = smois_input(k)
!      ENDDO
  
!     grid%tsk = tsk_input
!      grid%sst = tsk_input
!      grid%tmn = tmn_input

!      flag_soil_layers  = 0 ! go ahead and put skin temp in
!      flag_soil_levels  = 0 ! go ahead and put skin moisture in
!      flag_sst          = 0 ! don't modify for ocean
!      flag_tavgsfc      = 0 
!      flag_soilhgt      = 0 

!      CALL process_soil_real ( grid%tsk , grid%tmn , grid%tavgsfc, &
!                   grid%landmask , grid%sst , grid%ht, grid%toposoil, &
!                  st_input , sm_input , sw_input , &
!                   st_levels_input , sm_levels_input , sw_levels_input , &
!                   grid%zs , grid%dzs , grid%tslb , grid%smois , grid%sh2o , &
!                   flag_sst , flag_tavgsfc, flag_soilhgt, flag_soil_layers, flag_soil_levels,  &
!                   ids , ide , jds , jde , kds , kde , &
!                   ims , ime , jms , jme , kms , kme , &
!                   its , ite , jts , jte , kts , kte , &
!                   model_config_rec%sf_surface_physics(grid%id) , &
!                   model_config_rec%num_soil_layers , &
!                   model_config_rec%real_data_init_type , &
!                   num_st_levels_input , num_sm_levels_input , num_sw_levels_input , &
!                   num_st_levels_alloc , num_sm_levels_alloc , num_sw_levels_alloc )

!   ELSE ! ideal soil
! Process the soil; note that there are some things hard-wired into share/module_soil_pre.F
      CALL process_soil_ideal(grid%xland,grid%xice,grid%vegfra,grid%snow,grid%canwat, &
                     grid%ivgtyp,grid%isltyp,grid%tslb,grid%smois, &
                     grid%tsk,grid%tmn,grid%zs,grid%dzs,model_config_rec%num_soil_layers, &
                     model_config_rec%sf_surface_physics(grid%id), &
                                   ids,ide, jds,jde, kds,kde,&
                                   ims,ime, jms,jme, kms,kme,&
                                   its,ite, jts,jte, kts,kte )

!    ENDIF

    DO j = jts, jte
     DO k = kts, kte
       DO i = its, ite
          grid%ww(i,k,j)     = 0.
       END DO
     END DO
    END DO

! UNCOMMENT the following to use original WA GABLS case
! this is adopted from Wayne Angevine's GABLS case
!
!    grid%znw(1) = 1.0
!    zrwa(kde) = exp((kde-1)/40.)
!    zwa(kde) = grid%ztop
!    DO k=2, kde-1
!       zrwa(k) = exp((k-1)/40.)
!       zwa(k) = (zrwa(k)-1.) * grid%ztop/(zrwa(kde)-1.)
!       grid%znw(k) = 1. - (zwa(k) / zwa(kde))
!    ENDDO
!    grid%znw(kde) = 0.

!-------------------
! YLH set up the grid (stretch grid version)

   IF (stretch_grid) THEN ! exponential stretch for eta (nearly constant dz)
     DO k=1, kde
!     grid%znw(k) = (exp(-(k-1)/float(kde-1)/z_scale) - exp(-1./z_scale))/ &
!                               (1.-exp(-1./z_scale))
! read eta_levels from namelist (replace with commented code above if not)
      grid%znw(k) = model_config_rec%eta_levels(k)
     ENDDO
   ELSE
     DO k=1, kde
      grid%znw(k) = 1. - float(k-1)/float(kde-1)
     ENDDO
   ENDIF

!-------------------

   DO k=1, kde-1
    grid%dnw(k) = grid%znw(k+1) - grid%znw(k)
    grid%rdnw(k) = 1./grid%dnw(k)
    grid%znu(k) = 0.5*(grid%znw(k+1)+grid%znw(k))
   ENDDO

   DO k=2, kde-1
    grid%dn(k) = 0.5*(grid%dnw(k)+grid%dnw(k-1))
    grid%rdn(k) = 1./grid%dn(k)
    grid%fnp(k) = .5* grid%dnw(k  )/grid%dn(k)
    grid%fnm(k) = .5* grid%dnw(k-1)/grid%dn(k)
   ENDDO

   cof1 = (2.*grid%dn(2)+grid%dn(3))/(grid%dn(2)+grid%dn(3))*grid%dnw(1)/grid%dn(2) 
   cof2 =     grid%dn(2)        /(grid%dn(2)+grid%dn(3))*grid%dnw(1)/grid%dn(3) 
   grid%cf1  = grid%fnp(2) + cof1
   grid%cf2  = grid%fnm(2) - cof1 - cof2
   grid%cf3  = cof2       

   grid%cfn  = (.5*grid%dnw(kde-1)+grid%dn(kde-1))/grid%dn(kde-1)
   grid%cfn1 = -.5*grid%dnw(kde-1)/grid%dn(kde-1)
   grid%rdx = 1./config_flags%dx
   grid%rdy = 1./config_flags%dy

!  get the sounding from the ascii sounding file, first get dry sounding and 
!  calculate base state

  write(6,*) ' getting dry sounding for base state '
  dry_sounding = .true.
  ! YLH added theta_surf to get_sounding subroutine call
  CALL get_sounding( zsfc, zk, p_in, pd_in, theta, rho, u, v, qv, dry_sounding, nl_max, nl_in, theta_surf ) 
  

  write(6,*) ' returned from reading sounding, nl_in is ',nl_in

!  find ptop for the desired ztop (ztop is input from the namelist),
!  and find surface pressure

  grid%p_top = interp_0( p_in, zk, config_flags%ztop, nl_in )

  !  For hybrid coord

  DO k=kts, kte
     IF      ( config_flags%hybrid_opt .EQ. 0 ) THEN
        grid%c3f(k) = grid%znw(k)
     ELSE IF ( config_flags%hybrid_opt .EQ. 1 ) THEN
        grid%c3f(k) = grid%znw(k)
     ELSE IF ( config_flags%hybrid_opt .EQ. 2 ) THEN
        B1 = 2. * grid%etac**2 * ( 1. - grid%etac )
        B2 = -grid%etac * ( 4. - 3. * grid%etac - grid%etac**3 )
        B3 = 2. * ( 1. - grid%etac**3 )
        B4 = - ( 1. - grid%etac**2 )
        B5 = (1.-grid%etac)**4
        grid%c3f(k) = ( B1 + B2*grid%znw(k) + B3*grid%znw(k)**2 + B4*grid%znw(k)**3 ) / B5
        IF ( grid%znw(k) .LT. grid%etac ) THEN
           grid%c3f(k) = 0.
        END IF
        IF ( k .EQ. kds ) THEN
           grid%c3f(k) = 1.
        ELSE IF ( k .EQ. kde ) THEN
           grid%c3f(k) = 0.
        END IF
     ELSE IF ( config_flags%hybrid_opt .EQ. 3 ) THEN
        grid%c3f(k) = grid%znw(k)*sin(0.5*3.14159*grid%znw(k))**2
        IF      ( k .EQ. kds ) THEN
           grid%c3f(k) = 1.
        ELSE IF ( k .EQ. kds ) THEN
           grid%c3f(kde) = 0.
        END IF
     ELSE
        CALL wrf_message     ( 'ERROR: --- hybrid_opt' )
        CALL wrf_message     ( 'ERROR: --- hybrid_opt=0    ==> Standard WRF terrain-following coordinate' )
        CALL wrf_message     ( 'ERROR: --- hybrid_opt=1    ==> Standard WRF terrain-following coordinate, hybrid c1, c2, c3, c4' )
        CALL wrf_message     ( 'ERROR: --- hybrid_opt=2    ==> Hybrid, Klemp polynomial' )
        CALL wrf_message     ( 'ERROR: --- hybrid_opt=3    ==> Hybrid, sin^2' )
        CALL wrf_error_fatal ( 'ERROR: --- Invalid option' )
     END IF
  END DO

  !  c4 is a function of c3 and eta.

  DO k=1, kde
     grid%c4f(k) = ( grid%znw(k) - grid%c3f(k) ) * ( p1000mb - grid%p_top )
  ENDDO
      
  !  Now on half levels, just add up and divide by 2 (for c3h).  Use (eta-c3)*(p00-pt) for c4 on half levels.
      
  DO k=1, kde-1
     grid%znu(k) = ( grid%znw(k+1) + grid%znw(k) ) * 0.5
     grid%c3h(k) = ( grid%c3f(k+1) + grid%c3f(k) ) * 0.5
     grid%c4h(k) = ( grid%znu(k) - grid%c3h(k) ) * ( p1000mb - grid%p_top )
  ENDDO
      
  !  c1 = d(B)/d(eta).  We define c1f as c1 on FULL levels.  For a vertical difference,
  !  we need to use B and eta on half levels.  The k-loop ends up referring to the
  !  full levels, neglecting the top and bottom.
      
  DO k=kds+1, kde-1
     grid%c1f(k) = ( grid%c3h(k) - grid%c3h(k-1) ) / ( grid%znu(k) - grid%znu(k-1) )
  ENDDO
      
  !  The boundary conditions to get the coefficients:
  !  1) At k=kts: define d(B)/d(eta) = 1.  This gives us the same value of B and d(B)/d(eta)
  !     when doing the sigma-only B=eta.
  !  2) At k=kte: define d(B)/d(eta) = 0.  The curve B SMOOTHLY goes to zero, and at the very
  !     top, B continues to SMOOTHLY go to zero.  Note that for almost all cases of non B=eta,
  !     B is ALREADY=ZERO at the top, so this is a reasonable BC to assume.
      
  grid%c1f(kds) = 1.
  IF ( ( config_flags%hybrid_opt .EQ. 0 ) .OR. ( config_flags%hybrid_opt .EQ. 1 ) ) THEN
     grid%c1f(kde) = 1.
  ELSE
     grid%c1f(kde) = 0.
  END IF
      
  !  c2 = ( 1. - c1(k) ) * (p00 - pt).  There is no vertical differencing, so we can do the
  !  full kds to kde looping.
      
  DO k=kds, kde
     grid%c2f(k) = ( 1. - grid%c1f(k) ) * ( p1000mb - grid%p_top )
  ENDDO
      
  !  Now on half levels for c1 and c2.  The c1h will result from the full level c3 and full
  !  level eta differences.  The c2 value use the half level c1(k).
      
  DO k=1, kde-1
     grid%c1h(k) = ( grid%c3f(k+1) - grid%c3f(k) ) / ( grid%znw(k+1) - grid%znw(k) )
     grid%c2h(k) = ( 1. - grid%c1h(k) ) * ( p1000mb - grid%p_top )
  ENDDO

  DO j=jts,jte
  DO i=its,ite  ! flat surface
    grid%ht(i,j) = zsfc
    grid%phb(i,1,j) = grid%ht(i,j) * g
    grid%ph0(i,1,j) = grid%ht(i,j) * g
    grid%php(i,1,j) = 0.
  ENDDO
  ENDDO

  DO J = jts, jte
  DO I = its, ite

    p_surf = interp_0( p_in, zk, grid%phb(i,1,j)/g, nl_in )
    grid%mub(i,j) = p_surf-grid%p_top

!  this is dry hydrostatic sounding (base state), so given grid%p (coordinate),
!  interp theta (from interp) and compute 1/rho from eqn. of state

    DO K = 1, kte-1
      p_level = grid%c3h(k)*(p_surf - grid%p_top)+grid%c4h(k) + grid%p_top
      grid%pb(i,k,j) = p_level
      grid%t_init(i,k,j) = interp_0( theta, p_in, p_level, nl_in ) - t0
      grid%alb(i,k,j) = (r_d/p1000mb)*(grid%t_init(i,k,j)+t0)*(grid%pb(i,k,j)/p1000mb)**cvpm
    ENDDO

!  calc hydrostatic balance (alternatively we could interp the geopotential from the
!  sounding, but this assures that the base state is in exact hydrostatic balance with
!  respect to the model eqns.

    DO k  = 2,kte
      grid%phb(i,k,j) = grid%phb(i,k-1,j) - grid%dnw(k-1)*(grid%c1h(k-1)*grid%mub(i,j)+grid%c2h(k-1))*grid%alb(i,k-1,j)
    ENDDO

  ENDDO
  ENDDO

  write(6,*) ' ptop is ',grid%p_top
  write(6,*) ' base state grid%mub(1,1), p_surf is ',grid%mub(1,1),grid%mub(1,1)+grid%p_top

!  calculate full state for each column - this includes moisture.

  write(6,*) ' getting moist sounding for full state '
  dry_sounding = .false.
  ! YLH added theta_surf to get_sounding subroutine call
  CALL get_sounding( zsfc, zk, p_in, pd_in, theta, rho, u, v, qv, dry_sounding, nl_max, nl_in, theta_surf )

  DO J = jts, min(jde-1,jte)
  DO I = its, min(ide-1,ite)

!  At this point grid%p_top is already set. find the DRY mass in the column 
!  by interpolating the DRY pressure.  

   pd_surf = interp_0( pd_in, zk, grid%phb(i,1,j)/g, nl_in )

!  compute the perturbation mass and the full mass

    grid%mu_1(i,j) = pd_surf-grid%p_top - grid%mub(i,j)
    grid%mu_2(i,j) = grid%mu_1(i,j)
    grid%mu0(i,j) = grid%mu_1(i,j) + grid%mub(i,j)

! given the dry pressure and coordinate system, interp the potential
! temperature and qv

    do k=1,kde-1

      p_level = grid%znu(k)*(pd_surf - grid%p_top) + grid%p_top

      moist(i,k,j,P_QV) = interp_0( qv, pd_in, p_level, nl_in )
      grid%t_1(i,k,j)          = interp_0( theta, pd_in, p_level, nl_in ) - t0
      grid%t_2(i,k,j)          = grid%t_1(i,k,j)
      

    enddo

!  integrate the hydrostatic equation (from the RHS of the bigstep
!  vertical momentum equation) down from the top to get grid%p.
!  first from the top of the model to the top pressure

    k = kte-1  ! top level

    qvf1 = 0.5*(moist(i,k,j,P_QV)+moist(i,k,j,P_QV))
    qvf2 = 1./(1.+qvf1)
    qvf1 = qvf1*qvf2

    grid%p(i,k,j) = - 0.5*((grid%c1f(k+1)*grid%mu_1(i,j))+qvf1*(grid%c1f(k+1)*grid%mub(i,j)+grid%c2f(k+1)))/grid%rdnw(k)/qvf2
    qvf = 1. + rvovrd*moist(i,k,j,P_QV)
    grid%alt(i,k,j) = (r_d/p1000mb)*(grid%t_1(i,k,j)+t0)*qvf* &
                (((grid%p(i,k,j)+grid%pb(i,k,j))/p1000mb)**cvpm)
    grid%al(i,k,j) = grid%alt(i,k,j) - grid%alb(i,k,j)

!  down the column

    do k=kte-2,1,-1
      qvf1 = 0.5*(moist(i,k,j,P_QV)+moist(i,k+1,j,P_QV))
      qvf2 = 1./(1.+qvf1)
      qvf1 = qvf1*qvf2
      grid%p(i,k,j) = grid%p(i,k+1,j) - ((grid%c1f(k+1)*grid%mu_1(i,j)) + qvf1*(grid%c1f(k+1)*grid%mub(i,j)+grid%c2f(k+1)))/qvf2/grid%rdn(k+1)
      qvf = 1. + rvovrd*moist(i,k,j,P_QV)
      grid%alt(i,k,j) = (r_d/p1000mb)*(grid%t_1(i,k,j)+t0)*qvf* &
                  (((grid%p(i,k,j)+grid%pb(i,k,j))/p1000mb)**cvpm)
      grid%al(i,k,j) = grid%alt(i,k,j) - grid%alb(i,k,j)
    enddo

!  this is the hydrostatic equation used in the model after the
!  small timesteps.  In the model, grid%al (inverse density)
!  is computed from the geopotential.


    grid%ph_1(i,1,j) = 0.
    DO k  = 2,kte
      grid%ph_1(i,k,j) = grid%ph_1(i,k-1,j) - (grid%dnw(k-1))*(       &    
                   ((grid%c1h(k-1)*grid%mub(i,j)+grid%c2h(k-1))+(grid%c1h(k-1)*grid%mu_1(i,j)))*grid%al(i,k-1,j)+ &
                    (grid%c1h(k-1)*grid%mu_1(i,j))*grid%alb(i,k-1,j)  )
                                                   
      grid%ph_2(i,k,j) = grid%ph_1(i,k,j) 
      grid%ph0(i,k,j) = grid%ph_1(i,k,j) + grid%phb(i,k,j)
    ENDDO

    if((i==2) .and. (j==2)) then
     write(6,*) ' grid%ph_1 calc ',grid%ph_1(2,1,2),grid%ph_1(2,2,2),&
                              grid%mu_1(2,2)+grid%mub(2,2),grid%mu_1(2,2), &
                              grid%alb(2,1,2),grid%al(1,2,1),grid%rdnw(1)
    endif

  ENDDO
  ENDDO
  
!!!!!!!!!!!!!!!!!!!!!!
! YLH Add random low-level thermal perturbation to kick off convection

!  random low-level thermal perturbation to kick off convection
  call random_seed
  write(6,*) ' nxc, nyc for perturbation ',nxc,nyc
  write(6,*) ' delt for perturbation ',delt

  DO J = jts, min(jde-1,jte)
    DO I = its, min(ide-1,ite)
      DO K = 1, 10

	call RANDOM_NUMBER(rnd)
	  grid%t_1(i,k,j)=grid%t_1(i,k,j)+delt*(rnd-0.5)
         !  grid%t_1(i,k,j)=grid%t_1(i,k,j)+delt*COS(.5*PI*RAD)**2
           grid%t_2(i,k,j)=grid%t_1(i,k,j)
           qvf = 1. + rvovrd*moist(i,k,j,P_QV)
           grid%alt(i,k,j) = (r_d/p1000mb)*(grid%t_1(i,k,j)+t0)*qvf* &
                        (((grid%p(i,k,j)+grid%pb(i,k,j))/p1000mb)**cvpm)
           grid%al(i,k,j) = grid%alt(i,k,j) - grid%alb(i,k,j)
      ENDDO

!  rebalance hydrostatically

      DO k  = 2,kte
        grid%ph_1(i,k,j) = grid%ph_1(i,k-1,j) - (grid%dnw(k-1))*(       &
                     (grid%mub(i,j)+grid%mu_1(i,j))*grid%al(i,k-1,j)+ &
                      grid%mu_1(i,j)*grid%alb(i,k-1,j)  )
                                                   
        grid%ph_2(i,k,j) = grid%ph_1(i,k,j) 
        grid%ph0(i,k,j) = grid%ph_1(i,k,j) + grid%phb(i,k,j)
      ENDDO

    ENDDO
  ENDDO

!!!!!!!!!!!!!!!!!!!!!

   write(6,*) ' grid%mu_1 from comp ', grid%mu_1(1,1)
   write(6,*) ' full state sounding from comp, ph, grid%p, grid%al, grid%t_1, qv '

   do k=1,kde-1
     write(6,'(i3,1x,5(1x,1pe10.3))') k, grid%ph_1(1,k,1)+grid%phb(1,k,1), &
                                      grid%p(1,k,1)+grid%pb(1,k,1), grid%alt(1,k,1), &
                                      grid%t_1(1,k,1)+t0, moist(1,k,1,P_QV)
   enddo

   write(6,*) ' pert state sounding from comp, grid%ph_1, pp, alp, grid%t_1, qv '
   do k=1,kde-1
     write(6,'(i3,1x,5(1x,1pe10.3))') k, grid%ph_1(1,k,1), &
                                      grid%p(1,k,1), grid%al(1,k,1), &
                                      grid%t_1(1,k,1), moist(1,k,1,P_QV)
   enddo

! interp v

  DO J = jts, jte
  DO I = its, min(ide-1,ite)

    IF (j == jds) THEN
      z_at_v = grid%phb(i,1,j)/g
    ELSE IF (j == jde) THEN
      z_at_v = grid%phb(i,1,j-1)/g
    ELSE
      z_at_v = 0.5*(grid%phb(i,1,j)+grid%phb(i,1,j-1))/g
    END IF

    p_surf = interp_0( p_in, zk, z_at_v, nl_in )

    DO K = 1, kte
      p_level = grid%c3h(k)*(p_surf - grid%p_top)+grid%c4h(k) + grid%p_top
      grid%v_1(i,k,j) = interp_0( v, p_in, p_level, nl_in )
      grid%v_2(i,k,j) = grid%v_1(i,k,j)
    ENDDO

  ENDDO
  ENDDO

! interp u

  DO J = jts, min(jde-1,jte)
  DO I = its, ite

    IF (i == ids) THEN
      z_at_u = grid%phb(i,1,j)/g
    ELSE IF (i == ide) THEN
      z_at_u = grid%phb(i-1,1,j)/g
    ELSE
      z_at_u = 0.5*(grid%phb(i,1,j)+grid%phb(i-1,1,j))/g
    END IF

    p_surf = interp_0( p_in, zk, z_at_u, nl_in )

    DO K = 1, kte
      p_level = grid%c3h(k)*(p_surf - grid%p_top)+grid%c4h(k) + grid%p_top
      grid%u_1(i,k,j) = interp_0( u, p_in, p_level, nl_in )
      grid%u_2(i,k,j) = grid%u_1(i,k,j)
    ENDDO

  ENDDO
  ENDDO

!  set w

  DO J = jts, min(jde-1,jte)
  DO K = kts, kte
  DO I = its, min(ide-1,ite)
    grid%w_1(i,k,j) = 0.
    grid%w_2(i,k,j) = 0.
  ENDDO
  ENDDO
  ENDDO

!  set a few more things

  DO J = jts, min(jde-1,jte)
  DO K = kts, kte-1
  DO I = its, min(ide-1,ite)
    grid%h_diabatic(i,k,j) = 0.
  ENDDO
  ENDDO
  ENDDO

! Go ahead and initialize these from the sounding.  This will allow a run
! to actually succeed even if scm_force = 0
  DO k=1,kte-1
    grid%t_base(k) = grid%t_1(1,k,1)
    grid%qv_base(k) = moist(1,k,1,P_QV)
    grid%u_base(k) = grid%u_1(1,k,1)
    grid%v_base(k) = grid%v_1(1,k,1)
    grid%z_base(k) = 0.5*(grid%phb(1,k,1)+grid%phb(1,k+1,1)+grid%ph_1(1,k,1)+grid%ph_1(1,k+1,1))/g
  ENDDO

      !  Save the dry perturbation potential temperature.

      DO j = jts, min(jde-1,jte)
         DO k = kts, kte
            DO i = its, min(ide-1,ite)
               grid%th_phy_m_t0(i,k,j) = grid%t_2(i,k,j)
            END DO
         END DO
      END DO

 !  Turn dry potential temperature into moist potential temperature
      !  at the very end of this routine
      !  This field will be in the model IC and and used to construct the 
      !  BC file.

      IF ( ( config_flags%use_theta_m .EQ. 1 ) .AND. (P_Qv .GE. PARAM_FIRST_SCALAR) ) THEN
      DO J  = jts, min(jde-1,jte)
         DO K = kts, kte-1
            DO I = its, min(ide-1,ite)
               grid%t_2(i,k,j) = ( grid%t_2(i,k,j) + T0 ) * (1. + (R_v/R_d) * moist(i,k,j,p_qv)) - T0
            END DO
         END DO
      END DO
      ENDIF
    

!*********************************** YLH (SCM_MCM_EXPERIMENTS) ***********************************!

  ! SET SST, TSK and TMN

  ! configure SST
  if (config_flags%use_variable_sst_flag .eqv. .true.) then

    call wrf_debug( 50, "VARIABLE SST (HOTSPOT)")

    open(12, file="sst_hotspot_input.txt",form="FORMATTED", status="old")

    ! read in values
    allocate ( sst_array(its:min(ide-1,ite),jts:min(jde-1,jte)) )
    read(12,*) sst_array
    sst_array = transpose(sst_array)

    do j = jts,min(jde-1,jte)
       do i = its,min(ide-1,ite)
          
           grid%sst(i,j) = sst_array(i,j)

       end do
    end do

    close(12)    

  else if (config_flags%use_variable_sst_flag .eqv. .false.) then

      call wrf_debug( 50, "FIXED SST")

      grid%sst = config_flags%sst_ideal ! set SST to value read from namelist
  
  endif

  ! set grid%tsk,tmn and sst
  ! copied from convrad, line 614-619

  if (config_flags%set_tsk_eq_sst_flag .eqv. .true.) then

     if (config_flags%use_variable_sst_flag .eqv. .false.) then

          DO J = jts, min(jde-1,jte)
          DO I = its, min(ide-1,ite)
                 !grid%tsk(i,j) = theta_surf * (p_surf/p1000mb)**rcp
                 grid%tsk(i,j) = config_flags%sst_ideal
                 grid%tmn(i,j) = grid%tsk(i,j)
          ENDDO
          ENDDO

     else if (config_flags%use_variable_sst_flag .eqv. .true.) then

          DO J = jts, min(jde-1,jte)
          DO I = its, min(ide-1,ite)
                 !grid%tsk(i,j) = theta_surf * (p_surf/p1000mb)**rcp
                 grid%tsk(i,j) = grid%sst(i,j)
                 grid%tmn(i,j) = grid%tsk(i,j)
          ENDDO
          ENDDO

     end if

  else if (config_flags%set_tsk_eq_sst_flag .eqv. .false.) then

      DO J = jts, min(jde-1,jte)
      DO I = its, min(ide-1,ite)
             grid%tsk(i,j) = theta_surf * (p_surf/p1000mb)**rcp
             !grid%tsk(i,j) = config_flags%sst_ideal
             grid%tmn(i,j) = grid%tsk(i,j)
      ENDDO
      ENDDO

  end if

!*********************************** YLH (SCM_MCM_EXPERIMENTS) ***********************************!
 
  RETURN

 END SUBROUTINE init_domain_rk

   SUBROUTINE init_module_initialize
   END SUBROUTINE init_module_initialize

!---------------------------------------------------------------------

!  test driver for get_sounding
!
!      implicit none
!      integer n
!      parameter(n = 1000)
!      real zk(n),p(n),theta(n),rho(n),u(n),v(n),qv(n),pd(n)
!      logical dry
!      integer nl,k
!
!      dry = .false.
!      dry = .true.
!      call get_sounding( zk, p, pd, theta, rho, u, v, qv, dry, n, nl )
!      write(6,*) ' input levels ',nl
!      write(6,*) ' sounding '
!      write(6,*) '  k  height(m)  press (Pa) pd(Pa) theta (K) den(kg/m^3)  u(m/s)     v(m/s)    qv(g/g) '
!      do k=1,nl
!        write(6,'(1x,i3,8(1x,1pe10.3))') k, zk(k), p(k), pd(k), theta(k), rho(k), u(k), v(k), qv(k)
!      enddo
!      end
!
!---------------------------------------------------------------------------

      subroutine get_sounding( zsfc, zk, p, p_dry, theta, rho, &
                               u, v, qv, dry, nl_max, nl_in, th_surf )
      implicit none

      integer nl_max, nl_in
      real zsfc
      real zk(nl_max), p(nl_max), theta(nl_max), rho(nl_max), &
           u(nl_max), v(nl_max), qv(nl_max), p_dry(nl_max)
      logical dry

      integer n
      parameter(n=3000)
      logical debug
      parameter( debug = .true.)

! input sounding data

      real p_surf, th_surf, qv_surf
      real pi_surf, pi(n)
      real h_input(n), th_input(n), qv_input(n), u_input(n), v_input(n)

! diagnostics

      real rho_surf, p_input(n), rho_input(n)
      real pm_input(n)  !  this are for full moist sounding

! local data

      real r
      parameter (r = r_d)
      integer k, it, nl
      real qvf, qvf1, dz

!  first, read the sounding

      call read_sounding( zsfc, p_surf, th_surf, qv_surf, &
                          h_input, th_input, qv_input, u_input, v_input,n, nl, debug )


      if(dry) then
       do k=1,nl
         qv_input(k) = 0.
       enddo
      endif

      if(debug) write(6,*) ' number of input levels = ',nl

        nl_in = nl
        if(nl_in .gt. nl_max ) then
          write(6,*) ' too many levels for input arrays ',nl_in,nl_max
          call wrf_error_fatal ( ' too many levels for input arrays ' )
        end if

!  compute diagnostics,
!  first, convert qv(g/kg) to qv(g/g)

      do k=1,nl
        qv_input(k) = 0.001*qv_input(k)
      enddo

      p_surf = 100.*p_surf  ! convert to pascals
      qvf = 1. + rvovrd*qv_input(1) 
      rho_surf = 1./((r/p1000mb)*th_surf*qvf*((p_surf/p1000mb)**cvpm))
      pi_surf = (p_surf/p1000mb)**(r/cp)

      if(debug) then
        write(6,*) ' surface density is ',rho_surf
        write(6,*) ' surface pi is      ',pi_surf
      end if


!  integrate moist sounding hydrostatically, starting from the
!  specified surface pressure
!  -> first, integrate from surface to lowest level

          qvf = 1. + rvovrd*qv_input(1) 
          qvf1 = 1. + qv_input(1)
          rho_input(1) = rho_surf
          dz = h_input(1)-zsfc

! error check here
          if ( dz < 0.0 ) then
            write(6,*) "Your first input sounding level is below the WRF terrain elevation, aborting"
            stop "module_initialize_scm_xy:get_sounding"
          endif
          do it=1,10
            pm_input(1) = p_surf &
                    - 0.5*dz*(rho_surf+rho_input(1))*g*qvf1
            rho_input(1) = 1./((r/p1000mb)*th_input(1)*qvf*((pm_input(1)/p1000mb)**cvpm))
          enddo

! integrate up the column

          do k=2,nl
            rho_input(k) = rho_input(k-1)
            dz = h_input(k)-h_input(k-1)
            qvf1 = 0.5*(2.+(qv_input(k-1)+qv_input(k)))
            qvf = 1. + rvovrd*qv_input(k)   ! qv is in g/kg here
 
            do it=1,10
              pm_input(k) = pm_input(k-1) &
                      - 0.5*dz*(rho_input(k)+rho_input(k-1))*g*qvf1
              rho_input(k) = 1./((r/p1000mb)*th_input(k)*qvf*((pm_input(k)/p1000mb)**cvpm))
            enddo
          enddo
!  we have the moist sounding

!  next, compute the dry sounding using p at the highest level from the
!  moist sounding and integrating down.

        p_input(nl) = pm_input(nl)

          do k=nl-1,1,-1
            dz = h_input(k+1)-h_input(k)
            p_input(k) = p_input(k+1) + 0.5*dz*(rho_input(k)+rho_input(k+1))*g
          enddo


        do k=1,nl
          zk(k) = h_input(k)
          p(k) = pm_input(k)
          p_dry(k) = p_input(k)
          theta(k) = th_input(k)
          rho(k) = rho_input(k)
          u(k) = u_input(k)
          v(k) = v_input(k)
          qv(k) = qv_input(k) 

        enddo

     if(debug) then
      write(6,*) ' sounding '
      write(6,*) '  k  height(m)  press (Pa) pd(Pa) theta (K) den(kg/m^3)  u(m/s)     v(m/s)    qv(g/g) '
      do k=1,nl
        write(6,'(1x,i3,8(1x,1pe10.3))') k, zk(k), p(k), p_dry(k), theta(k), rho(k), u(k), v(k), qv(k)
      enddo

     end if

      end subroutine get_sounding

!-------------------------------------------------------

      subroutine read_sounding( zsfc,ps,ts,qvs,h,th,qv,u,v,n,nl,debug )
      implicit none
      integer n,nl
      real zsfc,ps,ts,qvs,h(n),th(n),qv(n),u(n),v(n)
      real u10,v10,t2,q2
      logical end_of_file
      logical debug

      integer k

      open(unit=10,file='input_sounding',form='formatted',status='old')
      rewind(10)

      read(10,*) zsfc, t2, q2, u10, v10, ps ! YLH change order of reading file
      !ps = ps/100.0 ! YLH change input sounding ps to hPa
      ts = t2
      !qvs = q2*1000 
      qvs = q2 ! YLH change input sounding to g/kg

      if(debug) then
        write(6,*) ' input sounding surface parameters '
        write(6,*) ' surface pressure (mb) ',ps
        write(6,*) ' surface pot. temp (K) ',ts
        write(6,*) ' surface mixing ratio (g/kg) ',qvs
      end if

      end_of_file = .false.
      k = 0

      do while (.not. end_of_file)

        read(10,*,end=100) h(k+1), th(k+1), qv(k+1), u(k+1), v(k+1)
        ! YLH change order to read file 

        !qv(k+1) = qv(k+1)*1000.0
        qv(k+1) = qv(k+1) ! YLH change input sounding to g/kg
        k = k+1
        if(debug) write(6,'(1x,i3,5(1x,e10.3))') k, h(k), th(k), qv(k), u(k), v(k)
        go to 110
 100    end_of_file = .true.
 110    continue
      enddo

      nl = k

      close(unit=10,status = 'keep')

      end subroutine read_sounding

!-------------------------------------------------------

      subroutine read_soil( n,nl,tmn,tsk,zs,tslb,smois )
      implicit none
      integer n,nl
      real tmn,tsk
      real zs(n),tslb(n),smois(n)
      logical end_of_file
      logical debug 

      integer k
    
      debug = .true.

      open(unit=11,file='input_soil',form='formatted',status='old')
      rewind(11)

      read(11,*) zs(1),tmn,tsk

      if(debug) then
        write(6,*) ' input deep soil temperature (K) ',tmn
        write(6,*) ' input skin temperature (K) ',tsk
      end if

      end_of_file = .false.
      k = 0

      do while (.not. end_of_file)

        read(11,*,end=100) zs(k+1), tslb(k+1), smois(k+1)
        k = k+1
        if(debug) write(6,'(1x,i3,3(1x,f16.7))') k, zs(k), tslb(k), smois(k)
        go to 110
 100    end_of_file = .true.
 110    continue
      enddo

      nl = k

      close(unit=11,status = 'keep')

      end subroutine read_soil

END MODULE module_initialize_ideal
