!=======================================================================
!  READER OF TIME_RESP.DAT (SEE MUL2_TIME_INPUT FOR THE FORMAT).
!=======================================================================
      MODULE MUL2_READ_TIME                                              ! Module mul2 read time begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_TIME_INPUT                                                ! Use everything exported by module mul2 time input.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_TIME_FILE                                           ! Export: read time file.
      PUBLIC :: READ_FREQ_FILE                                           ! Export: read freq file.
      PUBLIC :: READ_NL_FILE                                             ! Export: read nl file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_TIME_FILE(FILE_NAME, TIME, STATUS)                 ! Subroutine read time file takes file name, time, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(TIME_INPUT_TYPE), INTENT(OUT) :: TIME                         ! Output of type time_input_type: time.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: KEYWORD                                       ! Character (length 16): keyword.
      REAL(R8) :: VALUE(8)                                               ! Real (real64): value(8).
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: N_SPECIFIC                                          ! Integer (int32): n_specific.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ',    ! Open the file file_name.
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                         ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA(LINE, IOS)                                          ! Call next data with line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) TIME%INITIAL_TIME,         ! If ios = 0, read from the text line into time.initial_time, time.final_time.
     &                                        TIME%FINAL_TIME
      IF (IOS .EQ. 0) CALL NEXT_DATA(LINE, IOS)                          ! If ios = 0, call next data with line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) TIME%STEP_COUNT            ! If ios = 0, read from the text line into time.step_count.
      IF (IOS .EQ. 0) CALL NEXT_DATA(LINE, IOS)                          ! If ios = 0, call next data with line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) TIME%POST_EVERY            ! If ios = 0, read from the text line into time.post_every.
      IF (IOS .EQ. 0) CALL NEXT_DATA(LINE, IOS)                          ! If ios = 0, call next data with line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) N_SPECIFIC                 ! If ios = 0, read from the text line into n_specific.
      IF (IOS .NE. 0 .OR. TIME%STEP_COUNT .LT. 1_I4 .OR.                 ! If ios /= 0 or time.step_count < 1 or time.final_time <= time.initial_time or time.post_every < 1 or n_spec...
     &    TIME%FINAL_TIME .LE. TIME%INITIAL_TIME .OR.
     &    TIME%POST_EVERY .LT. 1_I4 .OR. N_SPECIFIC .LT. 0_I4) THEN
        CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                         ! Record an error in status: 'INVALID TIME HEADER (TI TF / NSTEP / POST_EVERY / N)'.
     &    'INVALID TIME HEADER (TI TF / NSTEP / POST_EVERY / N)')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(TIME%SPECIFIC_STEP(N_SPECIFIC))                           ! Allocate memory for time.specific_step(n_specific).
      DO I = 1_I4, N_SPECIFIC                                            ! Loop i from 1 to n_specific:
        CALL NEXT_DATA(LINE, IOS)                                        ! Call next data with line, ios.
        IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) TIME%SPECIFIC_STEP(I)    ! If ios = 0, read from the text line into time.specific_step(i).
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                       ! Record an error in status: 'INVALID SPECIFIC OUTPUT STEP'.
     &                   'INVALID SPECIFIC OUTPUT STEP')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL NEXT_DATA(LINE, IOS)                                          ! Call next data with line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) COUNT                      ! If ios = 0, read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 0_I4) THEN                          ! If ios /= 0 or count < 0:
        CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                         ! Record an error in status: 'INVALID NUMBER OF TIME LOADS'.
     &                 'INVALID NUMBER OF TIME LOADS')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(TIME%LOAD(COUNT))                                         ! Allocate memory for time.load(count).
      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA(LINE, IOS)                                        ! Call next data with line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                       ! Record an error in status: 'TIME LOAD RECORDS ARE MISSING'.
     &                   'TIME LOAD RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) KEYWORD                                  ! Read from the text line into keyword.
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        VALUE = 0.0_R8                                                   ! Set value to zero.
        SELECT CASE (TRIM(KEYWORD))                                      ! Choose according to the value of trim(keyword):
        CASE ('STEP')                                                    ! Case 'STEP':
          TIME%LOAD(I)%KIND = LOAD_STEP                                  ! Set time.load(i).kind to load_step.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, VALUE(1:2)                    ! Read from the text line into keyword, value(1:2).
        CASE ('IMPU')                                                    ! Case 'IMPU':
          TIME%LOAD(I)%KIND = LOAD_IMPULSE                               ! Set time.load(i).kind to load_impulse.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, VALUE(1:2)                    ! Read from the text line into keyword, value(1:2).
        CASE ('RAMP')                                                    ! Case 'RAMP':
          TIME%LOAD(I)%KIND = LOAD_RAMP                                  ! Set time.load(i).kind to load_ramp.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, VALUE(1:3)                    ! Read from the text line into keyword, value(1:3).
        CASE ('SINU')                                                    ! Case 'SINU':
          TIME%LOAD(I)%KIND = LOAD_SINE                                  ! Set time.load(i).kind to load_sine.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, VALUE(1:3)                    ! Read from the text line into keyword, value(1:3).
        CASE ('HASU')                                                    ! Case 'HASU':
          TIME%LOAD(I)%KIND = LOAD_HANN_SINE                             ! Set time.load(i).kind to load_hann_sine.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, VALUE(1:6)                    ! Read from the text line into keyword, value(1:6).
        CASE ('HACU')                                                    ! Case 'HACU':
          TIME%LOAD(I)%KIND = LOAD_HANN_COSINE                           ! Set time.load(i).kind to load_hann_cosine.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, VALUE(1:6)                    ! Read from the text line into keyword, value(1:6).
        CASE ('WPSU')                                                    ! Case 'WPSU':
          TIME%LOAD(I)%KIND = LOAD_WINDOWED_SINE                         ! Set time.load(i).kind to load_windowed_sine.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, VALUE(1:6)                    ! Read from the text line into keyword, value(1:6).
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                       ! Record an error in status: 'UNKNOWN TIME LOAD: '//trim(keyword).
     &                   'UNKNOWN TIME LOAD: '//TRIM(KEYWORD))
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END SELECT                                                       ! End of the case selection.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                       ! Record an error in status: 'WRONG NUMBER OF VALUES IN THE '//trim(keyword)//' LOAD'.
     &      'WRONG NUMBER OF VALUES IN THE '//TRIM(KEYWORD)//' LOAD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        TIME%LOAD(I)%ARG = VALUE                                         ! Set time.load(i).arg to value.
      END DO                                                             ! End of the loop.
