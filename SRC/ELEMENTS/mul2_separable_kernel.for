!=======================================================================
!  SEPARABLE CUF ELEMENT MATRICES.
!
!  THE COMBINED BASIS OF A DOF IS N_I(P) F_T(Q): A STRUCTURAL FACTOR
!  (STRUCTURAL POINT P) TIMES AN EXPANSION FACTOR (EXPANSION POINT Q OF
!  A SUB-ELEMENT E). IN THE ELEMENT FRAME, WITH S THE STRUCTURAL AXES,
!
!      DPHI/DD = SIGMA_D(P,I) * EPS_D(Q,T)
!      SIGMA_D = DN/DD  (D IN S),   N        (D NOT IN S)
!      EPS_D   = F      (D IN S),   DF/DD    (D NOT IN S)
!
!  AND THE STRAIN COLUMN IS B(:,R) = SUM_D W_D,F(R) SIGMA_D EPS_D, WITH
!  W_D,F = B_OPERATOR(E_D) * FRAME(:,F). TIED (MITC) ROWS REPLACE
!  SIGMA BY ITS TENSOR-LAGRANGE INTERPOLATION FROM THE TYING POINTS.
!  WITH A CONSTITUTIVE MATRIX C_E CONSTANT INSIDE EACH SUB-ELEMENT E,
!
!   K((I,T,F),(J,S,H)) = SUM_E SUM_D,D' LAMBDA_E,DD'(I,J,F,H)
!                        * EM_E,DD'(T,S)
!   LAMBDA = SUM_R,R' C_E(R,R') W_D,F(R) W_D',H(R') SM_DD'^CC'(I,J)
!   SM_DD'^CC'(I,J) = SUM_P W_P SIGMA_D^C(P,I) SIGMA_D'^C'(P,J)
!   EM_E,DD'(T,S)   = SUM_Q W_Q EPS_D(Q,T) EPS_D'(Q,S)
!
!  SO THE COST IS ADDITIVE IN THE STRUCTURAL AND EXPANSION POINTS
!  INSTEAD OF THEIR PRODUCT. THE RESULT IS ALGEBRAICALLY THE SAME AS
!  THE POINT-BY-POINT KERNEL (ROUND-OFF ONLY).
!=======================================================================
      MODULE MUL2_SEPARABLE_KERNEL                                       ! Module mul2 separable kernel begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       STATUS_IS_OK
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION              ! Use from module mul2 topologies: topology natural dimension.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE,                     ! Use from module mul2 kinematics: kinematics db type, expansion spec type.
     &                           EXPANSION_SPEC_TYPE
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE,                ! Use from module mul2 expansion meshes: expansion db type, find expansion index.
     &                                 FIND_EXPANSION_INDEX
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type.
     &                             GAUSS_LAYOUT_TYPE
      USE MUL2_GAUSS_GEOMETRY, ONLY:                                     ! Use from module mul2 gauss geometry: structural geometry cache type, expansion geometry cache type, gauss g...
     &     STRUCTURAL_GEOMETRY_CACHE_TYPE,
     &     EXPANSION_GEOMETRY_CACHE_TYPE, GAUSS_GEOMETRY_TYPE
      USE MUL2_GAUSS_MATERIALS, ONLY: MATERIAL_CACHE_TYPE,               ! Use from module mul2 gauss materials: material cache type, gauss material map type, stiffness part, part full.
     &                               GAUSS_MATERIAL_MAP_TYPE,
     &                               STIFFNESS_PART, PART_FULL
      USE MUL2_POINT_BASES, ONLY: EVALUATE_POINT_FACTORS                 ! Use from module mul2 point bases: evaluate point factors.
      USE MUL2_MITC, ONLY: MITC_DATA_TYPE, INTERPOLATION_WEIGHT          ! Use from module mul2 mitc: mitc data type, interpolation weight.
      USE MUL2_LINEAR_KINEMATICS, ONLY: BUILD_DISPLACEMENT_OPERATOR      ! Use from module mul2 linear kinematics: build displacement operator.
      USE MUL2_DENSE_PRODUCTS, ONLY: ACCUMULATE_PRODUCT                  ! Use from module mul2 dense products: accumulate product.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!  EXPANSION FUNCTIONS OF ONE DISTINCT KINEMATIC SPECIFICATION AT ALL
!  EXPANSION POINTS OF THE ELEMENT: EPS(POINT,TERM,0:3), 0 = VALUE.
      TYPE :: SPEC_BASIS_TYPE                                            ! Definition of the derived type spec basis type.
        TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                ! Of type expansion_spec_type: spec.
        INTEGER(I4) :: TERMS = 0_I4                                      ! Integer (int32): terms = 0.
        REAL(R8), ALLOCATABLE :: EPS(:,:,:)                              ! Allocatable real (real64): eps(:,:,:).
      END TYPE SPEC_BASIS_TYPE                                           ! End of the type definition spec basis type.

!  EM(T,S,K,E): K = 3*(D-1)+D' FOR D,D' = 1..3 AND K = 10 FOR F F.
      TYPE :: EXPANSION_PRODUCT_TYPE                                     ! Definition of the derived type expansion product type.
        LOGICAL :: READY = .FALSE.                                       ! Logical: ready = false.
        REAL(R8), ALLOCATABLE :: EM(:,:,:,:)                             ! Allocatable real (real64): em(:,:,:,:).
      END TYPE EXPANSION_PRODUCT_TYPE                                    ! End of the type definition expansion product type.

      PUBLIC :: BUILD_SEPARABLE_MATRICES                                 ! Export: build separable matrices.

      CONTAINS                                                           ! The procedures of the module follow.

