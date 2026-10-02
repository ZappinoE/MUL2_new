!=======================================================================
!  READER FOR THE FIRST MECHANICAL 101/103 BOUNDARY-CONDITION GATE.
!=======================================================================
      MODULE MUL2_READ_BOUNDARY_CONDITIONS                               ! Module mul2 read boundary conditions begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error.
     &                       SET_WARNING, SET_ERROR
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_BOUNDARY_CONDITIONS, ONLY: BOUNDARY_DB_TYPE,              ! Use from module mul2 boundary conditions: boundary db type, bc displacement plane, bc force point, bc value...
     &     BC_DISPLACEMENT_PLANE, BC_FORCE_POINT, BC_VALUE_POINT,
     &     BC_TIE_PLANE, BC_SURFACE

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_BOUNDARY_CONDITIONS_FILE                            ! Export: read boundary conditions file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_BOUNDARY_CONDITIONS_FILE(FILE_NAME,                ! Subroutine read boundary conditions file takes file name, database, status.
     &                                         DATABASE, STATUS)

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(BOUNDARY_DB_TYPE), INTENT(INOUT) :: DATABASE                  ! In/out of type boundary_db_type: database.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: KEYWORD                                       ! Character (length 16): keyword.
      CHARACTER(LEN=32) :: TOKEN(3)                                      ! Character (length 32): token(3).
      REAL(R8) :: EXTRA                                                  ! Real (real64): extra.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(DATABASE%ITEM)) DEALLOCATE(DATABASE%ITEM)            ! If allocated(database.item), free the memory of database.item.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_BOUNDARY_CONDITIONS_FILE',          ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT,LINE,IOS)                                 ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_BOUNDARY_CONDITIONS_FILE',          ! Record an error in status: 'MISSING BOUNDARY-CONDITION COUNT'.
     &                 'MISSING BOUNDARY-CONDITION COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(LINE,*,IOSTAT=IOS) COUNT                                      ! Read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 0_I4) THEN                          ! If ios /= 0 or count < 0:
        CALL SET_ERROR(STATUS, 'READ_BOUNDARY_CONDITIONS_FILE',          ! Record an error in status: 'INVALID BOUNDARY-CONDITION COUNT'.
     &                 'INVALID BOUNDARY-CONDITION COUNT')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(DATABASE%ITEM(COUNT))                                     ! Allocate memory for database.item(count).

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT,LINE,IOS)                               ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_BOUNDARY_CONDITIONS_FILE',        ! Record an error in status: 'BOUNDARY-CONDITION RECORDS ARE MISSING'.
     &                   'BOUNDARY-CONDITION RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) KEYWORD                                  ! Read from the text line into keyword.
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        SELECT CASE(TRIM(KEYWORD))                                       ! Choose according to the value of trim(keyword):
        CASE('D-PLANE')                                                  ! Case 'D-PLANE':
          DATABASE%ITEM(I)%KIND = BC_DISPLACEMENT_PLANE                  ! Set database.item(i).kind to bc_displacement_plane.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).plane, token.
     &      DATABASE%ITEM(I)%PLANE, TOKEN
          IF (IOS .EQ. 0) CALL PARSE_COMPONENTS(TOKEN,                   ! If ios = 0, call parse components with token, database.item(i).active(1:3), database.item(i).value(1:3), ios.
     &      DATABASE%ITEM(I)%ACTIVE(1:3), DATABASE%ITEM(I)%VALUE(1:3),
     &      IOS)
        CASE('V-PLANE')                                                  ! Case 'V-PLANE':
!         ELECTRIC POTENTIAL ON A PLANE: V-PLANE ID A B C D VALUE.
          DATABASE%ITEM(I)%KIND = BC_DISPLACEMENT_PLANE                  ! Set database.item(i).kind to bc_displacement_plane.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).plane, database.item(i).value(5).
     &      DATABASE%ITEM(I)%PLANE, DATABASE%ITEM(I)%VALUE(5)
          DATABASE%ITEM(I)%ACTIVE(5) = .TRUE.                            ! Set the flag database.item(i).active(5) to true.
        CASE('T-PLANE')                                                  ! Case 'T-PLANE':
!         TEMPERATURE ON A PLANE: T-PLANE ID A B C D VALUE.
          DATABASE%ITEM(I)%KIND = BC_DISPLACEMENT_PLANE                  ! Set database.item(i).kind to bc_displacement_plane.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).plane, database.item(i).value(4).
     &      DATABASE%ITEM(I)%PLANE, DATABASE%ITEM(I)%VALUE(4)
          DATABASE%ITEM(I)%ACTIVE(4) = .TRUE.                            ! Set the flag database.item(i).active(4) to true.
        CASE('T-POINT')                                                  ! Case 'T-POINT':
