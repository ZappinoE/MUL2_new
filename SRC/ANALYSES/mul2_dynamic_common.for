!=======================================================================
!  PIECES SHARED BY THE TIME AND FREQUENCY ANALYSES (104, 106).
!
!  A DEGREE OF FREEDOM BELONGS TO ONE OF THREE CLASSES THAT DECIDE HOW
!  IT ENTERS THE DYNAMIC EQUATIONS:
!      1  DISPLACEMENT (FIELDS 1-3): INERTIA AND VISCOUS DAMPING
!      2  TEMPERATURE  (FIELD 4):    HEAT CAPACITY (FIRST ORDER IN TIME)
!      3  POTENTIAL    (FIELD 5):    NO INERTIA (ALGEBRAIC)
!  THE DAMPING MATRIX LIVES ON THE CSR PATTERN OF K.
!=======================================================================
      MODULE MUL2_DYNAMIC_COMMON                                         ! Module mul2 dynamic common begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE, GLOBAL_DOF             ! Use from module mul2 dof layout: dof layout type, global dof.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: CLASS_DISPLACEMENT = 1_I4        ! Constant public integer (int32): class_displacement = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: CLASS_TEMPERATURE = 2_I4         ! Constant public integer (int32): class_temperature = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: CLASS_POTENTIAL = 3_I4           ! Constant public integer (int32): class_potential = 3.

      PUBLIC :: BUILD_DOF_CLASSES                                        ! Export: build dof classes.
      PUBLIC :: BUILD_DAMPING_VALUES                                     ! Export: build damping values.
      PUBLIC :: CSR_POSITION                                             ! Export: csr position.

      CONTAINS                                                           ! The procedures of the module follow.

