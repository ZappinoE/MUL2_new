!=======================================================================
!  UNIT TESTS OF THE HIERARCHICAL LEGENDRE EXPANSION (NO SOLVER).
!    1. NUMBER OF FUNCTIONS PER ORDER
!    2. VERTEX MODES: PARTITION OF UNITY, KRONECKER PROPERTY
!    3. DERIVATIVES BY CENTRAL DIFFERENCES
!    4. C0 CONFORMITY ON THE SHARED SIDE OF TWO SUB-ELEMENTS FOR
!       DIFFERENT ORDERS AND NODE NUMBERINGS
!    5. BLENDING MAP: AREA OF A QUARTER ANNULUS, SIDES ON THE CIRCLES,
!       DERIVATIVES OF THE MAP BY CENTRAL DIFFERENCES
!=======================================================================
      PROGRAM MUL2_HLE_TESTS                                             ! Main program mul2 hle tests begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, STATUS_IS_OK     ! Use from module mul2 status: status type, clear status, status is ok.
      USE MUL2_HLE_SHAPE, ONLY: HLE_FUNCTION_COUNT, EVALUATE_HLE_SHAPE   ! Use from module mul2 hle shape: hle function count, evaluate hle shape.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_MESH_TYPE               ! Use from module mul2 expansion meshes: expansion mesh type.
      USE MUL2_HLE_MODES, ONLY: BUILD_HLE_MESH                           ! Use from module mul2 hle modes: build hle mesh.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_HQ_BASE, TOPOLOGY_Q4           ! Use from module mul2 topologies: topology hq base, topology q4.
      USE MUL2_HLE_MAP, ONLY: HLE_GEOMETRY_TYPE, HLE_GEOMETRY_SETUP,     ! Use from module mul2 hle map: hle geometry type, hle geometry setup, hle map evaluate.
     &                        HLE_MAP_EVALUATE
      USE MUL2_QUADRATURE, ONLY: QUADRATURE_RULE_TYPE,                   ! Use from module mul2 quadrature: quadrature rule type, build ordered quadrature.
     &                           BUILD_ORDERED_QUADRATURE

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.

      INTEGER(I8) :: FAILURES                                            ! Integer (int64): failures.
      INTEGER(I4) :: P                                                   ! Integer (int32): p.
      INTEGER(I4) :: VARIANT                                             ! Integer (int32): variant.

      FAILURES = 0_I8                                                    ! Set failures to zero.
      CALL TEST_COUNTS(FAILURES)                                         ! Call test counts with failures.
      CALL TEST_VERTEX(FAILURES)                                         ! Call test vertex with failures.
      DO P = 1_I4, 8_I4                                                  ! Loop p from 1 to 8:
        CALL TEST_DERIVATIVES(P, FAILURES)                               ! Call test derivatives with p, failures.
      END DO                                                             ! End of the loop.
      DO VARIANT = 1_I4, 4_I4                                            ! Loop variant from 1 to 4:
        CALL TEST_CONFORMITY(3_I4, 4_I4, VARIANT, FAILURES)              ! Call test conformity with 3, 4, variant, failures.
        CALL TEST_CONFORMITY(4_I4, 2_I4, VARIANT, FAILURES)              ! Call test conformity with 4, 2, variant, failures.
        CALL TEST_CONFORMITY(5_I4, 5_I4, VARIANT, FAILURES)              ! Call test conformity with 5, 5, variant, failures.
      END DO                                                             ! End of the loop.

      CALL TEST_MAP(FAILURES)                                            ! Call test map with failures.

      IF (FAILURES .EQ. 0_I8) THEN                                       ! If failures = 0:
        WRITE(*,'(A)') 'MUL2_HLE_TESTS PASSED'                           ! Print: 'MUL2_HLE_TESTS PASSED'.
      ELSE                                                               ! Otherwise:
        WRITE(*,'(A,I0)') 'MUL2_HLE_TESTS FAILED: ', FAILURES            ! Print: 'MUL2_HLE_TESTS FAILED: ', failures.
        STOP 1                                                           ! Stop the program.
      END IF                                                             ! End of the IF block.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE TEST_MAP(FAILURES)                                      ! Subroutine test map takes failures.

      INTEGER(I8), INTENT(INOUT) :: FAILURES                             ! In/out integer (int64): failures.
      TYPE(HLE_GEOMETRY_TYPE) :: G                                       ! Of type hle_geometry_type: g.
      TYPE(QUADRATURE_RULE_TYPE) :: RULE                                 ! Of type quadrature_rule_type: rule.
      TYPE(STATUS_TYPE) :: STATUS                                        ! Of type status_type: status.
      REAL(R8), PARAMETER :: RI = 0.3_R8                                 ! Constant real (real64): ri = 0.3.
      REAL(R8), PARAMETER :: RO = 0.5_R8                                 ! Constant real (real64): ro = 0.5.
      REAL(R8), PARAMETER :: PI = 3.141592653589793_R8                   ! Constant real (real64): pi = 3.141592653589793.
      REAL(R8) :: V(2,4)                                                 ! Real (real64): v(2,4).
      REAL(R8) :: MID(2,4)                                               ! Real (real64): mid(2,4).
      REAL(R8) :: X(2)                                                   ! Real (real64): x(2).
      REAL(R8) :: XP(2)                                                  ! Real (real64): xp(2).
      REAL(R8) :: XM(2)                                                  ! Real (real64): xm(2).
      REAL(R8) :: DX(2,2)                                                ! Real (real64): dx(2,2).
      REAL(R8) :: DUMMY(2,2)                                             ! Real (real64): dummy(2,2).
      REAL(R8) :: AREA                                                   ! Real (real64): area.
      REAL(R8) :: DET                                                    ! Real (real64): det.
      REAL(R8) :: T                                                      ! Real (real64): t.
      REAL(R8) :: ERROR                                                  ! Real (real64): error.
      REAL(R8), PARAMETER :: H = 1.0E-6_R8                               ! Constant real (real64): h = 1.0e-6.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      LOGICAL :: HAS(4)                                                  ! Logical: has(4).

