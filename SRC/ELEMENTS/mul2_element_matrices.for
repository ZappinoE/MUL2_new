!=======================================================================
!  DENSE REFERENCE ELEMENT MATRICES FOR LINEAR MECHANICS.
!=======================================================================
      MODULE MUL2_ELEMENT_MATRICES                                       ! Module mul2 element matrices begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       SET_ERROR, STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, FIND_NODE_INDEX                ! Use from module mul2 nodes: node db type, find node index.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION              ! Use from module mul2 topologies: topology natural dimension.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE,                     ! Use from module mul2 kinematics: kinematics db type, expansion spec type, find kinematic index, field p, fi...
     &                           EXPANSION_SPEC_TYPE,
     &                           FIND_KINEMATIC_INDEX,
     &                           FIELD_P, FIELD_T, N_SOLVED_FIELDS
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE                 ! Use from module mul2 expansion meshes: expansion db type.
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type.
     &                             GAUSS_LAYOUT_TYPE
      USE MUL2_GAUSS_GEOMETRY, ONLY:                                     ! Use from module mul2 gauss geometry: structural geometry cache type, expansion geometry cache type, gauss g...
     &     STRUCTURAL_GEOMETRY_CACHE_TYPE,
     &     EXPANSION_GEOMETRY_CACHE_TYPE, GAUSS_GEOMETRY_TYPE
      USE MUL2_GAUSS_MATERIALS, ONLY: MATERIAL_CACHE_TYPE,               ! Use from module mul2 gauss materials: material cache type, gauss material map type, stiffness part, part fu...
     &                               GAUSS_MATERIAL_MAP_TYPE,
     &                               STIFFNESS_PART, PART_FULL,
     &                               GENERALIZED_CONSTITUTIVE,
     &                               THERMAL_STRESS_COEFFICIENT
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE, GLOBAL_DOF             ! Use from module mul2 dof layout: dof layout type, global dof.
      USE MUL2_POINT_BASES, ONLY: EVALUATE_POINT_FACTORS                 ! Use from module mul2 point bases: evaluate point factors.
      USE MUL2_MITC, ONLY: MITC_DATA_TYPE, MITC_TIE_COLUMN               ! Use from module mul2 mitc: mitc data type, mitc tie column.
      USE MUL2_LINEAR_KINEMATICS, ONLY: COMPOSE_PRODUCT_BASIS            ! Use from module mul2 linear kinematics: compose product basis.
      USE MUL2_LINEAR_KINEMATICS, ONLY:                                  ! Use from module mul2 linear kinematics: build displacement operator.
     &     BUILD_DISPLACEMENT_OPERATOR
      USE MUL2_DENSE_PRODUCTS, ONLY: ACCUMULATE_UPPER_PRODUCT,           ! Use from module mul2 dense products: accumulate upper product, accumulate product.
     &                               ACCUMULATE_PRODUCT
      USE MUL2_SEPARABLE_KERNEL, ONLY: BUILD_SEPARABLE_MATRICES          ! Use from module mul2 separable kernel: build separable matrices.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: ELEMENT_MATRIX_TYPE                                ! Definition of the derived type element matrix type.
        INTEGER(I4) :: ELEMENT_INDEX = 0_I4                              ! Integer (int32): element_index = 0.
        INTEGER(I4) :: LOCAL_DOF_COUNT = 0_I4                            ! Integer (int32): local_dof_count = 0.
        INTEGER(I8), ALLOCATABLE :: GLOBAL_DOF(:)                        ! Allocatable integer (int64): global_dof(:).
        INTEGER(I4), ALLOCATABLE :: NODE_INDEX(:)                        ! Allocatable integer (int32): node_index(:).
        INTEGER(I4), ALLOCATABLE :: KINEMATIC_INDEX(:)                   ! Allocatable integer (int32): kinematic_index(:).
        INTEGER(I4), ALLOCATABLE :: STRUCTURAL_NODE(:)                   ! Allocatable integer (int32): structural_node(:).
        INTEGER(I4), ALLOCATABLE :: FIELD(:)                             ! Allocatable integer (int32): field(:).
        INTEGER(I4), ALLOCATABLE :: TERM(:)                              ! Allocatable integer (int32): term(:).
        INTEGER(I8), ALLOCATABLE :: CSR_POSITION(:,:)                    ! Allocatable integer (int64): csr_position(:,:).
        REAL(R8), ALLOCATABLE :: STIFFNESS(:,:)                          ! Allocatable real (real64): stiffness(:,:).
        REAL(R8), ALLOCATABLE :: MASS(:,:)                               ! Allocatable real (real64): mass(:,:).
!       INTERNAL FORCE OF THE NONLINEAR (TOTAL LAGRANGIAN) ELEMENT.
        REAL(R8), ALLOCATABLE :: INTERNAL_FORCE(:)                       ! Allocatable real (real64): internal_force(:).
      END TYPE ELEMENT_MATRIX_TYPE                                       ! End of the type definition element matrix type.

      INTEGER(I4), PARAMETER :: MAX_BATCH = 128_I4                       ! Constant integer (int32): max_batch = 128.

!  WORKSPACE OF THE POINT-BY-POINT KERNELS. THE BASIS OF A DEGREE OF
!  FREEDOM IS N_NODE * F_TERM: THE STRUCTURAL FACTORS (ONE PER NODE) AND
!  THE EXPANSION FACTORS (ONE PER TERM AND PER DISTINCT EXPANSION) ARE
!  EVALUATED ONCE PER POINT AND COMBINED FOR EVERY DOF, INSTEAD OF
!  RE-EVALUATING BOTH FOR EACH OF THE (OFTEN HUNDREDS OF) DOFS.
      TYPE :: POINT_WORK_TYPE                                            ! Definition of the derived type point work type.
        INTEGER(I4) :: N_MEMO = 0_I4                                     ! Integer (int32): n_memo = 0.
        INTEGER(I4), ALLOCATABLE :: MEMO_OF(:)                           ! Allocatable integer (int32): memo_of(:).
        INTEGER(I4), ALLOCATABLE :: MEMO_NODE(:)                         ! Allocatable integer (int32): memo_node(:).
        INTEGER(I4), ALLOCATABLE :: MEMO_TERMS(:)                        ! Allocatable integer (int32): memo_terms(:).
        INTEGER(I4), ALLOCATABLE :: MEMO_KIN(:)                          ! Allocatable integer (int32): memo_kin(:).
        INTEGER(I4), ALLOCATABLE :: MEMO_FIELD(:)                        ! Allocatable integer (int32): memo_field(:).
        REAL(R8), ALLOCATABLE :: SVAL(:)                                 ! Allocatable real (real64): sval(:).
        REAL(R8), ALLOCATABLE :: SGRAD(:,:)                              ! Allocatable real (real64): sgrad(:,:).
        REAL(R8), ALLOCATABLE :: FVAL(:,:)                               ! Allocatable real (real64): fval(:,:).
        REAL(R8), ALLOCATABLE :: FGRAD(:,:,:)                            ! Allocatable real (real64): fgrad(:,:,:).
        REAL(R8), ALLOCATABLE :: VALUE(:)                                ! Allocatable real (real64): value(:).
        REAL(R8), ALLOCATABLE :: BCOL(:,:)                               ! Allocatable real (real64): bcol(:,:).
        REAL(R8), ALLOCATABLE :: GRAD(:,:)                               ! Allocatable real (real64): grad(:,:).
      END TYPE POINT_WORK_TYPE                                           ! End of the type definition point work type.

      PUBLIC :: BUILD_LINEAR_ELEMENT_MATRICES                            ! Export: build linear element matrices.
      PUBLIC :: BUILD_ELEMENT_DOF_LIST                                   ! Export: build element dof list.
      PUBLIC :: BUILD_NONLINEAR_ELEMENT_MATRICES                         ! Export: build nonlinear element matrices.
      PUBLIC :: CLEAR_ELEMENT_MATRIX                                     ! Export: clear element matrix.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_LINEAR_ELEMENT_MATRICES(ELEMENT_INDEX,            ! Subroutine build linear element matrices takes element index, nodes, elements, kinematics, expansions, dof ...
     &     NODES, ELEMENTS, KINEMATICS, EXPANSIONS, DOF_LAYOUT,
     &     RULES, GAUSS_LAYOUT, STRUCTURAL_CACHE,
     &     EXPANSION_CACHE, GEOMETRY, FRAMES, MATERIAL_CACHE,
     &     MATERIAL_MAP, MATRICES, STATUS, MITC, WITH_MASS,
     &     FORCE_GENERAL, PART, WITH_STIFFNESS, COUPLING, GEOMETRIC,
     &     U0)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: MATERIAL_CACHE            ! Input of type material_cache_type: material_cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(IN) :: MATERIAL_MAP          ! Input of type gauss_material_map_type: material_map.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(MITC_DATA_TYPE), INTENT(IN), OPTIONAL :: MITC                 ! Input optional of type mitc_data_type: mitc.
      LOGICAL, INTENT(IN), OPTIONAL :: WITH_MASS                         ! Input optional logical: with_mass.
      LOGICAL, INTENT(IN), OPTIONAL :: FORCE_GENERAL                     ! Input optional logical: force_general.
!     PART: PART_FULL, PART_NORMAL OR PART_SHEAR OF THE CONSTITUTIVE
!     MATRIX (SELECTIVE INTEGRATION); WITH_STIFFNESS = .FALSE. SKIPS K.
      INTEGER(I4), INTENT(IN), OPTIONAL :: PART                          ! Input optional integer (int32): part.
      LOGICAL, INTENT(IN), OPTIONAL :: WITH_STIFFNESS                    ! Input optional logical: with_stiffness.
!     COUPLING = .TRUE.: STIFFNESS RECEIVES ONLY THE THERMOELASTIC
!     COUPLING BLOCK K(U,T) = - SUM_P W B^T (C ALPHA) N_T (NOT
!     SYMMETRIC: THE BLOCK K(T,U) IS ZERO IN THE STATIONARY PROBLEM).
      LOGICAL, INTENT(IN), OPTIONAL :: COUPLING                          ! Input optional logical: coupling.
