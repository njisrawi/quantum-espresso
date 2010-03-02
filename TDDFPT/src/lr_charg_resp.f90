!!----------------------------------------------------------------------------
MODULE charg_resp
!
! This module contains charge response calculation related variables & subroutines. 
! Osman Baris Malcioglu 2009 
!
  !----------------------------------------------------------------------------
  use kinds,                only : dp
  use lr_variables,         only : lr_verbosity
  USE io_global,                ONLY : ionode, stdout,ionode_id
  character(len=256) :: w_T_prefix !prefix for storage of previous calculation
  integer :: w_T_npol ! number of polarization directions considered in previous run
  real(kind=dp), allocatable :: &  ! the required parts of the lanczos matrix for w_T (iter)
       w_T_beta_store(:),&
       w_T_gamma_store(:)
  real(kind=dp), allocatable :: w_T (:)          ! The solution to (omega-T) (iter)
  real(kind=dp) :: omeg                          !frequencies for calculating charge response
  real(kind=dp) :: epsil                         !Broadening    

CONTAINS
!-----------------------------------------------------------------------
subroutine read_wT_beta_gamma_z()
  !---------------------------------------------------------------------
  ! ... reads beta_gamma_z from a previous calculation for the given polarization direction pol
  !---------------------------------------------------------------------
  !
  use mp,                   only : mp_bcast, mp_barrier
  use lr_variables,         only : LR_polarization, itermax
  use mp_global,                ONLY : inter_pool_comm, intra_pool_comm
  use io_files,                 ONLY : trimcheck
  !
  implicit none
  ! 
  !
  character(len=6), external :: int_to_char
  ! local
  logical :: exst
  integer :: iter_restart,i,j
  character(len=256) :: filename
  real(kind=dp) :: discard
  complex(kind=dp), allocatable :: discard2(:)

 CALL start_clock( 'post-processing' )
 if (lr_verbosity > 5) WRITE(stdout,'("<read_wT_beta_gamma_z>")')
#ifdef __PARA
  if (ionode) then
#endif
         
         !
         !
         !if (.not. allocated(w_T_beta_store)) print *, "aaaaaaaaaaaaaa"
         filename = trim(w_T_prefix) // trim(int_to_char(LR_polarization))
         !
         inquire (file = filename, exist = exst)
         !
         if (.not.exst) call errore(' lr_main ','Lanczos coefficents not found ',1)
         !
         !
         open (158, file = filename, form = 'formatted', status = 'old')
         inquire (file = filename, opened = exst)
         if (.not.exst) call errore(' lr_main ','Lanczos coefficents can not be opened ',1)
         !
         WRITE(stdout,'("Reading Pre-calculated lanczos coefficents from ",A50)') filename
         allocate(discard2(w_T_npol))
         !
         read(158,*,end=301,err=302) iter_restart
         !print *,iter_restart
         !write(stdout,'(/,5X,"Reading of precalculated Lanczos Matrix")')
         if (iter_restart < itermax) call errore ('read_beta_gamma_z', 'Lanczos iteration mismatch', 1 )
         !
  if (.not. allocated(w_T_beta_store))  allocate(w_T_beta_store(iter_restart))
  if (.not. allocated(w_T_gamma_store))  allocate(w_T_gamma_store(iter_restart))
         read(158,*,end=301,err=303) discard
         !print *, discard
         !
         !write(stdout,'("--------------Lanczos Matrix-------------------")')
         do i=1,itermax
         !
          !print *, "Iter=",i
          read(158,*,end=301,err=303) w_T_beta_store(i)
          !print *, w_T_beta_store(i)
          read(158,*,end=301,err=303) w_T_gamma_store(i)
          !print *, w_T_gamma_store(i)
          read(158,*,end=301,err=303) discard2(:)
          !print *, discard2(:)
         !
         enddo
         !print *, "closing file"
         !
         close(158)
         !
         deallocate(discard2)
         !print *, "starting broadcast"
#ifdef __PARA
         end if
         call mp_barrier()
         call mp_bcast (w_T_beta_store(:), ionode_id)
         call mp_bcast (w_T_gamma_store(:), ionode_id)
#endif 
         !print *, "broadcast complete"
CALL stop_clock( 'post-processing' )
         return
         301 call errore ('read_beta_gamma_z', 'File is corrupted, no data', i ) 
         302 call errore ('read_beta_gamma_z', 'File is corrupted, itermax not found', 1 )
         303 call errore ('read_beta_gamma_z', 'File is corrupted, data number follows:', i )
