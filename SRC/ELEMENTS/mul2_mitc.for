!=======================================================================
!  MITC SHEAR-LOCKING CORRECTION BY ASSUMED STRAIN ROWS.
!
!  A TIED STRAIN ROW OF THE B OPERATOR IS NOT EVALUATED AT THE
!  QUADRATURE POINT BUT INTERPOLATED FROM ITS VALUES AT THE TYING
!  POINTS OF A TYING SET (TENSOR LAGRANGE INTERPOLATION):
!
!      B_R(XI) = SUM_L M_L(XI) B_R(XI_L)
!
!  THE SAME EXPANSION POINT IS USED AT THE TYING POINTS, SO THE
!  CORRECTION ACTS ON THE FEM DIRECTIONS ONLY. THE TABLE REPRODUCES THE
!  BASELINE (PHYSICAL STRAIN COMPONENTS, A=1/SQRT(3), B=SQRT(3/5)):
!
!    ELEMENT  ROW(S)   TYING POINTS (XI x ETA x ZETA)
!    B2       5,6      {0}
!    B3       5,6      {-A,A}
!    B4       5,6      {-B,0,B}
!    Q4       4        {0} x {1,-1}
!             5        {1,-1} x {0}
!    Q9       1,4      {-A,A} x {-B,0,B}
!             2,5      {-B,0,B} x {-A,A}
!             6        {-A,A} x {-A,A}
!    H8       4,5,6    {0} x {0} x {0}
!    H27      4,5,6    {-A,A} x {-A,A} x {-A,A}
!=======================================================================
      MODULE MUL2_MITC                                                   ! Module mul2 mitc begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       STATUS_IS_OK
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_B2, TOPOLOGY_B3,               ! Use from module mul2 topologies: topology b2, topology b3, topology b4, topology q4, topology q9, topology ...
     &     TOPOLOGY_B4, TOPOLOGY_Q4, TOPOLOGY_Q9, TOPOLOGY_H8,
     &     TOPOLOGY_H20, TOPOLOGY_H27, TOPOLOGY_NODE_COUNT,
     &     TOPOLOGY_NATURAL_DIMENSION
      USE MUL2_LOCAL_GRADIENTS, ONLY: EVALUATE_SHAPE_AND_GRADIENT        ! Use from module mul2 local gradients: evaluate shape and gradient.
      USE MUL2_LINEAR_KINEMATICS, ONLY: BUILD_DISPLACEMENT_OPERATOR      ! Use from module mul2 linear kinematics: build displacement operator.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER :: MAX_SET = 3_I4                           ! Constant integer (int32): max_set = 3.
      INTEGER(I4), PARAMETER :: MAX_POINT = 8_I4                         ! Constant integer (int32): max_point = 8.

!  POINTS OF ONE TYING SET: THE TENSOR PRODUCT OF ONE LIST PER DIRECTION.
      TYPE, PUBLIC :: TYING_SET_TYPE                                     ! Definition of the derived type tying set type.
        INTEGER(I4) :: COUNT_1D(3) = 1_I4                                ! Integer (int32): count_1d(3) = 1.
        REAL(R8) :: COORDINATE_1D(3,3) = 0.0_R8                          ! Real (real64): coordinate_1d(3,3) = 0.0.
      END TYPE TYING_SET_TYPE                                            ! End of the type definition tying set type.

      TYPE, PUBLIC :: MITC_DATA_TYPE                                     ! Definition of the derived type mitc data type.
        LOGICAL :: ACTIVE = .FALSE.                                      ! Logical: active = false.
        INTEGER(I4) :: SET_COUNT = 0_I4                                  ! Integer (int32): set_count = 0.
        INTEGER(I4) :: ROW_SET(6) = 0_I4                                 ! Integer (int32): row_set(6) = 0.
        TYPE(TYING_SET_TYPE) :: SET(MAX_SET)                             ! Of type tying_set_type: set(max_set).
        REAL(R8), ALLOCATABLE :: SHAPE(:,:,:)                            ! Allocatable real (real64): shape(:,:,:).
        REAL(R8), ALLOCATABLE :: GRADIENT(:,:,:,:)                       ! Allocatable real (real64): gradient(:,:,:,:).
      END TYPE MITC_DATA_TYPE                                            ! End of the type definition mitc data type.

      PUBLIC :: MITC_IS_AVAILABLE                                        ! Export: mitc is available.
      PUBLIC :: MITC_PREPARE_ELEMENT                                     ! Export: mitc prepare element.
      PUBLIC :: MITC_TIE_COLUMN                                          ! Export: mitc tie column.
      PUBLIC :: INTERPOLATION_WEIGHT                                     ! Export: interpolation weight.

      CONTAINS                                                           ! The procedures of the module follow.

      LOGICAL FUNCTION MITC_IS_AVAILABLE(TOPOLOGY)                       ! Function mitc is available takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      SELECT CASE(TOPOLOGY)                                              ! Choose according to the value of topology:
      CASE(TOPOLOGY_B2, TOPOLOGY_B3, TOPOLOGY_B4, TOPOLOGY_Q4,           ! Case topology_b2, topology_b3, topology_b4, topology_q4, topology_q9, topology_h8, topology_h20, topology_h27:
     &     TOPOLOGY_Q9, TOPOLOGY_H8, TOPOLOGY_H20, TOPOLOGY_H27)
        MITC_IS_AVAILABLE = .TRUE.                                       ! Set the flag mitc_is_available to true.
      CASE DEFAULT                                                       ! In every other case:
        MITC_IS_AVAILABLE = .FALSE.                                      ! Set the flag mitc_is_available to false.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION MITC_IS_AVAILABLE                                     ! End of the function mitc is available.

