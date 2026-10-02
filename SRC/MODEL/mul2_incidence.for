!=======================================================================
!  NODE-TO-ELEMENT INCIDENCE (CSR): THE ELEMENTS TOUCHING EACH NODE.
!=======================================================================
      MODULE MUL2_INCIDENCE                                              ! Module mul2 incidence begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, FIND_NODE_INDEX                ! Use from module mul2 nodes: node db type, find node index.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!  ELEMENTS OF NODE I: ELEMENT(FIRST(I):FIRST(I+1)-1), ASCENDING.
      TYPE, PUBLIC :: NODE_INCIDENCE_TYPE                                ! Definition of the derived type node incidence type.
        INTEGER(I4), ALLOCATABLE :: FIRST(:)                             ! Allocatable integer (int32): first(:).
        INTEGER(I4), ALLOCATABLE :: ELEMENT(:)                           ! Allocatable integer (int32): element(:).
      END TYPE NODE_INCIDENCE_TYPE                                       ! End of the type definition node incidence type.

      PUBLIC :: BUILD_NODE_INCIDENCE                                     ! Export: build node incidence.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_NODE_INCIDENCE(NODES, ELEMENTS, INCIDENCE,        ! Subroutine build node incidence takes nodes, elements, incidence, status.
     &                                STATUS)

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(NODE_INCIDENCE_TYPE), INTENT(INOUT) :: INCIDENCE              ! In/out of type node_incidence_type: incidence.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4), ALLOCATABLE :: FILL(:)                                ! Allocatable integer (int32): fill(:).
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: PASS                                                ! Integer (int32): pass.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(INCIDENCE%FIRST)) DEALLOCATE(INCIDENCE%FIRST)        ! If allocated(incidence.first), free the memory of incidence.first.
      IF (ALLOCATED(INCIDENCE%ELEMENT)) DEALLOCATE(INCIDENCE%ELEMENT)    ! If allocated(incidence.element), free the memory of incidence.element.
      ALLOCATE(INCIDENCE%FIRST(SIZE(NODES%ITEM)+1))                      ! Allocate memory for incidence.first(size(nodes.item)+1).
      INCIDENCE%FIRST = 0_I4                                             ! Set incidence.first to zero.
      DO PASS = 1_I4, 2_I4                                               ! Loop pass from 1 to 2:
        DO E = 1_I4, SIZE(ELEMENTS%ITEM)                                 ! Loop e from 1 to size(elements.item):
          DO J = 1_I4, SIZE(ELEMENTS%ITEM(E)%NODE_ID)                    ! Loop j from 1 to size(elements.item(e).node_id):
            NODE_INDEX = FIND_NODE_INDEX(NODES,                          ! Set node_index to find_node_index(nodes, elements.item(e).node_id(j)).
     &                   ELEMENTS%ITEM(E)%NODE_ID(J))
            IF (NODE_INDEX .EQ. 0_I4) THEN                               ! If node_index = 0:
              CALL SET_ERROR(STATUS, 'BUILD_NODE_INCIDENCE',             ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                       'ELEMENT REFERENCES UNKNOWN NODE')
              RETURN                                                     ! Return to the caller.
            END IF                                                       ! End of the IF block.
            IF (PASS .EQ. 1_I4) THEN                                     ! If pass = 1:
              INCIDENCE%FIRST(NODE_INDEX+1) =                            ! Add 1 to incidence.first(node_index+1).
     &          INCIDENCE%FIRST(NODE_INDEX+1) + 1_I4
            ELSE                                                         ! Otherwise:
              INCIDENCE%ELEMENT(FILL(NODE_INDEX)) = E                    ! Set incidence.element(fill(node_index)) to e.
              FILL(NODE_INDEX) = FILL(NODE_INDEX) + 1_I4                 ! Add 1 to fill(node_index).
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        IF (PASS .EQ. 1_I4) THEN                                         ! If pass = 1:
          INCIDENCE%FIRST(1) = 1_I4                                      ! Set incidence.first(1) to 1.
          DO NODE_INDEX = 1_I4, SIZE(NODES%ITEM)                         ! Loop node_index from 1 to size(nodes.item):
            INCIDENCE%FIRST(NODE_INDEX+1) =                              ! Add incidence.first(node_index) to incidence.first(node_index+1).
     &        INCIDENCE%FIRST(NODE_INDEX+1) +
     &        INCIDENCE%FIRST(NODE_INDEX)
          END DO                                                         ! End of the loop.
          ALLOCATE(INCIDENCE%ELEMENT(INCIDENCE%FIRST(                    ! Allocate memory for incidence.element(incidence.first( size(nodes.item)+1)-1).
     &                               SIZE(NODES%ITEM)+1)-1_I4))
          ALLOCATE(FILL(SIZE(NODES%ITEM)))                               ! Allocate memory for fill(size(nodes.item)).
          FILL = INCIDENCE%FIRST(1:SIZE(NODES%ITEM))                     ! Set fill to incidence.first(1:size(nodes.item)).
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_NODE_INCIDENCE                                ! End of the subroutine build node incidence.

      END MODULE MUL2_INCIDENCE                                          ! End of the module mul2 incidence.
