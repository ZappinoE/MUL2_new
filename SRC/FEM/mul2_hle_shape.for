!=======================================================================
!  HIERARCHICAL LEGENDRE EXPANSION (HLE) FUNCTIONS OF ONE SUB-ELEMENT.
!
!  THE FUNCTIONS ARE THE ONES OF PAGANI, GARCIA DE MIGUEL, CARRERA
!  (COMPUT MECH 2017) AND OF THE P-VERSION FINITE ELEMENT METHOD
!  (SZABO AND BABUSKA): THE TRUNK SPACE OF DEGREE P.
!
!    QUADRILATERAL (NATURAL R,S IN [-1,1], VERTICES 1(-1,-1) 2(1,-1)
!                   3(1,1) 4(-1,1)):
!      VERTEX   1/4 (1+RT R)(1+ST S)                   4 FUNCTIONS
!      SIDE K   1/2 (1-S) PHI_K(R)   SIDE 1 (VERTEX 1 -> 2)
!               1/2 (1+R) PHI_K(S)   SIDE 2 (VERTEX 2 -> 3)
!               1/2 (1+S) PHI_K(R)   SIDE 3 (VERTEX 4 -> 3)
!               1/2 (1-R) PHI_K(S)   SIDE 4 (VERTEX 1 -> 4)
!                                    4 (P-1) FUNCTIONS, K = 2..P
!      INTERNAL PHI_I(R) PHI_J(S), I,J >= 2, I+J <= P
!                                    (P-2)(P-3)/2 FUNCTIONS (P >= 4)
!    LINE (NATURAL R IN [-1,1]):
!      VERTEX 1/2 (1-R), 1/2 (1+R); INTERNAL PHI_K(R), K = 2..P
!
!    PHI_K(X) = SQRT((2K-1)/2) INTEGRAL(-1,X) L_(K-1)   (K >= 2)
!
!  LOCAL ORDER (THE NUMBERING OF THE PAPER): THE VERTICES; THEN, FOR
!  EACH K = 2..P, THE FOUR SIDES OF ORDER K FOLLOWED (K >= 4) BY THE
!  INTERNAL PAIRS (I,J) WITH I+J = K, I DESCENDING.
!=======================================================================
      MODULE MUL2_HLE_SHAPE                                              ! Module mul2 hle shape begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: HLE_VERTEX = 1_I4                ! Constant public integer (int32): hle_vertex = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: HLE_SIDE = 2_I4                  ! Constant public integer (int32): hle_side = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: HLE_INTERNAL = 3_I4              ! Constant public integer (int32): hle_internal = 3.

      PUBLIC :: HLE_FUNCTION_COUNT                                       ! Export: hle function count.
      PUBLIC :: HLE_MODE_LIST                                            ! Export: hle mode list.
      PUBLIC :: HLE_SIDE_ENDS                                            ! Export: hle side ends.
      PUBLIC :: HLE_PHI                                                  ! Export: hle phi.
      PUBLIC :: EVALUATE_HLE_SHAPE                                       ! Export: evaluate hle shape.

      CONTAINS                                                           ! The procedures of the module follow.

      INTEGER(I4) FUNCTION HLE_FUNCTION_COUNT(QUAD, P)                   ! Function hle function count takes quad, p.

      LOGICAL, INTENT(IN) :: QUAD                                        ! Input logical: quad.
      INTEGER(I4), INTENT(IN) :: P                                       ! Input integer (int32): p.

      IF (QUAD) THEN                                                     ! If quad:
        HLE_FUNCTION_COUNT = 4_I4 + 4_I4*(P-1_I4)                        ! Set hle_function_count to 4 + 4*(p-1).
        IF (P .GE. 4_I4) HLE_FUNCTION_COUNT = HLE_FUNCTION_COUNT +       ! If p >= 4, add (p-2)*(p-3)/2 to hle_function_count.
     &                   (P-2_I4)*(P-3_I4)/2_I4
      ELSE                                                               ! Otherwise:
        HLE_FUNCTION_COUNT = P + 1_I4                                    ! Set hle_function_count to p + 1.
      END IF                                                             ! End of the IF block.

      END FUNCTION HLE_FUNCTION_COUNT                                    ! End of the function hle function count.

