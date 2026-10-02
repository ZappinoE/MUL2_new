!=======================================================================
!  GEOMETRIC NODE DEFINITIONS.
!=======================================================================
      MODULE MUL2_NODES                                                  ! Module mul2 nodes begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_SORTING, ONLY: SORT_PERMUTATION, BINARY_SEARCH            ! Use from module mul2 sorting: sort permutation, binary search.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: NODE_TYPE                                          ! Definition of the derived type node type.
        INTEGER(I8) :: ID = 0_I8                                         ! Integer (int64): id = 0.
        REAL(R8) :: COORDINATE(3) = 0.0_R8                               ! Real (real64): coordinate(3) = 0.0.
        INTEGER(I4) :: KINEMATIC_ID = 0_I4                               ! Integer (int32): kinematic_id = 0.
!       EXACT DIRECTOR OF A SHELL NODE (DIRECTORS.DAT, OPTIONAL).
        LOGICAL :: HAS_DIRECTOR = .FALSE.                                ! Logical: has_director = false.
        REAL(R8) :: DIRECTOR(3) = 0.0_R8                                 ! Real (real64): director(3) = 0.0.
      END TYPE NODE_TYPE                                                 ! End of the type definition node type.

!  ID_LIST/ID_ORDER ARE THE SORTED-ID LOOKUP BUILT BY BUILD_NODE_INDEX.
      TYPE, PUBLIC :: NODE_DB_TYPE                                       ! Definition of the derived type node db type.
        TYPE(NODE_TYPE), ALLOCATABLE :: ITEM(:)                          ! Allocatable of type node_type: item(:).
        INTEGER(I8), ALLOCATABLE :: ID_LIST(:)                           ! Allocatable integer (int64): id_list(:).
        INTEGER(I4), ALLOCATABLE :: ID_ORDER(:)                          ! Allocatable integer (int32): id_order(:).
      END TYPE NODE_DB_TYPE                                              ! End of the type definition node db type.

      PUBLIC :: HAS_NODE_ID                                              ! Export: has node id.
      PUBLIC :: FIND_NODE_INDEX                                          ! Export: find node index.
      PUBLIC :: BUILD_NODE_INDEX                                         ! Export: build node index.

      CONTAINS                                                           ! The procedures of the module follow.

      LOGICAL FUNCTION HAS_NODE_ID(NODES, ID)                            ! Function has node id takes nodes, id.

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      INTEGER(I8), INTENT(IN) :: ID                                      ! Input integer (int64): id.
      HAS_NODE_ID = FIND_NODE_INDEX(NODES, ID) .NE. 0_I4                 ! Set has_node_id to find_node_index(nodes, id) /= 0.

      END FUNCTION HAS_NODE_ID                                           ! End of the function has node id.

      INTEGER(I4) FUNCTION FIND_NODE_INDEX(NODES, ID)                    ! Function find node index takes nodes, id.

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      INTEGER(I8), INTENT(IN) :: ID                                      ! Input integer (int64): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_NODE_INDEX = 0_I4                                             ! Set find_node_index to zero.
      IF (.NOT. ALLOCATED(NODES%ITEM)) RETURN                            ! If not allocated(nodes.item), return to the caller.
      IF (ALLOCATED(NODES%ID_ORDER)) THEN                                ! If allocated(nodes.id_order):
        FIND_NODE_INDEX = BINARY_SEARCH(NODES%ID_LIST,                   ! Set find_node_index to binary_search(nodes.id_list, nodes.id_order, id).
     &                                  NODES%ID_ORDER, ID)
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO I = 1_I4, SIZE(NODES%ITEM)                                      ! Loop i from 1 to size(nodes.item):
        IF (NODES%ITEM(I)%ID .EQ. ID) THEN                               ! If nodes.item(i).id = id:
          FIND_NODE_INDEX = I                                            ! Set find_node_index to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_NODE_INDEX                                       ! End of the function find node index.


!  SORTED-ID LOOKUP (O(LOG N) SEARCH); DUPLICATE IDS ARE AN ERROR.
      SUBROUTINE BUILD_NODE_INDEX(NODES, STATUS)                         ! Subroutine build node index takes nodes, status.

      TYPE(NODE_DB_TYPE), INTENT(INOUT) :: NODES                         ! In/out of type node_db_type: nodes.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(NODES%ID_LIST)) DEALLOCATE(NODES%ID_LIST)            ! If allocated(nodes.id_list), free the memory of nodes.id_list.
      IF (ALLOCATED(NODES%ID_ORDER)) DEALLOCATE(NODES%ID_ORDER)          ! If allocated(nodes.id_order), free the memory of nodes.id_order.
      IF (.NOT. ALLOCATED(NODES%ITEM)) RETURN                            ! If not allocated(nodes.item), return to the caller.
      ALLOCATE(NODES%ID_LIST(SIZE(NODES%ITEM)))                          ! Allocate memory for nodes.id_list(size(nodes.item)).
      ALLOCATE(NODES%ID_ORDER(SIZE(NODES%ITEM)))                         ! Allocate memory for nodes.id_order(size(nodes.item)).
      NODES%ID_LIST = NODES%ITEM%ID                                      ! Set nodes.id_list to nodes.item.id.
      CALL SORT_PERMUTATION(NODES%ID_LIST, NODES%ID_ORDER)               ! Call sort permutation with nodes.id_list, nodes.id_order.
      DO I = 2_I4, SIZE(NODES%ITEM)                                      ! Loop i from 2 to size(nodes.item):
        IF (NODES%ID_LIST(NODES%ID_ORDER(I)) .EQ.                        ! If nodes.id_list(nodes.id_order(i)) = nodes.id_list(nodes.id_order(i-1)):
     &      NODES%ID_LIST(NODES%ID_ORDER(I-1_I4))) THEN
          CALL SET_ERROR(STATUS, 'BUILD_NODE_INDEX',                     ! Record an error in status: 'DUPLICATE NODE ID'.
     &                   'DUPLICATE NODE ID')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_NODE_INDEX                                    ! End of the subroutine build node index.
      END MODULE MUL2_NODES                                              ! End of the module mul2 nodes.