!     QUARTER ANNULUS, COUNTER-CLOCKWISE: INNER -> OUTER ALONG X, OUTER
!     ARC (SIDE 2), OUTER -> INNER ALONG Z, INNER ARC (SIDE 4).
      V(:,1) = [RI,0.0_R8]                                               ! Set v(:,1) to [ri,0.0].
      V(:,2) = [RO,0.0_R8]                                               ! Set v(:,2) to [ro,0.0].
      V(:,3) = [0.0_R8,RO]                                               ! Set v(:,3) to [0.0,ro].
      V(:,4) = [0.0_R8,RI]                                               ! Set v(:,4) to [0.0,ri].
      MID = 0.0_R8                                                       ! Set mid to zero.
      MID(:,2) = RO*[COS(PI/4.0_R8),SIN(PI/4.0_R8)]                      ! Set mid(:,2) to ro*[cos(pi/4.0),sin(pi/4.0)].
      MID(:,4) = RI*[COS(PI/4.0_R8),SIN(PI/4.0_R8)]                      ! Set mid(:,4) to ri*[cos(pi/4.0),sin(pi/4.0)].
      HAS = [.FALSE.,.TRUE.,.FALSE.,.TRUE.]                              ! Set has to [false,true,false,true].
      CALL HLE_GEOMETRY_SETUP(V, MID, HAS, G)                            ! Call hle geometry setup with v, mid, has, g.
      IF (.NOT. G%ANY_CURVED) THEN                                       ! If not g.any_curved:
        WRITE(*,'(A)') 'FAIL: ARC NOT DETECTED'                          ! Print: 'FAIL: ARC NOT DETECTED'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL BUILD_ORDERED_QUADRATURE(TOPOLOGY_Q4, 12_I4, RULE, STATUS)    ! Call build ordered quadrature with topology_q4, 12, rule, status.
      AREA = 0.0_R8                                                      ! Set area to zero.
      DO I = 1_I4, SIZE(RULE%WEIGHT)                                     ! Loop i from 1 to size(rule.weight):
        CALL HLE_MAP_EVALUATE(G, RULE%COORDINATE(I,1),                   ! Call hle map evaluate with g, rule.coordinate(i,1), rule.coordinate(i,2), x, dx.
     &                        RULE%COORDINATE(I,2), X, DX)
        DET = DX(1,1)*DX(2,2) - DX(1,2)*DX(2,1)                          ! Set det to dx(1,1)*dx(2,2) - dx(1,2)*dx(2,1).
        AREA = AREA + RULE%WEIGHT(I)*DET                                 ! Add rule.weight(i)*det to area.
      END DO                                                             ! End of the loop.
      IF (ABS(AREA-0.25_R8*PI*(RO**2-RI**2)) .GT. 1.0E-13_R8) THEN       ! If abs(area-0.25*pi*(ro**2-ri**2)) > 1.0e-13:
        WRITE(*,'(A,2ES14.6)') 'FAIL: ANNULUS AREA ', AREA,              ! Print: 'FAIL: ANNULUS AREA ', area, 0.25*pi*(ro**2-ri**2).
     &    0.25_R8*PI*(RO**2-RI**2)
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

