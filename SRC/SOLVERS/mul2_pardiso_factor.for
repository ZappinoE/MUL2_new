!=======================================================================
!  MKL PARDISO ILP64 FACTORIZATION OF REAL SYMMETRIC CSR MATRICES.
!
!  THE CALLER PASSES THE FULL SYMMETRIC CSR (1-BASED, ILP64). THE UPPER
!  TRIANGLE REQUIRED BY MTYPE 2/-2 IS EXTRACTED HERE AND KEPT INSIDE
!  THE FACTOR HANDLE. THE FACTORS ARE RELEASED WITH PARDISO_RELEASE.
!=======================================================================
      MODULE MUL2_PARDISO_FACTOR                                         ! Module mul2 pardiso factor begins.

      USE MUL2_KINDS, ONLY: I8, R8                                       ! Use from module mul2 kinds: i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, set warning.
     &                       SET_WARNING

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I8), PARAMETER, PUBLIC :: MTYPE_SYMMETRIC_POSITIVE = 2_I8  ! Constant public integer (int64): mtype_symmetric_positive = 2.
      INTEGER(I8), PARAMETER, PUBLIC :: MTYPE_SYMMETRIC_INDEFINITE =     ! Constant public integer (int64): mtype_symmetric_indefinite = -2.
     &                                  -2_I8
!     REAL NON-SYMMETRIC (STRUCTURALLY SYMMETRIC) MATRIX: THE FULL CSR
!     IS KEPT IN THE HANDLE.
      INTEGER(I8), PARAMETER, PUBLIC :: MTYPE_NONSYMMETRIC = 11_I8       ! Constant public integer (int64): mtype_nonsymmetric = 11.

      TYPE, PUBLIC :: PARDISO_FACTOR_TYPE                                ! Definition of the derived type pardiso factor type.
        LOGICAL :: ACTIVE = .FALSE.                                      ! Logical: active = false.
        INTEGER(I8) :: ORDER = 0_I8                                      ! Integer (int64): order = 0.
        INTEGER(I8) :: MTYPE = 0_I8                                      ! Integer (int64): mtype = 0.
        INTEGER(I8) :: PT(64) = 0_I8                                     ! Integer (int64): pt(64) = 0.
        INTEGER(I8) :: IPARM(64) = 0_I8                                  ! Integer (int64): iparm(64) = 0.
        INTEGER(I8), ALLOCATABLE :: ROW_POINTER(:)                       ! Allocatable integer (int64): row_pointer(:).
        INTEGER(I8), ALLOCATABLE :: COLUMN_INDEX(:)                      ! Allocatable integer (int64): column_index(:).
        REAL(R8), ALLOCATABLE :: VALUE(:)                                ! Allocatable real (real64): value(:).
      END TYPE PARDISO_FACTOR_TYPE                                       ! End of the type definition pardiso factor type.

      PUBLIC :: PARDISO_FACTORIZE                                        ! Export: pardiso factorize.
      PUBLIC :: PARDISO_SET_SYSTEM                                       ! Export: pardiso set system.
      PUBLIC :: PARDISO_FACTOR_LOADED                                    ! Export: pardiso factor loaded.
      PUBLIC :: PARDISO_SOLVE                                            ! Export: pardiso solve.
      PUBLIC :: PARDISO_RELEASE                                          ! Export: pardiso release.

      INTERFACE                                                          ! Declare a generic interface.
        SUBROUTINE PARDISO(PT, MAXFCT, MNUM, MTYPE, PHASE, N,            ! Subroutine pardiso takes pt, maxfct, mnum, mtype, phase, n, a, ia, ja, perm, nrhs, iparm, msglvl, b, x, error.
     &      A, IA, JA, PERM, NRHS, IPARM, MSGLVL, B, X, ERROR)
        IMPORT I8, R8                                                    ! Import from the host: i8, r8.
        INTEGER(I8), INTENT(INOUT) :: PT(*)                              ! In/out integer (int64): pt(*).
        INTEGER(I8), INTENT(IN) :: MAXFCT                                ! Input integer (int64): maxfct.
        INTEGER(I8), INTENT(IN) :: MNUM                                  ! Input integer (int64): mnum.
        INTEGER(I8), INTENT(IN) :: MTYPE                                 ! Input integer (int64): mtype.
        INTEGER(I8), INTENT(IN) :: PHASE                                 ! Input integer (int64): phase.
        INTEGER(I8), INTENT(IN) :: N                                     ! Input integer (int64): n.
        REAL(R8), INTENT(IN) :: A(*)                                     ! Input real (real64): a(*).
        INTEGER(I8), INTENT(IN) :: IA(*)                                 ! Input integer (int64): ia(*).
        INTEGER(I8), INTENT(IN) :: JA(*)                                 ! Input integer (int64): ja(*).
        INTEGER(I8), INTENT(INOUT) :: PERM(*)                            ! In/out integer (int64): perm(*).
        INTEGER(I8), INTENT(IN) :: NRHS                                  ! Input integer (int64): nrhs.
        INTEGER(I8), INTENT(INOUT) :: IPARM(*)                           ! In/out integer (int64): iparm(*).
        INTEGER(I8), INTENT(IN) :: MSGLVL                                ! Input integer (int64): msglvl.
        REAL(R8), INTENT(INOUT) :: B(*)                                  ! In/out real (real64): b(*).
        REAL(R8), INTENT(OUT) :: X(*)                                    ! Output real (real64): x(*).
        INTEGER(I8), INTENT(OUT) :: ERROR                                ! Output integer (int64): error.
        END SUBROUTINE PARDISO                                           ! End of the subroutine pardiso.
      END INTERFACE                                                      ! End of the block.

      CONTAINS                                                           ! The procedures of the module follow.

