!=======================================================================
!  RECOVERY OF DISPLACEMENT, STRAIN AND STRESS AT ARBITRARY POINTS.
!
!  A POINT IS GIVEN BY AN ELEMENT, ONE SUB-ELEMENT OF ITS EXPANSION
!  MESH AND THE NATURAL COORDINATES OF BOTH (STRUCTURAL, EXPANSION).
!  THE FIELD IS COMPOSED WITH THE SAME BASIS RULE USED BY THE ELEMENT
!  MATRICES (MUL2_POINT_BASES), SO RECOVERY AND STIFFNESS SHARE ONE
!  IMPLEMENTATION OF THE KINEMATICS.
!
!  CONVENTIONS
!    STRAIN = [EXX, EYY, EZZ, GXZ, GYZ, GXY] (ENGINEERING SHEAR)
!    STRESS = [SXX, SYY, SZZ, SXZ, SYZ, SXY]
!    LOCAL = ELEMENT FRAME, GLOBAL = MODEL FRAME
!=======================================================================
      MODULE MUL2_RECOVERY                                               ! Module mul2 recovery begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       STATUS_IS_OK
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE,                      ! Use from module mul2 model cache: model cache type, prepare element mitc, element shear mode.
     &                            PREPARE_ELEMENT_MITC,
     &                            ELEMENT_SHEAR_MODE
      USE MUL2_ANALYSIS_INPUT, ONLY: SHEAR_MITC                          ! Use from module mul2 analysis input: shear mitc.
      USE MUL2_GENERAL_GEOMETRY, ONLY: IS_GENERAL_ELEMENT, GENERAL_MAP   ! Use from module mul2 general geometry: is general element, general map.
      USE MUL2_GENERAL_KERNEL, ONLY: GENERAL_CONTEXT_TYPE,               ! Use from module mul2 general kernel: general context type, general context setup, general point columns.
     &                               GENERAL_CONTEXT_SETUP,
     &                               GENERAL_POINT_COLUMNS
      USE MUL2_MITC, ONLY: MITC_DATA_TYPE, MITC_TIE_COLUMN               ! Use from module mul2 mitc: mitc data type, mitc tie column.
      USE MUL2_LOCAL_GRADIENTS, ONLY: LOCAL_SHAPE_GRADIENT               ! Use from module mul2 local gradients: local shape gradient.
      USE MUL2_LINEAR_KINEMATICS, ONLY: COMPOSE_PRODUCT_BASIS            ! Use from module mul2 linear kinematics: compose product basis.
      USE MUL2_NODES, ONLY: FIND_NODE_INDEX                              ! Use from module mul2 nodes: find node index.
      USE MUL2_KINEMATICS, ONLY: FIND_KINEMATIC_INDEX,                   ! Use from module mul2 kinematics: find kinematic index, expansion spec type, field p, field t, n solved fields.
     &                           EXPANSION_SPEC_TYPE, FIELD_P,
     &                           FIELD_T,
     &                           N_SOLVED_FIELDS
      USE MUL2_EXPANSION_MESHES, ONLY: FIND_EXPANSION_INDEX              ! Use from module mul2 expansion meshes: find expansion index.
      USE MUL2_LAMINATIONS, ONLY: FIND_LAMINATION_INDEX                  ! Use from module mul2 laminations: find lamination index.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NODE_COUNT,                    ! Use from module mul2 topologies: topology node count, topology natural dimension, topology t3, topology t6,...
     &     TOPOLOGY_NATURAL_DIMENSION, TOPOLOGY_T3, TOPOLOGY_T6,
     &     TOPOLOGY_T4, TOPOLOGY_T10, TOPOLOGY_FUNCTION_COUNT,
     &     TOPOLOGY_IS_HLE, TOPOLOGY_HQ_BASE
      USE MUL2_SHAPE_FUNCTIONS, ONLY: EVALUATE_SHAPE                     ! Use from module mul2 shape functions: evaluate shape.
      USE MUL2_HLE_MAP, ONLY: HLE_GEOMETRY_TYPE, HLE_GEOMETRY_SETUP,     ! Use from module mul2 hle map: hle geometry type, hle geometry setup, hle map evaluate.
     &                        HLE_MAP_EVALUATE
      USE MUL2_JACOBIANS, ONLY: EVALUATE_SQUARE_JACOBIAN                 ! Use from module mul2 jacobians: evaluate square jacobian.
      USE MUL2_DOF_LAYOUT, ONLY: GLOBAL_DOF                              ! Use from module mul2 dof layout: global dof.
      USE MUL2_POINT_BASES, ONLY: EVALUATE_FIELD_BASIS,                  ! Use from module mul2 point bases: evaluate field basis, evaluate expansion factor.
     &                            EVALUATE_EXPANSION_FACTOR
      USE MUL2_LINEAR_KINEMATICS, ONLY: BUILD_DISPLACEMENT_OPERATOR      ! Use from module mul2 linear kinematics: build displacement operator.
      USE MUL2_MATERIAL_ROTATIONS, ONLY:                                 ! Use from module mul2 material rotations: build engineering strain transform.
     &     BUILD_ENGINEERING_STRAIN_TRANSFORM

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!  GEOMETRY AND SHAPE DATA OF ONE (ELEMENT, SUB-ELEMENT) PAIR.
      TYPE, PUBLIC :: PLACE_TYPE                                         ! Definition of the derived type place type.
        INTEGER(I4) :: ELEMENT = 0_I4                                    ! Integer (int32): element = 0.
        INTEGER(I4) :: MESH = 0_I4                                       ! Integer (int32): mesh = 0.
        INTEGER(I4) :: SUB_ELEMENT = 0_I4                                ! Integer (int32): sub_element = 0.
        INTEGER(I4) :: STRUCTURAL_DIMENSION = 0_I4                       ! Integer (int32): structural_dimension = 0.
        INTEGER(I4) :: EXPANSION_DIMENSION = 0_I4                        ! Integer (int32): expansion_dimension = 0.
        INTEGER(I4) :: STRUCTURAL_TOPOLOGY = 0_I4                        ! Integer (int32): structural_topology = 0.
        INTEGER(I4) :: EXPANSION_TOPOLOGY = 0_I4                         ! Integer (int32): expansion_topology = 0.
        INTEGER(I4) :: STRUCTURAL_AXIS(3) = [1_I4,2_I4,3_I4]             ! Integer (int32): structural_axis(3) = [1, 2_i4, 3].
        INTEGER(I4) :: EXPANSION_AXIS(3) = [1_I4,2_I4,3_I4]              ! Integer (int32): expansion_axis(3) = [1, 2_i4, 3].
        REAL(R8), ALLOCATABLE :: NODE_GLOBAL(:,:)                        ! Allocatable real (real64): node_global(:,:).
        REAL(R8), ALLOCATABLE :: NODE_LOCAL(:,:)                         ! Allocatable real (real64): node_local(:,:).
        REAL(R8), ALLOCATABLE :: EXPANSION_NODE(:,:)                     ! Allocatable real (real64): expansion_node(:,:).
        REAL(R8), ALLOCATABLE :: SHAPE_STRUCTURAL(:)                     ! Allocatable real (real64): shape_structural(:).
        REAL(R8), ALLOCATABLE :: NATURAL_DERIVATIVE_S(:,:)               ! Allocatable real (real64): natural_derivative_s(:,:).
        REAL(R8), ALLOCATABLE :: GRADIENT_STRUCTURAL(:,:)                ! Allocatable real (real64): gradient_structural(:,:).
        REAL(R8), ALLOCATABLE :: SHAPE_EXPANSION(:)                      ! Allocatable real (real64): shape_expansion(:).
        REAL(R8), ALLOCATABLE :: NATURAL_DERIVATIVE_E(:,:)               ! Allocatable real (real64): natural_derivative_e(:,:).
        REAL(R8), ALLOCATABLE :: GRADIENT_EXPANSION(:,:)                 ! Allocatable real (real64): gradient_expansion(:,:).
        REAL(R8) :: EXPANSION_POINT_LOCAL(3) = 0.0_R8                    ! Real (real64): expansion_point_local(3) = 0.0.
!       HQ SUB-ELEMENT WITH CURVED SIDES: BLENDING-FUNCTION MAP.
        LOGICAL :: CURVED = .FALSE.                                      ! Logical: curved = false.
        TYPE(HLE_GEOMETRY_TYPE) :: HLE_MAP                               ! Of type hle_geometry_type: hle_map.
        REAL(R8) :: MAP_DX(2,2) = 0.0_R8                                 ! Real (real64): map_dx(2,2) = 0.0.
        REAL(R8) :: POINT_GLOBAL(3) = 0.0_R8                             ! Real (real64): point_global(3) = 0.0.
        REAL(R8) :: NATURAL_S(3) = 0.0_R8                                ! Real (real64): natural_s(3) = 0.0.
        TYPE(MITC_DATA_TYPE) :: MITC                                     ! Of type mitc_data_type: mitc.
!       CURVED BEAM / SHELL (MUL2_GENERAL_KERNEL): GEOMETRY AND TYING.
        LOGICAL :: GENERAL = .FALSE.                                     ! Logical: general = false.
        TYPE(GENERAL_CONTEXT_TYPE) :: GCTX                               ! Of type general_context_type: gctx.
      END TYPE PLACE_TYPE                                                ! End of the type definition place type.

      TYPE, PUBLIC :: POINT_STATE_TYPE                                   ! Definition of the derived type point state type.
        INTEGER(I4) :: ELEMENT = 0_I4                                    ! Integer (int32): element = 0.
        INTEGER(I4) :: SUB_ELEMENT = 0_I4                                ! Integer (int32): sub_element = 0.
        INTEGER(I4) :: ELEMENT_DIMENSION = 0_I4                          ! Integer (int32): element_dimension = 0.
        INTEGER(I4) :: LAMINATION_ID = 0_I4                              ! Integer (int32): lamination_id = 0.
        INTEGER(I4) :: MATERIAL_ID = 0_I4                                ! Integer (int32): material_id = 0.
        REAL(R8) :: COORDINATE(3) = 0.0_R8                               ! Real (real64): coordinate(3) = 0.0.
        REAL(R8) :: DISPLACEMENT(3) = 0.0_R8                             ! Real (real64): displacement(3) = 0.0.
        REAL(R8) :: STRAIN_LOCAL(6) = 0.0_R8                             ! Real (real64): strain_local(6) = 0.0.
        REAL(R8) :: STRAIN_GLOBAL(6) = 0.0_R8                            ! Real (real64): strain_global(6) = 0.0.
        REAL(R8) :: STRESS_LOCAL(6) = 0.0_R8                             ! Real (real64): stress_local(6) = 0.0.
        REAL(R8) :: STRESS_GLOBAL(6) = 0.0_R8                            ! Real (real64): stress_global(6) = 0.0.
!       ELECTRIC FIELDS (PIEZOELECTRIC MODELS): POTENTIAL, FIELD
!       E = -GRAD PHI AND DISPLACEMENT D = E_PZ S - EPS GRAD PHI.
        REAL(R8) :: POTENTIAL = 0.0_R8                                   ! Real (real64): potential = 0.0.
        REAL(R8) :: ELECTRIC_FIELD_LOCAL(3) = 0.0_R8                     ! Real (real64): electric_field_local(3) = 0.0.
        REAL(R8) :: ELECTRIC_FIELD_GLOBAL(3) = 0.0_R8                    ! Real (real64): electric_field_global(3) = 0.0.
        REAL(R8) :: ELECTRIC_DISPLACEMENT_LOCAL(3) = 0.0_R8              ! Real (real64): electric_displacement_local(3) = 0.0.
        REAL(R8) :: ELECTRIC_DISPLACEMENT_GLOBAL(3) = 0.0_R8             ! Real (real64): electric_displacement_global(3) = 0.0.