!  CLASS(DOF) FOR EVERY DEGREE OF FREEDOM OF THE LAYOUT.
      SUBROUTINE BUILD_DOF_CLASSES(NODE_COUNT, LAYOUT, ORDER, CLASS,     ! Subroutine build dof classes takes node count, layout, order, class, status.
     &                             STATUS)

      INTEGER(I4), INTENT(IN) :: NODE_COUNT                              ! Input integer (int32): node_count.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: LAYOUT                        ! Input of type dof_layout_type: layout.
      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I4), ALLOCATABLE, INTENT(OUT) :: CLASS(:)                  ! Allocatable output integer (int32): class(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      ALLOCATE(CLASS(ORDER))                                             ! Allocate memory for class(order).
      CLASS = 0_I4                                                       ! Set class to zero.
      DO NODE = 1_I4, NODE_COUNT                                         ! Loop node from 1 to node_count:
        DO FIELD = 1_I4, 5_I4                                            ! Loop field from 1 to 5:
          DO TERM = 1_I4, LAYOUT%TERM_COUNT(NODE,FIELD)                  ! Loop term from 1 to layout.term_count(node,field):
            CLASS(GLOBAL_DOF(LAYOUT,NODE,FIELD,TERM)) =                  ! Set class(global_dof(layout,node,field,term)) to class_displacement if field <= 3, otherwise field-2.
     &        MERGE(CLASS_DISPLACEMENT, FIELD-2_I4, FIELD .LE. 3_I4)
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (ANY(CLASS .EQ. 0_I4)) THEN                                     ! If any(class = 0):
        CALL SET_ERROR(STATUS, 'BUILD_DOF_CLASSES',                      ! Record an error in status: 'A DEGREE OF FREEDOM HAS NO FIELD'.
     &                 'A DEGREE OF FREEDOM HAS NO FIELD')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE BUILD_DOF_CLASSES                                   ! End of the subroutine build dof classes.

!  DAMPING VALUES ON THE PATTERN OF THE SYSTEM:
!    DISPLACEMENT ROWS AND COLUMNS: RAYLEIGH  C = ALPHA M + BETA K;
!    TEMPERATURE ROW, DISPLACEMENT COLUMN (ONLY WITH T0 > 0): THE
!    THERMOELASTIC HEATING  -T0 K_UT^T  (K_UT IS THE TRANSPOSED ENTRY).
      SUBROUTINE BUILD_DAMPING_VALUES(SYSTEM, CLASS, ALPHA_M, BETA_K,    ! Subroutine build damping values takes system, class, alpha m, beta k, t0, cdamp.
     &                                T0, CDAMP)

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(IN) :: SYSTEM                     ! Input of type sparse_system_type: system.
      INTEGER(I4), INTENT(IN) :: CLASS(:)                                ! Input integer (int32): class(:).
      REAL(R8), INTENT(IN) :: ALPHA_M                                    ! Input real (real64): alpha_m.
      REAL(R8), INTENT(IN) :: BETA_K                                     ! Input real (real64): beta_k.
      REAL(R8), INTENT(IN) :: T0                                         ! Input real (real64): t0.
      REAL(R8), ALLOCATABLE, INTENT(OUT) :: CDAMP(:)                     ! Allocatable output real (real64): cdamp(:).
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: POS                                                 ! Integer (int64): pos.
      INTEGER(I8) :: COL                                                 ! Integer (int64): col.
      INTEGER(I8) :: OTHER                                               ! Integer (int64): other.

      ALLOCATE(CDAMP(SYSTEM%NONZERO_COUNT))                              ! Allocate memory for cdamp(system.nonzero_count).
!     ROWS ARE INDEPENDENT: THE LOOP IS PARALLEL.
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(ROW,POS,COL,OTHER)
!$OMP& SCHEDULE(STATIC)
      DO ROW = 1_I8, SYSTEM%ORDER                                        ! Loop row from 1 to system.order:
        DO POS = SYSTEM%ROW_POINTER(ROW), SYSTEM%ROW_POINTER(ROW+1_I8)-  ! Loop pos from system.row_pointer(row) to system.row_pointer(row+1)- 1:
     &           1_I8
          COL = SYSTEM%COLUMN_INDEX(POS)                                 ! Set col to system.column_index(pos).
          CDAMP(POS) = 0.0_R8                                            ! Set cdamp(pos) to zero.
          IF (CLASS(ROW) .EQ. CLASS_DISPLACEMENT .AND.                   ! If class(row) = class_displacement and class(col) = class_displacement:
     &        CLASS(COL) .EQ. CLASS_DISPLACEMENT) THEN
            CDAMP(POS) = ALPHA_M*SYSTEM%MASS(POS) +                      ! Set cdamp(pos) to alpha_m*system.mass(pos) + beta_k*system.stiffness(pos).
     &                   BETA_K*SYSTEM%STIFFNESS(POS)
          ELSE IF (CLASS(ROW) .EQ. CLASS_TEMPERATURE .AND.               ! Otherwise, if class(row) = class_temperature and class(col) = class_displacement and t0 > 0.0:
     &             CLASS(COL) .EQ. CLASS_DISPLACEMENT .AND.
     &             T0 .GT. 0.0_R8) THEN
            OTHER = CSR_POSITION(SYSTEM, COL, ROW)                       ! Set other to csr_position(system, col, row).
            IF (OTHER .GT. 0_I8) CDAMP(POS) = -T0*                       ! If other > 0, set cdamp(pos) to -t0* system.stiffness(other).
     &        SYSTEM%STIFFNESS(OTHER)
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
!$OMP END PARALLEL DO

      END SUBROUTINE BUILD_DAMPING_VALUES                                ! End of the subroutine build damping values.

!  POSITION OF (ROW, COLUMN) IN THE CSR PATTERN (BINARY SEARCH IN THE
!  SORTED COLUMNS OF THE ROW), 0 WHEN THE ENTRY IS NOT IN THE PATTERN.
      INTEGER(I8) FUNCTION CSR_POSITION(SYSTEM, ROW, COLUMN)             ! Function csr position takes system, row, column.

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(IN) :: SYSTEM                     ! Input of type sparse_system_type: system.
      INTEGER(I8), INTENT(IN) :: ROW                                     ! Input integer (int64): row.
      INTEGER(I8), INTENT(IN) :: COLUMN                                  ! Input integer (int64): column.
      INTEGER(I8) :: LEFT                                                ! Integer (int64): left.
      INTEGER(I8) :: RIGHT                                               ! Integer (int64): right.
      INTEGER(I8) :: MIDDLE                                              ! Integer (int64): middle.

      CSR_POSITION = 0_I8                                                ! Set csr_position to zero.
      LEFT = SYSTEM%ROW_POINTER(ROW)                                     ! Set left to system.row_pointer(row).
      RIGHT = SYSTEM%ROW_POINTER(ROW+1_I8)-1_I8                          ! Set right to system.row_pointer(row+1)-1.
      DO WHILE (LEFT .LE. RIGHT)                                         ! Repeat while left <= right:
        MIDDLE = LEFT + (RIGHT-LEFT)/2_I8                                ! Set middle to left + (right-left)/2.
        IF (SYSTEM%COLUMN_INDEX(MIDDLE) .EQ. COLUMN) THEN                ! If system.column_index(middle) = column:
          CSR_POSITION = MIDDLE                                          ! Set csr_position to middle.
          RETURN                                                         ! Return to the caller.
        ELSE IF (SYSTEM%COLUMN_INDEX(MIDDLE) .LT. COLUMN) THEN           ! Otherwise, if system.column_index(middle) < column:
          LEFT = MIDDLE + 1_I8                                           ! Set left to middle + 1.
        ELSE                                                             ! Otherwise:
          RIGHT = MIDDLE - 1_I8                                          ! Set right to middle - 1.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION CSR_POSITION                                          ! End of the function csr position.

      END MODULE MUL2_DYNAMIC_COMMON                                     ! End of the module mul2 dynamic common.