!     OPTIONAL INTEGRATION PARAMETERS.
      DO                                                                 ! Loop until an EXIT statement is reached:
        CALL NEXT_DATA(LINE, IOS)                                        ! Call next data with line, ios.
        IF (IOS .NE. 0) EXIT                                             ! If ios /= 0, leave the loop.
        READ(LINE,*,IOSTAT=IOS) KEYWORD                                  ! Read from the text line into keyword.
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        SELECT CASE (TRIM(KEYWORD))                                      ! Choose according to the value of trim(keyword):
        CASE ('NEWMARK')                                                 ! Case 'NEWMARK':
          READ(LINE,*,IOSTAT=IOS) KEYWORD, TIME%NEWMARK_BETA,            ! Read from the text line into keyword, time.newmark_beta, time.newmark_gamma.
     &                            TIME%NEWMARK_GAMMA
        CASE ('RAYLEIGH')                                                ! Case 'RAYLEIGH':
          READ(LINE,*,IOSTAT=IOS) KEYWORD, TIME%RAYLEIGH_MASS,           ! Read from the text line into keyword, time.rayleigh_mass, time.rayleigh_stiffness.
     &                            TIME%RAYLEIGH_STIFFNESS
          TIME%HAS_RAYLEIGH = .TRUE.                                     ! Set the flag time.has_rayleigh to true.
        CASE ('THETA')                                                   ! Case 'THETA':
          READ(LINE,*,IOSTAT=IOS) KEYWORD, TIME%THETA                    ! Read from the text line into keyword, time.theta.
        CASE ('T0')                                                      ! Case 'T0':
          READ(LINE,*,IOSTAT=IOS) KEYWORD, TIME%REFERENCE_TEMPERATURE    ! Read from the text line into keyword, time.reference_temperature.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                       ! Record an error in status: 'UNKNOWN TIME RECORD: '//trim(keyword).
     &                   'UNKNOWN TIME RECORD: '//TRIM(KEYWORD))
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END SELECT                                                       ! End of the case selection.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                       ! Record an error in status: 'INVALID '//trim(keyword)//' RECORD'.
     &                   'INVALID '//TRIM(KEYWORD)//' RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.
      IF (TIME%NEWMARK_BETA .LE. 0.0_R8 .OR. TIME%NEWMARK_GAMMA .LT.     ! If time.newmark_beta <= 0.0 or time.newmark_gamma < 0.5 or time.theta < 0.5 or time.theta > 1.0:
     &    0.5_R8 .OR. TIME%THETA .LT. 0.5_R8 .OR. TIME%THETA .GT.
     &    1.0_R8) THEN
        CALL SET_ERROR(STATUS, 'READ_TIME_FILE',                         ! Record an error in status: 'NEWMARK NEEDS BETA > 0 AND GAMMA >= 1/2; THETA IN [1/2,1]'.
     &    'NEWMARK NEEDS BETA > 0 AND GAMMA >= 1/2; THETA IN [1/2,1]')
      END IF                                                             ! End of the IF block.

      CONTAINS                                                           ! The procedures of the module follow.

