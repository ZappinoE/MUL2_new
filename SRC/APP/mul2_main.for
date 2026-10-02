!=======================================================================
!  MUL2_V3 EXECUTABLE ENTRY POINT.
!
!      MUL2_V3 [INPUT_DIRECTORY]      (DEFAULT: FIRST LINE OF
!                                      PATH_input.dat, THEN `INPUT`)
!      MUL2_V3 --version
!
!  RESULTS ARE WRITTEN TO THE REPORT, STATIC, DYNAMIC AND WORK
!  DIRECTORIES OF THE WORKING DIRECTORY. THE EXIT CODE IS 0 ON SUCCESS.
!=======================================================================
      PROGRAM MUL2_V3                                                    ! Main program mul2 v3 begins.

      USE MUL2_KINDS, ONLY: R8                                           ! Use from module mul2 kinds: r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, STATUS_IS_OK                   ! Use from module mul2 status: status type, status is ok.
      USE MUL2_LOG, ONLY: LOG_INFO, LOG_ERROR                            ! Use from module mul2 log: log info, log error.
      USE MUL2_RUNTIME, ONLY: INITIALIZE_RUNTIME, FINALIZE_RUNTIME       ! Use from module mul2 runtime: initialize runtime, finalize runtime.
      USE MUL2_TIMER, ONLY: TIMER_TYPE, TIMER_START, TIMER_STOP,         ! Use from module mul2 timer: timer type, timer start, timer stop, timer cpu seconds, timer wall seconds.
     &                      TIMER_CPU_SECONDS, TIMER_WALL_SECONDS
      USE MUL2_DRIVER, ONLY: RUN_MUL2                                    ! Use from module mul2 driver: run mul2.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.

      TYPE(TIMER_TYPE) :: RUN_TIMER                                      ! Of type timer_type: run_timer.
      TYPE(STATUS_TYPE) :: STATUS                                        ! Of type status_type: status.
      CHARACTER(LEN=512) :: INPUT_PATH                                   ! Character (length 512): input_path.
      CHARACTER(LEN=128) :: MESSAGE                                      ! Character (length 128): message.
      REAL(R8) :: CPU_SECONDS                                            ! Real (real64): cpu_seconds.
      REAL(R8) :: WALL_SECONDS                                           ! Real (real64): wall_seconds.
      INTEGER :: ARGUMENT_LENGTH                                         ! Integer: argument_length.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      INPUT_PATH = ' '                                                   ! Set input_path to ' '.
      IF (COMMAND_ARGUMENT_COUNT() .GE. 1) THEN                          ! If command_argument_count() >= 1:
        CALL GET_COMMAND_ARGUMENT(1, INPUT_PATH, ARGUMENT_LENGTH)        ! Call get command argument with 1, input_path, argument_length.
        IF (TRIM(INPUT_PATH) .EQ. '--version' .OR.                       ! If trim(input_path) = '--version' or trim(input_path) = '-v':
     &      TRIM(INPUT_PATH) .EQ. '-v') THEN
          WRITE(*,'(A)') 'MUL2_V3 3.0.0 - LINEAR STATIC (101) AND '//    ! Print: 'MUL2_V3 3.0.0 - LINEAR STATIC (101) AND '// 'MODAL (103) CUF ANALYSIS'.
     &                   'MODAL (103) CUF ANALYSIS'
          STOP 0                                                         ! Stop the program.
        END IF                                                           ! End of the IF block.
      ELSE                                                               ! Otherwise:
        OPEN(NEWUNIT=UNIT, FILE='PATH_input.dat', STATUS='OLD',          ! Open the file 'PATH_input.dat'.
     &       ACTION='READ', IOSTAT=IOS)
        IF (IOS .EQ. 0) THEN                                             ! If ios = 0:
          READ(UNIT,'(A)',IOSTAT=IOS) INPUT_PATH                         ! Read from unit unit into input_path.
          CLOSE(UNIT)                                                    ! Close the file.
        END IF                                                           ! End of the IF block.
        IF (IOS .NE. 0 .OR. LEN_TRIM(INPUT_PATH) .EQ. 0)                 ! If ios /= 0 or len_trim(input_path) = 0, set input_path to 'INPUT'.
     &    INPUT_PATH = 'INPUT'
      END IF                                                             ! End of the IF block.
      INPUT_PATH = ADJUSTL(INPUT_PATH)                                   ! Set input_path to adjustl(input_path).

      CALL INITIALIZE_RUNTIME()                                          ! Call initialize runtime.
      CALL TIMER_START(RUN_TIMER, 'TOTAL')                               ! Call timer start with run_timer, 'TOTAL'.
      CALL LOG_INFO('INPUT DIRECTORY: '//TRIM(INPUT_PATH))               ! Log: 'INPUT DIRECTORY: '//trim(input_path).

      CALL RUN_MUL2(TRIM(INPUT_PATH), STATUS)                            ! Call run mul2 with trim(input_path), status.

      CALL TIMER_STOP(RUN_TIMER)                                         ! Call timer stop with run_timer.
      CPU_SECONDS = TIMER_CPU_SECONDS(RUN_TIMER)                         ! Set cpu_seconds to timer_cpu_seconds(run_timer).
      WALL_SECONDS = TIMER_WALL_SECONDS(RUN_TIMER)                       ! Set wall_seconds to timer_wall_seconds(run_timer).
      WRITE(MESSAGE,'(A,F12.6,A,F12.6)')                                 ! Format into the text message: 'CPU [S]: ', cpu_seconds, ' WALL [S]: ', wall_seconds.
     &      'CPU [S]: ', CPU_SECONDS, '  WALL [S]: ', WALL_SECONDS
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        CALL LOG_ERROR(TRIM(STATUS%SOURCE)//': '//                       ! Call log error with trim(status.source)//': '// trim(status.message).
     &                 TRIM(STATUS%MESSAGE))
        CALL FINALIZE_RUNTIME()                                          ! Call finalize runtime.
        STOP 1                                                           ! Stop the program.
      END IF                                                             ! End of the IF block.
      CALL FINALIZE_RUNTIME()                                            ! Call finalize runtime.

      END PROGRAM MUL2_V3                                                ! End of the program mul2 v3.
