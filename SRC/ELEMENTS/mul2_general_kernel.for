!=======================================================================
!  ELEMENT MATRICES OF CURVED BEAMS AND SHELLS (GENERAL GEOMETRY).
!
!  THE BASIS OF A DEGREE OF FREEDOM IS PHI = N_I(XI) F_TAU(C), WITH C THE
!  POSITION IN THE EXPANSION MESH (SECTION OF THE BEAM, THICKNESS OF THE
!  SHELL). THE DISPLACEMENTS ARE GLOBAL CARTESIAN COMPONENTS, SO THE
!  ELEMENT IS A SOLID WITH THE MAP OF MUL2_GENERAL_GEOMETRY:
!      G_A = D X / D T_A  (ROWS OF THE JACOBIAN),  GRAD PHI = G^-1 D PHI/D T.
!  THE STRAINS ARE FORMED IN THE COVARIANT BASIS,
!      E~_AB = 1/2 (G_A . U,B + G_B . U,A),
!  WHERE THE MITC INTERPOLATION CAN REPLACE THE COMPONENTS THAT LOCK
!  (A SHELL: THE TRANSVERSE SHEARS AND THE MEMBRANE ONES, BEAM: AXIAL
!  AND SHEARS) BY THE VALUES AT TYING POINTS OF THE SAME POSITION IN THE
!  THICKNESS; THEN THEY ARE ROTATED TO THE FRAME OF THE MATERIAL,
!      E_L = T(Q) E~,   Q = R G^-1,   R = GLOBAL_TO_LOCAL AT THE POINT.
!  WITHOUT TYING THIS IS EXACTLY THE CARTESIAN STRAIN OF A SOLID.
!  THE ELECTRIC POTENTIAL AND THE TEMPERATURE USE THE CARTESIAN GRADIENT.
!
!    GENERAL_CONTEXT_SETUP     GEOMETRY AND TYING TABLES OF AN ELEMENT
!    GENERAL_POINT_INPUT       SHAPES AND EXPANSION FACTORS OF A POINT
!    GENERAL_POINT_COLUMNS     STRAIN COLUMNS, BASIS, GRADIENT AND
!                              DIRECTION OF ALL THE DOFS AT A POINT
!  THE ELEMENT MATRICES ARE BUILT BY THE COMMON OPERATORS OF
!  MUL2_ELEMENT_OPERATORS; THE RECOVERY USES THE SAME COLUMNS.
!=======================================================================
      MODULE MUL2_GENERAL_KERNEL                                         ! Module mul2 general kernel begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, FIND_NODE_INDEX                ! Use from module mul2 nodes: node db type, find node index.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION,             ! Use from module mul2 topologies: topology natural dimension, topology node count, topology q4, topology q9,...
     &     TOPOLOGY_NODE_COUNT, TOPOLOGY_Q4, TOPOLOGY_Q9,
     &     TOPOLOGY_B2, TOPOLOGY_B3, TOPOLOGY_B4
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE,                     ! Use from module mul2 kinematics: kinematics db type, expansion spec type, field p, field t.
     &     EXPANSION_SPEC_TYPE, FIELD_P, FIELD_T
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE,                ! Use from module mul2 expansion meshes: expansion db type, find expansion index.
     &                                 FIND_EXPANSION_INDEX
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type.
     &                             GAUSS_LAYOUT_TYPE
      USE MUL2_GAUSS_GEOMETRY, ONLY:                                     ! Use from module mul2 gauss geometry: structural geometry cache type, expansion geometry cache type, gauss g...
     &     STRUCTURAL_GEOMETRY_CACHE_TYPE,
     &     EXPANSION_GEOMETRY_CACHE_TYPE, GAUSS_GEOMETRY_TYPE
      USE MUL2_GAUSS_MATERIALS, ONLY: MATERIAL_CACHE_TYPE,               ! Use from module mul2 gauss materials: material cache type, gauss material map type, part full, generalized ...
     &                               GAUSS_MATERIAL_MAP_TYPE,
     &                               PART_FULL,
     &                               GENERALIZED_CONSTITUTIVE,
     &                               THERMAL_STRESS_COEFFICIENT
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE                         ! Use from module mul2 dof layout: dof layout type.
      USE MUL2_POINT_BASES, ONLY: EVALUATE_POINT_FACTORS                 ! Use from module mul2 point bases: evaluate point factors.
      USE MUL2_DENSE_PRODUCTS, ONLY: ACCUMULATE_UPPER_PRODUCT            ! Use from module mul2 dense products: accumulate upper product.
      USE MUL2_ELEMENT_MATRICES, ONLY: ELEMENT_MATRIX_TYPE               ! Use from module mul2 element matrices: element matrix type.
      USE MUL2_GENERAL_GEOMETRY, ONLY: GENERAL_MAP, GENERAL_FRAME        ! Use from module mul2 general geometry: general map, general frame.
      USE MUL2_SHAPE_FUNCTIONS, ONLY: EVALUATE_SHAPE                     ! Use from module mul2 shape functions: evaluate shape.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER :: MAX_BATCH = 64_I4                        ! Constant integer (int32): max_batch = 64.
      INTEGER(I4), PARAMETER :: MAX_TIE_POINT = 9_I4                     ! Constant integer (int32): max_tie_point = 9.
!  ROW R OF THE STRAIN VECTOR (XX, YY, ZZ, XZ, YZ, XY) IS THE PAIR
!  (PAIR(1,R), PAIR(2,R)) OF NATURAL OR LOCAL AXES.
      INTEGER(I4), PARAMETER :: PAIR(2,6) =                              ! Constant integer (int32): pair(2,6) = reshape([1,1, 2,2, 3,3, 1,3, 2,3, 1,2], [2,6]).
     &  RESHAPE([1,1, 2,2, 3,3, 1,3, 2,3, 1,2], [2,6])

!  ONE FAMILY OF TYING POINTS: TENSOR PRODUCT OF A LIST IN XI AND ONE IN
!  ETA; THE ROWS OF THE STRAIN THAT ARE INTERPOLATED FROM THEM.
      TYPE :: TIE_FAMILY_TYPE                                            ! Definition of the derived type tie family type.
        INTEGER(I4) :: NX = 0_I4                                         ! Integer (int32): nx = 0.
        INTEGER(I4) :: NY = 1_I4                                         ! Integer (int32): ny = 1.
        REAL(R8) :: XL(4) = 0.0_R8                                       ! Real (real64): xl(4) = 0.0.
        REAL(R8) :: YL(4) = 0.0_R8                                       ! Real (real64): yl(4) = 0.0.
        LOGICAL :: ROW(6) = .FALSE.                                      ! Logical: row(6) = false.
        REAL(R8), ALLOCATABLE :: SHAPE(:,:)                              ! Allocatable real (real64): shape(:,:).
        REAL(R8), ALLOCATABLE :: DSHAPE(:,:,:)                           ! Allocatable real (real64): dshape(:,:,:).
      END TYPE TIE_FAMILY_TYPE                                           ! End of the type definition tie family type.

