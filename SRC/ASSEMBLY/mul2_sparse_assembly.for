!=======================================================================
!  ONE-BASED ILP64 CSR PATTERN AND GLOBAL MATRIX ASSEMBLY.
!=======================================================================
      MODULE MUL2_SPARSE_ASSEMBLY                                        ! Module mul2 sparse assembly begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       STATUS_IS_OK
      USE MUL2_ELEMENT_MATRICES, ONLY: ELEMENT_MATRIX_TYPE               ! Use from module mul2 element matrices: element matrix type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: SPARSE_SYSTEM_TYPE                                 ! Definition of the derived type sparse system type.
        INTEGER(I8) :: ORDER = 0_I8                                      ! Integer (int64): order = 0.
        INTEGER(I8) :: NONZERO_COUNT = 0_I8                              ! Integer (int64): nonzero_count = 0.
        INTEGER(I8), ALLOCATABLE :: ROW_POINTER(:)                       ! Allocatable integer (int64): row_pointer(:).
        INTEGER(I8), ALLOCATABLE :: COLUMN_INDEX(:)                      ! Allocatable integer (int64): column_index(:).
        REAL(R8), ALLOCATABLE :: STIFFNESS(:)                            ! Allocatable real (real64): stiffness(:).
        REAL(R8), ALLOCATABLE :: MASS(:)                                 ! Allocatable real (real64): mass(:).
      END TYPE SPARSE_SYSTEM_TYPE                                        ! End of the type definition sparse system type.

