!
! Copyright (C) 2002-2009 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!------------------------------------------------------------------------------!
  MODULE electrons_base
!------------------------------------------------------------------------------!

      USE kinds, ONLY: DP
!
      IMPLICIT NONE
      SAVE

      INTEGER :: nbnd       = 0    !  number electronic bands, each band contains
                                   !  two spin states
      INTEGER :: nbndx      = 0    !  array dimension nbndx >= nbnd
      INTEGER :: nspin      = 0    !  nspin = number of spins (1=no spin, 2=LSDA)
      INTEGER :: nel(2)     = 0    !  number of electrons (up, down)
      INTEGER :: nelt       = 0    !  total number of electrons ( up + down )
      INTEGER :: nupdwn(2)  = 0    !  number of states with spin up (1) and down (2)
      INTEGER :: iupdwn(2)  = 0    !  first state with spin (1) and down (2)
      INTEGER :: nudx       = 0    !  max (nupdw(1),nupdw(2))
      INTEGER :: nbsp       = 0    !  total number of electronic states 
                                   !  (nupdwn(1)+nupdwn(2))
      INTEGER :: nbspx      = 0    !  array dimension nbspx >= nbsp

      LOGICAL :: telectrons_base_initval = .FALSE.
      LOGICAL :: keep_occ = .FALSE.  ! if .true. when reading restart file keep 
                                     ! the occupations calculated in initval

      REAL(DP), ALLOCATABLE :: f(:)   ! occupation numbers ( at gamma )
      REAL(DP) :: qbac = 0.0_DP       ! background neutralizing charge
      INTEGER, ALLOCATABLE :: ispin(:) ! spin of each state
!
!------------------------------------------------------------------------------!
  CONTAINS
