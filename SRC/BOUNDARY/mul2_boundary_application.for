!=======================================================================
!  GEOMETRIC MECHANICAL BC RESOLUTION AND EXACT STATIC ELIMINATION.
!=======================================================================
      MODULE MUL2_BOUNDARY_APPLICATION                                   ! Module mul2 boundary application begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error, status is ok.
     &                       SET_WARNING, SET_ERROR,
     &                       STATUS_IS_OK
      USE MUL2_BOUNDARY_CONDITIONS, ONLY: BOUNDARY_DB_TYPE,              ! Use from module mul2 boundary conditions: boundary db type, bc displacement plane, bc force point, bc value...
     &     BC_DISPLACEMENT_PLANE, BC_FORCE_POINT, BC_VALUE_POINT,
     &     BC_TIE_PLANE, BC_SURFACE
      USE MUL2_NODES, ONLY: NODE_DB_TYPE                                 ! Use from module mul2 nodes: node db type.
      USE MUL2_INCIDENCE, ONLY: NODE_INCIDENCE_TYPE,                     ! Use from module mul2 incidence: node incidence type, build node incidence.
     &                          BUILD_NODE_INCIDENCE
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE,                     ! Use from module mul2 kinematics: kinematics db type, expansion none, expansion te, expansion le, expansion ...
     &     EXPANSION_NONE, EXPANSION_TE, EXPANSION_LE,
     &     EXPANSION_HLE, EXPANSION_MISC, FIND_KINEMATIC_INDEX,
     &     N_SOLVED_FIELDS
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE,                ! Use from module mul2 expansion meshes: expansion db type, find expansion index.
     &                                 FIND_EXPANSION_INDEX
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_GENERAL_GEOMETRY, ONLY: IS_GENERAL_ELEMENT,               ! Use from module mul2 general geometry: is general element, general offset.
     &                                 GENERAL_OFFSET
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE, GLOBAL_DOF             ! Use from module mul2 dof layout: dof layout type, global dof.
      USE MUL2_CUF_BASES, ONLY: EVALUATE_TAYLOR_TERM                     ! Use from module mul2 cuf bases: evaluate taylor term.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_MESH_TYPE               ! Use from module mul2 expansion meshes: expansion mesh type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NODE_COUNT,                    ! Use from module mul2 topologies: topology node count, topology natural dimension.
     &                           TOPOLOGY_NATURAL_DIMENSION
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_FIELDS, ONLY: FIELD_DB_TYPE, EVALUATE_FIELD               ! Use from module mul2 fields: field db type, evaluate field.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: CONSTRAINT_SET_TYPE                                ! Definition of the derived type constraint set type.
        INTEGER(I8) :: COUNT = 0_I8                                      ! Integer (int64): count = 0.
        LOGICAL, ALLOCATABLE :: ACTIVE(:)                                ! Allocatable logical: active(:).
        REAL(R8), ALLOCATABLE :: VALUE(:)                                ! Allocatable real (real64): value(:).
!       TIES (FLOATING ELECTRODES): MASTER(I) = I, OR THE DOF THAT
!       HOLDS THE VALUE OF THE DOF I (A SLAVE, ALSO MARKED ACTIVE).
        LOGICAL :: HAS_TIES = .FALSE.                                    ! Logical: has_ties = false.
        INTEGER(I8), ALLOCATABLE :: MASTER(:)                            ! Allocatable integer (int64): master(:).
      END TYPE CONSTRAINT_SET_TYPE                                       ! End of the type definition constraint set type.

      PUBLIC :: BUILD_MECHANICAL_BOUNDARY_DATA                           ! Export: build mechanical boundary data.
      PUBLIC :: APPLY_STATIC_CONSTRAINTS                                 ! Export: apply static constraints.
      PUBLIC :: APPLY_DOF_TIES                                           ! Export: apply dof ties.
      PUBLIC :: EXPAND_TIES                                              ! Export: expand ties.
      PUBLIC :: PLACED_POINT                                             ! Export: placed point.

      CONTAINS                                                           ! The procedures of the module follow.