!  APPLICABLE = .FALSE. LEAVES THE MATRICES UNTOUCHED (THE CALLER THEN
!  USES THE POINT-BY-POINT KERNEL). FIELD/STRUCTURAL_NODE/TERM ARE THE
!  LOCAL DOF LISTS (NODE-MAJOR, THEN FIELD, THEN TERM).
      SUBROUTINE BUILD_SEPARABLE_MATRICES(ELEMENT_INDEX, ELEMENTS,       ! Subroutine build separable matrices takes element index, elements, kinematics, expansions, rules, layout, s...
     &     KINEMATICS, EXPANSIONS, RULES, LAYOUT, STRUCTURAL_CACHE,
     &     EXPANSION_CACHE, GEOMETRY, FRAMES, MATERIAL_CACHE,
     &     MATERIAL_MAP, MITC_DATA, FIELD, STRUCTURAL_NODE, TERM,
     &     KINEMATIC_INDEX, WITH_MASS, STIFFNESS, MASS, APPLICABLE,
     &     STATUS, PART, WITH_STIFFNESS)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: LAYOUT                      ! Input of type gauss_layout_type: layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: MATERIAL_CACHE            ! Input of type material_cache_type: material_cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(IN) :: MATERIAL_MAP          ! Input of type gauss_material_map_type: material_map.
      TYPE(MITC_DATA_TYPE), INTENT(IN) :: MITC_DATA                      ! Input of type mitc_data_type: mitc_data.
      INTEGER(I4), INTENT(IN) :: FIELD(:)                                ! Input integer (int32): field(:).
      INTEGER(I4), INTENT(IN) :: STRUCTURAL_NODE(:)                      ! Input integer (int32): structural_node(:).
      INTEGER(I4), INTENT(IN) :: TERM(:)                                 ! Input integer (int32): term(:).
      INTEGER(I4), INTENT(IN) :: KINEMATIC_INDEX(:)                      ! Input integer (int32): kinematic_index(:).
      LOGICAL, INTENT(IN) :: WITH_MASS                                   ! Input logical: with_mass.
      REAL(R8), INTENT(INOUT) :: STIFFNESS(:,:)                          ! In/out real (real64): stiffness(:,:).
      REAL(R8), INTENT(INOUT) :: MASS(:,:)                               ! In/out real (real64): mass(:,:).
      LOGICAL, INTENT(OUT) :: APPLICABLE                                 ! Output logical: applicable.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4), INTENT(IN), OPTIONAL :: PART                          ! Input optional integer (int32): part.
      LOGICAL, INTENT(IN), OPTIONAL :: WITH_STIFFNESS                    ! Input optional logical: with_stiffness.
      REAL(R8) :: CMAT(6,6)                                              ! Real (real64): cmat(6,6).
      INTEGER(I4) :: CPART                                               ! Integer (int32): cpart.
      LOGICAL :: DO_STIFFNESS                                            ! Logical: do_stiffness.
      TYPE(SPEC_BASIS_TYPE), ALLOCATABLE :: BASIS(:)                     ! Allocatable of type spec_basis_type: basis(:).
      TYPE(EXPANSION_PRODUCT_TYPE), ALLOCATABLE :: PRODUCT(:,:)          ! Allocatable of type expansion_product_type: product(:,:).
      REAL(R8), ALLOCATABLE :: SW(:)                                     ! Allocatable real (real64): sw(:).
      REAL(R8), ALLOCATABLE :: SN(:,:)                                   ! Allocatable real (real64): sn(:,:).
      REAL(R8), ALLOCATABLE :: SG(:,:,:)                                 ! Allocatable real (real64): sg(:,:,:).
      REAL(R8), ALLOCATABLE :: SIGMA(:,:,:,:)                            ! Allocatable real (real64): sigma(:,:,:,:).
      REAL(R8), ALLOCATABLE :: SM(:,:,:,:,:,:)                           ! Allocatable real (real64): sm(:,:,:,:,:,:).
      REAL(R8), ALLOCATABLE :: SNN(:,:)                                  ! Allocatable real (real64): snn(:,:).
      REAL(R8), ALLOCATABLE :: WQ(:)                                     ! Allocatable real (real64): wq(:).
      REAL(R8), ALLOCATABLE :: LAMBDA(:,:,:,:,:,:)                       ! Allocatable real (real64): lambda(:,:,:,:,:,:).
      REAL(R8), ALLOCATABLE :: GAMMA(:,:,:,:,:,:,:)                      ! Allocatable real (real64): gamma(:,:,:,:,:,:,:).
      INTEGER(I8), ALLOCATABLE :: PE(:)                                  ! Allocatable integer (int64): pe(:).
      INTEGER(I4), ALLOCATABLE :: NQ(:)                                  ! Allocatable integer (int32): nq(:).
      INTEGER(I4), ALLOCATABLE :: QO(:)                                  ! Allocatable integer (int32): qo(:).
      INTEGER(I4), ALLOCATABLE :: ERULE(:)                               ! Allocatable integer (int32): erule(:).
      INTEGER(I4), ALLOCATABLE :: MAT(:)                                 ! Allocatable integer (int32): mat(:).
      INTEGER(I4), ALLOCATABLE :: OFFSET(:,:)                            ! Allocatable integer (int32): offset(:,:).
      INTEGER(I4), ALLOCATABLE :: TERMS(:,:)                             ! Allocatable integer (int32): terms(:,:).
      INTEGER(I4), ALLOCATABLE :: SPEC_OF(:,:)                           ! Allocatable integer (int32): spec_of(:,:).
      REAL(R8) :: OPERATOR(6,3)                                          ! Real (real64): operator(6,3).
      REAL(R8) :: UNIT(3)                                                ! Real (real64): unit(3).
      REAL(R8) :: W(6,3,3)                                               ! Real (real64): w(6,3,3).
      REAL(R8) :: STRUCTURAL_VALUE                                       ! Real (real64): structural_value.
      REAL(R8) :: STRUCTURAL_GRADIENT(3)                                 ! Real (real64): structural_gradient(3).
      REAL(R8) :: FACTOR_VALUE                                           ! Real (real64): factor_value.
      REAL(R8) :: FACTOR_GRADIENT(3)                                     ! Real (real64): factor_gradient(3).
      REAL(R8) :: TIE_WEIGHT(8)                                          ! Real (real64): tie_weight(8).
      REAL(R8) :: NATURAL(3)                                             ! Real (real64): natural(3).
      REAL(R8) :: VALUE                                                  ! Real (real64): value.
      REAL(R8) :: DENSITY                                                ! Real (real64): density.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I8) :: LAST                                                ! Integer (int64): last.
      INTEGER(I8) :: STRUCTURAL_POINT                                    ! Integer (int64): structural_point.
      INTEGER(I4) :: SRULE                                               ! Integer (int32): srule.
      INTEGER(I4) :: NP                                                  ! Integer (int32): np.
      INTEGER(I4) :: NS                                                  ! Integer (int32): ns.
      INTEGER(I4) :: NE                                                  ! Integer (int32): ne.
      INTEGER(I4) :: NQT                                                 ! Integer (int32): nqt.
      INTEGER(I4) :: MESH                                                ! Integer (int32): mesh.
      INTEGER(I4) :: NCLASS                                              ! Integer (int32): nclass.
      INTEGER(I4) :: NSPEC                                               ! Integer (int32): nspec.
      INTEGER(I4) :: CLASS(6)                                            ! Integer (int32): class(6).
      INTEGER(I4) :: CACHE_INDEX                                         ! Integer (int32): cache_index.
      INTEGER(I4) :: POINT_INDEX                                         ! Integer (int32): point_index.
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: P                                                   ! Integer (int32): p.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: F                                                   ! Integer (int32): f.
      INTEGER(I4) :: H                                                   ! Integer (int32): h.
      INTEGER(I4) :: D                                                   ! Integer (int32): d.
      INTEGER(I4) :: DD                                                  ! Integer (int32): dd.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: C                                                   ! Integer (int32): c.
      INTEGER(I4) :: CC                                                  ! Integer (int32): cc.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: R                                                   ! Integer (int32): r.
      INTEGER(I4) :: RR                                                  ! Integer (int32): rr.
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: B                                                   ! Integer (int32): b.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.
      LOGICAL :: STRUCTURAL_AXIS(3)                                      ! Logical: structural_axis(3).
      LOGICAL :: FOUND                                                   ! Logical: found.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      APPLICABLE = .FALSE.                                               ! Set the flag applicable to false.
      CPART = PART_FULL                                                  ! Set cpart to part_full.
      IF (PRESENT(PART)) CPART = PART                                    ! If present(part), set cpart to part.
      DO_STIFFNESS = .TRUE.                                              ! Set the flag do_stiffness to true.
      IF (PRESENT(WITH_STIFFNESS)) DO_STIFFNESS = WITH_STIFFNESS         ! If present(with_stiffness), set do_stiffness to with_stiffness.
      NS = SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID)                    ! Set ns to the size of elements.item(element_index).node_id.
      POINT = LAYOUT%ELEMENT_FIRST(ELEMENT_INDEX)                        ! Set point to layout.element_first(element_index).
      LAST = LAYOUT%ELEMENT_LAST(ELEMENT_INDEX)                          ! Set last to layout.element_last(element_index).
      SRULE = LAYOUT%STRUCTURAL_RULE_INDEX(POINT)                        ! Set srule to layout.structural_rule_index(point).
      NP = SIZE(RULES%ITEM(SRULE)%WEIGHT)                                ! Set np to the size of rules.item(srule).weight.
      DIMENSION = RULES%ITEM(SRULE)%NATURAL_DIMENSION                    ! Set dimension to rules.item(srule).natural_dimension.
      STRUCTURAL_AXIS = .FALSE.                                          ! Set the flag structural_axis to false.
      IF (DIMENSION .EQ. 1_I4) THEN                                      ! If dimension = 1:
        STRUCTURAL_AXIS(2) = .TRUE.                                      ! Set the flag structural_axis(2) to true.
      ELSE IF (DIMENSION .GE. 2_I4) THEN                                 ! Otherwise, if dimension >= 2:
        STRUCTURAL_AXIS(1:DIMENSION) = .TRUE.                            ! Set the flag structural_axis(1:dimension) to true.
      END IF                                                             ! End of the IF block.
      MESH = FIND_EXPANSION_INDEX(EXPANSIONS,                            ! Set mesh to find_expansion_index(expansions, elements.item(element_index).expansion_id).
     &       ELEMENTS%ITEM(ELEMENT_INDEX)%EXPANSION_ID)
      IF (MESH .EQ. 0_I4) RETURN                                         ! If mesh = 0, return to the caller.
      NE = SIZE(EXPANSIONS%ITEM(MESH)%ELEMENT)                           ! Set ne to the size of expansions.item(mesh).element.
      ALLOCATE(PE(NE), NQ(NE), QO(NE), ERULE(NE), MAT(NE))               ! Allocate memory for pe(ne), nq(ne), qo(ne), erule(ne), mat(ne).

