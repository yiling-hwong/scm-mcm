module module_ideal_radiation

! AUTHOR: Yi-Ling Hwong (CCRC)
! Implements constant radiative cooling profile
! To implement Herman & Kuang (2013) Linear Response Function (LRF)

CONTAINS
  
  subroutine fix_radiation(p_hyd, pi_phy, rthraten                 & 
                           , ims, ime, jms, jme, kms, kme          &                  
                           , its, ite, jts, jte, kts, kte          &                                        
                           )
  
  implicit none
  
  real, dimension(ims:ime,kms:kme,jms:jme), intent(in)    :: p_hyd,pi_phy
  real, dimension(ims:ime,kms:kme,jms:jme), intent(inout) :: rthraten
  integer, intent(in)                                     :: ims,ime,jms,jme,kms,kme, &  
                                                             its,ite,jts,jte,kts,kte  

  ! local vars
  integer                                  :: i,j,k
  real                                     :: t_tend
  character (len=256)                      :: message  
  
  call wrf_debug ( 50, " Ideal fixed radiation profile " )



  do j = jts,jte
     do k = kts,kte
        do i = its,ite
           
             !print *, "i,k,j", i,k,j 

             if (p_hyd(i,k,j) .ge. 20000) then
                 t_tend = -1.5/86400
             else if (p_hyd(i,k,j) .le. 10000) then
                 t_tend = 0.0
             else
                 t_tend = -((1.5*p_hyd(i,k,j)/10000 - 1.5) / 86400)
             endif

             rthraten(i,k,j)=t_tend/pi_phy(i,k,j) ! convert from temp tend to theta tend              


        enddo  
     enddo
  enddo

  end subroutine fix_radiation

end module module_ideal_radiation
