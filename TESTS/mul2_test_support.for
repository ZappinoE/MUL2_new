!=======================================================================
!  SUPPORT FOR THE END-TO-END TESTS: RUN THE EXECUTABLE IN AN ISOLATED
!  DIRECTORY AND READ ITS NUMERIC OUTPUT BACK.
!=======================================================================
      MODULE MUL2_TEST_SUPPORT                                           ! Module mul2 test support begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_FILES, ONLY: IS_WINDOWS                                   ! Use from module mul2 files: is windows.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: RUN_SOLVER                                               ! Export: run solver.
      PUBLIC :: READ_POINT_ROWS                                          ! Export: read point rows.
      PUBLIC :: READ_FREQUENCIES                                         ! Export: read frequencies.
      PUBLIC :: READ_VTK_BLOCK                                           ! Export: read vtk block.
      PUBLIC :: MAX_RELATIVE_DIFFERENCE                                  ! Export: max relative difference.
      PUBLIC :: FILES_ARE_IDENTICAL                                      ! Export: files are identical.

      CONTAINS                                                           ! The procedures of the module follow.

!  RUN `EXE INPUT_DIRECTORY` WITH RUN_DIRECTORY AS WORKING DIRECTORY.
!  THREADS > 0 SETS OMP_NUM_THREADS FOR THIS RUN.
      SUBROUTINE RUN_SOLVER(EXE, INPUT_DIRECTORY, RUN_DIRECTORY,         ! Subroutine run solver takes exe, input directory, run directory, threads, ok.
     &                      THREADS, OK)

      CHARACTER(LEN=*), INTENT(IN) :: EXE                                ! Input character (length *): exe.
      CHARACTER(LEN=*), INTENT(IN) :: INPUT_DIRECTORY                    ! Input character (length *): input_directory.
      CHARACTER(LEN=*), INTENT(IN) :: RUN_DIRECTORY                      ! Input character (length *): run_directory.
      INTEGER(I4), INTENT(IN) :: THREADS                                 ! Input integer (int32): threads.
      LOGICAL, INTENT(OUT) :: OK                                         ! Output logical: ok.
      CHARACTER(LEN=1024) :: COMMAND                                     ! Character (length 1024): command.
      CHARACTER(LEN=16) :: NUMBER                                        ! Character (length 16): number.
      INTEGER :: EXIT_STATUS                                             ! Integer: exit_status.
      INTEGER :: COMMAND_STATUS                                          ! Integer: command_status.

      WRITE(NUMBER,'(I0)') THREADS                                       ! Format into the text number: threads.
      IF (IS_WINDOWS()) THEN                                             ! If is_windows():
        CALL EXECUTE_COMMAND_LINE('if not exist "'//TRIM(RUN_DIRECTORY)  ! Call execute command line with 'if not exist "'//trim(run_directory) //'" mkdir "'//trim(run_directory)//'"'.
     &       //'" mkdir "'//TRIM(RUN_DIRECTORY)//'"')
        COMMAND = 'cd /d "'//TRIM(RUN_DIRECTORY)//'" && '                ! Set command to 'cd /d "'//trim(run_directory)//'" && '.
        IF (THREADS .GT. 0_I4) COMMAND = TRIM(COMMAND)//                 ! If threads > 0, set command to trim(command)// 'set OMP_NUM_THREADS='//trim(number)//'&& '.
     &    'set OMP_NUM_THREADS='//TRIM(NUMBER)//'&& '
        COMMAND = TRIM(COMMAND)//'"'//TRIM(EXE)//'" "'//                 ! Set command to trim(command)//'"'//trim(exe)//'" "'// trim(input_directory)//'" > console.log 2> error.log'.
     &            TRIM(INPUT_DIRECTORY)//'" > console.log 2> error.log'
      ELSE                                                               ! Otherwise:
        CALL EXECUTE_COMMAND_LINE('mkdir -p "'//TRIM(RUN_DIRECTORY)//    ! Call execute command line with 'mkdir -p "'//trim(run_directory)// '"'.
     &                            '"')
        COMMAND = 'cd "'//TRIM(RUN_DIRECTORY)//'" && '                   ! Set command to 'cd "'//trim(run_directory)//'" && '.
        IF (THREADS .GT. 0_I4) COMMAND = TRIM(COMMAND)//                 ! If threads > 0, set command to trim(command)// 'OMP_NUM_THREADS='//trim(number)//' '.
     &    'OMP_NUM_THREADS='//TRIM(NUMBER)//' '
        COMMAND = TRIM(COMMAND)//'"'//TRIM(EXE)//'" "'//                 ! Set command to trim(command)//'"'//trim(exe)//'" "'// trim(input_directory)//'" > console.log 2> error.log'.
     &            TRIM(INPUT_DIRECTORY)//'" > console.log 2> error.log'
      END IF                                                             ! End of the IF block.
      EXIT_STATUS = -1                                                   ! Set exit_status to -1.
      CALL EXECUTE_COMMAND_LINE(TRIM(COMMAND), WAIT=.TRUE.,              ! Call execute command line with trim(command), wait=true, exitstat=exit_status, cmdstat=command_status.
     &     EXITSTAT=EXIT_STATUS, CMDSTAT=COMMAND_STATUS)
      OK = COMMAND_STATUS .EQ. 0 .AND. EXIT_STATUS .EQ. 0                ! Set ok to command_status = 0 and exit_status = 0.

      END SUBROUTINE RUN_SOLVER                                          ! End of the subroutine run solver.

!  ROWS OF POST_POINT.dat: 46 NUMBERS PER ROW (HEADER SKIPPED).
      SUBROUTINE READ_POINT_ROWS(FILE_NAME, ROWS, COUNT, OK)             ! Subroutine read point rows takes file name, rows, count, ok.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      REAL(R8), INTENT(OUT) :: ROWS(:,:)                                 ! Output real (real64): rows(:,:).
      INTEGER(I4), INTENT(OUT) :: COUNT                                  ! Output integer (int32): count.
      LOGICAL, INTENT(OUT) :: OK                                         ! Output logical: ok.
      CHARACTER(LEN=2048) :: LINE                                        ! Character (length 2048): line.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      OK = .FALSE.                                                       ! Set the flag ok to false.
      COUNT = 0_I4                                                       ! Set count to zero.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ',    ! Open the file file_name.
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) RETURN                                             ! If ios /= 0, return to the caller.
      READ(UNIT,'(A)',IOSTAT=IOS) LINE                                   ! Read from unit unit into line.
      DO                                                                 ! Loop until an EXIT statement is reached:
        READ(UNIT,'(A)',IOSTAT=IOS) LINE                                 ! Read from unit unit into line.
        IF (IOS .NE. 0) EXIT                                             ! If ios /= 0, leave the loop.
        IF (LEN_TRIM(LINE) .EQ. 0) CYCLE                                 ! If len_trim(line) = 0, skip to the next iteration.
        IF (COUNT .GE. SIZE(ROWS,2)) EXIT                                ! If count >= size(rows,2), leave the loop.
        COUNT = COUNT + 1_I4                                             ! Add 1 to count.
        READ(LINE,*,IOSTAT=IOS) ROWS(1:SIZE(ROWS,1),COUNT)               ! Read from the text line into rows(1:size(rows,1),count).
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.
      OK = COUNT .GT. 0_I4                                               ! Set ok to count > 0.

      END SUBROUTINE READ_POINT_ROWS                                     ! End of the subroutine read point rows.

