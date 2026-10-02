!=======================================================================
!  GLOBAL K AND M OF A PREPROCESSED MODEL ON ONE SHARED CSR PATTERN.
!
!  1. THE DOF LIST OF EVERY ELEMENT GIVES THE CSR PATTERN (ONCE);
!  2. ELEMENTS ARE EVALUATED IN CHUNKS, IN PARALLEL (OPENMP, ELEMENTS
!     ARE INDEPENDENT AND WRITE ONLY THEIR OWN MATRICES);
!  3. EVERY CHUNK IS SCATTERED INTO THE CSR ARRAYS SERIALLY AND IN
!     ELEMENT ORDER, SO THE RESULT DOES NOT DEPEND ON THE NUMBER OF
!     THREADS (DETERMINISTIC ROUND-OFF).
!  THE MEMORY OF THE ELEMENT MATRICES IS BOUNDED BY THE CHUNK SIZE.
!=======================================================================
      MODULE MUL2_MODEL_ASSEMBLY                                         ! Module mul2 model assembly begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok, merge status.
     &                       STATUS_IS_OK, MERGE_STATUS
      USE MUL2_MITC, ONLY: MITC_DATA_TYPE                                ! Use from module mul2 mitc: mitc data type.
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE,                      ! Use from module mul2 model cache: model cache type, prepare element mitc, element shear mode.
     &                            PREPARE_ELEMENT_MITC,
     &                            ELEMENT_SHEAR_MODE
      USE MUL2_ANALYSIS_INPUT, ONLY: SHEAR_REDUCED, SHEAR_SELECTIVE      ! Use from module mul2 analysis input: shear reduced, shear selective.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION              ! Use from module mul2 topologies: topology natural dimension.
      USE MUL2_GAUSS_MATERIALS, ONLY: PART_FULL, PART_NORMAL,            ! Use from module mul2 gauss materials: part full, part normal, part shear.
     &                                PART_SHEAR
      USE MUL2_ELEMENT_MATRICES, ONLY: ELEMENT_MATRIX_TYPE,              ! Use from module mul2 element matrices: element matrix type, build linear element matrices, build element do...
     &     BUILD_LINEAR_ELEMENT_MATRICES, BUILD_ELEMENT_DOF_LIST,
     &     CLEAR_ELEMENT_MATRIX, BUILD_NONLINEAR_ELEMENT_MATRICES
      USE MUL2_GENERAL_KERNEL, ONLY: BUILD_GENERAL_ELEMENT_MATRICES      ! Use from module mul2 general kernel: build general element matrices.
      USE MUL2_GENERAL_GEOMETRY, ONLY: IS_GENERAL_ELEMENT                ! Use from module mul2 general geometry: is general element.
      USE MUL2_ANALYSIS_INPUT, ONLY: SHEAR_MITC                          ! Use from module mul2 analysis input: shear mitc.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE,                ! Use from module mul2 sparse assembly: sparse system type, dof list type, coupling table type, build pattern...
     &     DOF_LIST_TYPE, COUPLING_TABLE_TYPE,
     &     BUILD_PATTERN_FROM_DOF_LISTS, SCATTER_ELEMENT
      USE MUL2_KINEMATICS, ONLY: EXPANSION_LE, EXPANSION_HLE,            ! Use from module mul2 kinematics: expansion le, expansion hle, expansion none, find kinematic index.
     &                           EXPANSION_NONE, FIND_KINEMATIC_INDEX
      USE MUL2_NODES, ONLY: FIND_NODE_INDEX                              ! Use from module mul2 nodes: find node index.
      USE MUL2_EXPANSION_MESHES, ONLY: FIND_EXPANSION_INDEX,             ! Use from module mul2 expansion meshes: find expansion index, expansion term count.
     &                                 EXPANSION_TERM_COUNT

!$    USE OMP_LIB
      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!  BYTES OF ELEMENT MATRICES (K AND M) HELD AT ONE TIME.
      REAL(R8), PARAMETER :: CHUNK_BYTES = 1.0E9_R8                      ! Constant real (real64): chunk_bytes = 1.0e9.

      PUBLIC :: ASSEMBLE_MODEL_SYSTEM                                    ! Export: assemble model system.
      PUBLIC :: ASSEMBLE_GEOMETRIC_VALUES                                ! Export: assemble geometric values.
      PUBLIC :: ASSEMBLE_NONLINEAR_VALUES                                ! Export: assemble nonlinear values.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE ASSEMBLE_MODEL_SYSTEM(MODEL, CACHE, SYSTEM, STATUS,     ! Subroutine assemble model system takes model, cache, system, status, with mass, thermoelastic.
     &                                 WITH_MASS, THERMOELASTIC)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      LOGICAL, INTENT(IN), OPTIONAL :: WITH_MASS                         ! Input optional logical: with_mass.
!     THERMOELASTIC: ADD THE NON-SYMMETRIC COUPLING BLOCK K(U,T).
      LOGICAL, INTENT(IN), OPTIONAL :: THERMOELASTIC                     ! Input optional logical: thermoelastic.
      LOGICAL :: COUPLED                                                 ! Logical: coupled.
      LOGICAL :: MASS_REQUESTED                                          ! Logical: mass_requested.
      LOGICAL :: FORCE_GENERAL                                           ! Logical: force_general.
      CHARACTER(LEN=8) :: SWITCH                                         ! Character (length 8): switch.
      INTEGER :: SWITCH_LENGTH                                           ! Integer: switch_length.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(DOF_LIST_TYPE), ALLOCATABLE :: LISTS(:)                       ! Allocatable of type dof_list_type: lists(:).
      TYPE(COUPLING_TABLE_TYPE), ALLOCATABLE :: TABLES(:)                ! Allocatable of type coupling_table_type: tables(:).
      TYPE(ELEMENT_MATRIX_TYPE), ALLOCATABLE :: CHUNK(:)                 ! Allocatable of type element_matrix_type: chunk(:).
      TYPE(STATUS_TYPE), ALLOCATABLE :: CHUNK_STATUS(:)                  ! Allocatable of type status_type: chunk_status(:).
      TYPE(ELEMENT_MATRIX_TYPE) :: SCRATCH                               ! Of type element_matrix_type: scratch.
      INTEGER(I4) :: N_ELEMENT                                           ! Integer (int32): n_element.
      INTEGER(I4) :: MAX_LOCAL                                           ! Integer (int32): max_local.
      INTEGER(I4) :: CHUNK_SIZE                                          ! Integer (int32): chunk_size.
      INTEGER(I4) :: FIRST                                               ! Integer (int32): first.
      INTEGER(I4) :: LAST                                                ! Integer (int32): last.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: MAX_THREADS                                         ! Integer (int32): max_threads.
      REAL(R8) :: BYTES_PER_ENTRY                                        ! Real (real64): bytes_per_entry.

      MAX_THREADS = 1_I4                                                 ! Set max_threads to 1.
      BYTES_PER_ENTRY = 8.0_R8                                           ! Set bytes_per_entry to 8.0.
