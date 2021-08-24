module module_relax_winds

! AUTHOR: Yi-Ling Hwong (CCRC)
! Relax U and V wind to target values 

CONTAINS
  
  subroutine relax_winds(tau_relax_winds, u_target, v_target     & 
                         , uten, vten, u, v                      &
                         , ims, ime, jms, jme, kms, kme          &
                         , its, ite, jts, jte, kts, kte          &                                        
                         )
                         
  
  implicit none
  
  integer, intent(in)                                     :: tau_relax_winds ! relaxation timescale in seconds
  real, intent(in)                                        :: u_target, v_target ! target domain mean wind speed
  real, dimension(ims:ime,kms:kme,jms:jme), intent(in)    :: u,v
  real, dimension(ims:ime,kms:kme,jms:jme), intent(inout) :: uten,vten
  integer, intent(in)                                     :: ims,ime,jms,jme,kms,kme, &  
                                                             its,ite,jts,jte,kts,kte  

  ! local vars
  integer                                  :: i,j,k
  real,dimension(ims:ime,kms:kme,jms:jme)  :: u_tend,v_tend
  character (len=256)                      :: message  
  
  call wrf_debug ( 50, "Relax U and V winds" )

      do i = its,ite
         do k = kts+1,kte
            do j = jts,jte
               
               u_tend(i,k,j) = -(u(i,k,j) - u_target) / tau_relax_winds 
               v_tend(i,k,j) = -(v(i,k,j) - v_target) / tau_relax_winds
               
               uten(i,k,j) = uten(i,k,j) + u_tend(i,k,j)
               vten(i,k,j) = vten(i,k,j) + v_tend(i,k,j)
               
            enddo  
         enddo
      enddo

  end subroutine relax_winds

end module module_relax_winds