!  FREQUENCIES.dat: `Frequency  N:   VALUE`.
      SUBROUTINE READ_FREQUENCIES(FILE_NAME, VALUE, COUNT, OK)           ! Subroutine read frequencies takes file name, value, count, ok.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      REAL(R8), INTENT(OUT) :: VALUE(:)                                  ! Output real (real64): value(:).
      INTEGER(I4), INTENT(OUT) :: COUNT                                  ! Output integer (int32): count.
      LOGICAL, INTENT(OUT) :: OK                                         ! Output logical: ok.
      CHARACTER(LEN=256) :: LINE                                         ! Character (length 256): line.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER :: COLON                                                   ! Integer: colon.

      OK = .FALSE.                                                       ! Set the flag ok to false.
      COUNT = 0_I4                                                       ! Set count to zero.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ',    ! Open the file file_name.
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) RETURN                                             ! If ios /= 0, return to the caller.
      DO                                                                 ! Loop until an EXIT statement is reached:
        READ(UNIT,'(A)',IOSTAT=IOS) LINE                                 ! Read from unit unit into line.
        IF (IOS .NE. 0) EXIT                                             ! If ios /= 0, leave the loop.
        COLON = INDEX(LINE,':')                                          ! Set colon to index(line,':').
        IF (COLON .EQ. 0 .OR. COUNT .GE. SIZE(VALUE)) CYCLE              ! If colon = 0 or count >= size(value), skip to the next iteration.
        COUNT = COUNT + 1_I4                                             ! Add 1 to count.
        READ(LINE(COLON+1:),*,IOSTAT=IOS) VALUE(COUNT)                   ! Read from unit line(colon+1:) into value(count).
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.
      OK = COUNT .GT. 0_I4                                               ! Set ok to count > 0.

      END SUBROUTINE READ_FREQUENCIES                                    ! End of the subroutine read frequencies.

