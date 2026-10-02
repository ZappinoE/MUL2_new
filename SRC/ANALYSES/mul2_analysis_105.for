!=======================================================================
!  SOLUTION 105: LINEAR BUCKLING.
!
!      STATIC SOLUTION UNDER THE REFERENCE LOADS (101, THERMAL LOADS
!      INCLUDED) -> GEOMETRIC MATRIX K_G OF ITS STRESS FIELD ->
!      (K + LAMBDA K_G) X = 0   ON THE FREE MECHANICAL DOFS.
!
!  THE TEMPERATURE IS A GIVEN FIELD OF THE PRE-STRESS (ITS DOFS ARE NOT
!  PART OF THE EIGENPROBLEM); THE ELECTRIC POTENTIAL IS CONDENSED OUT
!  (CLOSED-CIRCUIT STIFFNESS WITH THE PRESCRIBED ELECTRODES).
!  LAMBDA IS THE FACTOR THAT MULTIPLIES THE REFERENCE LOAD, THE CRITICAL
!  LOAD IS LAMBDA TIMES THE APPLIED ONE. RESULTS: DYNAMIC/
!  BUCKLING_FACTORS.dat AND THE BUCKLING MODES (RESULTS_DYN_*.vtk/msh).
!=======================================================================
      MODULE MUL2_ANALYSIS_105                                           ! Module mul2 analysis 105 begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, set warning, status is ok, merge status.
     &                       SET_WARNING, STATUS_IS_OK, MERGE_STATUS
      USE MUL2_LOG, ONLY: LOG_INFO                                       ! Use from module mul2 log: log info.
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE                       ! Use from module mul2 model cache: model cache type.
      USE MUL2_MODEL_ASSEMBLY, ONLY: ASSEMBLE_MODEL_SYSTEM,              ! Use from module mul2 model assembly: assemble model system, assemble geometric values.
     &                               ASSEMBLE_GEOMETRIC_VALUES
      USE MUL2_SPARSE_OPERATIONS, ONLY: REDUCED_PATTERN_TYPE,            ! Use from module mul2 sparse operations: reduced pattern type, build reduced pattern, reduce values, expand ...
     &     BUILD_REDUCED_PATTERN, REDUCE_VALUES, EXPAND_VECTOR
      USE MUL2_MODAL_SOLVER, ONLY: SOLVE_BUCKLING_DENSE                  ! Use from module mul2 modal solver: solve buckling dense.
      USE MUL2_DOF_LAYOUT, ONLY: GLOBAL_DOF                              ! Use from module mul2 dof layout: global dof.
      USE MUL2_ANALYSIS_RESULTS, ONLY: ANALYSIS_RESULTS_TYPE             ! Use from module mul2 analysis results: analysis results type.
      USE MUL2_ANALYSIS_101, ONLY: RUN_STATIC_ANALYSIS                   ! Use from module mul2 analysis 101: run static analysis.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: RUN_BUCKLING_ANALYSIS                                    ! Export: run buckling analysis.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE RUN_BUCKLING_ANALYSIS(MODEL, CACHE, RESULTS, STATUS)    ! Subroutine run buckling analysis takes model, cache, results, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(INOUT) :: RESULTS              ! In/out of type analysis_results_type: results.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(ANALYSIS_RESULTS_TYPE) :: STATIC                              ! Of type analysis_results_type: static.
      TYPE(REDUCED_PATTERN_TYPE) :: PATTERN                              ! Of type reduced_pattern_type: pattern.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      REAL(R8), ALLOCATABLE :: GEOMETRIC(:)                              ! Allocatable real (real64): geometric(:).
      REAL(R8), ALLOCATABLE :: K_REDUCED(:)                              ! Allocatable real (real64): k_reduced(:).
      REAL(R8), ALLOCATABLE :: G_REDUCED(:)                              ! Allocatable real (real64): g_reduced(:).
      REAL(R8), ALLOCATABLE :: FACTOR(:)                                 ! Allocatable real (real64): factor(:).
      REAL(R8), ALLOCATABLE :: VECTOR(:,:)                               ! Allocatable real (real64): vector(:,:).
      LOGICAL, ALLOCATABLE :: EXCLUDED(:)                                ! Allocatable logical: excluded(:).
      INTEGER(I4) :: NEV                                                 ! Integer (int32): nev.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      CHARACTER(LEN=128) :: MESSAGE                                      ! Character (length 128): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      RESULTS%SOLUTION_ID = 105_I4                                       ! Set results.solution_id to 105.

      CALL RUN_STATIC_ANALYSIS(MODEL, CACHE, STATIC, LOCAL_STATUS)       ! Call run static analysis with model, cache, static, local_status.
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (STATIC%CONSTRAINTS%HAS_TIES) THEN                              ! If static.constraints.has_ties:
        CALL SET_ERROR(STATUS, 'RUN_BUCKLING_ANALYSIS',                  ! Record an error in status: 'FLOATING ELECTRODES (V-FLOAT) ARE NOT SUPPORTED BY 105'.
     &    'FLOATING ELECTRODES (V-FLOAT) ARE NOT SUPPORTED BY 105')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL ASSEMBLE_MODEL_SYSTEM(MODEL, CACHE, RESULTS%SYSTEM,           ! Call assemble model system with model, cache, results.system, local_status, with_mass=false.
     &     LOCAL_STATUS, WITH_MASS=.FALSE.)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL ASSEMBLE_GEOMETRIC_VALUES(MODEL, CACHE, STATIC%SOLUTION,      ! Call assemble geometric values with model, cache, static.solution, results.system, geometric, local_status.
     &     RESULTS%SYSTEM, GEOMETRIC, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

!     FREE DOFS: NOT CONSTRAINED AND NOT TEMPERATURE.
      ALLOCATE(EXCLUDED(RESULTS%SYSTEM%ORDER))                           ! Allocate memory for excluded(results.system.order).
      EXCLUDED = STATIC%CONSTRAINTS%ACTIVE                               ! Set excluded to static.constraints.active.
      DO NODE = 1_I4, SIZE(MODEL%NODES%ITEM)                             ! Loop node from 1 to size(model.nodes.item):
        DO TERM = 1_I4, CACHE%DOF_LAYOUT%TERM_COUNT(NODE,4_I4)           ! Loop term from 1 to cache.dof_layout.term_count(node,4):
          EXCLUDED(GLOBAL_DOF(CACHE%DOF_LAYOUT,NODE,4_I4,TERM)) =        ! Set the flag excluded(global_dof(cache.dof_layout,node,4,term)) to true.
     &      .TRUE.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CALL BUILD_REDUCED_PATTERN(RESULTS%SYSTEM%ORDER,                   ! Call build reduced pattern with results.system.order, results.system.row_pointer, results.system.column_ind...
     &     RESULTS%SYSTEM%ROW_POINTER, RESULTS%SYSTEM%COLUMN_INDEX,
     &     EXCLUDED, PATTERN)
      ALLOCATE(K_REDUCED(PATTERN%NONZERO_COUNT),                         ! Allocate memory for k_reduced(pattern.nonzero_count), g_reduced(pattern.nonzero_count).
     &         G_REDUCED(PATTERN%NONZERO_COUNT))
      CALL REDUCE_VALUES(PATTERN, RESULTS%SYSTEM%STIFFNESS, K_REDUCED)   ! Call reduce values with pattern, results.system.stiffness, k_reduced.
      CALL REDUCE_VALUES(PATTERN, GEOMETRIC, G_REDUCED)                  ! Call reduce values with pattern, geometric, g_reduced.

      NEV = MAX(1_I4, MODEL%ANALYSIS%MODE_COUNT)                         ! Set nev to the larger of 1 and model.analysis.mode_count.
      ALLOCATE(FACTOR(NEV), VECTOR(PATTERN%ORDER,NEV))                   ! Allocate memory for factor(nev), vector(pattern.order,nev).
      CALL SOLVE_BUCKLING_DENSE(PATTERN%ORDER, PATTERN%ROW_POINTER,      ! Call solve buckling dense with pattern.order, pattern.row_pointer, pattern.column_index, k_reduced, g_reduc...
     &     PATTERN%COLUMN_INDEX, K_REDUCED, G_REDUCED, NEV, FACTOR,
     &     VECTOR, COUNT, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      RESULTS%MODE_COUNT = COUNT                                         ! Set results.mode_count to count.
      RESULTS%CONSTRAINTS = STATIC%CONSTRAINTS                           ! Set results.constraints to static.constraints.
      ALLOCATE(RESULTS%SOLUTION(RESULTS%SYSTEM%ORDER))                   ! Allocate memory for results.solution(results.system.order).
      RESULTS%SOLUTION = STATIC%SOLUTION                                 ! Set results.solution to static.solution.
      ALLOCATE(RESULTS%EIGENVALUE(COUNT), RESULTS%FREQUENCY(COUNT))      ! Allocate memory for results.eigenvalue(count), results.frequency(count).
      ALLOCATE(RESULTS%RESIDUAL(COUNT))                                  ! Allocate memory for results.residual(count).
      ALLOCATE(RESULTS%MODE(RESULTS%SYSTEM%ORDER,COUNT))                 ! Allocate memory for results.mode(results.system.order,count).
      RESULTS%MODE = 0.0_R8                                              ! Set results.mode to zero.
      RESULTS%RESIDUAL = 0.0_R8                                          ! Set results.residual to zero.
      RESULTS%SOLVER_BACKEND = 'DENSE'                                   ! Set results.solver_backend to 'DENSE'.
      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL EXPAND_VECTOR(PATTERN, VECTOR(:,I), RESULTS%MODE(:,I))      ! Call expand vector with pattern, vector(:,i), results.mode(:,i).
        RESULTS%EIGENVALUE(I) = FACTOR(I)                                ! Set results.eigenvalue(i) to factor(i).
        RESULTS%FREQUENCY(I) = FACTOR(I)                                 ! Set results.frequency(i) to factor(i).
      END DO                                                             ! End of the loop.
      WRITE(MESSAGE,'(A,I0,A,ES14.6)') 'BUCKLING: ', COUNT,              ! Format into the text message: 'BUCKLING: ', count, ' LOAD FACTORS, THE FIRST IS ', factor(1).
     &  ' LOAD FACTORS, THE FIRST IS ', FACTOR(1)
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      END SUBROUTINE RUN_BUCKLING_ANALYSIS                               ! End of the subroutine run buckling analysis.

      END MODULE MUL2_ANALYSIS_105                                       ! End of the module mul2 analysis 105.