!         TEMPERATURE AT A SECTION NODE: T-POINT ID X Y Z VALUE.
          DATABASE%ITEM(I)%KIND = BC_VALUE_POINT                         ! Set database.item(i).kind to bc_value_point.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).point, database.item(i).value(4).
     &      DATABASE%ITEM(I)%POINT, DATABASE%ITEM(I)%VALUE(4)
          DATABASE%ITEM(I)%ACTIVE(4) = .TRUE.                            ! Set the flag database.item(i).active(4) to true.
        CASE('T-CONST')                                                  ! Case 'T-CONST':
!         UNIFORM TEMPERATURE EVERYWHERE: T-CONST ID VALUE (THE ZERO
!         PLANE SELECTS EVERY POINT).
          DATABASE%ITEM(I)%KIND = BC_DISPLACEMENT_PLANE                  ! Set database.item(i).kind to bc_displacement_plane.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).value(4).
     &      DATABASE%ITEM(I)%VALUE(4)
          DATABASE%ITEM(I)%ACTIVE(4) = .TRUE.                            ! Set the flag database.item(i).active(4) to true.
        CASE('Q-POINT')                                                  ! Case 'Q-POINT':
!         HEAT POWER AT A SECTION NODE: Q-POINT ID X Y Z POWER.
          DATABASE%ITEM(I)%KIND = BC_FORCE_POINT                         ! Set database.item(i).kind to bc_force_point.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).point, database.item(i).value(4).
     &      DATABASE%ITEM(I)%POINT, DATABASE%ITEM(I)%VALUE(4)
          DATABASE%ITEM(I)%ACTIVE(4) = .TRUE.                            ! Set the flag database.item(i).active(4) to true.
        CASE('Q-PLANE')                                                  ! Case 'Q-PLANE':
!         HEAT FLUX INTO THE EXPOSED SURFACE OF A PLANE (W/M2):
!         Q-PLANE ID A B C D Q.
          DATABASE%ITEM(I)%KIND = BC_SURFACE                             ! Set database.item(i).kind to bc_surface.
          DATABASE%ITEM(I)%SURFACE = 1_I4                                ! Set database.item(i).surface to 1.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).plane, database.item(i).param(1).
     &      DATABASE%ITEM(I)%PLANE, DATABASE%ITEM(I)%PARAM(1)
        CASE('Q-SUN')                                                    ! Case 'Q-SUN':
!         SOLAR LOAD ON THE WHOLE EXPOSED SKIN: Q-SUN ID SX SY SZ G A
!         (S TOWARDS THE SUN, G IRRADIANCE W/M2, A ABSORPTIVITY).
          DATABASE%ITEM(I)%KIND = BC_SURFACE                             ! Set database.item(i).kind to bc_surface.
          DATABASE%ITEM(I)%SURFACE = 2_I4                                ! Set database.item(i).surface to 2.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).param(1:5).
     &      DATABASE%ITEM(I)%PARAM(1:5)
          IF (IOS .EQ. 0) THEN                                           ! If ios = 0:
            IF (SUM(DATABASE%ITEM(I)%PARAM(1:3)**2) .LE. 0.0_R8) THEN    ! If sum(database.item(i).param(1:3)**2) <= 0.0:
              IOS = 1                                                    ! Set ios to 1.
            ELSE                                                         ! Otherwise:
              DATABASE%ITEM(I)%PARAM(1:3) = DATABASE%ITEM(I)%PARAM(1:3)/ ! Divide database.item(i).param(1:3) by sqrt(sum(database.item(i).param(1:3)**2)).
     &          SQRT(SUM(DATABASE%ITEM(I)%PARAM(1:3)**2))
            END IF                                                       ! End of the IF block.
          END IF                                                         ! End of the IF block.
        CASE('Q-CONV')                                                   ! Case 'Q-CONV':
