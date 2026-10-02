!=======================================================================
!  MINIMAL TEST RUNNER. SCIENTIFIC TESTS ARE ADDED AT EACH GATE.
!=======================================================================
      PROGRAM MUL2_TESTS                                                 ! Main program mul2 tests begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error, status is ok.
     &                       SET_WARNING, SET_ERROR, STATUS_IS_OK
      USE MUL2_TIMER, ONLY: TIMER_TYPE, TIMER_START, TIMER_STOP,         ! Use from module mul2 timer: timer type, timer start, timer stop, timer wall seconds.
     &                      TIMER_WALL_SECONDS
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE,                     ! Use from module mul2 kinematics: kinematics db type, expansion spec type, expansion te, expansion le, expan...
     &                            EXPANSION_SPEC_TYPE,
     &                            EXPANSION_TE, EXPANSION_LE,
     &                            EXPANSION_HLE, EXPANSION_MISC,
     &                            EXPANSION_NONE,
     &                            PARSE_EXPANSION_TOKEN
      USE MUL2_READ_KINEMATICS, ONLY: READ_KINEMATICS_FILE               ! Use from module mul2 read kinematics: read kinematics file.
      USE MUL2_NODES, ONLY: NODE_DB_TYPE                                 ! Use from module mul2 nodes: node db type.
      USE MUL2_READ_NODES, ONLY: READ_NODES_FILE                         ! Use from module mul2 read nodes: read nodes file.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_B2, TOPOLOGY_B3,               ! Use from module mul2 topologies: topology b2, topology b3, topology b4, topology q4, topology q9, topology ...
     &     TOPOLOGY_B4, TOPOLOGY_Q4, TOPOLOGY_Q9,
     &     TOPOLOGY_Q16, TOPOLOGY_T3, TOPOLOGY_T6,
     &     TOPOLOGY_H8, TOPOLOGY_H27, TOPOLOGY_NODE_COUNT,
     &     TOPOLOGY_NATURAL_DIMENSION
      USE MUL2_READ_CONNECTIVITY, ONLY: READ_CONNECTIVITY_FILE           ! Use from module mul2 read connectivity: read connectivity file.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE                 ! Use from module mul2 expansion meshes: expansion db type.
      USE MUL2_READ_EXPANSIONS, ONLY: READ_EXPANSION_SET                 ! Use from module mul2 read expansions: read expansion set.
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE,                        ! Use from module mul2 dof layout: dof layout type, build dof layout, global dof.
     &                           BUILD_DOF_LAYOUT, GLOBAL_DOF
      USE MUL2_SHAPE_FUNCTIONS, ONLY: EVALUATE_SHAPE                     ! Use from module mul2 shape functions: evaluate shape.
      USE MUL2_QUADRATURE, ONLY: QUADRATURE_RULE_TYPE,                   ! Use from module mul2 quadrature: quadrature rule type, build default quadrature.
     &                           BUILD_DEFAULT_QUADRATURE
      USE MUL2_JACOBIANS, ONLY: EVALUATE_SQUARE_JACOBIAN                 ! Use from module mul2 jacobians: evaluate square jacobian.
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type, build reference rule database...
     &     GAUSS_LAYOUT_TYPE, BUILD_REFERENCE_RULE_DATABASE,
     &     BUILD_GAUSS_LAYOUT
      USE MUL2_REFERENCE_SYSTEMS, ONLY: REFERENCE_VECTOR_DB_TYPE,        ! Use from module mul2 reference systems: reference vector db type, element frame db type.
     &                                  ELEMENT_FRAME_DB_TYPE
      USE MUL2_READ_REFERENCE_SYSTEMS, ONLY:                             ! Use from module mul2 read reference systems: read reference vectors file.
     &     READ_REFERENCE_VECTORS_FILE
      USE MUL2_ELEMENT_FRAMES, ONLY: BUILD_ELEMENT_FRAMES                ! Use from module mul2 element frames: build element frames.
      USE MUL2_GAUSS_GEOMETRY, ONLY:                                     ! Use from module mul2 gauss geometry: structural geometry cache type, expansion geometry cache type, gauss g...
     &     STRUCTURAL_GEOMETRY_CACHE_TYPE,
     &     EXPANSION_GEOMETRY_CACHE_TYPE, GAUSS_GEOMETRY_TYPE,
     &     BUILD_STRUCTURAL_GEOMETRY_CACHE,
     &     BUILD_EXPANSION_GEOMETRY_CACHE,
     &     BUILD_COMBINED_GAUSS_GEOMETRY
      USE MUL2_MATERIALS, ONLY: MATERIAL_TYPE, MATERIAL_DB_TYPE,         ! Use from module mul2 materials: material type, material db type, material isotropic, build isotropic materi...
     &     MATERIAL_ISOTROPIC, BUILD_ISOTROPIC_MATERIAL,
     &     BUILD_ORTHOTROPIC_MATERIAL
      USE MUL2_LAMINATIONS, ONLY: LAMINATION_DB_TYPE                     ! Use from module mul2 laminations: lamination db type.
      USE MUL2_READ_MATERIALS, ONLY: READ_MATERIALS_FILE                 ! Use from module mul2 read materials: read materials file.
      USE MUL2_READ_LAMINATIONS, ONLY: READ_LAMINATIONS_FILE             ! Use from module mul2 read laminations: read laminations file.
      USE MUL2_MATERIAL_ROTATIONS, ONLY: BUILD_MATERIAL_ROTATION,        ! Use from module mul2 material rotations: build material rotation, rotate stiffness.
     &                                  ROTATE_STIFFNESS
      USE MUL2_MATERIAL_RESOLUTION, ONLY: RESOLVE_LAMINATION             ! Use from module mul2 material resolution: resolve lamination.
      USE MUL2_GAUSS_MATERIALS, ONLY: MATERIAL_CACHE_TYPE,               ! Use from module mul2 gauss materials: material cache type, gauss material map type, build gauss material ca...
     &     GAUSS_MATERIAL_MAP_TYPE, BUILD_GAUSS_MATERIAL_CACHE
      USE MUL2_LINEAR_KINEMATICS, ONLY: COMPOSE_PRODUCT_BASIS,           ! Use from module mul2 linear kinematics: compose product basis, build displacement column, build displacemen...
     &     BUILD_DISPLACEMENT_COLUMN, BUILD_DISPLACEMENT_OPERATOR
      USE MUL2_FUNDAMENTAL_NUCLEUS, ONLY:                                ! Use from module mul2 fundamental nucleus: stiffness nucleus, stiffness block nucleus, mass nucleus, mass bl...
     &     STIFFNESS_NUCLEUS, STIFFNESS_BLOCK_NUCLEUS,
     &     MASS_NUCLEUS, MASS_BLOCK_NUCLEUS,
     &     ROTATE_BLOCK_TO_GLOBAL
      USE MUL2_CUF_BASES, ONLY: TAYLOR_BASIS_TERM_COUNT,                 ! Use from module mul2 cuf bases: taylor basis term count, evaluate taylor basis.
     &                          EVALUATE_TAYLOR_BASIS
      USE MUL2_POINT_BASES, ONLY: EVALUATE_POINT_BASIS                   ! Use from module mul2 point bases: evaluate point basis.
      USE MUL2_ELEMENT_MATRICES, ONLY: ELEMENT_MATRIX_TYPE,              ! Use from module mul2 element matrices: element matrix type, build linear element matrices.
     &     BUILD_LINEAR_ELEMENT_MATRICES
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE,                ! Use from module mul2 sparse assembly: sparse system type, build and assemble sparse system.
     &     BUILD_AND_ASSEMBLE_SPARSE_SYSTEM
      USE MUL2_BOUNDARY_CONDITIONS, ONLY: BOUNDARY_DB_TYPE,              ! Use from module mul2 boundary conditions: boundary db type, bc displacement plane, bc force point.
     &     BC_DISPLACEMENT_PLANE, BC_FORCE_POINT
      USE MUL2_READ_BOUNDARY_CONDITIONS, ONLY:                           ! Use from module mul2 read boundary conditions: read boundary conditions file.
     &     READ_BOUNDARY_CONDITIONS_FILE
      USE MUL2_BOUNDARY_APPLICATION, ONLY: CONSTRAINT_SET_TYPE,          ! Use from module mul2 boundary application: constraint set type, build mechanical boundary data, apply stati...
     &     BUILD_MECHANICAL_BOUNDARY_DATA, APPLY_STATIC_CONSTRAINTS

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.

      TYPE(STATUS_TYPE) :: STATUS                                        ! Of type status_type: status.
      TYPE(TIMER_TYPE) :: TIMER                                          ! Of type timer_type: timer.
      TYPE(KINEMATICS_DB_TYPE) :: KINEMATICS                             ! Of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                  ! Of type expansion_spec_type: spec.
      TYPE(NODE_DB_TYPE) :: NODES                                        ! Of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE) :: ELEMENTS                                  ! Of type element_db_type: elements.
      TYPE(ELEMENT_DB_TYPE) :: DOF_ELEMENTS                              ! Of type element_db_type: dof_elements.
      TYPE(EXPANSION_DB_TYPE) :: EXPANSIONS                              ! Of type expansion_db_type: expansions.
      TYPE(DOF_LAYOUT_TYPE) :: DOF_LAYOUT                                ! Of type dof_layout_type: dof_layout.
      TYPE(QUADRATURE_RULE_TYPE) :: QUADRATURE                           ! Of type quadrature_rule_type: quadrature.
      TYPE(REFERENCE_RULE_DB_TYPE) :: REFERENCE_RULES                    ! Of type reference_rule_db_type: reference_rules.
      TYPE(GAUSS_LAYOUT_TYPE) :: GAUSS_LAYOUT                            ! Of type gauss_layout_type: gauss_layout.
      TYPE(GAUSS_LAYOUT_TYPE) :: DOF_GAUSS_LAYOUT                        ! Of type gauss_layout_type: dof_gauss_layout.
      TYPE(REFERENCE_VECTOR_DB_TYPE) :: REFERENCE_VECTORS                ! Of type reference_vector_db_type: reference_vectors.
      TYPE(ELEMENT_FRAME_DB_TYPE) :: ELEMENT_FRAMES                      ! Of type element_frame_db_type: element_frames.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE) :: STRUCTURAL_GEOMETRY        ! Of type structural_geometry_cache_type: structural_geometry.
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE) :: EXPANSION_GEOMETRY          ! Of type expansion_geometry_cache_type: expansion_geometry.
      TYPE(GAUSS_GEOMETRY_TYPE) :: COMBINED_GEOMETRY                     ! Of type gauss_geometry_type: combined_geometry.
      TYPE(MATERIAL_TYPE) :: TEST_MATERIAL                               ! Of type material_type: test_material.
      TYPE(MATERIAL_DB_TYPE) :: MATERIALS                                ! Of type material_db_type: materials.
      TYPE(LAMINATION_DB_TYPE) :: LAMINATIONS                            ! Of type lamination_db_type: laminations.
      TYPE(MATERIAL_CACHE_TYPE) :: MATERIAL_CACHE                        ! Of type material_cache_type: material_cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE) :: GAUSS_MATERIAL_MAP                ! Of type gauss_material_map_type: gauss_material_map.
      TYPE(ELEMENT_MATRIX_TYPE) :: ELEMENT_MATRIX                        ! Of type element_matrix_type: element_matrix.
      TYPE(ELEMENT_MATRIX_TYPE), ALLOCATABLE ::                          ! Allocatable of type element_matrix_type: element_matrix_list(:).
     &  ELEMENT_MATRIX_LIST(:)
      TYPE(SPARSE_SYSTEM_TYPE) :: SPARSE_SYSTEM                          ! Of type sparse_system_type: sparse_system.
      TYPE(SPARSE_SYSTEM_TYPE) :: CONSTRAINED_SYSTEM                     ! Of type sparse_system_type: constrained_system.
      TYPE(BOUNDARY_DB_TYPE) :: BOUNDARIES                               ! Of type boundary_db_type: boundaries.
      TYPE(CONSTRAINT_SET_TYPE) :: CONSTRAINTS                           ! Of type constraint_set_type: constraints.
      INTEGER(I8) :: FAILURES                                            ! Integer (int64): failures.
      INTEGER(I4) :: SHAPE_TOPOLOGY(10)                                  ! Integer (int32): shape_topology(10).
      INTEGER(I4) :: SHAPE_NODE_COUNT                                    ! Integer (int32): shape_node_count.
      INTEGER(I4) :: SHAPE_DIMENSION                                     ! Integer (int32): shape_dimension.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      REAL(R8) :: ELAPSED                                                ! Real (real64): elapsed.
      REAL(R8) :: NATURAL(3)                                             ! Real (real64): natural(3).
      REAL(R8) :: SHAPE(27)                                              ! Real (real64): shape(27).
      REAL(R8) :: DERIVATIVE(27,3)                                       ! Real (real64): derivative(27,3).
      REAL(R8) :: COORDINATE_2D(4,2)                                     ! Real (real64): coordinate_2d(4,2).
      REAL(R8) :: JACOBIAN(3,3)                                          ! Real (real64): jacobian(3,3).
      REAL(R8) :: INVERSE_JACOBIAN(3,3)                                  ! Real (real64): inverse_jacobian(3,3).
      REAL(R8) :: PHYSICAL_DERIVATIVE(27,3)                              ! Real (real64): physical_derivative(27,3).
      REAL(R8) :: DETERMINANT                                            ! Real (real64): determinant.
      REAL(R8) :: MATERIAL_ROTATION(3,3)                                 ! Real (real64): material_rotation(3,3).
      REAL(R8) :: ROTATED_STIFFNESS(6,6)                                 ! Real (real64): rotated_stiffness(6,6).
      REAL(R8) :: RESOLVED_STIFFNESS(6,6)                                ! Real (real64): resolved_stiffness(6,6).
      REAL(R8) :: RESOLVED_DENSITY                                       ! Real (real64): resolved_density.
      REAL(R8) :: BASIS_VALUE                                            ! Real (real64): basis_value.
      REAL(R8) :: BASIS_GRADIENT(3)                                      ! Real (real64): basis_gradient(3).
      REAL(R8) :: TEST_GRADIENT(3)                                       ! Real (real64): test_gradient(3).
      REAL(R8) :: TRIAL_GRADIENT(3)                                      ! Real (real64): trial_gradient(3).
      REAL(R8) :: TEST_OPERATOR(6,3)                                     ! Real (real64): test_operator(6,3).
      REAL(R8) :: TRIAL_OPERATOR(6,3)                                    ! Real (real64): trial_operator(6,3).
      REAL(R8) :: TEST_COLUMN(6)                                         ! Real (real64): test_column(6).
      REAL(R8) :: TRIAL_COLUMN(6)                                        ! Real (real64): trial_column(6).
      REAL(R8) :: STIFFNESS_BLOCK(3,3)                                   ! Real (real64): stiffness_block(3,3).
      REAL(R8) :: REVERSE_BLOCK(3,3)                                     ! Real (real64): reverse_block(3,3).
      REAL(R8) :: MASS_BLOCK(3,3)                                        ! Real (real64): mass_block(3,3).
      REAL(R8) :: SCALAR_NUCLEUS                                         ! Real (real64): scalar_nucleus.
      REAL(R8) :: TAYLOR_VALUE(10)                                       ! Real (real64): taylor_value(10).
      REAL(R8) :: TAYLOR_GRADIENT(3,10)                                  ! Real (real64): taylor_gradient(3,10).
      REAL(R8) :: POINT_BASIS_VALUE                                      ! Real (real64): point_basis_value.
      REAL(R8) :: POINT_BASIS_GRADIENT(3)                                ! Real (real64): point_basis_gradient(3).
      REAL(R8) :: BASIS_VALUE_SUM                                        ! Real (real64): basis_value_sum.
      REAL(R8) :: BASIS_GRADIENT_SUM(3)                                  ! Real (real64): basis_gradient_sum(3).
      REAL(R8), ALLOCATABLE :: RIGID_VECTOR(:)                           ! Allocatable real (real64): rigid_vector(:).
      REAL(R8) :: RIGID_ENERGY                                           ! Real (real64): rigid_energy.
      REAL(R8) :: MASS_ENERGY                                            ! Real (real64): mass_energy.
      INTEGER(I8) :: SPARSE_POSITION                                     ! Integer (int64): sparse_position.
      INTEGER(I8) :: SPARSE_ROW                                          ! Integer (int64): sparse_row.
      INTEGER(I8) :: SPARSE_COLUMN                                       ! Integer (int64): sparse_column.
      REAL(R8), ALLOCATABLE :: GLOBAL_FORCE(:)                           ! Allocatable real (real64): global_force(:).

      FAILURES = 0_I8                                                    ! Set failures to zero.

      SHAPE_TOPOLOGY = [TOPOLOGY_B2, TOPOLOGY_B3,                        ! Set shape_topology to [topology_b2, topology_b3, topology_b4, topology_q4, topology_q9, topology_q16, topol...
     & TOPOLOGY_B4, TOPOLOGY_Q4, TOPOLOGY_Q9,
     & TOPOLOGY_Q16, TOPOLOGY_T3, TOPOLOGY_T6,
     & TOPOLOGY_H8, TOPOLOGY_H27]
      NATURAL = [0.2_R8,-0.3_R8,0.1_R8]                                  ! Set natural to [0.2,-0.3,0.1].
      DO I = 1_I4, SIZE(SHAPE_TOPOLOGY)                                  ! Loop i from 1 to size(shape_topology):
        CALL EVALUATE_SHAPE(SHAPE_TOPOLOGY(I), NATURAL,                  ! Call evaluate shape with shape_topology(i), natural, shape, derivative, status.
     &                      SHAPE, DERIVATIVE, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) THEN                             ! If not status is ok:
          WRITE(*,'(A)') 'FAIL: EVALUATE_SHAPE'                          ! Print: 'FAIL: EVALUATE_SHAPE'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
          CYCLE                                                          ! Skip to the next iteration.
        END IF                                                           ! End of the IF block.
        SHAPE_NODE_COUNT = TOPOLOGY_NODE_COUNT(                          ! Set shape_node_count to topology_node_count( shape_topology(i)).
     &                     SHAPE_TOPOLOGY(I))
        SHAPE_DIMENSION = TOPOLOGY_NATURAL_DIMENSION(                    ! Set shape_dimension to topology_natural_dimension( shape_topology(i)).
     &                    SHAPE_TOPOLOGY(I))
        IF (ABS(SUM(SHAPE(1:SHAPE_NODE_COUNT))-1.0_R8)                   ! If abs(sum(shape(1:shape_node_count))-1.0) > 1.0e-12:
     &      .GT. 1.0E-12_R8) THEN
          WRITE(*,'(A,I0)') 'FAIL: PARTITION OF UNITY ',                 ! Print: 'FAIL: PARTITION OF UNITY ', shape_topology(i).
     &                       SHAPE_TOPOLOGY(I)
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        DO J = 1_I4, SHAPE_DIMENSION                                     ! Loop j from 1 to shape_dimension:
          IF (ABS(SUM(DERIVATIVE(1:SHAPE_NODE_COUNT,J)))                 ! If abs(sum(derivative(1:shape_node_count,j))) > 1.0e-12:
     &        .GT. 1.0E-12_R8) THEN
            WRITE(*,'(A,I0)') 'FAIL: SHAPE DERIVATIVE SUM ',             ! Print: 'FAIL: SHAPE DERIVATIVE SUM ', shape_topology(i).
     &                         SHAPE_TOPOLOGY(I)
            FAILURES = FAILURES + 1_I8                                   ! Add 1 to failures.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      CALL BUILD_DEFAULT_QUADRATURE(TOPOLOGY_B4,                         ! Call build default quadrature with topology_b4, quadrature, status.
     &                              QUADRATURE, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or abs(sum(quadrature.weight)-2.0) > 1.0e-14:
     &    ABS(SUM(QUADRATURE%WEIGHT)-2.0_R8)
     &    .GT. 1.0E-14_R8) THEN
        WRITE(*,'(A)') 'FAIL: LINE GAUSS QUADRATURE'                     ! Print: 'FAIL: LINE GAUSS QUADRATURE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_DEFAULT_QUADRATURE(TOPOLOGY_Q9,                         ! Call build default quadrature with topology_q9, quadrature, status.
     &                              QUADRATURE, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or abs(sum(quadrature.weight)-4.0) > 1.0e-14:
     &    ABS(SUM(QUADRATURE%WEIGHT)-4.0_R8)
     &    .GT. 1.0E-14_R8) THEN
        WRITE(*,'(A)') 'FAIL: QUADRILATERAL GAUSS QUADRATURE'            ! Print: 'FAIL: QUADRILATERAL GAUSS QUADRATURE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_DEFAULT_QUADRATURE(TOPOLOGY_T6,                         ! Call build default quadrature with topology_t6, quadrature, status.
     &                              QUADRATURE, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or abs(sum(quadrature.weight)-0.5) > 1.0e-14:
     &    ABS(SUM(QUADRATURE%WEIGHT)-0.5_R8)
     &    .GT. 1.0E-14_R8) THEN
        WRITE(*,'(A)') 'FAIL: TRIANGLE GAUSS QUADRATURE'                 ! Print: 'FAIL: TRIANGLE GAUSS QUADRATURE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_DEFAULT_QUADRATURE(TOPOLOGY_H8,                         ! Call build default quadrature with topology_h8, quadrature, status.
     &                              QUADRATURE, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or abs(sum(quadrature.weight)-8.0) > 1.0e-13:
     &    ABS(SUM(QUADRATURE%WEIGHT)-8.0_R8)
     &    .GT. 1.0E-13_R8) THEN
        WRITE(*,'(A)') 'FAIL: HEXAHEDRON GAUSS QUADRATURE'               ! Print: 'FAIL: HEXAHEDRON GAUSS QUADRATURE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      NATURAL = 0.0_R8                                                   ! Set natural to zero.
      CALL EVALUATE_SHAPE(TOPOLOGY_Q4, NATURAL,                          ! Call evaluate shape with topology_q4, natural, shape, derivative, status.
     &                    SHAPE, DERIVATIVE, STATUS)
      COORDINATE_2D(1,:) = [0.0_R8,0.0_R8]                               ! Set coordinate_2d(1,:) to [0.0,0.0].
      COORDINATE_2D(2,:) = [2.0_R8,0.0_R8]                               ! Set coordinate_2d(2,:) to [2.0,0.0].
      COORDINATE_2D(3,:) = [2.0_R8,4.0_R8]                               ! Set coordinate_2d(3,:) to [2.0,4.0].
      COORDINATE_2D(4,:) = [0.0_R8,4.0_R8]                               ! Set coordinate_2d(4,:) to [0.0,4.0].
      CALL EVALUATE_SQUARE_JACOBIAN(COORDINATE_2D,                       ! Call evaluate square jacobian with coordinate_2d, derivative(1:4,1:2), 2, jacobian, determinant, inverse_ja...
     & DERIVATIVE(1:4,1:2), 2, JACOBIAN, DETERMINANT,
     & INVERSE_JACOBIAN, PHYSICAL_DERIVATIVE(1:4,1:2),
     & STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or abs(determinant-2.0) > 1.0e-14 or abs(jacobian(1,1)-1.0) > 1.0e-14 or abs(jacobian(2...
     &    ABS(DETERMINANT-2.0_R8) .GT. 1.0E-14_R8 .OR.
     &    ABS(JACOBIAN(1,1)-1.0_R8) .GT. 1.0E-14_R8 .OR.
     &    ABS(JACOBIAN(2,2)-2.0_R8) .GT. 1.0E-14_R8) THEN
        WRITE(*,'(A)') 'FAIL: Q4 JACOBIAN'                               ! Print: 'FAIL: Q4 JACOBIAN'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: CLEAR_STATUS'                              ! Print: 'FAIL: CLEAR_STATUS'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL PARSE_EXPANSION_TOKEN('hle4', SPEC, STATUS)                   ! Call parse expansion token with 'hle4', spec, status.
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or spec.family /= expansion_hle or spec.order /= 4:
     &    SPEC%FAMILY .NE. EXPANSION_HLE .OR.
     &    SPEC%ORDER .NE. 4) THEN
        WRITE(*,'(A)') 'FAIL: HLE TOKEN'                                 ! Print: 'FAIL: HLE TOKEN'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
!     PLAIN HLE: THE ORDER BELONGS TO THE SECTION SUB-ELEMENTS.
      CALL PARSE_EXPANSION_TOKEN('HLE', SPEC, STATUS)                    ! Call parse expansion token with 'HLE', spec, status.
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or spec.family /= expansion_hle:
     &    SPEC%FAMILY .NE. EXPANSION_HLE) THEN
        WRITE(*,'(A)') 'FAIL: PLAIN HLE TOKEN'                           ! Print: 'FAIL: PLAIN HLE TOKEN'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL PARSE_EXPANSION_TOKEN('M0', SPEC, STATUS)                     ! Call parse expansion token with 'M0', spec, status.
      IF (STATUS_IS_OK(STATUS)) THEN                                     ! If status is ok:
        WRITE(*,'(A)') 'FAIL: M FIELD ID MUST BE POSITIVE'               ! Print: 'FAIL: M FIELD ID MUST BE POSITIVE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL SET_WARNING(STATUS, 'MUL2_TESTS', 'EXPECTED WARNING')         ! Record a warning in status: 'EXPECTED WARNING'.
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or status.warning_count /= 1:
     &    STATUS%WARNING_COUNT .NE. 1) THEN
        WRITE(*,'(A)') 'FAIL: SET_WARNING'                               ! Print: 'FAIL: SET_WARNING'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL SET_ERROR(STATUS, 'MUL2_TESTS', 'EXPECTED ERROR')             ! Record an error in status: 'EXPECTED ERROR'.
      IF (STATUS_IS_OK(STATUS)) THEN                                     ! If status is ok:
        WRITE(*,'(A)') 'FAIL: SET_ERROR'                                 ! Print: 'FAIL: SET_ERROR'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL SET_ERROR(STATUS, 'MUL2_TESTS', 'MUST NOT REPLACE FIRST')     ! Record an error in status: 'MUST NOT REPLACE FIRST'.
      IF (TRIM(STATUS%MESSAGE) .NE. 'EXPECTED ERROR') THEN               ! If trim(status.message) /= 'EXPECTED ERROR':
        WRITE(*,'(A)') 'FAIL: FIRST ERROR MUST BE PRESERVED'             ! Print: 'FAIL: FIRST ERROR MUST BE PRESERVED'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL TIMER_START(TIMER, 'TEST')                                    ! Call timer start with timer, 'TEST'.
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      ELAPSED = TIMER_WALL_SECONDS(TIMER)                                ! Set elapsed to timer_wall_seconds(timer).
      IF (ELAPSED .LT. 0.0_R8) THEN                                      ! If elapsed < 0.0:
        WRITE(*,'(A,ES12.4)') 'FAIL: NEGATIVE TIMER ', ELAPSED           ! Print: 'FAIL: NEGATIVE TIMER ', elapsed.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL READ_KINEMATICS_FILE(                                         ! Call read kinematics file with 'TESTS/DATA/KINEMATICS_VALID.dat', kinematics, status.
     &     'TESTS/DATA/KINEMATICS_VALID.dat', KINEMATICS, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: READ_KINEMATICS_FILE'                      ! Print: 'FAIL: READ_KINEMATICS_FILE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        IF (SIZE(KINEMATICS%ITEM) .NE. 2) THEN                           ! If size(kinematics.item) /= 2:
          WRITE(*,'(A)') 'FAIL: KINEMATIC COUNT'                         ! Print: 'FAIL: KINEMATIC COUNT'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (KINEMATICS%ITEM(1)%FIELD(1)%FAMILY .NE.                      ! If kinematics.item(1).field(1).family /= expansion_te, add 1 to failures.
     &      EXPANSION_TE) FAILURES = FAILURES + 1_I8
        IF (KINEMATICS%ITEM(1)%FIELD(1)%ORDER .NE. 1) THEN               ! If kinematics.item(1).field(1).order /= 1:
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (KINEMATICS%ITEM(2)%FIELD(1)%FAMILY .NE.                      ! If kinematics.item(2).field(1).family /= expansion_le, add 1 to failures.
     &      EXPANSION_LE) FAILURES = FAILURES + 1_I8
        IF (KINEMATICS%ITEM(2)%FIELD(3)%FAMILY .NE.                      ! If kinematics.item(2).field(3).family /= expansion_hle, add 1 to failures.
     &      EXPANSION_HLE) FAILURES = FAILURES + 1_I8
        IF (KINEMATICS%ITEM(2)%FIELD(3)%ORDER .NE. 2) THEN               ! If kinematics.item(2).field(3).order /= 2:
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (KINEMATICS%ITEM(2)%FIELD(4)%FAMILY .NE.                      ! If kinematics.item(2).field(4).family /= expansion_misc, add 1 to failures.
     &      EXPANSION_MISC) FAILURES = FAILURES + 1_I8
        IF (KINEMATICS%ITEM(2)%FIELD(4)%FIELD_REFERENCE .NE. 1) THEN     ! If kinematics.item(2).field(4).field_reference /= 1:
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      CALL READ_NODES_FILE('TESTS/DATA/NODES_VALID.dat',                 ! Call read nodes file with 'TESTS/DATA/NODES_VALID.dat', kinematics, nodes, status.
     &                     KINEMATICS, NODES, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: READ_NODES_FILE'                           ! Print: 'FAIL: READ_NODES_FILE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        IF (SIZE(NODES%ITEM) .NE. 3) THEN                                ! If size(nodes.item) /= 3:
          WRITE(*,'(A)') 'FAIL: NODE COUNT'                              ! Print: 'FAIL: NODE COUNT'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (NODES%ITEM(2)%KINEMATIC_ID .NE. 2) THEN                      ! If nodes.item(2).kinematic_id /= 2:
          WRITE(*,'(A)') 'FAIL: NODE KINEMATIC ID'                       ! Print: 'FAIL: NODE KINEMATIC ID'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (ABS(NODES%ITEM(3)%COORDINATE(2)-1.0_R8) .GT.                 ! If abs(nodes.item(3).coordinate(2)-1.0) > 1.0e-14:
     &      1.0E-14_R8) THEN
          WRITE(*,'(A)') 'FAIL: NODE COORDINATE'                         ! Print: 'FAIL: NODE COORDINATE'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      CALL READ_CONNECTIVITY_FILE(                                       ! Call read connectivity file with 'TESTS/DATA/CONNECTIVITY_VALID.dat', nodes, elements, status.
     &     'TESTS/DATA/CONNECTIVITY_VALID.dat',
     &     NODES, ELEMENTS, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: READ_CONNECTIVITY_FILE'                    ! Print: 'FAIL: READ_CONNECTIVITY_FILE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        IF (SIZE(ELEMENTS%ITEM) .NE. 2) THEN                             ! If size(elements.item) /= 2:
          WRITE(*,'(A)') 'FAIL: ELEMENT COUNT'                           ! Print: 'FAIL: ELEMENT COUNT'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (ELEMENTS%ITEM(1)%TOPOLOGY .NE. TOPOLOGY_B2) THEN             ! If elements.item(1).topology /= topology_b2:
          WRITE(*,'(A)') 'FAIL: B2 TOPOLOGY'                             ! Print: 'FAIL: B2 TOPOLOGY'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (ELEMENTS%ITEM(2)%TOPOLOGY .NE. TOPOLOGY_T3) THEN             ! If elements.item(2).topology /= topology_t3:
          WRITE(*,'(A)') 'FAIL: T3 TOPOLOGY'                             ! Print: 'FAIL: T3 TOPOLOGY'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (SIZE(ELEMENTS%ITEM(2)%NODE_ID) .NE. 3) THEN                  ! If size(elements.item(2).node_id) /= 3:
          WRITE(*,'(A)') 'FAIL: T3 NODE COUNT'                           ! Print: 'FAIL: T3 NODE COUNT'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      CALL READ_EXPANSION_SET(                                           ! Call read expansion set with 'REFERENCES/BASELINE_INPUTS/INPUT_1d_2d_3d', 3, expansions, status.
     & 'REFERENCES/BASELINE_INPUTS/INPUT_1d_2d_3d',
     & 3, EXPANSIONS, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: READ_EXPANSION_SET'                        ! Print: 'FAIL: READ_EXPANSION_SET'.
        WRITE(*,'(A)') TRIM(STATUS%MESSAGE)                              ! Print: trim(status.message).
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        IF (SIZE(EXPANSIONS%ITEM) .NE. 3) THEN                           ! If size(expansions.item) /= 3:
          WRITE(*,'(A)') 'FAIL: EXPANSION COUNT'                         ! Print: 'FAIL: EXPANSION COUNT'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (SIZE(EXPANSIONS%ITEM(1)%NODE) .NE. 3) THEN                   ! If size(expansions.item(1).node) /= 3:
          WRITE(*,'(A)') 'FAIL: B3 EXPANSION NODES'                      ! Print: 'FAIL: B3 EXPANSION NODES'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (SIZE(EXPANSIONS%ITEM(2)%NODE) .NE. 9) THEN                   ! If size(expansions.item(2).node) /= 9:
          WRITE(*,'(A)') 'FAIL: Q9 EXPANSION NODES'                      ! Print: 'FAIL: Q9 EXPANSION NODES'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (SIZE(EXPANSIONS%ITEM(3)%NODE) .NE. 1) THEN                   ! If size(expansions.item(3).node) /= 1:
          WRITE(*,'(A)') 'FAIL: S1 EXPANSION NODES'                      ! Print: 'FAIL: S1 EXPANSION NODES'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (EXPANSIONS%ITEM(2)%ELEMENT(1)%LAMINATION_ID                  ! If expansions.item(2).element(1).lamination_id /= 1:
     &      .NE. 1) THEN
          WRITE(*,'(A)') 'FAIL: EXPANSION LAMINATION ID'                 ! Print: 'FAIL: EXPANSION LAMINATION ID'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      ALLOCATE(DOF_ELEMENTS%ITEM(1))                                     ! Allocate memory for dof_elements.item(1).
      DOF_ELEMENTS%ITEM(1)%ID = 1_I8                                     ! Set dof_elements.item(1).id to 1.
      DOF_ELEMENTS%ITEM(1)%TOPOLOGY = TOPOLOGY_B2                        ! Set dof_elements.item(1).topology to topology_b2.
      DOF_ELEMENTS%ITEM(1)%EXPANSION_ID = 1                              ! Set dof_elements.item(1).expansion_id to 1.
      DOF_ELEMENTS%ITEM(1)%FRAME_ID = 1                                  ! Set dof_elements.item(1).frame_id to 1.
      ALLOCATE(DOF_ELEMENTS%ITEM(1)%NODE_ID(2))                          ! Allocate memory for dof_elements.item(1).node_id(2).
      DOF_ELEMENTS%ITEM(1)%NODE_ID = [1_I8,2_I8]                         ! Set dof_elements.item(1).node_id to [1,2].
      KINEMATICS%ITEM(2)%FIELD(3)%FAMILY = EXPANSION_NONE                ! Set kinematics.item(2).field(3).family to expansion_none.
      KINEMATICS%ITEM(2)%FIELD(4)%FAMILY = EXPANSION_NONE                ! Set kinematics.item(2).field(4).family to expansion_none.
      CALL BUILD_DOF_LAYOUT(NODES, DOF_ELEMENTS, KINEMATICS,             ! Call build dof layout with nodes, dof_elements, kinematics, expansions, dof_layout, status.
     &                      EXPANSIONS, DOF_LAYOUT, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: BUILD_DOF_LAYOUT'                          ! Print: 'FAIL: BUILD_DOF_LAYOUT'.
        WRITE(*,'(A)') TRIM(STATUS%MESSAGE)                              ! Print: trim(status.message).
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        IF (DOF_LAYOUT%TOTAL_DOF .NE. 15_I8) THEN                        ! If dof_layout.total_dof /= 15:
          WRITE(*,'(A)') 'FAIL: TOTAL FIELD-MAJOR DOF'                   ! Print: 'FAIL: TOTAL FIELD-MAJOR DOF'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (GLOBAL_DOF(DOF_LAYOUT,1,1,1) .NE. 1_I8) THEN                 ! If global_dof(dof_layout,1,1,1) /= 1:
          WRITE(*,'(A)') 'FAIL: FIRST U DOF'                             ! Print: 'FAIL: FIRST U DOF'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (GLOBAL_DOF(DOF_LAYOUT,2,1,1) .NE. 3_I8) THEN                 ! If global_dof(dof_layout,2,1,1) /= 3:
          WRITE(*,'(A)') 'FAIL: SECOND NODE U DOF'                       ! Print: 'FAIL: SECOND NODE U DOF'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (GLOBAL_DOF(DOF_LAYOUT,1,2,1) .NE. 6_I8) THEN                 ! If global_dof(dof_layout,1,2,1) /= 6:
          WRITE(*,'(A)') 'FAIL: FIRST V DOF'                             ! Print: 'FAIL: FIRST V DOF'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      CALL READ_REFERENCE_VECTORS_FILE(                                  ! Call read reference vectors file with 'REFERENCES/BASELINE_INPUTS/101_BEAM_B4_LE/VERSORS.dat', reference_ve...
     & 'REFERENCES/BASELINE_INPUTS/101_BEAM_B4_LE/VERSORS.dat',
     & REFERENCE_VECTORS, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: READ_REFERENCE_VECTORS_FILE'               ! Print: 'FAIL: READ_REFERENCE_VECTORS_FILE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        CALL BUILD_ELEMENT_FRAMES(NODES, DOF_ELEMENTS,                   ! Call build element frames with nodes, dof_elements, reference_vectors, element_frames, status.
     &       REFERENCE_VECTORS, ELEMENT_FRAMES, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) THEN                             ! If not status is ok:
          WRITE(*,'(A)') 'FAIL: BUILD_ELEMENT_FRAMES'                    ! Print: 'FAIL: BUILD_ELEMENT_FRAMES'.
          WRITE(*,'(A)') TRIM(STATUS%MESSAGE)                            ! Print: trim(status.message).
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        ELSE IF (MAXVAL(ABS(ELEMENT_FRAMES%GLOBAL_TO_LOCAL(:,:,1)-       ! Otherwise, if maxval(abs(element_frames.global_to_local(:,:,1)- reshape([1.0,0.0,0.0, 0.0,1.0,0.0, 0.0,0.0,...
     &           RESHAPE([1.0_R8,0.0_R8,0.0_R8,
     &                    0.0_R8,1.0_R8,0.0_R8,
     &                    0.0_R8,0.0_R8,1.0_R8],[3,3])))
     &           .GT. 1.0E-14_R8) THEN
          WRITE(*,'(A)') 'FAIL: BEAM REFERENCE SYSTEM'                   ! Print: 'FAIL: BEAM REFERENCE SYSTEM'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      CALL BUILD_REFERENCE_RULE_DATABASE(ELEMENTS, EXPANSIONS,           ! Call build reference rule database with elements, expansions, reference_rules, status.
     &     REFERENCE_RULES, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: BUILD_REFERENCE_RULE_DATABASE'             ! Print: 'FAIL: BUILD_REFERENCE_RULE_DATABASE'.
        WRITE(*,'(A)') TRIM(STATUS%MESSAGE)                              ! Print: trim(status.message).
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE IF (SIZE(REFERENCE_RULES%ITEM) .NE. 5) THEN                   ! Otherwise, if size(reference_rules.item) /= 5:
        WRITE(*,'(A)') 'FAIL: REFERENCE RULE COUNT'                      ! Print: 'FAIL: REFERENCE RULE COUNT'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_GAUSS_LAYOUT(ELEMENTS, EXPANSIONS,                      ! Call build gauss layout with elements, expansions, reference_rules, gauss_layout, status.
     &     REFERENCE_RULES, GAUSS_LAYOUT, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: BUILD_GAUSS_LAYOUT'                        ! Print: 'FAIL: BUILD_GAUSS_LAYOUT'.
        WRITE(*,'(A)') TRIM(STATUS%MESSAGE)                              ! Print: trim(status.message).
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        IF (GAUSS_LAYOUT%COUNT .NE. 9_I8) THEN                           ! If gauss_layout.count /= 9:
          WRITE(*,'(A)') 'FAIL: GLOBAL GAUSS POINT COUNT'                ! Print: 'FAIL: GLOBAL GAUSS POINT COUNT'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (GAUSS_LAYOUT%ELEMENT_FIRST(1) .NE. 1_I8 .OR.                 ! If gauss_layout.element_first(1) /= 1 or gauss_layout.element_last(1) /= 6 or gauss_layout.element_first(2)...
     &      GAUSS_LAYOUT%ELEMENT_LAST(1) .NE. 6_I8 .OR.
     &      GAUSS_LAYOUT%ELEMENT_FIRST(2) .NE. 7_I8 .OR.
     &      GAUSS_LAYOUT%ELEMENT_LAST(2) .NE. 9_I8) THEN
          WRITE(*,'(A)') 'FAIL: ELEMENT GAUSS RANGES'                    ! Print: 'FAIL: ELEMENT GAUSS RANGES'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (ABS(SUM(GAUSS_LAYOUT%REFERENCE_WEIGHT)-5.0_R8)               ! If abs(sum(gauss_layout.reference_weight)-5.0) > 1.0e-13:
     &      .GT. 1.0E-13_R8) THEN
          WRITE(*,'(A)') 'FAIL: COMBINED REFERENCE WEIGHTS'              ! Print: 'FAIL: COMBINED REFERENCE WEIGHTS'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      CALL BUILD_GAUSS_LAYOUT(DOF_ELEMENTS, EXPANSIONS,                  ! Call build gauss layout with dof_elements, expansions, reference_rules, dof_gauss_layout, status.
     &     REFERENCE_RULES, DOF_GAUSS_LAYOUT, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: BUILD DOF GAUSS LAYOUT'                    ! Print: 'FAIL: BUILD DOF GAUSS LAYOUT'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_STRUCTURAL_GEOMETRY_CACHE(NODES, DOF_ELEMENTS,          ! Call build structural geometry cache with nodes, dof_elements, element_frames, reference_rules, structural_...
     &     ELEMENT_FRAMES, REFERENCE_RULES, STRUCTURAL_GEOMETRY,
     &     STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: BUILD STRUCTURAL GEOMETRY CACHE'           ! Print: 'FAIL: BUILD STRUCTURAL GEOMETRY CACHE'.
        WRITE(*,'(A)') TRIM(STATUS%MESSAGE)                              ! Print: trim(status.message).
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_EXPANSION_GEOMETRY_CACHE(EXPANSIONS,                    ! Call build expansion geometry cache with expansions, reference_rules, expansion_geometry, status.
     &     REFERENCE_RULES, EXPANSION_GEOMETRY, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: BUILD EXPANSION GEOMETRY CACHE'            ! Print: 'FAIL: BUILD EXPANSION GEOMETRY CACHE'.
        WRITE(*,'(A)') TRIM(STATUS%MESSAGE)                              ! Print: trim(status.message).
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_COMBINED_GAUSS_GEOMETRY(DOF_ELEMENTS,                   ! Call build combined gauss geometry with dof_elements, expansions, element_frames, dof_gauss_layout, structu...
     &     EXPANSIONS, ELEMENT_FRAMES, DOF_GAUSS_LAYOUT,
     &     STRUCTURAL_GEOMETRY, EXPANSION_GEOMETRY,
     &     COMBINED_GEOMETRY, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        WRITE(*,'(A)') 'FAIL: BUILD COMBINED GAUSS GEOMETRY'             ! Print: 'FAIL: BUILD COMBINED GAUSS GEOMETRY'.
        WRITE(*,'(A)') TRIM(STATUS%MESSAGE)                              ! Print: trim(status.message).
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        IF (STRUCTURAL_GEOMETRY%COUNT .NE. 2_I8 .OR.                     ! If structural_geometry.count /= 2 or expansion_geometry.count /= 13 or combined_geometry.count /= 6:
     &      EXPANSION_GEOMETRY%COUNT .NE. 13_I8 .OR.
     &      COMBINED_GEOMETRY%COUNT .NE. 6_I8) THEN
          WRITE(*,'(A)') 'FAIL: GEOMETRY CACHE COUNTS'                   ! Print: 'FAIL: GEOMETRY CACHE COUNTS'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (ABS(SUM(COMBINED_GEOMETRY%INTEGRATION_WEIGHT)-               ! If abs(sum(combined_geometry.integration_weight)- 0.5) > 1.0e-13:
     &      0.5_R8) .GT. 1.0E-13_R8) THEN
          WRITE(*,'(A)') 'FAIL: PHYSICAL INTEGRATION WEIGHT'             ! Print: 'FAIL: PHYSICAL INTEGRATION WEIGHT'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (MAXVAL(ABS(COMBINED_GEOMETRY%                                ! If maxval(abs(combined_geometry. coordinate_global(1,:))) > 1.0e-14:
     &      COORDINATE_GLOBAL(1,:))) .GT. 1.0E-14_R8) THEN
          WRITE(*,'(A)') 'FAIL: COMBINED PHYSICAL COORDINATE'            ! Print: 'FAIL: COMBINED PHYSICAL COORDINATE'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      CALL BUILD_ISOTROPIC_MATERIAL(7, 73.0E9_R8, 0.3_R8,                ! Call build isotropic material with 7, 73.0e9, 0.3, 2700.0, test_material, status.
     &     2700.0_R8, TEST_MATERIAL, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or test_material.model /= material_isotropic or abs(test_material.stiffness(1,1)- 98.26...
     &    TEST_MATERIAL%MODEL .NE. MATERIAL_ISOTROPIC .OR.
     &    ABS(TEST_MATERIAL%STIFFNESS(1,1)-
     &    98.2692307692308E9_R8) .GT. 1.0E-12_R8*
     &    TEST_MATERIAL%STIFFNESS(1,1)) THEN
        WRITE(*,'(A)') 'FAIL: ISOTROPIC CONSTITUTIVE MATRIX'             ! Print: 'FAIL: ISOTROPIC CONSTITUTIVE MATRIX'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_MATERIAL_ROTATION(31.0_R8, -17.0_R8,                    ! Call build material rotation with 31.0, -17.0, material_rotation.
     &                             MATERIAL_ROTATION)
      CALL ROTATE_STIFFNESS(TEST_MATERIAL%STIFFNESS,                     ! Call rotate stiffness with test_material.stiffness, material_rotation, rotated_stiffness.
     &     MATERIAL_ROTATION, ROTATED_STIFFNESS)
      IF (MAXVAL(ABS(ROTATED_STIFFNESS-                                  ! If maxval(abs(rotated_stiffness- test_material.stiffness)) > 1.0e-11* maxval(abs(test_material.stiffness)):
     &    TEST_MATERIAL%STIFFNESS)) .GT. 1.0E-11_R8*
     &    MAXVAL(ABS(TEST_MATERIAL%STIFFNESS))) THEN
        WRITE(*,'(A)') 'FAIL: ISOTROPIC ROTATION INVARIANCE'             ! Print: 'FAIL: ISOTROPIC ROTATION INVARIANCE'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL BUILD_ORTHOTROPIC_MATERIAL(8, 9.49E9_R8,                      ! Call build orthotropic material with 8, 9.49e9, 153.67e9, 9.49e9, 0.295, 0.295, 0.381, 4.26e9, 4.26e9, 3.44...
     &     153.67E9_R8, 9.49E9_R8, 0.295_R8, 0.295_R8,
     &     0.381_R8, 4.26E9_R8, 4.26E9_R8, 3.44E9_R8,
     &     1528.0_R8, TEST_MATERIAL, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or maxval(abs(test_material.stiffness- transpose(test_material.stiffness))) > 1.0e-5:
     &    MAXVAL(ABS(TEST_MATERIAL%STIFFNESS-
     &    TRANSPOSE(TEST_MATERIAL%STIFFNESS))) .GT. 1.0E-5_R8) THEN
        WRITE(*,'(A)') 'FAIL: ORTHOTROPIC CONSTITUTIVE MATRIX'           ! Print: 'FAIL: ORTHOTROPIC CONSTITUTIVE MATRIX'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      IF (ABS(TEST_MATERIAL%STIFFNESS(4,4)-3.44E9_R8)                    ! If abs(test_material.stiffness(4,4)-3.44e9) > 1.0e-12*3.44e9 or abs(test_material.stiffness(6,6)-4.26e9) > ...
     &    .GT. 1.0E-12_R8*3.44E9_R8 .OR.
     &    ABS(TEST_MATERIAL%STIFFNESS(6,6)-4.26E9_R8)
     &    .GT. 1.0E-12_R8*4.26E9_R8) THEN
        WRITE(*,'(A)') 'FAIL: ORTHOTROPIC SHEAR ORDER'                   ! Print: 'FAIL: ORTHOTROPIC SHEAR ORDER'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL READ_MATERIALS_FILE(                                          ! Call read materials file with 'REFERENCES/BASELINE_INPUTS/101_BEAM_B4_LE/MATERIAL.dat', materials, status.
     & 'REFERENCES/BASELINE_INPUTS/101_BEAM_B4_LE/MATERIAL.dat',
     & MATERIALS, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or size(materials.item) /= 2:
     &    SIZE(MATERIALS%ITEM) .NE. 2) THEN
        WRITE(*,'(A)') 'FAIL: READ LEGACY MATERIALS'                     ! Print: 'FAIL: READ LEGACY MATERIALS'.
        IF (.NOT. STATUS_IS_OK(STATUS))                                  ! If not status is ok, print: trim(status.message).
     &    WRITE(*,'(A)') TRIM(STATUS%MESSAGE)
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL READ_LAMINATIONS_FILE(                                        ! Call read laminations file with 'REFERENCES/BASELINE_INPUTS/101_BEAM_B4_LE/LAMINATION.dat', materials, lami...
     & 'REFERENCES/BASELINE_INPUTS/101_BEAM_B4_LE/LAMINATION.dat',
     & MATERIALS, LAMINATIONS, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or size(laminations.item) /= 2:
     &    SIZE(LAMINATIONS%ITEM) .NE. 2) THEN
        WRITE(*,'(A)') 'FAIL: READ LEGACY LAMINATIONS'                   ! Print: 'FAIL: READ LEGACY LAMINATIONS'.
        IF (.NOT. STATUS_IS_OK(STATUS))                                  ! If not status is ok, print: trim(status.message).
     &    WRITE(*,'(A)') TRIM(STATUS%MESSAGE)
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        CALL RESOLVE_LAMINATION(1, MATERIALS, LAMINATIONS,               ! Call resolve lamination with 1, materials, laminations, resolved_stiffness, resolved_density, material_rota...
     &       RESOLVED_STIFFNESS, RESOLVED_DENSITY,
     &       MATERIAL_ROTATION, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS) .OR.                              ! If not status is ok or abs(resolved_density-2700.0) > 1.0e-12 or maxval(abs(resolved_stiffness- materials.i...
     &      ABS(RESOLVED_DENSITY-2700.0_R8) .GT. 1.0E-12_R8 .OR.
     &      MAXVAL(ABS(RESOLVED_STIFFNESS-
     &      MATERIALS%ITEM(1)%STIFFNESS)) .GT. 1.0E-5_R8) THEN
          WRITE(*,'(A)') 'FAIL: RESOLVE LEGACY LAMINATION'               ! Print: 'FAIL: RESOLVE LEGACY LAMINATION'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      CALL BUILD_GAUSS_MATERIAL_CACHE(DOF_GAUSS_LAYOUT,                  ! Call build gauss material cache with dof_gauss_layout, materials, laminations, material_cache, gauss_materi...
     &     MATERIALS, LAMINATIONS, MATERIAL_CACHE,
     &     GAUSS_MATERIAL_MAP, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or material_cache.count /= 2 or gauss_material_map.count /= 6 or any(gauss_material_map...
     &    MATERIAL_CACHE%COUNT .NE. 2_I4 .OR.
     &    GAUSS_MATERIAL_MAP%COUNT .NE. 6_I8 .OR.
     &    ANY(GAUSS_MATERIAL_MAP%CACHE_INDEX .NE. 1_I4)) THEN
        WRITE(*,'(A)') 'FAIL: GAUSS MATERIAL CACHE'                      ! Print: 'FAIL: GAUSS MATERIAL CACHE'.
        IF (.NOT. STATUS_IS_OK(STATUS))                                  ! If not status is ok, print: trim(status.message).
     &    WRITE(*,'(A)') TRIM(STATUS%MESSAGE)
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      CALL BUILD_LINEAR_ELEMENT_MATRICES(1_I4, NODES,                    ! Call build linear element matrices with 1, nodes, dof_elements, kinematics, expansions, dof_layout, referen...
     &     DOF_ELEMENTS, KINEMATICS, EXPANSIONS, DOF_LAYOUT,
     &     REFERENCE_RULES, DOF_GAUSS_LAYOUT,
     &     STRUCTURAL_GEOMETRY, EXPANSION_GEOMETRY,
     &     COMBINED_GEOMETRY, ELEMENT_FRAMES, MATERIAL_CACHE,
     &     GAUSS_MATERIAL_MAP, ELEMENT_MATRIX, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or element_matrix.local_dof_count /= 15:
     &    ELEMENT_MATRIX%LOCAL_DOF_COUNT .NE. 15_I4) THEN
        WRITE(*,'(A)') 'FAIL: BUILD LINEAR ELEMENT MATRICES'             ! Print: 'FAIL: BUILD LINEAR ELEMENT MATRICES'.
        IF (.NOT. STATUS_IS_OK(STATUS))                                  ! If not status is ok, print: trim(status.message).
     &    WRITE(*,'(A)') TRIM(STATUS%MESSAGE)
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      ELSE                                                               ! Otherwise:
        IF (MAXVAL(ABS(ELEMENT_MATRIX%STIFFNESS-                         ! If maxval(abs(element_matrix.stiffness- transpose(element_matrix.stiffness))) > 1.0e-13*max(1.0,maxval(abs(...
     &      TRANSPOSE(ELEMENT_MATRIX%STIFFNESS))) .GT.
     &      1.0E-13_R8*MAX(1.0_R8,MAXVAL(ABS(
     &      ELEMENT_MATRIX%STIFFNESS)))) THEN
          WRITE(*,'(A)') 'FAIL: ELEMENT STIFFNESS SYMMETRY'              ! Print: 'FAIL: ELEMENT STIFFNESS SYMMETRY'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (MAXVAL(ABS(ELEMENT_MATRIX%MASS-                              ! If maxval(abs(element_matrix.mass- transpose(element_matrix.mass))) > 1.0e-13*max(1.0,maxval(abs( element_m...
     &      TRANSPOSE(ELEMENT_MATRIX%MASS))) .GT.
     &      1.0E-13_R8*MAX(1.0_R8,MAXVAL(ABS(
     &      ELEMENT_MATRIX%MASS)))) THEN
          WRITE(*,'(A)') 'FAIL: ELEMENT MASS SYMMETRY'                   ! Print: 'FAIL: ELEMENT MASS SYMMETRY'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        ALLOCATE(RIGID_VECTOR(ELEMENT_MATRIX%LOCAL_DOF_COUNT))           ! Allocate memory for rigid_vector(element_matrix.local_dof_count).
        RIGID_VECTOR = 0.0_R8                                            ! Set rigid_vector to zero.
        DO I = 1_I4, ELEMENT_MATRIX%LOCAL_DOF_COUNT                      ! Loop i from 1 to element_matrix.local_dof_count:
          IF (ELEMENT_MATRIX%FIELD(I) .NE. 1_I4) CYCLE                   ! If element_matrix.field(i) /= 1, skip to the next iteration.
          IF (ELEMENT_MATRIX%STRUCTURAL_NODE(I) .EQ. 1_I4 .AND.          ! If element_matrix.structural_node(i) = 1 and element_matrix.term(i) = 1:
     &        ELEMENT_MATRIX%TERM(I) .EQ. 1_I4) THEN
            RIGID_VECTOR(I) = 1.0_R8                                     ! Set rigid_vector(i) to 1.0.
          ELSE IF (ELEMENT_MATRIX%STRUCTURAL_NODE(I)                     ! Otherwise, if element_matrix.structural_node(i) = 2:
     &             .EQ. 2_I4) THEN
            RIGID_VECTOR(I) = 1.0_R8                                     ! Set rigid_vector(i) to 1.0.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        RIGID_ENERGY = DOT_PRODUCT(RIGID_VECTOR,                         ! Set rigid_energy to dot_product(rigid_vector, matmul(element_matrix.stiffness,rigid_vector)).
     &    MATMUL(ELEMENT_MATRIX%STIFFNESS,RIGID_VECTOR))
        MASS_ENERGY = DOT_PRODUCT(RIGID_VECTOR,                          ! Set mass_energy to dot_product(rigid_vector, matmul(element_matrix.mass,rigid_vector)).
     &    MATMUL(ELEMENT_MATRIX%MASS,RIGID_VECTOR))
        IF (ABS(RIGID_ENERGY) .GT. 1.0E-10_R8*                           ! If abs(rigid_energy) > 1.0e-10* max(1.0,maxval(abs( element_matrix.stiffness))):
     &      MAX(1.0_R8,MAXVAL(ABS(
     &      ELEMENT_MATRIX%STIFFNESS)))) THEN
          WRITE(*,'(A,ES12.4)')                                          ! Print: 'FAIL: FIELD-DEPENDENT RIGID TRANSLATION ', rigid_energy.
     &      'FAIL: FIELD-DEPENDENT RIGID TRANSLATION ',
     &      RIGID_ENERGY
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (MASS_ENERGY .LE. 0.0_R8) THEN                                ! If mass_energy <= 0.0:
          WRITE(*,'(A)') 'FAIL: POSITIVE ELEMENT MASS ENERGY'            ! Print: 'FAIL: POSITIVE ELEMENT MASS ENERGY'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        DEALLOCATE(RIGID_VECTOR)                                         ! Free the memory of rigid_vector.

        ALLOCATE(ELEMENT_MATRIX_LIST(1))                                 ! Allocate memory for element_matrix_list(1).
        ELEMENT_MATRIX_LIST(1) = ELEMENT_MATRIX                          ! Set element_matrix_list(1) to element_matrix.
        CALL BUILD_AND_ASSEMBLE_SPARSE_SYSTEM(                           ! Call build and assemble sparse system with dof_layout.total_dof, element_matrix_list, sparse_system, status.
     &       DOF_LAYOUT%TOTAL_DOF, ELEMENT_MATRIX_LIST,
     &       SPARSE_SYSTEM, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS) .OR.                              ! If not status is ok or sparse_system.order /= 15 or sparse_system.nonzero_count /= 225 or sparse_system.row...
     &      SPARSE_SYSTEM%ORDER .NE. 15_I8 .OR.
     &      SPARSE_SYSTEM%NONZERO_COUNT .NE. 225_I8 .OR.
     &      SPARSE_SYSTEM%ROW_POINTER(16) .NE. 226_I8 .OR.
     &      .NOT. ALLOCATED(ELEMENT_MATRIX_LIST(1)%
     &                      CSR_POSITION)) THEN
          WRITE(*,'(A)') 'FAIL: BUILD CSR GLOBAL MATRICES'               ! Print: 'FAIL: BUILD CSR GLOBAL MATRICES'.
          IF (.NOT. STATUS_IS_OK(STATUS))                                ! If not status is ok, print: trim(status.message).
     &      WRITE(*,'(A)') TRIM(STATUS%MESSAGE)
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        ELSE                                                             ! Otherwise:
          DO J = 1_I4, ELEMENT_MATRIX%LOCAL_DOF_COUNT                    ! Loop j from 1 to element_matrix.local_dof_count:
            DO I = 1_I4, ELEMENT_MATRIX%LOCAL_DOF_COUNT                  ! Loop i from 1 to element_matrix.local_dof_count:
              SPARSE_POSITION = SPARSE_SYSTEM%ROW_POINTER(               ! Set sparse_position to sparse_system.row_pointer( element_matrix.global_dof(i))+ element_matrix.global_dof(...
     &          ELEMENT_MATRIX%GLOBAL_DOF(I))+
     &          ELEMENT_MATRIX%GLOBAL_DOF(J)-1_I8
              IF (ABS(SPARSE_SYSTEM%STIFFNESS(SPARSE_POSITION)-          ! If abs(sparse_system.stiffness(sparse_position)- element_matrix.stiffness(i,j)) > 1.0e-13*max(1.0,abs( elem...
     &          ELEMENT_MATRIX%STIFFNESS(I,J)) .GT.
     &          1.0E-13_R8*MAX(1.0_R8,ABS(
     &          ELEMENT_MATRIX%STIFFNESS(I,J))) .OR.
     &          ABS(SPARSE_SYSTEM%MASS(SPARSE_POSITION)-
     &          ELEMENT_MATRIX%MASS(I,J)) .GT.
     &          1.0E-13_R8*MAX(1.0_R8,ABS(
     &          ELEMENT_MATRIX%MASS(I,J)))) THEN
                WRITE(*,'(A)') 'FAIL: CSR MATRIX ASSEMBLY'               ! Print: 'FAIL: CSR MATRIX ASSEMBLY'.
                FAILURES = FAILURES + 1_I8                               ! Add 1 to failures.
                EXIT                                                     ! Leave the loop.
              END IF                                                     ! End of the IF block.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END IF                                                           ! End of the IF block.

        CALL READ_BOUNDARY_CONDITIONS_FILE(                              ! Call read boundary conditions file with 'TESTS/DATA/BC_MECHANICAL_VALID.dat', boundaries, status.
     &       'TESTS/DATA/BC_MECHANICAL_VALID.dat',
     &       BOUNDARIES, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS) .OR.                              ! If not status is ok or size(boundaries.item) /= 2 or boundaries.item(1).kind /= bc_displacement_plane or bo...
     &      SIZE(BOUNDARIES%ITEM) .NE. 2_I4 .OR.
     &      BOUNDARIES%ITEM(1)%KIND .NE.
     &      BC_DISPLACEMENT_PLANE .OR.
     &      BOUNDARIES%ITEM(2)%KIND .NE. BC_FORCE_POINT) THEN
          WRITE(*,'(A)') 'FAIL: READ MECHANICAL BOUNDARIES'              ! Print: 'FAIL: READ MECHANICAL BOUNDARIES'.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        ELSE                                                             ! Otherwise:
          CALL BUILD_MECHANICAL_BOUNDARY_DATA(BOUNDARIES,                ! Call build mechanical boundary data with boundaries, nodes, dof_elements, kinematics, expansions, element_f...
     &         NODES, DOF_ELEMENTS, KINEMATICS, EXPANSIONS,
     &         ELEMENT_FRAMES, DOF_LAYOUT, 1.0E-10_R8,
     &         CONSTRAINTS, GLOBAL_FORCE, STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS) .OR.                            ! If not status is ok or constraints.count /= 9 or abs(constraints.value(1)-0.25) > 1.0e-13 or abs(global_for...
     &        CONSTRAINTS%COUNT .NE. 9_I8 .OR.
     &        ABS(CONSTRAINTS%VALUE(1)-0.25_R8) .GT.
     &        1.0E-13_R8 .OR.
     &        ABS(GLOBAL_FORCE(10)-100.0_R8) .GT.
     &        1.0E-13_R8 .OR.
     &        COUNT(ABS(GLOBAL_FORCE) .GT. 0.0_R8) .NE. 1_I4) THEN
            WRITE(*,'(A)') 'FAIL: RESOLVE MECHANICAL BOUNDARIES'         ! Print: 'FAIL: RESOLVE MECHANICAL BOUNDARIES'.
            IF (.NOT. STATUS_IS_OK(STATUS))                              ! If not status is ok, print: trim(status.message).
     &        WRITE(*,'(A)') TRIM(STATUS%MESSAGE)
            FAILURES = FAILURES + 1_I8                                   ! Add 1 to failures.
          ELSE                                                           ! Otherwise:
            CONSTRAINED_SYSTEM = SPARSE_SYSTEM                           ! Set constrained_system to sparse_system.
            CALL APPLY_STATIC_CONSTRAINTS(CONSTRAINED_SYSTEM,            ! Call apply static constraints with constrained_system, global_force, constraints, status.
     &           GLOBAL_FORCE, CONSTRAINTS, STATUS)
            IF (.NOT. STATUS_IS_OK(STATUS)) THEN                         ! If not status is ok:
              WRITE(*,'(A)') 'FAIL: APPLY STATIC CONSTRAINTS'            ! Print: 'FAIL: APPLY STATIC CONSTRAINTS'.
              FAILURES = FAILURES + 1_I8                                 ! Add 1 to failures.
            ELSE                                                         ! Otherwise:
              DO SPARSE_ROW = 1_I8, CONSTRAINED_SYSTEM%ORDER             ! Loop sparse_row from 1 to constrained_system.order:
                DO SPARSE_POSITION = CONSTRAINED_SYSTEM%                 ! Loop sparse_position from constrained_system. row_pointer(sparse_row) to constrained_system. row_pointer(sp...
     &            ROW_POINTER(SPARSE_ROW), CONSTRAINED_SYSTEM%
     &            ROW_POINTER(SPARSE_ROW+1_I8)-1_I8
                  SPARSE_COLUMN = CONSTRAINED_SYSTEM%                    ! Set sparse_column to constrained_system. column_index(sparse_position).
     &                            COLUMN_INDEX(SPARSE_POSITION)
                  IF (CONSTRAINTS%ACTIVE(SPARSE_ROW) .OR.                ! If constraints.active(sparse_row) or constraints.active(sparse_column):
     &                CONSTRAINTS%ACTIVE(SPARSE_COLUMN)) THEN
                    IF (SPARSE_ROW .EQ. SPARSE_COLUMN .AND.              ! If sparse_row = sparse_column and constraints.active(sparse_row):
     &                  CONSTRAINTS%ACTIVE(SPARSE_ROW)) THEN
                      IF (CONSTRAINED_SYSTEM%STIFFNESS(                  ! If constrained_system.stiffness( sparse_position) /= 1.0, add 1 to failures.
     &                    SPARSE_POSITION) .NE. 1.0_R8)
     &                  FAILURES = FAILURES+1_I8
                    ELSE IF (CONSTRAINED_SYSTEM%STIFFNESS(               ! Otherwise, if constrained_system.stiffness( sparse_position) /= 0.0:
     &                       SPARSE_POSITION) .NE. 0.0_R8) THEN
                      FAILURES = FAILURES+1_I8                           ! Add 1 to failures.
                    END IF                                               ! End of the IF block.
                  END IF                                                 ! End of the IF block.
                END DO                                                   ! End of the loop.
                IF (CONSTRAINTS%ACTIVE(SPARSE_ROW) .AND.                 ! If constraints.active(sparse_row) and abs(global_force(sparse_row)- constraints.value(sparse_row)) > 1.0e-1...
     &              ABS(GLOBAL_FORCE(SPARSE_ROW)-
     &              CONSTRAINTS%VALUE(SPARSE_ROW)) .GT.
     &              1.0E-13_R8) FAILURES = FAILURES+1_I8
              END DO                                                     ! End of the loop.
              SPARSE_POSITION = SPARSE_SYSTEM%ROW_POINTER(10_I8)         ! Set sparse_position to sparse_system.row_pointer(10).
              IF (ABS(GLOBAL_FORCE(10)-(100.0_R8-                        ! If abs(global_force(10)-(100.0- 0.25*sparse_system.stiffness( sparse_position))) > 1.0e-10* max(1.0,abs(glo...
     &            0.25_R8*SPARSE_SYSTEM%STIFFNESS(
     &            SPARSE_POSITION))) .GT. 1.0E-10_R8*
     &            MAX(1.0_R8,ABS(GLOBAL_FORCE(10)))) THEN
                WRITE(*,'(A)') 'FAIL: STATIC LOAD AFTER BC'              ! Print: 'FAIL: STATIC LOAD AFTER BC'.
                FAILURES = FAILURES+1_I8                                 ! Add 1 to failures.
              END IF                                                     ! End of the IF block.
            END IF                                                       ! End of the IF block.
          END IF                                                         ! End of the IF block.
        END IF                                                           ! End of the IF block.
        DEALLOCATE(ELEMENT_MATRIX_LIST)                                  ! Free the memory of element_matrix_list.
      END IF                                                             ! End of the IF block.

      CALL COMPOSE_PRODUCT_BASIS(0.5_R8,                                 ! Call compose product basis with 0.5, [0.0, 2.0, 0.0], 0.25, [3.0, 0.0, 4.0], basis_value, basis_gradient.
     &     [0.0_R8,2.0_R8,0.0_R8], 0.25_R8,
     &     [3.0_R8,0.0_R8,4.0_R8], BASIS_VALUE,
     &     BASIS_GRADIENT)
      IF (ABS(BASIS_VALUE-0.125_R8) .GT. 1.0E-14_R8 .OR.                 ! If abs(basis_value-0.125) > 1.0e-14 or maxval(abs(basis_gradient- [1.5,0.5,2.0])) > 1.0e-14:
     &    MAXVAL(ABS(BASIS_GRADIENT-
     &    [1.5_R8,0.5_R8,2.0_R8])) .GT. 1.0E-14_R8) THEN
        WRITE(*,'(A)') 'FAIL: CUF PRODUCT BASIS GRADIENT'                ! Print: 'FAIL: CUF PRODUCT BASIS GRADIENT'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      IF (TAYLOR_BASIS_TERM_COUNT(3,2) .NE. 10_I4 .OR.                   ! If taylor_basis_term_count(3,2) /= 10 or taylor_basis_term_count(3,1) /= 4:
     &    TAYLOR_BASIS_TERM_COUNT(3,1) .NE. 4_I4) THEN
        WRITE(*,'(A)') 'FAIL: TAYLOR TERM COUNT'                         ! Print: 'FAIL: TAYLOR TERM COUNT'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL EVALUATE_TAYLOR_BASIS(3, 2, [1_I4,3_I4],                      ! Call evaluate taylor basis with 3, 2, [1, 3], [2.0, 0.0, 3.0], taylor_value, taylor_gradient, status.
     &     [2.0_R8,0.0_R8,3.0_R8], TAYLOR_VALUE,
     &     TAYLOR_GRADIENT, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or maxval(abs(taylor_value- [1.0,2.0,3.0,4.0,6.0, 9.0,8.0,12.0,18.0,27.0])) > 1.0e-14 o...
     &    MAXVAL(ABS(TAYLOR_VALUE-
     &    [1.0_R8,2.0_R8,3.0_R8,4.0_R8,6.0_R8,
     &     9.0_R8,8.0_R8,12.0_R8,18.0_R8,27.0_R8]))
     &    .GT. 1.0E-14_R8 .OR.
     &    ABS(TAYLOR_GRADIENT(1,8)-12.0_R8)
     &    .GT. 1.0E-14_R8 .OR.
     &    ABS(TAYLOR_GRADIENT(3,8)-4.0_R8)
     &    .GT. 1.0E-14_R8) THEN
        WRITE(*,'(A)') 'FAIL: AUTHORITATIVE TAYLOR BASIS ORDER'          ! Print: 'FAIL: AUTHORITATIVE TAYLOR BASIS ORDER'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      BASIS_VALUE_SUM = 0.0_R8                                           ! Set basis_value_sum to zero.
      BASIS_GRADIENT_SUM = 0.0_R8                                        ! Set basis_gradient_sum to zero.
      DO I = 1_I4, 3_I4                                                  ! Loop i from 1 to 3:
        CALL EVALUATE_POINT_BASIS(1_I8, 1_I4, I,                         ! Call evaluate point basis with 1, 1, i, kinematics.item(2).field(1), dof_elements, expansions, reference_ru...
     &       KINEMATICS%ITEM(2)%FIELD(1), DOF_ELEMENTS,
     &       EXPANSIONS, REFERENCE_RULES, DOF_GAUSS_LAYOUT,
     &       STRUCTURAL_GEOMETRY, EXPANSION_GEOMETRY,
     &       COMBINED_GEOMETRY, POINT_BASIS_VALUE,
     &       POINT_BASIS_GRADIENT, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        BASIS_VALUE_SUM = BASIS_VALUE_SUM + POINT_BASIS_VALUE            ! Add point_basis_value to basis_value_sum.
        BASIS_GRADIENT_SUM = BASIS_GRADIENT_SUM +                        ! Add point_basis_gradient to basis_gradient_sum.
     &                       POINT_BASIS_GRADIENT
      END DO                                                             ! End of the loop.
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or abs(basis_value_sum-reference_rules.item( dof_gauss_layout.structural_rule_index(1))...
     &    ABS(BASIS_VALUE_SUM-REFERENCE_RULES%ITEM(
     &    DOF_GAUSS_LAYOUT%STRUCTURAL_RULE_INDEX(1))%SHAPE(1,
     &    DOF_GAUSS_LAYOUT%STRUCTURAL_POINT_INDEX(1)))
     &    .GT. 1.0E-13_R8 .OR.
     &    MAXVAL(ABS(BASIS_GRADIENT_SUM-
     &    STRUCTURAL_GEOMETRY%DERIVATIVE_LOCAL(:,
     &    STRUCTURAL_GEOMETRY%DERIVATIVE_OFFSET(
     &    COMBINED_GEOMETRY%STRUCTURAL_CACHE_INDEX(1)))))
     &    .GT. 1.0E-13_R8) THEN
        WRITE(*,'(A)') 'FAIL: LE POINT BASIS PARTITION'                  ! Print: 'FAIL: LE POINT BASIS PARTITION'.
        IF (.NOT. STATUS_IS_OK(STATUS))                                  ! If not status is ok, print: trim(status.message).
     &    WRITE(*,'(A)') TRIM(STATUS%MESSAGE)
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      TEST_GRADIENT = [2.0_R8,3.0_R8,4.0_R8]                             ! Set test_gradient to [2.0,3.0,4.0].
      TRIAL_GRADIENT = [-1.0_R8,0.5_R8,2.5_R8]                           ! Set trial_gradient to [-1.0,0.5,2.5].
      CALL BUILD_DISPLACEMENT_OPERATOR(TEST_GRADIENT,                    ! Call build displacement operator with test_gradient, test_operator, status.
     &     TEST_OPERATOR, STATUS)
      CALL BUILD_DISPLACEMENT_OPERATOR(TRIAL_GRADIENT,                   ! Call build displacement operator with trial_gradient, trial_operator, status.
     &     TRIAL_OPERATOR, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS) .OR.                                ! If not status is ok or maxval(abs(test_operator(:,1)- [2.0,0.0,0.0,4.0,0.0,3.0])) > 1.0e-14 or maxval(abs(t...
     &    MAXVAL(ABS(TEST_OPERATOR(:,1)-
     &    [2.0_R8,0.0_R8,0.0_R8,4.0_R8,0.0_R8,3.0_R8]))
     &    .GT. 1.0E-14_R8 .OR.
     &    MAXVAL(ABS(TEST_OPERATOR(:,3)-
     &    [0.0_R8,0.0_R8,4.0_R8,2.0_R8,3.0_R8,0.0_R8]))
     &    .GT. 1.0E-14_R8) THEN
        WRITE(*,'(A)') 'FAIL: LINEAR STRAIN OPERATOR'                    ! Print: 'FAIL: LINEAR STRAIN OPERATOR'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL STIFFNESS_BLOCK_NUCLEUS(TEST_OPERATOR,                        ! Call stiffness block nucleus with test_operator, materials.item(1).stiffness, trial_operator, 0.75, stiffne...
     &     MATERIALS%ITEM(1)%STIFFNESS, TRIAL_OPERATOR,
     &     0.75_R8, STIFFNESS_BLOCK)
      CALL STIFFNESS_BLOCK_NUCLEUS(TRIAL_OPERATOR,                       ! Call stiffness block nucleus with trial_operator, materials.item(1).stiffness, test_operator, 0.75, reverse...
     &     MATERIALS%ITEM(1)%STIFFNESS, TEST_OPERATOR,
     &     0.75_R8, REVERSE_BLOCK)
      IF (MAXVAL(ABS(STIFFNESS_BLOCK-TRANSPOSE(REVERSE_BLOCK)))          ! If maxval(abs(stiffness_block-transpose(reverse_block))) > 1.0e-12*maxval(abs(stiffness_block)):
     &    .GT. 1.0E-12_R8*MAXVAL(ABS(STIFFNESS_BLOCK))) THEN
        WRITE(*,'(A)') 'FAIL: FUNDAMENTAL NUCLEUS RECIPROCITY'           ! Print: 'FAIL: FUNDAMENTAL NUCLEUS RECIPROCITY'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL BUILD_DISPLACEMENT_COLUMN(1, TEST_GRADIENT,                   ! Call build displacement column with 1, test_gradient, test_column, status.
     &     TEST_COLUMN, STATUS)
      CALL BUILD_DISPLACEMENT_COLUMN(2, TRIAL_GRADIENT,                  ! Call build displacement column with 2, trial_gradient, trial_column, status.
     &     TRIAL_COLUMN, STATUS)
      SCALAR_NUCLEUS = STIFFNESS_NUCLEUS(TEST_COLUMN,                    ! Set scalar_nucleus to stiffness_nucleus(test_column, materials.item(1).stiffness, trial_column, 0.75).
     &     MATERIALS%ITEM(1)%STIFFNESS, TRIAL_COLUMN, 0.75_R8)
      IF (ABS(SCALAR_NUCLEUS-STIFFNESS_BLOCK(1,2))                       ! If abs(scalar_nucleus-stiffness_block(1,2)) > 1.0e-12*max(1.0, abs(scalar_nucleus)):
     &    .GT. 1.0E-12_R8*MAX(1.0_R8,
     &    ABS(SCALAR_NUCLEUS))) THEN
        WRITE(*,'(A)') 'FAIL: FIELD-DEPENDENT SCALAR NUCLEUS'            ! Print: 'FAIL: FIELD-DEPENDENT SCALAR NUCLEUS'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      CALL MASS_BLOCK_NUCLEUS(0.2_R8, 0.4_R8, 2700.0_R8,                 ! Call mass block nucleus with 0.2, 0.4, 2700.0, 0.5, mass_block.
     &     0.5_R8, MASS_BLOCK)
      IF (ABS(MASS_BLOCK(1,1)-108.0_R8) .GT. 1.0E-13_R8 .OR.             ! If abs(mass_block(1,1)-108.0) > 1.0e-13 or abs(mass_block(2,2)-108.0) > 1.0e-13 or mass_nucleus(1,2,0.2,0.4...
     &    ABS(MASS_BLOCK(2,2)-108.0_R8) .GT. 1.0E-13_R8 .OR.
     &    MASS_NUCLEUS(1,2,0.2_R8,0.4_R8,2700.0_R8,
     &    0.5_R8) .NE. 0.0_R8) THEN
        WRITE(*,'(A)') 'FAIL: MASS FUNDAMENTAL NUCLEUS'                  ! Print: 'FAIL: MASS FUNDAMENTAL NUCLEUS'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      STIFFNESS_BLOCK = 0.0_R8                                           ! Set stiffness_block to zero.
      STIFFNESS_BLOCK(1,1) = 1.0_R8                                      ! Set stiffness_block(1,1) to 1.0.
      STIFFNESS_BLOCK(2,2) = 2.0_R8                                      ! Set stiffness_block(2,2) to 2.0.
      STIFFNESS_BLOCK(3,3) = 3.0_R8                                      ! Set stiffness_block(3,3) to 3.0.
      CALL BUILD_MATERIAL_ROTATION(0.0_R8, 90.0_R8,                      ! Call build material rotation with 0.0, 90.0, material_rotation.
     &                             MATERIAL_ROTATION)
      CALL ROTATE_BLOCK_TO_GLOBAL(STIFFNESS_BLOCK,                       ! Call rotate block to global with stiffness_block, material_rotation, reverse_block.
     &     MATERIAL_ROTATION, REVERSE_BLOCK)
      IF (ABS(REVERSE_BLOCK(1,1)-2.0_R8) .GT. 1.0E-14_R8 .OR.            ! If abs(reverse_block(1,1)-2.0) > 1.0e-14 or abs(reverse_block(2,2)-1.0) > 1.0e-14 or abs(reverse_block(3,3)...
     &    ABS(REVERSE_BLOCK(2,2)-1.0_R8) .GT. 1.0E-14_R8 .OR.
     &    ABS(REVERSE_BLOCK(3,3)-3.0_R8) .GT. 1.0E-14_R8) THEN
        WRITE(*,'(A)') 'FAIL: LOCAL NUCLEUS TO GLOBAL ROTATION'          ! Print: 'FAIL: LOCAL NUCLEUS TO GLOBAL ROTATION'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      IF (FAILURES .NE. 0_I8) THEN                                       ! If failures /= 0:
        WRITE(*,'(A,I0)') 'MUL2_TESTS FAILED: ', FAILURES                ! Print: 'MUL2_TESTS FAILED: ', failures.
        ERROR STOP 1                                                     ! Stop the program with an error.
      END IF                                                             ! End of the IF block.

      WRITE(*,'(A)') 'MUL2_TESTS PASSED'                                 ! Print: 'MUL2_TESTS PASSED'.

      END PROGRAM MUL2_TESTS                                             ! End of the program mul2 tests.