!  GEOMETRY OF ONE ELEMENT AND ITS TYING TABLES.
      TYPE, PUBLIC :: GENERAL_CONTEXT_TYPE                               ! Definition of the derived type general context type.
        INTEGER(I4) :: TOPOLOGY = 0_I4                                   ! Integer (int32): topology = 0.
        INTEGER(I4) :: DS = 0_I4                                         ! Integer (int32): ds = 0.
        INTEGER(I4) :: NN = 0_I4                                         ! Integer (int32): nn = 0.
        INTEGER(I4) :: AXIS(3) = 0_I4                                    ! Integer (int32): axis(3) = 0.
        INTEGER(I4) :: N_FAMILY = 0_I4                                   ! Integer (int32): n_family = 0.
        REAL(R8) :: COORD(3,16) = 0.0_R8                                 ! Real (real64): coord(3,16) = 0.0.
        REAL(R8) :: TRIAD(3,3,16) = 0.0_R8                               ! Real (real64): triad(3,3,16) = 0.0.
        REAL(R8) :: REFERENCE(3) = 0.0_R8                                ! Real (real64): reference(3) = 0.0.
        INTEGER(I4) :: KINK(16) = 0_I4                                   ! Integer (int32): kink(16) = 0.
        TYPE(TIE_FAMILY_TYPE) :: FAMILY(3)                               ! Of type tie_family_type: family(3).
      END TYPE GENERAL_CONTEXT_TYPE                                      ! End of the type definition general context type.

      PUBLIC :: GENERAL_CONTEXT_SETUP                                    ! Export: general context setup.
      PUBLIC :: GENERAL_POINT_COLUMNS                                    ! Export: general point columns.
      PUBLIC :: GENERAL_POINT_INPUT                                      ! Export: general point input.

      CONTAINS                                                           ! The procedures of the module follow.

!  GEOMETRY (NODES, TRIADS, REFERENCE VECTOR), ACTIVE EXPANSION AXES
!  AND, WITH TYING, THE TYING POINTS OF THE ELEMENT.
      SUBROUTINE GENERAL_CONTEXT_SETUP(CTX, ELEMENT_INDEX, NODES,        ! Subroutine general context setup takes ctx, element index, nodes, elements, expansions, expansion cache, fr...
     &     ELEMENTS, EXPANSIONS, EXPANSION_CACHE, FRAMES, TYING,
     &     STATUS)

      TYPE(GENERAL_CONTEXT_TYPE), INTENT(OUT) :: CTX                     ! Output of type general_context_type: ctx.
      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      LOGICAL, INTENT(IN) :: TYING                                       ! Input logical: tying.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), PARAMETER :: A2 = 0.5773502691896258_R8                  ! Constant real (real64): a2 = 0.5773502691896258.
      REAL(R8), PARAMETER :: A3 = 0.7745966692414834_R8                  ! Constant real (real64): a3 = 0.7745966692414834.
      TYPE(STATUS_TYPE) :: ST                                            ! Of type status_type: st.
      REAL(R8) :: XI(2)                                                  ! Real (real64): xi(2).
      REAL(R8) :: NV(16)                                                 ! Real (real64): nv(16).
      REAL(R8) :: DNV(16,2)                                              ! Real (real64): dnv(16,2).
      INTEGER(I4) :: GI                                                  ! Integer (int32): gi.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: F                                                   ! Integer (int32): f.
      INTEGER(I4) :: IX                                                  ! Integer (int32): ix.
      INTEGER(I4) :: IY                                                  ! Integer (int32): iy.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      GI = FRAMES%GENERAL_INDEX(ELEMENT_INDEX)                           ! Set gi to frames.general_index(element_index).
      CTX%TOPOLOGY = ELEMENTS%ITEM(ELEMENT_INDEX)%TOPOLOGY               ! Set ctx.topology to elements.item(element_index).topology.
      CTX%DS = TOPOLOGY_NATURAL_DIMENSION(CTX%TOPOLOGY)                  ! Set ctx.ds to topology_natural_dimension(ctx.topology).
      CTX%NN = TOPOLOGY_NODE_COUNT(CTX%TOPOLOGY)                         ! Set ctx.nn to topology_node_count(ctx.topology).
      DO J = 1_I4, CTX%NN                                                ! Loop j from 1 to ctx.nn:
        K = FIND_NODE_INDEX(NODES, ELEMENTS%ITEM(ELEMENT_INDEX)%         ! Set k to find_node_index(nodes, elements.item(element_index). node_id(j)).
     &                      NODE_ID(J))
        CTX%COORD(:,J) = NODES%ITEM(K)%COORDINATE                        ! Set ctx.coord(:,j) to nodes.item(k).coordinate.
        CTX%TRIAD(:,:,J) = FRAMES%GENERAL_TRIAD(:,:,J,GI)                ! Set ctx.triad(:,:,j) to frames.general_triad(:,:,j,gi).
      END DO                                                             ! End of the loop.
      CTX%REFERENCE = FRAMES%GENERAL_REFERENCE(:,GI)                     ! Set ctx.reference to frames.general_reference(:,gi).
      IF (CTX%DS .EQ. 2_I4 .AND. ALLOCATED(FRAMES%GENERAL_KINK))         ! If ctx.ds = 2 and allocated(frames.general_kink), set ctx.kink(1:ctx.nn) to frames.general_kink(1:ctx.nn,gi).
     &  CTX%KINK(1:CTX%NN) = FRAMES%GENERAL_KINK(1:CTX%NN,GI)
      MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,                      ! Set mesh_index to find_expansion_index(expansions, elements.item(element_index).expansion_id).
     &             ELEMENTS%ITEM(ELEMENT_INDEX)%EXPANSION_ID)
      IF (MESH_INDEX .EQ. 0_I4) THEN                                     ! If mesh_index = 0:
        CALL SET_ERROR(STATUS, 'GENERAL_CONTEXT_SETUP',                  ! Record an error in status: 'EXPANSION MESH IS MISSING'.
     &                 'EXPANSION MESH IS MISSING')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CTX%AXIS = EXPANSION_CACHE%ACTIVE_AXIS(:,MESH_INDEX)               ! Set ctx.axis to expansion_cache.active_axis(:,mesh_index).
      IF (COUNT(CTX%AXIS .GT. 0_I4) .NE. 3_I4-CTX%DS) THEN               ! If count(ctx.axis > 0) /= 3-ctx.ds:
        CALL SET_ERROR(STATUS, 'GENERAL_CONTEXT_SETUP',                  ! Record an error in status: 'THE EXPANSION MESH OF A CURVED BEAM IS A SECTION (2D) AND '// 'THE ONE OF A SHE...
     &    'THE EXPANSION MESH OF A CURVED BEAM IS A SECTION (2D) AND '//
     &    'THE ONE OF A SHELL A THICKNESS (1D)')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CTX%N_FAMILY = 0_I4                                                ! Set ctx.n_family to zero.
      IF (.NOT. TYING) RETURN                                            ! If not tying, return to the caller.

      SELECT CASE (CTX%TOPOLOGY)                                         ! Choose according to the value of ctx.topology:
      CASE (TOPOLOGY_Q9)                                                 ! Case topology_q9:
!       MITC9 (BUCALEM-BATHE): E11, G13 AT XI IN {-A,A} X ETA IN
!       {-B,0,B}; E22, G23 AT XI IN {-B,0,B} X ETA IN {-A,A};
!       G12 AT {-A,A} X {-A,A} (A = 1/SQRT 3, B = SQRT 3/5).
        CTX%N_FAMILY = 3_I4                                              ! Set ctx.n_family to 3.
        CTX%FAMILY(1)%NX = 2_I4                                          ! Set ctx.family(1).nx to 2.
        CTX%FAMILY(1)%NY = 3_I4                                          ! Set ctx.family(1).ny to 3.
        CTX%FAMILY(1)%XL(1:2) = [-A2, A2]                                ! Set ctx.family(1).xl(1:2) to [-a2, a2].
        CTX%FAMILY(1)%YL(1:3) = [-A3, 0.0_R8, A3]                        ! Set ctx.family(1).yl(1:3) to [-a3, 0.0, a3].
        CTX%FAMILY(1)%ROW = [.TRUE., .FALSE., .FALSE., .TRUE.,           ! Set ctx.family(1).row to [true, false, false, true, false, false].
     &                       .FALSE., .FALSE.]
        CTX%FAMILY(2)%NX = 3_I4                                          ! Set ctx.family(2).nx to 3.
        CTX%FAMILY(2)%NY = 2_I4                                          ! Set ctx.family(2).ny to 2.
        CTX%FAMILY(2)%XL(1:3) = [-A3, 0.0_R8, A3]                        ! Set ctx.family(2).xl(1:3) to [-a3, 0.0, a3].
        CTX%FAMILY(2)%YL(1:2) = [-A2, A2]                                ! Set ctx.family(2).yl(1:2) to [-a2, a2].
        CTX%FAMILY(2)%ROW = [.FALSE., .TRUE., .FALSE., .FALSE.,          ! Set ctx.family(2).row to [false, true, false, false, true, false].
     &                       .TRUE., .FALSE.]
        CTX%FAMILY(3)%NX = 2_I4                                          ! Set ctx.family(3).nx to 2.
        CTX%FAMILY(3)%NY = 2_I4                                          ! Set ctx.family(3).ny to 2.
        CTX%FAMILY(3)%XL(1:2) = [-A2, A2]                                ! Set ctx.family(3).xl(1:2) to [-a2, a2].
        CTX%FAMILY(3)%YL(1:2) = [-A2, A2]                                ! Set ctx.family(3).yl(1:2) to [-a2, a2].
        CTX%FAMILY(3)%ROW = [.FALSE., .FALSE., .FALSE., .FALSE.,         ! Set ctx.family(3).row to [false, false, false, false, false, true].
     &                       .FALSE., .TRUE.]
      CASE (TOPOLOGY_Q4)                                                 ! Case topology_q4:
!       MITC4 (DVORKIN-BATHE): G13 AT (0,+-1), G23 AT (+-1,0).
        CTX%N_FAMILY = 2_I4                                              ! Set ctx.n_family to 2.
        CTX%FAMILY(1)%NX = 1_I4                                          ! Set ctx.family(1).nx to 1.
        CTX%FAMILY(1)%NY = 2_I4                                          ! Set ctx.family(1).ny to 2.
        CTX%FAMILY(1)%XL(1) = 0.0_R8                                     ! Set ctx.family(1).xl(1) to zero.
        CTX%FAMILY(1)%YL(1:2) = [-1.0_R8, 1.0_R8]                        ! Set ctx.family(1).yl(1:2) to [-1.0, 1.0].
        CTX%FAMILY(1)%ROW = [.FALSE., .FALSE., .FALSE., .TRUE.,          ! Set ctx.family(1).row to [false, false, false, true, false, false].
     &                       .FALSE., .FALSE.]
        CTX%FAMILY(2)%NX = 2_I4                                          ! Set ctx.family(2).nx to 2.
        CTX%FAMILY(2)%NY = 1_I4                                          ! Set ctx.family(2).ny to 1.
        CTX%FAMILY(2)%XL(1:2) = [-1.0_R8, 1.0_R8]                        ! Set ctx.family(2).xl(1:2) to [-1.0, 1.0].
        CTX%FAMILY(2)%YL(1) = 0.0_R8                                     ! Set ctx.family(2).yl(1) to zero.
        CTX%FAMILY(2)%ROW = [.FALSE., .FALSE., .FALSE., .FALSE.,         ! Set ctx.family(2).row to [false, false, false, false, true, false].
     &                       .TRUE., .FALSE.]
      CASE (TOPOLOGY_B2, TOPOLOGY_B3, TOPOLOGY_B4)                       ! Case topology_b2, topology_b3, topology_b4:
!       BEAM: E11, G12, G13 AT THE NN-1 GAUSS POINTS OF THE AXIS.
        CTX%N_FAMILY = 1_I4                                              ! Set ctx.n_family to 1.
        CTX%FAMILY(1)%NX = CTX%NN - 1_I4                                 ! Set ctx.family(1).nx to ctx.nn - 1.
        CTX%FAMILY(1)%NY = 1_I4                                          ! Set ctx.family(1).ny to 1.
        SELECT CASE (CTX%NN)                                             ! Choose according to the value of ctx.nn:
        CASE (2)                                                         ! Case 2:
          CTX%FAMILY(1)%XL(1) = 0.0_R8                                   ! Set ctx.family(1).xl(1) to zero.
        CASE (3)                                                         ! Case 3:
          CTX%FAMILY(1)%XL(1:2) = [-A2, A2]                              ! Set ctx.family(1).xl(1:2) to [-a2, a2].
        CASE DEFAULT                                                     ! In every other case:
          CTX%FAMILY(1)%XL(1:3) = [-A3, 0.0_R8, A3]                      ! Set ctx.family(1).xl(1:3) to [-a3, 0.0, a3].
        END SELECT                                                       ! End of the case selection.
        CTX%FAMILY(1)%ROW = [.TRUE., .FALSE., .FALSE., .TRUE.,           ! Set ctx.family(1).row to [true, false, false, true, false, true].
     &                       .FALSE., .TRUE.]
      CASE DEFAULT                                                       ! In every other case:
!       NO TYING TABLE (Q16): COMPATIBLE STRAINS.
        CTX%N_FAMILY = 0_I4                                              ! Set ctx.n_family to zero.
      END SELECT                                                         ! End of the case selection.
      DO F = 1_I4, CTX%N_FAMILY                                          ! Loop f from 1 to ctx.n_family:
        ALLOCATE(CTX%FAMILY(F)%SHAPE(CTX%NN,CTX%FAMILY(F)%NX*            ! Allocate memory for ctx.family(f).shape(ctx.nn,ctx.family(f).nx* ctx.family(f).ny).
     &                               CTX%FAMILY(F)%NY))
        ALLOCATE(CTX%FAMILY(F)%DSHAPE(CTX%NN,CTX%FAMILY(F)%NX*           ! Allocate memory for ctx.family(f).dshape(ctx.nn,ctx.family(f).nx* ctx.family(f).ny,2).
     &                                CTX%FAMILY(F)%NY,2))
        CTX%FAMILY(F)%SHAPE = 0.0_R8                                     ! Set ctx.family(f).shape to zero.
        CTX%FAMILY(F)%DSHAPE = 0.0_R8                                    ! Set ctx.family(f).dshape to zero.
        DO IX = 1_I4, CTX%FAMILY(F)%NX                                   ! Loop ix from 1 to ctx.family(f).nx:
          DO IY = 1_I4, CTX%FAMILY(F)%NY                                 ! Loop iy from 1 to ctx.family(f).ny:
            M = (IX-1_I4)*CTX%FAMILY(F)%NY + IY                          ! Set m to (ix-1)*ctx.family(f).ny + iy.
            XI = 0.0_R8                                                  ! Set xi to zero.
            XI(1) = CTX%FAMILY(F)%XL(IX)                                 ! Set xi(1) to ctx.family(f).xl(ix).
            IF (CTX%DS .EQ. 2_I4) XI(2) = CTX%FAMILY(F)%YL(IY)           ! If ctx.ds = 2, set xi(2) to ctx.family(f).yl(iy).
            NV = 0.0_R8                                                  ! Set nv to zero.
            DNV = 0.0_R8                                                 ! Set dnv to zero.
            CALL EVALUATE_SHAPE(CTX%TOPOLOGY, XI(1:CTX%DS),              ! Call evaluate shape with ctx.topology, xi(1:ctx.ds), nv(1:ctx.nn), dnv(1:ctx.nn,1:ctx.ds), st.
     &           NV(1:CTX%NN), DNV(1:CTX%NN,1:CTX%DS), ST)
            IF (.NOT. STATUS_IS_OK(ST)) THEN                             ! If not st is ok:
              CALL SET_ERROR(STATUS, 'GENERAL_CONTEXT_SETUP',            ! Record an error in status: trim(st.message).
     &                       TRIM(ST%MESSAGE))
              RETURN                                                     ! Return to the caller.
            END IF                                                       ! End of the IF block.
            CTX%FAMILY(F)%SHAPE(1:CTX%NN,M) = NV(1:CTX%NN)               ! Set ctx.family(f).shape(1:ctx.nn,m) to nv(1:ctx.nn).
            CTX%FAMILY(F)%DSHAPE(1:CTX%NN,M,1:2) = DNV(1:CTX%NN,1:2)     ! Set ctx.family(f).dshape(1:ctx.nn,m,1:2) to dnv(1:ctx.nn,1:2).
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE GENERAL_CONTEXT_SETUP                               ! End of the subroutine general context setup.

!  STRAIN COLUMNS OF ALL THE DOFS AT ONE POINT.
!    N, DN        STRUCTURAL SHAPES AND NATURAL DERIVATIVES (NN, DS)
!    NATURAL      STRUCTURAL NATURAL COORDINATES OF THE POINT
!    C            POSITION IN THE EXPANSION MESH (3)
!    DOF_NODE/FIELD, FV, FG   LOCAL NODE, FIELD, EXPANSION FACTOR AND
!                 ITS GRADIENT (LOCAL AXES) OF EVERY DOF
!    BCOL(1:6)    STRAIN IN THE LOCAL FRAME (BCOL(7:9) POTENTIAL
!                 GRADIENT, BCOL(10:12) TEMPERATURE GRADIENT);
!    VALUE        THE BASIS; G, R, DET GEOMETRY AT THE POINT.
      SUBROUTINE GENERAL_POINT_COLUMNS(CTX, N, DN, NATURAL, C, N_DOF,    ! Subroutine general point columns takes ctx, n, dn, natural, c, n dof, dof node, dof field, fv, fg, bcol, va...
     &     DOF_NODE, DOF_FIELD, FV, FG, BCOL, VALUE, G, R, DET, STATUS,
     &     DIRG, GRADL)

      TYPE(GENERAL_CONTEXT_TYPE), INTENT(IN) :: CTX                      ! Input of type general_context_type: ctx.
      REAL(R8), INTENT(IN) :: N(:)                                       ! Input real (real64): n(:).
      REAL(R8), INTENT(IN) :: DN(:,:)                                    ! Input real (real64): dn(:,:).
      REAL(R8), INTENT(IN) :: NATURAL(3)                                 ! Input real (real64): natural(3).
      REAL(R8), INTENT(IN) :: C(3)                                       ! Input real (real64): c(3).
      INTEGER(I4), INTENT(IN) :: N_DOF                                   ! Input integer (int32): n_dof.
      INTEGER(I4), INTENT(IN) :: DOF_NODE(:)                             ! Input integer (int32): dof_node(:).
      INTEGER(I4), INTENT(IN) :: DOF_FIELD(:)                            ! Input integer (int32): dof_field(:).
      REAL(R8), INTENT(IN) :: FV(:)                                      ! Input real (real64): fv(:).
      REAL(R8), INTENT(IN) :: FG(:,:)                                    ! Input real (real64): fg(:,:).
      REAL(R8), INTENT(OUT) :: BCOL(:,:)                                 ! Output real (real64): bcol(:,:).
      REAL(R8), INTENT(OUT) :: VALUE(:)                                  ! Output real (real64): value(:).
      REAL(R8), INTENT(OUT) :: G(3,3)                                    ! Output real (real64): g(3,3).
      REAL(R8), INTENT(OUT) :: R(3,3)                                    ! Output real (real64): r(3,3).
      REAL(R8), INTENT(OUT) :: DET                                       ! Output real (real64): det.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
!     DIRG(:,I): GLOBAL DISPLACEMENT DIRECTION OF THE DOF (A COMBINATION
!     OF THE AXES AT A KINKED NODE); GRADL(:,I): GRADIENT OF THE BASIS IN
!     THE FRAME R OF THE POINT.
      REAL(R8), INTENT(OUT), OPTIONAL :: DIRG(:,:)                       ! Output optional real (real64): dirg(:,:).
      REAL(R8), INTENT(OUT), OPTIONAL :: GRADL(:,:)                      ! Output optional real (real64): gradl(:,:).
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      REAL(R8) :: ST(3)                                                  ! Real (real64): st(3).
      REAL(R8) :: GINV(3,3)                                              ! Real (real64): ginv(3,3).
      REAL(R8) :: Q(3,3)                                                 ! Real (real64): q(3,3).
      REAL(R8) :: TM(6,6)                                                ! Real (real64): tm(6,6).
      REAL(R8) :: DPHI(3)                                                ! Real (real64): dphi(3).
      REAL(R8) :: DPHI_M(3)                                              ! Real (real64): dphi_m(3).
      REAL(R8) :: COV(6)                                                 ! Real (real64): cov(6).
      REAL(R8) :: VM(6)                                                  ! Real (real64): vm(6).
      REAL(R8) :: W_TIE(MAX_TIE_POINT,3)                                 ! Real (real64): w_tie(max_tie_point,3).
      REAL(R8) :: GM(3,3,MAX_TIE_POINT,3)                                ! Real (real64): gm(3,3,max_tie_point,3).
      REAL(R8) :: DNZ(16,2)                                              ! Real (real64): dnz(16,2).
      INTEGER(I4) :: DS                                                  ! Integer (int32): ds.
      INTEGER(I4) :: NN                                                  ! Integer (int32): nn.
      INTEGER(I4) :: F                                                   ! Integer (int32): f.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: P                                                   ! Integer (int32): p.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: ROW                                                 ! Integer (int32): row.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: I2                                                  ! Integer (int32): i2.
      INTEGER(I4) :: I3                                                  ! Integer (int32): i3.
      REAL(R8) :: NV3(3)                                                 ! Real (real64): nv3(3).
      REAL(R8) :: CB(12,3)                                               ! Real (real64): cb(12,3).
      REAL(R8) :: CD(3,3)                                                ! Real (real64): cd(3,3).
      REAL(R8) :: AM(3,3)                                                ! Real (real64): am(3,3).

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      DS = CTX%DS                                                        ! Set ds to ctx.ds.
      NN = CTX%NN                                                        ! Set nn to ctx.nn.
      CALL GENERAL_MAP(DS, NN, CTX%COORD, CTX%TRIAD, N, DN, C,           ! Call general map with ds, nn, ctx.coord, ctx.triad, n, dn, c, ctx.axis, st, g.
     &                 CTX%AXIS, ST, G)
      CALL INVERT3(G, GINV, DET)                                         ! Call invert3 with g, ginv, det.
      IF (ABS(DET) .LE. 1.0E-14_R8*MAX(1.0E-300_R8,                      ! If abs(det) <= 1.0e-14*max(1.0e-300, sqrt(sum(g*g))**3):
     &    SQRT(SUM(G*G))**3)) THEN
        CALL SET_ERROR(STATUS, 'GENERAL_POINT_COLUMNS',                  ! Record an error in status: 'DEGENERATE JACOBIAN OF A CURVED ELEMENT'.
     &                 'DEGENERATE JACOBIAN OF A CURVED ELEMENT')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DNZ = 0.0_R8                                                       ! Set dnz to zero.
      DNZ(1:NN,1:DS) = DN(1:NN,1:DS)                                     ! Set dnz(1:nn,1:ds) to dn(1:nn,1:ds).
      CALL GENERAL_FRAME(DS, NN, CTX%COORD, DNZ, G, CTX%REFERENCE, R,    ! Call general frame with ds, nn, ctx.coord, dnz, g, ctx.reference, r, local_status.
     &                   LOCAL_STATUS)
      IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                         ! If not local_status is ok:
        CALL SET_ERROR(STATUS, 'GENERAL_POINT_COLUMNS',                  ! Record an error in status: trim(local_status.message).
     &                 TRIM(LOCAL_STATUS%MESSAGE))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      Q = MATMUL(R,GINV)                                                 ! Set q to matmul(r,ginv).
      CALL BUILD_T(Q, TM)                                                ! Call build t with q, tm.

