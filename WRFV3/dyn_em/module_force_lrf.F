module module_force_lrf

! AUTHOR: Yi-Ling Hwong (CCRC)
! Apply small temperature or moisture tendency perturbation 
! To implement Herman & Kuang (2013) Linear Response Function (LRF)

CONTAINS
  
  subroutine force_LRF(perturb_t_flag, perturb_q_flag                        & 
                           , j_pert, TtendAmp, QtendAmp                      &
                           , p, pi, thten, qvten                             &
                           , ids, ide, jds, jde, kds, kde                    &
                           , ims, ime, jms, jme, kms, kme                    &
                           , ips, ipe, jps, jpe, kps, kpe                    &
                           , its, ite, jts, jte, kts, kte                    &                                        
                           )
  
  implicit none
  
  logical, intent(in)                                     :: perturb_t_flag,perturb_q_flag
  integer, intent(in)                                     :: j_pert ! n-th perturbation level
  real, intent(in)                                        :: TtendAmp !dT/dt perturbation (K/d)
  real, intent(in)                                        :: QtendAmp !dq/dt perturbation (kg/kg/d)
  real, dimension(ims:ime,kms:kme,jms:jme), intent(in)    :: p, pi
  real, dimension(ims:ime,kms:kme,jms:jme), intent(inout) :: thten ! potential temperature    
  real, dimension(ims:ime,kms:kme,jms:jme), intent(inout) :: qvten ! water vapor    
  integer, intent(in)                                     :: ids,ide,jds,jde,kds,kde, &
                                                             ims,ime,jms,jme,kms,kme, &  
                                                             ips,ipe,jps,jpe,kps,kpe, &
                                                             its,ite,jts,jte,kts,kte  

  ! local vars
  real, dimension(ims:ime,kms:kme,jms:jme) :: tten              ! dT/dt (K/s)
  real, dimension(ims:ime,kms:kme,jms:jme) :: qten              ! dq/dt (kg/kg/s)
  real                                     :: deltaf            ! (Kronecker?) Delta function
  integer                                  :: i,j,k
  character (len=256)                      :: message  
  
  call wrf_debug ( 50, "APPLY LRF tendency perturbation" )
    
    
  ! The forcing form is from the one used in Equation (4) of Herman and Kuang 2013
  ! The difference btw this form and the one used in Appendix A of Kuang 2012 is a factor of 1/2

  if ( perturb_t_flag .eqv. .true. ) then

      call wrf_debug ( 50, "perturb T tendency" )

      do i = its,ite
         do k = kts,kte
            do j = jts,jte
               
                ! Delta function
                if (k == j_pert) then
                    deltaf = 1.0
                else
                    deltaf = 0.0
                endif

                tten(i,k,j) = 0.5 * &
                         ( TtendAmp/86400 * & ! 86400 is number of s in a day
                         ( deltaf + exp(-((p(i,k,j)-p(i,j_pert,j))/7500.)**2. )))
                              

                thten(i,k,j) = thten(i,k,j) + (tten(i,k,j) / pi(i,k,j)) ! convert dT/dt to theta tendency
                
             enddo
          enddo
      enddo

  endif


  if ( perturb_q_flag .eqv. .true.) then

      call wrf_debug ( 50, "Perturb Q tendency" )

      do i = its,ite
         do k = kts,kte
            do j = jts,jte

                ! Delta function
                if (k == j_pert) then
                    deltaf = 1.0
                else
                    deltaf = 0.0
                endif

                qten(i,k,j) = 0.5 * &
                              ( QtendAmp/86400 * & ! 86400 is number of s in a day
                              ( deltaf + exp(-((p(i,k,j)-p(i,j_pert,j))/7500.)**2. )))

                qvten(i,k,j) = qvten(i,k,j) + qten(i,k,j)

             enddo
          enddo
      enddo

  endif

   end subroutine force_LRF

end module module_force_lrf
