!=======================================================================
!  PREPROCESSING OF A VALIDATED MODEL: FRAMES, DOFS, GAUSS DATABASES
!  AND MATERIAL CACHE. NOTHING HERE DEPENDS ON THE ANALYSIS TYPE.
!=======================================================================
      MODULE MUL2_MODEL_CACHE                                            ! Module mul2 model cache begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, set warning, status is ok, merge status.
     &                       SET_WARNING, STATUS_IS_OK, MERGE_STATUS
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_ANALYSIS_INPUT, ONLY: SHEAR_MITC, SHEAR_REDUCED,          ! Use from module mul2 analysis input: shear mitc, shear reduced, shear selective.
     &                               SHEAR_SELECTIVE
      USE MUL2_NODES, ONLY: FIND_NODE_INDEX                              ! Use from module mul2 nodes: find node index.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION,             ! Use from module mul2 topologies: topology natural dimension, topology node count, topology q4, topology h8,...
     &                           TOPOLOGY_NODE_COUNT, TOPOLOGY_Q4,
     &                           TOPOLOGY_H8, TOPOLOGY_H27
      USE MUL2_MITC, ONLY: MITC_DATA_TYPE, MITC_IS_AVAILABLE,            ! Use from module mul2 mitc: mitc data type, mitc is available, mitc prepare element.
     &                     MITC_PREPARE_ELEMENT
      USE MUL2_KINEMATICS, ONLY: N_FIELDS, EXPANSION_NONE, EXPANSION_TE, ! Use from module mul2 kinematics: n fields, expansion none, expansion te, find kinematic index.
     &                        FIND_KINEMATIC_INDEX
      USE MUL2_EXPANSION_MESHES, ONLY: FIND_EXPANSION_INDEX              ! Use from module mul2 expansion meshes: find expansion index.
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_ELEMENT_FRAMES, ONLY: BUILD_ELEMENT_FRAMES                ! Use from module mul2 element frames: build element frames.
      USE MUL2_GENERAL_GEOMETRY, ONLY: BUILD_GENERAL_GEOMETRY            ! Use from module mul2 general geometry: build general geometry.
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE, BUILD_DOF_LAYOUT       ! Use from module mul2 dof layout: dof layout type, build dof layout.
      USE MUL2_COINCIDENT_JOIN, ONLY: JOIN_COINCIDENT_DOFS               ! Use from module mul2 coincident join: join coincident dofs.
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type, build reference rule database...
     &     GAUSS_LAYOUT_TYPE, BUILD_REFERENCE_RULE_DATABASE,
     &     BUILD_GAUSS_LAYOUT
      USE MUL2_GAUSS_GEOMETRY, ONLY:                                     ! Use from module mul2 gauss geometry: structural geometry cache type, expansion geometry cache type, gauss g...
     &     STRUCTURAL_GEOMETRY_CACHE_TYPE,
     &     EXPANSION_GEOMETRY_CACHE_TYPE, GAUSS_GEOMETRY_TYPE,
     &     BUILD_STRUCTURAL_GEOMETRY_CACHE,
     &     BUILD_EXPANSION_GEOMETRY_CACHE,
     &     BUILD_COMBINED_GAUSS_GEOMETRY
      USE MUL2_GAUSS_MATERIALS, ONLY: MATERIAL_CACHE_TYPE,               ! Use from module mul2 gauss materials: material cache type, gauss material map type, build gauss material ca...
     &     GAUSS_MATERIAL_MAP_TYPE, BUILD_GAUSS_MATERIAL_CACHE
      USE MUL2_QUADRATURE, ONLY: REDUCED_POINTS_PER_DIRECTION            ! Use from module mul2 quadrature: reduced points per direction.
      USE MUL2_LAMINATIONS, ONLY: FIND_LAMINATION_INDEX                  ! Use from module mul2 laminations: find lamination index.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!  SECOND INTEGRATION SET OF THE REDUCED AND SELECTIVE INTEGRATION: THE