!  REORDER AND FACTORIZE (PHASE 12) A FULL SYMMETRIC CSR SYSTEM.
      SUBROUTINE PARDISO_FACTORIZE(ORDER, ROW_POINTER, COLUMN_INDEX,     ! Subroutine pardiso factorize takes order, row pointer, column index, value, mtype, factor, status.
     &                             VALUE, MTYPE, FACTOR, STATUS)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: VALUE(:)                                   ! Input real (real64): value(:).
      INTEGER(I8), INTENT(IN) :: MTYPE                                   ! Input integer (int64): mtype.
      TYPE(PARDISO_FACTOR_TYPE), INTENT(INOUT) :: FACTOR                 ! In/out of type pardiso_factor_type: factor.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL PARDISO_SET_SYSTEM(ORDER, ROW_POINTER, COLUMN_INDEX,          ! Call pardiso set system with order, row_pointer, column_index, value, factor, status.
     &                        VALUE, FACTOR, STATUS)
      IF (STATUS%CODE .GE. 2_I8) RETURN                                  ! If status.code >= 2, return to the caller.
      CALL PARDISO_FACTOR_LOADED(MTYPE, FACTOR, STATUS)                  ! Call pardiso factor loaded with mtype, factor, status.

      END SUBROUTINE PARDISO_FACTORIZE                                   ! End of the subroutine pardiso factorize.

!  COPY THE UPPER TRIANGLE INTO THE HANDLE. AFTERWARDS THE CALLER MAY
!  FREE ITS OWN COPY OF THE SYSTEM BEFORE THE FACTORIZATION.
      SUBROUTINE PARDISO_SET_SYSTEM(ORDER, ROW_POINTER, COLUMN_INDEX,    ! Subroutine pardiso set system takes order, row pointer, column index, value, factor, status, full.
     &                              VALUE, FACTOR, STATUS, FULL)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: VALUE(:)                                   ! Input real (real64): value(:).
      TYPE(PARDISO_FACTOR_TYPE), INTENT(INOUT) :: FACTOR                 ! In/out of type pardiso_factor_type: factor.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
