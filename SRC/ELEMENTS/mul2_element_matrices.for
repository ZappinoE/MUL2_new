!=======================================================================
!  ELEMENT MATRIX TYPE, DOF LIST, POINT EVALUATION OF THE ORDINARY
!  ELEMENTS (STRAIGHT BEAMS, FLAT PLATES, SOLIDS) AND THE SHARED POINT
!  OPERATORS (MASS, GEOMETRIC, NONLINEAR). THE ELEMENT BUILDERS ARE IN
!  MUL2_ELEMENT_OPERATORS.
!=======================================================================
      MODULE MUL2_ELEMENT_MATRICES                                       ! Module mul2 element matrices begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       SET_ERROR, STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, FIND_NODE_INDEX                ! Use from module mul2 nodes: node db type, find node index.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION              ! Use from module mul2 topologies: topology natural dimension.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE,                     ! Use from module mul2 kinematics: kinematics db type, expansion spec type, find kinematic index, field p, fi...
     &                           EXPANSION_SPEC_TYPE,
     &                           FIND_KINEMATIC_INDEX,
     &                           FIELD_P, FIELD_T, N_SOLVED_FIELDS
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE                 ! Use from module mul2 expansion meshes: expansion db type.
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type.
     &                             GAUSS_LAYOUT_TYPE
      USE MUL2_GAUSS_GEOMETRY, ONLY:                                     ! Use from module mul2 gauss geometry: structural geometry cache type, expansion geometry cache type, gauss g...
     &     STRUCTURAL_GEOMETRY_CACHE_TYPE,
     &     EXPANSION_GEOMETRY_CACHE_TYPE, GAUSS_GEOMETRY_TYPE
      USE MUL2_GAUSS_MATERIALS, ONLY: MATERIAL_CACHE_TYPE,               ! Use from module mul2 gauss materials: material cache type, gauss material map type, stiffness part, part fu...
     &                               GAUSS_MATERIAL_MAP_TYPE,
     &                               STIFFNESS_PART, PART_FULL,
     &                               GENERALIZED_CONSTITUTIVE,
     &                               THERMAL_STRESS_COEFFICIENT
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE, GLOBAL_DOF             ! Use from module mul2 dof layout: dof layout type, global dof.
      USE MUL2_POINT_BASES, ONLY: EVALUATE_POINT_FACTORS                 ! Use from module mul2 point bases: evaluate point factors.
      USE MUL2_MITC, ONLY: MITC_DATA_TYPE, MITC_TIE_COLUMN               ! Use from module mul2 mitc: mitc data type, mitc tie column.
      USE MUL2_LINEAR_KINEMATICS, ONLY: COMPOSE_PRODUCT_BASIS            ! Use from module mul2 linear kinematics: compose product basis.
      USE MUL2_LINEAR_KINEMATICS, ONLY:                                  ! Use from module mul2 linear kinematics: build displacement operator.
     &     BUILD_DISPLACEMENT_OPERATOR
      USE MUL2_DENSE_PRODUCTS, ONLY: ACCUMULATE_UPPER_PRODUCT,           ! Use from module mul2 dense products: accumulate upper product, accumulate product.
     &                               ACCUMULATE_PRODUCT

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: ELEMENT_MATRIX_TYPE                                ! Definition of the derived type element matrix type.
        INTEGER(I4) :: ELEMENT_INDEX = 0_I4                              ! Integer (int32): element_index = 0.
        INTEGER(I4) :: LOCAL_DOF_COUNT = 0_I4                            ! Integer (int32): local_dof_count = 0.
        INTEGER(I8), ALLOCATABLE :: GLOBAL_DOF(:)                        ! Allocatable integer (int64): global_dof(:).
        INTEGER(I4), ALLOCATABLE :: NODE_INDEX(:)                        ! Allocatable integer (int32): node_index(:).
        INTEGER(I4), ALLOCATABLE :: KINEMATIC_INDEX(:)                   ! Allocatable integer (int32): kinematic_index(:).
        INTEGER(I4), ALLOCATABLE :: STRUCTURAL_NODE(:)                   ! Allocatable integer (int32): structural_node(:).
        INTEGER(I4), ALLOCATABLE :: FIELD(:)                             ! Allocatable integer (int32): field(:).
        INTEGER(I4), ALLOCATABLE :: TERM(:)                              ! Allocatable integer (int32): term(:).
        INTEGER(I8), ALLOCATABLE :: CSR_POSITION(:,:)                    ! Allocatable integer (int64): csr_position(:,:).
        REAL(R8), ALLOCATABLE :: STIFFNESS(:,:)                          ! Allocatable real (real64): stiffness(:,:).
        REAL(R8), ALLOCATABLE :: MASS(:,:)                               ! Allocatable real (real64): mass(:,:).
!       INTERNAL FORCE OF THE NONLINEAR (TOTAL LAGRANGIAN) ELEMENT.
        REAL(R8), ALLOCATABLE :: INTERNAL_FORCE(:)                       ! Allocatable real (real64): internal_force(:).
      END TYPE ELEMENT_MATRIX_TYPE                                       ! End of the type definition element matrix type.

      INTEGER(I4), PARAMETER, PUBLIC :: MAX_BATCH = 128_I4               ! Constant public integer (int32): max_batch = 128.

!  WORKSPACE OF THE POINT-BY-POINT KERNELS. THE BASIS OF A DEGREE OF
!  FREEDOM IS N_NODE * F_TERM: THE STRUCTURAL FACTORS (ONE PER NODE) AND
!  THE EXPANSION FACTORS (ONE PER TERM AND PER DISTINCT EXPANSION) ARE
!  EVALUATED ONCE PER POINT AND COMBINED FOR EVERY DOF, INSTEAD OF
!  RE-EVALUATING BOTH FOR EACH OF THE (OFTEN HUNDREDS OF) DOFS.
      TYPE, PUBLIC :: POINT_WORK_TYPE                                    ! Definition of the derived type point work type.
        INTEGER(I4) :: N_MEMO = 0_I4                                     ! Integer (int32): n_memo = 0.
        INTEGER(I4), ALLOCATABLE :: MEMO_OF(:)                           ! Allocatable integer (int32): memo_of(:).
        INTEGER(I4), ALLOCATABLE :: MEMO_NODE(:)                         ! Allocatable integer (int32): memo_node(:).
        INTEGER(I4), ALLOCATABLE :: MEMO_TERMS(:)                        ! Allocatable integer (int32): memo_terms(:).
        INTEGER(I4), ALLOCATABLE :: MEMO_KIN(:)                          ! Allocatable integer (int32): memo_kin(:).
        INTEGER(I4), ALLOCATABLE :: MEMO_FIELD(:)                        ! Allocatable integer (int32): memo_field(:).
        REAL(R8), ALLOCATABLE :: SVAL(:)                                 ! Allocatable real (real64): sval(:).
        REAL(R8), ALLOCATABLE :: SGRAD(:,:)                              ! Allocatable real (real64): sgrad(:,:).
        REAL(R8), ALLOCATABLE :: FVAL(:,:)                               ! Allocatable real (real64): fval(:,:).
        REAL(R8), ALLOCATABLE :: FGRAD(:,:,:)                            ! Allocatable real (real64): fgrad(:,:,:).
        REAL(R8), ALLOCATABLE :: VALUE(:)                                ! Allocatable real (real64): value(:).
        REAL(R8), ALLOCATABLE :: BCOL(:,:)                               ! Allocatable real (real64): bcol(:,:).
        REAL(R8), ALLOCATABLE :: GRAD(:,:)                               ! Allocatable real (real64): grad(:,:).
      END TYPE POINT_WORK_TYPE                                           ! End of the type definition point work type.

