!=======================================================================
!  ANALYSIS.DAT AND POSTPROCESSING.DAT READERS (LEGACY FORMATS).
!=======================================================================
      MODULE MUL2_READ_ANALYSIS                                          ! Module mul2 read analysis begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error.
     &                       SET_WARNING, SET_ERROR
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_ANALYSIS_INPUT, ONLY: ANALYSIS_TYPE, POST_DB_TYPE,        ! Use from module mul2 analysis input: analysis type, post db type, post field request type, post point reque...
     &     POST_FIELD_REQUEST_TYPE, POST_POINT_REQUEST_TYPE,
     &     SHEAR_NONE, SHEAR_REDUCED, SHEAR_SELECTIVE, SHEAR_MITC,
     &     POST_FORMAT_PARAVIEW, POST_FORMAT_GMSH,
     &     POST_FRAME_LOCAL, POST_FRAME_GLOBAL

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_ANALYSIS_FILE                                       ! Export: read analysis file.
      PUBLIC :: READ_POSTPROCESSING_FILE                                 ! Export: read postprocessing file.

      CONTAINS                                                           ! The procedures of the module follow.

!  RECORD ORDER: SOLUTION ID, NUMBER OF MODES AND THE SHEAR TREATMENTS
!  (NONE, REDI, SELI, MITC) OF BEAM, PLATE AND SOLID ELEMENTS. THE
!  OBSOLETE SOLVER RECORD OF THE HISTORICAL FORMAT (A SECOND INTEGER
!  BETWEEN THE SOLUTION ID AND THE NUMBER OF MODES) IS RECOGNISED AND
!  IGNORED WITH A WARNING.
      SUBROUTINE READ_ANALYSIS_FILE(FILE_NAME, ANALYSIS, STATUS)         ! Subroutine read analysis file takes file name, analysis, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(ANALYSIS_TYPE), INTENT(OUT) :: ANALYSIS                       ! Output of type analysis_type: analysis.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=512) :: LINE_MODES                                   ! Character (length 512): line_modes.
      CHARACTER(LEN=16) :: TOKEN                                         ! Character (length 16): token.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER :: PROBE                                                   ! Integer: probe.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: PROBE_VALUE                                         ! Integer (int32): probe_value.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                     ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) ANALYSIS%SOLUTION          ! If ios = 0, read from the text line into analysis.solution.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                     ! Record an error in status: 'INVALID ANALYSIS TYPE'.
     &                 'INVALID ANALYSIS TYPE')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
!     SECOND RECORD: NUMBER OF MODES. IF THE FOLLOWING RECORD IS ALSO
!     AN INTEGER THE FILE HAS THE HISTORICAL SOLVER RECORD AND THE ONE
!     JUST READ WAS THAT.
      CALL NEXT_DATA_LINE(UNIT, LINE_MODES, IOS)                         ! Call next data line with unit, line_modes, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                     ! Record an error in status: 'INVALID NUMBER OF MODES'.
     &                 'INVALID NUMBER OF MODES')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        READ(LINE,*,IOSTAT=PROBE) PROBE_VALUE                            ! Read from the text line into probe_value.
        IF (PROBE .EQ. 0) THEN                                           ! If probe = 0:
          CALL SET_WARNING(STATUS, 'READ_ANALYSIS_FILE',                 ! Record a warning in status: 'THE SOLVER RECORD OF ANALYSIS.DAT IS OBSOLETE: IGNORED'.
     &      'THE SOLVER RECORD OF ANALYSIS.DAT IS OBSOLETE: IGNORED')
          LINE_MODES = LINE                                              ! Set line_modes to line.
          CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                           ! Call next data line with unit, line, ios.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      READ(LINE_MODES,*,IOSTAT=PROBE) ANALYSIS%MODE_COUNT                ! Read from unit line_modes into analysis.mode_count.
      IF (PROBE .NE. 0) THEN                                             ! If probe /= 0:
        CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                     ! Record an error in status: 'INVALID NUMBER OF MODES'.
     &                 'INVALID NUMBER OF MODES')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO I = 1_I4, 3_I4                                                  ! Loop i from 1 to 3:
        IF (I .GT. 1_I4) CALL NEXT_DATA_LINE(UNIT, LINE, IOS)            ! If i > 1, call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                   ! Record an error in status: 'MISSING SHEAR-LOCKING CORRECTION'.
     &                   'MISSING SHEAR-LOCKING CORRECTION')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) TOKEN                                    ! Read from the text line into token.
        CALL UPPERCASE(TOKEN)                                            ! Call uppercase with token.
        SELECT CASE(TRIM(TOKEN))                                         ! Choose according to the value of trim(token):
        CASE('NONE')                                                     ! Case 'NONE':
          ANALYSIS%SHEAR(I) = SHEAR_NONE                                 ! Set analysis.shear(i) to shear_none.
        CASE('REDI')                                                     ! Case 'REDI':
          ANALYSIS%SHEAR(I) = SHEAR_REDUCED                              ! Set analysis.shear(i) to shear_reduced.
        CASE('SELI')                                                     ! Case 'SELI':
          ANALYSIS%SHEAR(I) = SHEAR_SELECTIVE                            ! Set analysis.shear(i) to shear_selective.
        CASE('MITC')                                                     ! Case 'MITC':
          ANALYSIS%SHEAR(I) = SHEAR_MITC                                 ! Set analysis.shear(i) to shear_mitc.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                   ! Record an error in status: 'UNKNOWN SHEAR-LOCKING CORRECTION: '//trim(token).
     &      'UNKNOWN SHEAR-LOCKING CORRECTION: '//TRIM(TOKEN))
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END SELECT                                                       ! End of the case selection.
      END DO                                                             ! End of the loop.