!------------------------------------------------------------------------------!


    SUBROUTINE electrons_base_initval( zv_ , na_ , nsp_ , nbnd_ , nspin_ , &
          occupations_ , f_inp, tot_charge_, tot_magnetization_ )

      USE constants,         ONLY   : eps8
      USE io_global,         ONLY   : stdout
      USE control_flags,     ONLY   : iprsta

      REAL(DP),         INTENT(IN) :: zv_ (:), tot_charge_
      REAL(DP),         INTENT(IN) :: f_inp(:,:)
      REAL(DP),         INTENT(IN) :: tot_magnetization_
      INTEGER,          INTENT(IN) :: na_ (:) , nsp_
      INTEGER,          INTENT(IN) :: nbnd_ , nspin_
      CHARACTER(LEN=*), INTENT(IN) :: occupations_

      REAL(DP)                     :: nelec, nelup, neldw, ocp, fsum
      INTEGER                      :: iss, i, in

      nspin = nspin_
      !
      ! ... set nelec
      !
      nelec = 0.0_DP
      DO i = 1, nsp_
         nelec = nelec + na_ ( i ) * zv_ ( i )
      END DO 
      nelec = nelec - tot_charge_
      !
      ! ... set nelup/neldw
      !
      nelup = 0._dp
      neldw = 0._dp
      call set_nelup_neldw (tot_magnetization_, nelec, nelup, neldw )

      IF( ABS( nelec - ( nelup + neldw ) ) > eps8 ) THEN
         CALL errore(' electrons_base_initval ',' inconsistent n. of electrons ', 2 )
      END IF
      !
      !   Compute the number of bands
      !
      IF( nbnd_ /= 0 ) THEN
        nbnd  = nbnd_                          ! nbnd is given from input
      ELSE
        nbnd  = NINT( MAX( nelup, neldw ) )    ! take the maximum between up and down states
      END IF


      IF( nelec < 1 ) THEN
         CALL errore(' electrons_base_initval ',' nelec less than 1 ', 1 )
      END IF
      !
      IF( ABS( NINT( nelec ) - nelec ) > eps8 ) THEN
         CALL errore(' electrons_base_initval ',' nelec must be integer', 2 )
      END IF
      !
      IF( nbnd < 1 ) &
        CALL errore(' electrons_base_initval ',' nbnd out of range ', 1 )
      !

      IF ( nspin /= 1 .AND. nspin /= 2 ) THEN
        WRITE( stdout, * ) 'nspin = ', nspin
        CALL errore( ' electrons_base_initval ', ' nspin out of range ', 1 )
      END IF

      IF( MOD( nbnd, 2 ) == 0 ) THEN
         nbspx = nbnd * nspin
      ELSE
         nbspx = ( nbnd + 1 ) * nspin
      END IF

      ALLOCATE( f     ( nbspx ) )
      ALLOCATE( ispin ( nbspx ) )
      f     = 0.0_DP
      ispin = 0

      iupdwn ( 1 ) = 1
      nel          = 0

      SELECT CASE ( TRIM(occupations_) )
      CASE ('bogus')
         !
         ! bogus to ensure \sum_i f_i = Nelec  (nelec is integer)
         !
         f ( : )    = nelec / nbspx
         nel (1)    = nint( nelec )
         nupdwn (1) = nbspx
         if ( nspin == 2 ) then
            !
            ! bogus to ensure Nelec = Nup + Ndw
            !
            nel (1) = ( nint(nelec) + 1 ) / 2
            nel (2) =   nint(nelec)       / 2
            nupdwn (1)=nbnd
            nupdwn (2)=nbnd
            iupdwn (2)=nbnd+1
         end if
         !
         keep_occ = .true.
         !
      CASE ('from_input')
         !
         ! occupancies have been read from input
         !
         ! count electrons
         !
         IF( nspin == 1 ) THEN
            nelec = SUM( f_inp( :, 1 ) )
            nelup = nelec / 2.0_DP
            neldw = nelec / 2.0_DP
         ELSE
            nelup = SUM ( f_inp ( :, 1 ) )
            neldw = SUM ( f_inp ( :, 2 ) )
            nelec = nelup + neldw 
         END IF
         !
         ! consistency check
         !
         IF( nspin == 1 ) THEN
           IF( f_inp( 1, 1 ) <= 0.0_DP )  &
               CALL errore(' electrons_base_initval ',' Zero or negative occupation are not allowed ', 1 )
         ELSE
           IF( f_inp( 1, 1 ) < 0.0_DP )  &
               CALL errore(' electrons_base_initval ',' Zero or negative occupation are not allowed ', 1 )
           IF( f_inp( 1, 2 ) < 0.0_DP )  &
               CALL errore(' electrons_base_initval ',' Zero or negative occupation are not allowed ', 1 )
           IF( ( f_inp( 1, 1 ) + f_inp( 1, 2 ) ) == 0.0_DP )  &
               CALL errore(' electrons_base_initval ',' Zero or negative occupation are not allowed ', 1 )
         END IF
         DO i = 2, nbnd
           IF( nspin == 1 ) THEN
             IF( f_inp( i, 1 ) > 0.0_DP .AND. f_inp( i-1, 1 ) <= 0.0_DP )  &
               CALL errore(' electrons_base_initval ',' Zero or negative occupation are not allowed ', 1 )
           ELSE
             IF( f_inp( i, 1 ) > 0.0_DP .AND. f_inp( i-1, 1 ) <= 0.0_DP ) &
               CALL errore(' electrons_base_initval ',' Zero or negative occupation are not allowed ', 1 )
             IF( f_inp( i, 2 ) > 0.0_DP .AND. f_inp( i-1, 2 ) <= 0.0_DP ) &
               CALL errore(' electrons_base_initval ',' Zero or negative occupation are not allowed ', 1 )
           END IF
         END DO
         !
         ! count bands
         !
         nupdwn (1) = 0
         nupdwn (2) = 0
         DO i = 1, nbnd
           IF( nspin == 1 ) THEN
             IF( f_inp( i, 1 ) > 0.0_DP ) nupdwn (1) = nupdwn (1) + 1
           ELSE
             IF( f_inp( i, 1 ) > 0.0_DP ) nupdwn (1) = nupdwn (1) + 1
             IF( f_inp( i, 2 ) > 0.0_DP ) nupdwn (2) = nupdwn (2) + 1
           END IF
         END DO
         !
         if( nspin == 1 ) then
           nel (1)    = nint( nelec )
           iupdwn (1) = 1
         else
           nel (1)    = nint(nelup)
           nel (2)    = nint(neldw)
           iupdwn (1) = 1
           iupdwn (2) = nupdwn (1) + 1
         end if
         !
         DO iss = 1, nspin
           DO in = iupdwn ( iss ), iupdwn ( iss ) - 1 + nupdwn ( iss )
             f( in ) = f_inp( in - iupdwn ( iss ) + 1, iss )
           END DO
         END DO
         !
      CASE ('fixed')

         if( nspin == 1 ) then
            nel(1)    = nint(nelec)
            nupdwn(1) = nbnd
            iupdwn(1) = 1
         else
            IF ( nelup + neldw /= nelec  ) THEN
               CALL errore(' electrons_base_initval ',' wrong # of up and down spin', 1 )
            END IF
            nel(1)    = nint(nelup)
            nel(2)    = nint(neldw)
            nupdwn(1) = nint(nelup)
            nupdwn(2) = nint(neldw)
            iupdwn(1) = 1
            iupdwn(2) = nupdwn(1) + 1
         end if

