!=======================================================================
!  BASIC OPERATIONS ON THE SHARED CSR PATTERN.
!
!  REDUCTION TO THE FREE DOFS KEEPS A MAP FROM EVERY REDUCED ENTRY TO
!  ITS POSITION IN THE FULL PATTERN, SO THAT ANY VALUE ARRAY (K, M OR
!  A COMBINATION) IS REDUCED WITHOUT RE-BUILDING THE PATTERN.
!=======================================================================
      MODULE MUL2_SPARSE_OPERATIONS                                      ! Module mul2 sparse operations begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: REDUCED_PATTERN_TYPE                               ! Definition of the derived type reduced pattern type.
        INTEGER(I8) :: ORDER = 0_I8                                      ! Integer (int64): order = 0.
        INTEGER(I8) :: NONZERO_COUNT = 0_I8                              ! Integer (int64): nonzero_count = 0.
        INTEGER(I8), ALLOCATABLE :: FREE_TO_GLOBAL(:)                    ! Allocatable integer (int64): free_to_global(:).
        INTEGER(I8), ALLOCATABLE :: ROW_POINTER(:)                       ! Allocatable integer (int64): row_pointer(:).
        INTEGER(I8), ALLOCATABLE :: COLUMN_INDEX(:)                      ! Allocatable integer (int64): column_index(:).
        INTEGER(I8), ALLOCATABLE :: SOURCE_POSITION(:)                   ! Allocatable integer (int64): source_position(:).
      END TYPE REDUCED_PATTERN_TYPE                                      ! End of the type definition reduced pattern type.

      PUBLIC :: SPARSE_MULTIPLY                                          ! Export: sparse multiply.
      PUBLIC :: BUILD_REDUCED_PATTERN                                    ! Export: build reduced pattern.
      PUBLIC :: REDUCE_VALUES                                            ! Export: reduce values.
      PUBLIC :: EXPAND_VECTOR                                            ! Export: expand vector.

      CONTAINS                                                           ! The procedures of the module follow.

!  Y = A X FOR A FULL (NON-TRIANGULAR) CSR MATRIX.
      SUBROUTINE SPARSE_MULTIPLY(ORDER, ROW_POINTER, COLUMN_INDEX,       ! Subroutine sparse multiply takes order, row pointer, column index, value, x, y.
     &                           VALUE, X, Y)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: VALUE(:)                                   ! Input real (real64): value(:).
      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(OUT) :: Y(:)                                      ! Output real (real64): y(:).
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      REAL(R8) :: SUM                                                    ! Real (real64): sum.

!     ROWS ARE INDEPENDENT: THE RESULT DOES NOT DEPEND ON THE THREADS.
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(ROW,POSITION,SUM)
!$OMP& SCHEDULE(STATIC)
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        SUM = 0.0_R8                                                     ! Set sum to zero.
        DO POSITION = ROW_POINTER(ROW), ROW_POINTER(ROW+1_I8)-1_I8       ! Loop position from row_pointer(row) to row_pointer(row+1)-1:
          SUM = SUM + VALUE(POSITION)*X(COLUMN_INDEX(POSITION))          ! Add value(position)*x(column_index(position)) to sum.
        END DO                                                           ! End of the loop.
        Y(ROW) = SUM                                                     ! Set y(row) to sum.
      END DO                                                             ! End of the loop.
!$OMP END PARALLEL DO

      END SUBROUTINE SPARSE_MULTIPLY                                     ! End of the subroutine sparse multiply.