!       THERMAL FIELDS: TEMPERATURE AND HEAT FLUX Q = -K GRAD T.
        REAL(R8) :: TEMPERATURE = 0.0_R8                                 ! Real (real64): temperature = 0.0.
        REAL(R8) :: HEAT_FLUX_LOCAL(3) = 0.0_R8                          ! Real (real64): heat_flux_local(3) = 0.0.
        REAL(R8) :: HEAT_FLUX_GLOBAL(3) = 0.0_R8                         ! Real (real64): heat_flux_global(3) = 0.0.
!       FRAME OF THE POINT (GLOBAL_TO_LOCAL): THE ONE OF THE ELEMENT, OR
!       THE ONE OF THE POINT FOR A CURVED BEAM / SHELL.
        REAL(R8) :: FRAME(3,3) = RESHAPE([1.0_R8,0.0_R8,0.0_R8,          ! Real (real64): frame(3,3) = reshape([1.0,0.0,0.0, 0.0,1.0,0.0,0.0,0.0,1.0], [3,3]).
     &    0.0_R8,1.0_R8,0.0_R8,0.0_R8,0.0_R8,1.0_R8], [3,3])
      END TYPE POINT_STATE_TYPE                                          ! End of the type definition point state type.

      PUBLIC :: PLACE_SETUP                                              ! Export: place setup.
      PUBLIC :: PLACE_EVALUATE                                           ! Export: place evaluate.
      PUBLIC :: STATE_FROM_PLACE                                         ! Export: state from place.
      PUBLIC :: DISPLACEMENT_FROM_PLACE                                  ! Export: displacement from place.
      PUBLIC :: LOCATE_POINT                                             ! Export: locate point.

      CONTAINS                                                           ! The procedures of the module follow.

!  LOAD THE COORDINATES OF THE NODES OF ONE ELEMENT AND OF ONE
!  EXPANSION SUB-ELEMENT.
      SUBROUTINE PLACE_SETUP(MODEL, CACHE, ELEMENT, SUB_ELEMENT,         ! Subroutine place setup takes model, cache, element, sub element, place, status.
     &                       PLACE, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      INTEGER(I4), INTENT(IN) :: SUB_ELEMENT                             ! Input integer (int32): sub_element.
      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: N_S                                                 ! Integer (int32): n_s.
      INTEGER(I4) :: N_E                                                 ! Integer (int32): n_e.
      INTEGER(I4) :: N_F                                                 ! Integer (int32): n_f.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      PLACE%ELEMENT = ELEMENT                                            ! Set place.element to element.
      PLACE%SUB_ELEMENT = SUB_ELEMENT                                    ! Set place.sub_element to sub_element.
      PLACE%STRUCTURAL_TOPOLOGY = MODEL%ELEMENTS%ITEM(ELEMENT)%TOPOLOGY  ! Set place.structural_topology to model.elements.item(element).topology.
      PLACE%STRUCTURAL_DIMENSION = TOPOLOGY_NATURAL_DIMENSION(           ! Set place.structural_dimension to topology_natural_dimension( place.structural_topology).
     &                             PLACE%STRUCTURAL_TOPOLOGY)
      PLACE%MESH = FIND_EXPANSION_INDEX(MODEL%EXPANSIONS,                ! Set place.mesh to find_expansion_index(model.expansions, model.elements.item(element).expansion_id).
     &             MODEL%ELEMENTS%ITEM(ELEMENT)%EXPANSION_ID)
      IF (PLACE%MESH .EQ. 0_I4) THEN                                     ! If place.mesh = 0:
        CALL SET_ERROR(STATUS, 'PLACE_SETUP',                            ! Record an error in status: 'ELEMENT EXPANSION IS MISSING'.
     &                 'ELEMENT EXPANSION IS MISSING')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      PLACE%EXPANSION_TOPOLOGY = MODEL%EXPANSIONS%ITEM(PLACE%MESH)%      ! Set place.expansion_topology to model.expansions.item(place.mesh). element(sub_element).topology.
     &                           ELEMENT(SUB_ELEMENT)%TOPOLOGY
      PLACE%EXPANSION_DIMENSION = TOPOLOGY_NATURAL_DIMENSION(            ! Set place.expansion_dimension to topology_natural_dimension( place.expansion_topology).
     &                            PLACE%EXPANSION_TOPOLOGY)
      N_S = TOPOLOGY_NODE_COUNT(PLACE%STRUCTURAL_TOPOLOGY)               ! Set n_s to topology_node_count(place.structural_topology).
      N_E = TOPOLOGY_NODE_COUNT(PLACE%EXPANSION_TOPOLOGY)                ! Set n_e to topology_node_count(place.expansion_topology).
      N_F = TOPOLOGY_FUNCTION_COUNT(PLACE%EXPANSION_TOPOLOGY)            ! Set n_f to topology_function_count(place.expansion_topology).

      PLACE%STRUCTURAL_AXIS = [1_I4,2_I4,3_I4]                           ! Set place.structural_axis to [1,2,3].
      IF (PLACE%STRUCTURAL_DIMENSION .EQ. 1_I4)                          ! If place.structural_dimension = 1, set place.structural_axis(1) to 2.
     &  PLACE%STRUCTURAL_AXIS(1) = 2_I4
      PLACE%EXPANSION_AXIS = CACHE%EXPANSION_GEOMETRY%                   ! Set place.expansion_axis to cache.expansion_geometry. active_axis(:,place.mesh).
     &                       ACTIVE_AXIS(:,PLACE%MESH)

      CALL FREE_PLACE(PLACE)                                             ! Call free place with place.
      ALLOCATE(PLACE%NODE_GLOBAL(3,N_S))                                 ! Allocate memory for place.node_global(3,n_s).
      ALLOCATE(PLACE%NODE_LOCAL(3,N_S))                                  ! Allocate memory for place.node_local(3,n_s).
      ALLOCATE(PLACE%EXPANSION_NODE(3,N_E))                              ! Allocate memory for place.expansion_node(3,n_e).
      ALLOCATE(PLACE%SHAPE_STRUCTURAL(N_S))                              ! Allocate memory for place.shape_structural(n_s).
      ALLOCATE(PLACE%NATURAL_DERIVATIVE_S(N_S,3))                        ! Allocate memory for place.natural_derivative_s(n_s,3).
      ALLOCATE(PLACE%GRADIENT_STRUCTURAL(3,N_S))                         ! Allocate memory for place.gradient_structural(3,n_s).
      ALLOCATE(PLACE%SHAPE_EXPANSION(N_F))                               ! Allocate memory for place.shape_expansion(n_f).
      ALLOCATE(PLACE%NATURAL_DERIVATIVE_E(N_F,3))                        ! Allocate memory for place.natural_derivative_e(n_f,3).
      ALLOCATE(PLACE%GRADIENT_EXPANSION(3,N_F))                          ! Allocate memory for place.gradient_expansion(3,n_f).

      DO I = 1_I4, N_S                                                   ! Loop i from 1 to n_s:
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES,                        ! Set node_index to find_node_index(model.nodes, model.elements.item(element).node_id(i)).
     &               MODEL%ELEMENTS%ITEM(ELEMENT)%NODE_ID(I))
        IF (NODE_INDEX .EQ. 0_I4) THEN                                   ! If node_index = 0:
          CALL SET_ERROR(STATUS, 'PLACE_SETUP',                          ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                   'ELEMENT REFERENCES UNKNOWN NODE')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        PLACE%NODE_GLOBAL(:,I) = MODEL%NODES%ITEM(NODE_INDEX)%           ! Set place.node_global(:,i) to model.nodes.item(node_index). coordinate.
     &                           COORDINATE
        PLACE%NODE_LOCAL(:,I) = MATMUL(                                  ! Set place.node_local(:,i) to matmul( cache.frames.global_to_local(:,:,element), place.node_global(:,i)-cach...
     &    CACHE%FRAMES%GLOBAL_TO_LOCAL(:,:,ELEMENT),
     &    PLACE%NODE_GLOBAL(:,I)-CACHE%FRAMES%ORIGIN(:,ELEMENT))
      END DO                                                             ! End of the loop.
      DO I = 1_I4, N_E                                                   ! Loop i from 1 to n_e:
        PLACE%EXPANSION_NODE(:,I) = 0.0_R8                               ! Set place.expansion_node(:,i) to zero.
        DO J = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM(PLACE%MESH)%NODE)        ! Loop j from 1 to size(model.expansions.item(place.mesh).node):
          IF (MODEL%EXPANSIONS%ITEM(PLACE%MESH)%NODE(J)%ID .EQ.          ! If model.expansions.item(place.mesh).node(j).id = model.expansions.item(place.mesh).element(sub_element). n...
     &        MODEL%EXPANSIONS%ITEM(PLACE%MESH)%ELEMENT(SUB_ELEMENT)%
     &        NODE_ID(I)) THEN
            PLACE%EXPANSION_NODE(:,I) = MODEL%EXPANSIONS%                ! Set place.expansion_node(:,i) to model.expansions. item(place.mesh).node(j).coordinate.
     &        ITEM(PLACE%MESH)%NODE(J)%COORDINATE
            EXIT                                                         ! Leave the loop.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      PLACE%CURVED = .FALSE.                                             ! Set the flag place.curved to false.
      IF (TOPOLOGY_IS_HLE(PLACE%EXPANSION_TOPOLOGY) .AND.                ! If topology_is_hle(place.expansion_topology) and place.expansion_topology > topology_hq_base:
     &    PLACE%EXPANSION_TOPOLOGY .GT. TOPOLOGY_HQ_BASE) THEN
        IF (ANY(MODEL%EXPANSIONS%ITEM(PLACE%MESH)%ELEMENT(               ! If any(model.expansions.item(place.mesh).element( sub_element).mid_node_id /= 0):
     &      SUB_ELEMENT)%MID_NODE_ID .NE. 0_I8)) THEN
          CALL SETUP_CURVED_PLACE(MODEL, PLACE)                          ! Call setup curved place with model, place.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      PLACE%GENERAL = IS_GENERAL_ELEMENT(CACHE%FRAMES, ELEMENT)          ! Set place.general to is_general_element(cache.frames, element).
      IF (PLACE%GENERAL) THEN                                            ! If place.general:
        CALL GENERAL_CONTEXT_SETUP(PLACE%GCTX, ELEMENT, MODEL%NODES,     ! Call general context setup with place.gctx, element, model.nodes, model.elements, model.expansions, cache.e...
     &       MODEL%ELEMENTS, MODEL%EXPANSIONS, CACHE%EXPANSION_GEOMETRY,
     &       CACHE%FRAMES, ELEMENT_SHEAR_MODE(MODEL,ELEMENT) .EQ.
     &       SHEAR_MITC, STATUS)
        PLACE%MITC%ACTIVE = .FALSE.                                      ! Set the flag place.mitc.active to false.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL PREPARE_ELEMENT_MITC(MODEL, CACHE, ELEMENT, PLACE%MITC,       ! Call prepare element mitc with model, cache, element, place.mitc, status.
     &                          STATUS)

      END SUBROUTINE PLACE_SETUP                                         ! End of the subroutine place setup.

