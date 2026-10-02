!=======================================================================
!  BLENDING-FUNCTION MAP OF A HLE QUADRILATERAL WITH CURVED SIDES.
!
!  THE SIDES OF A SUB-ELEMENT ARE STRAIGHT UNLESS A THIRD POINT ON THE
!  SIDE IS GIVEN: THE SIDE IS THEN THE CIRCULAR ARC THROUGH ITS TWO
!  VERTICES AND THAT POINT, PARAMETERISED BY ITS ANGLE (EXACT CIRCLE,
!  NO GEOMETRIC APPROXIMATION ERROR). THE MAP IS THE TRANSFINITE
!  (GORDON-HALL) INTERPOLATION OF THE PAPER (EQS. 20-25):
!
!    Q(R,S) = SUM_I N_I(R,S) X_I + SUM_E BETA_E(R,S) (C_E(T) - L_E(T))
!
!  N_I ARE THE BILINEAR VERTEX FUNCTIONS, L_E THE STRAIGHT SIDE, C_E
!  THE ARC, T THE NATURAL COORDINATE ALONG THE SIDE AND BETA_E THE
!  LINEAR BLENDING FUNCTION (1 ON SIDE E, 0 ON THE OPPOSITE ONE).
!  THE FUNCTIONS OF THE EXPANSION ARE NOT THE MAP: THE ELEMENT IS NOT
!  ISOPARAMETRIC.
!=======================================================================
      MODULE MUL2_HLE_MAP                                                ! Module mul2 hle map begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_HLE_SHAPE, ONLY: HLE_SIDE_ENDS                            ! Use from module mul2 hle shape: hle side ends.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: HLE_GEOMETRY_TYPE                                  ! Definition of the derived type hle geometry type.
        LOGICAL :: ANY_CURVED = .FALSE.                                  ! Logical: any_curved = false.
        LOGICAL :: CURVED(4) = .FALSE.                                   ! Logical: curved(4) = false.
        REAL(R8) :: VERTEX(2,4) = 0.0_R8                                 ! Real (real64): vertex(2,4) = 0.0.
        REAL(R8) :: CENTER(2,4) = 0.0_R8                                 ! Real (real64): center(2,4) = 0.0.
        REAL(R8) :: RADIUS(4) = 0.0_R8                                   ! Real (real64): radius(4) = 0.0.
        REAL(R8) :: THETA0(4) = 0.0_R8                                   ! Real (real64): theta0(4) = 0.0.
        REAL(R8) :: DTHETA(4) = 0.0_R8                                   ! Real (real64): dtheta(4) = 0.0.
      END TYPE HLE_GEOMETRY_TYPE                                         ! End of the type definition hle geometry type.

      PUBLIC :: HLE_GEOMETRY_SETUP                                       ! Export: hle geometry setup.
      PUBLIC :: HLE_MAP_EVALUATE                                         ! Export: hle map evaluate.

      CONTAINS                                                           ! The procedures of the module follow.

!  VERTEX(2,4): VERTICES IN THE ACTIVE PLANE; MID(2,4) AND HAS_MID(4):
!  THIRD POINT OF EACH SIDE.
      SUBROUTINE HLE_GEOMETRY_SETUP(VERTEX, MID, HAS_MID, GEOMETRY)      ! Subroutine hle geometry setup takes vertex, mid, has mid, geometry.

      REAL(R8), INTENT(IN) :: VERTEX(2,4)                                ! Input real (real64): vertex(2,4).
      REAL(R8), INTENT(IN) :: MID(2,4)                                   ! Input real (real64): mid(2,4).
      LOGICAL, INTENT(IN) :: HAS_MID(4)                                  ! Input logical: has_mid(4).
      TYPE(HLE_GEOMETRY_TYPE), INTENT(OUT) :: GEOMETRY                   ! Output of type hle_geometry_type: geometry.
      REAL(R8), PARAMETER :: TWO_PI = 6.283185307179586_R8               ! Constant real (real64): two_pi = 6.283185307179586.
      REAL(R8) :: A(2)                                                   ! Real (real64): a(2).
      REAL(R8) :: B(2)                                                   ! Real (real64): b(2).
      REAL(R8) :: M(2)                                                   ! Real (real64): m(2).
      REAL(R8) :: C(2)                                                   ! Real (real64): c(2).
      REAL(R8) :: D                                                      ! Real (real64): d.
      REAL(R8) :: A2                                                     ! Real (real64): a2.
      REAL(R8) :: B2                                                     ! Real (real64): b2.
      REAL(R8) :: M2                                                     ! Real (real64): m2.
      REAL(R8) :: THETA_A                                                ! Real (real64): theta_a.
      REAL(R8) :: THETA_M                                                ! Real (real64): theta_m.
      REAL(R8) :: THETA_B                                                ! Real (real64): theta_b.
      REAL(R8) :: ANGLE_M                                                ! Real (real64): angle_m.
      REAL(R8) :: ANGLE_B                                                ! Real (real64): angle_b.
      INTEGER(I4) :: SIDE                                                ! Integer (int32): side.
      INTEGER(I4) :: START                                               ! Integer (int32): start.
      INTEGER(I4) :: FINISH                                              ! Integer (int32): finish.

      GEOMETRY%VERTEX = VERTEX                                           ! Set geometry.vertex to vertex.
      GEOMETRY%CURVED = .FALSE.                                          ! Set the flag geometry.curved to false.
      GEOMETRY%ANY_CURVED = .FALSE.                                      ! Set the flag geometry.any_curved to false.
      DO SIDE = 1_I4, 4_I4                                               ! Loop side from 1 to 4:
        IF (.NOT. HAS_MID(SIDE)) CYCLE                                   ! If not has_mid(side), skip to the next iteration.
        CALL HLE_SIDE_ENDS(SIDE, START, FINISH)                          ! Call hle side ends with side, start, finish.
        A = VERTEX(:,START)                                              ! Set a to vertex(:,start).
        B = VERTEX(:,FINISH)                                             ! Set b to vertex(:,finish).
        M = MID(:,SIDE)                                                  ! Set m to mid(:,side).
