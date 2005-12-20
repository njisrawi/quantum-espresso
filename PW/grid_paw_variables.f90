module grid_paw_variables
  !
  !   WARNINGS:
  !
  ! NO spin-orbit
  ! NO EXX
  ! NO Parallelism
  ! NO rinner > 0
  !
  USE kinds,      ONLY : DP
  USE parameters, ONLY : lqmax, nbrx, npsx, nqfx, ndmx
  !
  implicit none
  public!              <===
  save

  ! Analogous to okvan in  "uspp_param" (Modules/uspp.f90)
  LOGICAL :: &
       okpaw              ! if .TRUE. at least one pseudo is PAW

  ! Analogous to tvanp in "uspp_param" (Modules/uspp.f90)
  LOGICAL :: &
       tpawp(npsx)            ! if .TRUE. the atom is of PAW type

  ! Analogous to qfunc in "uspp_param" (Modules/uspp.f90)
  REAL(DP), TARGET :: &
       pfunc(ndmx,nbrx,nbrx,npsx), &! AE: \phi_{mu}(|r|)-\phi_{nu}(|r|)
       ptfunc(ndmx,nbrx,nbrx,npsx)  ! PS: \tilde{\phi}_{mu}(|r|)-\tilde{\phi}_{nu}(|r|)

  ! Analogous to qq in "uspp_param" (Modules/uspp.f90)
  REAL(DP), ALLOCATABLE, TARGET :: &
       pp(:,:,:),             &! the integrals of p functions in the solid
       ppt(:,:,:)              ! the integrals of pt functions in the solid

  ! Analogous to qrad in "us" (PW/pwcom.f90)
  REAL(DP), ALLOCATABLE, TARGET :: &
       prad(:,:,:,:),         &! radial FT of P functions
       ptrad(:,:,:,:)          ! radial FT of \tilde{P} functions

  ! Analogous to rho in "scf" (PW/pwcom.f90) + index scanning atoms
  REAL(DP), ALLOCATABLE, TARGET :: &
       rho1(:,:,:),             &! 1center AE charge density in real space
       rho1t(:,:,:)              ! 1center PS charge density in real space
!!! No more needed since ptfunc already contains the augmentation charge qfunc
!!!    rho1h(:,:,:)              ! 1center compensation charge in real space

  ! Analogous to vr in "scf" (PW/pwcom.f90) + index scanning atoms
  REAL(DP), ALLOCATABLE, TARGET :: &
       vr1(:,:,:),        &! the Hartree+XC potential in real space of rho1
       vr1t(:,:,:)         ! the Hartree+XC potential in real space of rho1t

  ! Analogous to qq in "uspp_param" (Modules/uspp.f90)
  REAL(DP), ALLOCATABLE, TARGET :: &
       int_r2pfunc(:,:,:),   &! Integrals of r^2 * pfunc(r) (AE)
       int_r2ptfunc(:,:,:)    ! Integrals of r^2 * pfunc(r) (PS)

  ! Analogous to rho_atc in "atom" (Modules/atom.f90)
  REAL(DP), TARGET :: &
       aerho_atc(ndmx,npsx),        &! radial AE core charge density
       psrho_atc(ndmx,npsx)          ! radial PS core charge density          
  
  ! Analogous to rho_core in "scf" (PW/pwcom.f90)
  REAL(DP), ALLOCATABLE, TARGET :: &
       aerho_core(:,:),            &! AE core charge density in real space
       psrho_core(:,:)              ! PS core charge density in real space

  ! Analogous to vloc_at in "uspp_param" (Modules/uspp.f90)
  REAL(DP), TARGET :: &
      aevloc_at(ndmx,npsx),               &! AE descreened potential
      psvloc_at(ndmx,npsx)                 ! PS descreened potential

  ! Analogous to vloc in "vlocal" (PW/pwcom.f90)
  REAL(DP), ALLOCATABLE, TARGET :: &
       aevloc(:,:),            &! AE local 1-c potential for each atom type
       psvloc(:,:)              ! PS local 1-c potential for each atom type

  ! Analogous to vltot in "scf" (PW/pwcom.f90)
  REAL(DP), ALLOCATABLE, TARGET :: &
       aevloc_r(:,:),            &! AE local potential in real space
       psvloc_r(:,:)              ! PS local potential in real space

  ! One-center energies
  REAL(DP), ALLOCATABLE, TARGET :: &
       ehart1 (:),                & ! Hartree energy (AE)
       etxc1  (:),                & ! XC: energy (AE)
       vtxc1  (:),                & ! XC: Int V*rho (AE)
       ehart1t(:),                & ! Hartree energy (PS)
       etxc1t (:),                & ! XC: energy (PS)
       vtxc1t (:)                   ! XC: Int V*rho (PS)

  ! Analogous to dion in "uspp_param" (Modules/uspp.f90)
  REAL(DP) :: &
       kdiff (nbrx,nbrx,npsx)                ! Kinetic energy differences

  ! Analogous to deeq in "uspp_param" (Modules/uspp.f90)
  REAL(DP), ALLOCATABLE :: &
       dpaw_ae(:,:,:,:),         &! AE D: D^1_{ij}         (except for K.E.)
       dpaw_ps(:,:,:,:)           ! PS D: \tilde{D}^1_{ij} (except for K.E.)
  
end module grid_paw_variables