!  STRUCTURAL POINTS USE THE REDUCED RULE (THE EXPANSION POINTS ARE
!  THE SAME AS IN THE FULL SET).
      TYPE, PUBLIC :: REDUCED_SET_TYPE                                   ! Definition of the derived type reduced set type.
        TYPE(GAUSS_LAYOUT_TYPE) :: GAUSS_LAYOUT                          ! Of type gauss_layout_type: gauss_layout.
        TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE) :: STRUCTURAL_GEOMETRY      ! Of type structural_geometry_cache_type: structural_geometry.
        TYPE(GAUSS_GEOMETRY_TYPE) :: GEOMETRY                            ! Of type gauss_geometry_type: geometry.
        TYPE(GAUSS_MATERIAL_MAP_TYPE) :: MATERIAL_MAP                    ! Of type gauss_material_map_type: material_map.
      END TYPE REDUCED_SET_TYPE                                          ! End of the type definition reduced set type.

      TYPE, PUBLIC :: MODEL_CACHE_TYPE                                   ! Definition of the derived type model cache type.
        TYPE(ELEMENT_FRAME_DB_TYPE) :: FRAMES                            ! Of type element_frame_db_type: frames.
        TYPE(DOF_LAYOUT_TYPE) :: DOF_LAYOUT                              ! Of type dof_layout_type: dof_layout.
        TYPE(REFERENCE_RULE_DB_TYPE) :: RULES                            ! Of type reference_rule_db_type: rules.
        TYPE(GAUSS_LAYOUT_TYPE) :: GAUSS_LAYOUT                          ! Of type gauss_layout_type: gauss_layout.
        TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE) :: STRUCTURAL_GEOMETRY      ! Of type structural_geometry_cache_type: structural_geometry.
        TYPE(EXPANSION_GEOMETRY_CACHE_TYPE) :: EXPANSION_GEOMETRY        ! Of type expansion_geometry_cache_type: expansion_geometry.
        TYPE(GAUSS_GEOMETRY_TYPE) :: GEOMETRY                            ! Of type gauss_geometry_type: geometry.
        TYPE(MATERIAL_CACHE_TYPE) :: MATERIAL_CACHE                      ! Of type material_cache_type: material_cache.
        INTEGER(I4), ALLOCATABLE :: EXPANSION_ORDER(:)                   ! Allocatable integer (int32): expansion_order(:).
        TYPE(GAUSS_MATERIAL_MAP_TYPE) :: MATERIAL_MAP                    ! Of type gauss_material_map_type: material_map.
!       REDUCED_DIMENSION(D): ELEMENTS OF DIMENSION D USE THE REDUCED
!       SET (REDI OR SELI WITH AN AVAILABLE REDUCED RULE).
        LOGICAL :: REDUCED_DIMENSION(3) = .FALSE.                        ! Logical: reduced_dimension(3) = false.
        LOGICAL :: HAS_REDUCED = .FALSE.                                 ! Logical: has_reduced = false.
        TYPE(REDUCED_SET_TYPE) :: REDUCED                                ! Of type reduced_set_type: reduced.
      END TYPE MODEL_CACHE_TYPE                                          ! End of the type definition model cache type.

      PUBLIC :: CHECK_MECHANICAL_MODEL                                   ! Export: check mechanical model.
      PUBLIC :: BUILD_MODEL_CACHE                                        ! Export: build model cache.
      PUBLIC :: PREPARE_ELEMENT_MITC                                     ! Export: prepare element mitc.
      PUBLIC :: ELEMENT_SHEAR_MODE                                       ! Export: element shear mode.

      CONTAINS                                                           ! The procedures of the module follow.