!         if( (nspin == 1) .and. MOD( nint(nelec), 2 ) /= 0 ) &
!              CALL errore(' electrons_base_initval ', &
!              ' must use nspin=2 for odd number of electrons', 1 )
         
         ! ocp = 2 for spinless systems, ocp = 1 for spin-polarized systems
         ocp = 2.0_DP / nspin
         !
         ! default filling: attribute ocp electrons to each states
         !                  until the good number of electrons is reached
         do iss = 1, nspin
            fsum = 0.0_DP
            do in = iupdwn ( iss ), iupdwn ( iss ) - 1 + nupdwn ( iss )
               if ( fsum + ocp < nel ( iss ) + 0.0001_DP ) then
                  f (in) = ocp
               else
                  f (in) = max( nel ( iss ) - fsum, 0.0_DP )
               end if
                fsum = fsum + f(in)
            end do
         end do
         !
      CASE ('ensemble','ensemble-dft','edft')

          if ( nspin == 1 ) then
            !
            f ( : )    = nelec / nbnd
            nel (1)    = nint(nelec)
            nupdwn (1) = nbnd
            !
          else
            !
            if (nelup.ne.0) then
              if ((nelup+neldw).ne.nelec) then
                 CALL errore(' electrons_base_initval ',' nelup+neldw .ne. nelec', 1 )
              end if
              nel (1) = nelup
              nel (2) = neldw
            else
              nel (1) = ( nint(nelec) + 1 ) / 2
              nel (2) =   nint(nelec)       / 2
            end if
            !
            nupdwn (1) = nbnd
            nupdwn (2) = nbnd
            iupdwn (2) = nbnd+1
            !
            do iss = 1, nspin
             do i = iupdwn ( iss ), iupdwn ( iss ) - 1 + nupdwn ( iss )
                f (i) =  nel (iss) / DBLE (nupdwn (iss))
             end do
            end do
            !
          end if

      CASE DEFAULT
         CALL errore(' electrons_base_initval ',' occupation method not implemented', 1 )
      END SELECT


      do iss = 1, nspin
         do in = iupdwn(iss), iupdwn(iss) - 1 + nupdwn(iss)
            ispin(in) = iss
         end do
      end do

      nbndx = nupdwn (1)
      nudx  = nupdwn (1)
      nbsp  = nupdwn (1) + nupdwn (2)

      IF ( nspin == 1 ) THEN 
        nelt = nel(1)
      ELSE
        nelt = nel(1) + nel(2)
      END IF

      IF( nupdwn(1) < nupdwn(2) ) &
        CALL errore(' electrons_base_initval ',' nupdwn(1) should be greather or equal nupdwn(2) ', 1 )

      IF( nbnd < nupdwn(1) ) &
        CALL errore(' electrons_base_initval ',' inconsistent nbnd, should be .GE. than  nupdwn(1) ', 1 )

      IF( nbspx < ( nupdwn(1) * nspin ) ) &
        CALL errore(' electrons_base_initval ',' inconsistent nbspx, should be .GE. than  nspin * nupdwn(1) ', 1 )

      IF( ( 2 * nbnd ) < nelt ) &
        CALL errore(' electrons_base_initval ',' too few states ',  1  )

      IF( nbsp < INT( nelec * nspin / 2.0_DP ) ) &
        CALL errore(' electrons_base_initval ',' too many electrons ', 1 )


      telectrons_base_initval = .TRUE.

      RETURN

    END SUBROUTINE electrons_base_initval

