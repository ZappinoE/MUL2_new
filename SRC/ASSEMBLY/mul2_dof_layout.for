!=======================================================================
!  FIELD-MAJOR GLOBAL DEGREE-OF-FREEDOM NUMBERING.
!=======================================================================
      MODULE MUL2_DOF_LAYOUT                                             ! Module mul2 dof layout begins.

      USE MUL2_KINDS, ONLY: I4, I8                                       ! Use from module mul2 kinds: i4, i8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error, status is ok.
     &                       SET_WARNING, SET_ERROR, STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE                                 ! Use from module mul2 nodes: node db type.
      USE MUL2_INCIDENCE, ONLY: NODE_INCIDENCE_TYPE,                     ! Use from module mul2 incidence: node incidence type, build node incidence.
     &                          BUILD_NODE_INCIDENCE
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE,                     ! Use from module mul2 kinematics: kinematics db type, expansion spec type, n fields, expansion none, expansi...
     &     EXPANSION_SPEC_TYPE, N_FIELDS, EXPANSION_NONE,
     &     EXPANSION_TE, EXPANSION_LE, EXPANSION_HLE,
     &     EXPANSION_MISC, FIND_KINEMATIC_INDEX
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE,                ! Use from module mul2 expansion meshes: expansion db type, find expansion index, expansion term count.
     &     FIND_EXPANSION_INDEX, EXPANSION_TERM_COUNT
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION              ! Use from module mul2 topologies: topology natural dimension.
      USE MUL2_CUF_BASES, ONLY: TAYLOR_BASIS_TERM_COUNT                  ! Use from module mul2 cuf bases: taylor basis term count.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: DOF_LAYOUT_TYPE                                    ! Definition of the derived type dof layout type.
        INTEGER(I4), ALLOCATABLE :: TERM_COUNT(:,:)                      ! Allocatable integer (int32): term_count(:,:).
        INTEGER(I8), ALLOCATABLE :: FIRST(:,:)                           ! Allocatable integer (int64): first(:,:).
        INTEGER(I8) :: FIELD_FIRST(N_FIELDS) = 0_I8                      ! Integer (int64): field_first(n_fields) = 0.
        INTEGER(I8) :: FIELD_LAST(N_FIELDS) = 0_I8                       ! Integer (int64): field_last(n_fields) = 0.
        INTEGER(I8) :: TOTAL_DOF = 0_I8                                  ! Integer (int64): total_dof = 0.
