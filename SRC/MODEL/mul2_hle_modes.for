!=======================================================================
!  GLOBAL TERMS OF A HIERARCHICAL LEGENDRE (HLE) EXPANSION MESH.
!
!  EVERY SUB-ELEMENT CARRIES ITS OWN POLYNOMIAL ORDER. THE GLOBAL TERMS
!  (THE DEGREES OF FREEDOM OF ONE STRUCTURAL NODE AND FIELD) ARE
!    FIRST      VERTEX MODES, ONE PER NODE THAT IS A VERTEX OF A
!               SUB-ELEMENT (THE NODAL VALUE); NODES THAT ONLY DESCRIBE A
!               CURVED SIDE CARRY NO TERM (MESH%NODE_TERM = 0);
!    NEXT       SIDE MODES: ONE GROUP FOR EVERY GEOMETRIC SIDE (PAIR OF
!               NODES), MODES K = 2..PMIN, PMIN BEING THE LOWEST ORDER
!               OF THE SUB-ELEMENTS THAT SHARE THE SIDE;
!    LAST       INTERNAL MODES, OWNED BY ONE SUB-ELEMENT.
!  A SIDE MODE OF A SUB-ELEMENT OF HIGHER ORDER THAN ITS NEIGHBOUR IS
!  OMITTED (CONSTRAINED TO ZERO): THE TRACE ON THE SHARED SIDE IS THEN
!  A POLYNOMIAL OF THE LOWER DEGREE ON BOTH SIDES, SO THE FIELD STAYS
!  C0. THE SIDE FUNCTIONS HAVE THE PARITY (-1)**K, SO A SUB-ELEMENT
!  WHOSE LOCAL SIDE DIRECTION IS OPPOSITE TO THE GLOBAL ONE (FROM THE
!  LOWER TO THE HIGHER NODE ID) USES THE SIGN (-1)**K.
!=======================================================================
      MODULE MUL2_HLE_MODES                                              ! Module mul2 hle modes begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_IS_HLE, TOPOLOGY_HLE_ORDER,    ! Use from module mul2 topologies: topology is hle, topology hle order, topology hq base.
     &                           TOPOLOGY_HQ_BASE
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_MESH_TYPE               ! Use from module mul2 expansion meshes: expansion mesh type.
      USE MUL2_HLE_SHAPE, ONLY: HLE_INTERNAL, HLE_SIDE,                  ! Use from module mul2 hle shape: hle internal, hle side, hle function count, hle mode list, hle side ends.
     &                          HLE_FUNCTION_COUNT, HLE_MODE_LIST,
     &                          HLE_SIDE_ENDS

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: BUILD_HLE_MESH                                           ! Export: build hle mesh.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_HLE_MESH(MESH, STATUS)                            ! Subroutine build hle mesh takes mesh, status.

      TYPE(EXPANSION_MESH_TYPE), INTENT(INOUT) :: MESH                   ! In/out of type expansion_mesh_type: mesh.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I4), ALLOCATABLE :: POSITION(:,:)                          ! Allocatable integer (int32): position(:,:).
      INTEGER(I4), ALLOCATABLE :: ELEMENT_EDGE(:,:)                      ! Allocatable integer (int32): element_edge(:,:).
      LOGICAL, ALLOCATABLE :: ELEMENT_REVERSED(:,:)                      ! Allocatable logical: element_reversed(:,:).
      INTEGER(I4), ALLOCATABLE :: EDGE_NODE(:,:)                         ! Allocatable integer (int32): edge_node(:,:).
      INTEGER(I4), ALLOCATABLE :: EDGE_ORDER(:)                          ! Allocatable integer (int32): edge_order(:).
      INTEGER(I4), ALLOCATABLE :: EDGE_FIRST(:)                          ! Allocatable integer (int32): edge_first(:).
      INTEGER(I4), ALLOCATABLE :: MKIND(:)                               ! Allocatable integer (int32): mkind(:).
      INTEGER(I4), ALLOCATABLE :: A(:)                                   ! Allocatable integer (int32): a(:).
      INTEGER(I4), ALLOCATABLE :: B(:)                                   ! Allocatable integer (int32): b(:).
      INTEGER(I4) :: N_ELEMENT                                           ! Integer (int32): n_element.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: N_VTERM                                             ! Integer (int32): n_vterm.
      INTEGER(I4) :: N_HLE                                               ! Integer (int32): n_hle.
      INTEGER(I4) :: N_QUAD                                              ! Integer (int32): n_quad.
      INTEGER(I4) :: N_EDGE                                              ! Integer (int32): n_edge.
      INTEGER(I4) :: N_TERM                                              ! Integer (int32): n_term.
      INTEGER(I4) :: N_VERTEX                                            ! Integer (int32): n_vertex.
      INTEGER(I4) :: N_FUNCTION                                          ! Integer (int32): n_function.
      INTEGER(I4) :: ORDER                                               ! Integer (int32): order.
      INTEGER(I4) :: START                                               ! Integer (int32): start.
      INTEGER(I4) :: FINISH                                              ! Integer (int32): finish.
      INTEGER(I4) :: LOW                                                 ! Integer (int32): low.
      INTEGER(I4) :: HIGH                                                ! Integer (int32): high.
      INTEGER(I4) :: EDGE                                                ! Integer (int32): edge.
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: V                                                   ! Integer (int32): v.
      INTEGER(I4) :: S                                                   ! Integer (int32): s.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      LOGICAL :: QUAD                                                    ! Logical: quad.

      MESH%IS_HLE = .FALSE.                                              ! Set the flag mesh.is_hle to false.
      MESH%N_TERM = 0_I4                                                 ! Set mesh.n_term to zero.
      IF (ALLOCATED(MESH%TERM_NODE)) DEALLOCATE(MESH%TERM_NODE)          ! If allocated(mesh.term_node), free the memory of mesh.term_node.
      IF (ALLOCATED(MESH%TERM_OWNER)) DEALLOCATE(MESH%TERM_OWNER)        ! If allocated(mesh.term_owner), free the memory of mesh.term_owner.
      IF (ALLOCATED(MESH%NODE_TERM)) DEALLOCATE(MESH%NODE_TERM)          ! If allocated(mesh.node_term), free the memory of mesh.node_term.
      N_ELEMENT = SIZE(MESH%ELEMENT)                                     ! Set n_element to the size of mesh.element.
      N_NODE = SIZE(MESH%NODE)                                           ! Set n_node to the size of mesh.node.
      N_HLE = 0_I4                                                       ! Set n_hle to zero.
      N_QUAD = 0_I4                                                      ! Set n_quad to zero.
      DO E = 1_I4, N_ELEMENT                                             ! Loop e from 1 to n_element:
        IF (TOPOLOGY_IS_HLE(MESH%ELEMENT(E)%TOPOLOGY)) THEN              ! If topology_is_hle(mesh.element(e).topology):
          N_HLE = N_HLE + 1_I4                                           ! Add 1 to n_hle.
          IF (MESH%ELEMENT(E)%TOPOLOGY .GT. TOPOLOGY_HQ_BASE)            ! If mesh.element(e).topology > topology_hq_base, add 1 to n_quad.
     &      N_QUAD = N_QUAD + 1_I4
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      IF (N_HLE .EQ. 0_I4) RETURN                                        ! If n_hle = 0, return to the caller.
      IF (N_HLE .NE. N_ELEMENT .OR.                                      ! If n_hle /= n_element or (n_quad /= 0 and n_quad /= n_element):
     &    (N_QUAD .NE. 0_I4 .AND. N_QUAD .NE. N_ELEMENT)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_HLE_MESH',                         ! Record an error in status: 'HLE SUB-ELEMENTS CANNOT BE MIXED WITH OTHER TOPOLOGIES'.
     &    'HLE SUB-ELEMENTS CANNOT BE MIXED WITH OTHER TOPOLOGIES')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      QUAD = N_QUAD .GT. 0_I4                                            ! Set quad to n_quad > 0.
      N_VERTEX = 2_I4                                                    ! Set n_vertex to 2.
      IF (QUAD) N_VERTEX = 4_I4                                          ! If quad, set n_vertex to 4.

      ALLOCATE(POSITION(N_VERTEX,N_ELEMENT))                             ! Allocate memory for position(n_vertex,n_element).
      ALLOCATE(ELEMENT_EDGE(4,N_ELEMENT))                                ! Allocate memory for element_edge(4,n_element).
      ALLOCATE(ELEMENT_REVERSED(4,N_ELEMENT))                            ! Allocate memory for element_reversed(4,n_element).
      ALLOCATE(EDGE_NODE(2,4*N_ELEMENT))                                 ! Allocate memory for edge_node(2,4*n_element).
      ALLOCATE(EDGE_ORDER(4*N_ELEMENT))                                  ! Allocate memory for edge_order(4*n_element).
      ALLOCATE(EDGE_FIRST(4*N_ELEMENT))                                  ! Allocate memory for edge_first(4*n_element).
      ELEMENT_EDGE = 0_I4                                                ! Set element_edge to zero.
      ELEMENT_REVERSED = .FALSE.                                         ! Set the flag element_reversed to false.
      N_EDGE = 0_I4                                                      ! Set n_edge to zero.

      DO E = 1_I4, N_ELEMENT                                             ! Loop e from 1 to n_element:
        ORDER = TOPOLOGY_HLE_ORDER(MESH%ELEMENT(E)%TOPOLOGY)             ! Set order to topology_hle_order(mesh.element(e).topology).
        IF (ORDER .LT. 1_I4) THEN                                        ! If order < 1:
          CALL SET_ERROR(STATUS, 'BUILD_HLE_MESH',                       ! Record an error in status: 'HLE ORDER MUST BE AT LEAST 1'.
     &                   'HLE ORDER MUST BE AT LEAST 1')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO V = 1_I4, N_VERTEX                                            ! Loop v from 1 to n_vertex:
          POSITION(V,E) = 0_I4                                           ! Set position(v,e) to zero.
          DO J = 1_I4, N_NODE                                            ! Loop j from 1 to n_node:
            IF (MESH%NODE(J)%ID .EQ. MESH%ELEMENT(E)%NODE_ID(V)) THEN    ! If mesh.node(j).id = mesh.element(e).node_id(v):
              POSITION(V,E) = J                                          ! Set position(v,e) to j.
              EXIT                                                       ! Leave the loop.
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
          IF (POSITION(V,E) .EQ. 0_I4) THEN                              ! If position(v,e) = 0:
            CALL SET_ERROR(STATUS, 'BUILD_HLE_MESH',                     ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                     'ELEMENT REFERENCES UNKNOWN NODE')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        IF (.NOT. QUAD) CYCLE                                            ! If not quad, skip to the next iteration.
        DO S = 1_I4, 4_I4                                                ! Loop s from 1 to 4:
          CALL HLE_SIDE_ENDS(S, START, FINISH)                           ! Call hle side ends with s, start, finish.
          IF (POSITION(START,E) .EQ. POSITION(FINISH,E)) THEN            ! If position(start,e) = position(finish,e):
            CALL SET_ERROR(STATUS, 'BUILD_HLE_MESH',                     ! Record an error in status: 'HLE SUB-ELEMENT HAS A DEGENERATE SIDE'.
     &                     'HLE SUB-ELEMENT HAS A DEGENERATE SIDE')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          IF (MESH%NODE(POSITION(START,E))%ID .LT.                       ! If mesh.node(position(start,e)).id < mesh.node(position(finish,e)).id:
     &        MESH%NODE(POSITION(FINISH,E))%ID) THEN
            LOW = POSITION(START,E)                                      ! Set low to position(start,e).
            HIGH = POSITION(FINISH,E)                                    ! Set high to position(finish,e).
          ELSE                                                           ! Otherwise:
            LOW = POSITION(FINISH,E)                                     ! Set low to position(finish,e).
            HIGH = POSITION(START,E)                                     ! Set high to position(start,e).
            ELEMENT_REVERSED(S,E) = .TRUE.                               ! Set the flag element_reversed(s,e) to true.
          END IF                                                         ! End of the IF block.
          EDGE = 0_I4                                                    ! Set edge to zero.
          DO J = 1_I4, N_EDGE                                            ! Loop j from 1 to n_edge:
            IF (EDGE_NODE(1,J) .EQ. LOW .AND.                            ! If edge_node(1,j) = low and edge_node(2,j) = high:
     &          EDGE_NODE(2,J) .EQ. HIGH) THEN
              EDGE = J                                                   ! Set edge to j.
              EXIT                                                       ! Leave the loop.
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
          IF (EDGE .EQ. 0_I4) THEN                                       ! If edge = 0:
            N_EDGE = N_EDGE + 1_I4                                       ! Add 1 to n_edge.
            EDGE = N_EDGE                                                ! Set edge to n_edge.
            EDGE_NODE(1,EDGE) = LOW                                      ! Set edge_node(1,edge) to low.
            EDGE_NODE(2,EDGE) = HIGH                                     ! Set edge_node(2,edge) to high.
            EDGE_ORDER(EDGE) = ORDER                                     ! Set edge_order(edge) to order.
          ELSE                                                           ! Otherwise:
            EDGE_ORDER(EDGE) = MIN(EDGE_ORDER(EDGE),ORDER)               ! Set edge_order(edge) to the smaller of edge_order(edge) and order.
          END IF                                                         ! End of the IF block.
          ELEMENT_EDGE(S,E) = EDGE                                       ! Set element_edge(s,e) to edge.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

