!=======================================================================
!  LOCAL-FRAME GRADIENTS OF THE SHAPE FUNCTIONS OF ONE ELEMENT.
!
!  THE ELEMENT LIVES IN ITS ACTIVE LOCAL AXES (BEAM: AXIS 2; PLATE:
!  AXES 1,2; SOLID AND EXPANSION ELEMENTS: THEIR OWN AXES). THE
!  JACOBIAN IS SQUARE IN THOSE AXES; THE GRADIENT IS EMBEDDED BACK INTO
!  THE THREE LOCAL COORDINATES (INACTIVE COMPONENTS ARE ZERO).
!=======================================================================
      MODULE MUL2_LOCAL_GRADIENTS                                        ! Module mul2 local gradients begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, STATUS_IS_OK     ! Use from module mul2 status: status type, clear status, status is ok.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NODE_COUNT,                    ! Use from module mul2 topologies: topology node count, topology natural dimension.
     &                           TOPOLOGY_NATURAL_DIMENSION
      USE MUL2_SHAPE_FUNCTIONS, ONLY: EVALUATE_SHAPE                     ! Use from module mul2 shape functions: evaluate shape.
      USE MUL2_JACOBIANS, ONLY: EVALUATE_SQUARE_JACOBIAN                 ! Use from module mul2 jacobians: evaluate square jacobian.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: STRUCTURAL_ACTIVE_AXES                                   ! Export: structural active axes.
      PUBLIC :: LOCAL_SHAPE_GRADIENT                                     ! Export: local shape gradient.
      PUBLIC :: EVALUATE_SHAPE_AND_GRADIENT                              ! Export: evaluate shape and gradient.

      CONTAINS                                                           ! The procedures of the module follow.

!  ACTIVE LOCAL AXES OF A STRUCTURAL ELEMENT OF GIVEN DIMENSION.
      SUBROUTINE STRUCTURAL_ACTIVE_AXES(DIMENSION, AXIS)                 ! Subroutine structural active axes takes dimension, axis.

      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      INTEGER(I4), INTENT(OUT) :: AXIS(3)                                ! Output integer (int32): axis(3).

      AXIS = [1_I4,2_I4,3_I4]                                            ! Set axis to [1,2,3].
      IF (DIMENSION .EQ. 1_I4) AXIS(1) = 2_I4                            ! If dimension = 1, set axis(1) to 2.

      END SUBROUTINE STRUCTURAL_ACTIVE_AXES                              ! End of the subroutine structural active axes.

