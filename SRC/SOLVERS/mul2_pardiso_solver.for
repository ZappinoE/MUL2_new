!=======================================================================
!  ONE-SHOT LINEAR SOLVE FOR REAL SYMMETRIC POSITIVE-DEFINITE CSR
!  SYSTEMS (STATIC ANALYSIS) ON TOP OF MUL2_PARDISO_FACTOR.
!=======================================================================
      MODULE MUL2_PARDISO_SOLVER                                         ! Module mul2 pardiso solver begins.

      USE MUL2_KINDS, ONLY: I8, R8                                       ! Use from module mul2 kinds: i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       STATUS_IS_OK
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_PARDISO_FACTOR, ONLY: PARDISO_FACTOR_TYPE,                ! Use from module mul2 pardiso factor: pardiso factor type, mtype symmetric positive, pardiso set system, par...
     &     MTYPE_SYMMETRIC_POSITIVE, PARDISO_SET_SYSTEM,
     &     PARDISO_FACTOR_LOADED,
     &     PARDISO_SOLVE, PARDISO_RELEASE

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: SOLVE_SYMMETRIC_POSITIVE_DEFINITE                        ! Export: solve symmetric positive definite.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE SOLVE_SYMMETRIC_POSITIVE_DEFINITE(SYSTEM,               ! Subroutine solve symmetric positive definite takes system, right hand side, solution, status, release system.
     &     RIGHT_HAND_SIDE, SOLUTION, STATUS, RELEASE_SYSTEM)

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      REAL(R8), INTENT(IN) :: RIGHT_HAND_SIDE(:)                         ! Input real (real64): right_hand_side(:).
      REAL(R8), ALLOCATABLE, INTENT(INOUT) :: SOLUTION(:)                ! Allocatable in/out real (real64): solution(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      LOGICAL, INTENT(IN), OPTIONAL :: RELEASE_SYSTEM                    ! Input optional logical: release_system.
      TYPE(PARDISO_FACTOR_TYPE) :: FACTOR                                ! Of type pardiso_factor_type: factor.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (SYSTEM%ORDER .LT. 1_I8 .OR.                                    ! If system.order < 1 or not allocated(system.row_pointer) or not allocated(system.column_index) or not alloc...
     &    .NOT. ALLOCATED(SYSTEM%ROW_POINTER) .OR.
     &    .NOT. ALLOCATED(SYSTEM%COLUMN_INDEX) .OR.
     &    .NOT. ALLOCATED(SYSTEM%STIFFNESS) .OR.
     &    SIZE(RIGHT_HAND_SIDE,KIND=I8) .NE. SYSTEM%ORDER) THEN
        CALL SET_ERROR(STATUS,                                           ! Record an error in status: 'INVALID OR INCONSISTENT LINEAR SYSTEM'.
     &    'SOLVE_SYMMETRIC_POSITIVE_DEFINITE',
     &    'INVALID OR INCONSISTENT LINEAR SYSTEM')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (ALLOCATED(SOLUTION)) DEALLOCATE(SOLUTION)                      ! If allocated(solution), free the memory of solution.
      ALLOCATE(SOLUTION(SYSTEM%ORDER))                                   ! Allocate memory for solution(system.order).
      SOLUTION = 0.0_R8                                                  ! Set solution to zero.

      CALL PARDISO_SET_SYSTEM(SYSTEM%ORDER, SYSTEM%ROW_POINTER,          ! Call pardiso set system with system.order, system.row_pointer, system.column_index, system.stiffness, facto...
     &     SYSTEM%COLUMN_INDEX, SYSTEM%STIFFNESS, FACTOR, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
!     THE HANDLE HOLDS ITS OWN COPY: THE CALLER'S MATRIX CAN GO BEFORE
!     THE (MEMORY-HUNGRY) FACTORIZATION.
      IF (PRESENT(RELEASE_SYSTEM)) THEN                                  ! If present(release_system):
        IF (RELEASE_SYSTEM) THEN                                         ! If release_system:
          DEALLOCATE(SYSTEM%STIFFNESS, SYSTEM%COLUMN_INDEX,              ! Free the memory of system.stiffness, system.column_index, system.row_pointer.
     &               SYSTEM%ROW_POINTER)
          IF (ALLOCATED(SYSTEM%MASS)) DEALLOCATE(SYSTEM%MASS)            ! If allocated(system.mass), free the memory of system.mass.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      CALL PARDISO_FACTOR_LOADED(MTYPE_SYMMETRIC_POSITIVE, FACTOR,       ! Call pardiso factor loaded with mtype_symmetric_positive, factor, status.
     &                           STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL PARDISO_SOLVE(FACTOR, RIGHT_HAND_SIDE, SOLUTION, STATUS)      ! Call pardiso solve with factor, right_hand_side, solution, status.
      CALL PARDISO_RELEASE(FACTOR)                                       ! Call pardiso release with factor.

      END SUBROUTINE SOLVE_SYMMETRIC_POSITIVE_DEFINITE                   ! End of the subroutine solve symmetric positive definite.

      END MODULE MUL2_PARDISO_SOLVER                                     ! End of the module mul2 pardiso solver.