!  PATTERN OF THE SUBMATRIX ON THE DOFS WITH CONSTRAINED(DOF) = FALSE.
      SUBROUTINE BUILD_REDUCED_PATTERN(ORDER, ROW_POINTER,               ! Subroutine build reduced pattern takes order, row pointer, column index, constrained, pattern.
     &     COLUMN_INDEX, CONSTRAINED, PATTERN)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      LOGICAL, INTENT(IN) :: CONSTRAINED(:)                              ! Input logical: constrained(:).
      TYPE(REDUCED_PATTERN_TYPE), INTENT(INOUT) :: PATTERN               ! In/out of type reduced_pattern_type: pattern.
      INTEGER(I8), ALLOCATABLE :: GLOBAL_TO_FREE(:)                      ! Allocatable integer (int64): global_to_free(:).
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I8) :: FREE_COUNT                                          ! Integer (int64): free_count.
      INTEGER(I8) :: ENTRY_COUNT                                         ! Integer (int64): entry_count.

      IF (ALLOCATED(PATTERN%FREE_TO_GLOBAL))                             ! If allocated(pattern.free_to_global), free the memory of pattern.free_to_global.
     &  DEALLOCATE(PATTERN%FREE_TO_GLOBAL)
      IF (ALLOCATED(PATTERN%ROW_POINTER))                                ! If allocated(pattern.row_pointer), free the memory of pattern.row_pointer.
     &  DEALLOCATE(PATTERN%ROW_POINTER)
      IF (ALLOCATED(PATTERN%COLUMN_INDEX))                               ! If allocated(pattern.column_index), free the memory of pattern.column_index.
     &  DEALLOCATE(PATTERN%COLUMN_INDEX)
      IF (ALLOCATED(PATTERN%SOURCE_POSITION))                            ! If allocated(pattern.source_position), free the memory of pattern.source_position.
     &  DEALLOCATE(PATTERN%SOURCE_POSITION)

      ALLOCATE(GLOBAL_TO_FREE(ORDER))                                    ! Allocate memory for global_to_free(order).
      GLOBAL_TO_FREE = 0_I8                                              ! Set global_to_free to zero.
      FREE_COUNT = 0_I8                                                  ! Set free_count to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        IF (CONSTRAINED(ROW)) CYCLE                                      ! If constrained(row), skip to the next iteration.
        FREE_COUNT = FREE_COUNT + 1_I8                                   ! Add 1 to free_count.
        GLOBAL_TO_FREE(ROW) = FREE_COUNT                                 ! Set global_to_free(row) to free_count.
      END DO                                                             ! End of the loop.
      ENTRY_COUNT = 0_I8                                                 ! Set entry_count to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        IF (CONSTRAINED(ROW)) CYCLE                                      ! If constrained(row), skip to the next iteration.
        DO POSITION = ROW_POINTER(ROW), ROW_POINTER(ROW+1_I8)-1_I8       ! Loop position from row_pointer(row) to row_pointer(row+1)-1:
          IF (GLOBAL_TO_FREE(COLUMN_INDEX(POSITION)) .GT. 0_I8)          ! If global_to_free(column_index(position)) > 0, add 1 to entry_count.
     &      ENTRY_COUNT = ENTRY_COUNT + 1_I8
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      PATTERN%ORDER = FREE_COUNT                                         ! Set pattern.order to free_count.
      PATTERN%NONZERO_COUNT = ENTRY_COUNT                                ! Set pattern.nonzero_count to entry_count.
      ALLOCATE(PATTERN%FREE_TO_GLOBAL(FREE_COUNT))                       ! Allocate memory for pattern.free_to_global(free_count).
      ALLOCATE(PATTERN%ROW_POINTER(FREE_COUNT+1_I8))                     ! Allocate memory for pattern.row_pointer(free_count+1).
      ALLOCATE(PATTERN%COLUMN_INDEX(ENTRY_COUNT))                        ! Allocate memory for pattern.column_index(entry_count).
      ALLOCATE(PATTERN%SOURCE_POSITION(ENTRY_COUNT))                     ! Allocate memory for pattern.source_position(entry_count).
      PATTERN%ROW_POINTER(1) = 1_I8                                      ! Set pattern.row_pointer(1) to 1.
      FREE_COUNT = 0_I8                                                  ! Set free_count to zero.
      ENTRY_COUNT = 0_I8                                                 ! Set entry_count to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        IF (CONSTRAINED(ROW)) CYCLE                                      ! If constrained(row), skip to the next iteration.
        FREE_COUNT = FREE_COUNT + 1_I8                                   ! Add 1 to free_count.
        PATTERN%FREE_TO_GLOBAL(FREE_COUNT) = ROW                         ! Set pattern.free_to_global(free_count) to row.
        DO POSITION = ROW_POINTER(ROW), ROW_POINTER(ROW+1_I8)-1_I8       ! Loop position from row_pointer(row) to row_pointer(row+1)-1:
          IF (GLOBAL_TO_FREE(COLUMN_INDEX(POSITION)) .EQ. 0_I8)          ! If global_to_free(column_index(position)) = 0, skip to the next iteration.
     &      CYCLE
          ENTRY_COUNT = ENTRY_COUNT + 1_I8                               ! Add 1 to entry_count.
          PATTERN%COLUMN_INDEX(ENTRY_COUNT) =                            ! Set pattern.column_index(entry_count) to global_to_free(column_index(position)).
     &      GLOBAL_TO_FREE(COLUMN_INDEX(POSITION))
          PATTERN%SOURCE_POSITION(ENTRY_COUNT) = POSITION                ! Set pattern.source_position(entry_count) to position.
        END DO                                                           ! End of the loop.
        PATTERN%ROW_POINTER(FREE_COUNT+1_I8) = ENTRY_COUNT + 1_I8        ! Set pattern.row_pointer(free_count+1) to entry_count + 1.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_REDUCED_PATTERN                               ! End of the subroutine build reduced pattern.

      SUBROUTINE REDUCE_VALUES(PATTERN, FULL_VALUE, REDUCED_VALUE)       ! Subroutine reduce values takes pattern, full value, reduced value.

      TYPE(REDUCED_PATTERN_TYPE), INTENT(IN) :: PATTERN                  ! Input of type reduced_pattern_type: pattern.
      REAL(R8), INTENT(IN) :: FULL_VALUE(:)                              ! Input real (real64): full_value(:).
      REAL(R8), INTENT(OUT) :: REDUCED_VALUE(:)                          ! Output real (real64): reduced_value(:).
      INTEGER(I8) :: I                                                   ! Integer (int64): i.

      DO I = 1_I8, PATTERN%NONZERO_COUNT                                 ! Loop i from 1 to pattern.nonzero_count:
        REDUCED_VALUE(I) = FULL_VALUE(PATTERN%SOURCE_POSITION(I))        ! Set reduced_value(i) to full_value(pattern.source_position(i)).
      END DO                                                             ! End of the loop.

      END SUBROUTINE REDUCE_VALUES                                       ! End of the subroutine reduce values.

!  SCATTER A REDUCED VECTOR BACK TO THE FULL DOF NUMBERING.
      SUBROUTINE EXPAND_VECTOR(PATTERN, REDUCED, FULL)                   ! Subroutine expand vector takes pattern, reduced, full.

      TYPE(REDUCED_PATTERN_TYPE), INTENT(IN) :: PATTERN                  ! Input of type reduced_pattern_type: pattern.
      REAL(R8), INTENT(IN) :: REDUCED(:)                                 ! Input real (real64): reduced(:).
      REAL(R8), INTENT(INOUT) :: FULL(:)                                 ! In/out real (real64): full(:).
      INTEGER(I8) :: I                                                   ! Integer (int64): i.

      DO I = 1_I8, PATTERN%ORDER                                         ! Loop i from 1 to pattern.order:
        FULL(PATTERN%FREE_TO_GLOBAL(I)) = REDUCED(I)                     ! Set full(pattern.free_to_global(i)) to reduced(i).
      END DO                                                             ! End of the loop.

      END SUBROUTINE EXPAND_VECTOR                                       ! End of the subroutine expand vector.

      END MODULE MUL2_SPARSE_OPERATIONS                                  ! End of the module mul2 sparse operations.