!  TABLE(K) > 0 MARKS A LAGRANGE-EXPANSION DOF AND TERM(K) ITS TERM: TWO
!  SUCH DOFS OF THE SAME TABLE ARE COUPLED ONLY IF COUPLED(TERM,TERM).
      TYPE, PUBLIC :: DOF_LIST_TYPE                                      ! Definition of the derived type dof list type.
        INTEGER(I8), ALLOCATABLE :: GLOBAL_DOF(:)                        ! Allocatable integer (int64): global_dof(:).
        INTEGER(I4), ALLOCATABLE :: TABLE(:)                             ! Allocatable integer (int32): table(:).
        INTEGER(I4), ALLOCATABLE :: TERM(:)                              ! Allocatable integer (int32): term(:).
      END TYPE DOF_LIST_TYPE                                             ! End of the type definition dof list type.

      TYPE, PUBLIC :: COUPLING_TABLE_TYPE                                ! Definition of the derived type coupling table type.
        LOGICAL, ALLOCATABLE :: COUPLED(:,:)                             ! Allocatable logical: coupled(:,:).
      END TYPE COUPLING_TABLE_TYPE                                       ! End of the type definition coupling table type.

      PUBLIC :: BUILD_SPARSE_PATTERN                                     ! Export: build sparse pattern.
      PUBLIC :: BUILD_PATTERN_FROM_DOF_LISTS                             ! Export: build pattern from dof lists.
      PUBLIC :: SCATTER_ELEMENT                                          ! Export: scatter element.
      PUBLIC :: ASSEMBLE_ELEMENT_MATRICES                                ! Export: assemble element matrices.
      PUBLIC :: BUILD_AND_ASSEMBLE_SPARSE_SYSTEM                         ! Export: build and assemble sparse system.
      PUBLIC :: CLEAR_SPARSE_SYSTEM                                      ! Export: clear sparse system.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_AND_ASSEMBLE_SPARSE_SYSTEM(TOTAL_DOF,             ! Subroutine build and assemble sparse system takes total dof, element matrices, system, status.
     &     ELEMENT_MATRICES, SYSTEM, STATUS)

      INTEGER(I8), INTENT(IN) :: TOTAL_DOF                               ! Input integer (int64): total_dof.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) ::                        ! In/out of type element_matrix_type: element_matrices(:).
     &  ELEMENT_MATRICES(:)
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL BUILD_SPARSE_PATTERN(TOTAL_DOF, ELEMENT_MATRICES,             ! Call build sparse pattern with total_dof, element_matrices, system, status.
     &                          SYSTEM, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL ASSEMBLE_ELEMENT_MATRICES(ELEMENT_MATRICES, SYSTEM,           ! Call assemble element matrices with element_matrices, system, status.
     &                               STATUS)

      END SUBROUTINE BUILD_AND_ASSEMBLE_SPARSE_SYSTEM                    ! End of the subroutine build and assemble sparse system.

      SUBROUTINE BUILD_SPARSE_PATTERN(TOTAL_DOF,                         ! Subroutine build sparse pattern takes total dof, element matrices, system, status.
     &     ELEMENT_MATRICES, SYSTEM, STATUS)

      INTEGER(I8), INTENT(IN) :: TOTAL_DOF                               ! Input integer (int64): total_dof.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) ::                        ! In/out of type element_matrix_type: element_matrices(:).
     &  ELEMENT_MATRICES(:)
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8), ALLOCATABLE :: ROW(:)                                 ! Allocatable integer (int64): row(:).
      INTEGER(I8), ALLOCATABLE :: COLUMN(:)                              ! Allocatable integer (int64): column(:).
      INTEGER(I8) :: ENTRY_COUNT                                         ! Integer (int64): entry_count.
      INTEGER(I8) :: UNIQUE_COUNT                                        ! Integer (int64): unique_count.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I8) :: PREVIOUS_ROW                                        ! Integer (int64): previous_row.
      INTEGER(I8) :: PREVIOUS_COLUMN                                     ! Integer (int64): previous_column.
      INTEGER(I8) :: GLOBAL_ROW                                          ! Integer (int64): global_row.
      INTEGER(I8) :: GLOBAL_COLUMN                                       ! Integer (int64): global_column.
      INTEGER(I8) :: I                                                   ! Integer (int64): i.
      INTEGER(I8) :: J                                                   ! Integer (int64): j.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: LOCAL_COUNT                                         ! Integer (int32): local_count.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_SPARSE_SYSTEM(SYSTEM)                                   ! Call clear sparse system with system.
      IF (TOTAL_DOF .LT. 1_I8 .OR.                                       ! If total_dof < 1 or size(element_matrices) < 1:
     &    SIZE(ELEMENT_MATRICES) .LT. 1_I4) THEN
        CALL SET_ERROR(STATUS, 'BUILD_SPARSE_PATTERN',                   ! Record an error in status: 'EMPTY GLOBAL MATRIX INPUT'.
     &                 'EMPTY GLOBAL MATRIX INPUT')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      ENTRY_COUNT = 0_I8                                                 ! Set entry_count to zero.
      DO ELEMENT = 1_I4, SIZE(ELEMENT_MATRICES)                          ! Loop element from 1 to size(element_matrices):
        LOCAL_COUNT = ELEMENT_MATRICES(ELEMENT)%LOCAL_DOF_COUNT          ! Set local_count to element_matrices(element).local_dof_count.
        IF (LOCAL_COUNT .LT. 1_I4 .OR.                                   ! If local_count < 1 or not allocated(element_matrices(element).global_dof):
     &      .NOT. ALLOCATED(ELEMENT_MATRICES(ELEMENT)%GLOBAL_DOF)) THEN
          CALL SET_ERROR(STATUS, 'BUILD_SPARSE_PATTERN',                 ! Record an error in status: 'ELEMENT DOF LIST IS NOT ALLOCATED'.
     &                   'ELEMENT DOF LIST IS NOT ALLOCATED')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        ENTRY_COUNT = ENTRY_COUNT+INT(LOCAL_COUNT,I8)*                   ! Add int(local_count,i8)* int(local_count,i8) to entry_count.
     &                INT(LOCAL_COUNT,I8)
      END DO                                                             ! End of the loop.
      ALLOCATE(ROW(ENTRY_COUNT))                                         ! Allocate memory for row(entry_count).
      ALLOCATE(COLUMN(ENTRY_COUNT))                                      ! Allocate memory for column(entry_count).

      POSITION = 0_I8                                                    ! Set position to zero.
      DO ELEMENT = 1_I4, SIZE(ELEMENT_MATRICES)                          ! Loop element from 1 to size(element_matrices):
        LOCAL_COUNT = ELEMENT_MATRICES(ELEMENT)%LOCAL_DOF_COUNT          ! Set local_count to element_matrices(element).local_dof_count.
        DO J = 1_I8, INT(LOCAL_COUNT,I8)                                 ! Loop j from 1 to int(local_count,i8):
          GLOBAL_COLUMN = ELEMENT_MATRICES(ELEMENT)%GLOBAL_DOF(J)        ! Set global_column to element_matrices(element).global_dof(j).
          DO I = 1_I8, INT(LOCAL_COUNT,I8)                               ! Loop i from 1 to int(local_count,i8):
            GLOBAL_ROW = ELEMENT_MATRICES(ELEMENT)%GLOBAL_DOF(I)         ! Set global_row to element_matrices(element).global_dof(i).
            IF (GLOBAL_ROW .LT. 1_I8 .OR.                                ! If global_row < 1 or global_row > total_dof or global_column < 1 or global_column > total_dof:
     &          GLOBAL_ROW .GT. TOTAL_DOF .OR.
     &          GLOBAL_COLUMN .LT. 1_I8 .OR.
     &          GLOBAL_COLUMN .GT. TOTAL_DOF) THEN
              CALL SET_ERROR(STATUS, 'BUILD_SPARSE_PATTERN',             ! Record an error in status: 'GLOBAL DOF IS OUT OF RANGE'.
     &                       'GLOBAL DOF IS OUT OF RANGE')
              RETURN                                                     ! Return to the caller.
            END IF                                                       ! End of the IF block.
            POSITION = POSITION+1_I8                                     ! Add 1 to position.
            ROW(POSITION) = GLOBAL_ROW                                   ! Set row(position) to global_row.
            COLUMN(POSITION) = GLOBAL_COLUMN                             ! Set column(position) to global_column.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      CALL SORT_COORDINATES(ROW,COLUMN)                                  ! Call sort coordinates with row, column.
      UNIQUE_COUNT = 0_I8                                                ! Set unique_count to zero.
      PREVIOUS_ROW = 0_I8                                                ! Set previous_row to zero.
      PREVIOUS_COLUMN = 0_I8                                             ! Set previous_column to zero.
      DO POSITION = 1_I8, ENTRY_COUNT                                    ! Loop position from 1 to entry_count:
        IF (ROW(POSITION) .NE. PREVIOUS_ROW .OR.                         ! If row(position) /= previous_row or column(position) /= previous_column:
     &      COLUMN(POSITION) .NE. PREVIOUS_COLUMN) THEN
          UNIQUE_COUNT = UNIQUE_COUNT+1_I8                               ! Add 1 to unique_count.
          PREVIOUS_ROW = ROW(POSITION)                                   ! Set previous_row to row(position).
          PREVIOUS_COLUMN = COLUMN(POSITION)                             ! Set previous_column to column(position).
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      SYSTEM%ORDER = TOTAL_DOF                                           ! Set system.order to total_dof.
      SYSTEM%NONZERO_COUNT = UNIQUE_COUNT                                ! Set system.nonzero_count to unique_count.
      ALLOCATE(SYSTEM%ROW_POINTER(TOTAL_DOF+1_I8))                       ! Allocate memory for system.row_pointer(total_dof+1).
      ALLOCATE(SYSTEM%COLUMN_INDEX(UNIQUE_COUNT))                        ! Allocate memory for system.column_index(unique_count).
      ALLOCATE(SYSTEM%STIFFNESS(UNIQUE_COUNT))                           ! Allocate memory for system.stiffness(unique_count).
      ALLOCATE(SYSTEM%MASS(UNIQUE_COUNT))                                ! Allocate memory for system.mass(unique_count).
      SYSTEM%ROW_POINTER = 0_I8                                          ! Set system.row_pointer to zero.
      SYSTEM%STIFFNESS = 0.0_R8                                          ! Set system.stiffness to zero.
      SYSTEM%MASS = 0.0_R8                                               ! Set system.mass to zero.

      UNIQUE_COUNT = 0_I8                                                ! Set unique_count to zero.
      PREVIOUS_ROW = 0_I8                                                ! Set previous_row to zero.
      PREVIOUS_COLUMN = 0_I8                                             ! Set previous_column to zero.
      DO POSITION = 1_I8, ENTRY_COUNT                                    ! Loop position from 1 to entry_count:
        IF (ROW(POSITION) .EQ. PREVIOUS_ROW .AND.                        ! If row(position) = previous_row and column(position) = previous_column, skip to the next iteration.
     &      COLUMN(POSITION) .EQ. PREVIOUS_COLUMN) CYCLE
        UNIQUE_COUNT = UNIQUE_COUNT+1_I8                                 ! Add 1 to unique_count.
        SYSTEM%COLUMN_INDEX(UNIQUE_COUNT) = COLUMN(POSITION)             ! Set system.column_index(unique_count) to column(position).
        SYSTEM%ROW_POINTER(ROW(POSITION)+1_I8) =                         ! Add 1 to system.row_pointer(row(position)+1).
     &    SYSTEM%ROW_POINTER(ROW(POSITION)+1_I8)+1_I8
        PREVIOUS_ROW = ROW(POSITION)                                     ! Set previous_row to row(position).
        PREVIOUS_COLUMN = COLUMN(POSITION)                               ! Set previous_column to column(position).
      END DO                                                             ! End of the loop.
      SYSTEM%ROW_POINTER(1) = 1_I8                                       ! Set system.row_pointer(1) to 1.
      DO I = 1_I8, TOTAL_DOF                                             ! Loop i from 1 to total_dof:
        SYSTEM%ROW_POINTER(I+1_I8) = SYSTEM%ROW_POINTER(I+1_I8)+         ! Add system.row_pointer(i) to system.row_pointer(i+1).
     &                               SYSTEM%ROW_POINTER(I)
      END DO                                                             ! End of the loop.

      CALL BUILD_SCATTER_MAPS(ELEMENT_MATRICES,SYSTEM,STATUS)            ! Call build scatter maps with element_matrices, system, status.

      END SUBROUTINE BUILD_SPARSE_PATTERN                                ! End of the subroutine build sparse pattern.


