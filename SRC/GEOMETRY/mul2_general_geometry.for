!=======================================================================
!  GENERAL (CURVED) GEOMETRY OF BEAMS AND SHELLS.
!
!  AN ORDINARY ELEMENT HAS ONE LOCAL FRAME: A STRAIGHT BEAM OR A FLAT
!  PLATE. AN ELEMENT WITH THE GENERAL GEOMETRY (A CURVED BEAM, A SHELL)
!  CARRIES A TRIAD A1, A2, A3 AT EVERY NODE AND THE MAP FROM THE
!  NATURAL COORDINATES TO SPACE IS
!      X(XI,C) = SUM_I N_I(XI) [ X_I + C1 A1_I + C2 A2_I + C3 A3_I ]
!  WHERE C IS THE POSITION OF A POINT OF THE EXPANSION MESH (THE SECTION
!  OF A BEAM, THE THICKNESS OF A SHELL, IN PHYSICAL LENGTHS). THE TRIAD
!      BEAM:  A1 = A2 X A3, A2 = TANGENT OF THE AXIS, A3 = REFERENCE
!             VECTOR (SOR) PROJECTED ON THE NORMAL PLANE;
!      SHELL: A3 = DIRECTOR (NORMAL), A1 = SOR PROJECTED ON THE TANGENT
!             PLANE, A2 = A3 X A1 (THE FRAME OF A FLAT PLATE).
!  THE TANGENTS AND THE DIRECTORS ARE AVERAGED OVER THE ELEMENTS THAT
!  SHARE A NODE (ONLY THE ONES WITHIN THE FEATURE ANGLE, SO A TRUE EDGE
!  KEEPS ONE DIRECTOR PER SIDE), WHICH MAKES THE GEOMETRY CONTINUOUS.
!  THE THICKNESS COMES FROM THE EXPANSION MESH, AS FOR THE PLATES.
!  AN ELEMENT IS GENERAL WHEN ITS NAME SAYS SO (S4 S9 S16 CB2 CB3 CB4)
!  OR WHEN ITS NODES ARE NOT ON A LINE (B2 B3 B4) OR IN A PLANE
!  (Q4 Q9 Q16).
!=======================================================================
      MODULE MUL2_GENERAL_GEOMETRY                                       ! Module mul2 general geometry begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, set warning, status is ok.
     &                       SET_WARNING, STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, FIND_NODE_INDEX                ! Use from module mul2 nodes: node db type, find node index.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_REFERENCE_SYSTEMS, ONLY: REFERENCE_VECTOR_DB_TYPE,        ! Use from module mul2 reference systems: reference vector db type, element frame db type.
     &                                  ELEMENT_FRAME_DB_TYPE
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_B2, TOPOLOGY_B3,               ! Use from module mul2 topologies: topology b2, topology b3, topology b4, topology q4, topology q9, topology ...
     &     TOPOLOGY_B4, TOPOLOGY_Q4, TOPOLOGY_Q9, TOPOLOGY_Q16,
     &     TOPOLOGY_NATURAL_DIMENSION, TOPOLOGY_NODE_COUNT
      USE MUL2_SHAPE_FUNCTIONS, ONLY: EVALUATE_SHAPE                     ! Use from module mul2 shape functions: evaluate shape.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!  DIRECTORS WITHIN THIS ANGLE (COSINE) ARE AVERAGED AT A NODE.
      REAL(R8), PARAMETER :: FEATURE_COSINE = 0.7660444431189780_R8      ! Constant real (real64): feature_cosine = 0.7660444431189780.
!  RELATIVE DISTANCE OF A NODE FROM THE LINE OR PLANE OF THE ELEMENT
!  ABOVE WHICH THE ELEMENT IS CURVED.
      REAL(R8), PARAMETER :: CURVED_TOLERANCE = 1.0E-6_R8                ! Constant real (real64): curved_tolerance = 1.0e-6.

      PUBLIC :: BUILD_GENERAL_GEOMETRY                                   ! Export: build general geometry.
      PUBLIC :: IS_GENERAL_ELEMENT                                       ! Export: is general element.
      PUBLIC :: GENERAL_NODE_NATURAL                                     ! Export: general node natural.
      PUBLIC :: GENERAL_MAP                                              ! Export: general map.
      PUBLIC :: GENERAL_FRAME                                            ! Export: general frame.
      PUBLIC :: GENERAL_OFFSET                                           ! Export: general offset.

      CONTAINS                                                           ! The procedures of the module follow.

      LOGICAL FUNCTION IS_GENERAL_ELEMENT(FRAMES, ELEMENT)               ! Function is general element takes frames, element.

      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.

      IS_GENERAL_ELEMENT = .FALSE.                                       ! Set the flag is_general_element to false.
      IF (.NOT. ALLOCATED(FRAMES%GENERAL_INDEX)) RETURN                  ! If not allocated(frames.general_index), return to the caller.
      IS_GENERAL_ELEMENT = FRAMES%GENERAL_INDEX(ELEMENT) .GT. 0_I4       ! Set is_general_element to frames.general_index(element) > 0.

      END FUNCTION IS_GENERAL_ELEMENT                                    ! End of the function is general element.

