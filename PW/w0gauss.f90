!
! Copyright (C) 2001 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-----------------------------------------------------------------------
function w0gauss (x, n)
  !-----------------------------------------------------------------------
  !
  !     the derivative of wgauss:  an approximation to the delta function
  !
  ! --> (n>=0) : derivative of the corresponding Methfessel-Paxton wgauss
  !
  ! --> (n=-1 ): derivative of cold smearing:
  !              1/sqrt(pi)*exp(-(x-1/sqrt(2))**2)*(2-sqrt(2)*x)
  !
  ! --> (n=-99): derivative of Fermi-Dirac function: 0.5/(1.0+cosh(x))
  !
  USE kinds
  implicit none
  real(kind=DP) :: w0gauss, x
  ! output: the value of the function
  ! input: the point where to compute the function

  integer :: n
  ! input: the order of the smearing function
  !
  !    here the local variables
  !
  real(kind=DP) :: a, arg, hp, hd, pi
  ! the coefficients a_n
  ! the argument of the exponential
  ! the hermite function
  ! the hermite function
  ! pi

  integer :: i, ni
  ! counter on n values
  ! counter on 2n values

  pi = 3.14159265358979d0
  ! Fermi-Dirac smearing
  if (n.eq. - 99) then
     if (abs (x) .le.36.0) then
        w0gauss = 1.0d0 / (2.0 + exp ( - x) + exp ( + x) )
        ! in order to avoid problems for large values of x in the e
     else
        w0gauss = 0.d0
     endif
     return

  endif
  ! cold smearing  (Marzari-Vanderbilt)
  if (n.eq. - 1) then
     arg = min (200.d0, (x - 1.0d0 / sqrt (2.0d0) ) **2)
     w0gauss = 1.0d0 / sqrt (pi) * exp ( - arg) * (2.0d0 - sqrt ( &
          2.0d0) * x)
     return

  endif
  ! Methfessel-Paxton
  arg = min (200.d0, x**2)
  w0gauss = exp ( - arg) / sqrt (pi)
  if (n.eq.0) return
  hd = 0.0d0
  hp = exp ( - arg)
  ni = 0
  a = 1.0 / sqrt (pi)
  do i = 1, n
     hd = 2.0d0 * x * hp - 2.0d0 * float (ni) * hd
     ni = ni + 1
     a = - a / (float (i) * 4.0d0)
     hp = 2.0d0 * x * hd-2.0d0 * float (ni) * hp
     ni = ni + 1
     w0gauss = w0gauss + a * hp
  enddo
  return
end function w0gauss
