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
  real                                     :: sum_var_hor_u,sum_var_hor_v
  real                                     :: count_hor
  real,dimension( kts:kte )                :: var_hor_average_u,var_hor_average_v
  character (len=256)                      :: message  
  
  call wrf_debug ( 50, "Relax U and V winds" )

  do k = kts, kte

     sum_var_hor_u = 0.
     sum_var_hor_v = 0.
     count_hor = 0.

     ! Get mean wind
     do j = jts, jte
         do i = its, ite
             sum_var_hor_u = sum_var_hor_u + u(i,k,j)
             sum_var_hor_v = sum_var_hor_v + v(i,k,j)
             count_hor = count_hor + 1
         end do
     end do

     var_hor_average_u(k) = sum_var_hor_u / count_hor
     var_hor_average_v(k) = sum_var_hor_v / count_hor

     do j=jts,jte
         do i=its,ite

             u_tend(i,k,j) = -(var_hor_average_u(k) - u_target) / tau_relax_winds
             v_tend(i,k,j) = -(var_hor_average_v(k) - v_target) / tau_relax_winds

             uten(i,k,j) = uten(i,k,j) + u_tend(i,k,j)
             vten(i,k,j) = vten(i,k,j) + v_tend(i,k,j)

         enddo
     enddo

  enddo

      !do i = its,ite
      !   do k = kts+1,kte
      !      do j = jts,jte
      !         
      !         u_tend(i,k,j) = -(u(i,k,j) - u_target) / tau_relax_winds 
      !         v_tend(i,k,j) = -(v(i,k,j) - v_target) / tau_relax_winds
      !         
      !         uten(i,k,j) = uten(i,k,j) + u_tend(i,k,j)
      !         vten(i,k,j) = vten(i,k,j) + v_tend(i,k,j)
      !         
      !      enddo  
      !   enddo
      !enddo

  end subroutine relax_winds

end module module_relax_winds