!  CONTRACT OF A POINT FOR THE STATE-DEPENDENT OPERATORS (GEOMETRIC AND
!  NONLINEAR MATRICES), FILLED BY EVERY KERNEL (ORDINARY OR CURVED):
!    VALUE(I)        BASIS OF THE DOF I
!    BCOL(:,I)       GENERALISED-STRAIN COLUMN IN THE FRAME OF THE POINT
!    GRAD(:,I)       GRADIENT OF THE BASIS IN THE FRAME OF THE POINT
!    DIRECTION(:,I)  DISPLACEMENT DIRECTION OF THE DOF IN THAT FRAME
!                    (ZERO FOR THE POTENTIAL AND THE TEMPERATURE)
!  AND THE WORK ARRAYS OF THE OPERATORS.
      TYPE :: POINT_STATE_WORK_TYPE                                      ! Definition of the derived type point state work type.
        REAL(R8), ALLOCATABLE :: VALUE(:)                                ! Allocatable real (real64): value(:).
        REAL(R8), ALLOCATABLE :: BCOL(:,:)                               ! Allocatable real (real64): bcol(:,:).
        REAL(R8), ALLOCATABLE :: GRAD(:,:)                               ! Allocatable real (real64): grad(:,:).
        REAL(R8), ALLOCATABLE :: DIRECTION(:,:)                          ! Allocatable real (real64): direction(:,:).
        REAL(R8), ALLOCATABLE :: B_TOTAL(:,:)                            ! Allocatable real (real64): b_total(:,:).
        REAL(R8), ALLOCATABLE :: MB(:,:)                                 ! Allocatable real (real64): mb(:,:).
        REAL(R8), ALLOCATABLE :: SG(:,:)                                 ! Allocatable real (real64): sg(:,:).
        REAL(R8), ALLOCATABLE :: A_STACK(:,:)                            ! Allocatable real (real64): a_stack(:,:).
        REAL(R8), ALLOCATABLE :: B_STACK(:,:)                            ! Allocatable real (real64): b_stack(:,:).
      END TYPE POINT_STATE_WORK_TYPE                                     ! End of the type definition point state work type.

      PUBLIC :: BUILD_ELEMENT_DOF_LIST                                   ! Export: build element dof list.
      PUBLIC :: CLEAR_ELEMENT_MATRIX                                     ! Export: clear element matrix.
      PUBLIC :: VALIDATE_INPUT                                           ! Export: validate input.
      PUBLIC :: SETUP_POINT_WORK                                         ! Export: setup point work.
      PUBLIC :: EVALUATE_POINT_COLUMNS                                   ! Export: evaluate point columns.
      PUBLIC :: ADD_MASS                                                 ! Export: add mass.
      PUBLIC :: POINT_STATE_WORK_TYPE                                    ! Export: point state work type.
      PUBLIC :: SETUP_POINT_STATE_WORK                                   ! Export: setup point state work.
      PUBLIC :: GEOMETRIC_POINT                                          ! Export: geometric point.
      PUBLIC :: NONLINEAR_POINT                                          ! Export: nonlinear point.
      PUBLIC :: MIRROR_UPPER_TRIANGLE                                    ! Export: mirror upper triangle.

      CONTAINS                                                           ! The procedures of the module follow.

!  WORK ARRAYS OF THE POINT OPERATORS FOR N_DOF DOFS AND NR STRAIN ROWS.
      SUBROUTINE SETUP_POINT_STATE_WORK(N_DOF, NR, WORK)                 ! Subroutine setup point state work takes n dof, nr, work.

      INTEGER(I4), INTENT(IN) :: N_DOF                                   ! Input integer (int32): n_dof.
      INTEGER(I4), INTENT(IN) :: NR                                      ! Input integer (int32): nr.
      TYPE(POINT_STATE_WORK_TYPE), INTENT(INOUT) :: WORK                 ! In/out of type point_state_work_type: work.

      ALLOCATE(WORK%VALUE(N_DOF), WORK%BCOL(12,N_DOF),                   ! Allocate memory for work.value(n_dof), work.bcol(12,n_dof), work.grad(3,n_dof), work.direction(3,n_dof).
     &         WORK%GRAD(3,N_DOF), WORK%DIRECTION(3,N_DOF))
      ALLOCATE(WORK%B_TOTAL(NR,N_DOF), WORK%MB(NR,N_DOF),                ! Allocate memory for work.b_total(nr,n_dof), work.mb(nr,n_dof), work.sg(3,n_dof), work.a_stack(nr+9,n_dof), ...
     &         WORK%SG(3,N_DOF), WORK%A_STACK(NR+9,N_DOF),
     &         WORK%B_STACK(NR+9,N_DOF))
      WORK%BCOL = 0.0_R8                                                 ! Set work.bcol to zero.

      END SUBROUTINE SETUP_POINT_STATE_WORK                              ! End of the subroutine setup point state work.

!  GEOMETRIC (INITIAL-STRESS) MATRIX OF ONE POINT, UPPER TRIANGLE:
!    S = M(1:6,:) GAMMA(U) - BETA T,
!    K_G(I,J) += W (D_I.D_J) GRAD N_I . S GRAD N_J,
!  A RANK-9 PRODUCT P^T Q. MW IS THE WEIGHTED CONSTITUTIVE MATRIX; THE
!  CONTRACT OF THE POINT IS IN WORK (VALUE: THE TEMPERATURE BASIS OF THE
!  T DOFS). THE CALLER MIRRORS THE MATRIX AT THE END.
      SUBROUTINE GEOMETRIC_POINT(NR, N_DOF, FIELD, UVALUE, WEIGHT, MW,   ! Subroutine geometric point takes nr, n dof, field, uvalue, weight, mw, beta, work, stiffness.
     &                           BETA, WORK, STIFFNESS)

      INTEGER(I4), INTENT(IN) :: NR                                      ! Input integer (int32): nr.
      INTEGER(I4), INTENT(IN) :: N_DOF                                   ! Input integer (int32): n_dof.
      INTEGER(I4), INTENT(IN) :: FIELD(:)                                ! Input integer (int32): field(:).
      REAL(R8), INTENT(IN) :: UVALUE(:)                                  ! Input real (real64): uvalue(:).
      REAL(R8), INTENT(IN) :: WEIGHT                                     ! Input real (real64): weight.
      REAL(R8), INTENT(IN) :: MW(12,12)                                  ! Input real (real64): mw(12,12).
      REAL(R8), INTENT(IN) :: BETA(6)                                    ! Input real (real64): beta(6).
      TYPE(POINT_STATE_WORK_TYPE), INTENT(INOUT) :: WORK                 ! In/out of type point_state_work_type: work.
      REAL(R8), INTENT(INOUT) :: STIFFNESS(:,:)                          ! In/out real (real64): stiffness(:,:).
      REAL(R8) :: GAMMA_V(12)                                            ! Real (real64): gamma_v(12).
      REAL(R8) :: STRESS6(6)                                             ! Real (real64): stress6(6).
      REAL(R8) :: STRESS3(3,3)                                           ! Real (real64): stress3(3,3).
      REAL(R8) :: THETA_POINT                                            ! Real (real64): theta_point.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      GAMMA_V = 0.0_R8                                                   ! Set gamma_v to zero.
      THETA_POINT = 0.0_R8                                               ! Set theta_point to zero.
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        GAMMA_V(1:NR) = GAMMA_V(1:NR) + WORK%BCOL(1:NR,I)*UVALUE(I)      ! Add work.bcol(1:nr,i)*uvalue(i) to gamma_v(1:nr).
        IF (FIELD(I) .EQ. FIELD_T) THETA_POINT =                         ! If field(i) = field_t, add work.value(i)*uvalue(i) to theta_point.
     &    THETA_POINT + WORK%VALUE(I)*UVALUE(I)
      END DO                                                             ! End of the loop.
      STRESS6 = MATMUL(MW(1:6,1:NR),GAMMA_V(1:NR))/                      ! Set stress6 to matmul(mw(1:6,1:nr),gamma_v(1:nr))/ weight - beta*theta_point.
     &          WEIGHT - BETA*THETA_POINT
      STRESS3(1,:) = [STRESS6(1),STRESS6(6),STRESS6(4)]                  ! Set stress3(1,:) to [stress6(1),stress6(6),stress6(4)].
      STRESS3(2,:) = [STRESS6(6),STRESS6(2),STRESS6(5)]                  ! Set stress3(2,:) to [stress6(6),stress6(2),stress6(5)].
      STRESS3(3,:) = [STRESS6(4),STRESS6(5),STRESS6(3)]                  ! Set stress3(3,:) to [stress6(4),stress6(5),stress6(3)].
      DO J = 1_I4, N_DOF                                                 ! Loop j from 1 to n_dof:
        WORK%SG(:,J) = MATMUL(STRESS3,WORK%GRAD(:,J))                    ! Set work.sg(:,j) to matmul(stress3,work.grad(:,j)).
        WORK%A_STACK(1:9,J) = 0.0_R8                                     ! Set work.a_stack(1:9,j) to zero.
        WORK%B_STACK(1:9,J) = 0.0_R8                                     ! Set work.b_stack(1:9,j) to zero.
        IF (FIELD(J) .GT. 3_I4) CYCLE                                    ! If field(j) > 3, skip to the next iteration.
        DO I = 1_I4, 3_I4                                                ! Loop i from 1 to 3:
          WORK%A_STACK(3*(I-1)+1:3*I,J) = WORK%DIRECTION(I,J)*           ! Set work.a_stack(3*(i-1)+1:3*i,j) to work.direction(i,j)* work.grad(:,j).
     &      WORK%GRAD(:,J)
          WORK%B_STACK(3*(I-1)+1:3*I,J) = WEIGHT*WORK%DIRECTION(I,J)*    ! Set work.b_stack(3*(i-1)+1:3*i,j) to weight*work.direction(i,j)* work.sg(:,j).
     &      WORK%SG(:,J)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CALL ACCUMULATE_UPPER_PRODUCT(WORK%A_STACK(1:9,:),                 ! Call accumulate upper product with work.a_stack(1:9,:), work.b_stack(1:9,:), 9, stiffness.
     &     WORK%B_STACK(1:9,:), 9_I4, STIFFNESS)

      END SUBROUTINE GEOMETRIC_POINT                                     ! End of the subroutine geometric point.