end subroutine read_wT_beta_gamma_z
!-----------------------------------------------------------------------
subroutine lr_calc_w_T()
  !---------------------------------------------------------------------
  ! ... calculates the w_T from equation (\freq - L ) e_1 
  ! ... by solving tridiagonal problem for each value of freq
  !---------------------------------------------------------------------
  !
  use lr_variables,         only : itermax,beta_store,gamma_store
  USE lr_variables,         ONLY : LR_polarization,charge_response, n_ipol
  use gvect,                only : nrxx,nr1,nr2,nr3

  !
  implicit none
  !
  !integer, intent(in) :: freq ! Input : The frequency identifier (1 o 5) for w_T
  complex(kind=dp), allocatable :: a(:), b(:), c(:),r(:)
  real(kind=dp) :: norm
  !
  integer :: i, info !used for error reporting 
  !Solver:
  real(kind=dp), external :: ddot
  !
 CALL start_clock( 'post-processing' )
  If (lr_verbosity > 5) THEN
    WRITE(stdout,'("<lr_calc_w_T>")')
  endif
  if (omeg == 0.D0) return
  !
  allocate(a(itermax))
  allocate(b(itermax-1))
  allocate(c(itermax-1))
  allocate(r(itermax))
  ! 
  a(:) = (0.0d0,0.0d0)
  b(:) = (0.0d0,0.0d0)
  c(:) = (0.0d0,0.0d0)
  w_T(:) = 0.0d0
  !
  write(stdout,'(/,5X,"Calculation of Response coefficients")')
  !
  !
     !
        ! prepare tridiagonal (w-L) for the given polarization
        !
        a(:) = cmplx(omeg,epsil,dp)
        !
        if (charge_response == 1) then
        do i=1,itermax-1
           !
           !Memory mapping in case of selected polarization direction
           info=1
           if ( n_ipol /= 1 ) info=LR_polarization
           !
           b(i)=-beta_store(info,i)
           c(i)=-gamma_store(info,i)
           !
        end do
        endif
        if (charge_response == 2) then
        do i=1,itermax-1
           !
           !b(i)=-w_T_beta_store(i)
           !c(i)=-w_T_gamma_store(i)
           b(i)=cmplx(-w_T_beta_store(i),0.0d0,dp)
           c(i)=cmplx(-w_T_gamma_store(i),0.0d0,dp)
           !
        end do
        endif
        ! 
        r(:) =(0.0d0,0.0d0)
        r(1)=(1.0d0,0.0d0)
 
        !
        ! solve the equation
        !
        call zgtsv(itermax,1,b,a,c,r(:),itermax,info)
        if(info /= 0) call errore ('calc_w_T', 'unable to solve tridiagonal system', 1 )
        w_t(:)=ABS(r(:))
        !
        ! normalize so that the final charge densities are normalized
        !
        norm=ddot(itermax,w_T(:),1,w_T(:),1)
        write(stdout,'(/,5X,"Charge Response renormalization factor: ",E15.5)') norm 
        !w_T(:)=w_T(:)/norm
        !norm=sum(w_T(:))
  !write(stdout,'(3X,"Initial sum of lanczos vectors",F8.5)') norm
        !w_T(:)=w_T(:)/norm
     !
  !
  deallocate(a)
  deallocate(b)
  deallocate(c)
  !
  if ( lr_verbosity > 0 ) then
  write(stdout,'("--------Lanczos weight coefficients in the direction ",I1," for freq=",D15.8," Ry ----------")') LR_polarization, omeg
  do i=1,itermax
   write(stdout,'(I5,3X,D15.8)') i, w_T(i)
  enddo
  write(stdout,'("------------------------------------------------------------------------")')
  write(stdout,'("NR1=",I5," NR2=",I5," NR3=",I5)') nr1, nr2, nr3
  write(stdout,'("------------------------------------------------------------------------")')
  endif
CALL stop_clock( 'post-processing' )
  return
  !
end subroutine lr_calc_w_T
!-----------------------------------------------------------------------
subroutine lr_dump_rho_tot_compat1()
  !-----------------------------------------------------------------------
  ! dump a density file in a format compatible to type 1 charge response calculation
  !-----------------------------------------------------------------------
  USE io_files,              ONLY : prefix
  USE lr_variables,          ONLY : rho_1_tot, LR_polarization, LR_iteration, cube_save
  use gvect,                    only : nrxx,gstart,nr1,nr2,nr3
  use mp_global,                ONLY : inter_pool_comm, intra_pool_comm
 
  IMPLICIT NONE
  character(len=6), external :: int_to_char
  !
  !Local
  CHARACTER (len=80):: filename
  real(kind=dp), allocatable :: rho_sum_resp_x(:),rho_sum_resp_y(:),rho_sum_resp_z(:)
  integer ir,i,j,k
 CALL start_clock( 'post-processing' )
 if (lr_verbosity > 5) WRITE(stdout,'("<lr_dump_rho_tot_compat1>")')
#ifdef __PARA
     if (ionode) then
#endif
    !
     if ( .not. allocated(cube_save) ) call lr_set_boxes_density()
     ALLOCATE( rho_sum_resp_x( nr1 ) )
     ALLOCATE( rho_sum_resp_y( nr2 ) )
     ALLOCATE( rho_sum_resp_z( nr3 ) )
     !
     rho_sum_resp_x = 0.D0
     rho_sum_resp_y = 0.D0
     rho_sum_resp_z = 0.D0
     !
     DO ir=1,nrxx
        !
        i=cube_save(ir,1)+1
        j=cube_save(ir,2)+1
        k=cube_save(ir,3)+1
        !
        rho_sum_resp_x(i)=rho_sum_resp_x(i)+rho_1_tot(ir,1)
        rho_sum_resp_y(j)=rho_sum_resp_y(j)+rho_1_tot(ir,1)
        rho_sum_resp_z(k)=rho_sum_resp_z(k)+rho_1_tot(ir,1)
        !
     END DO
     !
     !
     filename = trim(prefix) // "-summed-density-pol" //trim(int_to_char(LR_polarization))// "_x" 
     !
     open (158, file = filename, form = 'formatted', status = 'unknown', position = 'append')
     !
     do i=1,nr1
        write(158,*) rho_sum_resp_x(i)
     end do
     !
     close(158)
     !
     filename = trim(prefix) // "-summed-density-pol" //trim(int_to_char(LR_polarization))// "_y" 
     !
     open (158, file = filename, form = 'formatted', status = 'unknown', position = 'append')
     !
     do i=1,nr2
        write(158,*) rho_sum_resp_y(i)
     end do
     !
     close(158)
     !
     filename = trim(prefix) // "-summed-density-pol" //trim(int_to_char(LR_polarization))// "_z" 
     !
     open (158, file = filename, form = 'formatted', status = 'unknown', position = 'append')
     !
     do i=1,nr3
        write(158,*) rho_sum_resp_z(i)
     end do
     !
     close(158)
     DEALLOCATE( rho_sum_resp_x )
     DEALLOCATE( rho_sum_resp_y )
     DEALLOCATE( rho_sum_resp_z )
    !
