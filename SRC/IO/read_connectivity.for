!=======================================================================
!  CONNECTIVITY.DAT READER.
!=======================================================================
      MODULE MUL2_READ_CONNECTIVITY                                      ! Module mul2 read connectivity begins.

      USE MUL2_KINDS, ONLY: I4, I8                                       ! Use from module mul2 kinds: i4, i8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error.
     &                       SET_WARNING, SET_ERROR
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_SORTING, ONLY: HAS_DUPLICATE_KEYS                         ! Use from module mul2 sorting: has duplicate keys.
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, HAS_NODE_ID                    ! Use from module mul2 nodes: node db type, has node id.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_UNKNOWN,                       ! Use from module mul2 topologies: topology unknown, topology from name, topology node count.
     &     TOPOLOGY_FROM_NAME, TOPOLOGY_NODE_COUNT

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_CONNECTIVITY_FILE                                   ! Export: read connectivity file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_CONNECTIVITY_FILE(FILE_NAME, NODES,                ! Subroutine read connectivity file takes file name, nodes, elements, status.
     &                                  ELEMENTS, STATUS)

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(INOUT) :: ELEMENTS                   ! In/out of type element_db_type: elements.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: NAME                                          ! Character (length 16): name.
      INTEGER(I8) :: ID                                                  ! Integer (int64): id.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: TOPOLOGY                                            ! Integer (int32): topology.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: FRAME_ID                                            ! Integer (int32): frame_id.
      INTEGER(I4) :: EXPANSION_ID                                        ! Integer (int32): expansion_id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      LOGICAL :: FORCED                                                  ! Logical: forced.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(ELEMENTS%ITEM)) DEALLOCATE(ELEMENTS%ITEM)            ! If allocated(elements.item), free the memory of elements.item.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',                 ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',                 ! Record an error in status: 'MISSING ELEMENT COUNT'.
     &                 'MISSING ELEMENT COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(LINE,*,IOSTAT=IOS) COUNT                                      ! Read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 1_I4) THEN                          ! If ios /= 0 or count < 1:
        CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',                 ! Record an error in status: 'INVALID ELEMENT COUNT'.
     &                 'INVALID ELEMENT COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(ELEMENTS%ITEM(COUNT))                                     ! Allocate memory for elements.item(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',               ! Record an error in status: 'ELEMENT RECORDS ARE MISSING'.
     &                   'ELEMENT RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) NAME, ID                                 ! Read from the text line into name, id.
        IF (IOS .NE. 0 .OR. ID .LT. 1_I8) THEN                           ! If ios /= 0 or id < 1:
          CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',               ! Record an error in status: 'INVALID ELEMENT HEADER'.
     &                   'INVALID ELEMENT HEADER')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        FORCED = .FALSE.                                                 ! Set the flag forced to false.
        CALL ALIAS_NAME(NAME, FORCED)                                    ! Call alias name with name, forced.
        TOPOLOGY = TOPOLOGY_FROM_NAME(NAME)                              ! Set topology to topology_from_name(name).
        IF (TOPOLOGY .EQ. TOPOLOGY_UNKNOWN) THEN                         ! If topology = topology_unknown:
          CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',               ! Record an error in status: 'UNKNOWN ELEMENT TOPOLOGY: '//trim(name).
     &                   'UNKNOWN ELEMENT TOPOLOGY: '//TRIM(NAME))
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.

        N_NODE = TOPOLOGY_NODE_COUNT(TOPOLOGY)                           ! Set n_node to topology_node_count(topology).
        ALLOCATE(ELEMENTS%ITEM(I)%NODE_ID(N_NODE))                       ! Allocate memory for elements.item(i).node_id(n_node).
        FRAME_ID = 0_I4                                                  ! Set frame_id to zero.
        EXPANSION_ID = 0_I4                                              ! Set expansion_id to zero.
        READ(LINE,*,IOSTAT=IOS) NAME, ID,                                ! Read from the text line into name, id, (elements.item(i).node_id(j),j=1,n_node), frame_id, expansion_id.
     &       (ELEMENTS%ITEM(I)%NODE_ID(J),J=1,N_NODE),
     &       FRAME_ID, EXPANSION_ID
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          FRAME_ID = 0_I4                                                ! Set frame_id to zero.
          READ(LINE,*,IOSTAT=IOS) NAME, ID,                              ! Read from the text line into name, id, (elements.item(i).node_id(j),j=1,n_node), expansion_id.
     &         (ELEMENTS%ITEM(I)%NODE_ID(J),J=1,N_NODE),
     &         EXPANSION_ID
        END IF                                                           ! End of the IF block.
        IF (IOS .NE. 0 .OR. EXPANSION_ID .LT. 1_I4) THEN                 ! If ios /= 0 or expansion_id < 1:
          CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',               ! Record an error in status: 'INVALID ELEMENT CONNECTIVITY'.
     &                   'INVALID ELEMENT CONNECTIVITY')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO J = 1_I4, N_NODE                                              ! Loop j from 1 to n_node:
          IF (.NOT. HAS_NODE_ID(NODES,                                   ! If not has_node_id(nodes, elements.item(i).node_id(j)):
     &        ELEMENTS%ITEM(I)%NODE_ID(J))) THEN
            CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',             ! Record an error in status: 'CONNECTIVITY REFERENCES UNKNOWN NODE'.
     &                     'CONNECTIVITY REFERENCES UNKNOWN NODE')
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.

        ELEMENTS%ITEM(I)%ID = ID                                         ! Set elements.item(i).id to id.
        ELEMENTS%ITEM(I)%TOPOLOGY = TOPOLOGY                             ! Set elements.item(i).topology to topology.
        ELEMENTS%ITEM(I)%FRAME_ID = FRAME_ID                             ! Set elements.item(i).frame_id to frame_id.
        ELEMENTS%ITEM(I)%EXPANSION_ID = EXPANSION_ID                     ! Set elements.item(i).expansion_id to expansion_id.
        ELEMENTS%ITEM(I)%GENERAL = FORCED                                ! Set elements.item(i).general to forced.
      END DO                                                             ! End of the loop.

      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_CONNECTIVITY_FILE',               ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.
      IF (HAS_DUPLICATE_KEYS(ELEMENTS%ITEM%ID)) THEN                     ! If has_duplicate_keys(elements.item.id):
        CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE',                 ! Record an error in status: 'DUPLICATE ELEMENT ID'.
     &                 'DUPLICATE ELEMENT ID')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE READ_CONNECTIVITY_FILE                              ! End of the subroutine read connectivity file.