!  CONSTRAINTS AND LOADS OF BC.DAT; FIELDS (FIELDS.DAT) ARE OPTIONAL.
      SUBROUTINE BUILD_MECHANICAL_BOUNDARY_DATA(BOUNDARIES,              ! Subroutine build mechanical boundary data takes boundaries, nodes, elements, kinematics, expansions, frames...
     &     NODES, ELEMENTS, KINEMATICS, EXPANSIONS, FRAMES,
     &     DOF_LAYOUT, TOLERANCE, CONSTRAINTS, FORCE, STATUS,
     &     FIELDS)

      TYPE(BOUNDARY_DB_TYPE), INTENT(IN) :: BOUNDARIES                   ! Input of type boundary_db_type: boundaries.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      TYPE(CONSTRAINT_SET_TYPE), INTENT(INOUT) :: CONSTRAINTS            ! In/out of type constraint_set_type: constraints.
      REAL(R8), ALLOCATABLE, INTENT(INOUT) :: FORCE(:)                   ! Allocatable in/out real (real64): force(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(FIELD_DB_TYPE), INTENT(IN), OPTIONAL :: FIELDS                ! Input optional of type field_db_type: fields.
      TYPE(FIELD_DB_TYPE) :: NO_FIELDS                                   ! Of type field_db_type: no_fields.

      IF (PRESENT(FIELDS)) THEN                                          ! If present(fields):
        CALL BUILD_BOUNDARY_WITH_FIELDS(BOUNDARIES, NODES, ELEMENTS,     ! Call build boundary with fields with boundaries, nodes, elements, kinematics, expansions, frames, dof_layou...
     &       KINEMATICS, EXPANSIONS, FRAMES, DOF_LAYOUT, TOLERANCE,
     &       CONSTRAINTS, FORCE, STATUS, FIELDS)
      ELSE                                                               ! Otherwise:
        CALL BUILD_BOUNDARY_WITH_FIELDS(BOUNDARIES, NODES, ELEMENTS,     ! Call build boundary with fields with boundaries, nodes, elements, kinematics, expansions, frames, dof_layou...
     &       KINEMATICS, EXPANSIONS, FRAMES, DOF_LAYOUT, TOLERANCE,
     &       CONSTRAINTS, FORCE, STATUS, NO_FIELDS)
      END IF                                                             ! End of the IF block.

      END SUBROUTINE BUILD_MECHANICAL_BOUNDARY_DATA                      ! End of the subroutine build mechanical boundary data.

      SUBROUTINE BUILD_BOUNDARY_WITH_FIELDS(BOUNDARIES,                  ! Subroutine build boundary with fields takes boundaries, nodes, elements, kinematics, expansions, frames, do...
     &     NODES, ELEMENTS, KINEMATICS, EXPANSIONS, FRAMES,
     &     DOF_LAYOUT, TOLERANCE, CONSTRAINTS, FORCE, STATUS,
     &     FIELDS)

      TYPE(BOUNDARY_DB_TYPE), INTENT(IN) :: BOUNDARIES                   ! Input of type boundary_db_type: boundaries.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      TYPE(CONSTRAINT_SET_TYPE), INTENT(INOUT) :: CONSTRAINTS            ! In/out of type constraint_set_type: constraints.
      REAL(R8), ALLOCATABLE, INTENT(INOUT) :: FORCE(:)                   ! Allocatable in/out real (real64): force(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(FIELD_DB_TYPE), INTENT(IN) :: FIELDS                          ! Input of type field_db_type: fields.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(NODE_INCIDENCE_TYPE) :: INCIDENCE                             ! Of type node_incidence_type: incidence.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_BOUNDARY_DATA(CONSTRAINTS,FORCE)                        ! Call clear boundary data with constraints, force.
      CALL BUILD_NODE_INCIDENCE(NODES, ELEMENTS, INCIDENCE, STATUS)      ! Call build node incidence with nodes, elements, incidence, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (DOF_LAYOUT%TOTAL_DOF .LT. 1_I8 .OR.                            ! If dof_layout.total_dof < 1 or tolerance <= 0.0 or not allocated(boundaries.item):
     &    TOLERANCE .LE. 0.0_R8 .OR.
     &    .NOT. ALLOCATED(BOUNDARIES%ITEM)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_MECHANICAL_BOUNDARY_DATA',         ! Record an error in status: 'INVALID OR UNALLOCATED BOUNDARY INPUT'.
     &                 'INVALID OR UNALLOCATED BOUNDARY INPUT')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(CONSTRAINTS%ACTIVE(DOF_LAYOUT%TOTAL_DOF))                 ! Allocate memory for constraints.active(dof_layout.total_dof).
      ALLOCATE(CONSTRAINTS%VALUE(DOF_LAYOUT%TOTAL_DOF))                  ! Allocate memory for constraints.value(dof_layout.total_dof).
      ALLOCATE(FORCE(DOF_LAYOUT%TOTAL_DOF))                              ! Allocate memory for force(dof_layout.total_dof).
      CONSTRAINTS%ACTIVE = .FALSE.                                       ! Set the flag constraints.active to false.
      CONSTRAINTS%VALUE = 0.0_R8                                         ! Set constraints.value to zero.
      FORCE = 0.0_R8                                                     ! Set force to zero.

      DO I = 1_I4, SIZE(BOUNDARIES%ITEM)                                 ! Loop i from 1 to size(boundaries.item):
        SELECT CASE(BOUNDARIES%ITEM(I)%KIND)                             ! Choose according to the value of boundaries.item(i).kind:
        CASE(BC_DISPLACEMENT_PLANE)                                      ! Case bc_displacement_plane:
          CALL ADD_PLANE_CONSTRAINT(BOUNDARIES%ITEM(I)%PLANE,            ! Call add plane constraint with boundaries.item(i).plane, boundaries.item(i).active, boundaries.item(i).valu...
     &         BOUNDARIES%ITEM(I)%ACTIVE,
     &         BOUNDARIES%ITEM(I)%VALUE, NODES, ELEMENTS, INCIDENCE,
     &         KINEMATICS, EXPANSIONS, FRAMES, DOF_LAYOUT,
     &         TOLERANCE, CONSTRAINTS, LOCAL_STATUS,
     &         BOUNDARIES%ITEM(I)%FIELD_ID, FIELDS)
        CASE(BC_TIE_PLANE)                                               ! Case bc_tie_plane:
          CALL ADD_PLANE_TIE(BOUNDARIES%ITEM(I)%PLANE, NODES, ELEMENTS,  ! Call add plane tie with boundaries.item(i).plane, nodes, elements, incidence, kinematics, expansions, frame...
     &         INCIDENCE, KINEMATICS, EXPANSIONS, FRAMES, DOF_LAYOUT,
     &         TOLERANCE, CONSTRAINTS, LOCAL_STATUS)
        CASE(BC_VALUE_POINT)                                             ! Case bc_value_point:
          CALL ADD_POINT_VALUE(BOUNDARIES%ITEM(I)%POINT,                 ! Call add point value with boundaries.item(i).point, boundaries.item(i).active, boundaries.item(i).value, no...
     &         BOUNDARIES%ITEM(I)%ACTIVE,
     &         BOUNDARIES%ITEM(I)%VALUE, NODES, ELEMENTS, INCIDENCE,
     &         KINEMATICS, EXPANSIONS, FRAMES, DOF_LAYOUT,
     &         TOLERANCE, CONSTRAINTS, LOCAL_STATUS,
     &         BOUNDARIES%ITEM(I)%FIELD_ID, FIELDS)
        CASE(BC_FORCE_POINT)                                             ! Case bc_force_point:
          CALL ADD_POINT_FORCE(BOUNDARIES%ITEM(I)%POINT,                 ! Call add point force with boundaries.item(i).point, boundaries.item(i).value, nodes, elements, incidence, k...
     &         BOUNDARIES%ITEM(I)%VALUE, NODES, ELEMENTS, INCIDENCE,
     &         KINEMATICS, EXPANSIONS, FRAMES, DOF_LAYOUT,
     &         TOLERANCE, FORCE, LOCAL_STATUS)
        CASE(BC_SURFACE)                                                 ! Case bc_surface:
!         SURFACE LOADS ARE APPLIED BY MUL2_SURFACE_LOADS.
          CYCLE                                                          ! Skip to the next iteration.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'BUILD_MECHANICAL_BOUNDARY_DATA',       ! Record an error in status: 'UNKNOWN BOUNDARY-CONDITION KIND'.
     &                   'UNKNOWN BOUNDARY-CONDITION KIND')
          RETURN                                                         ! Return to the caller.
        END SELECT                                                       ! End of the case selection.
        IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                       ! If not local_status is ok:
          CALL SET_ERROR(STATUS, 'BUILD_MECHANICAL_BOUNDARY_DATA',       ! Record an error in status: trim(local_status.message).
     &                   TRIM(LOCAL_STATUS%MESSAGE))
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (LOCAL_STATUS%CODE .EQ. 1_I4) THEN                            ! If local_status.code = 1:
          CALL SET_WARNING(STATUS,                                       ! Record a warning in status: trim(local_status.message).
     &      'BUILD_MECHANICAL_BOUNDARY_DATA',
     &      TRIM(LOCAL_STATUS%MESSAGE))
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CONSTRAINTS%COUNT = COUNT(CONSTRAINTS%ACTIVE,KIND=I8)              ! Set constraints.count to count(constraints.active,kind=i8).

      END SUBROUTINE BUILD_BOUNDARY_WITH_FIELDS                          ! End of the subroutine build boundary with fields.

!  FLOATING ELECTRODE: THE ELECTRIC-POTENTIAL DOFS OF THE LAGRANGE
!  (OR HIERARCHICAL VERTEX) SECTION NODES ON THE PLANE ARE TIED TO THE
!  FIRST ONE; THE OTHERS BECOME INACTIVE SLAVES (VALUE 0).
      SUBROUTINE ADD_PLANE_TIE(PLANE, NODES, ELEMENTS, INCIDENCE,        ! Subroutine add plane tie takes plane, nodes, elements, incidence, kinematics, expansions, frames, dof layou...
     &     KINEMATICS, EXPANSIONS, FRAMES, DOF_LAYOUT, TOLERANCE,
     &     CONSTRAINTS, STATUS)

      REAL(R8), INTENT(IN) :: PLANE(4)                                   ! Input real (real64): plane(4).
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(NODE_INCIDENCE_TYPE), INTENT(IN) :: INCIDENCE                 ! Input of type node_incidence_type: incidence.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      TYPE(CONSTRAINT_SET_TYPE), INTENT(INOUT) :: CONSTRAINTS            ! In/out of type constraint_set_type: constraints.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: PHYSICAL_POINT(3)                                      ! Real (real64): physical_point(3).
      INTEGER(I8) :: DOF                                                 ! Integer (int64): dof.
      INTEGER(I8) :: MASTER_DOF                                          ! Integer (int64): master_dof.
      INTEGER(I4) :: ELEMENT_INDEX                                       ! Integer (int32): element_index.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: EXPANSION_NODE                                      ! Integer (int32): expansion_node.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      FIELD = 5_I4                                                       ! Set field to 5.
      MASTER_DOF = 0_I8                                                  ! Set master_dof to zero.
      IF (.NOT. ALLOCATED(CONSTRAINTS%MASTER)) THEN                      ! If not allocated(constraints.master):
        ALLOCATE(CONSTRAINTS%MASTER(SIZE(CONSTRAINTS%ACTIVE)))           ! Allocate memory for constraints.master(size(constraints.active)).
        CONSTRAINTS%MASTER = [(DOF, DOF = 1_I8,                          ! Set constraints.master to [(dof, dof = 1, size(constraints.active,kind=i8))].
     &                          SIZE(CONSTRAINTS%ACTIVE,KIND=I8))]
      END IF                                                             ! End of the IF block.
      DO NODE_INDEX = 1_I4, SIZE(NODES%ITEM)                             ! Loop node_index from 1 to size(nodes.item):
        ELEMENT_INDEX = FIRST_ELEMENT(INCIDENCE,NODE_INDEX)              ! Set element_index to first_element(incidence,node_index).
        IF (ELEMENT_INDEX .EQ. 0_I4) CYCLE                               ! If element_index = 0, skip to the next iteration.
        MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,                    ! Set mesh_index to find_expansion_index(expansions, elements.item(element_index).expansion_id).
     &    ELEMENTS%ITEM(ELEMENT_INDEX)%EXPANSION_ID)
        IF (MESH_INDEX .EQ. 0_I4) CYCLE                                  ! If mesh_index = 0, skip to the next iteration.
        KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(KINEMATICS,               ! Set kinematic_index to find_kinematic_index(kinematics, nodes.item(node_index).kinematic_id).
     &    NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
        IF (KINEMATICS%ITEM(KINEMATIC_INDEX)%FIELD(FIELD)%FAMILY         ! If kinematics.item(kinematic_index).field(field).family = expansion_none, skip to the next iteration.
     &      .EQ. EXPANSION_NONE) CYCLE
        DO EXPANSION_NODE = 1_I4,                                        ! Loop expansion_node from 1 to size(expansions.item(mesh_index).node):
     &    SIZE(EXPANSIONS%ITEM(MESH_INDEX)%NODE)
          CALL PLACED_POINT(NODES, ELEMENTS, FRAMES, ELEMENT_INDEX,      ! Call placed point with nodes, elements, frames, element_index, node_index, expansions.item(mesh_index).node...
     &      NODE_INDEX, EXPANSIONS%ITEM(MESH_INDEX)%NODE(
     &      EXPANSION_NODE)%COORDINATE, PHYSICAL_POINT, .TRUE.)
          IF (.NOT. POINT_ON_PLANE(PHYSICAL_POINT,PLANE,TOLERANCE))      ! If not point_on_plane(physical_point,plane,tolerance), skip to the next iteration.
     &      CYCLE
          IF (EXPANSIONS%ITEM(MESH_INDEX)%IS_HLE) THEN                   ! If expansions.item(mesh_index).is_hle:
            TERM = EXPANSIONS%ITEM(MESH_INDEX)%NODE_TERM(EXPANSION_NODE) ! Set term to expansions.item(mesh_index).node_term(expansion_node).
            IF (TERM .EQ. 0_I4) CYCLE                                    ! If term = 0, skip to the next iteration.
          ELSE IF (KINEMATICS%ITEM(KINEMATIC_INDEX)%FIELD(FIELD)%        ! Otherwise, if kinematics.item(kinematic_index).field(field). family = expansion_le:
     &             FAMILY .EQ. EXPANSION_LE) THEN
            TERM = EXPANSION_NODE                                        ! Set term to expansion_node.
          ELSE                                                           ! Otherwise:
            CALL SET_ERROR(STATUS, 'ADD_PLANE_TIE',                      ! Record an error in status: 'A FLOATING ELECTRODE NEEDS A LAGRANGE OR HLE POTENTIAL'.
     &        'A FLOATING ELECTRODE NEEDS A LAGRANGE OR HLE POTENTIAL')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          DOF = GLOBAL_DOF(DOF_LAYOUT,NODE_INDEX,FIELD,TERM)             ! Set dof to global_dof(dof_layout,node_index,field,term).
          IF (CONSTRAINTS%ACTIVE(DOF)) CYCLE                             ! If constraints.active(dof), skip to the next iteration.
          IF (MASTER_DOF .EQ. 0_I8) THEN                                 ! If master_dof = 0:
            MASTER_DOF = DOF                                             ! Set master_dof to dof.
          ELSE                                                           ! Otherwise:
            CONSTRAINTS%MASTER(DOF) = MASTER_DOF                         ! Set constraints.master(dof) to master_dof.
            CONSTRAINTS%ACTIVE(DOF) = .TRUE.                             ! Set the flag constraints.active(dof) to true.
            CONSTRAINTS%VALUE(DOF) = 0.0_R8                              ! Set constraints.value(dof) to zero.
            CONSTRAINTS%HAS_TIES = .TRUE.                                ! Set the flag constraints.has_ties to true.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (MASTER_DOF .EQ. 0_I8) THEN                                     ! If master_dof = 0:
        CALL SET_WARNING(STATUS, 'ADD_PLANE_TIE',                        ! Record a warning in status: 'FLOATING ELECTRODE SELECTED NO DOF'.
     &                   'FLOATING ELECTRODE SELECTED NO DOF')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE ADD_PLANE_TIE                                       ! End of the subroutine add plane tie.

!  K = T^T K T AND F = T^T F FOR THE TIES: THE ROWS AND COLUMNS OF THE
!  SLAVES ARE ADDED TO THOSE OF THEIR MASTER; A SLAVE KEEPS A UNIT
!  DIAGONAL (IT IS CONSTRAINED TO ZERO AND COPIED FROM THE MASTER AFTER
!  THE SOLUTION). K AND, WHEN ALLOCATED, M SHARE THE PATTERN.
      SUBROUTINE APPLY_DOF_TIES(SYSTEM, FORCE, CONSTRAINTS, STATUS)      ! Subroutine apply dof ties takes system, force, constraints, status.

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      REAL(R8), INTENT(INOUT), OPTIONAL :: FORCE(:)                      ! In/out optional real (real64): force(:).
      TYPE(CONSTRAINT_SET_TYPE), INTENT(IN) :: CONSTRAINTS               ! Input of type constraint_set_type: constraints.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8), ALLOCATABLE :: NEW_POINTER(:)                         ! Allocatable integer (int64): new_pointer(:).
      INTEGER(I8), ALLOCATABLE :: NEW_COLUMN(:)                          ! Allocatable integer (int64): new_column(:).
      INTEGER(I8), ALLOCATABLE :: HEAD(:)                                ! Allocatable integer (int64): head(:).
      INTEGER(I8), ALLOCATABLE :: NEXT(:)                                ! Allocatable integer (int64): next(:).
      INTEGER(I8), ALLOCATABLE :: COLUMN_BUFFER(:)                       ! Allocatable integer (int64): column_buffer(:).
      REAL(R8), ALLOCATABLE :: NEW_STIFFNESS(:)                          ! Allocatable real (real64): new_stiffness(:).
      REAL(R8), ALLOCATABLE :: NEW_MASS(:)                               ! Allocatable real (real64): new_mass(:).
      REAL(R8), ALLOCATABLE :: K_BUFFER(:)                               ! Allocatable real (real64): k_buffer(:).
      REAL(R8), ALLOCATABLE :: M_BUFFER(:)                               ! Allocatable real (real64): m_buffer(:).
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: SOURCE                                              ! Integer (int64): source.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I8) :: COUNT                                               ! Integer (int64): count.
      INTEGER(I8) :: OUT                                                 ! Integer (int64): out.
      INTEGER(I8) :: I                                                   ! Integer (int64): i.
      INTEGER(I8) :: J                                                   ! Integer (int64): j.
      INTEGER(I8) :: COLUMN                                              ! Integer (int64): column.
      LOGICAL :: WITH_MASS                                               ! Logical: with_mass.
      LOGICAL :: TOUCHED                                                 ! Logical: touched.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (.NOT. CONSTRAINTS%HAS_TIES) RETURN                             ! If not constraints.has_ties, return to the caller.
      WITH_MASS = ALLOCATED(SYSTEM%MASS)                                 ! Set with_mass to allocated(system.mass).
      ALLOCATE(HEAD(SYSTEM%ORDER), NEXT(SYSTEM%ORDER))                   ! Allocate memory for head(system.order), next(system.order).
      HEAD = 0_I8                                                        ! Set head to zero.
      NEXT = 0_I8                                                        ! Set next to zero.
      DO ROW = 1_I8, SYSTEM%ORDER                                        ! Loop row from 1 to system.order:
        IF (CONSTRAINTS%MASTER(ROW) .NE. ROW) THEN                       ! If constraints.master(row) /= row:
          NEXT(ROW) = HEAD(CONSTRAINTS%MASTER(ROW))                      ! Set next(row) to head(constraints.master(row)).
          HEAD(CONSTRAINTS%MASTER(ROW)) = ROW                            ! Set head(constraints.master(row)) to row.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      ALLOCATE(NEW_POINTER(SYSTEM%ORDER+1_I8))                           ! Allocate memory for new_pointer(system.order+1).
      ALLOCATE(NEW_COLUMN(SYSTEM%NONZERO_COUNT+SYSTEM%ORDER))            ! Allocate memory for new_column(system.nonzero_count+system.order).
      ALLOCATE(NEW_STIFFNESS(SYSTEM%NONZERO_COUNT+SYSTEM%ORDER))         ! Allocate memory for new_stiffness(system.nonzero_count+system.order).
      IF (WITH_MASS) ALLOCATE(NEW_MASS(SYSTEM%NONZERO_COUNT+             ! If with_mass, allocate memory for new_mass(system.nonzero_count+ system.order).
     &                                 SYSTEM%ORDER))
      ALLOCATE(COLUMN_BUFFER(SYSTEM%NONZERO_COUNT))                      ! Allocate memory for column_buffer(system.nonzero_count).
      ALLOCATE(K_BUFFER(SYSTEM%NONZERO_COUNT))                           ! Allocate memory for k_buffer(system.nonzero_count).
      ALLOCATE(M_BUFFER(MERGE(SYSTEM%NONZERO_COUNT,1_I8,WITH_MASS)))     ! Allocate memory for m_buffer(merge(system.nonzero_count,1,with_mass)).
      OUT = 0_I8                                                         ! Set out to zero.
      NEW_POINTER(1) = 1_I8                                              ! Set new_pointer(1) to 1.
      DO ROW = 1_I8, SYSTEM%ORDER                                        ! Loop row from 1 to system.order:
        IF (CONSTRAINTS%MASTER(ROW) .NE. ROW) THEN                       ! If constraints.master(row) /= row:
!         SLAVE: UNIT DIAGONAL ONLY.
          OUT = OUT + 1_I8                                               ! Add 1 to out.
          NEW_COLUMN(OUT) = ROW                                          ! Set new_column(out) to row.
          NEW_STIFFNESS(OUT) = 1.0_R8                                    ! Set new_stiffness(out) to 1.0.
          IF (WITH_MASS) NEW_MASS(OUT) = 0.0_R8                          ! If with_mass, set new_mass(out) to zero.
          NEW_POINTER(ROW+1_I8) = OUT + 1_I8                             ! Set new_pointer(row+1) to out + 1.
          CYCLE                                                          ! Skip to the next iteration.
        END IF                                                           ! End of the IF block.
!       GATHER THE ENTRIES OF THE ROW AND OF ITS SLAVES.
        COUNT = 0_I8                                                     ! Set count to zero.
        TOUCHED = HEAD(ROW) .NE. 0_I8                                    ! Set touched to head(row) /= 0.
        SOURCE = ROW                                                     ! Set source to row.
        DO                                                               ! Loop until an EXIT statement is reached:
          DO POSITION = SYSTEM%ROW_POINTER(SOURCE),                      ! Loop position from system.row_pointer(source) to system.row_pointer(source+1)-1:
     &                  SYSTEM%ROW_POINTER(SOURCE+1_I8)-1_I8
            COLUMN = SYSTEM%COLUMN_INDEX(POSITION)                       ! Set column to system.column_index(position).
            IF (CONSTRAINTS%MASTER(COLUMN) .NE. COLUMN) THEN             ! If constraints.master(column) /= column:
              COLUMN = CONSTRAINTS%MASTER(COLUMN)                        ! Set column to constraints.master(column).
              TOUCHED = .TRUE.                                           ! Set the flag touched to true.
            END IF                                                       ! End of the IF block.
            COUNT = COUNT + 1_I8                                         ! Add 1 to count.
            COLUMN_BUFFER(COUNT) = COLUMN                                ! Set column_buffer(count) to column.
            K_BUFFER(COUNT) = SYSTEM%STIFFNESS(POSITION)                 ! Set k_buffer(count) to system.stiffness(position).
            IF (WITH_MASS) M_BUFFER(COUNT) = SYSTEM%MASS(POSITION)       ! If with_mass, set m_buffer(count) to system.mass(position).
          END DO                                                         ! End of the loop.
          IF (SOURCE .EQ. ROW) THEN                                      ! If source = row:
            SOURCE = HEAD(ROW)                                           ! Set source to head(row).
          ELSE                                                           ! Otherwise:
            SOURCE = NEXT(SOURCE)                                        ! Set source to next(source).
          END IF                                                         ! End of the IF block.
          IF (SOURCE .EQ. 0_I8) EXIT                                     ! If source = 0, leave the loop.
        END DO                                                           ! End of the loop.
        IF (TOUCHED) THEN                                                ! If touched:
!         SORT BY COLUMN (INSERTION) AND MERGE EQUAL COLUMNS.
          DO I = 2_I8, COUNT                                             ! Loop i from 2 to count:
            COLUMN = COLUMN_BUFFER(I)                                    ! Set column to column_buffer(i).
            SOURCE = I                                                   ! Set source to i.
            DO J = I-1_I8, 1_I8, -1_I8                                   ! Loop j from i-1 to 1 in steps of -1:
              IF (COLUMN_BUFFER(J) .LE. COLUMN) EXIT                     ! If column_buffer(j) <= column, leave the loop.
              SOURCE = J                                                 ! Set source to j.
            END DO                                                       ! End of the loop.
            IF (SOURCE .NE. I) THEN                                      ! If source /= i:
              CALL SHIFT_ENTRY(COLUMN_BUFFER, K_BUFFER, M_BUFFER,        ! Call shift entry with column_buffer, k_buffer, m_buffer, with_mass, source, i.
     &                         WITH_MASS, SOURCE, I)
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
        END IF                                                           ! End of the IF block.
        I = 1_I8                                                         ! Set i to 1.
        DO WHILE (I .LE. COUNT)                                          ! Repeat while i <= count:
          OUT = OUT + 1_I8                                               ! Add 1 to out.
          NEW_COLUMN(OUT) = COLUMN_BUFFER(I)                             ! Set new_column(out) to column_buffer(i).
          NEW_STIFFNESS(OUT) = K_BUFFER(I)                               ! Set new_stiffness(out) to k_buffer(i).
          IF (WITH_MASS) NEW_MASS(OUT) = M_BUFFER(I)                     ! If with_mass, set new_mass(out) to m_buffer(i).
          J = I + 1_I8                                                   ! Set j to i + 1.
          DO WHILE (J .LE. COUNT)                                        ! Repeat while j <= count:
            IF (COLUMN_BUFFER(J) .NE. COLUMN_BUFFER(I)) EXIT             ! If column_buffer(j) /= column_buffer(i), leave the loop.
            NEW_STIFFNESS(OUT) = NEW_STIFFNESS(OUT) + K_BUFFER(J)        ! Add k_buffer(j) to new_stiffness(out).
            IF (WITH_MASS) NEW_MASS(OUT) = NEW_MASS(OUT) + M_BUFFER(J)   ! If with_mass, add m_buffer(j) to new_mass(out).
            J = J + 1_I8                                                 ! Add 1 to j.
          END DO                                                         ! End of the loop.
          I = J                                                          ! Set i to j.
        END DO                                                           ! End of the loop.
        NEW_POINTER(ROW+1_I8) = OUT + 1_I8                               ! Set new_pointer(row+1) to out + 1.
      END DO                                                             ! End of the loop.
      IF (PRESENT(FORCE)) THEN                                           ! If present(force):
        DO ROW = 1_I8, SYSTEM%ORDER                                      ! Loop row from 1 to system.order:
          IF (CONSTRAINTS%MASTER(ROW) .NE. ROW) THEN                     ! If constraints.master(row) /= row:
            FORCE(CONSTRAINTS%MASTER(ROW)) =                             ! Add force(row) to force(constraints.master(row)).
     &        FORCE(CONSTRAINTS%MASTER(ROW)) + FORCE(ROW)
            FORCE(ROW) = 0.0_R8                                          ! Set force(row) to zero.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.
      CALL MOVE_ALLOC(NEW_POINTER, SYSTEM%ROW_POINTER)                   ! Move the allocation of new_pointer into system.row_pointer.
      DEALLOCATE(SYSTEM%COLUMN_INDEX, SYSTEM%STIFFNESS)                  ! Free the memory of system.column_index, system.stiffness.
      ALLOCATE(SYSTEM%COLUMN_INDEX(OUT), SYSTEM%STIFFNESS(OUT))          ! Allocate memory for system.column_index(out), system.stiffness(out).
      SYSTEM%COLUMN_INDEX = NEW_COLUMN(1:OUT)                            ! Set system.column_index to new_column(1:out).
      SYSTEM%STIFFNESS = NEW_STIFFNESS(1:OUT)                            ! Set system.stiffness to new_stiffness(1:out).
      IF (WITH_MASS) THEN                                                ! If with_mass:
        DEALLOCATE(SYSTEM%MASS)                                          ! Free the memory of system.mass.
        ALLOCATE(SYSTEM%MASS(OUT))                                       ! Allocate memory for system.mass(out).
        SYSTEM%MASS = NEW_MASS(1:OUT)                                    ! Set system.mass to new_mass(1:out).
      END IF                                                             ! End of the IF block.
      SYSTEM%NONZERO_COUNT = OUT                                         ! Set system.nonzero_count to out.

      END SUBROUTINE APPLY_DOF_TIES                                      ! End of the subroutine apply dof ties.

