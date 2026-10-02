!=======================================================================
!  TIME-RESPONSE INPUT (TIME_RESP.DAT, HISTORICAL FORMAT) AND THE LOAD
!  AMPLITUDE a(t) THAT MULTIPLIES EVERY LOAD AND PRESCRIBED VALUE.
!
!      TI TF
!      NSTEP
!      POST_EVERY                 (OUTPUT EVERY N STEPS)
!      N_SPECIFIC                 (EXTRA OUTPUT STEPS, ONE PER LINE)
!      N_LOADS
!      STEP t0 A                  A FOR t >= t0
!      IMPU t0 A                  A AT THE FIRST STEP t >= t0 ONLY
!      RAMP t0 t1 A               LINEAR RISE FROM 0 TO A
!      SINU PHI OMEGA A           A SIN(PHI + OMEGA t)
!      HASU t0 F PHI2 N PHI1 A    HANN-WINDOWED SINE BURST
!      HACU t0 F PHI2 N PHI1 A    HANN-WINDOWED COSINE BURST
!      WPSU t0 F PHI2 N PHI1 A    SINE BURST WITH SIN**2 WINDOW
!  OPTIONAL RECORDS AFTER THE LOADS (ANY ORDER):
!      NEWMARK BETA GAMMA         DEFAULT 0.25 0.5
!      RAYLEIGH ALPHA BETA        C = ALPHA M + BETA K (OVERRIDES DAMP)
!      THETA TH                   THERMAL THETA-METHOD, DEFAULT 1
!      T0 TEMPERATURE            ABSOLUTE REFERENCE TEMPERATURE: SWITCHES
!                                 ON THE THERMOELASTIC HEATING TERM
!=======================================================================
      MODULE MUL2_TIME_INPUT                                             ! Module mul2 time input begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      REAL(R8), PARAMETER :: PI = 3.14159265358979323846_R8              ! Constant real (real64): pi = 3.14159265358979323846.

      INTEGER(I4), PARAMETER, PUBLIC :: LOAD_STEP = 1_I4                 ! Constant public integer (int32): load_step = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: LOAD_RAMP = 2_I4                 ! Constant public integer (int32): load_ramp = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: LOAD_IMPULSE = 3_I4              ! Constant public integer (int32): load_impulse = 3.
      INTEGER(I4), PARAMETER, PUBLIC :: LOAD_SINE = 4_I4                 ! Constant public integer (int32): load_sine = 4.
      INTEGER(I4), PARAMETER, PUBLIC :: LOAD_HANN_SINE = 5_I4            ! Constant public integer (int32): load_hann_sine = 5.
      INTEGER(I4), PARAMETER, PUBLIC :: LOAD_HANN_COSINE = 6_I4          ! Constant public integer (int32): load_hann_cosine = 6.
      INTEGER(I4), PARAMETER, PUBLIC :: LOAD_WINDOWED_SINE = 7_I4        ! Constant public integer (int32): load_windowed_sine = 7.

      TYPE, PUBLIC :: TIME_LOAD_TYPE                                     ! Definition of the derived type time load type.
        INTEGER(I4) :: KIND = 0_I4                                       ! Integer (int32): kind = 0.
        REAL(R8) :: ARG(8) = 0.0_R8                                      ! Real (real64): arg(8) = 0.0.
      END TYPE TIME_LOAD_TYPE                                            ! End of the type definition time load type.

      TYPE, PUBLIC :: TIME_INPUT_TYPE                                    ! Definition of the derived type time input type.
        REAL(R8) :: INITIAL_TIME = 0.0_R8                                ! Real (real64): initial_time = 0.0.
        REAL(R8) :: FINAL_TIME = 0.0_R8                                  ! Real (real64): final_time = 0.0.
        INTEGER(I4) :: STEP_COUNT = 0_I4                                 ! Integer (int32): step_count = 0.
        INTEGER(I4) :: POST_EVERY = 1_I4                                 ! Integer (int32): post_every = 1.
        INTEGER(I4), ALLOCATABLE :: SPECIFIC_STEP(:)                     ! Allocatable integer (int32): specific_step(:).
        TYPE(TIME_LOAD_TYPE), ALLOCATABLE :: LOAD(:)                     ! Allocatable of type time_load_type: load(:).
        REAL(R8) :: NEWMARK_BETA = 0.25_R8                               ! Real (real64): newmark_beta = 0.25.
        REAL(R8) :: NEWMARK_GAMMA = 0.5_R8                               ! Real (real64): newmark_gamma = 0.5.
        REAL(R8) :: RAYLEIGH_MASS = 0.0_R8                               ! Real (real64): rayleigh_mass = 0.0.
        REAL(R8) :: RAYLEIGH_STIFFNESS = 0.0_R8                          ! Real (real64): rayleigh_stiffness = 0.0.
        LOGICAL :: HAS_RAYLEIGH = .FALSE.                                ! Logical: has_rayleigh = false.
        REAL(R8) :: THETA = 1.0_R8                                       ! Real (real64): theta = 1.0.
        REAL(R8) :: REFERENCE_TEMPERATURE = 0.0_R8                       ! Real (real64): reference_temperature = 0.0.
      END TYPE TIME_INPUT_TYPE                                           ! End of the type definition time input type.

