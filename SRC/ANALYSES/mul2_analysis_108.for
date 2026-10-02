!=======================================================================
!  SOLUTION 108: GEOMETRICALLY NONLINEAR STATIC (TOTAL LAGRANGIAN).
!
!  NEWTON-RAPHSON WITH LOAD / DISPLACEMENT INCREMENTS. EVERY LOAD AND
!  PRESCRIBED VALUE IS SCALED BY THE FACTOR LAMBDA = N / NLSTEP OF STEP
!  N; THE PHYSICS ARE THOSE OF 101 (MECHANICAL, ELECTRIC POTENTIAL,
!  TEMPERATURE, SURFACE HEAT LOADS) IN THE ONE MONOLITHIC SYSTEM
!      R = LAMBDA F - F_INT(X) - KS X = 0,   K_T DX = R
!  WITH F_INT FROM THE GREEN STRAIN AND THE PK2 STRESS OF THE MATERIAL
!  (ST. VENANT-KIRCHHOFF). THE TANGENT IS RE-FACTORED AT EVERY
!  ITERATION. KS IS THE (LINEAR) CONVECTION OF THE SURFACE LOADS.
!  SOLVTEC 2 OF NL_INFO.DAT SELECTS THE ARC-LENGTH METHOD (CRISFIELD,
!  CYLINDRICAL CONSTRAINT ON THE DISPLACEMENTS, ADAPTIVE STEP): LAMBDA
!  BECOMES AN UNKNOWN AND THE PATH CAN PASS LIMIT POINTS (SNAP-THROUGH,
!  SNAP-BACK). IT NEEDS ZERO PRESCRIBED VALUES (THE LOAD IS THE
!  PARAMETER).
!  OUTPUT PER POST STEP: DYNAMIC/TIME_HISTORY.dat (THE TIME COLUMN IS
!  LAMBDA) AND, AT THE END, THE STATIC FILES. STRESSES AND STRAINS OF
!  THE OUTPUT ARE THE LINEARISED MEASURES OF THE FINAL DISPLACEMENTS.
!=======================================================================
      MODULE MUL2_ANALYSIS_108                                           ! Module mul2 analysis 108 begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok, merge status.
     &                       STATUS_IS_OK, MERGE_STATUS
      USE MUL2_LOG, ONLY: LOG_INFO                                       ! Use from module mul2 log: log info.
      USE MUL2_TIMER, ONLY: TIMER_TYPE, TIMER_START, TIMER_STOP,         ! Use from module mul2 timer: timer type, timer start, timer stop, timer wall seconds.
     &                      TIMER_WALL_SECONDS
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE                       ! Use from module mul2 model cache: model cache type.
      USE MUL2_MODEL_ASSEMBLY, ONLY: ASSEMBLE_MODEL_SYSTEM,              ! Use from module mul2 model assembly: assemble model system, assemble nonlinear values.
     &                               ASSEMBLE_NONLINEAR_VALUES
      USE MUL2_BOUNDARY_APPLICATION, ONLY:                               ! Use from module mul2 boundary application: build mechanical boundary data, apply static constraints, constr...
     &     BUILD_MECHANICAL_BOUNDARY_DATA, APPLY_STATIC_CONSTRAINTS,
     &     CONSTRAINT_SET_TYPE
      USE MUL2_SURFACE_LOADS, ONLY: APPLY_SURFACE_LOADS                  ! Use from module mul2 surface loads: apply surface loads.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_SPARSE_OPERATIONS, ONLY: SPARSE_MULTIPLY                  ! Use from module mul2 sparse operations: sparse multiply.
      USE MUL2_PARDISO_FACTOR, ONLY: PARDISO_FACTOR_TYPE,                ! Use from module mul2 pardiso factor: pardiso factor type, mtype symmetric positive, mtype nonsymmetric, par...
     &     MTYPE_SYMMETRIC_POSITIVE, MTYPE_NONSYMMETRIC,
     &     PARDISO_SET_SYSTEM, PARDISO_FACTOR_LOADED, PARDISO_SOLVE,
     &     PARDISO_RELEASE
      USE MUL2_KINEMATICS, ONLY: ANY_FIELD_ACTIVE                        ! Use from module mul2 kinematics: any field active.
      USE MUL2_DYNAMIC_COMMON, ONLY: BUILD_DOF_CLASSES,                  ! Use from module mul2 dynamic common: build dof classes, class displacement.
     &                               CLASS_DISPLACEMENT
      USE MUL2_POST_OUTPUT, ONLY: WARNING_LIST_TYPE,                     ! Use from module mul2 post output: warning list type, write time step output.
     &                            WRITE_TIME_STEP_OUTPUT
      USE MUL2_ANALYSIS_RESULTS, ONLY: ANALYSIS_RESULTS_TYPE             ! Use from module mul2 analysis results: analysis results type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      REAL(R8), PARAMETER :: GEOMETRIC_TOLERANCE = 1.0E-9_R8             ! Constant real (real64): geometric_tolerance = 1.0e-9.

      PUBLIC :: RUN_NONLINEAR_ANALYSIS                                   ! Export: run nonlinear analysis.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE RUN_NONLINEAR_ANALYSIS(MODEL, CACHE, RESULTS, WARNINGS, ! Subroutine run nonlinear analysis takes model, cache, results, warnings, status.
     &                                  STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(INOUT) :: RESULTS              ! In/out of type analysis_results_type: results.
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(SPARSE_SYSTEM_TYPE) :: SURFACE                                ! Of type sparse_system_type: surface.
      TYPE(SPARSE_SYSTEM_TYPE) :: SOLVER                                 ! Of type sparse_system_type: solver.
      TYPE(CONSTRAINT_SET_TYPE) :: ZERO_INCREMENT                        ! Of type constraint_set_type: zero_increment.
      TYPE(PARDISO_FACTOR_TYPE) :: FACTOR                                ! Of type pardiso_factor_type: factor.
      REAL(R8), ALLOCATABLE :: TANGENT(:)                                ! Allocatable real (real64): tangent(:).
      REAL(R8), ALLOCATABLE :: INTERNAL(:)                               ! Allocatable real (real64): internal(:).
      REAL(R8), ALLOCATABLE :: X(:)                                      ! Allocatable real (real64): x(:).
      REAL(R8), ALLOCATABLE :: R(:)                                      ! Allocatable real (real64): r(:).
      REAL(R8), ALLOCATABLE :: DX(:)                                     ! Allocatable real (real64): dx(:).
      REAL(R8), ALLOCATABLE :: WORK(:)                                   ! Allocatable real (real64): work(:).
      REAL(R8), ALLOCATABLE :: SURFACE_FORCE(:)                          ! Allocatable real (real64): surface_force(:).
      TYPE(TIMER_TYPE) :: TIMER                                          ! Of type timer_type: timer.
      REAL(R8) :: ASSEMBLY_SECONDS                                       ! Real (real64): assembly_seconds.
      REAL(R8) :: SOLVE_SECONDS                                          ! Real (real64): solve_seconds.
      REAL(R8) :: LAMBDA                                                 ! Real (real64): lambda.
      REAL(R8) :: RESIDUAL                                               ! Real (real64): residual.
      REAL(R8) :: REFERENCE                                              ! Real (real64): reference.
      REAL(R8) :: FIRST_RESIDUAL                                         ! Real (real64): first_residual.
      INTEGER(I8) :: N                                                   ! Integer (int64): n.
      INTEGER(I4) :: STEP                                                ! Integer (int32): step.
      INTEGER(I4) :: ITERATION                                           ! Integer (int32): iteration.
      INTEGER(I4) :: TOTAL_ITERATIONS                                    ! Integer (int32): total_iterations.
      LOGICAL :: HAS_TEMPERATURE                                         ! Logical: has_temperature.
      LOGICAL :: CONVERGED                                               ! Logical: converged.
      CHARACTER(LEN=128) :: MESSAGE                                      ! Character (length 128): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      RESULTS%SOLUTION_ID = 108_I4                                       ! Set results.solution_id to 108.
      HAS_TEMPERATURE = ANY_FIELD_ACTIVE(MODEL%KINEMATICS, 4_I4)         ! Set has_temperature to any_field_active(model.kinematics, 4).
      CALL ASSEMBLE_MODEL_SYSTEM(MODEL, CACHE, RESULTS%SYSTEM,           ! Call assemble model system with model, cache, results.system, local_status, with_mass=false.
     &     LOCAL_STATUS, WITH_MASS=.FALSE.)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_MECHANICAL_BOUNDARY_DATA(MODEL%BOUNDARIES,              ! Call build mechanical boundary data with model.boundaries, model.nodes, model.elements, model.kinematics, m...
     &     MODEL%NODES, MODEL%ELEMENTS, MODEL%KINEMATICS,
     &     MODEL%EXPANSIONS, CACHE%FRAMES, CACHE%DOF_LAYOUT,
     &     GEOMETRIC_TOLERANCE, RESULTS%CONSTRAINTS, RESULTS%FORCE,
     &     LOCAL_STATUS, MODEL%FIELDS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (RESULTS%CONSTRAINTS%HAS_TIES) THEN                             ! If results.constraints.has_ties:
        CALL SET_ERROR(STATUS, 'RUN_NONLINEAR_ANALYSIS',                 ! Record an error in status: 'FLOATING ELECTRODES (V-FLOAT) ARE NOT SUPPORTED BY 108'.
     &    'FLOATING ELECTRODES (V-FLOAT) ARE NOT SUPPORTED BY 108')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (RESULTS%CONSTRAINTS%COUNT .LT. 1_I8) THEN                      ! If results.constraints.count < 1:
        CALL SET_ERROR(STATUS, 'RUN_NONLINEAR_ANALYSIS',                 ! Record an error in status: 'NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR'.
     &    'NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      N = RESULTS%SYSTEM%ORDER                                           ! Set n to results.system.order.

!     SURFACE LOADS: THE FORCE JOINS F, THE CONVECTION MATRIX IS KEPT
!     SEPARATELY (LINEAR IN THE TEMPERATURE).
      SURFACE%ORDER = N                                                  ! Set surface.order to n.
      SURFACE%NONZERO_COUNT = RESULTS%SYSTEM%NONZERO_COUNT               ! Set surface.nonzero_count to results.system.nonzero_count.
      ALLOCATE(SURFACE%ROW_POINTER(N+1_I8))                              ! Allocate memory for surface.row_pointer(n+1).
      ALLOCATE(SURFACE%COLUMN_INDEX(SURFACE%NONZERO_COUNT))              ! Allocate memory for surface.column_index(surface.nonzero_count).
      ALLOCATE(SURFACE%STIFFNESS(SURFACE%NONZERO_COUNT))                 ! Allocate memory for surface.stiffness(surface.nonzero_count).
      SURFACE%ROW_POINTER = RESULTS%SYSTEM%ROW_POINTER                   ! Set surface.row_pointer to results.system.row_pointer.
      SURFACE%COLUMN_INDEX = RESULTS%SYSTEM%COLUMN_INDEX                 ! Set surface.column_index to results.system.column_index.
      SURFACE%STIFFNESS = 0.0_R8                                         ! Set surface.stiffness to zero.
      ALLOCATE(SURFACE_FORCE(N))                                         ! Allocate memory for surface_force(n).
      SURFACE_FORCE = 0.0_R8                                             ! Set surface_force to zero.
      CALL APPLY_SURFACE_LOADS(MODEL, CACHE, SURFACE, SURFACE_FORCE,     ! Call apply surface loads with model, cache, surface, surface_force, local_status.
     &                         LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      RESULTS%FORCE = RESULTS%FORCE + SURFACE_FORCE                      ! Add surface_force to results.force.

      ALLOCATE(X(N), R(N), DX(N), WORK(N), INTERNAL(N))                  ! Allocate memory for x(n), r(n), dx(n), work(n), internal(n).
      X = 0.0_R8                                                         ! Set x to zero.
      ZERO_INCREMENT%COUNT = RESULTS%CONSTRAINTS%COUNT                   ! Set zero_increment.count to results.constraints.count.
      ALLOCATE(ZERO_INCREMENT%ACTIVE(N), ZERO_INCREMENT%VALUE(N))        ! Allocate memory for zero_increment.active(n), zero_increment.value(n).
      ZERO_INCREMENT%ACTIVE = RESULTS%CONSTRAINTS%ACTIVE                 ! Set zero_increment.active to results.constraints.active.
      ZERO_INCREMENT%VALUE = 0.0_R8                                      ! Set zero_increment.value to zero.
      SOLVER%ORDER = N                                                   ! Set solver.order to n.
      SOLVER%NONZERO_COUNT = RESULTS%SYSTEM%NONZERO_COUNT                ! Set solver.nonzero_count to results.system.nonzero_count.
      ALLOCATE(SOLVER%ROW_POINTER(N+1_I8))                               ! Allocate memory for solver.row_pointer(n+1).
      ALLOCATE(SOLVER%COLUMN_INDEX(SOLVER%NONZERO_COUNT))                ! Allocate memory for solver.column_index(solver.nonzero_count).
      SOLVER%ROW_POINTER = RESULTS%SYSTEM%ROW_POINTER                    ! Set solver.row_pointer to results.system.row_pointer.
      SOLVER%COLUMN_INDEX = RESULTS%SYSTEM%COLUMN_INDEX                  ! Set solver.column_index to results.system.column_index.

      CALL WRITE_TIME_STEP_OUTPUT(MODEL, CACHE, X, 0_I4, 0.0_R8,         ! Call write time step output with model, cache, x, 0, 0.0, warnings, local_status.
     &                            WARNINGS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      TOTAL_ITERATIONS = 0_I4                                            ! Set total_iterations to zero.
      ASSEMBLY_SECONDS = 0.0_R8                                          ! Set assembly_seconds to zero.
      SOLVE_SECONDS = 0.0_R8                                             ! Set solve_seconds to zero.
      REFERENCE = 0.0_R8                                                 ! Set reference to zero.
      IF (MODEL%NL%TECHNIQUE .EQ. 2_I4) THEN                             ! If model.nl.technique = 2:
        CALL ARC_LENGTH_STEPS(MODEL, CACHE, RESULTS, SURFACE, SOLVER,    ! Call arc length steps with model, cache, results, surface, solver, zero_increment, has_temperature, x, tota...
     &       ZERO_INCREMENT, HAS_TEMPERATURE, X, TOTAL_ITERATIONS,
     &       ASSEMBLY_SECONDS, SOLVE_SECONDS, WARNINGS, LOCAL_STATUS)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
      END IF                                                             ! End of the IF block.
      DO STEP = 1_I4, MERGE(MODEL%NL%STEP_COUNT, 0_I4,                   ! Loop step from 1 to merge(model.nl.step_count, 0, model.nl.technique = 1):
     &                      MODEL%NL%TECHNIQUE .EQ. 1_I4)
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        LAMBDA = REAL(STEP,R8)/REAL(MODEL%NL%STEP_COUNT,R8)              ! Set lambda to real(step,r8)/real(model.nl.step_count,r8).
        WHERE (RESULTS%CONSTRAINTS%ACTIVE) X =                           ! Where results.constraints.active: set x to lambda*results.constraints.value.
     &    LAMBDA*RESULTS%CONSTRAINTS%VALUE
        CONVERGED = .FALSE.                                              ! Set the flag converged to false.
        FIRST_RESIDUAL = 0.0_R8                                          ! Set first_residual to zero.
        DO ITERATION = 1_I4, MODEL%NL%MAX_ITERATIONS                     ! Loop iteration from 1 to model.nl.max_iterations:
          CALL TIMER_START(TIMER, 'NL ASSEMBLY')                         ! Call timer start with timer, 'NL ASSEMBLY'.
          CALL ASSEMBLE_NONLINEAR_VALUES(MODEL, CACHE, X,                ! Call assemble nonlinear values with model, cache, x, results.system, tangent, internal, local_status.
     &         RESULTS%SYSTEM, TANGENT, INTERNAL, LOCAL_STATUS)
          CALL TIMER_STOP(TIMER)                                         ! Call timer stop with timer.
          ASSEMBLY_SECONDS = ASSEMBLY_SECONDS +                          ! Add timer_wall_seconds(timer) to assembly_seconds.
     &                       TIMER_WALL_SECONDS(TIMER)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                           ! If not status is ok, leave the loop.
          TANGENT = TANGENT + SURFACE%STIFFNESS                          ! Add surface.stiffness to tangent.
          CALL SPARSE_MULTIPLY(N, SURFACE%ROW_POINTER,                   ! Call sparse multiply with n, surface.row_pointer, surface.column_index, surface.stiffness, x, work.
     &         SURFACE%COLUMN_INDEX, SURFACE%STIFFNESS, X, WORK)
          R = LAMBDA*RESULTS%FORCE - INTERNAL - WORK                     ! Set r to lambda*results.force - internal - work.
          WHERE (RESULTS%CONSTRAINTS%ACTIVE) R = 0.0_R8                  ! Where results.constraints.active: set r to zero.
          RESIDUAL = SQRT(SUM(R*R))                                      ! Set residual to the square root of sum(r*r).
!         THE REFERENCE IS THE LARGEST FORCE SEEN SO FAR (A SELF-
!         EQUILIBRATED THERMAL LOAD HAS NO EXTERNAL FORCE AND ITS
!         INTERNAL FORCE VANISHES AT CONVERGENCE).
          REFERENCE = MAX(REFERENCE, SQRT(SUM((LAMBDA*                   ! Set reference to max(reference, sqrt(sum((lambda* results.force)**2)), sqrt(sum(internal* internal)), tiny(...
     &                RESULTS%FORCE)**2)), SQRT(SUM(INTERNAL*
     &                INTERNAL)), TINY(1.0_R8))
          IF (ITERATION .EQ. 1_I4) FIRST_RESIDUAL = RESIDUAL             ! If iteration = 1, set first_residual to residual.
          WRITE(MESSAGE,'(A,I0,A,I0,A,ES11.4)') '  STEP ', STEP,         ! Format into the text message: ' STEP ', step, ' ITERATION ', iteration, ': RELATIVE RESIDUAL ', residual/ma...
     &      ' ITERATION ', ITERATION, ': RELATIVE RESIDUAL ',
     &      RESIDUAL/MAX(REFERENCE,TINY(1.0_R8))
          CALL LOG_INFO(MESSAGE)                                         ! Log: message.
          IF (RESIDUAL .LE. MODEL%NL%TOLERANCE*REFERENCE) THEN           ! If residual <= model.nl.tolerance*reference:
            CONVERGED = .TRUE.                                           ! Set the flag converged to true.
            EXIT                                                         ! Leave the loop.
          END IF                                                         ! End of the IF block.
          CALL TIMER_START(TIMER, 'NL SOLVE')                            ! Call timer start with timer, 'NL SOLVE'.
          SOLVER%STIFFNESS = TANGENT                                     ! Set solver.stiffness to tangent.
          CALL APPLY_STATIC_CONSTRAINTS(SOLVER, R, ZERO_INCREMENT,       ! Call apply static constraints with solver, r, zero_increment, local_status.
     &                                  LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                           ! If not status is ok, leave the loop.
          CALL PARDISO_SET_SYSTEM(N, SOLVER%ROW_POINTER,                 ! Call pardiso set system with n, solver.row_pointer, solver.column_index, solver.stiffness, factor, local_st...
     &         SOLVER%COLUMN_INDEX, SOLVER%STIFFNESS, FACTOR,
     &         LOCAL_STATUS, FULL=HAS_TEMPERATURE)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                           ! If not status is ok, leave the loop.
          IF (HAS_TEMPERATURE) THEN                                      ! If has_temperature:
            CALL PARDISO_FACTOR_LOADED(MTYPE_NONSYMMETRIC, FACTOR,       ! Call pardiso factor loaded with mtype_nonsymmetric, factor, local_status.
     &                                 LOCAL_STATUS)
          ELSE                                                           ! Otherwise:
            CALL PARDISO_FACTOR_LOADED(MTYPE_SYMMETRIC_POSITIVE,         ! Call pardiso factor loaded with mtype_symmetric_positive, factor, local_status.
     &                                 FACTOR, LOCAL_STATUS)
          END IF                                                         ! End of the IF block.
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                           ! If not status is ok, leave the loop.
          CALL PARDISO_SOLVE(FACTOR, R, DX, LOCAL_STATUS)                ! Call pardiso solve with factor, r, dx, local_status.
          CALL PARDISO_RELEASE(FACTOR)                                   ! Call pardiso release with factor.
          CALL TIMER_STOP(TIMER)                                         ! Call timer stop with timer.
          SOLVE_SECONDS = SOLVE_SECONDS + TIMER_WALL_SECONDS(TIMER)      ! Add timer_wall_seconds(timer) to solve_seconds.
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                           ! If not status is ok, leave the loop.
          WRITE(MESSAGE,'(A,ES11.4,A,ES11.4)') '    MAX DX ',            ! Format into the text message: ' MAX DX ', maxval(abs(dx)), ' MAX R ', maxval(abs(r)).
     &      MAXVAL(ABS(DX)), ' MAX R ', MAXVAL(ABS(R))
          CALL LOG_INFO(MESSAGE)                                         ! Log: message.
          X = X + DX                                                     ! Add dx to x.
          TOTAL_ITERATIONS = TOTAL_ITERATIONS + 1_I4                     ! Add 1 to total_iterations.
        END DO                                                           ! End of the loop.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        IF (.NOT. CONVERGED) THEN                                        ! If not converged:
          WRITE(MESSAGE,'(A,I0,A,F8.4,A,ES10.3)')                        ! Format into the text message: 'NEWTON-RAPHSON DID NOT CONVERGE IN STEP ', step, ' (LAMBDA ', lambda, '), RE...
     &      'NEWTON-RAPHSON DID NOT CONVERGE IN STEP ', STEP,
     &      ' (LAMBDA ', LAMBDA, '), RESIDUAL ',
     &      RESIDUAL/MAX(REFERENCE,TINY(1.0_R8))
          CALL SET_ERROR(STATUS, 'RUN_NONLINEAR_ANALYSIS',               ! Record an error in status: trim(message).
     &                   TRIM(MESSAGE))
          EXIT                                                           ! Leave the loop.
        END IF                                                           ! End of the IF block.
        WRITE(MESSAGE,'(A,I0,A,F8.4,A,I0,A)') 'NL STEP ', STEP,          ! Format into the text message: 'NL STEP ', step, ' LAMBDA ', lambda, ': CONVERGED IN ', iteration-1, ' ITERA...
     &    ' LAMBDA ', LAMBDA, ': CONVERGED IN ', ITERATION-1_I4,
     &    ' ITERATIONS'
        CALL LOG_INFO(MESSAGE)                                           ! Log: message.
        IF (MOD(STEP,MODEL%NL%POST_EVERY) .EQ. 0_I4 .OR.                 ! If mod(step,model.nl.post_every) = 0 or step = model.nl.step_count:
     &      STEP .EQ. MODEL%NL%STEP_COUNT) THEN
          CALL WRITE_TIME_STEP_OUTPUT(MODEL, CACHE, X, STEP, LAMBDA,     ! Call write time step output with model, cache, x, step, lambda, warnings, local_status.
     &         WARNINGS, LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (ALLOCATED(RESULTS%SOLUTION)) DEALLOCATE(RESULTS%SOLUTION)      ! If allocated(results.solution), free the memory of results.solution.
      ALLOCATE(RESULTS%SOLUTION(N))                                      ! Allocate memory for results.solution(n).
      RESULTS%SOLUTION = X                                               ! Set results.solution to x.
      WRITE(MESSAGE,'(A,I0,A,I0,A,ES11.4)') 'NONLINEAR STATIC: ',        ! Format into the text message: 'NONLINEAR STATIC: ', model.nl.step_count, ' STEPS, ', total_iterations, ' IT...
     &  MODEL%NL%STEP_COUNT, ' STEPS, ', TOTAL_ITERATIONS,
     &  ' ITERATIONS, MAX |X| = ', MAXVAL(ABS(X))
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.
      WRITE(MESSAGE,'(A,F9.3,A,F9.3,A)') 'NL TIMES: ASSEMBLY ',          ! Format into the text message: 'NL TIMES: ASSEMBLY ', assembly_seconds, ' S, FACTOR+SOLVE ', solve_seconds, ...
     &  ASSEMBLY_SECONDS, ' S, FACTOR+SOLVE ', SOLVE_SECONDS, ' S'
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      END SUBROUTINE RUN_NONLINEAR_ANALYSIS                              ! End of the subroutine run nonlinear analysis.

!  FACTORISES THE TANGENT ONCE AND SOLVES FOR TWO RIGHT-HAND SIDES
!  (THE RESIDUAL AND THE REFERENCE LOAD). THE PRESCRIBED INCREMENTS ARE
!  ZERO, SO THE CONSTRAINED ENTRIES OF BOTH SOLUTIONS ARE ZERO.
      SUBROUTINE SOLVE_TWO(SOLVER, ZERO_INCREMENT, TANGENT,              ! Subroutine solve two takes solver, zero increment, tangent, has temperature, rhs a, rhs b, sol a, sol b, st...
     &                     HAS_TEMPERATURE, RHS_A, RHS_B, SOL_A, SOL_B,
     &                     STATUS)

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SOLVER                  ! In/out of type sparse_system_type: solver.
      TYPE(CONSTRAINT_SET_TYPE), INTENT(IN) :: ZERO_INCREMENT            ! Input of type constraint_set_type: zero_increment.
      REAL(R8), INTENT(IN) :: TANGENT(:)                                 ! Input real (real64): tangent(:).
      LOGICAL, INTENT(IN) :: HAS_TEMPERATURE                             ! Input logical: has_temperature.
      REAL(R8), INTENT(INOUT) :: RHS_A(:)                                ! In/out real (real64): rhs_a(:).
      REAL(R8), INTENT(IN) :: RHS_B(:)                                   ! Input real (real64): rhs_b(:).
      REAL(R8), INTENT(OUT) :: SOL_A(:)                                  ! Output real (real64): sol_a(:).
      REAL(R8), INTENT(OUT) :: SOL_B(:)                                  ! Output real (real64): sol_b(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(PARDISO_FACTOR_TYPE) :: FACTOR                                ! Of type pardiso_factor_type: factor.
      REAL(R8), ALLOCATABLE :: B(:)                                      ! Allocatable real (real64): b(:).

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      SOLVER%STIFFNESS = TANGENT                                         ! Set solver.stiffness to tangent.
      CALL APPLY_STATIC_CONSTRAINTS(SOLVER, RHS_A, ZERO_INCREMENT,       ! Call apply static constraints with solver, rhs_a, zero_increment, local_status.
     &                              LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL PARDISO_SET_SYSTEM(SOLVER%ORDER, SOLVER%ROW_POINTER,          ! Call pardiso set system with solver.order, solver.row_pointer, solver.column_index, solver.stiffness, facto...
     &     SOLVER%COLUMN_INDEX, SOLVER%STIFFNESS, FACTOR,
     &     LOCAL_STATUS, FULL=HAS_TEMPERATURE)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (HAS_TEMPERATURE) THEN                                          ! If has_temperature:
        CALL PARDISO_FACTOR_LOADED(MTYPE_NONSYMMETRIC, FACTOR,           ! Call pardiso factor loaded with mtype_nonsymmetric, factor, local_status.
     &                             LOCAL_STATUS)
      ELSE                                                               ! Otherwise:
        CALL PARDISO_FACTOR_LOADED(MTYPE_SYMMETRIC_POSITIVE, FACTOR,     ! Call pardiso factor loaded with mtype_symmetric_positive, factor, local_status.
     &                             LOCAL_STATUS)
      END IF                                                             ! End of the IF block.
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL PARDISO_SOLVE(FACTOR, RHS_A, SOL_A, LOCAL_STATUS)             ! Call pardiso solve with factor, rhs_a, sol_a, local_status.
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (STATUS_IS_OK(STATUS)) THEN                                     ! If status is ok:
        ALLOCATE(B(SIZE(RHS_B)))                                         ! Allocate memory for b(size(rhs_b)).
        B = RHS_B                                                        ! Set b to rhs_b.
        WHERE (ZERO_INCREMENT%ACTIVE) B = 0.0_R8                         ! Where zero_increment.active: set b to zero.
        CALL PARDISO_SOLVE(FACTOR, B, SOL_B, LOCAL_STATUS)               ! Call pardiso solve with factor, b, sol_b, local_status.
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
      END IF                                                             ! End of the IF block.
      CALL PARDISO_RELEASE(FACTOR)                                       ! Call pardiso release with factor.

      END SUBROUTINE SOLVE_TWO                                           ! End of the subroutine solve two.

!  ARC-LENGTH PATH FOLLOWING (CRISFIELD, CYLINDRICAL CONSTRAINT
!  |DU|^2 = DS^2 ON THE DISPLACEMENT DEGREES OF FREEDOM). THE REFERENCE
!  LOAD IS THE FORCE OF THE MODEL (LAMBDA = 1); THE PATH ENDS WHEN
!  LAMBDA REACHES LAMBDA_MAX OR AFTER NLSTEP STEPS (LAMBDA MAY BECOME
!  NEGATIVE ON THE WAY: SNAP-BACK, INVERTED SNAP-THROUGH). A STEP THAT DOES NOT CONVERGE IS REPEATED WITH HALF THE ARC
!  LENGTH; AFTER A CONVERGED STEP DS IS RESCALED BY SQRT(5/ITERATIONS).
      SUBROUTINE ARC_LENGTH_STEPS(MODEL, CACHE, RESULTS, SURFACE,        ! Subroutine arc length steps takes model, cache, results, surface, solver, zero increment, has temperature, ...
     &     SOLVER, ZERO_INCREMENT, HAS_TEMPERATURE, X, TOTAL_ITERATIONS,
     &     ASSEMBLY_SECONDS, SOLVE_SECONDS, WARNINGS, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(INOUT) :: RESULTS              ! In/out of type analysis_results_type: results.
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(IN) :: SURFACE                    ! Input of type sparse_system_type: surface.
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SOLVER                  ! In/out of type sparse_system_type: solver.
      TYPE(CONSTRAINT_SET_TYPE), INTENT(IN) :: ZERO_INCREMENT            ! Input of type constraint_set_type: zero_increment.
      LOGICAL, INTENT(IN) :: HAS_TEMPERATURE                             ! Input logical: has_temperature.
      REAL(R8), INTENT(INOUT) :: X(:)                                    ! In/out real (real64): x(:).
      INTEGER(I4), INTENT(INOUT) :: TOTAL_ITERATIONS                     ! In/out integer (int32): total_iterations.
      REAL(R8), INTENT(INOUT) :: ASSEMBLY_SECONDS                        ! In/out real (real64): assembly_seconds.
      REAL(R8), INTENT(INOUT) :: SOLVE_SECONDS                           ! In/out real (real64): solve_seconds.
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(TIMER_TYPE) :: TIMER                                          ! Of type timer_type: timer.
      REAL(R8), ALLOCATABLE :: TANGENT(:)                                ! Allocatable real (real64): tangent(:).
      REAL(R8), ALLOCATABLE :: INTERNAL(:)                               ! Allocatable real (real64): internal(:).
      REAL(R8), ALLOCATABLE :: R(:)                                      ! Allocatable real (real64): r(:).
      REAL(R8), ALLOCATABLE :: WORK(:)                                   ! Allocatable real (real64): work(:).
      REAL(R8), ALLOCATABLE :: FREF(:)                                   ! Allocatable real (real64): fref(:).
      REAL(R8), ALLOCATABLE :: UF(:)                                     ! Allocatable real (real64): uf(:).
      REAL(R8), ALLOCATABLE :: UR(:)                                     ! Allocatable real (real64): ur(:).
      REAL(R8), ALLOCATABLE :: DU(:)                                     ! Allocatable real (real64): du(:).
      REAL(R8), ALLOCATABLE :: PREVIOUS(:)                               ! Allocatable real (real64): previous(:).
      REAL(R8), ALLOCATABLE :: X0(:)                                     ! Allocatable real (real64): x0(:).
      REAL(R8), ALLOCATABLE :: XT(:)                                     ! Allocatable real (real64): xt(:).
      REAL(R8), ALLOCATABLE :: WEIGHT(:)                                 ! Allocatable real (real64): weight(:).
      INTEGER(I4), ALLOCATABLE :: CLASS(:)                               ! Allocatable integer (int32): class(:).
      REAL(R8) :: LAMBDA                                                 ! Real (real64): lambda.
      REAL(R8) :: LAMBDA0                                                ! Real (real64): lambda0.
      REAL(R8) :: DLAMBDA                                                ! Real (real64): dlambda.
      REAL(R8) :: DS                                                     ! Real (real64): ds.
      REAL(R8) :: DS_STEP                                                ! Real (real64): ds_step.
      REAL(R8) :: DS_MIN                                                 ! Real (real64): ds_min.
      REAL(R8) :: DS_MAX                                                 ! Real (real64): ds_max.
      REAL(R8) :: LAMBDA_MAX                                             ! Real (real64): lambda_max.
      REAL(R8) :: RESIDUAL                                               ! Real (real64): residual.
      REAL(R8) :: REFERENCE                                              ! Real (real64): reference.
      REAL(R8) :: A                                                      ! Real (real64): a.
      REAL(R8) :: B                                                      ! Real (real64): b.
      REAL(R8) :: C                                                      ! Real (real64): c.
      REAL(R8) :: DISC                                                   ! Real (real64): disc.
      REAL(R8) :: T1                                                     ! Real (real64): t1.
      REAL(R8) :: T2                                                     ! Real (real64): t2.
      REAL(R8) :: SIGN_DIR                                               ! Real (real64): sign_dir.
      REAL(R8) :: NORM_UF                                                ! Real (real64): norm_uf.
      INTEGER(I8) :: N                                                   ! Integer (int64): n.
      INTEGER(I4) :: STEP                                                ! Integer (int32): step.
      INTEGER(I4) :: ITERATION                                           ! Integer (int32): iteration.
      INTEGER(I4) :: CUTS                                                ! Integer (int32): cuts.
      LOGICAL :: CONVERGED                                               ! Logical: converged.
      LOGICAL :: FINISHED                                                ! Logical: finished.
      CHARACTER(LEN=160) :: MESSAGE                                      ! Character (length 160): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N = SIZE(X, KIND=I8)                                               ! Set n to size(x, kind=i8).
      IF (ANY(RESULTS%CONSTRAINTS%ACTIVE .AND.                           ! If any(results.constraints.active and results.constraints.value /= 0.0):
     &        RESULTS%CONSTRAINTS%VALUE .NE. 0.0_R8)) THEN
        CALL SET_ERROR(STATUS, 'ARC_LENGTH_STEPS',                       ! Record an error in status: 'ARC LENGTH NEEDS ZERO PRESCRIBED VALUES (LOAD PARAMETER)'.
     &    'ARC LENGTH NEEDS ZERO PRESCRIBED VALUES (LOAD PARAMETER)')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL BUILD_DOF_CLASSES(SIZE(MODEL%NODES%ITEM), CACHE%DOF_LAYOUT,   ! Call build dof classes with size(model.nodes.item), cache.dof_layout, n, class, local_status.
     &                       N, CLASS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      ALLOCATE(WEIGHT(N), FREF(N))                                       ! Allocate memory for weight(n), fref(n).
      ALLOCATE(TANGENT(RESULTS%SYSTEM%NONZERO_COUNT))                    ! Allocate memory for tangent(results.system.nonzero_count).
      ALLOCATE(INTERNAL(N), R(N), WORK(N), UF(N), UR(N), DU(N))          ! Allocate memory for internal(n), r(n), work(n), uf(n), ur(n), du(n).
      ALLOCATE(PREVIOUS(N), X0(N), XT(N))                                ! Allocate memory for previous(n), x0(n), xt(n).
      WEIGHT = MERGE(1.0_R8, 0.0_R8, CLASS .EQ. CLASS_DISPLACEMENT)      ! Set weight to 1.0 if class = class_displacement, otherwise 0.0.
      WHERE (RESULTS%CONSTRAINTS%ACTIVE) WEIGHT = 0.0_R8                 ! Where results.constraints.active: set weight to zero.
      FREF = RESULTS%FORCE                                               ! Set fref to results.force.
      WHERE (RESULTS%CONSTRAINTS%ACTIVE) FREF = 0.0_R8                   ! Where results.constraints.active: set fref to zero.
      LAMBDA_MAX = MODEL%NL%LAMBDA_MAX                                   ! Set lambda_max to model.nl.lambda_max.
      LAMBDA = 0.0_R8                                                    ! Set lambda to zero.
      X = 0.0_R8                                                         ! Set x to zero.
      REFERENCE = 0.0_R8                                                 ! Set reference to zero.
      DS = MODEL%NL%ARC_LENGTH                                           ! Set ds to model.nl.arc_length.
      DS_MIN = MODEL%NL%ARC_LENGTH_MIN                                   ! Set ds_min to model.nl.arc_length_min.
      DS_MAX = MODEL%NL%ARC_LENGTH_MAX                                   ! Set ds_max to model.nl.arc_length_max.
      PREVIOUS = 0.0_R8                                                  ! Set previous to zero.
      FINISHED = .FALSE.                                                 ! Set the flag finished to false.

      DO STEP = 1_I4, MODEL%NL%STEP_COUNT                                ! Loop step from 1 to model.nl.step_count:
        IF (FINISHED) EXIT                                               ! If finished, leave the loop.
        X0 = X                                                           ! Set x0 to x.
        LAMBDA0 = LAMBDA                                                 ! Set lambda0 to lambda.
        CUTS = 0_I4                                                      ! Set cuts to zero.
        DO                                                               ! Loop until an EXIT statement is reached:
!         TANGENT AT THE LAST CONVERGED STATE AND THE PREDICTOR.
          CALL TIMER_START(TIMER, 'NL ASSEMBLY')                         ! Call timer start with timer, 'NL ASSEMBLY'.
          CALL ASSEMBLE_NONLINEAR_VALUES(MODEL, CACHE, X0,               ! Call assemble nonlinear values with model, cache, x0, results.system, tangent, internal, local_status.
     &         RESULTS%SYSTEM, TANGENT, INTERNAL, LOCAL_STATUS)
          CALL TIMER_STOP(TIMER)                                         ! Call timer stop with timer.
          ASSEMBLY_SECONDS = ASSEMBLY_SECONDS +                          ! Add timer_wall_seconds(timer) to assembly_seconds.
     &                       TIMER_WALL_SECONDS(TIMER)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          TANGENT = TANGENT + SURFACE%STIFFNESS                          ! Add surface.stiffness to tangent.
          R = 0.0_R8                                                     ! Set r to zero.
          CALL TIMER_START(TIMER, 'NL SOLVE')                            ! Call timer start with timer, 'NL SOLVE'.
          CALL SOLVE_TWO(SOLVER, ZERO_INCREMENT, TANGENT,                ! Call solve two with solver, zero_increment, tangent, has_temperature, r, fref, ur, uf, local_status.
     &         HAS_TEMPERATURE, R, FREF, UR, UF, LOCAL_STATUS)
          CALL TIMER_STOP(TIMER)                                         ! Call timer stop with timer.
          SOLVE_SECONDS = SOLVE_SECONDS + TIMER_WALL_SECONDS(TIMER)      ! Add timer_wall_seconds(timer) to solve_seconds.
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          NORM_UF = SQRT(DOT_PRODUCT(UF, WEIGHT*UF))                     ! Set norm_uf to the square root of dot_product(uf, weight*uf).
          IF (NORM_UF .LE. TINY(1.0_R8)) THEN                            ! If norm_uf <= tiny(1.0):
            CALL SET_ERROR(STATUS, 'ARC_LENGTH_STEPS',                   ! Record an error in status: 'THE REFERENCE LOAD PRODUCES NO DISPLACEMENT'.
     &        'THE REFERENCE LOAD PRODUCES NO DISPLACEMENT')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          IF (DS .LE. 0.0_R8) DS = NORM_UF*LAMBDA_MAX/10.0_R8            ! If ds <= 0.0, set ds to norm_uf*lambda_max/10.0.
          IF (DS_MIN .LE. 0.0_R8) DS_MIN = DS*1.0E-4_R8                  ! If ds_min <= 0.0, set ds_min to ds*1.0e-4.
          IF (DS_MAX .LE. 0.0_R8) DS_MAX = DS*10.0_R8                    ! If ds_max <= 0.0, set ds_max to ds*10.0.
          IF (STEP .EQ. 1_I4 .AND. CUTS .EQ. 0_I4) PREVIOUS = UF         ! If step = 1 and cuts = 0, set previous to uf.
          SIGN_DIR = SIGN(1.0_R8, DOT_PRODUCT(UF, WEIGHT*PREVIOUS))      ! Set sign_dir to sign(1.0, dot_product(uf, weight*previous)).
          DS_STEP = DS                                                   ! Set ds_step to ds.
          DLAMBDA = SIGN_DIR*DS_STEP/NORM_UF                             ! Set dlambda to sign_dir*ds_step/norm_uf.
          IF (LAMBDA0+DLAMBDA .GT. LAMBDA_MAX) THEN                      ! If lambda0+dlambda > lambda_max:
            DS_STEP = DS_STEP*(LAMBDA_MAX-LAMBDA0)/DLAMBDA               ! Multiply ds_step by (lambda_max-lambda0)/dlambda.
            DLAMBDA = LAMBDA_MAX - LAMBDA0                               ! Set dlambda to lambda_max - lambda0.
          END IF                                                         ! End of the IF block.
          DU = DLAMBDA*UF                                                ! Set du to dlambda*uf.
          CONVERGED = .FALSE.                                            ! Set the flag converged to false.
          DO ITERATION = 1_I4, MODEL%NL%MAX_ITERATIONS                   ! Loop iteration from 1 to model.nl.max_iterations:
            XT = X0 + DU                                                 ! Set xt to x0 + du.
            CALL TIMER_START(TIMER, 'NL ASSEMBLY')                       ! Call timer start with timer, 'NL ASSEMBLY'.
            CALL ASSEMBLE_NONLINEAR_VALUES(MODEL, CACHE, XT,             ! Call assemble nonlinear values with model, cache, xt, results.system, tangent, internal, local_status.
     &           RESULTS%SYSTEM, TANGENT, INTERNAL, LOCAL_STATUS)
            CALL TIMER_STOP(TIMER)                                       ! Call timer stop with timer.
            ASSEMBLY_SECONDS = ASSEMBLY_SECONDS +                        ! Add timer_wall_seconds(timer) to assembly_seconds.
     &                         TIMER_WALL_SECONDS(TIMER)
            CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                      ! Merge status local_status into status.
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            TANGENT = TANGENT + SURFACE%STIFFNESS                        ! Add surface.stiffness to tangent.
            CALL SPARSE_MULTIPLY(N, SURFACE%ROW_POINTER,                 ! Call sparse multiply with n, surface.row_pointer, surface.column_index, surface.stiffness, xt, work.
     &           SURFACE%COLUMN_INDEX, SURFACE%STIFFNESS, XT, WORK)
            R = (LAMBDA0+DLAMBDA)*FREF - INTERNAL - WORK                 ! Set r to (lambda0+dlambda)*fref - internal - work.
            WHERE (RESULTS%CONSTRAINTS%ACTIVE) R = 0.0_R8                ! Where results.constraints.active: set r to zero.
            RESIDUAL = SQRT(SUM(R*R))                                    ! Set residual to the square root of sum(r*r).
            REFERENCE = MAX(REFERENCE, SQRT(SUM(((LAMBDA0+DLAMBDA)*      ! Set reference to max(reference, sqrt(sum(((lambda0+dlambda)* fref)**2)), sqrt(sum(internal*internal)), tiny...
     &                  FREF)**2)), SQRT(SUM(INTERNAL*INTERNAL)),
     &                  TINY(1.0_R8))
            IF (RESIDUAL .LE. MODEL%NL%TOLERANCE*REFERENCE) THEN         ! If residual <= model.nl.tolerance*reference:
              CONVERGED = .TRUE.                                         ! Set the flag converged to true.
              EXIT                                                       ! Leave the loop.
            END IF                                                       ! End of the IF block.
            CALL TIMER_START(TIMER, 'NL SOLVE')                          ! Call timer start with timer, 'NL SOLVE'.
            CALL SOLVE_TWO(SOLVER, ZERO_INCREMENT, TANGENT,              ! Call solve two with solver, zero_increment, tangent, has_temperature, r, fref, ur, uf, local_status.
     &           HAS_TEMPERATURE, R, FREF, UR, UF, LOCAL_STATUS)
            CALL TIMER_STOP(TIMER)                                       ! Call timer stop with timer.
            SOLVE_SECONDS = SOLVE_SECONDS + TIMER_WALL_SECONDS(TIMER)    ! Add timer_wall_seconds(timer) to solve_seconds.
            CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                      ! Merge status local_status into status.
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            TOTAL_ITERATIONS = TOTAL_ITERATIONS + 1_I4                   ! Add 1 to total_iterations.
!           CYLINDRICAL CONSTRAINT: |DU + UR + T UF|^2 = DS_STEP^2.
            UR = DU + UR                                                 ! Set ur to du + ur.
            A = DOT_PRODUCT(UF, WEIGHT*UF)                               ! Set a to dot_product(uf, weight*uf).
            B = DOT_PRODUCT(UF, WEIGHT*UR)                               ! Set b to dot_product(uf, weight*ur).
            C = DOT_PRODUCT(UR, WEIGHT*UR) - DS_STEP*DS_STEP             ! Set c to dot_product(ur, weight*ur) - ds_step*ds_step.
            DISC = B*B - A*C                                             ! Set disc to b*b - a*c.
            IF (A .LE. TINY(1.0_R8) .OR. DISC .LT. 0.0_R8) THEN          ! If a <= tiny(1.0) or disc < 0.0:
              EXIT                                                       ! Leave the loop.
            END IF                                                       ! End of the IF block.
            T1 = (-B + SQRT(DISC))/A                                     ! Set t1 to (-b + sqrt(disc))/a.
            T2 = (-B - SQRT(DISC))/A                                     ! Set t2 to (-b - sqrt(disc))/a.
!           THE ROOT THAT KEEPS THE DIRECTION OF THE CURRENT INCREMENT.
            IF (DOT_PRODUCT(UR + T1*UF, WEIGHT*DU) .LT.                  ! If dot_product(ur + t1*uf, weight*du) < dot_product(ur + t2*uf, weight*du), set t1 to t2.
     &          DOT_PRODUCT(UR + T2*UF, WEIGHT*DU)) T1 = T2
            DLAMBDA = DLAMBDA + T1                                       ! Add t1 to dlambda.
            DU = UR + T1*UF                                              ! Set du to ur + t1*uf.
          END DO                                                         ! End of the loop.
          IF (CONVERGED) EXIT                                            ! If converged, leave the loop.
          CUTS = CUTS + 1_I4                                             ! Add 1 to cuts.
          DS = 0.5_R8*DS                                                 ! Set ds to 0.5*ds.
          IF (DS .LT. DS_MIN .OR. CUTS .GT. 20_I4) THEN                  ! If ds < ds_min or cuts > 20:
            WRITE(MESSAGE,'(A,I0,A,ES10.3)')                             ! Format into the text message: 'ARC LENGTH DID NOT CONVERGE IN STEP ', step, ' (LAMBDA ', lambda0.
     &        'ARC LENGTH DID NOT CONVERGE IN STEP ', STEP,
     &        ' (LAMBDA ', LAMBDA0
            CALL SET_ERROR(STATUS, 'ARC_LENGTH_STEPS', TRIM(MESSAGE))    ! Record an error in status: trim(message).
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
!       ACCEPT THE STEP.
        X = X0 + DU                                                      ! Set x to x0 + du.
        LAMBDA = LAMBDA0 + DLAMBDA                                       ! Set lambda to lambda0 + dlambda.
        PREVIOUS = DU                                                    ! Set previous to du.
        WRITE(MESSAGE,'(A,I0,A,F9.5,A,I0,A,ES9.2)') 'ARC STEP ', STEP,   ! Format into the text message: 'ARC STEP ', step, ' LAMBDA ', lambda, ': ', iteration-1, ' ITERATIONS, DS ',...
     &    ' LAMBDA ', LAMBDA, ': ', ITERATION-1_I4,
     &    ' ITERATIONS, DS ', DS_STEP
        CALL LOG_INFO(MESSAGE)                                           ! Log: message.
        IF (MOD(STEP,MODEL%NL%POST_EVERY) .EQ. 0_I4 .OR.                 ! If mod(step,model.nl.post_every) = 0 or lambda >= lambda_max*(1.0-1.0e-9) or step = model.nl.step_count:
     &      LAMBDA .GE. LAMBDA_MAX*(1.0_R8-1.0E-9_R8) .OR.
     &      STEP .EQ. MODEL%NL%STEP_COUNT) THEN
          CALL WRITE_TIME_STEP_OUTPUT(MODEL, CACHE, X, STEP, LAMBDA,     ! Call write time step output with model, cache, x, step, lambda, warnings, local_status.
     &         WARNINGS, LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
        END IF                                                           ! End of the IF block.
        IF (LAMBDA .GE. LAMBDA_MAX*(1.0_R8-1.0E-9_R8)) FINISHED = .TRUE. ! If lambda >= lambda_max*(1.0-1.0e-9), set the flag finished to true.
        DS = DS_STEP*SQRT(5.0_R8/REAL(MAX(ITERATION-1_I4,1_I4),R8))      ! Set ds to ds_step*sqrt(5.0/real(max(iteration-1,1),r8)).
        DS = MIN(DS_MAX, MAX(DS_MIN, DS))                                ! Set ds to the smaller of ds_max and max(ds_min, ds).
        X0 = X                                                           ! Set x0 to x.
      END DO                                                             ! End of the loop.
      IF (.NOT. FINISHED) THEN                                           ! If not finished:
        CALL LOG_INFO('ARC LENGTH: MAXIMUM NUMBER OF STEPS REACHED')     ! Log: 'ARC LENGTH: MAXIMUM NUMBER OF STEPS REACHED'.
      END IF                                                             ! End of the IF block.
      WRITE(MESSAGE,'(A,F9.5)') 'ARC LENGTH: FINAL LAMBDA ', LAMBDA      ! Format into the text message: 'ARC LENGTH: FINAL LAMBDA ', lambda.
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      END SUBROUTINE ARC_LENGTH_STEPS                                    ! End of the subroutine arc length steps.

      END MODULE MUL2_ANALYSIS_108                                       ! End of the module mul2 analysis 108.