!  NATURAL COORDINATES OF NODE J OF A BEAM (1 VALUE) OR PLATE
!  (2 VALUES) TOPOLOGY, IN THE ORDER OF THE SHAPE FUNCTIONS.
      SUBROUTINE GENERAL_NODE_NATURAL(TOPOLOGY, J, XI)                   ! Subroutine general node natural takes topology, j, xi.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      INTEGER(I4), INTENT(IN) :: J                                       ! Input integer (int32): j.
      REAL(R8), INTENT(OUT) :: XI(2)                                     ! Output real (real64): xi(2).
      INTEGER(I4), PARAMETER :: Q4X(4) = [1,2,2,1]                       ! Constant integer (int32): q4x(4) = [1, 2, 2, 1].
      INTEGER(I4), PARAMETER :: Q4Y(4) = [1,1,2,2]                       ! Constant integer (int32): q4y(4) = [1, 1, 2, 2].
      INTEGER(I4), PARAMETER :: Q9X(9) = [1,2,3,3,3,2,1,1,2]             ! Constant integer (int32): q9x(9) = [1, 2, 3, 3, 3, 2, 1, 1, 2].
      INTEGER(I4), PARAMETER :: Q9Y(9) = [1,1,1,2,3,3,3,2,2]             ! Constant integer (int32): q9y(9) = [1, 1, 1, 2, 3, 3, 3, 2, 2].
      INTEGER(I4), PARAMETER :: Q16X(16) =                               ! Constant integer (int32): q16x(16) = [1, 2, 3, 4, 4, 4, 4, 3, 2, 1, 1, 1, 2, 3, 3, 2].
     &  [1,2,3,4,4,4,4,3,2,1,1,1,2,3,3,2]
      INTEGER(I4), PARAMETER :: Q16Y(16) =                               ! Constant integer (int32): q16y(16) = [1, 1, 1, 1, 2, 3, 4, 4, 4, 4, 3, 2, 2, 2, 3, 3].
     &  [1,1,1,1,2,3,4,4,4,4,3,2,2,2,3,3]

      XI = 0.0_R8                                                        ! Set xi to zero.
      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_B2)                                                 ! Case topology_b2:
        XI(1) = -1.0_R8 + 2.0_R8*REAL(J-1_I4,R8)/1.0_R8                  ! Set xi(1) to -1.0 + 2.0*real(j-1,r8)/1.0.
      CASE (TOPOLOGY_B3)                                                 ! Case topology_b3:
        XI(1) = -1.0_R8 + 2.0_R8*REAL(J-1_I4,R8)/2.0_R8                  ! Set xi(1) to -1.0 + 2.0*real(j-1,r8)/2.0.
      CASE (TOPOLOGY_B4)                                                 ! Case topology_b4:
        XI(1) = -1.0_R8 + 2.0_R8*REAL(J-1_I4,R8)/3.0_R8                  ! Set xi(1) to -1.0 + 2.0*real(j-1,r8)/3.0.
      CASE (TOPOLOGY_Q4)                                                 ! Case topology_q4:
        XI(1) = -1.0_R8 + 2.0_R8*REAL(Q4X(J)-1_I4,R8)/1.0_R8             ! Set xi(1) to -1.0 + 2.0*real(q4x(j)-1,r8)/1.0.
        XI(2) = -1.0_R8 + 2.0_R8*REAL(Q4Y(J)-1_I4,R8)/1.0_R8             ! Set xi(2) to -1.0 + 2.0*real(q4y(j)-1,r8)/1.0.
      CASE (TOPOLOGY_Q9)                                                 ! Case topology_q9:
        XI(1) = -1.0_R8 + 2.0_R8*REAL(Q9X(J)-1_I4,R8)/2.0_R8             ! Set xi(1) to -1.0 + 2.0*real(q9x(j)-1,r8)/2.0.
        XI(2) = -1.0_R8 + 2.0_R8*REAL(Q9Y(J)-1_I4,R8)/2.0_R8             ! Set xi(2) to -1.0 + 2.0*real(q9y(j)-1,r8)/2.0.
      CASE (TOPOLOGY_Q16)                                                ! Case topology_q16:
        XI(1) = -1.0_R8 + 2.0_R8*REAL(Q16X(J)-1_I4,R8)/3.0_R8            ! Set xi(1) to -1.0 + 2.0*real(q16x(j)-1,r8)/3.0.
        XI(2) = -1.0_R8 + 2.0_R8*REAL(Q16Y(J)-1_I4,R8)/3.0_R8            ! Set xi(2) to -1.0 + 2.0*real(q16y(j)-1,r8)/3.0.
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE GENERAL_NODE_NATURAL                                ! End of the subroutine general node natural.

!  POSITION X AND JACOBIAN ROWS G(A,:) = D X / D T_A OF THE MAP, WITH
!  T = (STRUCTURAL NATURAL COORDINATES, ACTIVE EXPANSION COORDINATES).
!    DS      NUMBER OF STRUCTURAL COORDINATES (1 BEAM, 2 SHELL)
!    COORD   NODAL COORDINATES (3,N); TRIAD NODAL TRIADS (3,3,N)
!    N, DN   SHAPE VALUES AND DERIVATIVES (N, DS)
!    C       POSITION IN THE EXPANSION MESH (3), AXIS ITS ACTIVE AXES
      SUBROUTINE GENERAL_MAP(DS, N_NODE, COORD, TRIAD, N, DN, C, AXIS,   ! Subroutine general map takes ds, n node, coord, triad, n, dn, c, axis, x, g.
     &                       X, G)

      INTEGER(I4), INTENT(IN) :: DS                                      ! Input integer (int32): ds.
      INTEGER(I4), INTENT(IN) :: N_NODE                                  ! Input integer (int32): n_node.
      REAL(R8), INTENT(IN) :: COORD(:,:)                                 ! Input real (real64): coord(:,:).
      REAL(R8), INTENT(IN) :: TRIAD(:,:,:)                               ! Input real (real64): triad(:,:,:).
      REAL(R8), INTENT(IN) :: N(:)                                       ! Input real (real64): n(:).
      REAL(R8), INTENT(IN) :: DN(:,:)                                    ! Input real (real64): dn(:,:).
      REAL(R8), INTENT(IN) :: C(3)                                       ! Input real (real64): c(3).
      INTEGER(I4), INTENT(IN) :: AXIS(:)                                 ! Input integer (int32): axis(:).
      REAL(R8), INTENT(OUT) :: X(3)                                      ! Output real (real64): x(3).
      REAL(R8), INTENT(OUT) :: G(3,3)                                    ! Output real (real64): g(3,3).
      REAL(R8) :: P(3)                                                   ! Real (real64): p(3).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.

      X = 0.0_R8                                                         ! Set x to zero.
      G = 0.0_R8                                                         ! Set g to zero.
      DO I = 1_I4, N_NODE                                                ! Loop i from 1 to n_node:
        P = COORD(:,I) + C(1)*TRIAD(:,1,I) + C(2)*TRIAD(:,2,I) +         ! Set p to coord(:,i) + c(1)*triad(:,1,i) + c(2)*triad(:,2,i) + c(3)*triad(:,3,i).
     &      C(3)*TRIAD(:,3,I)
        X = X + N(I)*P                                                   ! Add n(i)*p to x.
        DO A = 1_I4, DS                                                  ! Loop a from 1 to ds:
          G(A,:) = G(A,:) + DN(I,A)*P                                    ! Add dn(i,a)*p to g(a,:).
        END DO                                                           ! End of the loop.
        DO M = 1_I4, 3_I4-DS                                             ! Loop m from 1 to 3-ds:
          G(DS+M,:) = G(DS+M,:) + N(I)*TRIAD(:,AXIS(M),I)                ! Add n(i)*triad(:,axis(m),i) to g(ds+m,:).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE GENERAL_MAP                                         ! End of the subroutine general map.