!     GEOMETRIC = .TRUE.: STIFFNESS RECEIVES THE GEOMETRIC (INITIAL
!     STRESS) MATRIX OF THE STATE U0 (GLOBAL DOF VECTOR):
!     K_G(I,J) = SUM_P W (D_I.D_J) GRAD N_I . S GRAD N_J,
!     WITH S THE STRESS TENSOR OF U0 (ELEMENT FRAME) AND D THE LOCAL
!     DIRECTION OF THE DISPLACEMENT COMPONENT OF A DOF.
      LOGICAL, INTENT(IN), OPTIONAL :: GEOMETRIC                         ! Input optional logical: geometric.
      REAL(R8), INTENT(IN), OPTIONAL :: U0(:)                            ! Input optional real (real64): u0(:).
      LOGICAL :: GEOMETRY_REQUESTED                                      ! Logical: geometry_requested.
      REAL(R8), ALLOCATABLE :: GRAD_STORE(:,:)                           ! Allocatable real (real64): grad_store(:,:).
      REAL(R8), ALLOCATABLE :: SG_STORE(:,:)                             ! Allocatable real (real64): sg_store(:,:).
      REAL(R8), ALLOCATABLE :: P_STORE(:,:)                              ! Allocatable real (real64): p_store(:,:).
      REAL(R8), ALLOCATABLE :: Q_STORE(:,:)                              ! Allocatable real (real64): q_store(:,:).
      REAL(R8) :: GRAD_POINT(3)                                          ! Real (real64): grad_point(3).
      REAL(R8) :: GAMMA_V(12)                                            ! Real (real64): gamma_v(12).
      REAL(R8) :: STRESS6(6)                                             ! Real (real64): stress6(6).
      REAL(R8) :: STRESS3(3,3)                                           ! Real (real64): stress3(3,3).
      REAL(R8) :: THETA_POINT                                            ! Real (real64): theta_point.
      INTEGER(I4) :: CPART                                               ! Integer (int32): cpart.
      INTEGER(I4) :: CDIM                                                ! Integer (int32): cdim.
      LOGICAL :: STIFFNESS_REQUESTED                                     ! Logical: stiffness_requested.
      LOGICAL :: SEPARABLE                                               ! Logical: separable.
      TYPE(MITC_DATA_TYPE) :: MITC_DATA                                  ! Of type mitc_data_type: mitc_data.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      REAL(R8), ALLOCATABLE :: BASIS_VALUE(:,:)                          ! Allocatable real (real64): basis_value(:,:).
      REAL(R8), ALLOCATABLE :: B_TEST(:,:)                               ! Allocatable real (real64): b_test(:,:).
      REAL(R8), ALLOCATABLE :: B_WEIGHTED(:,:)                           ! Allocatable real (real64): b_weighted(:,:).
      REAL(R8) :: B_COLUMN(12)                                           ! Real (real64): b_column(12).
      REAL(R8) :: STIFFNESS_LOCAL(12,12)                                 ! Real (real64): stiffness_local(12,12).
      REAL(R8) :: WEIGHT                                                 ! Real (real64): weight.
      REAL(R8) :: POINT_VALUE                                            ! Real (real64): point_value.
      REAL(R8) :: BETA(6)                                                ! Real (real64): beta(6).
      REAL(R8), ALLOCATABLE :: THETA_VALUE(:)                            ! Allocatable real (real64): theta_value(:).
      TYPE(POINT_WORK_TYPE) :: PWORK                                     ! Of type point_work_type: pwork.
      LOGICAL :: THERMAL_REQUESTED                                       ! Logical: thermal_requested.
      INTEGER(I4) :: NR                                                  ! Integer (int32): nr.
      REAL(R8) :: POINT_MASS(MAX_BATCH)                                  ! Real (real64): point_mass(max_batch).
      REAL(R8) :: POINT_CAPACITY(MAX_BATCH)                              ! Real (real64): point_capacity(max_batch).
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I8) :: FIRST_POINT                                         ! Integer (int64): first_point.
      INTEGER(I8) :: LAST_POINT                                          ! Integer (int64): last_point.
      INTEGER(I4) :: MATERIAL_INDEX                                      ! Integer (int32): material_index.
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: BATCH                                               ! Integer (int32): batch.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.
      LOGICAL :: MASS_REQUESTED                                          ! Logical: mass_requested.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_ELEMENT_MATRIX(MATRICES)                                ! Call clear element matrix with matrices.
      IF (PRESENT(MITC)) MITC_DATA = MITC                                ! If present(mitc), set mitc_data to mitc.
      MASS_REQUESTED = .TRUE.                                            ! Set the flag mass_requested to true.
      IF (PRESENT(WITH_MASS)) MASS_REQUESTED = WITH_MASS                 ! If present(with_mass), set mass_requested to with_mass.
      CPART = PART_FULL                                                  ! Set cpart to part_full.
      IF (PRESENT(PART)) CPART = PART                                    ! If present(part), set cpart to part.