!  POINT DATA BLOCK OF A LEGACY ASCII VTK FILE. THE BLOCK IS THE FIRST
!  `VECTORS` OR `SCALARS` HEADER CONTAINING NAME. DATA(NCOMP,N).
      SUBROUTINE READ_VTK_BLOCK(FILE_NAME, NAME, NCOMP, DATA, N, OK)     ! Subroutine read vtk block takes file name, name, ncomp, data, n, ok.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      INTEGER(I4), INTENT(IN) :: NCOMP                                   ! Input integer (int32): ncomp.
      REAL(R8), ALLOCATABLE, INTENT(OUT) :: DATA(:,:)                    ! Allocatable output real (real64): data(:,:).
      INTEGER(I4), INTENT(OUT) :: N                                      ! Output integer (int32): n.
      LOGICAL, INTENT(OUT) :: OK                                         ! Output logical: ok.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      CHARACTER(LEN=512) :: TRIMMED                                      ! Character (length 512): trimmed.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      OK = .FALSE.                                                       ! Set the flag ok to false.
      N = 0_I4                                                           ! Set n to zero.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ',    ! Open the file file_name.
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) RETURN                                             ! If ios /= 0, return to the caller.
      DO                                                                 ! Loop until an EXIT statement is reached:
        READ(UNIT,'(A)',IOSTAT=IOS) LINE                                 ! Read from unit unit into line.
        IF (IOS .NE. 0) EXIT                                             ! If ios /= 0, leave the loop.
        TRIMMED = ADJUSTL(LINE)                                          ! Set trimmed to adjustl(line).
        IF (TRIMMED(1:6) .EQ. 'POINTS') THEN                             ! If trimmed(1:6) = 'POINTS':
          READ(TRIMMED(7:),*,IOSTAT=IOS) N                               ! Read from unit trimmed(7:) into n.
          CYCLE                                                          ! Skip to the next iteration.
        END IF                                                           ! End of the IF block.
        IF (N .EQ. 0_I4) CYCLE                                           ! If n = 0, skip to the next iteration.
        IF (TRIMMED(1:7) .NE. 'VECTORS' .AND.                            ! If trimmed(1:7) /= 'VECTORS' and trimmed(1:7) /= 'SCALARS', skip to the next iteration.
     &      TRIMMED(1:7) .NE. 'SCALARS') CYCLE
        IF (INDEX(TRIMMED,NAME) .EQ. 0) CYCLE                            ! If index(trimmed,name) = 0, skip to the next iteration.
        IF (TRIMMED(1:7) .EQ. 'SCALARS')                                 ! If trimmed(1:7) = 'SCALARS', read from unit unit into line.
     &    READ(UNIT,'(A)',IOSTAT=IOS) LINE
        ALLOCATE(DATA(NCOMP,N))                                          ! Allocate memory for data(ncomp,n).
        DO I = 1_I4, N                                                   ! Loop i from 1 to n:
          READ(UNIT,*,IOSTAT=IOS) DATA(:,I)                              ! Read from unit unit into data(:,i).
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        OK = .TRUE.                                                      ! Set the flag ok to true.
        EXIT                                                             ! Leave the loop.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_VTK_BLOCK                                      ! End of the subroutine read vtk block.

