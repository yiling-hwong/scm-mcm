module module_homogenise_qv
 
   ! AUTHORS: Yi-Ling HWONG & Maxime COLIN (CCRC)
   ! DESCRIPTION: relax QVAPOR to domain mean

contains

    subroutine homogenise_qv(tau_homogenise_qv                    &
                             ,qvten,qvapor                        &
                             ,qv_tend_curr                        &
                             ,ims,ime,jms,jme,kms,kme             &
                             ,its,ite,jts,jte,kts,kte             &
                            )   

    implicit none
 
    integer, intent(in)                                     :: tau_homogenise_qv ! relaxation timescale 
    real, dimension(ims:ime,kms:kme,jms:jme), intent(in)    :: qvapor
    real, dimension(ims:ime,kms:kme,jms:jme), intent(inout) :: qvten,qv_tend_curr

    integer, intent(in) :: ims,ime,jms,jme,kms,kme     
    integer, intent(in) :: its,ite,jts,jte,kts,kte
                       

    ! local vars
    integer                                  :: i,j,k
    character (len=256)                      :: message

    real ::  sum_var_hor
    real ::  count_hor
    real, dimension( kts:kte ) :: var_hor_average

    call wrf_debug( 50, "Homogenise free tropospheric QVAPOR")

    DO k = 16, kte
        sum_var_hor = 0.
        count_hor = 0.

        DO j = jts, jte  !jts , jte
        DO i = its, ite  !its , ite
           sum_var_hor = sum_var_hor + qvapor(i,k,j)
           count_hor = count_hor + 1.
        END DO
        END DO

        var_hor_average(k) = sum_var_hor / count_hor

        !call wrf_debug( 50, "count_hor,horizontal avg:")
        !write(message, *) &
        !k, count_hor, var_hor_average(k)
        !call wrf_debug(50, message)

        DO j = jts, jte  !jts , jte
        DO i = its, ite  !its , ite
           qv_tend_curr(i,k,j) =  - ( qvapor(i,k,j)  - var_hor_average(k) )  / tau_homogenise_qv
           qvten(i,k,j) = qvten(i,k,j) + qv_tend_curr(i,k,j)
        END DO
        END DO

    END DO


    end subroutine homogenise_qv

end module module_homogenise_qv 