!     TYING POSITIONS: WEIGHTS AND JACOBIANS AT THE SAME C.
      DO F = 1_I4, CTX%N_FAMILY                                          ! Loop f from 1 to ctx.n_family:
        CALL TIE_WEIGHTS(CTX%FAMILY(F), DS, NATURAL, W_TIE(:,F))         ! Call tie weights with ctx.family(f), ds, natural, w_tie(:,f).
        DO M = 1_I4, CTX%FAMILY(F)%NX*CTX%FAMILY(F)%NY                   ! Loop m from 1 to ctx.family(f).nx*ctx.family(f).ny:
          CALL GENERAL_MAP(DS, NN, CTX%COORD, CTX%TRIAD,                 ! Call general map with ds, nn, ctx.coord, ctx.triad, ctx.family(f).shape(:,m), ctx.family(f).dshape(:,m,:), ...
     &         CTX%FAMILY(F)%SHAPE(:,M), CTX%FAMILY(F)%DSHAPE(:,M,:),
     &         C, CTX%AXIS, ST, GM(:,:,M,F))
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        NODE = DOF_NODE(I)                                               ! Set node to dof_node(i).
        FIELD = DOF_FIELD(I)                                             ! Set field to dof_field(i).
        VALUE(I) = N(NODE)*FV(I)                                         ! Set value(i) to n(node)*fv(i).
        DPHI = 0.0_R8                                                    ! Set dphi to zero.
        DO A = 1_I4, DS                                                  ! Loop a from 1 to ds:
          DPHI(A) = DN(NODE,A)*FV(I)                                     ! Set dphi(a) to dn(node,a)*fv(i).
        END DO                                                           ! End of the loop.
        DO M = 1_I4, 3_I4-DS                                             ! Loop m from 1 to 3-ds:
          DPHI(DS+M) = N(NODE)*FG(CTX%AXIS(M),I)                         ! Set dphi(ds+m) to n(node)*fg(ctx.axis(m),i).
        END DO                                                           ! End of the loop.
        IF (PRESENT(GRADL)) GRADL(:,I) = MATMUL(R,MATMUL(GINV,DPHI))     ! If present(gradl), set gradl(:,i) to matmul(r,matmul(ginv,dphi)).
        IF (PRESENT(DIRG)) THEN                                          ! If present(dirg):
          DIRG(:,I) = 0.0_R8                                             ! Set dirg(:,i) to zero.
          IF (FIELD .LE. 3_I4) DIRG(FIELD,I) = 1.0_R8                    ! If field <= 3, set dirg(field,i) to 1.0.
        END IF                                                           ! End of the IF block.
        BCOL(:,I) = 0.0_R8                                               ! Set bcol(:,i) to zero.
        IF (FIELD .LE. 3_I4) THEN                                        ! If field <= 3:
          CALL COVARIANT_ROWS(DPHI, G, FIELD, COV)                       ! Call covariant rows with dphi, g, field, cov.
          DO F = 1_I4, CTX%N_FAMILY                                      ! Loop f from 1 to ctx.n_family:
            DO ROW = 1_I4, 6_I4                                          ! Loop row from 1 to 6:
              IF (CTX%FAMILY(F)%ROW(ROW)) COV(ROW) = 0.0_R8              ! If ctx.family(f).row(row), set cov(row) to zero.
            END DO                                                       ! End of the loop.
            DO M = 1_I4, CTX%FAMILY(F)%NX*CTX%FAMILY(F)%NY               ! Loop m from 1 to ctx.family(f).nx*ctx.family(f).ny:
              DPHI_M = 0.0_R8                                            ! Set dphi_m to zero.
              DO A = 1_I4, DS                                            ! Loop a from 1 to ds:
                DPHI_M(A) = CTX%FAMILY(F)%DSHAPE(NODE,M,A)*FV(I)         ! Set dphi_m(a) to ctx.family(f).dshape(node,m,a)*fv(i).
              END DO                                                     ! End of the loop.
              DO P = 1_I4, 3_I4-DS                                       ! Loop p from 1 to 3-ds:
                DPHI_M(DS+P) = CTX%FAMILY(F)%SHAPE(NODE,M)*              ! Set dphi_m(ds+p) to ctx.family(f).shape(node,m)* fg(ctx.axis(p),i).
     &                         FG(CTX%AXIS(P),I)
              END DO                                                     ! End of the loop.
              CALL COVARIANT_ROWS(DPHI_M, GM(:,:,M,F), FIELD, VM)        ! Call covariant rows with dphi_m, gm(:,:,m,f), field, vm.
              DO ROW = 1_I4, 6_I4                                        ! Loop row from 1 to 6:
                IF (CTX%FAMILY(F)%ROW(ROW)) COV(ROW) = COV(ROW) +        ! If ctx.family(f).row(row), add w_tie(m,f)*vm(row) to cov(row).
     &            W_TIE(M,F)*VM(ROW)
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
          BCOL(1:6,I) = MATMUL(TM,COV)                                   ! Set bcol(1:6,i) to matmul(tm,cov).
        ELSE IF (FIELD .EQ. FIELD_P) THEN                                ! Otherwise, if field = field_p:
          BCOL(7:9,I) = MATMUL(R,MATMUL(GINV,DPHI))                      ! Set bcol(7:9,i) to matmul(r,matmul(ginv,dphi)).
          VALUE(I) = 0.0_R8                                              ! Set value(i) to zero.
        ELSE                                                             ! Otherwise:
          BCOL(10:12,I) = MATMUL(R,MATMUL(GINV,DPHI))                    ! Set bcol(10:12,i) to matmul(r,matmul(ginv,dphi)).
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

