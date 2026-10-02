!=======================================================================
!  CENTRAL CONSOLE LOGGER.
!=======================================================================
      MODULE MUL2_LOG                                                    ! Module mul2 log begins.

      USE, INTRINSIC :: ISO_FORTRAN_ENV, ONLY:                           ! Use from module iso fortran env: output unit, error unit.
     &                  OUTPUT_UNIT, ERROR_UNIT

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      LOGICAL :: DEBUG_MODE = .FALSE.                                    ! Logical: debug_mode = false.

      PUBLIC :: LOG_INITIALIZE                                           ! Export: log initialize.
      PUBLIC :: LOG_INFO                                                 ! Export: log info.
      PUBLIC :: LOG_WARNING                                              ! Export: log warning.
      PUBLIC :: LOG_ERROR                                                ! Export: log error.
      PUBLIC :: LOG_DEBUG                                                ! Export: log debug.
      PUBLIC :: IS_DEBUG_MODE                                            ! Export: is debug mode.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE LOG_INITIALIZE(DEBUG_ENABLED)                           ! Subroutine log initialize takes debug enabled.

      LOGICAL, INTENT(IN) :: DEBUG_ENABLED                               ! Input logical: debug_enabled.

      DEBUG_MODE = DEBUG_ENABLED                                         ! Set debug_mode to debug_enabled.

      END SUBROUTINE LOG_INITIALIZE                                      ! End of the subroutine log initialize.

      SUBROUTINE LOG_INFO(MESSAGE)                                       ! Subroutine log info takes message.

      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.

      WRITE(OUTPUT_UNIT,'(A)') '[INFO] '//TRIM(MESSAGE)                  ! Write to unit output_unit: '[INFO] '//trim(message).

      END SUBROUTINE LOG_INFO                                            ! End of the subroutine log info.

      SUBROUTINE LOG_WARNING(MESSAGE)                                    ! Subroutine log warning takes message.

      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.

      WRITE(ERROR_UNIT,'(A)') '[WARNING] '//TRIM(MESSAGE)                ! Write to unit error_unit: '[WARNING] '//trim(message).

      END SUBROUTINE LOG_WARNING                                         ! End of the subroutine log warning.

      SUBROUTINE LOG_ERROR(MESSAGE)                                      ! Subroutine log error takes message.

      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.

      WRITE(ERROR_UNIT,'(A)') '[ERROR] '//TRIM(MESSAGE)                  ! Write to unit error_unit: '[ERROR] '//trim(message).

      END SUBROUTINE LOG_ERROR                                           ! End of the subroutine log error.

      SUBROUTINE LOG_DEBUG(MESSAGE)                                      ! Subroutine log debug takes message.

      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.

      IF (DEBUG_MODE) THEN                                               ! If debug_mode:
        WRITE(OUTPUT_UNIT,'(A)') '[DEBUG] '//TRIM(MESSAGE)               ! Write to unit output_unit: '[DEBUG] '//trim(message).
      END IF                                                             ! End of the IF block.

      END SUBROUTINE LOG_DEBUG                                           ! End of the subroutine log debug.

      LOGICAL FUNCTION IS_DEBUG_MODE()                                   ! Function is debug mode.

      IS_DEBUG_MODE = DEBUG_MODE                                         ! Set is_debug_mode to debug_mode.

      END FUNCTION IS_DEBUG_MODE                                         ! End of the function is debug mode.

      END MODULE MUL2_LOG                                                ! End of the module mul2 log.