!     TERM NUMBERING: VERTICES, SIDES, THEN INTERNAL MODES.
      ALLOCATE(MESH%NODE_TERM(N_NODE))                                   ! Allocate memory for mesh.node_term(n_node).
      MESH%NODE_TERM = 0_I4                                              ! Set mesh.node_term to zero.
      DO E = 1_I4, N_ELEMENT                                             ! Loop e from 1 to n_element:
        DO V = 1_I4, N_VERTEX                                            ! Loop v from 1 to n_vertex:
          MESH%NODE_TERM(POSITION(V,E)) = 1_I4                           ! Set mesh.node_term(position(v,e)) to 1.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      N_VTERM = 0_I4                                                     ! Set n_vterm to zero.
      DO J = 1_I4, N_NODE                                                ! Loop j from 1 to n_node:
        IF (MESH%NODE_TERM(J) .GT. 0_I4) THEN                            ! If mesh.node_term(j) > 0:
          N_VTERM = N_VTERM + 1_I4                                       ! Add 1 to n_vterm.
          MESH%NODE_TERM(J) = N_VTERM                                    ! Set mesh.node_term(j) to n_vterm.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      N_TERM = N_VTERM                                                   ! Set n_term to n_vterm.
      DO EDGE = 1_I4, N_EDGE                                             ! Loop edge from 1 to n_edge:
        EDGE_FIRST(EDGE) = N_TERM + 1_I4                                 ! Set edge_first(edge) to n_term + 1.
        N_TERM = N_TERM + MAX(0_I4,EDGE_ORDER(EDGE)-1_I4)                ! Add max(0,edge_order(edge)-1) to n_term.
      END DO                                                             ! End of the loop.
      DO E = 1_I4, N_ELEMENT                                             ! Loop e from 1 to n_element:
        ORDER = TOPOLOGY_HLE_ORDER(MESH%ELEMENT(E)%TOPOLOGY)             ! Set order to topology_hle_order(mesh.element(e).topology).
        N_FUNCTION = HLE_FUNCTION_COUNT(QUAD, ORDER)                     ! Set n_function to hle_function_count(quad, order).
        N_TERM = N_TERM + N_FUNCTION - N_VERTEX -                        ! Add n_function - n_vertex - merge(4*(order-1),0,quad) to n_term.
     &           MERGE(4_I4*(ORDER-1_I4),0_I4,QUAD)
      END DO                                                             ! End of the loop.
      ALLOCATE(MESH%TERM_NODE(2,N_TERM))                                 ! Allocate memory for mesh.term_node(2,n_term).
      ALLOCATE(MESH%TERM_OWNER(N_TERM))                                  ! Allocate memory for mesh.term_owner(n_term).
      MESH%TERM_NODE = 0_I4                                              ! Set mesh.term_node to zero.
      MESH%TERM_OWNER = 0_I4                                             ! Set mesh.term_owner to zero.
      DO J = 1_I4, N_NODE                                                ! Loop j from 1 to n_node:
        IF (MESH%NODE_TERM(J) .GT. 0_I4)                                 ! If mesh.node_term(j) > 0, set mesh.term_node(1,mesh.node_term(j)) to j.
     &    MESH%TERM_NODE(1,MESH%NODE_TERM(J)) = J
      END DO                                                             ! End of the loop.
      DO EDGE = 1_I4, N_EDGE                                             ! Loop edge from 1 to n_edge:
        DO K = 2_I4, EDGE_ORDER(EDGE)                                    ! Loop k from 2 to edge_order(edge):
          MESH%TERM_NODE(1:2,EDGE_FIRST(EDGE)+K-2_I4) =                  ! Set mesh.term_node(1:2,edge_first(edge)+k-2) to edge_node(1:2,edge).
     &      EDGE_NODE(1:2,EDGE)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      N_TERM = N_VTERM                                                   ! Set n_term to n_vterm.
      DO EDGE = 1_I4, N_EDGE                                             ! Loop edge from 1 to n_edge:
        N_TERM = N_TERM + MAX(0_I4,EDGE_ORDER(EDGE)-1_I4)                ! Add max(0,edge_order(edge)-1) to n_term.
      END DO                                                             ! End of the loop.
      DO E = 1_I4, N_ELEMENT                                             ! Loop e from 1 to n_element:
        ORDER = TOPOLOGY_HLE_ORDER(MESH%ELEMENT(E)%TOPOLOGY)             ! Set order to topology_hle_order(mesh.element(e).topology).
        N_FUNCTION = HLE_FUNCTION_COUNT(QUAD, ORDER)                     ! Set n_function to hle_function_count(quad, order).
        ALLOCATE(MKIND(N_FUNCTION),A(N_FUNCTION),B(N_FUNCTION))          ! Allocate memory for mkind(n_function), a(n_function), b(n_function).
        CALL HLE_MODE_LIST(QUAD, ORDER, MKIND, A, B)                     ! Call hle mode list with quad, order, mkind, a, b.
        IF (ALLOCATED(MESH%ELEMENT(E)%MODE_TERM))                        ! If allocated(mesh.element(e).mode_term), free the memory of mesh.element(e).mode_term.
     &    DEALLOCATE(MESH%ELEMENT(E)%MODE_TERM)
        IF (ALLOCATED(MESH%ELEMENT(E)%MODE_SIGN))                        ! If allocated(mesh.element(e).mode_sign), free the memory of mesh.element(e).mode_sign.
     &    DEALLOCATE(MESH%ELEMENT(E)%MODE_SIGN)
        ALLOCATE(MESH%ELEMENT(E)%MODE_TERM(N_FUNCTION))                  ! Allocate memory for mesh.element(e).mode_term(n_function).
        ALLOCATE(MESH%ELEMENT(E)%MODE_SIGN(N_FUNCTION))                  ! Allocate memory for mesh.element(e).mode_sign(n_function).
        MESH%ELEMENT(E)%MODE_SIGN = 1.0_R8                               ! Set mesh.element(e).mode_sign to 1.0.
        DO L = 1_I4, N_FUNCTION                                          ! Loop l from 1 to n_function:
          SELECT CASE (MKIND(L))                                         ! Choose according to the value of mkind(l):
          CASE (HLE_SIDE)                                                ! Case hle_side:
            EDGE = ELEMENT_EDGE(A(L),E)                                  ! Set edge to element_edge(a(l),e).
            IF (B(L) .GT. EDGE_ORDER(EDGE)) THEN                         ! If b(l) > edge_order(edge):
              MESH%ELEMENT(E)%MODE_TERM(L) = 0_I4                        ! Set mesh.element(e).mode_term(l) to zero.
            ELSE                                                         ! Otherwise:
              MESH%ELEMENT(E)%MODE_TERM(L) = EDGE_FIRST(EDGE) +          ! Set mesh.element(e).mode_term(l) to edge_first(edge) + b(l) - 2.
     &                                       B(L) - 2_I4
              IF (ELEMENT_REVERSED(A(L),E) .AND.                         ! If element_reversed(a(l),e) and mod(b(l),2) = 1, set mesh.element(e).mode_sign(l) to -1.0.
     &            MOD(B(L),2_I4) .EQ. 1_I4)
     &          MESH%ELEMENT(E)%MODE_SIGN(L) = -1.0_R8
            END IF                                                       ! End of the IF block.
          CASE (HLE_INTERNAL)                                            ! Case hle_internal:
            N_TERM = N_TERM + 1_I4                                       ! Add 1 to n_term.
            MESH%ELEMENT(E)%MODE_TERM(L) = N_TERM                        ! Set mesh.element(e).mode_term(l) to n_term.
            MESH%TERM_OWNER(N_TERM) = E                                  ! Set mesh.term_owner(n_term) to e.
          CASE DEFAULT                                                   ! In every other case:
            MESH%ELEMENT(E)%MODE_TERM(L) =                               ! Set mesh.element(e).mode_term(l) to mesh.node_term(position(a(l),e)).
     &        MESH%NODE_TERM(POSITION(A(L),E))
          END SELECT                                                     ! End of the case selection.
        END DO                                                           ! End of the loop.
        DEALLOCATE(MKIND,A,B)                                            ! Free the memory of mkind, a, b.
      END DO                                                             ! End of the loop.
      MESH%N_TERM = N_TERM                                               ! Set mesh.n_term to n_term.
      MESH%IS_HLE = .TRUE.                                               ! Set the flag mesh.is_hle to true.

      END SUBROUTINE BUILD_HLE_MESH                                      ! End of the subroutine build hle mesh.

      END MODULE MUL2_HLE_MODES                                          ! End of the module mul2 hle modes.
