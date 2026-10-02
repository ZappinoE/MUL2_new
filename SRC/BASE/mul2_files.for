!=======================================================================
!  FILE-SYSTEM HELPERS (OUTPUT DIRECTORIES).
!=======================================================================
      MODULE MUL2_FILES                                                  ! Module mul2 files begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: ENSURE_DIRECTORY                                         ! Export: ensure directory.
      PUBLIC :: IS_WINDOWS                                               ! Export: is windows.

      CONTAINS                                                           ! The procedures of the module follow.

      LOGICAL FUNCTION IS_WINDOWS()                                      ! Function is windows.

      CHARACTER(LEN=32) :: VALUE                                         ! Character (length 32): value.
      INTEGER :: LENGTH                                                  ! Integer: length.
      INTEGER :: STAT                                                    ! Integer: stat.

      VALUE = ' '                                                        ! Set value to ' '.
      CALL GET_ENVIRONMENT_VARIABLE('OS', VALUE, LENGTH, STAT)           ! Call get environment variable with 'OS', value, length, stat.
      IS_WINDOWS = STAT .EQ. 0 .AND. LENGTH .GT. 0 .AND.                 ! Set is_windows to stat = 0 and length > 0 and index(value,'Windows') > 0.
     &             INDEX(VALUE,'Windows') .GT. 0

      END FUNCTION IS_WINDOWS                                            ! End of the function is windows.

!  CREATE A RELATIVE DIRECTORY IF IT DOES NOT EXIST YET.
      SUBROUTINE ENSURE_DIRECTORY(NAME, STATUS)                          ! Subroutine ensure directory takes name, status.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER :: EXIT_STATUS                                             ! Integer: exit_status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (IS_WINDOWS()) THEN                                             ! If is_windows():
        CALL EXECUTE_COMMAND_LINE('if not exist "'//TRIM(NAME)//         ! Call execute command line with 'if not exist "'//trim(name)// '" mkdir "'//trim(name)//'"', exitstat=exit_s...
     &       '" mkdir "'//TRIM(NAME)//'"', EXITSTAT=EXIT_STATUS)
      ELSE                                                               ! Otherwise:
        CALL EXECUTE_COMMAND_LINE('mkdir -p "'//TRIM(NAME)//'"',         ! Call execute command line with 'mkdir -p "'//trim(name)//'"', exitstat=exit_status.
     &                            EXITSTAT=EXIT_STATUS)
      END IF                                                             ! End of the IF block.
      IF (EXIT_STATUS .NE. 0) THEN                                       ! If exit_status /= 0:
        CALL SET_ERROR(STATUS, 'ENSURE_DIRECTORY',                       ! Record an error in status: 'CANNOT CREATE DIRECTORY: '//trim(name).
     &                 'CANNOT CREATE DIRECTORY: '//TRIM(NAME))
      END IF                                                             ! End of the IF block.

      END SUBROUTINE ENSURE_DIRECTORY                                    ! End of the subroutine ensure directory.

      END MODULE MUL2_FILES                                              ! End of the module mul2 files.
