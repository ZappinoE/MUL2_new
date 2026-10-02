!=======================================================================
!  NODES.DAT READER FOR THE V3 FORMAT.
!=======================================================================
      MODULE MUL2_READ_NODES                                             ! Module mul2 read nodes begins.

      USE MUL2_KINDS, ONLY: I4, I8                                       ! Use from module mul2 kinds: i4, i8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error.
     &                       SET_WARNING, SET_ERROR
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE,                     ! Use from module mul2 kinematics: kinematics db type, has kinematic id.
     &                           HAS_KINEMATIC_ID
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, BUILD_NODE_INDEX               ! Use from module mul2 nodes: node db type, build node index.
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_NODES_FILE                                          ! Export: read nodes file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_NODES_FILE(FILE_NAME, KINEMATICS,                  ! Subroutine read nodes file takes file name, kinematics, nodes, status.
     &                           NODES, STATUS)

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(NODE_DB_TYPE), INTENT(INOUT) :: NODES                         ! In/out of type node_db_type: nodes.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      INTEGER(I8) :: ID                                                  ! Integer (int64): id.
      INTEGER(I4) :: KINEMATIC_ID                                        ! Integer (int32): kinematic_id.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(NODES%ITEM)) DEALLOCATE(NODES%ITEM)                  ! If allocated(nodes.item), free the memory of nodes.item.

      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_NODES_FILE',                        ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_NODES_FILE',                        ! Record an error in status: 'MISSING NODE COUNT'.
     &                 'MISSING NODE COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(LINE,*,IOSTAT=IOS) COUNT                                      ! Read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 1_I4) THEN                          ! If ios /= 0 or count < 1:
        CALL SET_ERROR(STATUS, 'READ_NODES_FILE',                        ! Record an error in status: 'INVALID NODE COUNT'.
     &                 'INVALID NODE COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(NODES%ITEM(COUNT))                                        ! Allocate memory for nodes.item(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_NODES_FILE',                      ! Record an error in status: 'NODE RECORDS ARE MISSING'.
     &                   'NODE RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) ID,                                      ! Read from the text line into id, nodes.item(i).coordinate(1:3), kinematic_id.
     &       NODES%ITEM(I)%COORDINATE(1:3), KINEMATIC_ID
        IF (IOS .NE. 0 .OR. ID .LT. 1_I8) THEN                           ! If ios /= 0 or id < 1:
          CALL SET_ERROR(STATUS, 'READ_NODES_FILE',                      ! Record an error in status: 'INVALID NODE RECORD'.
     &                   'INVALID NODE RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (.NOT. HAS_KINEMATIC_ID(KINEMATICS,                           ! If not has_kinematic_id(kinematics, kinematic_id):
     &                             KINEMATIC_ID)) THEN
          CALL SET_ERROR(STATUS, 'READ_NODES_FILE',                      ! Record an error in status: 'UNKNOWN KINEMATIC ID'.
     &                   'UNKNOWN KINEMATIC ID')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        NODES%ITEM(I)%ID = ID                                            ! Set nodes.item(i).id to id.
        NODES%ITEM(I)%KINEMATIC_ID = KINEMATIC_ID                        ! Set nodes.item(i).kinematic_id to kinematic_id.
      END DO                                                             ! End of the loop.

      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_NODES_FILE',                      ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.
      CALL BUILD_NODE_INDEX(NODES, LOCAL_STATUS)                         ! Call build node index with nodes, local_status.
      IF (LOCAL_STATUS%CODE .GE. 2_I4) THEN                              ! If local_status.code >= 2:
        CALL SET_ERROR(STATUS, 'READ_NODES_FILE',                        ! Record an error in status: trim(local_status.message).
     &                 TRIM(LOCAL_STATUS%MESSAGE))
      END IF                                                             ! End of the IF block.

      END SUBROUTINE READ_NODES_FILE                                     ! End of the subroutine read nodes file.

      END MODULE MUL2_READ_NODES                                         ! End of the module mul2 read nodes.
