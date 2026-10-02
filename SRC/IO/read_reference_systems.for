!=======================================================================
!  VERSORS.DAT READER.
!=======================================================================
      MODULE MUL2_READ_REFERENCE_SYSTEMS                                 ! Module mul2 read reference systems begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error.
     &                       SET_WARNING, SET_ERROR
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_REFERENCE_SYSTEMS, ONLY: REFERENCE_VECTOR_DB_TYPE         ! Use from module mul2 reference systems: reference vector db type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_REFERENCE_VECTORS_FILE                              ! Export: read reference vectors file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_REFERENCE_VECTORS_FILE(FILE_NAME,                  ! Subroutine read reference vectors file takes file name, database, status.
     &                                       DATABASE, STATUS)

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(REFERENCE_VECTOR_DB_TYPE), INTENT(INOUT) :: DATABASE          ! In/out of type reference_vector_db_type: database.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: KEYWORD                                       ! Character (length 16): keyword.
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
        CALL SET_ERROR(STATUS, 'READ_REFERENCE_VECTORS_FILE',            ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_REFERENCE_VECTORS_FILE',            ! Record an error in status: 'MISSING REFERENCE VECTOR COUNT'.
     &                 'MISSING REFERENCE VECTOR COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(LINE,*,IOSTAT=IOS) COUNT                                      ! Read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 1_I4) THEN                          ! If ios /= 0 or count < 1:
        CALL SET_ERROR(STATUS, 'READ_REFERENCE_VECTORS_FILE',            ! Record an error in status: 'INVALID REFERENCE VECTOR COUNT'.
     &                 'INVALID REFERENCE VECTOR COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(DATABASE%ITEM(COUNT))                                     ! Allocate memory for database.item(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_REFERENCE_VECTORS_FILE',          ! Record an error in status: 'REFERENCE VECTOR RECORDS ARE MISSING'.
     &                   'REFERENCE VECTOR RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,            ! Read from the text line into keyword, database.item(i).id, (database.item(i).direction(j),j=1,3).
     &       (DATABASE%ITEM(I)%DIRECTION(J),J=1,3)
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        IF (IOS .NE. 0 .OR. DATABASE%ITEM(I)%ID .LT. 1_I4 .OR.           ! If ios /= 0 or database.item(i).id < 1 or trim(keyword) /= 'VERSOR':
     &      TRIM(KEYWORD) .NE. 'VERSOR') THEN
          CALL SET_ERROR(STATUS, 'READ_REFERENCE_VECTORS_FILE',          ! Record an error in status: 'INVALID REFERENCE VECTOR RECORD'.
     &                   'INVALID REFERENCE VECTOR RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (DUPLICATE_ID(DATABASE,I,DATABASE%ITEM(I)%ID)) THEN           ! If duplicate_id(database,i,database.item(i).id):
          CALL SET_ERROR(STATUS, 'READ_REFERENCE_VECTORS_FILE',          ! Record an error in status: 'DUPLICATE REFERENCE VECTOR ID'.
     &                   'DUPLICATE REFERENCE VECTOR ID')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (SQRT(SUM(DATABASE%ITEM(I)%DIRECTION**2)) .LE.                ! If sqrt(sum(database.item(i).direction**2)) <= 100.0d0*tiny(1.0d0):
     &      100.0D0*TINY(1.0D0)) THEN
          CALL SET_ERROR(STATUS, 'READ_REFERENCE_VECTORS_FILE',          ! Record an error in status: 'ZERO REFERENCE VECTOR'.
     &                   'ZERO REFERENCE VECTOR')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_REFERENCE_VECTORS_FILE',          ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_REFERENCE_VECTORS_FILE                         ! End of the subroutine read reference vectors file.

      LOGICAL FUNCTION DUPLICATE_ID(DATABASE, LIMIT, ID)                 ! Function duplicate id takes database, limit, id.

      TYPE(REFERENCE_VECTOR_DB_TYPE), INTENT(IN) :: DATABASE             ! Input of type reference_vector_db_type: database.
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

      END MODULE MUL2_READ_REFERENCE_SYSTEMS                             ! End of the module mul2 read reference systems.
