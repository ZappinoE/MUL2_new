!=======================================================================
!  REFERENCE-ELEMENT GAUSS QUADRATURE RULES.
!=======================================================================
      MODULE MUL2_QUADRATURE                                             ! Module mul2 quadrature begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_TOPOLOGIES                                                ! Use everything exported by module mul2 topologies.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: QUADRATURE_RULE_TYPE                               ! Definition of the derived type quadrature rule type.
        INTEGER(I4) :: NATURAL_DIMENSION = 0_I4                          ! Integer (int32): natural_dimension = 0.
        REAL(R8), ALLOCATABLE :: COORDINATE(:,:)                         ! Allocatable real (real64): coordinate(:,:).
        REAL(R8), ALLOCATABLE :: WEIGHT(:)                               ! Allocatable real (real64): weight(:).
      END TYPE QUADRATURE_RULE_TYPE                                      ! End of the type definition quadrature rule type.

      PUBLIC :: BUILD_DEFAULT_QUADRATURE                                 ! Export: build default quadrature.
      PUBLIC :: BUILD_ORDERED_QUADRATURE                                 ! Export: build ordered quadrature.
      PUBLIC :: DEFAULT_POINTS_PER_DIRECTION                             ! Export: default points per direction.
      PUBLIC :: REDUCED_POINTS_PER_DIRECTION                             ! Export: reduced points per direction.
      PUBLIC :: BUILD_REDUCED_QUADRATURE                                 ! Export: build reduced quadrature.

      CONTAINS                                                           ! The procedures of the module follow.

