!******************************************************************************
!
!  gramschmidt.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header. 
#include <fpolybench.h>

! Include benchmark-specific header. 
! Default data type is double, default size is 512. 
#include "gramschmidt.h"

      program gramschmidt
      implicit none

      POLYBENCH_2D_ARRAY_DECL(a ,DATA_TYPE, NJ, NI)
      POLYBENCH_2D_ARRAY_DECL(r ,DATA_TYPE, NJ, NJ)
      POLYBENCH_2D_ARRAY_DECL(q ,DATA_TYPE, NJ, NI)
      polybench_declare_prevent_dce_vars
      polybench_declare_instruments

!     Allocation of Arrays
      POLYBENCH_ALLOC_2D_ARRAY(a, NJ, NI)
      POLYBENCH_ALLOC_2D_ARRAY(r, NJ, NJ)
      POLYBENCH_ALLOC_2D_ARRAY(q, NJ, NI)

!     Initialization
      call init_array(NI, NJ, a, r, q)

!     Kernel Execution
      polybench_start_instruments

      call kernel_gramschmidt(NI, NJ, a, r, q)

      polybench_stop_instruments
      polybench_print_instruments

!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
      polybench_prevent_dce(print_array(NI, NJ, a, r, q));

!     Deallocation of Arrays 
      POLYBENCH_DEALLOC_ARRAY(a)
      POLYBENCH_DEALLOC_ARRAY(r)
      POLYBENCH_DEALLOC_ARRAY(q)

      contains

        subroutine init_array(ni, nj, a, r, q)
        implicit none

        DATA_TYPE, dimension(nj, ni) :: a
        DATA_TYPE, dimension(nj, nj) :: r
        DATA_TYPE, dimension(nj, ni) :: q
        integer :: ni, nj
        integer :: i, j

        do i = 1, ni 
          do j = 1, nj
            a(j, i) = (DBLE(i - 1) * DBLE(j - 1)) / DBLE(ni)
            q(j, i) = (DBLE(i - 1) * DBLE(j)) / DBLE(nj)
          end do
        end do

        do i = 1, ni 
          do j = 1, nj
            r(j, i) = (DBLE(i - 1) * DBLE(j + 1)) / DBLE(nj)
          end do
        end do
        end subroutine


        subroutine print_array(ni, nj, a, r, q)
        implicit none

        DATA_TYPE, dimension(nj, ni) :: a
        DATA_TYPE, dimension(nj, nj) :: r
        DATA_TYPE, dimension(nj, ni) :: q
        integer :: ni, nj
        integer :: i, j
        do i = 1, ni 
          do j = 1, nj
            write(0, DATA_PRINTF_MODIFIER) a(j, i)
            if (mod((i - 1), 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        do i = 1, nj 
          do j = 1, nj
            write(0, DATA_PRINTF_MODIFIER) r(j, i)
            if (mod((i - 1), 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        do i = 1, ni 
          do j = 1, nj
            write(0, DATA_PRINTF_MODIFIER) q(j, i)
            if (mod((i - 1), 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        end subroutine


        subroutine kernel_gramschmidt(ni, nj, a, r, q) 
        implicit none

        DATA_TYPE, dimension(nj, ni) :: a
        DATA_TYPE, dimension(nj, nj) :: r
        DATA_TYPE, dimension(nj, ni) :: q
        DATA_TYPE :: nrm
        DATA_TYPE :: dot
        integer :: ni, nj
        integer :: i, j, k

!$pragma scop
        do k = 1, _PB_NJ
          nrm = 0.0D0
!$omp parallel do reduction(+:nrm) private(i)
          do i = 1, _PB_NI
            nrm = nrm + (a(k, i) * a(k, i))
          end do
!$omp end parallel do
          r(k, k) = sqrt(nrm)
!$omp parallel do private(i)
          do i = 1, _PB_NI
            q(k, i) = a(k, i) / r(k, k)
          end do
!$omp end parallel do
!$omp parallel do private(j, i, dot)
          do j = k + 1, _PB_NJ
            dot = 0.0D0
            do i = 1, _PB_NI
              dot = dot + (q(k, i) * a(j, i))
            end do
            r(j, k) = dot
            do i = 1, _PB_NI
              a(j, i) = a(j, i) - (q(k, i) * r(j, k))
            end do
          end do
!$omp end parallel do
        end do
!$pragma endscop
        end subroutine

      end program