!     NUMBER OF GENERALISED STRAIN ROWS: 6 (MECHANICS) OR 9 (WITH THE
!     POTENTIAL GRADIENT OF THE ELECTRIC FIELD, FIELD 5).
      NR = 6_I4                                                          ! Set nr to 6.
      CDIM = TOPOLOGY_NATURAL_DIMENSION(                                 ! Set cdim to topology_natural_dimension( elements.item(element_index).topology).
     &       ELEMENTS%ITEM(ELEMENT_INDEX)%TOPOLOGY)
      STIFFNESS_REQUESTED = .TRUE.                                       ! Set the flag stiffness_requested to true.
      IF (PRESENT(WITH_STIFFNESS)) STIFFNESS_REQUESTED = WITH_STIFFNESS  ! If present(with_stiffness), set stiffness_requested to with_stiffness.
      CALL VALIDATE_INPUT(ELEMENT_INDEX, NODES, ELEMENTS,                ! Call validate input with element_index, nodes, elements, kinematics, dof_layout, gauss_layout, geometry, fr...
     &     KINEMATICS, DOF_LAYOUT, GAUSS_LAYOUT, GEOMETRY,
     &     FRAMES, MATERIAL_CACHE, MATERIAL_MAP, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL BUILD_ELEMENT_DOF_LIST(ELEMENT_INDEX, NODES, ELEMENTS,        ! Call build element dof list with element_index, nodes, elements, kinematics, dof_layout, matrices, status.
     &     KINEMATICS, DOF_LAYOUT, MATRICES, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      N_DOF = MATRICES%LOCAL_DOF_COUNT                                   ! Set n_dof to matrices.local_dof_count.
      ALLOCATE(MATRICES%STIFFNESS(N_DOF,N_DOF))                          ! Allocate memory for matrices.stiffness(n_dof,n_dof).
      MATRICES%STIFFNESS = 0.0_R8                                        ! Set matrices.stiffness to zero.
      IF (MASS_REQUESTED) THEN                                           ! If mass_requested:
        ALLOCATE(MATRICES%MASS(N_DOF,N_DOF))                             ! Allocate memory for matrices.mass(n_dof,n_dof).
        MATRICES%MASS = 0.0_R8                                           ! Set matrices.mass to zero.
        ALLOCATE(BASIS_VALUE(MAX_BATCH,N_DOF))                           ! Allocate memory for basis_value(max_batch,n_dof).
      ELSE                                                               ! Otherwise:
!       THE SPARSE SCATTER ONLY READS MASS WHEN IT IS ALLOCATED.
        ALLOCATE(MATRICES%MASS(0,0))                                     ! Allocate memory for matrices.mass(0,0).
      END IF                                                             ! End of the IF block.
!     SEPARABLE CUF PATH (STRUCTURAL AND EXPANSION POINTS ADD UP
!     INSTEAD OF MULTIPLYING). THE POINT-BY-POINT PATH BELOW IS THE
!     REFERENCE AND THE FALLBACK FOR NON-SEPARABLE ELEMENTS.
      SEPARABLE = .FALSE.                                                ! Set the flag separable to false.
      THERMAL_REQUESTED = .FALSE.                                        ! Set the flag thermal_requested to false.
      IF (PRESENT(COUPLING)) THERMAL_REQUESTED = COUPLING                ! If present(coupling), set thermal_requested to coupling.
      GEOMETRY_REQUESTED = .FALSE.                                       ! Set the flag geometry_requested to false.
      IF (PRESENT(GEOMETRIC)) GEOMETRY_REQUESTED = GEOMETRIC             ! If present(geometric), set geometry_requested to geometric.
      IF (GEOMETRY_REQUESTED) THEN                                       ! If geometry_requested:
        IF (.NOT. PRESENT(U0)) THEN                                      ! If not present(u0):
          CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',        ! Record an error in status: 'THE GEOMETRIC MATRIX NEEDS A STATE VECTOR'.
     &                   'THE GEOMETRIC MATRIX NEEDS A STATE VECTOR')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        ALLOCATE(GRAD_STORE(3,N_DOF), SG_STORE(3,N_DOF),                 ! Allocate memory for grad_store(3,n_dof), sg_store(3,n_dof), p_store(9,n_dof), q_store(9,n_dof).
     &           P_STORE(9,N_DOF), Q_STORE(9,N_DOF))
      END IF                                                             ! End of the IF block.
      IF (THERMAL_REQUESTED .OR. GEOMETRY_REQUESTED) THEN                ! If thermal_requested or geometry_requested:
        ALLOCATE(THETA_VALUE(N_DOF))                                     ! Allocate memory for theta_value(n_dof).
      ELSE IF (.NOT. PRESENT(FORCE_GENERAL)) THEN                        ! Otherwise, if not present(force_general):
        CALL TRY_SEPARABLE()                                             ! Call try separable.
      ELSE IF (.NOT. FORCE_GENERAL) THEN                                 ! Otherwise, if not force_general:
        CALL TRY_SEPARABLE()                                             ! Call try separable.
      END IF                                                             ! End of the IF block.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (SEPARABLE) THEN                                                ! If separable:
        CALL MIRROR_UPPER_TRIANGLE(MATRICES, MASS_REQUESTED)             ! Call mirror upper triangle with matrices, mass_requested.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      MATRICES%STIFFNESS = 0.0_R8                                        ! Set matrices.stiffness to zero.
      IF (MASS_REQUESTED) MATRICES%MASS = 0.0_R8                         ! If mass_requested, set matrices.mass to zero.
!     BATCH OF POINTS: K = SUM_P (B_P)T (W_P C B_P) IS ONE MATRIX
!     PRODUCT OVER 6*BATCH ROWS, INSTEAD OF A SCALAR NUCLEUS PER PAIR.
      IF (ANY(MATRICES%FIELD .EQ. FIELD_P)) NR = 9_I4                    ! If any(matrices.field = field_p), set nr to 9.
      IF (ANY(MATRICES%FIELD .EQ. FIELD_T)) NR = 12_I4                   ! If any(matrices.field = field_t), set nr to 12.
      BATCH = MAX(1_I4, MIN(MAX_BATCH, INT(2.0E6_R8/                     ! Set batch to the larger of 1 and min(max_batch, int(2.0e6/ (real(nr,r8)*real(n_dof,r8)),i4)).
     &        (REAL(NR,R8)*REAL(N_DOF,R8)),I4)))
      ALLOCATE(B_TEST(NR*BATCH,N_DOF))                                   ! Allocate memory for b_test(nr*batch,n_dof).
      ALLOCATE(B_WEIGHTED(NR*BATCH,N_DOF))                               ! Allocate memory for b_weighted(nr*batch,n_dof).
      CALL SETUP_POINT_WORK(MATRICES, KINEMATICS, PWORK)                 ! Call setup point work with matrices, kinematics, pwork.

      FIRST_POINT = GAUSS_LAYOUT%ELEMENT_FIRST(ELEMENT_INDEX)            ! Set first_point to gauss_layout.element_first(element_index).
      DO WHILE (FIRST_POINT .LE.                                         ! Repeat while first_point <= gauss_layout.element_last(element_index):
     &          GAUSS_LAYOUT%ELEMENT_LAST(ELEMENT_INDEX))
        LAST_POINT = MIN(GAUSS_LAYOUT%ELEMENT_LAST(ELEMENT_INDEX),       ! Set last_point to the smaller of gauss_layout.element_last(element_index) and first_point+int(batch,i8)-1.
     &                   FIRST_POINT+INT(BATCH,I8)-1_I8)
        COUNT = INT(LAST_POINT-FIRST_POINT+1_I8,I4)                      ! Set count to int(last_point-first_point+1,i4).
        DO POINT = FIRST_POINT, LAST_POINT                               ! Loop point from first_point to last_point:
          Q = INT(POINT-FIRST_POINT,I4)                                  ! Set q to int(point-first_point,i4).
          MATERIAL_INDEX = MATERIAL_MAP%CACHE_INDEX(POINT)               ! Set material_index to material_map.cache_index(point).
          IF (MATERIAL_INDEX .LT. 1_I4 .OR. MATERIAL_INDEX .GT.          ! If material_index < 1 or material_index > material_cache.count:
     &        MATERIAL_CACHE%COUNT) THEN
            CALL SET_ERROR(STATUS,                                       ! Record an error in status: 'GAUSS POINT MATERIAL INDEX IS OUT OF RANGE'.
     &        'BUILD_LINEAR_ELEMENT_MATRICES',
     &        'GAUSS POINT MATERIAL INDEX IS OUT OF RANGE')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          WEIGHT = GEOMETRY%INTEGRATION_WEIGHT(POINT)                    ! Set weight to geometry.integration_weight(point).
          STIFFNESS_LOCAL = WEIGHT*GENERALIZED_CONSTITUTIVE(             ! Set stiffness_local to weight*generalized_constitutive( material_cache, material_index, cpart, cdim).
     &                      MATERIAL_CACHE, MATERIAL_INDEX, CPART, CDIM)
          POINT_MASS(Q+1_I4) = WEIGHT*                                   ! Set point_mass(q+1) to weight* material_cache.density(material_index).
     &      MATERIAL_CACHE%DENSITY(MATERIAL_INDEX)
          POINT_CAPACITY(Q+1_I4) = POINT_MASS(Q+1_I4)*                   ! Set point_capacity(q+1) to point_mass(q+1)* material_cache.specific_heat(material_index).
     &      MATERIAL_CACHE%SPECIFIC_HEAT(MATERIAL_INDEX)
          IF (THERMAL_REQUESTED .OR. GEOMETRY_REQUESTED) THEN            ! If thermal_requested or geometry_requested:
            THETA_VALUE = 0.0_R8                                         ! Set theta_value to zero.
            BETA = THERMAL_STRESS_COEFFICIENT(MATERIAL_CACHE,            ! Set beta to thermal_stress_coefficient(material_cache, material_index).
     &                                        MATERIAL_INDEX)
          END IF                                                         ! End of the IF block.
          CALL EVALUATE_POINT_COLUMNS(POINT, ELEMENT_INDEX,              ! Call evaluate point columns with point, element_index, elements, kinematics, expansions, rules, gauss_layou...
     &         ELEMENTS, KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &         STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &         MATRICES, MITC_DATA, PWORK, LOCAL_STATUS)
          DO I = 1_I4, N_DOF                                             ! Loop i from 1 to n_dof:
            POINT_VALUE = PWORK%VALUE(I)                                 ! Set point_value to pwork.value(i).
            B_COLUMN = PWORK%BCOL(:,I)                                   ! Set b_column to pwork.bcol(:,i).
            GRAD_POINT = PWORK%GRAD(:,I)                                 ! Set grad_point to pwork.grad(:,i).
            IF (MASS_REQUESTED) BASIS_VALUE(Q+1_I4,I) = POINT_VALUE      ! If mass_requested, set basis_value(q+1,i) to point_value.
            IF (THERMAL_REQUESTED .OR. GEOMETRY_REQUESTED) THEN          ! If thermal_requested or geometry_requested:
              IF (MATRICES%FIELD(I) .EQ. FIELD_T) THETA_VALUE(I) =       ! If matrices.field(i) = field_t, set theta_value(i) to point_value.
     &          POINT_VALUE
            END IF                                                       ! End of the IF block.
            IF (GEOMETRY_REQUESTED) GRAD_STORE(:,I) = GRAD_POINT         ! If geometry_requested, set grad_store(:,i) to grad_point.
            IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                   ! If not local_status is ok:
              CALL SET_ERROR(STATUS,                                     ! Record an error in status: trim(local_status.message).
     &          'BUILD_LINEAR_ELEMENT_MATRICES',
     &          TRIM(LOCAL_STATUS%MESSAGE))
              RETURN                                                     ! Return to the caller.
            END IF                                                       ! End of the IF block.
            B_TEST(NR*Q+1:NR*Q+NR,I) = B_COLUMN(1:NR)                    ! Set b_test(nr*q+1:nr*q+nr,i) to b_column(1:nr).
            B_WEIGHTED(NR*Q+1:NR*Q+NR,I) =                               ! Set b_weighted(nr*q+1:nr*q+nr,i) to matmul(stiffness_local(1:nr,1:nr),b_column(1:nr)).
     &        MATMUL(STIFFNESS_LOCAL(1:NR,1:NR),B_COLUMN(1:NR))
          END DO                                                         ! End of the loop.
          IF (THERMAL_REQUESTED) THEN                                    ! If thermal_requested:
            DO I = 1_I4, N_DOF                                           ! Loop i from 1 to n_dof:
              IF (MATRICES%FIELD(I) .GT. 3_I4) CYCLE                     ! If matrices.field(i) > 3, skip to the next iteration.
              DO J = 1_I4, N_DOF                                         ! Loop j from 1 to n_dof:
                IF (MATRICES%FIELD(J) .NE. FIELD_T) CYCLE                ! If matrices.field(j) /= field_t, skip to the next iteration.
                MATRICES%STIFFNESS(I,J) = MATRICES%STIFFNESS(I,J) -      ! Subtract weight*theta_value(j)*dot_product( b_test(nr*q+1:nr*q+6,i),beta) from matrices.stiffness(i,j).
     &            WEIGHT*THETA_VALUE(J)*DOT_PRODUCT(
     &            B_TEST(NR*Q+1:NR*Q+6,I),BETA)
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
!           PYROELECTRIC COUPLING: D = ... + P T ENTERS THE POTENTIAL
!           ROW, K(PHI,T) = SUM_P W (GRAD N_PHI . P) N_T.
            IF (MATERIAL_CACHE%ANY_PYRO) THEN                            ! If material_cache.any_pyro:
              DO I = 1_I4, N_DOF                                         ! Loop i from 1 to n_dof:
                IF (MATRICES%FIELD(I) .NE. FIELD_P) CYCLE                ! If matrices.field(i) /= field_p, skip to the next iteration.
                DO J = 1_I4, N_DOF                                       ! Loop j from 1 to n_dof:
                  IF (MATRICES%FIELD(J) .NE. FIELD_T) CYCLE              ! If matrices.field(j) /= field_t, skip to the next iteration.
                  MATRICES%STIFFNESS(I,J) = MATRICES%STIFFNESS(I,J) +    ! Add weight*theta_value(j)*dot_product( b_test(nr*q+7:nr*q+9,i), material_cache.pyro_local(:,material_index)...
     &              WEIGHT*THETA_VALUE(J)*DOT_PRODUCT(
     &              B_TEST(NR*Q+7:NR*Q+9,I),
     &              MATERIAL_CACHE%PYRO_LOCAL(:,MATERIAL_INDEX))
                END DO                                                   ! End of the loop.
              END DO                                                     ! End of the loop.
            END IF                                                       ! End of the IF block.
          END IF                                                         ! End of the IF block.
          IF (GEOMETRY_REQUESTED) THEN                                   ! If geometry_requested:
!           STRESS OF THE STATE AT THE POINT: S = M(1:6,:) GAMMA - BETA T
            GAMMA_V = 0.0_R8                                             ! Set gamma_v to zero.
            THETA_POINT = 0.0_R8                                         ! Set theta_point to zero.
            DO I = 1_I4, N_DOF                                           ! Loop i from 1 to n_dof:
              GAMMA_V(1:NR) = GAMMA_V(1:NR) + B_TEST(NR*Q+1:NR*Q+NR,I)*  ! Add b_test(nr*q+1:nr*q+nr,i)* u0(matrices.global_dof(i)) to gamma_v(1:nr).
     &                        U0(MATRICES%GLOBAL_DOF(I))
              IF (MATRICES%FIELD(I) .EQ. FIELD_T) THETA_POINT =          ! If matrices.field(i) = field_t, add theta_value(i)*u0(matrices.global_dof(i)) to theta_point.
     &          THETA_POINT + THETA_VALUE(I)*U0(MATRICES%GLOBAL_DOF(I))
            END DO                                                       ! End of the loop.
            STRESS6 = MATMUL(STIFFNESS_LOCAL(1:6,1:NR),GAMMA_V(1:NR))/   ! Set stress6 to matmul(stiffness_local(1:6,1:nr),gamma_v(1:nr))/ weight - beta*theta_point.
     &                WEIGHT - BETA*THETA_POINT
            STRESS3(1,:) = [STRESS6(1),STRESS6(6),STRESS6(4)]            ! Set stress3(1,:) to [stress6(1),stress6(6),stress6(4)].
            STRESS3(2,:) = [STRESS6(6),STRESS6(2),STRESS6(5)]            ! Set stress3(2,:) to [stress6(6),stress6(2),stress6(5)].
            STRESS3(3,:) = [STRESS6(4),STRESS6(5),STRESS6(3)]            ! Set stress3(3,:) to [stress6(4),stress6(5),stress6(3)].
!           THE PAIR TERM (D_I.D_J)(GRAD N_I . S GRAD N_J) IS A RANK-9
!           PRODUCT P^T Q (SEE THE NONLINEAR ELEMENT), ACCUMULATED ON
!           THE UPPER TRIANGLE; THE CALLER MIRRORS IT AT THE END.
            DO J = 1_I4, N_DOF                                           ! Loop j from 1 to n_dof:
              SG_STORE(:,J) = MATMUL(STRESS3,GRAD_STORE(:,J))            ! Set sg_store(:,j) to matmul(stress3,grad_store(:,j)).
              P_STORE(:,J) = 0.0_R8                                      ! Set p_store(:,j) to zero.
              Q_STORE(:,J) = 0.0_R8                                      ! Set q_store(:,j) to zero.
              IF (MATRICES%FIELD(J) .GT. 3_I4) CYCLE                     ! If matrices.field(j) > 3, skip to the next iteration.
              DO I = 1_I4, 3_I4                                          ! Loop i from 1 to 3:
                P_STORE(3*(I-1)+1:3*I,J) = FRAMES%GLOBAL_TO_LOCAL(I,     ! Set p_store(3*(i-1)+1:3*i,j) to frames.global_to_local(i, matrices.field(j),element_index)*grad_store(:,j).
     &            MATRICES%FIELD(J),ELEMENT_INDEX)*GRAD_STORE(:,J)
                Q_STORE(3*(I-1)+1:3*I,J) = WEIGHT*FRAMES%                ! Set q_store(3*(i-1)+1:3*i,j) to weight*frames. global_to_local(i,matrices.field(j),element_index)* sg_store...
     &            GLOBAL_TO_LOCAL(I,MATRICES%FIELD(J),ELEMENT_INDEX)*
     &            SG_STORE(:,J)
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
            CALL ACCUMULATE_UPPER_PRODUCT(P_STORE, Q_STORE, 9_I4,        ! Call accumulate upper product with p_store, q_store, 9, matrices.stiffness.
     &                                    MATRICES%STIFFNESS)
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        IF (.NOT. (THERMAL_REQUESTED .OR. GEOMETRY_REQUESTED))           ! If not (thermal_requested or geometry_requested), call accumulate upper product with b_test, b_weighted, nr...
     &    CALL ACCUMULATE_UPPER_PRODUCT(B_TEST,
     &         B_WEIGHTED, NR*COUNT, MATRICES%STIFFNESS)
        IF (MASS_REQUESTED) CALL ADD_MASS(MATRICES, BASIS_VALUE,         ! If mass_requested, call add mass with matrices, basis_value, point_mass, point_capacity, count.
     &                                    POINT_MASS, POINT_CAPACITY,
     &                                    COUNT)
        FIRST_POINT = LAST_POINT + 1_I8                                  ! Set first_point to last_point + 1.
      END DO                                                             ! End of the loop.
      IF (GEOMETRY_REQUESTED) CALL MIRROR_UPPER_TRIANGLE(MATRICES,       ! If geometry_requested, call mirror upper triangle with matrices, false.
     &                                                   .FALSE.)
      IF (THERMAL_REQUESTED .OR. GEOMETRY_REQUESTED) RETURN              ! If thermal_requested or geometry_requested, return to the caller.
      IF (.NOT. STIFFNESS_REQUESTED) MATRICES%STIFFNESS = 0.0_R8         ! If not stiffness_requested, set matrices.stiffness to zero.

      CALL MIRROR_UPPER_TRIANGLE(MATRICES, MASS_REQUESTED)               ! Call mirror upper triangle with matrices, mass_requested.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE TRY_SEPARABLE()                                         ! Subroutine try separable.

      CALL BUILD_SEPARABLE_MATRICES(ELEMENT_INDEX, ELEMENTS,             ! Call build separable matrices with element_index, elements, kinematics, expansions, rules, gauss_layout, st...
     &     KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &     STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &     MATERIAL_CACHE, MATERIAL_MAP, MITC_DATA, MATRICES%FIELD,
     &     MATRICES%STRUCTURAL_NODE, MATRICES%TERM,
     &     MATRICES%KINEMATIC_INDEX, MASS_REQUESTED,
     &     MATRICES%STIFFNESS, MATRICES%MASS, SEPARABLE, STATUS,
     &     CPART, STIFFNESS_REQUESTED)

      END SUBROUTINE TRY_SEPARABLE                                       ! End of the subroutine try separable.
      END SUBROUTINE BUILD_LINEAR_ELEMENT_MATRICES                       ! End of the subroutine build linear element matrices.

!  TOTAL LAGRANGIAN (ST. VENANT-KIRCHHOFF) ELEMENT AT THE STATE U0.
!    H = GRAD U (ELEMENT FRAME), E = B U + (H^T H)/2 (GREEN STRAIN),
!    SIGMA = M GAMMA (PK2 STRESS, ELECTRIC DISPLACEMENT, HEAT FLUX),
!    F_INT = SUM_P W B(U)^T SIGMA,
!    K_T   = SUM_P W [ B(U)^T M B(U) + (D_I.D_J) GRAD N_I . S GRAD N_J ]
!  WITH B(U) THE VARIATION OF GAMMA (B + THE TERM H^T GRAD N). THE
!  THERMAL AND PYROELECTRIC LOADS ENTER SIGMA, THE COUPLING BLOCKS
!  K(U,T) AND K(PHI,T) ARE ADDED. MITC TIES ONLY THE LINEAR PART.
      SUBROUTINE BUILD_NONLINEAR_ELEMENT_MATRICES(ELEMENT_INDEX,         ! Subroutine build nonlinear element matrices takes element index, nodes, elements, kinematics, expansions, d...
     &     NODES, ELEMENTS, KINEMATICS, EXPANSIONS, DOF_LAYOUT,
     &     RULES, GAUSS_LAYOUT, STRUCTURAL_CACHE,
     &     EXPANSION_CACHE, GEOMETRY, FRAMES, MATERIAL_CACHE,
     &     MATERIAL_MAP, MATRICES, STATUS, MITC, U0)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: MATERIAL_CACHE            ! Input of type material_cache_type: material_cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(IN) :: MATERIAL_MAP          ! Input of type gauss_material_map_type: material_map.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(MITC_DATA_TYPE), INTENT(IN) :: MITC                           ! Input of type mitc_data_type: mitc.
      REAL(R8), INTENT(IN) :: U0(:)                                      ! Input real (real64): u0(:).
      REAL(R8), ALLOCATABLE :: B_TOTAL(:,:)                              ! Allocatable real (real64): b_total(:,:).
      REAL(R8), ALLOCATABLE :: MB(:,:)                                   ! Allocatable real (real64): mb(:,:).
      REAL(R8), ALLOCATABLE :: SG(:,:)                                   ! Allocatable real (real64): sg(:,:).
      REAL(R8), ALLOCATABLE :: A_STACK(:,:)                              ! Allocatable real (real64): a_stack(:,:).
      REAL(R8), ALLOCATABLE :: B_STACK(:,:)                              ! Allocatable real (real64): b_stack(:,:).
      REAL(R8), ALLOCATABLE :: COUPLE(:,:)                               ! Allocatable real (real64): couple(:,:).
      REAL(R8), ALLOCATABLE :: GRAD(:,:)                                 ! Allocatable real (real64): grad(:,:).
      REAL(R8), ALLOCATABLE :: DIRECTION(:,:)                            ! Allocatable real (real64): direction(:,:).
      REAL(R8), ALLOCATABLE :: VALUE(:)                                  ! Allocatable real (real64): value(:).
      REAL(R8), ALLOCATABLE :: UVALUE(:)                                 ! Allocatable real (real64): uvalue(:).
      TYPE(POINT_WORK_TYPE) :: PWORK                                     ! Of type point_work_type: pwork.
      REAL(R8) :: B_COLUMN(12)                                           ! Real (real64): b_column(12).
      REAL(R8) :: GRAD_POINT(3)                                          ! Real (real64): grad_point(3).
      REAL(R8) :: POINT_VALUE                                            ! Real (real64): point_value.
      REAL(R8) :: MCON(12,12)                                            ! Real (real64): mcon(12,12).
      REAL(R8) :: GAMMA_V(12)                                            ! Real (real64): gamma_v(12).
      REAL(R8) :: SIGMA(12)                                              ! Real (real64): sigma(12).
      REAL(R8) :: BETA(6)                                                ! Real (real64): beta(6).
      REAL(R8) :: H(3,3)                                                 ! Real (real64): h(3,3).
      REAL(R8) :: HH(3,3)                                                ! Real (real64): hh(3,3).
      REAL(R8) :: S3(3,3)                                                ! Real (real64): s3(3,3).
      REAL(R8) :: W3(3)                                                  ! Real (real64): w3(3).
      REAL(R8) :: THETA_POINT                                            ! Real (real64): theta_point.
      REAL(R8) :: WEIGHT                                                 ! Real (real64): weight.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I4) :: NR                                                  ! Integer (int32): nr.
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: CDIM                                                ! Integer (int32): cdim.
      INTEGER(I4) :: MATERIAL_INDEX                                      ! Integer (int32): material_index.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_ELEMENT_MATRIX(MATRICES)                                ! Call clear element matrix with matrices.
      CDIM = TOPOLOGY_NATURAL_DIMENSION(                                 ! Set cdim to topology_natural_dimension( elements.item(element_index).topology).
     &       ELEMENTS%ITEM(ELEMENT_INDEX)%TOPOLOGY)
      CALL VALIDATE_INPUT(ELEMENT_INDEX, NODES, ELEMENTS,                ! Call validate input with element_index, nodes, elements, kinematics, dof_layout, gauss_layout, geometry, fr...
     &     KINEMATICS, DOF_LAYOUT, GAUSS_LAYOUT, GEOMETRY,
     &     FRAMES, MATERIAL_CACHE, MATERIAL_MAP, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_ELEMENT_DOF_LIST(ELEMENT_INDEX, NODES, ELEMENTS,        ! Call build element dof list with element_index, nodes, elements, kinematics, dof_layout, matrices, status.
     &     KINEMATICS, DOF_LAYOUT, MATRICES, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      N_DOF = MATRICES%LOCAL_DOF_COUNT                                   ! Set n_dof to matrices.local_dof_count.
      NR = 6_I4                                                          ! Set nr to 6.
      IF (ANY(MATRICES%FIELD .EQ. FIELD_P)) NR = 9_I4                    ! If any(matrices.field = field_p), set nr to 9.
      IF (ANY(MATRICES%FIELD .EQ. FIELD_T)) NR = 12_I4                   ! If any(matrices.field = field_t), set nr to 12.
      ALLOCATE(MATRICES%STIFFNESS(N_DOF,N_DOF),                          ! Allocate memory for matrices.stiffness(n_dof,n_dof), matrices.internal_force(n_dof).
     &         MATRICES%INTERNAL_FORCE(N_DOF))
      ALLOCATE(MATRICES%MASS(0,0))                                       ! Allocate memory for matrices.mass(0,0).
      MATRICES%STIFFNESS = 0.0_R8                                        ! Set matrices.stiffness to zero.
      MATRICES%INTERNAL_FORCE = 0.0_R8                                   ! Set matrices.internal_force to zero.
      ALLOCATE(B_TOTAL(NR,N_DOF), MB(NR,N_DOF), SG(3,N_DOF),             ! Allocate memory for b_total(nr,n_dof), mb(nr,n_dof), sg(3,n_dof), a_stack(nr+9,n_dof), b_stack(nr+9,n_dof),...
     &         A_STACK(NR+9,N_DOF), B_STACK(NR+9,N_DOF),
     &         GRAD(3,N_DOF),
     &         DIRECTION(3,N_DOF), VALUE(N_DOF), UVALUE(N_DOF))
      CALL SETUP_POINT_WORK(MATRICES, KINEMATICS, PWORK)                 ! Call setup point work with matrices, kinematics, pwork.
!     THE COUPLING BLOCKS (NOT SYMMETRIC) ARE KEPT APART FROM THE
!     SYMMETRIC TANGENT, WHICH IS ACCUMULATED ON ITS UPPER TRIANGLE.
      IF (NR .GE. 12_I4 .OR. MATERIAL_CACHE%ANY_PYRO) THEN               ! If nr >= 12 or material_cache.any_pyro:
        ALLOCATE(COUPLE(N_DOF,N_DOF))                                    ! Allocate memory for couple(n_dof,n_dof).
        COUPLE = 0.0_R8                                                  ! Set couple to zero.
      END IF                                                             ! End of the IF block.
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        UVALUE(I) = U0(MATRICES%GLOBAL_DOF(I))                           ! Set uvalue(i) to u0(matrices.global_dof(i)).
!       ONLY THE DISPLACEMENT FIELDS HAVE A DIRECTION IN THE FRAME.
        DIRECTION(:,I) = 0.0_R8                                          ! Set direction(:,i) to zero.
        IF (MATRICES%FIELD(I) .LE. 3_I4) DIRECTION(:,I) =                ! If matrices.field(i) <= 3, set direction(:,i) to frames.global_to_local(:,matrices.field(i),element_index).
     &    FRAMES%GLOBAL_TO_LOCAL(:,MATRICES%FIELD(I),ELEMENT_INDEX)
      END DO                                                             ! End of the loop.

      DO POINT = GAUSS_LAYOUT%ELEMENT_FIRST(ELEMENT_INDEX),              ! Loop point from gauss_layout.element_first(element_index) to gauss_layout.element_last(element_index):
     &           GAUSS_LAYOUT%ELEMENT_LAST(ELEMENT_INDEX)
        MATERIAL_INDEX = MATERIAL_MAP%CACHE_INDEX(POINT)                 ! Set material_index to material_map.cache_index(point).
        WEIGHT = GEOMETRY%INTEGRATION_WEIGHT(POINT)                      ! Set weight to geometry.integration_weight(point).
        MCON = GENERALIZED_CONSTITUTIVE(MATERIAL_CACHE,                  ! Set mcon to generalized_constitutive(material_cache, material_index, part_full, cdim).
     &                                  MATERIAL_INDEX, PART_FULL, CDIM)
        BETA = THERMAL_STRESS_COEFFICIENT(MATERIAL_CACHE,                ! Set beta to thermal_stress_coefficient(material_cache, material_index).
     &                                    MATERIAL_INDEX)
        GAMMA_V = 0.0_R8                                                 ! Set gamma_v to zero.
        THETA_POINT = 0.0_R8                                             ! Set theta_point to zero.
        H = 0.0_R8                                                       ! Set h to zero.
        CALL EVALUATE_POINT_COLUMNS(POINT, ELEMENT_INDEX, ELEMENTS,      ! Call evaluate point columns with point, element_index, elements, kinematics, expansions, rules, gauss_layou...
     &       KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &       STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &       MATRICES, MITC, PWORK, LOCAL_STATUS)
        IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                       ! If not local_status is ok:
          CALL SET_ERROR(STATUS, 'BUILD_NONLINEAR_ELEMENT_MATRICES',     ! Record an error in status: trim(local_status.message).
     &                   TRIM(LOCAL_STATUS%MESSAGE))
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO I = 1_I4, N_DOF                                               ! Loop i from 1 to n_dof:
          POINT_VALUE = PWORK%VALUE(I)                                   ! Set point_value to pwork.value(i).
          B_COLUMN = PWORK%BCOL(:,I)                                     ! Set b_column to pwork.bcol(:,i).
          GRAD_POINT = PWORK%GRAD(:,I)                                   ! Set grad_point to pwork.grad(:,i).
          B_TOTAL(:,I) = B_COLUMN(1:NR)                                  ! Set b_total(:,i) to b_column(1:nr).
          GRAD(:,I) = GRAD_POINT                                         ! Set grad(:,i) to grad_point.
          VALUE(I) = POINT_VALUE                                         ! Set value(i) to point_value.
          GAMMA_V(1:NR) = GAMMA_V(1:NR) + B_COLUMN(1:NR)*UVALUE(I)       ! Add b_column(1:nr)*uvalue(i) to gamma_v(1:nr).
          IF (MATRICES%FIELD(I) .EQ. FIELD_T) THETA_POINT =              ! If matrices.field(i) = field_t, add point_value*uvalue(i) to theta_point.
     &      THETA_POINT + POINT_VALUE*UVALUE(I)
          IF (MATRICES%FIELD(I) .LE. 3_I4) THEN                          ! If matrices.field(i) <= 3:
            DO J = 1_I4, 3_I4                                            ! Loop j from 1 to 3:
              H(:,J) = H(:,J) + UVALUE(I)*DIRECTION(:,I)*                ! Add uvalue(i)*direction(:,i)* grad_point(j) to h(:,j).
     &                 GRAD_POINT(J)
            END DO                                                       ! End of the loop.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
!       GREEN STRAIN: LINEAR PART (ALREADY IN GAMMA) + (H^T H)/2.
        HH = MATMUL(TRANSPOSE(H),H)                                      ! Set hh to matmul(transpose(h),h).
        GAMMA_V(1) = GAMMA_V(1) + 0.5_R8*HH(1,1)                         ! Add 0.5*hh(1,1) to gamma_v(1).
        GAMMA_V(2) = GAMMA_V(2) + 0.5_R8*HH(2,2)                         ! Add 0.5*hh(2,2) to gamma_v(2).
        GAMMA_V(3) = GAMMA_V(3) + 0.5_R8*HH(3,3)                         ! Add 0.5*hh(3,3) to gamma_v(3).
        GAMMA_V(4) = GAMMA_V(4) + HH(1,3)                                ! Add hh(1,3) to gamma_v(4).
        GAMMA_V(5) = GAMMA_V(5) + HH(2,3)                                ! Add hh(2,3) to gamma_v(5).
        GAMMA_V(6) = GAMMA_V(6) + HH(1,2)                                ! Add hh(1,2) to gamma_v(6).
        SIGMA(1:NR) = MATMUL(MCON(1:NR,1:NR),GAMMA_V(1:NR))              ! Set sigma(1:nr) to matmul(mcon(1:nr,1:nr),gamma_v(1:nr)).
        SIGMA(1:6) = SIGMA(1:6) - BETA*THETA_POINT                       ! Subtract beta*theta_point from sigma(1:6).
        IF (NR .GE. 9_I4 .AND. MATERIAL_CACHE%ANY_PYRO)                  ! If nr >= 9 and material_cache.any_pyro, add theta_point* material_cache.pyro_local(:,material_index) to sig...
     &    SIGMA(7:9) = SIGMA(7:9) + THETA_POINT*
     &                 MATERIAL_CACHE%PYRO_LOCAL(:,MATERIAL_INDEX)
        S3(1,:) = [SIGMA(1),SIGMA(6),SIGMA(4)]                           ! Set s3(1,:) to [sigma(1),sigma(6),sigma(4)].
        S3(2,:) = [SIGMA(6),SIGMA(2),SIGMA(5)]                           ! Set s3(2,:) to [sigma(6),sigma(2),sigma(5)].
        S3(3,:) = [SIGMA(4),SIGMA(5),SIGMA(3)]                           ! Set s3(3,:) to [sigma(4),sigma(5),sigma(3)].
!       VARIATION OF THE STRAIN: ADD H^T D_I (X) GRAD N_I (SYMMETRIC).
        DO I = 1_I4, N_DOF                                               ! Loop i from 1 to n_dof:
          IF (MATRICES%FIELD(I) .GT. 3_I4) CYCLE                         ! If matrices.field(i) > 3, skip to the next iteration.
          W3 = MATMUL(TRANSPOSE(H),DIRECTION(:,I))                       ! Set w3 to matmul(transpose(h),direction(:,i)).
          B_TOTAL(1,I) = B_TOTAL(1,I) + W3(1)*GRAD(1,I)                  ! Add w3(1)*grad(1,i) to b_total(1,i).
          B_TOTAL(2,I) = B_TOTAL(2,I) + W3(2)*GRAD(2,I)                  ! Add w3(2)*grad(2,i) to b_total(2,i).
          B_TOTAL(3,I) = B_TOTAL(3,I) + W3(3)*GRAD(3,I)                  ! Add w3(3)*grad(3,i) to b_total(3,i).
          B_TOTAL(4,I) = B_TOTAL(4,I) + W3(1)*GRAD(3,I) +                ! Add w3(1)*grad(3,i) + w3(3)*grad(1,i) to b_total(4,i).
     &                   W3(3)*GRAD(1,I)
          B_TOTAL(5,I) = B_TOTAL(5,I) + W3(2)*GRAD(3,I) +                ! Add w3(2)*grad(3,i) + w3(3)*grad(2,i) to b_total(5,i).
     &                   W3(3)*GRAD(2,I)
          B_TOTAL(6,I) = B_TOTAL(6,I) + W3(1)*GRAD(2,I) +                ! Add w3(1)*grad(2,i) + w3(2)*grad(1,i) to b_total(6,i).
     &                   W3(2)*GRAD(1,I)
        END DO                                                           ! End of the loop.
        DO I = 1_I4, N_DOF                                               ! Loop i from 1 to n_dof:
          MATRICES%INTERNAL_FORCE(I) = MATRICES%INTERNAL_FORCE(I) +      ! Add weight*dot_product(b_total(:,i),sigma(1:nr)) to matrices.internal_force(i).
     &      WEIGHT*DOT_PRODUCT(B_TOTAL(:,I),SIGMA(1:NR))
        END DO                                                           ! End of the loop.
!       TANGENT = B^T (W M) B + (D_I.D_J)(GRAD N_I . S GRAD N_J) W.
!       THE SECOND TERM IS A RANK-9 PRODUCT P^T Q WITH
!         P(3(A-1)+B,I) = D_IA GRAD_IB,  Q(3(A-1)+B,J) = W D_JA (S G)_JB,
!       SO BOTH TERMS ARE ONE PRODUCT OVER NR+9 STACKED ROWS (UPPER
!       TRIANGLE ONLY: THE TANGENT BLOCK IS SYMMETRIC).
        DO I = 1_I4, N_DOF                                               ! Loop i from 1 to n_dof:
          MB(:,I) = WEIGHT*MATMUL(MCON(1:NR,1:NR),B_TOTAL(:,I))          ! Set mb(:,i) to weight*matmul(mcon(1:nr,1:nr),b_total(:,i)).
          SG(:,I) = MATMUL(S3,GRAD(:,I))                                 ! Set sg(:,i) to matmul(s3,grad(:,i)).
          A_STACK(1:NR,I) = B_TOTAL(:,I)                                 ! Set a_stack(1:nr,i) to b_total(:,i).
          B_STACK(1:NR,I) = MB(:,I)                                      ! Set b_stack(1:nr,i) to mb(:,i).
          DO J = 1_I4, 3_I4                                              ! Loop j from 1 to 3:
            A_STACK(NR+3*(J-1)+1:NR+3*J,I) = DIRECTION(J,I)*GRAD(:,I)    ! Set a_stack(nr+3*(j-1)+1:nr+3*j,i) to direction(j,i)*grad(:,i).
            B_STACK(NR+3*(J-1)+1:NR+3*J,I) = WEIGHT*DIRECTION(J,I)*      ! Set b_stack(nr+3*(j-1)+1:nr+3*j,i) to weight*direction(j,i)* sg(:,i).
     &                                       SG(:,I)
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        CALL ACCUMULATE_UPPER_PRODUCT(A_STACK, B_STACK, NR+9_I4,         ! Call accumulate upper product with a_stack, b_stack, nr+9, matrices.stiffness.
     &                                MATRICES%STIFFNESS)
!       COUPLING OF THE TEMPERATURE: THERMOELASTIC AND PYROELECTRIC.
        IF (ALLOCATED(COUPLE)) THEN                                      ! If allocated(couple):
          DO J = 1_I4, N_DOF                                             ! Loop j from 1 to n_dof:
            IF (MATRICES%FIELD(J) .NE. FIELD_T) CYCLE                    ! If matrices.field(j) /= field_t, skip to the next iteration.
            DO I = 1_I4, N_DOF                                           ! Loop i from 1 to n_dof:
              IF (MATRICES%FIELD(I) .LE. 3_I4) THEN                      ! If matrices.field(i) <= 3:
                COUPLE(I,J) = COUPLE(I,J) - WEIGHT*VALUE(J)*             ! Subtract weight*value(j)* dot_product(b_total(1:6,i),beta) from couple(i,j).
     &            DOT_PRODUCT(B_TOTAL(1:6,I),BETA)
              ELSE IF (MATRICES%FIELD(I) .EQ. FIELD_P .AND.              ! Otherwise, if matrices.field(i) = field_p and material_cache.any_pyro:
     &                 MATERIAL_CACHE%ANY_PYRO) THEN
                COUPLE(I,J) = COUPLE(I,J) + WEIGHT*VALUE(J)*             ! Add weight*value(j)* dot_product(b_total(7:9,i), material_cache.pyro_local(:,material_index)) to couple(i,j).
     &            DOT_PRODUCT(B_TOTAL(7:9,I),
     &            MATERIAL_CACHE%PYRO_LOCAL(:,MATERIAL_INDEX))
              END IF                                                     ! End of the IF block.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
!     SYMMETRIC TANGENT FROM ITS UPPER TRIANGLE, THEN THE COUPLING.
      CALL MIRROR_UPPER_TRIANGLE(MATRICES, .FALSE.)                      ! Call mirror upper triangle with matrices, false.
      IF (ALLOCATED(COUPLE)) MATRICES%STIFFNESS =                        ! If allocated(couple), add couple to matrices.stiffness.
     &  MATRICES%STIFFNESS + COUPLE

      END SUBROUTINE BUILD_NONLINEAR_ELEMENT_MATRICES                    ! End of the subroutine build nonlinear element matrices.

!  M = SUM_P (W RHO)_P N_P N_PT, WITH N NON-ZERO ONLY BETWEEN DOFS OF
!  THE SAME FIELD: ONE PRODUCT PER FIELD. BASIS_VALUE(POINT,DOF).
      SUBROUTINE ADD_MASS(MATRICES, BASIS_VALUE, POINT_MASS,             ! Subroutine add mass takes matrices, basis value, point mass, point capacity, count.
     &                    POINT_CAPACITY, COUNT)

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      REAL(R8), INTENT(IN) :: BASIS_VALUE(:,:)                           ! Input real (real64): basis_value(:,:).
      REAL(R8), INTENT(IN) :: POINT_MASS(:)                              ! Input real (real64): point_mass(:).
      REAL(R8), INTENT(IN) :: POINT_CAPACITY(:)                          ! Input real (real64): point_capacity(:).
      INTEGER(I4), INTENT(IN) :: COUNT                                   ! Input integer (int32): count.
      REAL(R8), ALLOCATABLE :: SCALED(:,:)                               ! Allocatable real (real64): scaled(:,:).
      INTEGER(I4), ALLOCATABLE :: IDX(:)                                 ! Allocatable integer (int32): idx(:).
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      ALLOCATE(SCALED(SIZE(BASIS_VALUE,1),SIZE(BASIS_VALUE,2)))          ! Allocate memory for scaled(size(basis_value,1),size(basis_value,2)).
      DO I = 1_I4, SIZE(BASIS_VALUE,2)                                   ! Loop i from 1 to size(basis_value,2):
        DO Q = 1_I4, COUNT                                               ! Loop q from 1 to count:
          SCALED(Q,I) = BASIS_VALUE(Q,I)*POINT_MASS(Q)                   ! Set scaled(q,i) to basis_value(q,i)*point_mass(q).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      DO FIELD = 1_I4, 3_I4                                              ! Loop field from 1 to 3:
        IDX = PACK([(Q,Q=1_I4,MATRICES%LOCAL_DOF_COUNT)],                ! Set idx to pack([(q,q=1,matrices.local_dof_count)], matrices.field = field).
     &             MATRICES%FIELD .EQ. FIELD)
        IF (SIZE(IDX) .EQ. 0) CYCLE                                      ! If size(idx) = 0, skip to the next iteration.
        CALL ACCUMULATE_UPPER_PRODUCT(BASIS_VALUE, SCALED, COUNT,        ! Call accumulate upper product with basis_value, scaled, count, matrices.mass, idx.
     &                                MATRICES%MASS, IDX)
      END DO                                                             ! End of the loop.
!     THERMAL CAPACITY: RHO C N N^T ON THE TEMPERATURE DOFS.
      IDX = PACK([(Q,Q=1_I4,MATRICES%LOCAL_DOF_COUNT)],                  ! Set idx to pack([(q,q=1,matrices.local_dof_count)], matrices.field = field_t).
     &           MATRICES%FIELD .EQ. FIELD_T)
      IF (SIZE(IDX) .GT. 0) THEN                                         ! If size(idx) > 0:
        DO I = 1_I4, SIZE(BASIS_VALUE,2)                                 ! Loop i from 1 to size(basis_value,2):
          DO Q = 1_I4, COUNT                                             ! Loop q from 1 to count:
            SCALED(Q,I) = BASIS_VALUE(Q,I)*POINT_CAPACITY(Q)             ! Set scaled(q,i) to basis_value(q,i)*point_capacity(q).
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        CALL ACCUMULATE_UPPER_PRODUCT(BASIS_VALUE, SCALED, COUNT,        ! Call accumulate upper product with basis_value, scaled, count, matrices.mass, idx.
     &                                MATRICES%MASS, IDX)
      END IF                                                             ! End of the IF block.
      END SUBROUTINE ADD_MASS                                            ! End of the subroutine add mass.

      SUBROUTINE MIRROR_UPPER_TRIANGLE(MATRICES, WITH_MASS)              ! Subroutine mirror upper triangle takes matrices, with mass.

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      LOGICAL, INTENT(IN) :: WITH_MASS                                   ! Input logical: with_mass.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      DO J = 1_I4, MATRICES%LOCAL_DOF_COUNT                              ! Loop j from 1 to matrices.local_dof_count:
        DO I = J+1_I4, MATRICES%LOCAL_DOF_COUNT                          ! Loop i from j+1 to matrices.local_dof_count:
          MATRICES%STIFFNESS(I,J) = MATRICES%STIFFNESS(J,I)              ! Set matrices.stiffness(i,j) to matrices.stiffness(j,i).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (WITH_MASS) THEN                                                ! If with_mass:
        DO J = 1_I4, MATRICES%LOCAL_DOF_COUNT                            ! Loop j from 1 to matrices.local_dof_count:
          DO I = J+1_I4, MATRICES%LOCAL_DOF_COUNT                        ! Loop i from j+1 to matrices.local_dof_count:
            MATRICES%MASS(I,J) = MATRICES%MASS(J,I)                      ! Set matrices.mass(i,j) to matrices.mass(j,i).
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE MIRROR_UPPER_TRIANGLE                               ! End of the subroutine mirror upper triangle.

!  DISTINCT EXPANSIONS OF THE DOFS OF AN ELEMENT: TWO DOFS SHARE A
!  TABLE OF EXPANSION FACTORS WHEN THEIR EXPANSION (FAMILY, ORDER,
!  REFERENCE) IS THE SAME, E.G. THE THREE DISPLACEMENT COMPONENTS.
      SUBROUTINE SETUP_POINT_WORK(MATRICES, KINEMATICS, WORK)            ! Subroutine setup point work takes matrices, kinematics, work.

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(IN) :: MATRICES                  ! Input of type element_matrix_type: matrices.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(POINT_WORK_TYPE), INTENT(INOUT) :: WORK                       ! In/out of type point_work_type: work.
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: F                                                   ! Integer (int32): f.

      N_DOF = MATRICES%LOCAL_DOF_COUNT                                   ! Set n_dof to matrices.local_dof_count.
      N_NODE = SIZE(MATRICES%KINEMATIC_INDEX)                            ! Set n_node to the size of matrices.kinematic_index.
      ALLOCATE(WORK%MEMO_OF(N_DOF), WORK%MEMO_NODE(N_DOF),               ! Allocate memory for work.memo_of(n_dof), work.memo_node(n_dof), work.memo_terms(n_dof), work.memo_kin(n_dof...
     &         WORK%MEMO_TERMS(N_DOF), WORK%MEMO_KIN(N_DOF),
     &         WORK%MEMO_FIELD(N_DOF))
      WORK%N_MEMO = 0_I4                                                 ! Set work.n_memo to zero.
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        K = MATRICES%KINEMATIC_INDEX(MATRICES%STRUCTURAL_NODE(I))        ! Set k to matrices.kinematic_index(matrices.structural_node(i)).
        F = MATRICES%FIELD(I)                                            ! Set f to matrices.field(i).
        WORK%MEMO_OF(I) = 0_I4                                           ! Set work.memo_of(i) to zero.
        DO M = 1_I4, WORK%N_MEMO                                         ! Loop m from 1 to work.n_memo:
          IF (SAME_EXPANSION(                                            ! If same_expansion( kinematics.item(k).field(f), kinematics.item(work.memo_kin(m)).field( work.memo_field(m))):
     &        KINEMATICS%ITEM(K)%FIELD(F),
     &        KINEMATICS%ITEM(WORK%MEMO_KIN(M))%FIELD(
     &        WORK%MEMO_FIELD(M)))) THEN
            WORK%MEMO_OF(I) = M                                          ! Set work.memo_of(i) to m.
            EXIT                                                         ! Leave the loop.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        IF (WORK%MEMO_OF(I) .EQ. 0_I4) THEN                              ! If work.memo_of(i) = 0:
          WORK%N_MEMO = WORK%N_MEMO + 1_I4                               ! Add 1 to work.n_memo.
          WORK%MEMO_NODE(WORK%N_MEMO) = MATRICES%STRUCTURAL_NODE(I)      ! Set work.memo_node(work.n_memo) to matrices.structural_node(i).
          WORK%MEMO_KIN(WORK%N_MEMO) = K                                 ! Set work.memo_kin(work.n_memo) to k.
          WORK%MEMO_FIELD(WORK%N_MEMO) = F                               ! Set work.memo_field(work.n_memo) to f.
          WORK%MEMO_TERMS(WORK%N_MEMO) = 0_I4                            ! Set work.memo_terms(work.n_memo) to zero.
          WORK%MEMO_OF(I) = WORK%N_MEMO                                  ! Set work.memo_of(i) to work.n_memo.
        END IF                                                           ! End of the IF block.
        WORK%MEMO_TERMS(WORK%MEMO_OF(I)) = MAX(                          ! Set work.memo_terms(work.memo_of(i)) to the larger of work.memo_terms(work.memo_of(i)) and matrices.term(i).
     &    WORK%MEMO_TERMS(WORK%MEMO_OF(I)), MATRICES%TERM(I))
      END DO                                                             ! End of the loop.
      ALLOCATE(WORK%SVAL(N_NODE), WORK%SGRAD(3,N_NODE))                  ! Allocate memory for work.sval(n_node), work.sgrad(3,n_node).
      ALLOCATE(WORK%FVAL(MAXVAL(WORK%MEMO_TERMS(1:WORK%N_MEMO)),         ! Allocate memory for work.fval(maxval(work.memo_terms(1:work.n_memo)), work.n_memo).
     &                   WORK%N_MEMO))
      ALLOCATE(WORK%FGRAD(3,MAXVAL(WORK%MEMO_TERMS(1:WORK%N_MEMO)),      ! Allocate memory for work.fgrad(3,maxval(work.memo_terms(1:work.n_memo)), work.n_memo).
     &                    WORK%N_MEMO))
      ALLOCATE(WORK%VALUE(N_DOF), WORK%BCOL(12,N_DOF),                   ! Allocate memory for work.value(n_dof), work.bcol(12,n_dof), work.grad(3,n_dof).
     &         WORK%GRAD(3,N_DOF))

      END SUBROUTINE SETUP_POINT_WORK                                    ! End of the subroutine setup point work.

      LOGICAL FUNCTION SAME_EXPANSION(A, B)                              ! Function same expansion takes a, b.

      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: A                         ! Input of type expansion_spec_type: a.
      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: B                         ! Input of type expansion_spec_type: b.

      SAME_EXPANSION = A%FAMILY .EQ. B%FAMILY .AND.                      ! Set same_expansion to a.family = b.family and a.order = b.order and a.field_reference = b.field_reference.
     &  A%ORDER .EQ. B%ORDER .AND.
     &  A%FIELD_REFERENCE .EQ. B%FIELD_REFERENCE

      END FUNCTION SAME_EXPANSION                                        ! End of the function same expansion.

!  BASIS VALUE, GRADIENT AND GENERALISED-STRAIN COLUMN OF EVERY DOF AT
!  ONE GAUSS POINT (WORK%VALUE, WORK%GRAD, WORK%BCOL).
      SUBROUTINE EVALUATE_POINT_COLUMNS(POINT, ELEMENT_INDEX, ELEMENTS,  ! Subroutine evaluate point columns takes point, element index, elements, kinematics, expansions, rules, gaus...
     &     KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &     STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &     MATRICES, MITC_DATA, WORK, STATUS)

      INTEGER(I8), INTENT(IN) :: POINT                                   ! Input integer (int64): point.
      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(IN) :: MATRICES                  ! Input of type element_matrix_type: matrices.
      TYPE(MITC_DATA_TYPE), INTENT(IN) :: MITC_DATA                      ! Input of type mitc_data_type: mitc_data.
      TYPE(POINT_WORK_TYPE), INTENT(INOUT) :: WORK                       ! In/out of type point_work_type: work.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                  ! Of type expansion_spec_type: spec.
      REAL(R8) :: STRUCTURAL_VALUE                                       ! Real (real64): structural_value.
      REAL(R8) :: STRUCTURAL_GRADIENT(3)                                 ! Real (real64): structural_gradient(3).
      REAL(R8) :: FACTOR_VALUE                                           ! Real (real64): factor_value.
      REAL(R8) :: FACTOR_GRADIENT(3)                                     ! Real (real64): factor_gradient(3).
      REAL(R8) :: GRADIENT(3)                                            ! Real (real64): gradient(3).
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.
      INTEGER(I4) :: T                                                   ! Integer (int32): t.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: MEMO                                                ! Integer (int32): memo.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
!     STRUCTURAL FACTORS OF ALL THE NODES (THE EXPANSION OF THE FIRST
!     DISTINCT EXPANSION IS USED ONLY TO REACH THE STRUCTURAL CACHE).
      SPEC = KINEMATICS%ITEM(WORK%MEMO_KIN(1))%FIELD(WORK%MEMO_FIELD(1)) ! Set spec to kinematics.item(work.memo_kin(1)).field(work.memo_field(1)).
      DO N = 1_I4, SIZE(WORK%SVAL)                                       ! Loop n from 1 to size(work.sval):
        CALL EVALUATE_POINT_FACTORS(POINT, N, 1_I4, SPEC, ELEMENTS,      ! Call evaluate point factors with point, n, 1, spec, elements, expansions, rules, gauss_layout, structural_c...
     &       EXPANSIONS, RULES, GAUSS_LAYOUT, STRUCTURAL_CACHE,
     &       EXPANSION_CACHE, GEOMETRY, WORK%SVAL(N), WORK%SGRAD(:,N),
     &       FACTOR_VALUE, FACTOR_GRADIENT, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.
!     EXPANSION FACTORS OF EVERY TERM OF EVERY DISTINCT EXPANSION.
      DO M = 1_I4, WORK%N_MEMO                                           ! Loop m from 1 to work.n_memo:
        SPEC = KINEMATICS%ITEM(WORK%MEMO_KIN(M))%FIELD(                  ! Set spec to kinematics.item(work.memo_kin(m)).field( work.memo_field(m)).
     &         WORK%MEMO_FIELD(M))
        DO T = 1_I4, WORK%MEMO_TERMS(M)                                  ! Loop t from 1 to work.memo_terms(m):
          CALL EVALUATE_POINT_FACTORS(POINT, WORK%MEMO_NODE(M), T, SPEC, ! Call evaluate point factors with point, work.memo_node(m), t, spec, elements, expansions, rules, gauss_layo...
     &         ELEMENTS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &         STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY,
     &         STRUCTURAL_VALUE, STRUCTURAL_GRADIENT,
     &         WORK%FVAL(T,M), WORK%FGRAD(:,T,M), STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
!     BASIS OF EVERY DOF AND ITS GENERALISED-STRAIN COLUMN.
      DO I = 1_I4, MATRICES%LOCAL_DOF_COUNT                              ! Loop i from 1 to matrices.local_dof_count:
        NODE = MATRICES%STRUCTURAL_NODE(I)                               ! Set node to matrices.structural_node(i).
        MEMO = WORK%MEMO_OF(I)                                           ! Set memo to work.memo_of(i).
        T = MATRICES%TERM(I)                                             ! Set t to matrices.term(i).
        CALL COMPOSE_PRODUCT_BASIS(WORK%SVAL(NODE), WORK%SGRAD(:,NODE),  ! Call compose product basis with work.sval(node), work.sgrad(:,node), work.fval(t,memo), work.fgrad(:,t,memo...
     &       WORK%FVAL(T,MEMO), WORK%FGRAD(:,T,MEMO),
     &       WORK%VALUE(I), GRADIENT)
        WORK%GRAD(:,I) = GRADIENT                                        ! Set work.grad(:,i) to gradient.
        CALL COLUMN_FROM_BASIS(POINT, ELEMENT_INDEX,                     ! Call column from basis with point, element_index, matrices.field(i), node, rules, gauss_layout, frames, mit...
     &       MATRICES%FIELD(I), NODE, RULES, GAUSS_LAYOUT, FRAMES,
     &       MITC_DATA, GRADIENT, WORK%FVAL(T,MEMO),
     &       WORK%FGRAD(:,T,MEMO), WORK%VALUE(I), WORK%BCOL(:,I),
     &       STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_POINT_COLUMNS                              ! End of the subroutine evaluate point columns.

!  GENERALISED-STRAIN COLUMN OF A DOF FROM ITS BASIS GRADIENT: THE
!  DISPLACEMENT OPERATOR (WITH THE MITC TYING WHEN ACTIVE), THE
!  POTENTIAL GRADIENT (ROWS 7-9) OR THE TEMPERATURE GRADIENT (10-12).
      SUBROUTINE COLUMN_FROM_BASIS(POINT, ELEMENT_INDEX, FIELD,          ! Subroutine column from basis takes point, element index, field, structural node, rules, gauss layout, frame...
     &     STRUCTURAL_NODE, RULES, GAUSS_LAYOUT, FRAMES, MITC_DATA,
     &     GRADIENT, FACTOR_VALUE, FACTOR_GRADIENT, VALUE, B_COLUMN,
     &     STATUS)

      INTEGER(I8), INTENT(IN) :: POINT                                   ! Input integer (int64): point.
      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      INTEGER(I4), INTENT(IN) :: FIELD                                   ! Input integer (int32): field.
      INTEGER(I4), INTENT(IN) :: STRUCTURAL_NODE                         ! Input integer (int32): structural_node.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MITC_DATA_TYPE), INTENT(IN) :: MITC_DATA                      ! Input of type mitc_data_type: mitc_data.
      REAL(R8), INTENT(IN) :: GRADIENT(3)                                ! Input real (real64): gradient(3).
      REAL(R8), INTENT(IN) :: FACTOR_VALUE                               ! Input real (real64): factor_value.
      REAL(R8), INTENT(IN) :: FACTOR_GRADIENT(3)                         ! Input real (real64): factor_gradient(3).
      REAL(R8), INTENT(INOUT) :: VALUE                                   ! In/out real (real64): value.
      REAL(R8), INTENT(OUT) :: B_COLUMN(12)                              ! Output real (real64): b_column(12).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: B_OPERATOR(6,3)                                        ! Real (real64): b_operator(6,3).
      REAL(R8) :: NATURAL(3)                                             ! Real (real64): natural(3).
      INTEGER(I4) :: RULE_INDEX                                          ! Integer (int32): rule_index.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      B_COLUMN = 0.0_R8                                                  ! Set b_column to zero.
      IF (FIELD .EQ. FIELD_P) THEN                                       ! If field = field_p:
        B_COLUMN(7:9) = GRADIENT                                         ! Set b_column(7:9) to gradient.
        VALUE = 0.0_R8                                                   ! Set value to zero.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (FIELD .EQ. FIELD_T) THEN                                       ! If field = field_t:
        B_COLUMN(10:12) = GRADIENT                                       ! Set b_column(10:12) to gradient.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL BUILD_DISPLACEMENT_OPERATOR(GRADIENT, B_OPERATOR, STATUS)     ! Call build displacement operator with gradient, b_operator, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      B_COLUMN(1:6) = MATMUL(B_OPERATOR,                                 ! Set b_column(1:6) to matmul(b_operator, frames.global_to_local(:,field,element_index)).
     &  FRAMES%GLOBAL_TO_LOCAL(:,FIELD,ELEMENT_INDEX))
      IF (MITC_DATA%ACTIVE) THEN                                         ! If mitc_data.active:
        RULE_INDEX = GAUSS_LAYOUT%STRUCTURAL_RULE_INDEX(POINT)           ! Set rule_index to gauss_layout.structural_rule_index(point).
        NATURAL = RULES%ITEM(RULE_INDEX)%COORDINATE(                     ! Set natural to rules.item(rule_index).coordinate( gauss_layout.structural_point_index(point),1:3).
     &            GAUSS_LAYOUT%STRUCTURAL_POINT_INDEX(POINT),1:3)
        CALL MITC_TIE_COLUMN(MITC_DATA, NATURAL, STRUCTURAL_NODE,        ! Call mitc tie column with mitc_data, natural, structural_node, factor_value, factor_gradient, frames.global...
     &       FACTOR_VALUE, FACTOR_GRADIENT,
     &       FRAMES%GLOBAL_TO_LOCAL(:,FIELD,ELEMENT_INDEX),
     &       B_COLUMN(1:6), STATUS)
      END IF                                                             ! End of the IF block.

      END SUBROUTINE COLUMN_FROM_BASIS                                   ! End of the subroutine column from basis.

      SUBROUTINE BUILD_ELEMENT_DOF_LIST(ELEMENT_INDEX, NODES,            ! Subroutine build element dof list takes element index, nodes, elements, kinematics, dof layout, matrices, s...
     &     ELEMENTS, KINEMATICS, DOF_LAYOUT, MATRICES, STATUS)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: LOCAL_NODE                                          ! Integer (int32): local_node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.

      COUNT = 0_I4                                                       ! Set count to zero.
      DO LOCAL_NODE = 1_I4,                                              ! Loop local_node from 1 to size(elements.item(element_index).node_id):
     & SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID)
        NODE_INDEX = FIND_NODE_INDEX(NODES,                              ! Set node_index to find_node_index(nodes, elements.item(element_index).node_id(local_node)).
     &   ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID(LOCAL_NODE))
        IF (NODE_INDEX .EQ. 0_I4) THEN                                   ! If node_index = 0:
          CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_DOF_LIST',               ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                   'ELEMENT REFERENCES UNKNOWN NODE')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO FIELD = 1_I4, N_SOLVED_FIELDS                                 ! Loop field from 1 to n_solved_fields:
          COUNT = COUNT+DOF_LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)          ! Add dof_layout.term_count(node_index,field) to count.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (COUNT .LT. 1_I4) THEN                                          ! If count < 1:
        CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_DOF_LIST',                 ! Record an error in status: 'ELEMENT HAS NO MECHANICAL DEGREES OF FREEDOM'.
     &                 'ELEMENT HAS NO MECHANICAL DEGREES OF FREEDOM')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      MATRICES%ELEMENT_INDEX = ELEMENT_INDEX                             ! Set matrices.element_index to element_index.
      MATRICES%LOCAL_DOF_COUNT = COUNT                                   ! Set matrices.local_dof_count to count.
      ALLOCATE(MATRICES%GLOBAL_DOF(COUNT))                               ! Allocate memory for matrices.global_dof(count).
      ALLOCATE(MATRICES%NODE_INDEX(SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%    ! Allocate memory for matrices.node_index(size(elements.item(element_index). node_id)).
     &                                  NODE_ID)))
      ALLOCATE(MATRICES%KINEMATIC_INDEX(SIZE(ELEMENTS%ITEM(              ! Allocate memory for matrices.kinematic_index(size(elements.item( element_index).node_id)).
     &                                  ELEMENT_INDEX)%NODE_ID)))
      ALLOCATE(MATRICES%STRUCTURAL_NODE(COUNT))                          ! Allocate memory for matrices.structural_node(count).
      ALLOCATE(MATRICES%FIELD(COUNT))                                    ! Allocate memory for matrices.field(count).
      ALLOCATE(MATRICES%TERM(COUNT))                                     ! Allocate memory for matrices.term(count).
      COUNT = 0_I4                                                       ! Set count to zero.
      DO LOCAL_NODE = 1_I4,                                              ! Loop local_node from 1 to size(elements.item(element_index).node_id):
     & SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID)
        NODE_INDEX = FIND_NODE_INDEX(NODES,                              ! Set node_index to find_node_index(nodes, elements.item(element_index).node_id(local_node)).
     &   ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID(LOCAL_NODE))
        KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(KINEMATICS,               ! Set kinematic_index to find_kinematic_index(kinematics, nodes.item(node_index).kinematic_id).
     &   NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
        MATRICES%NODE_INDEX(LOCAL_NODE) = NODE_INDEX                     ! Set matrices.node_index(local_node) to node_index.
        MATRICES%KINEMATIC_INDEX(LOCAL_NODE) = KINEMATIC_INDEX           ! Set matrices.kinematic_index(local_node) to kinematic_index.
        IF (KINEMATIC_INDEX .EQ. 0_I4) THEN                              ! If kinematic_index = 0:
          CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_DOF_LIST',               ! Record an error in status: 'NODE REFERENCES UNKNOWN KINEMATIC'.
     &                   'NODE REFERENCES UNKNOWN KINEMATIC')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO FIELD = 1_I4, N_SOLVED_FIELDS                                 ! Loop field from 1 to n_solved_fields:
          DO TERM = 1_I4, DOF_LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)        ! Loop term from 1 to dof_layout.term_count(node_index,field):
            COUNT = COUNT+1_I4                                           ! Add 1 to count.
            MATRICES%GLOBAL_DOF(COUNT) = GLOBAL_DOF(DOF_LAYOUT,          ! Set matrices.global_dof(count) to global_dof(dof_layout, node_index,field,term).
     &                                      NODE_INDEX,FIELD,TERM)
            MATRICES%STRUCTURAL_NODE(COUNT) = LOCAL_NODE                 ! Set matrices.structural_node(count) to local_node.
            MATRICES%FIELD(COUNT) = FIELD                                ! Set matrices.field(count) to field.
            MATRICES%TERM(COUNT) = TERM                                  ! Set matrices.term(count) to term.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_ELEMENT_DOF_LIST                              ! End of the subroutine build element dof list.

      SUBROUTINE VALIDATE_INPUT(ELEMENT_INDEX, NODES, ELEMENTS,          ! Subroutine validate input takes element index, nodes, elements, kinematics, dof layout, gauss layout, geome...
     &     KINEMATICS, DOF_LAYOUT, GAUSS_LAYOUT, GEOMETRY,
     &     FRAMES, MATERIAL_CACHE, MATERIAL_MAP, STATUS)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: MATERIAL_CACHE            ! Input of type material_cache_type: material_cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(IN) :: MATERIAL_MAP          ! Input of type gauss_material_map_type: material_map.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.

      IF (.NOT. ALLOCATED(NODES%ITEM) .OR.                               ! If not allocated(nodes.item) or not allocated(elements.item) or not allocated(kinematics.item) or not alloc...
     &    .NOT. ALLOCATED(ELEMENTS%ITEM) .OR.
     &    .NOT. ALLOCATED(KINEMATICS%ITEM) .OR.
     &    .NOT. ALLOCATED(DOF_LAYOUT%TERM_COUNT)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',          ! Record an error in status: 'MODEL DATABASES ARE NOT ALLOCATED'.
     &                 'MODEL DATABASES ARE NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (ELEMENT_INDEX .LT. 1_I4 .OR. ELEMENT_INDEX .GT.                ! If element_index < 1 or element_index > size(elements.item):
     &    SIZE(ELEMENTS%ITEM)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',          ! Record an error in status: 'ELEMENT INDEX IS OUT OF RANGE'.
     &                 'ELEMENT INDEX IS OUT OF RANGE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (.NOT. ALLOCATED(GAUSS_LAYOUT%ELEMENT_FIRST) .OR.               ! If not allocated(gauss_layout.element_first) or not allocated(geometry.integration_weight) or not allocated...
     &    .NOT. ALLOCATED(GEOMETRY%INTEGRATION_WEIGHT) .OR.
     &    .NOT. ALLOCATED(FRAMES%GLOBAL_TO_LOCAL) .OR.
     &    .NOT. ALLOCATED(MATERIAL_CACHE%STIFFNESS_LOCAL) .OR.
     &    .NOT. ALLOCATED(MATERIAL_MAP%CACHE_INDEX)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',          ! Record an error in status: 'INTEGRATION DATABASES ARE NOT ALLOCATED'.
     &                 'INTEGRATION DATABASES ARE NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (GAUSS_LAYOUT%ELEMENT_FIRST(ELEMENT_INDEX) .LT. 1_I8 .OR.       ! If gauss_layout.element_first(element_index) < 1 or gauss_layout.element_last(element_index) > gauss_layout...
     &    GAUSS_LAYOUT%ELEMENT_LAST(ELEMENT_INDEX) .GT.
     &    GAUSS_LAYOUT%COUNT .OR. GEOMETRY%COUNT .NE.
     &    GAUSS_LAYOUT%COUNT .OR. MATERIAL_MAP%COUNT .NE.
     &    GAUSS_LAYOUT%COUNT) THEN
        CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',          ! Record an error in status: 'GAUSS DATABASES ARE INCONSISTENT'.
     &                 'GAUSS DATABASES ARE INCONSISTENT')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE VALIDATE_INPUT                                      ! End of the subroutine validate input.

      SUBROUTINE CLEAR_ELEMENT_MATRIX(MATRICES)                          ! Subroutine clear element matrix takes matrices.

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.

      IF (ALLOCATED(MATRICES%GLOBAL_DOF))                                ! If allocated(matrices.global_dof), free the memory of matrices.global_dof.
     &  DEALLOCATE(MATRICES%GLOBAL_DOF)
      IF (ALLOCATED(MATRICES%NODE_INDEX))                                ! If allocated(matrices.node_index), free the memory of matrices.node_index.
     &  DEALLOCATE(MATRICES%NODE_INDEX)
      IF (ALLOCATED(MATRICES%KINEMATIC_INDEX))                           ! If allocated(matrices.kinematic_index), free the memory of matrices.kinematic_index.
     &  DEALLOCATE(MATRICES%KINEMATIC_INDEX)
      IF (ALLOCATED(MATRICES%STRUCTURAL_NODE))                           ! If allocated(matrices.structural_node), free the memory of matrices.structural_node.
     &  DEALLOCATE(MATRICES%STRUCTURAL_NODE)
      IF (ALLOCATED(MATRICES%FIELD)) DEALLOCATE(MATRICES%FIELD)          ! If allocated(matrices.field), free the memory of matrices.field.
      IF (ALLOCATED(MATRICES%TERM)) DEALLOCATE(MATRICES%TERM)            ! If allocated(matrices.term), free the memory of matrices.term.
      IF (ALLOCATED(MATRICES%CSR_POSITION))                              ! If allocated(matrices.csr_position), free the memory of matrices.csr_position.
     &  DEALLOCATE(MATRICES%CSR_POSITION)
      IF (ALLOCATED(MATRICES%STIFFNESS))                                 ! If allocated(matrices.stiffness), free the memory of matrices.stiffness.
     &  DEALLOCATE(MATRICES%STIFFNESS)
      IF (ALLOCATED(MATRICES%MASS)) DEALLOCATE(MATRICES%MASS)            ! If allocated(matrices.mass), free the memory of matrices.mass.
      IF (ALLOCATED(MATRICES%INTERNAL_FORCE))                            ! If allocated(matrices.internal_force), free the memory of matrices.internal_force.
     &  DEALLOCATE(MATRICES%INTERNAL_FORCE)
      MATRICES%ELEMENT_INDEX = 0_I4                                      ! Set matrices.element_index to zero.
      MATRICES%LOCAL_DOF_COUNT = 0_I4                                    ! Set matrices.local_dof_count to zero.

      END SUBROUTINE CLEAR_ELEMENT_MATRIX                                ! End of the subroutine clear element matrix.

      END MODULE MUL2_ELEMENT_MATRICES                                   ! End of the module mul2 element matrices.