!  CSR PATTERN FROM THE DOF LISTS ALONE (NO ELEMENT MATRICES NEEDED).
!  ROW R COLLECTS THE DOFS OF EVERY ELEMENT TOUCHING R, WITHOUT
!  DUPLICATES, SORTED. MEMORY IS PROPORTIONAL TO THE FINAL NNZ.
      SUBROUTINE BUILD_PATTERN_FROM_DOF_LISTS(TOTAL_DOF, LISTS,          ! Subroutine build pattern from dof lists takes total dof, lists, system, status, with mass, tables.
     &                                        SYSTEM, STATUS,
     &                                        WITH_MASS, TABLES)

      INTEGER(I8), INTENT(IN) :: TOTAL_DOF                               ! Input integer (int64): total_dof.
      TYPE(DOF_LIST_TYPE), INTENT(IN) :: LISTS(:)                        ! Input of type dof_list_type: lists(:).
      TYPE(COUPLING_TABLE_TYPE), INTENT(IN), OPTIONAL :: TABLES(:)       ! Input optional of type coupling_table_type: tables(:).
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      LOGICAL, INTENT(IN), OPTIONAL :: WITH_MASS                         ! Input optional logical: with_mass.
      INTEGER(I8), ALLOCATABLE :: FIRST(:)                               ! Allocatable integer (int64): first(:).
      INTEGER(I8), ALLOCATABLE :: FILL(:)                                ! Allocatable integer (int64): fill(:).
      INTEGER(I8), ALLOCATABLE :: MARK(:)                                ! Allocatable integer (int64): mark(:).
      INTEGER(I4), ALLOCATABLE :: MEMBER(:)                              ! Allocatable integer (int32): member(:).
      INTEGER(I4), ALLOCATABLE :: MEMBER_LOCAL(:)                        ! Allocatable integer (int32): member_local(:).
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: DOF                                                 ! Integer (int64): dof.
      INTEGER(I8) :: COLUMN                                              ! Integer (int64): column.
      INTEGER(I8) :: COUNT                                               ! Integer (int64): count.
      INTEGER(I8) :: NNZ                                                 ! Integer (int64): nnz.
      INTEGER(I8) :: K                                                   ! Integer (int64): k.
      INTEGER(I8) :: L                                                   ! Integer (int64): l.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: PASS                                                ! Integer (int32): pass.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_SPARSE_SYSTEM(SYSTEM)                                   ! Call clear sparse system with system.
      IF (TOTAL_DOF .LT. 1_I8 .OR. SIZE(LISTS) .LT. 1_I4) THEN           ! If total_dof < 1 or size(lists) < 1:
        CALL SET_ERROR(STATUS, 'BUILD_PATTERN_FROM_DOF_LISTS',           ! Record an error in status: 'EMPTY GLOBAL MATRIX INPUT'.
     &                 'EMPTY GLOBAL MATRIX INPUT')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

!     DOF -> ELEMENTS (CSR).
      ALLOCATE(FIRST(TOTAL_DOF+1_I8))                                    ! Allocate memory for first(total_dof+1).
      FIRST = 0_I8                                                       ! Set first to zero.
      DO ELEMENT = 1_I4, SIZE(LISTS)                                     ! Loop element from 1 to size(lists):
        IF (.NOT. ALLOCATED(LISTS(ELEMENT)%GLOBAL_DOF)) THEN             ! If not allocated(lists(element).global_dof):
          CALL SET_ERROR(STATUS, 'BUILD_PATTERN_FROM_DOF_LISTS',         ! Record an error in status: 'ELEMENT DOF LIST IS NOT ALLOCATED'.
     &                   'ELEMENT DOF LIST IS NOT ALLOCATED')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO K = 1_I8, SIZE(LISTS(ELEMENT)%GLOBAL_DOF,KIND=I8)             ! Loop k from 1 to size(lists(element).global_dof,kind=i8):
          DOF = LISTS(ELEMENT)%GLOBAL_DOF(K)                             ! Set dof to lists(element).global_dof(k).
          IF (DOF .LT. 1_I8 .OR. DOF .GT. TOTAL_DOF) THEN                ! If dof < 1 or dof > total_dof:
            CALL SET_ERROR(STATUS, 'BUILD_PATTERN_FROM_DOF_LISTS',       ! Record an error in status: 'GLOBAL DOF IS OUT OF RANGE'.
     &                     'GLOBAL DOF IS OUT OF RANGE')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          FIRST(DOF+1_I8) = FIRST(DOF+1_I8) + 1_I8                       ! Add 1 to first(dof+1).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      FIRST(1) = 1_I8                                                    ! Set first(1) to 1.
      DO ROW = 1_I8, TOTAL_DOF                                           ! Loop row from 1 to total_dof:
        FIRST(ROW+1_I8) = FIRST(ROW+1_I8) + FIRST(ROW)                   ! Add first(row) to first(row+1).
      END DO                                                             ! End of the loop.
      ALLOCATE(MEMBER(FIRST(TOTAL_DOF+1_I8)-1_I8))                       ! Allocate memory for member(first(total_dof+1)-1).
      ALLOCATE(MEMBER_LOCAL(FIRST(TOTAL_DOF+1_I8)-1_I8))                 ! Allocate memory for member_local(first(total_dof+1)-1).
      ALLOCATE(FILL(TOTAL_DOF))                                          ! Allocate memory for fill(total_dof).
      FILL = FIRST(1:TOTAL_DOF)                                          ! Set fill to first(1:total_dof).
      DO ELEMENT = 1_I4, SIZE(LISTS)                                     ! Loop element from 1 to size(lists):
        DO K = 1_I8, SIZE(LISTS(ELEMENT)%GLOBAL_DOF,KIND=I8)             ! Loop k from 1 to size(lists(element).global_dof,kind=i8):
          DOF = LISTS(ELEMENT)%GLOBAL_DOF(K)                             ! Set dof to lists(element).global_dof(k).
          MEMBER(FILL(DOF)) = ELEMENT                                    ! Set member(fill(dof)) to element.
          MEMBER_LOCAL(FILL(DOF)) = INT(K,I4)                            ! Set member_local(fill(dof)) to int(k,i4).
          FILL(DOF) = FILL(DOF) + 1_I8                                   ! Add 1 to fill(dof).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      DEALLOCATE(FILL)                                                   ! Free the memory of fill.