!     THE CURVED SIDES LIE ON THE CIRCLES, THE STRAIGHT ONES ON AXES.
      ERROR = 0.0_R8                                                     ! Set error to zero.
      DO K = 0_I4, 10_I4                                                 ! Loop k from 0 to 10:
        T = -1.0_R8 + 0.2_R8*REAL(K,R8)                                  ! Set t to -1.0 + 0.2*real(k,r8).
        CALL HLE_MAP_EVALUATE(G, 1.0_R8, T, X, DX)                       ! Call hle map evaluate with g, 1.0, t, x, dx.
        ERROR = MAX(ERROR, ABS(SQRT(SUM(X**2))-RO))                      ! Set error to the larger of error and abs(sqrt(sum(x**2))-ro).
        CALL HLE_MAP_EVALUATE(G, -1.0_R8, T, X, DX)                      ! Call hle map evaluate with g, -1.0, t, x, dx.
        ERROR = MAX(ERROR, ABS(SQRT(SUM(X**2))-RI))                      ! Set error to the larger of error and abs(sqrt(sum(x**2))-ri).
        CALL HLE_MAP_EVALUATE(G, T, -1.0_R8, X, DX)                      ! Call hle map evaluate with g, t, -1.0, x, dx.
        ERROR = MAX(ERROR, ABS(X(2)))                                    ! Set error to the larger of error and abs(x(2)).
        CALL HLE_MAP_EVALUATE(G, T, 1.0_R8, X, DX)                       ! Call hle map evaluate with g, t, 1.0, x, dx.
        ERROR = MAX(ERROR, ABS(X(1)))                                    ! Set error to the larger of error and abs(x(1)).
      END DO                                                             ! End of the loop.
      IF (ERROR .GT. 1.0E-14_R8) THEN                                    ! If error > 1.0e-14:
        WRITE(*,'(A,ES10.2)') 'FAIL: SIDES OFF THE CIRCLES ', ERROR      ! Print: 'FAIL: SIDES OFF THE CIRCLES ', error.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

!     DERIVATIVES OF THE MAP.
      ERROR = 0.0_R8                                                     ! Set error to zero.
      DO K = 1_I4, 2_I4                                                  ! Loop k from 1 to 2:
        CALL HLE_MAP_EVALUATE(G, 0.31_R8+MERGE(H,0.0_R8,K .EQ. 1_I4),    ! Call hle map evaluate with g, 0.31+merge(h,0.0,k = 1), -0.47+merge(h,0.0,k = 2), xp, dummy.
     &    -0.47_R8+MERGE(H,0.0_R8,K .EQ. 2_I4), XP, DUMMY)
        CALL HLE_MAP_EVALUATE(G, 0.31_R8-MERGE(H,0.0_R8,K .EQ. 1_I4),    ! Call hle map evaluate with g, 0.31-merge(h,0.0,k = 1), -0.47-merge(h,0.0,k = 2), xm, dummy.
     &    -0.47_R8-MERGE(H,0.0_R8,K .EQ. 2_I4), XM, DUMMY)
        CALL HLE_MAP_EVALUATE(G, 0.31_R8, -0.47_R8, X, DX)               ! Call hle map evaluate with g, 0.31, -0.47, x, dx.
        ERROR = MAX(ERROR, MAXVAL(ABS((XP-XM)/(2.0_R8*H)-DX(:,K))))      ! Set error to the larger of error and maxval(abs((xp-xm)/(2.0*h)-dx(:,k))).
      END DO                                                             ! End of the loop.
      IF (ERROR .GT. 1.0E-8_R8) THEN                                     ! If error > 1.0e-8:
        WRITE(*,'(A,ES10.2)') 'FAIL: MAP DERIVATIVE ', ERROR             ! Print: 'FAIL: MAP DERIVATIVE ', error.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

