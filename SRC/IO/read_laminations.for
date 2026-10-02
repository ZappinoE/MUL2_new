!=======================================================================
!  LAMINATION.DAT READER. FIRST GATE SUPPORTS CONSTANT LAM2 RECORDS.
!=======================================================================
      MODULE MUL2_READ_LAMINATIONS                                       ! Module mul2 read laminations begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error.
     &                       SET_WARNING, SET_ERROR
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_MATERIALS, ONLY: MATERIAL_DB_TYPE,                        ! Use from module mul2 materials: material db type, find material index.
     &                          FIND_MATERIAL_INDEX
      USE MUL2_LAMINATIONS, ONLY: LAMINATION_DB_TYPE,                    ! Use from module mul2 laminations: lamination db type, lamination constant, find lamination index.
     &     LAMINATION_CONSTANT, FIND_LAMINATION_INDEX

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_LAMINATIONS_FILE                                    ! Export: read laminations file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_LAMINATIONS_FILE(FILE_NAME, MATERIALS,             ! Subroutine read laminations file takes file name, materials, database, status.
     &                                 DATABASE, STATUS)

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(MATERIAL_DB_TYPE), INTENT(IN) :: MATERIALS                    ! Input of type material_db_type: materials.
      TYPE(LAMINATION_DB_TYPE), INTENT(INOUT) :: DATABASE                ! In/out of type lamination_db_type: database.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: KEYWORD                                       ! Character (length 16): keyword.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(DATABASE%ITEM)) DEALLOCATE(DATABASE%ITEM)            ! If allocated(database.item), free the memory of database.item.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_LAMINATIONS_FILE',                  ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_LAMINATIONS_FILE',                  ! Record an error in status: 'MISSING LAMINATION COUNT'.
     &                 'MISSING LAMINATION COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(LINE,*,IOSTAT=IOS) COUNT                                      ! Read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 1_I4) THEN                          ! If ios /= 0 or count < 1:
        CALL SET_ERROR(STATUS, 'READ_LAMINATIONS_FILE',                  ! Record an error in status: 'INVALID LAMINATION COUNT'.
     &                 'INVALID LAMINATION COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(DATABASE%ITEM(COUNT))                                     ! Allocate memory for database.item(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_LAMINATIONS_FILE',                ! Record an error in status: 'LAMINATION RECORDS ARE MISSING'.
     &                   'LAMINATION RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,            ! Read from the text line into keyword, database.item(i).id, database.item(i).material_id, database.item(i).a...
     &       DATABASE%ITEM(I)%MATERIAL_ID,
     &       DATABASE%ITEM(I)%ANGLE_Y_DEG,
     &       DATABASE%ITEM(I)%ANGLE_Z_DEG
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        IF (IOS .NE. 0 .OR. TRIM(KEYWORD) .NE. 'LAM2') THEN              ! If ios /= 0 or trim(keyword) /= 'LAM2':
          CALL SET_ERROR(STATUS, 'READ_LAMINATIONS_FILE',                ! Record an error in status: 'ONLY LAM2 IS ACTIVE FOR SOLUTIONS 101/103'.
     &       'ONLY LAM2 IS ACTIVE FOR SOLUTIONS 101/103')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DATABASE%ITEM(I)%KIND = LAMINATION_CONSTANT                      ! Set database.item(i).kind to lamination_constant.
        IF (DATABASE%ITEM(I)%ID .LT. 1_I4 .OR.                           ! If database.item(i).id < 1 or find_lamination_index(database, database.item(i).id) /= i:
     &      FIND_LAMINATION_INDEX(DATABASE,
     &      DATABASE%ITEM(I)%ID) .NE. I) THEN
          CALL SET_ERROR(STATUS, 'READ_LAMINATIONS_FILE',                ! Record an error in status: 'INVALID OR DUPLICATE LAMINATION ID'.
     &                   'INVALID OR DUPLICATE LAMINATION ID')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (FIND_MATERIAL_INDEX(MATERIALS,                               ! If find_material_index(materials, database.item(i).material_id) = 0:
     &      DATABASE%ITEM(I)%MATERIAL_ID) .EQ. 0_I4) THEN
          CALL SET_ERROR(STATUS, 'READ_LAMINATIONS_FILE',                ! Record an error in status: 'LAMINATION REFERENCES UNKNOWN MATERIAL'.
     &                   'LAMINATION REFERENCES UNKNOWN MATERIAL')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_LAMINATIONS_FILE',                ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_LAMINATIONS_FILE                               ! End of the subroutine read laminations file.

      END MODULE MUL2_READ_LAMINATIONS                                   ! End of the module mul2 read laminations.
