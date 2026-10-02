!=======================================================================
!  SHARED REFERENCE RULES AND CONTIGUOUS GLOBAL GAUSS-POINT LAYOUT.
!=======================================================================
      MODULE MUL2_GAUSS_POINTS                                           ! Module mul2 gauss points begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       SET_ERROR, STATUS_IS_OK
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE,                ! Use from module mul2 expansion meshes: expansion db type, find expansion index.
     &                                 FIND_EXPANSION_INDEX
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_FUNCTION_COUNT,                ! Use from module mul2 topologies: topology function count, topology natural dimension.
     &                           TOPOLOGY_NATURAL_DIMENSION
      USE MUL2_QUADRATURE, ONLY: QUADRATURE_RULE_TYPE,                   ! Use from module mul2 quadrature: quadrature rule type, build default quadrature, build ordered quadrature, ...
     &                           BUILD_DEFAULT_QUADRATURE,
     &                           BUILD_ORDERED_QUADRATURE,
     &                           BUILD_REDUCED_QUADRATURE,
     &                           REDUCED_POINTS_PER_DIRECTION,
     &                           DEFAULT_POINTS_PER_DIRECTION
      USE MUL2_SHAPE_FUNCTIONS, ONLY: EVALUATE_SHAPE                     ! Use from module mul2 shape functions: evaluate shape.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: REFERENCE_RULE_TYPE                                ! Definition of the derived type reference rule type.
        INTEGER(I4) :: TOPOLOGY = 0_I4                                   ! Integer (int32): topology = 0.
        INTEGER(I4) :: ORDER = 0_I4                                      ! Integer (int32): order = 0.
        INTEGER(I4) :: NATURAL_DIMENSION = 0_I4                          ! Integer (int32): natural_dimension = 0.
        INTEGER(I4) :: NODE_COUNT = 0_I4                                 ! Integer (int32): node_count = 0.
        REAL(R8), ALLOCATABLE :: COORDINATE(:,:)                         ! Allocatable real (real64): coordinate(:,:).
        REAL(R8), ALLOCATABLE :: WEIGHT(:)                               ! Allocatable real (real64): weight(:).
        REAL(R8), ALLOCATABLE :: SHAPE(:,:)                              ! Allocatable real (real64): shape(:,:).
        REAL(R8), ALLOCATABLE :: DERIVATIVE(:,:,:)                       ! Allocatable real (real64): derivative(:,:,:).
      END TYPE REFERENCE_RULE_TYPE                                       ! End of the type definition reference rule type.

      TYPE, PUBLIC :: REFERENCE_RULE_DB_TYPE                             ! Definition of the derived type reference rule db type.
        TYPE(REFERENCE_RULE_TYPE), ALLOCATABLE :: ITEM(:)                ! Allocatable of type reference_rule_type: item(:).
      END TYPE REFERENCE_RULE_DB_TYPE                                    ! End of the type definition reference rule db type.

      TYPE, PUBLIC :: GAUSS_LAYOUT_TYPE                                  ! Definition of the derived type gauss layout type.
        INTEGER(I8) :: COUNT = 0_I8                                      ! Integer (int64): count = 0.
        INTEGER(I8), ALLOCATABLE :: ELEMENT_FIRST(:)                     ! Allocatable integer (int64): element_first(:).
        INTEGER(I8), ALLOCATABLE :: ELEMENT_LAST(:)                      ! Allocatable integer (int64): element_last(:).
        INTEGER(I4), ALLOCATABLE :: ELEMENT_INDEX(:)                     ! Allocatable integer (int32): element_index(:).
        INTEGER(I4), ALLOCATABLE :: EXPANSION_ELEMENT_INDEX(:)           ! Allocatable integer (int32): expansion_element_index(:).
        INTEGER(I4), ALLOCATABLE :: STRUCTURAL_RULE_INDEX(:)             ! Allocatable integer (int32): structural_rule_index(:).
        INTEGER(I4), ALLOCATABLE :: STRUCTURAL_POINT_INDEX(:)            ! Allocatable integer (int32): structural_point_index(:).
        INTEGER(I4), ALLOCATABLE :: EXPANSION_RULE_INDEX(:)              ! Allocatable integer (int32): expansion_rule_index(:).
        INTEGER(I4), ALLOCATABLE :: EXPANSION_POINT_INDEX(:)             ! Allocatable integer (int32): expansion_point_index(:).
        INTEGER(I4), ALLOCATABLE :: LAMINATION_ID(:)                     ! Allocatable integer (int32): lamination_id(:).
        REAL(R8), ALLOCATABLE :: REFERENCE_WEIGHT(:)                     ! Allocatable real (real64): reference_weight(:).
      END TYPE GAUSS_LAYOUT_TYPE                                         ! End of the type definition gauss layout type.

      PUBLIC :: BUILD_REFERENCE_RULE_DATABASE                            ! Export: build reference rule database.
      PUBLIC :: BUILD_GAUSS_LAYOUT                                       ! Export: build gauss layout.
      PUBLIC :: FIND_REFERENCE_RULE                                      ! Export: find reference rule.
      PUBLIC :: FIND_STRUCTURAL_RULE                                     ! Export: find structural rule.
      PUBLIC :: EXPANSION_MESH_ORDER                                     ! Export: expansion mesh order.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_REFERENCE_RULE_DATABASE(ELEMENTS,                 ! Subroutine build reference rule database takes elements, expansions, database, status, expansion order, red...
     &     EXPANSIONS, DATABASE, STATUS, EXPANSION_ORDER,
     &     REDUCED_DIMENSION)

      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(INOUT) :: DATABASE            ! In/out of type reference_rule_db_type: database.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4), INTENT(IN), OPTIONAL :: EXPANSION_ORDER(:)            ! Input optional integer (int32): expansion_order(:).
