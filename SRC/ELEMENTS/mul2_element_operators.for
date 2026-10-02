!=======================================================================
!  ELEMENT OPERATORS ON THE CONTRACT OF A POINT.
!
!  EVERY ELEMENT, ORDINARY (STRAIGHT BEAM, FLAT PLATE, SOLID) OR GENERAL
!  (CURVED BEAM, SHELL), PROVIDES AT EACH INTEGRATION POINT THE SAME
!  CONTRACT (POINT_STATE_WORK_TYPE OF MUL2_ELEMENT_MATRICES):
!    VALUE(I)        BASIS OF THE DOF I
!    BCOL(:,I)       GENERALISED-STRAIN COLUMN IN THE FRAME OF THE POINT
!    GRAD(:,I)       GRADIENT OF THE BASIS IN THAT FRAME
!    DIRECTION(:,I)  DISPLACEMENT DIRECTION OF THE DOF IN THAT FRAME
!  AND THE INTEGRATION WEIGHT. THE POINT PROVIDER BELOW IS THE ONLY PART
!  THAT KNOWS THE KIND OF ELEMENT; THE OPERATORS ARE COMMON:
!    BUILD_LINEAR_ELEMENT_MATRICES  K, M, THERMOELASTIC / PYROELECTRIC
!                                   COUPLING (SEPARABLE FAST PATH FOR THE
!                                   ORDINARY ELEMENTS WHEN POSSIBLE)
!    BUILD_STATE_ELEMENT_MATRICES   GEOMETRIC MATRIX, OR NONLINEAR
!                                   TANGENT AND INTERNAL FORCE, AT A STATE
!=======================================================================
      MODULE MUL2_ELEMENT_OPERATORS                                      ! Module mul2 element operators begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE                                 ! Use from module mul2 nodes: node db type.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION              ! Use from module mul2 topologies: topology natural dimension.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE, FIELD_P, FIELD_T    ! Use from module mul2 kinematics: kinematics db type, field p, field t.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE                 ! Use from module mul2 expansion meshes: expansion db type.
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_GAUSS_POINTS, ONLY: REFERENCE_RULE_DB_TYPE,               ! Use from module mul2 gauss points: reference rule db type, gauss layout type.
     &                             GAUSS_LAYOUT_TYPE
      USE MUL2_GAUSS_GEOMETRY, ONLY: STRUCTURAL_GEOMETRY_CACHE_TYPE,     ! Use from module mul2 gauss geometry: structural geometry cache type, expansion geometry cache type, gauss g...
     &     EXPANSION_GEOMETRY_CACHE_TYPE, GAUSS_GEOMETRY_TYPE
      USE MUL2_GAUSS_MATERIALS, ONLY: MATERIAL_CACHE_TYPE,               ! Use from module mul2 gauss materials: material cache type, gauss material map type, part full, generalized ...
     &     GAUSS_MATERIAL_MAP_TYPE, PART_FULL,
     &     GENERALIZED_CONSTITUTIVE, THERMAL_STRESS_COEFFICIENT
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE                         ! Use from module mul2 dof layout: dof layout type.
      USE MUL2_MITC, ONLY: MITC_DATA_TYPE                                ! Use from module mul2 mitc: mitc data type.
      USE MUL2_DENSE_PRODUCTS, ONLY: ACCUMULATE_UPPER_PRODUCT            ! Use from module mul2 dense products: accumulate upper product.
      USE MUL2_SEPARABLE_KERNEL, ONLY: BUILD_SEPARABLE_MATRICES          ! Use from module mul2 separable kernel: build separable matrices.
      USE MUL2_GENERAL_GEOMETRY, ONLY: IS_GENERAL_ELEMENT                ! Use from module mul2 general geometry: is general element.
      USE MUL2_ELEMENT_MATRICES, ONLY: ELEMENT_MATRIX_TYPE,              ! Use from module mul2 element matrices: element matrix type, point work type, point state work type, max bat...
     &     POINT_WORK_TYPE, POINT_STATE_WORK_TYPE, MAX_BATCH,
     &     BUILD_ELEMENT_DOF_LIST, CLEAR_ELEMENT_MATRIX,
     &     VALIDATE_INPUT, SETUP_POINT_WORK, EVALUATE_POINT_COLUMNS,
     &     SETUP_POINT_STATE_WORK, GEOMETRIC_POINT, NONLINEAR_POINT,
     &     ADD_MASS, MIRROR_UPPER_TRIANGLE
      USE MUL2_GENERAL_KERNEL, ONLY: GENERAL_CONTEXT_TYPE,               ! Use from module mul2 general kernel: general context type, general context setup, general point input, gene...
     &     GENERAL_CONTEXT_SETUP, GENERAL_POINT_INPUT,
     &     GENERAL_POINT_COLUMNS

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!  THE POINT PROVIDER: WORK DATA OF ONE ELEMENT FOR EITHER KERNEL.
      TYPE :: POINT_PROVIDER_TYPE                                        ! Definition of the derived type point provider type.
        LOGICAL :: GENERAL = .FALSE.                                     ! Logical: general = false.
        LOGICAL :: KINKED = .FALSE.                                      ! Logical: kinked = false.
        INTEGER(I4) :: CDIM = 0_I4                                       ! Integer (int32): cdim = 0.
        TYPE(POINT_WORK_TYPE) :: PWORK                                   ! Of type point_work_type: pwork.
        TYPE(MITC_DATA_TYPE) :: MITC                                     ! Of type mitc_data_type: mitc.
        TYPE(GENERAL_CONTEXT_TYPE) :: CTX                                ! Of type general_context_type: ctx.
        REAL(R8), ALLOCATABLE :: F_VALUE(:,:,:)                          ! Allocatable real (real64): f_value(:,:,:).
        REAL(R8), ALLOCATABLE :: F_GRAD(:,:,:,:)                         ! Allocatable real (real64): f_grad(:,:,:,:).
        LOGICAL, ALLOCATABLE :: F_DONE(:,:,:)                            ! Allocatable logical: f_done(:,:,:).
        REAL(R8), ALLOCATABLE :: FV(:)                                   ! Allocatable real (real64): fv(:).
        REAL(R8), ALLOCATABLE :: FG(:,:)                                 ! Allocatable real (real64): fg(:,:).
        REAL(R8), ALLOCATABLE :: DIRG(:,:)                               ! Allocatable real (real64): dirg(:,:).
        INTEGER(I4), ALLOCATABLE :: DOF_NODE(:)                          ! Allocatable integer (int32): dof_node(:).
      END TYPE POINT_PROVIDER_TYPE                                       ! End of the type definition point provider type.

      PUBLIC :: BUILD_LINEAR_ELEMENT_MATRICES                            ! Export: build linear element matrices.
      PUBLIC :: BUILD_STATE_ELEMENT_MATRICES                             ! Export: build state element matrices.

      CONTAINS                                                           ! The procedures of the module follow.