!     LAYOUT: SUB-ELEMENT E, THEN STRUCTURAL POINT P, THEN POINT Q.
      NQT = 0_I4                                                         ! Set nqt to zero.
      DO E = 1_I4, NE                                                    ! Loop e from 1 to ne:
        IF (POINT .GT. LAST) RETURN                                      ! If point > last, return to the caller.
        PE(E) = POINT                                                    ! Set pe(e) to point.
        ERULE(E) = LAYOUT%EXPANSION_RULE_INDEX(POINT)                    ! Set erule(e) to layout.expansion_rule_index(point).
        NQ(E) = SIZE(RULES%ITEM(ERULE(E))%WEIGHT)                        ! Set nq(e) to the size of rules.item(erule(e)).weight.
        MAT(E) = MATERIAL_MAP%CACHE_INDEX(POINT)                         ! Set mat(e) to material_map.cache_index(point).
        QO(E) = NQT                                                      ! Set qo(e) to nqt.
        NQT = NQT + NQ(E)                                                ! Add nq(e) to nqt.
        IF (POINT+INT(NP,I8)*INT(NQ(E),I8)-1_I8 .GT. LAST) RETURN        ! If point+int(np,i8)*int(nq(e),i8)-1 > last, return to the caller.
!       THE FAST PATH NEEDS A CONSTANT CONSTITUTIVE MATRIX PER E.
        IF (ANY(MATERIAL_MAP%CACHE_INDEX(POINT:POINT+INT(NP,I8)*         ! If any(material_map.cache_index(point:point+int(np,i8)* int(nq(e),i8)-1) /= mat(e)), return to the caller.
     &      INT(NQ(E),I8)-1_I8) .NE. MAT(E))) RETURN
        POINT = POINT + INT(NP,I8)*INT(NQ(E),I8)                         ! Add int(np,i8)*int(nq(e),i8) to point.
      END DO                                                             ! End of the loop.
      IF (POINT-1_I8 .NE. LAST) RETURN                                   ! If point-1 /= last, return to the caller.