!  GEOMETRY OF A HQ SUB-ELEMENT WITH CURVED SIDES.
      SUBROUTINE SETUP_CURVED_PLACE(MODEL, PLACE)                        ! Subroutine setup curved place takes model, place.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.
      REAL(R8) :: VERTEX_2D(2,4)                                         ! Real (real64): vertex_2d(2,4).
      REAL(R8) :: MID_2D(2,4)                                            ! Real (real64): mid_2d(2,4).
      LOGICAL :: HAS_MID(4)                                              ! Logical: has_mid(4).
      INTEGER(I8) :: MID_ID                                              ! Integer (int64): mid_id.
      INTEGER(I4) :: AX1                                                 ! Integer (int32): ax1.
      INTEGER(I4) :: AX2                                                 ! Integer (int32): ax2.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      AX1 = PLACE%EXPANSION_AXIS(1)                                      ! Set ax1 to place.expansion_axis(1).
      AX2 = PLACE%EXPANSION_AXIS(2)                                      ! Set ax2 to place.expansion_axis(2).
      HAS_MID = .FALSE.                                                  ! Set the flag has_mid to false.
      MID_2D = 0.0_R8                                                    ! Set mid_2d to zero.
      DO K = 1_I4, 4_I4                                                  ! Loop k from 1 to 4:
        VERTEX_2D(1,K) = PLACE%EXPANSION_NODE(AX1,K)                     ! Set vertex_2d(1,k) to place.expansion_node(ax1,k).
        VERTEX_2D(2,K) = PLACE%EXPANSION_NODE(AX2,K)                     ! Set vertex_2d(2,k) to place.expansion_node(ax2,k).
        MID_ID = MODEL%EXPANSIONS%ITEM(PLACE%MESH)%                      ! Set mid_id to model.expansions.item(place.mesh). element(place.sub_element).mid_node_id(k).
     &           ELEMENT(PLACE%SUB_ELEMENT)%MID_NODE_ID(K)
        IF (MID_ID .EQ. 0_I8) CYCLE                                      ! If mid_id = 0, skip to the next iteration.
        ASSOCIATE(NODE => MODEL%EXPANSIONS%ITEM(PLACE%MESH)%NODE)        ! Use short names (node) for longer expressions:
          DO J = 1_I4, SIZE(NODE)                                        ! Loop j from 1 to size(node):
            IF (NODE(J)%ID .NE. MID_ID) CYCLE                            ! If node(j).id /= mid_id, skip to the next iteration.
            MID_2D(1,K) = NODE(J)%COORDINATE(AX1)                        ! Set mid_2d(1,k) to node(j).coordinate(ax1).
            MID_2D(2,K) = NODE(J)%COORDINATE(AX2)                        ! Set mid_2d(2,k) to node(j).coordinate(ax2).
            HAS_MID(K) = .TRUE.                                          ! Set the flag has_mid(k) to true.
            EXIT                                                         ! Leave the loop.
          END DO                                                         ! End of the loop.
        END ASSOCIATE                                                    ! End of the shorthand names.
      END DO                                                             ! End of the loop.
      CALL HLE_GEOMETRY_SETUP(VERTEX_2D, MID_2D, HAS_MID,                ! Call hle geometry setup with vertex_2d, mid_2d, has_mid, place.hle_map.
     &                        PLACE%HLE_MAP)
      PLACE%CURVED = PLACE%HLE_MAP%ANY_CURVED                            ! Set place.curved to place.hle_map.any_curved.

      END SUBROUTINE SETUP_CURVED_PLACE                                  ! End of the subroutine setup curved place.

      SUBROUTINE FREE_PLACE(PLACE)                                       ! Subroutine free place takes place.

      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.

      IF (ALLOCATED(PLACE%NODE_GLOBAL)) DEALLOCATE(PLACE%NODE_GLOBAL)    ! If allocated(place.node_global), free the memory of place.node_global.
      IF (ALLOCATED(PLACE%NODE_LOCAL)) DEALLOCATE(PLACE%NODE_LOCAL)      ! If allocated(place.node_local), free the memory of place.node_local.
      IF (ALLOCATED(PLACE%EXPANSION_NODE))                               ! If allocated(place.expansion_node), free the memory of place.expansion_node.
     &  DEALLOCATE(PLACE%EXPANSION_NODE)
      IF (ALLOCATED(PLACE%SHAPE_STRUCTURAL))                             ! If allocated(place.shape_structural), free the memory of place.shape_structural.
     &  DEALLOCATE(PLACE%SHAPE_STRUCTURAL)
      IF (ALLOCATED(PLACE%NATURAL_DERIVATIVE_S))                         ! If allocated(place.natural_derivative_s), free the memory of place.natural_derivative_s.
     &  DEALLOCATE(PLACE%NATURAL_DERIVATIVE_S)
      IF (ALLOCATED(PLACE%GRADIENT_STRUCTURAL))                          ! If allocated(place.gradient_structural), free the memory of place.gradient_structural.
     &  DEALLOCATE(PLACE%GRADIENT_STRUCTURAL)
      IF (ALLOCATED(PLACE%SHAPE_EXPANSION))                              ! If allocated(place.shape_expansion), free the memory of place.shape_expansion.
     &  DEALLOCATE(PLACE%SHAPE_EXPANSION)
      IF (ALLOCATED(PLACE%NATURAL_DERIVATIVE_E))                         ! If allocated(place.natural_derivative_e), free the memory of place.natural_derivative_e.
     &  DEALLOCATE(PLACE%NATURAL_DERIVATIVE_E)
      IF (ALLOCATED(PLACE%GRADIENT_EXPANSION))                           ! If allocated(place.gradient_expansion), free the memory of place.gradient_expansion.
     &  DEALLOCATE(PLACE%GRADIENT_EXPANSION)

      END SUBROUTINE FREE_PLACE                                          ! End of the subroutine free place.