!  TOTAL LAGRANGIAN (ST. VENANT-KIRCHHOFF) POINT AT THE STATE UVALUE:
!    H = SUM_I U_I D_I (X) GRAD N_I,  E = B U + (H^T H)/2,
!    SIGMA = M E - BETA T (+ P T IN THE POTENTIAL ROWS),
!    F_INT += W B(U)^T SIGMA,
!    K_T += W [B(U)^T M B(U) + (D_I.D_J) GRAD N_I . S GRAD N_J]
!  (UPPER TRIANGLE), WITH B(U) = B + H^T D_I (X) GRAD N_I. THE COUPLING
!  BLOCKS K(U,T), K(PHI,T) GO TO COUPLE WHEN IT IS ALLOCATED.
      SUBROUTINE NONLINEAR_POINT(NR, N_DOF, FIELD, UVALUE, WEIGHT,       ! Subroutine nonlinear point takes nr, n dof, field, uvalue, weight, mcon, beta, any pyro, pyro, work, stiffn...
     &     MCON, BETA, ANY_PYRO, PYRO, WORK, STIFFNESS, INTERNAL,
     &     COUPLE)

      INTEGER(I4), INTENT(IN) :: NR                                      ! Input integer (int32): nr.
      INTEGER(I4), INTENT(IN) :: N_DOF                                   ! Input integer (int32): n_dof.
      INTEGER(I4), INTENT(IN) :: FIELD(:)                                ! Input integer (int32): field(:).
      REAL(R8), INTENT(IN) :: UVALUE(:)                                  ! Input real (real64): uvalue(:).
      REAL(R8), INTENT(IN) :: WEIGHT                                     ! Input real (real64): weight.
      REAL(R8), INTENT(IN) :: MCON(12,12)                                ! Input real (real64): mcon(12,12).
      REAL(R8), INTENT(IN) :: BETA(6)                                    ! Input real (real64): beta(6).
      LOGICAL, INTENT(IN) :: ANY_PYRO                                    ! Input logical: any_pyro.
      REAL(R8), INTENT(IN) :: PYRO(3)                                    ! Input real (real64): pyro(3).
      TYPE(POINT_STATE_WORK_TYPE), INTENT(INOUT) :: WORK                 ! In/out of type point_state_work_type: work.
      REAL(R8), INTENT(INOUT) :: STIFFNESS(:,:)                          ! In/out real (real64): stiffness(:,:).
      REAL(R8), INTENT(INOUT) :: INTERNAL(:)                             ! In/out real (real64): internal(:).
      REAL(R8), ALLOCATABLE, INTENT(INOUT) :: COUPLE(:,:)                ! Allocatable in/out real (real64): couple(:,:).
      REAL(R8) :: GAMMA_V(12)                                            ! Real (real64): gamma_v(12).
      REAL(R8) :: SIGMA(12)                                              ! Real (real64): sigma(12).
      REAL(R8) :: H(3,3)                                                 ! Real (real64): h(3,3).
      REAL(R8) :: HH(3,3)                                                ! Real (real64): hh(3,3).
      REAL(R8) :: S3(3,3)                                                ! Real (real64): s3(3,3).
      REAL(R8) :: W3(3)                                                  ! Real (real64): w3(3).
      REAL(R8) :: THETA_POINT                                            ! Real (real64): theta_point.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      GAMMA_V = 0.0_R8                                                   ! Set gamma_v to zero.
      THETA_POINT = 0.0_R8                                               ! Set theta_point to zero.
      H = 0.0_R8                                                         ! Set h to zero.
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        WORK%B_TOTAL(:,I) = WORK%BCOL(1:NR,I)                            ! Set work.b_total(:,i) to work.bcol(1:nr,i).
        GAMMA_V(1:NR) = GAMMA_V(1:NR) + WORK%BCOL(1:NR,I)*UVALUE(I)      ! Add work.bcol(1:nr,i)*uvalue(i) to gamma_v(1:nr).
        IF (FIELD(I) .EQ. FIELD_T) THETA_POINT =                         ! If field(i) = field_t, add work.value(i)*uvalue(i) to theta_point.
     &    THETA_POINT + WORK%VALUE(I)*UVALUE(I)
        IF (FIELD(I) .LE. 3_I4) THEN                                     ! If field(i) <= 3:
          DO J = 1_I4, 3_I4                                              ! Loop j from 1 to 3:
            H(:,J) = H(:,J) + UVALUE(I)*WORK%DIRECTION(:,I)*             ! Add uvalue(i)*work.direction(:,i)* work.grad(j,i) to h(:,j).
     &               WORK%GRAD(J,I)
          END DO                                                         ! End of the loop.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
!     GREEN STRAIN: LINEAR PART (ALREADY IN GAMMA) + (H^T H)/2.
      HH = MATMUL(TRANSPOSE(H),H)                                        ! Set hh to matmul(transpose(h),h).
      GAMMA_V(1) = GAMMA_V(1) + 0.5_R8*HH(1,1)                           ! Add 0.5*hh(1,1) to gamma_v(1).
      GAMMA_V(2) = GAMMA_V(2) + 0.5_R8*HH(2,2)                           ! Add 0.5*hh(2,2) to gamma_v(2).
      GAMMA_V(3) = GAMMA_V(3) + 0.5_R8*HH(3,3)                           ! Add 0.5*hh(3,3) to gamma_v(3).
      GAMMA_V(4) = GAMMA_V(4) + HH(1,3)                                  ! Add hh(1,3) to gamma_v(4).
      GAMMA_V(5) = GAMMA_V(5) + HH(2,3)                                  ! Add hh(2,3) to gamma_v(5).
      GAMMA_V(6) = GAMMA_V(6) + HH(1,2)                                  ! Add hh(1,2) to gamma_v(6).
      SIGMA(1:NR) = MATMUL(MCON(1:NR,1:NR),GAMMA_V(1:NR))                ! Set sigma(1:nr) to matmul(mcon(1:nr,1:nr),gamma_v(1:nr)).
      SIGMA(1:6) = SIGMA(1:6) - BETA*THETA_POINT                         ! Subtract beta*theta_point from sigma(1:6).
      IF (NR .GE. 9_I4 .AND. ANY_PYRO)                                   ! If nr >= 9 and any_pyro, add theta_point*pyro to sigma(7:9).
     &  SIGMA(7:9) = SIGMA(7:9) + THETA_POINT*PYRO
      S3(1,:) = [SIGMA(1),SIGMA(6),SIGMA(4)]                             ! Set s3(1,:) to [sigma(1),sigma(6),sigma(4)].
      S3(2,:) = [SIGMA(6),SIGMA(2),SIGMA(5)]                             ! Set s3(2,:) to [sigma(6),sigma(2),sigma(5)].
      S3(3,:) = [SIGMA(4),SIGMA(5),SIGMA(3)]                             ! Set s3(3,:) to [sigma(4),sigma(5),sigma(3)].