!  FREQ_RESP.DAT: FI FF / NSTEP / POST_EVERY, THEN OPTIONAL RAYLEIGH
!  ALPHA BETA AND T0 RECORDS (FREQUENCIES IN HZ).
      TYPE, PUBLIC :: FREQ_INPUT_TYPE                                    ! Definition of the derived type freq input type.
        REAL(R8) :: FIRST_FREQUENCY = 0.0_R8                             ! Real (real64): first_frequency = 0.0.
        REAL(R8) :: LAST_FREQUENCY = 0.0_R8                              ! Real (real64): last_frequency = 0.0.
        INTEGER(I4) :: STEP_COUNT = 0_I4                                 ! Integer (int32): step_count = 0.
        INTEGER(I4) :: POST_EVERY = 1_I4                                 ! Integer (int32): post_every = 1.
        REAL(R8) :: RAYLEIGH_MASS = 0.0_R8                               ! Real (real64): rayleigh_mass = 0.0.
        REAL(R8) :: RAYLEIGH_STIFFNESS = 0.0_R8                          ! Real (real64): rayleigh_stiffness = 0.0.
        LOGICAL :: HAS_RAYLEIGH = .FALSE.                                ! Logical: has_rayleigh = false.
        REAL(R8) :: REFERENCE_TEMPERATURE = 0.0_R8                       ! Real (real64): reference_temperature = 0.0.
      END TYPE FREQ_INPUT_TYPE                                           ! End of the type definition freq input type.