!  NEXT RECORD, SKIPPING COMMENTS AND THE DASHED SEPARATORS OF THE
!  HISTORICAL FILES.
      SUBROUTINE NEXT_DATA(TEXT, STAT)                                   ! Subroutine next data takes text, stat.

      CHARACTER(LEN=*), INTENT(OUT) :: TEXT                              ! Output character (length *): text.
      INTEGER, INTENT(OUT) :: STAT                                       ! Output integer: stat.

      DO                                                                 ! Loop until an EXIT statement is reached:
        CALL NEXT_DATA_LINE(UNIT, TEXT, STAT)                            ! Call next data line with unit, text, stat.
        IF (STAT .NE. 0) RETURN                                          ! If stat /= 0, return to the caller.
        IF (TEXT(1:2) .NE. '--') RETURN                                  ! If text(1:2) /= '--', return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE NEXT_DATA                                           ! End of the subroutine next data.

      END SUBROUTINE READ_TIME_FILE                                      ! End of the subroutine read time file.

!  FREQ_RESP.DAT.
      SUBROUTINE READ_FREQ_FILE(FILE_NAME, FREQ, STATUS)                 ! Subroutine read freq file takes file name, freq, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(FREQ_INPUT_TYPE), INTENT(OUT) :: FREQ                         ! Output of type freq_input_type: freq.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=16) :: KEYWORD                                       ! Character (length 16): keyword.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ',    ! Open the file file_name.
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_FREQ_FILE',                         ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) FREQ%FIRST_FREQUENCY,      ! If ios = 0, read from the text line into freq.first_frequency, freq.last_frequency.
     &                                        FREQ%LAST_FREQUENCY
      IF (IOS .EQ. 0) CALL NEXT_DATA_LINE(UNIT, LINE, IOS)               ! If ios = 0, call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) FREQ%STEP_COUNT            ! If ios = 0, read from the text line into freq.step_count.
      IF (IOS .EQ. 0) CALL NEXT_DATA_LINE(UNIT, LINE, IOS)               ! If ios = 0, call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) FREQ%POST_EVERY            ! If ios = 0, read from the text line into freq.post_every.
      IF (IOS .NE. 0 .OR. FREQ%STEP_COUNT .LT. 1_I4 .OR.                 ! If ios /= 0 or freq.step_count < 1 or freq.last_frequency <= freq.first_frequency or freq.post_every < 1:
     &    FREQ%LAST_FREQUENCY .LE. FREQ%FIRST_FREQUENCY .OR.
     &    FREQ%POST_EVERY .LT. 1_I4) THEN
        CALL SET_ERROR(STATUS, 'READ_FREQ_FILE',                         ! Record an error in status: 'INVALID FREQUENCY HEADER (FI FF / NSTEP / POST_EVERY)'.
     &    'INVALID FREQUENCY HEADER (FI FF / NSTEP / POST_EVERY)')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO                                                                 ! Loop until an EXIT statement is reached:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) EXIT                                             ! If ios /= 0, leave the loop.
        READ(LINE,*,IOSTAT=IOS) KEYWORD                                  ! Read from the text line into keyword.
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        SELECT CASE (TRIM(KEYWORD))                                      ! Choose according to the value of trim(keyword):
        CASE ('RAYLEIGH')                                                ! Case 'RAYLEIGH':
          READ(LINE,*,IOSTAT=IOS) KEYWORD, FREQ%RAYLEIGH_MASS,           ! Read from the text line into keyword, freq.rayleigh_mass, freq.rayleigh_stiffness.
     &                            FREQ%RAYLEIGH_STIFFNESS
          FREQ%HAS_RAYLEIGH = .TRUE.                                     ! Set the flag freq.has_rayleigh to true.
        CASE ('T0')                                                      ! Case 'T0':
          READ(LINE,*,IOSTAT=IOS) KEYWORD, FREQ%REFERENCE_TEMPERATURE    ! Read from the text line into keyword, freq.reference_temperature.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'READ_FREQ_FILE',                       ! Record an error in status: 'UNKNOWN FREQUENCY RECORD: '//trim(keyword).
     &                   'UNKNOWN FREQUENCY RECORD: '//TRIM(KEYWORD))
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END SELECT                                                       ! End of the case selection.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_FREQ_FILE',                       ! Record an error in status: 'INVALID '//trim(keyword)//' RECORD'.
     &                   'INVALID '//TRIM(KEYWORD)//' RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_FREQ_FILE                                      ! End of the subroutine read freq file.

