!=======================================================================
!  ENTRY POINT OF THE BUILD WITHOUT MKL: ONLY THE CORE LIBRARY IS
!  AVAILABLE, THERE IS NO LINEAR OR EIGENVALUE SOLVER.
!=======================================================================
      PROGRAM MUL2_V3                                                    ! Main program mul2 v3 begins.

      USE MUL2_LOG, ONLY: LOG_INFO, LOG_ERROR                            ! Use from module mul2 log: log info, log error.
      USE MUL2_RUNTIME, ONLY: INITIALIZE_RUNTIME, FINALIZE_RUNTIME       ! Use from module mul2 runtime: initialize runtime, finalize runtime.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.

      CHARACTER(LEN=64) :: ARGUMENT                                      ! Character (length 64): argument.

      CALL INITIALIZE_RUNTIME()                                          ! Call initialize runtime.
      IF (COMMAND_ARGUMENT_COUNT() .GE. 1) THEN                          ! If command_argument_count() >= 1:
        CALL GET_COMMAND_ARGUMENT(1, ARGUMENT)                           ! Call get command argument with 1, argument.
        IF (TRIM(ARGUMENT) .EQ. '--version') THEN                        ! If trim(argument) = '--version':
          CALL LOG_INFO('MUL2_V3 3.0.0 (CORE BUILD, NO SOLVER)')         ! Log: 'MUL2_V3 3.0.0 (CORE BUILD, NO SOLVER)'.
          CALL FINALIZE_RUNTIME()                                        ! Call finalize runtime.
          STOP 0                                                         ! Stop the program.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      CALL LOG_ERROR('THIS BUILD HAS NO SOLVER: CONFIGURE WITH '//       ! Call log error with 'THIS BUILD HAS NO SOLVER: CONFIGURE WITH '// 'MUL2_ENABLE_MKL=ON'.
     &               'MUL2_ENABLE_MKL=ON')
      CALL FINALIZE_RUNTIME()                                            ! Call finalize runtime.
      STOP 2                                                             ! Stop the program.

      END PROGRAM MUL2_V3                                                ! End of the program mul2 v3.