!     A MID POINT ON THE STRAIGHT LINE KEEPS THE SIDE STRAIGHT.
      MID = 0.0_R8                                                       ! Set mid to zero.
      MID(:,2) = 0.5_R8*(V(:,2)+V(:,3))                                  ! Set mid(:,2) to 0.5*(v(:,2)+v(:,3)).
      HAS = [.FALSE.,.TRUE.,.FALSE.,.FALSE.]                             ! Set has to [false,true,false,false].
      CALL HLE_GEOMETRY_SETUP(V, MID, HAS, G)                            ! Call hle geometry setup with v, mid, has, g.
      IF (G%ANY_CURVED) THEN                                             ! If g.any_curved:
        WRITE(*,'(A)') 'FAIL: COLLINEAR MID POINT SHOULD BE STRAIGHT'    ! Print: 'FAIL: COLLINEAR MID POINT SHOULD BE STRAIGHT'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE TEST_MAP                                            ! End of the subroutine test map.

      SUBROUTINE TEST_COUNTS(FAILURES)                                   ! Subroutine test counts takes failures.

      INTEGER(I8), INTENT(INOUT) :: FAILURES                             ! In/out integer (int64): failures.
      INTEGER(I4), PARAMETER :: EXPECTED(8) =                            ! Constant integer (int32): expected(8) = [4, 8, 12, 17, 23, 30, 38, 47].
     &  [4,8,12,17,23,30,38,47]
      INTEGER(I4) :: P                                                   ! Integer (int32): p.

      DO P = 1_I4, 8_I4                                                  ! Loop p from 1 to 8:
        IF (HLE_FUNCTION_COUNT(.TRUE.,P) .NE. EXPECTED(P)) THEN          ! If hle_function_count(true,p) /= expected(p):
          WRITE(*,'(A,I0)') 'FAIL: HQ FUNCTION COUNT, ORDER ', P         ! Print: 'FAIL: HQ FUNCTION COUNT, ORDER ', p.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
        IF (HLE_FUNCTION_COUNT(.FALSE.,P) .NE. P+1_I4) THEN              ! If hle_function_count(false,p) /= p+1:
          WRITE(*,'(A,I0)') 'FAIL: HB FUNCTION COUNT, ORDER ', P         ! Print: 'FAIL: HB FUNCTION COUNT, ORDER ', p.
          FAILURES = FAILURES + 1_I8                                     ! Add 1 to failures.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE TEST_COUNTS                                         ! End of the subroutine test counts.

      SUBROUTINE TEST_VERTEX(FAILURES)                                   ! Subroutine test vertex takes failures.

      INTEGER(I8), INTENT(INOUT) :: FAILURES                             ! In/out integer (int64): failures.
      REAL(R8) :: N(23)                                                  ! Real (real64): n(23).
      REAL(R8) :: DN(23,3)                                               ! Real (real64): dn(23,3).
      REAL(R8) :: X(2)                                                   ! Real (real64): x(2).
      REAL(R8), PARAMETER :: RV(4) = [-1.0_R8,1.0_R8,1.0_R8,-1.0_R8]     ! Constant real (real64): rv(4) = [-1.0, 1.0, 1.0, -1.0].
      REAL(R8), PARAMETER :: SV(4) = [-1.0_R8,-1.0_R8,1.0_R8,1.0_R8]     ! Constant real (real64): sv(4) = [-1.0, -1.0, 1.0, 1.0].
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      X = [0.31_R8,-0.47_R8]                                             ! Set x to [0.31,-0.47].
      CALL EVALUATE_HLE_SHAPE(.TRUE., 5_I4, X, N, DN)                    ! Call evaluate hle shape with true, 5, x, n, dn.
      IF (ABS(SUM(N(1:4))-1.0_R8) .GT. 1.0E-14_R8) THEN                  ! If abs(sum(n(1:4))-1.0) > 1.0e-14:
        WRITE(*,'(A)') 'FAIL: VERTEX PARTITION OF UNITY'                 ! Print: 'FAIL: VERTEX PARTITION OF UNITY'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      DO I = 1_I4, 4_I4                                                  ! Loop i from 1 to 4:
        X = [RV(I),SV(I)]                                                ! Set x to [rv(i),sv(i)].
        CALL EVALUATE_HLE_SHAPE(.TRUE., 5_I4, X, N, DN)                  ! Call evaluate hle shape with true, 5, x, n, dn.
        DO J = 1_I4, 23_I4                                               ! Loop j from 1 to 23:
          IF (ABS(N(J)-MERGE(1.0_R8,0.0_R8,J .EQ. I)) .GT.               ! If abs(n(j)-merge(1.0,0.0,j = i)) > 1.0e-14:
     &        1.0E-14_R8) THEN
            WRITE(*,'(A,2I3)') 'FAIL: KRONECKER AT VERTEX ', I, J        ! Print: 'FAIL: KRONECKER AT VERTEX ', i, j.
            FAILURES = FAILURES + 1_I8                                   ! Add 1 to failures.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE TEST_VERTEX                                         ! End of the subroutine test vertex.

      SUBROUTINE TEST_DERIVATIVES(P, FAILURES)                           ! Subroutine test derivatives takes p, failures.

      INTEGER(I4), INTENT(IN) :: P                                       ! Input integer (int32): p.
      INTEGER(I8), INTENT(INOUT) :: FAILURES                             ! In/out integer (int64): failures.
      REAL(R8) :: N(64)                                                  ! Real (real64): n(64).
      REAL(R8) :: DN(64,3)                                               ! Real (real64): dn(64,3).
      REAL(R8) :: NP(64)                                                 ! Real (real64): np(64).
      REAL(R8) :: NM(64)                                                 ! Real (real64): nm(64).
      REAL(R8) :: DUMMY(64,3)                                            ! Real (real64): dummy(64,3).
      REAL(R8) :: X(2)                                                   ! Real (real64): x(2).
      REAL(R8) :: XP(2)                                                  ! Real (real64): xp(2).
      REAL(R8) :: XM(2)                                                  ! Real (real64): xm(2).
      REAL(R8), PARAMETER :: H = 1.0E-6_R8                               ! Constant real (real64): h = 1.0e-6.
      INTEGER(I4) :: NF                                                  ! Integer (int32): nf.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.

      NF = HLE_FUNCTION_COUNT(.TRUE.,P)                                  ! Set nf to hle_function_count(true,p).
      X = [0.37_R8,-0.61_R8]                                             ! Set x to [0.37,-0.61].
      CALL EVALUATE_HLE_SHAPE(.TRUE., P, X, N, DN)                       ! Call evaluate hle shape with true, p, x, n, dn.
      DO K = 1_I4, 2_I4                                                  ! Loop k from 1 to 2:
        XP = X                                                           ! Set xp to x.
        XM = X                                                           ! Set xm to x.
        XP(K) = X(K) + H                                                 ! Set xp(k) to x(k) + h.
        XM(K) = X(K) - H                                                 ! Set xm(k) to x(k) - h.
        CALL EVALUATE_HLE_SHAPE(.TRUE., P, XP, NP, DUMMY)                ! Call evaluate hle shape with true, p, xp, np, dummy.
        CALL EVALUATE_HLE_SHAPE(.TRUE., P, XM, NM, DUMMY)                ! Call evaluate hle shape with true, p, xm, nm, dummy.
        DO L = 1_I4, NF                                                  ! Loop l from 1 to nf:
          IF (ABS((NP(L)-NM(L))/(2.0_R8*H)-DN(L,K)) .GT.                 ! If abs((np(l)-nm(l))/(2.0*h)-dn(l,k)) > 1.0e-6*max(1.0,abs(dn(l,k))):
     &        1.0E-6_R8*MAX(1.0_R8,ABS(DN(L,K)))) THEN
            WRITE(*,'(A,3I4)') 'FAIL: HQ DERIVATIVE P,MODE,AXIS ',       ! Print: 'FAIL: HQ DERIVATIVE P,MODE,AXIS ', p, l, k.
     &        P, L, K
            FAILURES = FAILURES + 1_I8                                   ! Add 1 to failures.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE TEST_DERIVATIVES                                    ! End of the subroutine test derivatives.

