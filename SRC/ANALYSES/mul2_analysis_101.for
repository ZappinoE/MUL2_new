!=======================================================================
!  SOLUTION 101: LINEAR STATIC MECHANICAL ANALYSIS.
!
!      ASSEMBLE K -> LOADS AND BOUNDARY CONDITIONS -> EXACT SYMMETRIC
!      ELIMINATION -> PARDISO -> DISPLACEMENT COEFFICIENTS
!=======================================================================
      MODULE MUL2_ANALYSIS_101                                           ! Module mul2 analysis 101 begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok, merge status.
     &                       STATUS_IS_OK, MERGE_STATUS
      USE MUL2_LOG, ONLY: LOG_INFO                                       ! Use from module mul2 log: log info.
      USE MUL2_TIMER, ONLY: TIMER_TYPE, TIMER_START, TIMER_STOP,         ! Use from module mul2 timer: timer type, timer start, timer stop, timer wall seconds.
     &                      TIMER_WALL_SECONDS
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE                       ! Use from module mul2 model cache: model cache type.
      USE MUL2_MODEL_ASSEMBLY, ONLY: ASSEMBLE_MODEL_SYSTEM               ! Use from module mul2 model assembly: assemble model system.
      USE MUL2_KINEMATICS, ONLY: ANY_FIELD_ACTIVE                        ! Use from module mul2 kinematics: any field active.
      USE MUL2_SURFACE_LOADS, ONLY: APPLY_SURFACE_LOADS                  ! Use from module mul2 surface loads: apply surface loads.
      USE MUL2_PARDISO_FACTOR, ONLY: PARDISO_FACTOR_TYPE,                ! Use from module mul2 pardiso factor: pardiso factor type, mtype nonsymmetric, pardiso set system, pardiso f...
     &     MTYPE_NONSYMMETRIC, PARDISO_SET_SYSTEM,
     &     PARDISO_FACTOR_LOADED, PARDISO_SOLVE, PARDISO_RELEASE
      USE MUL2_BOUNDARY_APPLICATION, ONLY:                               ! Use from module mul2 boundary application: build mechanical boundary data, apply static constraints, apply ...
     &     BUILD_MECHANICAL_BOUNDARY_DATA, APPLY_STATIC_CONSTRAINTS,
     &     APPLY_DOF_TIES, EXPAND_TIES
      USE MUL2_PARDISO_SOLVER, ONLY: SOLVE_SYMMETRIC_POSITIVE_DEFINITE   ! Use from module mul2 pardiso solver: solve symmetric positive definite.
      USE MUL2_ANALYSIS_RESULTS, ONLY: ANALYSIS_RESULTS_TYPE             ! Use from module mul2 analysis results: analysis results type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      REAL(R8), PARAMETER :: GEOMETRIC_TOLERANCE = 1.0E-9_R8             ! Constant real (real64): geometric_tolerance = 1.0e-9.

      PUBLIC :: RUN_STATIC_ANALYSIS                                      ! Export: run static analysis.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE RUN_STATIC_ANALYSIS(MODEL, CACHE, RESULTS, STATUS)      ! Subroutine run static analysis takes model, cache, results, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(INOUT) :: RESULTS              ! In/out of type analysis_results_type: results.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(TIMER_TYPE) :: TIMER                                          ! Of type timer_type: timer.
      CHARACTER(LEN=128) :: MESSAGE                                      ! Character (length 128): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      RESULTS%SOLUTION_ID = 101_I4                                       ! Set results.solution_id to 101.

      CALL TIMER_START(TIMER, 'K ASSEMBLY')                              ! Call timer start with timer, 'K ASSEMBLY'.