!         CONVECTION ON THE EXPOSED SURFACE OF A PLANE (THE ZERO PLANE
!         MEANS ALL): Q-CONV ID A B C D H T_INF.
          DATABASE%ITEM(I)%KIND = BC_SURFACE                             ! Set database.item(i).kind to bc_surface.
          DATABASE%ITEM(I)%SURFACE = 3_I4                                ! Set database.item(i).surface to 3.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).plane, database.item(i).param(1...
     &      DATABASE%ITEM(I)%PLANE, DATABASE%ITEM(I)%PARAM(1:2)
        CASE('V-FLOAT')                                                  ! Case 'V-FLOAT':
!         FLOATING (EQUIPOTENTIAL) ELECTRODE: V-FLOAT ID A B C D.
          DATABASE%ITEM(I)%KIND = BC_TIE_PLANE                           ! Set database.item(i).kind to bc_tie_plane.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).plane.
     &      DATABASE%ITEM(I)%PLANE
          DATABASE%ITEM(I)%ACTIVE(5) = .TRUE.                            ! Set the flag database.item(i).active(5) to true.
        CASE('V-POINT')                                                  ! Case 'V-POINT':
!         ELECTRIC POTENTIAL AT A SECTION NODE: V-POINT ID X Y Z VALUE.
          DATABASE%ITEM(I)%KIND = BC_VALUE_POINT                         ! Set database.item(i).kind to bc_value_point.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).point, database.item(i).value(5).
     &      DATABASE%ITEM(I)%POINT, DATABASE%ITEM(I)%VALUE(5)
          DATABASE%ITEM(I)%ACTIVE(5) = .TRUE.                            ! Set the flag database.item(i).active(5) to true.
        CASE('F-POINT')                                                  ! Case 'F-POINT':