!     KINKED NODES: THE FIRST-ORDER TERM (D U / D C) OF THE ELEMENT IS
!     THE ROTATION OMEGA OF THE NODE ACTING ON ITS OWN DIRECTOR,
!     T1 = OMEGA X A3, SO THAT THE ROTATION (NOT THE GRADIENT ALONG
!     DIFFERENT DIRECTORS) IS CONTINUOUS THROUGH THE KINK.
      IF (DS .EQ. 2_I4) THEN                                             ! If ds = 2:
        DO I = 1_I4, N_DOF                                               ! Loop i from 1 to n_dof:
          NODE = DOF_NODE(I)                                             ! Set node to dof_node(i).
          IF (CTX%KINK(NODE) .EQ. 0_I4) CYCLE                            ! If ctx.kink(node) = 0, skip to the next iteration.
          IF (DOF_FIELD(I) .NE. 1_I4) CYCLE                              ! If dof_field(i) /= 1, skip to the next iteration.
          IF (ABS(FG(CTX%AXIS(1),I)-1.0_R8) .GT. 1.0E-9_R8 .OR.          ! If abs(fg(ctx.axis(1),i)-1.0) > 1.0e-9 or abs(fv(i)-c(ctx.axis(1))) > 1.0e-9, skip to the next iteration.
     &        ABS(FV(I)-C(CTX%AXIS(1))) .GT. 1.0E-9_R8) CYCLE
          I2 = 0_I4                                                      ! Set i2 to zero.
          I3 = 0_I4                                                      ! Set i3 to zero.
          DO A = 1_I4, N_DOF                                             ! Loop a from 1 to n_dof:
            IF (DOF_NODE(A) .NE. NODE) CYCLE                             ! If dof_node(a) /= node, skip to the next iteration.
            IF (ABS(FG(CTX%AXIS(1),A)-1.0_R8) .GT. 1.0E-9_R8 .OR.        ! If abs(fg(ctx.axis(1),a)-1.0) > 1.0e-9 or abs(fv(a)-c(ctx.axis(1))) > 1.0e-9, skip to the next iteration.
     &          ABS(FV(A)-C(CTX%AXIS(1))) .GT. 1.0E-9_R8) CYCLE
            IF (DOF_FIELD(A) .EQ. 2_I4) I2 = A                           ! If dof_field(a) = 2, set i2 to a.
            IF (DOF_FIELD(A) .EQ. 3_I4) I3 = A                           ! If dof_field(a) = 3, set i3 to a.
          END DO                                                         ! End of the loop.
          IF (I2 .EQ. 0_I4 .OR. I3 .EQ. 0_I4) CYCLE                      ! If i2 = 0 or i3 = 0, skip to the next iteration.
          NV3 = CTX%TRIAD(:,3,NODE)                                      ! Set nv3 to ctx.triad(:,3,node).
          CB(:,1) = BCOL(:,I)                                            ! Set cb(:,1) to bcol(:,i).
          CB(:,2) = BCOL(:,I2)                                           ! Set cb(:,2) to bcol(:,i2).
          CB(:,3) = BCOL(:,I3)                                           ! Set cb(:,3) to bcol(:,i3).
          AM = 0.0_R8                                                    ! Set am to zero.
          IF (CTX%KINK(NODE) .LT. 0_I4) THEN                             ! If ctx.kink(node) < 0:
            AM(1,1) = -1.0_R8                                            ! Set am(1,1) to -1.0.
            AM(2,2) = -1.0_R8                                            ! Set am(2,2) to -1.0.
            AM(3,3) = -1.0_R8                                            ! Set am(3,3) to -1.0.
          ELSE                                                           ! Otherwise:
!           D1_C = EPS(C,J,M) OMEGA_J NV3_M
          AM(1,2) = NV3(3)                                               ! Set am(1,2) to nv3(3).
          AM(1,3) = -NV3(2)                                              ! Set am(1,3) to -nv3(2).
          AM(2,1) = -NV3(3)                                              ! Set am(2,1) to -nv3(3).
          AM(2,3) = NV3(1)                                               ! Set am(2,3) to nv3(1).
          AM(3,1) = NV3(2)                                               ! Set am(3,1) to nv3(2).
          AM(3,2) = -NV3(1)                                              ! Set am(3,2) to -nv3(1).
          END IF                                                         ! End of the IF block.
          BCOL(:,I) = MATMUL(CB,AM(:,1))                                 ! Set bcol(:,i) to matmul(cb,am(:,1)).
          BCOL(:,I2) = MATMUL(CB,AM(:,2))                                ! Set bcol(:,i2) to matmul(cb,am(:,2)).
          BCOL(:,I3) = MATMUL(CB,AM(:,3))                                ! Set bcol(:,i3) to matmul(cb,am(:,3)).
!         THE BASIS (VALUE) STAYS THE SCALAR N F OF THE TRIPLE; THE
!         DIRECTIONS OF THE NEW DOFS ARE THE COMBINATIONS OF THE AXES.
          IF (PRESENT(DIRG)) THEN                                        ! If present(dirg):
            CD(:,1) = DIRG(:,I)                                          ! Set cd(:,1) to dirg(:,i).
            CD(:,2) = DIRG(:,I2)                                         ! Set cd(:,2) to dirg(:,i2).
            CD(:,3) = DIRG(:,I3)                                         ! Set cd(:,3) to dirg(:,i3).
            DIRG(:,I) = MATMUL(CD,AM(:,1))                               ! Set dirg(:,i) to matmul(cd,am(:,1)).
            DIRG(:,I2) = MATMUL(CD,AM(:,2))                              ! Set dirg(:,i2) to matmul(cd,am(:,2)).
            DIRG(:,I3) = MATMUL(CD,AM(:,3))                              ! Set dirg(:,i3) to matmul(cd,am(:,3)).
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE GENERAL_POINT_COLUMNS                               ! End of the subroutine general point columns.

