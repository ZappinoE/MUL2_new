!=======================================================================
!  OPTIONAL MKL PARDISO BACKEND TEST.
!=======================================================================
      PROGRAM MUL2_PARDISO_TESTS                                         ! Main program mul2 pardiso tests begins.

      USE MUL2_KINDS, ONLY: I8, R8                                       ! Use from module mul2 kinds: i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, STATUS_IS_OK                   ! Use from module mul2 status: status type, status is ok.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_PARDISO_SOLVER, ONLY:                                     ! Use from module mul2 pardiso solver: solve symmetric positive definite.
     &     SOLVE_SYMMETRIC_POSITIVE_DEFINITE

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.

      TYPE(SPARSE_SYSTEM_TYPE) :: SYSTEM                                 ! Of type sparse_system_type: system.
      TYPE(STATUS_TYPE) :: STATUS                                        ! Of type status_type: status.
      REAL(R8) :: RIGHT_HAND_SIDE(2)                                     ! Real (real64): right_hand_side(2).
      REAL(R8), ALLOCATABLE :: SOLUTION(:)                               ! Allocatable real (real64): solution(:).

      SYSTEM%ORDER = 2_I8                                                ! Set system.order to 2.
      SYSTEM%NONZERO_COUNT = 4_I8                                        ! Set system.nonzero_count to 4.
      ALLOCATE(SYSTEM%ROW_POINTER(3))                                    ! Allocate memory for system.row_pointer(3).
      ALLOCATE(SYSTEM%COLUMN_INDEX(4))                                   ! Allocate memory for system.column_index(4).
      ALLOCATE(SYSTEM%STIFFNESS(4))                                      ! Allocate memory for system.stiffness(4).
      ALLOCATE(SYSTEM%MASS(4))                                           ! Allocate memory for system.mass(4).
      SYSTEM%ROW_POINTER = [1_I8,3_I8,5_I8]                              ! Set system.row_pointer to [1,3,5].
      SYSTEM%COLUMN_INDEX = [1_I8,2_I8,1_I8,2_I8]                        ! Set system.column_index to [1,2,1,2].
      SYSTEM%STIFFNESS = [4.0_R8,1.0_R8,1.0_R8,3.0_R8]                   ! Set system.stiffness to [4.0,1.0,1.0,3.0].
      SYSTEM%MASS = 0.0_R8                                               ! Set system.mass to zero.
      RIGHT_HAND_SIDE = [1.0_R8,2.0_R8]                                  ! Set right_hand_side to [1.0,2.0].

      CALL SOLVE_SYMMETRIC_POSITIVE_DEFINITE(SYSTEM,                     ! Call solve symmetric positive definite with system, right_hand_side, solution, status.
     &     RIGHT_HAND_SIDE,SOLUTION,STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: '//TRIM(STATUS%MESSAGE)                    ! Print: 'FAIL: '//trim(status.message).
        ERROR STOP 1                                                     ! Stop the program with an error.
      END IF                                                             ! End of the IF block.
      IF (MAXVAL(ABS(SOLUTION-[1.0_R8/11.0_R8,                           ! If maxval(abs(solution-[1.0/11.0, 7.0/11.0])) > 1.0e-13:
     &    7.0_R8/11.0_R8])) .GT. 1.0E-13_R8) THEN
        WRITE(*,'(A,2ES16.7)') 'FAIL: PARDISO SOLUTION ',SOLUTION        ! Print: 'FAIL: PARDISO SOLUTION ', solution.
        ERROR STOP 1                                                     ! Stop the program with an error.
      END IF                                                             ! End of the IF block.
      WRITE(*,'(A)') 'MUL2_PARDISO_TESTS PASSED'                         ! Print: 'MUL2_PARDISO_TESTS PASSED'.

      END PROGRAM MUL2_PARDISO_TESTS                                     ! End of the program mul2 pardiso tests.
