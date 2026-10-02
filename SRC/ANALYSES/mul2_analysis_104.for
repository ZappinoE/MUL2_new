!=======================================================================
!  SOLUTION 104: LINEAR TIME RESPONSE (NEWMARK).
!
!  MONOLITHIC SYSTEM FOR ALL THE PHYSICS IN ONE EFFECTIVE MATRIX,
!      U (FIELDS 1-3)  SECOND ORDER:  M A + C V + K X = F      (NEWMARK)
!      T (FIELD 4)     FIRST ORDER:   CAP TDOT + K_T T + ... = Q (THETA)
!      P (FIELD 5)     ALGEBRAIC:     NO INERTIA
!  WITH C = ALPHA M + BETA K ON THE MECHANICAL DOFS (RAYLEIGH). WHEN THE
!  ABSOLUTE REFERENCE TEMPERATURE T0 IS GIVEN THE THERMOELASTIC HEATING
!  TERM  T0 (-K_UT)^T V  IS ADDED TO THE TEMPERATURE ROWS (TWO-WAY
!  COUPLING, THERMOELASTIC DAMPING).
!
!  EVERY LOAD AND EVERY PRESCRIBED VALUE IS MULTIPLIED BY THE AMPLITUDE
!  a(t) OF TIME_RESP.DAT. THE INITIAL STATE IS A(0) TIMES THE PRESCRIBED
!  VALUES, ZERO VELOCITY, TEMPERATURE ZERO.
!  THE EFFECTIVE MATRIX IS FACTORED ONCE (CONSTANT STEP).
!=======================================================================
      MODULE MUL2_ANALYSIS_104                                           ! Module mul2 analysis 104 begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok, merge status.
     &                       STATUS_IS_OK, MERGE_STATUS
      USE MUL2_LOG, ONLY: LOG_INFO                                       ! Use from module mul2 log: log info.
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE                       ! Use from module mul2 model cache: model cache type.
      USE MUL2_MODEL_ASSEMBLY, ONLY: ASSEMBLE_MODEL_SYSTEM               ! Use from module mul2 model assembly: assemble model system.
      USE MUL2_BOUNDARY_APPLICATION, ONLY:                               ! Use from module mul2 boundary application: build mechanical boundary data, apply static constraints.
     &     BUILD_MECHANICAL_BOUNDARY_DATA, APPLY_STATIC_CONSTRAINTS
      USE MUL2_SURFACE_LOADS, ONLY: APPLY_SURFACE_LOADS                  ! Use from module mul2 surface loads: apply surface loads.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_SPARSE_OPERATIONS, ONLY: SPARSE_MULTIPLY,                 ! Use from module mul2 sparse operations: sparse multiply, build reduced pattern, reduce values, reduced patt...
     &     BUILD_REDUCED_PATTERN, REDUCE_VALUES, REDUCED_PATTERN_TYPE
      USE MUL2_PARDISO_FACTOR, ONLY: PARDISO_FACTOR_TYPE,                ! Use from module mul2 pardiso factor: pardiso factor type, mtype symmetric positive, mtype nonsymmetric, par...
     &     MTYPE_SYMMETRIC_POSITIVE, MTYPE_NONSYMMETRIC,
     &     PARDISO_SET_SYSTEM, PARDISO_FACTOR_LOADED, PARDISO_SOLVE,
     &     PARDISO_RELEASE
      USE MUL2_KINEMATICS, ONLY: ANY_FIELD_ACTIVE                        ! Use from module mul2 kinematics: any field active.
      USE MUL2_DYNAMIC_COMMON, ONLY: BUILD_DOF_CLASSES,                  ! Use from module mul2 dynamic common: build dof classes, build damping values.
     &     BUILD_DAMPING_VALUES
      USE MUL2_TIME_INPUT, ONLY: LOAD_AMPLITUDE, STEP_TIME,              ! Use from module mul2 time input: load amplitude, step time, step is output.
     &                           STEP_IS_OUTPUT
      USE MUL2_POST_OUTPUT, ONLY: WARNING_LIST_TYPE,                     ! Use from module mul2 post output: warning list type, write time step output.
     &                            WRITE_TIME_STEP_OUTPUT
      USE MUL2_ANALYSIS_RESULTS, ONLY: ANALYSIS_RESULTS_TYPE             ! Use from module mul2 analysis results: analysis results type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      REAL(R8), PARAMETER :: GEOMETRIC_TOLERANCE = 1.0E-9_R8             ! Constant real (real64): geometric_tolerance = 1.0e-9.

      PUBLIC :: RUN_TIME_ANALYSIS                                        ! Export: run time analysis.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE RUN_TIME_ANALYSIS(MODEL, CACHE, RESULTS, WARNINGS,      ! Subroutine run time analysis takes model, cache, results, warnings, status.
     &                             STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(INOUT) :: RESULTS              ! In/out of type analysis_results_type: results.
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(SPARSE_SYSTEM_TYPE) :: SOLVER_SYSTEM                          ! Of type sparse_system_type: solver_system.
      TYPE(PARDISO_FACTOR_TYPE) :: FACTOR                                ! Of type pardiso_factor_type: factor.
      INTEGER(I4), ALLOCATABLE :: CLASS(:)                               ! Allocatable integer (int32): class(:).
      REAL(R8), ALLOCATABLE :: KEFF(:)                                   ! Allocatable real (real64): keff(:).
      REAL(R8), ALLOCATABLE :: CDAMP(:)                                  ! Allocatable real (real64): cdamp(:).
      REAL(R8), ALLOCATABLE :: X(:)                                      ! Allocatable real (real64): x(:).
      REAL(R8), ALLOCATABLE :: X_NEW(:)                                  ! Allocatable real (real64): x_new(:).
      REAL(R8), ALLOCATABLE :: VEL(:)                                    ! Allocatable real (real64): vel(:).
      REAL(R8), ALLOCATABLE :: ACC(:)                                    ! Allocatable real (real64): acc(:).
      REAL(R8), ALLOCATABLE :: RATE(:)                                   ! Allocatable real (real64): rate(:).
      REAL(R8), ALLOCATABLE :: UTILDE(:)                                 ! Allocatable real (real64): utilde(:).
      REAL(R8), ALLOCATABLE :: VTILDE(:)                                 ! Allocatable real (real64): vtilde(:).
      REAL(R8), ALLOCATABLE :: TTILDE(:)                                 ! Allocatable real (real64): ttilde(:).
      REAL(R8), ALLOCATABLE :: W1(:)                                     ! Allocatable real (real64): w1(:).
      REAL(R8), ALLOCATABLE :: W2(:)                                     ! Allocatable real (real64): w2(:).
      REAL(R8), ALLOCATABLE :: RHS(:)                                    ! Allocatable real (real64): rhs(:).
      REAL(R8), ALLOCATABLE :: WORK(:)                                   ! Allocatable real (real64): work(:).
      REAL(R8), ALLOCATABLE :: GVEC(:)                                   ! Allocatable real (real64): gvec(:).
      REAL(R8) :: BETA                                                   ! Real (real64): beta.
      REAL(R8) :: GAMMA                                                  ! Real (real64): gamma.
      REAL(R8) :: THETA                                                  ! Real (real64): theta.
      REAL(R8) :: T0                                                     ! Real (real64): t0.
      REAL(R8) :: ALPHA_M                                                ! Real (real64): alpha_m.
      REAL(R8) :: BETA_K                                                 ! Real (real64): beta_k.
      REAL(R8) :: DT                                                     ! Real (real64): dt.
      REAL(R8) :: AMPLITUDE                                              ! Real (real64): amplitude.
      REAL(R8) :: CM                                                     ! Real (real64): cm.
      INTEGER(I8) :: N                                                   ! Integer (int64): n.
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: POS                                                 ! Integer (int64): pos.
      INTEGER(I8) :: COL                                                 ! Integer (int64): col.
      INTEGER(I8) :: OTHER                                               ! Integer (int64): other.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: STEP                                                ! Integer (int32): step.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      LOGICAL :: HAS_TEMPERATURE                                         ! Logical: has_temperature.
      CHARACTER(LEN=128) :: MESSAGE                                      ! Character (length 128): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      RESULTS%SOLUTION_ID = 104_I4                                       ! Set results.solution_id to 104.
      HAS_TEMPERATURE = ANY_FIELD_ACTIVE(MODEL%KINEMATICS, 4_I4)         ! Set has_temperature to any_field_active(model.kinematics, 4).

      CALL ASSEMBLE_MODEL_SYSTEM(MODEL, CACHE, RESULTS%SYSTEM,           ! Call assemble model system with model, cache, results.system, local_status, with_mass=true, thermoelastic=h...
     &     LOCAL_STATUS, WITH_MASS=.TRUE.,
     &     THERMOELASTIC=HAS_TEMPERATURE)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_MECHANICAL_BOUNDARY_DATA(MODEL%BOUNDARIES,              ! Call build mechanical boundary data with model.boundaries, model.nodes, model.elements, model.kinematics, m...
     &     MODEL%NODES, MODEL%ELEMENTS, MODEL%KINEMATICS,
     &     MODEL%EXPANSIONS, CACHE%FRAMES, CACHE%DOF_LAYOUT,
     &     GEOMETRIC_TOLERANCE, RESULTS%CONSTRAINTS, RESULTS%FORCE,
     &     LOCAL_STATUS, MODEL%FIELDS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL APPLY_SURFACE_LOADS(MODEL, CACHE, RESULTS%SYSTEM,             ! Call apply surface loads with model, cache, results.system, results.force, local_status.
     &     RESULTS%FORCE, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (RESULTS%CONSTRAINTS%HAS_TIES) THEN                             ! If results.constraints.has_ties:
        CALL SET_ERROR(STATUS, 'RUN_TIME_ANALYSIS',                      ! Record an error in status: 'FLOATING ELECTRODES (V-FLOAT) ARE NOT SUPPORTED BY 104'.
     &    'FLOATING ELECTRODES (V-FLOAT) ARE NOT SUPPORTED BY 104')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (RESULTS%CONSTRAINTS%COUNT .LT. 1_I8) THEN                      ! If results.constraints.count < 1:
        CALL SET_ERROR(STATUS, 'RUN_TIME_ANALYSIS',                      ! Record an error in status: 'NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR'.
     &    'NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      N = RESULTS%SYSTEM%ORDER                                           ! Set n to results.system.order.
      CALL BUILD_DOF_CLASSES(SIZE(MODEL%NODES%ITEM), CACHE%DOF_LAYOUT,   ! Call build dof classes with size(model.nodes.item), cache.dof_layout, n, class, local_status.
     &                       N, CLASS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      BETA = MODEL%TIME%NEWMARK_BETA                                     ! Set beta to model.time.newmark_beta.
      GAMMA = MODEL%TIME%NEWMARK_GAMMA                                   ! Set gamma to model.time.newmark_gamma.
      THETA = MODEL%TIME%THETA                                           ! Set theta to model.time.theta.
      T0 = MODEL%TIME%REFERENCE_TEMPERATURE                              ! Set t0 to model.time.reference_temperature.
      ALPHA_M = MODEL%MATERIALS%DAMP_MASS                                ! Set alpha_m to model.materials.damp_mass.
      BETA_K = MODEL%MATERIALS%DAMP_STIFFNESS                            ! Set beta_k to model.materials.damp_stiffness.
      IF (MODEL%TIME%HAS_RAYLEIGH) THEN                                  ! If model.time.has_rayleigh:
        ALPHA_M = MODEL%TIME%RAYLEIGH_MASS                               ! Set alpha_m to model.time.rayleigh_mass.
        BETA_K = MODEL%TIME%RAYLEIGH_STIFFNESS                           ! Set beta_k to model.time.rayleigh_stiffness.
      END IF                                                             ! End of the IF block.
      DT = (MODEL%TIME%FINAL_TIME-MODEL%TIME%INITIAL_TIME)/              ! Set dt to (model.time.final_time-model.time.initial_time)/ real(model.time.step_count,r8).
     &     REAL(MODEL%TIME%STEP_COUNT,R8)

!     EFFECTIVE MATRIX AND DAMPING MATRIX ON THE PATTERN OF K.
      CALL BUILD_DAMPING_VALUES(RESULTS%SYSTEM, CLASS, ALPHA_M, BETA_K,  ! Call build damping values with results.system, class, alpha_m, beta_k, t0, cdamp.
     &                          T0, CDAMP)
      ALLOCATE(KEFF(RESULTS%SYSTEM%NONZERO_COUNT))                       ! Allocate memory for keff(results.system.nonzero_count).
!     ROWS ARE INDEPENDENT: THE LOOP IS PARALLEL.
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(ROW,POS,CM)
!$OMP& SCHEDULE(STATIC)
      DO ROW = 1_I8, N                                                   ! Loop row from 1 to n:
        DO POS = RESULTS%SYSTEM%ROW_POINTER(ROW),                        ! Loop pos from results.system.row_pointer(row) to results.system.row_pointer(row+1)-1:
     &           RESULTS%SYSTEM%ROW_POINTER(ROW+1_I8)-1_I8
          SELECT CASE (CLASS(ROW))                                       ! Choose according to the value of class(row):
          CASE (1_I4)                                                    ! Case 1:
            CM = 1.0_R8/(BETA*DT*DT)                                     ! Set cm to 1.0/(beta*dt*dt).
          CASE (2_I4)                                                    ! Case 2:
            CM = 1.0_R8/(THETA*DT)                                       ! Set cm to 1.0/(theta*dt).
          CASE DEFAULT                                                   ! In every other case:
            CM = 0.0_R8                                                  ! Set cm to zero.
          END SELECT                                                     ! End of the case selection.
          KEFF(POS) = RESULTS%SYSTEM%STIFFNESS(POS) +                    ! Set keff(pos) to results.system.stiffness(pos) + cm*results.system.mass(pos) + gamma/(beta*dt)*cdamp(pos).
     &      CM*RESULTS%SYSTEM%MASS(POS) +
     &      GAMMA/(BETA*DT)*CDAMP(POS)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
!$OMP END PARALLEL DO

!     SOLVER MATRIX: CONSTRAINED ROWS AND COLUMNS REMOVED.
      SOLVER_SYSTEM%ORDER = N                                            ! Set solver_system.order to n.
      SOLVER_SYSTEM%NONZERO_COUNT = RESULTS%SYSTEM%NONZERO_COUNT         ! Set solver_system.nonzero_count to results.system.nonzero_count.
      ALLOCATE(SOLVER_SYSTEM%ROW_POINTER(N+1_I8))                        ! Allocate memory for solver_system.row_pointer(n+1).
      ALLOCATE(SOLVER_SYSTEM%COLUMN_INDEX(                               ! Allocate memory for solver_system.column_index( results.system.nonzero_count).
     &         RESULTS%SYSTEM%NONZERO_COUNT))
      ALLOCATE(SOLVER_SYSTEM%STIFFNESS(RESULTS%SYSTEM%NONZERO_COUNT))    ! Allocate memory for solver_system.stiffness(results.system.nonzero_count).
      SOLVER_SYSTEM%ROW_POINTER = RESULTS%SYSTEM%ROW_POINTER             ! Set solver_system.row_pointer to results.system.row_pointer.
      SOLVER_SYSTEM%COLUMN_INDEX = RESULTS%SYSTEM%COLUMN_INDEX           ! Set solver_system.column_index to results.system.column_index.
      SOLVER_SYSTEM%STIFFNESS = KEFF                                     ! Set solver_system.stiffness to keff.
      ALLOCATE(RHS(N), WORK(N), GVEC(N))                                 ! Allocate memory for rhs(n), work(n), gvec(n).
      WORK = 0.0_R8                                                      ! Set work to zero.
      CALL APPLY_STATIC_CONSTRAINTS(SOLVER_SYSTEM, WORK,                 ! Call apply static constraints with solver_system, work, results.constraints, local_status.
     &     RESULTS%CONSTRAINTS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL PARDISO_SET_SYSTEM(N, SOLVER_SYSTEM%ROW_POINTER,              ! Call pardiso set system with n, solver_system.row_pointer, solver_system.column_index, solver_system.stiffn...
     &     SOLVER_SYSTEM%COLUMN_INDEX, SOLVER_SYSTEM%STIFFNESS, FACTOR,
     &     LOCAL_STATUS, FULL=HAS_TEMPERATURE)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      DEALLOCATE(SOLVER_SYSTEM%STIFFNESS)                                ! Free the memory of solver_system.stiffness.
      IF (HAS_TEMPERATURE) THEN                                          ! If has_temperature:
        CALL PARDISO_FACTOR_LOADED(MTYPE_NONSYMMETRIC, FACTOR,           ! Call pardiso factor loaded with mtype_nonsymmetric, factor, local_status.
     &                             LOCAL_STATUS)
      ELSE                                                               ! Otherwise:
        CALL PARDISO_FACTOR_LOADED(MTYPE_SYMMETRIC_POSITIVE, FACTOR,     ! Call pardiso factor loaded with mtype_symmetric_positive, factor, local_status.
     &                             LOCAL_STATUS)
      END IF                                                             ! End of the IF block.
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

!     INITIAL STATE.
      ALLOCATE(X(N), X_NEW(N), VEL(N), ACC(N), RATE(N))                  ! Allocate memory for x(n), x_new(n), vel(n), acc(n), rate(n).
      ALLOCATE(UTILDE(N), VTILDE(N), TTILDE(N), W1(N), W2(N))            ! Allocate memory for utilde(n), vtilde(n), ttilde(n), w1(n), w2(n).
      VEL = 0.0_R8                                                       ! Set vel to zero.
      ACC = 0.0_R8                                                       ! Set acc to zero.
      RATE = 0.0_R8                                                      ! Set rate to zero.
      AMPLITUDE = LOAD_AMPLITUDE(MODEL%TIME, 0_I4)                       ! Set amplitude to load_amplitude(model.time, 0).
      X = 0.0_R8                                                         ! Set x to zero.
      WHERE (RESULTS%CONSTRAINTS%ACTIVE) X =                             ! Where results.constraints.active: set x to amplitude*results.constraints.value.
     &  AMPLITUDE*RESULTS%CONSTRAINTS%VALUE
      CALL INITIAL_ACCELERATION(RESULTS, CLASS, X, AMPLITUDE, ACC,       ! Call initial acceleration with results, class, x, amplitude, acc, local_status.
     &                          LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        CALL PARDISO_RELEASE(FACTOR)                                     ! Call pardiso release with factor.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL WRITE_TIME_STEP_OUTPUT(MODEL, CACHE, X, 0_I4,                 ! Call write time step output with model, cache, x, 0, step_time(model.time,0), warnings, local_status.
     &     STEP_TIME(MODEL%TIME,0_I4), WARNINGS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.

      DO STEP = 1_I4, MODEL%TIME%STEP_COUNT                              ! Loop step from 1 to model.time.step_count:
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        AMPLITUDE = LOAD_AMPLITUDE(MODEL%TIME, STEP)                     ! Set amplitude to load_amplitude(model.time, step).
!       PREDICTORS.
        UTILDE = 0.0_R8                                                  ! Set utilde to zero.
        VTILDE = 0.0_R8                                                  ! Set vtilde to zero.
        TTILDE = 0.0_R8                                                  ! Set ttilde to zero.
        W1 = 0.0_R8                                                      ! Set w1 to zero.
        W2 = 0.0_R8                                                      ! Set w2 to zero.
        DO ROW = 1_I8, N                                                 ! Loop row from 1 to n:
          SELECT CASE (CLASS(ROW))                                       ! Choose according to the value of class(row):
          CASE (1_I4)                                                    ! Case 1:
            UTILDE(ROW) = X(ROW) + DT*VEL(ROW) +                         ! Set utilde(row) to x(row) + dt*vel(row) + dt*dt*(0.5-beta)*acc(row).
     &                    DT*DT*(0.5_R8-BETA)*ACC(ROW)
            VTILDE(ROW) = VEL(ROW) + DT*(1.0_R8-GAMMA)*ACC(ROW)          ! Set vtilde(row) to vel(row) + dt*(1.0-gamma)*acc(row).
            W1(ROW) = UTILDE(ROW)/(BETA*DT*DT)                           ! Set w1(row) to utilde(row)/(beta*dt*dt).
            W2(ROW) = GAMMA*UTILDE(ROW)/(BETA*DT) - VTILDE(ROW)          ! Set w2(row) to gamma*utilde(row)/(beta*dt) - vtilde(row).
          CASE (2_I4)                                                    ! Case 2:
            TTILDE(ROW) = X(ROW) + DT*(1.0_R8-THETA)*RATE(ROW)           ! Set ttilde(row) to x(row) + dt*(1.0-theta)*rate(row).
            W1(ROW) = TTILDE(ROW)/(THETA*DT)                             ! Set w1(row) to ttilde(row)/(theta*dt).
          END SELECT                                                     ! End of the case selection.
        END DO                                                           ! End of the loop.
        CALL SPARSE_MULTIPLY(N, RESULTS%SYSTEM%ROW_POINTER,              ! Call sparse multiply with n, results.system.row_pointer, results.system.column_index, results.system.mass, ...
     &       RESULTS%SYSTEM%COLUMN_INDEX, RESULTS%SYSTEM%MASS, W1,
     &       RHS)
        CALL SPARSE_MULTIPLY(N, RESULTS%SYSTEM%ROW_POINTER,              ! Call sparse multiply with n, results.system.row_pointer, results.system.column_index, cdamp, w2, work.
     &       RESULTS%SYSTEM%COLUMN_INDEX, CDAMP, W2, WORK)
        RHS = RHS + WORK + AMPLITUDE*RESULTS%FORCE                       ! Add work + amplitude*results.force to rhs.
!       PRESCRIBED VALUES OF THIS STEP.
        GVEC = 0.0_R8                                                    ! Set gvec to zero.
        WHERE (RESULTS%CONSTRAINTS%ACTIVE) GVEC =                        ! Where results.constraints.active: set gvec to amplitude*results.constraints.value.
     &    AMPLITUDE*RESULTS%CONSTRAINTS%VALUE
        CALL SPARSE_MULTIPLY(N, RESULTS%SYSTEM%ROW_POINTER,              ! Call sparse multiply with n, results.system.row_pointer, results.system.column_index, keff, gvec, work.
     &       RESULTS%SYSTEM%COLUMN_INDEX, KEFF, GVEC, WORK)
        WHERE (.NOT. RESULTS%CONSTRAINTS%ACTIVE) RHS = RHS - WORK        ! Where not results.constraints.active: subtract work from rhs.
        WHERE (RESULTS%CONSTRAINTS%ACTIVE) RHS = GVEC                    ! Where results.constraints.active: set rhs to gvec.
        CALL PARDISO_SOLVE(FACTOR, RHS, X_NEW, LOCAL_STATUS)             ! Call pardiso solve with factor, rhs, x_new, local_status.
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
!       CORRECTORS.
        DO ROW = 1_I8, N                                                 ! Loop row from 1 to n:
          SELECT CASE (CLASS(ROW))                                       ! Choose according to the value of class(row):
          CASE (1_I4)                                                    ! Case 1:
            ACC(ROW) = (X_NEW(ROW)-UTILDE(ROW))/(BETA*DT*DT)             ! Set acc(row) to (x_new(row)-utilde(row))/(beta*dt*dt).
            VEL(ROW) = VTILDE(ROW) + GAMMA*DT*ACC(ROW)                   ! Set vel(row) to vtilde(row) + gamma*dt*acc(row).
          CASE (2_I4)                                                    ! Case 2:
            RATE(ROW) = (X_NEW(ROW)-TTILDE(ROW))/(THETA*DT)              ! Set rate(row) to (x_new(row)-ttilde(row))/(theta*dt).
          END SELECT                                                     ! End of the case selection.
        END DO                                                           ! End of the loop.
        X = X_NEW                                                        ! Set x to x_new.
        IF (STEP_IS_OUTPUT(MODEL%TIME, STEP)) THEN                       ! If step_is_output(model.time, step):
          CALL WRITE_TIME_STEP_OUTPUT(MODEL, CACHE, X, STEP,             ! Call write time step output with model, cache, x, step, step_time(model.time,step), warnings, local_status.
     &         STEP_TIME(MODEL%TIME,STEP), WARNINGS, LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL PARDISO_RELEASE(FACTOR)                                       ! Call pardiso release with factor.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (ALLOCATED(RESULTS%SOLUTION)) DEALLOCATE(RESULTS%SOLUTION)      ! If allocated(results.solution), free the memory of results.solution.
      ALLOCATE(RESULTS%SOLUTION(N))                                      ! Allocate memory for results.solution(n).
      RESULTS%SOLUTION = X                                               ! Set results.solution to x.
      WRITE(MESSAGE,'(A,I0,A,ES11.4,A,ES11.4)') 'TIME RESPONSE: ',       ! Format into the text message: 'TIME RESPONSE: ', model.time.step_count, ' STEPS, DT = ', dt, ', MAX |X| = '...
     &  MODEL%TIME%STEP_COUNT, ' STEPS, DT = ', DT,
     &  ', MAX |X| = ', MAXVAL(ABS(X))
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      END SUBROUTINE RUN_TIME_ANALYSIS                                   ! End of the subroutine run time analysis.

!  A(0) FROM M A = F - K X (FREE MECHANICAL DOFS ONLY).
      SUBROUTINE INITIAL_ACCELERATION(RESULTS, CLASS, X, AMPLITUDE,      ! Subroutine initial acceleration takes results, class, x, amplitude, acc, status.
     &                                ACC, STATUS)

      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(IN) :: RESULTS                 ! Input of type analysis_results_type: results.
      INTEGER(I4), INTENT(IN) :: CLASS(:)                                ! Input integer (int32): class(:).
      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(IN) :: AMPLITUDE                                  ! Input real (real64): amplitude.
      REAL(R8), INTENT(INOUT) :: ACC(:)                                  ! In/out real (real64): acc(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(REDUCED_PATTERN_TYPE) :: PATTERN                              ! Of type reduced_pattern_type: pattern.
      LOGICAL, ALLOCATABLE :: EXCLUDED(:)                                ! Allocatable logical: excluded(:).
      REAL(R8), ALLOCATABLE :: R(:)                                      ! Allocatable real (real64): r(:).
      REAL(R8), ALLOCATABLE :: R_FREE(:)                                 ! Allocatable real (real64): r_free(:).
      REAL(R8), ALLOCATABLE :: A_FREE(:)                                 ! Allocatable real (real64): a_free(:).
      REAL(R8), ALLOCATABLE :: M_FREE(:)                                 ! Allocatable real (real64): m_free(:).
      TYPE(PARDISO_FACTOR_TYPE) :: FACTOR                                ! Of type pardiso_factor_type: factor.
      INTEGER(I8) :: N                                                   ! Integer (int64): n.
      INTEGER(I8) :: I                                                   ! Integer (int64): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N = RESULTS%SYSTEM%ORDER                                           ! Set n to results.system.order.
      ALLOCATE(EXCLUDED(N), R(N))                                        ! Allocate memory for excluded(n), r(n).
      EXCLUDED = CLASS .NE. 1_I4 .OR. RESULTS%CONSTRAINTS%ACTIVE         ! Set excluded to class /= 1 or results.constraints.active.
      IF (ALL(EXCLUDED)) RETURN                                          ! If all(excluded), return to the caller.
      CALL SPARSE_MULTIPLY(N, RESULTS%SYSTEM%ROW_POINTER,                ! Call sparse multiply with n, results.system.row_pointer, results.system.column_index, results.system.stiffn...
     &     RESULTS%SYSTEM%COLUMN_INDEX, RESULTS%SYSTEM%STIFFNESS, X, R)
      R = AMPLITUDE*RESULTS%FORCE - R                                    ! Set r to amplitude*results.force - r.
      CALL BUILD_REDUCED_PATTERN(N, RESULTS%SYSTEM%ROW_POINTER,          ! Call build reduced pattern with n, results.system.row_pointer, results.system.column_index, excluded, pattern.
     &     RESULTS%SYSTEM%COLUMN_INDEX, EXCLUDED, PATTERN)
      ALLOCATE(M_FREE(PATTERN%NONZERO_COUNT))                            ! Allocate memory for m_free(pattern.nonzero_count).
      CALL REDUCE_VALUES(PATTERN, RESULTS%SYSTEM%MASS, M_FREE)           ! Call reduce values with pattern, results.system.mass, m_free.
      ALLOCATE(R_FREE(PATTERN%ORDER), A_FREE(PATTERN%ORDER))             ! Allocate memory for r_free(pattern.order), a_free(pattern.order).
      DO I = 1_I8, PATTERN%ORDER                                         ! Loop i from 1 to pattern.order:
        R_FREE(I) = R(PATTERN%FREE_TO_GLOBAL(I))                         ! Set r_free(i) to r(pattern.free_to_global(i)).
      END DO                                                             ! End of the loop.
      CALL PARDISO_SET_SYSTEM(PATTERN%ORDER, PATTERN%ROW_POINTER,        ! Call pardiso set system with pattern.order, pattern.row_pointer, pattern.column_index, m_free, factor, status.
     &     PATTERN%COLUMN_INDEX, M_FREE, FACTOR, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL PARDISO_FACTOR_LOADED(MTYPE_SYMMETRIC_POSITIVE, FACTOR,       ! Call pardiso factor loaded with mtype_symmetric_positive, factor, status.
     &                           STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL PARDISO_SOLVE(FACTOR, R_FREE, A_FREE, STATUS)                 ! Call pardiso solve with factor, r_free, a_free, status.
      CALL PARDISO_RELEASE(FACTOR)                                       ! Call pardiso release with factor.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      DO I = 1_I8, PATTERN%ORDER                                         ! Loop i from 1 to pattern.order:
        ACC(PATTERN%FREE_TO_GLOBAL(I)) = A_FREE(I)                       ! Set acc(pattern.free_to_global(i)) to a_free(i).
      END DO                                                             ! End of the loop.

      END SUBROUTINE INITIAL_ACCELERATION                                ! End of the subroutine initial acceleration.

      END MODULE MUL2_ANALYSIS_104                                       ! End of the module mul2 analysis 104.