!  GAUSS POINTS PER DIRECTION OF THE REDUCED RULE OF A STRUCTURAL
!  ELEMENT (ONE LESS THAN THE FULL RULE, AS IN THE BASELINE: REDI AND
!  SELI). 0 = NO REDUCED RULE (TRIANGLES AND ANY OTHER TOPOLOGY).
      INTEGER(I4) FUNCTION REDUCED_POINTS_PER_DIRECTION(TOPOLOGY)        ! Function reduced points per direction takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_B2, TOPOLOGY_Q4, TOPOLOGY_H8)                       ! Case topology_b2, topology_q4, topology_h8:
        REDUCED_POINTS_PER_DIRECTION = 1_I4                              ! Set reduced_points_per_direction to 1.
      CASE (TOPOLOGY_B3, TOPOLOGY_Q9, TOPOLOGY_H27)                      ! Case topology_b3, topology_q9, topology_h27:
        REDUCED_POINTS_PER_DIRECTION = 2_I4                              ! Set reduced_points_per_direction to 2.
      CASE (TOPOLOGY_B4, TOPOLOGY_Q16)                                   ! Case topology_b4, topology_q16:
        REDUCED_POINTS_PER_DIRECTION = 3_I4                              ! Set reduced_points_per_direction to 3.
      CASE DEFAULT                                                       ! In every other case:
        REDUCED_POINTS_PER_DIRECTION = 0_I4                              ! Set reduced_points_per_direction to zero.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION REDUCED_POINTS_PER_DIRECTION                          ! End of the function reduced points per direction.

      SUBROUTINE BUILD_REDUCED_QUADRATURE(TOPOLOGY, RULE, STATUS)        ! Subroutine build reduced quadrature takes topology, rule, status.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      TYPE(QUADRATURE_RULE_TYPE), INTENT(INOUT) :: RULE                  ! In/out of type quadrature_rule_type: rule.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: N                                                   ! Integer (int32): n.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_RULE(RULE)                                              ! Call clear rule with rule.
      N = REDUCED_POINTS_PER_DIRECTION(TOPOLOGY)                         ! Set n to reduced_points_per_direction(topology).
      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_B2, TOPOLOGY_B3, TOPOLOGY_B4)                       ! Case topology_b2, topology_b3, topology_b4:
        CALL BUILD_LINE_RULE(N, RULE)                                    ! Call build line rule with n, rule.
      CASE (TOPOLOGY_Q4, TOPOLOGY_Q9, TOPOLOGY_Q16)                      ! Case topology_q4, topology_q9, topology_q16:
        CALL BUILD_TENSOR_RULE(N, 2_I4, RULE)                            ! Call build tensor rule with n, 2, rule.
      CASE (TOPOLOGY_H8, TOPOLOGY_H27)                                   ! Case topology_h8, topology_h27:
        CALL BUILD_TENSOR_RULE(N, 3_I4, RULE)                            ! Call build tensor rule with n, 3, rule.
      CASE DEFAULT                                                       ! In every other case:
        CALL SET_ERROR(STATUS, 'BUILD_REDUCED_QUADRATURE',               ! Record an error in status: 'TOPOLOGY HAS NO REDUCED RULE'.
     &                 'TOPOLOGY HAS NO REDUCED RULE')
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE BUILD_REDUCED_QUADRATURE                            ! End of the subroutine build reduced quadrature.

      SUBROUTINE BUILD_DEFAULT_QUADRATURE(TOPOLOGY, RULE, STATUS)        ! Subroutine build default quadrature takes topology, rule, status.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      TYPE(QUADRATURE_RULE_TYPE), INTENT(INOUT) :: RULE                  ! In/out of type quadrature_rule_type: rule.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_RULE(RULE)                                              ! Call clear rule with rule.
      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_S1)                                                 ! Case topology_s1:
        RULE%NATURAL_DIMENSION = 0_I4                                    ! Set rule.natural_dimension to zero.
        ALLOCATE(RULE%COORDINATE(1,3),RULE%WEIGHT(1))                    ! Allocate memory for rule.coordinate(1,3), rule.weight(1).
        RULE%COORDINATE = 0.0_R8                                         ! Set rule.coordinate to zero.
        RULE%WEIGHT = 1.0_R8                                             ! Set rule.weight to 1.0.
      CASE (TOPOLOGY_B2)                                                 ! Case topology_b2:
        CALL BUILD_LINE_RULE(2_I4, RULE)                                 ! Call build line rule with 2, rule.
      CASE (TOPOLOGY_B3)                                                 ! Case topology_b3:
        CALL BUILD_LINE_RULE(3_I4, RULE)                                 ! Call build line rule with 3, rule.
      CASE (TOPOLOGY_B4)                                                 ! Case topology_b4:
        CALL BUILD_LINE_RULE(4_I4, RULE)                                 ! Call build line rule with 4, rule.
      CASE (TOPOLOGY_Q4)                                                 ! Case topology_q4:
        CALL BUILD_TENSOR_RULE(2_I4, 2_I4, RULE)                         ! Call build tensor rule with 2, 2, rule.
      CASE (TOPOLOGY_Q9)                                                 ! Case topology_q9:
        CALL BUILD_TENSOR_RULE(3_I4, 2_I4, RULE)                         ! Call build tensor rule with 3, 2, rule.
      CASE (TOPOLOGY_Q16)                                                ! Case topology_q16:
        CALL BUILD_TENSOR_RULE(4_I4, 2_I4, RULE)                         ! Call build tensor rule with 4, 2, rule.
      CASE (TOPOLOGY_T3)                                                 ! Case topology_t3:
        CALL BUILD_TRIANGLE_RULE(1_I4, RULE)                             ! Call build triangle rule with 1, rule.
      CASE (TOPOLOGY_T6)                                                 ! Case topology_t6:
        CALL BUILD_TRIANGLE_RULE(2_I4, RULE)                             ! Call build triangle rule with 2, rule.
      CASE (TOPOLOGY_H8)                                                 ! Case topology_h8:
        CALL BUILD_TENSOR_RULE(2_I4, 3_I4, RULE)                         ! Call build tensor rule with 2, 3, rule.
      CASE (TOPOLOGY_H20,TOPOLOGY_H27)                                   ! Case topology_h20,topology_h27:
        CALL BUILD_TENSOR_RULE(3_I4, 3_I4, RULE)                         ! Call build tensor rule with 3, 3, rule.