!----------------------------------------------------------------------------
!
    subroutine set_nelup_neldw ( tot_magnetization_, nelec_, nelup_, neldw_ )
      !
      USE kinds,     ONLY : DP
      USE constants, ONLY : eps8
      !
      REAL (KIND=DP), intent(IN)  :: tot_magnetization_
      REAL (KIND=DP), intent(IN)  :: nelec_
      REAL (KIND=DP), intent(OUT) :: nelup_, neldw_
      LOGICAL :: integer_charge
      !
      integer_charge = ( ABS (nelec_ - NINT(nelec_)) < eps8 )
      !
      IF ( tot_magnetization_ < 0 ) THEN
         ! default when tot_magnetization is unspecified
         IF ( integer_charge) THEN
            nelup_ = INT( nelec_ + 1 ) / 2
            neldw_ = nelec_ - nelup_
         ELSE
            nelup_ = nelec_ / 2
            neldw_ = neldw_
         END IF
      ELSE
         ! tot_magnetization specified in input
         !
         if ( (tot_magnetization_ > 0) .and. (nspin==1) ) &
                 CALL errore(' set_nelup_neldw  ', &
                 'tot_magnetization is inconsistent with nspin=1 ', 2 )
         IF ( integer_charge) THEN
            !
            ! odd  tot_magnetization requires an odd  number of electrons
            ! even tot_magnetization requires an even number of electrons
            if ( ((MOD(NINT(tot_magnetization_),2) == 0) .and. &
                  (MOD(NINT(nelec_),2)==1))               .or. &
                 ((MOD(NINT(tot_magnetization_),2) == 1) .and. &
                  (MOD(NINT(nelec_),2)==0))      ) &
              CALL errore(' set_nelup_neldw ',                          &
             'tot_magnetization is inconsistent with total number of electrons ', 2 )
            !
            ! ... setting nelup/neldw
            !
            nelup_ = ( INT(nelec_) + tot_magnetization_ ) / 2
            neldw_ = ( INT(nelec_) - tot_magnetization_ ) / 2
         ELSE
            !
            nelup_ = ( nelec_ + tot_magnetization_ ) / 2
            neldw_ = ( nelec_ - tot_magnetization_ ) / 2
         END IF
      END IF

      return
    end subroutine set_nelup_neldw

!----------------------------------------------------------------------------


    SUBROUTINE deallocate_elct()
      IF( ALLOCATED( f ) ) DEALLOCATE( f )
      IF( ALLOCATED( ispin ) ) DEALLOCATE( ispin )
      telectrons_base_initval = .FALSE.
      RETURN
    END SUBROUTINE deallocate_elct


!------------------------------------------------------------------------------!
  END MODULE electrons_base
!------------------------------------------------------------------------------!



!------------------------------------------------------------------------------!
  MODULE electrons_nose
!------------------------------------------------------------------------------!

      USE kinds, ONLY: DP
!
      IMPLICIT NONE
      SAVE

      REAL(DP) :: fnosee   = 0.0_DP   !  frequency of the thermostat ( in THz )
      REAL(DP) :: qne      = 0.0_DP   !  mass of teh termostat
      REAL(DP) :: ekincw   = 0.0_DP   !  kinetic energy to be kept constant

      REAL(DP) :: xnhe0   = 0.0_DP  
      REAL(DP) :: xnhep   = 0.0_DP
      REAL(DP) :: xnhem   = 0.0_DP
      REAL(DP) :: vnhe    = 0.0_DP
      
