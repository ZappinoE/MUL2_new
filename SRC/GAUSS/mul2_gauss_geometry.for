!=======================================================================
!  ELEMENT-DEPENDENT GEOMETRY CACHES FOR COMBINED GAUSS POINTS.
!=======================================================================
      MODULE MUL2_GAUSS_GEOMETRY                                         ! Module mul2 gauss geometry begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       SET_ERROR, STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, FIND_NODE_INDEX                ! Use from module mul2 nodes: node db type, find node index.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE,                ! Use from module mul2 expansion meshes: expansion db type, find expansion index.
     &                                 FIND_EXPANSION_INDEX
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION,             ! Use from module mul2 topologies: topology natural dimension, topology function count, topology is hle, topo...
     &                           TOPOLOGY_FUNCTION_COUNT,
     &                           TOPOLOGY_IS_HLE, TOPOLOGY_HQ_BASE
      USE MUL2_HLE_MAP, ONLY: HLE_GEOMETRY_TYPE, HLE_GEOMETRY_SETUP,     ! Use from module mul2 hle map: hle geometry type, hle geometry setup, hle map evaluate.
     &                        HLE_MAP_EVALUATE
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type, find reference rule, find str...
     &                             GAUSS_LAYOUT_TYPE,
     &                             FIND_REFERENCE_RULE,
     &                             FIND_STRUCTURAL_RULE,
     &                             EXPANSION_MESH_ORDER
      USE MUL2_JACOBIANS, ONLY: EVALUATE_SQUARE_JACOBIAN                 ! Use from module mul2 jacobians: evaluate square jacobian.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: STRUCTURAL_GEOMETRY_CACHE_TYPE                     ! Definition of the derived type structural geometry cache type.
        INTEGER(I8) :: COUNT = 0_I8                                      ! Integer (int64): count = 0.
        INTEGER(I8), ALLOCATABLE :: ELEMENT_FIRST(:)                     ! Allocatable integer (int64): element_first(:).
        INTEGER(I8), ALLOCATABLE :: ELEMENT_LAST(:)                      ! Allocatable integer (int64): element_last(:).
        REAL(R8), ALLOCATABLE :: CENTER_GLOBAL(:,:)                      ! Allocatable real (real64): center_global(:,:).
        REAL(R8), ALLOCATABLE :: JACOBIAN(:,:,:)                         ! Allocatable real (real64): jacobian(:,:,:).
        REAL(R8), ALLOCATABLE :: INVERSE_JACOBIAN(:,:,:)                 ! Allocatable real (real64): inverse_jacobian(:,:,:).
        REAL(R8), ALLOCATABLE :: DETERMINANT(:)                          ! Allocatable real (real64): determinant(:).
        INTEGER(I8), ALLOCATABLE :: DERIVATIVE_OFFSET(:)                 ! Allocatable integer (int64): derivative_offset(:).
        REAL(R8), ALLOCATABLE :: DERIVATIVE_LOCAL(:,:)                   ! Allocatable real (real64): derivative_local(:,:).
      END TYPE STRUCTURAL_GEOMETRY_CACHE_TYPE                            ! End of the type definition structural geometry cache type.

      TYPE, PUBLIC :: EXPANSION_GEOMETRY_CACHE_TYPE                      ! Definition of the derived type expansion geometry cache type.
        INTEGER(I8) :: COUNT = 0_I8                                      ! Integer (int64): count = 0.
        INTEGER(I4), ALLOCATABLE :: ACTIVE_AXIS(:,:)                     ! Allocatable integer (int32): active_axis(:,:).
        INTEGER(I4), ALLOCATABLE :: MESH_ELEMENT_BASE(:)                 ! Allocatable integer (int32): mesh_element_base(:).
        INTEGER(I8), ALLOCATABLE :: ELEMENT_FIRST(:)                     ! Allocatable integer (int64): element_first(:).
        INTEGER(I8), ALLOCATABLE :: ELEMENT_LAST(:)                      ! Allocatable integer (int64): element_last(:).
        REAL(R8), ALLOCATABLE :: COORDINATE_LOCAL(:,:)                   ! Allocatable real (real64): coordinate_local(:,:).
        REAL(R8), ALLOCATABLE :: JACOBIAN(:,:,:)                         ! Allocatable real (real64): jacobian(:,:,:).
        REAL(R8), ALLOCATABLE :: INVERSE_JACOBIAN(:,:,:)                 ! Allocatable real (real64): inverse_jacobian(:,:,:).
        REAL(R8), ALLOCATABLE :: DETERMINANT(:)                          ! Allocatable real (real64): determinant(:).
        INTEGER(I8), ALLOCATABLE :: DERIVATIVE_OFFSET(:)                 ! Allocatable integer (int64): derivative_offset(:).
        REAL(R8), ALLOCATABLE :: DERIVATIVE_LOCAL(:,:)                   ! Allocatable real (real64): derivative_local(:,:).
      END TYPE EXPANSION_GEOMETRY_CACHE_TYPE                             ! End of the type definition expansion geometry cache type.

      TYPE, PUBLIC :: GAUSS_GEOMETRY_TYPE                                ! Definition of the derived type gauss geometry type.
        INTEGER(I8) :: COUNT = 0_I8                                      ! Integer (int64): count = 0.
        INTEGER(I8), ALLOCATABLE :: STRUCTURAL_CACHE_INDEX(:)            ! Allocatable integer (int64): structural_cache_index(:).
        INTEGER(I8), ALLOCATABLE :: EXPANSION_CACHE_INDEX(:)             ! Allocatable integer (int64): expansion_cache_index(:).
        REAL(R8), ALLOCATABLE :: COORDINATE_GLOBAL(:,:)                  ! Allocatable real (real64): coordinate_global(:,:).
        REAL(R8), ALLOCATABLE :: INTEGRATION_WEIGHT(:)                   ! Allocatable real (real64): integration_weight(:).
      END TYPE GAUSS_GEOMETRY_TYPE                                       ! End of the type definition gauss geometry type.

      PUBLIC :: BUILD_STRUCTURAL_GEOMETRY_CACHE                          ! Export: build structural geometry cache.
      PUBLIC :: BUILD_EXPANSION_GEOMETRY_CACHE                           ! Export: build expansion geometry cache.
      PUBLIC :: BUILD_COMBINED_GAUSS_GEOMETRY                            ! Export: build combined gauss geometry.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_STRUCTURAL_GEOMETRY_CACHE(NODES, ELEMENTS,        ! Subroutine build structural geometry cache takes nodes, elements, frames, rules, cache, status, reduced.
     &     FRAMES, RULES, CACHE, STATUS, REDUCED)

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(INOUT) :: CACHE       ! In/out of type structural_geometry_cache_type: cache.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      LOGICAL, INTENT(IN), OPTIONAL :: REDUCED                           ! Input optional logical: reduced.
      LOGICAL :: USE_REDUCED                                             ! Logical: use_reduced.
      REAL(R8) :: GLOBAL_COORDINATE(27,3)                                ! Real (real64): global_coordinate(27,3).
      REAL(R8) :: LOCAL_COORDINATE(27,3)                                 ! Real (real64): local_coordinate(27,3).
      REAL(R8) :: ACTIVE_COORDINATE(27,3)                                ! Real (real64): active_coordinate(27,3).
      REAL(R8) :: DN_PHYSICAL(27,3)                                      ! Real (real64): dn_physical(27,3).
      REAL(R8) :: JACOBIAN(3,3)                                          ! Real (real64): jacobian(3,3).
      REAL(R8) :: INVERSE(3,3)                                           ! Real (real64): inverse(3,3).
      REAL(R8) :: DETERMINANT                                            ! Real (real64): determinant.
      REAL(R8) :: DELTA(3)                                               ! Real (real64): delta(3).
      INTEGER(I8) :: TOTAL_POINT                                         ! Integer (int64): total_point.
      INTEGER(I8) :: TOTAL_ENTRY                                         ! Integer (int64): total_entry.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I8) :: ENTRY                                               ! Integer (int64): entry.
      INTEGER(I4) :: RULE_INDEX                                          ! Integer (int32): rule_index.
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: N_POINT                                             ! Integer (int32): n_point.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: AXIS(3)                                             ! Integer (int32): axis(3).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: P                                                   ! Integer (int32): p.
      INTEGER(I4) :: II                                                  ! Integer (int32): ii.
      LOGICAL :: GENERAL_ELEMENT                                         ! Logical: general_element.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_STRUCTURAL_CACHE(CACHE)                                 ! Call clear structural cache with cache.
      USE_REDUCED = .FALSE.                                              ! Set the flag use_reduced to false.
      IF (PRESENT(REDUCED)) USE_REDUCED = REDUCED                        ! If present(reduced), set use_reduced to reduced.
      IF (.NOT. ALLOCATED(FRAMES%GLOBAL_TO_LOCAL)) THEN                  ! If not allocated(frames.global_to_local):
        CALL SET_ERROR(STATUS, 'BUILD_STRUCTURAL_GEOMETRY_CACHE',        ! Record an error in status: 'ELEMENT FRAMES ARE NOT AVAILABLE'.
     &                 'ELEMENT FRAMES ARE NOT AVAILABLE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      TOTAL_POINT = 0_I8                                                 ! Set total_point to zero.
      TOTAL_ENTRY = 0_I8                                                 ! Set total_entry to zero.
      DO I = 1_I4, SIZE(ELEMENTS%ITEM)                                   ! Loop i from 1 to size(elements.item):
        RULE_INDEX = FIND_STRUCTURAL_RULE(RULES,                         ! Set rule_index to find_structural_rule(rules, elements.item(i).topology, use_reduced).
     &               ELEMENTS%ITEM(I)%TOPOLOGY, USE_REDUCED)
        IF (RULE_INDEX .EQ. 0_I4) THEN                                   ! If rule_index = 0:
          CALL SET_ERROR(STATUS, 'BUILD_STRUCTURAL_GEOMETRY_CACHE',      ! Record an error in status: 'STRUCTURAL REFERENCE RULE IS MISSING'.
     &                   'STRUCTURAL REFERENCE RULE IS MISSING')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        N_POINT = SIZE(RULES%ITEM(RULE_INDEX)%WEIGHT)                    ! Set n_point to the size of rules.item(rule_index).weight.
        N_NODE = SIZE(ELEMENTS%ITEM(I)%NODE_ID)                          ! Set n_node to the size of elements.item(i).node_id.
        TOTAL_POINT = TOTAL_POINT + INT(N_POINT,I8)                      ! Add int(n_point,i8) to total_point.
        TOTAL_ENTRY = TOTAL_ENTRY + INT(N_POINT*N_NODE,I8)               ! Add int(n_point*n_node,i8) to total_entry.
      END DO                                                             ! End of the loop.
      CALL ALLOCATE_STRUCTURAL_CACHE(CACHE,                              ! Call allocate structural cache with cache, size(elements.item), total_point, total_entry.
     &     SIZE(ELEMENTS%ITEM), TOTAL_POINT, TOTAL_ENTRY)

      POINT = 0_I8                                                       ! Set point to zero.
      ENTRY = 0_I8                                                       ! Set entry to zero.
      DO I = 1_I4, SIZE(ELEMENTS%ITEM)                                   ! Loop i from 1 to size(elements.item):
        RULE_INDEX = FIND_STRUCTURAL_RULE(RULES,                         ! Set rule_index to find_structural_rule(rules, elements.item(i).topology, use_reduced).
     &               ELEMENTS%ITEM(I)%TOPOLOGY, USE_REDUCED)
        DIMENSION = RULES%ITEM(RULE_INDEX)%NATURAL_DIMENSION             ! Set dimension to rules.item(rule_index).natural_dimension.
        N_NODE = SIZE(ELEMENTS%ITEM(I)%NODE_ID)                          ! Set n_node to the size of elements.item(i).node_id.
        N_POINT = SIZE(RULES%ITEM(RULE_INDEX)%WEIGHT)                    ! Set n_point to the size of rules.item(rule_index).weight.
        CALL STRUCTURAL_ACTIVE_AXES(DIMENSION, AXIS)                     ! Call structural active axes with dimension, axis.
        GLOBAL_COORDINATE = 0.0_R8                                       ! Set global_coordinate to zero.
        LOCAL_COORDINATE = 0.0_R8                                        ! Set local_coordinate to zero.
        DO J = 1_I4, N_NODE                                              ! Loop j from 1 to n_node:
          NODE_INDEX = FIND_NODE_INDEX(NODES,                            ! Set node_index to find_node_index(nodes, elements.item(i).node_id(j)).
     &                 ELEMENTS%ITEM(I)%NODE_ID(J))
          IF (NODE_INDEX .EQ. 0_I4) THEN                                 ! If node_index = 0:
            CALL SET_ERROR(STATUS,                                       ! Record an error in status: 'STRUCTURAL NODE IS MISSING'.
     &                     'BUILD_STRUCTURAL_GEOMETRY_CACHE',
     &                     'STRUCTURAL NODE IS MISSING')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          GLOBAL_COORDINATE(J,:) =                                       ! Set global_coordinate(j,:) to nodes.item(node_index).coordinate.
     &      NODES%ITEM(NODE_INDEX)%COORDINATE
          DELTA = GLOBAL_COORDINATE(J,:)-FRAMES%ORIGIN(:,I)              ! Set delta to global_coordinate(j,:)-frames.origin(:,i).
          LOCAL_COORDINATE(J,:) = MATMUL(                                ! Set local_coordinate(j,:) to matmul( frames.global_to_local(:,:,i),delta).
     &      FRAMES%GLOBAL_TO_LOCAL(:,:,I),DELTA)
        END DO                                                           ! End of the loop.
        ACTIVE_COORDINATE = 0.0_R8                                       ! Set active_coordinate to zero.
        DO J = 1_I4, DIMENSION                                           ! Loop j from 1 to dimension:
          ACTIVE_COORDINATE(1:N_NODE,J) =                                ! Set active_coordinate(1:n_node,j) to local_coordinate(1:n_node,axis(j)).
     &      LOCAL_COORDINATE(1:N_NODE,AXIS(J))
        END DO                                                           ! End of the loop.
        CACHE%ELEMENT_FIRST(I) = POINT + 1_I8                            ! Set cache.element_first(i) to point + 1.
!       A CURVED BEAM / SHELL HAS ITS OWN GEOMETRY (MUL2_GENERAL_GEOMETRY):
!       THE CHORD / TANGENT-PLANE FRAME OF THIS CACHE IS NOT USED.
        GENERAL_ELEMENT = .FALSE.                                        ! Set the flag general_element to false.
        IF (ALLOCATED(FRAMES%GENERAL_INDEX))                             ! If allocated(frames.general_index), set general_element to frames.general_index(i) > 0.
     &    GENERAL_ELEMENT = FRAMES%GENERAL_INDEX(I) .GT. 0_I4
        DO P = 1_I4, N_POINT                                             ! Loop p from 1 to n_point:
          POINT = POINT + 1_I8                                           ! Add 1 to point.
          IF (GENERAL_ELEMENT) THEN                                      ! If general_element:
            JACOBIAN = 0.0_R8                                            ! Set jacobian to zero.
            DO II = 1_I4, 3_I4                                           ! Loop ii from 1 to 3:
              JACOBIAN(II,II) = 1.0_R8                                   ! Set jacobian(ii,ii) to 1.0.
            END DO                                                       ! End of the loop.
            INVERSE = JACOBIAN                                           ! Set inverse to jacobian.
            DETERMINANT = 1.0_R8                                         ! Set determinant to 1.0.
            DN_PHYSICAL(1:N_NODE,1:DIMENSION) =                          ! Set dn_physical(1:n_node,1:dimension) to rules.item(rule_index).derivative(1:n_node,1:dimension,p).
     &        RULES%ITEM(RULE_INDEX)%DERIVATIVE(1:N_NODE,1:DIMENSION,P)
          ELSE                                                           ! Otherwise:
            CALL EVALUATE_SQUARE_JACOBIAN(                               ! Call evaluate square jacobian with active_coordinate(1:n_node,1:dimension), rules.item(rule_index).derivati...
     &        ACTIVE_COORDINATE(1:N_NODE,1:DIMENSION),
     &        RULES%ITEM(RULE_INDEX)%DERIVATIVE(
     &        1:N_NODE,1:DIMENSION,P), DIMENSION,
     &        JACOBIAN, DETERMINANT, INVERSE,
     &        DN_PHYSICAL(1:N_NODE,1:DIMENSION), STATUS)
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
          END IF                                                         ! End of the IF block.
          CACHE%JACOBIAN(:,:,POINT) = JACOBIAN                           ! Set cache.jacobian(:,:,point) to jacobian.
          CACHE%INVERSE_JACOBIAN(:,:,POINT) = INVERSE                    ! Set cache.inverse_jacobian(:,:,point) to inverse.
          CACHE%DETERMINANT(POINT) = DETERMINANT                         ! Set cache.determinant(point) to determinant.
          CACHE%CENTER_GLOBAL(:,POINT) = 0.0_R8                          ! Set cache.center_global(:,point) to zero.
          DO J = 1_I4, N_NODE                                            ! Loop j from 1 to n_node:
            CACHE%CENTER_GLOBAL(:,POINT) =                               ! Add rules.item(rule_index).shape(j,p)* global_coordinate(j,:) to cache.center_global(:,point).
     &        CACHE%CENTER_GLOBAL(:,POINT) +
     &        RULES%ITEM(RULE_INDEX)%SHAPE(J,P)*
     &        GLOBAL_COORDINATE(J,:)
          END DO                                                         ! End of the loop.
          CACHE%DERIVATIVE_OFFSET(POINT) = ENTRY + 1_I8                  ! Set cache.derivative_offset(point) to entry + 1.
          DO J = 1_I4, N_NODE                                            ! Loop j from 1 to n_node:
            ENTRY = ENTRY + 1_I8                                         ! Add 1 to entry.
            CACHE%DERIVATIVE_LOCAL(:,ENTRY) = 0.0_R8                     ! Set cache.derivative_local(:,entry) to zero.
            CACHE%DERIVATIVE_LOCAL(AXIS(1:DIMENSION),ENTRY) =            ! Set cache.derivative_local(axis(1:dimension),entry) to dn_physical(j,1:dimension).
     &        DN_PHYSICAL(J,1:DIMENSION)
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        CACHE%ELEMENT_LAST(I) = POINT                                    ! Set cache.element_last(i) to point.
      END DO                                                             ! End of the loop.
      CACHE%DERIVATIVE_OFFSET(POINT+1_I8) = ENTRY + 1_I8                 ! Set cache.derivative_offset(point+1) to entry + 1.
      CACHE%COUNT = POINT                                                ! Set cache.count to point.

      END SUBROUTINE BUILD_STRUCTURAL_GEOMETRY_CACHE                     ! End of the subroutine build structural geometry cache.

      SUBROUTINE BUILD_EXPANSION_GEOMETRY_CACHE(EXPANSIONS,              ! Subroutine build expansion geometry cache takes expansions, rules, cache, status, expansion order.
     &     RULES, CACHE, STATUS, EXPANSION_ORDER)

      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(INOUT) :: CACHE        ! In/out of type expansion_geometry_cache_type: cache.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4), INTENT(IN), OPTIONAL :: EXPANSION_ORDER(:)            ! Input optional integer (int32): expansion_order(:).
      INTEGER(I4) :: ORDER                                               ! Integer (int32): order.
      REAL(R8) :: COORDINATE(27,3)                                       ! Real (real64): coordinate(27,3).
      REAL(R8) :: NODE_COORDINATE(3)                                     ! Real (real64): node_coordinate(3).
      REAL(R8) :: ACTIVE_COORDINATE(27,3)                                ! Real (real64): active_coordinate(27,3).
      REAL(R8), ALLOCATABLE :: DN_PHYSICAL(:,:)                          ! Allocatable real (real64): dn_physical(:,:).
      REAL(R8) :: JACOBIAN(3,3)                                          ! Real (real64): jacobian(3,3).
      REAL(R8) :: INVERSE(3,3)                                           ! Real (real64): inverse(3,3).
      REAL(R8) :: DETERMINANT                                            ! Real (real64): determinant.
      TYPE(HLE_GEOMETRY_TYPE) :: HLE_MAP                                 ! Of type hle_geometry_type: hle_map.
      REAL(R8) :: VERTEX_2D(2,4)                                         ! Real (real64): vertex_2d(2,4).
      REAL(R8) :: MID_2D(2,4)                                            ! Real (real64): mid_2d(2,4).
      REAL(R8) :: MAP_X(2)                                               ! Real (real64): map_x(2).
      REAL(R8) :: MAP_DX(2,2)                                            ! Real (real64): map_dx(2,2).
      REAL(R8) :: PSEUDO_X(2,2)                                          ! Real (real64): pseudo_x(2,2).
      REAL(R8) :: PSEUDO_DN(2,2)                                         ! Real (real64): pseudo_dn(2,2).
      REAL(R8) :: PSEUDO_PHYSICAL(2,2)                                   ! Real (real64): pseudo_physical(2,2).
      LOGICAL :: HAS_MID(4)                                              ! Logical: has_mid(4).
      LOGICAL :: CURVED_ELEMENT                                          ! Logical: curved_element.
      INTEGER(I4) :: THIRD                                               ! Integer (int32): third.
      INTEGER(I8) :: TOTAL_POINT                                         ! Integer (int64): total_point.
      INTEGER(I8) :: TOTAL_ENTRY                                         ! Integer (int64): total_entry.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I8) :: ENTRY                                               ! Integer (int64): entry.
      INTEGER(I4) :: TOTAL_ELEMENT                                       ! Integer (int32): total_element.
      INTEGER(I4) :: FLAT_ELEMENT                                        ! Integer (int32): flat_element.
      INTEGER(I4) :: RULE_INDEX                                          ! Integer (int32): rule_index.
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: N_FUNC                                              ! Integer (int32): n_func.
      INTEGER(I4) :: N_POINT                                             ! Integer (int32): n_point.
      INTEGER(I4) :: AXIS(3)                                             ! Integer (int32): axis(3).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: P                                                   ! Integer (int32): p.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_EXPANSION_CACHE(CACHE)                                  ! Call clear expansion cache with cache.
      TOTAL_ELEMENT = 0_I4                                               ! Set total_element to zero.
      TOTAL_POINT = 0_I8                                                 ! Set total_point to zero.
      TOTAL_ENTRY = 0_I8                                                 ! Set total_entry to zero.
      DO I = 1_I4, SIZE(EXPANSIONS%ITEM)                                 ! Loop i from 1 to size(expansions.item):
        TOTAL_ELEMENT = TOTAL_ELEMENT +                                  ! Add size(expansions.item(i).element) to total_element.
     &                  SIZE(EXPANSIONS%ITEM(I)%ELEMENT)
        DO J = 1_I4, SIZE(EXPANSIONS%ITEM(I)%ELEMENT)                    ! Loop j from 1 to size(expansions.item(i).element):
          ORDER = EXPANSION_MESH_ORDER(                                  ! Set order to expansion_mesh_order( expansions.item(i).element(j).topology, i, expansion_order).
     &      EXPANSIONS%ITEM(I)%ELEMENT(J)%TOPOLOGY, I,
     &      EXPANSION_ORDER)
          RULE_INDEX = FIND_REFERENCE_RULE(RULES,                        ! Set rule_index to find_reference_rule(rules, expansions.item(i).element(j).topology, order).
     &      EXPANSIONS%ITEM(I)%ELEMENT(J)%TOPOLOGY, ORDER)
          IF (RULE_INDEX .EQ. 0_I4) THEN                                 ! If rule_index = 0:
            CALL SET_ERROR(STATUS,                                       ! Record an error in status: 'EXPANSION REFERENCE RULE IS MISSING'.
     &                     'BUILD_EXPANSION_GEOMETRY_CACHE',
     &                     'EXPANSION REFERENCE RULE IS MISSING')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          N_POINT = SIZE(RULES%ITEM(RULE_INDEX)%WEIGHT)                  ! Set n_point to the size of rules.item(rule_index).weight.
          N_FUNC = TOPOLOGY_FUNCTION_COUNT(                              ! Set n_func to topology_function_count( expansions.item(i).element(j).topology).
     &      EXPANSIONS%ITEM(I)%ELEMENT(J)%TOPOLOGY)
          TOTAL_POINT = TOTAL_POINT + INT(N_POINT,I8)                    ! Add int(n_point,i8) to total_point.
          TOTAL_ENTRY = TOTAL_ENTRY + INT(N_POINT*N_FUNC,I8)             ! Add int(n_point*n_func,i8) to total_entry.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CALL ALLOCATE_EXPANSION_CACHE(CACHE, SIZE(EXPANSIONS%ITEM),        ! Call allocate expansion cache with cache, size(expansions.item), total_element, total_point, total_entry.
     &     TOTAL_ELEMENT, TOTAL_POINT, TOTAL_ENTRY)

      POINT = 0_I8                                                       ! Set point to zero.
      ENTRY = 0_I8                                                       ! Set entry to zero.
      FLAT_ELEMENT = 0_I4                                                ! Set flat_element to zero.
      DO I = 1_I4, SIZE(EXPANSIONS%ITEM)                                 ! Loop i from 1 to size(expansions.item):
        CALL FIND_EXPANSION_ACTIVE_AXES(EXPANSIONS, I,                   ! Call find expansion active axes with expansions, i, axis, status.
     &                                  AXIS, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        CACHE%ACTIVE_AXIS(:,I) = AXIS                                    ! Set cache.active_axis(:,i) to axis.
        CACHE%MESH_ELEMENT_BASE(I) = FLAT_ELEMENT + 1_I4                 ! Set cache.mesh_element_base(i) to flat_element + 1.
        DO J = 1_I4, SIZE(EXPANSIONS%ITEM(I)%ELEMENT)                    ! Loop j from 1 to size(expansions.item(i).element):
          FLAT_ELEMENT = FLAT_ELEMENT + 1_I4                             ! Add 1 to flat_element.
          ORDER = EXPANSION_MESH_ORDER(                                  ! Set order to expansion_mesh_order( expansions.item(i).element(j).topology, i, expansion_order).
     &      EXPANSIONS%ITEM(I)%ELEMENT(J)%TOPOLOGY, I,
     &      EXPANSION_ORDER)
          RULE_INDEX = FIND_REFERENCE_RULE(RULES,                        ! Set rule_index to find_reference_rule(rules, expansions.item(i).element(j).topology, order).
     &      EXPANSIONS%ITEM(I)%ELEMENT(J)%TOPOLOGY, ORDER)
          DIMENSION = RULES%ITEM(RULE_INDEX)%NATURAL_DIMENSION           ! Set dimension to rules.item(rule_index).natural_dimension.
          N_NODE = SIZE(EXPANSIONS%ITEM(I)%ELEMENT(J)%NODE_ID)           ! Set n_node to the size of expansions.item(i).element(j).node_id.
          N_FUNC = TOPOLOGY_FUNCTION_COUNT(                              ! Set n_func to topology_function_count( expansions.item(i).element(j).topology).
     &      EXPANSIONS%ITEM(I)%ELEMENT(J)%TOPOLOGY)
          N_POINT = SIZE(RULES%ITEM(RULE_INDEX)%WEIGHT)                  ! Set n_point to the size of rules.item(rule_index).weight.
          IF (ALLOCATED(DN_PHYSICAL)) DEALLOCATE(DN_PHYSICAL)            ! If allocated(dn_physical), free the memory of dn_physical.
          ALLOCATE(DN_PHYSICAL(MAX(N_FUNC,N_NODE),3))                    ! Allocate memory for dn_physical(max(n_func,n_node),3).
          COORDINATE = 0.0_R8                                            ! Set coordinate to zero.
          DO K = 1_I4, N_NODE                                            ! Loop k from 1 to n_node:
            CALL GET_EXPANSION_NODE_COORDINATE(EXPANSIONS, I,            ! Call get expansion node coordinate with expansions, i, expansions.item(i).element(j).node_id(k), node_coord...
     &        EXPANSIONS%ITEM(I)%ELEMENT(J)%NODE_ID(K),
     &        NODE_COORDINATE, STATUS)
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            COORDINATE(K,:) = NODE_COORDINATE                            ! Set coordinate(k,:) to node_coordinate.
          END DO                                                         ! End of the loop.
          ACTIVE_COORDINATE = 0.0_R8                                     ! Set active_coordinate to zero.
          DO K = 1_I4, DIMENSION                                         ! Loop k from 1 to dimension:
            ACTIVE_COORDINATE(1:N_NODE,K) =                              ! Set active_coordinate(1:n_node,k) to coordinate(1:n_node,axis(k)).
     &        COORDINATE(1:N_NODE,AXIS(K))
          END DO                                                         ! End of the loop.
!         HQ SUB-ELEMENT WITH CURVED SIDES: BLENDING-FUNCTION MAP.
          CURVED_ELEMENT = .FALSE.                                       ! Set the flag curved_element to false.
          IF (TOPOLOGY_IS_HLE(EXPANSIONS%ITEM(I)%ELEMENT(J)%             ! If topology_is_hle(expansions.item(i).element(j). topology) and expansions.item(i).element(j). topology > t...
     &        TOPOLOGY) .AND. EXPANSIONS%ITEM(I)%ELEMENT(J)%
     &        TOPOLOGY .GT. TOPOLOGY_HQ_BASE .AND.
     &        ANY(EXPANSIONS%ITEM(I)%ELEMENT(J)%MID_NODE_ID .NE.
     &        0_I8)) THEN
            THIRD = 6_I4 - AXIS(1) - AXIS(2)                             ! Set third to 6 - axis(1) - axis(2).
            HAS_MID = .FALSE.                                            ! Set the flag has_mid to false.
            MID_2D = 0.0_R8                                              ! Set mid_2d to zero.
            DO K = 1_I4, 4_I4                                            ! Loop k from 1 to 4:
              VERTEX_2D(1,K) = COORDINATE(K,AXIS(1))                     ! Set vertex_2d(1,k) to coordinate(k,axis(1)).
              VERTEX_2D(2,K) = COORDINATE(K,AXIS(2))                     ! Set vertex_2d(2,k) to coordinate(k,axis(2)).
              IF (EXPANSIONS%ITEM(I)%ELEMENT(J)%MID_NODE_ID(K)           ! If expansions.item(i).element(j).mid_node_id(k) = 0, skip to the next iteration.
     &            .EQ. 0_I8) CYCLE
              CALL GET_EXPANSION_NODE_COORDINATE(EXPANSIONS, I,          ! Call get expansion node coordinate with expansions, i, expansions.item(i).element(j).mid_node_id(k), node_c...
     &          EXPANSIONS%ITEM(I)%ELEMENT(J)%MID_NODE_ID(K),
     &          NODE_COORDINATE, STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
              MID_2D(1,K) = NODE_COORDINATE(AXIS(1))                     ! Set mid_2d(1,k) to node_coordinate(axis(1)).
              MID_2D(2,K) = NODE_COORDINATE(AXIS(2))                     ! Set mid_2d(2,k) to node_coordinate(axis(2)).
              HAS_MID(K) = .TRUE.                                        ! Set the flag has_mid(k) to true.
            END DO                                                       ! End of the loop.
            CALL HLE_GEOMETRY_SETUP(VERTEX_2D, MID_2D, HAS_MID,          ! Call hle geometry setup with vertex_2d, mid_2d, has_mid, hle_map.
     &                              HLE_MAP)
            CURVED_ELEMENT = HLE_MAP%ANY_CURVED                          ! Set curved_element to hle_map.any_curved.
          END IF                                                         ! End of the IF block.
          CACHE%ELEMENT_FIRST(FLAT_ELEMENT) = POINT + 1_I8               ! Set cache.element_first(flat_element) to point + 1.
          DO P = 1_I4, N_POINT                                           ! Loop p from 1 to n_point:
            POINT = POINT + 1_I8                                         ! Add 1 to point.
            JACOBIAN = 0.0_R8                                            ! Set jacobian to zero.
            INVERSE = 0.0_R8                                             ! Set inverse to zero.
            DN_PHYSICAL = 0.0_R8                                         ! Set dn_physical to zero.
            IF (DIMENSION .EQ. 0_I4) THEN                                ! If dimension = 0:
              DETERMINANT = 1.0_R8                                       ! Set determinant to 1.0.
            ELSE IF (CURVED_ELEMENT) THEN                                ! Otherwise, if curved_element:
!             THE JACOBIAN OF THE MAP IS PASSED AS TWO PSEUDO NODES
!             WHOSE COORDINATES ARE DX/DR AND DX/DS.
              CALL HLE_MAP_EVALUATE(HLE_MAP,                             ! Call hle map evaluate with hle_map, rules.item(rule_index).coordinate(p,1), rules.item(rule_index).coordina...
     &          RULES%ITEM(RULE_INDEX)%COORDINATE(P,1),
     &          RULES%ITEM(RULE_INDEX)%COORDINATE(P,2),
     &          MAP_X, MAP_DX)
              PSEUDO_X(1,:) = MAP_DX(:,1)                                ! Set pseudo_x(1,:) to map_dx(:,1).
              PSEUDO_X(2,:) = MAP_DX(:,2)                                ! Set pseudo_x(2,:) to map_dx(:,2).
              PSEUDO_DN = RESHAPE([1.0_R8,0.0_R8,0.0_R8,1.0_R8],         ! Set pseudo_dn to reshape([1.0,0.0,0.0,1.0], [2,2]).
     &                            [2,2])
              CALL EVALUATE_SQUARE_JACOBIAN(PSEUDO_X, PSEUDO_DN,         ! Call evaluate square jacobian with pseudo_x, pseudo_dn, dimension, jacobian, determinant, inverse, pseudo_p...
     &          DIMENSION, JACOBIAN, DETERMINANT, INVERSE,
     &          PSEUDO_PHYSICAL, STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
              DN_PHYSICAL(1:N_FUNC,1:DIMENSION) = MATMUL(                ! Set dn_physical(1:n_func,1:dimension) to matmul( rules.item(rule_index).derivative(1:n_func, 1:dimension,p)...
     &          RULES%ITEM(RULE_INDEX)%DERIVATIVE(1:N_FUNC,
     &          1:DIMENSION,P),
     &          TRANSPOSE(INVERSE(1:DIMENSION,1:DIMENSION)))
            ELSE                                                         ! Otherwise:
              CALL EVALUATE_SQUARE_JACOBIAN(                             ! Call evaluate square jacobian with active_coordinate(1:n_node,1:dimension), rules.item(rule_index).derivati...
     &          ACTIVE_COORDINATE(1:N_NODE,1:DIMENSION),
     &          RULES%ITEM(RULE_INDEX)%DERIVATIVE(
     &          1:N_NODE,1:DIMENSION,P), DIMENSION,
     &          JACOBIAN, DETERMINANT, INVERSE,
     &          DN_PHYSICAL(1:N_NODE,1:DIMENSION), STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
!             HLE: THE MAP USES THE VERTEX NODES (FIRST FUNCTIONS) BUT
!             EVERY MODE NEEDS ITS PHYSICAL GRADIENT.
              IF (N_FUNC .GT. N_NODE) THEN                               ! If n_func > n_node:
                DN_PHYSICAL(1:N_FUNC,1:DIMENSION) = MATMUL(              ! Set dn_physical(1:n_func,1:dimension) to matmul( rules.item(rule_index).derivative(1:n_func, 1:dimension,p)...
     &            RULES%ITEM(RULE_INDEX)%DERIVATIVE(1:N_FUNC,
     &            1:DIMENSION,P),
     &            TRANSPOSE(INVERSE(1:DIMENSION,1:DIMENSION)))
              END IF                                                     ! End of the IF block.
            END IF                                                       ! End of the IF block.
            CACHE%JACOBIAN(:,:,POINT) = JACOBIAN                         ! Set cache.jacobian(:,:,point) to jacobian.
            CACHE%INVERSE_JACOBIAN(:,:,POINT) = INVERSE                  ! Set cache.inverse_jacobian(:,:,point) to inverse.
            CACHE%DETERMINANT(POINT) = DETERMINANT                       ! Set cache.determinant(point) to determinant.
            CACHE%COORDINATE_LOCAL(:,POINT) = 0.0_R8                     ! Set cache.coordinate_local(:,point) to zero.
            DO K = 1_I4, N_NODE                                          ! Loop k from 1 to n_node:
              CACHE%COORDINATE_LOCAL(:,POINT) =                          ! Add rules.item(rule_index).shape(k,p)*coordinate(k,:) to cache.coordinate_local(:,point).
     &          CACHE%COORDINATE_LOCAL(:,POINT) +
     &          RULES%ITEM(RULE_INDEX)%SHAPE(K,P)*COORDINATE(K,:)
            END DO                                                       ! End of the loop.
            IF (CURVED_ELEMENT) THEN                                     ! If curved_element:
              CACHE%COORDINATE_LOCAL(THIRD,POINT) = COORDINATE(1,THIRD)  ! Set cache.coordinate_local(third,point) to coordinate(1,third).
              CACHE%COORDINATE_LOCAL(AXIS(1),POINT) = MAP_X(1)           ! Set cache.coordinate_local(axis(1),point) to map_x(1).
              CACHE%COORDINATE_LOCAL(AXIS(2),POINT) = MAP_X(2)           ! Set cache.coordinate_local(axis(2),point) to map_x(2).
            END IF                                                       ! End of the IF block.
            CACHE%DERIVATIVE_OFFSET(POINT) = ENTRY + 1_I8                ! Set cache.derivative_offset(point) to entry + 1.
            DO K = 1_I4, N_FUNC                                          ! Loop k from 1 to n_func:
              ENTRY = ENTRY + 1_I8                                       ! Add 1 to entry.
              CACHE%DERIVATIVE_LOCAL(:,ENTRY) = 0.0_R8                   ! Set cache.derivative_local(:,entry) to zero.
              IF (DIMENSION .GT. 0_I4) THEN                              ! If dimension > 0:
                CACHE%DERIVATIVE_LOCAL(AXIS(1:DIMENSION),ENTRY) =        ! Set cache.derivative_local(axis(1:dimension),entry) to dn_physical(k,1:dimension).
     &            DN_PHYSICAL(K,1:DIMENSION)
              END IF                                                     ! End of the IF block.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
          CACHE%ELEMENT_LAST(FLAT_ELEMENT) = POINT                       ! Set cache.element_last(flat_element) to point.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CACHE%DERIVATIVE_OFFSET(POINT+1_I8) = ENTRY + 1_I8                 ! Set cache.derivative_offset(point+1) to entry + 1.
      CACHE%COUNT = POINT                                                ! Set cache.count to point.

      END SUBROUTINE BUILD_EXPANSION_GEOMETRY_CACHE                      ! End of the subroutine build expansion geometry cache.

      SUBROUTINE BUILD_COMBINED_GAUSS_GEOMETRY(ELEMENTS,                 ! Subroutine build combined gauss geometry takes elements, expansions, frames, layout, structural cache, expa...
     &     EXPANSIONS, FRAMES, LAYOUT, STRUCTURAL_CACHE,
     &     EXPANSION_CACHE, GEOMETRY, STATUS)

      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: LAYOUT                      ! Input of type gauss_layout_type: layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(INOUT) :: GEOMETRY               ! In/out of type gauss_geometry_type: geometry.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: STRUCTURAL_INDEX                                    ! Integer (int64): structural_index.
      INTEGER(I8) :: EXPANSION_INDEX                                     ! Integer (int64): expansion_index.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I4) :: ELEMENT_INDEX                                       ! Integer (int32): element_index.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: FLAT_ELEMENT                                        ! Integer (int32): flat_element.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_COMBINED_GEOMETRY(GEOMETRY)                             ! Call clear combined geometry with geometry.
      IF (LAYOUT%COUNT .LT. 1_I8) THEN                                   ! If layout.count < 1:
        CALL SET_ERROR(STATUS, 'BUILD_COMBINED_GAUSS_GEOMETRY',          ! Record an error in status: 'GAUSS LAYOUT IS EMPTY'.
     &                 'GAUSS LAYOUT IS EMPTY')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(GEOMETRY%STRUCTURAL_CACHE_INDEX(LAYOUT%COUNT))            ! Allocate memory for geometry.structural_cache_index(layout.count).
      ALLOCATE(GEOMETRY%EXPANSION_CACHE_INDEX(LAYOUT%COUNT))             ! Allocate memory for geometry.expansion_cache_index(layout.count).
      ALLOCATE(GEOMETRY%COORDINATE_GLOBAL(3,LAYOUT%COUNT))               ! Allocate memory for geometry.coordinate_global(3,layout.count).
      ALLOCATE(GEOMETRY%INTEGRATION_WEIGHT(LAYOUT%COUNT))                ! Allocate memory for geometry.integration_weight(layout.count).

      DO POINT = 1_I8, LAYOUT%COUNT                                      ! Loop point from 1 to layout.count:
        ELEMENT_INDEX = LAYOUT%ELEMENT_INDEX(POINT)                      ! Set element_index to layout.element_index(point).
        MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,                    ! Set mesh_index to find_expansion_index(expansions, elements.item(element_index).expansion_id).
     &               ELEMENTS%ITEM(ELEMENT_INDEX)%EXPANSION_ID)
        IF (MESH_INDEX .EQ. 0_I4) THEN                                   ! If mesh_index = 0:
          CALL SET_ERROR(STATUS,                                         ! Record an error in status: 'EXPANSION MESH IS MISSING'.
     &                   'BUILD_COMBINED_GAUSS_GEOMETRY',
     &                   'EXPANSION MESH IS MISSING')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        STRUCTURAL_INDEX = STRUCTURAL_CACHE%ELEMENT_FIRST(               ! Set structural_index to structural_cache.element_first( element_index) + layout.structural_point_index(poin...
     &    ELEMENT_INDEX) +
     &    LAYOUT%STRUCTURAL_POINT_INDEX(POINT)-1_I8
        FLAT_ELEMENT = EXPANSION_CACHE%MESH_ELEMENT_BASE(                ! Set flat_element to expansion_cache.mesh_element_base( mesh_index) + layout.expansion_element_index(point)-1.
     &    MESH_INDEX) +
     &    LAYOUT%EXPANSION_ELEMENT_INDEX(POINT)-1_I4
        EXPANSION_INDEX = EXPANSION_CACHE%ELEMENT_FIRST(                 ! Set expansion_index to expansion_cache.element_first( flat_element) + layout.expansion_point_index(point)-1.
     &    FLAT_ELEMENT) +
     &    LAYOUT%EXPANSION_POINT_INDEX(POINT)-1_I8
        GEOMETRY%STRUCTURAL_CACHE_INDEX(POINT) = STRUCTURAL_INDEX        ! Set geometry.structural_cache_index(point) to structural_index.
        GEOMETRY%EXPANSION_CACHE_INDEX(POINT) = EXPANSION_INDEX          ! Set geometry.expansion_cache_index(point) to expansion_index.
        GEOMETRY%COORDINATE_GLOBAL(:,POINT) =                            ! Set geometry.coordinate_global(:,point) to structural_cache.center_global(:,structural_index) + matmul(fram...
     &    STRUCTURAL_CACHE%CENTER_GLOBAL(:,STRUCTURAL_INDEX) +
     &    MATMUL(FRAMES%LOCAL_TO_GLOBAL(:,:,ELEMENT_INDEX),
     &    EXPANSION_CACHE%COORDINATE_LOCAL(:,EXPANSION_INDEX))
        GEOMETRY%INTEGRATION_WEIGHT(POINT) =                             ! Set geometry.integration_weight(point) to layout.reference_weight(point)* structural_cache.determinant(stru...
     &    LAYOUT%REFERENCE_WEIGHT(POINT)*
     &    STRUCTURAL_CACHE%DETERMINANT(STRUCTURAL_INDEX)*
     &    EXPANSION_CACHE%DETERMINANT(EXPANSION_INDEX)
      END DO                                                             ! End of the loop.
      GEOMETRY%COUNT = LAYOUT%COUNT                                      ! Set geometry.count to layout.count.

      END SUBROUTINE BUILD_COMBINED_GAUSS_GEOMETRY                       ! End of the subroutine build combined gauss geometry.

      SUBROUTINE STRUCTURAL_ACTIVE_AXES(DIMENSION, AXIS)                 ! Subroutine structural active axes takes dimension, axis.

      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      INTEGER(I4), INTENT(OUT) :: AXIS(3)                                ! Output integer (int32): axis(3).

      AXIS = [1_I4,2_I4,3_I4]                                            ! Set axis to [1,2,3].
      IF (DIMENSION .EQ. 1_I4) AXIS(1) = 2_I4                            ! If dimension = 1, set axis(1) to 2.

      END SUBROUTINE STRUCTURAL_ACTIVE_AXES                              ! End of the subroutine structural active axes.

      SUBROUTINE FIND_EXPANSION_ACTIVE_AXES(EXPANSIONS,                  ! Subroutine find expansion active axes takes expansions, mesh index, axis, status.
     &                                      MESH_INDEX, AXIS, STATUS)

      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      INTEGER(I4), INTENT(IN) :: MESH_INDEX                              ! Input integer (int32): mesh_index.
      INTEGER(I4), INTENT(OUT) :: AXIS(3)                                ! Output integer (int32): axis(3).
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      REAL(R8) :: RANGE(3)                                               ! Real (real64): range(3).
      REAL(R8) :: MINIMUM(3)                                             ! Real (real64): minimum(3).
      REAL(R8) :: MAXIMUM(3)                                             ! Real (real64): maximum(3).
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: BEST                                                ! Integer (int32): best.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      AXIS = [1_I4,2_I4,3_I4]                                            ! Set axis to [1,2,3].
      DIMENSION = TOPOLOGY_NATURAL_DIMENSION(                            ! Set dimension to topology_natural_dimension( expansions.item(mesh_index).element(1).topology).
     & EXPANSIONS%ITEM(MESH_INDEX)%ELEMENT(1)%TOPOLOGY)
      IF (DIMENSION .EQ. 0_I4) RETURN                                    ! If dimension = 0, return to the caller.
      MINIMUM = HUGE(1.0_R8)                                             ! Set minimum to huge(1.0).
      MAXIMUM = -HUGE(1.0_R8)                                            ! Set maximum to -huge(1.0).
      DO I = 1_I4, SIZE(EXPANSIONS%ITEM(MESH_INDEX)%NODE)                ! Loop i from 1 to size(expansions.item(mesh_index).node):
        MINIMUM = MIN(MINIMUM,                                           ! Set minimum to the smaller of minimum and expansions.item(mesh_index).node(i).coordinate.
     &    EXPANSIONS%ITEM(MESH_INDEX)%NODE(I)%COORDINATE)
        MAXIMUM = MAX(MAXIMUM,                                           ! Set maximum to the larger of maximum and expansions.item(mesh_index).node(i).coordinate.
     &    EXPANSIONS%ITEM(MESH_INDEX)%NODE(I)%COORDINATE)
      END DO                                                             ! End of the loop.
      RANGE = MAXIMUM-MINIMUM                                            ! Set range to maximum-minimum.
      AXIS = 0_I4                                                        ! Set axis to zero.
      DO I = 1_I4, DIMENSION                                             ! Loop i from 1 to dimension:
        BEST = MAXLOC(RANGE,DIM=1)                                       ! Set best to maxloc(range,dim=1).
        IF (RANGE(BEST) .LE. 100.0_R8*EPSILON(1.0_R8)) THEN              ! If range(best) <= 100.0*epsilon(1.0):
          CALL SET_ERROR(STATUS,                                         ! Record an error in status: 'EXPANSION MESH IS DEGENERATE'.
     &                   'FIND_EXPANSION_ACTIVE_AXES',
     &                   'EXPANSION MESH IS DEGENERATE')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        AXIS(I) = BEST                                                   ! Set axis(i) to best.
        RANGE(BEST) = -1.0_R8                                            ! Set range(best) to -1.0.
      END DO                                                             ! End of the loop.
      DO I = 1_I4, DIMENSION - 1_I4                                      ! Loop i from 1 to dimension - 1:
        DO J = I + 1_I4, DIMENSION                                       ! Loop j from i + 1 to dimension:
          IF (AXIS(J) .LT. AXIS(I)) THEN                                 ! If axis(j) < axis(i):
            BEST = AXIS(I)                                               ! Set best to axis(i).
            AXIS(I) = AXIS(J)                                            ! Set axis(i) to axis(j).
            AXIS(J) = BEST                                               ! Set axis(j) to best.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE FIND_EXPANSION_ACTIVE_AXES                          ! End of the subroutine find expansion active axes.

      SUBROUTINE GET_EXPANSION_NODE_COORDINATE(EXPANSIONS,               ! Subroutine get expansion node coordinate takes expansions, mesh index, node id, coordinate, status.
     &     MESH_INDEX, NODE_ID, COORDINATE, STATUS)

      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      INTEGER(I4), INTENT(IN) :: MESH_INDEX                              ! Input integer (int32): mesh_index.
      INTEGER(I8), INTENT(IN) :: NODE_ID                                 ! Input integer (int64): node_id.
      REAL(R8), INTENT(OUT) :: COORDINATE(3)                             ! Output real (real64): coordinate(3).
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      COORDINATE = 0.0_R8                                                ! Set coordinate to zero.
      DO I = 1_I4, SIZE(EXPANSIONS%ITEM(MESH_INDEX)%NODE)                ! Loop i from 1 to size(expansions.item(mesh_index).node):
        IF (EXPANSIONS%ITEM(MESH_INDEX)%NODE(I)%ID .EQ. NODE_ID) THEN    ! If expansions.item(mesh_index).node(i).id = node_id:
          COORDINATE = EXPANSIONS%ITEM(                                  ! Set coordinate to expansions.item( mesh_index).node(i).coordinate.
     &                 MESH_INDEX)%NODE(I)%COORDINATE
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL SET_ERROR(STATUS, 'GET_EXPANSION_NODE_COORDINATE',            ! Record an error in status: 'EXPANSION NODE IS MISSING'.
     &               'EXPANSION NODE IS MISSING')

      END SUBROUTINE GET_EXPANSION_NODE_COORDINATE                       ! End of the subroutine get expansion node coordinate.

      SUBROUTINE ALLOCATE_STRUCTURAL_CACHE(CACHE, N_ELEMENT,             ! Subroutine allocate structural cache takes cache, n element, n point, n entry.
     &                                     N_POINT, N_ENTRY)

      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(INOUT) :: CACHE       ! In/out of type structural_geometry_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: N_ELEMENT                               ! Input integer (int32): n_element.
      INTEGER(I8), INTENT(IN) :: N_POINT                                 ! Input integer (int64): n_point.
      INTEGER(I8), INTENT(IN) :: N_ENTRY                                 ! Input integer (int64): n_entry.

      ALLOCATE(CACHE%ELEMENT_FIRST(N_ELEMENT))                           ! Allocate memory for cache.element_first(n_element).
      ALLOCATE(CACHE%ELEMENT_LAST(N_ELEMENT))                            ! Allocate memory for cache.element_last(n_element).
      ALLOCATE(CACHE%CENTER_GLOBAL(3,N_POINT))                           ! Allocate memory for cache.center_global(3,n_point).
      ALLOCATE(CACHE%JACOBIAN(3,3,N_POINT))                              ! Allocate memory for cache.jacobian(3,3,n_point).
      ALLOCATE(CACHE%INVERSE_JACOBIAN(3,3,N_POINT))                      ! Allocate memory for cache.inverse_jacobian(3,3,n_point).
      ALLOCATE(CACHE%DETERMINANT(N_POINT))                               ! Allocate memory for cache.determinant(n_point).
      ALLOCATE(CACHE%DERIVATIVE_OFFSET(N_POINT+1_I8))                    ! Allocate memory for cache.derivative_offset(n_point+1).
      ALLOCATE(CACHE%DERIVATIVE_LOCAL(3,N_ENTRY))                        ! Allocate memory for cache.derivative_local(3,n_entry).
      CACHE%JACOBIAN = 0.0_R8                                            ! Set cache.jacobian to zero.
      CACHE%INVERSE_JACOBIAN = 0.0_R8                                    ! Set cache.inverse_jacobian to zero.

      END SUBROUTINE ALLOCATE_STRUCTURAL_CACHE                           ! End of the subroutine allocate structural cache.

      SUBROUTINE ALLOCATE_EXPANSION_CACHE(CACHE, N_MESH,                 ! Subroutine allocate expansion cache takes cache, n mesh, n element, n point, n entry.
     &     N_ELEMENT, N_POINT, N_ENTRY)

      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(INOUT) :: CACHE        ! In/out of type expansion_geometry_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: N_MESH                                  ! Input integer (int32): n_mesh.
      INTEGER(I4), INTENT(IN) :: N_ELEMENT                               ! Input integer (int32): n_element.
      INTEGER(I8), INTENT(IN) :: N_POINT                                 ! Input integer (int64): n_point.
      INTEGER(I8), INTENT(IN) :: N_ENTRY                                 ! Input integer (int64): n_entry.

      ALLOCATE(CACHE%ACTIVE_AXIS(3,N_MESH))                              ! Allocate memory for cache.active_axis(3,n_mesh).
      ALLOCATE(CACHE%MESH_ELEMENT_BASE(N_MESH))                          ! Allocate memory for cache.mesh_element_base(n_mesh).
      ALLOCATE(CACHE%ELEMENT_FIRST(N_ELEMENT))                           ! Allocate memory for cache.element_first(n_element).
      ALLOCATE(CACHE%ELEMENT_LAST(N_ELEMENT))                            ! Allocate memory for cache.element_last(n_element).
      ALLOCATE(CACHE%COORDINATE_LOCAL(3,N_POINT))                        ! Allocate memory for cache.coordinate_local(3,n_point).
      ALLOCATE(CACHE%JACOBIAN(3,3,N_POINT))                              ! Allocate memory for cache.jacobian(3,3,n_point).
      ALLOCATE(CACHE%INVERSE_JACOBIAN(3,3,N_POINT))                      ! Allocate memory for cache.inverse_jacobian(3,3,n_point).
      ALLOCATE(CACHE%DETERMINANT(N_POINT))                               ! Allocate memory for cache.determinant(n_point).
      ALLOCATE(CACHE%DERIVATIVE_OFFSET(N_POINT+1_I8))                    ! Allocate memory for cache.derivative_offset(n_point+1).
      ALLOCATE(CACHE%DERIVATIVE_LOCAL(3,N_ENTRY))                        ! Allocate memory for cache.derivative_local(3,n_entry).
      CACHE%JACOBIAN = 0.0_R8                                            ! Set cache.jacobian to zero.
      CACHE%INVERSE_JACOBIAN = 0.0_R8                                    ! Set cache.inverse_jacobian to zero.

      END SUBROUTINE ALLOCATE_EXPANSION_CACHE                            ! End of the subroutine allocate expansion cache.

      SUBROUTINE CLEAR_STRUCTURAL_CACHE(CACHE)                           ! Subroutine clear structural cache takes cache.

      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(INOUT) :: CACHE       ! In/out of type structural_geometry_cache_type: cache.

      IF (ALLOCATED(CACHE%ELEMENT_FIRST))                                ! If allocated(cache.element_first), free the memory of cache.element_first.
     &  DEALLOCATE(CACHE%ELEMENT_FIRST)
      IF (ALLOCATED(CACHE%ELEMENT_LAST))                                 ! If allocated(cache.element_last), free the memory of cache.element_last.
     &  DEALLOCATE(CACHE%ELEMENT_LAST)
      IF (ALLOCATED(CACHE%CENTER_GLOBAL))                                ! If allocated(cache.center_global), free the memory of cache.center_global.
     &  DEALLOCATE(CACHE%CENTER_GLOBAL)
      IF (ALLOCATED(CACHE%JACOBIAN)) DEALLOCATE(CACHE%JACOBIAN)          ! If allocated(cache.jacobian), free the memory of cache.jacobian.
      IF (ALLOCATED(CACHE%INVERSE_JACOBIAN))                             ! If allocated(cache.inverse_jacobian), free the memory of cache.inverse_jacobian.
     &  DEALLOCATE(CACHE%INVERSE_JACOBIAN)
      IF (ALLOCATED(CACHE%DETERMINANT))                                  ! If allocated(cache.determinant), free the memory of cache.determinant.
     &  DEALLOCATE(CACHE%DETERMINANT)
      IF (ALLOCATED(CACHE%DERIVATIVE_OFFSET))                            ! If allocated(cache.derivative_offset), free the memory of cache.derivative_offset.
     &  DEALLOCATE(CACHE%DERIVATIVE_OFFSET)
      IF (ALLOCATED(CACHE%DERIVATIVE_LOCAL))                             ! If allocated(cache.derivative_local), free the memory of cache.derivative_local.
     &  DEALLOCATE(CACHE%DERIVATIVE_LOCAL)
      CACHE%COUNT = 0_I8                                                 ! Set cache.count to zero.

      END SUBROUTINE CLEAR_STRUCTURAL_CACHE                              ! End of the subroutine clear structural cache.

      SUBROUTINE CLEAR_EXPANSION_CACHE(CACHE)                            ! Subroutine clear expansion cache takes cache.

      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(INOUT) :: CACHE        ! In/out of type expansion_geometry_cache_type: cache.

      IF (ALLOCATED(CACHE%ACTIVE_AXIS)) DEALLOCATE(CACHE%ACTIVE_AXIS)    ! If allocated(cache.active_axis), free the memory of cache.active_axis.
      IF (ALLOCATED(CACHE%MESH_ELEMENT_BASE))                            ! If allocated(cache.mesh_element_base), free the memory of cache.mesh_element_base.
     &  DEALLOCATE(CACHE%MESH_ELEMENT_BASE)
      IF (ALLOCATED(CACHE%ELEMENT_FIRST))                                ! If allocated(cache.element_first), free the memory of cache.element_first.
     &  DEALLOCATE(CACHE%ELEMENT_FIRST)
      IF (ALLOCATED(CACHE%ELEMENT_LAST))                                 ! If allocated(cache.element_last), free the memory of cache.element_last.
     &  DEALLOCATE(CACHE%ELEMENT_LAST)
      IF (ALLOCATED(CACHE%COORDINATE_LOCAL))                             ! If allocated(cache.coordinate_local), free the memory of cache.coordinate_local.
     &  DEALLOCATE(CACHE%COORDINATE_LOCAL)
      IF (ALLOCATED(CACHE%JACOBIAN)) DEALLOCATE(CACHE%JACOBIAN)          ! If allocated(cache.jacobian), free the memory of cache.jacobian.
      IF (ALLOCATED(CACHE%INVERSE_JACOBIAN))                             ! If allocated(cache.inverse_jacobian), free the memory of cache.inverse_jacobian.
     &  DEALLOCATE(CACHE%INVERSE_JACOBIAN)
      IF (ALLOCATED(CACHE%DETERMINANT))                                  ! If allocated(cache.determinant), free the memory of cache.determinant.
     &  DEALLOCATE(CACHE%DETERMINANT)
      IF (ALLOCATED(CACHE%DERIVATIVE_OFFSET))                            ! If allocated(cache.derivative_offset), free the memory of cache.derivative_offset.
     &  DEALLOCATE(CACHE%DERIVATIVE_OFFSET)
      IF (ALLOCATED(CACHE%DERIVATIVE_LOCAL))                             ! If allocated(cache.derivative_local), free the memory of cache.derivative_local.
     &  DEALLOCATE(CACHE%DERIVATIVE_LOCAL)
      CACHE%COUNT = 0_I8                                                 ! Set cache.count to zero.

      END SUBROUTINE CLEAR_EXPANSION_CACHE                               ! End of the subroutine clear expansion cache.

      SUBROUTINE CLEAR_COMBINED_GEOMETRY(GEOMETRY)                       ! Subroutine clear combined geometry takes geometry.

      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(INOUT) :: GEOMETRY               ! In/out of type gauss_geometry_type: geometry.

      IF (ALLOCATED(GEOMETRY%STRUCTURAL_CACHE_INDEX))                    ! If allocated(geometry.structural_cache_index), free the memory of geometry.structural_cache_index.
     &  DEALLOCATE(GEOMETRY%STRUCTURAL_CACHE_INDEX)
      IF (ALLOCATED(GEOMETRY%EXPANSION_CACHE_INDEX))                     ! If allocated(geometry.expansion_cache_index), free the memory of geometry.expansion_cache_index.
     &  DEALLOCATE(GEOMETRY%EXPANSION_CACHE_INDEX)
      IF (ALLOCATED(GEOMETRY%COORDINATE_GLOBAL))                         ! If allocated(geometry.coordinate_global), free the memory of geometry.coordinate_global.
     &  DEALLOCATE(GEOMETRY%COORDINATE_GLOBAL)
      IF (ALLOCATED(GEOMETRY%INTEGRATION_WEIGHT))                        ! If allocated(geometry.integration_weight), free the memory of geometry.integration_weight.
     &  DEALLOCATE(GEOMETRY%INTEGRATION_WEIGHT)
      GEOMETRY%COUNT = 0_I8                                              ! Set geometry.count to zero.

      END SUBROUTINE CLEAR_COMBINED_GEOMETRY                             ! End of the subroutine clear combined geometry.

      END MODULE MUL2_GAUSS_GEOMETRY                                     ! End of the module mul2 gauss geometry.
