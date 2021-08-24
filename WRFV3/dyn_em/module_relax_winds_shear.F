module module_relax_winds_shear
 
   ! AUTHOR: Yi-Ling Hwong (CCRC)
   ! DESCRIPTION: relax wind to a profile read in from file
   ! to study impact of wind shear on convection

contains

    subroutine relax_winds_shear(relax_u_shear_flag                   &
                                 ,relax_v_shear_flag                  &
                                 ,tau_relax_winds_shear               &
                                 ,uten,vten,u,v                       &
                                 ,ims,ime,jms,jme,kms,kme             &
                                 ,its,ite,jts,jte,kts,kte             &
                                )

    implicit none
 
    logical, intent(in)                                     :: relax_u_shear_flag ! switch to relax winds shear
    logical, intent(in)                                     :: relax_v_shear_flag ! switch to relax winds shear
    integer, intent(in)                                     :: tau_relax_winds_shear ! relaxation timescale 
    real, dimension(ims:ime,kms:kme,jms:jme), intent(in)    :: u,v
    real, dimension(ims:ime,kms:kme,jms:jme), intent(inout) :: uten,vten

    integer, intent(in) :: ims,ime,jms,jme,kms,kme     
    integer, intent(in) :: its,ite,jts,jte,kts,kte
                       

    ! local vars
    integer                                  :: i,j,k
    real,dimension(ims:ime,kms:kme,jms:jme)  :: u_tend,v_tend
    real,dimension(kte)                      :: target_wind_u, target_wind_v
    character (len=256)                      :: message

    if ( relax_u_shear_flag .eqv. .true. ) then

        call wrf_debug( 50, "Relax U wind shear")
  
        ! read in target wind profile
        call read_input(kte,target_wind_u,target_wind_v)


        do j=jts,jte
           do k=kts,kte
              do i=its,ite

                  u_tend(i,k,j) = -(u(i,k,j) - target_wind_u(k)) / tau_relax_winds_shear
                  uten(i,k,j) = uten(i,k,j) + u_tend(i,k,j)

              enddo
           enddo
        enddo

    endif


    if ( relax_v_shear_flag .eqv. .true. ) then

        call wrf_debug( 50, "Relax V wind shear")

        ! read in target wind profile
        call read_input(kte,target_wind_u,target_wind_v)


        do j=jts,jte
           do k=kts,kte
              do i=its,ite

                  v_tend(i,k,j) = -(v(i,k,j) - target_wind_v(k)) / tau_relax_winds_shear
                  vten(i,k,j) = vten(i,k,j) + v_tend(i,k,j)              

              enddo
           enddo
        enddo

    endif

    end subroutine relax_winds_shear


    subroutine read_input(kte,u_val,v_val)

    implicit none
    integer, intent(in)                  :: kte
    real, dimension(kte), intent(inout)  :: u_val,v_val

    ! local vars
    integer                              :: k
    logical                              :: end_of_file
 
    ! read u profile

    open(unit=10,file='u_shear_profile',form='formatted',status='old')
    rewind(10)

    end_of_file = .false.
    k = 1

    do while(.not. end_of_file)

        if (k .gt. kte) then

            end_of_file = .true.

        else if (k .le. kte) then

            read(10,*) u_val(k)
            k = k+1

        end if

    enddo

    close(unit=10,status='keep')

    ! read v profile

    open(unit=10,file='v_shear_profile',form='formatted',status='old')
    rewind(10)

    end_of_file = .false.
    k = 1

    do while(.not. end_of_file)

        if (k .gt. kte) then

            end_of_file = .true.

        else if (k .le. kte) then

            read(10,*) v_val(k)
            k = k+1

        end if

    enddo

    close(unit=10,status='keep')


    end subroutine read_input


end module module_relax_winds_shear  