!  STRUCTURAL SHAPES, EXPANSION POSITION AND EXPANSION FACTORS OF EVERY
!  DOF AT ONE POINT (ONE EVALUATION PER DISTINCT KINEMATIC, FIELD, TERM;
!  F_VALUE, F_GRAD, F_DONE ARE THE WORK TABLES OF THE CALLER).
      SUBROUTINE GENERAL_POINT_INPUT(POINT, CTX, MATRICES, KINEMATICS,   ! Subroutine general point input takes point, ctx, matrices, kinematics, elements, expansions, rules, gauss l...
     &     ELEMENTS, EXPANSIONS, RULES, GAUSS_LAYOUT, STRUCTURAL_CACHE,
     &     EXPANSION_CACHE, GEOMETRY, F_VALUE, F_GRAD, F_DONE, N, DN,
     &     NATURAL, C, EXP_INDEX, FV, FG, STATUS)

      INTEGER(I8), INTENT(IN) :: POINT                                   ! Input integer (int64): point.
      TYPE(GENERAL_CONTEXT_TYPE), INTENT(IN) :: CTX                      ! Input of type general_context_type: ctx.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(IN) :: MATRICES                  ! Input of type element_matrix_type: matrices.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      REAL(R8), INTENT(INOUT) :: F_VALUE(:,:,:)                          ! In/out real (real64): f_value(:,:,:).
      REAL(R8), INTENT(INOUT) :: F_GRAD(:,:,:,:)                         ! In/out real (real64): f_grad(:,:,:,:).
      LOGICAL, INTENT(INOUT) :: F_DONE(:,:,:)                            ! In/out logical: f_done(:,:,:).
      REAL(R8), INTENT(OUT) :: N(16)                                     ! Output real (real64): n(16).
      REAL(R8), INTENT(OUT) :: DN(16,2)                                  ! Output real (real64): dn(16,2).
      REAL(R8), INTENT(OUT) :: NATURAL(3)                                ! Output real (real64): natural(3).
      REAL(R8), INTENT(OUT) :: C(3)                                      ! Output real (real64): c(3).
      INTEGER(I8), INTENT(OUT) :: EXP_INDEX                              ! Output integer (int64): exp_index.
      REAL(R8), INTENT(OUT) :: FV(:)                                     ! Output real (real64): fv(:).
      REAL(R8), INTENT(OUT) :: FG(:,:)                                   ! Output real (real64): fg(:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                  ! Of type expansion_spec_type: spec.
      REAL(R8) :: PROBE                                                  ! Real (real64): probe.
      REAL(R8) :: ST(3)                                                  ! Real (real64): st(3).
      REAL(R8) :: ONE_VALUE                                              ! Real (real64): one_value.
      REAL(R8) :: ONE_GRAD(3)                                            ! Real (real64): one_grad(3).
      INTEGER(I4) :: RULE_INDEX                                          ! Integer (int32): rule_index.
      INTEGER(I4) :: POINT_INDEX                                         ! Integer (int32): point_index.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: KIN                                                 ! Integer (int32): kin.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      RULE_INDEX = GAUSS_LAYOUT%STRUCTURAL_RULE_INDEX(POINT)             ! Set rule_index to gauss_layout.structural_rule_index(point).
      POINT_INDEX = GAUSS_LAYOUT%STRUCTURAL_POINT_INDEX(POINT)           ! Set point_index to gauss_layout.structural_point_index(point).
      N = 0.0_R8                                                         ! Set n to zero.
      DN = 0.0_R8                                                        ! Set dn to zero.
      N(1:CTX%NN) = RULES%ITEM(RULE_INDEX)%SHAPE(1:CTX%NN,POINT_INDEX)   ! Set n(1:ctx.nn) to rules.item(rule_index).shape(1:ctx.nn,point_index).
      DN(1:CTX%NN,1:CTX%DS) = RULES%ITEM(RULE_INDEX)%DERIVATIVE(         ! Set dn(1:ctx.nn,1:ctx.ds) to rules.item(rule_index).derivative( 1:ctx.nn,1:ctx.ds,point_index).
     &  1:CTX%NN,1:CTX%DS,POINT_INDEX)
      NATURAL = RULES%ITEM(RULE_INDEX)%COORDINATE(POINT_INDEX,1:3)       ! Set natural to rules.item(rule_index).coordinate(point_index,1:3).
      EXP_INDEX = GEOMETRY%EXPANSION_CACHE_INDEX(POINT)                  ! Set exp_index to geometry.expansion_cache_index(point).
      C = EXPANSION_CACHE%COORDINATE_LOCAL(:,EXP_INDEX)                  ! Set c to expansion_cache.coordinate_local(:,exp_index).
      F_DONE = .FALSE.                                                   ! Set the flag f_done to false.
      DO I = 1_I4, MATRICES%LOCAL_DOF_COUNT                              ! Loop i from 1 to matrices.local_dof_count:
        NODE = MATRICES%STRUCTURAL_NODE(I)                               ! Set node to matrices.structural_node(i).
        FIELD = MATRICES%FIELD(I)                                        ! Set field to matrices.field(i).
        TERM = MATRICES%TERM(I)                                          ! Set term to matrices.term(i).
        KIN = MATRICES%KINEMATIC_INDEX(NODE)                             ! Set kin to matrices.kinematic_index(node).
        IF (.NOT. F_DONE(TERM,FIELD,KIN)) THEN                           ! If not f_done(term,field,kin):
          SPEC = KINEMATICS%ITEM(KIN)%FIELD(FIELD)                       ! Set spec to kinematics.item(kin).field(field).
          CALL EVALUATE_POINT_FACTORS(POINT, NODE, TERM, SPEC,           ! Call evaluate point factors with point, node, term, spec, elements, expansions, rules, gauss_layout, struct...
     &         ELEMENTS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &         STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, PROBE,
     &         ST, ONE_VALUE, ONE_GRAD, STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          F_VALUE(TERM,FIELD,KIN) = ONE_VALUE                            ! Set f_value(term,field,kin) to one_value.
          F_GRAD(:,TERM,FIELD,KIN) = ONE_GRAD                            ! Set f_grad(:,term,field,kin) to one_grad.
          F_DONE(TERM,FIELD,KIN) = .TRUE.                                ! Set the flag f_done(term,field,kin) to true.
        END IF                                                           ! End of the IF block.
        FV(I) = F_VALUE(TERM,FIELD,KIN)                                  ! Set fv(i) to f_value(term,field,kin).
        FG(:,I) = F_GRAD(:,TERM,FIELD,KIN)                               ! Set fg(:,i) to f_grad(:,term,field,kin).
      END DO                                                             ! End of the loop.

      END SUBROUTINE GENERAL_POINT_INPUT                                 ! End of the subroutine general point input.

!  WEIGHTS OF THE TYING POINTS OF A FAMILY AT A NATURAL POINT.
      SUBROUTINE TIE_WEIGHTS(FAM, DS, NAT, W)                            ! Subroutine tie weights takes fam, ds, nat, w.

      TYPE(TIE_FAMILY_TYPE), INTENT(IN) :: FAM                           ! Input of type tie_family_type: fam.
      INTEGER(I4), INTENT(IN) :: DS                                      ! Input integer (int32): ds.
      REAL(R8), INTENT(IN) :: NAT(3)                                     ! Input real (real64): nat(3).
      REAL(R8), INTENT(OUT) :: W(MAX_TIE_POINT)                          ! Output real (real64): w(max_tie_point).
      INTEGER(I4) :: IX                                                  ! Integer (int32): ix.
      INTEGER(I4) :: IY                                                  ! Integer (int32): iy.

      W = 0.0_R8                                                         ! Set w to zero.
      DO IX = 1_I4, FAM%NX                                               ! Loop ix from 1 to fam.nx:
        DO IY = 1_I4, FAM%NY                                             ! Loop iy from 1 to fam.ny:
          W((IX-1_I4)*FAM%NY+IY) = LAGRANGE(FAM%XL, FAM%NX, IX, NAT(1))  ! Set w((ix-1)*fam.ny+iy) to lagrange(fam.xl, fam.nx, ix, nat(1)).
          IF (DS .EQ. 2_I4) W((IX-1_I4)*FAM%NY+IY) =                     ! If ds = 2, multiply w((ix-1)*fam.ny+iy) by lagrange(fam.yl, fam.ny, iy, nat(2)).
     &      W((IX-1_I4)*FAM%NY+IY)*LAGRANGE(FAM%YL, FAM%NY, IY, NAT(2))
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE TIE_WEIGHTS                                         ! End of the subroutine tie weights.

!  COVARIANT STRAIN ROWS (11, 22, 33, 13, 23, 12; ENGINEERING SHEARS) OF
!  A DISPLACEMENT IN THE GLOBAL DIRECTION F WITH SCALAR BASIS DERIVATIVES
!  DPHI = D PHI / D T.
      SUBROUTINE COVARIANT_ROWS(DPHI, G, F, V)                           ! Subroutine covariant rows takes dphi, g, f, v.

      REAL(R8), INTENT(IN) :: DPHI(3)                                    ! Input real (real64): dphi(3).
      REAL(R8), INTENT(IN) :: G(3,3)                                     ! Input real (real64): g(3,3).
      INTEGER(I4), INTENT(IN) :: F                                       ! Input integer (int32): f.
      REAL(R8), INTENT(OUT) :: V(6)                                      ! Output real (real64): v(6).
      INTEGER(I4) :: R                                                   ! Integer (int32): r.
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: B                                                   ! Integer (int32): b.

      DO R = 1_I4, 6_I4                                                  ! Loop r from 1 to 6:
        A = PAIR(1,R)                                                    ! Set a to pair(1,r).
        B = PAIR(2,R)                                                    ! Set b to pair(2,r).
        IF (A .EQ. B) THEN                                               ! If a = b:
          V(R) = DPHI(A)*G(A,F)                                          ! Set v(r) to dphi(a)*g(a,f).
        ELSE                                                             ! Otherwise:
          V(R) = DPHI(B)*G(A,F) + DPHI(A)*G(B,F)                         ! Set v(r) to dphi(b)*g(a,f) + dphi(a)*g(b,f).
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE COVARIANT_ROWS                                      ! End of the subroutine covariant rows.

!  6 X 6 MATRIX THAT TURNS THE COVARIANT ENGINEERING STRAINS INTO THE
!  ONES OF THE LOCAL FRAME, Q(M,A) = E_M . G^A.
      SUBROUTINE BUILD_T(Q, T)                                           ! Subroutine build t takes q, t.

      REAL(R8), INTENT(IN) :: Q(3,3)                                     ! Input real (real64): q(3,3).
      REAL(R8), INTENT(OUT) :: T(6,6)                                    ! Output real (real64): t(6,6).
      INTEGER(I4) :: R                                                   ! Integer (int32): r.
      INTEGER(I4) :: S                                                   ! Integer (int32): s.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: B                                                   ! Integer (int32): b.

      DO R = 1_I4, 6_I4                                                  ! Loop r from 1 to 6:
        M = PAIR(1,R)                                                    ! Set m to pair(1,r).
        N = PAIR(2,R)                                                    ! Set n to pair(2,r).
        DO S = 1_I4, 6_I4                                                ! Loop s from 1 to 6:
          A = PAIR(1,S)                                                  ! Set a to pair(1,s).
          B = PAIR(2,S)                                                  ! Set b to pair(2,s).
          IF (A .EQ. B) THEN                                             ! If a = b:
            T(R,S) = Q(M,A)*Q(N,A)                                       ! Set t(r,s) to q(m,a)*q(n,a).
          ELSE                                                           ! Otherwise:
            T(R,S) = 0.5_R8*(Q(M,A)*Q(N,B)+Q(M,B)*Q(N,A))                ! Set t(r,s) to 0.5*(q(m,a)*q(n,b)+q(m,b)*q(n,a)).
          END IF                                                         ! End of the IF block.
          IF (M .NE. N) T(R,S) = 2.0_R8*T(R,S)                           ! If m /= n, set t(r,s) to 2.0*t(r,s).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_T                                             ! End of the subroutine build t.

!  LAGRANGE POLYNOMIAL I OF THE N POINTS X(1:N) AT XI.
      REAL(R8) FUNCTION LAGRANGE(X, N, I, XI)                            ! Function lagrange takes x, n, i, xi.

      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      INTEGER(I4), INTENT(IN) :: N                                       ! Input integer (int32): n.
      INTEGER(I4), INTENT(IN) :: I                                       ! Input integer (int32): i.
      REAL(R8), INTENT(IN) :: XI                                         ! Input real (real64): xi.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      LAGRANGE = 1.0_R8                                                  ! Set lagrange to 1.0.
      DO J = 1_I4, N                                                     ! Loop j from 1 to n:
        IF (J .EQ. I) CYCLE                                              ! If j = i, skip to the next iteration.
        LAGRANGE = LAGRANGE*(XI-X(J))/(X(I)-X(J))                        ! Multiply lagrange by (xi-x(j))/(x(i)-x(j)).
      END DO                                                             ! End of the loop.

      END FUNCTION LAGRANGE                                              ! End of the function lagrange.

      SUBROUTINE INVERT3(A, B, DET)                                      ! Subroutine invert3 takes a, b, det.

      REAL(R8), INTENT(IN) :: A(3,3)                                     ! Input real (real64): a(3,3).
      REAL(R8), INTENT(OUT) :: B(3,3)                                    ! Output real (real64): b(3,3).
      REAL(R8), INTENT(OUT) :: DET                                       ! Output real (real64): det.

      B(1,1) = A(2,2)*A(3,3) - A(2,3)*A(3,2)                             ! Set b(1,1) to a(2,2)*a(3,3) - a(2,3)*a(3,2).
      B(1,2) = A(1,3)*A(3,2) - A(1,2)*A(3,3)                             ! Set b(1,2) to a(1,3)*a(3,2) - a(1,2)*a(3,3).
      B(1,3) = A(1,2)*A(2,3) - A(1,3)*A(2,2)                             ! Set b(1,3) to a(1,2)*a(2,3) - a(1,3)*a(2,2).
      B(2,1) = A(2,3)*A(3,1) - A(2,1)*A(3,3)                             ! Set b(2,1) to a(2,3)*a(3,1) - a(2,1)*a(3,3).
      B(2,2) = A(1,1)*A(3,3) - A(1,3)*A(3,1)                             ! Set b(2,2) to a(1,1)*a(3,3) - a(1,3)*a(3,1).
      B(2,3) = A(1,3)*A(2,1) - A(1,1)*A(2,3)                             ! Set b(2,3) to a(1,3)*a(2,1) - a(1,1)*a(2,3).
      B(3,1) = A(2,1)*A(3,2) - A(2,2)*A(3,1)                             ! Set b(3,1) to a(2,1)*a(3,2) - a(2,2)*a(3,1).
      B(3,2) = A(1,2)*A(3,1) - A(1,1)*A(3,2)                             ! Set b(3,2) to a(1,2)*a(3,1) - a(1,1)*a(3,2).
      B(3,3) = A(1,1)*A(2,2) - A(1,2)*A(2,1)                             ! Set b(3,3) to a(1,1)*a(2,2) - a(1,2)*a(2,1).
      DET = A(1,1)*B(1,1) + A(1,2)*B(2,1) + A(1,3)*B(3,1)                ! Set det to a(1,1)*b(1,1) + a(1,2)*b(2,1) + a(1,3)*b(3,1).
      IF (ABS(DET) .GT. 0.0_R8) B = B/DET                                ! If abs(det) > 0.0, divide b by det.

      END SUBROUTINE INVERT3                                             ! End of the subroutine invert3.

      END MODULE MUL2_GENERAL_KERNEL                                     ! End of the module mul2 general kernel.
