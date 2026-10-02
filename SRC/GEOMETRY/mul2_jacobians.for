!=======================================================================
!  SQUARE ISOPARAMETRIC JACOBIAN AND DERIVATIVE TRANSFORMATION.
!=======================================================================
      MODULE MUL2_JACOBIANS                                              ! Module mul2 jacobians begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: EVALUATE_SQUARE_JACOBIAN                                 ! Export: evaluate square jacobian.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE EVALUATE_SQUARE_JACOBIAN(COORDINATE,                    ! Subroutine evaluate square jacobian takes coordinate, dn dnatural, dimension, jacobian, determinant, invers...
     &     DN_DNATURAL, DIMENSION, JACOBIAN, DETERMINANT,
     &     INVERSE_JACOBIAN, DN_DPHYSICAL, STATUS)

      REAL(R8), INTENT(IN) :: COORDINATE(:,:)                            ! Input real (real64): coordinate(:,:).
      REAL(R8), INTENT(IN) :: DN_DNATURAL(:,:)                           ! Input real (real64): dn_dnatural(:,:).
      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      REAL(R8), INTENT(OUT) :: JACOBIAN(:,:)                             ! Output real (real64): jacobian(:,:).
      REAL(R8), INTENT(OUT) :: DETERMINANT                               ! Output real (real64): determinant.
      REAL(R8), INTENT(OUT) :: INVERSE_JACOBIAN(:,:)                     ! Output real (real64): inverse_jacobian(:,:).
      REAL(R8), INTENT(OUT) :: DN_DPHYSICAL(:,:)                         ! Output real (real64): dn_dphysical(:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: SCALE                                                  ! Real (real64): scale.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: B                                                   ! Integer (int32): b.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      JACOBIAN = 0.0_R8                                                  ! Set jacobian to zero.
      INVERSE_JACOBIAN = 0.0_R8                                          ! Set inverse_jacobian to zero.
      DN_DPHYSICAL = 0.0_R8                                              ! Set dn_dphysical to zero.
      DETERMINANT = 0.0_R8                                               ! Set determinant to zero.
      IF (DIMENSION .LT. 1_I4 .OR. DIMENSION .GT. 3_I4) THEN             ! If dimension < 1 or dimension > 3:
        CALL SET_ERROR(STATUS, 'EVALUATE_SQUARE_JACOBIAN',               ! Record an error in status: 'DIMENSION MUST BE BETWEEN 1 AND 3'.
     &                 'DIMENSION MUST BE BETWEEN 1 AND 3')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (SIZE(COORDINATE,1) .NE. SIZE(DN_DNATURAL,1) .OR.               ! If size(coordinate,1) /= size(dn_dnatural,1) or size(coordinate,2) < dimension or size(dn_dnatural,2) < dim...
     &    SIZE(COORDINATE,2) .LT. DIMENSION .OR.
     &    SIZE(DN_DNATURAL,2) .LT. DIMENSION .OR.
     &    SIZE(JACOBIAN,1) .LT. DIMENSION .OR.
     &    SIZE(JACOBIAN,2) .LT. DIMENSION .OR.
     &    SIZE(INVERSE_JACOBIAN,1) .LT. DIMENSION .OR.
     &    SIZE(INVERSE_JACOBIAN,2) .LT. DIMENSION .OR.
     &    SIZE(DN_DPHYSICAL,1) .LT. SIZE(COORDINATE,1) .OR.
     &    SIZE(DN_DPHYSICAL,2) .LT. DIMENSION) THEN
        CALL SET_ERROR(STATUS, 'EVALUATE_SQUARE_JACOBIAN',               ! Record an error in status: 'JACOBIAN WORKSPACE IS INCONSISTENT'.
     &                 'JACOBIAN WORKSPACE IS INCONSISTENT')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      DO A = 1_I4, DIMENSION                                             ! Loop a from 1 to dimension:
        DO B = 1_I4, DIMENSION                                           ! Loop b from 1 to dimension:
          DO I = 1_I4, SIZE(COORDINATE,1)                                ! Loop i from 1 to size(coordinate,1):
            JACOBIAN(A,B) = JACOBIAN(A,B) +                              ! Add coordinate(i,b)*dn_dnatural(i,a) to jacobian(a,b).
     &        COORDINATE(I,B)*DN_DNATURAL(I,A)
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      CALL INVERT_SMALL_MATRIX(JACOBIAN, DIMENSION,                      ! Call invert small matrix with jacobian, dimension, determinant, inverse_jacobian.
     &                         DETERMINANT, INVERSE_JACOBIAN)
      SCALE = MAX(1.0_R8,MAXVAL(ABS(JACOBIAN(1:DIMENSION,                ! Set scale to the larger of 1.0 and maxval(abs(jacobian(1:dimension, 1:dimension))).
     &                                      1:DIMENSION))))
      IF (DETERMINANT .LE. 100.0_R8*EPSILON(1.0_R8)*                     ! If determinant <= 100.0*epsilon(1.0)* scale**dimension:
     &    SCALE**DIMENSION) THEN
        CALL SET_ERROR(STATUS, 'EVALUATE_SQUARE_JACOBIAN',               ! Record an error in status: 'ELEMENT IS DEGENERATE OR INVERTED'.
     &                 'ELEMENT IS DEGENERATE OR INVERTED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      DO I = 1_I4, SIZE(COORDINATE,1)                                    ! Loop i from 1 to size(coordinate,1):
        DN_DPHYSICAL(I,1:DIMENSION) = MATMUL(                            ! Set dn_dphysical(i,1:dimension) to matmul( inverse_jacobian(1:dimension,1:dimension), dn_dnatural(i,1:dimen...
     &    INVERSE_JACOBIAN(1:DIMENSION,1:DIMENSION),
     &    DN_DNATURAL(I,1:DIMENSION))
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_SQUARE_JACOBIAN                            ! End of the subroutine evaluate square jacobian.

      SUBROUTINE INVERT_SMALL_MATRIX(A, DIMENSION,                       ! Subroutine invert small matrix takes a, dimension, determinant, inverse.
     &                               DETERMINANT, INVERSE)

      REAL(R8), INTENT(IN) :: A(:,:)                                     ! Input real (real64): a(:,:).
      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      REAL(R8), INTENT(OUT) :: DETERMINANT                               ! Output real (real64): determinant.
      REAL(R8), INTENT(INOUT) :: INVERSE(:,:)                            ! In/out real (real64): inverse(:,:).

      SELECT CASE (DIMENSION)                                            ! Choose according to the value of dimension:
      CASE (1_I4)                                                        ! Case 1:
        DETERMINANT = A(1,1)                                             ! Set determinant to a(1,1).
        IF (DETERMINANT .NE. 0.0_R8) THEN                                ! If determinant /= 0.0:
          INVERSE(1,1) = 1.0_R8/DETERMINANT                              ! Set inverse(1,1) to 1.0/determinant.
        END IF                                                           ! End of the IF block.
      CASE (2_I4)                                                        ! Case 2:
        DETERMINANT = A(1,1)*A(2,2)-A(1,2)*A(2,1)                        ! Set determinant to a(1,1)*a(2,2)-a(1,2)*a(2,1).
        IF (DETERMINANT .NE. 0.0_R8) THEN                                ! If determinant /= 0.0:
          INVERSE(1,1) = A(2,2)/DETERMINANT                              ! Set inverse(1,1) to a(2,2)/determinant.
          INVERSE(1,2) = -A(1,2)/DETERMINANT                             ! Set inverse(1,2) to -a(1,2)/determinant.
          INVERSE(2,1) = -A(2,1)/DETERMINANT                             ! Set inverse(2,1) to -a(2,1)/determinant.
          INVERSE(2,2) = A(1,1)/DETERMINANT                              ! Set inverse(2,2) to a(1,1)/determinant.
        END IF                                                           ! End of the IF block.
      CASE (3_I4)                                                        ! Case 3:
        DETERMINANT = A(1,1)*(A(2,2)*A(3,3)-A(2,3)*A(3,2))               ! Set determinant to a(1,1)*(a(2,2)*a(3,3)-a(2,3)*a(3,2)) - a(1,2)*(a(2,1)*a(3,3)-a(2,3)*a(3,1)) + a(1,3)*(a(...
     &              - A(1,2)*(A(2,1)*A(3,3)-A(2,3)*A(3,1))
     &              + A(1,3)*(A(2,1)*A(3,2)-A(2,2)*A(3,1))
        IF (DETERMINANT .NE. 0.0_R8) THEN                                ! If determinant /= 0.0:
          INVERSE(1,1) = (A(2,2)*A(3,3)-A(2,3)*A(3,2))/                  ! Set inverse(1,1) to (a(2,2)*a(3,3)-a(2,3)*a(3,2))/ determinant.
     &                   DETERMINANT
          INVERSE(1,2) = (A(1,3)*A(3,2)-A(1,2)*A(3,3))/                  ! Set inverse(1,2) to (a(1,3)*a(3,2)-a(1,2)*a(3,3))/ determinant.
     &                   DETERMINANT
          INVERSE(1,3) = (A(1,2)*A(2,3)-A(1,3)*A(2,2))/                  ! Set inverse(1,3) to (a(1,2)*a(2,3)-a(1,3)*a(2,2))/ determinant.
     &                   DETERMINANT
          INVERSE(2,1) = (A(2,3)*A(3,1)-A(2,1)*A(3,3))/                  ! Set inverse(2,1) to (a(2,3)*a(3,1)-a(2,1)*a(3,3))/ determinant.
     &                   DETERMINANT
          INVERSE(2,2) = (A(1,1)*A(3,3)-A(1,3)*A(3,1))/                  ! Set inverse(2,2) to (a(1,1)*a(3,3)-a(1,3)*a(3,1))/ determinant.
     &                   DETERMINANT
          INVERSE(2,3) = (A(1,3)*A(2,1)-A(1,1)*A(2,3))/                  ! Set inverse(2,3) to (a(1,3)*a(2,1)-a(1,1)*a(2,3))/ determinant.
     &                   DETERMINANT
          INVERSE(3,1) = (A(2,1)*A(3,2)-A(2,2)*A(3,1))/                  ! Set inverse(3,1) to (a(2,1)*a(3,2)-a(2,2)*a(3,1))/ determinant.
     &                   DETERMINANT
          INVERSE(3,2) = (A(1,2)*A(3,1)-A(1,1)*A(3,2))/                  ! Set inverse(3,2) to (a(1,2)*a(3,1)-a(1,1)*a(3,2))/ determinant.
     &                   DETERMINANT
          INVERSE(3,3) = (A(1,1)*A(2,2)-A(1,2)*A(2,1))/                  ! Set inverse(3,3) to (a(1,1)*a(2,2)-a(1,2)*a(2,1))/ determinant.
     &                   DETERMINANT
        END IF                                                           ! End of the IF block.
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE INVERT_SMALL_MATRIX                                 ! End of the subroutine invert small matrix.

      END MODULE MUL2_JACOBIANS                                          ! End of the module mul2 jacobians.