!     OPTIONAL LAST RECORDS: `FIELDS MECH THERMO PIEZO` AND
!     `JOIN COINCIDENT [TOLERANCE]`, IN ANY ORDER
      DO                                                                 ! Loop until an EXIT statement is reached:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) EXIT                                             ! If ios /= 0, leave the loop.
        TOKEN = ' '                                                      ! Set token to ' '.
        READ(LINE,*,IOSTAT=PROBE) TOKEN                                  ! Read from the text line into token.
        CALL UPPERCASE(TOKEN)                                            ! Call uppercase with token.
        SELECT CASE (TRIM(TOKEN))                                        ! Choose according to the value of trim(token):
        CASE ('FIELDS')                                                  ! Case 'FIELDS':
          CALL READ_FIELD_RECORD(LINE, ANALYSIS, STATUS)                 ! Call read field record with line, analysis, status.
        CASE ('JOIN')                                                    ! Case 'JOIN':
          CALL READ_JOIN_RECORD(LINE, ANALYSIS, STATUS)                  ! Call read join record with line, analysis, status.
        CASE DEFAULT                                                     ! In every other case:
          CONTINUE                                                       ! No operation (loop terminator).
        END SELECT                                                       ! End of the case selection.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_ANALYSIS_FILE                                  ! End of the subroutine read analysis file.

!  `JOIN COINCIDENT [TOLERANCE]`: THE DOFS OF DIFFERENT NODES THAT ARE
!  THE SAME FIELD AT THE SAME POINT ARE JOINED (TOLERANCE: FRACTION OF THE
!  DIAGONAL OF THE MODEL, DEFAULT 1E-6).
      SUBROUTINE READ_JOIN_RECORD(LINE, ANALYSIS, STATUS)                ! Subroutine read join record takes line, analysis, status.

      CHARACTER(LEN=*), INTENT(IN) :: LINE                               ! Input character (length *): line.
      TYPE(ANALYSIS_TYPE), INTENT(INOUT) :: ANALYSIS                     ! In/out of type analysis_type: analysis.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      CHARACTER(LEN=16) :: WORD(2)                                       ! Character (length 16): word(2).
      REAL(R8) :: VALUE                                                  ! Real (real64): value.
      INTEGER :: IOS                                                     ! Integer: ios.

      WORD = ' '                                                         ! Set word to ' '.
      VALUE = ANALYSIS%JOIN_TOLERANCE                                    ! Set value to analysis.join_tolerance.
      READ(LINE,*,IOSTAT=IOS) WORD, VALUE                                ! Read from the text line into word, value.
      CALL UPPERCASE(WORD(2))                                            ! Call uppercase with word(2).
      IF (TRIM(WORD(2)) .NE. 'COINCIDENT') THEN                          ! If trim(word(2)) /= 'COINCIDENT':
        CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                     ! Record an error in status: 'THE JOIN RECORD IS `JOIN COINCIDENT [TOLERANCE]`'.
     &    'THE JOIN RECORD IS `JOIN COINCIDENT [TOLERANCE]`')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (VALUE .LE. 0.0_R8) THEN                                        ! If value <= 0.0:
        CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                     ! Record an error in status: 'THE TOLERANCE OF JOIN COINCIDENT MUST BE POSITIVE'.
     &    'THE TOLERANCE OF JOIN COINCIDENT MUST BE POSITIVE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ANALYSIS%JOIN_COINCIDENT = .TRUE.                                  ! Set the flag analysis.join_coincident to true.
      ANALYSIS%JOIN_TOLERANCE = VALUE                                    ! Set analysis.join_tolerance to value.

      END SUBROUTINE READ_JOIN_RECORD                                    ! End of the subroutine read join record.