!  MOVE ENTRY I TO POSITION TARGET (<= I), SHIFTING THE OTHERS UP.
      SUBROUTINE SHIFT_ENTRY(COLUMN, K, M, WITH_MASS, TARGET, I)         ! Subroutine shift entry takes column, k, m, with mass, target, i.

      INTEGER(I8), INTENT(INOUT) :: COLUMN(:)                            ! In/out integer (int64): column(:).
      REAL(R8), INTENT(INOUT) :: K(:)                                    ! In/out real (real64): k(:).
      REAL(R8), INTENT(INOUT) :: M(:)                                    ! In/out real (real64): m(:).
      LOGICAL, INTENT(IN) :: WITH_MASS                                   ! Input logical: with_mass.
      INTEGER(I8), INTENT(IN) :: TARGET                                  ! Input integer (int64): target.
      INTEGER(I8), INTENT(IN) :: I                                       ! Input integer (int64): i.
      INTEGER(I8) :: SAVE_COLUMN                                         ! Integer (int64): save_column.
      REAL(R8) :: SAVE_K                                                 ! Real (real64): save_k.
      REAL(R8) :: SAVE_M                                                 ! Real (real64): save_m.
      INTEGER(I8) :: J                                                   ! Integer (int64): j.

      SAVE_COLUMN = COLUMN(I)                                            ! Set save_column to column(i).
      SAVE_K = K(I)                                                      ! Set save_k to k(i).
      SAVE_M = 0.0_R8                                                    ! Set save_m to zero.
      IF (WITH_MASS) SAVE_M = M(I)                                       ! If with_mass, set save_m to m(i).
      DO J = I, TARGET+1_I8, -1_I8                                       ! Loop j from i to target+1 in steps of -1:
        COLUMN(J) = COLUMN(J-1_I8)                                       ! Set column(j) to column(j-1).
        K(J) = K(J-1_I8)                                                 ! Set k(j) to k(j-1).
        IF (WITH_MASS) M(J) = M(J-1_I8)                                  ! If with_mass, set m(j) to m(j-1).
      END DO                                                             ! End of the loop.
      COLUMN(TARGET) = SAVE_COLUMN                                       ! Set column(target) to save_column.
      K(TARGET) = SAVE_K                                                 ! Set k(target) to save_k.
      IF (WITH_MASS) M(TARGET) = SAVE_M                                  ! If with_mass, set m(target) to save_m.

      END SUBROUTINE SHIFT_ENTRY                                         ! End of the subroutine shift entry.

