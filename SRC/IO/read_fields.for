!=======================================================================
!  READER OF FIELDS.DAT (OPTIONAL FILE).
!
!      N_FIELDS
!      FIELD ID N_TERMS
!      TERM C1 [C2 ...]          (N_TERMS LINES)
!      ...
!=======================================================================
      MODULE MUL2_READ_FIELDS                                            ! Module mul2 read fields begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_FIELDS                                                    ! Use everything exported by module mul2 fields.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_FIELDS_FILE                                         ! Export: read fields file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_FIELDS_FILE(FILE_NAME, DATABASE, STATUS)           ! Subroutine read fields file takes file name, database, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(FIELD_DB_TYPE), INTENT(INOUT) :: DATABASE                     ! In/out of type field_db_type: database.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: KEYWORD                                       ! Character (length 16): keyword.
      REAL(R8) :: VALUE(5)                                               ! Real (real64): value(5).
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: ID                                                  ! Integer (int32): id.
      INTEGER(I4) :: N_TERM                                              ! Integer (int32): n_term.
      INTEGER(I4) :: NEED                                                ! Integer (int32): need.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(DATABASE%ITEM)) DEALLOCATE(DATABASE%ITEM)            ! If allocated(database.item), free the memory of database.item.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ',    ! Open the file file_name.
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        ALLOCATE(DATABASE%ITEM(0))                                       ! Allocate memory for database.item(0).
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) COUNT                      ! If ios = 0, read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 0_I4) THEN                          ! If ios /= 0 or count < 0:
        CALL SET_ERROR(STATUS, 'READ_FIELDS_FILE',                       ! Record an error in status: 'INVALID NUMBER OF FIELDS'.
     &                 'INVALID NUMBER OF FIELDS')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(DATABASE%ITEM(COUNT))                                     ! Allocate memory for database.item(count).
      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, N_TERM      ! If ios = 0, read from the text line into keyword, id, n_term.
        IF (IOS .NE. 0 .OR. N_TERM .LT. 1_I4 .OR. ID .LT. 1_I4) THEN     ! If ios /= 0 or n_term < 1 or id < 1:
          CALL SET_ERROR(STATUS, 'READ_FIELDS_FILE',                     ! Record an error in status: 'INVALID FIELD HEADER (FIELD ID N_TERMS)'.
     &                   'INVALID FIELD HEADER (FIELD ID N_TERMS)')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (FIND_FIELD_INDEX(DATABASE,ID) .NE. 0_I4) THEN                ! If find_field_index(database,id) /= 0:
          CALL SET_ERROR(STATUS, 'READ_FIELDS_FILE',                     ! Record an error in status: 'DUPLICATE FIELD ID'.
     &                   'DUPLICATE FIELD ID')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DATABASE%ITEM(I)%ID = ID                                         ! Set database.item(i).id to id.
        ALLOCATE(DATABASE%ITEM(I)%TERM(N_TERM))                          ! Allocate memory for database.item(i).term(n_term).
        ALLOCATE(DATABASE%ITEM(I)%CONSTANT(N_TERM,5))                    ! Allocate memory for database.item(i).constant(n_term,5).
        DATABASE%ITEM(I)%CONSTANT = 0.0_R8                               ! Set database.item(i).constant to zero.
        DO J = 1_I4, N_TERM                                              ! Loop j from 1 to n_term:
          CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                           ! Call next data line with unit, line, ios.
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CALL SET_ERROR(STATUS, 'READ_FIELDS_FILE',                   ! Record an error in status: 'FIELD TERMS ARE MISSING'.
     &                     'FIELD TERMS ARE MISSING')
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          READ(LINE,*,IOSTAT=IOS) KEYWORD                                ! Read from the text line into keyword.
          CALL UPPERCASE(KEYWORD)                                        ! Call uppercase with keyword.
          VALUE = 0.0_R8                                                 ! Set value to zero.
          SELECT CASE (TRIM(KEYWORD))                                    ! Choose according to the value of trim(keyword):
          CASE ('CONST')                                                 ! Case 'CONST':
            DATABASE%ITEM(I)%TERM(J) = TERM_CONSTANT                     ! Set database.item(i).term(j) to term_constant.
            NEED = 1_I4                                                  ! Set need to 1.
          CASE ('X-EXP')                                                 ! Case 'X-EXP':
            DATABASE%ITEM(I)%TERM(J) = TERM_POWER_X                      ! Set database.item(i).term(j) to term_power_x.
            NEED = 2_I4                                                  ! Set need to 2.
          CASE ('Y-EXP')                                                 ! Case 'Y-EXP':
            DATABASE%ITEM(I)%TERM(J) = TERM_POWER_Y                      ! Set database.item(i).term(j) to term_power_y.
            NEED = 2_I4                                                  ! Set need to 2.
          CASE ('Z-EXP')                                                 ! Case 'Z-EXP':
            DATABASE%ITEM(I)%TERM(J) = TERM_POWER_Z                      ! Set database.item(i).term(j) to term_power_z.
            NEED = 2_I4                                                  ! Set need to 2.
          CASE ('ATNZX')                                                 ! Case 'ATNZX':
            DATABASE%ITEM(I)%TERM(J) = TERM_ARCTAN                       ! Set database.item(i).term(j) to term_arctan.
            NEED = 3_I4                                                  ! Set need to 3.
          CASE ('COS-X')                                                 ! Case 'COS-X':
            DATABASE%ITEM(I)%TERM(J) = TERM_COS_X                        ! Set database.item(i).term(j) to term_cos_x.
            NEED = 3_I4                                                  ! Set need to 3.
          CASE ('COS-Y')                                                 ! Case 'COS-Y':
            DATABASE%ITEM(I)%TERM(J) = TERM_COS_Y                        ! Set database.item(i).term(j) to term_cos_y.
            NEED = 3_I4                                                  ! Set need to 3.
          CASE ('COS-Z')                                                 ! Case 'COS-Z':
            DATABASE%ITEM(I)%TERM(J) = TERM_COS_Z                        ! Set database.item(i).term(j) to term_cos_z.
            NEED = 3_I4                                                  ! Set need to 3.
          CASE ('SIN-X')                                                 ! Case 'SIN-X':
            DATABASE%ITEM(I)%TERM(J) = TERM_SIN_X                        ! Set database.item(i).term(j) to term_sin_x.
            NEED = 3_I4                                                  ! Set need to 3.
          CASE ('SIN-Y')                                                 ! Case 'SIN-Y':
            DATABASE%ITEM(I)%TERM(J) = TERM_SIN_Y                        ! Set database.item(i).term(j) to term_sin_y.
            NEED = 3_I4                                                  ! Set need to 3.
          CASE ('SIN-Z')                                                 ! Case 'SIN-Z':
            DATABASE%ITEM(I)%TERM(J) = TERM_SIN_Z                        ! Set database.item(i).term(j) to term_sin_z.
            NEED = 3_I4                                                  ! Set need to 3.
          CASE ('B-SIN')                                                 ! Case 'B-SIN':
            DATABASE%ITEM(I)%TERM(J) = TERM_BI_SINE                      ! Set database.item(i).term(j) to term_bi_sine.
            NEED = 5_I4                                                  ! Set need to 5.
          CASE DEFAULT                                                   ! In every other case:
            CALL SET_ERROR(STATUS, 'READ_FIELDS_FILE',                   ! Record an error in status: 'UNSUPPORTED FIELD TERM: '//trim(keyword).
     &        'UNSUPPORTED FIELD TERM: '//TRIM(KEYWORD))
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END SELECT                                                     ! End of the case selection.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, VALUE(1:NEED)                 ! Read from the text line into keyword, value(1:need).
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CALL SET_ERROR(STATUS, 'READ_FIELDS_FILE',                   ! Record an error in status: 'WRONG NUMBER OF CONSTANTS FOR '//trim(keyword).
     &        'WRONG NUMBER OF CONSTANTS FOR '//TRIM(KEYWORD))
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          DATABASE%ITEM(I)%CONSTANT(J,:) = VALUE                         ! Set database.item(i).constant(j,:) to value.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_FIELDS_FILE                                    ! End of the subroutine read fields file.

      END MODULE MUL2_READ_FIELDS                                        ! End of the module mul2 read fields.
