!=======================================================================
!  READ EXP_MESH_NN.DAT AND EXP_CONN_NN.DAT FILES.
!=======================================================================
      MODULE MUL2_READ_EXPANSIONS                                        ! Module mul2 read expansions begins.

      USE MUL2_KINDS, ONLY: I4, I8                                       ! Use from module mul2 kinds: i4, i8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error, status is ok.
     &                       SET_WARNING, SET_ERROR, STATUS_IS_OK
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_UNKNOWN,                       ! Use from module mul2 topologies: topology unknown, topology from name, topology node count, topology is hle...
     &     TOPOLOGY_FROM_NAME, TOPOLOGY_NODE_COUNT,
     &     TOPOLOGY_IS_HLE_FAMILY
      USE MUL2_HLE_MODES, ONLY: BUILD_HLE_MESH                           ! Use from module mul2 hle modes: build hle mesh.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_MESH_TYPE,              ! Use from module mul2 expansion meshes: expansion mesh type, expansion db type, has expansion node id.
     &     EXPANSION_DB_TYPE, HAS_EXPANSION_NODE_ID

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_EXPANSION_FILES                                     ! Export: read expansion files.
      PUBLIC :: READ_EXPANSION_SET                                       ! Export: read expansion set.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_EXPANSION_FILES(MESH_FILE, CONNECTIVITY_FILE,      ! Subroutine read expansion files takes mesh file, connectivity file, expansion id, mesh, status.
     &                                EXPANSION_ID, MESH, STATUS)

      CHARACTER(LEN=*), INTENT(IN) :: MESH_FILE                          ! Input character (length *): mesh_file.
      CHARACTER(LEN=*), INTENT(IN) :: CONNECTIVITY_FILE                  ! Input character (length *): connectivity_file.
      INTEGER(I4), INTENT(IN) :: EXPANSION_ID                            ! Input integer (int32): expansion_id.
      TYPE(EXPANSION_MESH_TYPE), INTENT(INOUT) :: MESH                   ! In/out of type expansion_mesh_type: mesh.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL READ_EXPANSION_NODES(MESH_FILE, MESH, STATUS)                 ! Call read expansion nodes with mesh_file, mesh, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL READ_EXPANSION_ELEMENTS(CONNECTIVITY_FILE, MESH, STATUS)      ! Call read expansion elements with connectivity_file, mesh, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_HLE_MESH(MESH, STATUS)                                  ! Call build hle mesh with mesh, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      MESH%ID = EXPANSION_ID                                             ! Set mesh.id to expansion_id.

      END SUBROUTINE READ_EXPANSION_FILES                                ! End of the subroutine read expansion files.

      SUBROUTINE READ_EXPANSION_SET(PATH, COUNT, DATABASE, STATUS)       ! Subroutine read expansion set takes path, count, database, status.

      CHARACTER(LEN=*), INTENT(IN) :: PATH                               ! Input character (length *): path.
      INTEGER(I4), INTENT(IN) :: COUNT                                   ! Input integer (int32): count.
      TYPE(EXPANSION_DB_TYPE), INTENT(INOUT) :: DATABASE                 ! In/out of type expansion_db_type: database.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: MESH_FILE                                    ! Character (length 512): mesh_file.
      CHARACTER(LEN=512) :: CONNECTIVITY_FILE                            ! Character (length 512): connectivity_file.
      CHARACTER(LEN=32) :: SUFFIX                                        ! Character (length 32): suffix.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(DATABASE%ITEM)) DEALLOCATE(DATABASE%ITEM)            ! If allocated(database.item), free the memory of database.item.
      IF (COUNT .LT. 1_I4 .OR. COUNT .GT. 99_I4) THEN                    ! If count < 1 or count > 99:
        CALL SET_ERROR(STATUS, 'READ_EXPANSION_SET',                     ! Record an error in status: 'EXPANSION COUNT MUST BE BETWEEN 1 AND 99'.
     &                 'EXPANSION COUNT MUST BE BETWEEN 1 AND 99')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(DATABASE%ITEM(COUNT))                                     ! Allocate memory for database.item(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        WRITE(SUFFIX,'(I2.2)') I                                         ! Write to unit suffix: i.
        MESH_FILE = TRIM(PATH)//'/EXP_MESH_'//TRIM(SUFFIX)//'.dat'       ! Set mesh_file to trim(path)//'/EXP_MESH_'//trim(suffix)//'.dat'.
        CONNECTIVITY_FILE = TRIM(PATH)//'/EXP_CONN_'//                   ! Set connectivity_file to trim(path)//'/EXP_CONN_'// trim(suffix)//'.dat'.
     &                      TRIM(SUFFIX)//'.dat'
        CALL READ_EXPANSION_FILES(TRIM(MESH_FILE),                       ! Call read expansion files with trim(mesh_file), trim(connectivity_file), i, database.item(i), status.
     &       TRIM(CONNECTIVITY_FILE), I, DATABASE%ITEM(I), STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE READ_EXPANSION_SET                                  ! End of the subroutine read expansion set.

      SUBROUTINE READ_EXPANSION_NODES(FILE_NAME, MESH, STATUS)           ! Subroutine read expansion nodes takes file name, mesh, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(EXPANSION_MESH_TYPE), INTENT(INOUT) :: MESH                   ! In/out of type expansion_mesh_type: mesh.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      IF (ALLOCATED(MESH%NODE)) DEALLOCATE(MESH%NODE)                    ! If allocated(mesh.node), free the memory of mesh.node.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_EXPANSION_NODES',                   ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_EXPANSION_NODES',                   ! Record an error in status: 'MISSING NODE COUNT'.
     &                 'MISSING NODE COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(LINE,*,IOSTAT=IOS) COUNT                                      ! Read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 1_I4) THEN                          ! If ios /= 0 or count < 1:
        CALL SET_ERROR(STATUS, 'READ_EXPANSION_NODES',                   ! Record an error in status: 'INVALID NODE COUNT'.
     &                 'INVALID NODE COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(MESH%NODE(COUNT))                                         ! Allocate memory for mesh.node(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_EXPANSION_NODES',                 ! Record an error in status: 'NODE RECORDS ARE MISSING'.
     &                   'NODE RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) MESH%NODE(I)%ID,                         ! Read from the text line into mesh.node(i).id, (mesh.node(i).coordinate(j),j=1,3).
     &       (MESH%NODE(I)%COORDINATE(J),J=1,3)
        IF (IOS .NE. 0 .OR. MESH%NODE(I)%ID .LT. 1_I8) THEN              ! If ios /= 0 or mesh.node(i).id < 1:
          CALL SET_ERROR(STATUS, 'READ_EXPANSION_NODES',                 ! Record an error in status: 'INVALID NODE RECORD'.
     &                   'INVALID NODE RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (DUPLICATE_NODE_ID(MESH,I,MESH%NODE(I)%ID)) THEN              ! If duplicate_node_id(mesh,i,mesh.node(i).id):
          CALL SET_ERROR(STATUS, 'READ_EXPANSION_NODES',                 ! Record an error in status: 'DUPLICATE EXPANSION NODE ID'.
     &                   'DUPLICATE EXPANSION NODE ID')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_EXPANSION_NODES',                 ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_EXPANSION_NODES                                ! End of the subroutine read expansion nodes.

      SUBROUTINE READ_EXPANSION_ELEMENTS(FILE_NAME, MESH, STATUS)        ! Subroutine read expansion elements takes file name, mesh, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(EXPANSION_MESH_TYPE), INTENT(INOUT) :: MESH                   ! In/out of type expansion_mesh_type: mesh.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: NAME                                          ! Character (length 16): name.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: TOPOLOGY                                            ! Integer (int32): topology.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: ORDER                                               ! Integer (int32): order.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER :: MID_IOS                                                 ! Integer: mid_ios.

      IF (ALLOCATED(MESH%ELEMENT)) DEALLOCATE(MESH%ELEMENT)              ! If allocated(mesh.element), free the memory of mesh.element.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',                ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',                ! Record an error in status: 'MISSING ELEMENT COUNT'.
     &                 'MISSING ELEMENT COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(LINE,*,IOSTAT=IOS) COUNT                                      ! Read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 1_I4) THEN                          ! If ios /= 0 or count < 1:
        CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',                ! Record an error in status: 'INVALID ELEMENT COUNT'.
     &                 'INVALID ELEMENT COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(MESH%ELEMENT(COUNT))                                      ! Allocate memory for mesh.element(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',              ! Record an error in status: 'ELEMENT RECORDS ARE MISSING'.
     &                   'ELEMENT RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) NAME, MESH%ELEMENT(I)%ID                 ! Read from the text line into name, mesh.element(i).id.
        IF (IOS .NE. 0 .OR. MESH%ELEMENT(I)%ID .LT. 1_I8) THEN           ! If ios /= 0 or mesh.element(i).id < 1:
          CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',              ! Record an error in status: 'INVALID ELEMENT HEADER'.
     &                   'INVALID ELEMENT HEADER')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        TOPOLOGY = TOPOLOGY_FROM_NAME(NAME)                              ! Set topology to topology_from_name(name).
        IF (TOPOLOGY .EQ. TOPOLOGY_UNKNOWN) THEN                         ! If topology = topology_unknown:
          CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',              ! Record an error in status: 'UNKNOWN TOPOLOGY: '//trim(name).
     &                   'UNKNOWN TOPOLOGY: '//TRIM(NAME))
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (DUPLICATE_ELEMENT_ID(MESH,I,MESH%ELEMENT(I)%ID)) THEN        ! If duplicate_element_id(mesh,i,mesh.element(i).id):
          CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',              ! Record an error in status: 'DUPLICATE EXPANSION ELEMENT ID'.
     &                   'DUPLICATE EXPANSION ELEMENT ID')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        N_NODE = TOPOLOGY_NODE_COUNT(TOPOLOGY)                           ! Set n_node to topology_node_count(topology).
        ALLOCATE(MESH%ELEMENT(I)%NODE_ID(N_NODE))                        ! Allocate memory for mesh.element(i).node_id(n_node).
        ORDER = 0_I4                                                     ! Set order to zero.
        IF (TOPOLOGY_IS_HLE_FAMILY(TOPOLOGY)) THEN                       ! If topology_is_hle_family(topology):
!         HLE: THE POLYNOMIAL ORDER FOLLOWS THE VERTEX NODES.
          READ(LINE,*,IOSTAT=IOS) NAME, MESH%ELEMENT(I)%ID,              ! Read from the text line into name, mesh.element(i).id, mesh.element(i).lamination_id, (mesh.element(i).node...
     &         MESH%ELEMENT(I)%LAMINATION_ID,
     &         (MESH%ELEMENT(I)%NODE_ID(J),J=1,N_NODE), ORDER
!         OPTIONAL: FOUR MID-SIDE NODE IDS (0 = STRAIGHT SIDE).
          MESH%ELEMENT(I)%MID_NODE_ID = 0_I8                             ! Set mesh.element(i).mid_node_id to zero.
          IF (IOS .EQ. 0 .AND. N_NODE .EQ. 4_I4) THEN                    ! If ios = 0 and n_node = 4:
            READ(LINE,*,IOSTAT=MID_IOS) NAME, MESH%ELEMENT(I)%ID,        ! Read from the text line into name, mesh.element(i).id, mesh.element(i).lamination_id, (mesh.element(i).node...
     &           MESH%ELEMENT(I)%LAMINATION_ID,
     &           (MESH%ELEMENT(I)%NODE_ID(J),J=1,N_NODE), ORDER,
     &           (MESH%ELEMENT(I)%MID_NODE_ID(J),J=1,4)
            IF (MID_IOS .NE. 0) MESH%ELEMENT(I)%MID_NODE_ID = 0_I8       ! If mid_ios /= 0, set mesh.element(i).mid_node_id to zero.
          END IF                                                         ! End of the IF block.
          IF (IOS .EQ. 0 .AND. (ORDER .LT. 1_I4 .OR.                     ! If ios = 0 and (order < 1 or order > 30), set ios to 1.
     &        ORDER .GT. 30_I4)) IOS = 1
          IF (IOS .EQ. 0) TOPOLOGY = TOPOLOGY + ORDER                    ! If ios = 0, add order to topology.
        ELSE                                                             ! Otherwise:
          READ(LINE,*,IOSTAT=IOS) NAME, MESH%ELEMENT(I)%ID,              ! Read from the text line into name, mesh.element(i).id, mesh.element(i).lamination_id, (mesh.element(i).node...
     &         MESH%ELEMENT(I)%LAMINATION_ID,
     &         (MESH%ELEMENT(I)%NODE_ID(J),J=1,N_NODE)
        END IF                                                           ! End of the IF block.
        IF (IOS .NE. 0 .OR.                                              ! If ios /= 0 or mesh.element(i).lamination_id < 1:
     &      MESH%ELEMENT(I)%LAMINATION_ID .LT. 1_I4) THEN
          CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',              ! Record an error in status: 'INVALID ELEMENT RECORD'.
     &                   'INVALID ELEMENT RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO J = 1_I4, N_NODE                                              ! Loop j from 1 to n_node:
          IF (.NOT. HAS_EXPANSION_NODE_ID(MESH,                          ! If not has_expansion_node_id(mesh, mesh.element(i).node_id(j)):
     &        MESH%ELEMENT(I)%NODE_ID(J))) THEN
            CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',            ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                     'ELEMENT REFERENCES UNKNOWN NODE')
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        DO J = 1_I4, 4_I4                                                ! Loop j from 1 to 4:
          IF (MESH%ELEMENT(I)%MID_NODE_ID(J) .NE. 0_I8) THEN             ! If mesh.element(i).mid_node_id(j) /= 0:
            IF (.NOT. HAS_EXPANSION_NODE_ID(MESH,                        ! If not has_expansion_node_id(mesh, mesh.element(i).mid_node_id(j)):
     &          MESH%ELEMENT(I)%MID_NODE_ID(J))) THEN
              CALL SET_ERROR(STATUS, 'READ_EXPANSION_ELEMENTS',          ! Record an error in status: 'MID-SIDE NODE IS NOT IN EXP_MESH'.
     &                       'MID-SIDE NODE IS NOT IN EXP_MESH')
              CLOSE(UNIT)                                                ! Close the file.
              RETURN                                                     ! Return to the caller.
            END IF                                                       ! End of the IF block.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        MESH%ELEMENT(I)%TOPOLOGY = TOPOLOGY                              ! Set mesh.element(i).topology to topology.
      END DO                                                             ! End of the loop.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_EXPANSION_ELEMENTS',              ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_EXPANSION_ELEMENTS                             ! End of the subroutine read expansion elements.

      LOGICAL FUNCTION DUPLICATE_NODE_ID(MESH, LIMIT, ID)                ! Function duplicate node id takes mesh, limit, id.

      TYPE(EXPANSION_MESH_TYPE), INTENT(IN) :: MESH                      ! Input of type expansion_mesh_type: mesh.
      INTEGER(I4), INTENT(IN) :: LIMIT                                   ! Input integer (int32): limit.
      INTEGER(I8), INTENT(IN) :: ID                                      ! Input integer (int64): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      DUPLICATE_NODE_ID = .FALSE.                                        ! Set the flag duplicate_node_id to false.
      DO I = 1_I4, LIMIT - 1_I4                                          ! Loop i from 1 to limit - 1:
        IF (MESH%NODE(I)%ID .EQ. ID) THEN                                ! If mesh.node(i).id = id:
          DUPLICATE_NODE_ID = .TRUE.                                     ! Set the flag duplicate_node_id to true.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION DUPLICATE_NODE_ID                                     ! End of the function duplicate node id.

      LOGICAL FUNCTION DUPLICATE_ELEMENT_ID(MESH, LIMIT, ID)             ! Function duplicate element id takes mesh, limit, id.

      TYPE(EXPANSION_MESH_TYPE), INTENT(IN) :: MESH                      ! Input of type expansion_mesh_type: mesh.
      INTEGER(I4), INTENT(IN) :: LIMIT                                   ! Input integer (int32): limit.
      INTEGER(I8), INTENT(IN) :: ID                                      ! Input integer (int64): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      DUPLICATE_ELEMENT_ID = .FALSE.                                     ! Set the flag duplicate_element_id to false.
      DO I = 1_I4, LIMIT - 1_I4                                          ! Loop i from 1 to limit - 1:
        IF (MESH%ELEMENT(I)%ID .EQ. ID) THEN                             ! If mesh.element(i).id = id:
          DUPLICATE_ELEMENT_ID = .TRUE.                                  ! Set the flag duplicate_element_id to true.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION DUPLICATE_ELEMENT_ID                                  ! End of the function duplicate element id.

      END MODULE MUL2_READ_EXPANSIONS                                    ! End of the module mul2 read expansions.
