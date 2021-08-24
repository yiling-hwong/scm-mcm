module module_relax_t_qv_strato
 
   ! AUTHOR: Yi-Ling Hwong (CCRC)
   ! DESCRIPTION: add temp. and moisture relaxation at top of troposphere
   ! based on Herman and Kuang (2013), relaxation tau based on Figure 1

contains

   subroutine relax_t_qv_strato(t_phy,qv                     &
                                ,rthblten,rqvblten,p_hyd,dt  &
                                ,pi                          &
                                ,ims,ime,jms,jme,kms,kme     &
                                ,its,ite,jts,jte,kts,kte     &
                               )       

    implicit none
 
    integer, intent(in) :: ims,ime,jms,jme,kms,kme     
    integer, intent(in) :: its,ite,jts,jte,kts,kte

    real, dimension( ims:ime, kms:kme, jms:jme ),         &
          intent(inout)  ::                        t_phy  &
                                                  ,qv    
    
    real, dimension( ims:ime, kms:kme, jms:jme ),         &
          intent(in)  ::                           p_hyd, pi

    real, intent(in)  ::                           dt

    real, dimension( ims:ime, kms:kme, jms:jme ),            &
          intent(inout)  ::                        rthblten  &
                                                  ,rqvblten


    ! local vars
    integer                                        :: i,j,k
    real, dimension( ims:ime, kms:kme, jms:jme )   :: rtau, relaxt, relaxq
    real, dimension( kte )                         :: t_obs, qv_obs
    character (len=1000)                           :: message  

    call wrf_debug( 50, "Relax T and QV to PreRCE values")
  
    ! read in t_obs and qv_obs
    call read_input(kte,t_obs,qv_obs)


    do j=jts,jte
       do k=kts,kte
          do i=its,ite

             if (p_hyd(i,k,j) .ge. 16000) then

                rtau(i,k,j) = 0.0
                relaxt(i,k,j) = 0.0
                relaxq(i,k,j) = 0.0

             else if (p_hyd(i,k,j) .le. 10000) then

                rtau(i,k,j) = 1/0.5
                relaxt(i,k,j) = -(t_phy(i,k,j) - t_obs(k))/(rtau(i,k,j)*24*3600)
                relaxq(i,k,j) = -(qv(i,k,j) - qv_obs(k))/(rtau(i,k,j)*24*3600)

             else

                rtau(i,k,j) = 6000/((16000 - p_hyd(i,k,j))*(0.5))
                relaxt(i,k,j) = -(t_phy(i,k,j) - t_obs(k))/(rtau(i,k,j)*24*3600)
                relaxq(i,k,j) = -(qv(i,k,j) - qv_obs(k))/(rtau(i,k,j)*24*3600)

             endif

             rthblten(i,k,j) = rthblten(i,k,j) + (relaxt(i,k,j) / pi(i,k,j))
             rqvblten(i,k,j) = rqvblten(i,k,j) + relaxq(i,k,j)

          enddo
       enddo
    enddo

   end subroutine relax_t_qv_strato 


   subroutine read_input(kte,t_val,qv_val)

      implicit none
      integer, intent(in)                  :: kte
      real, dimension(kte), intent(inout)  :: t_val,qv_val

      ! local vars
      integer                              :: k
      logical                              :: end_of_file
 
    ! read t_obs

    open(unit=10,file='t_obs',form='formatted',status='old')
    rewind(10)

    end_of_file = .false.
    k = 1

    do while(.not. end_of_file)

        if (k .gt. kte) then

            end_of_file = .true.

        else if (k .le. kte) then

            read(10,*) t_val(k)
            k = k+1

        end if

    enddo

    close(unit=10,status='keep')

    ! read qv_obs

    open(unit=10,file='qv_obs',form='formatted',status='old')
    rewind(10)

    end_of_file = .false.
    k = 1

    do while(.not. end_of_file)

        if (k .gt. kte) then

            end_of_file = .true.

        else if (k .le. kte) then

            read(10,*) qv_val(k)
            k = k+1

        end if

    enddo

    close(unit=10,status='keep')


   end subroutine read_input


end module module_relax_t_qv_strato 


