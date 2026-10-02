!=======================================================================
!  KINEMATICS.DAT READER.
!=======================================================================
      MODULE MUL2_READ_KINEMATICS                                        ! Module mul2 read kinematics begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error, status is ok.
     &                       SET_WARNING, SET_ERROR, STATUS_IS_OK
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_KINEMATICS, ONLY: N_FIELDS, KINEMATICS_DB_TYPE,           ! Use from module mul2 kinematics: n fields, kinematics db type, parse expansion token.
     &                           PARSE_EXPANSION_TOKEN

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_KINEMATICS_FILE                                     ! Export: read kinematics file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_KINEMATICS_FILE(FILE_NAME, DATABASE, STATUS)       ! Subroutine read kinematics file takes file name, database, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(KINEMATICS_DB_TYPE), INTENT(INOUT) :: DATABASE                ! In/out of type kinematics_db_type: database.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=32) :: KEYWORD                                       ! Character (length 32): keyword.
      CHARACTER(LEN=32) :: TOKENS(N_FIELDS)                              ! Character (length 32): tokens(n_fields).
      INTEGER(I4) :: ID                                                  ! Integer (int32): id.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(DATABASE%ITEM)) DEALLOCATE(DATABASE%ITEM)            ! If allocated(database.item), free the memory of database.item.

      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_KINEMATICS_FILE',                   ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_KINEMATICS_FILE',                   ! Record an error in status: 'MISSING KINEMATIC COUNT'.
     &                 'MISSING KINEMATIC COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      READ(LINE,*,IOSTAT=IOS) COUNT                                      ! Read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 1_I4) THEN                          ! If ios /= 0 or count < 1:
        CALL SET_ERROR(STATUS, 'READ_KINEMATICS_FILE',                   ! Record an error in status: 'INVALID KINEMATIC COUNT'.
     &                 'INVALID KINEMATIC COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(DATABASE%ITEM(COUNT))                                     ! Allocate memory for database.item(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_KINEMATICS_FILE',                 ! Record an error in status: 'KINEMATIC RECORDS ARE MISSING'.
     &                   'KINEMATIC RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.

        TOKENS = ' '                                                     ! Set tokens to ' '.
        KEYWORD = ' '                                                    ! Set keyword to ' '.
        READ(LINE,*,IOSTAT=IOS) KEYWORD, ID,                             ! Read from the text line into keyword, id, (tokens(j),j=1,n_fields).
     &                          (TOKENS(J),J=1,N_FIELDS)
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        IF (IOS .NE. 0 .OR. TRIM(KEYWORD) .NE. 'KINEMATIC') THEN         ! If ios /= 0 or trim(keyword) /= 'KINEMATIC':
          CALL SET_ERROR(STATUS, 'READ_KINEMATICS_FILE',                 ! Record an error in status: 'INVALID KINEMATIC RECORD'.
     &                   'INVALID KINEMATIC RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (ID .LT. 1_I4 .OR. DUPLICATE_ID(DATABASE,I,ID)) THEN          ! If id < 1 or duplicate_id(database,i,id):
          CALL SET_ERROR(STATUS, 'READ_KINEMATICS_FILE',                 ! Record an error in status: 'INVALID OR DUPLICATE KINEMATIC ID'.
     &                   'INVALID OR DUPLICATE KINEMATIC ID')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.

        DATABASE%ITEM(I)%ID = ID                                         ! Set database.item(i).id to id.
        DO J = 1_I4, N_FIELDS                                            ! Loop j from 1 to n_fields:
          CALL PARSE_EXPANSION_TOKEN(TOKENS(J),                          ! Call parse expansion token with tokens(j), database.item(i).field(j), status.
     &         DATABASE%ITEM(I)%FIELD(J), STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) THEN                           ! If not status is ok:
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_KINEMATICS_FILE',                 ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_KINEMATICS_FILE                                ! End of the subroutine read kinematics file.

      LOGICAL FUNCTION DUPLICATE_ID(DATABASE, LIMIT, ID)                 ! Function duplicate id takes database, limit, id.

      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: DATABASE                   ! Input of type kinematics_db_type: database.
      INTEGER(I4), INTENT(IN) :: LIMIT                                   ! Input integer (int32): limit.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      DUPLICATE_ID = .FALSE.                                             ! Set the flag duplicate_id to false.
      DO I = 1_I4, LIMIT - 1_I4                                          ! Loop i from 1 to limit - 1:
        IF (DATABASE%ITEM(I)%ID .EQ. ID) THEN                            ! If database.item(i).id = id:
          DUPLICATE_ID = .TRUE.                                          ! Set the flag duplicate_id to true.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION DUPLICATE_ID                                          ! End of the function duplicate id.

      END MODULE MUL2_READ_KINEMATICS                                    ! End of the module mul2 read kinematics.