!  START AND END VERTEX OF A SIDE ALONG ITS NATURAL DIRECTION.
      SUBROUTINE HLE_SIDE_ENDS(SIDE, START, FINISH)                      ! Subroutine hle side ends takes side, start, finish.

      INTEGER(I4), INTENT(IN) :: SIDE                                    ! Input integer (int32): side.
      INTEGER(I4), INTENT(OUT) :: START                                  ! Output integer (int32): start.
      INTEGER(I4), INTENT(OUT) :: FINISH                                 ! Output integer (int32): finish.

      SELECT CASE (SIDE)                                                 ! Choose according to the value of side:
      CASE (1_I4)                                                        ! Case 1:
        START = 1_I4                                                     ! Set start to 1.
        FINISH = 2_I4                                                    ! Set finish to 2.
      CASE (2_I4)                                                        ! Case 2:
        START = 2_I4                                                     ! Set start to 2.
        FINISH = 3_I4                                                    ! Set finish to 3.
      CASE (3_I4)                                                        ! Case 3:
        START = 4_I4                                                     ! Set start to 4.
        FINISH = 3_I4                                                    ! Set finish to 3.
      CASE DEFAULT                                                       ! In every other case:
        START = 1_I4                                                     ! Set start to 1.
        FINISH = 4_I4                                                    ! Set finish to 4.
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE HLE_SIDE_ENDS                                       ! End of the subroutine hle side ends.

!  KIND(L), A(L), B(L) OF EVERY LOCAL FUNCTION:
!    VERTEX    A = VERTEX
!    SIDE      A = SIDE, B = ORDER K
!    INTERNAL  A = I, B = J (QUADRILATERAL); A = K (LINE)
      SUBROUTINE HLE_MODE_LIST(QUAD, P, KIND, A, B)                      ! Subroutine hle mode list takes quad, p, kind, a, b.

      LOGICAL, INTENT(IN) :: QUAD                                        ! Input logical: quad.
      INTEGER(I4), INTENT(IN) :: P                                       ! Input integer (int32): p.
      INTEGER(I4), INTENT(OUT) :: KIND(:)                                ! Output integer (int32): kind(:).
      INTEGER(I4), INTENT(OUT) :: A(:)                                   ! Output integer (int32): a(:).
      INTEGER(I4), INTENT(OUT) :: B(:)                                   ! Output integer (int32): b(:).
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: SIDE                                                ! Integer (int32): side.

      KIND = 0_I4                                                        ! Set kind to zero.
      A = 0_I4                                                           ! Set a to zero.
      B = 0_I4                                                           ! Set b to zero.
      L = 0_I4                                                           ! Set l to zero.
      IF (QUAD) THEN                                                     ! If quad:
        DO I = 1_I4, 4_I4                                                ! Loop i from 1 to 4:
          L = L + 1_I4                                                   ! Add 1 to l.
          KIND(L) = HLE_VERTEX                                           ! Set kind(l) to hle_vertex.
          A(L) = I                                                       ! Set a(l) to i.
        END DO                                                           ! End of the loop.
        DO K = 2_I4, P                                                   ! Loop k from 2 to p:
          DO SIDE = 1_I4, 4_I4                                           ! Loop side from 1 to 4:
            L = L + 1_I4                                                 ! Add 1 to l.
            KIND(L) = HLE_SIDE                                           ! Set kind(l) to hle_side.
            A(L) = SIDE                                                  ! Set a(l) to side.
            B(L) = K                                                     ! Set b(l) to k.
          END DO                                                         ! End of the loop.
          IF (K .LT. 4_I4) CYCLE                                         ! If k < 4, skip to the next iteration.
          DO I = K-2_I4, 2_I4, -1_I4                                     ! Loop i from k-2 to 2 in steps of -1:
            L = L + 1_I4                                                 ! Add 1 to l.
            KIND(L) = HLE_INTERNAL                                       ! Set kind(l) to hle_internal.
            A(L) = I                                                     ! Set a(l) to i.
            B(L) = K - I                                                 ! Set b(l) to k - i.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      ELSE                                                               ! Otherwise:
        DO I = 1_I4, 2_I4                                                ! Loop i from 1 to 2:
          L = L + 1_I4                                                   ! Add 1 to l.
          KIND(L) = HLE_VERTEX                                           ! Set kind(l) to hle_vertex.
          A(L) = I                                                       ! Set a(l) to i.
        END DO                                                           ! End of the loop.
        DO K = 2_I4, P                                                   ! Loop k from 2 to p:
          L = L + 1_I4                                                   ! Add 1 to l.
          KIND(L) = HLE_INTERNAL                                         ! Set kind(l) to hle_internal.
          A(L) = K                                                       ! Set a(l) to k.
        END DO                                                           ! End of the loop.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE HLE_MODE_LIST                                       ! End of the subroutine hle mode list.

