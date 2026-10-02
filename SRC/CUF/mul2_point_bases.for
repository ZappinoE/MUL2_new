!=======================================================================
!  EVALUATE ONE FIELD-DEPENDENT CUF X FEM BASIS AT A POINT.
!
!  THE BASIS IS THE PRODUCT  PHI = N_STRUCTURAL * F_EXPANSION.
!    EVALUATE_EXPANSION_FACTOR  F AND ITS GRADIENT AT AN EXPANSION POINT
!    EVALUATE_FIELD_BASIS       COMPOSES PHI FROM GIVEN N, GRAD N, F, GRAD F
!    EVALUATE_POINT_FACTORS     N, GRAD N, F, GRAD F AT A CACHED GAUSS POINT
!    EVALUATE_POINT_BASIS       PHI AT A CACHED GAUSS POINT
!  THE SAME COMPOSITION RULE SERVES CACHED GAUSS POINTS, ARBITRARY POST
!  POINTS AND THE TYING POINTS OF THE SHEAR-LOCKING CORRECTIONS.
!=======================================================================
      MODULE MUL2_POINT_BASES                                            ! Module mul2 point bases begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       SET_ERROR, STATUS_IS_OK
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE,                ! Use from module mul2 expansion meshes: expansion db type, expansion mesh type, find expansion index.
     &                                 EXPANSION_MESH_TYPE,
     &                                 FIND_EXPANSION_INDEX
      USE MUL2_KINEMATICS, ONLY: EXPANSION_SPEC_TYPE,                    ! Use from module mul2 kinematics: expansion spec type, expansion te, expansion le, expansion hle, expansion ...
     &     EXPANSION_TE, EXPANSION_LE, EXPANSION_HLE,
     &     EXPANSION_MISC, EXPANSION_NONE
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type.
     &                             GAUSS_LAYOUT_TYPE
      USE MUL2_GAUSS_GEOMETRY, ONLY:                                     ! Use from module mul2 gauss geometry: structural geometry cache type, expansion geometry cache type, gauss g...
     &     STRUCTURAL_GEOMETRY_CACHE_TYPE,
     &     EXPANSION_GEOMETRY_CACHE_TYPE, GAUSS_GEOMETRY_TYPE
      USE MUL2_CUF_BASES, ONLY: EVALUATE_TAYLOR_TERM                     ! Use from module mul2 cuf bases: evaluate taylor term.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_FUNCTION_COUNT                 ! Use from module mul2 topologies: topology function count.
      USE MUL2_LINEAR_KINEMATICS, ONLY: COMPOSE_PRODUCT_BASIS            ! Use from module mul2 linear kinematics: compose product basis.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: EVALUATE_POINT_BASIS                                     ! Export: evaluate point basis.
      PUBLIC :: EVALUATE_POINT_FACTORS                                   ! Export: evaluate point factors.
      PUBLIC :: EVALUATE_FIELD_BASIS                                     ! Export: evaluate field basis.
      PUBLIC :: EVALUATE_EXPANSION_FACTOR                                ! Export: evaluate expansion factor.

      CONTAINS                                                           ! The procedures of the module follow.