!       CIRCUMCENTRE OF A, M, B.
        D = 2.0_R8*(A(1)*(M(2)-B(2)) + M(1)*(B(2)-A(2)) +                ! Set d to 2.0*(a(1)*(m(2)-b(2)) + m(1)*(b(2)-a(2)) + b(1)*(a(2)-m(2))).
     &              B(1)*(A(2)-M(2)))
        IF (ABS(D) .LE. 1.0E-12_R8*MAX(1.0_R8,                           ! If abs(d) <= 1.0e-12*max(1.0, sum((b-a)**2)), skip to the next iteration.
     &      SUM((B-A)**2))) CYCLE
        A2 = SUM(A**2)                                                   ! Set a2 to the sum of a**2.
        M2 = SUM(M**2)                                                   ! Set m2 to the sum of m**2.
        B2 = SUM(B**2)                                                   ! Set b2 to the sum of b**2.
        C(1) = (A2*(M(2)-B(2)) + M2*(B(2)-A(2)) +                        ! Set c(1) to (a2*(m(2)-b(2)) + m2*(b(2)-a(2)) + b2*(a(2)-m(2)))/d.
     &          B2*(A(2)-M(2)))/D
        C(2) = (A2*(B(1)-M(1)) + M2*(A(1)-B(1)) +                        ! Set c(2) to (a2*(b(1)-m(1)) + m2*(a(1)-b(1)) + b2*(m(1)-a(1)))/d.
     &          B2*(M(1)-A(1)))/D
        THETA_A = ATAN2(A(2)-C(2), A(1)-C(1))                            ! Set theta_a to atan2(a(2)-c(2), a(1)-c(1)).
        THETA_M = ATAN2(M(2)-C(2), M(1)-C(1))                            ! Set theta_m to atan2(m(2)-c(2), m(1)-c(1)).
        THETA_B = ATAN2(B(2)-C(2), B(1)-C(1))                            ! Set theta_b to atan2(b(2)-c(2), b(1)-c(1)).
        ANGLE_M = MODULO(THETA_M-THETA_A, TWO_PI)                        ! Set angle_m to modulo(theta_m-theta_a, two_pi).
        ANGLE_B = MODULO(THETA_B-THETA_A, TWO_PI)                        ! Set angle_b to modulo(theta_b-theta_a, two_pi).
        GEOMETRY%CURVED(SIDE) = .TRUE.                                   ! Set the flag geometry.curved(side) to true.
        GEOMETRY%CENTER(:,SIDE) = C                                      ! Set geometry.center(:,side) to c.
        GEOMETRY%RADIUS(SIDE) = SQRT(SUM((A-C)**2))                      ! Set geometry.radius(side) to the square root of sum((a-c)**2).
        GEOMETRY%THETA0(SIDE) = THETA_A                                  ! Set geometry.theta0(side) to theta_a.