#ifdef __PARA
     end if
#endif
CALL stop_clock( 'post-processing' )
     !
!-----------------------------------------------------------------------
end subroutine lr_dump_rho_tot_compat1
!-----------------------------------------------------------------------
subroutine lr_dump_rho_tot_cube(rho,identifier)
  !-----------------------------------------------------------------------
  ! dump a density file in the gaussian cube format. "Inspired" by 
  ! Modules/cube.f90 :)
  !-----------------------------------------------------------------------
  USE io_files,              ONLY : prefix
  USE lr_variables,          ONLY : LR_polarization, LR_iteration, cube_save
  use gvect,                    only : nrxx,gstart,nr1,nr2,nr3,nrx1,nrx2,nrx3
  use cell_base
  USE ions_base,                ONLY : nat, ityp, atm, ntyp => nsp, tau
  use mp,                   only : mp_barrier, mp_sum, mp_bcast, mp_get
  USE mp_global,            ONLY : me_image, intra_image_comm, me_pool, nproc_pool, &
                            intra_pool_comm, my_pool_id
  
  USE constants,            ONLY : BOHR_RADIUS_ANGS
  USE fft_base,             ONLY : dfftp !this contains dfftp%npp (number of z planes per processor
                                           ! and dfftp%ipp (offset of the first z plane of the processor

  !
  IMPLICIT NONE
  !
  real (kind=dp), intent(in)   :: rho(:)
  CHARACTER(len=10), intent(in) :: identifier
  !
  CHARACTER(len=80) :: filename
  !
  character(len=6), external :: int_to_char
  !
  !Local
  integer          :: i, nt, i1, i2, i3, at_num, iopool_id, ldr, kk, ionode_pool, six_count
  real(DP)    :: at_chrg, tpos(3), inpos(3)
  REAL(DP), ALLOCATABLE :: rho_plane(:),rho_temp(:)
  INTEGER,  ALLOCATABLE :: kowner(:)
  !
  integer, external:: atomic_number
    ! 
 
 CALL start_clock( 'post-processing' )
 if (lr_verbosity > 5) WRITE(stdout,'("<lr_dump_rho_tot_cube>")')
  !
 six_count=0
#ifdef __PARA
   ALLOCATE( rho_temp(dfftp%npp(1)+1) )
   if (ionode) then
       filename = trim(prefix) // "-" // identifier // "-pol" //trim(int_to_char(LR_polarization))// ".cube"
       write(stdout,'(5X,"Writing Cube file for response charge density")') 
       !write(stdout, *) filename
       !write(stdout,'(5X,"|rho|=",D15.8)') rho_sum
       open (158, file = filename, form = 'formatted', status = 'replace', err=501)

!C     WRITE A FORMATTED 'DENSITY-STYLE' CUBEFILE VERY SIMILAR
!C     TO THOSE CREATED BY THE GAUSSIAN PROGRAM OR THE CUBEGEN UTILITY.
!C     THE FORMAT IS AS FOLLOWS (LAST CHECKED AGAINST GAUSSIAN 98):
!C
!C     LINE   FORMAT      CONTENTS
!C     ===============================================================
!C      1     A           TITLE
!C      2     A           DESCRIPTION OF PROPERTY STORED IN CUBEFILE
!C      3     I5,3F12.6   #ATOMS, X-,Y-,Z-COORDINATES OF ORIGIN
!C      4-6   I5,3F12.6   #GRIDPOINTS, INCREMENT VECTOR
!C      #ATOMS LINES OF ATOM COORDINATES:
!C      ...   I5,4F12.6   ATOM NUMBER, CHARGE, X-,Y-,Z-COORDINATE
!C      REST: 6E13.5      CUBE DATA
!C
!C     ALL COORDINATES ARE GIVEN IN ATOMIC UNITS.

         write(158,*) 'Cubfile created from TDDFPT calculation'
         write(158,*) identifier
         !                        origin is forced to (0.0,0.0,0.0)
         write(158,'(I5,3F12.6)') nat, 0.0d0, 0.0d0, 0.0d0
         write(158,'(I5,3F12.6)') nr1, (alat*at(i,1)/DBLE(nr1),i=1,3)
         write(158,'(I5,3F12.6)') nr2, (alat*at(i,2)/DBLE(nr2),i=1,3)
         write(158,'(I5,3F12.6)') nr3, (alat*at(i,3)/DBLE(nr3),i=1,3)
        
         do i=1,nat
            nt = ityp(i)
            ! find atomic number for this atom. 
            at_num = atomic_number(TRIM(atm(nt)))
            at_chrg= DBLE(at_num)
            ! at_chrg could be alternatively set to valence charge
            ! positions are in cartesian coordinates and a.u.
            !
            ! wrap coordinates back into cell.
            tpos = MATMUL( TRANSPOSE(bg), tau(:,i) )
            tpos = tpos - NINT(tpos - 0.5d0)
            inpos = alat * MATMUL( at, tpos )
            write(158,'(I5,5F12.6)') at_num, at_chrg, inpos
         enddo
   endif
! Header is complete, now dump the charge density, as derived from xyzd subroutine
         ALLOCATE( rho_plane( nrx3 ) )
         !ALLOCATE( kowner( nr3 ) ) 
        !
        ! ... find the index of the pool that will write rho
        !
        IF ( ionode ) iopool_id = my_pool_id
        !
        CALL mp_bcast( iopool_id, ionode_id, intra_image_comm )
        !
        ! ... find the index of the ionode within its own pool
        !
        IF ( ionode ) ionode_pool = me_pool
        !
        CALL mp_bcast( ionode_pool, ionode_id, intra_image_comm )
        !
        ! ... find out the owner of each "z" plane
        !
        !
        !IF (nproc_pool > 1) THEN
        ! DO i = 1, nproc_pool
        !    !
        !    kowner( (dfftp%ipp(i)+1):(dfftp%ipp(i)+dfftp%npp(i)) ) = i - 1
        !    !
        ! END DO
        !ELSE
        ! kowner = ionode_id
        !ENDIF
        ldr = nrx1*nrx2
      !
      !
      ! Each processor is on standby to send its plane to ionode
      DO i1 = 1, nr1
         !
         DO i2 = 1, nr2
            ! 
            !Parallel gather of Z plane
            rho_plane(:)=0
            DO i = 1, nproc_pool
                rho_temp(:)=0
                IF( (i-1) == me_pool ) THEN
                   !
                   !
                   DO  i3=1, dfftp%npp(i)
                         !
                         rho_temp(i3) = rho(i1+(i2-1)*nrx1+(i3-1)*ldr)
                         !
                      !
                   END DO
                   !print *, "get 1=",rho_plane(1)," 2=",rho_plane(2)," ",dfftp%npp(i),"=",rho_plane(dfftp%npp(i))
                 END IF
                 !call mp_barrier()
                 IF ( my_pool_id == iopool_id ) & 
                   !Send plane to ionode
                   ! Send and recieve rho_plane, 
                   CALL mp_get( rho_temp, rho_temp, &
                                                 me_pool, ionode_pool, (i-1), i-1, intra_pool_comm )

                   !
                 !call mp_barrier()
                   IF(ionode) then 
                    rho_plane( (dfftp%ipp(i)+1):(dfftp%ipp(i)+dfftp%npp(i)) ) = rho_temp(1:dfftp%npp(i))
                   !print *, "get (",dfftp%ipp(i)+1,")=",rho_plane(dfftp%ipp(i)+1)," (",dfftp%ipp(i)+dfftp%npp(i),")=",rho_plane(dfftp%ipp(i)+dfftp%npp(i))
                   !print *, "data of proc ",i," written I2=",i2,"I1=",i1
                   END IF
             END DO
             ! End of parallel send
             IF (ionode) then
             DO  i3=1, nr3
                 six_count=six_count+1
                 write(158,'(E13.5)',advance='no') rho_plane(i3)
                 if (six_count == 6 ) then 
                      write(158,'("")')
                         six_count=0
                 endif
                 !print *, rho_plane(i3)
             ENDDO
             ENDIF
             call mp_barrier()
         END DO
      END DO
      !
      DEALLOCATE( rho_plane )
      DEALLOCATE( rho_temp )

     if (ionode) close(158)
  
     call mp_barrier()

#else
   ! 
     !
     
     filename = trim(prefix) // "-" // identifier // "-pol" //trim(int_to_char(LR_polarization))// ".cube"
     write(stdout,'(5X,"Writing Cube file for response charge density")') 
     !write(stdout, *) filename
     !write(stdout,'(5X,"|rho|=",D15.8)') rho_sum
     open (158, file = filename, form = 'formatted', status = 'replace', err=501)

!C     WRITE A FORMATTED 'DENSITY-STYLE' CUBEFILE VERY SIMILAR
!C     TO THOSE CREATED BY THE GAUSSIAN PROGRAM OR THE CUBEGEN UTILITY.
!C     THE FORMAT IS AS FOLLOWS (LAST CHECKED AGAINST GAUSSIAN 98):
!C
!C     LINE   FORMAT      CONTENTS
!C     ===============================================================
!C      1     A           TITLE
!C      2     A           DESCRIPTION OF PROPERTY STORED IN CUBEFILE
!C      3     I5,3F12.6   #ATOMS, X-,Y-,Z-COORDINATES OF ORIGIN
!C      4-6   I5,3F12.6   #GRIDPOINTS, INCREMENT VECTOR
!C      #ATOMS LINES OF ATOM COORDINATES:
!C      ...   I5,4F12.6   ATOM NUMBER, CHARGE, X-,Y-,Z-COORDINATE
!C      REST: 6E13.5      CUBE DATA
!C
!C     ALL COORDINATES ARE GIVEN IN ATOMIC UNITS.

  write(158,*) 'Cubfile created from TDDFPT calculation'
  write(158,*) identifier
!                        origin is forced to (0.0,0.0,0.0)
  write(158,'(I5,3F12.6)') nat, 0.0d0, 0.0d0, 0.0d0
  write(158,'(I5,3F12.6)') nr1, (alat*at(i,1)/DBLE(nr1),i=1,3)
  write(158,'(I5,3F12.6)') nr2, (alat*at(i,2)/DBLE(nr2),i=1,3)
  write(158,'(I5,3F12.6)') nr3, (alat*at(i,3)/DBLE(nr3),i=1,3)

  do i=1,nat
     nt = ityp(i)
     ! find atomic number for this atom. 
     at_num = atomic_number(TRIM(atm(nt)))
     at_chrg= DBLE(at_num)
     ! at_chrg could be alternatively set to valence charge
     ! positions are in cartesian coordinates and a.u.
     !
     ! wrap coordinates back into cell.
     tpos = MATMUL( TRANSPOSE(bg), tau(:,i) )
     tpos = tpos - NINT(tpos - 0.5d0)
     inpos = alat * MATMUL( at, tpos )
     write(158,'(I5,5F12.6)') at_num, at_chrg, inpos
  enddo
  i=0
  do i1=1,nr1
   do i2=1,nr2
    do i3=1,nr3
         !i(i3-1)*nrx1*nrx2+(i2-1)*nrx1+(i1-1)+1
         i=i+1
         write(158,'(E13.5)',advance='no') (rho((i3-1)*nrx1*nrx2+(i2-1)*nrx1+i1))
         if (i == 6 ) then 
          write(158,'("")')
          i=0
         endif
     enddo
    enddo
  enddo
  close(158)
     !
     !
#endif
CALL stop_clock( 'post-processing' )
     return
     !
     501 call errore ('lr_dump_rho_tot_cube', 'Unable to open file for writing', 1 ) 
!-----------------------------------------------------------------------
end subroutine lr_dump_rho_tot_cube
!-----------------------------------------------------------------------
subroutine lr_dump_rho_tot_xyzd(rho,identifier)

  ! dump a density file in the x y z density format. 
  !-----------------------------------------------------------------------
  USE io_files,             ONLY : prefix
  USE lr_variables,         ONLY : LR_polarization, LR_iteration, cube_save
  use gvect,                only : nrxx,gstart,nr1,nr2,nr3,nrx1,nrx2,nrx3
  use cell_base
  USE ions_base,            ONLY : nat, ityp, atm, ntyp => nsp, tau
  use mp,                   only : mp_barrier, mp_sum, mp_bcast, mp_get
  USE mp_global,            ONLY : me_image, intra_image_comm, me_pool, nproc_pool, &
                            intra_pool_comm, my_pool_id
  
  USE constants,            ONLY : BOHR_RADIUS_ANGS
  USE fft_base,             ONLY : dfftp !this contains dfftp%npp (number of z planes per processor
                                           ! and dfftp%ipp (offset of the first z plane of the processor
  !
  IMPLICIT NONE
  !
  real (kind=dp), intent(in)   :: rho(:)
  CHARACTER(len=10), intent(in) :: identifier
  !
  CHARACTER(len=80) :: filename
  !
  character(len=6), external :: int_to_char
  !
  !Local
  integer          :: i, nt, i1, i2, i3, at_num, iopool_id,ldr,kk,ionode_pool
  REAL(DP), ALLOCATABLE :: rho_plane(:)
  INTEGER,  ALLOCATABLE :: kowner(:)
  REAL(DP)              :: tpos(3), inpos(3)
  integer, external:: atomic_number
  ! 
 
 CALL start_clock( 'post-processing' )
 if (lr_verbosity > 5) WRITE(stdout,'("<lr_dump_rho_tot_xyzd>")')
  !

#ifdef __PARA
      !Derived From Modules/xml_io_base.f90
        ALLOCATE( rho_plane( nr1*nr2 ) )
        ALLOCATE( kowner( nr3 ) ) 
        if (ionode) then
         filename = trim(prefix) // "-" // identifier // "-pol" //trim(int_to_char(LR_polarization))// ".xyzd"
         write(stdout,'(5X,"Writing xyzd file for response charge density")') 
         !write(stdout, *) filename
         !write(stdout,'(5X,"|rho|=",D15.8)') rho_sum
         open (158, file = filename, form = 'formatted', status = 'replace', err=501)
         write(158,'("#NAT=",I5)') nat
         write(158,'("#NR1=",I5,"at1=",3F12.6)') nr1, (alat*at(i,1)/DBLE(nr1),i=1,3)
         write(158,'("#NR2=",I5,"at2=",3F12.6)') nr2, (alat*at(i,2)/DBLE(nr2),i=1,3)
         write(158,'("#NR3=",I5,"at3=",3F12.6)') nr3, (alat*at(i,3)/DBLE(nr3),i=1,3)
        
         do i=1,nat 
            ! wrap coordinates back into cell.
            tpos = MATMUL( TRANSPOSE(bg), tau(:,i) )
            tpos = tpos - NINT(tpos - 0.5d0)
            inpos = alat * MATMUL( at, tpos )
            write(158,'("#",A3,X,I5,X,3F12.6)') atm(ityp(i)), atomic_number(TRIM(atm(ityp(i)))), inpos
         enddo
   endif
        !
        ! ... find the index of the pool that will write rho
        !
        IF ( ionode ) iopool_id = my_pool_id
        !
        CALL mp_bcast( iopool_id, ionode_id, intra_image_comm )
        !
        ! ... find the index of the ionode within its own pool
        !
        IF ( ionode ) ionode_pool = me_pool
        !
        CALL mp_bcast( ionode_pool, ionode_id, intra_image_comm )
        !
        ! ... find out the owner of each "z" plane
        !
        !
        IF (nproc_pool > 1) THEN
         DO i = 1, nproc_pool
            !
            kowner( (dfftp%ipp(i)+1):(dfftp%ipp(i)+dfftp%npp(i)) ) = i - 1
            !
         END DO
        ELSE
         kowner = ionode_id
        ENDIF
        ldr = nrx1*nrx2
      !
      !
      ! Each processor is on standby to send its plane to ionode
      !
      DO i3 = 1, nr3
         !
         IF( kowner(i3) == me_pool ) THEN
            !
            kk = i3
            !
            IF ( nproc_pool > 1 ) kk = i3 - dfftp%ipp(me_pool+1)
            ! 
            DO i2 = 1, nr2
               !
               DO i1 = 1, nr1
                  !
                  rho_plane(i1+(i2-1)*nr1) = rho(i1+(i2-1)*nrx1+(kk-1)*ldr)
                  !
               END DO
               !
            END DO
            !
         END IF
         !Send plane to ionode 
         IF ( kowner(i3) /= ionode_pool .AND. my_pool_id == iopool_id ) &
            CALL mp_get( rho_plane, rho_plane, &
                                          me_pool, ionode_pool, kowner(i3), i3, intra_pool_comm )
         !
         ! write
         IF ( ionode ) then
             DO i2 = 1, nr2
               !
               DO i1 = 1, nr1
                  !
                  write(158,'(f15.8,3X)', advance='no') (DBLE(i1-1)*(alat*BOHR_RADIUS_ANGS*(at(1,1)+at(2,1)+at(3,1))/DBLE(nr1-1)))
                  write(158,'(f15.8,3X)', advance='no') (DBLE(i2-1)*(alat*BOHR_RADIUS_ANGS*(at(1,2)+at(2,2)+at(3,2))/DBLE(nr2-1)))
                  write(158,'(f15.8,3X)', advance='no') (DBLE(i3-1)*(alat*BOHR_RADIUS_ANGS*(at(1,3)+at(2,3)+at(3,3))/DBLE(nr3-1)))
                  write(158,'(e13.5)') rho_plane((i2-1)*nr1+i1)
               ENDDO
             ENDDO
         endif
         !
      END DO
      !
      DEALLOCATE( rho_plane )
      DEALLOCATE( kowner )

     if (ionode) close(158)
#else
   ! 
     !
     
     filename = trim(prefix) // "-" // identifier // "-pol" //trim(int_to_char(LR_polarization))// ".xyzd"
     write(stdout,'(5X,"Writing xyzd file for response charge density")') 
     !write(stdout, *) filename
     !write(stdout,'(5X,"|rho|=",D15.8)') rho_sum
     open (158, file = filename, form = 'formatted', status = 'replace', err=501)

  write(158,*) "# x         y          z        density"
  do i3=0,(nr3-1)
   do i2=0,(nr2-1)
    do i1=0,(nr1-1)
     write(158,'(f15.8,3X)', advance='no') (DBLE(i1)*(alat*BOHR_RADIUS_ANGS*(at(1,1)+at(2,1)+at(3,1))/DBLE(nr1-1)))
     write(158,'(f15.8,3X)', advance='no') (DBLE(i2)*(alat*BOHR_RADIUS_ANGS*(at(1,2)+at(2,2)+at(3,2))/DBLE(nr2-1)))
     write(158,'(f15.8,3X)', advance='no') (DBLE(i3)*(alat*BOHR_RADIUS_ANGS*(at(1,3)+at(2,3)+at(3,3))/DBLE(nr3-1)))
     write(158,'(e13.5)') rho(i3*nr1*nr2+i2*nr1+i1+1)
    enddo
   enddo
  enddo
  close(158)
     !
     !
#endif
CALL stop_clock( 'post-processing' )
     return
     !
     501 call errore ('lr_dump_rho_tot_xyzd', 'Unable to open file for writing', 1 ) 
!-----------------------------------------------------------------------
end subroutine lr_dump_rho_tot_xyzd
!-----------------------------------------------------------------------

subroutine lr_dump_rho_tot_xcrys(rho, identifier)
!---------------------------------------------------------------------------
! This routine dumps the charge density in xcrysden format, copyright information from
! the derived routines follows
!---------------------------------------------------------------------------
! Copyright (C) 2003 Tone Kokalj
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
! This file holds XSF (=Xcrysden Structure File) utilities.
! Routines written by Tone Kokalj on Mon Jan 27 18:51:17 CET 2003
!
! -------------------------------------------------------------------
!   this routine writes the crystal structure in XSF format
! -------------------------------------------------------------------
! -------------------------------------------------------------------
!   this routine writes the 3D scalar field (i.e. uniform mesh of points)
!   in XSF format using the FFT mesh (i.e. fast write)
! -------------------------------------------------------------------
  USE constants,             ONLY : BOHR_RADIUS_ANGS
  USE io_files,              ONLY : prefix
  USE lr_variables,          ONLY : LR_polarization, LR_iteration, cube_save
  use gvect,                 only : nrxx,gstart,nr1,nr2,nr3,nrx1,nrx2,nrx3
  use cell_base
  USE ions_base,             ONLY : nat, ityp, atm, ntyp => nsp, tau
  use mp,                   only : mp_barrier, mp_sum, mp_bcast, mp_get
  USE mp_global,            ONLY : me_image, intra_image_comm, me_pool, nproc_pool, &
                            intra_pool_comm, my_pool_id
  
  USE constants,            ONLY : BOHR_RADIUS_ANGS
  USE fft_base,             ONLY : dfftp !this contains dfftp%npp (number of z planes per processor
                                           ! and dfftp%ipp (offset of the first z plane of the processor


  
  implicit none
  !
  real (kind=dp), intent(in)   :: rho(:)
  CHARACTER(len=10), intent(in) :: identifier
  ! INTERNAL
  CHARACTER(len=80) :: filename
  ! --
  integer          :: i, j, n
  integer       :: i1, i2, i3, ix, iy, iz, count, &
       ind_x(10), ind_y(10),ind_z(10)

  real(DP)    :: at1 (3, 3)
  character(len=6), external :: int_to_char
  !Local
  integer          :: iopool_id,ldr,kk,ionode_pool,six_count
  REAL(DP), ALLOCATABLE :: rho_plane(:)
  INTEGER,  ALLOCATABLE :: kowner(:)
  ! 
  six_count=0
 CALL start_clock( 'post-processing' )
 if (lr_verbosity > 5) WRITE(stdout,'("<lr_dump_rho_tot_xsf>")')
#ifdef __PARA
     if (ionode) then
         ! 
           !
           filename = trim(prefix) // "-" // identifier // "-pol" //trim(int_to_char(LR_polarization))// ".xsf"
           write(stdout,'(5X,"Writing xsf file for response charge density")') 
           !write(stdout, *) filename
           open (158, file = filename, form = 'formatted', status = 'replace', err=501)
       
       
        ! convert lattice vectors to ANGSTROM units ...
        do i=1,3
           do j=1,3
              at1(j,i) = at(j,i)*alat*BOHR_RADIUS_ANGS
           enddo
        enddo
       
        write(158,*) 'CRYSTAL'
        write(158,*) 'PRIMVEC'
        write(158,'(2(3F15.9/),3f15.9)') at1
        write(158,*) 'PRIMCOORD'
        write(158,*) nat, 1
       
        do n=1,nat
           ! positions are in Angstroms
           write(158,'(a3,3x,3f15.9)') atm(ityp(n)), &
                tau(1,n)*alat*BOHR_RADIUS_ANGS, &
                tau(2,n)*alat*BOHR_RADIUS_ANGS, &
                tau(3,n)*alat*BOHR_RADIUS_ANGS
        enddo
       
        ! --
        ! XSF scalar-field header
        write(158,'(a)') 'BEGIN_BLOCK_DATAGRID_3D'
        write(158,'(a)') '3D_PWSCF'
        write(158,'(a)') 'DATAGRID_3D_UNKNOWN'
       
        ! number of points in each direction
        write(158,*) nr1+1, nr2+1, nr3+1
        ! origin
        write(158,'(3f10.6)') 0.0d0, 0.0d0, 0.0d0
        ! 1st spanning (=lattice) vector
        write(158,'(3f10.6)') (BOHR_RADIUS_ANGS*alat*at(i,1),i=1,3) ! in ANSTROMS
        ! 2nd spanning (=lattice) vector
        write(158,'(3f10.6)') (BOHR_RADIUS_ANGS*alat*at(i,2),i=1,3)
        ! 3rd spanning (=lattice) vector
        write(158,'(3f10.6)') (BOHR_RADIUS_ANGS*alat*at(i,3),i=1,3)
     endif
        ALLOCATE( rho_plane( nr1*nr2 ) )
        ALLOCATE( kowner( nr3 ) ) 
        !
        ! ... find the index of the pool that will write rho
        !
        IF ( ionode ) iopool_id = my_pool_id
        !
        CALL mp_bcast( iopool_id, ionode_id, intra_image_comm )
        !
        ! ... find the index of the ionode within its own pool
        !
        IF ( ionode ) ionode_pool = me_pool
        !
        CALL mp_bcast( ionode_pool, ionode_id, intra_image_comm )
        !
        ! ... find out the owner of each "z" plane
        !
        !
        IF (nproc_pool > 1) THEN
         DO i = 1, nproc_pool
            !
            kowner( (dfftp%ipp(i)+1):(dfftp%ipp(i)+dfftp%npp(i)) ) = i - 1
            !
         END DO
        ELSE
         kowner = ionode_id
        ENDIF
        ldr = nrx1*nrx2
      !
      !
      ! Each processor is on standby to send its plane to ionode
      !
      DO i3 = 1, nr3
         !
         IF( kowner(i3) == me_pool ) THEN
            !
            kk = i3
            !
            IF ( nproc_pool > 1 ) kk = i3 - dfftp%ipp(me_pool+1)
            ! 
            DO i2 = 1, nr2
               !
               DO i1 = 1, nr1
                  !
                  rho_plane(i1+(i2-1)*nr1) = rho(i1+(i2-1)*nrx1+(kk-1)*ldr)
                  !
               END DO
               !
            END DO
            !
         END IF
         !Send plane to ionode 
         IF ( kowner(i3) /= ionode_pool .AND. my_pool_id == iopool_id ) &
            CALL mp_get( rho_plane, rho_plane, &
                                          me_pool, ionode_pool, kowner(i3), i3, intra_pool_comm )
         !
         ! write
         IF ( ionode ) then
             DO i2 = 1, nr2
               !
               DO i1 = 1, nr1
                       six_count=six_count+1
                       write(158,'(e13.5)',advance='no') rho_plane((i2-1)*nr1+i1)
                       if (six_count == 6 ) then 
                         write(158,'("")')
                         six_count=0
                       endif
               ENDDO
             ENDDO
         endif
         !
      END DO
      !
      DEALLOCATE( rho_plane )
      DEALLOCATE( kowner )

     if (ionode) close(158)

#else
   ! 
     !
     filename = trim(prefix) // "-" // identifier // "-pol" //trim(int_to_char(LR_polarization))// ".xsf"
     write(stdout,'(5X,"Writing xsf file for response charge density")') 
     !write(stdout, *) filename
     open (158, file = filename, form = 'formatted', status = 'replace', err=501)


  ! convert lattice vectors to ANGSTROM units ...
  do i=1,3
     do j=1,3
        at1(j,i) = at(j,i)*alat*BOHR_RADIUS_ANGS
     enddo
  enddo

  write(158,*) 'CRYSTAL'
  write(158,*) 'PRIMVEC'
  write(158,'(2(3F15.9/),3f15.9)') at1
  write(158,*) 'PRIMCOORD'
  write(158,*) nat, 1

  do n=1,nat
     ! positions are in Angstroms
     write(158,'(a3,3x,3f15.9)') atm(ityp(n)), &
          tau(1,n)*alat*BOHR_RADIUS_ANGS, &
          tau(2,n)*alat*BOHR_RADIUS_ANGS, &
          tau(3,n)*alat*BOHR_RADIUS_ANGS
  enddo

  ! --
  ! XSF scalar-field header
  write(158,'(a)') 'BEGIN_BLOCK_DATAGRID_3D'
  write(158,'(a)') '3D_PWSCF'
  write(158,'(a)') 'DATAGRID_3D_UNKNOWN'

  ! number of points in each direction
  write(158,*) nr1+1, nr2+1, nr3+1
  ! origin
  write(158,'(3f10.6)') 0.0d0, 0.0d0, 0.0d0
  ! 1st spanning (=lattice) vector
  write(158,'(3f10.6)') (BOHR_RADIUS_ANGS*alat*at(i,1),i=1,3) ! in ANSTROMS
  ! 2nd spanning (=lattice) vector
  write(158,'(3f10.6)') (BOHR_RADIUS_ANGS*alat*at(i,2),i=1,3)
  ! 3rd spanning (=lattice) vector
  write(158,'(3f10.6)') (BOHR_RADIUS_ANGS*alat*at(i,3),i=1,3)

  count=0
  do i3=0,nr3
     iz = mod(i3,nr3)
     !iz = mod(i3,nr3) + 1

     do i2=0,nr2
        iy = mod(i2,nr2)
        !iy = mod(i2,nr2) + 1

        do i1=0,nr1
           ix = mod(i1,nr1)
           !ix = mod(i1,nr1) + 1

           !ii = (1+ix) + iy*nrx1 + iz*nrx1*nrx2
           if (count.lt.6) then
              count = count + 1
              !ind(count) = ii
           else
              write(158,'(6e13.5)') &
                   (rho(ind_x(i)+1+nr1*ind_y(i)+nr1*nr2*ind_z(i)),i=1,6)
              count=1
              !ind(count) = ii
           endif
           ind_x(count) = ix
           ind_y(count) = iy
           ind_z(count) = iz
        enddo
     enddo
  enddo
  write(158,'(6e13.5:)') (rho(ind_x(i)+1+nr1*ind_y(i)+nr1*nr2*ind_z(i)),i=1,count)
  write(158,'(a)') 'END_DATAGRID_3D'
  write(158,'(a)') 'END_BLOCK_DATAGRID_3D'
#endif
     return
CALL stop_clock( 'post-processing' )
     !
     501 call errore ('lr_dump_rho_tot_xyzd', 'Unable to open file for writing', 1 ) 
!-----------------------------------------------------------------------
end subroutine lr_dump_rho_tot_xcrys
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
subroutine lr_dump_rho_tot_pxyd(rho,identifier)
  !-----------------------------------------------------------------------
  ! dump a density file in the x y plane density summed over z planes format. 
  !-----------------------------------------------------------------------
  USE io_files,              ONLY : prefix
  USE lr_variables,          ONLY : LR_polarization, LR_iteration, cube_save
  use gvect,                    only : nrxx,gstart,nr1,nr2,nr3
  use cell_base
  USE ions_base,                ONLY : nat, ityp, atm, ntyp => nsp, tau
  use mp,                       only : mp_barrier, mp_sum
  use mp_global,                only : intra_pool_comm
  USE constants,             ONLY : BOHR_RADIUS_ANGS
  !
  IMPLICIT NONE
  !
  real (kind=dp), intent(in)   :: rho(:)
  CHARACTER(len=10), intent(in) :: identifier
  !
  CHARACTER(len=80) :: filename
  !
  character(len=6), external :: int_to_char
  !
  !Local
  integer          :: i, nt, i1, i2, i3, at_num
  integer, external:: atomic_number
  real(DP)    :: at_chrg, tpos(3), inpos(3),rho_sum
    ! 
 
 CALL start_clock( 'post-processing' )
 if (lr_verbosity > 5) WRITE(stdout,'("<lr_dump_rho_tot_pxyd>")')
  rho_sum=0.0d0
  do i=1,nrxx
     rho_sum=rho_sum+rho(i)
  enddo
  !

#ifdef __PARA
     if (ionode) then
#endif
   ! 
     !
     
     filename = trim(prefix) // "-" // identifier // "-pol" //trim(int_to_char(LR_polarization))// ".pxyd"
     write(stdout,'(5X,"Writing z plane averaged pxyd file for response charge density")') 
     !write(stdout, *) filename
     write(stdout,'(5X,"|rho|=",D15.8)') rho_sum
     open (158, file = filename, form = 'formatted', status = 'replace', err=501)

  write(158,*) "# x         y          z        density"
   do i1=0,(nr1-1)
    do i2=0,(nr2-1)
     rho_sum=0
     do i3=0,(nr3-1)
      rho_sum=rho_sum+rho(i3*nr1*nr2+i2*nr1+i1+1)
     enddo
     write(158,'(f15.8,3X)', advance='no') (DBLE(i1)*(alat*BOHR_RADIUS_ANGS*(at(1,1)+at(2,1)+at(3,1))/DBLE(nr1-1)))
     write(158,'(f15.8,3X)', advance='no') (DBLE(i2)*(alat*BOHR_RADIUS_ANGS*(at(1,2)+at(2,2)+at(3,2))/DBLE(nr2-1)))
     write(158,'(e13.5)') rho_sum
    enddo
   enddo
  close(158)
     !
     !
#ifdef __PARA
     end if
     call mp_barrier()
#endif
CALL stop_clock( 'post-processing' )
     return
     !
     501 call errore ('lr_dump_rho_tot_pxyd', 'Unable to open file for writing', 1 ) 
!-----------------------------------------------------------------------
end subroutine lr_dump_rho_tot_pxyd
!-----------------------------------------------------------------------




END MODULE charg_resp