!  SHAPES, LOCAL GRADIENTS AND PHYSICAL POSITION AT A NATURAL POINT.
!  WITH_GRADIENT = .FALSE. SKIPS THE JACOBIAN INVERSIONS (NEWTON).
      SUBROUTINE PLACE_EVALUATE(PLACE, MODEL, CACHE, NATURAL_S,          ! Subroutine place evaluate takes place, model, cache, natural s, natural e, with gradient, status.
     &     NATURAL_E, WITH_GRADIENT, STATUS)

      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.
      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      REAL(R8), INTENT(IN) :: NATURAL_S(3)                               ! Input real (real64): natural_s(3).
      REAL(R8), INTENT(IN) :: NATURAL_E(3)                               ! Input real (real64): natural_e(3).
      LOGICAL, INTENT(IN) :: WITH_GRADIENT                               ! Input logical: with_gradient.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: CENTER(3)                                              ! Real (real64): center(3).
      REAL(R8) :: MAP_X(2)                                               ! Real (real64): map_x(2).
      REAL(R8) :: GENERAL_G(3,3)                                         ! Real (real64): general_g(3,3).
      INTEGER(I4) :: N_S                                                 ! Integer (int32): n_s.
      INTEGER(I4) :: N_E                                                 ! Integer (int32): n_e.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N_S = SIZE(PLACE%SHAPE_STRUCTURAL)                                 ! Set n_s to the size of place.shape_structural.
      N_E = SIZE(PLACE%EXPANSION_NODE,2)                                 ! Set n_e to size(place.expansion_node,2).
      PLACE%NATURAL_S = NATURAL_S                                        ! Set place.natural_s to natural_s.
      CALL EVALUATE_SHAPE(PLACE%STRUCTURAL_TOPOLOGY, NATURAL_S,          ! Call evaluate shape with place.structural_topology, natural_s, place.shape_structural, place.natural_deriva...
     &     PLACE%SHAPE_STRUCTURAL, PLACE%NATURAL_DERIVATIVE_S, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL EVALUATE_SHAPE(PLACE%EXPANSION_TOPOLOGY, NATURAL_E,           ! Call evaluate shape with place.expansion_topology, natural_e, place.shape_expansion, place.natural_derivati...
     &     PLACE%SHAPE_EXPANSION, PLACE%NATURAL_DERIVATIVE_E, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CENTER = 0.0_R8                                                    ! Set center to zero.
      DO I = 1_I4, N_S                                                   ! Loop i from 1 to n_s:
        CENTER = CENTER + PLACE%SHAPE_STRUCTURAL(I)*                     ! Add place.shape_structural(i)* place.node_global(:,i) to center.
     &           PLACE%NODE_GLOBAL(:,I)
      END DO                                                             ! End of the loop.
      PLACE%EXPANSION_POINT_LOCAL = 0.0_R8                               ! Set place.expansion_point_local to zero.
      DO I = 1_I4, N_E                                                   ! Loop i from 1 to n_e:
        PLACE%EXPANSION_POINT_LOCAL = PLACE%EXPANSION_POINT_LOCAL +      ! Add place.shape_expansion(i)*place.expansion_node(:,i) to place.expansion_point_local.
     &    PLACE%SHAPE_EXPANSION(I)*PLACE%EXPANSION_NODE(:,I)
      END DO                                                             ! End of the loop.
      IF (PLACE%CURVED) THEN                                             ! If place.curved:
        CALL HLE_MAP_EVALUATE(PLACE%HLE_MAP, NATURAL_E(1),               ! Call hle map evaluate with place.hle_map, natural_e(1), natural_e(2), map_x, place.map_dx.
     &                        NATURAL_E(2), MAP_X, PLACE%MAP_DX)
        PLACE%EXPANSION_POINT_LOCAL(PLACE%EXPANSION_AXIS(1)) =           ! Set place.expansion_point_local(place.expansion_axis(1)) to map_x(1).
     &    MAP_X(1)
        PLACE%EXPANSION_POINT_LOCAL(PLACE%EXPANSION_AXIS(2)) =           ! Set place.expansion_point_local(place.expansion_axis(2)) to map_x(2).
     &    MAP_X(2)
      END IF                                                             ! End of the IF block.
      IF (PLACE%GENERAL) THEN                                            ! If place.general:
        CALL GENERAL_MAP(PLACE%STRUCTURAL_DIMENSION, N_S,                ! Call general map with place.structural_dimension, n_s, place.gctx.coord, place.gctx.triad, place.shape_stru...
     &       PLACE%GCTX%COORD, PLACE%GCTX%TRIAD,
     &       PLACE%SHAPE_STRUCTURAL, PLACE%NATURAL_DERIVATIVE_S,
     &       PLACE%EXPANSION_POINT_LOCAL, PLACE%GCTX%AXIS,
     &       PLACE%POINT_GLOBAL, GENERAL_G)
      ELSE                                                               ! Otherwise:
        PLACE%POINT_GLOBAL = CENTER + MATMUL(                            ! Set place.point_global to center + matmul( cache.frames.local_to_global(:,:,place.element), place.expansion...
     &    CACHE%FRAMES%LOCAL_TO_GLOBAL(:,:,PLACE%ELEMENT),
     &    PLACE%EXPANSION_POINT_LOCAL)
      END IF                                                             ! End of the IF block.
      IF (.NOT. WITH_GRADIENT) RETURN                                    ! If not with_gradient, return to the caller.

      IF (PLACE%GENERAL) THEN                                            ! If place.general:
!       THE STRUCTURAL GRADIENT OF A CURVED ELEMENT DEPENDS ON THE
!       EXPANSION POINT: THE STATE USES MUL2_GENERAL_KERNEL.
        PLACE%GRADIENT_STRUCTURAL = 0.0_R8                               ! Set place.gradient_structural to zero.
      ELSE                                                               ! Otherwise:
        CALL LOCAL_SHAPE_GRADIENT(PLACE%STRUCTURAL_DIMENSION,            ! Call local shape gradient with place.structural_dimension, place.structural_axis, place.node_local, place.n...
     &       PLACE%STRUCTURAL_AXIS, PLACE%NODE_LOCAL,
     &       PLACE%NATURAL_DERIVATIVE_S, PLACE%GRADIENT_STRUCTURAL,
     &       STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END IF                                                             ! End of the IF block.
      IF (PLACE%CURVED) THEN                                             ! If place.curved:
        CALL CURVED_GRADIENT(PLACE, STATUS)                              ! Call curved gradient with place, status.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL LOCAL_SHAPE_GRADIENT(PLACE%EXPANSION_DIMENSION,               ! Call local shape gradient with place.expansion_dimension, place.expansion_axis, place.expansion_node, place...
     &     PLACE%EXPANSION_AXIS, PLACE%EXPANSION_NODE,
     &     PLACE%NATURAL_DERIVATIVE_E, PLACE%GRADIENT_EXPANSION,
     &     STATUS)

      END SUBROUTINE PLACE_EVALUATE                                      ! End of the subroutine place evaluate.

!  PHYSICAL GRADIENTS OF THE EXPANSION FUNCTIONS WITH THE BLENDING MAP.
      SUBROUTINE CURVED_GRADIENT(PLACE, STATUS)                          ! Subroutine curved gradient takes place, status.

      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: PSEUDO_X(2,2)                                          ! Real (real64): pseudo_x(2,2).
      REAL(R8) :: PSEUDO_DN(2,2)                                         ! Real (real64): pseudo_dn(2,2).
      REAL(R8) :: PSEUDO_PHYSICAL(2,2)                                   ! Real (real64): pseudo_physical(2,2).
      REAL(R8) :: JACOBIAN(2,2)                                          ! Real (real64): jacobian(2,2).
      REAL(R8) :: INVERSE(2,2)                                           ! Real (real64): inverse(2,2).
      REAL(R8) :: DETERMINANT                                            ! Real (real64): determinant.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: B                                                   ! Integer (int32): b.

      PSEUDO_X(1,:) = PLACE%MAP_DX(:,1)                                  ! Set pseudo_x(1,:) to place.map_dx(:,1).
      PSEUDO_X(2,:) = PLACE%MAP_DX(:,2)                                  ! Set pseudo_x(2,:) to place.map_dx(:,2).
      PSEUDO_DN = RESHAPE([1.0_R8,0.0_R8,0.0_R8,1.0_R8],[2,2])           ! Set pseudo_dn to reshape([1.0,0.0,0.0,1.0],[2,2]).
      CALL EVALUATE_SQUARE_JACOBIAN(PSEUDO_X, PSEUDO_DN, 2_I4,           ! Call evaluate square jacobian with pseudo_x, pseudo_dn, 2, jacobian, determinant, inverse, pseudo_physical,...
     &     JACOBIAN, DETERMINANT, INVERSE, PSEUDO_PHYSICAL, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      PLACE%GRADIENT_EXPANSION = 0.0_R8                                  ! Set place.gradient_expansion to zero.
      DO I = 1_I4, SIZE(PLACE%SHAPE_EXPANSION)                           ! Loop i from 1 to size(place.shape_expansion):
        DO B = 1_I4, 2_I4                                                ! Loop b from 1 to 2:
          PLACE%GRADIENT_EXPANSION(PLACE%EXPANSION_AXIS(B),I) =          ! Set place.gradient_expansion(place.expansion_axis(b),i) to inverse(b,1)*place.natural_derivative_e(i,1) + i...
     &      INVERSE(B,1)*PLACE%NATURAL_DERIVATIVE_E(I,1) +
     &      INVERSE(B,2)*PLACE%NATURAL_DERIVATIVE_E(I,2)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE CURVED_GRADIENT                                     ! End of the subroutine curved gradient.

!  DISPLACEMENT, STRAIN AND STRESS AT THE POINT LAST EVALUATED BY
!  PLACE_EVALUATE(..., WITH_GRADIENT = .TRUE.).
      SUBROUTINE STATE_FROM_PLACE(MODEL, CACHE, PLACE, SOLUTION,         ! Subroutine state from place takes model, cache, place, solution, state, status.
     &                            STATE, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(PLACE_TYPE), INTENT(IN) :: PLACE                              ! Input of type place_type: place.
      REAL(R8), INTENT(IN) :: SOLUTION(:)                                ! Input real (real64): solution(:).
      TYPE(POINT_STATE_TYPE), INTENT(OUT) :: STATE                       ! Output of type point_state_type: state.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                  ! Of type expansion_spec_type: spec.
      REAL(R8) :: B_OPERATOR(6,3)                                        ! Real (real64): b_operator(6,3).
      REAL(R8) :: B_COLUMN(6)                                            ! Real (real64): b_column(6).
      REAL(R8) :: GRADIENT(3)                                            ! Real (real64): gradient(3).
      REAL(R8) :: FACTOR                                                 ! Real (real64): factor.
      REAL(R8) :: FACTOR_GRADIENT(3)                                     ! Real (real64): factor_gradient(3).
      REAL(R8) :: VALUE                                                  ! Real (real64): value.
      REAL(R8) :: COEFFICIENT                                            ! Real (real64): coefficient.
      REAL(R8) :: ROTATION(3,3)                                          ! Real (real64): rotation(3,3).
      REAL(R8) :: TRANSFORM(6,6)                                         ! Real (real64): transform(6,6).
      REAL(R8) :: GRAD_POTENTIAL(3)                                      ! Real (real64): grad_potential(3).
      REAL(R8) :: GRAD_TEMPERATURE(3)                                    ! Real (real64): grad_temperature(3).
      INTEGER(I8) :: DOF                                                 ! Integer (int64): dof.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: LAMINATION_INDEX                                    ! Integer (int32): lamination_index.
      INTEGER(I4) :: LOCAL_NODE                                          ! Integer (int32): local_node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      STATE%ELEMENT = PLACE%ELEMENT                                      ! Set state.element to place.element.
      STATE%SUB_ELEMENT = PLACE%SUB_ELEMENT                              ! Set state.sub_element to place.sub_element.
      STATE%COORDINATE = PLACE%POINT_GLOBAL                              ! Set state.coordinate to place.point_global.
      STATE%DISPLACEMENT = 0.0_R8                                        ! Set state.displacement to zero.
      STATE%STRAIN_LOCAL = 0.0_R8                                        ! Set state.strain_local to zero.
      GRAD_POTENTIAL = 0.0_R8                                            ! Set grad_potential to zero.
      GRAD_TEMPERATURE = 0.0_R8                                          ! Set grad_temperature to zero.
      STATE%TEMPERATURE = 0.0_R8                                         ! Set state.temperature to zero.
      STATE%ELEMENT_DIMENSION = PLACE%STRUCTURAL_DIMENSION               ! Set state.element_dimension to place.structural_dimension.
      ROTATION = CACHE%FRAMES%GLOBAL_TO_LOCAL(:,:,PLACE%ELEMENT)         ! Set rotation to cache.frames.global_to_local(:,:,place.element).

      IF (PLACE%GENERAL) THEN                                            ! If place.general:
        CALL GENERAL_STATE_PART(MODEL, CACHE, PLACE, SOLUTION, STATE,    ! Call general state part with model, cache, place, solution, state, rotation, grad_potential, grad_temperatu...
     &       ROTATION, GRAD_POTENTIAL, GRAD_TEMPERATURE, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END IF                                                             ! End of the IF block.
      DO LOCAL_NODE = 1_I4, SIZE(PLACE%SHAPE_STRUCTURAL)                 ! Loop local_node from 1 to size(place.shape_structural):
        IF (PLACE%GENERAL) EXIT                                          ! If place.general, leave the loop.
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES, MODEL%ELEMENTS%        ! Set node_index to find_node_index(model.nodes, model.elements. item(place.element).node_id(local_node)).
     &               ITEM(PLACE%ELEMENT)%NODE_ID(LOCAL_NODE))
        KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(MODEL%KINEMATICS,         ! Set kinematic_index to find_kinematic_index(model.kinematics, model.nodes.item(node_index).kinematic_id).
     &                    MODEL%NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
        DO FIELD = 1_I4, N_SOLVED_FIELDS                                 ! Loop field from 1 to n_solved_fields:
          SPEC = MODEL%KINEMATICS%ITEM(KINEMATIC_INDEX)%FIELD(FIELD)     ! Set spec to model.kinematics.item(kinematic_index).field(field).
          DO TERM = 1_I4, CACHE%DOF_LAYOUT%TERM_COUNT(NODE_INDEX,        ! Loop term from 1 to cache.dof_layout.term_count(node_index, field):
     &                                                FIELD)
            DOF = GLOBAL_DOF(CACHE%DOF_LAYOUT, NODE_INDEX, FIELD,        ! Set dof to global_dof(cache.dof_layout, node_index, field, term).
     &                       TERM)
            COEFFICIENT = SOLUTION(DOF)                                  ! Set coefficient to solution(dof).
            CALL EVALUATE_EXPANSION_FACTOR(SPEC, TERM,                   ! Call evaluate expansion factor with spec, term, model.expansions.item(place.mesh), place.sub_element, place...
     &           MODEL%EXPANSIONS%ITEM(PLACE%MESH),
     &           PLACE%SUB_ELEMENT, PLACE%EXPANSION_DIMENSION,
     &           PLACE%EXPANSION_AXIS(1:2),
     &           PLACE%EXPANSION_POINT_LOCAL,
     &           PLACE%SHAPE_EXPANSION, PLACE%GRADIENT_EXPANSION,
     &           FACTOR, FACTOR_GRADIENT, STATUS)
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            CALL COMPOSE_PRODUCT_BASIS(                                  ! Call compose product basis with place.shape_structural(local_node), place.gradient_structural(:,local_node)...
     &           PLACE%SHAPE_STRUCTURAL(LOCAL_NODE),
     &           PLACE%GRADIENT_STRUCTURAL(:,LOCAL_NODE),
     &           FACTOR, FACTOR_GRADIENT, VALUE, GRADIENT)
            IF (FIELD .EQ. FIELD_P) THEN                                 ! If field = field_p:
              STATE%POTENTIAL = STATE%POTENTIAL + COEFFICIENT*VALUE      ! Add coefficient*value to state.potential.
              GRAD_POTENTIAL = GRAD_POTENTIAL + COEFFICIENT*GRADIENT     ! Add coefficient*gradient to grad_potential.
              CYCLE                                                      ! Skip to the next iteration.
            END IF                                                       ! End of the IF block.
            IF (FIELD .EQ. FIELD_T) THEN                                 ! If field = field_t:
              STATE%TEMPERATURE = STATE%TEMPERATURE + COEFFICIENT*VALUE  ! Add coefficient*value to state.temperature.
              GRAD_TEMPERATURE = GRAD_TEMPERATURE +                      ! Add coefficient*gradient to grad_temperature.
     &                           COEFFICIENT*GRADIENT
              CYCLE                                                      ! Skip to the next iteration.
            END IF                                                       ! End of the IF block.
            IF (FIELD .GT. 3_I4) CYCLE                                   ! If field > 3, skip to the next iteration.
            STATE%DISPLACEMENT(FIELD) = STATE%DISPLACEMENT(FIELD) +      ! Add coefficient*value to state.displacement(field).
     &                                  COEFFICIENT*VALUE
            CALL BUILD_DISPLACEMENT_OPERATOR(GRADIENT, B_OPERATOR,       ! Call build displacement operator with gradient, b_operator, status.
     &                                       STATUS)
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            B_COLUMN = MATMUL(B_OPERATOR,ROTATION(:,FIELD))              ! Set b_column to matmul(b_operator,rotation(:,field)).
            IF (PLACE%MITC%ACTIVE) THEN                                  ! If place.mitc.active:
              CALL MITC_TIE_COLUMN(PLACE%MITC, PLACE%NATURAL_S,          ! Call mitc tie column with place.mitc, place.natural_s, local_node, factor, factor_gradient, rotation(:,fiel...
     &             LOCAL_NODE, FACTOR, FACTOR_GRADIENT,
     &             ROTATION(:,FIELD), B_COLUMN, STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
            END IF                                                       ! End of the IF block.
            STATE%STRAIN_LOCAL = STATE%STRAIN_LOCAL +                    ! Add coefficient*b_column to state.strain_local.
     &                           COEFFICIENT*B_COLUMN
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      STATE%FRAME = ROTATION                                             ! Set state.frame to rotation.
      MATERIAL_AND_STRESS: BLOCK                                         ! Block material and stress with its own local variables begins:
        LAMINATION_INDEX = FIND_LAMINATION_INDEX(MODEL%LAMINATIONS,      ! Set lamination_index to find_lamination_index(model.laminations, model.expansions.item(place.mesh). element...
     &    MODEL%EXPANSIONS%ITEM(PLACE%MESH)%
     &    ELEMENT(PLACE%SUB_ELEMENT)%LAMINATION_ID)
        IF (LAMINATION_INDEX .EQ. 0_I4) THEN                             ! If lamination_index = 0:
          CALL SET_ERROR(STATUS, 'STATE_FROM_PLACE',                     ! Record an error in status: 'UNKNOWN LAMINATION AT THE POINT'.
     &                   'UNKNOWN LAMINATION AT THE POINT')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        STATE%LAMINATION_ID = MODEL%LAMINATIONS%                         ! Set state.lamination_id to model.laminations. item(lamination_index).id.
     &                        ITEM(LAMINATION_INDEX)%ID
        STATE%MATERIAL_ID = MODEL%LAMINATIONS%                           ! Set state.material_id to model.laminations. item(lamination_index).material_id.
     &                      ITEM(LAMINATION_INDEX)%MATERIAL_ID
        STATE%STRESS_LOCAL = MATMUL(                                     ! Set state.stress_local to matmul( cache.material_cache.stiffness_local(:,:,lamination_index), state.strain_...
     &    CACHE%MATERIAL_CACHE%STIFFNESS_LOCAL(:,:,LAMINATION_INDEX),
     &    STATE%STRAIN_LOCAL)
        IF (CACHE%MATERIAL_CACHE%ANY_PIEZO) THEN                         ! If cache.material_cache.any_piezo:
!         SIGMA = C S + E^T GRAD PHI ;  D = E S - EPS GRAD PHI.
          STATE%STRESS_LOCAL = STATE%STRESS_LOCAL + MATMUL(TRANSPOSE(    ! Add matmul(transpose( cache.material_cache.piezo_local(:,:,lamination_index)), grad_potential) to state.str...
     &      CACHE%MATERIAL_CACHE%PIEZO_LOCAL(:,:,LAMINATION_INDEX)),
     &      GRAD_POTENTIAL)
          STATE%ELECTRIC_FIELD_LOCAL = -GRAD_POTENTIAL                   ! Set state.electric_field_local to -grad_potential.
          STATE%ELECTRIC_DISPLACEMENT_LOCAL = MATMUL(                    ! Set state.electric_displacement_local to matmul( cache.material_cache.piezo_local(:,:,lamination_index), st...
     &      CACHE%MATERIAL_CACHE%PIEZO_LOCAL(:,:,LAMINATION_INDEX),
     &      STATE%STRAIN_LOCAL) - MATMUL(
     &      CACHE%MATERIAL_CACHE%PERMITTIVITY_LOCAL(:,:,
     &      LAMINATION_INDEX),GRAD_POTENTIAL)
          IF (CACHE%MATERIAL_CACHE%ANY_PYRO)                             ! If cache.material_cache.any_pyro, add state.temperature* cache.material_cache.pyro_local(:,lamination_index...
     &      STATE%ELECTRIC_DISPLACEMENT_LOCAL =
     &      STATE%ELECTRIC_DISPLACEMENT_LOCAL + STATE%TEMPERATURE*
     &      CACHE%MATERIAL_CACHE%PYRO_LOCAL(:,LAMINATION_INDEX)
        ELSE                                                             ! Otherwise:
          STATE%ELECTRIC_FIELD_LOCAL = -GRAD_POTENTIAL                   ! Set state.electric_field_local to -grad_potential.
        END IF                                                           ! End of the IF block.
        IF (CACHE%MATERIAL_CACHE%ANY_THERMAL) THEN                       ! If cache.material_cache.any_thermal:
!         SIGMA = C (S - ALPHA T) ;  Q = -K GRAD T.
          STATE%STRESS_LOCAL = STATE%STRESS_LOCAL -                      ! Subtract state.temperature*matmul(cache.material_cache. stiffness_local(:,:,lamination_index), cache.materi...
     &      STATE%TEMPERATURE*MATMUL(CACHE%MATERIAL_CACHE%
     &      STIFFNESS_LOCAL(:,:,LAMINATION_INDEX),
     &      CACHE%MATERIAL_CACHE%EXPANSION_LOCAL(:,LAMINATION_INDEX))
          STATE%HEAT_FLUX_LOCAL = -MATMUL(CACHE%MATERIAL_CACHE%          ! Set state.heat_flux_local to -matmul(cache.material_cache. conductivity_local(:,:,lamination_index),grad_te...
     &      CONDUCTIVITY_LOCAL(:,:,LAMINATION_INDEX),GRAD_TEMPERATURE)
          STATE%HEAT_FLUX_GLOBAL = MATMUL(TRANSPOSE(ROTATION),           ! Set state.heat_flux_global to matmul(transpose(rotation), state.heat_flux_local).
     &      STATE%HEAT_FLUX_LOCAL)
        END IF                                                           ! End of the IF block.
        STATE%ELECTRIC_FIELD_GLOBAL = MATMUL(TRANSPOSE(ROTATION),        ! Set state.electric_field_global to matmul(transpose(rotation), state.electric_field_local).
     &    STATE%ELECTRIC_FIELD_LOCAL)
        STATE%ELECTRIC_DISPLACEMENT_GLOBAL = MATMUL(                     ! Set state.electric_displacement_global to matmul( transpose(rotation),state.electric_displacement_local).
     &    TRANSPOSE(ROTATION),STATE%ELECTRIC_DISPLACEMENT_LOCAL)
      END BLOCK MATERIAL_AND_STRESS                                      ! End of the block.

!     LOCAL = T(R) GLOBAL FOR STRAIN; GLOBAL = T(R)**T LOCAL FOR STRESS.
      CALL BUILD_ENGINEERING_STRAIN_TRANSFORM(ROTATION, TRANSFORM)       ! Call build engineering strain transform with rotation, transform.
      STATE%STRAIN_GLOBAL = MATMUL(TRANSFORM_INVERSE(ROTATION),          ! Set state.strain_global to matmul(transform_inverse(rotation), state.strain_local).
     &                             STATE%STRAIN_LOCAL)
      STATE%STRESS_GLOBAL = MATMUL(TRANSPOSE(TRANSFORM),                 ! Set state.stress_global to matmul(transpose(transform), state.stress_local).
     &                             STATE%STRESS_LOCAL)

      END SUBROUTINE STATE_FROM_PLACE                                    ! End of the subroutine state from place.

!  DISPLACEMENT, POTENTIAL, TEMPERATURE AND THE STRAIN / GRADIENTS OF THE
!  LOCAL FRAME AT A POINT OF A CURVED BEAM / SHELL.
      SUBROUTINE GENERAL_STATE_PART(MODEL, CACHE, PLACE, SOLUTION,       ! Subroutine general state part takes model, cache, place, solution, state, rotation, grad potential, grad te...
     &     STATE, ROTATION, GRAD_POTENTIAL, GRAD_TEMPERATURE, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(PLACE_TYPE), INTENT(IN) :: PLACE                              ! Input of type place_type: place.
      REAL(R8), INTENT(IN) :: SOLUTION(:)                                ! Input real (real64): solution(:).
      TYPE(POINT_STATE_TYPE), INTENT(INOUT) :: STATE                     ! In/out of type point_state_type: state.
      REAL(R8), INTENT(OUT) :: ROTATION(3,3)                             ! Output real (real64): rotation(3,3).
      REAL(R8), INTENT(OUT) :: GRAD_POTENTIAL(3)                         ! Output real (real64): grad_potential(3).
      REAL(R8), INTENT(OUT) :: GRAD_TEMPERATURE(3)                       ! Output real (real64): grad_temperature(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                  ! Of type expansion_spec_type: spec.
      REAL(R8), ALLOCATABLE :: FV(:)                                     ! Allocatable real (real64): fv(:).
      REAL(R8), ALLOCATABLE :: FG(:,:)                                   ! Allocatable real (real64): fg(:,:).
      REAL(R8), ALLOCATABLE :: COEFFICIENT(:)                            ! Allocatable real (real64): coefficient(:).
      REAL(R8), ALLOCATABLE :: BCOL(:,:)                                 ! Allocatable real (real64): bcol(:,:).
      REAL(R8), ALLOCATABLE :: VALUE(:)                                  ! Allocatable real (real64): value(:).
      REAL(R8), ALLOCATABLE :: DIRG(:,:)                                 ! Allocatable real (real64): dirg(:,:).
      INTEGER(I4), ALLOCATABLE :: DOF_NODE(:)                            ! Allocatable integer (int32): dof_node(:).
      INTEGER(I4), ALLOCATABLE :: DOF_FIELD(:)                           ! Allocatable integer (int32): dof_field(:).
      REAL(R8) :: G(3,3)                                                 ! Real (real64): g(3,3).
      REAL(R8) :: DET                                                    ! Real (real64): det.
      REAL(R8) :: FACTOR                                                 ! Real (real64): factor.
      REAL(R8) :: FACTOR_GRADIENT(3)                                     ! Real (real64): factor_gradient(3).
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: LOCAL_NODE                                          ! Integer (int32): local_node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N_DOF = 0_I4                                                       ! Set n_dof to zero.
      DO LOCAL_NODE = 1_I4, SIZE(PLACE%SHAPE_STRUCTURAL)                 ! Loop local_node from 1 to size(place.shape_structural):
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES, MODEL%ELEMENTS%        ! Set node_index to find_node_index(model.nodes, model.elements. item(place.element).node_id(local_node)).
     &               ITEM(PLACE%ELEMENT)%NODE_ID(LOCAL_NODE))
        DO FIELD = 1_I4, N_SOLVED_FIELDS                                 ! Loop field from 1 to n_solved_fields:
          N_DOF = N_DOF + CACHE%DOF_LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)  ! Add cache.dof_layout.term_count(node_index,field) to n_dof.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      ALLOCATE(FV(N_DOF), FG(3,N_DOF), COEFFICIENT(N_DOF))               ! Allocate memory for fv(n_dof), fg(3,n_dof), coefficient(n_dof).
      ALLOCATE(BCOL(12,N_DOF), VALUE(N_DOF), DOF_NODE(N_DOF))            ! Allocate memory for bcol(12,n_dof), value(n_dof), dof_node(n_dof).
      ALLOCATE(DOF_FIELD(N_DOF), DIRG(3,N_DOF))                          ! Allocate memory for dof_field(n_dof), dirg(3,n_dof).
      I = 0_I4                                                           ! Set i to zero.
      DO LOCAL_NODE = 1_I4, SIZE(PLACE%SHAPE_STRUCTURAL)                 ! Loop local_node from 1 to size(place.shape_structural):
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES, MODEL%ELEMENTS%        ! Set node_index to find_node_index(model.nodes, model.elements. item(place.element).node_id(local_node)).
     &               ITEM(PLACE%ELEMENT)%NODE_ID(LOCAL_NODE))
        KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(MODEL%KINEMATICS,         ! Set kinematic_index to find_kinematic_index(model.kinematics, model.nodes.item(node_index).kinematic_id).
     &                    MODEL%NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
        DO FIELD = 1_I4, N_SOLVED_FIELDS                                 ! Loop field from 1 to n_solved_fields:
          SPEC = MODEL%KINEMATICS%ITEM(KINEMATIC_INDEX)%FIELD(FIELD)     ! Set spec to model.kinematics.item(kinematic_index).field(field).
          DO TERM = 1_I4, CACHE%DOF_LAYOUT%TERM_COUNT(NODE_INDEX,        ! Loop term from 1 to cache.dof_layout.term_count(node_index, field):
     &                                                FIELD)
            I = I + 1_I4                                                 ! Add 1 to i.
            COEFFICIENT(I) = SOLUTION(GLOBAL_DOF(CACHE%DOF_LAYOUT,       ! Set coefficient(i) to solution(global_dof(cache.dof_layout, node_index, field, term)).
     &                                  NODE_INDEX, FIELD, TERM))
            CALL EVALUATE_EXPANSION_FACTOR(SPEC, TERM,                   ! Call evaluate expansion factor with spec, term, model.expansions.item(place.mesh), place.sub_element, place...
     &           MODEL%EXPANSIONS%ITEM(PLACE%MESH),
     &           PLACE%SUB_ELEMENT, PLACE%EXPANSION_DIMENSION,
     &           PLACE%EXPANSION_AXIS(1:2),
     &           PLACE%EXPANSION_POINT_LOCAL,
     &           PLACE%SHAPE_EXPANSION, PLACE%GRADIENT_EXPANSION,
     &           FACTOR, FACTOR_GRADIENT, STATUS)
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            FV(I) = FACTOR                                               ! Set fv(i) to factor.
            FG(:,I) = FACTOR_GRADIENT                                    ! Set fg(:,i) to factor_gradient.
            DOF_NODE(I) = LOCAL_NODE                                     ! Set dof_node(i) to local_node.
            DOF_FIELD(I) = FIELD                                         ! Set dof_field(i) to field.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CALL GENERAL_POINT_COLUMNS(PLACE%GCTX, PLACE%SHAPE_STRUCTURAL,     ! Call general point columns with place.gctx, place.shape_structural, place.natural_derivative_s, place.natur...
     &     PLACE%NATURAL_DERIVATIVE_S, PLACE%NATURAL_S,
     &     PLACE%EXPANSION_POINT_LOCAL, N_DOF, DOF_NODE, DOF_FIELD, FV,
     &     FG, BCOL, VALUE, G, ROTATION, DET, STATUS, DIRG)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      GRAD_POTENTIAL = 0.0_R8                                            ! Set grad_potential to zero.
      GRAD_TEMPERATURE = 0.0_R8                                          ! Set grad_temperature to zero.
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        SELECT CASE (DOF_FIELD(I))                                       ! Choose according to the value of dof_field(i):
        CASE (1_I4, 2_I4, 3_I4)                                          ! Case 1, 2, 3:
!         THE DIRECTION IS THE AXIS OF THE FIELD, OR A COMBINATION OF
!         THE AXES FOR THE FIRST-ORDER TERM AT A KINKED SHELL NODE.
          STATE%DISPLACEMENT = STATE%DISPLACEMENT +                      ! Add coefficient(i)*value(i)*dirg(:,i) to state.displacement.
     &      COEFFICIENT(I)*VALUE(I)*DIRG(:,I)
          STATE%STRAIN_LOCAL = STATE%STRAIN_LOCAL +                      ! Add coefficient(i)*bcol(1:6,i) to state.strain_local.
     &                         COEFFICIENT(I)*BCOL(1:6,I)
        CASE (FIELD_P)                                                   ! Case field_p:
          STATE%POTENTIAL = STATE%POTENTIAL + COEFFICIENT(I)*            ! Add coefficient(i)* place.shape_structural(dof_node(i))*fv(i) to state.potential.
     &      PLACE%SHAPE_STRUCTURAL(DOF_NODE(I))*FV(I)
          GRAD_POTENTIAL = GRAD_POTENTIAL + COEFFICIENT(I)*BCOL(7:9,I)   ! Add coefficient(i)*bcol(7:9,i) to grad_potential.
        CASE (FIELD_T)                                                   ! Case field_t:
          STATE%TEMPERATURE = STATE%TEMPERATURE + COEFFICIENT(I)*        ! Add coefficient(i)* value(i) to state.temperature.
     &      VALUE(I)
          GRAD_TEMPERATURE = GRAD_TEMPERATURE +                          ! Add coefficient(i)*bcol(10:12,i) to grad_temperature.
     &                       COEFFICIENT(I)*BCOL(10:12,I)
        END SELECT                                                       ! End of the case selection.
      END DO                                                             ! End of the loop.

      END SUBROUTINE GENERAL_STATE_PART                                  ! End of the subroutine general state part.

!  GLOBAL DISPLACEMENT OF SEVERAL DOF VECTORS (E.G. MODE SHAPES) AT
!  THE POINT LAST EVALUATED BY PLACE_EVALUATE. NO GRADIENT IS NEEDED.
!    VECTORS(DOF,K) -> DISPLACEMENT(1:3,K)
      SUBROUTINE DISPLACEMENT_FROM_PLACE(MODEL, CACHE, PLACE, VECTORS,   ! Subroutine displacement from place takes model, cache, place, vectors, displacement, status.
     &                                   DISPLACEMENT, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(PLACE_TYPE), INTENT(IN) :: PLACE                              ! Input of type place_type: place.
      REAL(R8), INTENT(IN) :: VECTORS(:,:)                               ! Input real (real64): vectors(:,:).
      REAL(R8), INTENT(OUT) :: DISPLACEMENT(:,:)                         ! Output real (real64): displacement(:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                  ! Of type expansion_spec_type: spec.
      REAL(R8) :: GRADIENT(3)                                            ! Real (real64): gradient(3).
      REAL(R8) :: VALUE                                                  ! Real (real64): value.
      INTEGER(I8) :: DOF                                                 ! Integer (int64): dof.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: LOCAL_NODE                                          ! Integer (int32): local_node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      DISPLACEMENT = 0.0_R8                                              ! Set displacement to zero.
      DO LOCAL_NODE = 1_I4, SIZE(PLACE%SHAPE_STRUCTURAL)                 ! Loop local_node from 1 to size(place.shape_structural):
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES, MODEL%ELEMENTS%        ! Set node_index to find_node_index(model.nodes, model.elements. item(place.element).node_id(local_node)).
     &               ITEM(PLACE%ELEMENT)%NODE_ID(LOCAL_NODE))
        KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(MODEL%KINEMATICS,         ! Set kinematic_index to find_kinematic_index(model.kinematics, model.nodes.item(node_index).kinematic_id).
     &                    MODEL%NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
        DO FIELD = 1_I4, 3_I4                                            ! Loop field from 1 to 3:
          SPEC = MODEL%KINEMATICS%ITEM(KINEMATIC_INDEX)%FIELD(FIELD)     ! Set spec to model.kinematics.item(kinematic_index).field(field).
          DO TERM = 1_I4, CACHE%DOF_LAYOUT%TERM_COUNT(NODE_INDEX,        ! Loop term from 1 to cache.dof_layout.term_count(node_index, field):
     &                                                FIELD)
            DOF = GLOBAL_DOF(CACHE%DOF_LAYOUT, NODE_INDEX, FIELD,        ! Set dof to global_dof(cache.dof_layout, node_index, field, term).
     &                       TERM)
            CALL EVALUATE_FIELD_BASIS(SPEC, TERM,                        ! Call evaluate field basis with spec, term, place.shape_structural(local_node), place.gradient_structural(:,...
     &           PLACE%SHAPE_STRUCTURAL(LOCAL_NODE),
     &           PLACE%GRADIENT_STRUCTURAL(:,LOCAL_NODE),
     &           MODEL%EXPANSIONS%ITEM(PLACE%MESH),
     &           PLACE%SUB_ELEMENT, PLACE%EXPANSION_DIMENSION,
     &           PLACE%EXPANSION_AXIS(1:2),
     &           PLACE%EXPANSION_POINT_LOCAL,
     &           PLACE%SHAPE_EXPANSION, PLACE%GRADIENT_EXPANSION,
     &           VALUE, GRADIENT, STATUS)
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
            DISPLACEMENT(FIELD,:) = DISPLACEMENT(FIELD,:) +              ! Add vectors(dof,:)*value to displacement(field,:).
     &                              VECTORS(DOF,:)*VALUE
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE DISPLACEMENT_FROM_PLACE                             ! End of the subroutine displacement from place.

!  INVERSE OF THE STRAIN TRANSFORM OF AN ORTHOGONAL ROTATION.
      FUNCTION TRANSFORM_INVERSE(ROTATION) RESULT(INVERSE)               ! Function transform inverse takes rotation and returns inverse.

      REAL(R8), INTENT(IN) :: ROTATION(3,3)                              ! Input real (real64): rotation(3,3).
      REAL(R8) :: INVERSE(6,6)                                           ! Real (real64): inverse(6,6).
      REAL(R8) :: REVERSE(3,3)                                           ! Real (real64): reverse(3,3).

      REVERSE = TRANSPOSE(ROTATION)                                      ! Set reverse to transpose(rotation).
      CALL BUILD_ENGINEERING_STRAIN_TRANSFORM(REVERSE, INVERSE)          ! Call build engineering strain transform with reverse, inverse.

      END FUNCTION TRANSFORM_INVERSE                                     ! End of the function transform inverse.

!  FIND THE (ELEMENT, SUB-ELEMENT, NATURAL COORDINATES) CONTAINING THE
!  TARGET POINT. NEWTON ITERATION ON X_S(XI_S) + R**T X_E(XI_E) = TARGET
!  WHOSE UNKNOWNS ARE ALL THE NATURAL COORDINATES OF THE POINT.
      SUBROUTINE LOCATE_POINT(MODEL, CACHE, TARGET, TOLERANCE,           ! Subroutine locate point takes model, cache, target, tolerance, element, sub element, natural s, natural e, ...
     &     ELEMENT, SUB_ELEMENT, NATURAL_S, NATURAL_E, FOUND, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      REAL(R8), INTENT(IN) :: TARGET(3)                                  ! Input real (real64): target(3).
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      INTEGER(I4), INTENT(OUT) :: ELEMENT                                ! Output integer (int32): element.
      INTEGER(I4), INTENT(OUT) :: SUB_ELEMENT                            ! Output integer (int32): sub_element.
      REAL(R8), INTENT(OUT) :: NATURAL_S(3)                              ! Output real (real64): natural_s(3).
      REAL(R8), INTENT(OUT) :: NATURAL_E(3)                              ! Output real (real64): natural_e(3).
      LOGICAL, INTENT(OUT) :: FOUND                                      ! Output logical: found.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PLACE_TYPE) :: PLACE                                          ! Of type place_type: place.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      LOGICAL :: CONVERGED                                               ! Logical: converged.
      REAL(R8), ALLOCATABLE :: EXTENT(:)                                 ! Allocatable real (real64): extent(:).
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: MESH                                                ! Integer (int32): mesh.
      INTEGER(I4) :: S                                                   ! Integer (int32): s.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      FOUND = .FALSE.                                                    ! Set the flag found to false.
      ELEMENT = 0_I4                                                     ! Set element to zero.
      SUB_ELEMENT = 0_I4                                                 ! Set sub_element to zero.
      NATURAL_S = 0.0_R8                                                 ! Set natural_s to zero.
      NATURAL_E = 0.0_R8                                                 ! Set natural_e to zero.

      ALLOCATE(EXTENT(SIZE(MODEL%EXPANSIONS%ITEM)))                      ! Allocate memory for extent(size(model.expansions.item)).
      DO MESH = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM)                        ! Loop mesh from 1 to size(model.expansions.item):
        EXTENT(MESH) = 0.0_R8                                            ! Set extent(mesh) to zero.
        DO S = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM(MESH)%NODE)              ! Loop s from 1 to size(model.expansions.item(mesh).node):
          EXTENT(MESH) = MAX(EXTENT(MESH), SQRT(SUM(                     ! Set extent(mesh) to the larger of extent(mesh) and sqrt(sum( model.expansions.item(mesh).node(s).coordinate...
     &      MODEL%EXPANSIONS%ITEM(MESH)%NODE(S)%COORDINATE**2)))
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      DO E = 1_I4, SIZE(MODEL%ELEMENTS%ITEM)                             ! Loop e from 1 to size(model.elements.item):
        MESH = FIND_EXPANSION_INDEX(MODEL%EXPANSIONS,                    ! Set mesh to find_expansion_index(model.expansions, model.elements.item(e).expansion_id).
     &         MODEL%ELEMENTS%ITEM(E)%EXPANSION_ID)
        IF (MESH .EQ. 0_I4) CYCLE                                        ! If mesh = 0, skip to the next iteration.
        IF (.NOT. POINT_NEAR_ELEMENT(MODEL, E, TARGET,                   ! If not point_near_element(model, e, target, extent(mesh)*(1.0+tolerance)), skip to the next iteration.
     &      EXTENT(MESH)*(1.0_R8+TOLERANCE))) CYCLE
        DO S = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT)           ! Loop s from 1 to size(model.expansions.item(mesh).element):
          CALL PLACE_SETUP(MODEL, CACHE, E, S, PLACE, LOCAL_STATUS)      ! Call place setup with model, cache, e, s, place, local_status.
          IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) CYCLE                    ! If not local_status is ok, skip to the next iteration.
          CALL NEWTON_LOCATE(PLACE, MODEL, CACHE, TARGET, TOLERANCE,     ! Call newton locate with place, model, cache, target, tolerance, natural_s, natural_e, converged.
     &         NATURAL_S, NATURAL_E, CONVERGED)
          IF (.NOT. CONVERGED) CYCLE                                     ! If not converged, skip to the next iteration.
          IF (.NOT. NATURAL_INSIDE(PLACE%STRUCTURAL_TOPOLOGY,            ! If not natural_inside(place.structural_topology, natural_s, tolerance), skip to the next iteration.
     &        NATURAL_S, TOLERANCE)) CYCLE
          IF (.NOT. NATURAL_INSIDE(PLACE%EXPANSION_TOPOLOGY,             ! If not natural_inside(place.expansion_topology, natural_e, tolerance), skip to the next iteration.
     &        NATURAL_E, TOLERANCE)) CYCLE
          ELEMENT = E                                                    ! Set element to e.
          SUB_ELEMENT = S                                                ! Set sub_element to s.
          FOUND = .TRUE.                                                 ! Set the flag found to true.
          RETURN                                                         ! Return to the caller.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE LOCATE_POINT                                        ! End of the subroutine locate point.


!  CHEAP REJECTION: THE POINT LIES WITHIN THE BOUNDING BOX OF THE
!  STRUCTURAL NODES EXPANDED BY THE LARGEST EXPANSION EXTENT.
      LOGICAL FUNCTION POINT_NEAR_ELEMENT(MODEL, ELEMENT, TARGET,        ! Function point near element takes model, element, target, margin.
     &                                    MARGIN)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      REAL(R8), INTENT(IN) :: TARGET(3)                                  ! Input real (real64): target(3).
      REAL(R8), INTENT(IN) :: MARGIN                                     ! Input real (real64): margin.
      REAL(R8) :: LOW(3)                                                 ! Real (real64): low(3).
      REAL(R8) :: HIGH(3)                                                ! Real (real64): high(3).
      REAL(R8) :: X(3)                                                   ! Real (real64): x(3).
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      LOW = HUGE(1.0_R8)                                                 ! Set low to huge(1.0).
      HIGH = -HUGE(1.0_R8)                                               ! Set high to -huge(1.0).
      POINT_NEAR_ELEMENT = .TRUE.                                        ! Set the flag point_near_element to true.
      DO J = 1_I4, SIZE(MODEL%ELEMENTS%ITEM(ELEMENT)%NODE_ID)            ! Loop j from 1 to size(model.elements.item(element).node_id):
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES,                        ! Set node_index to find_node_index(model.nodes, model.elements.item(element).node_id(j)).
     &               MODEL%ELEMENTS%ITEM(ELEMENT)%NODE_ID(J))
        IF (NODE_INDEX .EQ. 0_I4) RETURN                                 ! If node_index = 0, return to the caller.
        X = MODEL%NODES%ITEM(NODE_INDEX)%COORDINATE                      ! Set x to model.nodes.item(node_index).coordinate.
        LOW = MIN(LOW,X)                                                 ! Set low to the smaller of low and x.
        HIGH = MAX(HIGH,X)                                               ! Set high to the larger of high and x.
      END DO                                                             ! End of the loop.
!     HIGH-ORDER ELEMENTS MAY BULGE SLIGHTLY OUT OF THE NODE BOX.
      X = MARGIN + 0.1_R8*(HIGH-LOW) + 1.0E-12_R8                        ! Set x to margin + 0.1*(high-low) + 1.0e-12.
      POINT_NEAR_ELEMENT = ALL(TARGET .GE. LOW-X) .AND.                  ! Set point_near_element to whether all of target >= low-x) and all(target <= high+x.
     &                     ALL(TARGET .LE. HIGH+X)

      END FUNCTION POINT_NEAR_ELEMENT                                    ! End of the function point near element.
      SUBROUTINE NEWTON_LOCATE(PLACE, MODEL, CACHE, TARGET, TOLERANCE,   ! Subroutine newton locate takes place, model, cache, target, tolerance, natural s, natural e, converged.
     &     NATURAL_S, NATURAL_E, CONVERGED)

      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.
      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      REAL(R8), INTENT(IN) :: TARGET(3)                                  ! Input real (real64): target(3).
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      REAL(R8), INTENT(OUT) :: NATURAL_S(3)                              ! Output real (real64): natural_s(3).
      REAL(R8), INTENT(OUT) :: NATURAL_E(3)                              ! Output real (real64): natural_e(3).
      LOGICAL, INTENT(OUT) :: CONVERGED                                  ! Output logical: converged.
      TYPE(STATUS_TYPE) :: STATUS                                        ! Of type status_type: status.
      REAL(R8) :: JACOBIAN(3,3)                                          ! Real (real64): jacobian(3,3).
      REAL(R8) :: INVERSE(3,3)                                           ! Real (real64): inverse(3,3).
      REAL(R8) :: RESIDUAL(3)                                            ! Real (real64): residual(3).
      REAL(R8) :: STEP(3)                                                ! Real (real64): step(3).
      REAL(R8) :: DETERMINANT                                            ! Real (real64): determinant.
      REAL(R8) :: SCALE                                                  ! Real (real64): scale.
      REAL(R8) :: POSITION(3)                                            ! Real (real64): position(3).
      REAL(R8) :: GMATRIX(3,3)                                           ! Real (real64): gmatrix(3,3).
      REAL(R8) :: DCDN(3)                                                ! Real (real64): dcdn(3).
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: DIM_S                                               ! Integer (int32): dim_s.
      INTEGER(I4) :: DIM_E                                               ! Integer (int32): dim_e.
      INTEGER(I4) :: ITERATION                                           ! Integer (int32): iteration.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CONVERGED = .FALSE.                                                ! Set the flag converged to false.
      NATURAL_S = 0.0_R8                                                 ! Set natural_s to zero.
      NATURAL_E = 0.0_R8                                                 ! Set natural_e to zero.
      DIM_S = PLACE%STRUCTURAL_DIMENSION                                 ! Set dim_s to place.structural_dimension.
      DIM_E = PLACE%EXPANSION_DIMENSION                                  ! Set dim_e to place.expansion_dimension.
      IF (DIM_S+DIM_E .NE. 3_I4) RETURN                                  ! If dim_s+dim_e /= 3, return to the caller.
      IF (PLACE%STRUCTURAL_TOPOLOGY .EQ. TOPOLOGY_T3 .OR.                ! If place.structural_topology = topology_t3 or place.structural_topology = topology_t6:
     &    PLACE%STRUCTURAL_TOPOLOGY .EQ. TOPOLOGY_T6) THEN
        NATURAL_S(1:2) = 1.0_R8/3.0_R8                                   ! Set natural_s(1:2) to 1.0/3.0.
      END IF                                                             ! End of the IF block.
      IF (PLACE%EXPANSION_TOPOLOGY .EQ. TOPOLOGY_T3 .OR.                 ! If place.expansion_topology = topology_t3 or place.expansion_topology = topology_t6:
     &    PLACE%EXPANSION_TOPOLOGY .EQ. TOPOLOGY_T6) THEN
        NATURAL_E(1:2) = 1.0_R8/3.0_R8                                   ! Set natural_e(1:2) to 1.0/3.0.
      END IF                                                             ! End of the IF block.
      SCALE = MAX(1.0_R8, MAXVAL(ABS(TARGET)))                           ! Set scale to the larger of 1.0 and maxval(abs(target)).

      DO ITERATION = 1_I4, 30_I4                                         ! Loop iteration from 1 to 30:
        CALL PLACE_EVALUATE(PLACE, MODEL, CACHE, NATURAL_S,              ! Call place evaluate with place, model, cache, natural_s, natural_e, false, status.
     &                      NATURAL_E, .FALSE., STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        RESIDUAL = PLACE%POINT_GLOBAL - TARGET                           ! Set residual to place.point_global - target.
        IF (MAXVAL(ABS(RESIDUAL)) .LE. 1.0E-13_R8*SCALE) THEN            ! If maxval(abs(residual)) <= 1.0e-13*scale:
          CONVERGED = .TRUE.                                             ! Set the flag converged to true.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (PLACE%GENERAL) THEN                                          ! If place.general:
!         CURVED ELEMENT: THE COLUMNS ARE THE ROWS OF THE GENERAL
!         JACOBIAN; THE EXPANSION COLUMNS COMBINE THE NODAL TRIADS.
          CALL GENERAL_MAP(DIM_S, SIZE(PLACE%SHAPE_STRUCTURAL),          ! Call general map with dim_s, size(place.shape_structural), place.gctx.coord, place.gctx.triad, place.shape_...
     &         PLACE%GCTX%COORD, PLACE%GCTX%TRIAD,
     &         PLACE%SHAPE_STRUCTURAL, PLACE%NATURAL_DERIVATIVE_S,
     &         PLACE%EXPANSION_POINT_LOCAL, PLACE%GCTX%AXIS,
     &         POSITION, GMATRIX)
          DO K = 1_I4, DIM_S                                             ! Loop k from 1 to dim_s:
            JACOBIAN(:,K) = GMATRIX(K,:)                                 ! Set jacobian(:,k) to gmatrix(k,:).
          END DO                                                         ! End of the loop.
          DO K = 1_I4, DIM_E                                             ! Loop k from 1 to dim_e:
            DCDN = 0.0_R8                                                ! Set dcdn to zero.
            IF (PLACE%CURVED) THEN                                       ! If place.curved:
              DCDN(PLACE%EXPANSION_AXIS(1)) = PLACE%MAP_DX(1,K)          ! Set dcdn(place.expansion_axis(1)) to place.map_dx(1,k).
              DCDN(PLACE%EXPANSION_AXIS(2)) = PLACE%MAP_DX(2,K)          ! Set dcdn(place.expansion_axis(2)) to place.map_dx(2,k).
            ELSE                                                         ! Otherwise:
              DO I = 1_I4, SIZE(PLACE%EXPANSION_NODE,2)                  ! Loop i from 1 to size(place.expansion_node,2):
                DCDN = DCDN + PLACE%NATURAL_DERIVATIVE_E(I,K)*           ! Add place.natural_derivative_e(i,k)* place.expansion_node(:,i) to dcdn.
     &                 PLACE%EXPANSION_NODE(:,I)
              END DO                                                     ! End of the loop.
            END IF                                                       ! End of the IF block.
            JACOBIAN(:,DIM_S+K) = 0.0_R8                                 ! Set jacobian(:,dim_s+k) to zero.
            DO I = 1_I4, SIZE(PLACE%SHAPE_STRUCTURAL)                    ! Loop i from 1 to size(place.shape_structural):
              DO A = 1_I4, 3_I4                                          ! Loop a from 1 to 3:
                JACOBIAN(:,DIM_S+K) = JACOBIAN(:,DIM_S+K) +              ! Add dcdn(a)*place.shape_structural(i)* place.gctx.triad(:,a,i) to jacobian(:,dim_s+k).
     &            DCDN(A)*PLACE%SHAPE_STRUCTURAL(I)*
     &            PLACE%GCTX%TRIAD(:,A,I)
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        ELSE                                                             ! Otherwise:
        DO K = 1_I4, DIM_S                                               ! Loop k from 1 to dim_s:
          JACOBIAN(:,K) = 0.0_R8                                         ! Set jacobian(:,k) to zero.
          DO I = 1_I4, SIZE(PLACE%SHAPE_STRUCTURAL)                      ! Loop i from 1 to size(place.shape_structural):
            JACOBIAN(:,K) = JACOBIAN(:,K) +                              ! Add place.natural_derivative_s(i,k)*place.node_global(:,i) to jacobian(:,k).
     &        PLACE%NATURAL_DERIVATIVE_S(I,K)*PLACE%NODE_GLOBAL(:,I)
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        DO K = 1_I4, DIM_E                                               ! Loop k from 1 to dim_e:
          JACOBIAN(:,DIM_S+K) = 0.0_R8                                   ! Set jacobian(:,dim_s+k) to zero.
          IF (PLACE%CURVED) THEN                                         ! If place.curved:
            JACOBIAN(PLACE%EXPANSION_AXIS(1),DIM_S+K) =                  ! Set jacobian(place.expansion_axis(1),dim_s+k) to place.map_dx(1,k).
     &        PLACE%MAP_DX(1,K)
            JACOBIAN(PLACE%EXPANSION_AXIS(2),DIM_S+K) =                  ! Set jacobian(place.expansion_axis(2),dim_s+k) to place.map_dx(2,k).
     &        PLACE%MAP_DX(2,K)
          ELSE                                                           ! Otherwise:
          DO I = 1_I4, SIZE(PLACE%EXPANSION_NODE,2)                      ! Loop i from 1 to size(place.expansion_node,2):
            JACOBIAN(:,DIM_S+K) = JACOBIAN(:,DIM_S+K) +                  ! Add place.natural_derivative_e(i,k)*place.expansion_node(:,i) to jacobian(:,dim_s+k).
     &        PLACE%NATURAL_DERIVATIVE_E(I,K)*PLACE%EXPANSION_NODE(:,I)
          END DO                                                         ! End of the loop.
          END IF                                                         ! End of the IF block.
          JACOBIAN(:,DIM_S+K) = MATMUL(CACHE%FRAMES%                     ! Set jacobian(:,dim_s+k) to matmul(cache.frames. local_to_global(:,:,place.element),jacobian(:,dim_s+k)).
     &      LOCAL_TO_GLOBAL(:,:,PLACE%ELEMENT),JACOBIAN(:,DIM_S+K))
        END DO                                                           ! End of the loop.
        END IF                                                           ! End of the IF block.
        CALL INVERT_3X3(JACOBIAN, INVERSE, DETERMINANT)                  ! Call invert 3x3 with jacobian, inverse, determinant.
        IF (ABS(DETERMINANT) .LE. TINY(1.0_R8)) RETURN                   ! If abs(determinant) <= tiny(1.0), return to the caller.
        STEP = MATMUL(INVERSE,RESIDUAL)                                  ! Set step to matmul(inverse,residual).
        NATURAL_S(1:DIM_S) = NATURAL_S(1:DIM_S) - STEP(1:DIM_S)          ! Subtract step(1:dim_s) from natural_s(1:dim_s).
        NATURAL_E(1:DIM_E) = NATURAL_E(1:DIM_E) -                        ! Subtract step(dim_s+1:dim_s+dim_e) from natural_e(1:dim_e).
     &                       STEP(DIM_S+1:DIM_S+DIM_E)
        IF (MAXVAL(ABS(NATURAL_S)) .GT. 50.0_R8 .OR.                     ! If maxval(abs(natural_s)) > 50.0 or maxval(abs(natural_e)) > 50.0, return to the caller.
     &      MAXVAL(ABS(NATURAL_E)) .GT. 50.0_R8) RETURN
      END DO                                                             ! End of the loop.
      CALL PLACE_EVALUATE(PLACE, MODEL, CACHE, NATURAL_S, NATURAL_E,     ! Call place evaluate with place, model, cache, natural_s, natural_e, false, status.
     &                    .FALSE., STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CONVERGED = MAXVAL(ABS(PLACE%POINT_GLOBAL-TARGET)) .LE.            ! Set converged to maxval(abs(place.point_global-target)) <= max(tolerance,1.0e-12)*scale.
     &            MAX(TOLERANCE,1.0E-12_R8)*SCALE

      END SUBROUTINE NEWTON_LOCATE                                       ! End of the subroutine newton locate.

      LOGICAL FUNCTION NATURAL_INSIDE(TOPOLOGY, NATURAL, TOLERANCE)      ! Function natural inside takes topology, natural, tolerance.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      REAL(R8), INTENT(IN) :: NATURAL(3)                                 ! Input real (real64): natural(3).
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.

      DIMENSION = TOPOLOGY_NATURAL_DIMENSION(TOPOLOGY)                   ! Set dimension to topology_natural_dimension(topology).
      SELECT CASE(TOPOLOGY)                                              ! Choose according to the value of topology:
      CASE(TOPOLOGY_T3, TOPOLOGY_T6)                                     ! Case topology_t3, topology_t6:
        NATURAL_INSIDE = NATURAL(1) .GE. -TOLERANCE .AND.                ! Set natural_inside to natural(1) >= -tolerance and natural(2) >= -tolerance and natural(1)+natural(2) <= 1....
     &                   NATURAL(2) .GE. -TOLERANCE .AND.
     &                   NATURAL(1)+NATURAL(2) .LE. 1.0_R8+TOLERANCE
      CASE(TOPOLOGY_T4, TOPOLOGY_T10)                                    ! Case topology_t4, topology_t10:
        NATURAL_INSIDE = MINVAL(NATURAL) .GE. -TOLERANCE .AND.           ! Set natural_inside to minval(natural) >= -tolerance and sum(natural) <= 1.0+tolerance.
     &                   SUM(NATURAL) .LE. 1.0_R8+TOLERANCE
      CASE DEFAULT                                                       ! In every other case:
        IF (DIMENSION .EQ. 0_I4) THEN                                    ! If dimension = 0:
          NATURAL_INSIDE = .TRUE.                                        ! Set the flag natural_inside to true.
        ELSE                                                             ! Otherwise:
          NATURAL_INSIDE = MAXVAL(ABS(NATURAL(1:DIMENSION))) .LE.        ! Set natural_inside to maxval(abs(natural(1:dimension))) <= 1.0+tolerance.
     &                     1.0_R8+TOLERANCE
        END IF                                                           ! End of the IF block.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION NATURAL_INSIDE                                        ! End of the function natural inside.

      SUBROUTINE INVERT_3X3(A, INVERSE, DETERMINANT)                     ! Subroutine invert 3x3 takes a, inverse, determinant.

      REAL(R8), INTENT(IN) :: A(3,3)                                     ! Input real (real64): a(3,3).
      REAL(R8), INTENT(OUT) :: INVERSE(3,3)                              ! Output real (real64): inverse(3,3).
      REAL(R8), INTENT(OUT) :: DETERMINANT                               ! Output real (real64): determinant.

      INVERSE = 0.0_R8                                                   ! Set inverse to zero.
      DETERMINANT = A(1,1)*(A(2,2)*A(3,3)-A(2,3)*A(3,2))                 ! Set determinant to a(1,1)*(a(2,2)*a(3,3)-a(2,3)*a(3,2)) - a(1,2)*(a(2,1)*a(3,3)-a(2,3)*a(3,1)) + a(1,3)*(a(...
     &            - A(1,2)*(A(2,1)*A(3,3)-A(2,3)*A(3,1))
     &            + A(1,3)*(A(2,1)*A(3,2)-A(2,2)*A(3,1))
      IF (ABS(DETERMINANT) .LE. TINY(1.0_R8)) RETURN                     ! If abs(determinant) <= tiny(1.0), return to the caller.
      INVERSE(1,1) = (A(2,2)*A(3,3)-A(2,3)*A(3,2))/DETERMINANT           ! Set inverse(1,1) to (a(2,2)*a(3,3)-a(2,3)*a(3,2))/determinant.
      INVERSE(1,2) = (A(1,3)*A(3,2)-A(1,2)*A(3,3))/DETERMINANT           ! Set inverse(1,2) to (a(1,3)*a(3,2)-a(1,2)*a(3,3))/determinant.
      INVERSE(1,3) = (A(1,2)*A(2,3)-A(1,3)*A(2,2))/DETERMINANT           ! Set inverse(1,3) to (a(1,2)*a(2,3)-a(1,3)*a(2,2))/determinant.
      INVERSE(2,1) = (A(2,3)*A(3,1)-A(2,1)*A(3,3))/DETERMINANT           ! Set inverse(2,1) to (a(2,3)*a(3,1)-a(2,1)*a(3,3))/determinant.
      INVERSE(2,2) = (A(1,1)*A(3,3)-A(1,3)*A(3,1))/DETERMINANT           ! Set inverse(2,2) to (a(1,1)*a(3,3)-a(1,3)*a(3,1))/determinant.
      INVERSE(2,3) = (A(1,3)*A(2,1)-A(1,1)*A(2,3))/DETERMINANT           ! Set inverse(2,3) to (a(1,3)*a(2,1)-a(1,1)*a(2,3))/determinant.
      INVERSE(3,1) = (A(2,1)*A(3,2)-A(2,2)*A(3,1))/DETERMINANT           ! Set inverse(3,1) to (a(2,1)*a(3,2)-a(2,2)*a(3,1))/determinant.
      INVERSE(3,2) = (A(1,2)*A(3,1)-A(1,1)*A(3,2))/DETERMINANT           ! Set inverse(3,2) to (a(1,2)*a(3,1)-a(1,1)*a(3,2))/determinant.
      INVERSE(3,3) = (A(1,1)*A(2,2)-A(1,2)*A(2,1))/DETERMINANT           ! Set inverse(3,3) to (a(1,1)*a(2,2)-a(1,2)*a(2,1))/determinant.

      END SUBROUTINE INVERT_3X3                                          ! End of the subroutine invert 3x3.

      END MODULE MUL2_RECOVERY                                           ! End of the module mul2 recovery.
