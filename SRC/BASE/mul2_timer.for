!=======================================================================
!  WALL-CLOCK AND CPU TIMER.
!=======================================================================
      MODULE MUL2_TIMER                                                  ! Module mul2 timer begins.

      USE MUL2_KINDS, ONLY: I8, R8                                       ! Use from module mul2 kinds: i8, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: TIMER_TYPE                                         ! Definition of the derived type timer type.
        CHARACTER(LEN=64) :: NAME = ' '                                  ! Character (length 64): name = ' '.
        REAL(R8) :: CPU_BEGIN = 0.0_R8                                   ! Real (real64): cpu_begin = 0.0.
        REAL(R8) :: CPU_END = 0.0_R8                                     ! Real (real64): cpu_end = 0.0.
        INTEGER(I8) :: CLOCK_BEGIN = 0_I8                                ! Integer (int64): clock_begin = 0.
        INTEGER(I8) :: CLOCK_END = 0_I8                                  ! Integer (int64): clock_end = 0.
        INTEGER(I8) :: CLOCK_RATE = 0_I8                                 ! Integer (int64): clock_rate = 0.
        INTEGER(I8) :: CLOCK_MAX = 0_I8                                  ! Integer (int64): clock_max = 0.
        LOGICAL :: RUNNING = .FALSE.                                     ! Logical: running = false.
      END TYPE TIMER_TYPE                                                ! End of the type definition timer type.

      PUBLIC :: TIMER_START                                              ! Export: timer start.
      PUBLIC :: TIMER_STOP                                               ! Export: timer stop.
      PUBLIC :: TIMER_CPU_SECONDS                                        ! Export: timer cpu seconds.
      PUBLIC :: TIMER_WALL_SECONDS                                       ! Export: timer wall seconds.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE TIMER_START(TIMER, NAME)                                ! Subroutine timer start takes timer, name.

      TYPE(TIMER_TYPE), INTENT(INOUT) :: TIMER                           ! In/out of type timer_type: timer.
      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.

      TIMER%NAME = NAME                                                  ! Set timer.name to name.
      CALL CPU_TIME(TIMER%CPU_BEGIN)                                     ! Read the CPU clock into timer.cpu_begin.
      CALL SYSTEM_CLOCK(TIMER%CLOCK_BEGIN, TIMER%CLOCK_RATE,             ! Read the system clock into timer.clock_begin.
     &                  TIMER%CLOCK_MAX)
      TIMER%RUNNING = .TRUE.                                             ! Set the flag timer.running to true.

      END SUBROUTINE TIMER_START                                         ! End of the subroutine timer start.

      SUBROUTINE TIMER_STOP(TIMER)                                       ! Subroutine timer stop takes timer.

      TYPE(TIMER_TYPE), INTENT(INOUT) :: TIMER                           ! In/out of type timer_type: timer.

      CALL CPU_TIME(TIMER%CPU_END)                                       ! Read the CPU clock into timer.cpu_end.
      CALL SYSTEM_CLOCK(TIMER%CLOCK_END)                                 ! Read the system clock into timer.clock_end.
      TIMER%RUNNING = .FALSE.                                            ! Set the flag timer.running to false.

      END SUBROUTINE TIMER_STOP                                          ! End of the subroutine timer stop.

      REAL(R8) FUNCTION TIMER_CPU_SECONDS(TIMER)                         ! Function timer cpu seconds takes timer.

      TYPE(TIMER_TYPE), INTENT(IN) :: TIMER                              ! Input of type timer_type: timer.

      TIMER_CPU_SECONDS = TIMER%CPU_END - TIMER%CPU_BEGIN                ! Set timer_cpu_seconds to timer.cpu_end - timer.cpu_begin.

      END FUNCTION TIMER_CPU_SECONDS                                     ! End of the function timer cpu seconds.

      REAL(R8) FUNCTION TIMER_WALL_SECONDS(TIMER)                        ! Function timer wall seconds takes timer.

      TYPE(TIMER_TYPE), INTENT(IN) :: TIMER                              ! Input of type timer_type: timer.
      INTEGER(I8) :: TICKS                                               ! Integer (int64): ticks.

      IF (TIMER%CLOCK_RATE .LE. 0_I8) THEN                               ! If timer.clock_rate <= 0:
        TIMER_WALL_SECONDS = 0.0_R8                                      ! Set timer_wall_seconds to zero.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      IF (TIMER%CLOCK_END .GE. TIMER%CLOCK_BEGIN) THEN                   ! If timer.clock_end >= timer.clock_begin:
        TICKS = TIMER%CLOCK_END - TIMER%CLOCK_BEGIN                      ! Set ticks to timer.clock_end - timer.clock_begin.
      ELSE                                                               ! Otherwise:
        TICKS = TIMER%CLOCK_MAX - TIMER%CLOCK_BEGIN +                    ! Set ticks to timer.clock_max - timer.clock_begin + timer.clock_end + 1.
     &          TIMER%CLOCK_END + 1_I8
      END IF                                                             ! End of the IF block.
      TIMER_WALL_SECONDS = REAL(TICKS,R8) /                              ! Set timer_wall_seconds to real(ticks,r8) / real(timer.clock_rate,r8).
     &                     REAL(TIMER%CLOCK_RATE,R8)

      END FUNCTION TIMER_WALL_SECONDS                                    ! End of the function timer wall seconds.

      END MODULE MUL2_TIMER                                              ! End of the module mul2 timer.