!
!------------------------------------------------------------------------------!
  CONTAINS
!------------------------------------------------------------------------------!

  subroutine electrons_nose_init( ekincw_ , fnosee_ )
     USE constants, ONLY: pi, au_terahertz
     REAL(DP), INTENT(IN) :: ekincw_, fnosee_
     ! set thermostat parameter for electrons
     qne     = 0.0_DP
     ekincw  = ekincw_
     fnosee  = fnosee_
     xnhe0   = 0.0_DP
     xnhep   = 0.0_DP
     xnhem   = 0.0_DP
     vnhe    = 0.0_DP
     if( fnosee > 0.0_DP ) qne = 4.0_DP * ekincw / ( fnosee * ( 2.0_DP * pi ) * au_terahertz )**2
    return
  end subroutine electrons_nose_init


  function electrons_nose_nrg( xnhe0, vnhe, qne, ekincw )
    !  compute energy term for nose thermostat
    implicit none
    real(dp) :: electrons_nose_nrg
    real(dp), intent(in) :: xnhe0, vnhe, qne, ekincw
      !
      electrons_nose_nrg = 0.5_DP * qne * vnhe * vnhe + 2.0_DP * ekincw * xnhe0
      !
    return
  end function electrons_nose_nrg

  subroutine electrons_nose_shiftvar( xnhep, xnhe0, xnhem )
    !  shift values of nose variables to start a new step
    implicit none
    real(dp), intent(out) :: xnhem
    real(dp), intent(inout) :: xnhe0
    real(dp), intent(in) :: xnhep
      !
      xnhem = xnhe0
      xnhe0 = xnhep
      !
    return
  end subroutine electrons_nose_shiftvar

  subroutine electrons_nosevel( vnhe, xnhe0, xnhem, delt )
    implicit none
    real(dp), intent(inout) :: vnhe
    real(dp), intent(in) :: xnhe0, xnhem, delt 
    vnhe=2.0_DP*(xnhe0-xnhem)/delt-vnhe
    return
  end subroutine electrons_nosevel

  subroutine electrons_noseupd( xnhep, xnhe0, xnhem, delt, qne, ekinc, ekincw, vnhe )
    implicit none
    real(dp), intent(out) :: xnhep, vnhe
    real(dp), intent(in) :: xnhe0, xnhem, delt, qne, ekinc, ekincw
    xnhep = 2.0_DP * xnhe0 - xnhem + 2.0_DP * ( delt**2 / qne ) * ( ekinc - ekincw )
    vnhe  = ( xnhep - xnhem ) / ( 2.0_DP * delt )
    return
  end subroutine electrons_noseupd


  SUBROUTINE electrons_nose_info()

      use constants,     only: au_terahertz, pi
      use time_step,     only: delt
      USE io_global,     ONLY: stdout
      USE control_flags, ONLY: tnosee

      IMPLICIT NONE

      INTEGER   :: nsvar
      REAL(DP) :: wnosee

      IF( tnosee ) THEN
        !
        IF( fnosee <= 0.0_DP) &
          CALL errore(' electrons_nose_info ', ' fnosee less than zero ', 1)
        IF( delt <= 0.0_DP) &
          CALL errore(' electrons_nose_info ', ' delt less than zero ', 1)

        wnosee = fnosee * ( 2.0_DP * pi ) * au_terahertz
        nsvar  = ( 2.0_DP * pi ) / ( wnosee * delt )

        WRITE( stdout,563) ekincw, nsvar, fnosee, qne
      END IF

 563  format( //, &
     &       3X,'electrons dynamics with nose` temperature control:', /, &
     &       3X,'Kinetic energy required   = ', f10.5, ' (a.u.) ', /, &
     &       3X,'time steps per nose osc.  = ', i5, /, &
     &       3X,'nose` frequency           = ', f10.3, ' (THz) ', /, &
     &       3X,'nose` mass(es)            = ', 20(1X,f10.3),//)


    RETURN
  END SUBROUTINE electrons_nose_info

!------------------------------------------------------------------------------!
  END MODULE electrons_nose
!------------------------------------------------------------------------------!