!     PASS 1 COUNTS THE UNIQUE COLUMNS OF EVERY ROW, PASS 2 STORES
!     AND SORTS THEM.
      SYSTEM%ORDER = TOTAL_DOF                                           ! Set system.order to total_dof.
      ALLOCATE(SYSTEM%ROW_POINTER(TOTAL_DOF+1_I8))                       ! Allocate memory for system.row_pointer(total_dof+1).
      SYSTEM%ROW_POINTER = 0_I8                                          ! Set system.row_pointer to zero.
      ALLOCATE(MARK(TOTAL_DOF))                                          ! Allocate memory for mark(total_dof).
      DO PASS = 1_I4, 2_I4                                               ! Loop pass from 1 to 2:
        MARK = 0_I8                                                      ! Set mark to zero.
        NNZ = 0_I8                                                       ! Set nnz to zero.
        DO ROW = 1_I8, TOTAL_DOF                                         ! Loop row from 1 to total_dof:
          COUNT = 0_I8                                                   ! Set count to zero.
          DO L = FIRST(ROW), FIRST(ROW+1_I8)-1_I8                        ! Loop l from first(row) to first(row+1)-1:
            ELEMENT = MEMBER(L)                                          ! Set element to member(l).
            DO K = 1_I8, SIZE(LISTS(ELEMENT)%GLOBAL_DOF,KIND=I8)         ! Loop k from 1 to size(lists(element).global_dof,kind=i8):
              IF (PRESENT(TABLES)) THEN                                  ! If present(tables):
                IF (.NOT. ARE_COUPLED(LISTS(ELEMENT), TABLES,            ! If not are_coupled(lists(element), tables, member_local(l), int(k,i4)), skip to the next iteration.
     &              MEMBER_LOCAL(L), INT(K,I4))) CYCLE
              END IF                                                     ! End of the IF block.
              COLUMN = LISTS(ELEMENT)%GLOBAL_DOF(K)                      ! Set column to lists(element).global_dof(k).
              IF (MARK(COLUMN) .EQ. ROW) CYCLE                           ! If mark(column) = row, skip to the next iteration.
              MARK(COLUMN) = ROW                                         ! Set mark(column) to row.
              COUNT = COUNT + 1_I8                                       ! Add 1 to count.
              IF (PASS .EQ. 2_I4)                                        ! If pass = 2, set system.column_index(system.row_pointer(row)+count- 1) to column.
     &          SYSTEM%COLUMN_INDEX(SYSTEM%ROW_POINTER(ROW)+COUNT-
     &                              1_I8) = COLUMN
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
          IF (PASS .EQ. 1_I4) THEN                                       ! If pass = 1:
            SYSTEM%ROW_POINTER(ROW+1_I8) = COUNT                         ! Set system.row_pointer(row+1) to count.
          ELSE                                                           ! Otherwise:
            CALL SORT_SEGMENT(SYSTEM%COLUMN_INDEX,                       ! Call sort segment with system.column_index, system.row_pointer(row), system.row_pointer(row)+ count-1.
     &           SYSTEM%ROW_POINTER(ROW), SYSTEM%ROW_POINTER(ROW)+
     &           COUNT-1_I8)
          END IF                                                         ! End of the IF block.
          NNZ = NNZ + COUNT                                              ! Add count to nnz.
        END DO                                                           ! End of the loop.
        IF (PASS .EQ. 1_I4) THEN                                         ! If pass = 1:
          SYSTEM%ROW_POINTER(1) = 1_I8                                   ! Set system.row_pointer(1) to 1.
          DO ROW = 1_I8, TOTAL_DOF                                       ! Loop row from 1 to total_dof:
            SYSTEM%ROW_POINTER(ROW+1_I8) =                               ! Add system.row_pointer(row) to system.row_pointer(row+1).
     &        SYSTEM%ROW_POINTER(ROW+1_I8) + SYSTEM%ROW_POINTER(ROW)
          END DO                                                         ! End of the loop.
          SYSTEM%NONZERO_COUNT = NNZ                                     ! Set system.nonzero_count to nnz.
          ALLOCATE(SYSTEM%COLUMN_INDEX(NNZ))                             ! Allocate memory for system.column_index(nnz).
          ALLOCATE(SYSTEM%STIFFNESS(NNZ))                                ! Allocate memory for system.stiffness(nnz).
          SYSTEM%STIFFNESS = 0.0_R8                                      ! Set system.stiffness to zero.
          IF (.NOT. PRESENT(WITH_MASS) .OR. WITH_MASS) THEN              ! If not present(with_mass) or with_mass:
            ALLOCATE(SYSTEM%MASS(NNZ))                                   ! Allocate memory for system.mass(nnz).
            SYSTEM%MASS = 0.0_R8                                         ! Set system.mass to zero.
          END IF                                                         ! End of the IF block.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_PATTERN_FROM_DOF_LISTS                        ! End of the subroutine build pattern from dof lists.