!  NL_INFO.DAT: FIVE RECORDS (SOLVTEC 1 = LOAD CONTROL, 2 = ARC
!  LENGTH) AND AN OPTIONAL SIXTH ONE  DS0 DSMIN DSMAX LAMBDA_MAX
!  FOR THE ARC LENGTH. ANYTHING ELSE OF THE HISTORICAL FILE IS UNUSED.
      SUBROUTINE READ_NL_FILE(FILE_NAME, NL, STATUS)                     ! Subroutine read nl file takes file name, nl, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(NL_INPUT_TYPE), INTENT(OUT) :: NL                             ! Output of type nl_input_type: nl.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER :: EXTRA                                                   ! Integer: extra.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ',    ! Open the file file_name.
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_NL_FILE',                           ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) NL%TECHNIQUE               ! If ios = 0, read from the text line into nl.technique.
      IF (IOS .EQ. 0) CALL NEXT_DATA_LINE(UNIT, LINE, IOS)               ! If ios = 0, call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) NL%STEP_COUNT              ! If ios = 0, read from the text line into nl.step_count.
      IF (IOS .EQ. 0) CALL NEXT_DATA_LINE(UNIT, LINE, IOS)               ! If ios = 0, call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) NL%MAX_ITERATIONS          ! If ios = 0, read from the text line into nl.max_iterations.
      IF (IOS .EQ. 0) CALL NEXT_DATA_LINE(UNIT, LINE, IOS)               ! If ios = 0, call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) NL%TOLERANCE               ! If ios = 0, read from the text line into nl.tolerance.
      IF (IOS .EQ. 0) CALL NEXT_DATA_LINE(UNIT, LINE, IOS)               ! If ios = 0, call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) NL%POST_EVERY              ! If ios = 0, read from the text line into nl.post_every.
      IF (IOS .EQ. 0 .AND. NL%TECHNIQUE .EQ. 2_I4) THEN                  ! If ios = 0 and nl.technique = 2:
        CALL NEXT_DATA_LINE(UNIT, LINE, EXTRA)                           ! Call next data line with unit, line, extra.
        IF (EXTRA .EQ. 0) READ(LINE,*,IOSTAT=IOS) NL%ARC_LENGTH,         ! If extra = 0, read from the text line into nl.arc_length, nl.arc_length_min, nl.arc_length_max, nl.lambda_max.
     &    NL%ARC_LENGTH_MIN, NL%ARC_LENGTH_MAX, NL%LAMBDA_MAX
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.
      IF (IOS .EQ. 0 .AND. (NL%TECHNIQUE .LT. 1_I4 .OR.                  ! If ios = 0 and (nl.technique < 1 or nl.technique > 2):
     &    NL%TECHNIQUE .GT. 2_I4)) THEN
        CALL SET_ERROR(STATUS, 'READ_NL_FILE',                           ! Record an error in status: 'SOLVTEC MUST BE 1 (LOAD CONTROL) OR 2 (ARC LENGTH)'.
     &    'SOLVTEC MUST BE 1 (LOAD CONTROL) OR 2 (ARC LENGTH)')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (IOS .NE. 0 .OR. NL%STEP_COUNT .LT. 1_I4 .OR.                   ! If ios /= 0 or nl.step_count < 1 or nl.max_iterations < 1 or nl.tolerance <= 0.0 or nl.post_every < 1:
     &    NL%MAX_ITERATIONS .LT. 1_I4 .OR. NL%TOLERANCE .LE. 0.0_R8
     &    .OR. NL%POST_EVERY .LT. 1_I4) THEN
        CALL SET_ERROR(STATUS, 'READ_NL_FILE',                           ! Record an error in status: 'INVALID NL_INFO.dat (SOLVTEC/NLSTEP/ITMAX/TOLL/POST_EVERY)'.
     &    'INVALID NL_INFO.dat (SOLVTEC/NLSTEP/ITMAX/TOLL/POST_EVERY)')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE READ_NL_FILE                                        ! End of the subroutine read nl file.

      END MODULE MUL2_READ_TIME                                          ! End of the module mul2 read time.