!  PHI_K AND ITS DERIVATIVE FOR K = 2..KMAX.
      SUBROUTINE HLE_PHI(KMAX, X, PHI, DPHI)                             ! Subroutine hle phi takes kmax, x, phi, dphi.

      INTEGER(I4), INTENT(IN) :: KMAX                                    ! Input integer (int32): kmax.
      REAL(R8), INTENT(IN) :: X                                          ! Input real (real64): x.
      REAL(R8), INTENT(OUT) :: PHI(:)                                    ! Output real (real64): phi(:).
      REAL(R8), INTENT(OUT) :: DPHI(:)                                   ! Output real (real64): dphi(:).
      REAL(R8) :: L(0:MAX(KMAX,2))                                       ! Real (real64): l(0:max(kmax,2)).
      INTEGER(I4) :: K                                                   ! Integer (int32): k.

      PHI = 0.0_R8                                                       ! Set phi to zero.
      DPHI = 0.0_R8                                                      ! Set dphi to zero.
      IF (KMAX .LT. 2_I4) RETURN                                         ! If kmax < 2, return to the caller.
      L(0) = 1.0_R8                                                      ! Set l(0) to 1.0.
      L(1) = X                                                           ! Set l(1) to x.
      DO K = 2_I4, KMAX                                                  ! Loop k from 2 to kmax:
        L(K) = ((2.0_R8*REAL(K,R8)-1.0_R8)*X*L(K-1_I4) -                 ! Set l(k) to ((2.0*real(k,r8)-1.0)*x*l(k-1) - (real(k,r8)-1.0)*l(k-2))/real(k,r8).
     &          (REAL(K,R8)-1.0_R8)*L(K-2_I4))/REAL(K,R8)
      END DO                                                             ! End of the loop.
      DO K = 2_I4, KMAX                                                  ! Loop k from 2 to kmax:
        PHI(K) = (L(K)-L(K-2_I4))/                                       ! Set phi(k) to (l(k)-l(k-2))/ sqrt(2.0*(2.0*real(k,r8)-1.0)).
     &           SQRT(2.0_R8*(2.0_R8*REAL(K,R8)-1.0_R8))
        DPHI(K) = SQRT((2.0_R8*REAL(K,R8)-1.0_R8)/2.0_R8)*               ! Set dphi(k) to the square root of (2.0*real(k,r8)-1.0)/2.0)* l(k-1.
     &            L(K-1_I4)
      END DO                                                             ! End of the loop.

      END SUBROUTINE HLE_PHI                                             ! End of the subroutine hle phi.

      SUBROUTINE EVALUATE_HLE_SHAPE(QUAD, P, X, N, DN)                   ! Subroutine evaluate hle shape takes quad, p, x, n, dn.

      LOGICAL, INTENT(IN) :: QUAD                                        ! Input logical: quad.
      INTEGER(I4), INTENT(IN) :: P                                       ! Input integer (int32): p.
      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(OUT) :: N(:)                                      ! Output real (real64): n(:).
      REAL(R8), INTENT(OUT) :: DN(:,:)                                   ! Output real (real64): dn(:,:).
      REAL(R8) :: PR(MAX(P,2))                                           ! Real (real64): pr(max(p,2)).
      REAL(R8) :: DPR(MAX(P,2))                                          ! Real (real64): dpr(max(p,2)).
      REAL(R8) :: PS(MAX(P,2))                                           ! Real (real64): ps(max(p,2)).
      REAL(R8) :: DPS(MAX(P,2))                                          ! Real (real64): dps(max(p,2)).
      REAL(R8), PARAMETER :: RV(4) = [-1.0_R8,1.0_R8,1.0_R8,-1.0_R8]     ! Constant real (real64): rv(4) = [-1.0, 1.0, 1.0, -1.0].
      REAL(R8), PARAMETER :: SV(4) = [-1.0_R8,-1.0_R8,1.0_R8,1.0_R8]     ! Constant real (real64): sv(4) = [-1.0, -1.0, 1.0, 1.0].
      REAL(R8) :: R                                                      ! Real (real64): r.
      REAL(R8) :: S                                                      ! Real (real64): s.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: SIDE                                                ! Integer (int32): side.

      N = 0.0_R8                                                         ! Set n to zero.
      DN = 0.0_R8                                                        ! Set dn to zero.
      R = X(1)                                                           ! Set r to x(1).
      CALL HLE_PHI(P, R, PR, DPR)                                        ! Call hle phi with p, r, pr, dpr.
      L = 0_I4                                                           ! Set l to zero.
      IF (.NOT. QUAD) THEN                                               ! If not quad:
        N(1) = 0.5_R8*(1.0_R8-R)                                         ! Set n(1) to 0.5*(1.0-r).
        DN(1,1) = -0.5_R8                                                ! Set dn(1,1) to -0.5.
        N(2) = 0.5_R8*(1.0_R8+R)                                         ! Set n(2) to 0.5*(1.0+r).
        DN(2,1) = 0.5_R8                                                 ! Set dn(2,1) to 0.5.
        L = 2_I4                                                         ! Set l to 2.
        DO K = 2_I4, P                                                   ! Loop k from 2 to p:
          L = L + 1_I4                                                   ! Add 1 to l.
          N(L) = PR(K)                                                   ! Set n(l) to pr(k).
          DN(L,1) = DPR(K)                                               ! Set dn(l,1) to dpr(k).
        END DO                                                           ! End of the loop.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      S = X(2)                                                           ! Set s to x(2).
      CALL HLE_PHI(P, S, PS, DPS)                                        ! Call hle phi with p, s, ps, dps.
      DO I = 1_I4, 4_I4                                                  ! Loop i from 1 to 4:
        L = L + 1_I4                                                     ! Add 1 to l.
        N(L) = 0.25_R8*(1.0_R8+RV(I)*R)*(1.0_R8+SV(I)*S)                 ! Set n(l) to 0.25*(1.0+rv(i)*r)*(1.0+sv(i)*s).
        DN(L,1) = 0.25_R8*RV(I)*(1.0_R8+SV(I)*S)                         ! Set dn(l,1) to 0.25*rv(i)*(1.0+sv(i)*s).
        DN(L,2) = 0.25_R8*SV(I)*(1.0_R8+RV(I)*R)                         ! Set dn(l,2) to 0.25*sv(i)*(1.0+rv(i)*r).
      END DO                                                             ! End of the loop.
      DO K = 2_I4, P                                                     ! Loop k from 2 to p:
        DO SIDE = 1_I4, 4_I4                                             ! Loop side from 1 to 4:
          L = L + 1_I4                                                   ! Add 1 to l.
          SELECT CASE (SIDE)                                             ! Choose according to the value of side:
          CASE (1_I4)                                                    ! Case 1:
            N(L) = 0.5_R8*(1.0_R8-S)*PR(K)                               ! Set n(l) to 0.5*(1.0-s)*pr(k).
            DN(L,1) = 0.5_R8*(1.0_R8-S)*DPR(K)                           ! Set dn(l,1) to 0.5*(1.0-s)*dpr(k).
            DN(L,2) = -0.5_R8*PR(K)                                      ! Set dn(l,2) to -0.5*pr(k).
          CASE (2_I4)                                                    ! Case 2:
            N(L) = 0.5_R8*(1.0_R8+R)*PS(K)                               ! Set n(l) to 0.5*(1.0+r)*ps(k).
            DN(L,1) = 0.5_R8*PS(K)                                       ! Set dn(l,1) to 0.5*ps(k).
            DN(L,2) = 0.5_R8*(1.0_R8+R)*DPS(K)                           ! Set dn(l,2) to 0.5*(1.0+r)*dps(k).
          CASE (3_I4)                                                    ! Case 3:
            N(L) = 0.5_R8*(1.0_R8+S)*PR(K)                               ! Set n(l) to 0.5*(1.0+s)*pr(k).
            DN(L,1) = 0.5_R8*(1.0_R8+S)*DPR(K)                           ! Set dn(l,1) to 0.5*(1.0+s)*dpr(k).
            DN(L,2) = 0.5_R8*PR(K)                                       ! Set dn(l,2) to 0.5*pr(k).
          CASE DEFAULT                                                   ! In every other case:
            N(L) = 0.5_R8*(1.0_R8-R)*PS(K)                               ! Set n(l) to 0.5*(1.0-r)*ps(k).
            DN(L,1) = -0.5_R8*PS(K)                                      ! Set dn(l,1) to -0.5*ps(k).
            DN(L,2) = 0.5_R8*(1.0_R8-R)*DPS(K)                           ! Set dn(l,2) to 0.5*(1.0-r)*dps(k).
          END SELECT                                                     ! End of the case selection.
        END DO                                                           ! End of the loop.
        IF (K .LT. 4_I4) CYCLE                                           ! If k < 4, skip to the next iteration.
        DO I = K-2_I4, 2_I4, -1_I4                                       ! Loop i from k-2 to 2 in steps of -1:
          J = K - I                                                      ! Set j to k - i.
          L = L + 1_I4                                                   ! Add 1 to l.
          N(L) = PR(I)*PS(J)                                             ! Set n(l) to pr(i)*ps(j).
          DN(L,1) = DPR(I)*PS(J)                                         ! Set dn(l,1) to dpr(i)*ps(j).
          DN(L,2) = PR(I)*DPS(J)                                         ! Set dn(l,2) to pr(i)*dps(j).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_HLE_SHAPE                                  ! End of the subroutine evaluate hle shape.

      END MODULE MUL2_HLE_SHAPE                                          ! End of the module mul2 hle shape.