!  COPY THE VALUE OF EVERY MASTER TO ITS SLAVES.
      SUBROUTINE EXPAND_TIES(CONSTRAINTS, VECTOR)                        ! Subroutine expand ties takes constraints, vector.

      TYPE(CONSTRAINT_SET_TYPE), INTENT(IN) :: CONSTRAINTS               ! Input of type constraint_set_type: constraints.
      REAL(R8), INTENT(INOUT) :: VECTOR(:)                               ! In/out real (real64): vector(:).
      INTEGER(I8) :: I                                                   ! Integer (int64): i.

      IF (.NOT. CONSTRAINTS%HAS_TIES) RETURN                             ! If not constraints.has_ties, return to the caller.
      DO I = 1_I8, SIZE(VECTOR,KIND=I8)                                  ! Loop i from 1 to size(vector,kind=i8):
        IF (CONSTRAINTS%MASTER(I) .NE. I)                                ! If constraints.master(i) /= i, set vector(i) to vector(constraints.master(i)).
     &    VECTOR(I) = VECTOR(CONSTRAINTS%MASTER(I))
      END DO                                                             ! End of the loop.

      END SUBROUTINE EXPAND_TIES                                         ! End of the subroutine expand ties.

      SUBROUTINE ADD_PLANE_CONSTRAINT(PLANE, COMPONENT_ACTIVE,           ! Subroutine add plane constraint takes plane, component active, component value, nodes, elements, incidence,...
     &     COMPONENT_VALUE, NODES, ELEMENTS, INCIDENCE, KINEMATICS,
     &     EXPANSIONS, FRAMES, DOF_LAYOUT, TOLERANCE,
     &     CONSTRAINTS, STATUS, FIELD_ID, FIELDS)

      REAL(R8), INTENT(IN) :: PLANE(4)                                   ! Input real (real64): plane(4).
      LOGICAL, INTENT(IN) :: COMPONENT_ACTIVE(9)                         ! Input logical: component_active(9).
      REAL(R8), INTENT(IN) :: COMPONENT_VALUE(9)                         ! Input real (real64): component_value(9).
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(NODE_INCIDENCE_TYPE), INTENT(IN) :: INCIDENCE                 ! Input of type node_incidence_type: incidence.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      TYPE(CONSTRAINT_SET_TYPE), INTENT(INOUT) :: CONSTRAINTS            ! In/out of type constraint_set_type: constraints.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4), INTENT(IN) :: FIELD_ID                                ! Input integer (int32): field_id.
      TYPE(FIELD_DB_TYPE), INTENT(IN) :: FIELDS                          ! Input of type field_db_type: fields.
      REAL(R8) :: PHYSICAL_POINT(3)                                      ! Real (real64): physical_point(3).
      REAL(R8), ALLOCATABLE :: TERM_POINT(:,:)                           ! Allocatable real (real64): term_point(:,:).
      LOGICAL, ALLOCATABLE :: ON_PLANE(:)                                ! Allocatable logical: on_plane(:).
      INTEGER(I4) :: ELEMENT_INDEX                                       ! Integer (int32): element_index.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: MATCH_COUNT                                         ! Integer (int32): match_count.
      INTEGER(I8) :: BEFORE_COUNT                                        ! Integer (int64): before_count.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      BEFORE_COUNT = COUNT(CONSTRAINTS%ACTIVE,KIND=I8)                   ! Set before_count to count(constraints.active,kind=i8).
      DO NODE_INDEX = 1_I4, SIZE(NODES%ITEM)                             ! Loop node_index from 1 to size(nodes.item):
        ELEMENT_INDEX = FIRST_ELEMENT(INCIDENCE,NODE_INDEX)              ! Set element_index to first_element(incidence,node_index).
        IF (ELEMENT_INDEX .EQ. 0_I4) CYCLE                               ! If element_index = 0, skip to the next iteration.
        MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,                    ! Set mesh_index to find_expansion_index(expansions, elements.item(element_index).expansion_id).
     &    ELEMENTS%ITEM(ELEMENT_INDEX)%EXPANSION_ID)
        IF (MESH_INDEX .EQ. 0_I4) THEN                                   ! If mesh_index = 0:
          CALL SET_ERROR(STATUS, 'ADD_PLANE_CONSTRAINT',                 ! Record an error in status: 'ELEMENT EXPANSION IS MISSING'.
     &                   'ELEMENT EXPANSION IS MISSING')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        ALLOCATE(ON_PLANE(SIZE(EXPANSIONS%ITEM(MESH_INDEX)%NODE)))       ! Allocate memory for on_plane(size(expansions.item(mesh_index).node)).
        ALLOCATE(TERM_POINT(3,SIZE(ON_PLANE)))                           ! Allocate memory for term_point(3,size(on_plane)).
        DO TERM = 1_I4, SIZE(ON_PLANE)                                   ! Loop term from 1 to size(on_plane):
          CALL PLACED_POINT(NODES, ELEMENTS, FRAMES, ELEMENT_INDEX,      ! Call placed point with nodes, elements, frames, element_index, node_index, expansions.item(mesh_index).node...
     &      NODE_INDEX, EXPANSIONS%ITEM(MESH_INDEX)%NODE(TERM)%
     &      COORDINATE, PHYSICAL_POINT, .TRUE.)
          TERM_POINT(:,TERM) = PHYSICAL_POINT                            ! Set term_point(:,term) to physical_point.
          ON_PLANE(TERM) = POINT_ON_PLANE(PHYSICAL_POINT,PLANE,          ! Set on_plane(term) to point_on_plane(physical_point,plane, tolerance).
     &                                    TOLERANCE)
        END DO                                                           ! End of the loop.
        MATCH_COUNT = COUNT(ON_PLANE)                                    ! Set match_count to the number of true entries of on_plane.
        IF (MATCH_COUNT .EQ. 0_I4) THEN                                  ! If match_count = 0:
          DEALLOCATE(ON_PLANE, TERM_POINT)                               ! Free the memory of on_plane, term_point.
          CYCLE                                                          ! Skip to the next iteration.
        END IF                                                           ! End of the IF block.
        KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(KINEMATICS,               ! Set kinematic_index to find_kinematic_index(kinematics, nodes.item(node_index).kinematic_id).
     &    NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
        DO FIELD = 1_I4, N_SOLVED_FIELDS                                 ! Loop field from 1 to n_solved_fields:
          IF (.NOT. COMPONENT_ACTIVE(FIELD)) CYCLE                       ! If not component_active(field), skip to the next iteration.
          SELECT CASE(KINEMATICS%ITEM(KINEMATIC_INDEX)%                  ! Choose according to the value of kinematics.item(kinematic_index). field(field).family:
     &                FIELD(FIELD)%FAMILY)
          CASE(EXPANSION_NONE)                                           ! Case expansion_none:
            CYCLE                                                        ! Skip to the next iteration.
          CASE(EXPANSION_LE)                                             ! Case expansion_le:
            DO TERM = 1_I4, SIZE(ON_PLANE)                               ! Loop term from 1 to size(on_plane):
              IF (.NOT. ON_PLANE(TERM)) CYCLE                            ! If not on_plane(term), skip to the next iteration.
              CALL SET_DOF_CONSTRAINT(GLOBAL_DOF(DOF_LAYOUT,             ! Call set dof constraint with global_dof(dof_layout, node_index,field,term), component_value(field)* evaluat...
     &          NODE_INDEX,FIELD,TERM),COMPONENT_VALUE(FIELD)*
     &          EVALUATE_FIELD(FIELDS,FIELD_ID,TERM_POINT(1,TERM),
     &          TERM_POINT(2,TERM),TERM_POINT(3,TERM)),
     &          TOLERANCE,CONSTRAINTS,STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
            END DO                                                       ! End of the loop.
          CASE(EXPANSION_TE)                                             ! Case expansion_te:
            IF (MATCH_COUNT .NE. SIZE(ON_PLANE)) THEN                    ! If match_count /= size(on_plane):
              CALL SET_ERROR(STATUS, 'ADD_PLANE_CONSTRAINT',             ! Record an error in status: 'PARTIAL PLANE CONSTRAINT REQUIRES MPC FOR TE'.
     &          'PARTIAL PLANE CONSTRAINT REQUIRES MPC FOR TE')
              RETURN                                                     ! Return to the caller.
            END IF                                                       ! End of the IF block.
            DO TERM = 1_I4,                                              ! Loop term from 1 to dof_layout.term_count(node_index,field):
     &        DOF_LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)
              CALL SET_DOF_CONSTRAINT(GLOBAL_DOF(DOF_LAYOUT,             ! Call set dof constraint with global_dof(dof_layout, node_index,field,term), merge( component_value(field)*e...
     &          NODE_INDEX,FIELD,TERM),MERGE(
     &          COMPONENT_VALUE(FIELD)*EVALUATE_FIELD(FIELDS,
     &          FIELD_ID,NODES%ITEM(NODE_INDEX)%COORDINATE(1),
     &          NODES%ITEM(NODE_INDEX)%COORDINATE(2),
     &          NODES%ITEM(NODE_INDEX)%COORDINATE(3)),
     &          0.0_R8,TERM .EQ. 1_I4),
     &          TOLERANCE,CONSTRAINTS,STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
            END DO                                                       ! End of the loop.
          CASE(EXPANSION_HLE)                                            ! Case expansion_hle:
!           VERTEX MODES ARE NODAL VALUES; SIDE AND INTERNAL MODES
!           VANISH AT THE NODES, SO THEY ARE FIXED TO ZERO WHEN THEIR
!           WHOLE SIDE / SUB-ELEMENT LIES ON THE PLANE.
            DO TERM = 1_I4,                                              ! Loop term from 1 to dof_layout.term_count(node_index,field):
     &        DOF_LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)
              IF (.NOT. HLE_TERM_ON_PLANE(                               ! If not hle_term_on_plane( expansions.item(mesh_index),term,on_plane), skip to the next iteration.
     &            EXPANSIONS%ITEM(MESH_INDEX),TERM,ON_PLANE)) CYCLE
              CALL SET_DOF_CONSTRAINT(GLOBAL_DOF(DOF_LAYOUT,             ! Call set dof constraint with global_dof(dof_layout, node_index,field,term), merge(component_value(field)* e...
     &          NODE_INDEX,FIELD,TERM),MERGE(COMPONENT_VALUE(FIELD)*
     &          EVALUATE_FIELD(FIELDS,FIELD_ID,
     &          NODES%ITEM(NODE_INDEX)%COORDINATE(1),
     &          NODES%ITEM(NODE_INDEX)%COORDINATE(2),
     &          NODES%ITEM(NODE_INDEX)%COORDINATE(3)),
     &          0.0_R8,EXPANSIONS%ITEM(MESH_INDEX)%
     &          TERM_NODE(2,TERM) .EQ. 0_I4 .AND.
     &          EXPANSIONS%ITEM(MESH_INDEX)%
     &          TERM_NODE(1,TERM) .GT. 0_I4),
     &          TOLERANCE,CONSTRAINTS,STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
            END DO                                                       ! End of the loop.
          CASE(EXPANSION_MISC)                                           ! Case expansion_misc:
            CALL SET_ERROR(STATUS, 'ADD_PLANE_CONSTRAINT',               ! Record an error in status: 'M PLANE CONSTRAINT IS NOT IMPLEMENTED'.
     &        'M PLANE CONSTRAINT IS NOT IMPLEMENTED')
            RETURN                                                       ! Return to the caller.
          END SELECT                                                     ! End of the case selection.
        END DO                                                           ! End of the loop.
        DEALLOCATE(ON_PLANE, TERM_POINT)                                 ! Free the memory of on_plane, term_point.
      END DO                                                             ! End of the loop.
      IF (COUNT(CONSTRAINTS%ACTIVE,KIND=I8) .EQ. BEFORE_COUNT) THEN      ! If count(constraints.active,kind=i8) = before_count:
        CALL SET_WARNING(STATUS, 'ADD_PLANE_CONSTRAINT',                 ! Record a warning in status: 'PLANE DID NOT SELECT ANY ACTIVE DOF'.
     &                   'PLANE DID NOT SELECT ANY ACTIVE DOF')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE ADD_PLANE_CONSTRAINT                                ! End of the subroutine add plane constraint.

!  A HLE TERM IS ON THE PLANE WHEN ITS VERTEX, BOTH ENDS OF ITS SIDE
!  OR ALL THE VERTICES OF ITS SUB-ELEMENT ARE.
      LOGICAL FUNCTION HLE_TERM_ON_PLANE(MESH, TERM, ON_PLANE)           ! Function hle term on plane takes mesh, term, on plane.

      TYPE(EXPANSION_MESH_TYPE), INTENT(IN) :: MESH                      ! Input of type expansion_mesh_type: mesh.
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.
      LOGICAL, INTENT(IN) :: ON_PLANE(:)                                 ! Input logical: on_plane(:).
      INTEGER(I4) :: OWNER                                               ! Integer (int32): owner.
      INTEGER(I4) :: N_VERTEX                                            ! Integer (int32): n_vertex.

      IF (MESH%TERM_NODE(2,TERM) .GT. 0_I4) THEN                         ! If mesh.term_node(2,term) > 0:
        HLE_TERM_ON_PLANE = ON_PLANE(MESH%TERM_NODE(1,TERM)) .AND.       ! Set hle_term_on_plane to on_plane(mesh.term_node(1,term)) and on_plane(mesh.term_node(2,term)).
     &                      ON_PLANE(MESH%TERM_NODE(2,TERM))
      ELSE IF (MESH%TERM_NODE(1,TERM) .GT. 0_I4) THEN                    ! Otherwise, if mesh.term_node(1,term) > 0:
        HLE_TERM_ON_PLANE = ON_PLANE(MESH%TERM_NODE(1,TERM))             ! Set hle_term_on_plane to on_plane(mesh.term_node(1,term)).
      ELSE                                                               ! Otherwise:
        OWNER = MESH%TERM_OWNER(TERM)                                    ! Set owner to mesh.term_owner(term).
        N_VERTEX = TOPOLOGY_NODE_COUNT(MESH%ELEMENT(OWNER)%TOPOLOGY)     ! Set n_vertex to topology_node_count(mesh.element(owner).topology).
        HLE_TERM_ON_PLANE = ALL(ON_PLANE(                                ! Set hle_term_on_plane to whether all of on_plane( mesh.term_node(1,mesh.element(owner).mode_term( 1:n_verte...
     &    MESH%TERM_NODE(1,MESH%ELEMENT(OWNER)%MODE_TERM(
     &    1:N_VERTEX))))
      END IF                                                             ! End of the IF block.

      END FUNCTION HLE_TERM_ON_PLANE                                     ! End of the function hle term on plane.

      SUBROUTINE ADD_POINT_FORCE(POINT, LOAD, NODES, ELEMENTS,           ! Subroutine add point force takes point, load, nodes, elements, incidence, kinematics, expansions, frames, d...
     &     INCIDENCE, KINEMATICS, EXPANSIONS, FRAMES, DOF_LAYOUT,
     &     TOLERANCE, FORCE, STATUS)

      REAL(R8), INTENT(IN) :: POINT(3)                                   ! Input real (real64): point(3).
      REAL(R8), INTENT(IN) :: LOAD(9)                                    ! Input real (real64): load(9).
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(NODE_INCIDENCE_TYPE), INTENT(IN) :: INCIDENCE                 ! Input of type node_incidence_type: incidence.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      REAL(R8), INTENT(INOUT) :: FORCE(:)                                ! In/out real (real64): force(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      REAL(R8) :: PHYSICAL_POINT(3)                                      ! Real (real64): physical_point(3).
      REAL(R8) :: BASIS_VALUE                                            ! Real (real64): basis_value.
      REAL(R8) :: BASIS_GRADIENT(3)                                      ! Real (real64): basis_gradient(3).
      INTEGER(I4) :: ACTIVE_AXIS(2)                                      ! Integer (int32): active_axis(2).
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: ELEMENT_INDEX                                       ! Integer (int32): element_index.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: EXPANSION_NODE                                      ! Integer (int32): expansion_node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      DO NODE_INDEX = 1_I4, SIZE(NODES%ITEM)                             ! Loop node_index from 1 to size(nodes.item):
        ELEMENT_INDEX = FIRST_ELEMENT(INCIDENCE,NODE_INDEX)              ! Set element_index to first_element(incidence,node_index).
        IF (ELEMENT_INDEX .EQ. 0_I4) CYCLE                               ! If element_index = 0, skip to the next iteration.
        MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,                    ! Set mesh_index to find_expansion_index(expansions, elements.item(element_index).expansion_id).
     &    ELEMENTS%ITEM(ELEMENT_INDEX)%EXPANSION_ID)
        IF (MESH_INDEX .EQ. 0_I4) CYCLE                                  ! If mesh_index = 0, skip to the next iteration.
        DO EXPANSION_NODE = 1_I4,                                        ! Loop expansion_node from 1 to size(expansions.item(mesh_index).node):
     &    SIZE(EXPANSIONS%ITEM(MESH_INDEX)%NODE)
          CALL PLACED_POINT(NODES, ELEMENTS, FRAMES, ELEMENT_INDEX,      ! Call placed point with nodes, elements, frames, element_index, node_index, expansions.item(mesh_index).node...
     &      NODE_INDEX, EXPANSIONS%ITEM(MESH_INDEX)%NODE(
     &      EXPANSION_NODE)%COORDINATE, PHYSICAL_POINT)
          IF (SQRT(SUM((PHYSICAL_POINT-POINT)**2)) .GT.                  ! If sqrt(sum((physical_point-point)**2)) > tolerance*max(1.0,sqrt(sum(point**2))), skip to the next iteration.
     &        TOLERANCE*MAX(1.0_R8,SQRT(SUM(POINT**2)))) CYCLE
!         A NODE THAT ONLY DESCRIBES A CURVED SIDE HAS NO DOF.
          IF (EXPANSIONS%ITEM(MESH_INDEX)%IS_HLE) THEN                   ! If expansions.item(mesh_index).is_hle:
            IF (EXPANSIONS%ITEM(MESH_INDEX)%                             ! If expansions.item(mesh_index). node_term(expansion_node) = 0, skip to the next iteration.
     &          NODE_TERM(EXPANSION_NODE) .EQ. 0_I4) CYCLE
          END IF                                                         ! End of the IF block.
          KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(KINEMATICS,             ! Set kinematic_index to find_kinematic_index(kinematics, nodes.item(node_index).kinematic_id).
     &      NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
          CALL FIND_EXPANSION_AXES(EXPANSIONS,MESH_INDEX,                ! Call find expansion axes with expansions, mesh_index, tolerance, dimension, active_axis.
     &                             TOLERANCE,DIMENSION,ACTIVE_AXIS)
          DO FIELD = 1_I4, N_SOLVED_FIELDS                               ! Loop field from 1 to n_solved_fields:
            IF (LOAD(FIELD) .EQ. 0.0_R8) CYCLE                           ! If load(field) = 0.0, skip to the next iteration.
            SELECT CASE(KINEMATICS%ITEM(KINEMATIC_INDEX)%                ! Choose according to the value of kinematics.item(kinematic_index). field(field).family:
     &                  FIELD(FIELD)%FAMILY)
            CASE(EXPANSION_LE, EXPANSION_HLE)                            ! Case expansion_le, expansion_hle:
              TERM = EXPANSION_NODE                                      ! Set term to expansion_node.
              IF (KINEMATICS%ITEM(KINEMATIC_INDEX)%                      ! If kinematics.item(kinematic_index). field(field).family = expansion_hle, set term to expansions.item(mesh_...
     &            FIELD(FIELD)%FAMILY .EQ. EXPANSION_HLE)
     &          TERM = EXPANSIONS%ITEM(MESH_INDEX)%
     &                 NODE_TERM(EXPANSION_NODE)
              FORCE(GLOBAL_DOF(DOF_LAYOUT,NODE_INDEX,                    ! Add load(field) to force(global_dof(dof_layout,node_index, field,term)).
     &              FIELD,TERM)) =
     &          FORCE(GLOBAL_DOF(DOF_LAYOUT,NODE_INDEX,
     &              FIELD,TERM))+LOAD(FIELD)
            CASE(EXPANSION_TE)                                           ! Case expansion_te:
              DO TERM = 1_I4,                                            ! Loop term from 1 to dof_layout.term_count(node_index,field):
     &          DOF_LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)
                CALL EVALUATE_TAYLOR_TERM(                               ! Call evaluate taylor term with kinematics.item(kinematic_index). field(field).order, dimension, active_axis...
     &            KINEMATICS%ITEM(KINEMATIC_INDEX)%
     &            FIELD(FIELD)%ORDER,DIMENSION,ACTIVE_AXIS,
     &            EXPANSIONS%ITEM(MESH_INDEX)%NODE(
     &            EXPANSION_NODE)%COORDINATE,TERM,BASIS_VALUE,
     &            BASIS_GRADIENT,LOCAL_STATUS)
                IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN               ! If not local_status is ok:
                  CALL SET_ERROR(STATUS, 'ADD_POINT_FORCE',              ! Record an error in status: trim(local_status.message).
     &                           TRIM(LOCAL_STATUS%MESSAGE))
                  RETURN                                                 ! Return to the caller.
                END IF                                                   ! End of the IF block.
                FORCE(GLOBAL_DOF(DOF_LAYOUT,NODE_INDEX,                  ! Add load(field)*basis_value to force(global_dof(dof_layout,node_index, field,term)).
     &                FIELD,TERM)) =
     &            FORCE(GLOBAL_DOF(DOF_LAYOUT,NODE_INDEX,
     &                FIELD,TERM))+LOAD(FIELD)*BASIS_VALUE
              END DO                                                     ! End of the loop.
            CASE DEFAULT                                                 ! In every other case:
              CALL SET_ERROR(STATUS, 'ADD_POINT_FORCE',                  ! Record an error in status: 'LOAD ACTS ON AN INACTIVE FIELD'.
     &                       'LOAD ACTS ON AN INACTIVE FIELD')
              RETURN                                                     ! Return to the caller.
            END SELECT                                                   ! End of the case selection.
          END DO                                                         ! End of the loop.
          RETURN                                                         ! Return to the caller.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CALL SET_ERROR(STATUS, 'ADD_POINT_FORCE',                          ! Record an error in status: 'POINT LOAD LOCATION WAS NOT FOUND'.
     &               'POINT LOAD LOCATION WAS NOT FOUND')

      END SUBROUTINE ADD_POINT_FORCE                                     ! End of the subroutine add point force.

!  PRESCRIBED FIELD VALUE (E.G. ELECTRIC POTENTIAL) AT A SECTION NODE
!  OF A LAGRANGE OR HIERARCHICAL EXPANSION.
      SUBROUTINE ADD_POINT_VALUE(POINT, COMPONENT_ACTIVE, VALUE, NODES,  ! Subroutine add point value takes point, component active, value, nodes, elements, incidence, kinematics, ex...
     &     ELEMENTS, INCIDENCE, KINEMATICS, EXPANSIONS, FRAMES,
     &     DOF_LAYOUT, TOLERANCE, CONSTRAINTS, STATUS, FIELD_ID,
     &     FIELDS)

      REAL(R8), INTENT(IN) :: POINT(3)                                   ! Input real (real64): point(3).
      LOGICAL, INTENT(IN) :: COMPONENT_ACTIVE(9)                         ! Input logical: component_active(9).
      REAL(R8), INTENT(IN) :: VALUE(9)                                   ! Input real (real64): value(9).
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(NODE_INCIDENCE_TYPE), INTENT(IN) :: INCIDENCE                 ! Input of type node_incidence_type: incidence.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      TYPE(CONSTRAINT_SET_TYPE), INTENT(INOUT) :: CONSTRAINTS            ! In/out of type constraint_set_type: constraints.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4), INTENT(IN) :: FIELD_ID                                ! Input integer (int32): field_id.
      TYPE(FIELD_DB_TYPE), INTENT(IN) :: FIELDS                          ! Input of type field_db_type: fields.
      REAL(R8) :: PHYSICAL_POINT(3)                                      ! Real (real64): physical_point(3).
      INTEGER(I4) :: ELEMENT_INDEX                                       ! Integer (int32): element_index.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: EXPANSION_NODE                                      ! Integer (int32): expansion_node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      DO NODE_INDEX = 1_I4, SIZE(NODES%ITEM)                             ! Loop node_index from 1 to size(nodes.item):
        ELEMENT_INDEX = FIRST_ELEMENT(INCIDENCE,NODE_INDEX)              ! Set element_index to first_element(incidence,node_index).
        IF (ELEMENT_INDEX .EQ. 0_I4) CYCLE                               ! If element_index = 0, skip to the next iteration.
        MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,                    ! Set mesh_index to find_expansion_index(expansions, elements.item(element_index).expansion_id).
     &    ELEMENTS%ITEM(ELEMENT_INDEX)%EXPANSION_ID)
        IF (MESH_INDEX .EQ. 0_I4) CYCLE                                  ! If mesh_index = 0, skip to the next iteration.
        DO EXPANSION_NODE = 1_I4,                                        ! Loop expansion_node from 1 to size(expansions.item(mesh_index).node):
     &    SIZE(EXPANSIONS%ITEM(MESH_INDEX)%NODE)
          CALL PLACED_POINT(NODES, ELEMENTS, FRAMES, ELEMENT_INDEX,      ! Call placed point with nodes, elements, frames, element_index, node_index, expansions.item(mesh_index).node...
     &      NODE_INDEX, EXPANSIONS%ITEM(MESH_INDEX)%NODE(
     &      EXPANSION_NODE)%COORDINATE, PHYSICAL_POINT)
          IF (SQRT(SUM((PHYSICAL_POINT-POINT)**2)) .GT.                  ! If sqrt(sum((physical_point-point)**2)) > tolerance*max(1.0,sqrt(sum(point**2))), skip to the next iteration.
     &        TOLERANCE*MAX(1.0_R8,SQRT(SUM(POINT**2)))) CYCLE
          IF (EXPANSIONS%ITEM(MESH_INDEX)%IS_HLE) THEN                   ! If expansions.item(mesh_index).is_hle:
            IF (EXPANSIONS%ITEM(MESH_INDEX)%                             ! If expansions.item(mesh_index). node_term(expansion_node) = 0, skip to the next iteration.
     &          NODE_TERM(EXPANSION_NODE) .EQ. 0_I4) CYCLE
          END IF                                                         ! End of the IF block.
          KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(KINEMATICS,             ! Set kinematic_index to find_kinematic_index(kinematics, nodes.item(node_index).kinematic_id).
     &      NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
          DO FIELD = 1_I4, N_SOLVED_FIELDS                               ! Loop field from 1 to n_solved_fields:
            IF (.NOT. COMPONENT_ACTIVE(FIELD)) CYCLE                     ! If not component_active(field), skip to the next iteration.
            SELECT CASE(KINEMATICS%ITEM(KINEMATIC_INDEX)%                ! Choose according to the value of kinematics.item(kinematic_index). field(field).family:
     &                  FIELD(FIELD)%FAMILY)
            CASE(EXPANSION_LE, EXPANSION_HLE)                            ! Case expansion_le, expansion_hle:
              TERM = EXPANSION_NODE                                      ! Set term to expansion_node.
              IF (KINEMATICS%ITEM(KINEMATIC_INDEX)%                      ! If kinematics.item(kinematic_index). field(field).family = expansion_hle, set term to expansions.item(mesh_...
     &            FIELD(FIELD)%FAMILY .EQ. EXPANSION_HLE)
     &          TERM = EXPANSIONS%ITEM(MESH_INDEX)%
     &                 NODE_TERM(EXPANSION_NODE)
              CALL SET_DOF_CONSTRAINT(GLOBAL_DOF(DOF_LAYOUT,             ! Call set dof constraint with global_dof(dof_layout, node_index,field,term), value(field)*evaluate_field( fi...
     &          NODE_INDEX,FIELD,TERM),VALUE(FIELD)*EVALUATE_FIELD(
     &          FIELDS,FIELD_ID,PHYSICAL_POINT(1),PHYSICAL_POINT(2),
     &          PHYSICAL_POINT(3)),TOLERANCE,
     &          CONSTRAINTS,STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
            CASE DEFAULT                                                 ! In every other case:
              CALL SET_ERROR(STATUS, 'ADD_POINT_VALUE',                  ! Record an error in status: 'A POINT VALUE NEEDS A LAGRANGE OR HLE EXPANSION '// 'OF THE FIELD'.
     &          'A POINT VALUE NEEDS A LAGRANGE OR HLE EXPANSION '//
     &          'OF THE FIELD')
              RETURN                                                     ! Return to the caller.
            END SELECT                                                   ! End of the case selection.
          END DO                                                         ! End of the loop.
          RETURN                                                         ! Return to the caller.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CALL SET_ERROR(STATUS, 'ADD_POINT_VALUE',                          ! Record an error in status: 'POINT LOCATION WAS NOT FOUND'.
     &               'POINT LOCATION WAS NOT FOUND')

      END SUBROUTINE ADD_POINT_VALUE                                     ! End of the subroutine add point value.

      SUBROUTINE APPLY_STATIC_CONSTRAINTS(SYSTEM, FORCE,                 ! Subroutine apply static constraints takes system, force, constraints, status.
     &                                    CONSTRAINTS, STATUS)

      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      REAL(R8), INTENT(INOUT) :: FORCE(:)                                ! In/out real (real64): force(:).
      TYPE(CONSTRAINT_SET_TYPE), INTENT(IN) :: CONSTRAINTS               ! Input of type constraint_set_type: constraints.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: COLUMN                                              ! Integer (int64): column.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      LOGICAL :: DIAGONAL_FOUND                                          ! Logical: diagonal_found.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (SIZE(FORCE,KIND=I8) .NE. SYSTEM%ORDER .OR.                     ! If size(force,kind=i8) /= system.order or not allocated(constraints.active) or size(constraints.active,kind...
     &    .NOT. ALLOCATED(CONSTRAINTS%ACTIVE) .OR.
     &    SIZE(CONSTRAINTS%ACTIVE,KIND=I8) .NE. SYSTEM%ORDER) THEN
        CALL SET_ERROR(STATUS, 'APPLY_STATIC_CONSTRAINTS',               ! Record an error in status: 'BOUNDARY DATA SIZE DOES NOT MATCH CSR ORDER'.
     &                 'BOUNDARY DATA SIZE DOES NOT MATCH CSR ORDER')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO ROW = 1_I8, SYSTEM%ORDER                                        ! Loop row from 1 to system.order:
        DO POSITION = SYSTEM%ROW_POINTER(ROW),                           ! Loop position from system.row_pointer(row) to system.row_pointer(row+1)-1:
     &                SYSTEM%ROW_POINTER(ROW+1_I8)-1_I8
          COLUMN = SYSTEM%COLUMN_INDEX(POSITION)                         ! Set column to system.column_index(position).
          IF (CONSTRAINTS%ACTIVE(COLUMN)) THEN                           ! If constraints.active(column):
            FORCE(ROW) = FORCE(ROW)-SYSTEM%STIFFNESS(POSITION)*          ! Subtract system.stiffness(position)* constraints.value(column) from force(row).
     &                   CONSTRAINTS%VALUE(COLUMN)
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      DO ROW = 1_I8, SYSTEM%ORDER                                        ! Loop row from 1 to system.order:
        DIAGONAL_FOUND = .FALSE.                                         ! Set the flag diagonal_found to false.
        DO POSITION = SYSTEM%ROW_POINTER(ROW),                           ! Loop position from system.row_pointer(row) to system.row_pointer(row+1)-1:
     &                SYSTEM%ROW_POINTER(ROW+1_I8)-1_I8
          COLUMN = SYSTEM%COLUMN_INDEX(POSITION)                         ! Set column to system.column_index(position).
          IF (CONSTRAINTS%ACTIVE(ROW) .OR.                               ! If constraints.active(row) or constraints.active(column):
     &        CONSTRAINTS%ACTIVE(COLUMN)) THEN
            SYSTEM%STIFFNESS(POSITION) = 0.0_R8                          ! Set system.stiffness(position) to zero.
          END IF                                                         ! End of the IF block.
          IF (COLUMN .EQ. ROW .AND. CONSTRAINTS%ACTIVE(ROW)) THEN        ! If column = row and constraints.active(row):
            SYSTEM%STIFFNESS(POSITION) = 1.0_R8                          ! Set system.stiffness(position) to 1.0.
            DIAGONAL_FOUND = .TRUE.                                      ! Set the flag diagonal_found to true.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        IF (CONSTRAINTS%ACTIVE(ROW)) THEN                                ! If constraints.active(row):
          IF (.NOT. DIAGONAL_FOUND) THEN                                 ! If not diagonal_found:
            CALL SET_ERROR(STATUS, 'APPLY_STATIC_CONSTRAINTS',           ! Record an error in status: 'CONSTRAINED CSR ROW HAS NO DIAGONAL'.
     &                     'CONSTRAINED CSR ROW HAS NO DIAGONAL')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          FORCE(ROW) = CONSTRAINTS%VALUE(ROW)                            ! Set force(row) to constraints.value(row).
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE APPLY_STATIC_CONSTRAINTS                            ! End of the subroutine apply static constraints.

      SUBROUTINE SET_DOF_CONSTRAINT(DOF, VALUE, TOLERANCE,               ! Subroutine set dof constraint takes dof, value, tolerance, constraints, status.
     &                              CONSTRAINTS, STATUS)

      INTEGER(I8), INTENT(IN) :: DOF                                     ! Input integer (int64): dof.
      REAL(R8), INTENT(IN) :: VALUE                                      ! Input real (real64): value.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      TYPE(CONSTRAINT_SET_TYPE), INTENT(INOUT) :: CONSTRAINTS            ! In/out of type constraint_set_type: constraints.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.

      IF (DOF .LT. 1_I8 .OR. DOF .GT.                                    ! If dof < 1 or dof > size(constraints.active,kind=i8):
     &    SIZE(CONSTRAINTS%ACTIVE,KIND=I8)) THEN
        CALL SET_ERROR(STATUS, 'SET_DOF_CONSTRAINT',                     ! Record an error in status: 'CONSTRAINED DOF IS OUT OF RANGE'.
     &                 'CONSTRAINED DOF IS OUT OF RANGE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (CONSTRAINTS%ACTIVE(DOF)) THEN                                  ! If constraints.active(dof):
        IF (ABS(CONSTRAINTS%VALUE(DOF)-VALUE) .GT.                       ! If abs(constraints.value(dof)-value) > tolerance*max(1.0,abs(value)):
     &      TOLERANCE*MAX(1.0_R8,ABS(VALUE))) THEN
          CALL SET_ERROR(STATUS, 'SET_DOF_CONSTRAINT',                   ! Record an error in status: 'CONFLICTING PRESCRIBED VALUES'.
     &                   'CONFLICTING PRESCRIBED VALUES')
        END IF                                                           ! End of the IF block.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CONSTRAINTS%ACTIVE(DOF) = .TRUE.                                   ! Set the flag constraints.active(dof) to true.
      CONSTRAINTS%VALUE(DOF) = VALUE                                     ! Set constraints.value(dof) to value.

      END SUBROUTINE SET_DOF_CONSTRAINT                                  ! End of the subroutine set dof constraint.

      INTEGER(I4) FUNCTION FIRST_ELEMENT(INCIDENCE, NODE_INDEX)          ! Function first element takes incidence, node index.

      TYPE(NODE_INCIDENCE_TYPE), INTENT(IN) :: INCIDENCE                 ! Input of type node_incidence_type: incidence.
      INTEGER(I4), INTENT(IN) :: NODE_INDEX                              ! Input integer (int32): node_index.

      FIRST_ELEMENT = 0_I4                                               ! Set first_element to zero.
      IF (INCIDENCE%FIRST(NODE_INDEX+1_I4) .GT.                          ! If incidence.first(node_index+1) > incidence.first(node_index), set first_element to incidence.element(inci...
     &    INCIDENCE%FIRST(NODE_INDEX))
     &  FIRST_ELEMENT = INCIDENCE%ELEMENT(INCIDENCE%FIRST(NODE_INDEX))

      END FUNCTION FIRST_ELEMENT                                         ! End of the function first element.

      SUBROUTINE EXPANDED_POINT(STRUCTURAL_POINT, LOCAL_POINT,           ! Subroutine expanded point takes structural point, local point, local to global, physical point.
     &                          LOCAL_TO_GLOBAL, PHYSICAL_POINT)

      REAL(R8), INTENT(IN) :: STRUCTURAL_POINT(3)                        ! Input real (real64): structural_point(3).
      REAL(R8), INTENT(IN) :: LOCAL_POINT(3)                             ! Input real (real64): local_point(3).
      REAL(R8), INTENT(IN) :: LOCAL_TO_GLOBAL(3,3)                       ! Input real (real64): local_to_global(3,3).
      REAL(R8), INTENT(OUT) :: PHYSICAL_POINT(3)                         ! Output real (real64): physical_point(3).

      PHYSICAL_POINT = STRUCTURAL_POINT+                                 ! Set physical_point to structural_point+ matmul(local_to_global,local_point).
     &                 MATMUL(LOCAL_TO_GLOBAL,LOCAL_POINT)

      END SUBROUTINE EXPANDED_POINT                                      ! End of the subroutine expanded point.

!  GLOBAL POSITION OF A POINT OF THE EXPANSION MESH AT A NODE, SEEN BY
!  THE ELEMENT: THE FRAME OF AN ORDINARY ELEMENT, THE TRIAD OF THE NODE
!  OF A CURVED BEAM / SHELL.
      SUBROUTINE PLACED_POINT(NODES, ELEMENTS, FRAMES, ELEMENT_INDEX,    ! Subroutine placed point takes nodes, elements, frames, element index, node index, local point, physical poi...
     &                        NODE_INDEX, LOCAL_POINT, PHYSICAL_POINT,
     &                        MID_SURFACE)

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      INTEGER(I4), INTENT(IN) :: NODE_INDEX                              ! Input integer (int32): node_index.
      REAL(R8), INTENT(IN) :: LOCAL_POINT(3)                             ! Input real (real64): local_point(3).
      REAL(R8), INTENT(OUT) :: PHYSICAL_POINT(3)                         ! Output real (real64): physical_point(3).
!     MID_SURFACE: A PLANE SELECTS THE NODES OF A SHELL BY THEIR
!     MID-SURFACE POINT (THE DIRECTOR IS NOT EXACTLY THE NORMAL OF A
!     SYMMETRY PLANE), AND CONSTRAINS THE WHOLE THICKNESS.
      LOGICAL, INTENT(IN), OPTIONAL :: MID_SURFACE                       ! Input optional logical: mid_surface.
      REAL(R8) :: OFFSET(3)                                              ! Real (real64): offset(3).
      INTEGER(I4) :: L                                                   ! Integer (int32): l.

      IF (PRESENT(MID_SURFACE)) THEN                                     ! If present(mid_surface):
        IF (MID_SURFACE .AND. IS_GENERAL_ELEMENT(FRAMES,ELEMENT_INDEX)   ! If mid_surface and is_general_element(frames,element_index) and topology_natural_dimension(elements.item( e...
     &      .AND. TOPOLOGY_NATURAL_DIMENSION(ELEMENTS%ITEM(
     &      ELEMENT_INDEX)%TOPOLOGY) .EQ. 2_I4) THEN
          PHYSICAL_POINT = NODES%ITEM(NODE_INDEX)%COORDINATE             ! Set physical_point to nodes.item(node_index).coordinate.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      IF (.NOT. IS_GENERAL_ELEMENT(FRAMES,ELEMENT_INDEX)) THEN           ! If not is_general_element(frames,element_index):
        CALL EXPANDED_POINT(NODES%ITEM(NODE_INDEX)%COORDINATE,           ! Call expanded point with nodes.item(node_index).coordinate, local_point, frames.local_to_global(:,:,element...
     &       LOCAL_POINT, FRAMES%LOCAL_TO_GLOBAL(:,:,ELEMENT_INDEX),
     &       PHYSICAL_POINT)
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      PHYSICAL_POINT = NODES%ITEM(NODE_INDEX)%COORDINATE                 ! Set physical_point to nodes.item(node_index).coordinate.
      DO L = 1_I4, SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID)            ! Loop l from 1 to size(elements.item(element_index).node_id):
        IF (ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID(L) .NE.                 ! If elements.item(element_index).node_id(l) /= nodes.item(node_index).id, skip to the next iteration.
     &      NODES%ITEM(NODE_INDEX)%ID) CYCLE
        CALL GENERAL_OFFSET(FRAMES, ELEMENT_INDEX, L, LOCAL_POINT,       ! Call general offset with frames, element_index, l, local_point, offset.
     &                      OFFSET)
        PHYSICAL_POINT = PHYSICAL_POINT + OFFSET                         ! Add offset to physical_point.
        RETURN                                                           ! Return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE PLACED_POINT                                        ! End of the subroutine placed point.

      LOGICAL FUNCTION POINT_ON_PLANE(POINT, PLANE, TOLERANCE)           ! Function point on plane takes point, plane, tolerance.

      REAL(R8), INTENT(IN) :: POINT(3)                                   ! Input real (real64): point(3).
      REAL(R8), INTENT(IN) :: PLANE(4)                                   ! Input real (real64): plane(4).
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      REAL(R8) :: SCALE                                                  ! Real (real64): scale.

      SCALE = MAX(1.0_R8,ABS(PLANE(4)),                                  ! Set scale to max(1.0,abs(plane(4)), sqrt(sum(plane(1:3)**2))*sqrt(sum(point**2))).
     &        SQRT(SUM(PLANE(1:3)**2))*SQRT(SUM(POINT**2)))
      POINT_ON_PLANE = ABS(DOT_PRODUCT(PLANE(1:3),POINT)+                ! Set point_on_plane to abs(dot_product(plane(1:3),point)+ plane(4)) <= tolerance*scale.
     &                 PLANE(4)) .LE. TOLERANCE*SCALE

      END FUNCTION POINT_ON_PLANE                                        ! End of the function point on plane.

      SUBROUTINE FIND_EXPANSION_AXES(EXPANSIONS, MESH_INDEX,             ! Subroutine find expansion axes takes expansions, mesh index, tolerance, dimension, active axis.
     &                               TOLERANCE, DIMENSION,
     &                               ACTIVE_AXIS)

      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      INTEGER(I4), INTENT(IN) :: MESH_INDEX                              ! Input integer (int32): mesh_index.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      INTEGER(I4), INTENT(OUT) :: DIMENSION                              ! Output integer (int32): dimension.
      INTEGER(I4), INTENT(OUT) :: ACTIVE_AXIS(2)                         ! Output integer (int32): active_axis(2).
      REAL(R8) :: MINIMUM(3)                                             ! Real (real64): minimum(3).
      REAL(R8) :: MAXIMUM(3)                                             ! Real (real64): maximum(3).
      INTEGER(I4) :: AXIS                                                ! Integer (int32): axis.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.

      MINIMUM = EXPANSIONS%ITEM(MESH_INDEX)%NODE(1)%COORDINATE           ! Set minimum to expansions.item(mesh_index).node(1).coordinate.
      MAXIMUM = MINIMUM                                                  ! Set maximum to minimum.
      DO NODE = 2_I4, SIZE(EXPANSIONS%ITEM(MESH_INDEX)%NODE)             ! Loop node from 2 to size(expansions.item(mesh_index).node):
        MINIMUM = MIN(MINIMUM,EXPANSIONS%ITEM(MESH_INDEX)%               ! Set minimum to the smaller of minimum and expansions.item(mesh_index). node(node).coordinate.
     &                NODE(NODE)%COORDINATE)
        MAXIMUM = MAX(MAXIMUM,EXPANSIONS%ITEM(MESH_INDEX)%               ! Set maximum to the larger of maximum and expansions.item(mesh_index). node(node).coordinate.
     &                NODE(NODE)%COORDINATE)
      END DO                                                             ! End of the loop.
      DIMENSION = 0_I4                                                   ! Set dimension to zero.
      ACTIVE_AXIS = [1_I4,2_I4]                                          ! Set active_axis to [1,2].
      DO AXIS = 1_I4, 3_I4                                               ! Loop axis from 1 to 3:
        IF (MAXIMUM(AXIS)-MINIMUM(AXIS) .LE. TOLERANCE) CYCLE            ! If maximum(axis)-minimum(axis) <= tolerance, skip to the next iteration.
        DIMENSION = DIMENSION+1_I4                                       ! Add 1 to dimension.
        IF (DIMENSION .LE. 2_I4) ACTIVE_AXIS(DIMENSION) = AXIS           ! If dimension <= 2, set active_axis(dimension) to axis.
      END DO                                                             ! End of the loop.

      END SUBROUTINE FIND_EXPANSION_AXES                                 ! End of the subroutine find expansion axes.

      SUBROUTINE CLEAR_BOUNDARY_DATA(CONSTRAINTS, FORCE)                 ! Subroutine clear boundary data takes constraints, force.

      TYPE(CONSTRAINT_SET_TYPE), INTENT(INOUT) :: CONSTRAINTS            ! In/out of type constraint_set_type: constraints.
      REAL(R8), ALLOCATABLE, INTENT(INOUT) :: FORCE(:)                   ! Allocatable in/out real (real64): force(:).

      IF (ALLOCATED(CONSTRAINTS%ACTIVE))                                 ! If allocated(constraints.active), free the memory of constraints.active.
     &  DEALLOCATE(CONSTRAINTS%ACTIVE)
      IF (ALLOCATED(CONSTRAINTS%VALUE))                                  ! If allocated(constraints.value), free the memory of constraints.value.
     &  DEALLOCATE(CONSTRAINTS%VALUE)
      IF (ALLOCATED(CONSTRAINTS%MASTER))                                 ! If allocated(constraints.master), free the memory of constraints.master.
     &  DEALLOCATE(CONSTRAINTS%MASTER)
      CONSTRAINTS%HAS_TIES = .FALSE.                                     ! Set the flag constraints.has_ties to false.
      IF (ALLOCATED(FORCE)) DEALLOCATE(FORCE)                            ! If allocated(force), free the memory of force.
      CONSTRAINTS%COUNT = 0_I8                                           ! Set constraints.count to zero.

      END SUBROUTINE CLEAR_BOUNDARY_DATA                                 ! End of the subroutine clear boundary data.

      END MODULE MUL2_BOUNDARY_APPLICATION                               ! End of the module mul2 boundary application.
