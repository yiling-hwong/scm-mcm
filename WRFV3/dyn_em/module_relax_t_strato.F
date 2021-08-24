module module_relax_t_strato
 
   ! AUTHOR: Yi-Ling Hwong (CCRC)
   ! DESCRIPTION: Relax stratospheric T profile for PreRCE run 

contains

   subroutine relax_t_strato(t_strato_target,tau_relax_t_strato        &
                             ,t_phy,rthblten,p_hyd                     &
                             ,pi                                       &
                             ,ims,ime,jms,jme,kms,kme                  &
                             ,its,ite,jts,jte,kts,kte                  &
                             )

    implicit none
 
    integer, intent(in) :: ims,ime,jms,jme,kms,kme     
    integer, intent(in) :: its,ite,jts,jte,kts,kte

    real, dimension( ims:ime, kms:kme, jms:jme ),         &
          intent(inout)  ::                        t_phy  
    
    real, dimension( ims:ime, kms:kme, jms:jme ),         &
          intent(in)  ::                           p_hyd, pi

    integer, intent(in) ::                         tau_relax_t_strato
    real, intent(in)  ::                           t_strato_target

    real, dimension( ims:ime, kms:kme, jms:jme ),            &
          intent(inout)  ::                        rthblten  

    ! local vars
    integer                                        :: i,j,k
    real, dimension( ims:ime, kms:kme, jms:jme )   :: rtau, t_tend
    character (len=1000)                           :: message ! YLH 

    call wrf_debug( 50, "Relax strato T (PreRCE)")
  
    do j=jts,jte
       do k=kts,kte
          do i=its,ite

             if (p_hyd(i,k,j) .ge. 10000) then

                t_tend(i,k,j) = 0.0

             else

                t_tend(i,k,j) = -(t_phy(i,k,j) - t_strato_target) / tau_relax_t_strato

             endif

             rthblten(i,k,j) = rthblten(i,k,j) + (t_tend(i,k,j) / pi(i,k,j))

          enddo
       enddo
    enddo

   end subroutine relax_t_strato 


end module module_relax_t_strato  