!     THE MASS MATRIX IS ONLY BUILT WHEN ITS DUMP IS REQUESTED.
      CALL ASSEMBLE_MODEL_SYSTEM(MODEL, CACHE, RESULTS%SYSTEM,           ! Call assemble model system with model, cache, results.system, local_status, with_mass=model.post.write_mass...
     &                           LOCAL_STATUS,
     &                           WITH_MASS=MODEL%POST%WRITE_MASS,
     &                           THERMOELASTIC=ANY_FIELD_ACTIVE(
     &                           MODEL%KINEMATICS,4_I4))
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      RESULTS%ASSEMBLY_SECONDS = TIMER_WALL_SECONDS(TIMER)               ! Set results.assembly_seconds to timer_wall_seconds(timer).
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      WRITE(MESSAGE,'(A,I0,A,I0,A,F9.3,A)') 'K ASSEMBLED: ',             ! Format into the text message: 'K ASSEMBLED: ', results.system.order, ' DOF, ', results.system.nonzero_count...
     &  RESULTS%SYSTEM%ORDER, ' DOF, ', RESULTS%SYSTEM%NONZERO_COUNT,
     &  ' NNZ, ', RESULTS%ASSEMBLY_SECONDS, ' S'
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      CALL BUILD_MECHANICAL_BOUNDARY_DATA(MODEL%BOUNDARIES,              ! Call build mechanical boundary data with model.boundaries, model.nodes, model.elements, model.kinematics, m...
     &     MODEL%NODES, MODEL%ELEMENTS, MODEL%KINEMATICS,
     &     MODEL%EXPANSIONS, CACHE%FRAMES, CACHE%DOF_LAYOUT,
     &     GEOMETRIC_TOLERANCE, RESULTS%CONSTRAINTS, RESULTS%FORCE,
     &     LOCAL_STATUS, MODEL%FIELDS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (RESULTS%CONSTRAINTS%COUNT .LT. 1_I8) THEN                      ! If results.constraints.count < 1:
        CALL SET_ERROR(STATUS, 'RUN_STATIC_ANALYSIS',                    ! Record an error in status: 'NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR'.
     &    'NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL APPLY_SURFACE_LOADS(MODEL, CACHE, RESULTS%SYSTEM,             ! Call apply surface loads with model, cache, results.system, results.force, local_status.
     &     RESULTS%FORCE, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL APPLY_DOF_TIES(RESULTS%SYSTEM, RESULTS%FORCE,                 ! Call apply dof ties with results.system, results.force, results.constraints, local_status.
     &     RESULTS%CONSTRAINTS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL APPLY_STATIC_CONSTRAINTS(RESULTS%SYSTEM, RESULTS%FORCE,       ! Call apply static constraints with results.system, results.force, results.constraints, local_status.
     &     RESULTS%CONSTRAINTS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL TIMER_START(TIMER, 'SOLVER')                                  ! Call timer start with timer, 'SOLVER'.
      IF (ANY_FIELD_ACTIVE(MODEL%KINEMATICS,4_I4)) THEN                  ! If any_field_active(model.kinematics,4):
        CALL SOLVE_THERMOELASTIC(RESULTS, LOCAL_STATUS)                  ! Call solve thermoelastic with results, local_status.
      ELSE                                                               ! Otherwise:
        CALL SOLVE_SYMMETRIC_POSITIVE_DEFINITE(RESULTS%SYSTEM,           ! Call solve symmetric positive definite with results.system, results.force, results.solution, local_status, ...
     &     RESULTS%FORCE, RESULTS%SOLUTION, LOCAL_STATUS,
     &     RELEASE_SYSTEM=.NOT. (MODEL%POST%WRITE_STIFFNESS .OR.
     &                           MODEL%POST%WRITE_MASS))
      END IF                                                             ! End of the IF block.
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      RESULTS%SOLVER_SECONDS = TIMER_WALL_SECONDS(TIMER)                 ! Set results.solver_seconds to timer_wall_seconds(timer).
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (ANY(RESULTS%SOLUTION .NE. RESULTS%SOLUTION) .OR.               ! If any(results.solution /= results.solution) or any(abs(results.solution) > huge(1.0)):
     &    ANY(ABS(RESULTS%SOLUTION) .GT. HUGE(1.0_R8))) THEN
        CALL SET_ERROR(STATUS, 'RUN_STATIC_ANALYSIS',                    ! Record an error in status: 'THE SOLUTION CONTAINS NAN OR INFINITY'.
     &                 'THE SOLUTION CONTAINS NAN OR INFINITY')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL EXPAND_TIES(RESULTS%CONSTRAINTS, RESULTS%SOLUTION)            ! Call expand ties with results.constraints, results.solution.
      WRITE(MESSAGE,'(A,F9.3,A,ES12.4)') 'STATIC SOLVE: ',               ! Format into the text message: 'STATIC SOLVE: ', results.solver_seconds, ' S, MAX |U| = ', maxval(abs(result...
     &  RESULTS%SOLVER_SECONDS, ' S, MAX |U| = ',
     &  MAXVAL(ABS(RESULTS%SOLUTION))
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      END SUBROUTINE RUN_STATIC_ANALYSIS                                 ! End of the subroutine run static analysis.

!  MONOLITHIC THERMOELASTICITY: THE SYSTEM
!      [ K_UU  K_UT ] [U]   [F]
!      [  0    K_TT ] [T] = [Q]
!  IS NON-SYMMETRIC AND SOLVED IN ONE PARDISO FACTORIZATION (MTYPE 11).
      SUBROUTINE SOLVE_THERMOELASTIC(RESULTS, STATUS)                    ! Subroutine solve thermoelastic takes results, status.

      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(INOUT) :: RESULTS              ! In/out of type analysis_results_type: results.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PARDISO_FACTOR_TYPE) :: FACTOR                                ! Of type pardiso_factor_type: factor.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL PARDISO_SET_SYSTEM(RESULTS%SYSTEM%ORDER,                      ! Call pardiso set system with results.system.order, results.system.row_pointer, results.system.column_index,...
     &     RESULTS%SYSTEM%ROW_POINTER, RESULTS%SYSTEM%COLUMN_INDEX,
     &     RESULTS%SYSTEM%STIFFNESS, FACTOR, STATUS, FULL=.TRUE.)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL PARDISO_FACTOR_LOADED(MTYPE_NONSYMMETRIC, FACTOR, STATUS)     ! Call pardiso factor loaded with mtype_nonsymmetric, factor, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (ALLOCATED(RESULTS%SOLUTION)) DEALLOCATE(RESULTS%SOLUTION)      ! If allocated(results.solution), free the memory of results.solution.
      ALLOCATE(RESULTS%SOLUTION(RESULTS%SYSTEM%ORDER))                   ! Allocate memory for results.solution(results.system.order).
      CALL PARDISO_SOLVE(FACTOR, RESULTS%FORCE, RESULTS%SOLUTION,        ! Call pardiso solve with factor, results.force, results.solution, status.
     &                   STATUS)
      CALL PARDISO_RELEASE(FACTOR)                                       ! Call pardiso release with factor.

      END SUBROUTINE SOLVE_THERMOELASTIC                                 ! End of the subroutine solve thermoelastic.

      END MODULE MUL2_ANALYSIS_101                                       ! End of the module mul2 analysis 101.