!  N, GRAD N (STRUCTURAL NODE) AND F, GRAD F (EXPANSION TERM) AT A
!  CACHED GAUSS POINT.
      SUBROUTINE EVALUATE_POINT_FACTORS(POINT, STRUCTURAL_NODE,          ! Subroutine evaluate point factors takes point, structural node, term, spec, elements, expansions, rules, la...
     &     TERM, SPEC, ELEMENTS, EXPANSIONS, RULES, LAYOUT,
     &     STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY,
     &     STRUCTURAL_VALUE, STRUCTURAL_GRADIENT,
     &     FACTOR_VALUE, FACTOR_GRADIENT, STATUS)

      INTEGER(I8), INTENT(IN) :: POINT                                   ! Input integer (int64): point.
      INTEGER(I4), INTENT(IN) :: STRUCTURAL_NODE                         ! Input integer (int32): structural_node.
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.
      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: SPEC                      ! Input of type expansion_spec_type: spec.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: LAYOUT                      ! Input of type gauss_layout_type: layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      REAL(R8), INTENT(OUT) :: STRUCTURAL_VALUE                          ! Output real (real64): structural_value.
      REAL(R8), INTENT(OUT) :: STRUCTURAL_GRADIENT(3)                    ! Output real (real64): structural_gradient(3).
      REAL(R8), INTENT(OUT) :: FACTOR_VALUE                              ! Output real (real64): factor_value.
      REAL(R8), INTENT(OUT) :: FACTOR_GRADIENT(3)                        ! Output real (real64): factor_gradient(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: STRUCTURAL_CACHE_INDEX                              ! Integer (int64): structural_cache_index.
      INTEGER(I8) :: EXPANSION_CACHE_INDEX                               ! Integer (int64): expansion_cache_index.
      INTEGER(I8) :: DERIVATIVE_ENTRY                                    ! Integer (int64): derivative_entry.
      INTEGER(I4) :: ELEMENT_INDEX                                       ! Integer (int32): element_index.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: EXPANSION_ELEMENT_INDEX                             ! Integer (int32): expansion_element_index.
      INTEGER(I4) :: STRUCTURAL_RULE_INDEX                               ! Integer (int32): structural_rule_index.
      INTEGER(I4) :: EXPANSION_RULE_INDEX                                ! Integer (int32): expansion_rule_index.
      INTEGER(I4) :: STRUCTURAL_POINT_INDEX                              ! Integer (int32): structural_point_index.
      INTEGER(I4) :: EXPANSION_POINT_INDEX                               ! Integer (int32): expansion_point_index.
      INTEGER(I4) :: EXPANSION_DIMENSION                                 ! Integer (int32): expansion_dimension.
      INTEGER(I4) :: N_LOCAL                                             ! Integer (int32): n_local.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      STRUCTURAL_VALUE = 0.0_R8                                          ! Set structural_value to zero.
      STRUCTURAL_GRADIENT = 0.0_R8                                       ! Set structural_gradient to zero.
      FACTOR_VALUE = 0.0_R8                                              ! Set factor_value to zero.
      FACTOR_GRADIENT = 0.0_R8                                           ! Set factor_gradient to zero.
      IF (POINT .LT. 1_I8 .OR. POINT .GT. LAYOUT%COUNT .OR.              ! If point < 1 or point > layout.count or point > geometry.count:
     &    POINT .GT. GEOMETRY%COUNT) THEN
        CALL SET_ERROR(STATUS, 'EVALUATE_POINT_FACTORS',                 ! Record an error in status: 'GAUSS POINT IS OUT OF RANGE'.
     &                 'GAUSS POINT IS OUT OF RANGE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (SPEC%FAMILY .EQ. EXPANSION_NONE) RETURN                        ! If spec.family = expansion_none, return to the caller.

      ELEMENT_INDEX = LAYOUT%ELEMENT_INDEX(POINT)                        ! Set element_index to layout.element_index(point).
      STRUCTURAL_RULE_INDEX = LAYOUT%STRUCTURAL_RULE_INDEX(POINT)        ! Set structural_rule_index to layout.structural_rule_index(point).
      STRUCTURAL_POINT_INDEX =                                           ! Set structural_point_index to layout.structural_point_index(point).
     & LAYOUT%STRUCTURAL_POINT_INDEX(POINT)
      IF (STRUCTURAL_NODE .LT. 1_I4 .OR. STRUCTURAL_NODE .GT.            ! If structural_node < 1 or structural_node > size(elements.item(element_index).node_id):
     &    SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID)) THEN
        CALL SET_ERROR(STATUS, 'EVALUATE_POINT_FACTORS',                 ! Record an error in status: 'STRUCTURAL NODE IS OUT OF RANGE'.
     &                 'STRUCTURAL NODE IS OUT OF RANGE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      STRUCTURAL_CACHE_INDEX =                                           ! Set structural_cache_index to geometry.structural_cache_index(point).
     & GEOMETRY%STRUCTURAL_CACHE_INDEX(POINT)
      STRUCTURAL_VALUE = RULES%ITEM(STRUCTURAL_RULE_INDEX)%              ! Set structural_value to rules.item(structural_rule_index). shape(structural_node,structural_point_index).
     & SHAPE(STRUCTURAL_NODE,STRUCTURAL_POINT_INDEX)
      DERIVATIVE_ENTRY = STRUCTURAL_CACHE%DERIVATIVE_OFFSET(             ! Set derivative_entry to structural_cache.derivative_offset( structural_cache_index)+structural_node-1.
     & STRUCTURAL_CACHE_INDEX)+STRUCTURAL_NODE-1_I8
      STRUCTURAL_GRADIENT = STRUCTURAL_CACHE%                            ! Set structural_gradient to structural_cache. derivative_local(:,derivative_entry).
     & DERIVATIVE_LOCAL(:,DERIVATIVE_ENTRY)

      MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,                      ! Set mesh_index to find_expansion_index(expansions, elements.item(element_index).expansion_id).
     & ELEMENTS%ITEM(ELEMENT_INDEX)%EXPANSION_ID)
      IF (MESH_INDEX .EQ. 0_I4) THEN                                     ! If mesh_index = 0:
        CALL SET_ERROR(STATUS, 'EVALUATE_POINT_FACTORS',                 ! Record an error in status: 'EXPANSION MESH IS MISSING'.
     &                 'EXPANSION MESH IS MISSING')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      EXPANSION_RULE_INDEX = LAYOUT%EXPANSION_RULE_INDEX(POINT)          ! Set expansion_rule_index to layout.expansion_rule_index(point).
      EXPANSION_POINT_INDEX = LAYOUT%EXPANSION_POINT_INDEX(POINT)        ! Set expansion_point_index to layout.expansion_point_index(point).
      EXPANSION_ELEMENT_INDEX =                                          ! Set expansion_element_index to layout.expansion_element_index(point).
     & LAYOUT%EXPANSION_ELEMENT_INDEX(POINT)
      EXPANSION_CACHE_INDEX =                                            ! Set expansion_cache_index to geometry.expansion_cache_index(point).
     & GEOMETRY%EXPANSION_CACHE_INDEX(POINT)
      EXPANSION_DIMENSION = RULES%ITEM(EXPANSION_RULE_INDEX)%            ! Set expansion_dimension to rules.item(expansion_rule_index). natural_dimension.
     & NATURAL_DIMENSION
      N_LOCAL = TOPOLOGY_FUNCTION_COUNT(EXPANSIONS%ITEM(MESH_INDEX)%     ! Set n_local to topology_function_count(expansions.item(mesh_index). element(expansion_element_index).topolo...
     &               ELEMENT(EXPANSION_ELEMENT_INDEX)%TOPOLOGY)
      DERIVATIVE_ENTRY = EXPANSION_CACHE%DERIVATIVE_OFFSET(              ! Set derivative_entry to expansion_cache.derivative_offset( expansion_cache_index).
     & EXPANSION_CACHE_INDEX)

      CALL EVALUATE_EXPANSION_FACTOR(SPEC, TERM,                         ! Call evaluate expansion factor with spec, term, expansions.item(mesh_index), expansion_element_index, expan...
     &     EXPANSIONS%ITEM(MESH_INDEX), EXPANSION_ELEMENT_INDEX,
     &     EXPANSION_DIMENSION, EXPANSION_CACHE%ACTIVE_AXIS(
     &     1:2,MESH_INDEX), EXPANSION_CACHE%COORDINATE_LOCAL(
     &     :,EXPANSION_CACHE_INDEX),
     &     RULES%ITEM(EXPANSION_RULE_INDEX)%
     &     SHAPE(1:N_LOCAL,EXPANSION_POINT_INDEX),
     &     EXPANSION_CACHE%DERIVATIVE_LOCAL(
     &     :,DERIVATIVE_ENTRY:DERIVATIVE_ENTRY+N_LOCAL-1_I8),
     &     FACTOR_VALUE, FACTOR_GRADIENT, STATUS)

      END SUBROUTINE EVALUATE_POINT_FACTORS                              ! End of the subroutine evaluate point factors.

      SUBROUTINE EVALUATE_POINT_BASIS(POINT, STRUCTURAL_NODE,            ! Subroutine evaluate point basis takes point, structural node, term, spec, elements, expansions, rules, layo...
     &     TERM, SPEC, ELEMENTS, EXPANSIONS, RULES, LAYOUT,
     &     STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY,
     &     VALUE, GRADIENT, STATUS)

      INTEGER(I8), INTENT(IN) :: POINT                                   ! Input integer (int64): point.
      INTEGER(I4), INTENT(IN) :: STRUCTURAL_NODE                         ! Input integer (int32): structural_node.
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.
      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: SPEC                      ! Input of type expansion_spec_type: spec.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: LAYOUT                      ! Input of type gauss_layout_type: layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      REAL(R8), INTENT(OUT) :: VALUE                                     ! Output real (real64): value.
      REAL(R8), INTENT(OUT) :: GRADIENT(3)                               ! Output real (real64): gradient(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: STRUCTURAL_VALUE                                       ! Real (real64): structural_value.
      REAL(R8) :: STRUCTURAL_GRADIENT(3)                                 ! Real (real64): structural_gradient(3).
      REAL(R8) :: FACTOR_VALUE                                           ! Real (real64): factor_value.
      REAL(R8) :: FACTOR_GRADIENT(3)                                     ! Real (real64): factor_gradient(3).

      CALL EVALUATE_POINT_FACTORS(POINT, STRUCTURAL_NODE, TERM, SPEC,    ! Call evaluate point factors with point, structural_node, term, spec, elements, expansions, rules, layout, s...
     &     ELEMENTS, EXPANSIONS, RULES, LAYOUT, STRUCTURAL_CACHE,
     &     EXPANSION_CACHE, GEOMETRY, STRUCTURAL_VALUE,
     &     STRUCTURAL_GRADIENT, FACTOR_VALUE, FACTOR_GRADIENT, STATUS)
      VALUE = 0.0_R8                                                     ! Set value to zero.
      GRADIENT = 0.0_R8                                                  ! Set gradient to zero.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (SPEC%FAMILY .EQ. EXPANSION_NONE) RETURN                        ! If spec.family = expansion_none, return to the caller.
      CALL COMPOSE_PRODUCT_BASIS(STRUCTURAL_VALUE,                       ! Call compose product basis with structural_value, structural_gradient, factor_value, factor_gradient, value...
     &     STRUCTURAL_GRADIENT, FACTOR_VALUE, FACTOR_GRADIENT,
     &     VALUE, GRADIENT)

      END SUBROUTINE EVALUATE_POINT_BASIS                                ! End of the subroutine evaluate point basis.

!  ONE SCALAR BASIS TERM OF ONE FIELD AT ONE POINT.
!    STRUCTURAL_VALUE/GRADIENT: N_I AND ITS LOCAL-FRAME GRADIENT.
!    EXPANSION_SHAPE(:):        SHAPES OF THE EXPANSION ELEMENT NODES.
!    EXPANSION_GRADIENT(3,:):   THEIR LOCAL-FRAME GRADIENTS.
!    COORDINATE_LOCAL:          LOCAL COORDINATE OF THE EXPANSION POINT.
      SUBROUTINE EVALUATE_FIELD_BASIS(SPEC, TERM,                        ! Subroutine evaluate field basis takes spec, term, structural value, structural gradient, mesh, expansion el...
     &     STRUCTURAL_VALUE, STRUCTURAL_GRADIENT, MESH,
     &     EXPANSION_ELEMENT_INDEX, EXPANSION_DIMENSION,
     &     ACTIVE_AXIS, COORDINATE_LOCAL, EXPANSION_SHAPE,
     &     EXPANSION_GRADIENT, VALUE, GRADIENT, STATUS)

      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: SPEC                      ! Input of type expansion_spec_type: spec.
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.
      REAL(R8), INTENT(IN) :: STRUCTURAL_VALUE                           ! Input real (real64): structural_value.
      REAL(R8), INTENT(IN) :: STRUCTURAL_GRADIENT(3)                     ! Input real (real64): structural_gradient(3).
      TYPE(EXPANSION_MESH_TYPE), INTENT(IN) :: MESH                      ! Input of type expansion_mesh_type: mesh.
      INTEGER(I4), INTENT(IN) :: EXPANSION_ELEMENT_INDEX                 ! Input integer (int32): expansion_element_index.
      INTEGER(I4), INTENT(IN) :: EXPANSION_DIMENSION                     ! Input integer (int32): expansion_dimension.
      INTEGER(I4), INTENT(IN) :: ACTIVE_AXIS(2)                          ! Input integer (int32): active_axis(2).
      REAL(R8), INTENT(IN) :: COORDINATE_LOCAL(3)                        ! Input real (real64): coordinate_local(3).
      REAL(R8), INTENT(IN) :: EXPANSION_SHAPE(:)                         ! Input real (real64): expansion_shape(:).
      REAL(R8), INTENT(IN) :: EXPANSION_GRADIENT(:,:)                    ! Input real (real64): expansion_gradient(:,:).
      REAL(R8), INTENT(OUT) :: VALUE                                     ! Output real (real64): value.
      REAL(R8), INTENT(OUT) :: GRADIENT(3)                               ! Output real (real64): gradient(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: FACTOR_VALUE                                           ! Real (real64): factor_value.
      REAL(R8) :: FACTOR_GRADIENT(3)                                     ! Real (real64): factor_gradient(3).

      VALUE = 0.0_R8                                                     ! Set value to zero.
      GRADIENT = 0.0_R8                                                  ! Set gradient to zero.
      CALL EVALUATE_EXPANSION_FACTOR(SPEC, TERM, MESH,                   ! Call evaluate expansion factor with spec, term, mesh, expansion_element_index, expansion_dimension, active_...
     &     EXPANSION_ELEMENT_INDEX, EXPANSION_DIMENSION, ACTIVE_AXIS,
     &     COORDINATE_LOCAL, EXPANSION_SHAPE, EXPANSION_GRADIENT,
     &     FACTOR_VALUE, FACTOR_GRADIENT, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (SPEC%FAMILY .EQ. EXPANSION_NONE) RETURN                        ! If spec.family = expansion_none, return to the caller.
      CALL COMPOSE_PRODUCT_BASIS(STRUCTURAL_VALUE,                       ! Call compose product basis with structural_value, structural_gradient, factor_value, factor_gradient, value...
     &     STRUCTURAL_GRADIENT, FACTOR_VALUE, FACTOR_GRADIENT,
     &     VALUE, GRADIENT)

      END SUBROUTINE EVALUATE_FIELD_BASIS                                ! End of the subroutine evaluate field basis.

!  THE EXPANSION FACTOR F_TAU AND ITS LOCAL GRADIENT.
      SUBROUTINE EVALUATE_EXPANSION_FACTOR(SPEC, TERM, MESH,             ! Subroutine evaluate expansion factor takes spec, term, mesh, expansion element index, expansion dimension, ...
     &     EXPANSION_ELEMENT_INDEX, EXPANSION_DIMENSION,
     &     ACTIVE_AXIS, COORDINATE_LOCAL, EXPANSION_SHAPE,
     &     EXPANSION_GRADIENT, FACTOR_VALUE, FACTOR_GRADIENT, STATUS)

      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: SPEC                      ! Input of type expansion_spec_type: spec.
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.
      TYPE(EXPANSION_MESH_TYPE), INTENT(IN) :: MESH                      ! Input of type expansion_mesh_type: mesh.
      INTEGER(I4), INTENT(IN) :: EXPANSION_ELEMENT_INDEX                 ! Input integer (int32): expansion_element_index.
      INTEGER(I4), INTENT(IN) :: EXPANSION_DIMENSION                     ! Input integer (int32): expansion_dimension.
      INTEGER(I4), INTENT(IN) :: ACTIVE_AXIS(2)                          ! Input integer (int32): active_axis(2).
      REAL(R8), INTENT(IN) :: COORDINATE_LOCAL(3)                        ! Input real (real64): coordinate_local(3).
      REAL(R8), INTENT(IN) :: EXPANSION_SHAPE(:)                         ! Input real (real64): expansion_shape(:).
      REAL(R8), INTENT(IN) :: EXPANSION_GRADIENT(:,:)                    ! Input real (real64): expansion_gradient(:,:).
      REAL(R8), INTENT(OUT) :: FACTOR_VALUE                              ! Output real (real64): factor_value.
      REAL(R8), INTENT(OUT) :: FACTOR_GRADIENT(3)                        ! Output real (real64): factor_gradient(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: TARGET_NODE_ID                                      ! Integer (int64): target_node_id.
      INTEGER(I4) :: LOCAL_NODE                                          ! Integer (int32): local_node.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      FACTOR_VALUE = 0.0_R8                                              ! Set factor_value to zero.
      FACTOR_GRADIENT = 0.0_R8                                           ! Set factor_gradient to zero.
      IF (SPEC%FAMILY .EQ. EXPANSION_NONE) RETURN                        ! If spec.family = expansion_none, return to the caller.
      IF (SPEC%FAMILY .EQ. EXPANSION_MISC) THEN                          ! If spec.family = expansion_misc:
        CALL SET_ERROR(STATUS, 'EVALUATE_EXPANSION_FACTOR',              ! Record an error in status: 'M BASIS IS NOT IMPLEMENTED YET'.
     &                 'M BASIS IS NOT IMPLEMENTED YET')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      SELECT CASE(SPEC%FAMILY)                                           ! Choose according to the value of spec.family:
      CASE(EXPANSION_TE)                                                 ! Case expansion_te:
        CALL EVALUATE_TAYLOR_TERM(SPEC%ORDER, EXPANSION_DIMENSION,       ! Call evaluate taylor term with spec.order, expansion_dimension, active_axis, coordinate_local, term, factor...
     &       ACTIVE_AXIS, COORDINATE_LOCAL, TERM,
     &       FACTOR_VALUE, FACTOR_GRADIENT, STATUS)
      CASE(EXPANSION_LE)                                                 ! Case expansion_le:
        IF (TERM .LT. 1_I4 .OR. TERM .GT. SIZE(MESH%NODE)) THEN          ! If term < 1 or term > size(mesh.node):
          CALL SET_ERROR(STATUS, 'EVALUATE_EXPANSION_FACTOR',            ! Record an error in status: 'LE TERM IS OUT OF RANGE'.
     &                   'LE TERM IS OUT OF RANGE')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        TARGET_NODE_ID = MESH%NODE(TERM)%ID                              ! Set target_node_id to mesh.node(term).id.
        LOCAL_NODE = 0_I4                                                ! Set local_node to zero.
        DO I = 1_I4, SIZE(MESH%ELEMENT(                                  ! Loop i from 1 to size(mesh.element( expansion_element_index).node_id):
     &                    EXPANSION_ELEMENT_INDEX)%NODE_ID)
          IF (MESH%ELEMENT(EXPANSION_ELEMENT_INDEX)%NODE_ID(I)           ! If mesh.element(expansion_element_index).node_id(i) = target_node_id:
     &        .EQ. TARGET_NODE_ID) THEN
            LOCAL_NODE = I                                               ! Set local_node to i.
            EXIT                                                         ! Leave the loop.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
!       A LAGRANGE TERM OUTSIDE THE ACTIVE SUB-ELEMENT IS ZERO THERE.
        IF (LOCAL_NODE .EQ. 0_I4) RETURN                                 ! If local_node = 0, return to the caller.
        FACTOR_VALUE = EXPANSION_SHAPE(LOCAL_NODE)                       ! Set factor_value to expansion_shape(local_node).
        FACTOR_GRADIENT = EXPANSION_GRADIENT(:,LOCAL_NODE)               ! Set factor_gradient to expansion_gradient(:,local_node).
      CASE(EXPANSION_HLE)                                                ! Case expansion_hle:
        IF (TERM .LT. 1_I4 .OR. TERM .GT. MESH%N_TERM) THEN              ! If term < 1 or term > mesh.n_term:
          CALL SET_ERROR(STATUS, 'EVALUATE_EXPANSION_FACTOR',            ! Record an error in status: 'HLE TERM IS OUT OF RANGE'.
     &                   'HLE TERM IS OUT OF RANGE')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
!       A MODE OUTSIDE THE ACTIVE SUB-ELEMENT (OR OMITTED BY THE ORDER
!       OF AN ADJACENT SUB-ELEMENT) IS ZERO THERE.
        DO I = 1_I4, SIZE(MESH%ELEMENT(EXPANSION_ELEMENT_INDEX)%         ! Loop i from 1 to size(mesh.element(expansion_element_index). mode_term):
     &                    MODE_TERM)
          IF (MESH%ELEMENT(EXPANSION_ELEMENT_INDEX)%MODE_TERM(I)         ! If mesh.element(expansion_element_index).mode_term(i) = term:
     &        .EQ. TERM) THEN
            FACTOR_VALUE = MESH%ELEMENT(EXPANSION_ELEMENT_INDEX)%        ! Set factor_value to mesh.element(expansion_element_index). mode_sign(i)*expansion_shape(i).
     &                     MODE_SIGN(I)*EXPANSION_SHAPE(I)
            FACTOR_GRADIENT = MESH%ELEMENT(EXPANSION_ELEMENT_INDEX)%     ! Set factor_gradient to mesh.element(expansion_element_index). mode_sign(i)*expansion_gradient(:,i).
     &                        MODE_SIGN(I)*EXPANSION_GRADIENT(:,I)
            EXIT                                                         ! Leave the loop.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      CASE DEFAULT                                                       ! In every other case:
        CALL SET_ERROR(STATUS, 'EVALUATE_EXPANSION_FACTOR',              ! Record an error in status: 'UNKNOWN EXPANSION FAMILY'.
     &                 'UNKNOWN EXPANSION FAMILY')
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE EVALUATE_EXPANSION_FACTOR                           ! End of the subroutine evaluate expansion factor.

      END MODULE MUL2_POINT_BASES                                        ! End of the module mul2 point bases.
