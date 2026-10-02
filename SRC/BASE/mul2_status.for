!=======================================================================
!  CENTRAL STATUS AND ERROR DESCRIPTION.
!=======================================================================
      MODULE MUL2_STATUS                                                 ! Module mul2 status begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: STATUS_OK = 0_I4                 ! Constant public integer (int32): status_ok = 0.
      INTEGER(I4), PARAMETER, PUBLIC :: STATUS_WARNING = 1_I4            ! Constant public integer (int32): status_warning = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: STATUS_ERROR = 2_I4              ! Constant public integer (int32): status_error = 2.

      TYPE, PUBLIC :: STATUS_TYPE                                        ! Definition of the derived type status type.
        INTEGER(I4) :: CODE = STATUS_OK                                  ! Integer (int32): code = status_ok.
        INTEGER(I4) :: WARNING_COUNT = 0_I4                              ! Integer (int32): warning_count = 0.
        CHARACTER(LEN=256) :: MESSAGE = ' '                              ! Character (length 256): message = ' '.
        CHARACTER(LEN=64) :: SOURCE = ' '                                ! Character (length 64): source = ' '.
      END TYPE STATUS_TYPE                                               ! End of the type definition status type.

      PUBLIC :: CLEAR_STATUS                                             ! Export: clear status.
      PUBLIC :: SET_WARNING                                              ! Export: set warning.
      PUBLIC :: SET_ERROR                                                ! Export: set error.
      PUBLIC :: STATUS_IS_OK                                             ! Export: status is ok.
      PUBLIC :: MERGE_STATUS                                             ! Export: merge status.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE CLEAR_STATUS(STATUS)                                    ! Subroutine clear status takes status.

      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      STATUS%CODE = STATUS_OK                                            ! Set status.code to status_ok.
      STATUS%WARNING_COUNT = 0_I4                                        ! Set status.warning_count to zero.
      STATUS%MESSAGE = ' '                                               ! Set status.message to ' '.
      STATUS%SOURCE = ' '                                                ! Set status.source to ' '.

      END SUBROUTINE CLEAR_STATUS                                        ! End of the subroutine clear status.

      SUBROUTINE SET_WARNING(STATUS, SOURCE, MESSAGE)                    ! Subroutine set warning takes status, source, message.

      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      CHARACTER(LEN=*), INTENT(IN) :: SOURCE                             ! Input character (length *): source.
      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.

      IF (STATUS%CODE .EQ. STATUS_ERROR) RETURN                          ! If status.code = status_error, return to the caller.
      STATUS%CODE = STATUS_WARNING                                       ! Set status.code to status_warning.
      STATUS%WARNING_COUNT = STATUS%WARNING_COUNT + 1_I4                 ! Add 1 to status.warning_count.
      STATUS%SOURCE = SOURCE                                             ! Set status.source to source.
      STATUS%MESSAGE = MESSAGE                                           ! Set status.message to message.

      END SUBROUTINE SET_WARNING                                         ! End of the subroutine set warning.

      SUBROUTINE SET_ERROR(STATUS, SOURCE, MESSAGE)                      ! Subroutine set error takes status, source, message.

      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      CHARACTER(LEN=*), INTENT(IN) :: SOURCE                             ! Input character (length *): source.
      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.

      IF (STATUS%CODE .EQ. STATUS_ERROR) RETURN                          ! If status.code = status_error, return to the caller.
      STATUS%CODE = STATUS_ERROR                                         ! Set status.code to status_error.
      STATUS%SOURCE = SOURCE                                             ! Set status.source to source.
      STATUS%MESSAGE = MESSAGE                                           ! Set status.message to message.

      END SUBROUTINE SET_ERROR                                           ! End of the subroutine set error.

      LOGICAL FUNCTION STATUS_IS_OK(STATUS)                              ! Function status is ok takes status.

      TYPE(STATUS_TYPE), INTENT(IN) :: STATUS                            ! Input of type status_type: status.

      STATUS_IS_OK = STATUS%CODE .NE. STATUS_ERROR                       ! Set status_is_ok to status.code /= status_error.

      END FUNCTION STATUS_IS_OK                                          ! End of the function status is ok.

!  FOLD THE STATUS OF ONE STEP INTO THE STATUS OF A WHOLE PHASE: THE
!  FIRST ERROR WINS AND WARNINGS ARE COUNTED, NEVER LOST.
      SUBROUTINE MERGE_STATUS(LOCAL, GLOBAL)                             ! Subroutine merge status takes local, global.

      TYPE(STATUS_TYPE), INTENT(IN) :: LOCAL                             ! Input of type status_type: local.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: GLOBAL                         ! In/out of type status_type: global.

      IF (LOCAL%CODE .EQ. STATUS_ERROR) THEN                             ! If local.code = status_error:
        CALL SET_ERROR(GLOBAL, TRIM(LOCAL%SOURCE),                       ! Record an error in global: trim(local.message).
     &                 TRIM(LOCAL%MESSAGE))
      ELSE IF (LOCAL%WARNING_COUNT .GT. 0_I4) THEN                       ! Otherwise, if local.warning_count > 0:
        CALL SET_WARNING(GLOBAL, TRIM(LOCAL%SOURCE),                     ! Record a warning in global: trim(local.message).
     &                   TRIM(LOCAL%MESSAGE))
        GLOBAL%WARNING_COUNT = GLOBAL%WARNING_COUNT +                    ! Add local.warning_count - 1 to global.warning_count.
     &                         LOCAL%WARNING_COUNT - 1_I4
      END IF                                                             ! End of the IF block.

      END SUBROUTINE MERGE_STATUS                                        ! End of the subroutine merge status.

      END MODULE MUL2_STATUS                                             ! End of the module mul2 status.