!       THE ARC FROM A TO B MUST PASS THROUGH M.
        IF (ANGLE_M .LT. ANGLE_B) THEN                                   ! If angle_m < angle_b:
          GEOMETRY%DTHETA(SIDE) = ANGLE_B                                ! Set geometry.dtheta(side) to angle_b.
        ELSE                                                             ! Otherwise:
          GEOMETRY%DTHETA(SIDE) = ANGLE_B - TWO_PI                       ! Set geometry.dtheta(side) to angle_b - two_pi.
        END IF                                                           ! End of the IF block.
        GEOMETRY%ANY_CURVED = .TRUE.                                     ! Set the flag geometry.any_curved to true.
      END DO                                                             ! End of the loop.

      END SUBROUTINE HLE_GEOMETRY_SETUP                                  ! End of the subroutine hle geometry setup.

!  X(2) AND DX(:,1) = DX/DR, DX(:,2) = DX/DS AT THE NATURAL POINT (R,S).
      SUBROUTINE HLE_MAP_EVALUATE(GEOMETRY, R, S, X, DX)                 ! Subroutine hle map evaluate takes geometry, r, s, x, dx.

      TYPE(HLE_GEOMETRY_TYPE), INTENT(IN) :: GEOMETRY                    ! Input of type hle_geometry_type: geometry.
      REAL(R8), INTENT(IN) :: R                                          ! Input real (real64): r.
      REAL(R8), INTENT(IN) :: S                                          ! Input real (real64): s.
      REAL(R8), INTENT(OUT) :: X(2)                                      ! Output real (real64): x(2).
      REAL(R8), INTENT(OUT) :: DX(2,2)                                   ! Output real (real64): dx(2,2).
      REAL(R8), PARAMETER :: RV(4) = [-1.0_R8,1.0_R8,1.0_R8,-1.0_R8]     ! Constant real (real64): rv(4) = [-1.0, 1.0, 1.0, -1.0].
      REAL(R8), PARAMETER :: SV(4) = [-1.0_R8,-1.0_R8,1.0_R8,1.0_R8]     ! Constant real (real64): sv(4) = [-1.0, -1.0, 1.0, 1.0].
      REAL(R8) :: NI                                                     ! Real (real64): ni.
      REAL(R8) :: BETA                                                   ! Real (real64): beta.
      REAL(R8) :: DBETA(2)                                               ! Real (real64): dbeta(2).
      REAL(R8) :: T                                                      ! Real (real64): t.
      REAL(R8) :: DT(2)                                                  ! Real (real64): dt(2).
      REAL(R8) :: THETA                                                  ! Real (real64): theta.
      REAL(R8) :: CURVE(2)                                               ! Real (real64): curve(2).
      REAL(R8) :: DCURVE(2)                                              ! Real (real64): dcurve(2).
      REAL(R8) :: LINE(2)                                                ! Real (real64): line(2).
      REAL(R8) :: DLINE(2)                                               ! Real (real64): dline(2).
      REAL(R8) :: DEVIATION(2)                                           ! Real (real64): deviation(2).
      REAL(R8) :: DDEVIATION(2)                                          ! Real (real64): ddeviation(2).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: SIDE                                                ! Integer (int32): side.
      INTEGER(I4) :: START                                               ! Integer (int32): start.
      INTEGER(I4) :: FINISH                                              ! Integer (int32): finish.

      X = 0.0_R8                                                         ! Set x to zero.
      DX = 0.0_R8                                                        ! Set dx to zero.
      DO I = 1_I4, 4_I4                                                  ! Loop i from 1 to 4:
        NI = 0.25_R8*(1.0_R8+RV(I)*R)*(1.0_R8+SV(I)*S)                   ! Set ni to 0.25*(1.0+rv(i)*r)*(1.0+sv(i)*s).
        X = X + NI*GEOMETRY%VERTEX(:,I)                                  ! Add ni*geometry.vertex(:,i) to x.
        DX(:,1) = DX(:,1) + 0.25_R8*RV(I)*(1.0_R8+SV(I)*S)*              ! Add 0.25*rv(i)*(1.0+sv(i)*s)* geometry.vertex(:,i) to dx(:,1).
     &            GEOMETRY%VERTEX(:,I)
        DX(:,2) = DX(:,2) + 0.25_R8*SV(I)*(1.0_R8+RV(I)*R)*              ! Add 0.25*sv(i)*(1.0+rv(i)*r)* geometry.vertex(:,i) to dx(:,2).
     &            GEOMETRY%VERTEX(:,I)
      END DO                                                             ! End of the loop.
      IF (.NOT. GEOMETRY%ANY_CURVED) RETURN                              ! If not geometry.any_curved, return to the caller.

      DO SIDE = 1_I4, 4_I4                                               ! Loop side from 1 to 4:
        IF (.NOT. GEOMETRY%CURVED(SIDE)) CYCLE                           ! If not geometry.curved(side), skip to the next iteration.
        CALL HLE_SIDE_ENDS(SIDE, START, FINISH)                          ! Call hle side ends with side, start, finish.
        SELECT CASE (SIDE)                                               ! Choose according to the value of side:
        CASE (1_I4)                                                      ! Case 1:
          BETA = 0.5_R8*(1.0_R8-S)                                       ! Set beta to 0.5*(1.0-s).
          DBETA = [0.0_R8,-0.5_R8]                                       ! Set dbeta to [0.0,-0.5].
          T = R                                                          ! Set t to r.
          DT = [1.0_R8,0.0_R8]                                           ! Set dt to [1.0,0.0].
        CASE (2_I4)                                                      ! Case 2:
          BETA = 0.5_R8*(1.0_R8+R)                                       ! Set beta to 0.5*(1.0+r).
          DBETA = [0.5_R8,0.0_R8]                                        ! Set dbeta to [0.5,0.0].
          T = S                                                          ! Set t to s.
          DT = [0.0_R8,1.0_R8]                                           ! Set dt to [0.0,1.0].
        CASE (3_I4)                                                      ! Case 3:
          BETA = 0.5_R8*(1.0_R8+S)                                       ! Set beta to 0.5*(1.0+s).
          DBETA = [0.0_R8,0.5_R8]                                        ! Set dbeta to [0.0,0.5].
          T = R                                                          ! Set t to r.
          DT = [1.0_R8,0.0_R8]                                           ! Set dt to [1.0,0.0].
        CASE DEFAULT                                                     ! In every other case:
          BETA = 0.5_R8*(1.0_R8-R)                                       ! Set beta to 0.5*(1.0-r).
          DBETA = [-0.5_R8,0.0_R8]                                       ! Set dbeta to [-0.5,0.0].
          T = S                                                          ! Set t to s.
          DT = [0.0_R8,1.0_R8]                                           ! Set dt to [0.0,1.0].
        END SELECT                                                       ! End of the case selection.
        THETA = GEOMETRY%THETA0(SIDE) +                                  ! Set theta to geometry.theta0(side) + geometry.dtheta(side)*0.5*(t+1.0).
     &          GEOMETRY%DTHETA(SIDE)*0.5_R8*(T+1.0_R8)
        CURVE = GEOMETRY%CENTER(:,SIDE) + GEOMETRY%RADIUS(SIDE)*         ! Set curve to geometry.center(:,side) + geometry.radius(side)* [cos(theta),sin(theta)].
     &          [COS(THETA),SIN(THETA)]
        DCURVE = GEOMETRY%RADIUS(SIDE)*GEOMETRY%DTHETA(SIDE)*0.5_R8*     ! Set dcurve to geometry.radius(side)*geometry.dtheta(side)*0.5* [-sin(theta),cos(theta)].
     &           [-SIN(THETA),COS(THETA)]
        LINE = 0.5_R8*(1.0_R8-T)*GEOMETRY%VERTEX(:,START) +              ! Set line to 0.5*(1.0-t)*geometry.vertex(:,start) + 0.5*(1.0+t)*geometry.vertex(:,finish).
     &         0.5_R8*(1.0_R8+T)*GEOMETRY%VERTEX(:,FINISH)
        DLINE = 0.5_R8*(GEOMETRY%VERTEX(:,FINISH) -                      ! Set dline to 0.5*(geometry.vertex(:,finish) - geometry.vertex(:,start)).
     &                  GEOMETRY%VERTEX(:,START))
        DEVIATION = CURVE - LINE                                         ! Set deviation to curve - line.
        DDEVIATION = DCURVE - DLINE                                      ! Set ddeviation to dcurve - dline.
        X = X + BETA*DEVIATION                                           ! Add beta*deviation to x.
        DX(:,1) = DX(:,1) + DBETA(1)*DEVIATION +                         ! Add dbeta(1)*deviation + beta*ddeviation*dt(1) to dx(:,1).
     &            BETA*DDEVIATION*DT(1)
        DX(:,2) = DX(:,2) + DBETA(2)*DEVIATION +                         ! Add dbeta(2)*deviation + beta*ddeviation*dt(2) to dx(:,2).
     &            BETA*DDEVIATION*DT(2)
      END DO                                                             ! End of the loop.

      END SUBROUTINE HLE_MAP_EVALUATE                                    ! End of the subroutine hle map evaluate.

      END MODULE MUL2_HLE_MAP                                            ! End of the module mul2 hle map.
