!=======================================================================
!  SOLUTION 106: HARMONIC (FREQUENCY) RESPONSE.
!
!      ( K - W**2 M + I W C ) X = F        F: THE LOADS OF BC.dat,
!                                           PRESCRIBED VALUES AT PHASE 0
!  ON EVERY FREQUENCY OF FREQ_RESP.dat. THE COMPLEX SYSTEM IS SOLVED AS
!  THE REAL BLOCK SYSTEM
!      [ AR  -AI ] [XR]   [FR]
!      [ AI   AR ] [XI] = [FI]
!  (PARDISO, ONE FACTORIZATION PER FREQUENCY). ALL THE PHYSICS OF THE
!  TIME ANALYSIS ARE INCLUDED: THE MECHANICAL DOFS HAVE INERTIA AND THE
!  RAYLEIGH DAMPING C = ALPHA M + BETA K, THE ELECTRIC POTENTIAL IS
!  ALGEBRAIC, THE TEMPERATURE ROWS GET I W CAPACITY AND, WITH T0, THE
!  THERMOELASTIC HEATING I W T0 (-K_UT)^T.
!  RESULT: DYNAMIC/FREQ_HISTORY.dat (REAL AND IMAGINARY PARTS).
!=======================================================================
      MODULE MUL2_ANALYSIS_106                                           ! Module mul2 analysis 106 begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok, merge status.
     &                       STATUS_IS_OK, MERGE_STATUS
      USE MUL2_LOG, ONLY: LOG_INFO                                       ! Use from module mul2 log: log info.
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE                       ! Use from module mul2 model cache: model cache type.
      USE MUL2_MODEL_ASSEMBLY, ONLY: ASSEMBLE_MODEL_SYSTEM               ! Use from module mul2 model assembly: assemble model system.
      USE MUL2_BOUNDARY_APPLICATION, ONLY:                               ! Use from module mul2 boundary application: build mechanical boundary data, apply static constraints, constr...
     &     BUILD_MECHANICAL_BOUNDARY_DATA, APPLY_STATIC_CONSTRAINTS,
     &     CONSTRAINT_SET_TYPE
      USE MUL2_SURFACE_LOADS, ONLY: APPLY_SURFACE_LOADS                  ! Use from module mul2 surface loads: apply surface loads.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_PARDISO_FACTOR, ONLY: PARDISO_FACTOR_TYPE,                ! Use from module mul2 pardiso factor: pardiso factor type, mtype nonsymmetric, mtype symmetric indefinite, p...
     &     MTYPE_NONSYMMETRIC, MTYPE_SYMMETRIC_INDEFINITE,
     &     PARDISO_SET_SYSTEM,
     &     PARDISO_FACTOR_LOADED, PARDISO_SOLVE, PARDISO_RELEASE
      USE MUL2_KINEMATICS, ONLY: ANY_FIELD_ACTIVE                        ! Use from module mul2 kinematics: any field active.
      USE MUL2_DYNAMIC_COMMON, ONLY: BUILD_DOF_CLASSES,                  ! Use from module mul2 dynamic common: build dof classes, build damping values.
     &     BUILD_DAMPING_VALUES
      USE MUL2_POST_OUTPUT, ONLY: WARNING_LIST_TYPE,                     ! Use from module mul2 post output: warning list type, write frequency output.
     &                            WRITE_FREQUENCY_OUTPUT
      USE MUL2_ANALYSIS_RESULTS, ONLY: ANALYSIS_RESULTS_TYPE             ! Use from module mul2 analysis results: analysis results type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      REAL(R8), PARAMETER :: GEOMETRIC_TOLERANCE = 1.0E-9_R8             ! Constant real (real64): geometric_tolerance = 1.0e-9.
      REAL(R8), PARAMETER :: PI = 3.14159265358979323846_R8              ! Constant real (real64): pi = 3.14159265358979323846.

      PUBLIC :: RUN_FREQUENCY_ANALYSIS                                   ! Export: run frequency analysis.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE RUN_FREQUENCY_ANALYSIS(MODEL, CACHE, RESULTS, WARNINGS, ! Subroutine run frequency analysis takes model, cache, results, warnings, status.
     &                                  STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(INOUT) :: RESULTS              ! In/out of type analysis_results_type: results.
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(SPARSE_SYSTEM_TYPE) :: BLOCK                                  ! Of type sparse_system_type: block.
      TYPE(CONSTRAINT_SET_TYPE) :: CONSTRAINTS2                          ! Of type constraint_set_type: constraints2.
      TYPE(PARDISO_FACTOR_TYPE) :: FACTOR                                ! Of type pardiso_factor_type: factor.
      INTEGER(I4), ALLOCATABLE :: CLASS(:)                               ! Allocatable integer (int32): class(:).
      REAL(R8), ALLOCATABLE :: CDAMP(:)                                  ! Allocatable real (real64): cdamp(:).
      REAL(R8), ALLOCATABLE :: RHS(:)                                    ! Allocatable real (real64): rhs(:).
      REAL(R8), ALLOCATABLE :: SOLUTION(:)                               ! Allocatable real (real64): solution(:).
      REAL(R8), ALLOCATABLE :: FORCE2(:)                                 ! Allocatable real (real64): force2(:).
      REAL(R8) :: ALPHA_M                                                ! Real (real64): alpha_m.
      REAL(R8) :: BETA_K                                                 ! Real (real64): beta_k.
      REAL(R8) :: T0                                                     ! Real (real64): t0.
      REAL(R8) :: FREQUENCY                                              ! Real (real64): frequency.
      REAL(R8) :: W                                                      ! Real (real64): w.
      REAL(R8) :: AR                                                     ! Real (real64): ar.
      REAL(R8) :: AI                                                     ! Real (real64): ai.
      INTEGER(I8) :: N                                                   ! Integer (int64): n.
      INTEGER(I8) :: NNZ                                                 ! Integer (int64): nnz.
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: POS                                                 ! Integer (int64): pos.
      INTEGER(I8) :: COL                                                 ! Integer (int64): col.
      INTEGER(I8) :: OTHER                                               ! Integer (int64): other.
      INTEGER(I8) :: ENTRY                                               ! Integer (int64): entry.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: STEP                                                ! Integer (int32): step.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      LOGICAL :: HAS_TEMPERATURE                                         ! Logical: has_temperature.
      CHARACTER(LEN=128) :: MESSAGE                                      ! Character (length 128): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      RESULTS%SOLUTION_ID = 106_I4                                       ! Set results.solution_id to 106.
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
        CALL SET_ERROR(STATUS, 'RUN_FREQUENCY_ANALYSIS',                 ! Record an error in status: 'FLOATING ELECTRODES (V-FLOAT) ARE NOT SUPPORTED BY 106'.
     &    'FLOATING ELECTRODES (V-FLOAT) ARE NOT SUPPORTED BY 106')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (RESULTS%CONSTRAINTS%COUNT .LT. 1_I8) THEN                      ! If results.constraints.count < 1:
        CALL SET_ERROR(STATUS, 'RUN_FREQUENCY_ANALYSIS',                 ! Record an error in status: 'NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR'.
     &    'NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      N = RESULTS%SYSTEM%ORDER                                           ! Set n to results.system.order.
      NNZ = RESULTS%SYSTEM%NONZERO_COUNT                                 ! Set nnz to results.system.nonzero_count.
      CALL BUILD_DOF_CLASSES(SIZE(MODEL%NODES%ITEM), CACHE%DOF_LAYOUT,   ! Call build dof classes with size(model.nodes.item), cache.dof_layout, n, class, local_status.
     &                       N, CLASS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      T0 = MODEL%FREQ%REFERENCE_TEMPERATURE                              ! Set t0 to model.freq.reference_temperature.
      ALPHA_M = MODEL%MATERIALS%DAMP_MASS                                ! Set alpha_m to model.materials.damp_mass.
      BETA_K = MODEL%MATERIALS%DAMP_STIFFNESS                            ! Set beta_k to model.materials.damp_stiffness.
      IF (MODEL%FREQ%HAS_RAYLEIGH) THEN                                  ! If model.freq.has_rayleigh:
        ALPHA_M = MODEL%FREQ%RAYLEIGH_MASS                               ! Set alpha_m to model.freq.rayleigh_mass.
        BETA_K = MODEL%FREQ%RAYLEIGH_STIFFNESS                           ! Set beta_k to model.freq.rayleigh_stiffness.
      END IF                                                             ! End of the IF block.

!     DAMPING ON THE PATTERN OF K (MECHANICAL RAYLEIGH + HEATING TERM).
      CALL BUILD_DAMPING_VALUES(RESULTS%SYSTEM, CLASS, ALPHA_M, BETA_K,  ! Call build damping values with results.system, class, alpha_m, beta_k, t0, cdamp.
     &                          T0, CDAMP)

!     REAL BLOCK PATTERN [[A,-B],[B,A]] (COLUMNS STAY SORTED). WITHOUT
!     TEMPERATURE A AND B ARE SYMMETRIC AND THE SECOND BLOCK ROW IS
!     MULTIPLIED BY -1: [[A,-B],[-B,-A]] IS SYMMETRIC (INDEFINITE), WHICH
!     NEEDS HALF THE MEMORY AND TIME OF THE GENERAL FACTORIZATION.
      BLOCK%ORDER = 2_I8*N                                               ! Set block.order to 2*n.
      BLOCK%NONZERO_COUNT = 4_I8*NNZ                                     ! Set block.nonzero_count to 4*nnz.
      ALLOCATE(BLOCK%ROW_POINTER(2_I8*N+1_I8))                           ! Allocate memory for block.row_pointer(2*n+1).
      ALLOCATE(BLOCK%COLUMN_INDEX(4_I8*NNZ), BLOCK%STIFFNESS(4_I8*NNZ))  ! Allocate memory for block.column_index(4*nnz), block.stiffness(4*nnz).
      BLOCK%ROW_POINTER(1) = 1_I8                                        ! Set block.row_pointer(1) to 1.
      ENTRY = 0_I8                                                       ! Set entry to zero.
      DO ROW = 1_I8, 2_I8*N                                              ! Loop row from 1 to 2*n:
        OTHER = MOD(ROW-1_I8,N) + 1_I8                                   ! Set other to mod(row-1,n) + 1.
        DO POS = RESULTS%SYSTEM%ROW_POINTER(OTHER),                      ! Loop pos from results.system.row_pointer(other) to results.system.row_pointer(other+1)-1:
     &           RESULTS%SYSTEM%ROW_POINTER(OTHER+1_I8)-1_I8
          ENTRY = ENTRY + 1_I8                                           ! Add 1 to entry.
          BLOCK%COLUMN_INDEX(ENTRY) = RESULTS%SYSTEM%COLUMN_INDEX(POS)   ! Set block.column_index(entry) to results.system.column_index(pos).
        END DO                                                           ! End of the loop.
        DO POS = RESULTS%SYSTEM%ROW_POINTER(OTHER),                      ! Loop pos from results.system.row_pointer(other) to results.system.row_pointer(other+1)-1:
     &           RESULTS%SYSTEM%ROW_POINTER(OTHER+1_I8)-1_I8
          ENTRY = ENTRY + 1_I8                                           ! Add 1 to entry.
          BLOCK%COLUMN_INDEX(ENTRY) = N +                                ! Set block.column_index(entry) to n + results.system.column_index(pos).
     &                                RESULTS%SYSTEM%COLUMN_INDEX(POS)
        END DO                                                           ! End of the loop.
        BLOCK%ROW_POINTER(ROW+1_I8) = ENTRY + 1_I8                       ! Set block.row_pointer(row+1) to entry + 1.
      END DO                                                             ! End of the loop.
      CONSTRAINTS2%COUNT = 2_I8*RESULTS%CONSTRAINTS%COUNT                ! Set constraints2.count to 2*results.constraints.count.
      ALLOCATE(CONSTRAINTS2%ACTIVE(2_I8*N), CONSTRAINTS2%VALUE(2_I8*N))  ! Allocate memory for constraints2.active(2*n), constraints2.value(2*n).
      CONSTRAINTS2%ACTIVE(1:N) = RESULTS%CONSTRAINTS%ACTIVE              ! Set constraints2.active(1:n) to results.constraints.active.
      CONSTRAINTS2%ACTIVE(N+1:2*N) = RESULTS%CONSTRAINTS%ACTIVE          ! Set constraints2.active(n+1:2*n) to results.constraints.active.
      CONSTRAINTS2%VALUE(1:N) = RESULTS%CONSTRAINTS%VALUE                ! Set constraints2.value(1:n) to results.constraints.value.
      CONSTRAINTS2%VALUE(N+1:2*N) = 0.0_R8                               ! Set constraints2.value(n+1:2*n) to zero.
      ALLOCATE(FORCE2(2_I8*N), RHS(2_I8*N), SOLUTION(2_I8*N))            ! Allocate memory for force2(2*n), rhs(2*n), solution(2*n).

      DO STEP = 0_I4, MODEL%FREQ%STEP_COUNT                              ! Loop step from 0 to model.freq.step_count:
        FREQUENCY = MODEL%FREQ%FIRST_FREQUENCY + REAL(STEP,R8)*          ! Set frequency to model.freq.first_frequency + real(step,r8)* (model.freq.last_frequency-model.freq.first_fr...
     &    (MODEL%FREQ%LAST_FREQUENCY-MODEL%FREQ%FIRST_FREQUENCY)/
     &    REAL(MODEL%FREQ%STEP_COUNT,R8)
        W = 2.0_R8*PI*FREQUENCY                                          ! Set w to 2.0*pi*frequency.
!       THE ENTRY OF A ROW STARTS AT ITS ROW POINTER (ROWS ARE
!       INDEPENDENT, THE LOOP IS PARALLEL).
!$OMP   PARALLEL DO DEFAULT(SHARED) PRIVATE(ROW,OTHER,POS,ENTRY,AR,AI)
!$OMP&  SCHEDULE(STATIC)
        DO ROW = 1_I8, 2_I8*N                                            ! Loop row from 1 to 2*n:
          OTHER = MOD(ROW-1_I8,N) + 1_I8                                 ! Set other to mod(row-1,n) + 1.
          ENTRY = BLOCK%ROW_POINTER(ROW) - 1_I8                          ! Set entry to block.row_pointer(row) - 1.
          DO POS = RESULTS%SYSTEM%ROW_POINTER(OTHER),                    ! Loop pos from results.system.row_pointer(other) to results.system.row_pointer(other+1)-1:
     &             RESULTS%SYSTEM%ROW_POINTER(OTHER+1_I8)-1_I8
            AR = RESULTS%SYSTEM%STIFFNESS(POS)                           ! Set ar to results.system.stiffness(pos).
            AI = CDAMP(POS)                                              ! Set ai to cdamp(pos).
            IF (CLASS(OTHER) .EQ. 1_I4) THEN                             ! If class(other) = 1:
              AR = AR - W*W*RESULTS%SYSTEM%MASS(POS)                     ! Subtract w*w*results.system.mass(pos) from ar.
            ELSE IF (CLASS(OTHER) .EQ. 2_I4) THEN                        ! Otherwise, if class(other) = 2:
              AI = AI + RESULTS%SYSTEM%MASS(POS)                         ! Add results.system.mass(pos) to ai.
            END IF                                                       ! End of the IF block.
            AI = W*AI                                                    ! Set ai to w*ai.
            ENTRY = ENTRY + 1_I8                                         ! Add 1 to entry.
            IF (ROW .LE. N) THEN                                         ! If row <= n:
              BLOCK%STIFFNESS(ENTRY) = AR                                ! Set block.stiffness(entry) to ar.
            ELSE IF (HAS_TEMPERATURE) THEN                               ! Otherwise, if has_temperature:
              BLOCK%STIFFNESS(ENTRY) = AI                                ! Set block.stiffness(entry) to ai.
            ELSE                                                         ! Otherwise:
              BLOCK%STIFFNESS(ENTRY) = -AI                               ! Set block.stiffness(entry) to -ai.
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
          DO POS = RESULTS%SYSTEM%ROW_POINTER(OTHER),                    ! Loop pos from results.system.row_pointer(other) to results.system.row_pointer(other+1)-1:
     &             RESULTS%SYSTEM%ROW_POINTER(OTHER+1_I8)-1_I8
            AR = RESULTS%SYSTEM%STIFFNESS(POS)                           ! Set ar to results.system.stiffness(pos).
            AI = CDAMP(POS)                                              ! Set ai to cdamp(pos).
            IF (CLASS(OTHER) .EQ. 1_I4) THEN                             ! If class(other) = 1:
              AR = AR - W*W*RESULTS%SYSTEM%MASS(POS)                     ! Subtract w*w*results.system.mass(pos) from ar.
            ELSE IF (CLASS(OTHER) .EQ. 2_I4) THEN                        ! Otherwise, if class(other) = 2:
              AI = AI + RESULTS%SYSTEM%MASS(POS)                         ! Add results.system.mass(pos) to ai.
            END IF                                                       ! End of the IF block.
            AI = W*AI                                                    ! Set ai to w*ai.
            ENTRY = ENTRY + 1_I8                                         ! Add 1 to entry.
            IF (ROW .LE. N) THEN                                         ! If row <= n:
              BLOCK%STIFFNESS(ENTRY) = -AI                               ! Set block.stiffness(entry) to -ai.
            ELSE IF (HAS_TEMPERATURE) THEN                               ! Otherwise, if has_temperature:
              BLOCK%STIFFNESS(ENTRY) = AR                                ! Set block.stiffness(entry) to ar.
            ELSE                                                         ! Otherwise:
              BLOCK%STIFFNESS(ENTRY) = -AR                               ! Set block.stiffness(entry) to -ar.
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
!$OMP   END PARALLEL DO
        FORCE2(1:N) = RESULTS%FORCE                                      ! Set force2(1:n) to results.force.
        FORCE2(N+1:2*N) = 0.0_R8                                         ! Set force2(n+1:2*n) to zero.
        IF (.NOT. HAS_TEMPERATURE) CONSTRAINTS2%VALUE(N+1:2*N) = 0.0_R8  ! If not has_temperature, set constraints2.value(n+1:2*n) to zero.
        CALL APPLY_STATIC_CONSTRAINTS(BLOCK, FORCE2, CONSTRAINTS2,       ! Call apply static constraints with block, force2, constraints2, local_status.
     &                                LOCAL_STATUS)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        CALL PARDISO_SET_SYSTEM(2_I8*N, BLOCK%ROW_POINTER,               ! Call pardiso set system with 2*n, block.row_pointer, block.column_index, block.stiffness, factor, local_sta...
     &       BLOCK%COLUMN_INDEX, BLOCK%STIFFNESS, FACTOR, LOCAL_STATUS,
     &       FULL=HAS_TEMPERATURE)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        IF (HAS_TEMPERATURE) THEN                                        ! If has_temperature:
          CALL PARDISO_FACTOR_LOADED(MTYPE_NONSYMMETRIC, FACTOR,         ! Call pardiso factor loaded with mtype_nonsymmetric, factor, local_status.
     &                               LOCAL_STATUS)
        ELSE                                                             ! Otherwise:
          CALL PARDISO_FACTOR_LOADED(MTYPE_SYMMETRIC_INDEFINITE,         ! Call pardiso factor loaded with mtype_symmetric_indefinite, factor, local_status.
     &                               FACTOR, LOCAL_STATUS)
        END IF                                                           ! End of the IF block.
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        RHS = FORCE2                                                     ! Set rhs to force2.
        CALL PARDISO_SOLVE(FACTOR, RHS, SOLUTION, LOCAL_STATUS)          ! Call pardiso solve with factor, rhs, solution, local_status.
        CALL PARDISO_RELEASE(FACTOR)                                     ! Call pardiso release with factor.
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        IF (MOD(STEP,MAX(1_I4,MODEL%FREQ%POST_EVERY)) .EQ. 0_I4 .OR.     ! If mod(step,max(1,model.freq.post_every)) = 0 or step = model.freq.step_count:
     &      STEP .EQ. MODEL%FREQ%STEP_COUNT) THEN
          CALL WRITE_FREQUENCY_OUTPUT(MODEL, CACHE, SOLUTION(1:N),       ! Call write frequency output with model, cache, solution(1:n), solution(n+1:2*n), step, frequency, warnings,...
     &         SOLUTION(N+1:2*N), STEP, FREQUENCY, WARNINGS,
     &         LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                           ! If not status is ok, leave the loop.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (ALLOCATED(RESULTS%SOLUTION)) DEALLOCATE(RESULTS%SOLUTION)      ! If allocated(results.solution), free the memory of results.solution.
      ALLOCATE(RESULTS%SOLUTION(N))                                      ! Allocate memory for results.solution(n).
      RESULTS%SOLUTION = SOLUTION(1:N)                                   ! Set results.solution to solution(1:n).
      WRITE(MESSAGE,'(A,I0,A,F10.3,A,F10.3,A)') 'FREQUENCY RESPONSE: ',  ! Format into the text message: 'FREQUENCY RESPONSE: ', model.freq.step_count+1, ' FREQUENCIES, ', model.freq...
     &  MODEL%FREQ%STEP_COUNT+1_I4, ' FREQUENCIES, ',
     &  MODEL%FREQ%FIRST_FREQUENCY, ' TO ', MODEL%FREQ%LAST_FREQUENCY,
     &  ' HZ'
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      END SUBROUTINE RUN_FREQUENCY_ANALYSIS                              ! End of the subroutine run frequency analysis.

      END MODULE MUL2_ANALYSIS_106                                       ! End of the module mul2 analysis 106.