!$    MAX_THREADS = OMP_GET_MAX_THREADS()
      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
!     MUL2_GENERAL_KERNEL=1 FORCES THE POINT-BY-POINT REFERENCE KERNEL.
      SWITCH = ' '                                                       ! Set switch to ' '.
      CALL GET_ENVIRONMENT_VARIABLE('MUL2_GENERAL_KERNEL', SWITCH,       ! Call get environment variable with 'MUL2_GENERAL_KERNEL', switch, switch_length.
     &                              SWITCH_LENGTH)
      FORCE_GENERAL = SWITCH_LENGTH .GT. 0 .AND. SWITCH(1:1) .EQ. '1'    ! Set force_general to switch_length > 0 and switch(1:1) = '1'.
      MASS_REQUESTED = .TRUE.                                            ! Set the flag mass_requested to true.
      IF (PRESENT(WITH_MASS)) MASS_REQUESTED = WITH_MASS                 ! If present(with_mass), set mass_requested to with_mass.
      COUPLED = .FALSE.                                                  ! Set the flag coupled to false.
      IF (PRESENT(THERMOELASTIC)) COUPLED = THERMOELASTIC                ! If present(thermoelastic), set coupled to thermoelastic.
      IF (MASS_REQUESTED) BYTES_PER_ENTRY = 16.0_R8                      ! If mass_requested, set bytes_per_entry to 16.0.
      N_ELEMENT = SIZE(MODEL%ELEMENTS%ITEM)                              ! Set n_element to the size of model.elements.item.
      ALLOCATE(LISTS(N_ELEMENT))                                         ! Allocate memory for lists(n_element).
      MAX_LOCAL = 1_I4                                                   ! Set max_local to 1.
      DO ELEMENT = 1_I4, N_ELEMENT                                       ! Loop element from 1 to n_element:
        CALL BUILD_ELEMENT_DOF_LIST(ELEMENT, MODEL%NODES,                ! Call build element dof list with element, model.nodes, model.elements, model.kinematics, cache.dof_layout, ...
     &       MODEL%ELEMENTS, MODEL%KINEMATICS, CACHE%DOF_LAYOUT,
     &       SCRATCH, LOCAL_STATUS)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        CALL MARK_LAGRANGE_DOFS(MODEL, ELEMENT, SCRATCH,                 ! Call mark lagrange dofs with model, element, scratch, lists(element).
     &                          LISTS(ELEMENT))
        CALL MOVE_ALLOC(SCRATCH%GLOBAL_DOF, LISTS(ELEMENT)%GLOBAL_DOF)   ! Move the allocation of scratch.global_dof into lists(element).global_dof.
        MAX_LOCAL = MAX(MAX_LOCAL,                                       ! Set max_local to the larger of max_local and int(size(lists(element).global_dof),i4).
     &                  INT(SIZE(LISTS(ELEMENT)%GLOBAL_DOF),I4))
        CALL CLEAR_ELEMENT_MATRIX(SCRATCH)                               ! Call clear element matrix with scratch.
      END DO                                                             ! End of the loop.
      CALL BUILD_COUPLING_TABLES(MODEL, TABLES)                          ! Call build coupling tables with model, tables.
      CALL BUILD_PATTERN_FROM_DOF_LISTS(CACHE%DOF_LAYOUT%TOTAL_DOF,      ! Call build pattern from dof lists with cache.dof_layout.total_dof, lists, system, local_status, mass_reques...
     &     LISTS, SYSTEM, LOCAL_STATUS, MASS_REQUESTED, TABLES)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

!     A CHUNK HOLDS A WHOLE NUMBER OF ROUNDS OF THREADS WHEN THE MEMORY
!     BUDGET ALLOWS IT, SO THAT NO THREAD IDLES INSIDE A CHUNK.
      CHUNK_SIZE = INT(MAX(1.0_R8,MIN(1024.0_R8,CHUNK_BYTES/             ! Set chunk_size to int(max(1.0,min(1024.0,chunk_bytes/ (bytes_per_entry*real(max_local,r8)**2))),i4).
     &             (BYTES_PER_ENTRY*REAL(MAX_LOCAL,R8)**2))),I4)
      IF (CHUNK_SIZE .GT. MAX_THREADS) CHUNK_SIZE =                      ! If chunk_size > max_threads, set chunk_size to (chunk_size/max_threads)*max_threads.
     &  (CHUNK_SIZE/MAX_THREADS)*MAX_THREADS
      CHUNK_SIZE = MAX(CHUNK_SIZE, MIN(MAX_THREADS, N_ELEMENT))          ! Set chunk_size to the larger of chunk_size and min(max_threads, n_element).
      CHUNK_SIZE = MIN(CHUNK_SIZE, N_ELEMENT)                            ! Set chunk_size to the smaller of chunk_size and n_element.
      ALLOCATE(CHUNK(CHUNK_SIZE), CHUNK_STATUS(CHUNK_SIZE))              ! Allocate memory for chunk(chunk_size), chunk_status(chunk_size).

      DO FIRST = 1_I4, N_ELEMENT, CHUNK_SIZE                             ! Loop first from 1 to n_element in steps of chunk_size:
        LAST = MIN(N_ELEMENT, FIRST+CHUNK_SIZE-1_I4)                     ! Set last to the smaller of n_element and first+chunk_size-1.
!$OMP   PARALLEL DO DEFAULT(SHARED) PRIVATE(I) SCHEDULE(DYNAMIC,1)
        DO I = 1_I4, LAST-FIRST+1_I4                                     ! Loop i from 1 to last-first+1:
          CALL EVALUATE_ELEMENT(MODEL, CACHE, FIRST+I-1_I4,              ! Call evaluate element with model, cache, first+i-1, chunk(i), chunk_status(i), mass_requested, force_genera...
     &                          CHUNK(I), CHUNK_STATUS(I),
     &                          MASS_REQUESTED, FORCE_GENERAL, COUPLED)
        END DO                                                           ! End of the loop.