!     HLE OF ORDER P: P+2 POINTS PER DIRECTION (EXACT FOR THE MASS
!     OF AN AFFINE SUB-ELEMENT, AND ACCURATE FOR BILINEAR MAPS).
      CASE (TOPOLOGY_HB_BASE+1_I4:TOPOLOGY_HB_BASE+99_I4)                ! Case topology_hb_base+1:topology_hb_base+99:
        CALL BUILD_LINE_RULE(TOPOLOGY_HLE_ORDER(TOPOLOGY)+2_I4, RULE)    ! Call build line rule with topology_hle_order(topology)+2, rule.
      CASE (TOPOLOGY_HQ_BASE+1_I4:TOPOLOGY_HQ_BASE+99_I4)                ! Case topology_hq_base+1:topology_hq_base+99:
        CALL BUILD_TENSOR_RULE(TOPOLOGY_HLE_ORDER(TOPOLOGY)+2_I4,        ! Call build tensor rule with topology_hle_order(topology)+2, 2, rule.
     &                         2_I4, RULE)
      CASE DEFAULT                                                       ! In every other case:
        CALL SET_ERROR(STATUS, 'BUILD_DEFAULT_QUADRATURE',               ! Record an error in status: 'TOPOLOGY QUADRATURE IS NOT IMPLEMENTED'.
     &                 'TOPOLOGY QUADRATURE IS NOT IMPLEMENTED')
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE BUILD_DEFAULT_QUADRATURE                            ! End of the subroutine build default quadrature.

!  GAUSS POINTS PER DIRECTION OF THE DEFAULT RULE (0 = NOT TENSOR).
      INTEGER(I4) FUNCTION DEFAULT_POINTS_PER_DIRECTION(TOPOLOGY)        ! Function default points per direction takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_B2, TOPOLOGY_Q4)                                    ! Case topology_b2, topology_q4:
        DEFAULT_POINTS_PER_DIRECTION = 2_I4                              ! Set default_points_per_direction to 2.
      CASE (TOPOLOGY_B3, TOPOLOGY_Q9)                                    ! Case topology_b3, topology_q9:
        DEFAULT_POINTS_PER_DIRECTION = 3_I4                              ! Set default_points_per_direction to 3.
      CASE (TOPOLOGY_B4, TOPOLOGY_Q16)                                   ! Case topology_b4, topology_q16:
        DEFAULT_POINTS_PER_DIRECTION = 4_I4                              ! Set default_points_per_direction to 4.
      CASE (TOPOLOGY_HB_BASE+1_I4:TOPOLOGY_HB_BASE+99_I4,                ! Case topology_hb_base+1:topology_hb_base+99, topology_hq_base+1:topology_hq_base+99:
     &      TOPOLOGY_HQ_BASE+1_I4:TOPOLOGY_HQ_BASE+99_I4)
        DEFAULT_POINTS_PER_DIRECTION = TOPOLOGY_HLE_ORDER(TOPOLOGY) +    ! Set default_points_per_direction to topology_hle_order(topology) + 2.
     &                                 2_I4
      CASE DEFAULT                                                       ! In every other case:
        DEFAULT_POINTS_PER_DIRECTION = 0_I4                              ! Set default_points_per_direction to zero.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION DEFAULT_POINTS_PER_DIRECTION                          ! End of the function default points per direction.