!  GRADIENT(:,I) = GRADIENT OF SHAPE I IN THE LOCAL FRAME.
      SUBROUTINE LOCAL_SHAPE_GRADIENT(DIMENSION, AXIS, COORDINATE,       ! Subroutine local shape gradient takes dimension, axis, coordinate, natural derivative, gradient, status.
     &     NATURAL_DERIVATIVE, GRADIENT, STATUS)

      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      INTEGER(I4), INTENT(IN) :: AXIS(3)                                 ! Input integer (int32): axis(3).
      REAL(R8), INTENT(IN) :: COORDINATE(:,:)                            ! Input real (real64): coordinate(:,:).
      REAL(R8), INTENT(IN) :: NATURAL_DERIVATIVE(:,:)                    ! Input real (real64): natural_derivative(:,:).
      REAL(R8), INTENT(OUT) :: GRADIENT(:,:)                             ! Output real (real64): gradient(:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: ACTIVE(:,:)                               ! Allocatable real (real64): active(:,:).
      REAL(R8), ALLOCATABLE :: PHYSICAL(:,:)                             ! Allocatable real (real64): physical(:,:).
      REAL(R8) :: JACOBIAN(3,3)                                          ! Real (real64): jacobian(3,3).
      REAL(R8) :: INVERSE(3,3)                                           ! Real (real64): inverse(3,3).
      REAL(R8) :: DETERMINANT                                            ! Real (real64): determinant.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.
      INTEGER(I4) :: N_FUNC                                              ! Integer (int32): n_func.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      GRADIENT = 0.0_R8                                                  ! Set gradient to zero.
      IF (DIMENSION .EQ. 0_I4) RETURN                                    ! If dimension = 0, return to the caller.
      N_NODE = SIZE(COORDINATE,2)                                        ! Set n_node to size(coordinate,2).
      N_FUNC = MAX(N_NODE,SIZE(NATURAL_DERIVATIVE,1))                    ! Set n_func to the larger of n_node and size(natural_derivative,1).
      ALLOCATE(ACTIVE(N_NODE,3))                                         ! Allocate memory for active(n_node,3).
      ALLOCATE(PHYSICAL(N_FUNC,3))                                       ! Allocate memory for physical(n_func,3).
      ACTIVE = 0.0_R8                                                    ! Set active to zero.
      DO K = 1_I4, DIMENSION                                             ! Loop k from 1 to dimension:
        ACTIVE(:,K) = COORDINATE(AXIS(K),:)                              ! Set active(:,k) to coordinate(axis(k),:).
      END DO                                                             ! End of the loop.
      CALL EVALUATE_SQUARE_JACOBIAN(ACTIVE(:,1:DIMENSION),               ! Call evaluate square jacobian with active(:,1:dimension), natural_derivative(1:n_node,1:dimension), dimensi...
     &     NATURAL_DERIVATIVE(1:N_NODE,1:DIMENSION), DIMENSION,
     &     JACOBIAN, DETERMINANT, INVERSE,
     &     PHYSICAL(1:N_NODE,1:DIMENSION), STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
!     HLE SUB-ELEMENTS HAVE MORE FUNCTIONS THAN VERTEX NODES.
      IF (N_FUNC .GT. N_NODE) THEN                                       ! If n_func > n_node:
        PHYSICAL(1:N_FUNC,1:DIMENSION) = MATMUL(                         ! Set physical(1:n_func,1:dimension) to matmul( natural_derivative(1:n_func,1:dimension), transpose(inverse(1...
     &    NATURAL_DERIVATIVE(1:N_FUNC,1:DIMENSION),
     &    TRANSPOSE(INVERSE(1:DIMENSION,1:DIMENSION)))
      END IF                                                             ! End of the IF block.
      DO K = 1_I4, DIMENSION                                             ! Loop k from 1 to dimension:
        GRADIENT(AXIS(K),:) = PHYSICAL(:,K)                              ! Set gradient(axis(k),:) to physical(:,k).
      END DO                                                             ! End of the loop.

      END SUBROUTINE LOCAL_SHAPE_GRADIENT                                ! End of the subroutine local shape gradient.

!  SHAPES AND LOCAL GRADIENTS OF A STRUCTURAL ELEMENT AT A NATURAL
!  POINT. NODE_LOCAL(:,I) IS THE LOCAL COORDINATE OF NODE I.
      SUBROUTINE EVALUATE_SHAPE_AND_GRADIENT(TOPOLOGY, NODE_LOCAL,       ! Subroutine evaluate shape and gradient takes topology, node local, natural, shape, gradient, status.
     &     NATURAL, SHAPE, GRADIENT, STATUS)

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.
      REAL(R8), INTENT(IN) :: NODE_LOCAL(:,:)                            ! Input real (real64): node_local(:,:).
      REAL(R8), INTENT(IN) :: NATURAL(3)                                 ! Input real (real64): natural(3).
      REAL(R8), INTENT(OUT) :: SHAPE(:)                                  ! Output real (real64): shape(:).
      REAL(R8), INTENT(OUT) :: GRADIENT(:,:)                             ! Output real (real64): gradient(:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: DERIVATIVE(:,:)                           ! Allocatable real (real64): derivative(:,:).
      INTEGER(I4) :: AXIS(3)                                             ! Integer (int32): axis(3).
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: N_NODE                                              ! Integer (int32): n_node.

      N_NODE = TOPOLOGY_NODE_COUNT(TOPOLOGY)                             ! Set n_node to topology_node_count(topology).
      DIMENSION = TOPOLOGY_NATURAL_DIMENSION(TOPOLOGY)                   ! Set dimension to topology_natural_dimension(topology).
      ALLOCATE(DERIVATIVE(N_NODE,3))                                     ! Allocate memory for derivative(n_node,3).
      CALL EVALUATE_SHAPE(TOPOLOGY, NATURAL, SHAPE, DERIVATIVE,          ! Call evaluate shape with topology, natural, shape, derivative, status.
     &                    STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL STRUCTURAL_ACTIVE_AXES(DIMENSION, AXIS)                       ! Call structural active axes with dimension, axis.
      CALL LOCAL_SHAPE_GRADIENT(DIMENSION, AXIS,                         ! Call local shape gradient with dimension, axis, node_local(:,1:n_node), derivative, gradient, status.
     &     NODE_LOCAL(:,1:N_NODE), DERIVATIVE, GRADIENT, STATUS)

      END SUBROUTINE EVALUATE_SHAPE_AND_GRADIENT                         ! End of the subroutine evaluate shape and gradient.

      END MODULE MUL2_LOCAL_GRADIENTS                                    ! End of the module mul2 local gradients.