!     VARIATION OF THE STRAIN: ADD H^T D_I (X) GRAD N_I (SYMMETRIC).
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        IF (FIELD(I) .GT. 3_I4) CYCLE                                    ! If field(i) > 3, skip to the next iteration.
        W3 = MATMUL(TRANSPOSE(H),WORK%DIRECTION(:,I))                    ! Set w3 to matmul(transpose(h),work.direction(:,i)).
        WORK%B_TOTAL(1,I) = WORK%B_TOTAL(1,I) + W3(1)*WORK%GRAD(1,I)     ! Add w3(1)*work.grad(1,i) to work.b_total(1,i).
        WORK%B_TOTAL(2,I) = WORK%B_TOTAL(2,I) + W3(2)*WORK%GRAD(2,I)     ! Add w3(2)*work.grad(2,i) to work.b_total(2,i).
        WORK%B_TOTAL(3,I) = WORK%B_TOTAL(3,I) + W3(3)*WORK%GRAD(3,I)     ! Add w3(3)*work.grad(3,i) to work.b_total(3,i).
        WORK%B_TOTAL(4,I) = WORK%B_TOTAL(4,I) + W3(1)*WORK%GRAD(3,I) +   ! Add w3(1)*work.grad(3,i) + w3(3)*work.grad(1,i) to work.b_total(4,i).
     &                      W3(3)*WORK%GRAD(1,I)
        WORK%B_TOTAL(5,I) = WORK%B_TOTAL(5,I) + W3(2)*WORK%GRAD(3,I) +   ! Add w3(2)*work.grad(3,i) + w3(3)*work.grad(2,i) to work.b_total(5,i).
     &                      W3(3)*WORK%GRAD(2,I)
        WORK%B_TOTAL(6,I) = WORK%B_TOTAL(6,I) + W3(1)*WORK%GRAD(2,I) +   ! Add w3(1)*work.grad(2,i) + w3(2)*work.grad(1,i) to work.b_total(6,i).
     &                      W3(2)*WORK%GRAD(1,I)
      END DO                                                             ! End of the loop.
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        INTERNAL(I) = INTERNAL(I) +                                      ! Add weight*dot_product(work.b_total(:,i),sigma(1:nr)) to internal(i).
     &    WEIGHT*DOT_PRODUCT(WORK%B_TOTAL(:,I),SIGMA(1:NR))
      END DO                                                             ! End of the loop.
!     TANGENT = B^T (W M) B + (D_I.D_J)(GRAD N_I . S GRAD N_J) W: ONE
!     PRODUCT OVER NR+9 STACKED ROWS (UPPER TRIANGLE).
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        WORK%MB(:,I) = WEIGHT*MATMUL(MCON(1:NR,1:NR),WORK%B_TOTAL(:,I))  ! Set work.mb(:,i) to weight*matmul(mcon(1:nr,1:nr),work.b_total(:,i)).
        WORK%SG(:,I) = MATMUL(S3,WORK%GRAD(:,I))                         ! Set work.sg(:,i) to matmul(s3,work.grad(:,i)).
        WORK%A_STACK(1:NR,I) = WORK%B_TOTAL(:,I)                         ! Set work.a_stack(1:nr,i) to work.b_total(:,i).
        WORK%B_STACK(1:NR,I) = WORK%MB(:,I)                              ! Set work.b_stack(1:nr,i) to work.mb(:,i).
        DO J = 1_I4, 3_I4                                                ! Loop j from 1 to 3:
          WORK%A_STACK(NR+3*(J-1)+1:NR+3*J,I) = WORK%DIRECTION(J,I)*     ! Set work.a_stack(nr+3*(j-1)+1:nr+3*j,i) to work.direction(j,i)* work.grad(:,i).
     &      WORK%GRAD(:,I)
          WORK%B_STACK(NR+3*(J-1)+1:NR+3*J,I) = WEIGHT*                  ! Set work.b_stack(nr+3*(j-1)+1:nr+3*j,i) to weight* work.direction(j,i)*work.sg(:,i).
     &      WORK%DIRECTION(J,I)*WORK%SG(:,I)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CALL ACCUMULATE_UPPER_PRODUCT(WORK%A_STACK, WORK%B_STACK,          ! Call accumulate upper product with work.a_stack, work.b_stack, nr+9, stiffness.
     &                              NR+9_I4, STIFFNESS)
!     COUPLING OF THE TEMPERATURE: THERMOELASTIC AND PYROELECTRIC.
      IF (ALLOCATED(COUPLE)) THEN                                        ! If allocated(couple):
        DO J = 1_I4, N_DOF                                               ! Loop j from 1 to n_dof:
          IF (FIELD(J) .NE. FIELD_T) CYCLE                               ! If field(j) /= field_t, skip to the next iteration.
          DO I = 1_I4, N_DOF                                             ! Loop i from 1 to n_dof:
            IF (FIELD(I) .LE. 3_I4) THEN                                 ! If field(i) <= 3:
              COUPLE(I,J) = COUPLE(I,J) - WEIGHT*WORK%VALUE(J)*          ! Subtract weight*work.value(j)* dot_product(work.b_total(1:6,i),beta) from couple(i,j).
     &          DOT_PRODUCT(WORK%B_TOTAL(1:6,I),BETA)
            ELSE IF (FIELD(I) .EQ. FIELD_P .AND. ANY_PYRO) THEN          ! Otherwise, if field(i) = field_p and any_pyro:
              COUPLE(I,J) = COUPLE(I,J) + WEIGHT*WORK%VALUE(J)*          ! Add weight*work.value(j)* dot_product(work.b_total(7:9,i),pyro) to couple(i,j).
     &          DOT_PRODUCT(WORK%B_TOTAL(7:9,I),PYRO)
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE NONLINEAR_POINT                                     ! End of the subroutine nonlinear point.

!  M = SUM_P (W RHO)_P N_P N_PT, WITH N NON-ZERO ONLY BETWEEN DOFS OF
!  THE SAME FIELD: ONE PRODUCT PER FIELD. BASIS_VALUE(POINT,DOF).
      SUBROUTINE ADD_MASS(MATRICES, BASIS_VALUE, POINT_MASS,             ! Subroutine add mass takes matrices, basis value, point mass, point capacity, count, skip displacement.
     &                    POINT_CAPACITY, COUNT, SKIP_DISPLACEMENT)

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      REAL(R8), INTENT(IN) :: BASIS_VALUE(:,:)                           ! Input real (real64): basis_value(:,:).
      REAL(R8), INTENT(IN) :: POINT_MASS(:)                              ! Input real (real64): point_mass(:).
      REAL(R8), INTENT(IN) :: POINT_CAPACITY(:)                          ! Input real (real64): point_capacity(:).
      INTEGER(I4), INTENT(IN) :: COUNT                                   ! Input integer (int32): count.