!  TWO SQUARES SHARING THE SIDE X = 0. VARIANT BITS: 1 = SWAP THE IDS OF
!  THE SHARED NODES, 2 = ROTATE THE NUMBERING OF THE RIGHT ELEMENT BY 2.
      SUBROUTINE TEST_CONFORMITY(PL, PR, VARIANT, FAILURES)              ! Subroutine test conformity takes pl, pr, variant, failures.

      INTEGER(I4), INTENT(IN) :: PL                                      ! Input integer (int32): pl.
      INTEGER(I4), INTENT(IN) :: PR                                      ! Input integer (int32): pr.
      INTEGER(I4), INTENT(IN) :: VARIANT                                 ! Input integer (int32): variant.
      INTEGER(I8), INTENT(INOUT) :: FAILURES                             ! In/out integer (int64): failures.
      TYPE(EXPANSION_MESH_TYPE) :: MESH                                  ! Of type expansion_mesh_type: mesh.
      TYPE(STATUS_TYPE) :: STATUS                                        ! Of type status_type: status.
      REAL(R8) :: X(2)                                                   ! Real (real64): x(2).
      REAL(R8) :: FLEFT(400)                                             ! Real (real64): fleft(400).
      REAL(R8) :: FRIGHT(400)                                            ! Real (real64): fright(400).
      REAL(R8) :: T                                                      ! Real (real64): t.
      REAL(R8) :: WORST                                                  ! Real (real64): worst.
      INTEGER(I8) :: IDS(6)                                              ! Integer (int64): ids(6).
      INTEGER(I8) :: LEFT(4)                                             ! Integer (int64): left(4).
      INTEGER(I8) :: RIGHT(4)                                            ! Integer (int64): right(4).
      INTEGER(I8) :: HOLD(4)                                             ! Integer (int64): hold(4).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: SAMPLE                                              ! Integer (int32): sample.
      REAL(R8), PARAMETER :: XC(6) =                                     ! Constant real (real64): xc(6) = [-1.0, 0.0, 1.0, -1.0, 0.0, 1.0].
     &  [-1.0_R8,0.0_R8,1.0_R8,-1.0_R8,0.0_R8,1.0_R8]
      REAL(R8), PARAMETER :: ZC(6) =                                     ! Constant real (real64): zc(6) = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0].
     &  [0.0_R8,0.0_R8,0.0_R8,1.0_R8,1.0_R8,1.0_R8]

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IDS = [10_I8,20_I8,30_I8,40_I8,50_I8,60_I8]                        ! Set ids to [10,20,30,40,50,60].
      IF (IAND(VARIANT-1_I4,1_I4) .NE. 0_I4) THEN                        ! If iand(variant-1,1) /= 0:
        IDS(2) = 55_I8                                                   ! Set ids(2) to 55.
        IDS(5) = 15_I8                                                   ! Set ids(5) to 15.
      END IF                                                             ! End of the IF block.
      ALLOCATE(MESH%NODE(6))                                             ! Allocate memory for mesh.node(6).
      DO I = 1_I4, 6_I4                                                  ! Loop i from 1 to 6:
        MESH%NODE(I)%ID = IDS(I)                                         ! Set mesh.node(i).id to ids(i).
        MESH%NODE(I)%COORDINATE = [XC(I),0.0_R8,ZC(I)]                   ! Set mesh.node(i).coordinate to [xc(i),0.0,zc(i)].
      END DO                                                             ! End of the loop.
      LEFT = [IDS(1),IDS(2),IDS(5),IDS(4)]                               ! Set left to [ids(1),ids(2),ids(5),ids(4)].
      RIGHT = [IDS(2),IDS(3),IDS(6),IDS(5)]                              ! Set right to [ids(2),ids(3),ids(6),ids(5)].
      IF (IAND((VARIANT-1_I4)/2_I4,1_I4) .NE. 0_I4) THEN                 ! If iand((variant-1)/2,1) /= 0:
        HOLD = RIGHT                                                     ! Set hold to right.
        RIGHT = [HOLD(3),HOLD(4),HOLD(1),HOLD(2)]                        ! Set right to [hold(3),hold(4),hold(1),hold(2)].
      END IF                                                             ! End of the IF block.
      ALLOCATE(MESH%ELEMENT(2))                                          ! Allocate memory for mesh.element(2).
      MESH%ELEMENT(1)%TOPOLOGY = TOPOLOGY_HQ_BASE + PL                   ! Set mesh.element(1).topology to topology_hq_base + pl.
      MESH%ELEMENT(2)%TOPOLOGY = TOPOLOGY_HQ_BASE + PR                   ! Set mesh.element(2).topology to topology_hq_base + pr.
      MESH%ELEMENT(1)%NODE_ID = LEFT                                     ! Set mesh.element(1).node_id to left.
      MESH%ELEMENT(2)%NODE_ID = RIGHT                                    ! Set mesh.element(2).node_id to right.
      CALL BUILD_HLE_MESH(MESH, STATUS)                                  ! Call build hle mesh with mesh, status.
      IF (.NOT. STATUS_IS_OK(STATUS) .OR. .NOT. MESH%IS_HLE) THEN        ! If not status is ok or not mesh.is_hle:
        WRITE(*,'(A)') 'FAIL: BUILD_HLE_MESH'                            ! Print: 'FAIL: BUILD_HLE_MESH'.
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      WORST = 0.0_R8                                                     ! Set worst to zero.
      DO SAMPLE = 0_I4, 10_I4                                            ! Loop sample from 0 to 10:
        T = 0.0_R8 + 0.1_R8*REAL(SAMPLE,R8)                              ! Set t to 0.0 + 0.1*real(sample,r8).
        CALL TRACE(MESH, 1_I4, T, FLEFT)                                 ! Call trace with mesh, 1, t, fleft.
        CALL TRACE(MESH, 2_I4, T, FRIGHT)                                ! Call trace with mesh, 2, t, fright.
        DO K = 1_I4, MESH%N_TERM                                         ! Loop k from 1 to mesh.n_term:
          WORST = MAX(WORST, ABS(FLEFT(K)-FRIGHT(K)))                    ! Set worst to the larger of worst and abs(fleft(k)-fright(k)).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (WORST .GT. 1.0E-13_R8) THEN                                    ! If worst > 1.0e-13:
        WRITE(*,'(A,3I3,ES10.2)') 'FAIL: C0 JUMP P,P,VARIANT ',          ! Print: 'FAIL: C0 JUMP P,P,VARIANT ', pl, pr, variant, worst.
     &    PL, PR, VARIANT, WORST
        FAILURES = FAILURES + 1_I8                                       ! Add 1 to failures.
      END IF                                                             ! End of the IF block.
      DEALLOCATE(MESH%NODE, MESH%ELEMENT)                                ! Free the memory of mesh.node, mesh.element.

      END SUBROUTINE TEST_CONFORMITY                                     ! End of the subroutine test conformity.