!  FALSE ONLY FOR TWO LAGRANGE-EXPANSION DOFS OF THE SAME TABLE WHOSE
!  TERMS DO NOT SHARE A SUB-ELEMENT (THEIR ENTRY IS EXACTLY ZERO).
      LOGICAL FUNCTION ARE_COUPLED(LIST, TABLES, K0, K1)                 ! Function are coupled takes list, tables, k0, k1.

      TYPE(DOF_LIST_TYPE), INTENT(IN) :: LIST                            ! Input of type dof_list_type: list.
      TYPE(COUPLING_TABLE_TYPE), INTENT(IN) :: TABLES(:)                 ! Input of type coupling_table_type: tables(:).
      INTEGER(I4), INTENT(IN) :: K0                                      ! Input integer (int32): k0.
      INTEGER(I4), INTENT(IN) :: K1                                      ! Input integer (int32): k1.
      INTEGER(I4) :: TABLE                                               ! Integer (int32): table.

      ARE_COUPLED = .TRUE.                                               ! Set the flag are_coupled to true.
      IF (.NOT. ALLOCATED(LIST%TABLE)) RETURN                            ! If not allocated(list.table), return to the caller.
      TABLE = LIST%TABLE(K0)                                             ! Set table to list.table(k0).
      IF (TABLE .LT. 1_I4 .OR. LIST%TABLE(K1) .NE. TABLE) RETURN         ! If table < 1 or list.table(k1) /= table, return to the caller.
      ARE_COUPLED = TABLES(TABLE)%COUPLED(LIST%TERM(K0),LIST%TERM(K1))   ! Set are_coupled to tables(table).coupled(list.term(k0),list.term(k1)).

      END FUNCTION ARE_COUPLED                                           ! End of the function are coupled.
!  ASCENDING SORT OF COLUMN(FIRST:LAST) (INSERTION, HEAP FOR LONG ROWS).
      SUBROUTINE SORT_SEGMENT(COLUMN, FIRST, LAST)                       ! Subroutine sort segment takes column, first, last.

      INTEGER(I8), INTENT(INOUT) :: COLUMN(:)                            ! In/out integer (int64): column(:).
      INTEGER(I8), INTENT(IN) :: FIRST                                   ! Input integer (int64): first.
      INTEGER(I8), INTENT(IN) :: LAST                                    ! Input integer (int64): last.
      INTEGER(I8) :: I                                                   ! Integer (int64): i.
      INTEGER(I8) :: J                                                   ! Integer (int64): j.
      INTEGER(I8) :: VALUE                                               ! Integer (int64): value.
      INTEGER(I8) :: N                                                   ! Integer (int64): n.

      N = LAST - FIRST + 1_I8                                            ! Set n to last - first + 1.
      IF (N .LT. 2_I8) RETURN                                            ! If n < 2, return to the caller.
      IF (N .LE. 24_I8) THEN                                             ! If n <= 24:
        DO I = FIRST+1_I8, LAST                                          ! Loop i from first+1 to last:
          VALUE = COLUMN(I)                                              ! Set value to column(i).
          J = I - 1_I8                                                   ! Set j to i - 1.
          DO WHILE (J .GE. FIRST)                                        ! Repeat while j >= first:
            IF (COLUMN(J) .LE. VALUE) EXIT                               ! If column(j) <= value, leave the loop.
            COLUMN(J+1_I8) = COLUMN(J)                                   ! Set column(j+1) to column(j).
            J = J - 1_I8                                                 ! Subtract 1 from j.
          END DO                                                         ! End of the loop.
          COLUMN(J+1_I8) = VALUE                                         ! Set column(j+1) to value.
        END DO                                                           ! End of the loop.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO I = N/2_I8, 1_I8, -1_I8                                         ! Loop i from n/2 to 1 in steps of -1:
        CALL SIFT_COLUMN(COLUMN, FIRST, I, N)                            ! Call sift column with column, first, i, n.
      END DO                                                             ! End of the loop.
      DO I = N, 2_I8, -1_I8                                              ! Loop i from n to 2 in steps of -1:
        VALUE = COLUMN(FIRST)                                            ! Set value to column(first).
        COLUMN(FIRST) = COLUMN(FIRST+I-1_I8)                             ! Set column(first) to column(first+i-1).
        COLUMN(FIRST+I-1_I8) = VALUE                                     ! Set column(first+i-1) to value.
        CALL SIFT_COLUMN(COLUMN, FIRST, 1_I8, I-1_I8)                    ! Call sift column with column, first, 1, i-1.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SORT_SEGMENT                                        ! End of the subroutine sort segment.

      SUBROUTINE SIFT_COLUMN(COLUMN, FIRST, ROOT, LAST)                  ! Subroutine sift column takes column, first, root, last.

      INTEGER(I8), INTENT(INOUT) :: COLUMN(:)                            ! In/out integer (int64): column(:).
      INTEGER(I8), INTENT(IN) :: FIRST                                   ! Input integer (int64): first.
      INTEGER(I8), INTENT(IN) :: ROOT                                    ! Input integer (int64): root.
      INTEGER(I8), INTENT(IN) :: LAST                                    ! Input integer (int64): last.
      INTEGER(I8) :: CURRENT                                             ! Integer (int64): current.
      INTEGER(I8) :: CHILD                                               ! Integer (int64): child.
      INTEGER(I8) :: VALUE                                               ! Integer (int64): value.

      CURRENT = ROOT                                                     ! Set current to root.
      DO WHILE (2_I8*CURRENT .LE. LAST)                                  ! Repeat while 2*current <= last:
        CHILD = 2_I8*CURRENT                                             ! Set child to 2*current.
        IF (CHILD .LT. LAST) THEN                                        ! If child < last:
          IF (COLUMN(FIRST+CHILD-1_I8) .LT.                              ! If column(first+child-1) < column(first+child), add 1 to child.
     &        COLUMN(FIRST+CHILD)) CHILD = CHILD + 1_I8
        END IF                                                           ! End of the IF block.
        IF (COLUMN(FIRST+CURRENT-1_I8) .GE.                              ! If column(first+current-1) >= column(first+child-1), return to the caller.
     &      COLUMN(FIRST+CHILD-1_I8)) RETURN
        VALUE = COLUMN(FIRST+CURRENT-1_I8)                               ! Set value to column(first+current-1).
        COLUMN(FIRST+CURRENT-1_I8) = COLUMN(FIRST+CHILD-1_I8)            ! Set column(first+current-1) to column(first+child-1).
        COLUMN(FIRST+CHILD-1_I8) = VALUE                                 ! Set column(first+child-1) to value.
        CURRENT = CHILD                                                  ! Set current to child.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SIFT_COLUMN                                         ! End of the subroutine sift column.

