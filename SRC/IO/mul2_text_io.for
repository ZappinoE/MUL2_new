!=======================================================================
!  SHARED TEXT-INPUT UTILITIES.
!=======================================================================
      MODULE MUL2_TEXT_IO                                                ! Module mul2 text io begins.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: NEXT_DATA_LINE                                           ! Export: next data line.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE NEXT_DATA_LINE(UNIT, LINE, IOS)                         ! Subroutine next data line takes unit, line, ios.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.
      CHARACTER(LEN=*), INTENT(OUT) :: LINE                              ! Output character (length *): line.
      INTEGER, INTENT(OUT) :: IOS                                        ! Output integer: ios.

      DO                                                                 ! Loop until an EXIT statement is reached:
        READ(UNIT,'(A)',IOSTAT=IOS) LINE                                 ! Read from unit unit into line.
        IF (IOS .NE. 0) RETURN                                           ! If ios /= 0, return to the caller.
        LINE = ADJUSTL(LINE)                                             ! Set line to adjustl(line).
        IF (LEN_TRIM(LINE) .EQ. 0) CYCLE                                 ! If len_trim(line) = 0, skip to the next iteration.
        IF (LINE(1:1) .EQ. '#' .OR.                                      ! If line(1:1) = '#' or line(1:1) = '!', skip to the next iteration.
     &      LINE(1:1) .EQ. '!') CYCLE
        RETURN                                                           ! Return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE NEXT_DATA_LINE                                      ! End of the subroutine next data line.

      END MODULE MUL2_TEXT_IO                                            ! End of the module mul2 text io.