!$OMP   END PARALLEL DO
        DO I = 1_I4, LAST-FIRST+1_I4                                     ! Loop i from 1 to last-first+1:
          CALL MERGE_STATUS(CHUNK_STATUS(I), STATUS)                     ! Merge status chunk_status(i) into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          CALL SCATTER_ELEMENT(SYSTEM, LISTS(FIRST+I-1_I4)%GLOBAL_DOF,   ! Call scatter element with system, lists(first+i-1).global_dof, chunk(i).stiffness, chunk(i).mass, local_sta...
     &         CHUNK(I)%STIFFNESS, CHUNK(I)%MASS, LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          CALL CLEAR_ELEMENT_MATRIX(CHUNK(I))                            ! Call clear element matrix with chunk(i).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE ASSEMBLE_MODEL_SYSTEM                               ! End of the subroutine assemble model system.

!  TANGENT MATRIX AND INTERNAL FORCE OF THE NONLINEAR (TOTAL
!  LAGRANGIAN) MODEL AT THE STATE U0. TANGENT(:) IS ALIGNED WITH
!  SYSTEM%COLUMN_INDEX. ELEMENTS ARE EVALUATED IN PARALLEL IN CHUNKS AND
!  SCATTERED IN ELEMENT ORDER (THE RESULT DOES NOT DEPEND ON THE
!  NUMBER OF THREADS).
      SUBROUTINE ASSEMBLE_NONLINEAR_VALUES(MODEL, CACHE, U0, SYSTEM,     ! Subroutine assemble nonlinear values takes model, cache, u0, system, tangent, internal, status.
     &                                     TANGENT, INTERNAL, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      REAL(R8), INTENT(IN) :: U0(:)                                      ! Input real (real64): u0(:).
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(IN) :: SYSTEM                     ! Input of type sparse_system_type: system.
      REAL(R8), ALLOCATABLE, INTENT(INOUT) :: TANGENT(:)                 ! Allocatable in/out real (real64): tangent(:).
      REAL(R8), INTENT(OUT) :: INTERNAL(:)                               ! Output real (real64): internal(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(SPARSE_SYSTEM_TYPE) :: WORK                                   ! Of type sparse_system_type: work.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(ELEMENT_MATRIX_TYPE), ALLOCATABLE :: CHUNK(:)                 ! Allocatable of type element_matrix_type: chunk(:).
      TYPE(STATUS_TYPE), ALLOCATABLE :: CHUNK_STATUS(:)                  ! Allocatable of type status_type: chunk_status(:).
      REAL(R8) :: NO_MASS(0,0)                                           ! Real (real64): no_mass(0,0).
      INTEGER(I4), PARAMETER :: CHUNK_SIZE = 64_I4                       ! Constant integer (int32): chunk_size = 64.
      INTEGER(I4) :: N_ELEMENT                                           ! Integer (int32): n_element.
      INTEGER(I4) :: FIRST                                               ! Integer (int32): first.
      INTEGER(I4) :: LAST                                                ! Integer (int32): last.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      WORK%ORDER = SYSTEM%ORDER                                          ! Set work.order to system.order.
      WORK%NONZERO_COUNT = SYSTEM%NONZERO_COUNT                          ! Set work.nonzero_count to system.nonzero_count.
      ALLOCATE(WORK%ROW_POINTER(SIZE(SYSTEM%ROW_POINTER)))               ! Allocate memory for work.row_pointer(size(system.row_pointer)).
      ALLOCATE(WORK%COLUMN_INDEX(SIZE(SYSTEM%COLUMN_INDEX)))             ! Allocate memory for work.column_index(size(system.column_index)).
      ALLOCATE(WORK%STIFFNESS(SIZE(SYSTEM%STIFFNESS)))                   ! Allocate memory for work.stiffness(size(system.stiffness)).
      WORK%ROW_POINTER = SYSTEM%ROW_POINTER                              ! Set work.row_pointer to system.row_pointer.
      WORK%COLUMN_INDEX = SYSTEM%COLUMN_INDEX                            ! Set work.column_index to system.column_index.
      WORK%STIFFNESS = 0.0_R8                                            ! Set work.stiffness to zero.
      INTERNAL = 0.0_R8                                                  ! Set internal to zero.
      N_ELEMENT = SIZE(MODEL%ELEMENTS%ITEM)                              ! Set n_element to the size of model.elements.item.
      ALLOCATE(CHUNK(CHUNK_SIZE), CHUNK_STATUS(CHUNK_SIZE))              ! Allocate memory for chunk(chunk_size), chunk_status(chunk_size).
      DO FIRST = 1_I4, N_ELEMENT, CHUNK_SIZE                             ! Loop first from 1 to n_element in steps of chunk_size:
        LAST = MIN(N_ELEMENT, FIRST+CHUNK_SIZE-1_I4)                     ! Set last to the smaller of n_element and first+chunk_size-1.
!$OMP   PARALLEL DO DEFAULT(SHARED) PRIVATE(I) SCHEDULE(DYNAMIC,1)
        DO I = 1_I4, LAST-FIRST+1_I4                                     ! Loop i from 1 to last-first+1:
          CALL NONLINEAR_ELEMENT(MODEL, CACHE, FIRST+I-1_I4, U0,         ! Call nonlinear element with model, cache, first+i-1, u0, chunk(i), chunk_status(i).
     &                           CHUNK(I), CHUNK_STATUS(I))
        END DO                                                           ! End of the loop.
!$OMP   END PARALLEL DO
        DO I = 1_I4, LAST-FIRST+1_I4                                     ! Loop i from 1 to last-first+1:
          CALL MERGE_STATUS(CHUNK_STATUS(I), STATUS)                     ! Merge status chunk_status(i) into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          CALL SCATTER_ELEMENT(WORK, CHUNK(I)%GLOBAL_DOF,                ! Call scatter element with work, chunk(i).global_dof, chunk(i).stiffness, no_mass, local_status.
     &         CHUNK(I)%STIFFNESS, NO_MASS, LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          DO K = 1_I4, CHUNK(I)%LOCAL_DOF_COUNT                          ! Loop k from 1 to chunk(i).local_dof_count:
            INTERNAL(CHUNK(I)%GLOBAL_DOF(K)) =                           ! Add chunk(i).internal_force(k) to internal(chunk(i).global_dof(k)).
     &        INTERNAL(CHUNK(I)%GLOBAL_DOF(K)) +
     &        CHUNK(I)%INTERNAL_FORCE(K)
          END DO                                                         ! End of the loop.
          CALL CLEAR_ELEMENT_MATRIX(CHUNK(I))                            ! Call clear element matrix with chunk(i).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (ALLOCATED(TANGENT)) DEALLOCATE(TANGENT)                        ! If allocated(tangent), free the memory of tangent.
      CALL MOVE_ALLOC(WORK%STIFFNESS, TANGENT)                           ! Move the allocation of work.stiffness into tangent.

      END SUBROUTINE ASSEMBLE_NONLINEAR_VALUES                           ! End of the subroutine assemble nonlinear values.

      SUBROUTINE NONLINEAR_ELEMENT(MODEL, CACHE, ELEMENT, U0, MATRICES,  ! Subroutine nonlinear element takes model, cache, element, u0, matrices, status.
     &                             STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      REAL(R8), INTENT(IN) :: U0(:)                                      ! Input real (real64): u0(:).
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(MITC_DATA_TYPE) :: MITC                                       ! Of type mitc_data_type: mitc.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (IS_GENERAL_ELEMENT(CACHE%FRAMES, ELEMENT)) THEN                ! If is_general_element(cache.frames, element):
        CALL SET_ERROR(STATUS, 'NONLINEAR_ELEMENT',                      ! Record an error in status: 'CURVED BEAMS AND SHELLS ARE NOT SUPPORTED BY THIS ANALYSIS'.
     &    'CURVED BEAMS AND SHELLS ARE NOT SUPPORTED BY THIS ANALYSIS')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL PREPARE_ELEMENT_MITC(MODEL, CACHE, ELEMENT, MITC,             ! Call prepare element mitc with model, cache, element, mitc, local_status.
     &                          LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_NONLINEAR_ELEMENT_MATRICES(ELEMENT, MODEL%NODES,        ! Call build nonlinear element matrices with element, model.nodes, model.elements, model.kinematics, model.ex...
     &     MODEL%ELEMENTS, MODEL%KINEMATICS, MODEL%EXPANSIONS,
     &     CACHE%DOF_LAYOUT, CACHE%RULES, CACHE%GAUSS_LAYOUT,
     &     CACHE%STRUCTURAL_GEOMETRY, CACHE%EXPANSION_GEOMETRY,
     &     CACHE%GEOMETRY, CACHE%FRAMES, CACHE%MATERIAL_CACHE,
     &     CACHE%MATERIAL_MAP, MATRICES, LOCAL_STATUS, MITC, U0)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.

      END SUBROUTINE NONLINEAR_ELEMENT                                   ! End of the subroutine nonlinear element.

!  GEOMETRIC (INITIAL-STRESS) MATRIX OF THE STATE U0 ON THE PATTERN OF
!  THE SYSTEM: VALUES(:) IS ALIGNED WITH SYSTEM%COLUMN_INDEX.
      SUBROUTINE ASSEMBLE_GEOMETRIC_VALUES(MODEL, CACHE, U0, SYSTEM,     ! Subroutine assemble geometric values takes model, cache, u0, system, values, status.
     &                                     VALUES, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      REAL(R8), INTENT(IN) :: U0(:)                                      ! Input real (real64): u0(:).
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(IN) :: SYSTEM                     ! Input of type sparse_system_type: system.
      REAL(R8), ALLOCATABLE, INTENT(OUT) :: VALUES(:)                    ! Allocatable output real (real64): values(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(SPARSE_SYSTEM_TYPE) :: WORK                                   ! Of type sparse_system_type: work.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(ELEMENT_MATRIX_TYPE), ALLOCATABLE :: CHUNK(:)                 ! Allocatable of type element_matrix_type: chunk(:).
      TYPE(STATUS_TYPE), ALLOCATABLE :: CHUNK_STATUS(:)                  ! Allocatable of type status_type: chunk_status(:).
      REAL(R8) :: NO_MASS(0,0)                                           ! Real (real64): no_mass(0,0).
      INTEGER(I4), PARAMETER :: CHUNK_SIZE = 64_I4                       ! Constant integer (int32): chunk_size = 64.
      INTEGER(I4) :: N_ELEMENT                                           ! Integer (int32): n_element.
      INTEGER(I4) :: FIRST                                               ! Integer (int32): first.
      INTEGER(I4) :: LAST                                                ! Integer (int32): last.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
!     SAME PATTERN AS THE SYSTEM, VALUES ZERO.
      WORK%ORDER = SYSTEM%ORDER                                          ! Set work.order to system.order.
      WORK%NONZERO_COUNT = SYSTEM%NONZERO_COUNT                          ! Set work.nonzero_count to system.nonzero_count.
      ALLOCATE(WORK%ROW_POINTER(SIZE(SYSTEM%ROW_POINTER)))               ! Allocate memory for work.row_pointer(size(system.row_pointer)).
      ALLOCATE(WORK%COLUMN_INDEX(SIZE(SYSTEM%COLUMN_INDEX)))             ! Allocate memory for work.column_index(size(system.column_index)).
      ALLOCATE(WORK%STIFFNESS(SIZE(SYSTEM%STIFFNESS)))                   ! Allocate memory for work.stiffness(size(system.stiffness)).
      WORK%ROW_POINTER = SYSTEM%ROW_POINTER                              ! Set work.row_pointer to system.row_pointer.
      WORK%COLUMN_INDEX = SYSTEM%COLUMN_INDEX                            ! Set work.column_index to system.column_index.
      WORK%STIFFNESS = 0.0_R8                                            ! Set work.stiffness to zero.
      N_ELEMENT = SIZE(MODEL%ELEMENTS%ITEM)                              ! Set n_element to the size of model.elements.item.
      ALLOCATE(CHUNK(CHUNK_SIZE), CHUNK_STATUS(CHUNK_SIZE))              ! Allocate memory for chunk(chunk_size), chunk_status(chunk_size).
      DO FIRST = 1_I4, N_ELEMENT, CHUNK_SIZE                             ! Loop first from 1 to n_element in steps of chunk_size:
        LAST = MIN(N_ELEMENT, FIRST+CHUNK_SIZE-1_I4)                     ! Set last to the smaller of n_element and first+chunk_size-1.
!$OMP   PARALLEL DO DEFAULT(SHARED) PRIVATE(I) SCHEDULE(DYNAMIC,1)
        DO I = 1_I4, LAST-FIRST+1_I4                                     ! Loop i from 1 to last-first+1:
          CALL GEOMETRIC_ELEMENT(MODEL, CACHE, FIRST+I-1_I4, U0,         ! Call geometric element with model, cache, first+i-1, u0, chunk(i), chunk_status(i).
     &                           CHUNK(I), CHUNK_STATUS(I))
        END DO                                                           ! End of the loop.
!$OMP   END PARALLEL DO
        DO I = 1_I4, LAST-FIRST+1_I4                                     ! Loop i from 1 to last-first+1:
          CALL MERGE_STATUS(CHUNK_STATUS(I), STATUS)                     ! Merge status chunk_status(i) into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          CALL SCATTER_ELEMENT(WORK, CHUNK(I)%GLOBAL_DOF,                ! Call scatter element with work, chunk(i).global_dof, chunk(i).stiffness, no_mass, local_status.
     &         CHUNK(I)%STIFFNESS, NO_MASS, LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          CALL CLEAR_ELEMENT_MATRIX(CHUNK(I))                            ! Call clear element matrix with chunk(i).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CALL MOVE_ALLOC(WORK%STIFFNESS, VALUES)                            ! Move the allocation of work.stiffness into values.

      END SUBROUTINE ASSEMBLE_GEOMETRIC_VALUES                           ! End of the subroutine assemble geometric values.

!  GEOMETRIC MATRIX OF ONE ELEMENT (THREAD-SAFE: ONLY READS SHARED DATA).
      SUBROUTINE GEOMETRIC_ELEMENT(MODEL, CACHE, ELEMENT, U0, MATRICES,  ! Subroutine geometric element takes model, cache, element, u0, matrices, status.
     &                             STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      REAL(R8), INTENT(IN) :: U0(:)                                      ! Input real (real64): u0(:).
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(MITC_DATA_TYPE) :: MITC                                       ! Of type mitc_data_type: mitc.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (IS_GENERAL_ELEMENT(CACHE%FRAMES, ELEMENT)) THEN                ! If is_general_element(cache.frames, element):
        CALL SET_ERROR(STATUS, 'GEOMETRIC_ELEMENT',                      ! Record an error in status: 'CURVED BEAMS AND SHELLS ARE NOT SUPPORTED BY THIS ANALYSIS'.
     &    'CURVED BEAMS AND SHELLS ARE NOT SUPPORTED BY THIS ANALYSIS')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL PREPARE_ELEMENT_MITC(MODEL, CACHE, ELEMENT, MITC,             ! Call prepare element mitc with model, cache, element, mitc, local_status.
     &                          LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_LINEAR_ELEMENT_MATRICES(ELEMENT, MODEL%NODES,           ! Call build linear element matrices with element, model.nodes, model.elements, model.kinematics, model.expan...
     &     MODEL%ELEMENTS, MODEL%KINEMATICS, MODEL%EXPANSIONS,
     &     CACHE%DOF_LAYOUT, CACHE%RULES, CACHE%GAUSS_LAYOUT,
     &     CACHE%STRUCTURAL_GEOMETRY, CACHE%EXPANSION_GEOMETRY,
     &     CACHE%GEOMETRY, CACHE%FRAMES, CACHE%MATERIAL_CACHE,
     &     CACHE%MATERIAL_MAP, MATRICES, LOCAL_STATUS, MITC,
     &     WITH_MASS=.FALSE., FORCE_GENERAL=.TRUE.,
     &     GEOMETRIC=.TRUE., U0=U0)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.

      END SUBROUTINE GEOMETRIC_ELEMENT                                   ! End of the subroutine geometric element.

!  LAGRANGE-EXPANSION DOFS OF AN ELEMENT: TABLE = EXPANSION MESH AND
!  TERM = MESH NODE. (TAYLOR DOFS KEEP TABLE = 0: FULLY COUPLED.)
      SUBROUTINE MARK_LAGRANGE_DOFS(MODEL, ELEMENT, SCRATCH, LIST)       ! Subroutine mark lagrange dofs takes model, element, scratch, list.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(IN) :: SCRATCH                   ! Input of type element_matrix_type: scratch.
      TYPE(DOF_LIST_TYPE), INTENT(INOUT) :: LIST                         ! In/out of type dof_list_type: list.
      INTEGER(I4) :: MESH                                                ! Integer (int32): mesh.
      INTEGER(I4) :: KINEMATIC                                           ! Integer (int32): kinematic.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      MESH = FIND_EXPANSION_INDEX(MODEL%EXPANSIONS,                      ! Set mesh to find_expansion_index(model.expansions, model.elements.item(element).expansion_id).
     &       MODEL%ELEMENTS%ITEM(ELEMENT)%EXPANSION_ID)
      ALLOCATE(LIST%TABLE(SIZE(SCRATCH%FIELD)))                          ! Allocate memory for list.table(size(scratch.field)).
      ALLOCATE(LIST%TERM(SIZE(SCRATCH%FIELD)))                           ! Allocate memory for list.term(size(scratch.field)).
      LIST%TABLE = 0_I4                                                  ! Set list.table to zero.
      LIST%TERM = 0_I4                                                   ! Set list.term to zero.
      IF (MESH .EQ. 0_I4) RETURN                                         ! If mesh = 0, return to the caller.
      DO I = 1_I4, SIZE(SCRATCH%FIELD)                                   ! Loop i from 1 to size(scratch.field):
        KINEMATIC = SCRATCH%KINEMATIC_INDEX(SCRATCH%STRUCTURAL_NODE(I))  ! Set kinematic to scratch.kinematic_index(scratch.structural_node(i)).
        IF (MODEL%KINEMATICS%ITEM(KINEMATIC)%FIELD(SCRATCH%FIELD(I))%    ! If model.kinematics.item(kinematic).field(scratch.field(i)). family /= expansion_le and model.kinematics.it...
     &      FAMILY .NE. EXPANSION_LE .AND.
     &      MODEL%KINEMATICS%ITEM(KINEMATIC)%FIELD(SCRATCH%FIELD(I))%
     &      FAMILY .NE. EXPANSION_HLE) CYCLE
        LIST%TABLE(I) = MESH                                             ! Set list.table(i) to mesh.
        LIST%TERM(I) = SCRATCH%TERM(I)                                   ! Set list.term(i) to scratch.term(i).
      END DO                                                             ! End of the loop.

      END SUBROUTINE MARK_LAGRANGE_DOFS                                  ! End of the subroutine mark lagrange dofs.

!  COUPLED(T,S) = TERMS T AND S (NODES OF THE MESH) SHARE A SUB-ELEMENT.
      SUBROUTINE BUILD_COUPLING_TABLES(MODEL, TABLES)                    ! Subroutine build coupling tables takes model, tables.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(COUPLING_TABLE_TYPE), ALLOCATABLE, INTENT(OUT) :: TABLES(:)   ! Allocatable output of type coupling_table_type: tables(:).
      INTEGER(I4), ALLOCATABLE :: POSITION(:)                            ! Allocatable integer (int32): position(:).
      INTEGER(I4) :: MESH                                                ! Integer (int32): mesh.
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: T                                                   ! Integer (int32): t.

      ALLOCATE(TABLES(SIZE(MODEL%EXPANSIONS%ITEM)))                      ! Allocate memory for tables(size(model.expansions.item)).
      DO MESH = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM)                        ! Loop mesh from 1 to size(model.expansions.item):
        T = EXPANSION_TERM_COUNT(MODEL%EXPANSIONS%ITEM(MESH))            ! Set t to expansion_term_count(model.expansions.item(mesh)).
        ALLOCATE(TABLES(MESH)%COUPLED(T,T))                              ! Allocate memory for tables(mesh).coupled(t,t).
        TABLES(MESH)%COUPLED = .FALSE.                                   ! Set the flag tables(mesh).coupled to false.
        DO E = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT)           ! Loop e from 1 to size(model.expansions.item(mesh).element):
          IF (MODEL%EXPANSIONS%ITEM(MESH)%IS_HLE) THEN                   ! If model.expansions.item(mesh).is_hle:
!           HLE: TWO TERMS COUPLE WHEN THEIR MODES LIVE IN ONE ELEMENT.
            ASSOCIATE(MT => MODEL%EXPANSIONS%ITEM(MESH)%                 ! Use short names (mt) for longer expressions:
     &                ELEMENT(E)%MODE_TERM)
              DO K = 1_I4, SIZE(MT)                                      ! Loop k from 1 to size(mt):
                IF (MT(K) .LT. 1_I4) CYCLE                               ! If mt(k) < 1, skip to the next iteration.
                DO J = 1_I4, SIZE(MT)                                    ! Loop j from 1 to size(mt):
                  IF (MT(J) .GE. 1_I4) TABLES(MESH)%COUPLED(MT(K),       ! If mt(j) >= 1, set the flag tables(mesh).coupled(mt(k), mt(j)) to true.
     &              MT(J)) = .TRUE.
                END DO                                                   ! End of the loop.
              END DO                                                     ! End of the loop.
            END ASSOCIATE                                                ! End of the shorthand names.
            CYCLE                                                        ! Skip to the next iteration.
          END IF                                                         ! End of the IF block.
          ASSOCIATE(NODE_ID => MODEL%EXPANSIONS%ITEM(MESH)%              ! Use short names (node_id) for longer expressions:
     &              ELEMENT(E)%NODE_ID)
            ALLOCATE(POSITION(SIZE(NODE_ID)))                            ! Allocate memory for position(size(node_id)).
            POSITION = 0_I4                                              ! Set position to zero.
            DO K = 1_I4, SIZE(NODE_ID)                                   ! Loop k from 1 to size(node_id):
              DO J = 1_I4, T                                             ! Loop j from 1 to t:
                IF (MODEL%EXPANSIONS%ITEM(MESH)%NODE(J)%ID .EQ.          ! If model.expansions.item(mesh).node(j).id = node_id(k):
     &              NODE_ID(K)) THEN
                  POSITION(K) = J                                        ! Set position(k) to j.
                  EXIT                                                   ! Leave the loop.
                END IF                                                   ! End of the IF block.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
            DO K = 1_I4, SIZE(NODE_ID)                                   ! Loop k from 1 to size(node_id):
              DO J = 1_I4, SIZE(NODE_ID)                                 ! Loop j from 1 to size(node_id):
                IF (POSITION(K) .GT. 0_I4 .AND. POSITION(J) .GT. 0_I4)   ! If position(k) > 0 and position(j) > 0, set the flag tables(mesh).coupled(position(k),position(j)) to true.
     &            TABLES(MESH)%COUPLED(POSITION(K),POSITION(J)) =
     &              .TRUE.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
            DEALLOCATE(POSITION)                                         ! Free the memory of position.
          END ASSOCIATE                                                  ! End of the shorthand names.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_COUPLING_TABLES                               ! End of the subroutine build coupling tables.
!  K AND M OF ONE ELEMENT; WITH COUPLED THE THERMOELASTIC BLOCK K(U,T)
!  (FULL INTEGRATION) IS ADDED WHEN THE ELEMENT HAS A TEMPERATURE FIELD.
      SUBROUTINE EVALUATE_ELEMENT(MODEL, CACHE, ELEMENT, MATRICES,       ! Subroutine evaluate element takes model, cache, element, matrices, status, with mass, force general, coupled.
     &                            STATUS, WITH_MASS, FORCE_GENERAL,
     &                            COUPLED)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      LOGICAL, INTENT(IN) :: WITH_MASS                                   ! Input logical: with_mass.
      LOGICAL, INTENT(IN) :: FORCE_GENERAL                               ! Input logical: force_general.
      LOGICAL, INTENT(IN) :: COUPLED                                     ! Input logical: coupled.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(ELEMENT_MATRIX_TYPE) :: BLOCK                                 ! Of type element_matrix_type: block.
      TYPE(MITC_DATA_TYPE) :: MITC                                       ! Of type mitc_data_type: mitc.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC                                           ! Integer (int32): kinematic.
      LOGICAL :: HAS_TEMPERATURE                                         ! Logical: has_temperature.

      CALL EVALUATE_ELEMENT_BASE(MODEL, CACHE, ELEMENT, MATRICES,        ! Call evaluate element base with model, cache, element, matrices, status, with_mass, force_general.
     &                           STATUS, WITH_MASS, FORCE_GENERAL)
      IF (.NOT. COUPLED .OR. .NOT. STATUS_IS_OK(STATUS)) RETURN          ! If not coupled or not status is ok, return to the caller.
      HAS_TEMPERATURE = .FALSE.                                          ! Set the flag has_temperature to false.
      DO NODE = 1_I4, SIZE(MODEL%ELEMENTS%ITEM(ELEMENT)%NODE_ID)         ! Loop node from 1 to size(model.elements.item(element).node_id):
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES,                        ! Set node_index to find_node_index(model.nodes, model.elements.item(element).node_id(node)).
     &    MODEL%ELEMENTS%ITEM(ELEMENT)%NODE_ID(NODE))
        KINEMATIC = FIND_KINEMATIC_INDEX(MODEL%KINEMATICS,               ! Set kinematic to find_kinematic_index(model.kinematics, model.nodes.item(node_index).kinematic_id).
     &    MODEL%NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
        IF (MODEL%KINEMATICS%ITEM(KINEMATIC)%FIELD(4)%FAMILY             ! If model.kinematics.item(kinematic).field(4).family /= expansion_none, set the flag has_temperature to true.
     &      .NE. EXPANSION_NONE) HAS_TEMPERATURE = .TRUE.
      END DO                                                             ! End of the loop.
      IF (.NOT. HAS_TEMPERATURE) RETURN                                  ! If not has_temperature, return to the caller.
      IF (IS_GENERAL_ELEMENT(CACHE%FRAMES, ELEMENT)) THEN                ! If is_general_element(cache.frames, element):
        CALL GENERAL_ELEMENT(MODEL, CACHE, ELEMENT,                      ! Call general element with model, cache, element, element_shear_mode(model, element), block, local_status, f...
     &       ELEMENT_SHEAR_MODE(MODEL, ELEMENT), BLOCK, LOCAL_STATUS,
     &       .FALSE., .TRUE.)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        MATRICES%STIFFNESS = MATRICES%STIFFNESS + BLOCK%STIFFNESS        ! Add block.stiffness to matrices.stiffness.
        CALL CLEAR_ELEMENT_MATRIX(BLOCK)                                 ! Call clear element matrix with block.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL PREPARE_ELEMENT_MITC(MODEL, CACHE, ELEMENT, MITC,             ! Call prepare element mitc with model, cache, element, mitc, local_status.
     &                          LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_LINEAR_ELEMENT_MATRICES(ELEMENT, MODEL%NODES,           ! Call build linear element matrices with element, model.nodes, model.elements, model.kinematics, model.expan...
     &     MODEL%ELEMENTS, MODEL%KINEMATICS, MODEL%EXPANSIONS,
     &     CACHE%DOF_LAYOUT, CACHE%RULES, CACHE%GAUSS_LAYOUT,
     &     CACHE%STRUCTURAL_GEOMETRY, CACHE%EXPANSION_GEOMETRY,
     &     CACHE%GEOMETRY, CACHE%FRAMES, CACHE%MATERIAL_CACHE,
     &     CACHE%MATERIAL_MAP, BLOCK, LOCAL_STATUS, MITC,
     &     WITH_MASS=.FALSE., FORCE_GENERAL=.TRUE., COUPLING=.TRUE.)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      MATRICES%STIFFNESS = MATRICES%STIFFNESS + BLOCK%STIFFNESS          ! Add block.stiffness to matrices.stiffness.
      CALL CLEAR_ELEMENT_MATRIX(BLOCK)                                   ! Call clear element matrix with block.

      END SUBROUTINE EVALUATE_ELEMENT                                    ! End of the subroutine evaluate element.

!  K AND M OF ONE ELEMENT (THREAD-SAFE: ONLY READS THE SHARED DATA).
      SUBROUTINE EVALUATE_ELEMENT_BASE(MODEL, CACHE, ELEMENT, MATRICES,  ! Subroutine evaluate element base takes model, cache, element, matrices, status, with mass, force general.
     &                                 STATUS, WITH_MASS, FORCE_GENERAL)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      LOGICAL, INTENT(IN) :: WITH_MASS                                   ! Input logical: with_mass.
      LOGICAL, INTENT(IN) :: FORCE_GENERAL                               ! Input logical: force_general.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(MITC_DATA_TYPE) :: MITC                                       ! Of type mitc_data_type: mitc.
      TYPE(ELEMENT_MATRIX_TYPE) :: SECOND                                ! Of type element_matrix_type: second.
      INTEGER(I4) :: MODE                                                ! Integer (int32): mode.
      INTEGER(I4) :: DIM                                                 ! Integer (int32): dim.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
!     REDUCED / SELECTIVE INTEGRATION OF THE STRUCTURAL ELEMENT.
      MODE = ELEMENT_SHEAR_MODE(MODEL, ELEMENT)                          ! Set mode to element_shear_mode(model, element).
      IF (IS_GENERAL_ELEMENT(CACHE%FRAMES, ELEMENT)) THEN                ! If is_general_element(cache.frames, element):
        CALL GENERAL_ELEMENT(MODEL, CACHE, ELEMENT, MODE, MATRICES,      ! Call general element with model, cache, element, mode, matrices, status, with_mass, false.
     &                       STATUS, WITH_MASS, .FALSE.)
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DIM = TOPOLOGY_NATURAL_DIMENSION(                                  ! Set dim to topology_natural_dimension( model.elements.item(element).topology).
     &      MODEL%ELEMENTS%ITEM(ELEMENT)%TOPOLOGY)
      IF ((MODE .EQ. SHEAR_REDUCED .OR. MODE .EQ. SHEAR_SELECTIVE)       ! If (mode = shear_reduced or mode = shear_selective) and cache.has_reduced and dim >= 1 and dim <= 3:
     &    .AND. CACHE%HAS_REDUCED .AND. DIM .GE. 1_I4 .AND.
     &    DIM .LE. 3_I4) THEN
        IF (CACHE%REDUCED_DIMENSION(DIM)) THEN                           ! If cache.reduced_dimension(dim):
          IF (MODE .EQ. SHEAR_REDUCED) THEN                              ! If mode = shear_reduced:
!           REDI: K AND M WITH THE REDUCED RULE (AS IN THE BASELINE).
            CALL BUILD_LINEAR_ELEMENT_MATRICES(ELEMENT, MODEL%NODES,     ! Call build linear element matrices with element, model.nodes, model.elements, model.kinematics, model.expan...
     &       MODEL%ELEMENTS, MODEL%KINEMATICS, MODEL%EXPANSIONS,
     &       CACHE%DOF_LAYOUT, CACHE%RULES, CACHE%REDUCED%GAUSS_LAYOUT,
     &       CACHE%REDUCED%STRUCTURAL_GEOMETRY,
     &       CACHE%EXPANSION_GEOMETRY, CACHE%REDUCED%GEOMETRY,
     &       CACHE%FRAMES, CACHE%MATERIAL_CACHE,
     &       CACHE%REDUCED%MATERIAL_MAP, MATRICES, LOCAL_STATUS,
     &       MITC, WITH_MASS, FORCE_GENERAL, PART_FULL)
            CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                      ! Merge status local_status into status.
          ELSE                                                           ! Otherwise:
!           SELI: NORMAL-STRAIN TERMS FULL, TERMS WITH A SHEAR STRAIN
!           REDUCED; THE MASS IS THE FULL ONE.
            CALL BUILD_LINEAR_ELEMENT_MATRICES(ELEMENT, MODEL%NODES,     ! Call build linear element matrices with element, model.nodes, model.elements, model.kinematics, model.expan...
     &       MODEL%ELEMENTS, MODEL%KINEMATICS, MODEL%EXPANSIONS,
     &       CACHE%DOF_LAYOUT, CACHE%RULES, CACHE%GAUSS_LAYOUT,
     &       CACHE%STRUCTURAL_GEOMETRY, CACHE%EXPANSION_GEOMETRY,
     &       CACHE%GEOMETRY, CACHE%FRAMES, CACHE%MATERIAL_CACHE,
     &       CACHE%MATERIAL_MAP, MATRICES, LOCAL_STATUS, MITC,
     &       WITH_MASS, FORCE_GENERAL, PART_NORMAL)
            CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                      ! Merge status local_status into status.
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            CALL BUILD_LINEAR_ELEMENT_MATRICES(ELEMENT, MODEL%NODES,     ! Call build linear element matrices with element, model.nodes, model.elements, model.kinematics, model.expan...
     &       MODEL%ELEMENTS, MODEL%KINEMATICS, MODEL%EXPANSIONS,
     &       CACHE%DOF_LAYOUT, CACHE%RULES, CACHE%REDUCED%GAUSS_LAYOUT,
     &       CACHE%REDUCED%STRUCTURAL_GEOMETRY,
     &       CACHE%EXPANSION_GEOMETRY, CACHE%REDUCED%GEOMETRY,
     &       CACHE%FRAMES, CACHE%MATERIAL_CACHE,
     &       CACHE%REDUCED%MATERIAL_MAP, SECOND, LOCAL_STATUS, MITC,
     &       .FALSE., FORCE_GENERAL, PART_SHEAR)
            CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                      ! Merge status local_status into status.
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            MATRICES%STIFFNESS = MATRICES%STIFFNESS + SECOND%STIFFNESS   ! Add second.stiffness to matrices.stiffness.
            CALL CLEAR_ELEMENT_MATRIX(SECOND)                            ! Call clear element matrix with second.
          END IF                                                         ! End of the IF block.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      CALL PREPARE_ELEMENT_MITC(MODEL, CACHE, ELEMENT, MITC,             ! Call prepare element mitc with model, cache, element, mitc, local_status.
     &                          LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_LINEAR_ELEMENT_MATRICES(ELEMENT, MODEL%NODES,           ! Call build linear element matrices with element, model.nodes, model.elements, model.kinematics, model.expan...
     &     MODEL%ELEMENTS, MODEL%KINEMATICS, MODEL%EXPANSIONS,
     &     CACHE%DOF_LAYOUT, CACHE%RULES, CACHE%GAUSS_LAYOUT,
     &     CACHE%STRUCTURAL_GEOMETRY, CACHE%EXPANSION_GEOMETRY,
     &     CACHE%GEOMETRY, CACHE%FRAMES, CACHE%MATERIAL_CACHE,
     &     CACHE%MATERIAL_MAP, MATRICES, LOCAL_STATUS, MITC,
     &     WITH_MASS, FORCE_GENERAL)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.

      END SUBROUTINE EVALUATE_ELEMENT_BASE                               ! End of the subroutine evaluate element base.

!  K AND M (OR THE THERMOELASTIC BLOCK) OF A CURVED BEAM / SHELL.
!  NONE: COMPATIBLE STRAINS; MITC: TIED STRAINS; REDI / SELI ARE NOT
!  DEFINED FOR THE GENERAL GEOMETRY.
      SUBROUTINE GENERAL_ELEMENT(MODEL, CACHE, ELEMENT, MODE, MATRICES,  ! Subroutine general element takes model, cache, element, mode, matrices, status, with mass, coupling.
     &                           STATUS, WITH_MASS, COUPLING)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      INTEGER(I4), INTENT(IN) :: MODE                                    ! Input integer (int32): mode.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      LOGICAL, INTENT(IN) :: WITH_MASS                                   ! Input logical: with_mass.
      LOGICAL, INTENT(IN) :: COUPLING                                    ! Input logical: coupling.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (MODE .EQ. SHEAR_REDUCED .OR. MODE .EQ. SHEAR_SELECTIVE) THEN   ! If mode = shear_reduced or mode = shear_selective:
        CALL SET_ERROR(STATUS, 'GENERAL_ELEMENT',                        ! Record an error in status: 'REDI / SELI ARE NOT DEFINED FOR CURVED BEAMS AND SHELLS: '// 'USE NONE OR MITC'.
     &    'REDI / SELI ARE NOT DEFINED FOR CURVED BEAMS AND SHELLS: '//
     &    'USE NONE OR MITC')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL BUILD_GENERAL_ELEMENT_MATRICES(ELEMENT, MODEL%NODES,          ! Call build general element matrices with element, model.nodes, model.elements, model.kinematics, model.expa...
     &     MODEL%ELEMENTS, MODEL%KINEMATICS, MODEL%EXPANSIONS,
     &     CACHE%DOF_LAYOUT, CACHE%RULES, CACHE%GAUSS_LAYOUT,
     &     CACHE%STRUCTURAL_GEOMETRY, CACHE%EXPANSION_GEOMETRY,
     &     CACHE%GEOMETRY, CACHE%FRAMES, CACHE%MATERIAL_CACHE,
     &     CACHE%MATERIAL_MAP, MATRICES, STATUS, MODE .EQ. SHEAR_MITC,
     &     WITH_MASS, COUPLING)

      END SUBROUTINE GENERAL_ELEMENT                                     ! End of the subroutine general element.

      END MODULE MUL2_MODEL_ASSEMBLY                                     ! End of the module mul2 model assembly.