!  K AND M OF AN ELEMENT (OR THE COUPLING BLOCKS ONLY, COUPLING=.TRUE.).
!    MITC        TYING DATA OF AN ORDINARY ELEMENT
!    TYING       MITC TYING OF A GENERAL (CURVED) ELEMENT
!    PART        PART_FULL / PART_NORMAL / PART_SHEAR OF THE CONSTITUTIVE
!                MATRIX (SELECTIVE INTEGRATION)
!    FORCE_GENERAL  NO SEPARABLE FAST PATH
!  K = SUM_P B^T (W C) B IS ONE PRODUCT PER BATCH OF POINTS; THE COUPLING
!  BLOCK K(U,T) = - SUM_P W B^T BETA N_T, K(PHI,T) = SUM_P W GRAD N.P N_T
!  IS NOT SYMMETRIC AND IS RETURNED WITHOUT MIRRORING.
      SUBROUTINE BUILD_LINEAR_ELEMENT_MATRICES(ELEMENT_INDEX,            ! Subroutine build linear element matrices takes element index, nodes, elements, kinematics, expansions, dof ...
     &     NODES, ELEMENTS, KINEMATICS, EXPANSIONS, DOF_LAYOUT,
     &     RULES, GAUSS_LAYOUT, STRUCTURAL_CACHE,
     &     EXPANSION_CACHE, GEOMETRY, FRAMES, MATERIAL_CACHE,
     &     MATERIAL_MAP, MATRICES, STATUS, MITC, WITH_MASS,
     &     FORCE_GENERAL, PART, WITH_STIFFNESS, COUPLING, TYING)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: MATERIAL_CACHE            ! Input of type material_cache_type: material_cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(IN) :: MATERIAL_MAP          ! Input of type gauss_material_map_type: material_map.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(MITC_DATA_TYPE), INTENT(IN), OPTIONAL :: MITC                 ! Input optional of type mitc_data_type: mitc.
      LOGICAL, INTENT(IN), OPTIONAL :: WITH_MASS                         ! Input optional logical: with_mass.
      LOGICAL, INTENT(IN), OPTIONAL :: FORCE_GENERAL                     ! Input optional logical: force_general.
      INTEGER(I4), INTENT(IN), OPTIONAL :: PART                          ! Input optional integer (int32): part.
      LOGICAL, INTENT(IN), OPTIONAL :: WITH_STIFFNESS                    ! Input optional logical: with_stiffness.
      LOGICAL, INTENT(IN), OPTIONAL :: COUPLING                          ! Input optional logical: coupling.
      LOGICAL, INTENT(IN), OPTIONAL :: TYING                             ! Input optional logical: tying.
      TYPE(POINT_PROVIDER_TYPE) :: PROV                                  ! Of type point_provider_type: prov.
      TYPE(POINT_STATE_WORK_TYPE) :: SWORK                               ! Of type point_state_work_type: swork.
      REAL(R8), ALLOCATABLE :: BASIS_VALUE(:,:)                          ! Allocatable real (real64): basis_value(:,:).
      REAL(R8), ALLOCATABLE :: B_TEST(:,:)                               ! Allocatable real (real64): b_test(:,:).
      REAL(R8), ALLOCATABLE :: B_WEIGHTED(:,:)                           ! Allocatable real (real64): b_weighted(:,:).
      REAL(R8), ALLOCATABLE :: A3(:,:)                                   ! Allocatable real (real64): a3(:,:).
      REAL(R8), ALLOCATABLE :: B3(:,:)                                   ! Allocatable real (real64): b3(:,:).
      REAL(R8) :: STIFFNESS_LOCAL(12,12)                                 ! Real (real64): stiffness_local(12,12).
      REAL(R8) :: POINT_MASS(MAX_BATCH)                                  ! Real (real64): point_mass(max_batch).
      REAL(R8) :: POINT_CAPACITY(MAX_BATCH)                              ! Real (real64): point_capacity(max_batch).
      REAL(R8) :: BETA(6)                                                ! Real (real64): beta(6).
      REAL(R8) :: WEIGHT                                                 ! Real (real64): weight.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I8) :: FIRST_POINT                                         ! Integer (int64): first_point.
      INTEGER(I8) :: LAST_POINT                                          ! Integer (int64): last_point.
      INTEGER(I4) :: CPART                                               ! Integer (int32): cpart.
      INTEGER(I4) :: NR                                                  ! Integer (int32): nr.
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: BATCH                                               ! Integer (int32): batch.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: MATERIAL_INDEX                                      ! Integer (int32): material_index.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      LOGICAL :: MASS_REQUESTED                                          ! Logical: mass_requested.
      LOGICAL :: STIFFNESS_REQUESTED                                     ! Logical: stiffness_requested.
      LOGICAL :: THERMAL_REQUESTED                                       ! Logical: thermal_requested.
      LOGICAL :: SEPARABLE                                               ! Logical: separable.
      LOGICAL :: GENERAL                                                 ! Logical: general.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_ELEMENT_MATRIX(MATRICES)                                ! Call clear element matrix with matrices.
      GENERAL = IS_GENERAL_ELEMENT(FRAMES, ELEMENT_INDEX)                ! Set general to is_general_element(frames, element_index).
      MASS_REQUESTED = .TRUE.                                            ! Set the flag mass_requested to true.
      IF (PRESENT(WITH_MASS)) MASS_REQUESTED = WITH_MASS                 ! If present(with_mass), set mass_requested to with_mass.
      CPART = PART_FULL                                                  ! Set cpart to part_full.
      IF (PRESENT(PART)) CPART = PART                                    ! If present(part), set cpart to part.
      STIFFNESS_REQUESTED = .TRUE.                                       ! Set the flag stiffness_requested to true.
      IF (PRESENT(WITH_STIFFNESS)) STIFFNESS_REQUESTED = WITH_STIFFNESS  ! If present(with_stiffness), set stiffness_requested to with_stiffness.
      THERMAL_REQUESTED = .FALSE.                                        ! Set the flag thermal_requested to false.
      IF (PRESENT(COUPLING)) THERMAL_REQUESTED = COUPLING                ! If present(coupling), set thermal_requested to coupling.
      IF (.NOT. GENERAL) THEN                                            ! If not general:
        CALL VALIDATE_INPUT(ELEMENT_INDEX, NODES, ELEMENTS,              ! Call validate input with element_index, nodes, elements, kinematics, dof_layout, gauss_layout, geometry, fr...
     &       KINEMATICS, DOF_LAYOUT, GAUSS_LAYOUT, GEOMETRY,
     &       FRAMES, MATERIAL_CACHE, MATERIAL_MAP, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END IF                                                             ! End of the IF block.
      CALL BUILD_ELEMENT_DOF_LIST(ELEMENT_INDEX, NODES, ELEMENTS,        ! Call build element dof list with element_index, nodes, elements, kinematics, dof_layout, matrices, status.
     &     KINEMATICS, DOF_LAYOUT, MATRICES, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      N_DOF = MATRICES%LOCAL_DOF_COUNT                                   ! Set n_dof to matrices.local_dof_count.
      ALLOCATE(MATRICES%STIFFNESS(N_DOF,N_DOF))                          ! Allocate memory for matrices.stiffness(n_dof,n_dof).
      MATRICES%STIFFNESS = 0.0_R8                                        ! Set matrices.stiffness to zero.
      IF (MASS_REQUESTED) THEN                                           ! If mass_requested:
        ALLOCATE(MATRICES%MASS(N_DOF,N_DOF))                             ! Allocate memory for matrices.mass(n_dof,n_dof).
        MATRICES%MASS = 0.0_R8                                           ! Set matrices.mass to zero.
        ALLOCATE(BASIS_VALUE(MAX_BATCH,N_DOF))                           ! Allocate memory for basis_value(max_batch,n_dof).
      ELSE                                                               ! Otherwise:
!       THE SPARSE SCATTER ONLY READS MASS WHEN IT IS ALLOCATED.
        ALLOCATE(MATRICES%MASS(0,0))                                     ! Allocate memory for matrices.mass(0,0).
      END IF                                                             ! End of the IF block.

!     SEPARABLE CUF PATH OF THE ORDINARY ELEMENTS (STRUCTURAL AND
!     EXPANSION POINTS ADD UP INSTEAD OF MULTIPLYING). THE POINT-BY-
!     POINT PATH BELOW IS THE REFERENCE AND THE FALLBACK.
      SEPARABLE = .FALSE.                                                ! Set the flag separable to false.
      IF (.NOT. GENERAL .AND. .NOT. THERMAL_REQUESTED) THEN              ! If not general and not thermal_requested:
        IF (.NOT. PRESENT(FORCE_GENERAL)) THEN                           ! If not present(force_general):
          CALL TRY_SEPARABLE()                                           ! Call try separable.
        ELSE IF (.NOT. FORCE_GENERAL) THEN                               ! Otherwise, if not force_general:
          CALL TRY_SEPARABLE()                                           ! Call try separable.
        END IF                                                           ! End of the IF block.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        IF (SEPARABLE) THEN                                              ! If separable:
          CALL MIRROR_UPPER_TRIANGLE(MATRICES, MASS_REQUESTED)           ! Call mirror upper triangle with matrices, mass_requested.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        MATRICES%STIFFNESS = 0.0_R8                                      ! Set matrices.stiffness to zero.
        IF (MASS_REQUESTED) MATRICES%MASS = 0.0_R8                       ! If mass_requested, set matrices.mass to zero.
      END IF                                                             ! End of the IF block.

      CALL PROVIDER_SETUP(PROV, ELEMENT_INDEX, NODES, ELEMENTS,          ! Call provider setup with prov, element_index, nodes, elements, kinematics, expansions, expansion_cache, fra...
     &     KINEMATICS, EXPANSIONS, EXPANSION_CACHE, FRAMES, MATRICES,
     &     STATUS, MITC, TYING)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
!     NUMBER OF GENERALISED STRAIN ROWS: 6, 9 (POTENTIAL) OR 12 (T).
      NR = 6_I4                                                          ! Set nr to 6.
      IF (ANY(MATRICES%FIELD .EQ. FIELD_P)) NR = 9_I4                    ! If any(matrices.field = field_p), set nr to 9.
      IF (ANY(MATRICES%FIELD .EQ. FIELD_T)) NR = 12_I4                   ! If any(matrices.field = field_t), set nr to 12.
      CALL SETUP_POINT_STATE_WORK(N_DOF, NR, SWORK)                      ! Call setup point state work with n_dof, nr, swork.
      IF (PROV%KINKED .AND. MASS_REQUESTED)                              ! If prov.kinked and mass_requested, allocate memory for a3(3,n_dof), b3(3,n_dof).
     &  ALLOCATE(A3(3,N_DOF), B3(3,N_DOF))
!     BATCH OF POINTS: K = SUM_P (B_P)T (W_P C B_P) IS ONE MATRIX
!     PRODUCT OVER NR*BATCH ROWS, INSTEAD OF A SCALAR NUCLEUS PER PAIR.
      BATCH = MAX(1_I4, MIN(MAX_BATCH, INT(2.0E6_R8/                     ! Set batch to the larger of 1 and min(max_batch, int(2.0e6/ (real(nr,r8)*real(n_dof,r8)),i4)).
     &        (REAL(NR,R8)*REAL(N_DOF,R8)),I4)))
      ALLOCATE(B_TEST(NR*BATCH,N_DOF), B_WEIGHTED(NR*BATCH,N_DOF))       ! Allocate memory for b_test(nr*batch,n_dof), b_weighted(nr*batch,n_dof).

      FIRST_POINT = GAUSS_LAYOUT%ELEMENT_FIRST(ELEMENT_INDEX)            ! Set first_point to gauss_layout.element_first(element_index).
      DO WHILE (FIRST_POINT .LE.                                         ! Repeat while first_point <= gauss_layout.element_last(element_index):
     &          GAUSS_LAYOUT%ELEMENT_LAST(ELEMENT_INDEX))
        LAST_POINT = MIN(GAUSS_LAYOUT%ELEMENT_LAST(ELEMENT_INDEX),       ! Set last_point to the smaller of gauss_layout.element_last(element_index) and first_point+int(batch,i8)-1.
     &                   FIRST_POINT+INT(BATCH,I8)-1_I8)
        COUNT = INT(LAST_POINT-FIRST_POINT+1_I8,I4)                      ! Set count to int(last_point-first_point+1,i4).
        DO POINT = FIRST_POINT, LAST_POINT                               ! Loop point from first_point to last_point:
          Q = INT(POINT-FIRST_POINT,I4)                                  ! Set q to int(point-first_point,i4).
          MATERIAL_INDEX = MATERIAL_MAP%CACHE_INDEX(POINT)               ! Set material_index to material_map.cache_index(point).
          IF (MATERIAL_INDEX .LT. 1_I4 .OR. MATERIAL_INDEX .GT.          ! If material_index < 1 or material_index > material_cache.count:
     &        MATERIAL_CACHE%COUNT) THEN
            CALL SET_ERROR(STATUS, 'BUILD_LINEAR_ELEMENT_MATRICES',      ! Record an error in status: 'GAUSS POINT MATERIAL INDEX IS OUT OF RANGE'.
     &        'GAUSS POINT MATERIAL INDEX IS OUT OF RANGE')
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          CALL PROVIDER_POINT(PROV, POINT, ELEMENT_INDEX, ELEMENTS,      ! Call provider point with prov, point, element_index, elements, kinematics, expansions, rules, gauss_layout,...
     &         KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &         STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &         MATRICES, SWORK, WEIGHT, STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          STIFFNESS_LOCAL = WEIGHT*GENERALIZED_CONSTITUTIVE(             ! Set stiffness_local to weight*generalized_constitutive( material_cache, material_index, cpart, prov.cdim).
     &      MATERIAL_CACHE, MATERIAL_INDEX, CPART, PROV%CDIM)
          POINT_MASS(Q+1_I4) = WEIGHT*                                   ! Set point_mass(q+1) to weight* material_cache.density(material_index).
     &      MATERIAL_CACHE%DENSITY(MATERIAL_INDEX)
          POINT_CAPACITY(Q+1_I4) = POINT_MASS(Q+1_I4)*                   ! Set point_capacity(q+1) to point_mass(q+1)* material_cache.specific_heat(material_index).
     &      MATERIAL_CACHE%SPECIFIC_HEAT(MATERIAL_INDEX)
          DO I = 1_I4, N_DOF                                             ! Loop i from 1 to n_dof:
            IF (MASS_REQUESTED) BASIS_VALUE(Q+1_I4,I) = SWORK%VALUE(I)   ! If mass_requested, set basis_value(q+1,i) to swork.value(i).
            B_TEST(NR*Q+1:NR*Q+NR,I) = SWORK%BCOL(1:NR,I)                ! Set b_test(nr*q+1:nr*q+nr,i) to swork.bcol(1:nr,i).
            B_WEIGHTED(NR*Q+1:NR*Q+NR,I) =                               ! Set b_weighted(nr*q+1:nr*q+nr,i) to matmul(stiffness_local(1:nr,1:nr),swork.bcol(1:nr,i)).
     &        MATMUL(STIFFNESS_LOCAL(1:NR,1:NR),SWORK%BCOL(1:NR,I))
          END DO                                                         ! End of the loop.
!         KINKED SHELL NODES: THE DOFS OF THE FIRST-ORDER TERM HAVE
!         COMBINED DIRECTIONS, M += W RHO (N_I D_I).(N_J D_J).
          IF (PROV%KINKED .AND. MASS_REQUESTED) THEN                     ! If prov.kinked and mass_requested:
            DO I = 1_I4, N_DOF                                           ! Loop i from 1 to n_dof:
              A3(:,I) = 0.0_R8                                           ! Set a3(:,i) to zero.
              IF (MATRICES%FIELD(I) .LE. 3_I4) A3(:,I) =                 ! If matrices.field(i) <= 3, set a3(:,i) to swork.value(i)*prov.dirg(:,i).
     &          SWORK%VALUE(I)*PROV%DIRG(:,I)
              B3(:,I) = POINT_MASS(Q+1_I4)*A3(:,I)                       ! Set b3(:,i) to point_mass(q+1)*a3(:,i).
            END DO                                                       ! End of the loop.
            CALL ACCUMULATE_UPPER_PRODUCT(A3, B3, 3_I4, MATRICES%MASS)   ! Call accumulate upper product with a3, b3, 3, matrices.mass.
          END IF                                                         ! End of the IF block.
          IF (THERMAL_REQUESTED) THEN                                    ! If thermal_requested:
            BETA = THERMAL_STRESS_COEFFICIENT(MATERIAL_CACHE,            ! Set beta to thermal_stress_coefficient(material_cache, material_index).
     &                                        MATERIAL_INDEX)
            DO I = 1_I4, N_DOF                                           ! Loop i from 1 to n_dof:
              IF (MATRICES%FIELD(I) .GT. 3_I4) CYCLE                     ! If matrices.field(i) > 3, skip to the next iteration.
              DO J = 1_I4, N_DOF                                         ! Loop j from 1 to n_dof:
                IF (MATRICES%FIELD(J) .NE. FIELD_T) CYCLE                ! If matrices.field(j) /= field_t, skip to the next iteration.
                MATRICES%STIFFNESS(I,J) = MATRICES%STIFFNESS(I,J) -      ! Subtract weight*swork.value(j)*dot_product( swork.bcol(1:6,i),beta) from matrices.stiffness(i,j).
     &            WEIGHT*SWORK%VALUE(J)*DOT_PRODUCT(
     &            SWORK%BCOL(1:6,I),BETA)
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
            IF (MATERIAL_CACHE%ANY_PYRO) THEN                            ! If material_cache.any_pyro:
              DO I = 1_I4, N_DOF                                         ! Loop i from 1 to n_dof:
                IF (MATRICES%FIELD(I) .NE. FIELD_P) CYCLE                ! If matrices.field(i) /= field_p, skip to the next iteration.
                DO J = 1_I4, N_DOF                                       ! Loop j from 1 to n_dof:
                  IF (MATRICES%FIELD(J) .NE. FIELD_T) CYCLE              ! If matrices.field(j) /= field_t, skip to the next iteration.
                  MATRICES%STIFFNESS(I,J) = MATRICES%STIFFNESS(I,J) +    ! Add weight*swork.value(j)*dot_product( swork.bcol(7:9,i), material_cache.pyro_local(:,material_index)) to m...
     &              WEIGHT*SWORK%VALUE(J)*DOT_PRODUCT(
     &              SWORK%BCOL(7:9,I),
     &              MATERIAL_CACHE%PYRO_LOCAL(:,MATERIAL_INDEX))
                END DO                                                   ! End of the loop.
              END DO                                                     ! End of the loop.
            END IF                                                       ! End of the IF block.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        IF (.NOT. THERMAL_REQUESTED) CALL ACCUMULATE_UPPER_PRODUCT(      ! If not thermal_requested, call accumulate upper product with b_test, b_weighted, nr*count, matrices.stiffness.
     &    B_TEST, B_WEIGHTED, NR*COUNT, MATRICES%STIFFNESS)
        IF (MASS_REQUESTED) CALL ADD_MASS(MATRICES, BASIS_VALUE,         ! If mass_requested, call add mass with matrices, basis_value, point_mass, point_capacity, count, prov.kinked.
     &    POINT_MASS, POINT_CAPACITY, COUNT, PROV%KINKED)
        FIRST_POINT = LAST_POINT + 1_I8                                  ! Set first_point to last_point + 1.
      END DO                                                             ! End of the loop.
      IF (THERMAL_REQUESTED) RETURN                                      ! If thermal_requested, return to the caller.
      IF (.NOT. STIFFNESS_REQUESTED) MATRICES%STIFFNESS = 0.0_R8         ! If not stiffness_requested, set matrices.stiffness to zero.
      CALL MIRROR_UPPER_TRIANGLE(MATRICES, MASS_REQUESTED)               ! Call mirror upper triangle with matrices, mass_requested.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE TRY_SEPARABLE()                                         ! Subroutine try separable.
      TYPE(MITC_DATA_TYPE) :: MITC_DATA                                  ! Of type mitc_data_type: mitc_data.
      IF (PRESENT(MITC)) MITC_DATA = MITC                                ! If present(mitc), set mitc_data to mitc.
      CALL BUILD_SEPARABLE_MATRICES(ELEMENT_INDEX, ELEMENTS,             ! Call build separable matrices with element_index, elements, kinematics, expansions, rules, gauss_layout, st...
     &     KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &     STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &     MATERIAL_CACHE, MATERIAL_MAP, MITC_DATA, MATRICES%FIELD,
     &     MATRICES%STRUCTURAL_NODE, MATRICES%TERM,
     &     MATRICES%KINEMATIC_INDEX, MASS_REQUESTED,
     &     MATRICES%STIFFNESS, MATRICES%MASS, SEPARABLE, STATUS,
     &     CPART, STIFFNESS_REQUESTED)
      END SUBROUTINE TRY_SEPARABLE                                       ! End of the subroutine try separable.

      END SUBROUTINE BUILD_LINEAR_ELEMENT_MATRICES                       ! End of the subroutine build linear element matrices.

!  STATE-DEPENDENT MATRICES AT THE STATE U0 (GLOBAL DOF VECTOR):
!    NONLINEAR = .FALSE.  GEOMETRIC (INITIAL-STRESS) MATRIX
!    NONLINEAR = .TRUE.   TOTAL-LAGRANGIAN TANGENT AND INTERNAL FORCE
!  WITH THE SHARED POINT OPERATORS GEOMETRIC_POINT / NONLINEAR_POINT.
!  THE MITC TYING (MITC OR TYING) ACTS ON THE LINEAR PART ONLY.
      SUBROUTINE BUILD_STATE_ELEMENT_MATRICES(ELEMENT_INDEX,             ! Subroutine build state element matrices takes element index, nodes, elements, kinematics, expansions, dof l...
     &     NODES, ELEMENTS, KINEMATICS, EXPANSIONS, DOF_LAYOUT,
     &     RULES, GAUSS_LAYOUT, STRUCTURAL_CACHE,
     &     EXPANSION_CACHE, GEOMETRY, FRAMES, MATERIAL_CACHE,
     &     MATERIAL_MAP, MATRICES, STATUS, U0, NONLINEAR, MITC, TYING)

      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(DOF_LAYOUT_TYPE), INTENT(IN) :: DOF_LAYOUT                    ! Input of type dof_layout_type: dof_layout.
      TYPE(REFERENCE_RULE_DB_TYPE), INTENT(IN) :: RULES                  ! Input of type reference_rule_db_type: rules.
      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: GAUSS_LAYOUT                ! Input of type gauss_layout_type: gauss_layout.
      TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                ! Input of type structural_geometry_cache_type: structural_cache.
     &  STRUCTURAL_CACHE
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(GAUSS_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                  ! Input of type gauss_geometry_type: geometry.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: MATERIAL_CACHE            ! Input of type material_cache_type: material_cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(IN) :: MATERIAL_MAP          ! Input of type gauss_material_map_type: material_map.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(INOUT) :: MATRICES               ! In/out of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), INTENT(IN) :: U0(:)                                      ! Input real (real64): u0(:).
      LOGICAL, INTENT(IN) :: NONLINEAR                                   ! Input logical: nonlinear.
      TYPE(MITC_DATA_TYPE), INTENT(IN), OPTIONAL :: MITC                 ! Input optional of type mitc_data_type: mitc.
      LOGICAL, INTENT(IN), OPTIONAL :: TYING                             ! Input optional logical: tying.
      TYPE(POINT_PROVIDER_TYPE) :: PROV                                  ! Of type point_provider_type: prov.
      TYPE(POINT_STATE_WORK_TYPE) :: SWORK                               ! Of type point_state_work_type: swork.
      REAL(R8), ALLOCATABLE :: COUPLE(:,:)                               ! Allocatable real (real64): couple(:,:).
      REAL(R8), ALLOCATABLE :: UVALUE(:)                                 ! Allocatable real (real64): uvalue(:).
      REAL(R8) :: MCON(12,12)                                            ! Real (real64): mcon(12,12).
      REAL(R8) :: BETA(6)                                                ! Real (real64): beta(6).
      REAL(R8) :: WEIGHT                                                 ! Real (real64): weight.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      INTEGER(I4) :: NR                                                  ! Integer (int32): nr.
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: MATERIAL_INDEX                                      ! Integer (int32): material_index.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      LOGICAL :: GENERAL                                                 ! Logical: general.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_ELEMENT_MATRIX(MATRICES)                                ! Call clear element matrix with matrices.
      GENERAL = IS_GENERAL_ELEMENT(FRAMES, ELEMENT_INDEX)                ! Set general to is_general_element(frames, element_index).
      IF (.NOT. GENERAL) THEN                                            ! If not general:
        CALL VALIDATE_INPUT(ELEMENT_INDEX, NODES, ELEMENTS,              ! Call validate input with element_index, nodes, elements, kinematics, dof_layout, gauss_layout, geometry, fr...
     &       KINEMATICS, DOF_LAYOUT, GAUSS_LAYOUT, GEOMETRY,
     &       FRAMES, MATERIAL_CACHE, MATERIAL_MAP, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END IF                                                             ! End of the IF block.
      CALL BUILD_ELEMENT_DOF_LIST(ELEMENT_INDEX, NODES, ELEMENTS,        ! Call build element dof list with element_index, nodes, elements, kinematics, dof_layout, matrices, status.
     &     KINEMATICS, DOF_LAYOUT, MATRICES, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      N_DOF = MATRICES%LOCAL_DOF_COUNT                                   ! Set n_dof to matrices.local_dof_count.
      NR = 6_I4                                                          ! Set nr to 6.
      IF (ANY(MATRICES%FIELD .EQ. FIELD_P)) NR = 9_I4                    ! If any(matrices.field = field_p), set nr to 9.
      IF (ANY(MATRICES%FIELD .EQ. FIELD_T)) NR = 12_I4                   ! If any(matrices.field = field_t), set nr to 12.
      ALLOCATE(MATRICES%STIFFNESS(N_DOF,N_DOF), MATRICES%MASS(0,0))      ! Allocate memory for matrices.stiffness(n_dof,n_dof), matrices.mass(0,0).
      MATRICES%STIFFNESS = 0.0_R8                                        ! Set matrices.stiffness to zero.
      IF (NONLINEAR) THEN                                                ! If nonlinear:
        ALLOCATE(MATRICES%INTERNAL_FORCE(N_DOF))                         ! Allocate memory for matrices.internal_force(n_dof).
        MATRICES%INTERNAL_FORCE = 0.0_R8                                 ! Set matrices.internal_force to zero.
!       THE COUPLING BLOCKS (NOT SYMMETRIC) ARE KEPT APART FROM THE
!       SYMMETRIC TANGENT, WHICH IS ACCUMULATED ON ITS UPPER TRIANGLE.
        IF (NR .GE. 12_I4 .OR. MATERIAL_CACHE%ANY_PYRO) THEN             ! If nr >= 12 or material_cache.any_pyro:
          ALLOCATE(COUPLE(N_DOF,N_DOF))                                  ! Allocate memory for couple(n_dof,n_dof).
          COUPLE = 0.0_R8                                                ! Set couple to zero.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      ALLOCATE(UVALUE(N_DOF))                                            ! Allocate memory for uvalue(n_dof).
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        UVALUE(I) = U0(MATRICES%GLOBAL_DOF(I))                           ! Set uvalue(i) to u0(matrices.global_dof(i)).
      END DO                                                             ! End of the loop.
      CALL PROVIDER_SETUP(PROV, ELEMENT_INDEX, NODES, ELEMENTS,          ! Call provider setup with prov, element_index, nodes, elements, kinematics, expansions, expansion_cache, fra...
     &     KINEMATICS, EXPANSIONS, EXPANSION_CACHE, FRAMES, MATRICES,
     &     STATUS, MITC, TYING)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL SETUP_POINT_STATE_WORK(N_DOF, NR, SWORK)                      ! Call setup point state work with n_dof, nr, swork.

      DO POINT = GAUSS_LAYOUT%ELEMENT_FIRST(ELEMENT_INDEX),              ! Loop point from gauss_layout.element_first(element_index) to gauss_layout.element_last(element_index):
     &           GAUSS_LAYOUT%ELEMENT_LAST(ELEMENT_INDEX)
        MATERIAL_INDEX = MATERIAL_MAP%CACHE_INDEX(POINT)                 ! Set material_index to material_map.cache_index(point).
        IF (MATERIAL_INDEX .LT. 1_I4 .OR. MATERIAL_INDEX .GT.            ! If material_index < 1 or material_index > material_cache.count:
     &      MATERIAL_CACHE%COUNT) THEN
          CALL SET_ERROR(STATUS, 'BUILD_STATE_ELEMENT_MATRICES',         ! Record an error in status: 'GAUSS POINT MATERIAL INDEX IS OUT OF RANGE'.
     &                   'GAUSS POINT MATERIAL INDEX IS OUT OF RANGE')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        CALL PROVIDER_POINT(PROV, POINT, ELEMENT_INDEX, ELEMENTS,        ! Call provider point with prov, point, element_index, elements, kinematics, expansions, rules, gauss_layout,...
     &       KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &       STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &       MATRICES, SWORK, WEIGHT, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        MCON = GENERALIZED_CONSTITUTIVE(MATERIAL_CACHE,                  ! Set mcon to generalized_constitutive(material_cache, material_index, part_full, prov.cdim).
     &                                  MATERIAL_INDEX, PART_FULL,
     &                                  PROV%CDIM)
        BETA = THERMAL_STRESS_COEFFICIENT(MATERIAL_CACHE,                ! Set beta to thermal_stress_coefficient(material_cache, material_index).
     &                                    MATERIAL_INDEX)
        IF (NONLINEAR) THEN                                              ! If nonlinear:
          CALL NONLINEAR_POINT(NR, N_DOF, MATRICES%FIELD, UVALUE,        ! Call nonlinear point with nr, n_dof, matrices.field, uvalue, weight, mcon, beta, material_cache.any_pyro, m...
     &         WEIGHT, MCON, BETA, MATERIAL_CACHE%ANY_PYRO,
     &         MATERIAL_CACHE%PYRO_LOCAL(:,MATERIAL_INDEX), SWORK,
     &         MATRICES%STIFFNESS, MATRICES%INTERNAL_FORCE, COUPLE)
        ELSE                                                             ! Otherwise:
          CALL GEOMETRIC_POINT(NR, N_DOF, MATRICES%FIELD, UVALUE,        ! Call geometric point with nr, n_dof, matrices.field, uvalue, weight, weight*mcon, beta, swork, matrices.sti...
     &         WEIGHT, WEIGHT*MCON, BETA, SWORK, MATRICES%STIFFNESS)
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
!     SYMMETRIC PART FROM ITS UPPER TRIANGLE, THEN THE COUPLING.
      CALL MIRROR_UPPER_TRIANGLE(MATRICES, .FALSE.)                      ! Call mirror upper triangle with matrices, false.
      IF (ALLOCATED(COUPLE)) MATRICES%STIFFNESS =                        ! If allocated(couple), add couple to matrices.stiffness.
     &  MATRICES%STIFFNESS + COUPLE

      END SUBROUTINE BUILD_STATE_ELEMENT_MATRICES                        ! End of the subroutine build state element matrices.

!  THE PROVIDER OF ONE ELEMENT: ORDINARY (POINT FACTORS, CONSTANT FRAME,
!  MITC DATA) OR GENERAL (CONTEXT, TABLES OF THE EXPANSION FACTORS).
      SUBROUTINE PROVIDER_SETUP(PROV, ELEMENT_INDEX, NODES, ELEMENTS,    ! Subroutine provider setup takes prov, element index, nodes, elements, kinematics, expansions, expansion cac...
     &     KINEMATICS, EXPANSIONS, EXPANSION_CACHE, FRAMES, MATRICES,
     &     STATUS, MITC, TYING)

      TYPE(POINT_PROVIDER_TYPE), INTENT(INOUT) :: PROV                   ! In/out of type point_provider_type: prov.
      INTEGER(I4), INTENT(IN) :: ELEMENT_INDEX                           ! Input integer (int32): element_index.
      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), INTENT(IN) ::                 ! Input of type expansion_geometry_cache_type: expansion_cache.
     &  EXPANSION_CACHE
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      TYPE(ELEMENT_MATRIX_TYPE), INTENT(IN) :: MATRICES                  ! Input of type element_matrix_type: matrices.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(MITC_DATA_TYPE), INTENT(IN), OPTIONAL :: MITC                 ! Input optional of type mitc_data_type: mitc.
      LOGICAL, INTENT(IN), OPTIONAL :: TYING                             ! Input optional logical: tying.
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: MAX_TERM                                            ! Integer (int32): max_term.
      INTEGER(I4) :: N_KIN                                               ! Integer (int32): n_kin.
      LOGICAL :: TIED                                                    ! Logical: tied.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N_DOF = MATRICES%LOCAL_DOF_COUNT                                   ! Set n_dof to matrices.local_dof_count.
      PROV%GENERAL = IS_GENERAL_ELEMENT(FRAMES, ELEMENT_INDEX)           ! Set prov.general to is_general_element(frames, element_index).
      PROV%CDIM = TOPOLOGY_NATURAL_DIMENSION(                            ! Set prov.cdim to topology_natural_dimension( elements.item(element_index).topology).
     &            ELEMENTS%ITEM(ELEMENT_INDEX)%TOPOLOGY)
      IF (.NOT. PROV%GENERAL) THEN                                       ! If not prov.general:
        IF (PRESENT(MITC)) PROV%MITC = MITC                              ! If present(mitc), set prov.mitc to mitc.
        CALL SETUP_POINT_WORK(MATRICES, KINEMATICS, PROV%PWORK)          ! Call setup point work with matrices, kinematics, prov.pwork.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      TIED = .FALSE.                                                     ! Set the flag tied to false.
      IF (PRESENT(TYING)) TIED = TYING                                   ! If present(tying), set tied to tying.
      CALL GENERAL_CONTEXT_SETUP(PROV%CTX, ELEMENT_INDEX, NODES,         ! Call general context setup with prov.ctx, element_index, nodes, elements, expansions, expansion_cache, fram...
     &     ELEMENTS, EXPANSIONS, EXPANSION_CACHE, FRAMES, TIED, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      PROV%KINKED = ANY(PROV%CTX%KINK(1:PROV%CTX%NN) .NE. 0_I4)          ! Set prov.kinked to whether any of prov.ctx.kink(1:prov.ctx.nn) /= 0.
      MAX_TERM = MAXVAL(MATRICES%TERM)                                   ! Set max_term to the maximum of matrices.term.
      N_KIN = SIZE(KINEMATICS%ITEM)                                      ! Set n_kin to the size of kinematics.item.
      ALLOCATE(PROV%F_VALUE(MAX_TERM,5,N_KIN),                           ! Allocate memory for prov.f_value(max_term,5,n_kin), prov.f_grad(3,max_term,5,n_kin), prov.f_done(max_term,5...
     &         PROV%F_GRAD(3,MAX_TERM,5,N_KIN),
     &         PROV%F_DONE(MAX_TERM,5,N_KIN))
      ALLOCATE(PROV%FV(N_DOF), PROV%FG(3,N_DOF), PROV%DIRG(3,N_DOF),     ! Allocate memory for prov.fv(n_dof), prov.fg(3,n_dof), prov.dirg(3,n_dof), prov.dof_node(n_dof).
     &         PROV%DOF_NODE(N_DOF))
      PROV%DOF_NODE = MATRICES%STRUCTURAL_NODE                           ! Set prov.dof_node to matrices.structural_node.

      END SUBROUTINE PROVIDER_SETUP                                      ! End of the subroutine provider setup.

!  THE CONTRACT OF ONE POINT (SWORK) AND ITS INTEGRATION WEIGHT.
      SUBROUTINE PROVIDER_POINT(PROV, POINT, ELEMENT_INDEX, ELEMENTS,    ! Subroutine provider point takes prov, point, element index, elements, kinematics, expansions, rules, gauss ...
     &     KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &     STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &     MATRICES, SWORK, WEIGHT, STATUS)

      TYPE(POINT_PROVIDER_TYPE), INTENT(INOUT) :: PROV                   ! In/out of type point_provider_type: prov.
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
      TYPE(POINT_STATE_WORK_TYPE), INTENT(INOUT) :: SWORK                ! In/out of type point_state_work_type: swork.
      REAL(R8), INTENT(OUT) :: WEIGHT                                    ! Output real (real64): weight.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      REAL(R8) :: N(16)                                                  ! Real (real64): n(16).
      REAL(R8) :: DN(16,2)                                               ! Real (real64): dn(16,2).
      REAL(R8) :: NATURAL(3)                                             ! Real (real64): natural(3).
      REAL(R8) :: C(3)                                                   ! Real (real64): c(3).
      REAL(R8) :: G(3,3)                                                 ! Real (real64): g(3,3).
      REAL(R8) :: R(3,3)                                                 ! Real (real64): r(3,3).
      REAL(R8) :: DET                                                    ! Real (real64): det.
      INTEGER(I8) :: EXP_INDEX                                           ! Integer (int64): exp_index.
      INTEGER(I4) :: N_DOF                                               ! Integer (int32): n_dof.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N_DOF = MATRICES%LOCAL_DOF_COUNT                                   ! Set n_dof to matrices.local_dof_count.
      IF (.NOT. PROV%GENERAL) THEN                                       ! If not prov.general:
        CALL EVALUATE_POINT_COLUMNS(POINT, ELEMENT_INDEX, ELEMENTS,      ! Call evaluate point columns with point, element_index, elements, kinematics, expansions, rules, gauss_layou...
     &       KINEMATICS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &       STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, FRAMES,
     &       MATRICES, PROV%MITC, PROV%PWORK, LOCAL_STATUS)
        IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                       ! If not local_status is ok:
          CALL SET_ERROR(STATUS, 'PROVIDER_POINT',                       ! Record an error in status: trim(local_status.message).
     &                   TRIM(LOCAL_STATUS%MESSAGE))
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        DO I = 1_I4, N_DOF                                               ! Loop i from 1 to n_dof:
          SWORK%VALUE(I) = PROV%PWORK%VALUE(I)                           ! Set swork.value(i) to prov.pwork.value(i).
          SWORK%BCOL(:,I) = PROV%PWORK%BCOL(:,I)                         ! Set swork.bcol(:,i) to prov.pwork.bcol(:,i).
          SWORK%GRAD(:,I) = PROV%PWORK%GRAD(:,I)                         ! Set swork.grad(:,i) to prov.pwork.grad(:,i).
          SWORK%DIRECTION(:,I) = 0.0_R8                                  ! Set swork.direction(:,i) to zero.
          IF (MATRICES%FIELD(I) .LE. 3_I4) SWORK%DIRECTION(:,I) =        ! If matrices.field(i) <= 3, set swork.direction(:,i) to frames.global_to_local(:,matrices.field(i),element_i...
     &      FRAMES%GLOBAL_TO_LOCAL(:,MATRICES%FIELD(I),ELEMENT_INDEX)
        END DO                                                           ! End of the loop.
        WEIGHT = GEOMETRY%INTEGRATION_WEIGHT(POINT)                      ! Set weight to geometry.integration_weight(point).
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL GENERAL_POINT_INPUT(POINT, PROV%CTX, MATRICES, KINEMATICS,    ! Call general point input with point, prov.ctx, matrices, kinematics, elements, expansions, rules, gauss_lay...
     &     ELEMENTS, EXPANSIONS, RULES, GAUSS_LAYOUT,
     &     STRUCTURAL_CACHE, EXPANSION_CACHE, GEOMETRY, PROV%F_VALUE,
     &     PROV%F_GRAD, PROV%F_DONE, N, DN, NATURAL, C, EXP_INDEX,
     &     PROV%FV, PROV%FG, LOCAL_STATUS)
      IF (STATUS_IS_OK(LOCAL_STATUS))                                    ! If local_status is ok, call general point columns with prov.ctx, n, dn, natural, c, n_dof, prov.dof_node, m...
     &  CALL GENERAL_POINT_COLUMNS(PROV%CTX, N, DN, NATURAL, C, N_DOF,
     &       PROV%DOF_NODE, MATRICES%FIELD, PROV%FV, PROV%FG,
     &       SWORK%BCOL, SWORK%VALUE, G, R, DET, LOCAL_STATUS,
     &       PROV%DIRG, SWORK%GRAD)
      IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                         ! If not local_status is ok:
        CALL SET_ERROR(STATUS, 'PROVIDER_POINT',                         ! Record an error in status: trim(local_status.message).
     &                 TRIM(LOCAL_STATUS%MESSAGE))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO I = 1_I4, N_DOF                                                 ! Loop i from 1 to n_dof:
        SWORK%DIRECTION(:,I) = MATMUL(R,PROV%DIRG(:,I))                  ! Set swork.direction(:,i) to matmul(r,prov.dirg(:,i)).
      END DO                                                             ! End of the loop.
      WEIGHT = GAUSS_LAYOUT%REFERENCE_WEIGHT(POINT)*                     ! Set weight to gauss_layout.reference_weight(point)* expansion_cache.determinant(exp_index)*abs(det).
     &         EXPANSION_CACHE%DETERMINANT(EXP_INDEX)*ABS(DET)

      END SUBROUTINE PROVIDER_POINT                                      ! End of the subroutine provider point.

      END MODULE MUL2_ELEMENT_OPERATORS                                  ! End of the module mul2 element operators.
