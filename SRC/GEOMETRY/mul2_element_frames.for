!=======================================================================
!  CONSTRUCTION OF RIGHT-HANDED ELEMENT REFERENCE SYSTEMS.
!=======================================================================
      MODULE MUL2_ELEMENT_FRAMES                                         ! Module mul2 element frames begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       SET_ERROR, STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, FIND_NODE_INDEX                ! Use from module mul2 nodes: node db type, find node index.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_REFERENCE_SYSTEMS, ONLY: REFERENCE_VECTOR_DB_TYPE,        ! Use from module mul2 reference systems: reference vector db type, element frame db type.
     &                                  ELEMENT_FRAME_DB_TYPE
      USE MUL2_TOPOLOGIES                                                ! Use everything exported by module mul2 topologies.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: BUILD_ELEMENT_FRAMES                                     ! Export: build element frames.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_ELEMENT_FRAMES(NODES, ELEMENTS,                   ! Subroutine build element frames takes nodes, elements, reference vectors, frames, status.
     &     REFERENCE_VECTORS, FRAMES, STATUS)

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(REFERENCE_VECTOR_DB_TYPE), INTENT(IN) :: REFERENCE_VECTORS    ! Input of type reference_vector_db_type: reference_vectors.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(INOUT) :: FRAMES               ! In/out of type element_frame_db_type: frames.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: NODE_COORDINATE(3,27)                                  ! Real (real64): node_coordinate(3,27).
      REAL(R8) :: REFERENCE_VECTOR(3)                                    ! Real (real64): reference_vector(3).
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: VECTOR_INDEX                                        ! Integer (int32): vector_index.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_FRAMES(FRAMES)                                          ! Call clear frames with frames.
      IF (.NOT. ALLOCATED(NODES%ITEM) .OR.                               ! If not allocated(nodes.item) or not allocated(elements.item):
     &    .NOT. ALLOCATED(ELEMENTS%ITEM)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_FRAMES',                   ! Record an error in status: 'MODEL DATABASES ARE NOT ALLOCATED'.
     &                 'MODEL DATABASES ARE NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(FRAMES%ORIGIN(3,SIZE(ELEMENTS%ITEM)))                     ! Allocate memory for frames.origin(3,size(elements.item)).
      ALLOCATE(FRAMES%GLOBAL_TO_LOCAL(3,3,SIZE(ELEMENTS%ITEM)))          ! Allocate memory for frames.global_to_local(3,3,size(elements.item)).
      ALLOCATE(FRAMES%LOCAL_TO_GLOBAL(3,3,SIZE(ELEMENTS%ITEM)))          ! Allocate memory for frames.local_to_global(3,3,size(elements.item)).
      FRAMES%ORIGIN = 0.0_R8                                             ! Set frames.origin to zero.
      FRAMES%GLOBAL_TO_LOCAL = 0.0_R8                                    ! Set frames.global_to_local to zero.
      FRAMES%LOCAL_TO_GLOBAL = 0.0_R8                                    ! Set frames.local_to_global to zero.

      DO I = 1_I4, SIZE(ELEMENTS%ITEM)                                   ! Loop i from 1 to size(elements.item):
        N_NODE = SIZE(ELEMENTS%ITEM(I)%NODE_ID)                          ! Set n_node to the size of elements.item(i).node_id.
        NODE_COORDINATE = 0.0_R8                                         ! Set node_coordinate to zero.
        DO J = 1_I4, N_NODE                                              ! Loop j from 1 to n_node:
          NODE_INDEX = FIND_NODE_INDEX(NODES,                            ! Set node_index to find_node_index(nodes, elements.item(i).node_id(j)).
     &                 ELEMENTS%ITEM(I)%NODE_ID(J))
          IF (NODE_INDEX .EQ. 0_I4) THEN                                 ! If node_index = 0:
            CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_FRAMES',               ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                     'ELEMENT REFERENCES UNKNOWN NODE')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          NODE_COORDINATE(:,J) = NODES%ITEM(NODE_INDEX)%COORDINATE       ! Set node_coordinate(:,j) to nodes.item(node_index).coordinate.
        END DO                                                           ! End of the loop.
        FRAMES%ORIGIN(:,I) = NODE_COORDINATE(:,1)                        ! Set frames.origin(:,i) to node_coordinate(:,1).
        DIMENSION = TOPOLOGY_NATURAL_DIMENSION(                          ! Set dimension to topology_natural_dimension( elements.item(i).topology).
     &              ELEMENTS%ITEM(I)%TOPOLOGY)
        IF (DIMENSION .EQ. 3_I4) THEN                                    ! If dimension = 3:
          CALL SET_IDENTITY(FRAMES%GLOBAL_TO_LOCAL(:,:,I))               ! Call set identity with frames.global_to_local(:,:,i).
        ELSE                                                             ! Otherwise:
          VECTOR_INDEX = FIND_VECTOR_INDEX(REFERENCE_VECTORS,            ! Set vector_index to find_vector_index(reference_vectors, elements.item(i).frame_id).
     &                   ELEMENTS%ITEM(I)%FRAME_ID)
          IF (VECTOR_INDEX .EQ. 0_I4) THEN                               ! If vector_index = 0:
            CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_FRAMES',               ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN SOR'.
     &                     'ELEMENT REFERENCES UNKNOWN SOR')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          REFERENCE_VECTOR = REFERENCE_VECTORS%ITEM(                     ! Set reference_vector to reference_vectors.item( vector_index).direction.
     &                       VECTOR_INDEX)%DIRECTION
          IF (DIMENSION .EQ. 1_I4) THEN                                  ! If dimension = 1:
            CALL BUILD_BEAM_FRAME(ELEMENTS%ITEM(I)%TOPOLOGY,             ! Call build beam frame with elements.item(i).topology, node_coordinate, reference_vector, frames.global_to_l...
     &           NODE_COORDINATE, REFERENCE_VECTOR,
     &           FRAMES%GLOBAL_TO_LOCAL(:,:,I), STATUS)
          ELSE                                                           ! Otherwise:
            CALL BUILD_SURFACE_FRAME(ELEMENTS%ITEM(I)%TOPOLOGY,          ! Call build surface frame with elements.item(i).topology, node_coordinate, reference_vector, frames.global_t...
     &           NODE_COORDINATE, REFERENCE_VECTOR,
     &           FRAMES%GLOBAL_TO_LOCAL(:,:,I), STATUS)
          END IF                                                         ! End of the IF block.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
        END IF                                                           ! End of the IF block.
        FRAMES%LOCAL_TO_GLOBAL(:,:,I) =                                  ! Set frames.local_to_global(:,:,i) to transpose(frames.global_to_local(:,:,i)).
     &    TRANSPOSE(FRAMES%GLOBAL_TO_LOCAL(:,:,I))
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_ELEMENT_FRAMES                                ! End of the subroutine build element frames.

      SUBROUTINE BUILD_BEAM_FRAME(TOPOLOGY, COORDINATE,                  ! Subroutine build beam frame takes topology, coordinate, reference vector, rotation, status.
     &     REFERENCE_VECTOR, ROTATION, STATUS)

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      REAL(R8), INTENT(IN) :: COORDINATE(3,27)                           ! Input real (real64): coordinate(3,27).
      REAL(R8), INTENT(IN) :: REFERENCE_VECTOR(3)                        ! Input real (real64): reference_vector(3).
      REAL(R8), INTENT(OUT) :: ROTATION(3,3)                             ! Output real (real64): rotation(3,3).
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      REAL(R8) :: EX(3)                                                  ! Real (real64): ex(3).
      REAL(R8) :: EY(3)                                                  ! Real (real64): ey(3).
      REAL(R8) :: EZ(3)                                                  ! Real (real64): ez(3).
      INTEGER(I4) :: END_NODE                                            ! Integer (int32): end_node.

      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_B2)                                                 ! Case topology_b2:
        END_NODE = 2_I4                                                  ! Set end_node to 2.
      CASE (TOPOLOGY_B3)                                                 ! Case topology_b3:
        END_NODE = 3_I4                                                  ! Set end_node to 3.
      CASE (TOPOLOGY_B4)                                                 ! Case topology_b4:
        END_NODE = 4_I4                                                  ! Set end_node to 4.
      CASE DEFAULT                                                       ! In every other case:
        CALL SET_ERROR(STATUS, 'BUILD_BEAM_FRAME',                       ! Record an error in status: 'INVALID BEAM TOPOLOGY'.
     &                 'INVALID BEAM TOPOLOGY')
        RETURN                                                           ! Return to the caller.
      END SELECT                                                         ! End of the case selection.
      EY = COORDINATE(:,END_NODE)-COORDINATE(:,1)                        ! Set ey to coordinate(:,end_node)-coordinate(:,1).
      CALL NORMALIZE(EY, 'DEGENERATE BEAM AXIS', STATUS)                 ! Call normalize with ey, 'DEGENERATE BEAM AXIS', status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      EZ = REFERENCE_VECTOR-DOT_PRODUCT(REFERENCE_VECTOR,EY)*EY          ! Set ez to reference_vector-dot_product(reference_vector,ey)*ey.
      CALL NORMALIZE(EZ, 'SOR IS PARALLEL TO BEAM AXIS', STATUS)         ! Call normalize with ez, 'SOR IS PARALLEL TO BEAM AXIS', status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      EX = CROSS_PRODUCT(EY,EZ)                                          ! Set ex to cross_product(ey,ez).
      CALL NORMALIZE(EX, 'INVALID BEAM FRAME', STATUS)                   ! Call normalize with ex, 'INVALID BEAM FRAME', status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      EZ = CROSS_PRODUCT(EX,EY)                                          ! Set ez to cross_product(ex,ey).
      ROTATION(1,:) = EX                                                 ! Set rotation(1,:) to ex.
      ROTATION(2,:) = EY                                                 ! Set rotation(2,:) to ey.
      ROTATION(3,:) = EZ                                                 ! Set rotation(3,:) to ez.

      END SUBROUTINE BUILD_BEAM_FRAME                                    ! End of the subroutine build beam frame.

      SUBROUTINE BUILD_SURFACE_FRAME(TOPOLOGY, COORDINATE,               ! Subroutine build surface frame takes topology, coordinate, reference vector, rotation, status.
     &     REFERENCE_VECTOR, ROTATION, STATUS)

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      REAL(R8), INTENT(IN) :: COORDINATE(3,27)                           ! Input real (real64): coordinate(3,27).
      REAL(R8), INTENT(IN) :: REFERENCE_VECTOR(3)                        ! Input real (real64): reference_vector(3).
      REAL(R8), INTENT(OUT) :: ROTATION(3,3)                             ! Output real (real64): rotation(3,3).
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      REAL(R8) :: EX(3)                                                  ! Real (real64): ex(3).
      REAL(R8) :: EY(3)                                                  ! Real (real64): ey(3).
      REAL(R8) :: EZ(3)                                                  ! Real (real64): ez(3).
      REAL(R8) :: V1(3)                                                  ! Real (real64): v1(3).
      REAL(R8) :: V2(3)                                                  ! Real (real64): v2(3).
      INTEGER(I4) :: CORNER_2                                            ! Integer (int32): corner_2.
      INTEGER(I4) :: CORNER_3                                            ! Integer (int32): corner_3.

      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_Q4)                                                 ! Case topology_q4:
        CORNER_2 = 2_I4                                                  ! Set corner_2 to 2.
        CORNER_3 = 4_I4                                                  ! Set corner_3 to 4.
      CASE (TOPOLOGY_Q9)                                                 ! Case topology_q9:
        CORNER_2 = 3_I4                                                  ! Set corner_2 to 3.
        CORNER_3 = 7_I4                                                  ! Set corner_3 to 7.
      CASE (TOPOLOGY_Q16)                                                ! Case topology_q16:
        CORNER_2 = 4_I4                                                  ! Set corner_2 to 4.
        CORNER_3 = 10_I4                                                 ! Set corner_3 to 10.
      CASE (TOPOLOGY_T3,TOPOLOGY_T6)                                     ! Case topology_t3,topology_t6:
        CORNER_2 = 2_I4                                                  ! Set corner_2 to 2.
        CORNER_3 = 3_I4                                                  ! Set corner_3 to 3.
      CASE DEFAULT                                                       ! In every other case:
        CALL SET_ERROR(STATUS, 'BUILD_SURFACE_FRAME',                    ! Record an error in status: 'INVALID SURFACE TOPOLOGY'.
     &                 'INVALID SURFACE TOPOLOGY')
        RETURN                                                           ! Return to the caller.
      END SELECT                                                         ! End of the case selection.
      V1 = COORDINATE(:,CORNER_2)-COORDINATE(:,1)                        ! Set v1 to coordinate(:,corner_2)-coordinate(:,1).
      V2 = COORDINATE(:,CORNER_3)-COORDINATE(:,1)                        ! Set v2 to coordinate(:,corner_3)-coordinate(:,1).
      EZ = CROSS_PRODUCT(V1,V2)                                          ! Set ez to cross_product(v1,v2).
      CALL NORMALIZE(EZ, 'DEGENERATE SURFACE', STATUS)                   ! Call normalize with ez, 'DEGENERATE SURFACE', status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      EX = REFERENCE_VECTOR-DOT_PRODUCT(REFERENCE_VECTOR,EZ)*EZ          ! Set ex to reference_vector-dot_product(reference_vector,ez)*ez.
      CALL NORMALIZE(EX, 'SOR IS NORMAL TO SURFACE', STATUS)             ! Call normalize with ex, 'SOR IS NORMAL TO SURFACE', status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      EY = CROSS_PRODUCT(EZ,EX)                                          ! Set ey to cross_product(ez,ex).
      CALL NORMALIZE(EY, 'INVALID SURFACE FRAME', STATUS)                ! Call normalize with ey, 'INVALID SURFACE FRAME', status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      EX = CROSS_PRODUCT(EY,EZ)                                          ! Set ex to cross_product(ey,ez).
      ROTATION(1,:) = EX                                                 ! Set rotation(1,:) to ex.
      ROTATION(2,:) = EY                                                 ! Set rotation(2,:) to ey.
      ROTATION(3,:) = EZ                                                 ! Set rotation(3,:) to ez.

      END SUBROUTINE BUILD_SURFACE_FRAME                                 ! End of the subroutine build surface frame.

      SUBROUTINE NORMALIZE(VECTOR, MESSAGE, STATUS)                      ! Subroutine normalize takes vector, message, status.

      REAL(R8), INTENT(INOUT) :: VECTOR(3)                               ! In/out real (real64): vector(3).
      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      REAL(R8) :: LENGTH                                                 ! Real (real64): length.

      LENGTH = SQRT(DOT_PRODUCT(VECTOR,VECTOR))                          ! Set length to the square root of dot_product(vector,vector).
      IF (LENGTH .LE. 100.0_R8*EPSILON(1.0_R8)) THEN                     ! If length <= 100.0*epsilon(1.0):
        CALL SET_ERROR(STATUS, 'NORMALIZE', MESSAGE)                     ! Record an error in status: message.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      VECTOR = VECTOR/LENGTH                                             ! Divide vector by length.

      END SUBROUTINE NORMALIZE                                           ! End of the subroutine normalize.

      PURE FUNCTION CROSS_PRODUCT(A, B) RESULT(C)                        ! Function cross product takes a, b and returns c.

      REAL(R8), INTENT(IN) :: A(3)                                       ! Input real (real64): a(3).
      REAL(R8), INTENT(IN) :: B(3)                                       ! Input real (real64): b(3).
      REAL(R8) :: C(3)                                                   ! Real (real64): c(3).

      C(1) = A(2)*B(3)-A(3)*B(2)                                         ! Set c(1) to a(2)*b(3)-a(3)*b(2).
      C(2) = A(3)*B(1)-A(1)*B(3)                                         ! Set c(2) to a(3)*b(1)-a(1)*b(3).
      C(3) = A(1)*B(2)-A(2)*B(1)                                         ! Set c(3) to a(1)*b(2)-a(2)*b(1).

      END FUNCTION CROSS_PRODUCT                                         ! End of the function cross product.

      INTEGER(I4) FUNCTION FIND_VECTOR_INDEX(DATABASE, ID)               ! Function find vector index takes database, id.

      TYPE(REFERENCE_VECTOR_DB_TYPE), INTENT(IN) :: DATABASE             ! Input of type reference_vector_db_type: database.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_VECTOR_INDEX = 0_I4                                           ! Set find_vector_index to zero.
      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (DATABASE%ITEM(I)%ID .EQ. ID) THEN                            ! If database.item(i).id = id:
          FIND_VECTOR_INDEX = I                                          ! Set find_vector_index to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_VECTOR_INDEX                                     ! End of the function find vector index.

      SUBROUTINE SET_IDENTITY(MATRIX)                                    ! Subroutine set identity takes matrix.

      REAL(R8), INTENT(OUT) :: MATRIX(3,3)                               ! Output real (real64): matrix(3,3).

      MATRIX = 0.0_R8                                                    ! Set matrix to zero.
      MATRIX(1,1) = 1.0_R8                                               ! Set matrix(1,1) to 1.0.
      MATRIX(2,2) = 1.0_R8                                               ! Set matrix(2,2) to 1.0.
      MATRIX(3,3) = 1.0_R8                                               ! Set matrix(3,3) to 1.0.

      END SUBROUTINE SET_IDENTITY                                        ! End of the subroutine set identity.

      SUBROUTINE CLEAR_FRAMES(FRAMES)                                    ! Subroutine clear frames takes frames.

      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(INOUT) :: FRAMES               ! In/out of type element_frame_db_type: frames.

      IF (ALLOCATED(FRAMES%ORIGIN)) DEALLOCATE(FRAMES%ORIGIN)            ! If allocated(frames.origin), free the memory of frames.origin.
      IF (ALLOCATED(FRAMES%GLOBAL_TO_LOCAL))                             ! If allocated(frames.global_to_local), free the memory of frames.global_to_local.
     &  DEALLOCATE(FRAMES%GLOBAL_TO_LOCAL)
      IF (ALLOCATED(FRAMES%LOCAL_TO_GLOBAL))                             ! If allocated(frames.local_to_global), free the memory of frames.local_to_global.
     &  DEALLOCATE(FRAMES%LOCAL_TO_GLOBAL)

      END SUBROUTINE CLEAR_FRAMES                                        ! End of the subroutine clear frames.

      END MODULE MUL2_ELEMENT_FRAMES                                     ! End of the module mul2 element frames.