!         F-POINT ID X Y Z FX FY FZ [CHARGE]: THE OPTIONAL LAST VALUE
!         IS THE ELECTRIC CHARGE APPLIED TO THE POTENTIAL FIELD.
          DATABASE%ITEM(I)%KIND = BC_FORCE_POINT                         ! Set database.item(i).kind to bc_force_point.
          DATABASE%ITEM(I)%ACTIVE(1:3) = .TRUE.                          ! Set the flag database.item(i).active(1:3) to true.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,          ! Read from the text line into keyword, database.item(i).id, database.item(i).point, database.item(i).value(1...
     &      DATABASE%ITEM(I)%POINT, DATABASE%ITEM(I)%VALUE(1:3), EXTRA
          IF (IOS .EQ. 0) THEN                                           ! If ios = 0:
            DATABASE%ITEM(I)%VALUE(5) = EXTRA                            ! Set database.item(i).value(5) to extra.
            DATABASE%ITEM(I)%ACTIVE(5) = .TRUE.                          ! Set the flag database.item(i).active(5) to true.
          ELSE                                                           ! Otherwise:
            READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%ITEM(I)%ID,        ! Read from the text line into keyword, database.item(i).id, database.item(i).point, database.item(i).value(1...
     &        DATABASE%ITEM(I)%POINT, DATABASE%ITEM(I)%VALUE(1:3)
          END IF                                                         ! End of the IF block.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'READ_BOUNDARY_CONDITIONS_FILE',        ! Record an error in status: 'UNSUPPORTED 101/103 BOUNDARY CONDITION: '// trim(keyword).
     &      'UNSUPPORTED 101/103 BOUNDARY CONDITION: '//
     &      TRIM(KEYWORD))
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END SELECT                                                       ! End of the case selection.
        IF (IOS .EQ. 0) CALL READ_FIELD_ID(LINE, KEYWORD,                ! If ios = 0, call read field id with line, keyword, database.item(i).
     &                                  DATABASE%ITEM(I))
        IF (IOS .NE. 0 .OR. DATABASE%ITEM(I)%ID .LT. 1_I4) THEN          ! If ios /= 0 or database.item(i).id < 1:
          CALL SET_ERROR(STATUS, 'READ_BOUNDARY_CONDITIONS_FILE',        ! Record an error in status: 'INVALID BOUNDARY-CONDITION RECORD'.
     &                   'INVALID BOUNDARY-CONDITION RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL NEXT_DATA_LINE(UNIT,LINE,IOS)                                 ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_BOUNDARY_CONDITIONS_FILE',        ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_BOUNDARY_CONDITIONS_FILE                       ! End of the subroutine read boundary conditions file.

!  A RECORD OF A VALUE MAY END WITH A FIELD NUMBER (FIELDS.DAT): THE
!  RECORD IS READ AGAIN WITH ONE MORE ITEM; IF IT IS NOT THERE NOTHING
!  CHANGES.
      SUBROUTINE READ_FIELD_ID(LINE, KEYWORD, ITEM)                      ! Subroutine read field id takes line, keyword, item.

      USE MUL2_BOUNDARY_CONDITIONS, ONLY: BOUNDARY_CONDITION_TYPE        ! Use from module mul2 boundary conditions: boundary condition type.
      CHARACTER(LEN=*), INTENT(IN) :: LINE                               ! Input character (length *): line.
      CHARACTER(LEN=*), INTENT(IN) :: KEYWORD                            ! Input character (length *): keyword.
      TYPE(BOUNDARY_CONDITION_TYPE), INTENT(INOUT) :: ITEM               ! In/out of type boundary_condition_type: item.
      CHARACTER(LEN=16) :: WORD                                          ! Character (length 16): word.
      CHARACTER(LEN=32) :: TOKEN(3)                                      ! Character (length 32): token(3).
      INTEGER(I4) :: ID                                                  ! Integer (int32): id.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      REAL(R8) :: X(8)                                                   ! Real (real64): x(8).
      INTEGER :: IOS                                                     ! Integer: ios.

      FIELD = 0_I4                                                       ! Set field to zero.
      SELECT CASE (TRIM(KEYWORD))                                        ! Choose according to the value of trim(keyword):
      CASE ('D-PLANE')                                                   ! Case 'D-PLANE':
        READ(LINE,*,IOSTAT=IOS) WORD, ID, X(1:4), TOKEN, FIELD           ! Read from the text line into word, id, x(1:4), token, field.
      CASE ('V-PLANE','T-PLANE')                                         ! Case 'V-PLANE','T-PLANE':
        READ(LINE,*,IOSTAT=IOS) WORD, ID, X(1:4), X(5), FIELD            ! Read from the text line into word, id, x(1:4), x(5), field.
      CASE ('V-POINT','T-POINT')                                         ! Case 'V-POINT','T-POINT':
        READ(LINE,*,IOSTAT=IOS) WORD, ID, X(1:3), X(4), FIELD            ! Read from the text line into word, id, x(1:3), x(4), field.
      CASE ('T-CONST')                                                   ! Case 'T-CONST':
        READ(LINE,*,IOSTAT=IOS) WORD, ID, X(1), FIELD                    ! Read from the text line into word, id, x(1), field.
      CASE ('Q-PLANE')                                                   ! Case 'Q-PLANE':
        READ(LINE,*,IOSTAT=IOS) WORD, ID, X(1:4), X(5), FIELD            ! Read from the text line into word, id, x(1:4), x(5), field.
      CASE DEFAULT                                                       ! In every other case:
        RETURN                                                           ! Return to the caller.
      END SELECT                                                         ! End of the case selection.
      IF (IOS .EQ. 0) ITEM%FIELD_ID = FIELD                              ! If ios = 0, set item.field_id to field.

      END SUBROUTINE READ_FIELD_ID                                       ! End of the subroutine read field id.

      SUBROUTINE PARSE_COMPONENTS(TOKEN, ACTIVE, VALUE, IOS)             ! Subroutine parse components takes token, active, value, ios.

      CHARACTER(LEN=32), INTENT(IN) :: TOKEN(3)                          ! Input character (length 32): token(3).
      LOGICAL, INTENT(OUT) :: ACTIVE(3)                                  ! Output logical: active(3).
      REAL(R8), INTENT(OUT) :: VALUE(3)                                  ! Output real (real64): value(3).
      CHARACTER(LEN=32) :: CLEAN                                         ! Character (length 32): clean.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER, INTENT(OUT) :: IOS                                        ! Output integer: ios.

      ACTIVE = .FALSE.                                                   ! Set the flag active to false.
      VALUE = 0.0_R8                                                     ! Set value to zero.
      IOS = 0                                                            ! Set ios to zero.
      DO I = 1_I4, 3_I4                                                  ! Loop i from 1 to 3:
        CLEAN = TOKEN(I)                                                 ! Set clean to token(i).
        CALL UPPERCASE(CLEAN)                                            ! Call uppercase with clean.
        IF (TRIM(ADJUSTL(CLEAN)) .EQ. 'N') CYCLE                         ! If trim(adjustl(clean)) = 'N', skip to the next iteration.
        READ(CLEAN,*,IOSTAT=IOS) VALUE(I)                                ! Read from unit clean into value(i).
        IF (IOS .NE. 0) RETURN                                           ! If ios /= 0, return to the caller.
        ACTIVE(I) = .TRUE.                                               ! Set the flag active(i) to true.
      END DO                                                             ! End of the loop.

      END SUBROUTINE PARSE_COMPONENTS                                    ! End of the subroutine parse components.

      END MODULE MUL2_READ_BOUNDARY_CONDITIONS                           ! End of the module mul2 read boundary conditions.