!  GLOBAL FUNCTIONS OF ONE ELEMENT AT THE POINT (X = 0, Z = T) OF THE
!  SHARED SIDE; THE NATURAL COORDINATES COME FROM A NEWTON ITERATION ON
!  THE BILINEAR MAP OF THE ELEMENT.
      SUBROUTINE TRACE(MESH, E, T, F)                                    ! Subroutine trace takes mesh, e, t, f.

      TYPE(EXPANSION_MESH_TYPE), INTENT(IN) :: MESH                      ! Input of type expansion_mesh_type: mesh.
      INTEGER(I4), INTENT(IN) :: E                                       ! Input integer (int32): e.
      REAL(R8), INTENT(IN) :: T                                          ! Input real (real64): t.
      REAL(R8), INTENT(OUT) :: F(:)                                      ! Output real (real64): f(:).
      REAL(R8) :: V(4,2)                                                 ! Real (real64): v(4,2).
      REAL(R8) :: N(64)                                                  ! Real (real64): n(64).
      REAL(R8) :: DN(64,3)                                               ! Real (real64): dn(64,3).
      REAL(R8) :: X(2)                                                   ! Real (real64): x(2).
      REAL(R8) :: PHYS(2)                                                ! Real (real64): phys(2).
      REAL(R8) :: RES(2)                                                 ! Real (real64): res(2).
      REAL(R8) :: JAC(2,2)                                               ! Real (real64): jac(2,2).
      REAL(R8) :: DET                                                    ! Real (real64): det.
      REAL(R8) :: STEP(2)                                                ! Real (real64): step(2).
      INTEGER(I4) :: P                                                   ! Integer (int32): p.
      INTEGER(I4) :: NF                                                  ! Integer (int32): nf.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: ITER                                                ! Integer (int32): iter.

      P = MESH%ELEMENT(E)%TOPOLOGY - TOPOLOGY_HQ_BASE                    ! Set p to mesh.element(e).topology - topology_hq_base.
      NF = HLE_FUNCTION_COUNT(.TRUE.,P)                                  ! Set nf to hle_function_count(true,p).
      DO I = 1_I4, 4_I4                                                  ! Loop i from 1 to 4:
        DO J = 1_I4, SIZE(MESH%NODE)                                     ! Loop j from 1 to size(mesh.node):
          IF (MESH%NODE(J)%ID .EQ. MESH%ELEMENT(E)%NODE_ID(I)) THEN      ! If mesh.node(j).id = mesh.element(e).node_id(i):
            V(I,1) = MESH%NODE(J)%COORDINATE(1)                          ! Set v(i,1) to mesh.node(j).coordinate(1).
            V(I,2) = MESH%NODE(J)%COORDINATE(3)                          ! Set v(i,2) to mesh.node(j).coordinate(3).
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      PHYS = [0.0_R8,T]                                                  ! Set phys to [0.0,t].
      X = 0.0_R8                                                         ! Set x to zero.
      DO ITER = 1_I4, 30_I4                                              ! Loop iter from 1 to 30:
        CALL EVALUATE_HLE_SHAPE(.TRUE., 1_I4, X, N, DN)                  ! Call evaluate hle shape with true, 1, x, n, dn.
        RES = -PHYS                                                      ! Set res to -phys.
        JAC = 0.0_R8                                                     ! Set jac to zero.
        DO I = 1_I4, 4_I4                                                ! Loop i from 1 to 4:
          RES = RES + N(I)*V(I,:)                                        ! Add n(i)*v(i,:) to res.
          DO J = 1_I4, 2_I4                                              ! Loop j from 1 to 2:
            JAC(:,J) = JAC(:,J) + DN(I,J)*V(I,:)                         ! Add dn(i,j)*v(i,:) to jac(:,j).
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
        DET = JAC(1,1)*JAC(2,2)-JAC(1,2)*JAC(2,1)                        ! Set det to jac(1,1)*jac(2,2)-jac(1,2)*jac(2,1).
        STEP(1) = (JAC(2,2)*RES(1)-JAC(1,2)*RES(2))/DET                  ! Set step(1) to (jac(2,2)*res(1)-jac(1,2)*res(2))/det.
        STEP(2) = (-JAC(2,1)*RES(1)+JAC(1,1)*RES(2))/DET                 ! Set step(2) to (-jac(2,1)*res(1)+jac(1,1)*res(2))/det.
        X = X - STEP                                                     ! Subtract step from x.
      END DO                                                             ! End of the loop.
      CALL EVALUATE_HLE_SHAPE(.TRUE., P, X, N, DN)                       ! Call evaluate hle shape with true, p, x, n, dn.
      F = 0.0_R8                                                         ! Set f to zero.
      DO I = 1_I4, NF                                                    ! Loop i from 1 to nf:
        IF (MESH%ELEMENT(E)%MODE_TERM(I) .GE. 1_I4)                      ! If mesh.element(e).mode_term(i) >= 1, add mesh.element(e).mode_sign(i)*n(i) to f(mesh.element(e).mode_term(...
     &    F(MESH%ELEMENT(E)%MODE_TERM(I)) =
     &      F(MESH%ELEMENT(E)%MODE_TERM(I)) +
     &      MESH%ELEMENT(E)%MODE_SIGN(I)*N(I)
      END DO                                                             ! End of the loop.

      END SUBROUTINE TRACE                                               ! End of the subroutine trace.

      END PROGRAM MUL2_HLE_TESTS                                         ! End of the program mul2 hle tests.