!  TENSOR RULE WITH ORDER POINTS PER DIRECTION (LINES AND
!  QUADRILATERALS). USED FOR HIGH-ORDER TAYLOR EXPANSIONS, WHOSE
!  INTEGRANDS ARE POLYNOMIALS OF DEGREE 2*N.
      SUBROUTINE BUILD_ORDERED_QUADRATURE(TOPOLOGY, ORDER, RULE, STATUS) ! Subroutine build ordered quadrature takes topology, order, rule, status.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      TYPE(QUADRATURE_RULE_TYPE), INTENT(INOUT) :: RULE                  ! In/out of type quadrature_rule_type: rule.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ORDER .LT. 1_I4 .OR. DEFAULT_POINTS_PER_DIRECTION(TOPOLOGY)    ! If order < 1 or default_points_per_direction(topology) = 0:
     &    .EQ. 0_I4) THEN
        CALL BUILD_DEFAULT_QUADRATURE(TOPOLOGY, RULE, STATUS)            ! Call build default quadrature with topology, rule, status.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL CLEAR_RULE(RULE)                                              ! Call clear rule with rule.
      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_B2, TOPOLOGY_B3, TOPOLOGY_B4,                       ! Case topology_b2, topology_b3, topology_b4, topology_hb_base+1:topology_hb_base+99:
     &      TOPOLOGY_HB_BASE+1_I4:TOPOLOGY_HB_BASE+99_I4)
        CALL BUILD_LINE_RULE(ORDER, RULE)                                ! Call build line rule with order, rule.
      CASE DEFAULT                                                       ! In every other case:
        CALL BUILD_TENSOR_RULE(ORDER, 2_I4, RULE)                        ! Call build tensor rule with order, 2, rule.
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE BUILD_ORDERED_QUADRATURE                            ! End of the subroutine build ordered quadrature.
      SUBROUTINE BUILD_LINE_RULE(ORDER, RULE)                            ! Subroutine build line rule takes order, rule.

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      TYPE(QUADRATURE_RULE_TYPE), INTENT(INOUT) :: RULE                  ! In/out of type quadrature_rule_type: rule.
      REAL(R8) :: X(MAX(ORDER,4))                                        ! Real (real64): x(max(order,4)).
      REAL(R8) :: W(MAX(ORDER,4))                                        ! Real (real64): w(max(order,4)).

      CALL GAUSS_LEGENDRE_1D(ORDER, X, W)                                ! Call gauss legendre 1d with order, x, w.
      RULE%NATURAL_DIMENSION = 1_I4                                      ! Set rule.natural_dimension to 1.
      ALLOCATE(RULE%COORDINATE(ORDER,3),RULE%WEIGHT(ORDER))              ! Allocate memory for rule.coordinate(order,3), rule.weight(order).
      RULE%COORDINATE = 0.0_R8                                           ! Set rule.coordinate to zero.
      RULE%COORDINATE(:,1) = X(1:ORDER)                                  ! Set rule.coordinate(:,1) to x(1:order).
      RULE%WEIGHT = W(1:ORDER)                                           ! Set rule.weight to w(1:order).

      END SUBROUTINE BUILD_LINE_RULE                                     ! End of the subroutine build line rule.

      SUBROUTINE BUILD_TENSOR_RULE(ORDER, DIMENSION, RULE)               ! Subroutine build tensor rule takes order, dimension, rule.

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      TYPE(QUADRATURE_RULE_TYPE), INTENT(INOUT) :: RULE                  ! In/out of type quadrature_rule_type: rule.
      REAL(R8) :: X(MAX(ORDER,4))                                        ! Real (real64): x(max(order,4)).
      REAL(R8) :: W(MAX(ORDER,4))                                        ! Real (real64): w(max(order,4)).
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: POINT                                               ! Integer (int32): point.

      CALL GAUSS_LEGENDRE_1D(ORDER, X, W)                                ! Call gauss legendre 1d with order, x, w.
      COUNT = ORDER**DIMENSION                                           ! Set count to order**dimension.
      RULE%NATURAL_DIMENSION = DIMENSION                                 ! Set rule.natural_dimension to dimension.
      ALLOCATE(RULE%COORDINATE(COUNT,3),RULE%WEIGHT(COUNT))              ! Allocate memory for rule.coordinate(count,3), rule.weight(count).
      RULE%COORDINATE = 0.0_R8                                           ! Set rule.coordinate to zero.
      POINT = 0_I4                                                       ! Set point to zero.
      IF (DIMENSION .EQ. 2_I4) THEN                                      ! If dimension = 2:
        DO J = 1_I4, ORDER                                               ! Loop j from 1 to order:
          DO I = 1_I4, ORDER                                             ! Loop i from 1 to order:
            POINT = POINT + 1_I4                                         ! Add 1 to point.
            RULE%COORDINATE(POINT,1:2) = [X(I),X(J)]                     ! Set rule.coordinate(point,1:2) to [x(i),x(j)].
            RULE%WEIGHT(POINT) = W(I)*W(J)                               ! Set rule.weight(point) to w(i)*w(j).
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      ELSE                                                               ! Otherwise:
        DO K = 1_I4, ORDER                                               ! Loop k from 1 to order:
          DO J = 1_I4, ORDER                                             ! Loop j from 1 to order:
            DO I = 1_I4, ORDER                                           ! Loop i from 1 to order:
              POINT = POINT + 1_I4                                       ! Add 1 to point.
              RULE%COORDINATE(POINT,1:3) = [X(I),X(J),X(K)]              ! Set rule.coordinate(point,1:3) to [x(i),x(j),x(k)].
              RULE%WEIGHT(POINT) = W(I)*W(J)*W(K)                        ! Set rule.weight(point) to w(i)*w(j)*w(k).
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE BUILD_TENSOR_RULE                                   ! End of the subroutine build tensor rule.

      SUBROUTINE BUILD_TRIANGLE_RULE(DEGREE, RULE)                       ! Subroutine build triangle rule takes degree, rule.

      INTEGER(I4), INTENT(IN) :: DEGREE                                  ! Input integer (int32): degree.
      TYPE(QUADRATURE_RULE_TYPE), INTENT(INOUT) :: RULE                  ! In/out of type quadrature_rule_type: rule.

      RULE%NATURAL_DIMENSION = 2_I4                                      ! Set rule.natural_dimension to 2.
      IF (DEGREE .EQ. 1_I4) THEN                                         ! If degree = 1:
        ALLOCATE(RULE%COORDINATE(1,3),RULE%WEIGHT(1))                    ! Allocate memory for rule.coordinate(1,3), rule.weight(1).
        RULE%COORDINATE = 0.0_R8                                         ! Set rule.coordinate to zero.
        RULE%COORDINATE(1,1:2) = [1.0_R8/3.0_R8,                         ! Set rule.coordinate(1,1:2) to [1.0/3.0, 1.0/3.0].
     &                             1.0_R8/3.0_R8]
        RULE%WEIGHT(1) = 0.5_R8                                          ! Set rule.weight(1) to 0.5.
      ELSE                                                               ! Otherwise:
        ALLOCATE(RULE%COORDINATE(3,3),RULE%WEIGHT(3))                    ! Allocate memory for rule.coordinate(3,3), rule.weight(3).
        RULE%COORDINATE = 0.0_R8                                         ! Set rule.coordinate to zero.
        RULE%COORDINATE(1,1:2) = [1.0_R8/6.0_R8,                         ! Set rule.coordinate(1,1:2) to [1.0/6.0, 1.0/6.0].
     &                             1.0_R8/6.0_R8]
        RULE%COORDINATE(2,1:2) = [2.0_R8/3.0_R8,                         ! Set rule.coordinate(2,1:2) to [2.0/3.0, 1.0/6.0].
     &                             1.0_R8/6.0_R8]
        RULE%COORDINATE(3,1:2) = [1.0_R8/6.0_R8,                         ! Set rule.coordinate(3,1:2) to [1.0/6.0, 2.0/3.0].
     &                             2.0_R8/3.0_R8]
        RULE%WEIGHT = 1.0_R8/6.0_R8                                      ! Set rule.weight to 1.0/6.0.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE BUILD_TRIANGLE_RULE                                 ! End of the subroutine build triangle rule.

      SUBROUTINE GAUSS_LEGENDRE_1D(ORDER, X, W)                          ! Subroutine gauss legendre 1d takes order, x, w.

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      REAL(R8), INTENT(OUT) :: X(MAX(ORDER,4))                           ! Output real (real64): x(max(order,4)).
      REAL(R8), INTENT(OUT) :: W(MAX(ORDER,4))                           ! Output real (real64): w(max(order,4)).
      REAL(R8) :: P0                                                     ! Real (real64): p0.
      REAL(R8) :: P1                                                     ! Real (real64): p1.
      REAL(R8) :: P2                                                     ! Real (real64): p2.
      REAL(R8) :: DP                                                     ! Real (real64): dp.
      REAL(R8) :: Z                                                      ! Real (real64): z.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: ITER                                                ! Integer (int32): iter.

      X = 0.0_R8                                                         ! Set x to zero.
      W = 0.0_R8                                                         ! Set w to zero.
      IF (ORDER .GT. 4_I4) THEN                                          ! If order > 4:
!       NEWTON ITERATION ON THE LEGENDRE POLYNOMIAL ROOTS.
        DO I = 1_I4, (ORDER+1_I4)/2_I4                                   ! Loop i from 1 to (order+1)/2:
          Z = COS(ACOS(-1.0_R8)*(REAL(I,R8)-0.25_R8)/                    ! Set z to cos(acos(-1.0)*(real(i,r8)-0.25)/ (real(order,r8)+0.5)).
     &        (REAL(ORDER,R8)+0.5_R8))
          DO ITER = 1_I4, 100_I4                                         ! Loop iter from 1 to 100:
            P1 = 1.0_R8                                                  ! Set p1 to 1.0.
            P2 = 0.0_R8                                                  ! Set p2 to zero.
            DO J = 1_I4, ORDER                                           ! Loop j from 1 to order:
              P0 = P2                                                    ! Set p0 to p2.
              P2 = P1                                                    ! Set p2 to p1.
              P1 = ((2.0_R8*REAL(J,R8)-1.0_R8)*Z*P2-                     ! Set p1 to ((2.0*real(j,r8)-1.0)*z*p2- (real(j,r8)-1.0)*p0)/real(j,r8).
     &              (REAL(J,R8)-1.0_R8)*P0)/REAL(J,R8)
            END DO                                                       ! End of the loop.
            DP = REAL(ORDER,R8)*(Z*P1-P2)/(Z*Z-1.0_R8)                   ! Set dp to real(order,r8)*(z*p1-p2)/(z*z-1.0).
            P0 = Z                                                       ! Set p0 to z.
            Z = Z-P1/DP                                                  ! Subtract p1/dp from z.
            IF (ABS(Z-P0) .LT. 1.0E-15_R8) EXIT                          ! If abs(z-p0) < 1.0e-15, leave the loop.
          END DO                                                         ! End of the loop.
          X(I) = -Z                                                      ! Set x(i) to -z.
          X(ORDER+1_I4-I) = Z                                            ! Set x(order+1-i) to z.
          W(I) = 2.0_R8/((1.0_R8-Z*Z)*DP*DP)                             ! Set w(i) to 2.0/((1.0-z*z)*dp*dp).
          W(ORDER+1_I4-I) = W(I)                                         ! Set w(order+1-i) to w(i).
        END DO                                                           ! End of the loop.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      SELECT CASE (ORDER)                                                ! Choose according to the value of order:
      CASE (1_I4)                                                        ! Case 1:
        W(1) = 2.0_R8                                                    ! Set w(1) to 2.0.
      CASE (2_I4)                                                        ! Case 2:
        X(1:2) = [-0.57735026918962576451_R8,                            ! Set x(1:2) to [-0.57735026918962576451, 0.57735026918962576451].
     &             0.57735026918962576451_R8]
        W(1:2) = 1.0_R8                                                  ! Set w(1:2) to 1.0.
      CASE (3_I4)                                                        ! Case 3:
        X(1:3) = [-0.77459666924148337704_R8,0.0_R8,                     ! Set x(1:3) to [-0.77459666924148337704,0.0, 0.77459666924148337704].
     &             0.77459666924148337704_R8]
        W(1:3) = [0.55555555555555555556_R8,                             ! Set w(1:3) to [0.55555555555555555556, 0.88888888888888888889, 0.55555555555555555556].
     &            0.88888888888888888889_R8,
     &            0.55555555555555555556_R8]
      CASE (4_I4)                                                        ! Case 4:
        X(1:4) = [-0.86113631159405257522_R8,                            ! Set x(1:4) to [-0.86113631159405257522, -0.33998104358485626480, 0.33998104358485626480, 0.8611363115940525...
     &            -0.33998104358485626480_R8,
     &             0.33998104358485626480_R8,
     &             0.86113631159405257522_R8]
        W(1:4) = [0.34785484513745385737_R8,                             ! Set w(1:4) to [0.34785484513745385737, 0.65214515486254614263, 0.65214515486254614263, 0.347854845137453857...
     &            0.65214515486254614263_R8,
     &            0.65214515486254614263_R8,
     &            0.34785484513745385737_R8]
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE GAUSS_LEGENDRE_1D                                   ! End of the subroutine gauss legendre 1d.

      SUBROUTINE CLEAR_RULE(RULE)                                        ! Subroutine clear rule takes rule.

      TYPE(QUADRATURE_RULE_TYPE), INTENT(INOUT) :: RULE                  ! In/out of type quadrature_rule_type: rule.

      IF (ALLOCATED(RULE%COORDINATE)) DEALLOCATE(RULE%COORDINATE)        ! If allocated(rule.coordinate), free the memory of rule.coordinate.
      IF (ALLOCATED(RULE%WEIGHT)) DEALLOCATE(RULE%WEIGHT)                ! If allocated(rule.weight), free the memory of rule.weight.
      RULE%NATURAL_DIMENSION = 0_I4                                      ! Set rule.natural_dimension to zero.

      END SUBROUTINE CLEAR_RULE                                          ! End of the subroutine clear rule.

      END MODULE MUL2_QUADRATURE                                         ! End of the module mul2 quadrature.
