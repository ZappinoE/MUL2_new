!=======================================================================
!  SOLUTION 103: LINEAR FREE VIBRATIONS.
!
!      ASSEMBLE K, M -> ELIMINATE CONSTRAINED DOFS -> ARPACK/PARDISO
!      -> EXPAND MODES -> FREQUENCIES  F = SQRT(LAMBDA) / (2 PI)
!
!  CONSTRAINED DOFS ARE REMOVED FROM THE PROBLEM (THE BASELINE ADDS A
!  LARGE PENALTY TO K INSTEAD). PRESCRIBED NON-ZERO DISPLACEMENTS AND
!  FORCES HAVE NO MEANING HERE AND ARE IGNORED WITH A WARNING.
!=======================================================================
      MODULE MUL2_ANALYSIS_103                                           ! Module mul2 analysis 103 begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, set warning, status is ok, merge status.
     &                       SET_WARNING, STATUS_IS_OK, MERGE_STATUS
      USE MUL2_LOG, ONLY: LOG_INFO                                       ! Use from module mul2 log: log info.
      USE MUL2_TIMER, ONLY: TIMER_TYPE, TIMER_START, TIMER_STOP,         ! Use from module mul2 timer: timer type, timer start, timer stop, timer wall seconds.
     &                      TIMER_WALL_SECONDS
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_KINEMATICS, ONLY: ANY_FIELD_ACTIVE                        ! Use from module mul2 kinematics: any field active.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE                       ! Use from module mul2 model cache: model cache type.
      USE MUL2_MODEL_ASSEMBLY, ONLY: ASSEMBLE_MODEL_SYSTEM               ! Use from module mul2 model assembly: assemble model system.
      USE MUL2_BOUNDARY_APPLICATION, ONLY:                               ! Use from module mul2 boundary application: build mechanical boundary data, apply dof ties, expand ties.
     &     BUILD_MECHANICAL_BOUNDARY_DATA, APPLY_DOF_TIES, EXPAND_TIES
      USE MUL2_SPARSE_OPERATIONS, ONLY: REDUCED_PATTERN_TYPE,            ! Use from module mul2 sparse operations: reduced pattern type, build reduced pattern, reduce values, expand ...
     &     BUILD_REDUCED_PATTERN, REDUCE_VALUES, EXPAND_VECTOR
      USE MUL2_MODAL_SOLVER, ONLY: MODAL_INFO_TYPE,                      ! Use from module mul2 modal solver: modal info type, solve modal problem.
     &                             SOLVE_MODAL_PROBLEM
      USE MUL2_ANALYSIS_RESULTS, ONLY: ANALYSIS_RESULTS_TYPE             ! Use from module mul2 analysis results: analysis results type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      REAL(R8), PARAMETER :: GEOMETRIC_TOLERANCE = 1.0E-9_R8             ! Constant real (real64): geometric_tolerance = 1.0e-9.
      REAL(R8), PARAMETER :: PI = 3.14159265358979323846_R8              ! Constant real (real64): pi = 3.14159265358979323846.

      PUBLIC :: RUN_MODAL_ANALYSIS                                       ! Export: run modal analysis.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE RUN_MODAL_ANALYSIS(MODEL, CACHE, RESULTS, STATUS)       ! Subroutine run modal analysis takes model, cache, results, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(INOUT) :: RESULTS              ! In/out of type analysis_results_type: results.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(TIMER_TYPE) :: TIMER                                          ! Of type timer_type: timer.
      TYPE(REDUCED_PATTERN_TYPE) :: PATTERN                              ! Of type reduced_pattern_type: pattern.
      TYPE(MODAL_INFO_TYPE) :: INFO                                      ! Of type modal_info_type: info.
      REAL(R8), ALLOCATABLE :: STIFFNESS(:)                              ! Allocatable real (real64): stiffness(:).
      REAL(R8), ALLOCATABLE :: MASS(:)                                   ! Allocatable real (real64): mass(:).
      REAL(R8), ALLOCATABLE :: EIGENVALUE(:)                             ! Allocatable real (real64): eigenvalue(:).
      REAL(R8), ALLOCATABLE :: VECTOR(:,:)                               ! Allocatable real (real64): vector(:,:).
      REAL(R8), ALLOCATABLE :: RESIDUAL(:)                               ! Allocatable real (real64): residual(:).
      INTEGER(I4) :: MODE_COUNT                                          ! Integer (int32): mode_count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      CHARACTER(LEN=128) :: MESSAGE                                      ! Character (length 128): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      RESULTS%SOLUTION_ID = 103_I4                                       ! Set results.solution_id to 103.
      IF (ANY_FIELD_ACTIVE(MODEL%KINEMATICS,4_I4)) THEN                  ! If any_field_active(model.kinematics,4):
        CALL SET_ERROR(STATUS, 'RUN_MODAL_ANALYSIS',                     ! Record an error in status: 'THE TEMPERATURE FIELD IS NOT SUPPORTED BY 103'.
     &    'THE TEMPERATURE FIELD IS NOT SUPPORTED BY 103')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL TIMER_START(TIMER, 'K M ASSEMBLY')                            ! Call timer start with timer, 'K M ASSEMBLY'.
      CALL ASSEMBLE_MODEL_SYSTEM(MODEL, CACHE, RESULTS%SYSTEM,           ! Call assemble model system with model, cache, results.system, local_status.
     &                           LOCAL_STATUS)
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      RESULTS%ASSEMBLY_SECONDS = TIMER_WALL_SECONDS(TIMER)               ! Set results.assembly_seconds to timer_wall_seconds(timer).
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      WRITE(MESSAGE,'(A,I0,A,I0,A,F9.3,A)') 'K,M ASSEMBLED: ',           ! Format into the text message: 'K,M ASSEMBLED: ', results.system.order, ' DOF, ', results.system.nonzero_cou...
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
      IF (ANY(RESULTS%CONSTRAINTS%VALUE .NE. 0.0_R8) .OR.                ! If any(results.constraints.value /= 0.0) or any(results.force /= 0.0):
     &    ANY(RESULTS%FORCE .NE. 0.0_R8)) THEN
        CALL SET_WARNING(STATUS, 'RUN_MODAL_ANALYSIS',                   ! Record a warning in status: 'LOADS AND NON-ZERO PRESCRIBED DISPLACEMENTS ARE IGNORED'.
     &    'LOADS AND NON-ZERO PRESCRIBED DISPLACEMENTS ARE IGNORED')
      END IF                                                             ! End of the IF block.

      CALL APPLY_DOF_TIES(RESULTS%SYSTEM, CONSTRAINTS=                   ! Call apply dof ties with results.system, constraints= results.constraints, status=local_status.
     &     RESULTS%CONSTRAINTS, STATUS=LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_REDUCED_PATTERN(RESULTS%SYSTEM%ORDER,                   ! Call build reduced pattern with results.system.order, results.system.row_pointer, results.system.column_ind...
     &     RESULTS%SYSTEM%ROW_POINTER, RESULTS%SYSTEM%COLUMN_INDEX,
     &     RESULTS%CONSTRAINTS%ACTIVE, PATTERN)
      MODE_COUNT = MODEL%ANALYSIS%MODE_COUNT                             ! Set mode_count to model.analysis.mode_count.
      IF (INT(MODE_COUNT,I8) .GT. PATTERN%ORDER) THEN                    ! If int(mode_count,i8) > pattern.order:
        MODE_COUNT = INT(PATTERN%ORDER,I4)                               ! Set mode_count to int(pattern.order,i4).
        CALL SET_WARNING(STATUS, 'RUN_MODAL_ANALYSIS',                   ! Record a warning in status: 'MORE MODES REQUESTED THAN FREE DEGREES OF FREEDOM'.
     &    'MORE MODES REQUESTED THAN FREE DEGREES OF FREEDOM')
      END IF                                                             ! End of the IF block.
      IF (MODE_COUNT .LT. 1_I4) THEN                                     ! If mode_count < 1:
        CALL SET_ERROR(STATUS, 'RUN_MODAL_ANALYSIS',                     ! Record an error in status: 'NO MODES REQUESTED OR NO FREE DOF'.
     &                 'NO MODES REQUESTED OR NO FREE DOF')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      ALLOCATE(STIFFNESS(PATTERN%NONZERO_COUNT))                         ! Allocate memory for stiffness(pattern.nonzero_count).
      ALLOCATE(MASS(PATTERN%NONZERO_COUNT))                              ! Allocate memory for mass(pattern.nonzero_count).
      ALLOCATE(EIGENVALUE(MODE_COUNT), RESIDUAL(MODE_COUNT))             ! Allocate memory for eigenvalue(mode_count), residual(mode_count).
      ALLOCATE(VECTOR(PATTERN%ORDER,MODE_COUNT))                         ! Allocate memory for vector(pattern.order,mode_count).
      CALL REDUCE_VALUES(PATTERN, RESULTS%SYSTEM%STIFFNESS, STIFFNESS)   ! Call reduce values with pattern, results.system.stiffness, stiffness.
      CALL REDUCE_VALUES(PATTERN, RESULTS%SYSTEM%MASS, MASS)             ! Call reduce values with pattern, results.system.mass, mass.
!     THE FULL SYSTEM IS ONLY KEPT WHEN ITS DUMP IS REQUESTED.
      IF (ALLOCATED(PATTERN%SOURCE_POSITION))                            ! If allocated(pattern.source_position), free the memory of pattern.source_position.
     &  DEALLOCATE(PATTERN%SOURCE_POSITION)
      IF (.NOT. (MODEL%POST%WRITE_STIFFNESS .OR.                         ! If not (model.post.write_stiffness or model.post.write_mass):
     &           MODEL%POST%WRITE_MASS)) THEN
        DEALLOCATE(RESULTS%SYSTEM%STIFFNESS, RESULTS%SYSTEM%MASS,        ! Free the memory of results.system.stiffness, results.system.mass, results.system.column_index, results.syst...
     &             RESULTS%SYSTEM%COLUMN_INDEX,
     &             RESULTS%SYSTEM%ROW_POINTER)
      END IF                                                             ! End of the IF block.

      CALL TIMER_START(TIMER, 'EIGENSOLVER')                             ! Call timer start with timer, 'EIGENSOLVER'.
      CALL SOLVE_MODAL_PROBLEM(PATTERN%ORDER, PATTERN%ROW_POINTER,       ! Call solve modal problem with pattern.order, pattern.row_pointer, pattern.column_index, stiffness, mass, mo...
     &     PATTERN%COLUMN_INDEX, STIFFNESS, MASS, MODE_COUNT, 0.0_R8,
     &     EIGENVALUE, VECTOR, RESIDUAL, INFO, LOCAL_STATUS)
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      RESULTS%SOLVER_SECONDS = TIMER_WALL_SECONDS(TIMER)                 ! Set results.solver_seconds to timer_wall_seconds(timer).
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      RESULTS%MODE_COUNT = INT(INFO%CONVERGED,I4)                        ! Set results.mode_count to int(info.converged,i4).
      ALLOCATE(RESULTS%EIGENVALUE(RESULTS%MODE_COUNT))                   ! Allocate memory for results.eigenvalue(results.mode_count).
      ALLOCATE(RESULTS%FREQUENCY(RESULTS%MODE_COUNT))                    ! Allocate memory for results.frequency(results.mode_count).
      ALLOCATE(RESULTS%RESIDUAL(RESULTS%MODE_COUNT))                     ! Allocate memory for results.residual(results.mode_count).
      ALLOCATE(RESULTS%MODE(RESULTS%SYSTEM%ORDER,RESULTS%MODE_COUNT))    ! Allocate memory for results.mode(results.system.order,results.mode_count).
      RESULTS%MODE = 0.0_R8                                              ! Set results.mode to zero.
      RESULTS%EIGENVALUE = EIGENVALUE(1:RESULTS%MODE_COUNT)              ! Set results.eigenvalue to eigenvalue(1:results.mode_count).
      RESULTS%RESIDUAL = RESIDUAL(1:RESULTS%MODE_COUNT)                  ! Set results.residual to residual(1:results.mode_count).
      DO I = 1_I4, RESULTS%MODE_COUNT                                    ! Loop i from 1 to results.mode_count:
        CALL EXPAND_VECTOR(PATTERN, VECTOR(:,I), RESULTS%MODE(:,I))      ! Call expand vector with pattern, vector(:,i), results.mode(:,i).
        CALL EXPAND_TIES(RESULTS%CONSTRAINTS, RESULTS%MODE(:,I))         ! Call expand ties with results.constraints, results.mode(:,i).
        RESULTS%FREQUENCY(I) = SQRT(MAX(0.0_R8,EIGENVALUE(I)))/          ! Set results.frequency(i) to the square root of max(0.0,eigenvalue(i)))/ (2.0*pi.
     &                         (2.0_R8*PI)
      END DO                                                             ! End of the loop.
      IF (ANY(EIGENVALUE(1:RESULTS%MODE_COUNT) .LT. 0.0_R8)) THEN        ! If any(eigenvalue(1:results.mode_count) < 0.0):
        CALL SET_WARNING(STATUS, 'RUN_MODAL_ANALYSIS',                   ! Record a warning in status: 'NEGATIVE EIGENVALUES: K IS NOT POSITIVE SEMI-DEFINITE'.
     &    'NEGATIVE EIGENVALUES: K IS NOT POSITIVE SEMI-DEFINITE')
      END IF                                                             ! End of the IF block.
      WRITE(MESSAGE,'(A,A,I0,A,F9.3,A,ES10.2)') TRIM(INFO%BACKEND),      ! Format into the text message: trim(info.backend), ': MODES ', results.mode_count, ', ', results.solver_seco...
     &  ': MODES ', RESULTS%MODE_COUNT, ', ', RESULTS%SOLVER_SECONDS,
     &  ' S, MAX RESIDUAL ', MAXVAL(RESULTS%RESIDUAL)
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.
      RESULTS%SOLVER_BACKEND = INFO%BACKEND                              ! Set results.solver_backend to info.backend.
      RESULTS%SOLVER_ITERATIONS = INFO%ITERATIONS                        ! Set results.solver_iterations to info.iterations.
      RESULTS%SOLVER_OPERATIONS = INFO%OPERATIONS                        ! Set results.solver_operations to info.operations.
      RESULTS%SOLVER_SUBSPACE = INFO%SUBSPACE                            ! Set results.solver_subspace to info.subspace.

      END SUBROUTINE RUN_MODAL_ANALYSIS                                  ! End of the subroutine run modal analysis.

      END MODULE MUL2_ANALYSIS_103                                       ! End of the module mul2 analysis 103.