!  V3 101/103 ARE PURELY MECHANICAL: ONLY U, V AND W MAY BE ACTIVE.
      SUBROUTINE CHECK_MECHANICAL_MODEL(MODEL, STATUS)                   ! Subroutine check mechanical model takes model, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      DO I = 1_I4, SIZE(MODEL%KINEMATICS%ITEM)                           ! Loop i from 1 to size(model.kinematics.item):
        DO FIELD = 4_I4, N_FIELDS                                        ! Loop field from 4 to n_fields:
          IF (FIELD .EQ. 4_I4 .OR. FIELD .EQ. 5_I4) CYCLE                ! If field = 4 or field = 5, skip to the next iteration.
          IF (MODEL%KINEMATICS%ITEM(I)%FIELD(FIELD)%FAMILY               ! If model.kinematics.item(i).field(field).family /= expansion_none:
     &        .NE. EXPANSION_NONE) THEN
            CALL SET_ERROR(STATUS, 'CHECK_MECHANICAL_MODEL',             ! Record an error in status: 'ONLY U, V, W, THE TEMPERATURE T AND THE ELECTRIC '// 'POTENTIAL P ARE SUPPORTED...
     &        'ONLY U, V, W, THE TEMPERATURE T AND THE ELECTRIC '//
     &        'POTENTIAL P ARE SUPPORTED BY 101/103')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (SIZE(MODEL%ELEMENTS%ITEM) .LT. 1_I4) THEN                      ! If size(model.elements.item) < 1:
        CALL SET_ERROR(STATUS, 'CHECK_MECHANICAL_MODEL',                 ! Record an error in status: 'THE MODEL HAS NO ELEMENTS'.
     &                 'THE MODEL HAS NO ELEMENTS')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE CHECK_MECHANICAL_MODEL                              ! End of the subroutine check mechanical model.

      SUBROUTINE BUILD_MODEL_CACHE(MODEL, CACHE, STATUS)                 ! Subroutine build model cache takes model, cache, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(INOUT) :: CACHE                     ! In/out of type model_cache_type: cache.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(MATERIAL_CACHE_TYPE) :: SCRATCH_MATERIALS                     ! Of type material_cache_type: scratch_materials.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CHECK_MECHANICAL_MODEL(MODEL, LOCAL_STATUS)                   ! Call check mechanical model with model, local_status.
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL BUILD_DOF_LAYOUT(MODEL%NODES, MODEL%ELEMENTS,                 ! Call build dof layout with model.nodes, model.elements, model.kinematics, model.expansions, cache.dof_layou...
     &     MODEL%KINEMATICS, MODEL%EXPANSIONS, CACHE%DOF_LAYOUT,
     &     LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL BUILD_ELEMENT_FRAMES(MODEL%NODES, MODEL%ELEMENTS,             ! Call build element frames with model.nodes, model.elements, model.vectors, cache.frames, local_status.
     &     MODEL%VECTORS, CACHE%FRAMES, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
!     CURVED BEAMS AND SHELLS: NODAL TRIADS.
      CALL BUILD_GENERAL_GEOMETRY(MODEL%NODES, MODEL%ELEMENTS,           ! Call build general geometry with model.nodes, model.elements, model.vectors, cache.frames, local_status.
     &     MODEL%VECTORS, CACHE%FRAMES, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
!     DOFS OF DIFFERENT NODES AT THE SAME POINT (JOIN COINCIDENT).
      IF (MODEL%ANALYSIS%JOIN_COINCIDENT) THEN                           ! If model.analysis.join_coincident:
        CALL JOIN_COINCIDENT_DOFS(MODEL%NODES, MODEL%ELEMENTS,           ! Call join coincident dofs with model.nodes, model.elements, model.kinematics, model.expansions, cache.frame...
     &       MODEL%KINEMATICS, MODEL%EXPANSIONS, CACHE%FRAMES,
     &       MODEL%ANALYSIS%JOIN_TOLERANCE, CACHE%DOF_LAYOUT,
     &       LOCAL_STATUS)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END IF                                                             ! End of the IF block.

      CALL BUILD_EXPANSION_POINT_ORDERS(MODEL, CACHE%EXPANSION_ORDER)    ! Call build expansion point orders with model, cache.expansion_order.
      CALL FIND_REDUCED_DIMENSIONS(MODEL, CACHE%REDUCED_DIMENSION,       ! Call find reduced dimensions with model, cache.reduced_dimension, local_status.
     &                             LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      CACHE%HAS_REDUCED = ANY(CACHE%REDUCED_DIMENSION)                   ! Set cache.has_reduced to whether any of cache.reduced_dimension.
      CALL BUILD_REFERENCE_RULE_DATABASE(MODEL%ELEMENTS,                 ! Call build reference rule database with model.elements, model.expansions, cache.rules, local_status, cache....
     &     MODEL%EXPANSIONS, CACHE%RULES, LOCAL_STATUS,
     &     CACHE%EXPANSION_ORDER, CACHE%REDUCED_DIMENSION)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL BUILD_GAUSS_LAYOUT(MODEL%ELEMENTS, MODEL%EXPANSIONS,          ! Call build gauss layout with model.elements, model.expansions, cache.rules, cache.gauss_layout, local_statu...
     &     CACHE%RULES, CACHE%GAUSS_LAYOUT, LOCAL_STATUS,
     &     CACHE%EXPANSION_ORDER)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL BUILD_STRUCTURAL_GEOMETRY_CACHE(MODEL%NODES,                  ! Call build structural geometry cache with model.nodes, model.elements, cache.frames, cache.rules, cache.str...
     &     MODEL%ELEMENTS, CACHE%FRAMES, CACHE%RULES,
     &     CACHE%STRUCTURAL_GEOMETRY, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL BUILD_EXPANSION_GEOMETRY_CACHE(MODEL%EXPANSIONS,              ! Call build expansion geometry cache with model.expansions, cache.rules, cache.expansion_geometry, local_sta...
     &     CACHE%RULES, CACHE%EXPANSION_GEOMETRY, LOCAL_STATUS,
     &     CACHE%EXPANSION_ORDER)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL BUILD_COMBINED_GAUSS_GEOMETRY(MODEL%ELEMENTS,                 ! Call build combined gauss geometry with model.elements, model.expansions, cache.frames, cache.gauss_layout,...
     &     MODEL%EXPANSIONS, CACHE%FRAMES, CACHE%GAUSS_LAYOUT,
     &     CACHE%STRUCTURAL_GEOMETRY, CACHE%EXPANSION_GEOMETRY,
     &     CACHE%GEOMETRY, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL BUILD_GAUSS_MATERIAL_CACHE(CACHE%GAUSS_LAYOUT,                ! Call build gauss material cache with cache.gauss_layout, model.materials, model.laminations, cache.material...
     &     MODEL%MATERIALS, MODEL%LAMINATIONS, CACHE%MATERIAL_CACHE,
     &     CACHE%MATERIAL_MAP, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL CHECK_PHYSICS_DATA(MODEL, CACHE%MATERIAL_CACHE, LOCAL_STATUS) ! Call check physics data with model, cache.material_cache, local_status.
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (.NOT. CACHE%HAS_REDUCED) RETURN                                ! If not cache.has_reduced, return to the caller.

!     SECOND SET WITH THE REDUCED STRUCTURAL RULE (REDI / SELI).
      CALL BUILD_GAUSS_LAYOUT(MODEL%ELEMENTS, MODEL%EXPANSIONS,          ! Call build gauss layout with model.elements, model.expansions, cache.rules, cache.reduced.gauss_layout, loc...
     &     CACHE%RULES, CACHE%REDUCED%GAUSS_LAYOUT, LOCAL_STATUS,
     &     CACHE%EXPANSION_ORDER, .TRUE.)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_STRUCTURAL_GEOMETRY_CACHE(MODEL%NODES,                  ! Call build structural geometry cache with model.nodes, model.elements, cache.frames, cache.rules, cache.red...
     &     MODEL%ELEMENTS, CACHE%FRAMES, CACHE%RULES,
     &     CACHE%REDUCED%STRUCTURAL_GEOMETRY, LOCAL_STATUS, .TRUE.)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_COMBINED_GAUSS_GEOMETRY(MODEL%ELEMENTS,                 ! Call build combined gauss geometry with model.elements, model.expansions, cache.frames, cache.reduced.gauss...
     &     MODEL%EXPANSIONS, CACHE%FRAMES, CACHE%REDUCED%GAUSS_LAYOUT,
     &     CACHE%REDUCED%STRUCTURAL_GEOMETRY, CACHE%EXPANSION_GEOMETRY,
     &     CACHE%REDUCED%GEOMETRY, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL BUILD_GAUSS_MATERIAL_CACHE(CACHE%REDUCED%GAUSS_LAYOUT,        ! Call build gauss material cache with cache.reduced.gauss_layout, model.materials, model.laminations, scratc...
     &     MODEL%MATERIALS, MODEL%LAMINATIONS, SCRATCH_MATERIALS,
     &     CACHE%REDUCED%MATERIAL_MAP, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.

      END SUBROUTINE BUILD_MODEL_CACHE                                   ! End of the subroutine build model cache.

!  EVERY LAMINATION OF AN ELEMENT WHOSE NODES SOLVE THE TEMPERATURE (THE
!  ELECTRIC POTENTIAL) NEEDS ITS CONDUCTIVITY (PERMITTIVITY): WITHOUT
!  THEM THE MATRIX IS SINGULAR AND THE SOLVER ONLY REPORTS NOT-A-NUMBER.
      SUBROUTINE CHECK_PHYSICS_DATA(MODEL, MATERIALS, STATUS)            ! Subroutine check physics data takes model, materials, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: MATERIALS                 ! Input of type material_cache_type: materials.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=96) :: MESSAGE                                       ! Character (length 96): message.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC                                           ! Integer (int32): kinematic.
      INTEGER(I4) :: MESH                                                ! Integer (int32): mesh.
      INTEGER(I4) :: SUB                                                 ! Integer (int32): sub.
      INTEGER(I4) :: LAMINATION                                          ! Integer (int32): lamination.
      LOGICAL :: NEEDS_T                                                 ! Logical: needs_t.
      LOGICAL :: NEEDS_P                                                 ! Logical: needs_p.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      DO ELEMENT = 1_I4, SIZE(MODEL%ELEMENTS%ITEM)                       ! Loop element from 1 to size(model.elements.item):
        NEEDS_T = .FALSE.                                                ! Set the flag needs_t to false.
        NEEDS_P = .FALSE.                                                ! Set the flag needs_p to false.
        DO NODE = 1_I4, SIZE(MODEL%ELEMENTS%ITEM(ELEMENT)%NODE_ID)       ! Loop node from 1 to size(model.elements.item(element).node_id):
          NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES,                      ! Set node_index to find_node_index(model.nodes, model.elements.item(element).node_id(node)).
     &      MODEL%ELEMENTS%ITEM(ELEMENT)%NODE_ID(NODE))
          KINEMATIC = FIND_KINEMATIC_INDEX(MODEL%KINEMATICS,             ! Set kinematic to find_kinematic_index(model.kinematics, model.nodes.item(node_index).kinematic_id).
     &      MODEL%NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
          IF (MODEL%KINEMATICS%ITEM(KINEMATIC)%FIELD(4)%FAMILY           ! If model.kinematics.item(kinematic).field(4).family /= expansion_none, set the flag needs_t to true.
     &        .NE. EXPANSION_NONE) NEEDS_T = .TRUE.
          IF (MODEL%KINEMATICS%ITEM(KINEMATIC)%FIELD(5)%FAMILY           ! If model.kinematics.item(kinematic).field(5).family /= expansion_none, set the flag needs_p to true.
     &        .NE. EXPANSION_NONE) NEEDS_P = .TRUE.
        END DO                                                           ! End of the loop.
        IF (.NOT. (NEEDS_T .OR. NEEDS_P)) CYCLE                          ! If not (needs_t or needs_p), skip to the next iteration.
        MESH = FIND_EXPANSION_INDEX(MODEL%EXPANSIONS,                    ! Set mesh to find_expansion_index(model.expansions, model.elements.item(element).expansion_id).
     &         MODEL%ELEMENTS%ITEM(ELEMENT)%EXPANSION_ID)
        IF (MESH .EQ. 0_I4) CYCLE                                        ! If mesh = 0, skip to the next iteration.
        DO SUB = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT)         ! Loop sub from 1 to size(model.expansions.item(mesh).element):
          LAMINATION = FIND_LAMINATION_INDEX(MODEL%LAMINATIONS,          ! Set lamination to find_lamination_index(model.laminations, model.expansions.item(mesh).element(sub).laminat...
     &      MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT(SUB)%LAMINATION_ID)
          IF (LAMINATION .EQ. 0_I4) CYCLE                                ! If lamination = 0, skip to the next iteration.
          IF (NEEDS_T .AND. ALL(MATERIALS%CONDUCTIVITY_LOCAL(:,:,        ! If needs_t and all(materials.conductivity_local(:,:, lamination) = 0.0):
     &        LAMINATION) .EQ. 0.0_R8)) THEN
            WRITE(MESSAGE,'(A,I0,A)') 'LAMINATION ',                     ! Format into the text message: 'LAMINATION ', model.laminations.item(lamination).id, ' HAS NO T-CON BUT THE ...
     &        MODEL%LAMINATIONS%ITEM(LAMINATION)%ID,
     &        ' HAS NO T-CON BUT THE TEMPERATURE IS SOLVED'
            CALL SET_ERROR(STATUS, 'CHECK_PHYSICS_DATA', TRIM(MESSAGE))  ! Record an error in status: trim(message).
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          IF (NEEDS_P .AND. ALL(MATERIALS%PERMITTIVITY_LOCAL(:,:,        ! If needs_p and all(materials.permittivity_local(:,:, lamination) = 0.0):
     &        LAMINATION) .EQ. 0.0_R8)) THEN
            WRITE(MESSAGE,'(A,I0,A)') 'LAMINATION ',                     ! Format into the text message: 'LAMINATION ', model.laminations.item(lamination).id, ' HAS NO Z-PRM BUT THE ...
     &        MODEL%LAMINATIONS%ITEM(LAMINATION)%ID,
     &        ' HAS NO Z-PRM BUT THE POTENTIAL IS SOLVED'
            CALL SET_ERROR(STATUS, 'CHECK_PHYSICS_DATA', TRIM(MESSAGE))  ! Record an error in status: trim(message).
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE CHECK_PHYSICS_DATA                                  ! End of the subroutine check physics data.

!  DIMENSIONS (1 BEAM, 2 PLATE, 3 SOLID) WHOSE ELEMENTS USE THE REDUCED
!  STRUCTURAL RULE. A DIMENSION REQUESTING REDI/SELI WITH NO ELEMENT
!  THAT HAS A REDUCED RULE (TRIANGLES) STAYS FULLY INTEGRATED: WARNING.
      SUBROUTINE FIND_REDUCED_DIMENSIONS(MODEL, REDUCED, STATUS)         ! Subroutine find reduced dimensions takes model, reduced, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      LOGICAL, INTENT(OUT) :: REDUCED(3)                                 ! Output logical: reduced(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      LOGICAL :: ASKED(3)                                                ! Logical: asked(3).
      LOGICAL :: HOURGLASS                                               ! Logical: hourglass.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: DIM                                                 ! Integer (int32): dim.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      REDUCED = .FALSE.                                                  ! Set the flag reduced to false.
      ASKED = .FALSE.                                                    ! Set the flag asked to false.
      HOURGLASS = .FALSE.                                                ! Set the flag hourglass to false.
      DO I = 1_I4, SIZE(MODEL%ELEMENTS%ITEM)                             ! Loop i from 1 to size(model.elements.item):
        DIM = TOPOLOGY_NATURAL_DIMENSION(                                ! Set dim to topology_natural_dimension( model.elements.item(i).topology).
     &        MODEL%ELEMENTS%ITEM(I)%TOPOLOGY)
        IF (DIM .LT. 1_I4 .OR. DIM .GT. 3_I4) CYCLE                      ! If dim < 1 or dim > 3, skip to the next iteration.
        IF (MODEL%ANALYSIS%SHEAR(DIM) .NE. SHEAR_REDUCED .AND.           ! If model.analysis.shear(dim) /= shear_reduced and model.analysis.shear(dim) /= shear_selective, skip to the...
     &      MODEL%ANALYSIS%SHEAR(DIM) .NE. SHEAR_SELECTIVE) CYCLE
        ASKED(DIM) = .TRUE.                                              ! Set the flag asked(dim) to true.
        IF (MODEL%ANALYSIS%SHEAR(DIM) .EQ. SHEAR_REDUCED .AND.           ! If model.analysis.shear(dim) = shear_reduced and (model.elements.item(i).topology = topology_q4 or model.el...
     &      (MODEL%ELEMENTS%ITEM(I)%TOPOLOGY .EQ. TOPOLOGY_Q4 .OR.
     &      MODEL%ELEMENTS%ITEM(I)%TOPOLOGY .EQ. TOPOLOGY_H8 .OR.
     &      MODEL%ELEMENTS%ITEM(I)%TOPOLOGY .EQ. TOPOLOGY_H27))
     &    HOURGLASS = .TRUE.
        IF (REDUCED_POINTS_PER_DIRECTION(                                ! If reduced_points_per_direction( model.elements.item(i).topology) > 0, set the flag reduced(dim) to true.
     &      MODEL%ELEMENTS%ITEM(I)%TOPOLOGY) .GT. 0_I4)
     &    REDUCED(DIM) = .TRUE.
      END DO                                                             ! End of the loop.
      IF (ANY(ASKED .AND. .NOT. REDUCED)) THEN                           ! If any(asked and not reduced):
        CALL SET_WARNING(STATUS, 'FIND_REDUCED_DIMENSIONS',              ! Record a warning in status: 'REDI/SELI IS NOT DEFINED FOR TRIANGLES: FULL INTEGRATION'.
     &    'REDI/SELI IS NOT DEFINED FOR TRIANGLES: FULL INTEGRATION')
      END IF                                                             ! End of the IF block.
      IF (HOURGLASS) THEN                                                ! If hourglass:
        CALL SET_WARNING(STATUS, 'FIND_REDUCED_DIMENSIONS',              ! Record a warning in status: 'REDI LEAVES HOURGLASS MODES IN Q4, H8 AND H27: USE SELI'.
     &    'REDI LEAVES HOURGLASS MODES IN Q4, H8 AND H27: USE SELI')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE FIND_REDUCED_DIMENSIONS                             ! End of the subroutine find reduced dimensions.

!  SHEAR TREATMENT REQUESTED FOR THE DIMENSION OF AN ELEMENT.
      INTEGER(I4) FUNCTION ELEMENT_SHEAR_MODE(MODEL, ELEMENT)            ! Function element shear mode takes model, element.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      INTEGER(I4) :: DIM                                                 ! Integer (int32): dim.

      ELEMENT_SHEAR_MODE = 0_I4                                          ! Set element_shear_mode to zero.
      DIM = TOPOLOGY_NATURAL_DIMENSION(                                  ! Set dim to topology_natural_dimension( model.elements.item(element).topology).
     &      MODEL%ELEMENTS%ITEM(ELEMENT)%TOPOLOGY)
      IF (DIM .GE. 1_I4 .AND. DIM .LE. 3_I4)                             ! If dim >= 1 and dim <= 3, set element_shear_mode to model.analysis.shear(dim).
     &  ELEMENT_SHEAR_MODE = MODEL%ANALYSIS%SHEAR(DIM)

      END FUNCTION ELEMENT_SHEAR_MODE                                    ! End of the function element shear mode.


!  GAUSS POINTS PER DIRECTION NEEDED BY EACH EXPANSION MESH. A TAYLOR
!  EXPANSION OF ORDER N GIVES INTEGRANDS OF DEGREE 2N: N+1 POINTS ARE
!  REQUIRED (THE BASELINE USES THE SAME COUNT). LE NODES NEED NOTHING
!  BEYOND THE DEFAULT RULE OF THE EXPANSION ELEMENT.
      SUBROUTINE BUILD_EXPANSION_POINT_ORDERS(MODEL, ORDER)              ! Subroutine build expansion point orders takes model, order.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      INTEGER(I4), ALLOCATABLE, INTENT(INOUT) :: ORDER(:)                ! Allocatable in/out integer (int32): order(:).
      INTEGER(I4) :: MESH                                                ! Integer (int32): mesh.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.

      IF (ALLOCATED(ORDER)) DEALLOCATE(ORDER)                            ! If allocated(order), free the memory of order.
      ALLOCATE(ORDER(SIZE(MODEL%EXPANSIONS%ITEM)))                       ! Allocate memory for order(size(model.expansions.item)).
      ORDER = 0_I4                                                       ! Set order to zero.
      DO I = 1_I4, SIZE(MODEL%ELEMENTS%ITEM)                             ! Loop i from 1 to size(model.elements.item):
        MESH = FIND_EXPANSION_INDEX(MODEL%EXPANSIONS,                    ! Set mesh to find_expansion_index(model.expansions, model.elements.item(i).expansion_id).
     &         MODEL%ELEMENTS%ITEM(I)%EXPANSION_ID)
        IF (MESH .EQ. 0_I4) CYCLE                                        ! If mesh = 0, skip to the next iteration.
        DO J = 1_I4, SIZE(MODEL%ELEMENTS%ITEM(I)%NODE_ID)                ! Loop j from 1 to size(model.elements.item(i).node_id):
          NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES,                      ! Set node_index to find_node_index(model.nodes, model.elements.item(i).node_id(j)).
     &                 MODEL%ELEMENTS%ITEM(I)%NODE_ID(J))
          IF (NODE_INDEX .EQ. 0_I4) CYCLE                                ! If node_index = 0, skip to the next iteration.
          KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(MODEL%KINEMATICS,       ! Set kinematic_index to find_kinematic_index(model.kinematics, model.nodes.item(node_index).kinematic_id).
     &      MODEL%NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
          IF (KINEMATIC_INDEX .EQ. 0_I4) CYCLE                           ! If kinematic_index = 0, skip to the next iteration.
          DO FIELD = 1_I4, 3_I4                                          ! Loop field from 1 to 3:
            IF (MODEL%KINEMATICS%ITEM(KINEMATIC_INDEX)%FIELD(FIELD)%     ! If model.kinematics.item(kinematic_index).field(field). family = expansion_te, set order(mesh) to the large...
     &          FAMILY .EQ. EXPANSION_TE) ORDER(MESH) = MAX(ORDER(MESH),
     &        MODEL%KINEMATICS%ITEM(KINEMATIC_INDEX)%FIELD(FIELD)%
     &        ORDER+1_I4)
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_EXPANSION_POINT_ORDERS                        ! End of the subroutine build expansion point orders.
!  MITC TYING DATA OF ONE ELEMENT WHEN THE ANALYSIS REQUESTS MITC FOR
!  ITS DIMENSION. A TOPOLOGY WITHOUT A MITC TABLE IS INTEGRATED FULLY
!  AND A WARNING IS RAISED (THE BASELINE SILENTLY PRODUCES NO MATRIX).
      SUBROUTINE PREPARE_ELEMENT_MITC(MODEL, CACHE, ELEMENT, MITC,       ! Subroutine prepare element mitc takes model, cache, element, mitc, status.
     &                                STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      TYPE(MITC_DATA_TYPE), INTENT(INOUT) :: MITC                        ! In/out of type mitc_data_type: mitc.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: NODE_LOCAL(:,:)                           ! Allocatable real (real64): node_local(:,:).
      INTEGER(I4) :: TOPOLOGY                                            ! Integer (int32): topology.
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      MITC%ACTIVE = .FALSE.                                              ! Set the flag mitc.active to false.
      TOPOLOGY = MODEL%ELEMENTS%ITEM(ELEMENT)%TOPOLOGY                   ! Set topology to model.elements.item(element).topology.
      DIMENSION = TOPOLOGY_NATURAL_DIMENSION(TOPOLOGY)                   ! Set dimension to topology_natural_dimension(topology).
      IF (DIMENSION .LT. 1_I4 .OR. DIMENSION .GT. 3_I4) RETURN           ! If dimension < 1 or dimension > 3, return to the caller.
      IF (MODEL%ANALYSIS%SHEAR(DIMENSION) .NE. SHEAR_MITC) RETURN        ! If model.analysis.shear(dimension) /= shear_mitc, return to the caller.
      IF (.NOT. MITC_IS_AVAILABLE(TOPOLOGY)) THEN                        ! If not mitc_is_available(topology):
        CALL SET_WARNING(STATUS, 'PREPARE_ELEMENT_MITC',                 ! Record a warning in status: 'MITC IS NOT DEFINED FOR SOME TOPOLOGY: FULL INTEGRATION'.
     &    'MITC IS NOT DEFINED FOR SOME TOPOLOGY: FULL INTEGRATION')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      N_NODE = TOPOLOGY_NODE_COUNT(TOPOLOGY)                             ! Set n_node to topology_node_count(topology).
      ALLOCATE(NODE_LOCAL(3,N_NODE))                                     ! Allocate memory for node_local(3,n_node).
      DO I = 1_I4, N_NODE                                                ! Loop i from 1 to n_node:
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES,                        ! Set node_index to find_node_index(model.nodes, model.elements.item(element).node_id(i)).
     &               MODEL%ELEMENTS%ITEM(ELEMENT)%NODE_ID(I))
        IF (NODE_INDEX .EQ. 0_I4) THEN                                   ! If node_index = 0:
          CALL SET_ERROR(STATUS, 'PREPARE_ELEMENT_MITC',                 ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                   'ELEMENT REFERENCES UNKNOWN NODE')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        NODE_LOCAL(:,I) = MATMUL(                                        ! Set node_local(:,i) to matmul( cache.frames.global_to_local(:,:,element), model.nodes.item(node_index).coor...
     &    CACHE%FRAMES%GLOBAL_TO_LOCAL(:,:,ELEMENT),
     &    MODEL%NODES%ITEM(NODE_INDEX)%COORDINATE-
     &    CACHE%FRAMES%ORIGIN(:,ELEMENT))
      END DO                                                             ! End of the loop.
      CALL MITC_PREPARE_ELEMENT(TOPOLOGY, NODE_LOCAL, MITC, STATUS)      ! Call mitc prepare element with topology, node_local, mitc, status.

      END SUBROUTINE PREPARE_ELEMENT_MITC                                ! End of the subroutine prepare element mitc.
      END MODULE MUL2_MODEL_CACHE                                        ! End of the module mul2 model cache.