!     DOF BLOCKS (NODE, FIELD): OFFSET AND NUMBER OF TERMS.
      ALLOCATE(OFFSET(NS,3), TERMS(NS,3), SPEC_OF(NS,3))                 ! Allocate memory for offset(ns,3), terms(ns,3), spec_of(ns,3).
      OFFSET = 0_I4                                                      ! Set offset to zero.
      TERMS = 0_I4                                                       ! Set terms to zero.
      SPEC_OF = 0_I4                                                     ! Set spec_of to zero.
      DO I = 1_I4, SIZE(FIELD)                                           ! Loop i from 1 to size(field):
        IF (FIELD(I) .LT. 1_I4 .OR. FIELD(I) .GT. 3_I4) RETURN           ! If field(i) < 1 or field(i) > 3, return to the caller.
        IF (TERMS(STRUCTURAL_NODE(I),FIELD(I)) .EQ. 0_I4)                ! If terms(structural_node(i),field(i)) = 0, set offset(structural_node(i),field(i)) to i - 1.
     &    OFFSET(STRUCTURAL_NODE(I),FIELD(I)) = I - 1_I4
        TERMS(STRUCTURAL_NODE(I),FIELD(I)) =                             ! Add 1 to terms(structural_node(i),field(i)).
     &    TERMS(STRUCTURAL_NODE(I),FIELD(I)) + 1_I4
        IF (TERM(I) .NE. TERMS(STRUCTURAL_NODE(I),FIELD(I))) RETURN      ! If term(i) /= terms(structural_node(i),field(i)), return to the caller.
      END DO                                                             ! End of the loop.

