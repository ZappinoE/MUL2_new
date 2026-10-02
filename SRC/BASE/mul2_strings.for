!=======================================================================
!  BASIC STRING UTILITIES.
!=======================================================================
      MODULE MUL2_STRINGS                                                ! Module mul2 strings begins.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: UPPERCASE                                                ! Export: uppercase.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE UPPERCASE(TEXT)                                         ! Subroutine uppercase takes text.

      CHARACTER(LEN=*), INTENT(INOUT) :: TEXT                            ! In/out character (length *): text.
      INTEGER :: I                                                       ! Integer: i.
      INTEGER :: CODE                                                    ! Integer: code.

      DO I = 1, LEN(TEXT)                                                ! Loop i from 1 to len(text):
        CODE = IACHAR(TEXT(I:I))                                         ! Set code to iachar(text(i:i)).
        IF (CODE .GE. IACHAR('a') .AND.                                  ! If code >= iachar('a') and code <= iachar('z'):
     &      CODE .LE. IACHAR('z')) THEN
          TEXT(I:I) = ACHAR(CODE - 32)                                   ! Set text(i:i) to achar(code - 32).
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE UPPERCASE                                           ! End of the subroutine uppercase.

      END MODULE MUL2_STRINGS                                            ! End of the module mul2 strings.
