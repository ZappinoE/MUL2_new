!=======================================================================
!  SURFACE HEAT LOADS ON THE EXPOSED SKIN OF THE MODEL.
!
!  A SURFACE PIECE IS THE PRODUCT OF A PART OF THE STRUCTURAL ELEMENT
!  AND A PART OF THE EXPANSION SUB-ELEMENT, WITH TWO PARAMETERS IN ALL:
!      BEAM   (1D X 2D):  AXIS X EDGE OF THE SECTION    (LATERAL SKIN)
!                         END NODE X WHOLE SECTION      (END FACES)
!      PLATE  (2D X 1D):  SURFACE X END OF THE THICKNESS (TOP, BOTTOM)
!                         EDGE X WHOLE THICKNESS        (SIDES)
!      SOLID  (3D X 0D):  FACE OF THE ELEMENT
!  A PIECE IS EXPOSED WHEN NO OTHER PIECE HAS THE SAME CENTRE (SHARED
!  FACES ARE INTERIOR). THE OUTWARD NORMAL POINTS AWAY FROM THE CENTRE
!  OF THE ELEMENT.
!
!  LOADS (Q > 0 HEATS THE BODY), ALL ON THE TEMPERATURE FIELD (4):
!    1  FLUX      Q = Q0                       ON THE PIECES OF A PLANE
!    2  SUN       Q = ABSORPTIVITY G MAX(0, N.S)   (S: TOWARDS THE SUN)
!    3  CONVECTION Q = H (T_INF - T)           ON THE PIECES OF A PLANE
!  THE CONVECTION ADDS H INT N N^T TO THE CONDUCTION MATRIX.
!=======================================================================
      MODULE MUL2_SURFACE_LOADS                                          ! Module mul2 surface loads begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, set warning, status is ok.
     &                       SET_WARNING, STATUS_IS_OK
      USE MUL2_LOG, ONLY: LOG_INFO                                       ! Use from module mul2 log: log info.
      USE MUL2_TIMER, ONLY: TIMER_TYPE, TIMER_START, TIMER_STOP,         ! Use from module mul2 timer: timer type, timer start, timer stop, timer wall seconds.
     &                      TIMER_WALL_SECONDS
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE                       ! Use from module mul2 model cache: model cache type.
      USE MUL2_BOUNDARY_CONDITIONS, ONLY: BC_SURFACE                     ! Use from module mul2 boundary conditions: bc surface.
      USE MUL2_RECOVERY, ONLY: PLACE_TYPE, PLACE_SETUP, PLACE_EVALUATE   ! Use from module mul2 recovery: place type, place setup, place evaluate.
      USE MUL2_TOPOLOGIES                                                ! Use everything exported by module mul2 topologies.
      USE MUL2_SHAPE_FUNCTIONS, ONLY: EVALUATE_SHAPE                     ! Use from module mul2 shape functions: evaluate shape.
      USE MUL2_QUADRATURE, ONLY: QUADRATURE_RULE_TYPE,                   ! Use from module mul2 quadrature: quadrature rule type, build ordered quadrature, build default quadrature.
     &     BUILD_ORDERED_QUADRATURE, BUILD_DEFAULT_QUADRATURE
      USE MUL2_NODES, ONLY: FIND_NODE_INDEX                              ! Use from module mul2 nodes: find node index.
      USE MUL2_KINEMATICS, ONLY: FIND_KINEMATIC_INDEX,                   ! Use from module mul2 kinematics: find kinematic index, expansion spec type, expansion none.
     &                           EXPANSION_SPEC_TYPE, EXPANSION_NONE
      USE MUL2_DOF_LAYOUT, ONLY: GLOBAL_DOF                              ! Use from module mul2 dof layout: global dof.
      USE MUL2_POINT_BASES, ONLY: EVALUATE_EXPANSION_FACTOR              ! Use from module mul2 point bases: evaluate expansion factor.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE,                ! Use from module mul2 sparse assembly: sparse system type, scatter element.
     &                                SCATTER_ELEMENT
      USE MUL2_SORTING, ONLY: SORT_PERMUTATION                           ! Use from module mul2 sorting: sort permutation.
      USE MUL2_FIELDS, ONLY: EVALUATE_FIELD                              ! Use from module mul2 fields: evaluate field.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!     GAUSS POINTS PER DIRECTION ON A SURFACE PIECE.
      INTEGER(I4), PARAMETER :: SURFACE_ORDER = 4_I4                     ! Constant integer (int32): surface_order = 4.
      INTEGER(I4), PARAMETER :: FIELD_TEMPERATURE = 4_I4                 ! Constant integer (int32): field_temperature = 4.

