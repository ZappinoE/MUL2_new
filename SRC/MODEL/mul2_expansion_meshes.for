!=======================================================================
!  LAGRANGE EXPANSION MESHES USED ON SECTIONS OR THICKNESSES.
!=======================================================================
      MODULE MUL2_EXPANSION_MESHES                                       ! Module mul2 expansion meshes begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: EXPANSION_NODE_TYPE                                ! Definition of the derived type expansion node type.
        INTEGER(I8) :: ID = 0_I8                                         ! Integer (int64): id = 0.
        REAL(R8) :: COORDINATE(3) = 0.0_R8                               ! Real (real64): coordinate(3) = 0.0.
      END TYPE EXPANSION_NODE_TYPE                                       ! End of the type definition expansion node type.

      TYPE, PUBLIC :: EXPANSION_ELEMENT_TYPE                             ! Definition of the derived type expansion element type.
        INTEGER(I8) :: ID = 0_I8                                         ! Integer (int64): id = 0.
        INTEGER(I4) :: TOPOLOGY = 0_I4                                   ! Integer (int32): topology = 0.
        INTEGER(I4) :: LAMINATION_ID = 0_I4                              ! Integer (int32): lamination_id = 0.
        INTEGER(I8), ALLOCATABLE :: NODE_ID(:)                           ! Allocatable integer (int64): node_id(:).
!  HLE ONLY: GLOBAL TERM AND SIGN OF EVERY LOCAL FUNCTION (TERM 0 =
!  FUNCTION OMITTED BY THE ORDER OF AN ADJACENT SUB-ELEMENT).
        INTEGER(I4), ALLOCATABLE :: MODE_TERM(:)                         ! Allocatable integer (int32): mode_term(:).
        REAL(R8), ALLOCATABLE :: MODE_SIGN(:)                            ! Allocatable real (real64): mode_sign(:).
!  HQ ONLY: THIRD POINT (A MESH NODE, 0 = NONE) OF EACH SIDE; A SIDE
!  WITH ONE IS THE CIRCULAR ARC THROUGH ITS VERTICES AND THAT POINT.
        INTEGER(I8) :: MID_NODE_ID(4) = 0_I8                             ! Integer (int64): mid_node_id(4) = 0.
      END TYPE EXPANSION_ELEMENT_TYPE                                    ! End of the type definition expansion element type.

      TYPE, PUBLIC :: EXPANSION_MESH_TYPE                                ! Definition of the derived type expansion mesh type.
        INTEGER(I4) :: ID = 0_I4                                         ! Integer (int32): id = 0.
        TYPE(EXPANSION_NODE_TYPE), ALLOCATABLE :: NODE(:)                ! Allocatable of type expansion_node_type: node(:).
        TYPE(EXPANSION_ELEMENT_TYPE), ALLOCATABLE :: ELEMENT(:)          ! Allocatable of type expansion_element_type: element(:).
!  HLE ONLY: NUMBER OF GLOBAL TERMS AND THEIR ORIGIN. THE FIRST TERMS
!  ARE THE VERTEX MODES; TERM_NODE(:,T) = (NODE,0) FOR A VERTEX,
!  (NODE_A,NODE_B) FOR A SIDE MODE, (0,0) FOR AN INTERNAL MODE;
!  TERM_OWNER(T) IS THE SUB-ELEMENT OF AN INTERNAL MODE.
        LOGICAL :: IS_HLE = .FALSE.                                      ! Logical: is_hle = false.
        INTEGER(I4) :: N_TERM = 0_I4                                     ! Integer (int32): n_term = 0.
        INTEGER(I4), ALLOCATABLE :: TERM_NODE(:,:)                       ! Allocatable integer (int32): term_node(:,:).
        INTEGER(I4), ALLOCATABLE :: TERM_OWNER(:)                        ! Allocatable integer (int32): term_owner(:).