!  NL_INFO.DAT (NONLINEAR STATIC): SOLVTEC / NLSTEP / ITMAX / TOLL /
!  POST_EVERY (THE FIRST FIVE RECORDS OF THE HISTORICAL FILE).
!  SOLVTEC 1: LOAD CONTROL (NLSTEP EQUAL STEPS, LAMBDA = N/NLSTEP);
!  SOLVTEC 2: ARC LENGTH (NLSTEP = MAXIMUM NUMBER OF STEPS). OPTIONAL
!  SIXTH RECORD (ARC LENGTH ONLY): DS0 DSMIN DSMAX LAMBDA_MAX; A ZERO
!  DS0 / DSMIN / DSMAX MEANS AUTOMATIC.
      TYPE, PUBLIC :: NL_INPUT_TYPE                                      ! Definition of the derived type nl input type.
        INTEGER(I4) :: TECHNIQUE = 1_I4                                  ! Integer (int32): technique = 1.
        INTEGER(I4) :: STEP_COUNT = 10_I4                                ! Integer (int32): step_count = 10.
        INTEGER(I4) :: MAX_ITERATIONS = 30_I4                            ! Integer (int32): max_iterations = 30.
        REAL(R8) :: TOLERANCE = 1.0E-6_R8                                ! Real (real64): tolerance = 1.0e-6.
        INTEGER(I4) :: POST_EVERY = 1_I4                                 ! Integer (int32): post_every = 1.
        REAL(R8) :: ARC_LENGTH = 0.0_R8                                  ! Real (real64): arc_length = 0.0.
        REAL(R8) :: ARC_LENGTH_MIN = 0.0_R8                              ! Real (real64): arc_length_min = 0.0.
        REAL(R8) :: ARC_LENGTH_MAX = 0.0_R8                              ! Real (real64): arc_length_max = 0.0.
        REAL(R8) :: LAMBDA_MAX = 1.0_R8                                  ! Real (real64): lambda_max = 1.0.
      END TYPE NL_INPUT_TYPE                                             ! End of the type definition nl input type.

      PUBLIC :: LOAD_AMPLITUDE                                           ! Export: load amplitude.
      PUBLIC :: STEP_TIME                                                ! Export: step time.
      PUBLIC :: STEP_IS_OUTPUT                                           ! Export: step is output.

      CONTAINS                                                           ! The procedures of the module follow.

      REAL(R8) FUNCTION STEP_TIME(TIME, STEP)                            ! Function step time takes time, step.

      TYPE(TIME_INPUT_TYPE), INTENT(IN) :: TIME                          ! Input of type time_input_type: time.
      INTEGER(I4), INTENT(IN) :: STEP                                    ! Input integer (int32): step.

      STEP_TIME = TIME%INITIAL_TIME + REAL(STEP,R8)*                     ! Set step_time to time.initial_time + real(step,r8)* (time.final_time-time.initial_time)/real(time.step_coun...
     &  (TIME%FINAL_TIME-TIME%INITIAL_TIME)/REAL(TIME%STEP_COUNT,R8)

      END FUNCTION STEP_TIME                                             ! End of the function step time.

      LOGICAL FUNCTION STEP_IS_OUTPUT(TIME, STEP)                        ! Function step is output takes time, step.

      TYPE(TIME_INPUT_TYPE), INTENT(IN) :: TIME                          ! Input of type time_input_type: time.
      INTEGER(I4), INTENT(IN) :: STEP                                    ! Input integer (int32): step.

      STEP_IS_OUTPUT = STEP .EQ. TIME%STEP_COUNT                         ! Set step_is_output to step = time.step_count.
      IF (MOD(STEP,MAX(1_I4,TIME%POST_EVERY)) .EQ. 0_I4)                 ! If mod(step,max(1,time.post_every)) = 0, set the flag step_is_output to true.
     &  STEP_IS_OUTPUT = .TRUE.
      IF (ALLOCATED(TIME%SPECIFIC_STEP)) THEN                            ! If allocated(time.specific_step):
        IF (ANY(TIME%SPECIFIC_STEP .EQ. STEP))                           ! If any(time.specific_step = step), set the flag step_is_output to true.
     &    STEP_IS_OUTPUT = .TRUE.
      END IF                                                             ! End of the IF block.

      END FUNCTION STEP_IS_OUTPUT                                        ! End of the function step is output.

!  AMPLITUDE AT STEP I (T = STEP_TIME): SUM OF ALL THE LOAD RECORDS.
!  THE IMPULSE IS A SINGLE-STEP VALUE, AS IN THE HISTORICAL CODE.
      REAL(R8) FUNCTION LOAD_AMPLITUDE(TIME, STEP)                       ! Function load amplitude takes time, step.

      TYPE(TIME_INPUT_TYPE), INTENT(IN) :: TIME                          ! Input of type time_input_type: time.
      INTEGER(I4), INTENT(IN) :: STEP                                    ! Input integer (int32): step.
      REAL(R8) :: T                                                      ! Real (real64): t.
      REAL(R8) :: DT                                                     ! Real (real64): dt.
      REAL(R8) :: SLOPE                                                  ! Real (real64): slope.
      REAL(R8) :: P(8)                                                   ! Real (real64): p(8).
      REAL(R8) :: EPS                                                    ! Real (real64): eps.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      LOAD_AMPLITUDE = 0.0_R8                                            ! Set load_amplitude to zero.
      IF (.NOT. ALLOCATED(TIME%LOAD)) RETURN                             ! If not allocated(time.load), return to the caller.
      T = STEP_TIME(TIME, STEP)                                          ! Set t to step_time(time, step).
      DT = (TIME%FINAL_TIME-TIME%INITIAL_TIME)/REAL(TIME%STEP_COUNT,R8)  ! Set dt to (time.final_time-time.initial_time)/real(time.step_count,r8).
      EPS = 1.0E-9_R8*DT                                                 ! Set eps to 1.0e-9*dt.
      DO I = 1_I4, SIZE(TIME%LOAD)                                       ! Loop i from 1 to size(time.load):
        P = TIME%LOAD(I)%ARG                                             ! Set p to time.load(i).arg.
        SELECT CASE (TIME%LOAD(I)%KIND)                                  ! Choose according to the value of time.load(i).kind:
        CASE (LOAD_STEP)                                                 ! Case load_step:
          IF (T .GE. P(1)-EPS) LOAD_AMPLITUDE = LOAD_AMPLITUDE +         ! If t >= p(1)-eps, add p(2) to load_amplitude.
     &      P(2)
        CASE (LOAD_IMPULSE)                                              ! Case load_impulse:
!         FIRST STEP AT OR AFTER T0.
          IF (T .GE. P(1)-EPS .AND. T-DT .LT. P(1)-EPS)                  ! If t >= p(1)-eps and t-dt < p(1)-eps, add p(2) to load_amplitude.
     &      LOAD_AMPLITUDE = LOAD_AMPLITUDE + P(2)
        CASE (LOAD_RAMP)                                                 ! Case load_ramp:
          SLOPE = P(3)/(P(2)-P(1))                                       ! Set slope to p(3)/(p(2)-p(1)).
          IF (T .GE. P(2)-EPS) THEN                                      ! If t >= p(2)-eps:
            LOAD_AMPLITUDE = LOAD_AMPLITUDE + P(3)                       ! Add p(3) to load_amplitude.
          ELSE IF (T .GE. P(1)) THEN                                     ! Otherwise, if t >= p(1):
            LOAD_AMPLITUDE = LOAD_AMPLITUDE + (T-P(1))*SLOPE             ! Add (t-p(1))*slope to load_amplitude.
          END IF                                                         ! End of the IF block.
        CASE (LOAD_SINE)                                                 ! Case load_sine:
          LOAD_AMPLITUDE = LOAD_AMPLITUDE + P(3)*SIN(P(1)+P(2)*T)        ! Add p(3)*sin(p(1)+p(2)*t) to load_amplitude.
        CASE (LOAD_HANN_SINE, LOAD_HANN_COSINE)                          ! Case load_hann_sine, load_hann_cosine:
!         P = T0, F, PHI2, N, PHI1, A
          IF (T .GE. P(1) .AND. T .LE. P(1)+P(4)/P(2)) THEN              ! If t >= p(1) and t <= p(1)+p(4)/p(2):
            IF (TIME%LOAD(I)%KIND .EQ. LOAD_HANN_SINE) THEN              ! If time.load(i).kind = load_hann_sine:
              LOAD_AMPLITUDE = LOAD_AMPLITUDE + P(6)*0.5_R8*(1.0_R8-     ! Add p(6)*0.5*(1.0- cos(p(3)+2.0*pi*(p(2)/p(4)*(t-p(1)))))* sin(p(5)+2.0*pi*p(2)*(t-p(1))) to load_amplitude.
     &          COS(P(3)+2.0_R8*PI*(P(2)/P(4)*(T-P(1)))))*
     &          SIN(P(5)+2.0_R8*PI*P(2)*(T-P(1)))
            ELSE                                                         ! Otherwise:
              LOAD_AMPLITUDE = LOAD_AMPLITUDE + P(6)*0.5_R8*(1.0_R8-     ! Add p(6)*0.5*(1.0- cos(p(3)+2.0*pi*(p(2)/p(4)*(t-p(1)))))* cos(p(5)+2.0*pi*p(2)*(t-p(1))) to load_amplitude.
     &          COS(P(3)+2.0_R8*PI*(P(2)/P(4)*(T-P(1)))))*
     &          COS(P(5)+2.0_R8*PI*P(2)*(T-P(1)))
            END IF                                                       ! End of the IF block.
          END IF                                                         ! End of the IF block.
        CASE (LOAD_WINDOWED_SINE)                                        ! Case load_windowed_sine:
          IF (T .GE. P(1) .AND. T .LE. P(1)+P(4)/P(2)) THEN              ! If t >= p(1) and t <= p(1)+p(4)/p(2):
            LOAD_AMPLITUDE = LOAD_AMPLITUDE + P(6)*                      ! Add p(6)* sin(p(3)+2.0*pi*p(2)*(t-p(1)))* sin(p(5)+2.0*pi*(p(2)/(2.0*p(4)))*(t-p(1)))**2 to load_amplitude.
     &        SIN(P(3)+2.0_R8*PI*P(2)*(T-P(1)))*
     &        SIN(P(5)+2.0_R8*PI*(P(2)/(2.0_R8*P(4)))*(T-P(1)))**2
          END IF                                                         ! End of the IF block.
        END SELECT                                                       ! End of the case selection.
      END DO                                                             ! End of the loop.

      END FUNCTION LOAD_AMPLITUDE                                        ! End of the function load amplitude.

      END MODULE MUL2_TIME_INPUT                                         ! End of the module mul2 time input.