!  FRAME ROWS (E1; E2; E3) = GLOBAL_TO_LOCAL AT A POINT, WITH THE SAME
!  RULES AS THE ORDINARY FRAMES: A BEAM HAS E2 ALONG THE AXIS (TANGENT
!  OF THE AXIS CURVE, C = 0) AND E3 FROM THE REFERENCE VECTOR, A SHELL
!  HAS E3 NORMAL TO THE COORDINATE SURFACE AND E1 FROM THE REFERENCE
!  VECTOR.
      SUBROUTINE GENERAL_FRAME(DS, N_NODE, COORD, DN, G, REFERENCE,      ! Subroutine general frame takes ds, n node, coord, dn, g, reference, r, status.
     &                         R, STATUS)

      INTEGER(I4), INTENT(IN) :: DS                                      ! Input integer (int32): ds.
      INTEGER(I4), INTENT(IN) :: N_NODE                                  ! Input integer (int32): n_node.
      REAL(R8), INTENT(IN) :: COORD(:,:)                                 ! Input real (real64): coord(:,:).
      REAL(R8), INTENT(IN) :: DN(:,:)                                    ! Input real (real64): dn(:,:).
      REAL(R8), INTENT(IN) :: G(3,3)                                     ! Input real (real64): g(3,3).
      REAL(R8), INTENT(IN) :: REFERENCE(3)                               ! Input real (real64): reference(3).
      REAL(R8), INTENT(OUT) :: R(3,3)                                    ! Output real (real64): r(3,3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: E1(3)                                                  ! Real (real64): e1(3).
      REAL(R8) :: E2(3)                                                  ! Real (real64): e2(3).
      REAL(R8) :: E3(3)                                                  ! Real (real64): e3(3).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      R = 0.0_R8                                                         ! Set r to zero.
      IF (DS .EQ. 1_I4) THEN                                             ! If ds = 1:
        E2 = 0.0_R8                                                      ! Set e2 to zero.
        DO I = 1_I4, N_NODE                                              ! Loop i from 1 to n_node:
          E2 = E2 + DN(I,1)*COORD(:,I)                                   ! Add dn(i,1)*coord(:,i) to e2.
        END DO                                                           ! End of the loop.
        CALL UNIT_VECTOR(E2, 'DEGENERATE BEAM AXIS', STATUS)             ! Call unit vector with e2, 'DEGENERATE BEAM AXIS', status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        E3 = REFERENCE - DOT_PRODUCT(REFERENCE,E2)*E2                    ! Set e3 to reference - dot_product(reference,e2)*e2.
        CALL UNIT_VECTOR(E3, 'SOR IS PARALLEL TO BEAM AXIS', STATUS)     ! Call unit vector with e3, 'SOR IS PARALLEL TO BEAM AXIS', status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        E1 = CROSS(E2,E3)                                                ! Set e1 to cross(e2,e3).
        CALL UNIT_VECTOR(E1, 'INVALID BEAM FRAME', STATUS)               ! Call unit vector with e1, 'INVALID BEAM FRAME', status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        E3 = CROSS(E1,E2)                                                ! Set e3 to cross(e1,e2).
      ELSE                                                               ! Otherwise:
        E3 = CROSS(G(1,:),G(2,:))                                        ! Set e3 to cross(g(1,:),g(2,:)).
        CALL UNIT_VECTOR(E3, 'DEGENERATE SURFACE', STATUS)               ! Call unit vector with e3, 'DEGENERATE SURFACE', status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        E1 = REFERENCE - DOT_PRODUCT(REFERENCE,E3)*E3                    ! Set e1 to reference - dot_product(reference,e3)*e3.
        CALL UNIT_VECTOR(E1, 'SOR IS NORMAL TO SURFACE', STATUS)         ! Call unit vector with e1, 'SOR IS NORMAL TO SURFACE', status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        E2 = CROSS(E3,E1)                                                ! Set e2 to cross(e3,e1).
        CALL UNIT_VECTOR(E2, 'INVALID SURFACE FRAME', STATUS)            ! Call unit vector with e2, 'INVALID SURFACE FRAME', status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        E1 = CROSS(E2,E3)                                                ! Set e1 to cross(e2,e3).
      END IF                                                             ! End of the IF block.
      R(1,:) = E1                                                        ! Set r(1,:) to e1.
      R(2,:) = E2                                                        ! Set r(2,:) to e2.
      R(3,:) = E3                                                        ! Set r(3,:) to e3.

      END SUBROUTINE GENERAL_FRAME                                       ! End of the subroutine general frame.

!  OFFSET OF AN EXPANSION POINT C FROM THE NODE, IN GLOBAL COMPONENTS
!  (THE EQUIVALENT OF LOCAL_TO_GLOBAL * C OF AN ORDINARY ELEMENT).
      SUBROUTINE GENERAL_OFFSET(FRAMES, ELEMENT, LOCAL_NODE, C, OFFSET)  ! Subroutine general offset takes frames, element, local node, c, offset.

      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      INTEGER(I4), INTENT(IN) :: LOCAL_NODE                              ! Input integer (int32): local_node.
      REAL(R8), INTENT(IN) :: C(3)                                       ! Input real (real64): c(3).
      REAL(R8), INTENT(OUT) :: OFFSET(3)                                 ! Output real (real64): offset(3).
      INTEGER(I4) :: G                                                   ! Integer (int32): g.

      G = FRAMES%GENERAL_INDEX(ELEMENT)                                  ! Set g to frames.general_index(element).
      OFFSET = C(1)*FRAMES%GENERAL_TRIAD(:,1,LOCAL_NODE,G) +             ! Set offset to c(1)*frames.general_triad(:,1,local_node,g) + c(2)*frames.general_triad(:,2,local_node,g) + c...
     &         C(2)*FRAMES%GENERAL_TRIAD(:,2,LOCAL_NODE,G) +
     &         C(3)*FRAMES%GENERAL_TRIAD(:,3,LOCAL_NODE,G)

      END SUBROUTINE GENERAL_OFFSET                                      ! End of the subroutine general offset.

!  FINDS THE GENERAL ELEMENTS AND BUILDS THE NODAL TRIADS.
      SUBROUTINE BUILD_GENERAL_GEOMETRY(NODES, ELEMENTS, VECTORS,        ! Subroutine build general geometry takes nodes, elements, vectors, frames, status.
     &                                  FRAMES, STATUS)

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(REFERENCE_VECTOR_DB_TYPE), INTENT(IN) :: VECTORS              ! Input of type reference_vector_db_type: vectors.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(INOUT) :: FRAMES               ! In/out of type element_frame_db_type: frames.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: RAW(:,:,:)                                ! Allocatable real (real64): raw(:,:,:).
      INTEGER(I4), ALLOCATABLE :: ELEMENT_OF(:)                          ! Allocatable integer (int32): element_of(:).
      INTEGER(I4), ALLOCATABLE :: NODE_INDEX(:,:)                        ! Allocatable integer (int32): node_index(:,:).
      INTEGER(I4), ALLOCATABLE :: FIRST(:)                               ! Allocatable integer (int32): first(:).
      INTEGER(I4), ALLOCATABLE :: FILL(:)                                ! Allocatable integer (int32): fill(:).
      INTEGER(I4), ALLOCATABLE :: ENTRY_G(:)                             ! Allocatable integer (int32): entry_g(:).
      INTEGER(I4), ALLOCATABLE :: ENTRY_J(:)                             ! Allocatable integer (int32): entry_j(:).
      REAL(R8) :: COORD(3,16)                                            ! Real (real64): coord(3,16).
      REAL(R8) :: XI(2)                                                  ! Real (real64): xi(2).
      REAL(R8) :: N(16)                                                  ! Real (real64): n(16).
      REAL(R8) :: DN(16,2)                                               ! Real (real64): dn(16,2).
      REAL(R8) :: REFERENCE(3)                                           ! Real (real64): reference(3).
      REAL(R8) :: A1(3)                                                  ! Real (real64): a1(3).
      REAL(R8) :: A2(3)                                                  ! Real (real64): a2(3).
      REAL(R8) :: V(3)                                                   ! Real (real64): v(3).
      REAL(R8) :: S                                                      ! Real (real64): s.
      LOGICAL :: EXACT                                                   ! Logical: exact.
      LOGICAL :: OPPOSITE                                                ! Logical: opposite.
      INTEGER(I4) :: N_ELEMENT                                           ! Integer (int32): n_element.
      INTEGER(I4) :: N_GENERAL                                           ! Integer (int32): n_general.
      INTEGER(I4) :: MAX_NODE                                            ! Integer (int32): max_node.
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: G                                                   ! Integer (int32): g.
      INTEGER(I4) :: GE                                                  ! Integer (int32): ge.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: P                                                   ! Integer (int32): p.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.
      INTEGER(I4) :: VECTOR_INDEX                                        ! Integer (int32): vector_index.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N_ELEMENT = SIZE(ELEMENTS%ITEM)                                    ! Set n_element to the size of elements.item.
      IF (ALLOCATED(FRAMES%GENERAL_INDEX))                               ! If allocated(frames.general_index), free the memory of frames.general_index.
     &  DEALLOCATE(FRAMES%GENERAL_INDEX)
      IF (ALLOCATED(FRAMES%GENERAL_TRIAD))                               ! If allocated(frames.general_triad), free the memory of frames.general_triad.
     &  DEALLOCATE(FRAMES%GENERAL_TRIAD)
      IF (ALLOCATED(FRAMES%GENERAL_REFERENCE))                           ! If allocated(frames.general_reference), free the memory of frames.general_reference.
     &  DEALLOCATE(FRAMES%GENERAL_REFERENCE)
      ALLOCATE(FRAMES%GENERAL_INDEX(N_ELEMENT))                          ! Allocate memory for frames.general_index(n_element).
      FRAMES%GENERAL_INDEX = 0_I4                                        ! Set frames.general_index to zero.

!     1. WHICH ELEMENTS ARE GENERAL.
      N_GENERAL = 0_I4                                                   ! Set n_general to zero.
      MAX_NODE = 1_I4                                                    ! Set max_node to 1.
      DO E = 1_I4, N_ELEMENT                                             ! Loop e from 1 to n_element:
        DIMENSION = TOPOLOGY_NATURAL_DIMENSION(                          ! Set dimension to topology_natural_dimension( elements.item(e).topology).
     &              ELEMENTS%ITEM(E)%TOPOLOGY)
        IF (DIMENSION .LT. 1_I4 .OR. DIMENSION .GT. 2_I4) CYCLE          ! If dimension < 1 or dimension > 2, skip to the next iteration.
        N_NODE = TOPOLOGY_NODE_COUNT(ELEMENTS%ITEM(E)%TOPOLOGY)          ! Set n_node to topology_node_count(elements.item(e).topology).
        IF (ELEMENTS%ITEM(E)%TOPOLOGY .NE. TOPOLOGY_B2 .AND.             ! If elements.item(e).topology /= topology_b2 and elements.item(e).topology /= topology_b3 and elements.item(...
     &      ELEMENTS%ITEM(E)%TOPOLOGY .NE. TOPOLOGY_B3 .AND.
     &      ELEMENTS%ITEM(E)%TOPOLOGY .NE. TOPOLOGY_B4 .AND.
     &      ELEMENTS%ITEM(E)%TOPOLOGY .NE. TOPOLOGY_Q4 .AND.
     &      ELEMENTS%ITEM(E)%TOPOLOGY .NE. TOPOLOGY_Q9 .AND.
     &      ELEMENTS%ITEM(E)%TOPOLOGY .NE. TOPOLOGY_Q16) CYCLE
        DO J = 1_I4, N_NODE                                              ! Loop j from 1 to n_node:
          K = FIND_NODE_INDEX(NODES, ELEMENTS%ITEM(E)%NODE_ID(J))        ! Set k to find_node_index(nodes, elements.item(e).node_id(j)).
          IF (K .EQ. 0_I4) THEN                                          ! If k = 0:
            CALL SET_ERROR(STATUS, 'BUILD_GENERAL_GEOMETRY',             ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                     'ELEMENT REFERENCES UNKNOWN NODE')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          COORD(:,J) = NODES%ITEM(K)%COORDINATE                          ! Set coord(:,j) to nodes.item(k).coordinate.
        END DO                                                           ! End of the loop.
        IF (ELEMENTS%ITEM(E)%GENERAL .OR.                                ! If elements.item(e).general or is_curved(elements.item(e).topology, coord, n_node):
     &      IS_CURVED(ELEMENTS%ITEM(E)%TOPOLOGY, COORD, N_NODE)) THEN
          N_GENERAL = N_GENERAL + 1_I4                                   ! Add 1 to n_general.
          FRAMES%GENERAL_INDEX(E) = N_GENERAL                            ! Set frames.general_index(e) to n_general.
          MAX_NODE = MAX(MAX_NODE, N_NODE)                               ! Set max_node to the larger of max_node and n_node.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      ALLOCATE(FRAMES%GENERAL_TRIAD(3,3,MAX_NODE,N_GENERAL))             ! Allocate memory for frames.general_triad(3,3,max_node,n_general).
      ALLOCATE(FRAMES%GENERAL_REFERENCE(3,N_GENERAL))                    ! Allocate memory for frames.general_reference(3,n_general).
      IF (ALLOCATED(FRAMES%GENERAL_KINK))                                ! If allocated(frames.general_kink), free the memory of frames.general_kink.
     &  DEALLOCATE(FRAMES%GENERAL_KINK)
      ALLOCATE(FRAMES%GENERAL_KINK(MAX_NODE,N_GENERAL))                  ! Allocate memory for frames.general_kink(max_node,n_general).
      FRAMES%GENERAL_KINK = 0_I4                                         ! Set frames.general_kink to zero.
      FRAMES%GENERAL_TRIAD = 0.0_R8                                      ! Set frames.general_triad to zero.
      FRAMES%GENERAL_REFERENCE = 0.0_R8                                  ! Set frames.general_reference to zero.
      IF (N_GENERAL .EQ. 0_I4) RETURN                                    ! If n_general = 0, return to the caller.

!     2. RAW TANGENT / NORMAL AT EVERY NODE OF EVERY GENERAL ELEMENT.
      ALLOCATE(RAW(3,MAX_NODE,N_GENERAL), ELEMENT_OF(N_GENERAL))         ! Allocate memory for raw(3,max_node,n_general), element_of(n_general).
      ALLOCATE(NODE_INDEX(MAX_NODE,N_GENERAL))                           ! Allocate memory for node_index(max_node,n_general).
      RAW = 0.0_R8                                                       ! Set raw to zero.
      NODE_INDEX = 0_I4                                                  ! Set node_index to zero.
      DO E = 1_I4, N_ELEMENT                                             ! Loop e from 1 to n_element:
        G = FRAMES%GENERAL_INDEX(E)                                      ! Set g to frames.general_index(e).
        IF (G .EQ. 0_I4) CYCLE                                           ! If g = 0, skip to the next iteration.
        ELEMENT_OF(G) = E                                                ! Set element_of(g) to e.
        DIMENSION = TOPOLOGY_NATURAL_DIMENSION(                          ! Set dimension to topology_natural_dimension( elements.item(e).topology).
     &              ELEMENTS%ITEM(E)%TOPOLOGY)
        N_NODE = TOPOLOGY_NODE_COUNT(ELEMENTS%ITEM(E)%TOPOLOGY)          ! Set n_node to topology_node_count(elements.item(e).topology).
        VECTOR_INDEX = FIND_VECTOR(VECTORS, ELEMENTS%ITEM(E)%FRAME_ID)   ! Set vector_index to find_vector(vectors, elements.item(e).frame_id).
        IF (VECTOR_INDEX .EQ. 0_I4) THEN                                 ! If vector_index = 0:
          CALL SET_ERROR(STATUS, 'BUILD_GENERAL_GEOMETRY',               ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN SOR'.
     &                   'ELEMENT REFERENCES UNKNOWN SOR')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        REFERENCE = VECTORS%ITEM(VECTOR_INDEX)%DIRECTION                 ! Set reference to vectors.item(vector_index).direction.
        FRAMES%GENERAL_REFERENCE(:,G) = REFERENCE                        ! Set frames.general_reference(:,g) to reference.
        DO J = 1_I4, N_NODE                                              ! Loop j from 1 to n_node:
          K = FIND_NODE_INDEX(NODES, ELEMENTS%ITEM(E)%NODE_ID(J))        ! Set k to find_node_index(nodes, elements.item(e).node_id(j)).
          NODE_INDEX(J,G) = K                                            ! Set node_index(j,g) to k.
          COORD(:,J) = NODES%ITEM(K)%COORDINATE                          ! Set coord(:,j) to nodes.item(k).coordinate.
        END DO                                                           ! End of the loop.
        DO J = 1_I4, N_NODE                                              ! Loop j from 1 to n_node:
          CALL GENERAL_NODE_NATURAL(ELEMENTS%ITEM(E)%TOPOLOGY, J, XI)    ! Call general node natural with elements.item(e).topology, j, xi.
          CALL EVALUATE_SHAPE(ELEMENTS%ITEM(E)%TOPOLOGY,                 ! Call evaluate shape with elements.item(e).topology, xi(1:dimension), n(1:n_node), dn(1:n_node,1:dimension),...
     &                        XI(1:DIMENSION), N(1:N_NODE),
     &                        DN(1:N_NODE,1:DIMENSION), STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          A1 = 0.0_R8                                                    ! Set a1 to zero.
          A2 = 0.0_R8                                                    ! Set a2 to zero.
          DO K = 1_I4, N_NODE                                            ! Loop k from 1 to n_node:
            A1 = A1 + DN(K,1)*COORD(:,K)                                 ! Add dn(k,1)*coord(:,k) to a1.
            IF (DIMENSION .EQ. 2_I4) A2 = A2 + DN(K,2)*COORD(:,K)        ! If dimension = 2, add dn(k,2)*coord(:,k) to a2.
          END DO                                                         ! End of the loop.
          IF (DIMENSION .EQ. 1_I4) THEN                                  ! If dimension = 1:
            V = A1                                                       ! Set v to a1.
          ELSE                                                           ! Otherwise:
            V = CROSS(A1,A2)                                             ! Set v to cross(a1,a2).
          END IF                                                         ! End of the IF block.
          CALL UNIT_VECTOR(V, 'DEGENERATE CURVED ELEMENT', STATUS)       ! Call unit vector with v, 'DEGENERATE CURVED ELEMENT', status.
          IF (.NOT. STATUS_IS_OK(STATUS)) THEN                           ! If not status is ok:
            CALL SET_ERROR(STATUS, 'BUILD_GENERAL_GEOMETRY',             ! Record an error in status: 'DEGENERATE CURVED ELEMENT '//trim(itoa( elements.item(e).id)).
     &        'DEGENERATE CURVED ELEMENT '//TRIM(ITOA(
     &        ELEMENTS%ITEM(E)%ID)))
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          RAW(:,J,G) = V                                                 ! Set raw(:,j,g) to v.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

!     3. ELEMENT-NODE ENTRIES GROUPED BY NODE.
      ALLOCATE(FIRST(SIZE(NODES%ITEM)+1), FILL(SIZE(NODES%ITEM)))        ! Allocate memory for first(size(nodes.item)+1), fill(size(nodes.item)).
      FIRST = 0_I4                                                       ! Set first to zero.
      DO G = 1_I4, N_GENERAL                                             ! Loop g from 1 to n_general:
        E = ELEMENT_OF(G)                                                ! Set e to element_of(g).
        DO J = 1_I4, TOPOLOGY_NODE_COUNT(ELEMENTS%ITEM(E)%TOPOLOGY)      ! Loop j from 1 to topology_node_count(elements.item(e).topology):
          FIRST(NODE_INDEX(J,G)+1) = FIRST(NODE_INDEX(J,G)+1) + 1_I4     ! Add 1 to first(node_index(j,g)+1).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      FIRST(1) = 1_I4                                                    ! Set first(1) to 1.
      DO K = 1_I4, SIZE(NODES%ITEM)                                      ! Loop k from 1 to size(nodes.item):
        FIRST(K+1) = FIRST(K+1) + FIRST(K)                               ! Add first(k) to first(k+1).
      END DO                                                             ! End of the loop.
      ALLOCATE(ENTRY_G(FIRST(SIZE(NODES%ITEM)+1)-1_I4))                  ! Allocate memory for entry_g(first(size(nodes.item)+1)-1).
      ALLOCATE(ENTRY_J(FIRST(SIZE(NODES%ITEM)+1)-1_I4))                  ! Allocate memory for entry_j(first(size(nodes.item)+1)-1).
      FILL = 0_I4                                                        ! Set fill to zero.
      DO G = 1_I4, N_GENERAL                                             ! Loop g from 1 to n_general:
        E = ELEMENT_OF(G)                                                ! Set e to element_of(g).
        DO J = 1_I4, TOPOLOGY_NODE_COUNT(ELEMENTS%ITEM(E)%TOPOLOGY)      ! Loop j from 1 to topology_node_count(elements.item(e).topology):
          K = NODE_INDEX(J,G)                                            ! Set k to node_index(j,g).
          ENTRY_G(FIRST(K)+FILL(K)) = G                                  ! Set entry_g(first(k)+fill(k)) to g.
          ENTRY_J(FIRST(K)+FILL(K)) = J                                  ! Set entry_j(first(k)+fill(k)) to j.
          FILL(K) = FILL(K) + 1_I4                                       ! Add 1 to fill(k).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

!     4. TRIAD OF EVERY ELEMENT NODE FROM THE AVERAGE OF THE RAW
!        VECTORS OF THE ELEMENTS (WITHIN THE FEATURE ANGLE) AT THE NODE.
      OPPOSITE = .FALSE.                                                 ! Set the flag opposite to false.
      DO G = 1_I4, N_GENERAL                                             ! Loop g from 1 to n_general:
        E = ELEMENT_OF(G)                                                ! Set e to element_of(g).
        DIMENSION = TOPOLOGY_NATURAL_DIMENSION(                          ! Set dimension to topology_natural_dimension( elements.item(e).topology).
     &              ELEMENTS%ITEM(E)%TOPOLOGY)
        N_NODE = TOPOLOGY_NODE_COUNT(ELEMENTS%ITEM(E)%TOPOLOGY)          ! Set n_node to topology_node_count(elements.item(e).topology).
        REFERENCE = FRAMES%GENERAL_REFERENCE(:,G)                        ! Set reference to frames.general_reference(:,g).
        DO J = 1_I4, N_NODE                                              ! Loop j from 1 to n_node:
          K = NODE_INDEX(J,G)                                            ! Set k to node_index(j,g).
          V = 0.0_R8                                                     ! Set v to zero.
          IF (DIMENSION .EQ. 2_I4 .AND. NODES%ITEM(K)%HAS_DIRECTOR) THEN ! If dimension = 2 and nodes.item(k).has_director:
!           EXACT DIRECTOR (DIRECTORS.DAT) FOR THE ELEMENTS WITHIN THE
!           FEATURE ANGLE OF IT.
            IF (DOT_PRODUCT(NODES%ITEM(K)%DIRECTOR,RAW(:,J,G)) .GE.      ! If dot_product(nodes.item(k).director,raw(:,j,g)) >= feature_cosine, set v to nodes.item(k).director.
     &          FEATURE_COSINE) V = NODES%ITEM(K)%DIRECTOR
          END IF                                                         ! End of the IF block.
          EXACT = SQRT(DOT_PRODUCT(V,V)) .GT. 0.5_R8                     ! Set exact to sqrt(dot_product(v,v)) > 0.5.
          DO P = FIRST(K), FIRST(K+1)-1_I4                               ! Loop p from first(k) to first(k+1)-1:
            GE = ENTRY_G(P)                                              ! Set ge to entry_g(p).
            Q = ENTRY_J(P)                                               ! Set q to entry_j(p).
            IF (TOPOLOGY_NATURAL_DIMENSION(ELEMENTS%ITEM(                ! If topology_natural_dimension(elements.item( element_of(ge)).topology) /= dimension, skip to the next itera...
     &          ELEMENT_OF(GE))%TOPOLOGY) .NE. DIMENSION) CYCLE
            S = DOT_PRODUCT(RAW(:,Q,GE),RAW(:,J,G))                      ! Set s to dot_product(raw(:,q,ge),raw(:,j,g)).
            IF (DIMENSION .EQ. 1_I4) THEN                                ! If dimension = 1:
!             A BEAM CHAIN MAY BE ORDERED IN OPPOSITE WAYS.
              V = V + SIGN(1.0_R8,S)*RAW(:,Q,GE)                         ! Add sign(1.0,s)*raw(:,q,ge) to v.
            ELSE IF (S .GE. FEATURE_COSINE) THEN                         ! Otherwise, if s >= feature_cosine:
              IF (.NOT. EXACT) V = V + RAW(:,Q,GE)                       ! If not exact, add raw(:,q,ge) to v.
            ELSE IF (S .LT. -0.9999999_R8) THEN                          ! Otherwise, if s < -0.9999999:
              IF (DIMENSION .EQ. 2_I4 .AND.                              ! If dimension = 2 and frames.general_kink(j,g) = 0 and dot_product(raw(:,j,g),raw(:,entry_j(first(k)), entry...
     &            FRAMES%GENERAL_KINK(J,G) .EQ. 0_I4 .AND.
     &            DOT_PRODUCT(RAW(:,J,G),RAW(:,ENTRY_J(FIRST(K)),
     &            ENTRY_G(FIRST(K)))) .LT. 0.0_R8)
     &          FRAMES%GENERAL_KINK(J,G) = -1_I4
            ELSE IF (DIMENSION .EQ. 2_I4) THEN                           ! Otherwise, if dimension = 2:
              FRAMES%GENERAL_KINK(J,G) = 1_I4                            ! Set frames.general_kink(j,g) to 1.
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
          CALL UNIT_VECTOR(V, 'DEGENERATE NODAL VECTOR', STATUS)         ! Call unit vector with v, 'DEGENERATE NODAL VECTOR', status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          IF (DIMENSION .EQ. 1_I4) THEN                                  ! If dimension = 1:
            FRAMES%GENERAL_TRIAD(:,2,J,G) = V                            ! Set frames.general_triad(:,2,j,g) to v.
            A1 = REFERENCE - DOT_PRODUCT(REFERENCE,V)*V                  ! Set a1 to reference - dot_product(reference,v)*v.
            CALL UNIT_VECTOR(A1, 'SOR IS PARALLEL TO BEAM AXIS', STATUS) ! Call unit vector with a1, 'SOR IS PARALLEL TO BEAM AXIS', status.
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            FRAMES%GENERAL_TRIAD(:,3,J,G) = A1                           ! Set frames.general_triad(:,3,j,g) to a1.
            A2 = CROSS(V,A1)                                             ! Set a2 to cross(v,a1).
            CALL UNIT_VECTOR(A2, 'INVALID BEAM FRAME', STATUS)           ! Call unit vector with a2, 'INVALID BEAM FRAME', status.
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            FRAMES%GENERAL_TRIAD(:,1,J,G) = A2                           ! Set frames.general_triad(:,1,j,g) to a2.
          ELSE                                                           ! Otherwise:
            FRAMES%GENERAL_TRIAD(:,3,J,G) = V                            ! Set frames.general_triad(:,3,j,g) to v.
            A1 = REFERENCE - DOT_PRODUCT(REFERENCE,V)*V                  ! Set a1 to reference - dot_product(reference,v)*v.
            CALL UNIT_VECTOR(A1, 'SOR IS NORMAL TO SURFACE', STATUS)     ! Call unit vector with a1, 'SOR IS NORMAL TO SURFACE', status.
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            FRAMES%GENERAL_TRIAD(:,1,J,G) = A1                           ! Set frames.general_triad(:,1,j,g) to a1.
            A2 = CROSS(V,A1)                                             ! Set a2 to cross(v,a1).
            CALL UNIT_VECTOR(A2, 'INVALID SURFACE FRAME', STATUS)        ! Call unit vector with a2, 'INVALID SURFACE FRAME', status.
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            FRAMES%GENERAL_TRIAD(:,2,J,G) = A2                           ! Set frames.general_triad(:,2,j,g) to a2.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_GENERAL_GEOMETRY                              ! End of the subroutine build general geometry.

!  TRUE WHEN THE NODES ARE NOT ON THE LINE OF A BEAM / IN THE PLANE OF A
!  PLATE.
      LOGICAL FUNCTION IS_CURVED(TOPOLOGY, COORD, N_NODE)                ! Function is curved takes topology, coord, n node.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      REAL(R8), INTENT(IN) :: COORD(:,:)                                 ! Input real (real64): coord(:,:).
      INTEGER(I4), INTENT(IN) :: N_NODE                                  ! Input integer (int32): n_node.
      REAL(R8) :: AXIS(3)                                                ! Real (real64): axis(3).
      REAL(R8) :: NORMAL(3)                                              ! Real (real64): normal(3).
      REAL(R8) :: D1(3)                                                  ! Real (real64): d1(3).
      REAL(R8) :: D2(3)                                                  ! Real (real64): d2(3).
      REAL(R8) :: LENGTH                                                 ! Real (real64): length.
      REAL(R8) :: DEVIATION                                              ! Real (real64): deviation.
      INTEGER(I4) :: C(4)                                                ! Integer (int32): c(4).
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      IS_CURVED = .FALSE.                                                ! Set the flag is_curved to false.
      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_B2)                                                 ! Case topology_b2:
        RETURN                                                           ! Return to the caller.
      CASE (TOPOLOGY_B3, TOPOLOGY_B4)                                    ! Case topology_b3, topology_b4:
        AXIS = COORD(:,N_NODE) - COORD(:,1)                              ! Set axis to coord(:,n_node) - coord(:,1).
        LENGTH = SQRT(DOT_PRODUCT(AXIS,AXIS))                            ! Set length to the square root of dot_product(axis,axis).
        IF (LENGTH .LE. TINY(1.0_R8)) RETURN                             ! If length <= tiny(1.0), return to the caller.
        AXIS = AXIS/LENGTH                                               ! Divide axis by length.
        DO J = 2_I4, N_NODE-1_I4                                         ! Loop j from 2 to n_node-1:
          D1 = COORD(:,J) - COORD(:,1)                                   ! Set d1 to coord(:,j) - coord(:,1).
          D2 = D1 - DOT_PRODUCT(D1,AXIS)*AXIS                            ! Set d2 to d1 - dot_product(d1,axis)*axis.
          IF (SQRT(DOT_PRODUCT(D2,D2)) .GT. CURVED_TOLERANCE*LENGTH)     ! If sqrt(dot_product(d2,d2)) > curved_tolerance*length, set the flag is_curved to true.
     &      IS_CURVED = .TRUE.
        END DO                                                           ! End of the loop.
      CASE (TOPOLOGY_Q4, TOPOLOGY_Q9, TOPOLOGY_Q16)                      ! Case topology_q4, topology_q9, topology_q16:
        SELECT CASE (TOPOLOGY)                                           ! Choose according to the value of topology:
        CASE (TOPOLOGY_Q4)                                               ! Case topology_q4:
          C = [1_I4,2_I4,3_I4,4_I4]                                      ! Set c to [1,2,3,4].
        CASE (TOPOLOGY_Q9)                                               ! Case topology_q9:
          C = [1_I4,3_I4,5_I4,7_I4]                                      ! Set c to [1,3,5,7].
        CASE DEFAULT                                                     ! In every other case:
          C = [1_I4,4_I4,7_I4,10_I4]                                     ! Set c to [1,4,7,10].
        END SELECT                                                       ! End of the case selection.
        D1 = COORD(:,C(3)) - COORD(:,C(1))                               ! Set d1 to coord(:,c(3)) - coord(:,c(1)).
        D2 = COORD(:,C(4)) - COORD(:,C(2))                               ! Set d2 to coord(:,c(4)) - coord(:,c(2)).
        NORMAL = CROSS(D1,D2)                                            ! Set normal to cross(d1,d2).
        LENGTH = SQRT(DOT_PRODUCT(NORMAL,NORMAL))                        ! Set length to the square root of dot_product(normal,normal).
        IF (LENGTH .LE. TINY(1.0_R8)) RETURN                             ! If length <= tiny(1.0), return to the caller.
        NORMAL = NORMAL/LENGTH                                           ! Divide normal by length.
        LENGTH = SQRT(DOT_PRODUCT(D1,D1))                                ! Set length to the square root of dot_product(d1,d1).
        DO J = 2_I4, N_NODE                                              ! Loop j from 2 to n_node:
          DEVIATION = ABS(DOT_PRODUCT(NORMAL,COORD(:,J)-COORD(:,1)))     ! Set deviation to the absolute value of dot_product(normal,coord(:,j)-coord(:,1)).
          IF (DEVIATION .GT. CURVED_TOLERANCE*LENGTH) IS_CURVED = .TRUE. ! If deviation > curved_tolerance*length, set the flag is_curved to true.
        END DO                                                           ! End of the loop.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION IS_CURVED                                             ! End of the function is curved.

      INTEGER(I4) FUNCTION FIND_VECTOR(VECTORS, ID)                      ! Function find vector takes vectors, id.

      TYPE(REFERENCE_VECTOR_DB_TYPE), INTENT(IN) :: VECTORS              ! Input of type reference_vector_db_type: vectors.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_VECTOR = 0_I4                                                 ! Set find_vector to zero.
      IF (.NOT. ALLOCATED(VECTORS%ITEM)) RETURN                          ! If not allocated(vectors.item), return to the caller.
      DO I = 1_I4, SIZE(VECTORS%ITEM)                                    ! Loop i from 1 to size(vectors.item):
        IF (VECTORS%ITEM(I)%ID .EQ. ID) THEN                             ! If vectors.item(i).id = id:
          FIND_VECTOR = I                                                ! Set find_vector to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_VECTOR                                           ! End of the function find vector.

      SUBROUTINE UNIT_VECTOR(V, MESSAGE, STATUS)                         ! Subroutine unit vector takes v, message, status.

      REAL(R8), INTENT(INOUT) :: V(3)                                    ! In/out real (real64): v(3).
      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      REAL(R8) :: LENGTH                                                 ! Real (real64): length.

      LENGTH = SQRT(DOT_PRODUCT(V,V))                                    ! Set length to the square root of dot_product(v,v).
      IF (LENGTH .LE. 100.0_R8*EPSILON(1.0_R8)) THEN                     ! If length <= 100.0*epsilon(1.0):
        CALL SET_ERROR(STATUS, 'GENERAL_GEOMETRY', MESSAGE)              ! Record an error in status: message.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      V = V/LENGTH                                                       ! Divide v by length.

      END SUBROUTINE UNIT_VECTOR                                         ! End of the subroutine unit vector.

      PURE FUNCTION CROSS(A, B) RESULT(C)                                ! Function cross takes a, b and returns c.

      REAL(R8), INTENT(IN) :: A(3)                                       ! Input real (real64): a(3).
      REAL(R8), INTENT(IN) :: B(3)                                       ! Input real (real64): b(3).
      REAL(R8) :: C(3)                                                   ! Real (real64): c(3).

      C(1) = A(2)*B(3) - A(3)*B(2)                                       ! Set c(1) to a(2)*b(3) - a(3)*b(2).
      C(2) = A(3)*B(1) - A(1)*B(3)                                       ! Set c(2) to a(3)*b(1) - a(1)*b(3).
      C(3) = A(1)*B(2) - A(2)*B(1)                                       ! Set c(3) to a(1)*b(2) - a(2)*b(1).

      END FUNCTION CROSS                                                 ! End of the function cross.

      FUNCTION ITOA(VALUE) RESULT(TEXT)                                  ! Function itoa takes value and returns text.

      INTEGER(I8), INTENT(IN) :: VALUE                                   ! Input integer (int64): value.
      CHARACTER(LEN=20) :: TEXT                                          ! Character (length 20): text.

      WRITE(TEXT,'(I0)') VALUE                                           ! Format into the text text: value.
      TEXT = ADJUSTL(TEXT)                                               ! Set text to adjustl(text).

      END FUNCTION ITOA                                                  ! End of the function itoa.

      END MODULE MUL2_GENERAL_GEOMETRY                                   ! End of the module mul2 general geometry.