!       DOFS JOINED BY COINCIDENCE (JOIN COINCIDENT): PROVISIONAL
!       NUMBER -> FINAL NUMBER. NOT ALLOCATED WHEN NOTHING IS JOINED.
        INTEGER(I8), ALLOCATABLE :: ALIAS(:)                             ! Allocatable integer (int64): alias(:).
      END TYPE DOF_LAYOUT_TYPE                                           ! End of the type definition dof layout type.

      PUBLIC :: BUILD_DOF_LAYOUT                                         ! Export: build dof layout.
      PUBLIC :: GLOBAL_DOF                                               ! Export: global dof.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_DOF_LAYOUT(NODES, ELEMENTS, KINEMATICS,           ! Subroutine build dof layout takes nodes, elements, kinematics, expansions, layout, status.
     &                            EXPANSIONS, LAYOUT, STATUS)

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(DOF_LAYOUT_TYPE), INTENT(INOUT) :: LAYOUT                     ! In/out of type dof_layout_type: layout.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(NODE_INCIDENCE_TYPE) :: INCIDENCE                             ! Of type node_incidence_type: incidence.
      INTEGER(I8) :: NEXT_DOF                                            ! Integer (int64): next_dof.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: TERM_COUNT                                          ! Integer (int32): term_count.
      INTEGER(I4) :: UNUSED_COUNT                                        ! Integer (int32): unused_count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_LAYOUT(LAYOUT)                                          ! Call clear layout with layout.
      IF (.NOT. ALLOCATED(NODES%ITEM) .OR.                               ! If not allocated(nodes.item) or not allocated(elements.item) or not allocated(kinematics.item) or not alloc...
     &    .NOT. ALLOCATED(ELEMENTS%ITEM) .OR.
     &    .NOT. ALLOCATED(KINEMATICS%ITEM) .OR.
     &    .NOT. ALLOCATED(EXPANSIONS%ITEM)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_DOF_LAYOUT',                       ! Record an error in status: 'MODEL DATABASES ARE NOT ALLOCATED'.
     &                 'MODEL DATABASES ARE NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL BUILD_NODE_INCIDENCE(NODES, ELEMENTS, INCIDENCE, STATUS)      ! Call build node incidence with nodes, elements, incidence, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      ALLOCATE(LAYOUT%TERM_COUNT(SIZE(NODES%ITEM),N_FIELDS))             ! Allocate memory for layout.term_count(size(nodes.item),n_fields).
      ALLOCATE(LAYOUT%FIRST(SIZE(NODES%ITEM),N_FIELDS))                  ! Allocate memory for layout.first(size(nodes.item),n_fields).
      LAYOUT%TERM_COUNT = 0_I4                                           ! Set layout.term_count to zero.
      LAYOUT%FIRST = 0_I8                                                ! Set layout.first to zero.
      UNUSED_COUNT = 0_I4                                                ! Set unused_count to zero.

      DO I = 1_I4, SIZE(NODES%ITEM)                                      ! Loop i from 1 to size(nodes.item):
        KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(KINEMATICS,               ! Set kinematic_index to find_kinematic_index(kinematics, nodes.item(i).kinematic_id).
     &                    NODES%ITEM(I)%KINEMATIC_ID)
        IF (KINEMATIC_INDEX .EQ. 0_I4) THEN                              ! If kinematic_index = 0:
          CALL SET_ERROR(STATUS, 'BUILD_DOF_LAYOUT',                     ! Record an error in status: 'NODE REFERENCES UNKNOWN KINEMATIC'.
     &                   'NODE REFERENCES UNKNOWN KINEMATIC')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (INCIDENCE%FIRST(I+1) .EQ. INCIDENCE%FIRST(I)) THEN           ! If incidence.first(i+1) = incidence.first(i):
          UNUSED_COUNT = UNUSED_COUNT + 1_I4                             ! Add 1 to unused_count.
          CYCLE                                                          ! Skip to the next iteration.
        END IF                                                           ! End of the IF block.
        DO FIELD = 1_I4, N_FIELDS                                        ! Loop field from 1 to n_fields:
          CALL NODE_FIELD_TERM_COUNT(                                    ! Call node field term count with incidence.element(incidence.first(i): incidence.first(i+1)-1), kinematics.i...
     &         INCIDENCE%ELEMENT(INCIDENCE%FIRST(I):
     &                           INCIDENCE%FIRST(I+1)-1_I4),
     &         KINEMATICS%ITEM(KINEMATIC_INDEX)%FIELD(FIELD),
     &         ELEMENTS, EXPANSIONS, TERM_COUNT, STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          LAYOUT%TERM_COUNT(I,FIELD) = TERM_COUNT                        ! Set layout.term_count(i,field) to term_count.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      NEXT_DOF = 1_I8                                                    ! Set next_dof to 1.
      DO FIELD = 1_I4, N_FIELDS                                          ! Loop field from 1 to n_fields:
        LAYOUT%FIELD_FIRST(FIELD) = NEXT_DOF                             ! Set layout.field_first(field) to next_dof.
        DO I = 1_I4, SIZE(NODES%ITEM)                                    ! Loop i from 1 to size(nodes.item):
          TERM_COUNT = LAYOUT%TERM_COUNT(I,FIELD)                        ! Set term_count to layout.term_count(i,field).
          IF (TERM_COUNT .GT. 0_I4) THEN                                 ! If term_count > 0:
            LAYOUT%FIRST(I,FIELD) = NEXT_DOF                             ! Set layout.first(i,field) to next_dof.
            NEXT_DOF = NEXT_DOF + INT(TERM_COUNT,I8)                     ! Add int(term_count,i8) to next_dof.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        LAYOUT%FIELD_LAST(FIELD) = NEXT_DOF - 1_I8                       ! Set layout.field_last(field) to next_dof - 1.
        IF (LAYOUT%FIELD_LAST(FIELD) .LT.                                ! If layout.field_last(field) < layout.field_first(field):
     &      LAYOUT%FIELD_FIRST(FIELD)) THEN
          LAYOUT%FIELD_FIRST(FIELD) = 0_I8                               ! Set layout.field_first(field) to zero.
          LAYOUT%FIELD_LAST(FIELD) = 0_I8                                ! Set layout.field_last(field) to zero.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      LAYOUT%TOTAL_DOF = NEXT_DOF - 1_I8                                 ! Set layout.total_dof to next_dof - 1.

      IF (UNUSED_COUNT .GT. 0_I4) THEN                                   ! If unused_count > 0:
        CALL SET_WARNING(STATUS, 'BUILD_DOF_LAYOUT',                     ! Record a warning in status: 'UNUSED NODES HAVE NO DEGREES OF FREEDOM'.
     &                   'UNUSED NODES HAVE NO DEGREES OF FREEDOM')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE BUILD_DOF_LAYOUT                                    ! End of the subroutine build dof layout.

      SUBROUTINE NODE_FIELD_TERM_COUNT(INCIDENT, SPEC, ELEMENTS,         ! Subroutine node field term count takes incident, spec, elements, expansions, count, status.
     &                                 EXPANSIONS, COUNT, STATUS)

      INTEGER(I4), INTENT(IN) :: INCIDENT(:)                             ! Input integer (int32): incident(:).
      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: SPEC                      ! Input of type expansion_spec_type: spec.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      INTEGER(I4), INTENT(OUT) :: COUNT                                  ! Output integer (int32): count.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I4) :: CANDIDATE                                           ! Integer (int32): candidate.
      INTEGER(I4) :: EXPANSION_DIMENSION                                 ! Integer (int32): expansion_dimension.
      INTEGER(I4) :: BASIS_ID                                            ! Integer (int32): basis_id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.

      COUNT = 0_I4                                                       ! Set count to zero.
      BASIS_ID = 0_I4                                                    ! Set basis_id to zero.
      IF (SPEC%FAMILY .EQ. EXPANSION_NONE) RETURN                        ! If spec.family = expansion_none, return to the caller.
      IF (SPEC%FAMILY .EQ. EXPANSION_MISC) THEN                          ! If spec.family = expansion_misc:
        CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',                  ! Record an error in status: 'MISCELLANEOUS BASIS IS NOT IMPLEMENTED YET'.
     &                 'MISCELLANEOUS BASIS IS NOT IMPLEMENTED YET')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      DO K = 1_I4, SIZE(INCIDENT)                                        ! Loop k from 1 to size(incident):
        I = INCIDENT(K)                                                  ! Set i to incident(k).
        SELECT CASE (SPEC%FAMILY)                                        ! Choose according to the value of spec.family:
        CASE (EXPANSION_TE)                                              ! Case expansion_te:
          EXPANSION_DIMENSION = EXPANSION_DIMENSION_FOR_ELEMENT(         ! Set expansion_dimension to expansion_dimension_for_element( elements.item(i).expansion_id, expansions).
     &      ELEMENTS%ITEM(I)%EXPANSION_ID, EXPANSIONS)
          IF (EXPANSION_DIMENSION .EQ. -1_I4) THEN                       ! If expansion_dimension = -1:
            CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',              ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN EXPANSION'.
     &                     'ELEMENT REFERENCES UNKNOWN EXPANSION')
            RETURN                                                       ! Return to the caller.
          ELSE IF (EXPANSION_DIMENSION .EQ. -2_I4) THEN                  ! Otherwise, if expansion_dimension = -2:
            CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',              ! Record an error in status: 'EXPANSION HAS MIXED DIMENSIONS'.
     &                     'EXPANSION HAS MIXED DIMENSIONS')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          CANDIDATE = TAYLOR_BASIS_TERM_COUNT(SPEC%ORDER,                ! Set candidate to taylor_basis_term_count(spec.order, expansion_dimension).
     &                                        EXPANSION_DIMENSION)
        CASE (EXPANSION_LE, EXPANSION_HLE)                               ! Case expansion_le, expansion_hle:
          CANDIDATE = LAGRANGE_TERM_COUNT(                               ! Set candidate to lagrange_term_count( elements.item(i).expansion_id, expansions).
     &      ELEMENTS%ITEM(I)%EXPANSION_ID, EXPANSIONS)
          IF (CANDIDATE .EQ. 0_I4) THEN                                  ! If candidate = 0:
            CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',              ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN EXPANSION'.
     &                     'ELEMENT REFERENCES UNKNOWN EXPANSION')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          IF ((SPEC%FAMILY .EQ. EXPANSION_HLE) .NEQV.                    ! If (spec.family = expansion_hle) differs from mesh_is_hle(elements.item(i).expansion_id, expansions):
     &        MESH_IS_HLE(ELEMENTS%ITEM(I)%EXPANSION_ID,
     &        EXPANSIONS)) THEN
            CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',              ! Record an error in status: 'HLE NODES NEED A HLE SECTION MESH (HQ4/HB2) AND '// 'LE NODES A LAGRANGE ONE'.
     &        'HLE NODES NEED A HLE SECTION MESH (HQ4/HB2) AND '//
     &        'LE NODES A LAGRANGE ONE')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          IF (BASIS_ID .EQ. 0_I4) THEN                                   ! If basis_id = 0:
            BASIS_ID = ELEMENTS%ITEM(I)%EXPANSION_ID                     ! Set basis_id to elements.item(i).expansion_id.
          ELSE IF (BASIS_ID .NE.                                         ! Otherwise, if basis_id /= elements.item(i).expansion_id:
     &             ELEMENTS%ITEM(I)%EXPANSION_ID) THEN
            CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',              ! Record an error in status: 'LE NODE USES INCOMPATIBLE EXPANSIONS'.
     &                     'LE NODE USES INCOMPATIBLE EXPANSIONS')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',                ! Record an error in status: 'UNKNOWN EXPANSION FAMILY'.
     &                   'UNKNOWN EXPANSION FAMILY')
          RETURN                                                         ! Return to the caller.
        END SELECT                                                       ! End of the case selection.

        IF (CANDIDATE .LT. 1_I4) THEN                                    ! If candidate < 1:
          CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',                ! Record an error in status: 'INVALID EXPANSION TERM COUNT'.
     &                   'INVALID EXPANSION TERM COUNT')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (COUNT .EQ. 0_I4) THEN                                        ! If count = 0:
          COUNT = CANDIDATE                                              ! Set count to candidate.
        ELSE IF (COUNT .NE. CANDIDATE) THEN                              ! Otherwise, if count /= candidate:
          CALL SET_ERROR(STATUS, 'NODE_FIELD_TERM_COUNT',                ! Record an error in status: 'NODE HAS INCOMPATIBLE EXPANSION DIMENSIONS'.
     &                   'NODE HAS INCOMPATIBLE EXPANSION DIMENSIONS')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE NODE_FIELD_TERM_COUNT                               ! End of the subroutine node field term count.

      INTEGER(I4) FUNCTION LAGRANGE_TERM_COUNT(EXPANSION_ID,             ! Function lagrange term count takes expansion id, expansions.
     &                                         EXPANSIONS)

      INTEGER(I4), INTENT(IN) :: EXPANSION_ID                            ! Input integer (int32): expansion_id.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      LAGRANGE_TERM_COUNT = 0_I4                                         ! Set lagrange_term_count to zero.
      DO I = 1_I4, SIZE(EXPANSIONS%ITEM)                                 ! Loop i from 1 to size(expansions.item):
        IF (EXPANSIONS%ITEM(I)%ID .EQ. EXPANSION_ID) THEN                ! If expansions.item(i).id = expansion_id:
          LAGRANGE_TERM_COUNT = EXPANSION_TERM_COUNT(                    ! Set lagrange_term_count to expansion_term_count( expansions.item(i)).
     &                          EXPANSIONS%ITEM(I))
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION LAGRANGE_TERM_COUNT                                   ! End of the function lagrange term count.

      LOGICAL FUNCTION MESH_IS_HLE(EXPANSION_ID, EXPANSIONS)             ! Function mesh is hle takes expansion id, expansions.

      INTEGER(I4), INTENT(IN) :: EXPANSION_ID                            ! Input integer (int32): expansion_id.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      MESH_IS_HLE = .FALSE.                                              ! Set the flag mesh_is_hle to false.
      DO I = 1_I4, SIZE(EXPANSIONS%ITEM)                                 ! Loop i from 1 to size(expansions.item):
        IF (EXPANSIONS%ITEM(I)%ID .EQ. EXPANSION_ID) THEN                ! If expansions.item(i).id = expansion_id:
          MESH_IS_HLE = EXPANSIONS%ITEM(I)%IS_HLE                        ! Set mesh_is_hle to expansions.item(i).is_hle.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION MESH_IS_HLE                                           ! End of the function mesh is hle.

      INTEGER(I4) FUNCTION EXPANSION_DIMENSION_FOR_ELEMENT(              ! Function expansion dimension for element takes expansion id, expansions.
     &     EXPANSION_ID, EXPANSIONS)

      INTEGER(I4), INTENT(IN) :: EXPANSION_ID                            ! Input integer (int32): expansion_id.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      EXPANSION_DIMENSION_FOR_ELEMENT = -1_I4                            ! Set expansion_dimension_for_element to -1.
      MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,EXPANSION_ID)         ! Set mesh_index to find_expansion_index(expansions,expansion_id).
      IF (MESH_INDEX .EQ. 0_I4) RETURN                                   ! If mesh_index = 0, return to the caller.
      IF (.NOT. ALLOCATED(EXPANSIONS%ITEM(MESH_INDEX)%ELEMENT)) RETURN   ! If not allocated(expansions.item(mesh_index).element), return to the caller.
      IF (SIZE(EXPANSIONS%ITEM(MESH_INDEX)%ELEMENT) .LT. 1_I4) RETURN    ! If size(expansions.item(mesh_index).element) < 1, return to the caller.
      EXPANSION_DIMENSION_FOR_ELEMENT =                                  ! Set expansion_dimension_for_element to topology_natural_dimension(expansions.item(mesh_index). element(1).t...
     &  TOPOLOGY_NATURAL_DIMENSION(EXPANSIONS%ITEM(MESH_INDEX)%
     &                             ELEMENT(1)%TOPOLOGY)
      DO I = 2_I4, SIZE(EXPANSIONS%ITEM(MESH_INDEX)%ELEMENT)             ! Loop i from 2 to size(expansions.item(mesh_index).element):
        DIMENSION = TOPOLOGY_NATURAL_DIMENSION(                          ! Set dimension to topology_natural_dimension( expansions.item(mesh_index).element(i).topology).
     &    EXPANSIONS%ITEM(MESH_INDEX)%ELEMENT(I)%TOPOLOGY)
        IF (DIMENSION .NE. EXPANSION_DIMENSION_FOR_ELEMENT) THEN         ! If dimension /= expansion_dimension_for_element:
          EXPANSION_DIMENSION_FOR_ELEMENT = -2_I4                        ! Set expansion_dimension_for_element to -2.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION EXPANSION_DIMENSION_FOR_ELEMENT                       ! End of the function expansion dimension for element.

      INTEGER(I8) FUNCTION GLOBAL_DOF(LAYOUT, NODE_INDEX,                ! Function global dof takes layout, node index, field, term.
     &                                FIELD, TERM)

      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: LAYOUT                        ! Input of type dof_layout_type: layout.
      INTEGER(I4), INTENT(IN) :: NODE_INDEX                              ! Input integer (int32): node_index.
      INTEGER(I4), INTENT(IN) :: FIELD                                   ! Input integer (int32): field.
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.

      GLOBAL_DOF = 0_I8                                                  ! Set global_dof to zero.
      IF (.NOT. ALLOCATED(LAYOUT%FIRST)) RETURN                          ! If not allocated(layout.first), return to the caller.
      IF (NODE_INDEX .LT. 1_I4 .OR.                                      ! If node_index < 1 or node_index > size(layout.first,1), return to the caller.
     &    NODE_INDEX .GT. SIZE(LAYOUT%FIRST,1)) RETURN
      IF (FIELD .LT. 1_I4 .OR. FIELD .GT. N_FIELDS) RETURN               ! If field < 1 or field > n_fields, return to the caller.
      IF (TERM .LT. 1_I4 .OR.                                            ! If term < 1 or term > layout.term_count(node_index,field), return to the caller.
     &    TERM .GT. LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)) RETURN
      GLOBAL_DOF = LAYOUT%FIRST(NODE_INDEX,FIELD) + TERM - 1_I8          ! Set global_dof to layout.first(node_index,field) + term - 1.
      IF (ALLOCATED(LAYOUT%ALIAS)) GLOBAL_DOF = LAYOUT%ALIAS(GLOBAL_DOF) ! If allocated(layout.alias), set global_dof to layout.alias(global_dof).

      END FUNCTION GLOBAL_DOF                                            ! End of the function global dof.

      SUBROUTINE CLEAR_LAYOUT(LAYOUT)                                    ! Subroutine clear layout takes layout.

      TYPE(DOF_LAYOUT_TYPE), INTENT(INOUT) :: LAYOUT                     ! In/out of type dof_layout_type: layout.

      IF (ALLOCATED(LAYOUT%TERM_COUNT)) DEALLOCATE(LAYOUT%TERM_COUNT)    ! If allocated(layout.term_count), free the memory of layout.term_count.
      IF (ALLOCATED(LAYOUT%FIRST)) DEALLOCATE(LAYOUT%FIRST)              ! If allocated(layout.first), free the memory of layout.first.
      LAYOUT%FIELD_FIRST = 0_I8                                          ! Set layout.field_first to zero.
      LAYOUT%FIELD_LAST = 0_I8                                           ! Set layout.field_last to zero.
      IF (ALLOCATED(LAYOUT%ALIAS)) DEALLOCATE(LAYOUT%ALIAS)              ! If allocated(layout.alias), free the memory of layout.alias.
      LAYOUT%TOTAL_DOF = 0_I8                                            ! Set layout.total_dof to zero.

      END SUBROUTINE CLEAR_LAYOUT                                        ! End of the subroutine clear layout.

      END MODULE MUL2_DOF_LAYOUT                                         ! End of the module mul2 dof layout.