!  TERM OF THE VERTEX MODE OF EVERY NODE (0 = NODE USED ONLY TO
!  DESCRIBE A CURVED SIDE, IT CARRIES NO DEGREE OF FREEDOM).
        INTEGER(I4), ALLOCATABLE :: NODE_TERM(:)                         ! Allocatable integer (int32): node_term(:).
      END TYPE EXPANSION_MESH_TYPE                                       ! End of the type definition expansion mesh type.

      TYPE, PUBLIC :: EXPANSION_DB_TYPE                                  ! Definition of the derived type expansion db type.
        TYPE(EXPANSION_MESH_TYPE), ALLOCATABLE :: ITEM(:)                ! Allocatable of type expansion_mesh_type: item(:).
      END TYPE EXPANSION_DB_TYPE                                         ! End of the type definition expansion db type.

      PUBLIC :: HAS_EXPANSION_NODE_ID                                    ! Export: has expansion node id.
      PUBLIC :: FIND_EXPANSION_INDEX                                     ! Export: find expansion index.
      PUBLIC :: EXPANSION_TERM_COUNT                                     ! Export: expansion term count.

      CONTAINS                                                           ! The procedures of the module follow.

      LOGICAL FUNCTION HAS_EXPANSION_NODE_ID(MESH, ID)                   ! Function has expansion node id takes mesh, id.

      TYPE(EXPANSION_MESH_TYPE), INTENT(IN) :: MESH                      ! Input of type expansion_mesh_type: mesh.
      INTEGER(I8), INTENT(IN) :: ID                                      ! Input integer (int64): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      HAS_EXPANSION_NODE_ID = .FALSE.                                    ! Set the flag has_expansion_node_id to false.
      IF (.NOT. ALLOCATED(MESH%NODE)) RETURN                             ! If not allocated(mesh.node), return to the caller.
      DO I = 1_I4, SIZE(MESH%NODE)                                       ! Loop i from 1 to size(mesh.node):
        IF (MESH%NODE(I)%ID .EQ. ID) THEN                                ! If mesh.node(i).id = id:
          HAS_EXPANSION_NODE_ID = .TRUE.                                 ! Set the flag has_expansion_node_id to true.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION HAS_EXPANSION_NODE_ID                                 ! End of the function has expansion node id.

      INTEGER(I4) FUNCTION FIND_EXPANSION_INDEX(DATABASE, ID)            ! Function find expansion index takes database, id.

      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: DATABASE                    ! Input of type expansion_db_type: database.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_EXPANSION_INDEX = 0_I4                                        ! Set find_expansion_index to zero.
      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (DATABASE%ITEM(I)%ID .EQ. ID) THEN                            ! If database.item(i).id = id:
          FIND_EXPANSION_INDEX = I                                       ! Set find_expansion_index to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_EXPANSION_INDEX                                  ! End of the function find expansion index.

!  NUMBER OF DEGREES OF FREEDOM PER STRUCTURAL NODE AND FIELD OF A
!  LAGRANGE OR HLE MESH.
      INTEGER(I4) FUNCTION EXPANSION_TERM_COUNT(MESH)                    ! Function expansion term count takes mesh.

      TYPE(EXPANSION_MESH_TYPE), INTENT(IN) :: MESH                      ! Input of type expansion_mesh_type: mesh.

      EXPANSION_TERM_COUNT = 0_I4                                        ! Set expansion_term_count to zero.
      IF (MESH%IS_HLE) THEN                                              ! If mesh.is_hle:
        EXPANSION_TERM_COUNT = MESH%N_TERM                               ! Set expansion_term_count to mesh.n_term.
      ELSE IF (ALLOCATED(MESH%NODE)) THEN                                ! Otherwise, if allocated(mesh.node):
        EXPANSION_TERM_COUNT = SIZE(MESH%NODE)                           ! Set expansion_term_count to the size of mesh.node.
      END IF                                                             ! End of the IF block.

      END FUNCTION EXPANSION_TERM_COUNT                                  ! End of the function expansion term count.

      END MODULE MUL2_EXPANSION_MESHES                                   ! End of the module mul2 expansion meshes.