!     SKIP_DISPLACEMENT: THE DISPLACEMENT MASS IS ADDED BY THE CALLER
!     (KINKED SHELL NODES, DOFS WITH COMBINED DIRECTIONS).
      LOGICAL, INTENT(IN), OPTIONAL :: SKIP_DISPLACEMENT                 ! Input optional logical: skip_displacement.
      REAL(R8), ALLOCATABLE :: SCALED(:,:)                               ! Allocatable real (real64): scaled(:,:).
      INTEGER(I4), ALLOCATABLE :: IDX(:)                                 ! Allocatable integer (int32): idx(:).
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      ALLOCATE(SCALED(SIZE(BASIS_VALUE,1),SIZE(BASIS_VALUE,2)))          ! Allocate memory for scaled(size(basis_value,1),size(basis_value,2)).
      DO I = 1_I4, SIZE(BASIS_VALUE,2)                                   ! Loop i from 1 to size(basis_value,2):
        DO Q = 1_I4, COUNT                                               ! Loop q from 1 to count:
          SCALED(Q,I) = BASIS_VALUE(Q,I)*POINT_MASS(Q)                   ! Set scaled(q,i) to basis_value(q,i)*point_mass(q).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      DO FIELD = 1_I4, 3_I4                                              ! Loop field from 1 to 3:
        IF (PRESENT(SKIP_DISPLACEMENT)) THEN                             ! If present(skip_displacement):
          IF (SKIP_DISPLACEMENT) EXIT                                    ! If skip_displacement, leave the loop.
        END IF                                                           ! End of the IF block.
        IDX = PACK([(Q,Q=1_I4,MATRICES%LOCAL_DOF_COUNT)],                ! Set idx to pack([(q,q=1,matrices.local_dof_count)], matrices.field = field).
     &             MATRICES%FIELD .EQ. FIELD)
        IF (SIZE(IDX) .EQ. 0) CYCLE                                      ! If size(idx) = 0, skip to the next iteration.
        CALL ACCUMULATE_UPPER_PRODUCT(BASIS_VALUE, SCALED, COUNT,        ! Call accumulate upper product with basis_value, scaled, count, matrices.mass, idx.
     &                                MATRICES%MASS, IDX)
      END DO                                                             ! End of the loop.
!     THERMAL CAPACITY: RHO C N N^T ON THE TEMPERATURE DOFS.
      IDX = PACK([(Q,Q=1_I4,MATRICES%LOCAL_DOF_COUNT)],                  ! Set idx to pack([(q,q=1,matrices.local_dof_count)], matrices.field = field_t).
     &           MATRICES%FIELD .EQ. FIELD_T)
      IF (SIZE(IDX) .GT. 0) THEN                                         ! If size(idx) > 0:
        DO I = 1_I4, SIZE(BASIS_VALUE,2)                                 ! Loop i from 1 to size(basis_value,2):
          DO Q = 1_I4, COUNT                                             ! Loop q from 1 to count:
            SCALED(Q,I) = BASIS_VALUE(Q,I)*POINT_CAPACITY(Q)             ! Set scaled(q,i) to basis_value(q,i)*point_capacity(q).
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        CALL ACCUMULATE_UPPER_PRODUCT(BASIS_VALUE, SCALED, COUNT,        ! Call accumulate upper product with basis_value, scaled, count, matrices.mass, idx.
     &                                MATRICES%MASS, IDX)
      END IF                                                             ! End of the IF block.
      END SUBROUTINE ADD_MASS                                            ! End of the subroutine add mass.

      SUBROUTINE MIRROR_UPPER_TRIANGLE(MATRICES, WITH_MASS)              ! Subroutine mirror upper triangle takes matrices, with mass.

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      LOGICAL, INTENT(IN) :: WITH_MASS                                   ! Input logical: with_mass.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      DO J = 1_I4, MATRICES%LOCAL_DOF_COUNT                              ! Loop j from 1 to matrices.local_dof_count:
        DO I = J+1_I4, MATRICES%LOCAL_DOF_COUNT                          ! Loop i from j+1 to matrices.local_dof_count:
          MATRICES%STIFFNESS(I,J) = MATRICES%STIFFNESS(J,I)              ! Set matrices.stiffness(i,j) to matrices.stiffness(j,i).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (WITH_MASS) THEN                                                ! If with_mass:
        DO J = 1_I4, MATRICES%LOCAL_DOF_COUNT                            ! Loop j from 1 to matrices.local_dof_count:
          DO I = J+1_I4, MATRICES%LOCAL_DOF_COUNT                        ! Loop i from j+1 to matrices.local_dof_count:
            MATRICES%MASS(I,J) = MATRICES%MASS(J,I)                      ! Set matrices.mass(i,j) to matrices.mass(j,i).
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE MIRROR_UPPER_TRIANGLE                               ! End of the subroutine mirror upper triangle.