!     REDUCED_DIMENSION(D): THE STRUCTURAL ELEMENTS OF DIMENSION D
!     ALSO GET A REDUCED RULE (ORDER = -1 IN THE DATABASE).
      LOGICAL, INTENT(IN), OPTIONAL :: REDUCED_DIMENSION(3)              ! Input optional logical: reduced_dimension(3).
      INTEGER(I4) :: DIM                                                 ! Integer (int32): dim.
      INTEGER(I4) :: TOPOLOGY_LIST(64)                                   ! Integer (int32): topology_list(64).
      INTEGER(I4) :: ORDER_LIST(64)                                      ! Integer (int32): order_list(64).
      INTEGER(I4) :: TOPOLOGY_COUNT                                      ! Integer (int32): topology_count.
      INTEGER(I4) :: ORDER                                               ! Integer (int32): order.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(DATABASE%ITEM)) DEALLOCATE(DATABASE%ITEM)            ! If allocated(database.item), free the memory of database.item.
      TOPOLOGY_LIST = 0_I4                                               ! Set topology_list to zero.
      ORDER_LIST = 0_I4                                                  ! Set order_list to zero.
      TOPOLOGY_COUNT = 0_I4                                              ! Set topology_count to zero.
      IF (.NOT. ALLOCATED(ELEMENTS%ITEM) .OR.                            ! If not allocated(elements.item) or not allocated(expansions.item):
     &    .NOT. ALLOCATED(EXPANSIONS%ITEM)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_REFERENCE_RULE_DATABASE',          ! Record an error in status: 'MODEL DATABASES ARE NOT ALLOCATED'.
     &                 'MODEL DATABASES ARE NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      DO I = 1_I4, SIZE(ELEMENTS%ITEM)                                   ! Loop i from 1 to size(elements.item):
        CALL ADD_TOPOLOGY(ELEMENTS%ITEM(I)%TOPOLOGY, 0_I4,               ! Call add topology with elements.item(i).topology, 0, topology_list, order_list, topology_count, status.
     &                    TOPOLOGY_LIST, ORDER_LIST, TOPOLOGY_COUNT,
     &                    STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        IF (PRESENT(REDUCED_DIMENSION)) THEN                             ! If present(reduced_dimension):
          DIM = TOPOLOGY_NATURAL_DIMENSION(ELEMENTS%ITEM(I)%TOPOLOGY)    ! Set dim to topology_natural_dimension(elements.item(i).topology).
          IF (DIM .GE. 1_I4 .AND. DIM .LE. 3_I4) THEN                    ! If dim >= 1 and dim <= 3:
            IF (REDUCED_DIMENSION(DIM) .AND.                             ! If reduced_dimension(dim) and reduced_points_per_direction( elements.item(i).topology) > 0:
     &          REDUCED_POINTS_PER_DIRECTION(
     &          ELEMENTS%ITEM(I)%TOPOLOGY) .GT. 0_I4) THEN
              CALL ADD_TOPOLOGY(ELEMENTS%ITEM(I)%TOPOLOGY, -1_I4,        ! Call add topology with elements.item(i).topology, -1, topology_list, order_list, topology_count, status.
     &          TOPOLOGY_LIST, ORDER_LIST, TOPOLOGY_COUNT, STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
            END IF                                                       ! End of the IF block.
          END IF                                                         ! End of the IF block.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      DO I = 1_I4, SIZE(EXPANSIONS%ITEM)                                 ! Loop i from 1 to size(expansions.item):
        IF (.NOT. ALLOCATED(EXPANSIONS%ITEM(I)%ELEMENT)) CYCLE           ! If not allocated(expansions.item(i).element), skip to the next iteration.
        DO J = 1_I4, SIZE(EXPANSIONS%ITEM(I)%ELEMENT)                    ! Loop j from 1 to size(expansions.item(i).element):
          ORDER = EXPANSION_MESH_ORDER(                                  ! Set order to expansion_mesh_order( expansions.item(i).element(j).topology, i, expansion_order).
     &      EXPANSIONS%ITEM(I)%ELEMENT(J)%TOPOLOGY, I,
     &      EXPANSION_ORDER)
          CALL ADD_TOPOLOGY(                                             ! Call add topology with expansions.item(i).element(j).topology, order, topology_list, order_list, topology_c...
     &      EXPANSIONS%ITEM(I)%ELEMENT(J)%TOPOLOGY, ORDER,
     &      TOPOLOGY_LIST, ORDER_LIST, TOPOLOGY_COUNT, STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      ALLOCATE(DATABASE%ITEM(TOPOLOGY_COUNT))                            ! Allocate memory for database.item(topology_count).
      DO I = 1_I4, TOPOLOGY_COUNT                                        ! Loop i from 1 to topology_count:
        CALL BUILD_REFERENCE_RULE(TOPOLOGY_LIST(I), ORDER_LIST(I),       ! Call build reference rule with topology_list(i), order_list(i), database.item(i), status.
     &                            DATABASE%ITEM(I), STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_REFERENCE_RULE_DATABASE                       ! End of the subroutine build reference rule database.

      SUBROUTINE BUILD_REFERENCE_RULE(TOPOLOGY, ORDER, RULE, STATUS)     ! Subroutine build reference rule takes topology, order, rule, status.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      TYPE(REFERENCE_RULE_TYPE), INTENT(INOUT) :: RULE                   ! In/out of type reference_rule_type: rule.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      TYPE(QUADRATURE_RULE_TYPE) :: QUADRATURE                           ! Of type quadrature_rule_type: quadrature.
      REAL(R8), ALLOCATABLE :: N(:)                                      ! Allocatable real (real64): n(:).
      REAL(R8), ALLOCATABLE :: DN(:,:)                                   ! Allocatable real (real64): dn(:,:).
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: N_POINT                                             ! Integer (int32): n_point.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      IF (ORDER .LT. 0_I4) THEN                                          ! If order < 0:
        CALL BUILD_REDUCED_QUADRATURE(TOPOLOGY, QUADRATURE, STATUS)      ! Call build reduced quadrature with topology, quadrature, status.
      ELSE IF (ORDER .GT. 0_I4) THEN                                     ! Otherwise, if order > 0:
        CALL BUILD_ORDERED_QUADRATURE(TOPOLOGY, ORDER, QUADRATURE,       ! Call build ordered quadrature with topology, order, quadrature, status.
     &                                STATUS)
      ELSE                                                               ! Otherwise:
        CALL BUILD_DEFAULT_QUADRATURE(TOPOLOGY, QUADRATURE, STATUS)      ! Call build default quadrature with topology, quadrature, status.
      END IF                                                             ! End of the IF block.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      N_NODE = TOPOLOGY_FUNCTION_COUNT(TOPOLOGY)                         ! Set n_node to topology_function_count(topology).
      N_POINT = SIZE(QUADRATURE%WEIGHT)                                  ! Set n_point to the size of quadrature.weight.
      RULE%TOPOLOGY = TOPOLOGY                                           ! Set rule.topology to topology.
      RULE%ORDER = ORDER                                                 ! Set rule.order to order.
      RULE%NATURAL_DIMENSION = QUADRATURE%NATURAL_DIMENSION              ! Set rule.natural_dimension to quadrature.natural_dimension.
      RULE%NODE_COUNT = N_NODE                                           ! Set rule.node_count to n_node.
      ALLOCATE(RULE%COORDINATE(N_POINT,3))                               ! Allocate memory for rule.coordinate(n_point,3).
      ALLOCATE(RULE%WEIGHT(N_POINT))                                     ! Allocate memory for rule.weight(n_point).
      ALLOCATE(RULE%SHAPE(N_NODE,N_POINT))                               ! Allocate memory for rule.shape(n_node,n_point).
      ALLOCATE(RULE%DERIVATIVE(N_NODE,3,N_POINT))                        ! Allocate memory for rule.derivative(n_node,3,n_point).
      ALLOCATE(N(N_NODE),DN(N_NODE,3))                                   ! Allocate memory for n(n_node), dn(n_node,3).
      RULE%COORDINATE = QUADRATURE%COORDINATE                            ! Set rule.coordinate to quadrature.coordinate.
      RULE%WEIGHT = QUADRATURE%WEIGHT                                    ! Set rule.weight to quadrature.weight.
      RULE%SHAPE = 0.0_R8                                                ! Set rule.shape to zero.
      RULE%DERIVATIVE = 0.0_R8                                           ! Set rule.derivative to zero.

      DO I = 1_I4, N_POINT                                               ! Loop i from 1 to n_point:
        CALL EVALUATE_SHAPE(TOPOLOGY,                                    ! Call evaluate shape with topology, quadrature.coordinate(i,:), n, dn, status.
     &       QUADRATURE%COORDINATE(I,:), N, DN, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        RULE%SHAPE(:,I) = N                                              ! Set rule.shape(:,i) to n.
        RULE%DERIVATIVE(:,:,I) = DN                                      ! Set rule.derivative(:,:,i) to dn.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_REFERENCE_RULE                                ! End of the subroutine build reference rule.

      SUBROUTINE BUILD_GAUSS_LAYOUT(ELEMENTS, EXPANSIONS,                ! Subroutine build gauss layout takes elements, expansions, reference rules, layout, status, expansion order,...
     &     REFERENCE_RULES, LAYOUT, STATUS, EXPANSION_ORDER,
     &     REDUCED)

      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: REFERENCE_RULES        ! Input of type reference_rule_db_type: reference_rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(INOUT) :: LAYOUT                   ! In/out of type gauss_layout_type: layout.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4), INTENT(IN), OPTIONAL :: EXPANSION_ORDER(:)            ! Input optional integer (int32): expansion_order(:).
!     REDUCED: THE STRUCTURAL POINTS USE THE REDUCED RULE WHERE ONE EXISTS.
      LOGICAL, INTENT(IN), OPTIONAL :: REDUCED                           ! Input optional logical: reduced.
      LOGICAL :: USE_REDUCED                                             ! Logical: use_reduced.
      INTEGER(I8) :: TOTAL_COUNT                                         ! Integer (int64): total_count.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I4) :: EXPANSION_INDEX                                     ! Integer (int32): expansion_index.
      INTEGER(I4) :: TOPOLOGY                                            ! Integer (int32): topology.
      INTEGER(I4) :: STRUCTURAL_RULE                                     ! Integer (int32): structural_rule.
      INTEGER(I4) :: EXPANSION_RULE                                      ! Integer (int32): expansion_rule.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: P                                                   ! Integer (int32): p.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_LAYOUT(LAYOUT)                                          ! Call clear layout with layout.
      USE_REDUCED = .FALSE.                                              ! Set the flag use_reduced to false.
      IF (PRESENT(REDUCED)) USE_REDUCED = REDUCED                        ! If present(reduced), set use_reduced to reduced.
      IF (.NOT. ALLOCATED(REFERENCE_RULES%ITEM)) THEN                    ! If not allocated(reference_rules.item):
        CALL SET_ERROR(STATUS, 'BUILD_GAUSS_LAYOUT',                     ! Record an error in status: 'REFERENCE RULE DATABASE IS EMPTY'.
     &                 'REFERENCE RULE DATABASE IS EMPTY')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      TOTAL_COUNT = 0_I8                                                 ! Set total_count to zero.
      DO I = 1_I4, SIZE(ELEMENTS%ITEM)                                   ! Loop i from 1 to size(elements.item):
        EXPANSION_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,               ! Set expansion_index to find_expansion_index(expansions, elements.item(i).expansion_id).
     &                    ELEMENTS%ITEM(I)%EXPANSION_ID)
        STRUCTURAL_RULE = FIND_STRUCTURAL_RULE(REFERENCE_RULES,          ! Set structural_rule to find_structural_rule(reference_rules, elements.item(i).topology, use_reduced).
     &                    ELEMENTS%ITEM(I)%TOPOLOGY, USE_REDUCED)
        IF (EXPANSION_INDEX .EQ. 0_I4 .OR.                               ! If expansion_index = 0 or structural_rule = 0:
     &      STRUCTURAL_RULE .EQ. 0_I4) THEN
          CALL SET_ERROR(STATUS, 'BUILD_GAUSS_LAYOUT',                   ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN DATA'.
     &                   'ELEMENT REFERENCES UNKNOWN DATA')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO J = 1_I4,                                                     ! Loop j from 1 to size(expansions.item(expansion_index).element):
     &    SIZE(EXPANSIONS%ITEM(EXPANSION_INDEX)%ELEMENT)
          TOPOLOGY = EXPANSIONS%ITEM(EXPANSION_INDEX)%ELEMENT(J)%        ! Set topology to expansions.item(expansion_index).element(j). topology.
     &               TOPOLOGY
          EXPANSION_RULE = FIND_REFERENCE_RULE(REFERENCE_RULES,          ! Set expansion_rule to find_reference_rule(reference_rules, topology, expansion_mesh_order(topology, expansi...
     &      TOPOLOGY, EXPANSION_MESH_ORDER(TOPOLOGY, EXPANSION_INDEX,
     &      EXPANSION_ORDER))
          IF (EXPANSION_RULE .EQ. 0_I4) THEN                             ! If expansion_rule = 0:
            CALL SET_ERROR(STATUS, 'BUILD_GAUSS_LAYOUT',                 ! Record an error in status: 'EXPANSION RULE IS MISSING'.
     &                     'EXPANSION RULE IS MISSING')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          TOTAL_COUNT = TOTAL_COUNT + INT(SIZE(                          ! Add int(size( reference_rules.item(structural_rule).weight),i8)* int(size(reference_rules.item( expansion_r...
     &      REFERENCE_RULES%ITEM(STRUCTURAL_RULE)%WEIGHT),I8)*
     &      INT(SIZE(REFERENCE_RULES%ITEM(
     &      EXPANSION_RULE)%WEIGHT),I8)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      CALL ALLOCATE_LAYOUT(LAYOUT, SIZE(ELEMENTS%ITEM), TOTAL_COUNT)     ! Call allocate layout with layout, size(elements.item), total_count.
      POINT = 0_I8                                                       ! Set point to zero.
      DO I = 1_I4, SIZE(ELEMENTS%ITEM)                                   ! Loop i from 1 to size(elements.item):
        LAYOUT%ELEMENT_FIRST(I) = POINT + 1_I8                           ! Set layout.element_first(i) to point + 1.
        EXPANSION_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,               ! Set expansion_index to find_expansion_index(expansions, elements.item(i).expansion_id).
     &                    ELEMENTS%ITEM(I)%EXPANSION_ID)
        STRUCTURAL_RULE = FIND_STRUCTURAL_RULE(REFERENCE_RULES,          ! Set structural_rule to find_structural_rule(reference_rules, elements.item(i).topology, use_reduced).
     &                    ELEMENTS%ITEM(I)%TOPOLOGY, USE_REDUCED)
        DO J = 1_I4,                                                     ! Loop j from 1 to size(expansions.item(expansion_index).element):
     &    SIZE(EXPANSIONS%ITEM(EXPANSION_INDEX)%ELEMENT)
          TOPOLOGY = EXPANSIONS%ITEM(EXPANSION_INDEX)%ELEMENT(J)%        ! Set topology to expansions.item(expansion_index).element(j). topology.
     &               TOPOLOGY
          EXPANSION_RULE = FIND_REFERENCE_RULE(REFERENCE_RULES,          ! Set expansion_rule to find_reference_rule(reference_rules, topology, expansion_mesh_order(topology, expansi...
     &      TOPOLOGY, EXPANSION_MESH_ORDER(TOPOLOGY, EXPANSION_INDEX,
     &      EXPANSION_ORDER))
          DO P = 1_I4, SIZE(REFERENCE_RULES%ITEM(                        ! Loop p from 1 to size(reference_rules.item( structural_rule).weight):
     &                         STRUCTURAL_RULE)%WEIGHT)
            DO Q = 1_I4, SIZE(REFERENCE_RULES%ITEM(                      ! Loop q from 1 to size(reference_rules.item( expansion_rule).weight):
     &                           EXPANSION_RULE)%WEIGHT)
              POINT = POINT + 1_I8                                       ! Add 1 to point.
              LAYOUT%ELEMENT_INDEX(POINT) = I                            ! Set layout.element_index(point) to i.
              LAYOUT%EXPANSION_ELEMENT_INDEX(POINT) = J                  ! Set layout.expansion_element_index(point) to j.
              LAYOUT%STRUCTURAL_RULE_INDEX(POINT) = STRUCTURAL_RULE      ! Set layout.structural_rule_index(point) to structural_rule.
              LAYOUT%STRUCTURAL_POINT_INDEX(POINT) = P                   ! Set layout.structural_point_index(point) to p.
              LAYOUT%EXPANSION_RULE_INDEX(POINT) = EXPANSION_RULE        ! Set layout.expansion_rule_index(point) to expansion_rule.
              LAYOUT%EXPANSION_POINT_INDEX(POINT) = Q                    ! Set layout.expansion_point_index(point) to q.
              LAYOUT%LAMINATION_ID(POINT) = EXPANSIONS%ITEM(             ! Set layout.lamination_id(point) to expansions.item( expansion_index).element(j).lamination_id.
     &          EXPANSION_INDEX)%ELEMENT(J)%LAMINATION_ID
              LAYOUT%REFERENCE_WEIGHT(POINT) =                           ! Set layout.reference_weight(point) to reference_rules.item(structural_rule).weight(p)* reference_rules.item...
     &          REFERENCE_RULES%ITEM(STRUCTURAL_RULE)%WEIGHT(P)*
     &          REFERENCE_RULES%ITEM(EXPANSION_RULE)%WEIGHT(Q)
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        LAYOUT%ELEMENT_LAST(I) = POINT                                   ! Set layout.element_last(i) to point.
      END DO                                                             ! End of the loop.
      LAYOUT%COUNT = POINT                                               ! Set layout.count to point.

      END SUBROUTINE BUILD_GAUSS_LAYOUT                                  ! End of the subroutine build gauss layout.

      SUBROUTINE ADD_TOPOLOGY(TOPOLOGY, ORDER, LIST, ORDERS, COUNT,      ! Subroutine add topology takes topology, order, list, orders, count, status.
     &                        STATUS)

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(INOUT) :: LIST(:)                              ! In/out integer (int32): list(:).
      INTEGER(I4), INTENT(INOUT) :: ORDERS(:)                            ! In/out integer (int32): orders(:).
      INTEGER(I4), INTENT(INOUT) :: COUNT                                ! In/out integer (int32): count.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        IF (LIST(I) .EQ. TOPOLOGY .AND. ORDERS(I) .EQ. ORDER) RETURN     ! If list(i) = topology and orders(i) = order, return to the caller.
      END DO                                                             ! End of the loop.
      IF (COUNT .EQ. SIZE(LIST)) THEN                                    ! If count = size(list):
        CALL SET_ERROR(STATUS, 'ADD_TOPOLOGY',                           ! Record an error in status: 'TOPOLOGY REGISTRY CAPACITY EXCEEDED'.
     &                 'TOPOLOGY REGISTRY CAPACITY EXCEEDED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      COUNT = COUNT + 1_I4                                               ! Add 1 to count.
      LIST(COUNT) = TOPOLOGY                                             ! Set list(count) to topology.
      ORDERS(COUNT) = ORDER                                              ! Set orders(count) to order.

      END SUBROUTINE ADD_TOPOLOGY                                        ! End of the subroutine add topology.

      INTEGER(I4) FUNCTION FIND_REFERENCE_RULE(DATABASE, TOPOLOGY,       ! Function find reference rule takes database, topology, order.
     &                                         ORDER)

      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: DATABASE               ! Input of type reference_rule_db_type: database.
      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      INTEGER(I4), INTENT(IN), OPTIONAL :: ORDER                         ! Input optional integer (int32): order.
      INTEGER(I4) :: WANTED                                              ! Integer (int32): wanted.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_REFERENCE_RULE = 0_I4                                         ! Set find_reference_rule to zero.
      WANTED = 0_I4                                                      ! Set wanted to zero.
      IF (PRESENT(ORDER)) WANTED = ORDER                                 ! If present(order), set wanted to order.
      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (DATABASE%ITEM(I)%TOPOLOGY .EQ. TOPOLOGY .AND.                ! If database.item(i).topology = topology and database.item(i).order = wanted:
     &      DATABASE%ITEM(I)%ORDER .EQ. WANTED) THEN
          FIND_REFERENCE_RULE = I                                        ! Set find_reference_rule to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_REFERENCE_RULE                                   ! End of the function find reference rule.

!  RULE OF A STRUCTURAL ELEMENT: THE REDUCED ONE (ORDER -1) WHEN
!  REQUESTED AND AVAILABLE, OTHERWISE THE DEFAULT RULE.
      INTEGER(I4) FUNCTION FIND_STRUCTURAL_RULE(DATABASE, TOPOLOGY,      ! Function find structural rule takes database, topology, reduced.
     &                                          REDUCED)

      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: DATABASE               ! Input of type reference_rule_db_type: database.
      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      LOGICAL, INTENT(IN) :: REDUCED                                     ! Input logical: reduced.

      FIND_STRUCTURAL_RULE = 0_I4                                        ! Set find_structural_rule to zero.
      IF (REDUCED) FIND_STRUCTURAL_RULE = FIND_REFERENCE_RULE(DATABASE,  ! If reduced, set find_structural_rule to find_reference_rule(database, topology, -1).
     &                                    TOPOLOGY, -1_I4)
      IF (FIND_STRUCTURAL_RULE .EQ. 0_I4) FIND_STRUCTURAL_RULE =         ! If find_structural_rule = 0, set find_structural_rule to find_reference_rule(database, topology).
     &  FIND_REFERENCE_RULE(DATABASE, TOPOLOGY)

      END FUNCTION FIND_STRUCTURAL_RULE                                  ! End of the function find structural rule.

!  POINTS PER DIRECTION REQUIRED BY A MESH (0 = DEFAULT RULE).
      INTEGER(I4) FUNCTION EXPANSION_POINTS(TOPOLOGY, NEEDED)            ! Function expansion points takes topology, needed.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      INTEGER(I4), INTENT(IN) :: NEEDED                                  ! Input integer (int32): needed.

      EXPANSION_POINTS = 0_I4                                            ! Set expansion_points to zero.
      IF (NEEDED .GT. DEFAULT_POINTS_PER_DIRECTION(TOPOLOGY))            ! If needed > default_points_per_direction(topology), set expansion_points to needed.
     &  EXPANSION_POINTS = NEEDED

      END FUNCTION EXPANSION_POINTS                                      ! End of the function expansion points.

      INTEGER(I4) FUNCTION EXPANSION_MESH_ORDER(TOPOLOGY, MESH,          ! Function expansion mesh order takes topology, mesh, expansion order.
     &                                          EXPANSION_ORDER)

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      INTEGER(I4), INTENT(IN) :: MESH                                    ! Input integer (int32): mesh.
      INTEGER(I4), INTENT(IN), OPTIONAL :: EXPANSION_ORDER(:)            ! Input optional integer (int32): expansion_order(:).

      EXPANSION_MESH_ORDER = 0_I4                                        ! Set expansion_mesh_order to zero.
      IF (PRESENT(EXPANSION_ORDER)) EXPANSION_MESH_ORDER =               ! If present(expansion_order), set expansion_mesh_order to expansion_points( topology, expansion_order(mesh)).
     &  EXPANSION_POINTS(
     &  TOPOLOGY, EXPANSION_ORDER(MESH))

      END FUNCTION EXPANSION_MESH_ORDER                                  ! End of the function expansion mesh order.

      SUBROUTINE ALLOCATE_LAYOUT(LAYOUT, N_ELEMENT, N_POINT)             ! Subroutine allocate layout takes layout, n element, n point.

      TYPE(GAUSS_LAYOUT_TYPE), INTENT(INOUT) :: LAYOUT                   ! In/out of type gauss_layout_type: layout.
      INTEGER(I4), INTENT(IN) :: N_ELEMENT                               ! Input integer (int32): n_element.
      INTEGER(I8), INTENT(IN) :: N_POINT                                 ! Input integer (int64): n_point.

      ALLOCATE(LAYOUT%ELEMENT_FIRST(N_ELEMENT))                          ! Allocate memory for layout.element_first(n_element).
      ALLOCATE(LAYOUT%ELEMENT_LAST(N_ELEMENT))                           ! Allocate memory for layout.element_last(n_element).
      ALLOCATE(LAYOUT%ELEMENT_INDEX(N_POINT))                            ! Allocate memory for layout.element_index(n_point).
      ALLOCATE(LAYOUT%EXPANSION_ELEMENT_INDEX(N_POINT))                  ! Allocate memory for layout.expansion_element_index(n_point).
      ALLOCATE(LAYOUT%STRUCTURAL_RULE_INDEX(N_POINT))                    ! Allocate memory for layout.structural_rule_index(n_point).
      ALLOCATE(LAYOUT%STRUCTURAL_POINT_INDEX(N_POINT))                   ! Allocate memory for layout.structural_point_index(n_point).
      ALLOCATE(LAYOUT%EXPANSION_RULE_INDEX(N_POINT))                     ! Allocate memory for layout.expansion_rule_index(n_point).
      ALLOCATE(LAYOUT%EXPANSION_POINT_INDEX(N_POINT))                    ! Allocate memory for layout.expansion_point_index(n_point).
      ALLOCATE(LAYOUT%LAMINATION_ID(N_POINT))                            ! Allocate memory for layout.lamination_id(n_point).
      ALLOCATE(LAYOUT%REFERENCE_WEIGHT(N_POINT))                         ! Allocate memory for layout.reference_weight(n_point).
      LAYOUT%ELEMENT_FIRST = 0_I8                                        ! Set layout.element_first to zero.
      LAYOUT%ELEMENT_LAST = 0_I8                                         ! Set layout.element_last to zero.

      END SUBROUTINE ALLOCATE_LAYOUT                                     ! End of the subroutine allocate layout.

      SUBROUTINE CLEAR_LAYOUT(LAYOUT)                                    ! Subroutine clear layout takes layout.

      TYPE(GAUSS_LAYOUT_TYPE), INTENT(INOUT) :: LAYOUT                   ! In/out of type gauss_layout_type: layout.

      IF (ALLOCATED(LAYOUT%ELEMENT_FIRST))                               ! If allocated(layout.element_first), free the memory of layout.element_first.
     &  DEALLOCATE(LAYOUT%ELEMENT_FIRST)
      IF (ALLOCATED(LAYOUT%ELEMENT_LAST))                                ! If allocated(layout.element_last), free the memory of layout.element_last.
     &  DEALLOCATE(LAYOUT%ELEMENT_LAST)
      IF (ALLOCATED(LAYOUT%ELEMENT_INDEX))                               ! If allocated(layout.element_index), free the memory of layout.element_index.
     &  DEALLOCATE(LAYOUT%ELEMENT_INDEX)
      IF (ALLOCATED(LAYOUT%EXPANSION_ELEMENT_INDEX))                     ! If allocated(layout.expansion_element_index), free the memory of layout.expansion_element_index.
     &  DEALLOCATE(LAYOUT%EXPANSION_ELEMENT_INDEX)
      IF (ALLOCATED(LAYOUT%STRUCTURAL_RULE_INDEX))                       ! If allocated(layout.structural_rule_index), free the memory of layout.structural_rule_index.
     &  DEALLOCATE(LAYOUT%STRUCTURAL_RULE_INDEX)
      IF (ALLOCATED(LAYOUT%STRUCTURAL_POINT_INDEX))                      ! If allocated(layout.structural_point_index), free the memory of layout.structural_point_index.
     &  DEALLOCATE(LAYOUT%STRUCTURAL_POINT_INDEX)
      IF (ALLOCATED(LAYOUT%EXPANSION_RULE_INDEX))                        ! If allocated(layout.expansion_rule_index), free the memory of layout.expansion_rule_index.
     &  DEALLOCATE(LAYOUT%EXPANSION_RULE_INDEX)
      IF (ALLOCATED(LAYOUT%EXPANSION_POINT_INDEX))                       ! If allocated(layout.expansion_point_index), free the memory of layout.expansion_point_index.
     &  DEALLOCATE(LAYOUT%EXPANSION_POINT_INDEX)
      IF (ALLOCATED(LAYOUT%LAMINATION_ID))                               ! If allocated(layout.lamination_id), free the memory of layout.lamination_id.
     &  DEALLOCATE(LAYOUT%LAMINATION_ID)
      IF (ALLOCATED(LAYOUT%REFERENCE_WEIGHT))                            ! If allocated(layout.reference_weight), free the memory of layout.reference_weight.
     &  DEALLOCATE(LAYOUT%REFERENCE_WEIGHT)
      LAYOUT%COUNT = 0_I8                                                ! Set layout.count to zero.

      END SUBROUTINE CLEAR_LAYOUT                                        ! End of the subroutine clear layout.

      END MODULE MUL2_GAUSS_POINTS                                       ! End of the module mul2 gauss points.
