!=======================================================================
!  ADAPTER FOR THE HISTORICAL NODES.DAT (ID X Y Z MODEL [ORDER]).
!
!  THE HISTORICAL FILE HAS NO KINEMATICS.DAT. EACH DISTINCT (MODEL,
!  ORDER) PAIR BECOMES ONE KINEMATIC WITH THE SAME EXPANSION FOR U, V
!  AND W AND NO OTHER ACTIVE FIELD. LE IGNORES THE ORDER COLUMN.
!  ONLY THE MODELS IMPLEMENTED BY V3 (TE, LE) ARE ACCEPTED.
!=======================================================================
      MODULE MUL2_READ_LEGACY_NODES                                      ! Module mul2 read legacy nodes begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error.
     &                       SET_WARNING, SET_ERROR
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE, KINEMATIC_TYPE,     ! Use from module mul2 kinematics: kinematics db type, kinematic type, expansion te, expansion le, expansion ...
     &     EXPANSION_TE, EXPANSION_LE, EXPANSION_HLE, EXPANSION_NONE
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, BUILD_NODE_INDEX               ! Use from module mul2 nodes: node db type, build node index.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_LEGACY_NODES_FILE                                   ! Export: read legacy nodes file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_LEGACY_NODES_FILE(FILE_NAME, KINEMATICS,           ! Subroutine read legacy nodes file takes file name, kinematics, nodes, status.
     &                                  NODES, STATUS)

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(KINEMATICS_DB_TYPE), INTENT(INOUT) :: KINEMATICS              ! In/out of type kinematics_db_type: kinematics.
      TYPE(NODE_DB_TYPE), INTENT(INOUT) :: NODES                         ! In/out of type node_db_type: nodes.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(KINEMATIC_TYPE), ALLOCATABLE :: TABLE(:)                      ! Allocatable of type kinematic_type: table(:).
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: MODEL                                         ! Character (length 16): model.
      INTEGER(I8) :: ID                                                  ! Integer (int64): id.
      REAL(R8) :: ORDER_VALUE                                            ! Real (real64): order_value.
      INTEGER(I4) :: FAMILY                                              ! Integer (int32): family.
      INTEGER(I4) :: ORDER                                               ! Integer (int32): order.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: N_KINEMATIC                                         ! Integer (int32): n_kinematic.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(NODES%ITEM)) DEALLOCATE(NODES%ITEM)                  ! If allocated(nodes.item), free the memory of nodes.item.
      IF (ALLOCATED(KINEMATICS%ITEM)) DEALLOCATE(KINEMATICS%ITEM)        ! If allocated(kinematics.item), free the memory of kinematics.item.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_LEGACY_NODES_FILE',                 ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) COUNT                      ! If ios = 0, read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 1_I4) THEN                          ! If ios /= 0 or count < 1:
        CALL SET_ERROR(STATUS, 'READ_LEGACY_NODES_FILE',                 ! Record an error in status: 'INVALID NODE COUNT'.
     &                 'INVALID NODE COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(NODES%ITEM(COUNT))                                        ! Allocate memory for nodes.item(count).
      ALLOCATE(TABLE(COUNT))                                             ! Allocate memory for table(count).
      N_KINEMATIC = 0_I4                                                 ! Set n_kinematic to zero.

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_LEGACY_NODES_FILE',               ! Record an error in status: 'NODE RECORDS ARE MISSING'.
     &                   'NODE RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        ORDER_VALUE = 0.0_R8                                             ! Set order_value to zero.
        READ(LINE,*,IOSTAT=IOS) ID, NODES%ITEM(I)%COORDINATE(1:3),       ! Read from the text line into id, nodes.item(i).coordinate(1:3), model, order_value.
     &                          MODEL, ORDER_VALUE
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          ORDER_VALUE = 0.0_R8                                           ! Set order_value to zero.
          READ(LINE,*,IOSTAT=IOS) ID,                                    ! Read from the text line into id, nodes.item(i).coordinate(1:3), model.
     &                            NODES%ITEM(I)%COORDINATE(1:3), MODEL
        END IF                                                           ! End of the IF block.
        IF (IOS .NE. 0 .OR. ID .LT. 1_I8) THEN                           ! If ios /= 0 or id < 1:
          CALL SET_ERROR(STATUS, 'READ_LEGACY_NODES_FILE',               ! Record an error in status: 'INVALID NODE RECORD'.
     &                   'INVALID NODE RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        CALL UPPERCASE(MODEL)                                            ! Call uppercase with model.
        ORDER = NINT(ORDER_VALUE)                                        ! Set order to nint(order_value).
        SELECT CASE(TRIM(MODEL))                                         ! Choose according to the value of trim(model):
        CASE('TE')                                                       ! Case 'TE':
          FAMILY = EXPANSION_TE                                          ! Set family to expansion_te.
          IF (ORDER .LT. 0_I4) THEN                                      ! If order < 0:
            CALL SET_ERROR(STATUS, 'READ_LEGACY_NODES_FILE',             ! Record an error in status: 'NEGATIVE TAYLOR ORDER'.
     &                     'NEGATIVE TAYLOR ORDER')
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        CASE('LE')                                                       ! Case 'LE':
          FAMILY = EXPANSION_LE                                          ! Set family to expansion_le.
          ORDER = 0_I4                                                   ! Set order to zero.
        CASE('HLE')                                                      ! Case 'HLE':
          FAMILY = EXPANSION_HLE                                         ! Set family to expansion_hle.
          ORDER = 0_I4                                                   ! Set order to zero.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'READ_LEGACY_NODES_FILE',               ! Record an error in status: 'UNSUPPORTED NODE MODEL (ONLY TE, LE AND HLE): '// trim(model).
     &      'UNSUPPORTED NODE MODEL (ONLY TE, LE AND HLE): '//
     &      TRIM(MODEL))
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END SELECT                                                       ! End of the case selection.
        NODES%ITEM(I)%ID = ID                                            ! Set nodes.item(i).id to id.
        NODES%ITEM(I)%KINEMATIC_ID = REGISTER_KINEMATIC(TABLE,           ! Set nodes.item(i).kinematic_id to register_kinematic(table, n_kinematic, family, order).
     &                               N_KINEMATIC, FAMILY, ORDER)
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.
      CALL BUILD_NODE_INDEX(NODES, STATUS)                               ! Call build node index with nodes, status.
      IF (STATUS%CODE .GE. 2_I4) RETURN                                  ! If status.code >= 2, return to the caller.

      ALLOCATE(KINEMATICS%ITEM(N_KINEMATIC))                             ! Allocate memory for kinematics.item(n_kinematic).
      KINEMATICS%ITEM = TABLE(1:N_KINEMATIC)                             ! Set kinematics.item to table(1:n_kinematic).

      END SUBROUTINE READ_LEGACY_NODES_FILE                              ! End of the subroutine read legacy nodes file.

!  RETURN THE ID OF THE (FAMILY, ORDER) KINEMATIC, CREATING IT IF NEW.
      INTEGER(I4) FUNCTION REGISTER_KINEMATIC(TABLE, N_KINEMATIC,        ! Function register kinematic takes table, n kinematic, family, order.
     &                                        FAMILY, ORDER)

      TYPE(KINEMATIC_TYPE), INTENT(INOUT) :: TABLE(:)                    ! In/out of type kinematic_type: table(:).
      INTEGER(I4), INTENT(INOUT) :: N_KINEMATIC                          ! In/out integer (int32): n_kinematic.
      INTEGER(I4), INTENT(IN) :: FAMILY                                  ! Input integer (int32): family.
      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.

      DO I = 1_I4, N_KINEMATIC                                           ! Loop i from 1 to n_kinematic:
        IF (TABLE(I)%FIELD(1)%FAMILY .EQ. FAMILY .AND.                   ! If table(i).field(1).family = family and table(i).field(1).order = order:
     &      TABLE(I)%FIELD(1)%ORDER .EQ. ORDER) THEN
          REGISTER_KINEMATIC = TABLE(I)%ID                               ! Set register_kinematic to table(i).id.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      N_KINEMATIC = N_KINEMATIC + 1_I4                                   ! Add 1 to n_kinematic.
      TABLE(N_KINEMATIC)%ID = N_KINEMATIC                                ! Set table(n_kinematic).id to n_kinematic.
      DO FIELD = 1_I4, 3_I4                                              ! Loop field from 1 to 3:
        TABLE(N_KINEMATIC)%FIELD(FIELD)%FAMILY = FAMILY                  ! Set table(n_kinematic).field(field).family to family.
        TABLE(N_KINEMATIC)%FIELD(FIELD)%ORDER = ORDER                    ! Set table(n_kinematic).field(field).order to order.
      END DO                                                             ! End of the loop.
      REGISTER_KINEMATIC = N_KINEMATIC                                   ! Set register_kinematic to n_kinematic.

      END FUNCTION REGISTER_KINEMATIC                                    ! End of the function register kinematic.

      END MODULE MUL2_READ_LEGACY_NODES                                  ! End of the module mul2 read legacy nodes.
