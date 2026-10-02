!=======================================================================
!  CUF EXPANSION BASES. TAYLOR ORDER MATCHES THE AUTHORITATIVE CODE.
!=======================================================================
      MODULE MUL2_CUF_BASES                                              ! Module mul2 cuf bases begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: TAYLOR_BASIS_TERM_COUNT                                  ! Export: taylor basis term count.
      PUBLIC :: EVALUATE_TAYLOR_BASIS                                    ! Export: evaluate taylor basis.
      PUBLIC :: EVALUATE_TAYLOR_TERM                                     ! Export: evaluate taylor term.

      CONTAINS                                                           ! The procedures of the module follow.

      INTEGER(I4) FUNCTION TAYLOR_BASIS_TERM_COUNT(ORDER,                ! Function taylor basis term count takes order, dimension.
     &                                             DIMENSION)

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.

      TAYLOR_BASIS_TERM_COUNT = 0_I4                                     ! Set taylor_basis_term_count to zero.
      IF (ORDER .LT. 0_I4) RETURN                                        ! If order < 0, return to the caller.
      SELECT CASE(DIMENSION)                                             ! Choose according to the value of dimension:
      CASE(0_I4)                                                         ! Case 0:
        TAYLOR_BASIS_TERM_COUNT = 1_I4                                   ! Set taylor_basis_term_count to 1.
      CASE(1_I4)                                                         ! Case 1:
        TAYLOR_BASIS_TERM_COUNT = ORDER + 1_I4                           ! Set taylor_basis_term_count to order + 1.
      CASE(2_I4)                                                         ! Case 2:
        TAYLOR_BASIS_TERM_COUNT =                                        ! Set taylor_basis_term_count to (order+1)*(order+2)/2.
     &    (ORDER+1_I4)*(ORDER+2_I4)/2_I4
      END SELECT                                                         ! End of the case selection.

      END FUNCTION TAYLOR_BASIS_TERM_COUNT                               ! End of the function taylor basis term count.

      SUBROUTINE EVALUATE_TAYLOR_BASIS(ORDER, DIMENSION,                 ! Subroutine evaluate taylor basis takes order, dimension, active axis, coordinate, value, gradient, status.
     &     ACTIVE_AXIS, COORDINATE, VALUE, GRADIENT, STATUS)

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      INTEGER(I4), INTENT(IN) :: ACTIVE_AXIS(2)                          ! Input integer (int32): active_axis(2).
      REAL(R8), INTENT(IN) :: COORDINATE(3)                              ! Input real (real64): coordinate(3).
      REAL(R8), INTENT(OUT) :: VALUE(:)                                  ! Output real (real64): value(:).
      REAL(R8), INTENT(OUT) :: GRADIENT(:,:)                             ! Output real (real64): gradient(:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: REQUIRED                                            ! Integer (int32): required.
      INTEGER(I4) :: TERM                                                ! Integer (int32): term.
      INTEGER(I4) :: DEGREE                                              ! Integer (int32): degree.
      INTEGER(I4) :: EXPONENT_1                                          ! Integer (int32): exponent_1.
      INTEGER(I4) :: EXPONENT_2                                          ! Integer (int32): exponent_2.
      REAL(R8) :: X1                                                     ! Real (real64): x1.
      REAL(R8) :: X2                                                     ! Real (real64): x2.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      VALUE = 0.0_R8                                                     ! Set value to zero.
      GRADIENT = 0.0_R8                                                  ! Set gradient to zero.
      REQUIRED = TAYLOR_BASIS_TERM_COUNT(ORDER,DIMENSION)                ! Set required to taylor_basis_term_count(order,dimension).
      IF (REQUIRED .LT. 1_I4 .OR. SIZE(VALUE) .LT. REQUIRED .OR.         ! If required < 1 or size(value) < required or size(gradient,1) < 3 or size(gradient,2) < required:
     &    SIZE(GRADIENT,1) .LT. 3_I4 .OR.
     &    SIZE(GRADIENT,2) .LT. REQUIRED) THEN
        CALL SET_ERROR(STATUS, 'EVALUATE_TAYLOR_BASIS',                  ! Record an error in status: 'INVALID TAYLOR BASIS DIMENSIONS'.
     &                 'INVALID TAYLOR BASIS DIMENSIONS')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (DIMENSION .GT. 0_I4) THEN                                      ! If dimension > 0:
        IF (MINVAL(ACTIVE_AXIS(1:DIMENSION)) .LT. 1_I4 .OR.              ! If minval(active_axis(1:dimension)) < 1 or maxval(active_axis(1:dimension)) > 3:
     &      MAXVAL(ACTIVE_AXIS(1:DIMENSION)) .GT. 3_I4) THEN
          CALL SET_ERROR(STATUS, 'EVALUATE_TAYLOR_BASIS',                ! Record an error in status: 'INVALID TAYLOR ACTIVE AXIS'.
     &                   'INVALID TAYLOR ACTIVE AXIS')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.

      SELECT CASE(DIMENSION)                                             ! Choose according to the value of dimension:
      CASE(0_I4)                                                         ! Case 0:
        VALUE(1) = 1.0_R8                                                ! Set value(1) to 1.0.
      CASE(1_I4)                                                         ! Case 1:
        X1 = COORDINATE(ACTIVE_AXIS(1))                                  ! Set x1 to coordinate(active_axis(1)).
        DO DEGREE = 0_I4, ORDER                                          ! Loop degree from 0 to order:
          TERM = DEGREE + 1_I4                                           ! Set term to degree + 1.
          VALUE(TERM) = INTEGER_POWER(X1,DEGREE)                         ! Set value(term) to integer_power(x1,degree).
          IF (DEGREE .GT. 0_I4) THEN                                     ! If degree > 0:
            GRADIENT(ACTIVE_AXIS(1),TERM) = REAL(DEGREE,R8)*             ! Set gradient(active_axis(1),term) to real(degree,r8)* integer_power(x1,degree-1).
     &        INTEGER_POWER(X1,DEGREE-1_I4)
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
      CASE(2_I4)                                                         ! Case 2:
        X1 = COORDINATE(ACTIVE_AXIS(1))                                  ! Set x1 to coordinate(active_axis(1)).
        X2 = COORDINATE(ACTIVE_AXIS(2))                                  ! Set x2 to coordinate(active_axis(2)).
        TERM = 0_I4                                                      ! Set term to zero.
        DO DEGREE = 0_I4, ORDER                                          ! Loop degree from 0 to order:
          DO EXPONENT_2 = 0_I4, DEGREE                                   ! Loop exponent_2 from 0 to degree:
            EXPONENT_1 = DEGREE - EXPONENT_2                             ! Set exponent_1 to degree - exponent_2.
            TERM = TERM + 1_I4                                           ! Add 1 to term.
            VALUE(TERM) = INTEGER_POWER(X1,EXPONENT_1)*                  ! Set value(term) to integer_power(x1,exponent_1)* integer_power(x2,exponent_2).
     &                    INTEGER_POWER(X2,EXPONENT_2)
            IF (EXPONENT_1 .GT. 0_I4) THEN                               ! If exponent_1 > 0:
              GRADIENT(ACTIVE_AXIS(1),TERM) =                            ! Set gradient(active_axis(1),term) to real(exponent_1,r8)* integer_power(x1,exponent_1-1)* integer_power(x2,...
     &          REAL(EXPONENT_1,R8)*
     &          INTEGER_POWER(X1,EXPONENT_1-1_I4)*
     &          INTEGER_POWER(X2,EXPONENT_2)
            END IF                                                       ! End of the IF block.
            IF (EXPONENT_2 .GT. 0_I4) THEN                               ! If exponent_2 > 0:
              GRADIENT(ACTIVE_AXIS(2),TERM) =                            ! Set gradient(active_axis(2),term) to real(exponent_2,r8)* integer_power(x1,exponent_1)* integer_power(x2,ex...
     &          REAL(EXPONENT_2,R8)*
     &          INTEGER_POWER(X1,EXPONENT_1)*
     &          INTEGER_POWER(X2,EXPONENT_2-1_I4)
            END IF                                                       ! End of the IF block.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      CASE DEFAULT                                                       ! In every other case:
        CALL SET_ERROR(STATUS, 'EVALUATE_TAYLOR_BASIS',                  ! Record an error in status: 'TAYLOR DIMENSION MUST BE 0, 1 OR 2'.
     &                 'TAYLOR DIMENSION MUST BE 0, 1 OR 2')
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE EVALUATE_TAYLOR_BASIS                               ! End of the subroutine evaluate taylor basis.

      SUBROUTINE EVALUATE_TAYLOR_TERM(ORDER, DIMENSION,                  ! Subroutine evaluate taylor term takes order, dimension, active axis, coordinate, term, value, gradient, sta...
     &     ACTIVE_AXIS, COORDINATE, TERM, VALUE, GRADIENT, STATUS)

      INTEGER(I4), INTENT(IN) :: ORDER                                   ! Input integer (int32): order.
      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      INTEGER(I4), INTENT(IN) :: ACTIVE_AXIS(2)                          ! Input integer (int32): active_axis(2).
      REAL(R8), INTENT(IN) :: COORDINATE(3)                              ! Input real (real64): coordinate(3).
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.
      REAL(R8), INTENT(OUT) :: VALUE                                     ! Output real (real64): value.
      REAL(R8), INTENT(OUT) :: GRADIENT(3)                               ! Output real (real64): gradient(3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: CURRENT                                             ! Integer (int32): current.
      INTEGER(I4) :: DEGREE                                              ! Integer (int32): degree.
      INTEGER(I4) :: EXPONENT_1                                          ! Integer (int32): exponent_1.
      INTEGER(I4) :: EXPONENT_2                                          ! Integer (int32): exponent_2.
      REAL(R8) :: X1                                                     ! Real (real64): x1.
      REAL(R8) :: X2                                                     ! Real (real64): x2.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      VALUE = 0.0_R8                                                     ! Set value to zero.
      GRADIENT = 0.0_R8                                                  ! Set gradient to zero.
      IF (TERM .LT. 1_I4 .OR. TERM .GT.                                  ! If term < 1 or term > taylor_basis_term_count(order,dimension):
     &    TAYLOR_BASIS_TERM_COUNT(ORDER,DIMENSION)) THEN
        CALL SET_ERROR(STATUS, 'EVALUATE_TAYLOR_TERM',                   ! Record an error in status: 'TAYLOR TERM IS OUT OF RANGE'.
     &                 'TAYLOR TERM IS OUT OF RANGE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (DIMENSION .EQ. 0_I4) THEN                                      ! If dimension = 0:
        VALUE = 1.0_R8                                                   ! Set value to 1.0.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (MINVAL(ACTIVE_AXIS(1:DIMENSION)) .LT. 1_I4 .OR.                ! If minval(active_axis(1:dimension)) < 1 or maxval(active_axis(1:dimension)) > 3:
     &    MAXVAL(ACTIVE_AXIS(1:DIMENSION)) .GT. 3_I4) THEN
        CALL SET_ERROR(STATUS, 'EVALUATE_TAYLOR_TERM',                   ! Record an error in status: 'INVALID TAYLOR ACTIVE AXIS'.
     &                 'INVALID TAYLOR ACTIVE AXIS')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      X1 = COORDINATE(ACTIVE_AXIS(1))                                    ! Set x1 to coordinate(active_axis(1)).
      IF (DIMENSION .EQ. 1_I4) THEN                                      ! If dimension = 1:
        EXPONENT_1 = TERM - 1_I4                                         ! Set exponent_1 to term - 1.
        VALUE = INTEGER_POWER(X1,EXPONENT_1)                             ! Set value to integer_power(x1,exponent_1).
        IF (EXPONENT_1 .GT. 0_I4) THEN                                   ! If exponent_1 > 0:
          GRADIENT(ACTIVE_AXIS(1)) = REAL(EXPONENT_1,R8)*                ! Set gradient(active_axis(1)) to real(exponent_1,r8)* integer_power(x1,exponent_1-1).
     &      INTEGER_POWER(X1,EXPONENT_1-1_I4)
        END IF                                                           ! End of the IF block.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (DIMENSION .NE. 2_I4) THEN                                      ! If dimension /= 2:
        CALL SET_ERROR(STATUS, 'EVALUATE_TAYLOR_TERM',                   ! Record an error in status: 'TAYLOR DIMENSION MUST BE 0, 1 OR 2'.
     &                 'TAYLOR DIMENSION MUST BE 0, 1 OR 2')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      X2 = COORDINATE(ACTIVE_AXIS(2))                                    ! Set x2 to coordinate(active_axis(2)).
      CURRENT = 0_I4                                                     ! Set current to zero.
      DO DEGREE = 0_I4, ORDER                                            ! Loop degree from 0 to order:
        DO EXPONENT_2 = 0_I4, DEGREE                                     ! Loop exponent_2 from 0 to degree:
          CURRENT = CURRENT + 1_I4                                       ! Add 1 to current.
          IF (CURRENT .NE. TERM) CYCLE                                   ! If current /= term, skip to the next iteration.
          EXPONENT_1 = DEGREE - EXPONENT_2                               ! Set exponent_1 to degree - exponent_2.
          VALUE = INTEGER_POWER(X1,EXPONENT_1)*                          ! Set value to integer_power(x1,exponent_1)* integer_power(x2,exponent_2).
     &            INTEGER_POWER(X2,EXPONENT_2)
          IF (EXPONENT_1 .GT. 0_I4) THEN                                 ! If exponent_1 > 0:
            GRADIENT(ACTIVE_AXIS(1)) = REAL(EXPONENT_1,R8)*              ! Set gradient(active_axis(1)) to real(exponent_1,r8)* integer_power(x1,exponent_1-1)* integer_power(x2,expon...
     &        INTEGER_POWER(X1,EXPONENT_1-1_I4)*
     &        INTEGER_POWER(X2,EXPONENT_2)
          END IF                                                         ! End of the IF block.
          IF (EXPONENT_2 .GT. 0_I4) THEN                                 ! If exponent_2 > 0:
            GRADIENT(ACTIVE_AXIS(2)) = REAL(EXPONENT_2,R8)*              ! Set gradient(active_axis(2)) to real(exponent_2,r8)* integer_power(x1,exponent_1)* integer_power(x2,exponen...
     &        INTEGER_POWER(X1,EXPONENT_1)*
     &        INTEGER_POWER(X2,EXPONENT_2-1_I4)
          END IF                                                         ! End of the IF block.
          RETURN                                                         ! Return to the caller.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_TAYLOR_TERM                                ! End of the subroutine evaluate taylor term.

      REAL(R8) FUNCTION INTEGER_POWER(VALUE, EXPONENT)                   ! Function integer power takes value, exponent.

      REAL(R8), INTENT(IN) :: VALUE                                      ! Input real (real64): value.
      INTEGER(I4), INTENT(IN) :: EXPONENT                                ! Input integer (int32): exponent.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      INTEGER_POWER = 1.0_R8                                             ! Set integer_power to 1.0.
      DO I = 1_I4, EXPONENT                                              ! Loop i from 1 to exponent:
        INTEGER_POWER = INTEGER_POWER*VALUE                              ! Multiply integer_power by value.
      END DO                                                             ! End of the loop.

      END FUNCTION INTEGER_POWER                                         ! End of the function integer power.

      END MODULE MUL2_CUF_BASES                                          ! End of the module mul2 cuf bases.