!  TYING TABLE OF A TOPOLOGY AND THE SHAPES/GRADIENTS AT ITS POINTS.
!  NODE_LOCAL(:,I) IS THE LOCAL COORDINATE OF ELEMENT NODE I.
      SUBROUTINE MITC_PREPARE_ELEMENT(TOPOLOGY, NODE_LOCAL, DATA,        ! Subroutine mitc prepare element takes topology, node local, data, status.
     &                                STATUS)

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      REAL(R8), INTENT(IN) :: NODE_LOCAL(:,:)                            ! Input real (real64): node_local(:,:).
      TYPE(MITC_DATA_TYPE), INTENT(INOUT) :: DATA                        ! In/out of type mitc_data_type: data.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: NATURAL(3)                                             ! Real (real64): natural(3).
      REAL(R8) :: POINT_COORDINATE(3)                                    ! Real (real64): point_coordinate(3).
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: S                                                   ! Integer (int32): s.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: N_POINT                                             ! Integer (int32): n_point.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL MITC_CLEAR(DATA)                                              ! Call mitc clear with data.
      IF (.NOT. MITC_IS_AVAILABLE(TOPOLOGY)) THEN                        ! If not mitc_is_available(topology):
        CALL SET_ERROR(STATUS, 'MITC_PREPARE_ELEMENT',                   ! Record an error in status: 'MITC IS NOT DEFINED FOR THIS TOPOLOGY'.
     &                 'MITC IS NOT DEFINED FOR THIS TOPOLOGY')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL DEFINE_TYING(TOPOLOGY, DATA)                                  ! Call define tying with topology, data.
      N_NODE = TOPOLOGY_NODE_COUNT(TOPOLOGY)                             ! Set n_node to topology_node_count(topology).
      ALLOCATE(DATA%SHAPE(N_NODE,MAX_POINT,DATA%SET_COUNT))              ! Allocate memory for data.shape(n_node,max_point,data.set_count).
      ALLOCATE(DATA%GRADIENT(3,N_NODE,MAX_POINT,DATA%SET_COUNT))         ! Allocate memory for data.gradient(3,n_node,max_point,data.set_count).
      DATA%SHAPE = 0.0_R8                                                ! Declaration: data.shape = 0.0.
      DATA%GRADIENT = 0.0_R8                                             ! Declaration: data.gradient = 0.0.
      DO S = 1_I4, DATA%SET_COUNT                                        ! Loop s from 1 to data.set_count:
        N_POINT = PRODUCT(DATA%SET(S)%COUNT_1D)                          ! Set n_point to product(data.set(s).count_1d).
        DO L = 1_I4, N_POINT                                             ! Loop l from 1 to n_point:
          CALL POINT_OF_SET(DATA%SET(S), L, POINT_COORDINATE)            ! Call point of set with data.set(s), l, point_coordinate.
          NATURAL = POINT_COORDINATE                                     ! Set natural to point_coordinate.
          CALL EVALUATE_SHAPE_AND_GRADIENT(TOPOLOGY, NODE_LOCAL,         ! Call evaluate shape and gradient with topology, node_local, natural, data.shape(1:n_node,l,s), data.gradien...
     &         NATURAL, DATA%SHAPE(1:N_NODE,L,S),
     &         DATA%GRADIENT(:,1:N_NODE,L,S), STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      DATA%ACTIVE = .TRUE.                                               ! Declaration: data.active = true.

      END SUBROUTINE MITC_PREPARE_ELEMENT                                ! End of the subroutine mitc prepare element.

      SUBROUTINE MITC_CLEAR(DATA)                                        ! Subroutine mitc clear takes data.

      TYPE(MITC_DATA_TYPE), INTENT(INOUT) :: DATA                        ! In/out of type mitc_data_type: data.

      IF (ALLOCATED(DATA%SHAPE)) DEALLOCATE(DATA%SHAPE)                  ! If allocated(data.shape), free the memory of data.shape.
      IF (ALLOCATED(DATA%GRADIENT)) DEALLOCATE(DATA%GRADIENT)            ! If allocated(data.gradient), free the memory of data.gradient.
      DATA%ACTIVE = .FALSE.                                              ! Declaration: data.active = false.
      DATA%SET_COUNT = 0_I4                                              ! Declaration: data.set_count = 0.
      DATA%ROW_SET = 0_I4                                                ! Declaration: data.row_set = 0.
      DATA%SET = TYING_SET_TYPE()                                        ! Declaration: data.set = tying_set_type().

      END SUBROUTINE MITC_CLEAR                                          ! End of the subroutine mitc clear.

      SUBROUTINE DEFINE_TYING(TOPOLOGY, DATA)                            ! Subroutine define tying takes topology, data.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      TYPE(MITC_DATA_TYPE), INTENT(INOUT) :: DATA                        ! In/out of type mitc_data_type: data.
      REAL(R8), PARAMETER :: A = 0.5773502691896257_R8                   ! Constant real (real64): a = 0.5773502691896257.
      REAL(R8), PARAMETER :: B = 0.7745966692414834_R8                   ! Constant real (real64): b = 0.7745966692414834.

      SELECT CASE(TOPOLOGY)                                              ! Choose according to the value of topology:
      CASE(TOPOLOGY_B2)                                                  ! Case topology_b2:
        DATA%SET_COUNT = 1_I4                                            ! Declaration: data.set_count = 1.
        DATA%ROW_SET(5:6) = 1_I4                                         ! Declaration: data.row_set(5:6) = 1.
        CALL SET_LIST(DATA%SET(1), 1, [0.0_R8])                          ! Call set list with data.set(1), 1, [0.0].
      CASE(TOPOLOGY_B3)                                                  ! Case topology_b3:
        DATA%SET_COUNT = 1_I4                                            ! Declaration: data.set_count = 1.
        DATA%ROW_SET(5:6) = 1_I4                                         ! Declaration: data.row_set(5:6) = 1.
        CALL SET_LIST(DATA%SET(1), 1, [-A,A])                            ! Call set list with data.set(1), 1, [-a, a].
      CASE(TOPOLOGY_B4)                                                  ! Case topology_b4:
        DATA%SET_COUNT = 1_I4                                            ! Declaration: data.set_count = 1.
        DATA%ROW_SET(5:6) = 1_I4                                         ! Declaration: data.row_set(5:6) = 1.
        CALL SET_LIST(DATA%SET(1), 1, [-B,0.0_R8,B])                     ! Call set list with data.set(1), 1, [-b, 0.0, b].
      CASE(TOPOLOGY_Q4)                                                  ! Case topology_q4:
        DATA%SET_COUNT = 2_I4                                            ! Declaration: data.set_count = 2.
        DATA%ROW_SET(4) = 1_I4                                           ! Declaration: data.row_set(4) = 1.
        DATA%ROW_SET(5) = 2_I4                                           ! Declaration: data.row_set(5) = 2.
        CALL SET_LIST(DATA%SET(1), 1, [0.0_R8])                          ! Call set list with data.set(1), 1, [0.0].
        CALL SET_LIST(DATA%SET(1), 2, [1.0_R8,-1.0_R8])                  ! Call set list with data.set(1), 2, [1.0, -1.0].
        CALL SET_LIST(DATA%SET(2), 1, [1.0_R8,-1.0_R8])                  ! Call set list with data.set(2), 1, [1.0, -1.0].
        CALL SET_LIST(DATA%SET(2), 2, [0.0_R8])                          ! Call set list with data.set(2), 2, [0.0].
      CASE(TOPOLOGY_Q9)                                                  ! Case topology_q9:
        DATA%SET_COUNT = 3_I4                                            ! Declaration: data.set_count = 3.
        DATA%ROW_SET(6) = 1_I4                                           ! Declaration: data.row_set(6) = 1.
        DATA%ROW_SET(1) = 2_I4                                           ! Declaration: data.row_set(1) = 2.
        DATA%ROW_SET(4) = 2_I4                                           ! Declaration: data.row_set(4) = 2.
        DATA%ROW_SET(2) = 3_I4                                           ! Declaration: data.row_set(2) = 3.
        DATA%ROW_SET(5) = 3_I4                                           ! Declaration: data.row_set(5) = 3.
        CALL SET_LIST(DATA%SET(1), 1, [-A,A])                            ! Call set list with data.set(1), 1, [-a, a].
        CALL SET_LIST(DATA%SET(1), 2, [-A,A])                            ! Call set list with data.set(1), 2, [-a, a].
        CALL SET_LIST(DATA%SET(2), 1, [-A,A])                            ! Call set list with data.set(2), 1, [-a, a].
        CALL SET_LIST(DATA%SET(2), 2, [-B,0.0_R8,B])                     ! Call set list with data.set(2), 2, [-b, 0.0, b].
        CALL SET_LIST(DATA%SET(3), 1, [-B,0.0_R8,B])                     ! Call set list with data.set(3), 1, [-b, 0.0, b].
        CALL SET_LIST(DATA%SET(3), 2, [-A,A])                            ! Call set list with data.set(3), 2, [-a, a].
      CASE(TOPOLOGY_H8)                                                  ! Case topology_h8:
        DATA%SET_COUNT = 1_I4                                            ! Declaration: data.set_count = 1.
        DATA%ROW_SET(4:6) = 1_I4                                         ! Declaration: data.row_set(4:6) = 1.
        CALL SET_LIST(DATA%SET(1), 1, [0.0_R8])                          ! Call set list with data.set(1), 1, [0.0].
        CALL SET_LIST(DATA%SET(1), 2, [0.0_R8])                          ! Call set list with data.set(1), 2, [0.0].
        CALL SET_LIST(DATA%SET(1), 3, [0.0_R8])                          ! Call set list with data.set(1), 3, [0.0].
      CASE(TOPOLOGY_H20, TOPOLOGY_H27)                                   ! Case topology_h20, topology_h27:
        DATA%SET_COUNT = 1_I4                                            ! Declaration: data.set_count = 1.
        DATA%ROW_SET(4:6) = 1_I4                                         ! Declaration: data.row_set(4:6) = 1.
        CALL SET_LIST(DATA%SET(1), 1, [-A,A])                            ! Call set list with data.set(1), 1, [-a, a].
        CALL SET_LIST(DATA%SET(1), 2, [-A,A])                            ! Call set list with data.set(1), 2, [-a, a].
        CALL SET_LIST(DATA%SET(1), 3, [-A,A])                            ! Call set list with data.set(1), 3, [-a, a].
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE DEFINE_TYING                                        ! End of the subroutine define tying.

      SUBROUTINE SET_LIST(SET, DIRECTION, POINT)                         ! Subroutine set list takes set, direction, point.

      TYPE(TYING_SET_TYPE), INTENT(INOUT) :: SET                         ! In/out of type tying_set_type: set.
      INTEGER, INTENT(IN) :: DIRECTION                                   ! Input integer: direction.
      REAL(R8), INTENT(IN) :: POINT(:)                                   ! Input real (real64): point(:).

      SET%COUNT_1D(DIRECTION) = SIZE(POINT)                              ! Set set.count_1d(direction) to the size of point.
      SET%COORDINATE_1D(1:SIZE(POINT),DIRECTION) = POINT                 ! Set set.coordinate_1d(1:size(point),direction) to point.

      END SUBROUTINE SET_LIST                                            ! End of the subroutine set list.

!  NATURAL COORDINATES OF TYING POINT L (FIRST DIRECTION FASTEST).
      SUBROUTINE POINT_OF_SET(SET, L, COORDINATE)                        ! Subroutine point of set takes set, l, coordinate.

      TYPE(TYING_SET_TYPE), INTENT(IN) :: SET                            ! Input of type tying_set_type: set.
      INTEGER(I4), INTENT(IN) :: L                                       ! Input integer (int32): l.
      REAL(R8), INTENT(OUT) :: COORDINATE(3)                             ! Output real (real64): coordinate(3).
      INTEGER(I4) :: INDEX(3)                                            ! Integer (int32): index(3).
      INTEGER(I4) :: REST                                                ! Integer (int32): rest.
      INTEGER(I4) :: D                                                   ! Integer (int32): d.

      REST = L - 1_I4                                                    ! Set rest to l - 1.
      DO D = 1_I4, 3_I4                                                  ! Loop d from 1 to 3:
        INDEX(D) = MOD(REST,SET%COUNT_1D(D)) + 1_I4                      ! Set index(d) to mod(rest,set.count_1d(d)) + 1.
        REST = REST/SET%COUNT_1D(D)                                      ! Divide rest by set.count_1d(d).
        COORDINATE(D) = SET%COORDINATE_1D(INDEX(D),D)                    ! Set coordinate(d) to set.coordinate_1d(index(d),d).
      END DO                                                             ! End of the loop.

      END SUBROUTINE POINT_OF_SET                                        ! End of the subroutine point of set.

!  M_L(NATURAL): LAGRANGE WEIGHT OF EVERY TYING POINT OF THE SET.
      SUBROUTINE INTERPOLATION_WEIGHT(SET, NATURAL, WEIGHT)              ! Subroutine interpolation weight takes set, natural, weight.

      TYPE(TYING_SET_TYPE), INTENT(IN) :: SET                            ! Input of type tying_set_type: set.
      REAL(R8), INTENT(IN) :: NATURAL(3)                                 ! Input real (real64): natural(3).
      REAL(R8), INTENT(OUT) :: WEIGHT(:)                                 ! Output real (real64): weight(:).
      REAL(R8) :: FACTOR(3,3)                                            ! Real (real64): factor(3,3).
      INTEGER(I4) :: INDEX(3)                                            ! Integer (int32): index(3).
      INTEGER(I4) :: REST                                                ! Integer (int32): rest.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: D                                                   ! Integer (int32): d.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.

      FACTOR = 1.0_R8                                                    ! Set factor to 1.0.
      DO D = 1_I4, 3_I4                                                  ! Loop d from 1 to 3:
        DO K = 1_I4, SET%COUNT_1D(D)                                     ! Loop k from 1 to set.count_1d(d):
          DO M = 1_I4, SET%COUNT_1D(D)                                   ! Loop m from 1 to set.count_1d(d):
            IF (M .EQ. K) CYCLE                                          ! If m = k, skip to the next iteration.
            FACTOR(K,D) = FACTOR(K,D)*(NATURAL(D)-                       ! Multiply factor(k,d) by (natural(d)- set.coordinate_1d(m,d))/(set.coordinate_1d(k,d)- set.coordinate_1d(m,d)).
     &        SET%COORDINATE_1D(M,D))/(SET%COORDINATE_1D(K,D)-
     &        SET%COORDINATE_1D(M,D))
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      WEIGHT = 0.0_R8                                                    ! Set weight to zero.
      DO L = 1_I4, PRODUCT(SET%COUNT_1D)                                 ! Loop l from 1 to product(set.count_1d):
        REST = L - 1_I4                                                  ! Set rest to l - 1.
        WEIGHT(L) = 1.0_R8                                               ! Set weight(l) to 1.0.
        DO D = 1_I4, 3_I4                                                ! Loop d from 1 to 3:
          INDEX(D) = MOD(REST,SET%COUNT_1D(D)) + 1_I4                    ! Set index(d) to mod(rest,set.count_1d(d)) + 1.
          REST = REST/SET%COUNT_1D(D)                                    ! Divide rest by set.count_1d(d).
          WEIGHT(L) = WEIGHT(L)*FACTOR(INDEX(D),D)                       ! Multiply weight(l) by factor(index(d),d).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE INTERPOLATION_WEIGHT                                ! End of the subroutine interpolation weight.

!  REPLACE THE TIED ROWS OF THE STRAIN COLUMN OF ONE DOF.
!    NATURAL:       STRUCTURAL NATURAL COORDINATES OF THE POINT
!    LOCAL_NODE:    STRUCTURAL NODE OF THE DOF
!    FACTOR, FACTOR_GRADIENT: EXPANSION FACTOR AND ITS GRADIENT AT THE
!                   EXPANSION POINT (UNCHANGED AT THE TYING POINTS)
!    COMPONENT:     COLUMN OF THE FRAME ROTATION FOR THE DOF FIELD
!    B_COLUMN:      IN: REGULAR COLUMN; OUT: COLUMN WITH TIED ROWS
      SUBROUTINE MITC_TIE_COLUMN(DATA, NATURAL, LOCAL_NODE, FACTOR,      ! Subroutine mitc tie column takes data, natural, local node, factor, factor gradient, component, b column, s...
     &     FACTOR_GRADIENT, COMPONENT, B_COLUMN, STATUS)

      TYPE(MITC_DATA_TYPE), INTENT(IN) :: DATA                           ! Input of type mitc_data_type: data.
      REAL(R8), INTENT(IN) :: NATURAL(3)                                 ! Input real (real64): natural(3).
      INTEGER(I4), INTENT(IN) :: LOCAL_NODE                              ! Input integer (int32): local_node.
      REAL(R8), INTENT(IN) :: FACTOR                                     ! Input real (real64): factor.
      REAL(R8), INTENT(IN) :: FACTOR_GRADIENT(3)                         ! Input real (real64): factor_gradient(3).
      REAL(R8), INTENT(IN) :: COMPONENT(3)                               ! Input real (real64): component(3).
      REAL(R8), INTENT(INOUT) :: B_COLUMN(6)                             ! In/out real (real64): b_column(6).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: WEIGHT(MAX_POINT)                                      ! Real (real64): weight(max_point).
      REAL(R8) :: GRADIENT(3)                                            ! Real (real64): gradient(3).
      REAL(R8) :: OPERATOR(6,3)                                          ! Real (real64): operator(6,3).
      REAL(R8) :: COLUMN(6)                                              ! Real (real64): column(6).
      REAL(R8) :: TIED(6)                                                ! Real (real64): tied(6).
      INTEGER(I4) :: S                                                   ! Integer (int32): s.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER(I4) :: ROW                                                 ! Integer (int32): row.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (.NOT. DATA%ACTIVE) RETURN                                      ! If not data.active, return to the caller.
      DO S = 1_I4, DATA%SET_COUNT                                        ! Loop s from 1 to data.set_count:
        CALL INTERPOLATION_WEIGHT(DATA%SET(S), NATURAL, WEIGHT)          ! Call interpolation weight with data.set(s), natural, weight.
        TIED = 0.0_R8                                                    ! Set tied to zero.
        DO L = 1_I4, PRODUCT(DATA%SET(S)%COUNT_1D)                       ! Loop l from 1 to product(data.set(s).count_1d):
          GRADIENT = DATA%GRADIENT(:,LOCAL_NODE,L,S)*FACTOR +            ! Set gradient to data.gradient(:,local_node,l,s)*factor + data.shape(local_node,l,s)*factor_gradient.
     &               DATA%SHAPE(LOCAL_NODE,L,S)*FACTOR_GRADIENT
          CALL BUILD_DISPLACEMENT_OPERATOR(GRADIENT, OPERATOR, STATUS)   ! Call build displacement operator with gradient, operator, status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
          COLUMN = MATMUL(OPERATOR,COMPONENT)                            ! Set column to matmul(operator,component).
          TIED = TIED + WEIGHT(L)*COLUMN                                 ! Add weight(l)*column to tied.
        END DO                                                           ! End of the loop.
        DO ROW = 1_I4, 6_I4                                              ! Loop row from 1 to 6:
          IF (DATA%ROW_SET(ROW) .EQ. S) B_COLUMN(ROW) = TIED(ROW)        ! If data.row_set(row) = s, set b_column(row) to tied(row).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE MITC_TIE_COLUMN                                     ! End of the subroutine mitc tie column.

      END MODULE MUL2_MITC                                               ! End of the module mul2 mitc.