!  PART OF A NATURAL DOMAIN: NATURAL = A + M (U, V). KIND: 0 POINT,
!  1 LINE, 2 SQUARE, 3 TRIANGLE (THE PARAMETERS ARE THE FIRST COLUMNS).
      TYPE :: PART_TYPE                                                  ! Definition of the derived type part type.
        INTEGER(I4) :: KIND = 0_I4                                       ! Integer (int32): kind = 0.
        LOGICAL :: WHOLE = .FALSE.                                       ! Logical: whole = false.
        REAL(R8) :: A(3) = 0.0_R8                                        ! Real (real64): a(3) = 0.0.
        REAL(R8) :: M(3,2) = 0.0_R8                                      ! Real (real64): m(3,2) = 0.0.
      END TYPE PART_TYPE                                                 ! End of the type definition part type.

      PUBLIC :: APPLY_SURFACE_LOADS                                      ! Export: apply surface loads.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE APPLY_SURFACE_LOADS(MODEL, CACHE, SYSTEM, FORCE,        ! Subroutine apply surface loads takes model, cache, system, force, status.
     &                               STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      REAL(R8), INTENT(INOUT) :: FORCE(:)                                ! In/out real (real64): force(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PART_TYPE), ALLOCATABLE :: S_PARTS(:)                         ! Allocatable of type part_type: s_parts(:).
      TYPE(PART_TYPE), ALLOCATABLE :: E_PARTS(:)                         ! Allocatable of type part_type: e_parts(:).
      TYPE(PLACE_TYPE) :: PLACE                                          ! Of type place_type: place.
      INTEGER(I4), ALLOCATABLE :: F_ELEMENT(:)                           ! Allocatable integer (int32): f_element(:).
      INTEGER(I4), ALLOCATABLE :: F_SUB(:)                               ! Allocatable integer (int32): f_sub(:).
      INTEGER(I4), ALLOCATABLE :: F_SPART(:)                             ! Allocatable integer (int32): f_spart(:).
      INTEGER(I4), ALLOCATABLE :: F_EPART(:)                             ! Allocatable integer (int32): f_epart(:).
      REAL(R8), ALLOCATABLE :: F_CENTRE(:,:)                             ! Allocatable real (real64): f_centre(:,:).
      LOGICAL, ALLOCATABLE :: F_EXPOSED(:)                               ! Allocatable logical: f_exposed(:).
      REAL(R8) :: REFERENCE(3)                                           ! Real (real64): reference(3).
      INTEGER(I4) :: N_ITEM                                              ! Integer (int32): n_item.
      INTEGER(I4) :: N_FACE                                              ! Integer (int32): n_face.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: MESH                                                ! Integer (int32): mesh.
      INTEGER(I4) :: SUB                                                 ! Integer (int32): sub.
      INTEGER(I4) :: SP                                                  ! Integer (int32): sp.
      INTEGER(I4) :: EP                                                  ! Integer (int32): ep.
      INTEGER(I4) :: PASS                                                ! Integer (int32): pass.
      INTEGER(I4) :: F                                                   ! Integer (int32): f.
      INTEGER(I4) :: LAST_ELEMENT                                        ! Integer (int32): last_element.
      INTEGER(I4) :: LAST_SUB                                            ! Integer (int32): last_sub.
      REAL(R8) :: UNIT                                                   ! Real (real64): unit.
      TYPE(TIMER_TYPE) :: TIMER                                          ! Of type timer_type: timer.
      REAL(R8) :: FIND_SECONDS                                           ! Real (real64): find_seconds.
      REAL(R8), ALLOCATABLE :: AREA(:)                                   ! Allocatable real (real64): area(:).
      REAL(R8), ALLOCATABLE :: POWER(:)                                  ! Allocatable real (real64): power(:).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      CHARACTER(LEN=160) :: MESSAGE                                      ! Character (length 160): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N_ITEM = 0_I4                                                      ! Set n_item to zero.
      IF (ALLOCATED(MODEL%BOUNDARIES%ITEM)) THEN                         ! If allocated(model.boundaries.item):
        DO I = 1_I4, SIZE(MODEL%BOUNDARIES%ITEM)                         ! Loop i from 1 to size(model.boundaries.item):
          IF (MODEL%BOUNDARIES%ITEM(I)%KIND .EQ. BC_SURFACE)             ! If model.boundaries.item(i).kind = bc_surface, add 1 to n_item.
     &      N_ITEM = N_ITEM + 1_I4
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.
      IF (N_ITEM .EQ. 0_I4) RETURN                                       ! If n_item = 0, return to the caller.
      IF (ALLOCATED(CACHE%FRAMES%GENERAL_INDEX)) THEN                    ! If allocated(cache.frames.general_index):
        IF (ANY(CACHE%FRAMES%GENERAL_INDEX .GT. 0_I4)) THEN              ! If any(cache.frames.general_index > 0):
          CALL SET_ERROR(STATUS, 'APPLY_SURFACE_LOADS',                  ! Record an error in status: 'SURFACE LOADS (Q-PLANE, Q-SUN, Q-CONV) ARE NOT '// 'SUPPORTED WITH CURVED BEAMS...
     &      'SURFACE LOADS (Q-PLANE, Q-SUN, Q-CONV) ARE NOT '//
     &      'SUPPORTED WITH CURVED BEAMS AND SHELLS')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

!     PASS 1 COUNTS THE CANDIDATE PIECES, PASS 2 FILLS THEM.
      CALL TIMER_START(TIMER, 'SURFACE LOADS')                           ! Call timer start with timer, 'SURFACE LOADS'.
      N_FACE = 0_I4                                                      ! Set n_face to zero.
      DO PASS = 1_I4, 2_I4                                               ! Loop pass from 1 to 2:
        IF (PASS .EQ. 2_I4) THEN                                         ! If pass = 2:
          ALLOCATE(F_ELEMENT(N_FACE), F_SUB(N_FACE), F_SPART(N_FACE),    ! Allocate memory for f_element(n_face), f_sub(n_face), f_spart(n_face), f_epart(n_face), f_centre(3,n_face),...
     &             F_EPART(N_FACE), F_CENTRE(3,N_FACE),
     &             F_EXPOSED(N_FACE))
          N_FACE = 0_I4                                                  ! Set n_face to zero.
        END IF                                                           ! End of the IF block.
        DO ELEMENT = 1_I4, SIZE(MODEL%ELEMENTS%ITEM)                     ! Loop element from 1 to size(model.elements.item):
          MESH = MESH_OF(MODEL, ELEMENT)                                 ! Set mesh to mesh_of(model, element).
          IF (MESH .EQ. 0_I4) CYCLE                                      ! If mesh = 0, skip to the next iteration.
          CALL STRUCTURAL_PARTS(                                         ! Call structural parts with model.elements.item(element).topology, s_parts.
     &         MODEL%ELEMENTS%ITEM(ELEMENT)%TOPOLOGY, S_PARTS)
          IF (SIZE(S_PARTS) .EQ. 0) CYCLE                                ! If size(s_parts) = 0, skip to the next iteration.
          DO SUB = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT)       ! Loop sub from 1 to size(model.expansions.item(mesh).element):
            CALL STRUCTURAL_PARTS(MODEL%EXPANSIONS%ITEM(MESH)%           ! Call structural parts with model.expansions.item(mesh). element(sub).topology, e_parts.
     &           ELEMENT(SUB)%TOPOLOGY, E_PARTS)
            IF (PASS .EQ. 2_I4) THEN                                     ! If pass = 2:
              CALL PLACE_SETUP(MODEL, CACHE, ELEMENT, SUB, PLACE,        ! Call place setup with model, cache, element, sub, place, status.
     &                         STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
            END IF                                                       ! End of the IF block.
            DO SP = 1_I4, SIZE(S_PARTS)                                  ! Loop sp from 1 to size(s_parts):
              DO EP = 1_I4, SIZE(E_PARTS)                                ! Loop ep from 1 to size(e_parts):
                IF (.NOT. PIECE_IS_SURFACE(S_PARTS(SP),E_PARTS(EP),      ! If not piece_is_surface(s_parts(sp),e_parts(ep), model.elements.item(element).topology, model.expansions.it...
     &              MODEL%ELEMENTS%ITEM(ELEMENT)%TOPOLOGY,
     &              MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT(SUB)%TOPOLOGY))
     &            CYCLE
                N_FACE = N_FACE + 1_I4                                   ! Add 1 to n_face.
                IF (PASS .EQ. 1_I4) CYCLE                                ! If pass = 1, skip to the next iteration.
                F_ELEMENT(N_FACE) = ELEMENT                              ! Set f_element(n_face) to element.
                F_SUB(N_FACE) = SUB                                      ! Set f_sub(n_face) to sub.
                F_SPART(N_FACE) = SP                                     ! Set f_spart(n_face) to sp.
                F_EPART(N_FACE) = EP                                     ! Set f_epart(n_face) to ep.
                CALL PIECE_CENTRE(MODEL, CACHE, PLACE, S_PARTS(SP),      ! Call piece centre with model, cache, place, s_parts(sp), e_parts(ep), f_centre(:,n_face), status.
     &               E_PARTS(EP), F_CENTRE(:,N_FACE), STATUS)
                IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                   ! If not status is ok, return to the caller.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (N_FACE .EQ. 0_I4) THEN                                         ! If n_face = 0:
        CALL SET_WARNING(STATUS, 'APPLY_SURFACE_LOADS',                  ! Record a warning in status: 'THE MODEL HAS NO SURFACE PIECES'.
     &                   'THE MODEL HAS NO SURFACE PIECES')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      UNIT = 1.0E-7_R8*MAX(1.0E-12_R8, MAXVAL(ABS(F_CENTRE)))            ! Set unit to 1.0e-7*max(1.0e-12, maxval(abs(f_centre))).
      CALL FIND_EXPOSED(F_CENTRE, UNIT, F_EXPOSED)                       ! Call find exposed with f_centre, unit, f_exposed.
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      FIND_SECONDS = TIMER_WALL_SECONDS(TIMER)                           ! Set find_seconds to timer_wall_seconds(timer).
      CALL TIMER_START(TIMER, 'SURFACE INTEGRATION')                     ! Call timer start with timer, 'SURFACE INTEGRATION'.

      ALLOCATE(AREA(SIZE(MODEL%BOUNDARIES%ITEM)),                        ! Allocate memory for area(size(model.boundaries.item)), power(size(model.boundaries.item)).
     &         POWER(SIZE(MODEL%BOUNDARIES%ITEM)))
      AREA = 0.0_R8                                                      ! Set area to zero.
      POWER = 0.0_R8                                                     ! Set power to zero.
      LAST_ELEMENT = 0_I4                                                ! Set last_element to zero.
      LAST_SUB = 0_I4                                                    ! Set last_sub to zero.
      DO F = 1_I4, N_FACE                                                ! Loop f from 1 to n_face:
        IF (.NOT. F_EXPOSED(F)) CYCLE                                    ! If not f_exposed(f), skip to the next iteration.
        ELEMENT = F_ELEMENT(F)                                           ! Set element to f_element(f).
        SUB = F_SUB(F)                                                   ! Set sub to f_sub(f).
        MESH = MESH_OF(MODEL, ELEMENT)                                   ! Set mesh to mesh_of(model, element).
        CALL STRUCTURAL_PARTS(                                           ! Call structural parts with model.elements.item(element).topology, s_parts.
     &       MODEL%ELEMENTS%ITEM(ELEMENT)%TOPOLOGY, S_PARTS)
        CALL STRUCTURAL_PARTS(MODEL%EXPANSIONS%ITEM(MESH)%               ! Call structural parts with model.expansions.item(mesh). element(sub).topology, e_parts.
     &       ELEMENT(SUB)%TOPOLOGY, E_PARTS)
        IF (ELEMENT .NE. LAST_ELEMENT .OR. SUB .NE. LAST_SUB) THEN       ! If element /= last_element or sub /= last_sub:
          CALL PLACE_SETUP(MODEL, CACHE, ELEMENT, SUB, PLACE, STATUS)    ! Call place setup with model, cache, element, sub, place, status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          LAST_ELEMENT = ELEMENT                                         ! Set last_element to element.
          LAST_SUB = SUB                                                 ! Set last_sub to sub.
        END IF                                                           ! End of the IF block.
        CALL ELEMENT_REFERENCE(MODEL, CACHE, PLACE, REFERENCE, STATUS)   ! Call element reference with model, cache, place, reference, status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        CALL INTEGRATE_PIECE(MODEL, CACHE, PLACE, S_PARTS(F_SPART(F)),   ! Call integrate piece with model, cache, place, s_parts(f_spart(f)), e_parts(f_epart(f)), f_centre(:,f), ref...
     &       E_PARTS(F_EPART(F)), F_CENTRE(:,F), REFERENCE, SYSTEM,
     &       FORCE, AREA, POWER, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      WRITE(MESSAGE,'(A,I0,A,I0,A,F8.3,A,F8.3,A)') 'SURFACE PIECES: ',   ! Format into the text message: 'SURFACE PIECES: ', n_face, ' (', count(f_exposed), ' EXPOSED), SEARCH ', fin...
     &  N_FACE, ' (', COUNT(F_EXPOSED), ' EXPOSED), SEARCH ',
     &  FIND_SECONDS, ' S, INTEGRATION ', TIMER_WALL_SECONDS(TIMER),
     &  ' S'
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.
      DO I = 1_I4, SIZE(MODEL%BOUNDARIES%ITEM)                           ! Loop i from 1 to size(model.boundaries.item):
        IF (MODEL%BOUNDARIES%ITEM(I)%KIND .NE. BC_SURFACE) CYCLE         ! If model.boundaries.item(i).kind /= bc_surface, skip to the next iteration.
        WRITE(MESSAGE,'(A,I0,A,ES12.5,A,ES12.5)') 'SURFACE LOAD ',       ! Format into the text message: 'SURFACE LOAD ', model.boundaries.item(i).id, ': AREA ', area(i), ', HEAT POW...
     &    MODEL%BOUNDARIES%ITEM(I)%ID, ': AREA ', AREA(I),
     &    ', HEAT POWER ', POWER(I)
        CALL LOG_INFO(MESSAGE)                                           ! Log: message.
        IF (AREA(I) .EQ. 0.0_R8) CALL SET_WARNING(STATUS,                ! If area(i) = 0.0, record a warning in status: 'A SURFACE LOAD DID NOT SELECT ANY EXPOSED SURFACE'.
     &    'APPLY_SURFACE_LOADS',
     &    'A SURFACE LOAD DID NOT SELECT ANY EXPOSED SURFACE')
      END DO                                                             ! End of the loop.

      END SUBROUTINE APPLY_SURFACE_LOADS                                 ! End of the subroutine apply surface loads.

      INTEGER(I4) FUNCTION MESH_OF(MODEL, ELEMENT)                       ! Function mesh of takes model, element.

      USE MUL2_EXPANSION_MESHES, ONLY: FIND_EXPANSION_INDEX              ! Use from module mul2 expansion meshes: find expansion index.
      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.

      MESH_OF = FIND_EXPANSION_INDEX(MODEL%EXPANSIONS,                   ! Set mesh_of to find_expansion_index(model.expansions, model.elements.item(element).expansion_id).
     &          MODEL%ELEMENTS%ITEM(ELEMENT)%EXPANSION_ID)

      END FUNCTION MESH_OF                                               ! End of the function mesh of.

!  PARTS OF THE NATURAL DOMAIN OF A TOPOLOGY THAT CAN BUILD A SURFACE.
      SUBROUTINE STRUCTURAL_PARTS(TOPOLOGY, PARTS)                       ! Subroutine structural parts takes topology, parts.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      TYPE(PART_TYPE), ALLOCATABLE, INTENT(OUT) :: PARTS(:)              ! Allocatable output of type part_type: parts(:).
      INTEGER(I4) :: DIM                                                 ! Integer (int32): dim.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: S                                                   ! Integer (int32): s.
      LOGICAL :: TRI                                                     ! Logical: tri.

      DIM = TOPOLOGY_NATURAL_DIMENSION(TOPOLOGY)                         ! Set dim to topology_natural_dimension(topology).
      TRI = TOPOLOGY .EQ. TOPOLOGY_T3 .OR. TOPOLOGY .EQ. TOPOLOGY_T6     ! Set tri to topology = topology_t3 or topology = topology_t6.
      IF (TOPOLOGY .EQ. TOPOLOGY_S1) THEN                                ! If topology = topology_s1:
        ALLOCATE(PARTS(1))                                               ! Allocate memory for parts(1).
        PARTS(1)%KIND = 0_I4                                             ! Set parts(1).kind to zero.
        PARTS(1)%WHOLE = .TRUE.                                          ! Set the flag parts(1).whole to true.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (TOPOLOGY .EQ. TOPOLOGY_T4 .OR. TOPOLOGY .EQ. TOPOLOGY_T10 .OR. ! If topology = topology_t4 or topology = topology_t10 or topology = topology_p6 or topology = topology_h20 o...
     &    TOPOLOGY .EQ. TOPOLOGY_P6 .OR. TOPOLOGY .EQ. TOPOLOGY_H20 .OR.
     &    DIM .LT. 1_I4) THEN
        ALLOCATE(PARTS(0))                                               ! Allocate memory for parts(0).
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      SELECT CASE (DIM)                                                  ! Choose according to the value of dim:
      CASE (1_I4)                                                        ! Case 1:
        ALLOCATE(PARTS(3))                                               ! Allocate memory for parts(3).
        PARTS(1)%KIND = 1_I4                                             ! Set parts(1).kind to 1.
        PARTS(1)%WHOLE = .TRUE.                                          ! Set the flag parts(1).whole to true.
        PARTS(1)%M(1,1) = 1.0_R8                                         ! Set parts(1).m(1,1) to 1.0.
        DO K = 1_I4, 2_I4                                                ! Loop k from 1 to 2:
          PARTS(1+K)%KIND = 0_I4                                         ! Set parts(1+k).kind to zero.
          PARTS(1+K)%A(1) = REAL(2*K-3,R8)                               ! Set parts(1+k).a(1) to real(2*k-3,r8).
        END DO                                                           ! End of the loop.
      CASE (2_I4)                                                        ! Case 2:
        IF (TRI) THEN                                                    ! If tri:
          ALLOCATE(PARTS(4))                                             ! Allocate memory for parts(4).
          PARTS(1)%KIND = 3_I4                                           ! Set parts(1).kind to 3.
          PARTS(1)%WHOLE = .TRUE.                                        ! Set the flag parts(1).whole to true.
          PARTS(1)%M(1,1) = 1.0_R8                                       ! Set parts(1).m(1,1) to 1.0.
          PARTS(1)%M(2,2) = 1.0_R8                                       ! Set parts(1).m(2,2) to 1.0.
          PARTS(2)%KIND = 1_I4                                           ! Set parts(2).kind to 1.
          PARTS(2)%A(1) = 0.5_R8                                         ! Set parts(2).a(1) to 0.5.
          PARTS(2)%M(1,1) = 0.5_R8                                       ! Set parts(2).m(1,1) to 0.5.
          PARTS(3)%KIND = 1_I4                                           ! Set parts(3).kind to 1.
          PARTS(3)%A(1:2) = [0.5_R8,0.5_R8]                              ! Set parts(3).a(1:2) to [0.5,0.5].
          PARTS(3)%M(1,1) = -0.5_R8                                      ! Set parts(3).m(1,1) to -0.5.
          PARTS(3)%M(2,1) = 0.5_R8                                       ! Set parts(3).m(2,1) to 0.5.
          PARTS(4)%KIND = 1_I4                                           ! Set parts(4).kind to 1.
          PARTS(4)%A(2) = 0.5_R8                                         ! Set parts(4).a(2) to 0.5.
          PARTS(4)%M(2,1) = -0.5_R8                                      ! Set parts(4).m(2,1) to -0.5.
        ELSE                                                             ! Otherwise:
          ALLOCATE(PARTS(5))                                             ! Allocate memory for parts(5).
          PARTS(1)%KIND = 2_I4                                           ! Set parts(1).kind to 2.
          PARTS(1)%WHOLE = .TRUE.                                        ! Set the flag parts(1).whole to true.
          PARTS(1)%M(1,1) = 1.0_R8                                       ! Set parts(1).m(1,1) to 1.0.
          PARTS(1)%M(2,2) = 1.0_R8                                       ! Set parts(1).m(2,2) to 1.0.
          PARTS(2)%KIND = 1_I4                                           ! Set parts(2).kind to 1.
          PARTS(2)%A(2) = -1.0_R8                                        ! Set parts(2).a(2) to -1.0.
          PARTS(2)%M(1,1) = 1.0_R8                                       ! Set parts(2).m(1,1) to 1.0.
          PARTS(3)%KIND = 1_I4                                           ! Set parts(3).kind to 1.
          PARTS(3)%A(1) = 1.0_R8                                         ! Set parts(3).a(1) to 1.0.
          PARTS(3)%M(2,1) = 1.0_R8                                       ! Set parts(3).m(2,1) to 1.0.
          PARTS(4)%KIND = 1_I4                                           ! Set parts(4).kind to 1.
          PARTS(4)%A(2) = 1.0_R8                                         ! Set parts(4).a(2) to 1.0.
          PARTS(4)%M(1,1) = 1.0_R8                                       ! Set parts(4).m(1,1) to 1.0.
          PARTS(5)%KIND = 1_I4                                           ! Set parts(5).kind to 1.
          PARTS(5)%A(1) = -1.0_R8                                        ! Set parts(5).a(1) to -1.0.
          PARTS(5)%M(2,1) = 1.0_R8                                       ! Set parts(5).m(2,1) to 1.0.
        END IF                                                           ! End of the IF block.
      CASE DEFAULT                                                       ! In every other case:
!       HEXAHEDRON: SIX FACES, TWO PER NATURAL AXIS.
        ALLOCATE(PARTS(6))                                               ! Allocate memory for parts(6).
        DO K = 1_I4, 3_I4                                                ! Loop k from 1 to 3:
          DO S = 1_I4, 2_I4                                              ! Loop s from 1 to 2:
            PARTS(2*(K-1)+S)%KIND = 2_I4                                 ! Set parts(2*(k-1)+s).kind to 2.
            PARTS(2*(K-1)+S)%A(K) = REAL(2*S-3,R8)                       ! Set parts(2*(k-1)+s).a(k) to real(2*s-3,r8).
            PARTS(2*(K-1)+S)%M(MOD(K,3_I4)+1_I4,1) = 1.0_R8              ! Set parts(2*(k-1)+s).m(mod(k,3)+1,1) to 1.0.
            PARTS(2*(K-1)+S)%M(MOD(K+1_I4,3_I4)+1_I4,2) = 1.0_R8         ! Set parts(2*(k-1)+s).m(mod(k+1,3)+1,2) to 1.0.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE STRUCTURAL_PARTS                                    ! End of the subroutine structural parts.

      INTEGER(I4) FUNCTION PART_DIMENSION(PART)                          ! Function part dimension takes part.

      TYPE(PART_TYPE), INTENT(IN) :: PART                                ! Input of type part_type: part.

      SELECT CASE (PART%KIND)                                            ! Choose according to the value of part.kind:
      CASE (0_I4)                                                        ! Case 0:
        PART_DIMENSION = 0_I4                                            ! Set part_dimension to zero.
      CASE (1_I4)                                                        ! Case 1:
        PART_DIMENSION = 1_I4                                            ! Set part_dimension to 1.
      CASE DEFAULT                                                       ! In every other case:
        PART_DIMENSION = 2_I4                                            ! Set part_dimension to 2.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION PART_DIMENSION                                        ! End of the function part dimension.

!  A PIECE IS A SURFACE WHEN THE TWO PARTS HAVE TWO PARAMETERS IN ALL
!  AND ARE NOT BOTH THE WHOLE DOMAIN.
      LOGICAL FUNCTION PIECE_IS_SURFACE(S_PART, E_PART, S_TOPOLOGY,      ! Function piece is surface takes s part, e part, s topology, e topology.
     &                                  E_TOPOLOGY)

      TYPE(PART_TYPE), INTENT(IN) :: S_PART                              ! Input of type part_type: s_part.
      TYPE(PART_TYPE), INTENT(IN) :: E_PART                              ! Input of type part_type: e_part.
      INTEGER(I4), INTENT(IN) :: S_TOPOLOGY                              ! Input integer (int32): s_topology.
      INTEGER(I4), INTENT(IN) :: E_TOPOLOGY                              ! Input integer (int32): e_topology.

      PIECE_IS_SURFACE = PART_DIMENSION(S_PART) +                        ! Set piece_is_surface to part_dimension(s_part) + part_dimension(e_part) = 2.
     &  PART_DIMENSION(E_PART) .EQ. 2_I4
      IF (S_PART%WHOLE .AND. E_PART%WHOLE) PIECE_IS_SURFACE = .FALSE.    ! If s_part.whole and e_part.whole, set the flag piece_is_surface to false.
      IF (TOPOLOGY_NATURAL_DIMENSION(S_TOPOLOGY) +                       ! If topology_natural_dimension(s_topology) + topology_natural_dimension(e_topology) /= 3, set the flag piece...
     &    TOPOLOGY_NATURAL_DIMENSION(E_TOPOLOGY) .NE. 3_I4)
     &  PIECE_IS_SURFACE = .FALSE.

      END FUNCTION PIECE_IS_SURFACE                                      ! End of the function piece is surface.

!  NATURAL COORDINATES OF THE CENTRE OF A PART.
      SUBROUTINE PART_CENTRE(PART, CENTRE)                               ! Subroutine part centre takes part, centre.

      TYPE(PART_TYPE), INTENT(IN) :: PART                                ! Input of type part_type: part.
      REAL(R8), INTENT(OUT) :: CENTRE(3)                                 ! Output real (real64): centre(3).
      REAL(R8) :: PAR(2)                                                 ! Real (real64): par(2).

      PAR = 0.0_R8                                                       ! Set par to zero.
      IF (PART%KIND .EQ. 3_I4) PAR = 1.0_R8/3.0_R8                       ! If part.kind = 3, set par to 1.0/3.0.
      CENTRE = PART%A + MATMUL(PART%M,PAR)                               ! Set centre to part.a + matmul(part.m,par).

      END SUBROUTINE PART_CENTRE                                         ! End of the subroutine part centre.

!  PHYSICAL POSITION OF THE CENTRE OF A PIECE.
      SUBROUTINE PIECE_CENTRE(MODEL, CACHE, PLACE, S_PART, E_PART,       ! Subroutine piece centre takes model, cache, place, s part, e part, centre, status.
     &                        CENTRE, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.
      TYPE(PART_TYPE), INTENT(IN) :: S_PART                              ! Input of type part_type: s_part.
      TYPE(PART_TYPE), INTENT(IN) :: E_PART                              ! Input of type part_type: e_part.
      REAL(R8), INTENT(OUT) :: CENTRE(3)                                 ! Output real (real64): centre(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: NS(3)                                                  ! Real (real64): ns(3).
      REAL(R8) :: NE(3)                                                  ! Real (real64): ne(3).

      CALL PART_CENTRE(S_PART, NS)                                       ! Call part centre with s_part, ns.
      CALL PART_CENTRE(E_PART, NE)                                       ! Call part centre with e_part, ne.
      CALL PLACE_EVALUATE(PLACE, MODEL, CACHE, NS, NE, .FALSE., STATUS)  ! Call place evaluate with place, model, cache, ns, ne, false, status.
      CENTRE = PLACE%POINT_GLOBAL                                        ! Set centre to place.point_global.

      END SUBROUTINE PIECE_CENTRE                                        ! End of the subroutine piece centre.

!  CENTRE OF THE ELEMENT (SUB-ELEMENT): THE NORMALS POINT AWAY FROM IT.
      SUBROUTINE ELEMENT_REFERENCE(MODEL, CACHE, PLACE, REFERENCE,       ! Subroutine element reference takes model, cache, place, reference, status.
     &                             STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.
      REAL(R8), INTENT(OUT) :: REFERENCE(3)                              ! Output real (real64): reference(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: NS(3)                                                  ! Real (real64): ns(3).
      REAL(R8) :: NE(3)                                                  ! Real (real64): ne(3).

      NS = 0.0_R8                                                        ! Set ns to zero.
      NE = 0.0_R8                                                        ! Set ne to zero.
      IF (PLACE%STRUCTURAL_TOPOLOGY .EQ. TOPOLOGY_T3 .OR.                ! If place.structural_topology = topology_t3 or place.structural_topology = topology_t6, set ns(1:2) to 1.0/3.0.
     &    PLACE%STRUCTURAL_TOPOLOGY .EQ. TOPOLOGY_T6) NS(1:2) =
     &  1.0_R8/3.0_R8
      IF (PLACE%EXPANSION_TOPOLOGY .EQ. TOPOLOGY_T3 .OR.                 ! If place.expansion_topology = topology_t3 or place.expansion_topology = topology_t6, set ne(1:2) to 1.0/3.0.
     &    PLACE%EXPANSION_TOPOLOGY .EQ. TOPOLOGY_T6) NE(1:2) =
     &  1.0_R8/3.0_R8
      CALL PLACE_EVALUATE(PLACE, MODEL, CACHE, NS, NE, .FALSE., STATUS)  ! Call place evaluate with place, model, cache, ns, ne, false, status.
      REFERENCE = PLACE%POINT_GLOBAL                                     ! Set reference to place.point_global.

      END SUBROUTINE ELEMENT_REFERENCE                                   ! End of the subroutine element reference.

!  EXPOSED = NO OTHER PIECE HAS THE SAME CENTRE.
      SUBROUTINE FIND_EXPOSED(CENTRE, UNIT, EXPOSED)                     ! Subroutine find exposed takes centre, unit, exposed.

      REAL(R8), INTENT(IN) :: CENTRE(:,:)                                ! Input real (real64): centre(:,:).
      REAL(R8), INTENT(IN) :: UNIT                                       ! Input real (real64): unit.
      LOGICAL, INTENT(OUT) :: EXPOSED(:)                                 ! Output logical: exposed(:).
      INTEGER(I8), ALLOCATABLE :: KEY(:)                                 ! Allocatable integer (int64): key(:).
      INTEGER(I4), ALLOCATABLE :: ORDER(:)                               ! Allocatable integer (int32): order(:).
      INTEGER(I8) :: IX(3)                                               ! Integer (int64): ix(3).
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: FIRST                                               ! Integer (int32): first.
      INTEGER(I4) :: LAST_IN_RUN                                         ! Integer (int32): last_in_run.

      N = SIZE(CENTRE,2)                                                 ! Set n to size(centre,2).
      ALLOCATE(KEY(N), ORDER(N))                                         ! Allocate memory for key(n), order(n).
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        IX = NINT(CENTRE(:,I)/UNIT, I8)                                  ! Set ix to nint(centre(:,i)/unit, i8).
        KEY(I) = IX(1)*73856093_I8 + IX(2)*19349663_I8 +                 ! Set key(i) to ix(1)*73856093 + ix(2)*19349663 + ix(3)*83492791.
     &           IX(3)*83492791_I8
      END DO                                                             ! End of the loop.
      CALL SORT_PERMUTATION(KEY, ORDER)                                  ! Call sort permutation with key, order.
      EXPOSED = .TRUE.                                                   ! Set the flag exposed to true.
      FIRST = 1_I4                                                       ! Set first to 1.
      DO WHILE (FIRST .LE. N)                                            ! Repeat while first <= n:
        LAST_IN_RUN = FIRST                                              ! Set last_in_run to first.
        DO WHILE (LAST_IN_RUN .LT. N)                                    ! Repeat while last_in_run < n:
          IF (KEY(ORDER(LAST_IN_RUN+1_I4)) .NE. KEY(ORDER(FIRST))) EXIT  ! If key(order(last_in_run+1)) /= key(order(first)), leave the loop.
          LAST_IN_RUN = LAST_IN_RUN + 1_I4                               ! Add 1 to last_in_run.
        END DO                                                           ! End of the loop.
        DO I = FIRST, LAST_IN_RUN                                        ! Loop i from first to last_in_run:
          DO J = FIRST, LAST_IN_RUN                                      ! Loop j from first to last_in_run:
            IF (I .EQ. J) CYCLE                                          ! If i = j, skip to the next iteration.
            IF (MAXVAL(ABS(CENTRE(:,ORDER(I))-CENTRE(:,ORDER(J))))       ! If maxval(abs(centre(:,order(i))-centre(:,order(j)))) <= 10.0*unit:
     &          .LE. 10.0_R8*UNIT) THEN
              EXPOSED(ORDER(I)) = .FALSE.                                ! Set the flag exposed(order(i)) to false.
              EXIT                                                       ! Leave the loop.
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        FIRST = LAST_IN_RUN + 1_I4                                       ! Set first to last_in_run + 1.
      END DO                                                             ! End of the loop.

      END SUBROUTINE FIND_EXPOSED                                        ! End of the subroutine find exposed.

      SUBROUTINE PART_RULE(PART, RULE, STATUS)                           ! Subroutine part rule takes part, rule, status.

      TYPE(PART_TYPE), INTENT(IN) :: PART                                ! Input of type part_type: part.
      TYPE(QUADRATURE_RULE_TYPE), INTENT(INOUT) :: RULE                  ! In/out of type quadrature_rule_type: rule.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      SELECT CASE (PART%KIND)                                            ! Choose according to the value of part.kind:
      CASE (0_I4)                                                        ! Case 0:
        CALL BUILD_DEFAULT_QUADRATURE(TOPOLOGY_S1, RULE, STATUS)         ! Call build default quadrature with topology_s1, rule, status.
      CASE (1_I4)                                                        ! Case 1:
        CALL BUILD_ORDERED_QUADRATURE(TOPOLOGY_B2, SURFACE_ORDER, RULE,  ! Call build ordered quadrature with topology_b2, surface_order, rule, status.
     &                                STATUS)
      CASE (2_I4)                                                        ! Case 2:
        CALL BUILD_ORDERED_QUADRATURE(TOPOLOGY_Q4, SURFACE_ORDER, RULE,  ! Call build ordered quadrature with topology_q4, surface_order, rule, status.
     &                                STATUS)
      CASE DEFAULT                                                       ! In every other case:
        CALL BUILD_DEFAULT_QUADRATURE(TOPOLOGY_T6, RULE, STATUS)         ! Call build default quadrature with topology_t6, rule, status.
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE PART_RULE                                           ! End of the subroutine part rule.

!  INTEGRAL OF ALL THE SURFACE LOADS OVER ONE EXPOSED PIECE.
      SUBROUTINE INTEGRATE_PIECE(MODEL, CACHE, PLACE, S_PART, E_PART,    ! Subroutine integrate piece takes model, cache, place, s part, e part, centre, reference, system, force, are...
     &     CENTRE, REFERENCE, SYSTEM, FORCE, AREA, POWER, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(PLACE_TYPE), INTENT(INOUT) :: PLACE                           ! In/out of type place_type: place.
      TYPE(PART_TYPE), INTENT(IN) :: S_PART                              ! Input of type part_type: s_part.
      TYPE(PART_TYPE), INTENT(IN) :: E_PART                              ! Input of type part_type: e_part.
      REAL(R8), INTENT(IN) :: CENTRE(3)                                  ! Input real (real64): centre(3).
      REAL(R8), INTENT(IN) :: REFERENCE(3)                               ! Input real (real64): reference(3).
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(INOUT) :: SYSTEM                  ! In/out of type sparse_system_type: system.
      REAL(R8), INTENT(INOUT) :: FORCE(:)                                ! In/out real (real64): force(:).
      REAL(R8), INTENT(INOUT) :: AREA(:)                                 ! In/out real (real64): area(:).
      REAL(R8), INTENT(INOUT) :: POWER(:)                                ! In/out real (real64): power(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(QUADRATURE_RULE_TYPE) :: S_RULE                               ! Of type quadrature_rule_type: s_rule.
      TYPE(QUADRATURE_RULE_TYPE) :: E_RULE                               ! Of type quadrature_rule_type: e_rule.
      TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                  ! Of type expansion_spec_type: spec.
      REAL(R8), ALLOCATABLE :: VALUE(:)                                  ! Allocatable real (real64): value(:).
      REAL(R8), ALLOCATABLE :: STIFFNESS(:,:)                            ! Allocatable real (real64): stiffness(:,:).
      INTEGER(I8), ALLOCATABLE :: DOF(:)                                 ! Allocatable integer (int64): dof(:).
      REAL(R8) :: NO_MASS(0,0)                                           ! Real (real64): no_mass(0,0).
      REAL(R8) :: GEO_SHAPE(32)                                          ! Real (real64): geo_shape(32).
      REAL(R8) :: GEO_DERIVATIVE(32,3)                                   ! Real (real64): geo_derivative(32,3).
      INTEGER(I4) :: GEO_TOPOLOGY                                        ! Integer (int32): geo_topology.
      REAL(R8) :: NS(3)                                                  ! Real (real64): ns(3).
      REAL(R8) :: NE(3)                                                  ! Real (real64): ne(3).
      REAL(R8) :: TANGENT(3,2)                                           ! Real (real64): tangent(3,2).
      REAL(R8) :: DX(3)                                                  ! Real (real64): dx(3).
      REAL(R8) :: LOCAL(3)                                               ! Real (real64): local(3).
      REAL(R8) :: NORMAL(3)                                              ! Real (real64): normal(3).
      REAL(R8) :: WEIGHT                                                 ! Real (real64): weight.
      REAL(R8) :: AREA_ELEMENT                                           ! Real (real64): area_element.
      REAL(R8) :: FACTOR                                                 ! Real (real64): factor.
      REAL(R8) :: FACTOR_GRADIENT(3)                                     ! Real (real64): factor_gradient(3).
      REAL(R8) :: Q                                                      ! Real (real64): q.
      REAL(R8) :: SUN(3)                                                 ! Real (real64): sun(3).
      LOGICAL :: ANY_CONVECTION                                          ! Logical: any_convection.
      LOGICAL :: SELECTED                                                ! Logical: selected.
      INTEGER(I4) :: DS                                                  ! Integer (int32): ds.
      INTEGER(I4) :: DE                                                  ! Integer (int32): de.
      INTEGER(I4) :: PS                                                  ! Integer (int32): ps.
      INTEGER(I4) :: PE                                                  ! Integer (int32): pe.
      INTEGER(I4) :: ITEM                                                ! Integer (int32): item.
      INTEGER(I4) :: LOCAL_NODE                                          ! Integer (int32): local_node.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC                                           ! Integer (int32): kinematic.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: C                                                   ! Integer (int32): c.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
!     SELECTION: WHICH LOADS APPLY TO THIS PIECE (BY ITS CENTRE).
      SELECTED = .FALSE.                                                 ! Set the flag selected to false.
      ANY_CONVECTION = .FALSE.                                           ! Set the flag any_convection to false.
      DO ITEM = 1_I4, SIZE(MODEL%BOUNDARIES%ITEM)                        ! Loop item from 1 to size(model.boundaries.item):
        IF (MODEL%BOUNDARIES%ITEM(ITEM)%KIND .NE. BC_SURFACE) CYCLE      ! If model.boundaries.item(item).kind /= bc_surface, skip to the next iteration.
        IF (.NOT. ON_PLANE(CENTRE, MODEL%BOUNDARIES%ITEM(ITEM)%PLANE))   ! If not on_plane(centre, model.boundaries.item(item).plane), skip to the next iteration.
     &    CYCLE
        SELECTED = .TRUE.                                                ! Set the flag selected to true.
        IF (MODEL%BOUNDARIES%ITEM(ITEM)%SURFACE .EQ. 3_I4)               ! If model.boundaries.item(item).surface = 3, set the flag any_convection to true.
     &    ANY_CONVECTION = .TRUE.
      END DO                                                             ! End of the loop.
      IF (.NOT. SELECTED) RETURN                                         ! If not selected, return to the caller.

!     TEMPERATURE DOFS OF THE ELEMENT (ALL NODES, ALL TERMS).
      COUNT = 0_I4                                                       ! Set count to zero.
      DO LOCAL_NODE = 1_I4, SIZE(PLACE%SHAPE_STRUCTURAL)                 ! Loop local_node from 1 to size(place.shape_structural):
        NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES, MODEL%ELEMENTS%        ! Set node_index to find_node_index(model.nodes, model.elements. item(place.element).node_id(local_node)).
     &    ITEM(PLACE%ELEMENT)%NODE_ID(LOCAL_NODE))
        COUNT = COUNT + CACHE%DOF_LAYOUT%TERM_COUNT(NODE_INDEX,          ! Add cache.dof_layout.term_count(node_index, field_temperature) to count.
     &                                              FIELD_TEMPERATURE)
      END DO                                                             ! End of the loop.
      IF (COUNT .EQ. 0_I4) RETURN                                        ! If count = 0, return to the caller.
      ALLOCATE(VALUE(COUNT), DOF(COUNT))                                 ! Allocate memory for value(count), dof(count).
      IF (ANY_CONVECTION) THEN                                           ! If any_convection:
        ALLOCATE(STIFFNESS(COUNT,COUNT))                                 ! Allocate memory for stiffness(count,count).
        STIFFNESS = 0.0_R8                                               ! Set stiffness to zero.
      END IF                                                             ! End of the IF block.

      DS = PART_DIMENSION(S_PART)                                        ! Set ds to part_dimension(s_part).
      DE = PART_DIMENSION(E_PART)                                        ! Set de to part_dimension(e_part).
      CALL PART_RULE(S_PART, S_RULE, STATUS)                             ! Call part rule with s_part, s_rule, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL PART_RULE(E_PART, E_RULE, STATUS)                             ! Call part rule with e_part, e_rule, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      DO PS = 1_I4, SIZE(S_RULE%WEIGHT)                                  ! Loop ps from 1 to size(s_rule.weight):
        DO PE = 1_I4, SIZE(E_RULE%WEIGHT)                                ! Loop pe from 1 to size(e_rule.weight):
          NS = S_PART%A + MATMUL(S_PART%M(:,1:2),                        ! Set ns to s_part.a + matmul(s_part.m(:,1:2), [s_rule.coordinate(ps,1),s_rule.coordinate(ps,2)]).
     &         [S_RULE%COORDINATE(PS,1),S_RULE%COORDINATE(PS,2)])
          NE = E_PART%A + MATMUL(E_PART%M(:,1:2),                        ! Set ne to e_part.a + matmul(e_part.m(:,1:2), [e_rule.coordinate(pe,1),e_rule.coordinate(pe,2)]).
     &         [E_RULE%COORDINATE(PE,1),E_RULE%COORDINATE(PE,2)])
          CALL PLACE_EVALUATE(PLACE, MODEL, CACHE, NS, NE, .TRUE.,       ! Call place evaluate with place, model, cache, ns, ne, true, status.
     &                        STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
!         TANGENTS: STRUCTURAL PARAMETERS FIRST, THEN EXPANSION ONES.
          TANGENT = 0.0_R8                                               ! Set tangent to zero.
          DO K = 1_I4, DS                                                ! Loop k from 1 to ds:
            DO L = 1_I4, PLACE%STRUCTURAL_DIMENSION                      ! Loop l from 1 to place.structural_dimension:
              DX = MATMUL(PLACE%NODE_GLOBAL,                             ! Set dx to matmul(place.node_global, place.natural_derivative_s(:,l)).
     &                    PLACE%NATURAL_DERIVATIVE_S(:,L))
              TANGENT(:,K) = TANGENT(:,K) + S_PART%M(L,K)*DX             ! Add s_part.m(l,k)*dx to tangent(:,k).
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
!         GEOMETRY OF AN HLE SUB-ELEMENT: ITS STRAIGHT (VERTEX) MAP.
          GEO_TOPOLOGY = PLACE%EXPANSION_TOPOLOGY                        ! Set geo_topology to place.expansion_topology.
          IF (TOPOLOGY_IS_HLE(GEO_TOPOLOGY)) THEN                        ! If topology_is_hle(geo_topology):
            GEO_TOPOLOGY = TOPOLOGY_B2                                   ! Set geo_topology to topology_b2.
            IF (PLACE%EXPANSION_DIMENSION .EQ. 2_I4)                     ! If place.expansion_dimension = 2, set geo_topology to topology_q4.
     &        GEO_TOPOLOGY = TOPOLOGY_Q4
          END IF                                                         ! End of the IF block.
          GEO_DERIVATIVE = 0.0_R8                                        ! Set geo_derivative to zero.
          IF (PLACE%EXPANSION_DIMENSION .GE. 1_I4) THEN                  ! If place.expansion_dimension >= 1:
            CALL EVALUATE_SHAPE(GEO_TOPOLOGY, NE, GEO_SHAPE,             ! Call evaluate shape with geo_topology, ne, geo_shape, geo_derivative, status.
     &                          GEO_DERIVATIVE, STATUS)
            IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                       ! If not status is ok, return to the caller.
          END IF                                                         ! End of the IF block.
          DO K = 1_I4, DE                                                ! Loop k from 1 to de:
            DO L = 1_I4, PLACE%EXPANSION_DIMENSION                       ! Loop l from 1 to place.expansion_dimension:
              IF (PLACE%CURVED) THEN                                     ! If place.curved:
                LOCAL = 0.0_R8                                           ! Set local to zero.
                LOCAL(PLACE%EXPANSION_AXIS(1)) = PLACE%MAP_DX(1,L)       ! Set local(place.expansion_axis(1)) to place.map_dx(1,l).
                LOCAL(PLACE%EXPANSION_AXIS(2)) = PLACE%MAP_DX(2,L)       ! Set local(place.expansion_axis(2)) to place.map_dx(2,l).
              ELSE                                                       ! Otherwise:
                LOCAL = MATMUL(PLACE%EXPANSION_NODE,                     ! Set local to matmul(place.expansion_node, geo_derivative(1:size( place.expansion_node,2),l)).
     &                         GEO_DERIVATIVE(1:SIZE(
     &                         PLACE%EXPANSION_NODE,2),L))
              END IF                                                     ! End of the IF block.
              DX = MATMUL(CACHE%FRAMES%LOCAL_TO_GLOBAL(:,:,              ! Set dx to matmul(cache.frames.local_to_global(:,:, place.element),local).
     &                    PLACE%ELEMENT),LOCAL)
              TANGENT(:,DS+K) = TANGENT(:,DS+K) + E_PART%M(L,K)*DX       ! Add e_part.m(l,k)*dx to tangent(:,ds+k).
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
          NORMAL(1) = TANGENT(2,1)*TANGENT(3,2)-TANGENT(3,1)*            ! Set normal(1) to tangent(2,1)*tangent(3,2)-tangent(3,1)* tangent(2,2).
     &                TANGENT(2,2)
          NORMAL(2) = TANGENT(3,1)*TANGENT(1,2)-TANGENT(1,1)*            ! Set normal(2) to tangent(3,1)*tangent(1,2)-tangent(1,1)* tangent(3,2).
     &                TANGENT(3,2)
          NORMAL(3) = TANGENT(1,1)*TANGENT(2,2)-TANGENT(2,1)*            ! Set normal(3) to tangent(1,1)*tangent(2,2)-tangent(2,1)* tangent(1,2).
     &                TANGENT(1,2)
          AREA_ELEMENT = SQRT(SUM(NORMAL**2))                            ! Set area_element to the square root of sum(normal**2).
          IF (AREA_ELEMENT .LE. TINY(1.0_R8)) CYCLE                      ! If area_element <= tiny(1.0), skip to the next iteration.
          NORMAL = NORMAL/AREA_ELEMENT                                   ! Divide normal by area_element.
          IF (DOT_PRODUCT(NORMAL,PLACE%POINT_GLOBAL-REFERENCE) .LT.      ! If dot_product(normal,place.point_global-reference) < 0.0, set normal to -normal.
     &        0.0_R8) NORMAL = -NORMAL
          WEIGHT = S_RULE%WEIGHT(PS)*E_RULE%WEIGHT(PE)*AREA_ELEMENT      ! Set weight to s_rule.weight(ps)*e_rule.weight(pe)*area_element.

!         TEMPERATURE BASIS ON THE PIECE.
          C = 0_I4                                                       ! Set c to zero.
          DO LOCAL_NODE = 1_I4, SIZE(PLACE%SHAPE_STRUCTURAL)             ! Loop local_node from 1 to size(place.shape_structural):
            NODE_INDEX = FIND_NODE_INDEX(MODEL%NODES, MODEL%ELEMENTS%    ! Set node_index to find_node_index(model.nodes, model.elements. item(place.element).node_id(local_node)).
     &        ITEM(PLACE%ELEMENT)%NODE_ID(LOCAL_NODE))
            KINEMATIC = FIND_KINEMATIC_INDEX(MODEL%KINEMATICS,           ! Set kinematic to find_kinematic_index(model.kinematics, model.nodes.item(node_index).kinematic_id).
     &        MODEL%NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
            SPEC = MODEL%KINEMATICS%ITEM(KINEMATIC)%                     ! Set spec to model.kinematics.item(kinematic). field(field_temperature).
     &             FIELD(FIELD_TEMPERATURE)
            DO TERM = 1_I4, CACHE%DOF_LAYOUT%TERM_COUNT(NODE_INDEX,      ! Loop term from 1 to cache.dof_layout.term_count(node_index, field_temperature):
     &                                            FIELD_TEMPERATURE)
              C = C + 1_I4                                               ! Add 1 to c.
              DOF(C) = GLOBAL_DOF(CACHE%DOF_LAYOUT, NODE_INDEX,          ! Set dof(c) to global_dof(cache.dof_layout, node_index, field_temperature, term).
     &                            FIELD_TEMPERATURE, TERM)
              CALL EVALUATE_EXPANSION_FACTOR(SPEC, TERM,                 ! Call evaluate expansion factor with spec, term, model.expansions.item(place.mesh), place.sub_element, place...
     &             MODEL%EXPANSIONS%ITEM(PLACE%MESH),
     &             PLACE%SUB_ELEMENT, PLACE%EXPANSION_DIMENSION,
     &             PLACE%EXPANSION_AXIS(1:2),
     &             PLACE%EXPANSION_POINT_LOCAL, PLACE%SHAPE_EXPANSION,
     &             PLACE%GRADIENT_EXPANSION, FACTOR, FACTOR_GRADIENT,
     &             LOCAL_STATUS)
              IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                 ! If not local_status is ok:
                CALL SET_ERROR(STATUS, 'INTEGRATE_PIECE',                ! Record an error in status: trim(local_status.message).
     &                         TRIM(LOCAL_STATUS%MESSAGE))
                RETURN                                                   ! Return to the caller.
              END IF                                                     ! End of the IF block.
              VALUE(C) = PLACE%SHAPE_STRUCTURAL(LOCAL_NODE)*FACTOR       ! Set value(c) to place.shape_structural(local_node)*factor.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.

          DO ITEM = 1_I4, SIZE(MODEL%BOUNDARIES%ITEM)                    ! Loop item from 1 to size(model.boundaries.item):
            IF (MODEL%BOUNDARIES%ITEM(ITEM)%KIND .NE. BC_SURFACE)        ! If model.boundaries.item(item).kind /= bc_surface, skip to the next iteration.
     &        CYCLE
            IF (.NOT. ON_PLANE(CENTRE,                                   ! If not on_plane(centre, model.boundaries.item(item).plane), skip to the next iteration.
     &          MODEL%BOUNDARIES%ITEM(ITEM)%PLANE)) CYCLE
            SELECT CASE (MODEL%BOUNDARIES%ITEM(ITEM)%SURFACE)            ! Choose according to the value of model.boundaries.item(item).surface:
            CASE (1_I4)                                                  ! Case 1:
              Q = MODEL%BOUNDARIES%ITEM(ITEM)%PARAM(1)*                  ! Set q to model.boundaries.item(item).param(1)* evaluate_field(model.fields, model.boundaries.item(item).fie...
     &            EVALUATE_FIELD(MODEL%FIELDS,
     &            MODEL%BOUNDARIES%ITEM(ITEM)%FIELD_ID,
     &            PLACE%POINT_GLOBAL(1),PLACE%POINT_GLOBAL(2),
     &            PLACE%POINT_GLOBAL(3))
              AREA(ITEM) = AREA(ITEM) + WEIGHT                           ! Add weight to area(item).
            CASE (2_I4)                                                  ! Case 2:
              SUN = MODEL%BOUNDARIES%ITEM(ITEM)%PARAM(1:3)               ! Set sun to model.boundaries.item(item).param(1:3).
              Q = MODEL%BOUNDARIES%ITEM(ITEM)%PARAM(5)*                  ! Set q to model.boundaries.item(item).param(5)* model.boundaries.item(item).param(4)* max(0.0,dot_product(no...
     &            MODEL%BOUNDARIES%ITEM(ITEM)%PARAM(4)*
     &            MAX(0.0_R8,DOT_PRODUCT(NORMAL,SUN))
              IF (DOT_PRODUCT(NORMAL,SUN) .GT. 1.0E-12_R8)               ! If dot_product(normal,sun) > 1.0e-12, add weight to area(item).
     &          AREA(ITEM) = AREA(ITEM) + WEIGHT
            CASE DEFAULT                                                 ! In every other case:
!             CONVECTION: H T_INF ON THE LOAD, H N N^T ON THE MATRIX.
              AREA(ITEM) = AREA(ITEM) + WEIGHT                           ! Add weight to area(item).
              Q = MODEL%BOUNDARIES%ITEM(ITEM)%PARAM(1)*                  ! Set q to model.boundaries.item(item).param(1)* model.boundaries.item(item).param(2).
     &            MODEL%BOUNDARIES%ITEM(ITEM)%PARAM(2)
              DO K = 1_I4, COUNT                                         ! Loop k from 1 to count:
                DO L = 1_I4, COUNT                                       ! Loop l from 1 to count:
                  STIFFNESS(K,L) = STIFFNESS(K,L) + WEIGHT*              ! Add weight* model.boundaries.item(item).param(1)* value(k)*value(l) to stiffness(k,l).
     &              MODEL%BOUNDARIES%ITEM(ITEM)%PARAM(1)*
     &              VALUE(K)*VALUE(L)
                END DO                                                   ! End of the loop.
              END DO                                                     ! End of the loop.
            END SELECT                                                   ! End of the case selection.
            POWER(ITEM) = POWER(ITEM) + WEIGHT*Q                         ! Add weight*q to power(item).
            DO K = 1_I4, COUNT                                           ! Loop k from 1 to count:
              FORCE(DOF(K)) = FORCE(DOF(K)) + WEIGHT*Q*VALUE(K)          ! Add weight*q*value(k) to force(dof(k)).
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (ANY_CONVECTION) THEN                                           ! If any_convection:
        CALL SCATTER_ELEMENT(SYSTEM, DOF, STIFFNESS,                     ! Call scatter element with system, dof, stiffness, no_mass, local_status.
     &                       NO_MASS, LOCAL_STATUS)
        IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                       ! If not local_status is ok:
          CALL SET_ERROR(STATUS, 'INTEGRATE_PIECE',                      ! Record an error in status: trim(local_status.message).
     &                   TRIM(LOCAL_STATUS%MESSAGE))
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE INTEGRATE_PIECE                                     ! End of the subroutine integrate piece.

!  THE ZERO PLANE SELECTS EVERYTHING.
      LOGICAL FUNCTION ON_PLANE(POINT, PLANE)                            ! Function on plane takes point, plane.

      REAL(R8), INTENT(IN) :: POINT(3)                                   ! Input real (real64): point(3).
      REAL(R8), INTENT(IN) :: PLANE(4)                                   ! Input real (real64): plane(4).
      REAL(R8) :: SCALE                                                  ! Real (real64): scale.

      IF (ALL(PLANE .EQ. 0.0_R8)) THEN                                   ! If all(plane = 0.0):
        ON_PLANE = .TRUE.                                                ! Set the flag on_plane to true.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      SCALE = MAX(1.0_R8,ABS(PLANE(4)),SQRT(SUM(PLANE(1:3)**2))*         ! Set scale to max(1.0,abs(plane(4)),sqrt(sum(plane(1:3)**2))* sqrt(sum(point**2))).
     &        SQRT(SUM(POINT**2)))
      ON_PLANE = ABS(DOT_PRODUCT(PLANE(1:3),POINT)+PLANE(4)) .LE.        ! Set on_plane to abs(dot_product(plane(1:3),point)+plane(4)) <= 1.0e-7*scale.
     &           1.0E-7_R8*SCALE

      END FUNCTION ON_PLANE                                              ! End of the function on plane.

      END MODULE MUL2_SURFACE_LOADS                                      ! End of the module mul2 surface loads.