!  S4 S9 S16 ARE THE Q4 Q9 Q16 PLATE TOPOLOGIES AND CB2 CB3 CB4 THE B2 B3
!  B4 BEAM TOPOLOGIES, WITH THE GENERAL (CURVED) GEOMETRY FORCED.
      SUBROUTINE ALIAS_NAME(NAME, FORCED)                                ! Subroutine alias name takes name, forced.

      CHARACTER(LEN=*), INTENT(INOUT) :: NAME                            ! In/out character (length *): name.
      LOGICAL, INTENT(OUT) :: FORCED                                     ! Output logical: forced.
      CHARACTER(LEN=16) :: CLEAN                                         ! Character (length 16): clean.

      FORCED = .TRUE.                                                    ! Set the flag forced to true.
      CLEAN = ADJUSTL(NAME)                                              ! Set clean to adjustl(name).
      SELECT CASE (TRIM(CLEAN))                                          ! Choose according to the value of trim(clean):
      CASE ('S4', 's4')                                                  ! Case 'S4', 's4':
        NAME = 'Q4'                                                      ! Set name to 'Q4'.
      CASE ('S9', 's9')                                                  ! Case 'S9', 's9':
        NAME = 'Q9'                                                      ! Set name to 'Q9'.
      CASE ('S16', 's16')                                                ! Case 'S16', 's16':
        NAME = 'Q16'                                                     ! Set name to 'Q16'.
      CASE ('CB2', 'cb2')                                                ! Case 'CB2', 'cb2':
        NAME = 'B2'                                                      ! Set name to 'B2'.
      CASE ('CB3', 'cb3')                                                ! Case 'CB3', 'cb3':
        NAME = 'B3'                                                      ! Set name to 'B3'.
      CASE ('CB4', 'cb4')                                                ! Case 'CB4', 'cb4':
        NAME = 'B4'                                                      ! Set name to 'B4'.
      CASE DEFAULT                                                       ! In every other case:
        FORCED = .FALSE.                                                 ! Set the flag forced to false.
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE ALIAS_NAME                                          ! End of the subroutine alias name.

      END MODULE MUL2_READ_CONNECTIVITY                                  ! End of the module mul2 read connectivity.