!  DISTINCT EXPANSIONS OF THE DOFS OF AN ELEMENT: TWO DOFS SHARE A
!  TABLE OF EXPANSION FACTORS WHEN THEIR EXPANSION (FAMILY, ORDER,
!  REFERENCE) IS THE SAME, E.G. THE THREE DISPLACEMENT COMPONENTS.
      SUBROUTINE SETUP_POINT_WORK(MATRICES, KINEMATICS, WORK)            ! Subroutine setup point work takes matrices, kinematics, work.

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(IN) :: MATRICES                  ! Input of type element_matrix_type: matrices.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(POINT_WORK_TYPE), INTENT(INOUT) :: WORK                       ! In/out of type point_work_type: work.
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: F                                                   ! Integer (int32): f.

      N_DOF = MATRICES%LOCAL_DOF_COUNT                                   ! Set n_dof to matrices.local_dof_count.
      N_NODE = SIZE(MATRICES%KINEMATIC_INDEX)                            ! Set n_node to the size of matrices.kinematic_index.
      ALLOCATE(WORK%MEMO_OF(N_DOF), WORK%MEMO_NODE(N_DOF),               ! Allocate memory for work.memo_of(n_dof), work.memo_node(n_dof), work.memo_terms(n_dof), work.memo_kin(n_dof...
     &         WORK%MEMO_TERMS(N_DOF), WORK%MEMO_KIN(N_DOF),
     &         WORK%MEMO_FIELD(N_DOF))
      WORK%N_MEMO = 0_I4                                                 ! Set work.n_memo to zero.
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        K = MATRICES%KINEMATIC_INDEX(MATRICES%STRUCTURAL_NODE(I))        ! Set k to matrices.kinematic_index(matrices.structural_node(i)).
        F = MATRICES%FIELD(I)                                            ! Set f to matrices.field(i).
        WORK%MEMO_OF(I) = 0_I4                                           ! Set work.memo_of(i) to zero.
        DO M = 1_I4, WORK%N_MEMO                                         ! Loop m from 1 to work.n_memo:
          IF (SAME_EXPANSION(                                            ! If same_expansion( kinematics.item(k).field(f), kinematics.item(work.memo_kin(m)).field( work.memo_field(m))):
     &        KINEMATICS%ITEM(K)%FIELD(F),
     &        KINEMATICS%ITEM(WORK%MEMO_KIN(M))%FIELD(
     &        WORK%MEMO_FIELD(M)))) THEN
            WORK%MEMO_OF(I) = M                                          ! Set work.memo_of(i) to m.
            EXIT                                                         ! Leave the loop.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        IF (WORK%MEMO_OF(I) .EQ. 0_I4) THEN                              ! If work.memo_of(i) = 0:
          WORK%N_MEMO = WORK%N_MEMO + 1_I4                               ! Add 1 to work.n_memo.
          WORK%MEMO_NODE(WORK%N_MEMO) = MATRICES%STRUCTURAL_NODE(I)      ! Set work.memo_node(work.n_memo) to matrices.structural_node(i).
          WORK%MEMO_KIN(WORK%N_MEMO) = K                                 ! Set work.memo_kin(work.n_memo) to k.
          WORK%MEMO_FIELD(WORK%N_MEMO) = F                               ! Set work.memo_field(work.n_memo) to f.
          WORK%MEMO_TERMS(WORK%N_MEMO) = 0_I4                            ! Set work.memo_terms(work.n_memo) to zero.
          WORK%MEMO_OF(I) = WORK%N_MEMO                                  ! Set work.memo_of(i) to work.n_memo.
        END IF                                                           ! End of the IF block.
        WORK%MEMO_TERMS(WORK%MEMO_OF(I)) = MAX(                          ! Set work.memo_terms(work.memo_of(i)) to the larger of work.memo_terms(work.memo_of(i)) and matrices.term(i).
     &    WORK%MEMO_TERMS(WORK%MEMO_OF(I)), MATRICES%TERM(I))
      END DO                                                             ! End of the loop.
      ALLOCATE(WORK%SVAL(N_NODE), WORK%SGRAD(3,N_NODE))                  ! Allocate memory for work.sval(n_node), work.sgrad(3,n_node).
      ALLOCATE(WORK%FVAL(MAXVAL(WORK%MEMO_TERMS(1:WORK%N_MEMO)),         ! Allocate memory for work.fval(maxval(work.memo_terms(1:work.n_memo)), work.n_memo).
     &                   WORK%N_MEMO))
      ALLOCATE(WORK%FGRAD(3,MAXVAL(WORK%MEMO_TERMS(1:WORK%N_MEMO)),      ! Allocate memory for work.fgrad(3,maxval(work.memo_terms(1:work.n_memo)), work.n_memo).
     &                    WORK%N_MEMO))
      ALLOCATE(WORK%VALUE(N_DOF), WORK%BCOL(12,N_DOF),                   ! Allocate memory for work.value(n_dof), work.bcol(12,n_dof), work.grad(3,n_dof).
     &         WORK%GRAD(3,N_DOF))

      END SUBROUTINE SETUP_POINT_WORK                                    ! End of the subroutine setup point work.

      LOGICAL FUNCTION SAME_EXPANSION(A, B)                              ! Function same expansion takes a, b.

      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: A                         ! Input of type expansion_spec_type: a.
      TYPE(EXPANSION_SPEC_TYPE), INTENT(IN) :: B                         ! Input of type expansion_spec_type: b.

      SAME_EXPANSION = A%FAMILY .EQ. B%FAMILY .AND.                      ! Set same_expansion to a.family = b.family and a.order = b.order and a.field_reference = b.field_reference.
     &  A%ORDER .EQ. B%ORDER .AND.
     &  A%FIELD_REFERENCE .EQ. B%FIELD_REFERENCE

      END FUNCTION SAME_EXPANSION                                        ! End of the function same expansion.

!  BASIS VALUE, GRADIENT AND GENERALISED-STRAIN COLUMN OF EVERY DOF AT
!  ONE GAUSS POINT (WORK%VALUE, WORK%GRAD, WORK%BCOL).
      SUBROUTINE EVALUATE_POINT_COLUMNS(POINT, ELEMENT_INDEX, ELEMENTS,  ! Subroutine evaluate point columns takes point, element index, elements, kinematics, expansions, rules, gaus...
     &     KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &     STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &     MATRICES, MITC_DATA, WORK, STATUS)

      INTEGER(I8), INTENT(IN) :: POINT                                   ! Input integer (int64): point.
      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(IN) :: MATRICES                  ! Input of type element_matrix_type: matrices.
      TYPE(MITC_DATA_TYPE), INTENT(IN) :: MITC_DATA                      ! Input of type mitc_data_type: mitc_data.
      TYPE(POINT_WORK_TYPE), INTENT(INOUT) :: WORK                       ! In/out of type point_work_type: work.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(EXPANSION_SPEC_TYPE) :: SPEC                                  ! Of type expansion_spec_type: spec.
      REAL(R8) :: STRUCTURAL_VALUE                                       ! Real (real64): structural_value.
      REAL(R8) :: STRUCTURAL_GRADIENT(3)                                 ! Real (real64): structural_gradient(3).
      REAL(R8) :: FACTOR_VALUE                                           ! Real (real64): factor_value.
      REAL(R8) :: FACTOR_GRADIENT(3)                                     ! Real (real64): factor_gradient(3).
      REAL(R8) :: GRADIENT(3)                                            ! Real (real64): gradient(3).
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.
      INTEGER(I4) :: T                                                   ! Integer (int32): t.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: MEMO                                                ! Integer (int32): memo.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
!     STRUCTURAL FACTORS OF ALL THE NODES (THE EXPANSION OF THE FIRST
!     DISTINCT EXPANSION IS USED ONLY TO REACH THE STRUCTURAL CACHE).
      SPEC = KINEMATICS%ITEM(WORK%MEMO_KIN(1))%FIELD(WORK%MEMO_FIELD(1)) ! Set spec to kinematics.item(work.memo_kin(1)).field(work.memo_field(1)).
      DO N = 1_I4, SIZE(WORK%SVAL)                                       ! Loop n from 1 to size(work.sval):
        CALL EVALUATE_POINT_FACTORS(POINT, N, 1_I4, SPEC, ELEMENTS,      ! Call evaluate point factors with point, n, 1, spec, elements, expansions, rules, gauss_layout, structural_c...
     &       EXPANSIONS, RULES, GAUSS_LAYOUT, STRUCTURAL_CACHE,
     &       EXPANSION_CACHE, GEOMETRY, WORK%SVAL(N), WORK%SGRAD(:,N),
     &       FACTOR_VALUE, FACTOR_GRADIENT, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.
!     EXPANSION FACTORS OF EVERY TERM OF EVERY DISTINCT EXPANSION.
      DO M = 1_I4, WORK%N_MEMO                                           ! Loop m from 1 to work.n_memo:
        SPEC = KINEMATICS%ITEM(WORK%MEMO_KIN(M))%FIELD(                  ! Set spec to kinematics.item(work.memo_kin(m)).field( work.memo_field(m)).
     &         WORK%MEMO_FIELD(M))
        DO T = 1_I4, WORK%MEMO_TERMS(M)                                  ! Loop t from 1 to work.memo_terms(m):
          CALL EVALUATE_POINT_FACTORS(POINT, WORK%MEMO_NODE(M), T, SPEC, ! Call evaluate point factors with point, work.memo_node(m), t, spec, elements, expansions, rules, gauss_layo...
     &         ELEMENTS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &         STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY,
     &         STRUCTURAL_VALUE, STRUCTURAL_GRADIENT,
     &         WORK%FVAL(T,M), WORK%FGRAD(:,T,M), STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
!     BASIS OF EVERY DOF AND ITS GENERALISED-STRAIN COLUMN.
      DO I = 1_I4, MATRICES%LOCAL_DOF_COUNT                              ! Loop i from 1 to matrices.local_dof_count:
        NODE = MATRICES%STRUCTURAL_NODE(I)                               ! Set node to matrices.structural_node(i).
        MEMO = WORK%MEMO_OF(I)                                           ! Set memo to work.memo_of(i).
        T = MATRICES%TERM(I)                                             ! Set t to matrices.term(i).
        CALL COMPOSE_PRODUCT_BASIS(WORK%SVAL(NODE), WORK%SGRAD(:,NODE),  ! Call compose product basis with work.sval(node), work.sgrad(:,node), work.fval(t,memo), work.fgrad(:,t,memo...
     &       WORK%FVAL(T,MEMO), WORK%FGRAD(:,T,MEMO),
     &       WORK%VALUE(I), GRADIENT)
        WORK%GRAD(:,I) = GRADIENT                                        ! Set work.grad(:,i) to gradient.
        CALL COLUMN_FROM_BASIS(POINT, ELEMENT_INDEX,                     ! Call column from basis with point, element_index, matrices.field(i), node, rules, gauss_layout, frames, mit...
     &       MATRICES%FIELD(I), NODE, RULES, GAUSS_LAYOUT, FRAMES,
     &       MITC_DATA, GRADIENT, WORK%FVAL(T,MEMO),
     &       WORK%FGRAD(:,T,MEMO), WORK%VALUE(I), WORK%BCOL(:,I),
     &       STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_POINT_COLUMNS                              ! End of the subroutine evaluate point columns.

!  GENERALISED-STRAIN COLUMN OF A DOF FROM ITS BASIS GRADIENT: THE
!  DISPLACEMENT OPERATOR (WITH THE MITC TYING WHEN ACTIVE), THE
!  POTENTIAL GRADIENT (ROWS 7-9) OR THE TEMPERATURE GRADIENT (10-12).
      SUBROUTINE COLUMN_FROM_BASIS(POINT, ELEMENT_INDEX, FIELD,          ! Subroutine column from basis takes point, element index, field, structural node, rules, gauss layout, frame...
     &     STRUCTURAL_NODE, RULES, GAUSS_LAYOUT, FRAMES, MITC_DATA,
     &     GRADIENT, FACTOR_VALUE, FACTOR_GRADIENT, VALUE, B_COLUMN,
     &     STATUS)

      INTEGER(I8), INTENT(IN) :: POINT                                   ! Input integer (int64): point.
      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      INTEGER(I4), INTENT(IN) :: FIELD                                   ! Input integer (int32): field.
      INTEGER(I4), INTENT(IN) :: STRUCTURAL_NODE                         ! Input integer (int32): structural_node.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MITC_DATA_TYPE), INTENT(IN) :: MITC_DATA                      ! Input of type mitc_data_type: mitc_data.
      REAL(R8), INTENT(IN) :: GRADIENT(3)                                ! Input real (real64): gradient(3).
      REAL(R8), INTENT(IN) :: FACTOR_VALUE                               ! Input real (real64): factor_value.
      REAL(R8), INTENT(IN) :: FACTOR_GRADIENT(3)                         ! Input real (real64): factor_gradient(3).
      REAL(R8), INTENT(INOUT) :: VALUE                                   ! In/out real (real64): value.
      REAL(R8), INTENT(OUT) :: B_COLUMN(12)                              ! Output real (real64): b_column(12).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: B_OPERATOR(6,3)                                        ! Real (real64): b_operator(6,3).
      REAL(R8) :: NATURAL(3)                                             ! Real (real64): natural(3).
      INTEGER(I4) :: RULE_INDEX                                          ! Integer (int32): rule_index.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      B_COLUMN = 0.0_R8                                                  ! Set b_column to zero.
      IF (FIELD .EQ. FIELD_P) THEN                                       ! If field = field_p:
        B_COLUMN(7:9) = GRADIENT                                         ! Set b_column(7:9) to gradient.
        VALUE = 0.0_R8                                                   ! Set value to zero.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (FIELD .EQ. FIELD_T) THEN                                       ! If field = field_t:
        B_COLUMN(10:12) = GRADIENT                                       ! Set b_column(10:12) to gradient.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL BUILD_DISPLACEMENT_OPERATOR(GRADIENT, B_OPERATOR, STATUS)     ! Call build displacement operator with gradient, b_operator, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      B_COLUMN(1:6) = MATMUL(B_OPERATOR,                                 ! Set b_column(1:6) to matmul(b_operator, frames.global_to_local(:,field,element_index)).
     &  FRAMES%GLOBAL_TO_LOCAL(:,FIELD,ELEMENT_INDEX))
      IF (MITC_DATA%ACTIVE) THEN                                         ! If mitc_data.active:
        RULE_INDEX = GAUSS_LAYOUT%STRUCTURAL_RULE_INDEX(POINT)           ! Set rule_index to gauss_layout.structural_rule_index(point).
        NATURAL = RULES%ITEM(RULE_INDEX)%COORDINATE(                     ! Set natural to rules.item(rule_index).coordinate( gauss_layout.structural_point_index(point),1:3).
     &            GAUSS_LAYOUT%STRUCTURAL_POINT_INDEX(POINT),1:3)
        CALL MITC_TIE_COLUMN(MITC_DATA, NATURAL, STRUCTURAL_NODE,        ! Call mitc tie column with mitc_data, natural, structural_node, factor_value, factor_gradient, frames.global...
     &       FACTOR_VALUE, FACTOR_GRADIENT,
     &       FRAMES%GLOBAL_TO_LOCAL(:,FIELD,ELEMENT_INDEX),
     &       B_COLUMN(1:6), STATUS)
      END IF                                                             ! End of the IF block.

      END SUBROUTINE COLUMN_FROM_BASIS                                   ! End of the subroutine column from basis.

      SUBROUTINE BUILD_ELEMENT_DOF_LIST(ELEMENT_INDEX, NODES,            ! Subroutine build element dof list takes element index, nodes, elements, kinematics, dof layout, matrices, s...
     &     ELEMENTS, KINEMATICS, DOF_LAYOUT, MATRICES, STATUS)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I4) :: NODE_INDEX                                          ! Integer (int32): node_index.
      INTEGER(I4) :: KINEMATIC_INDEX                                     ! Integer (int32): kinematic_index.
      INTEGER(I4) :: LOCAL_NODE                                          ! Integer (int32): local_node.
      INTEGER(I4) :: FIELD                                               ! Integer (int32): field.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.

      COUNT = 0_I4                                                       ! Set count to zero.
      DO LOCAL_NODE = 1_I4,                                              ! Loop local_node from 1 to size(elements.item(element_index).node_id):
     & SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID)
        NODE_INDEX = FIND_NODE_INDEX(NODES,                              ! Set node_index to find_node_index(nodes, elements.item(element_index).node_id(local_node)).
     &   ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID(LOCAL_NODE))
        IF (NODE_INDEX .EQ. 0_I4) THEN                                   ! If node_index = 0:
          CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_DOF_LIST',               ! Record an error in status: 'ELEMENT REFERENCES UNKNOWN NODE'.
     &                   'ELEMENT REFERENCES UNKNOWN NODE')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO FIELD = 1_I4, N_SOLVED_FIELDS                                 ! Loop field from 1 to n_solved_fields:
          COUNT = COUNT+DOF_LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)          ! Add dof_layout.term_count(node_index,field) to count.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (COUNT .LT. 1_I4) THEN                                          ! If count < 1:
        CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_DOF_LIST',                 ! Record an error in status: 'ELEMENT HAS NO MECHANICAL DEGREES OF FREEDOM'.
     &                 'ELEMENT HAS NO MECHANICAL DEGREES OF FREEDOM')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      MATRICES%ELEMENT_INDEX = ELEMENT_INDEX                             ! Set matrices.element_index to element_index.
      MATRICES%LOCAL_DOF_COUNT = COUNT                                   ! Set matrices.local_dof_count to count.
      ALLOCATE(MATRICES%GLOBAL_DOF(COUNT))                               ! Allocate memory for matrices.global_dof(count).
      ALLOCATE(MATRICES%NODE_INDEX(SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%    ! Allocate memory for matrices.node_index(size(elements.item(element_index). node_id)).
     &                                  NODE_ID)))
      ALLOCATE(MATRICES%KINEMATIC_INDEX(SIZE(ELEMENTS%ITEM(              ! Allocate memory for matrices.kinematic_index(size(elements.item( element_index).node_id)).
     &                                  ELEMENT_INDEX)%NODE_ID)))
      ALLOCATE(MATRICES%STRUCTURAL_NODE(COUNT))                          ! Allocate memory for matrices.structural_node(count).
      ALLOCATE(MATRICES%FIELD(COUNT))                                    ! Allocate memory for matrices.field(count).
      ALLOCATE(MATRICES%TERM(COUNT))                                     ! Allocate memory for matrices.term(count).
      COUNT = 0_I4                                                       ! Set count to zero.
      DO LOCAL_NODE = 1_I4,                                              ! Loop local_node from 1 to size(elements.item(element_index).node_id):
     & SIZE(ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID)
        NODE_INDEX = FIND_NODE_INDEX(NODES,                              ! Set node_index to find_node_index(nodes, elements.item(element_index).node_id(local_node)).
     &   ELEMENTS%ITEM(ELEMENT_INDEX)%NODE_ID(LOCAL_NODE))
        KINEMATIC_INDEX = FIND_KINEMATIC_INDEX(KINEMATICS,               ! Set kinematic_index to find_kinematic_index(kinematics, nodes.item(node_index).kinematic_id).
     &   NODES%ITEM(NODE_INDEX)%KINEMATIC_ID)
        MATRICES%NODE_INDEX(LOCAL_NODE) = NODE_INDEX                     ! Set matrices.node_index(local_node) to node_index.
        MATRICES%KINEMATIC_INDEX(LOCAL_NODE) = KINEMATIC_INDEX           ! Set matrices.kinematic_index(local_node) to kinematic_index.
        IF (KINEMATIC_INDEX .EQ. 0_I4) THEN                              ! If kinematic_index = 0:
          CALL SET_ERROR(STATUS, 'BUILD_ELEMENT_DOF_LIST',               ! Record an error in status: 'NODE REFERENCES UNKNOWN KINEMATIC'.
     &                   'NODE REFERENCES UNKNOWN KINEMATIC')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO FIELD = 1_I4, N_SOLVED_FIELDS                                 ! Loop field from 1 to n_solved_fields:
          DO TERM = 1_I4, DOF_LAYOUT%TERM_COUNT(NODE_INDEX,FIELD)        ! Loop term from 1 to dof_layout.term_count(node_index,field):
            COUNT = COUNT+1_I4                                           ! Add 1 to count.
            MATRICES%GLOBAL_DOF(COUNT) = GLOBAL_DOF(DOF_LAYOUT,          ! Set matrices.global_dof(count) to global_dof(dof_layout, node_index,field,term).
     &                                      NODE_INDEX,FIELD,TERM)
            MATRICES%STRUCTURAL_NODE(COUNT) = LOCAL_NODE                 ! Set matrices.structural_node(count) to local_node.
            MATRICES%FIELD(COUNT) = FIELD                                ! Set matrices.field(count) to field.
            MATRICES%TERM(COUNT) = TERM                                  ! Set matrices.term(count) to term.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_ELEMENT_DOF_LIST                              ! End of the subroutine build element dof list.

      SUBROUTINE VALIDATE_INPUT(ELEMENT_INDEX, NODES, ELEMENTS,          ! Subroutine validate input takes element index, nodes, elements, kinematics, dof layout, gauss layout, geome...
     &     KINEMATICS, DOF_LAYOUT, GAUSS_LAYOUT, GEOMETRY,
     &     FRAMES, MATERIAL_CACHE, MATERIAL_MAP, STATUS)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: MATERIAL_CACHE            ! Input of type material_cache_type: material_cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(IN) :: MATERIAL_MAP          ! Input of type gauss_material_map_type: material_map.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.

      IF (.NOT. ALLOCATED(NODES%ITEM) .OR.                               ! If not allocated(nodes.item) or not allocated(elements.item) or not allocated(kinematics.item) or not alloc...
     &    .NOT. ALLOCATED(ELEMENTS%ITEM) .OR.
     &    .NOT. ALLOCATED(KINEMATICS%ITEM) .OR.
     &    .NOT. ALLOCATED(DOF_LAYOUT%TERM_COUNT)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',          ! Record an error in status: 'MODEL DATABASES ARE NOT ALLOCATED'.
     &                 'MODEL DATABASES ARE NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (ELEMENT_INDEX .LT. 1_I4 .OR. ELEMENT_INDEX .GT.                ! If element_index < 1 or element_index > size(elements.item):
     &    SIZE(ELEMENTS%ITEM)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',          ! Record an error in status: 'ELEMENT INDEX IS OUT OF RANGE'.
     &                 'ELEMENT INDEX IS OUT OF RANGE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (.NOT. ALLOCATED(GAUSS_LAYOUT%ELEMENT_FIRST) .OR.               ! If not allocated(gauss_layout.element_first) or not allocated(geometry.integration_weight) or not allocated...
     &    .NOT. ALLOCATED(GEOMETRY%INTEGRATION_WEIGHT) .OR.
     &    .NOT. ALLOCATED(FRAMES%GLOBAL_TO_LOCAL) .OR.
     &    .NOT. ALLOCATED(MATERIAL_CACHE%STIFFNESS_LOCAL) .OR.
     &    .NOT. ALLOCATED(MATERIAL_MAP%CACHE_INDEX)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',          ! Record an error in status: 'INTEGRATION DATABASES ARE NOT ALLOCATED'.
     &                 'INTEGRATION DATABASES ARE NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (GAUSS_LAYOUT%ELEMENT_FIRST(ELEMENT_INDEX) .LT. 1_I8 .OR.       ! If gauss_layout.element_first(element_index) < 1 or gauss_layout.element_last(element_index) > gauss_layout...
     &    GAUSS_LAYOUT%ELEMENT_LAST(ELEMENT_INDEX) .GT.
     &    GAUSS_LAYOUT%COUNT .OR. GEOMETRY%COUNT .NE.
     &    GAUSS_LAYOUT%COUNT .OR. MATERIAL_MAP%COUNT .NE.
     &    GAUSS_LAYOUT%COUNT) THEN
        CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',          ! Record an error in status: 'GAUSS DATABASES ARE INCONSISTENT'.
     &                 'GAUSS DATABASES ARE INCONSISTENT')
      END IF                                                             ! End of the IF block.

      END SUBROUTINE VALIDATE_INPUT                                      ! End of the subroutine validate input.

      SUBROUTINE CLEAR_ELEMENT_MATRIX(MATRICES)                          ! Subroutine clear element matrix takes matrices.

      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.

      IF (ALLOCATED(MATRICES%GLOBAL_DOF))                                ! If allocated(matrices.global_dof), free the memory of matrices.global_dof.
     &  DEALLOCATE(MATRICES%GLOBAL_DOF)
      IF (ALLOCATED(MATRICES%NODE_INDEX))                                ! If allocated(matrices.node_index), free the memory of matrices.node_index.
     &  DEALLOCATE(MATRICES%NODE_INDEX)
      IF (ALLOCATED(MATRICES%KINEMATIC_INDEX))                           ! If allocated(matrices.kinematic_index), free the memory of matrices.kinematic_index.
     &  DEALLOCATE(MATRICES%KINEMATIC_INDEX)
      IF (ALLOCATED(MATRICES%STRUCTURAL_NODE))                           ! If allocated(matrices.structural_node), free the memory of matrices.structural_node.
     &  DEALLOCATE(MATRICES%STRUCTURAL_NODE)
      IF (ALLOCATED(MATRICES%FIELD)) DEALLOCATE(MATRICES%FIELD)          ! If allocated(matrices.field), free the memory of matrices.field.
      IF (ALLOCATED(MATRICES%TERM)) DEALLOCATE(MATRICES%TERM)            ! If allocated(matrices.term), free the memory of matrices.term.
      IF (ALLOCATED(MATRICES%CSR_POSITION))                              ! If allocated(matrices.csr_position), free the memory of matrices.csr_position.
     &  DEALLOCATE(MATRICES%CSR_POSITION)
      IF (ALLOCATED(MATRICES%STIFFNESS))                                 ! If allocated(matrices.stiffness), free the memory of matrices.stiffness.
     &  DEALLOCATE(MATRICES%STIFFNESS)
      IF (ALLOCATED(MATRICES%MASS)) DEALLOCATE(MATRICES%MASS)            ! If allocated(matrices.mass), free the memory of matrices.mass.
      IF (ALLOCATED(MATRICES%INTERNAL_FORCE))                            ! If allocated(matrices.internal_force), free the memory of matrices.internal_force.
     &  DEALLOCATE(MATRICES%INTERNAL_FORCE)
      MATRICES%ELEMENT_INDEX = 0_I4                                      ! Set matrices.element_index to zero.
      MATRICES%LOCAL_DOF_COUNT = 0_I4                                    ! Set matrices.local_dof_count to zero.

      END SUBROUTINE CLEAR_ELEMENT_MATRIX                                ! End of the subroutine clear element matrix.

      END MODULE MUL2_ELEMENT_MATRICES                                   ! End of the module mul2 element matrices.