!     FULL = .TRUE.: KEEP THE WHOLE (NON-SYMMETRIC) MATRIX.
      LOGICAL, INTENT(IN), OPTIONAL :: FULL                              ! Input optional logical: full.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL PARDISO_RELEASE(FACTOR)                                       ! Call pardiso release with factor.
      IF (ORDER .LT. 1_I8 .OR. SIZE(ROW_POINTER,KIND=I8) .NE.            ! If order < 1 or size(row_pointer,kind=i8) /= order+1:
     &    ORDER+1_I8) THEN
        CALL SET_ERROR(STATUS, 'PARDISO_SET_SYSTEM',                     ! Record an error in status: 'INVALID CSR SYSTEM'.
     &                 'INVALID CSR SYSTEM')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (PRESENT(FULL)) THEN                                            ! If present(full):
        IF (FULL) THEN                                                   ! If full:
          ALLOCATE(FACTOR%ROW_POINTER(ORDER+1_I8),                       ! Allocate memory for factor.row_pointer(order+1), factor.column_index(size(column_index)), factor.value(size...
     &             FACTOR%COLUMN_INDEX(SIZE(COLUMN_INDEX)),
     &             FACTOR%VALUE(SIZE(VALUE)))
          FACTOR%ROW_POINTER = ROW_POINTER                               ! Set factor.row_pointer to row_pointer.
          FACTOR%COLUMN_INDEX = COLUMN_INDEX                             ! Set factor.column_index to column_index.
          FACTOR%VALUE = VALUE                                           ! Set factor.value to value.
          FACTOR%ORDER = ORDER                                           ! Set factor.order to order.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      CALL EXTRACT_UPPER_TRIANGLE(ORDER, ROW_POINTER, COLUMN_INDEX,      ! Call extract upper triangle with order, row_pointer, column_index, value, factor, status.
     &     VALUE, FACTOR, STATUS)
      FACTOR%ORDER = ORDER                                               ! Set factor.order to order.

      END SUBROUTINE PARDISO_SET_SYSTEM                                  ! End of the subroutine pardiso set system.

!  PHASE 12 ON THE MATRIX STORED IN THE HANDLE. A CHOLESKY BREAKDOWN
!  (ROUND-OFF IN A VERY ILL-CONDITIONED SPD MATRIX, E.G. HIGH-ORDER
!  TAYLOR EXPANSIONS) IS RETRIED WITH THE SYMMETRIC INDEFINITE
!  FACTORIZATION AND PIVOT PERTURBATION.
      SUBROUTINE PARDISO_FACTOR_LOADED(MTYPE, FACTOR, STATUS)            ! Subroutine pardiso factor loaded takes mtype, factor, status.

      INTEGER(I8), INTENT(IN) :: MTYPE                                   ! Input integer (int64): mtype.
      TYPE(PARDISO_FACTOR_TYPE), INTENT(INOUT) :: FACTOR                 ! In/out of type pardiso_factor_type: factor.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: PERM(1)                                             ! Integer (int64): perm(1).
      INTEGER(I8) :: PHASE                                               ! Integer (int64): phase.
      INTEGER(I8) :: ERROR                                               ! Integer (int64): error.
      INTEGER(I8) :: USED_MTYPE                                          ! Integer (int64): used_mtype.
      REAL(R8) :: DUMMY_B(1)                                             ! Real (real64): dummy_b(1).
      REAL(R8) :: DUMMY_X(1)                                             ! Real (real64): dummy_x(1).
      CHARACTER(LEN=160) :: MESSAGE                                      ! Character (length 160): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (FACTOR%ORDER .LT. 1_I8 .OR. .NOT. ALLOCATED(FACTOR%VALUE))     ! If factor.order < 1 or not allocated(factor.value):
     &  THEN
        CALL SET_ERROR(STATUS, 'PARDISO_FACTOR_LOADED',                  ! Record an error in status: 'NO SYSTEM IN THE HANDLE'.
     &                 'NO SYSTEM IN THE HANDLE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      USED_MTYPE = MTYPE                                                 ! Set used_mtype to mtype.
      DO                                                                 ! Loop until an EXIT statement is reached:
        FACTOR%MTYPE = USED_MTYPE                                        ! Set factor.mtype to used_mtype.
        FACTOR%PT = 0_I8                                                 ! Set factor.pt to zero.
        FACTOR%IPARM = 0_I8                                              ! Set factor.iparm to zero.
        PERM = 0_I8                                                      ! Set perm to zero.
        ERROR = 0_I8                                                     ! Set error to zero.
        PHASE = 12_I8                                                    ! Set phase to 12.
        CALL PARDISO(FACTOR%PT, 1_I8, 1_I8, USED_MTYPE, PHASE,           ! Call pardiso with factor.pt, 1, 1, used_mtype, phase, factor.order, factor.value, factor.row_pointer, facto...
     &       FACTOR%ORDER, FACTOR%VALUE, FACTOR%ROW_POINTER,
     &       FACTOR%COLUMN_INDEX, PERM, 1_I8, FACTOR%IPARM, 0_I8,
     &       DUMMY_B, DUMMY_X, ERROR)
        FACTOR%ACTIVE = .TRUE.                                           ! Set the flag factor.active to true.
        IF (ERROR .EQ. 0_I8) EXIT                                        ! If error = 0, leave the loop.
        CALL PARDISO_FREE_INTERNAL(FACTOR)                               ! Call pardiso free internal with factor.
        IF (ERROR .EQ. -4_I8 .AND.                                       ! If error = -4 and used_mtype = mtype_symmetric_positive:
     &      USED_MTYPE .EQ. MTYPE_SYMMETRIC_POSITIVE) THEN
          USED_MTYPE = MTYPE_SYMMETRIC_INDEFINITE                        ! Set used_mtype to mtype_symmetric_indefinite.
          CALL SET_WARNING(STATUS, 'PARDISO_FACTORIZE',                  ! Record a warning in status: 'CHOLESKY FAILED (ILL-CONDITIONED MATRIX): USED '// 'SYMMETRIC INDEFINITE FACTO...
     &      'CHOLESKY FAILED (ILL-CONDITIONED MATRIX): USED '//
     &      'SYMMETRIC INDEFINITE FACTORIZATION')
          CYCLE                                                          ! Skip to the next iteration.
        END IF                                                           ! End of the IF block.
        WRITE(MESSAGE,'(A,I0,A)')                                        ! Format into the text message: 'PARDISO FACTORIZATION ERROR CODE ', error, pardiso_hint(error).
     &    'PARDISO FACTORIZATION ERROR CODE ', ERROR,
     &    PARDISO_HINT(ERROR)
        CALL SET_ERROR(STATUS, 'PARDISO_FACTORIZE', TRIM(MESSAGE))       ! Record an error in status: trim(message).
        CALL PARDISO_RELEASE(FACTOR)                                     ! Call pardiso release with factor.
        RETURN                                                           ! Return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE PARDISO_FACTOR_LOADED                               ! End of the subroutine pardiso factor loaded.

!  FREE THE INTERNAL MEMORY OF PARDISO BUT KEEP THE MATRIX.
      SUBROUTINE PARDISO_FREE_INTERNAL(FACTOR)                           ! Subroutine pardiso free internal takes factor.

      TYPE(PARDISO_FACTOR_TYPE), INTENT(INOUT) :: FACTOR                 ! In/out of type pardiso_factor_type: factor.
      INTEGER(I8) :: PERM(1)                                             ! Integer (int64): perm(1).
      INTEGER(I8) :: ERROR                                               ! Integer (int64): error.
      REAL(R8) :: DUMMY_B(1)                                             ! Real (real64): dummy_b(1).
      REAL(R8) :: DUMMY_X(1)                                             ! Real (real64): dummy_x(1).

      IF (FACTOR%ACTIVE) THEN                                            ! If factor.active:
        PERM = 0_I8                                                      ! Set perm to zero.
        ERROR = 0_I8                                                     ! Set error to zero.
        CALL PARDISO(FACTOR%PT, 1_I8, 1_I8, FACTOR%MTYPE, -1_I8,         ! Call pardiso with factor.pt, 1, 1, factor.mtype, -1, factor.order, factor.value, factor.row_pointer, factor...
     &       FACTOR%ORDER, FACTOR%VALUE, FACTOR%ROW_POINTER,
     &       FACTOR%COLUMN_INDEX, PERM, 1_I8, FACTOR%IPARM, 0_I8,
     &       DUMMY_B, DUMMY_X, ERROR)
      END IF                                                             ! End of the IF block.
      FACTOR%ACTIVE = .FALSE.                                            ! Set the flag factor.active to false.

      END SUBROUTINE PARDISO_FREE_INTERNAL                               ! End of the subroutine pardiso free internal.
!  SOLVE A X = B WITH THE FACTORS OF THE HANDLE (PHASE 33).
      SUBROUTINE PARDISO_SOLVE(FACTOR, RIGHT_HAND_SIDE, SOLUTION,        ! Subroutine pardiso solve takes factor, right hand side, solution, status.
     &                         STATUS)

      TYPE(PARDISO_FACTOR_TYPE), INTENT(INOUT) :: FACTOR                 ! In/out of type pardiso_factor_type: factor.
      REAL(R8), INTENT(IN) :: RIGHT_HAND_SIDE(:)                         ! Input real (real64): right_hand_side(:).
      REAL(R8), INTENT(OUT) :: SOLUTION(:)                               ! Output real (real64): solution(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: WORK(:)                                   ! Allocatable real (real64): work(:).
      INTEGER(I8) :: PERM(1)                                             ! Integer (int64): perm(1).
      INTEGER(I8) :: PHASE                                               ! Integer (int64): phase.
      INTEGER(I8) :: ERROR                                               ! Integer (int64): error.
      CHARACTER(LEN=96) :: MESSAGE                                       ! Character (length 96): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (.NOT. FACTOR%ACTIVE .OR.                                       ! If not factor.active or size(right_hand_side,kind=i8) /= factor.order or size(solution,kind=i8) /= factor.o...
     &    SIZE(RIGHT_HAND_SIDE,KIND=I8) .NE. FACTOR%ORDER .OR.
     &    SIZE(SOLUTION,KIND=I8) .NE. FACTOR%ORDER) THEN
        CALL SET_ERROR(STATUS, 'PARDISO_SOLVE',                          ! Record an error in status: 'NO FACTORS OR INCONSISTENT VECTOR SIZE'.
     &                 'NO FACTORS OR INCONSISTENT VECTOR SIZE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(WORK(FACTOR%ORDER))                                       ! Allocate memory for work(factor.order).
      WORK = RIGHT_HAND_SIDE                                             ! Set work to right_hand_side.
      SOLUTION = 0.0_R8                                                  ! Set solution to zero.
      PERM = 0_I8                                                        ! Set perm to zero.
      ERROR = 0_I8                                                       ! Set error to zero.
      PHASE = 33_I8                                                      ! Set phase to 33.
      CALL PARDISO(FACTOR%PT, 1_I8, 1_I8, FACTOR%MTYPE, PHASE,           ! Call pardiso with factor.pt, 1, 1, factor.mtype, phase, factor.order, factor.value, factor.row_pointer, fac...
     &     FACTOR%ORDER, FACTOR%VALUE, FACTOR%ROW_POINTER,
     &     FACTOR%COLUMN_INDEX, PERM, 1_I8, FACTOR%IPARM, 0_I8,
     &     WORK, SOLUTION, ERROR)
      IF (ERROR .NE. 0_I8) THEN                                          ! If error /= 0:
        WRITE(MESSAGE,'(A,I0)') 'PARDISO SOLVE ERROR CODE ', ERROR       ! Format into the text message: 'PARDISO SOLVE ERROR CODE ', error.
        CALL SET_ERROR(STATUS, 'PARDISO_SOLVE', TRIM(MESSAGE))           ! Record an error in status: trim(message).
      END IF                                                             ! End of the IF block.

      END SUBROUTINE PARDISO_SOLVE                                       ! End of the subroutine pardiso solve.

!  FREE THE INTERNAL MEMORY OF PARDISO (PHASE -1). SAFE TO REPEAT.
      SUBROUTINE PARDISO_RELEASE(FACTOR)                                 ! Subroutine pardiso release takes factor.

      TYPE(PARDISO_FACTOR_TYPE), INTENT(INOUT) :: FACTOR                 ! In/out of type pardiso_factor_type: factor.
      INTEGER(I8) :: PERM(1)                                             ! Integer (int64): perm(1).
      INTEGER(I8) :: ERROR                                               ! Integer (int64): error.
      REAL(R8) :: DUMMY_B(1)                                             ! Real (real64): dummy_b(1).
      REAL(R8) :: DUMMY_X(1)                                             ! Real (real64): dummy_x(1).

      IF (FACTOR%ACTIVE) THEN                                            ! If factor.active:
        PERM = 0_I8                                                      ! Set perm to zero.
        ERROR = 0_I8                                                     ! Set error to zero.
        CALL PARDISO(FACTOR%PT, 1_I8, 1_I8, FACTOR%MTYPE, -1_I8,         ! Call pardiso with factor.pt, 1, 1, factor.mtype, -1, factor.order, factor.value, factor.row_pointer, factor...
     &       FACTOR%ORDER, FACTOR%VALUE, FACTOR%ROW_POINTER,
     &       FACTOR%COLUMN_INDEX, PERM, 1_I8, FACTOR%IPARM, 0_I8,
     &       DUMMY_B, DUMMY_X, ERROR)
      END IF                                                             ! End of the IF block.
      FACTOR%ACTIVE = .FALSE.                                            ! Set the flag factor.active to false.
      FACTOR%ORDER = 0_I8                                                ! Set factor.order to zero.
      IF (ALLOCATED(FACTOR%ROW_POINTER))                                 ! If allocated(factor.row_pointer), free the memory of factor.row_pointer.
     &  DEALLOCATE(FACTOR%ROW_POINTER)
      IF (ALLOCATED(FACTOR%COLUMN_INDEX))                                ! If allocated(factor.column_index), free the memory of factor.column_index.
     &  DEALLOCATE(FACTOR%COLUMN_INDEX)
      IF (ALLOCATED(FACTOR%VALUE)) DEALLOCATE(FACTOR%VALUE)              ! If allocated(factor.value), free the memory of factor.value.

      END SUBROUTINE PARDISO_RELEASE                                     ! End of the subroutine pardiso release.

      SUBROUTINE EXTRACT_UPPER_TRIANGLE(ORDER, ROW_POINTER,              ! Subroutine extract upper triangle takes order, row pointer, column index, value, factor, status.
     &     COLUMN_INDEX, VALUE, FACTOR, STATUS)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: VALUE(:)                                   ! Input real (real64): value(:).
      TYPE(PARDISO_FACTOR_TYPE), INTENT(INOUT) :: FACTOR                 ! In/out of type pardiso_factor_type: factor.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I8) :: UPPER_COUNT                                         ! Integer (int64): upper_count.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I8) :: OUTPUT_POSITION                                     ! Integer (int64): output_position.
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: COLUMN                                              ! Integer (int64): column.
      LOGICAL :: DIAGONAL_FOUND                                          ! Logical: diagonal_found.

      UPPER_COUNT = 0_I8                                                 ! Set upper_count to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        DO POSITION = ROW_POINTER(ROW), ROW_POINTER(ROW+1_I8)-1_I8       ! Loop position from row_pointer(row) to row_pointer(row+1)-1:
          IF (COLUMN_INDEX(POSITION) .GE. ROW)                           ! If column_index(position) >= row, add 1 to upper_count.
     &      UPPER_COUNT = UPPER_COUNT+1_I8
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      ALLOCATE(FACTOR%ROW_POINTER(ORDER+1_I8))                           ! Allocate memory for factor.row_pointer(order+1).
      ALLOCATE(FACTOR%COLUMN_INDEX(UPPER_COUNT))                         ! Allocate memory for factor.column_index(upper_count).
      ALLOCATE(FACTOR%VALUE(UPPER_COUNT))                                ! Allocate memory for factor.value(upper_count).
      FACTOR%ROW_POINTER(1) = 1_I8                                       ! Set factor.row_pointer(1) to 1.
      OUTPUT_POSITION = 0_I8                                             ! Set output_position to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        DIAGONAL_FOUND = .FALSE.                                         ! Set the flag diagonal_found to false.
        DO POSITION = ROW_POINTER(ROW), ROW_POINTER(ROW+1_I8)-1_I8       ! Loop position from row_pointer(row) to row_pointer(row+1)-1:
          COLUMN = COLUMN_INDEX(POSITION)                                ! Set column to column_index(position).
          IF (COLUMN .LT. ROW) CYCLE                                     ! If column < row, skip to the next iteration.
          OUTPUT_POSITION = OUTPUT_POSITION+1_I8                         ! Add 1 to output_position.
          FACTOR%COLUMN_INDEX(OUTPUT_POSITION) = COLUMN                  ! Set factor.column_index(output_position) to column.
          FACTOR%VALUE(OUTPUT_POSITION) = VALUE(POSITION)                ! Set factor.value(output_position) to value(position).
          IF (COLUMN .EQ. ROW) DIAGONAL_FOUND = .TRUE.                   ! If column = row, set the flag diagonal_found to true.
        END DO                                                           ! End of the loop.
        IF (.NOT. DIAGONAL_FOUND) THEN                                   ! If not diagonal_found:
          CALL SET_ERROR(STATUS, 'EXTRACT_UPPER_TRIANGLE',               ! Record an error in status: 'CSR ROW HAS NO DIAGONAL ENTRY'.
     &                   'CSR ROW HAS NO DIAGONAL ENTRY')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        FACTOR%ROW_POINTER(ROW+1_I8) = OUTPUT_POSITION+1_I8              ! Set factor.row_pointer(row+1) to output_position+1.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EXTRACT_UPPER_TRIANGLE                              ! End of the subroutine extract upper triangle.


!  MEANING OF THE MOST COMMON PARDISO ERROR CODES.
      CHARACTER(LEN=64) FUNCTION PARDISO_HINT(ERROR)                     ! Function pardiso hint takes error.

      INTEGER(I8), INTENT(IN) :: ERROR                                   ! Input integer (int64): error.

      SELECT CASE(ERROR)                                                 ! Choose according to the value of error:
      CASE(-2_I8)                                                        ! Case -2:
        PARDISO_HINT = ' (NOT ENOUGH MEMORY)'                            ! Set pardiso_hint to ' (NOT ENOUGH MEMORY)'.
      CASE(-3_I8)                                                        ! Case -3:
        PARDISO_HINT = ' (REORDERING FAILED)'                            ! Set pardiso_hint to ' (REORDERING FAILED)'.
      CASE(-4_I8)                                                        ! Case -4:
        PARDISO_HINT = ' (ZERO PIVOT: SINGULAR MATRIX, CHECK SUPPORTS)'  ! Set pardiso_hint to ' (ZERO PIVOT: SINGULAR MATRIX, CHECK SUPPORTS)'.
      CASE(-5_I8, -6_I8)                                                 ! Case -5, -6:
        PARDISO_HINT = ' (INTERNAL PARDISO FAILURE)'                     ! Set pardiso_hint to ' (INTERNAL PARDISO FAILURE)'.
      CASE DEFAULT                                                       ! In every other case:
        PARDISO_HINT = ' '                                               ! Set pardiso_hint to ' '.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION PARDISO_HINT                                          ! End of the function pardiso hint.
      END MODULE MUL2_PARDISO_FACTOR                                     ! End of the module mul2 pardiso factor.