!  `FIELDS MECH THERMO PIEZO`: THE ACTIVE PHYSICS. MECH (DISPLACEMENTS)
!  IS ALWAYS SOLVED; `STRESS` (MIXED RMVT ELEMENTS) IS RESERVED.
      SUBROUTINE READ_FIELD_RECORD(LINE, ANALYSIS, STATUS)               ! Subroutine read field record takes line, analysis, status.

      CHARACTER(LEN=*), INTENT(IN) :: LINE                               ! Input character (length *): line.
      TYPE(ANALYSIS_TYPE), INTENT(INOUT) :: ANALYSIS                     ! In/out of type analysis_type: analysis.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      CHARACTER(LEN=16) :: WORD(8)                                       ! Character (length 16): word(8).
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER :: IOS                                                     ! Integer: ios.

      WORD = ' '                                                         ! Set word to ' '.
      READ(LINE,*,IOSTAT=IOS) WORD                                       ! Read from the text line into word.
      ANALYSIS%FIELD_RECORD = .TRUE.                                     ! Set the flag analysis.field_record to true.
      ANALYSIS%FIELD_MECH = .FALSE.                                      ! Set the flag analysis.field_mech to false.
      ANALYSIS%FIELD_THERMO = .FALSE.                                    ! Set the flag analysis.field_thermo to false.
      ANALYSIS%FIELD_PIEZO = .FALSE.                                     ! Set the flag analysis.field_piezo to false.
      DO K = 2_I4, 8_I4                                                  ! Loop k from 2 to 8:
        CALL UPPERCASE(WORD(K))                                          ! Call uppercase with word(k).
        SELECT CASE(TRIM(WORD(K)))                                       ! Choose according to the value of trim(word(k)):
        CASE(' ')                                                        ! Case ' ':
          CONTINUE                                                       ! No operation (loop terminator).
        CASE('MECH')                                                     ! Case 'MECH':
          ANALYSIS%FIELD_MECH = .TRUE.                                   ! Set the flag analysis.field_mech to true.
        CASE('THERMO')                                                   ! Case 'THERMO':
          ANALYSIS%FIELD_THERMO = .TRUE.                                 ! Set the flag analysis.field_thermo to true.
        CASE('PIEZO')                                                    ! Case 'PIEZO':
          ANALYSIS%FIELD_PIEZO = .TRUE.                                  ! Set the flag analysis.field_piezo to true.
        CASE('STRESS')                                                   ! Case 'STRESS':
          CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                   ! Record an error in status: 'MIXED STRESS FIELDS (RMVT) ARE NOT IMPLEMENTED YET'.
     &      'MIXED STRESS FIELDS (RMVT) ARE NOT IMPLEMENTED YET')
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'READ_ANALYSIS_FILE',                   ! Record an error in status: 'UNKNOWN FIELD IN THE FIELDS RECORD: '//trim(word(k)).
     &      'UNKNOWN FIELD IN THE FIELDS RECORD: '//TRIM(WORD(K)))
        END SELECT                                                       ! End of the case selection.
      END DO                                                             ! End of the loop.
      IF (.NOT. ANALYSIS%FIELD_MECH) CALL SET_ERROR(STATUS,              ! If not analysis.field_mech, record an error in status: 'THE FIELDS RECORD MUST CONTAIN MECH'.
     &  'READ_ANALYSIS_FILE', 'THE FIELDS RECORD MUST CONTAIN MECH')

      END SUBROUTINE READ_FIELD_RECORD                                   ! End of the subroutine read field record.