!  ADD ONE ELEMENT MATRIX PAIR INTO THE SHARED PATTERN (BINARY SEARCH
!  IN EVERY ROW; NO ALLOCATION, NO PATTERN CHANGE).
      SUBROUTINE SCATTER_ELEMENT(SYSTEM, GLOBAL_DOF, STIFFNESS, MASS,    ! Subroutine scatter element takes system, global dof, stiffness, mass, status.
     &                           STATUS)

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      INTEGER(I8), INTENT(IN) :: GLOBAL_DOF(:)                           ! Input integer (int64): global_dof(:).
      REAL(R8), INTENT(IN) :: STIFFNESS(:,:)                             ! Input real (real64): stiffness(:,:).
      REAL(R8), INTENT(IN) :: MASS(:,:)                                  ! Input real (real64): mass(:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      DO J = 1_I4, SIZE(GLOBAL_DOF)                                      ! Loop j from 1 to size(global_dof):
        DO I = 1_I4, SIZE(GLOBAL_DOF)                                    ! Loop i from 1 to size(global_dof):
!         STRUCTURAL ZEROS (NOT IN THE PATTERN) ARE SKIPPED; A NON-ZERO
!         ENTRY OUTSIDE THE PATTERN IS AN ERROR.
          IF (STIFFNESS(I,J) .EQ. 0.0_R8) THEN                           ! If stiffness(i,j) = 0.0:
            IF (SIZE(MASS) .EQ. 0) CYCLE                                 ! If size(mass) = 0, skip to the next iteration.
            IF (MASS(I,J) .EQ. 0.0_R8) CYCLE                             ! If mass(i,j) = 0.0, skip to the next iteration.
          END IF                                                         ! End of the IF block.
          POSITION = FIND_CSR_POSITION(SYSTEM, GLOBAL_DOF(I),            ! Set position to find_csr_position(system, global_dof(i), global_dof(j)).
     &                                 GLOBAL_DOF(J))
          IF (POSITION .EQ. 0_I8) THEN                                   ! If position = 0:
            CALL SET_ERROR(STATUS, 'SCATTER_ELEMENT',                    ! Record an error in status: 'ENTRY IS MISSING FROM CSR PATTERN'.
     &                     'ENTRY IS MISSING FROM CSR PATTERN')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          SYSTEM%STIFFNESS(POSITION) = SYSTEM%STIFFNESS(POSITION) +      ! Add stiffness(i,j) to system.stiffness(position).
     &                                 STIFFNESS(I,J)
          IF (ALLOCATED(SYSTEM%MASS) .AND. SIZE(MASS) .GT. 0)            ! If allocated(system.mass) and size(mass) > 0, add mass(i,j) to system.mass(position).
     &      SYSTEM%MASS(POSITION) = SYSTEM%MASS(POSITION) + MASS(I,J)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SCATTER_ELEMENT                                     ! End of the subroutine scatter element.
      SUBROUTINE BUILD_SCATTER_MAPS(ELEMENT_MATRICES,                    ! Subroutine build scatter maps takes element matrices, system, status.
     &                              SYSTEM, STATUS)

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) ::                        ! In/out of type element_matrix_type: element_matrices(:).
     &  ELEMENT_MATRICES(:)
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(IN) :: SYSTEM                     ! Input of type sparse_system_type: system.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I8) :: GLOBAL_ROW                                          ! Integer (int64): global_row.
      INTEGER(I8) :: GLOBAL_COLUMN                                       ! Integer (int64): global_column.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      DO ELEMENT = 1_I4, SIZE(ELEMENT_MATRICES)                          ! Loop element from 1 to size(element_matrices):
        IF (ALLOCATED(ELEMENT_MATRICES(ELEMENT)%CSR_POSITION))           ! If allocated(element_matrices(element).csr_position), free the memory of element_matrices(element).csr_posi...
     &    DEALLOCATE(ELEMENT_MATRICES(ELEMENT)%CSR_POSITION)
        ALLOCATE(ELEMENT_MATRICES(ELEMENT)%CSR_POSITION(                 ! Allocate memory for element_matrices(element).csr_position( element_matrices(element).local_dof_count, elem...
     &    ELEMENT_MATRICES(ELEMENT)%LOCAL_DOF_COUNT,
     &    ELEMENT_MATRICES(ELEMENT)%LOCAL_DOF_COUNT))
        DO J = 1_I4, ELEMENT_MATRICES(ELEMENT)%LOCAL_DOF_COUNT           ! Loop j from 1 to element_matrices(element).local_dof_count:
          GLOBAL_COLUMN = ELEMENT_MATRICES(ELEMENT)%GLOBAL_DOF(J)        ! Set global_column to element_matrices(element).global_dof(j).
          DO I = 1_I4, ELEMENT_MATRICES(ELEMENT)%LOCAL_DOF_COUNT         ! Loop i from 1 to element_matrices(element).local_dof_count:
            GLOBAL_ROW = ELEMENT_MATRICES(ELEMENT)%GLOBAL_DOF(I)         ! Set global_row to element_matrices(element).global_dof(i).
            POSITION = FIND_CSR_POSITION(SYSTEM,GLOBAL_ROW,              ! Set position to find_csr_position(system,global_row, global_column).
     &                                   GLOBAL_COLUMN)
            IF (POSITION .EQ. 0_I8) THEN                                 ! If position = 0:
              CALL SET_ERROR(STATUS, 'BUILD_SCATTER_MAPS',               ! Record an error in status: 'ENTRY IS MISSING FROM CSR PATTERN'.
     &                       'ENTRY IS MISSING FROM CSR PATTERN')
              RETURN                                                     ! Return to the caller.
            END IF                                                       ! End of the IF block.
            ELEMENT_MATRICES(ELEMENT)%CSR_POSITION(I,J) = POSITION       ! Set element_matrices(element).csr_position(i,j) to position.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_SCATTER_MAPS                                  ! End of the subroutine build scatter maps.

      SUBROUTINE ASSEMBLE_ELEMENT_MATRICES(ELEMENT_MATRICES,             ! Subroutine assemble element matrices takes element matrices, system, status.
     &                                     SYSTEM, STATUS)

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(IN) :: ELEMENT_MATRICES(:)       ! Input of type element_matrix_type: element_matrices(:).
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I8) :: GLOBAL_ROW                                          ! Integer (int64): global_row.
      INTEGER(I8) :: GLOBAL_COLUMN                                       ! Integer (int64): global_column.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (.NOT. ALLOCATED(SYSTEM%ROW_POINTER) .OR.                       ! If not allocated(system.row_pointer) or not allocated(system.column_index) or not allocated(system.stiffnes...
     &    .NOT. ALLOCATED(SYSTEM%COLUMN_INDEX) .OR.
     &    .NOT. ALLOCATED(SYSTEM%STIFFNESS) .OR.
     &    .NOT. ALLOCATED(SYSTEM%MASS)) THEN
        CALL SET_ERROR(STATUS, 'ASSEMBLE_ELEMENT_MATRICES',              ! Record an error in status: 'SPARSE PATTERN IS NOT ALLOCATED'.
     &                 'SPARSE PATTERN IS NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      SYSTEM%STIFFNESS = 0.0_R8                                          ! Set system.stiffness to zero.
      SYSTEM%MASS = 0.0_R8                                               ! Set system.mass to zero.
      DO ELEMENT = 1_I4, SIZE(ELEMENT_MATRICES)                          ! Loop element from 1 to size(element_matrices):
        IF (.NOT. ALLOCATED(ELEMENT_MATRICES(ELEMENT)%STIFFNESS)         ! If not allocated(element_matrices(element).stiffness) or not allocated( element_matrices(element).mass):
     &      .OR. .NOT. ALLOCATED(
     &      ELEMENT_MATRICES(ELEMENT)%MASS)) THEN
          CALL SET_ERROR(STATUS, 'ASSEMBLE_ELEMENT_MATRICES',            ! Record an error in status: 'ELEMENT MATRICES ARE NOT ALLOCATED'.
     &                   'ELEMENT MATRICES ARE NOT ALLOCATED')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO J = 1_I4, ELEMENT_MATRICES(ELEMENT)%LOCAL_DOF_COUNT           ! Loop j from 1 to element_matrices(element).local_dof_count:
          GLOBAL_COLUMN = ELEMENT_MATRICES(ELEMENT)%GLOBAL_DOF(J)        ! Set global_column to element_matrices(element).global_dof(j).
          DO I = 1_I4, ELEMENT_MATRICES(ELEMENT)%LOCAL_DOF_COUNT         ! Loop i from 1 to element_matrices(element).local_dof_count:
            GLOBAL_ROW = ELEMENT_MATRICES(ELEMENT)%GLOBAL_DOF(I)         ! Set global_row to element_matrices(element).global_dof(i).
            IF (ALLOCATED(                                               ! If allocated( element_matrices(element).csr_position):
     &          ELEMENT_MATRICES(ELEMENT)%CSR_POSITION)) THEN
              POSITION = ELEMENT_MATRICES(ELEMENT)%                      ! Set position to element_matrices(element). csr_position(i,j).
     &                   CSR_POSITION(I,J)
            ELSE                                                         ! Otherwise:
              POSITION = FIND_CSR_POSITION(SYSTEM,GLOBAL_ROW,            ! Set position to find_csr_position(system,global_row, global_column).
     &                                     GLOBAL_COLUMN)
            END IF                                                       ! End of the IF block.
            IF (POSITION .EQ. 0_I8) THEN                                 ! If position = 0:
              CALL SET_ERROR(STATUS, 'ASSEMBLE_ELEMENT_MATRICES',        ! Record an error in status: 'ENTRY IS MISSING FROM CSR PATTERN'.
     &                       'ENTRY IS MISSING FROM CSR PATTERN')
              RETURN                                                     ! Return to the caller.
            END IF                                                       ! End of the IF block.
            SYSTEM%STIFFNESS(POSITION) =                                 ! Add element_matrices(element).stiffness(i,j) to system.stiffness(position).
     &        SYSTEM%STIFFNESS(POSITION)+
     &        ELEMENT_MATRICES(ELEMENT)%STIFFNESS(I,J)
            SYSTEM%MASS(POSITION) = SYSTEM%MASS(POSITION)+               ! Add element_matrices(element).mass(i,j) to system.mass(position).
     &        ELEMENT_MATRICES(ELEMENT)%MASS(I,J)
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE ASSEMBLE_ELEMENT_MATRICES                           ! End of the subroutine assemble element matrices.

      INTEGER(I8) FUNCTION FIND_CSR_POSITION(SYSTEM, ROW, COLUMN)        ! Function find csr position takes system, row, column.

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(IN) :: SYSTEM                     ! Input of type sparse_system_type: system.
      INTEGER(I8), INTENT(IN) :: ROW                                     ! Input integer (int64): row.
      INTEGER(I8), INTENT(IN) :: COLUMN                                  ! Input integer (int64): column.
      INTEGER(I8) :: LEFT                                                ! Integer (int64): left.
      INTEGER(I8) :: RIGHT                                               ! Integer (int64): right.
      INTEGER(I8) :: MIDDLE                                              ! Integer (int64): middle.

      FIND_CSR_POSITION = 0_I8                                           ! Set find_csr_position to zero.
      LEFT = SYSTEM%ROW_POINTER(ROW)                                     ! Set left to system.row_pointer(row).
      RIGHT = SYSTEM%ROW_POINTER(ROW+1_I8)-1_I8                          ! Set right to system.row_pointer(row+1)-1.
      DO WHILE (LEFT .LE. RIGHT)                                         ! Repeat while left <= right:
        MIDDLE = LEFT+(RIGHT-LEFT)/2_I8                                  ! Set middle to left+(right-left)/2.
        IF (SYSTEM%COLUMN_INDEX(MIDDLE) .EQ. COLUMN) THEN                ! If system.column_index(middle) = column:
          FIND_CSR_POSITION = MIDDLE                                     ! Set find_csr_position to middle.
          RETURN                                                         ! Return to the caller.
        ELSE IF (SYSTEM%COLUMN_INDEX(MIDDLE) .LT. COLUMN) THEN           ! Otherwise, if system.column_index(middle) < column:
          LEFT = MIDDLE+1_I8                                             ! Set left to middle+1.
        ELSE                                                             ! Otherwise:
          RIGHT = MIDDLE-1_I8                                            ! Set right to middle-1.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_CSR_POSITION                                     ! End of the function find csr position.

      SUBROUTINE SORT_COORDINATES(ROW, COLUMN)                           ! Subroutine sort coordinates takes row, column.

      INTEGER(I8), INTENT(INOUT) :: ROW(:)                               ! In/out integer (int64): row(:).
      INTEGER(I8), INTENT(INOUT) :: COLUMN(:)                            ! In/out integer (int64): column(:).
      INTEGER(I8) :: END_INDEX                                           ! Integer (int64): end_index.
      INTEGER(I8) :: I                                                   ! Integer (int64): i.

      DO I = SIZE(ROW,KIND=I8)/2_I8, 1_I8, -1_I8                         ! Loop i from size(row,kind=i8)/2 to 1 in steps of -1:
        CALL SIFT_DOWN(ROW,COLUMN,I,SIZE(ROW,KIND=I8))                   ! Call sift down with row, column, i, size(row,kind=i8).
      END DO                                                             ! End of the loop.
      DO END_INDEX = SIZE(ROW,KIND=I8), 2_I8, -1_I8                      ! Loop end_index from size(row,kind=i8) to 2 in steps of -1:
        CALL SWAP_PAIR(ROW,COLUMN,1_I8,END_INDEX)                        ! Call swap pair with row, column, 1, end_index.
        CALL SIFT_DOWN(ROW,COLUMN,1_I8,END_INDEX-1_I8)                   ! Call sift down with row, column, 1, end_index-1.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SORT_COORDINATES                                    ! End of the subroutine sort coordinates.

      SUBROUTINE SIFT_DOWN(ROW, COLUMN, ROOT, LAST)                      ! Subroutine sift down takes row, column, root, last.

      INTEGER(I8), INTENT(INOUT) :: ROW(:)                               ! In/out integer (int64): row(:).
      INTEGER(I8), INTENT(INOUT) :: COLUMN(:)                            ! In/out integer (int64): column(:).
      INTEGER(I8), INTENT(IN) :: ROOT                                    ! Input integer (int64): root.
      INTEGER(I8), INTENT(IN) :: LAST                                    ! Input integer (int64): last.
      INTEGER(I8) :: CURRENT                                             ! Integer (int64): current.
      INTEGER(I8) :: CHILD                                               ! Integer (int64): child.

      CURRENT = ROOT                                                     ! Set current to root.
      DO WHILE (2_I8*CURRENT .LE. LAST)                                  ! Repeat while 2*current <= last:
        CHILD = 2_I8*CURRENT                                             ! Set child to 2*current.
        IF (CHILD .LT. LAST) THEN                                        ! If child < last:
          IF (PAIR_LESS(ROW(CHILD),COLUMN(CHILD),                        ! If pair_less(row(child),column(child), row(child+1),column(child+1)), add 1 to child.
     &        ROW(CHILD+1_I8),COLUMN(CHILD+1_I8))) CHILD = CHILD+1_I8
        END IF                                                           ! End of the IF block.
        IF (.NOT. PAIR_LESS(ROW(CURRENT),COLUMN(CURRENT),                ! If not pair_less(row(current),column(current), row(child),column(child)), return to the caller.
     &      ROW(CHILD),COLUMN(CHILD))) RETURN
        CALL SWAP_PAIR(ROW,COLUMN,CURRENT,CHILD)                         ! Call swap pair with row, column, current, child.
        CURRENT = CHILD                                                  ! Set current to child.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SIFT_DOWN                                           ! End of the subroutine sift down.

      LOGICAL FUNCTION PAIR_LESS(ROW_A, COLUMN_A, ROW_B, COLUMN_B)       ! Function pair less takes row a, column a, row b, column b.

      INTEGER(I8), INTENT(IN) :: ROW_A                                   ! Input integer (int64): row_a.
      INTEGER(I8), INTENT(IN) :: COLUMN_A                                ! Input integer (int64): column_a.
      INTEGER(I8), INTENT(IN) :: ROW_B                                   ! Input integer (int64): row_b.
      INTEGER(I8), INTENT(IN) :: COLUMN_B                                ! Input integer (int64): column_b.

      PAIR_LESS = ROW_A .LT. ROW_B .OR.                                  ! Set pair_less to row_a < row_b or (row_a = row_b and column_a < column_b).
     &           (ROW_A .EQ. ROW_B .AND. COLUMN_A .LT. COLUMN_B)

      END FUNCTION PAIR_LESS                                             ! End of the function pair less.

      SUBROUTINE SWAP_PAIR(ROW, COLUMN, FIRST, SECOND)                   ! Subroutine swap pair takes row, column, first, second.

      INTEGER(I8), INTENT(INOUT) :: ROW(:)                               ! In/out integer (int64): row(:).
      INTEGER(I8), INTENT(INOUT) :: COLUMN(:)                            ! In/out integer (int64): column(:).
      INTEGER(I8), INTENT(IN) :: FIRST                                   ! Input integer (int64): first.
      INTEGER(I8), INTENT(IN) :: SECOND                                  ! Input integer (int64): second.
      INTEGER(I8) :: TEMPORARY                                           ! Integer (int64): temporary.

      TEMPORARY = ROW(FIRST)                                             ! Set temporary to row(first).
      ROW(FIRST) = ROW(SECOND)                                           ! Set row(first) to row(second).
      ROW(SECOND) = TEMPORARY                                            ! Set row(second) to temporary.
      TEMPORARY = COLUMN(FIRST)                                          ! Set temporary to column(first).
      COLUMN(FIRST) = COLUMN(SECOND)                                     ! Set column(first) to column(second).
      COLUMN(SECOND) = TEMPORARY                                         ! Set column(second) to temporary.

      END SUBROUTINE SWAP_PAIR                                           ! End of the subroutine swap pair.

      SUBROUTINE CLEAR_SPARSE_SYSTEM(SYSTEM)                             ! Subroutine clear sparse system takes system.

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.

      IF (ALLOCATED(SYSTEM%ROW_POINTER))                                 ! If allocated(system.row_pointer), free the memory of system.row_pointer.
     &  DEALLOCATE(SYSTEM%ROW_POINTER)
      IF (ALLOCATED(SYSTEM%COLUMN_INDEX))                                ! If allocated(system.column_index), free the memory of system.column_index.
     &  DEALLOCATE(SYSTEM%COLUMN_INDEX)
      IF (ALLOCATED(SYSTEM%STIFFNESS))                                   ! If allocated(system.stiffness), free the memory of system.stiffness.
     &  DEALLOCATE(SYSTEM%STIFFNESS)
      IF (ALLOCATED(SYSTEM%MASS)) DEALLOCATE(SYSTEM%MASS)                ! If allocated(system.mass), free the memory of system.mass.
      SYSTEM%ORDER = 0_I8                                                ! Set system.order to zero.
      SYSTEM%NONZERO_COUNT = 0_I8                                        ! Set system.nonzero_count to zero.

      END SUBROUTINE CLEAR_SPARSE_SYSTEM                                 ! End of the subroutine clear sparse system.

      END MODULE MUL2_SPARSE_ASSEMBLY                                    ! End of the module mul2 sparse assembly.
