!=======================================================================
!  PROCESS-WIDE RUNTIME INITIALIZATION.
!=======================================================================
      MODULE MUL2_RUNTIME                                                ! Module mul2 runtime begins.

      USE MUL2_LOG, ONLY: LOG_INITIALIZE, LOG_INFO, LOG_DEBUG            ! Use from module mul2 log: log initialize, log info, log debug.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: INITIALIZE_RUNTIME                                       ! Export: initialize runtime.
      PUBLIC :: FINALIZE_RUNTIME                                         ! Export: finalize runtime.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE INITIALIZE_RUNTIME()                                    ! Subroutine initialize runtime.

      CHARACTER(LEN=32) :: VALUE                                         ! Character (length 32): value.
      INTEGER :: LENGTH                                                  ! Integer: length.
      INTEGER :: STAT                                                    ! Integer: stat.
      LOGICAL :: DEBUG_ENABLED                                           ! Logical: debug_enabled.

      VALUE = ' '                                                        ! Set value to ' '.
      CALL GET_ENVIRONMENT_VARIABLE('MUL2_DEBUG', VALUE,                 ! Call get environment variable with 'MUL2_DEBUG', value, length, stat.
     &                              LENGTH, STAT)
      DEBUG_ENABLED = .FALSE.                                            ! Set the flag debug_enabled to false.
      IF (STAT .EQ. 0 .AND. LENGTH .GT. 0) THEN                          ! If stat = 0 and length > 0:
        DEBUG_ENABLED = VALUE(1:1) .EQ. '1' .OR.                         ! Set debug_enabled to value(1:1) = '1' or value(1:1) = 'Y' or value(1:1) = 'y'.
     &                  VALUE(1:1) .EQ. 'Y' .OR.
     &                  VALUE(1:1) .EQ. 'y'
      END IF                                                             ! End of the IF block.

      CALL LOG_INITIALIZE(DEBUG_ENABLED)                                 ! Call log initialize with debug_enabled.
      CALL LOG_INFO('MUL2_V3 RUNTIME INITIALIZED')                       ! Log: 'MUL2_V3 RUNTIME INITIALIZED'.
      CALL LOG_DEBUG('DEBUG MODE ENABLED')                               ! Call log debug with 'DEBUG MODE ENABLED'.

      END SUBROUTINE INITIALIZE_RUNTIME                                  ! End of the subroutine initialize runtime.

      SUBROUTINE FINALIZE_RUNTIME()                                      ! Subroutine finalize runtime.

      CALL LOG_INFO('MUL2_V3 RUNTIME FINALIZED')                         ! Log: 'MUL2_V3 RUNTIME FINALIZED'.

      END SUBROUTINE FINALIZE_RUNTIME                                    ! End of the subroutine finalize runtime.

      END MODULE MUL2_RUNTIME                                            ! End of the module mul2 runtime.