!     STRUCTURAL FACTORS (THE FIRST SUB-ELEMENT CARRIES ALL POINTS P).
      ALLOCATE(SW(NP), SN(NP,NS), SG(3,NP,NS))                           ! Allocate memory for sw(np), sn(np,ns), sg(3,np,ns).
      DO P = 1_I4, NP                                                    ! Loop p from 1 to np:
        STRUCTURAL_POINT = PE(1) + INT(P-1_I4,I8)*INT(NQ(1),I8)          ! Set structural_point to pe(1) + int(p-1,i8)*int(nq(1),i8).
        CACHE_INDEX = INT(GEOMETRY%STRUCTURAL_CACHE_INDEX(               ! Set cache_index to int(geometry.structural_cache_index( structural_point),i4).
     &                STRUCTURAL_POINT),I4)
        POINT_INDEX = LAYOUT%STRUCTURAL_POINT_INDEX(STRUCTURAL_POINT)    ! Set point_index to layout.structural_point_index(structural_point).
        SW(P) = RULES%ITEM(SRULE)%WEIGHT(POINT_INDEX)*                   ! Set sw(p) to rules.item(srule).weight(point_index)* structural_cache.determinant(cache_index).
     &          STRUCTURAL_CACHE%DETERMINANT(CACHE_INDEX)
        DO I = 1_I4, NS                                                  ! Loop i from 1 to ns:
          SN(P,I) = RULES%ITEM(SRULE)%SHAPE(I,POINT_INDEX)               ! Set sn(p,i) to rules.item(srule).shape(i,point_index).
          SG(:,P,I) = STRUCTURAL_CACHE%DERIVATIVE_LOCAL(:,               ! Set sg(:,p,i) to structural_cache.derivative_local(:, structural_cache.derivative_offset(cache_index)+ int(...
     &      STRUCTURAL_CACHE%DERIVATIVE_OFFSET(CACHE_INDEX)+
     &      INT(I-1_I4,I8))
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

!     STRAIN ROW CLASSES: 1 = PLAIN, 1+S = TIED BY SET S.
      NCLASS = 1_I4                                                      ! Set nclass to 1.
      CLASS = 1_I4                                                       ! Set class to 1.
      IF (MITC_DATA%ACTIVE) THEN                                         ! If mitc_data.active:
        NCLASS = 1_I4 + MITC_DATA%SET_COUNT                              ! Set nclass to 1 + mitc_data.set_count.
        DO R = 1_I4, 6_I4                                                ! Loop r from 1 to 6:
          IF (MITC_DATA%ROW_SET(R) .GT. 0_I4)                            ! If mitc_data.row_set(r) > 0, set class(r) to 1 + mitc_data.row_set(r).
     &      CLASS(R) = 1_I4 + MITC_DATA%ROW_SET(R)
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.
      ALLOCATE(SIGMA(3,NP,NS,NCLASS))                                    ! Allocate memory for sigma(3,np,ns,nclass).
      DO I = 1_I4, NS                                                    ! Loop i from 1 to ns:
        DO P = 1_I4, NP                                                  ! Loop p from 1 to np:
          DO D = 1_I4, 3_I4                                              ! Loop d from 1 to 3:
            IF (STRUCTURAL_AXIS(D)) THEN                                 ! If structural_axis(d):
              SIGMA(D,P,I,1) = SG(D,P,I)                                 ! Set sigma(d,p,i,1) to sg(d,p,i).
            ELSE                                                         ! Otherwise:
              SIGMA(D,P,I,1) = SN(P,I)                                   ! Set sigma(d,p,i,1) to sn(p,i).
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      DO C = 2_I4, NCLASS                                                ! Loop c from 2 to nclass:
        DO P = 1_I4, NP                                                  ! Loop p from 1 to np:
          STRUCTURAL_POINT = PE(1) + INT(P-1_I4,I8)*INT(NQ(1),I8)        ! Set structural_point to pe(1) + int(p-1,i8)*int(nq(1),i8).
          POINT_INDEX = LAYOUT%STRUCTURAL_POINT_INDEX(STRUCTURAL_POINT)  ! Set point_index to layout.structural_point_index(structural_point).
          NATURAL = RULES%ITEM(SRULE)%COORDINATE(POINT_INDEX,1:3)        ! Set natural to rules.item(srule).coordinate(point_index,1:3).
          CALL INTERPOLATION_WEIGHT(MITC_DATA%SET(C-1_I4), NATURAL,      ! Call interpolation weight with mitc_data.set(c-1), natural, tie_weight.
     &                              TIE_WEIGHT)
          DO I = 1_I4, NS                                                ! Loop i from 1 to ns:
            SIGMA(:,P,I,C) = 0.0_R8                                      ! Set sigma(:,p,i,c) to zero.
            DO L = 1_I4, PRODUCT_OF(MITC_DATA%SET(C-1_I4)%COUNT_1D)      ! Loop l from 1 to product_of(mitc_data.set(c-1).count_1d):
              DO D = 1_I4, 3_I4                                          ! Loop d from 1 to 3:
                IF (STRUCTURAL_AXIS(D)) THEN                             ! If structural_axis(d):
                  VALUE = MITC_DATA%GRADIENT(D,I,L,C-1_I4)               ! Set value to mitc_data.gradient(d,i,l,c-1).
                ELSE                                                     ! Otherwise:
                  VALUE = MITC_DATA%SHAPE(I,L,C-1_I4)                    ! Set value to mitc_data.shape(i,l,c-1).
                END IF                                                   ! End of the IF block.
                SIGMA(D,P,I,C) = SIGMA(D,P,I,C) + TIE_WEIGHT(L)*VALUE    ! Add tie_weight(l)*value to sigma(d,p,i,c).
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      ALLOCATE(SM(NS,NS,3,3,NCLASS,NCLASS), SNN(NS,NS))                  ! Allocate memory for sm(ns,ns,3,3,nclass,nclass), snn(ns,ns).
      SM = 0.0_R8                                                        ! Set sm to zero.
      SNN = 0.0_R8                                                       ! Set snn to zero.
      DO P = 1_I4, NP                                                    ! Loop p from 1 to np:
        DO J = 1_I4, NS                                                  ! Loop j from 1 to ns:
          DO I = 1_I4, NS                                                ! Loop i from 1 to ns:
            SNN(I,J) = SNN(I,J) + SW(P)*SN(P,I)*SN(P,J)                  ! Add sw(p)*sn(p,i)*sn(p,j) to snn(i,j).
            DO CC = 1_I4, NCLASS                                         ! Loop cc from 1 to nclass:
              DO C = 1_I4, NCLASS                                        ! Loop c from 1 to nclass:
                DO DD = 1_I4, 3_I4                                       ! Loop dd from 1 to 3:
                  DO D = 1_I4, 3_I4                                      ! Loop d from 1 to 3:
                    SM(I,J,D,DD,C,CC) = SM(I,J,D,DD,C,CC) +              ! Add sw(p)*sigma(d,p,i,c)*sigma(dd,p,j,cc) to sm(i,j,d,dd,c,cc).
     &                SW(P)*SIGMA(D,P,I,C)*SIGMA(DD,P,J,CC)
                  END DO                                                 ! End of the loop.
                END DO                                                   ! End of the loop.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

!     DISTINCT KINEMATIC SPECIFICATIONS AND THEIR EXPANSION FUNCTIONS.
      ALLOCATE(BASIS(NS*3))                                              ! Allocate memory for basis(ns*3).
      NSPEC = 0_I4                                                       ! Set nspec to zero.
      DO I = 1_I4, NS                                                    ! Loop i from 1 to ns:
        DO F = 1_I4, 3_I4                                                ! Loop f from 1 to 3:
          IF (TERMS(I,F) .EQ. 0_I4) CYCLE                                ! If terms(i,f) = 0, skip to the next iteration.
          IF (KINEMATIC_INDEX(I) .LT. 1_I4) RETURN                       ! If kinematic_index(i) < 1, return to the caller.
          FOUND = .FALSE.                                                ! Set the flag found to false.
          DO M = 1_I4, NSPEC                                             ! Loop m from 1 to nspec:
            IF (SAME_SPEC(BASIS(M)%SPEC, KINEMATICS%ITEM(                ! If same_spec(basis(m).spec, kinematics.item( kinematic_index(i)).field(f)) and basis(m).terms = terms(i,f):
     &          KINEMATIC_INDEX(I))%FIELD(F)) .AND.
     &          BASIS(M)%TERMS .EQ. TERMS(I,F)) THEN
              SPEC_OF(I,F) = M                                           ! Set spec_of(i,f) to m.
              FOUND = .TRUE.                                             ! Set the flag found to true.
              EXIT                                                       ! Leave the loop.
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
          IF (.NOT. FOUND) THEN                                          ! If not found:
            NSPEC = NSPEC + 1_I4                                         ! Add 1 to nspec.
            BASIS(NSPEC)%SPEC = KINEMATICS%ITEM(                         ! Set basis(nspec).spec to kinematics.item( kinematic_index(i)).field(f).
     &        KINEMATIC_INDEX(I))%FIELD(F)
            BASIS(NSPEC)%TERMS = TERMS(I,F)                              ! Set basis(nspec).terms to terms(i,f).
            SPEC_OF(I,F) = NSPEC                                         ! Set spec_of(i,f) to nspec.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      ALLOCATE(WQ(NQT))                                                  ! Allocate memory for wq(nqt).
      DO E = 1_I4, NE                                                    ! Loop e from 1 to ne:
        DO Q = 1_I4, NQ(E)                                               ! Loop q from 1 to nq(e):
          POINT = PE(E) + INT(Q-1_I4,I8)                                 ! Set point to pe(e) + int(q-1,i8).
          CACHE_INDEX = INT(GEOMETRY%EXPANSION_CACHE_INDEX(POINT),I4)    ! Set cache_index to int(geometry.expansion_cache_index(point),i4).
          POINT_INDEX = LAYOUT%EXPANSION_POINT_INDEX(POINT)              ! Set point_index to layout.expansion_point_index(point).
          WQ(QO(E)+Q) = RULES%ITEM(ERULE(E))%WEIGHT(POINT_INDEX)*        ! Set wq(qo(e)+q) to rules.item(erule(e)).weight(point_index)* expansion_cache.determinant(cache_index).
     &                  EXPANSION_CACHE%DETERMINANT(CACHE_INDEX)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      DO M = 1_I4, NSPEC                                                 ! Loop m from 1 to nspec:
        ALLOCATE(BASIS(M)%EPS(NQT,BASIS(M)%TERMS,0:3))                   ! Allocate memory for basis(m).eps(nqt,basis(m).terms,0:3).
        DO K = 1_I4, BASIS(M)%TERMS                                      ! Loop k from 1 to basis(m).terms:
          DO E = 1_I4, NE                                                ! Loop e from 1 to ne:
            DO Q = 1_I4, NQ(E)                                           ! Loop q from 1 to nq(e):
              POINT = PE(E) + INT(Q-1_I4,I8)                             ! Set point to pe(e) + int(q-1,i8).
              CALL EVALUATE_POINT_FACTORS(POINT, 1_I4, K,                ! Call evaluate point factors with point, 1, k, basis(m).spec, elements, expansions, rules, layout, structura...
     &             BASIS(M)%SPEC, ELEMENTS, EXPANSIONS, RULES, LAYOUT,
     &             STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY,
     &             STRUCTURAL_VALUE, STRUCTURAL_GRADIENT,
     &             FACTOR_VALUE, FACTOR_GRADIENT, STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
              BASIS(M)%EPS(QO(E)+Q,K,0) = FACTOR_VALUE                   ! Set basis(m).eps(qo(e)+q,k,0) to factor_value.
              DO D = 1_I4, 3_I4                                          ! Loop d from 1 to 3:
                IF (STRUCTURAL_AXIS(D)) THEN                             ! If structural_axis(d):
                  BASIS(M)%EPS(QO(E)+Q,K,D) = FACTOR_VALUE               ! Set basis(m).eps(qo(e)+q,k,d) to factor_value.
                ELSE                                                     ! Otherwise:
                  BASIS(M)%EPS(QO(E)+Q,K,D) = FACTOR_GRADIENT(D)         ! Set basis(m).eps(qo(e)+q,k,d) to factor_gradient(d).
                END IF                                                   ! End of the IF block.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      ALLOCATE(PRODUCT(NSPEC,NSPEC))                                     ! Allocate memory for product(nspec,nspec).

!     W(:,D,F) = B_OPERATOR(E_D) * FRAME(:,F).
      DO D = 1_I4, 3_I4                                                  ! Loop d from 1 to 3:
        UNIT = 0.0_R8                                                    ! Set unit to zero.
        UNIT(D) = 1.0_R8                                                 ! Set unit(d) to 1.0.
        CALL BUILD_DISPLACEMENT_OPERATOR(UNIT, OPERATOR, STATUS)         ! Call build displacement operator with unit, operator, status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        DO F = 1_I4, 3_I4                                                ! Loop f from 1 to 3:
          W(:,D,F) = MATMUL(OPERATOR,                                    ! Set w(:,d,f) to matmul(operator, frames.global_to_local(:,f,element_index)).
     &               FRAMES%GLOBAL_TO_LOCAL(:,F,ELEMENT_INDEX))
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

!     GAMMA(F,H,D,D',C,C',E) = SUM W_D,F(R) C_E(R,R') W_D',H(R').
      ALLOCATE(GAMMA(3,3,3,3,NCLASS,NCLASS,NE))                          ! Allocate memory for gamma(3,3,3,3,nclass,nclass,ne).
      GAMMA = 0.0_R8                                                     ! Set gamma to zero.
      DO E = 1_I4, NE                                                    ! Loop e from 1 to ne:
        IF (MAT(E) .LT. 1_I4 .OR. MAT(E) .GT. MATERIAL_CACHE%COUNT)      ! If mat(e) < 1 or mat(e) > material_cache.count, return to the caller.
     &    RETURN
        CMAT = STIFFNESS_PART(MATERIAL_CACHE, MAT(E), CPART,             ! Set cmat to stiffness_part(material_cache, mat(e), cpart, topology_natural_dimension( elements.item(element...
     &         TOPOLOGY_NATURAL_DIMENSION(
     &         ELEMENTS%ITEM(ELEMENT_INDEX)%TOPOLOGY))
        DO RR = 1_I4, 6_I4                                               ! Loop rr from 1 to 6:
          DO R = 1_I4, 6_I4                                              ! Loop r from 1 to 6:
            VALUE = CMAT(R,RR)                                           ! Set value to cmat(r,rr).
            DO H = 1_I4, 3_I4                                            ! Loop h from 1 to 3:
              DO F = 1_I4, 3_I4                                          ! Loop f from 1 to 3:
                DO DD = 1_I4, 3_I4                                       ! Loop dd from 1 to 3:
                  DO D = 1_I4, 3_I4                                      ! Loop d from 1 to 3:
                    GAMMA(F,H,D,DD,CLASS(R),CLASS(RR),E) =               ! Add w(r,d,f)*value*w(rr,dd,h) to gamma(f,h,d,dd,class(r),class(rr),e).
     &                GAMMA(F,H,D,DD,CLASS(R),CLASS(RR),E) +
     &                W(R,D,F)*VALUE*W(RR,DD,H)
                  END DO                                                 ! End of the loop.
                END DO                                                   ! End of the loop.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

!     LAMBDA(I,J,F,H,K,E) AND BLOCK ASSEMBLY.
      ALLOCATE(LAMBDA(NS,NS,3,3,10,NE))                                  ! Allocate memory for lambda(ns,ns,3,3,10,ne).
      LAMBDA = 0.0_R8                                                    ! Set lambda to zero.
      DO E = 1_I4, NE                                                    ! Loop e from 1 to ne:
        DO DD = 1_I4, 3_I4                                               ! Loop dd from 1 to 3:
          DO D = 1_I4, 3_I4                                              ! Loop d from 1 to 3:
            K = 3_I4*(D-1_I4) + DD                                       ! Set k to 3*(d-1) + dd.
            DO CC = 1_I4, NCLASS                                         ! Loop cc from 1 to nclass:
              DO C = 1_I4, NCLASS                                        ! Loop c from 1 to nclass:
                DO H = 1_I4, 3_I4                                        ! Loop h from 1 to 3:
                  DO F = 1_I4, 3_I4                                      ! Loop f from 1 to 3:
                    DO J = 1_I4, NS                                      ! Loop j from 1 to ns:
                      DO I = 1_I4, NS                                    ! Loop i from 1 to ns:
                        LAMBDA(I,J,F,H,K,E) = LAMBDA(I,J,F,H,K,E) +      ! Add gamma(f,h,d,dd,c,cc,e)*sm(i,j,d,dd,c,cc) to lambda(i,j,f,h,k,e).
     &                    GAMMA(F,H,D,DD,C,CC,E)*SM(I,J,D,DD,C,CC)
                      END DO                                             ! End of the loop.
                    END DO                                               ! End of the loop.
                  END DO                                                 ! End of the loop.
                END DO                                                   ! End of the loop.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      DO J = 1_I4, NS                                                    ! Loop j from 1 to ns:
        DO H = 1_I4, 3_I4                                                ! Loop h from 1 to 3:
          IF (TERMS(J,H) .EQ. 0_I4) CYCLE                                ! If terms(j,h) = 0, skip to the next iteration.
          B = SPEC_OF(J,H)                                               ! Set b to spec_of(j,h).
          DO I = 1_I4, J                                                 ! Loop i from 1 to j:
            DO F = 1_I4, 3_I4                                            ! Loop f from 1 to 3:
              IF (TERMS(I,F) .EQ. 0_I4) CYCLE                            ! If terms(i,f) = 0, skip to the next iteration.
              IF (I .EQ. J .AND. F .GT. H) CYCLE                         ! If i = j and f > h, skip to the next iteration.
              A = SPEC_OF(I,F)                                           ! Set a to spec_of(i,f).
              CALL PREPARE_PRODUCT(PRODUCT(A,B), BASIS(A), BASIS(B),     ! Call prepare product with product(a,b), basis(a), basis(b), wq, ne, nq, qo, status.
     &             WQ, NE, NQ, QO, STATUS)
              IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                     ! If not status is ok, return to the caller.
              DO E = 1_I4, NE                                            ! Loop e from 1 to ne:
                DO K = 1_I4, 9_I4                                        ! Loop k from 1 to 9:
                  IF (.NOT. DO_STIFFNESS) EXIT                           ! If not do_stiffness, leave the loop.
                  STIFFNESS(OFFSET(I,F)+1:OFFSET(I,F)+TERMS(I,F),        ! Add lambda(i,j,f,h,k,e)*product(a,b).em(:,:,k,e) to stiffness(offset(i,f)+1:offset(i,f)+terms(i,f), offset(...
     &                      OFFSET(J,H)+1:OFFSET(J,H)+TERMS(J,H)) =
     &              STIFFNESS(OFFSET(I,F)+1:OFFSET(I,F)+TERMS(I,F),
     &                        OFFSET(J,H)+1:OFFSET(J,H)+TERMS(J,H)) +
     &              LAMBDA(I,J,F,H,K,E)*PRODUCT(A,B)%EM(:,:,K,E)
                END DO                                                   ! End of the loop.
                IF (WITH_MASS .AND. F .EQ. H) THEN                       ! If with_mass and f = h:
                  DENSITY = MATERIAL_CACHE%DENSITY(MAT(E))               ! Set density to material_cache.density(mat(e)).
                  MASS(OFFSET(I,F)+1:OFFSET(I,F)+TERMS(I,F),             ! Add density*snn(i,j)*product(a,b).em(:,:,10,e) to mass(offset(i,f)+1:offset(i,f)+terms(i,f), offset(j,h)+1:...
     &                 OFFSET(J,H)+1:OFFSET(J,H)+TERMS(J,H)) =
     &              MASS(OFFSET(I,F)+1:OFFSET(I,F)+TERMS(I,F),
     &                   OFFSET(J,H)+1:OFFSET(J,H)+TERMS(J,H)) +
     &              DENSITY*SNN(I,J)*PRODUCT(A,B)%EM(:,:,10,E)
                END IF                                                   ! End of the IF block.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      APPLICABLE = .TRUE.                                                ! Set the flag applicable to true.

      END SUBROUTINE BUILD_SEPARABLE_MATRICES                            ! End of the subroutine build separable matrices.

      INTEGER(I4) FUNCTION PRODUCT_OF(COUNT_1D)                          ! Function product of takes count 1d.

      INTEGER(I4), INTENT(IN) :: COUNT_1D(3)                             ! Input integer (int32): count_1d(3).

      PRODUCT_OF = COUNT_1D(1)*COUNT_1D(2)*COUNT_1D(3)                   ! Set product_of to count_1d(1)*count_1d(2)*count_1d(3).

      END FUNCTION PRODUCT_OF                                            ! End of the function product of.

      LOGICAL FUNCTION SAME_SPEC(SPEC_A, SPEC_B)                         ! Function same spec takes spec a, spec b.

      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: SPEC_A                    ! Input of type expansion_spec_type: spec_a.
      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: SPEC_B                    ! Input of type expansion_spec_type: spec_b.

      SAME_SPEC = SPEC_A%FAMILY .EQ. SPEC_B%FAMILY .AND.                 ! Set same_spec to spec_a.family = spec_b.family and spec_a.order = spec_b.order and spec_a.field_reference =...
     &            SPEC_A%ORDER .EQ. SPEC_B%ORDER .AND.
     &            SPEC_A%FIELD_REFERENCE .EQ. SPEC_B%FIELD_REFERENCE

      END FUNCTION SAME_SPEC                                             ! End of the function same spec.

!  EM_E,K(T,S) = SUM_Q W_Q EPS_A,D(Q,T) EPS_B,D'(Q,S), ONCE PER PAIR.
      SUBROUTINE PREPARE_PRODUCT(PRODUCT, BASIS_A, BASIS_B, WQ, NE,      ! Subroutine prepare product takes product, basis a, basis b, wq, ne, nq, qo, status.
     &                           NQ, QO, STATUS)

      TYPE(EXPANSION_PRODUCT_TYPE), INTENT(INOUT) :: PRODUCT             ! In/out of type expansion_product_type: product.
      TYPE(SPEC_BASIS_TYPE), INTENT(IN) :: BASIS_A                       ! Input of type spec_basis_type: basis_a.
      TYPE(SPEC_BASIS_TYPE), INTENT(IN) :: BASIS_B                       ! Input of type spec_basis_type: basis_b.
      REAL(R8), INTENT(IN) :: WQ(:)                                      ! Input real (real64): wq(:).
      INTEGER(I4), INTENT(IN) :: NE                                      ! Input integer (int32): ne.
      INTEGER(I4), INTENT(IN) :: NQ(:)                                   ! Input integer (int32): nq(:).
      INTEGER(I4), INTENT(IN) :: QO(:)                                   ! Input integer (int32): qo(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: WEIGHTED(:,:)                             ! Allocatable real (real64): weighted(:,:).
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: D                                                   ! Integer (int32): d.
      INTEGER(I4) :: DD                                                  ! Integer (int32): dd.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (PRODUCT%READY) RETURN                                          ! If product.ready, return to the caller.
      ALLOCATE(PRODUCT%EM(BASIS_A%TERMS,BASIS_B%TERMS,10,NE))            ! Allocate memory for product.em(basis_a.terms,basis_b.terms,10,ne).
      PRODUCT%EM = 0.0_R8                                                ! Set product.em to zero.
      ALLOCATE(WEIGHTED(SIZE(WQ),BASIS_A%TERMS))                         ! Allocate memory for weighted(size(wq),basis_a.terms).
      DO E = 1_I4, NE                                                    ! Loop e from 1 to ne:
        DO K = 1_I4, 10_I4                                               ! Loop k from 1 to 10:
          IF (K .LE. 9_I4) THEN                                          ! If k <= 9:
            D = (K-1_I4)/3_I4 + 1_I4                                     ! Set d to (k-1)/3 + 1.
            DD = K - 3_I4*(D-1_I4)                                       ! Set dd to k - 3*(d-1).
          ELSE                                                           ! Otherwise:
            D = 0_I4                                                     ! Set d to zero.
            DD = 0_I4                                                    ! Set dd to zero.
          END IF                                                         ! End of the IF block.
          DO Q = QO(E)+1_I4, QO(E)+NQ(E)                                 ! Loop q from qo(e)+1 to qo(e)+nq(e):
            WEIGHTED(Q,:) = WQ(Q)*BASIS_A%EPS(Q,:,D)                     ! Set weighted(q,:) to wq(q)*basis_a.eps(q,:,d).
          END DO                                                         ! End of the loop.
          CALL ACCUMULATE_PRODUCT(                                       ! Call accumulate product with weighted(qo(e)+1:qo(e)+nq(e),:), basis_b.eps(qo(e)+1:qo(e)+nq(e),:,dd), nq(e),...
     &         WEIGHTED(QO(E)+1:QO(E)+NQ(E),:),
     &         BASIS_B%EPS(QO(E)+1:QO(E)+NQ(E),:,DD), NQ(E),
     &         PRODUCT%EM(:,:,K,E))
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      PRODUCT%READY = .TRUE.                                             ! Set the flag product.ready to true.

      END SUBROUTINE PREPARE_PRODUCT                                     ! End of the subroutine prepare product.

      END MODULE MUL2_SEPARABLE_KERNEL                                   ! End of the module mul2 separable kernel.