!  FIRST RECORD: NUMBER OF REQUESTS. THEN `PARA`/`GMSH` FIELD OUTPUTS,
!  `PNT` POINT OUTPUTS AND THE MATRIX DUMPS `KMAT MMAT FRCE UNKN ENRG`.
      SUBROUTINE READ_POSTPROCESSING_FILE(FILE_NAME, POST, STATUS)       ! Subroutine read postprocessing file takes file name, post, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(POST_DB_TYPE), INTENT(INOUT) :: POST                          ! In/out of type post_db_type: post.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(POST_FIELD_REQUEST_TYPE), ALLOCATABLE :: FIELD(:)             ! Allocatable of type post_field_request_type: field(:).
      TYPE(POST_POINT_REQUEST_TYPE), ALLOCATABLE :: POINT(:)             ! Allocatable of type post_point_request_type: point(:).
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: KEYWORD                                       ! Character (length 16): keyword.
      CHARACTER(LEN=16) :: FRAME_TOKEN                                   ! Character (length 16): frame_token.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: N_FIELD                                             ! Integer (int32): n_field.
      INTEGER(I4) :: N_POINT                                             ! Integer (int32): n_point.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: CELL_NODES                                          ! Integer (int32): cell_nodes.
      INTEGER(I4) :: SPLIT(9)                                            ! Integer (int32): split(9).
      INTEGER(I4) :: ID                                                  ! Integer (int32): id.
      REAL(R8) :: COORDINATE(3)                                          ! Real (real64): coordinate(3).

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(POST%FIELD)) DEALLOCATE(POST%FIELD)                  ! If allocated(post.field), free the memory of post.field.
      IF (ALLOCATED(POST%POINT)) DEALLOCATE(POST%POINT)                  ! If allocated(post.point), free the memory of post.point.
      POST%WRITE_STIFFNESS = .FALSE.                                     ! Set the flag post.write_stiffness to false.
      POST%WRITE_MASS = .FALSE.                                          ! Set the flag post.write_mass to false.
      POST%WRITE_FORCE = .FALSE.                                         ! Set the flag post.write_force to false.
      POST%WRITE_UNKNOWN = .FALSE.                                       ! Set the flag post.write_unknown to false.
      POST%WRITE_ENERGY = .FALSE.                                        ! Set the flag post.write_energy to false.

      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_POSTPROCESSING_FILE',               ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) COUNT                      ! If ios = 0, read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 0_I4) THEN                          ! If ios /= 0 or count < 0:
        CALL SET_ERROR(STATUS, 'READ_POSTPROCESSING_FILE',               ! Record an error in status: 'INVALID NUMBER OF POST-PROCESSING RECORDS'.
     &                 'INVALID NUMBER OF POST-PROCESSING RECORDS')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(FIELD(MAX(COUNT,1_I4)))                                   ! Allocate memory for field(max(count,1)).
      ALLOCATE(POINT(MAX(COUNT,1_I4)))                                   ! Allocate memory for point(max(count,1)).
      N_FIELD = 0_I4                                                     ! Set n_field to zero.
      N_POINT = 0_I4                                                     ! Set n_point to zero.

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
!         THE BASELINE SILENTLY IGNORES MISSING TRAILING RECORDS.
          CALL SET_WARNING(STATUS, 'READ_POSTPROCESSING_FILE',           ! Record a warning in status: 'FEWER RECORDS THAN DECLARED: THE REST IS IGNORED'.
     &      'FEWER RECORDS THAN DECLARED: THE REST IS IGNORED')
          EXIT                                                           ! Leave the loop.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) KEYWORD                                  ! Read from the text line into keyword.
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        SELECT CASE(TRIM(KEYWORD))                                       ! Choose according to the value of trim(keyword):
        CASE('PARA','GMSH')                                              ! Case 'PARA','GMSH':
          READ(LINE,*,IOSTAT=IOS) KEYWORD, CELL_NODES,                   ! Read from the text line into keyword, cell_nodes, frame_token, split.
     &                            FRAME_TOKEN, SPLIT
          CALL UPPERCASE(FRAME_TOKEN)                                    ! Call uppercase with frame_token.
          IF (IOS .NE. 0 .OR. MINVAL(SPLIT) .LT. 1_I4 .OR.               ! If ios /= 0 or minval(split) < 1 or (cell_nodes /= 8 and cell_nodes /= 20 and cell_nodes /= 27):
     &        (CELL_NODES .NE. 8_I4 .AND. CELL_NODES .NE. 20_I4
     &        .AND. CELL_NODES .NE. 27_I4)) THEN
            CALL SET_ERROR(STATUS, 'READ_POSTPROCESSING_FILE',           ! Record an error in status: 'INVALID PARA/GMSH RECORD'.
     &                     'INVALID PARA/GMSH RECORD')
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          N_FIELD = N_FIELD + 1_I4                                       ! Add 1 to n_field.
          FIELD(N_FIELD)%CELL_NODES = CELL_NODES                         ! Set field(n_field).cell_nodes to cell_nodes.
          FIELD(N_FIELD)%SPLIT = SPLIT                                   ! Set field(n_field).split to split.
          FIELD(N_FIELD)%FORMAT = POST_FORMAT_PARAVIEW                   ! Set field(n_field).format to post_format_paraview.
          IF (TRIM(KEYWORD) .EQ. 'GMSH')                                 ! If trim(keyword) = 'GMSH', set field(n_field).format to post_format_gmsh.
     &      FIELD(N_FIELD)%FORMAT = POST_FORMAT_GMSH
          SELECT CASE(TRIM(FRAME_TOKEN))                                 ! Choose according to the value of trim(frame_token):
          CASE('LOC')                                                    ! Case 'LOC':
            FIELD(N_FIELD)%FRAME = POST_FRAME_LOCAL                      ! Set field(n_field).frame to post_frame_local.
          CASE('GLB')                                                    ! Case 'GLB':
            FIELD(N_FIELD)%FRAME = POST_FRAME_GLOBAL                     ! Set field(n_field).frame to post_frame_global.
          CASE DEFAULT                                                   ! In every other case:
            CALL SET_ERROR(STATUS, 'READ_POSTPROCESSING_FILE',           ! Record an error in status: 'REFERENCE MUST BE LOC OR GLB'.
     &        'REFERENCE MUST BE LOC OR GLB')
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END SELECT                                                     ! End of the case selection.
        CASE('PNT')                                                      ! Case 'PNT':
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, COORDINATE                ! Read from the text line into keyword, id, coordinate.
          IF (IOS .NE. 0 .OR. ID .LT. 1_I4) THEN                         ! If ios /= 0 or id < 1:
            CALL SET_ERROR(STATUS, 'READ_POSTPROCESSING_FILE',           ! Record an error in status: 'INVALID PNT RECORD'.
     &                     'INVALID PNT RECORD')
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          N_POINT = N_POINT + 1_I4                                       ! Add 1 to n_point.
          POINT(N_POINT)%ID = ID                                         ! Set point(n_point).id to id.
          POINT(N_POINT)%COORDINATE = COORDINATE                         ! Set point(n_point).coordinate to coordinate.
        CASE('KMAT')                                                     ! Case 'KMAT':
          POST%WRITE_STIFFNESS = .TRUE.                                  ! Set the flag post.write_stiffness to true.
        CASE('MMAT')                                                     ! Case 'MMAT':
          POST%WRITE_MASS = .TRUE.                                       ! Set the flag post.write_mass to true.
        CASE('FRCE')                                                     ! Case 'FRCE':
          POST%WRITE_FORCE = .TRUE.                                      ! Set the flag post.write_force to true.
        CASE('UNKN')                                                     ! Case 'UNKN':
          POST%WRITE_UNKNOWN = .TRUE.                                    ! Set the flag post.write_unknown to true.
        CASE('ENRG')                                                     ! Case 'ENRG':
          POST%WRITE_ENERGY = .TRUE.                                     ! Set the flag post.write_energy to true.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_WARNING(STATUS, 'READ_POSTPROCESSING_FILE',           ! Record a warning in status: 'IGNORED POST-PROCESSING RECORD: '//trim(keyword).
     &      'IGNORED POST-PROCESSING RECORD: '//TRIM(KEYWORD))
        END SELECT                                                       ! End of the case selection.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      ALLOCATE(POST%FIELD(N_FIELD))                                      ! Allocate memory for post.field(n_field).
      ALLOCATE(POST%POINT(N_POINT))                                      ! Allocate memory for post.point(n_point).
      IF (N_FIELD .GT. 0_I4) POST%FIELD = FIELD(1:N_FIELD)               ! If n_field > 0, set post.field to field(1:n_field).
      IF (N_POINT .GT. 0_I4) POST%POINT = POINT(1:N_POINT)               ! If n_point > 0, set post.point to point(1:n_point).

      END SUBROUTINE READ_POSTPROCESSING_FILE                            ! End of the subroutine read postprocessing file.

      END MODULE MUL2_READ_ANALYSIS                                      ! End of the module mul2 read analysis.