!  MAX |A-B| / MAX(MAX|B|, TINY).
      REAL(R8) FUNCTION MAX_RELATIVE_DIFFERENCE(A, B)                    ! Function max relative difference takes a, b.

      REAL(R8), INTENT(IN) :: A(:)                                       ! Input real (real64): a(:).
      REAL(R8), INTENT(IN) :: B(:)                                       ! Input real (real64): b(:).

      MAX_RELATIVE_DIFFERENCE = MAXVAL(ABS(A-B))/                        ! Set max_relative_difference to maxval(abs(a-b))/ max(maxval(abs(b)),tiny(1.0)).
     &                          MAX(MAXVAL(ABS(B)),TINY(1.0_R8))

      END FUNCTION MAX_RELATIVE_DIFFERENCE                               ! End of the function max relative difference.

!  TEXT COMPARISON LINE BY LINE.
      LOGICAL FUNCTION FILES_ARE_IDENTICAL(FILE_A, FILE_B)               ! Function files are identical takes file a, file b.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_A                             ! Input character (length *): file_a.
      CHARACTER(LEN=*), INTENT(IN) :: FILE_B                             ! Input character (length *): file_b.
      CHARACTER(LEN=2048) :: LINE_A                                      ! Character (length 2048): line_a.
      CHARACTER(LEN=2048) :: LINE_B                                      ! Character (length 2048): line_b.
      INTEGER :: UNIT_A                                                  ! Integer: unit_a.
      INTEGER :: UNIT_B                                                  ! Integer: unit_b.
      INTEGER :: IOS_A                                                   ! Integer: ios_a.
      INTEGER :: IOS_B                                                   ! Integer: ios_b.

      FILES_ARE_IDENTICAL = .FALSE.                                      ! Set the flag files_are_identical to false.
      OPEN(NEWUNIT=UNIT_A, FILE=FILE_A, STATUS='OLD', ACTION='READ',     ! Open the file file_a.
     &     IOSTAT=IOS_A)
      OPEN(NEWUNIT=UNIT_B, FILE=FILE_B, STATUS='OLD', ACTION='READ',     ! Open the file file_b.
     &     IOSTAT=IOS_B)
      IF (IOS_A .NE. 0 .OR. IOS_B .NE. 0) RETURN                         ! If ios_a /= 0 or ios_b /= 0, return to the caller.
      DO                                                                 ! Loop until an EXIT statement is reached:
        READ(UNIT_A,'(A)',IOSTAT=IOS_A) LINE_A                           ! Read from unit unit_a into line_a.
        READ(UNIT_B,'(A)',IOSTAT=IOS_B) LINE_B                           ! Read from unit unit_b into line_b.
        IF (IOS_A .NE. IOS_B) EXIT                                       ! If ios_a /= ios_b, leave the loop.
        IF (IOS_A .NE. 0) THEN                                           ! If ios_a /= 0:
          FILES_ARE_IDENTICAL = .TRUE.                                   ! Set the flag files_are_identical to true.
          EXIT                                                           ! Leave the loop.
        END IF                                                           ! End of the IF block.
        IF (LINE_A .NE. LINE_B) EXIT                                     ! If line_a /= line_b, leave the loop.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT_A)                                                      ! Close the file.
      CLOSE(UNIT_B)                                                      ! Close the file.

      END FUNCTION FILES_ARE_IDENTICAL                                   ! End of the function files are identical.

      END MODULE MUL2_TEST_SUPPORT                                       ! End of the module mul2 test support.
