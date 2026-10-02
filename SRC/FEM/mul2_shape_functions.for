!=======================================================================
!  SHAPE FUNCTIONS AND NATURAL DERIVATIVES.
!=======================================================================
      MODULE MUL2_SHAPE_FUNCTIONS                                        ! Module mul2 shape functions begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_TOPOLOGIES                                                ! Use everything exported by module mul2 topologies.
      USE MUL2_HLE_SHAPE, ONLY: EVALUATE_HLE_SHAPE                       ! Use from module mul2 hle shape: evaluate hle shape.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: EVALUATE_SHAPE                                           ! Export: evaluate shape.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE EVALUATE_SHAPE(TOPOLOGY, NATURAL, N,                    ! Subroutine evaluate shape takes topology, natural, n, dn dnatural, status.
     &                          DN_DNATURAL, STATUS)

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      REAL(R8), INTENT(IN) :: NATURAL(:)                                 ! Input real (real64): natural(:).
      REAL(R8), INTENT(OUT) :: N(:)                                      ! Output real (real64): n(:).
      REAL(R8), INTENT(OUT) :: DN_DNATURAL(:,:)                          ! Output real (real64): dn_dnatural(:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: N_DIMENSION                                         ! Integer (int32): n_dimension.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N = 0.0_R8                                                         ! Set n to zero.
      DN_DNATURAL = 0.0_R8                                               ! Set dn_dnatural to zero.
      N_NODE = TOPOLOGY_FUNCTION_COUNT(TOPOLOGY)                         ! Set n_node to topology_function_count(topology).
      N_DIMENSION = TOPOLOGY_NATURAL_DIMENSION(TOPOLOGY)                 ! Set n_dimension to topology_natural_dimension(topology).
      IF (N_NODE .EQ. 0_I4) THEN                                         ! If n_node = 0:
        CALL SET_ERROR(STATUS, 'EVALUATE_SHAPE',                         ! Record an error in status: 'UNKNOWN TOPOLOGY'.
     &                 'UNKNOWN TOPOLOGY')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (SIZE(N) .LT. N_NODE .OR.                                       ! If size(n) < n_node or size(dn_dnatural,1) < n_node or size(dn_dnatural,2) < max(1,n_dimension) or size(nat...
     &    SIZE(DN_DNATURAL,1) .LT. N_NODE .OR.
     &    SIZE(DN_DNATURAL,2) .LT. MAX(1_I4,N_DIMENSION) .OR.
     &    SIZE(NATURAL) .LT. N_DIMENSION) THEN
        CALL SET_ERROR(STATUS, 'EVALUATE_SHAPE',                         ! Record an error in status: 'SHAPE WORKSPACE IS TOO SMALL'.
     &                 'SHAPE WORKSPACE IS TOO SMALL')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_S1)                                                 ! Case topology_s1:
        N(1) = 1.0_R8                                                    ! Set n(1) to 1.0.
      CASE (TOPOLOGY_B2)                                                 ! Case topology_b2:
        CALL SHAPE_B(1_I4, 2_I4, NATURAL(1), N,                          ! Call shape b with 1, 2, natural(1), n, dn_dnatural.
     &               DN_DNATURAL)
      CASE (TOPOLOGY_B3)                                                 ! Case topology_b3:
        CALL SHAPE_B(2_I4, 3_I4, NATURAL(1), N,                          ! Call shape b with 2, 3, natural(1), n, dn_dnatural.
     &               DN_DNATURAL)
      CASE (TOPOLOGY_B4)                                                 ! Case topology_b4:
        CALL SHAPE_B(3_I4, 4_I4, NATURAL(1), N,                          ! Call shape b with 3, 4, natural(1), n, dn_dnatural.
     &               DN_DNATURAL)
      CASE (TOPOLOGY_Q4)                                                 ! Case topology_q4:
        CALL SHAPE_Q4(NATURAL, N, DN_DNATURAL)                           ! Call shape q4 with natural, n, dn_dnatural.
      CASE (TOPOLOGY_Q9)                                                 ! Case topology_q9:
        CALL SHAPE_Q9(NATURAL, N, DN_DNATURAL)                           ! Call shape q9 with natural, n, dn_dnatural.
      CASE (TOPOLOGY_Q16)                                                ! Case topology_q16:
        CALL SHAPE_Q16(NATURAL, N, DN_DNATURAL)                          ! Call shape q16 with natural, n, dn_dnatural.
      CASE (TOPOLOGY_T3)                                                 ! Case topology_t3:
        CALL SHAPE_T3(NATURAL, N, DN_DNATURAL)                           ! Call shape t3 with natural, n, dn_dnatural.
      CASE (TOPOLOGY_T6)                                                 ! Case topology_t6:
        CALL SHAPE_T6(NATURAL, N, DN_DNATURAL)                           ! Call shape t6 with natural, n, dn_dnatural.
      CASE (TOPOLOGY_H8)                                                 ! Case topology_h8:
        CALL SHAPE_H8(NATURAL, N, DN_DNATURAL)                           ! Call shape h8 with natural, n, dn_dnatural.
      CASE (TOPOLOGY_H27)                                                ! Case topology_h27:
        CALL SHAPE_H27(NATURAL, N, DN_DNATURAL)                          ! Call shape h27 with natural, n, dn_dnatural.
      CASE (TOPOLOGY_HB_BASE+1_I4:TOPOLOGY_HB_BASE+99_I4)                ! Case topology_hb_base+1:topology_hb_base+99:
        CALL EVALUATE_HLE_SHAPE(.FALSE., TOPOLOGY_HLE_ORDER(TOPOLOGY),   ! Call evaluate hle shape with false, topology_hle_order(topology), natural, n, dn_dnatural.
     &                          NATURAL, N, DN_DNATURAL)
      CASE (TOPOLOGY_HQ_BASE+1_I4:TOPOLOGY_HQ_BASE+99_I4)                ! Case topology_hq_base+1:topology_hq_base+99:
        CALL EVALUATE_HLE_SHAPE(.TRUE., TOPOLOGY_HLE_ORDER(TOPOLOGY),    ! Call evaluate hle shape with true, topology_hle_order(topology), natural, n, dn_dnatural.
     &                          NATURAL, N, DN_DNATURAL)
      CASE DEFAULT                                                       ! In every other case:
        CALL SET_ERROR(STATUS, 'EVALUATE_SHAPE',                         ! Record an error in status: 'TOPOLOGY SHAPE IS NOT IMPLEMENTED YET'.
     &                 'TOPOLOGY SHAPE IS NOT IMPLEMENTED YET')
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE EVALUATE_SHAPE                                      ! End of the subroutine evaluate shape.

      SUBROUTINE SHAPE_B(ORDER, N_NODE, XI, N, DN)                       ! Subroutine shape b takes order, n node, xi, n, dn.

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(IN) :: N_NODE                                  ! Input integer (int32): n_node.
      REAL(R8), INTENT(IN) :: XI                                         ! Input real (real64): xi.
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      DO I = 1_I4, N_NODE                                                ! Loop i from 1 to n_node:
        CALL LAGRANGE_1D(ORDER, I, XI, N(I), DN(I,1))                    ! Call lagrange 1d with order, i, xi, n(i), dn(i,1).
      END DO                                                             ! End of the loop.

      END SUBROUTINE SHAPE_B                                             ! End of the subroutine shape b.

      SUBROUTINE SHAPE_Q4(X, N, DN)                                      ! Subroutine shape q4 takes x, n, dn.

      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      INTEGER(I4), PARAMETER :: IX(4) = [1,2,2,1]                        ! Constant integer (int32): ix(4) = [1, 2, 2, 1].
      INTEGER(I4), PARAMETER :: IY(4) = [1,1,2,2]                        ! Constant integer (int32): iy(4) = [1, 1, 2, 2].

      CALL TENSOR_2D(1_I4, 4_I4, IX, IY, X, N, DN)                       ! Call tensor 2d with 1, 4, ix, iy, x, n, dn.

      END SUBROUTINE SHAPE_Q4                                            ! End of the subroutine shape q4.

      SUBROUTINE SHAPE_Q9(X, N, DN)                                      ! Subroutine shape q9 takes x, n, dn.

      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      INTEGER(I4), PARAMETER :: IX(9) =                                  ! Constant integer (int32): ix(9) = [1, 2, 3, 3, 3, 2, 1, 1, 2].
     &  [1,2,3,3,3,2,1,1,2]
      INTEGER(I4), PARAMETER :: IY(9) =                                  ! Constant integer (int32): iy(9) = [1, 1, 1, 2, 3, 3, 3, 2, 2].
     &  [1,1,1,2,3,3,3,2,2]

      CALL TENSOR_2D(2_I4, 9_I4, IX, IY, X, N, DN)                       ! Call tensor 2d with 2, 9, ix, iy, x, n, dn.

      END SUBROUTINE SHAPE_Q9                                            ! End of the subroutine shape q9.

      SUBROUTINE SHAPE_Q16(X, N, DN)                                     ! Subroutine shape q16 takes x, n, dn.

      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      INTEGER(I4), PARAMETER :: IX(16) =                                 ! Constant integer (int32): ix(16) = [1, 2, 3, 4, 4, 4, 4, 3, 2, 1, 1, 1, 2, 3, 3, 2].
     &  [1,2,3,4,4,4,4,3,2,1,1,1,2,3,3,2]
      INTEGER(I4), PARAMETER :: IY(16) =                                 ! Constant integer (int32): iy(16) = [1, 1, 1, 1, 2, 3, 4, 4, 4, 4, 3, 2, 2, 2, 3, 3].
     &  [1,1,1,1,2,3,4,4,4,4,3,2,2,2,3,3]

      CALL TENSOR_2D(3_I4, 16_I4, IX, IY, X, N, DN)                      ! Call tensor 2d with 3, 16, ix, iy, x, n, dn.

      END SUBROUTINE SHAPE_Q16                                           ! End of the subroutine shape q16.

      SUBROUTINE SHAPE_T3(X, N, DN)                                      ! Subroutine shape t3 takes x, n, dn.

      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).

      N(1) = 1.0_R8 - X(1) - X(2)                                        ! Set n(1) to 1.0 - x(1) - x(2).
      N(2) = X(1)                                                        ! Set n(2) to x(1).
      N(3) = X(2)                                                        ! Set n(3) to x(2).
      DN(1,1) = -1.0_R8                                                  ! Set dn(1,1) to -1.0.
      DN(1,2) = -1.0_R8                                                  ! Set dn(1,2) to -1.0.
      DN(2,1) = 1.0_R8                                                   ! Set dn(2,1) to 1.0.
      DN(3,2) = 1.0_R8                                                   ! Set dn(3,2) to 1.0.

      END SUBROUTINE SHAPE_T3                                            ! End of the subroutine shape t3.

      SUBROUTINE SHAPE_T6(X, N, DN)                                      ! Subroutine shape t6 takes x, n, dn.

      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      REAL(R8) :: L1                                                     ! Real (real64): l1.
      REAL(R8) :: L2                                                     ! Real (real64): l2.
      REAL(R8) :: L3                                                     ! Real (real64): l3.

      L1 = 1.0_R8 - X(1) - X(2)                                          ! Set l1 to 1.0 - x(1) - x(2).
      L2 = X(1)                                                          ! Set l2 to x(1).
      L3 = X(2)                                                          ! Set l3 to x(2).
      N(1) = L1*(2.0_R8*L1 - 1.0_R8)                                     ! Set n(1) to l1*(2.0*l1 - 1.0).
      N(2) = L2*(2.0_R8*L2 - 1.0_R8)                                     ! Set n(2) to l2*(2.0*l2 - 1.0).
      N(3) = L3*(2.0_R8*L3 - 1.0_R8)                                     ! Set n(3) to l3*(2.0*l3 - 1.0).
      N(4) = 4.0_R8*L1*L2                                                ! Set n(4) to 4.0*l1*l2.
      N(5) = 4.0_R8*L2*L3                                                ! Set n(5) to 4.0*l2*l3.
      N(6) = 4.0_R8*L3*L1                                                ! Set n(6) to 4.0*l3*l1.
      DN(1,1:2) = 1.0_R8 - 4.0_R8*L1                                     ! Set dn(1,1:2) to 1.0 - 4.0*l1.
      DN(2,1) = 4.0_R8*L2 - 1.0_R8                                       ! Set dn(2,1) to 4.0*l2 - 1.0.
      DN(3,2) = 4.0_R8*L3 - 1.0_R8                                       ! Set dn(3,2) to 4.0*l3 - 1.0.
      DN(4,1) = 4.0_R8*(L1-L2)                                           ! Set dn(4,1) to 4.0*(l1-l2).
      DN(4,2) = -4.0_R8*L2                                               ! Set dn(4,2) to -4.0*l2.
      DN(5,1) = 4.0_R8*L3                                                ! Set dn(5,1) to 4.0*l3.
      DN(5,2) = 4.0_R8*L2                                                ! Set dn(5,2) to 4.0*l2.
      DN(6,1) = -4.0_R8*L3                                               ! Set dn(6,1) to -4.0*l3.
      DN(6,2) = 4.0_R8*(L1-L3)                                           ! Set dn(6,2) to 4.0*(l1-l3).

      END SUBROUTINE SHAPE_T6                                            ! End of the subroutine shape t6.

      SUBROUTINE SHAPE_H8(X, N, DN)                                      ! Subroutine shape h8 takes x, n, dn.

      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      INTEGER(I4), PARAMETER :: IX(8) = [1,2,2,1,1,2,2,1]                ! Constant integer (int32): ix(8) = [1, 2, 2, 1, 1, 2, 2, 1].
      INTEGER(I4), PARAMETER :: IY(8) = [1,1,2,2,1,1,2,2]                ! Constant integer (int32): iy(8) = [1, 1, 2, 2, 1, 1, 2, 2].
      INTEGER(I4), PARAMETER :: IZ(8) = [1,1,1,1,2,2,2,2]                ! Constant integer (int32): iz(8) = [1, 1, 1, 1, 2, 2, 2, 2].

      CALL TENSOR_3D(1_I4, 8_I4, IX, IY, IZ, X, N, DN)                   ! Call tensor 3d with 1, 8, ix, iy, iz, x, n, dn.

      END SUBROUTINE SHAPE_H8                                            ! End of the subroutine shape h8.

      SUBROUTINE SHAPE_H27(X, N, DN)                                     ! Subroutine shape h27 takes x, n, dn.

      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      INTEGER(I4), PARAMETER :: IX(27) =                                 ! Constant integer (int32): ix(27) = [1, 3, 3, 1, 1, 3, 3, 1, 2, 1, 1, 3, 3, 2, 3, 1, 2, 1, 3, 2, 2, 2, 1, 3,...
     & [1,3,3,1,1,3,3,1,2,1,1,3,3,2,3,1,2,1,3,2,2,2,1,3,2,2,2]
      INTEGER(I4), PARAMETER :: IY(27) =                                 ! Constant integer (int32): iy(27) = [1, 1, 3, 3, 1, 1, 3, 3, 1, 2, 1, 2, 1, 3, 3, 3, 1, 2, 2, 3, 2, 1, 2, 2,...
     & [1,1,3,3,1,1,3,3,1,2,1,2,1,3,3,3,1,2,2,3,2,1,2,2,3,2,2]
      INTEGER(I4), PARAMETER :: IZ(27) =                                 ! Constant integer (int32): iz(27) = [1, 1, 1, 1, 3, 3, 3, 3, 1, 1, 2, 1, 2, 1, 2, 2, 3, 3, 3, 3, 1, 2, 2, 2,...
     & [1,1,1,1,3,3,3,3,1,1,2,1,2,1,2,2,3,3,3,3,1,2,2,2,2,3,2]

      CALL TENSOR_3D(2_I4, 27_I4, IX, IY, IZ, X, N, DN)                  ! Call tensor 3d with 2, 27, ix, iy, iz, x, n, dn.

      END SUBROUTINE SHAPE_H27                                           ! End of the subroutine shape h27.

      SUBROUTINE TENSOR_2D(ORDER, N_NODE, IX, IY, X, N, DN)              ! Subroutine tensor 2d takes order, n node, ix, iy, x, n, dn.

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(IN) :: N_NODE                                  ! Input integer (int32): n_node.
      INTEGER(I4), INTENT(IN) :: IX(N_NODE)                              ! Input integer (int32): ix(n_node).
      INTEGER(I4), INTENT(IN) :: IY(N_NODE)                              ! Input integer (int32): iy(n_node).
      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      REAL(R8) :: LX                                                     ! Real (real64): lx.
      REAL(R8) :: LY                                                     ! Real (real64): ly.
      REAL(R8) :: DLX                                                    ! Real (real64): dlx.
      REAL(R8) :: DLY                                                    ! Real (real64): dly.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      DO I = 1_I4, N_NODE                                                ! Loop i from 1 to n_node:
        CALL LAGRANGE_1D(ORDER, IX(I), X(1), LX, DLX)                    ! Call lagrange 1d with order, ix(i), x(1), lx, dlx.
        CALL LAGRANGE_1D(ORDER, IY(I), X(2), LY, DLY)                    ! Call lagrange 1d with order, iy(i), x(2), ly, dly.
        N(I) = LX*LY                                                     ! Set n(i) to lx*ly.
        DN(I,1) = DLX*LY                                                 ! Set dn(i,1) to dlx*ly.
        DN(I,2) = LX*DLY                                                 ! Set dn(i,2) to lx*dly.
      END DO                                                             ! End of the loop.

      END SUBROUTINE TENSOR_2D                                           ! End of the subroutine tensor 2d.

      SUBROUTINE TENSOR_3D(ORDER, N_NODE, IX, IY, IZ,                    ! Subroutine tensor 3d takes order, n node, ix, iy, iz, x, n, dn.
     &                     X, N, DN)

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(IN) :: N_NODE                                  ! Input integer (int32): n_node.
      INTEGER(I4), INTENT(IN) :: IX(N_NODE)                              ! Input integer (int32): ix(n_node).
      INTEGER(I4), INTENT(IN) :: IY(N_NODE)                              ! Input integer (int32): iy(n_node).
      INTEGER(I4), INTENT(IN) :: IZ(N_NODE)                              ! Input integer (int32): iz(n_node).
      REAL(R8), INTENT(IN) :: X(:)                                       ! Input real (real64): x(:).
      REAL(R8), INTENT(INOUT) :: N(:)                                    ! In/out real (real64): n(:).
      REAL(R8), INTENT(INOUT) :: DN(:,:)                                 ! In/out real (real64): dn(:,:).
      REAL(R8) :: LX                                                     ! Real (real64): lx.
      REAL(R8) :: LY                                                     ! Real (real64): ly.
      REAL(R8) :: LZ                                                     ! Real (real64): lz.
      REAL(R8) :: DLX                                                    ! Real (real64): dlx.
      REAL(R8) :: DLY                                                    ! Real (real64): dly.
      REAL(R8) :: DLZ                                                    ! Real (real64): dlz.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      DO I = 1_I4, N_NODE                                                ! Loop i from 1 to n_node:
        CALL LAGRANGE_1D(ORDER, IX(I), X(1), LX, DLX)                    ! Call lagrange 1d with order, ix(i), x(1), lx, dlx.
        CALL LAGRANGE_1D(ORDER, IY(I), X(2), LY, DLY)                    ! Call lagrange 1d with order, iy(i), x(2), ly, dly.
        CALL LAGRANGE_1D(ORDER, IZ(I), X(3), LZ, DLZ)                    ! Call lagrange 1d with order, iz(i), x(3), lz, dlz.
        N(I) = LX*LY*LZ                                                  ! Set n(i) to lx*ly*lz.
        DN(I,1) = DLX*LY*LZ                                              ! Set dn(i,1) to dlx*ly*lz.
        DN(I,2) = LX*DLY*LZ                                              ! Set dn(i,2) to lx*dly*lz.
        DN(I,3) = LX*LY*DLZ                                              ! Set dn(i,3) to lx*ly*dlz.
      END DO                                                             ! End of the loop.

      END SUBROUTINE TENSOR_3D                                           ! End of the subroutine tensor 3d.

      SUBROUTINE LAGRANGE_1D(ORDER, INDEX, X, VALUE, DERIVATIVE)         ! Subroutine lagrange 1d takes order, index, x, value, derivative.

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(IN) :: INDEX                                   ! Input integer (int32): index.
      REAL(R8), INTENT(IN) :: X                                          ! Input real (real64): x.
      REAL(R8), INTENT(OUT) :: VALUE                                     ! Output real (real64): value.
      REAL(R8), INTENT(OUT) :: DERIVATIVE                                ! Output real (real64): derivative.
      REAL(R8) :: GRID(4)                                                ! Real (real64): grid(4).
      REAL(R8) :: PRODUCT                                                ! Real (real64): product.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      GRID = 0.0_R8                                                      ! Set grid to zero.
      SELECT CASE (ORDER)                                                ! Choose according to the value of order:
      CASE (1_I4)                                                        ! Case 1:
        GRID(1:2) = [-1.0_R8,1.0_R8]                                     ! Set grid(1:2) to [-1.0,1.0].
      CASE (2_I4)                                                        ! Case 2:
        GRID(1:3) = [-1.0_R8,0.0_R8,1.0_R8]                              ! Set grid(1:3) to [-1.0,0.0,1.0].
      CASE (3_I4)                                                        ! Case 3:
        GRID(1:4) = [-1.0_R8,-1.0_R8/3.0_R8,                             ! Set grid(1:4) to [-1.0,-1.0/3.0, 1.0/3.0,1.0].
     &                1.0_R8/3.0_R8,1.0_R8]
      END SELECT                                                         ! End of the case selection.

      VALUE = 1.0_R8                                                     ! Set value to 1.0.
      DO J = 1_I4, ORDER + 1_I4                                          ! Loop j from 1 to order + 1:
        IF (J .NE. INDEX) VALUE = VALUE*(X-GRID(J))/                     ! If j /= index, multiply value by (x-grid(j))/ (grid(index)-grid(j)).
     &                    (GRID(INDEX)-GRID(J))
      END DO                                                             ! End of the loop.
      DERIVATIVE = 0.0_R8                                                ! Set derivative to zero.
      DO I = 1_I4, ORDER + 1_I4                                          ! Loop i from 1 to order + 1:
        IF (I .EQ. INDEX) CYCLE                                          ! If i = index, skip to the next iteration.
        PRODUCT = 1.0_R8/(GRID(INDEX)-GRID(I))                           ! Set product to 1.0/(grid(index)-grid(i)).
        DO J = 1_I4, ORDER + 1_I4                                        ! Loop j from 1 to order + 1:
          IF (J .NE. INDEX .AND. J .NE. I) THEN                          ! If j /= index and j /= i:
            PRODUCT = PRODUCT*(X-GRID(J))/                               ! Multiply product by (x-grid(j))/ (grid(index)-grid(j)).
     &                (GRID(INDEX)-GRID(J))
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        DERIVATIVE = DERIVATIVE + PRODUCT                                ! Add product to derivative.
      END DO                                                             ! End of the loop.

      END SUBROUTINE LAGRANGE_1D                                         ! End of the subroutine lagrange 1d.

      END MODULE MUL2_SHAPE_FUNCTIONS                                    ! End of the module mul2 shape functions.
