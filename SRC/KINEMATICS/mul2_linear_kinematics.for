!=======================================================================
!  LINEAR SMALL-STRAIN OPERATORS FOR FIELD-DEPENDENT DISPLACEMENTS.
!=======================================================================
      MODULE MUL2_LINEAR_KINEMATICS                                      ! Module mul2 linear kinematics begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: COMPOSE_PRODUCT_BASIS                                    ! Export: compose product basis.
      PUBLIC :: BUILD_DISPLACEMENT_COLUMN                                ! Export: build displacement column.
      PUBLIC :: BUILD_DISPLACEMENT_OPERATOR                              ! Export: build displacement operator.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE COMPOSE_PRODUCT_BASIS(STRUCTURAL_VALUE,                 ! Subroutine compose product basis takes structural value, structural gradient, expansion value, expansion gr...
     &     STRUCTURAL_GRADIENT, EXPANSION_VALUE,
     &     EXPANSION_GRADIENT, VALUE, GRADIENT)

      REAL(R8), INTENT(IN) :: STRUCTURAL_VALUE                           ! Input real (real64): structural_value.
      REAL(R8), INTENT(IN) :: STRUCTURAL_GRADIENT(3)                     ! Input real (real64): structural_gradient(3).
      REAL(R8), INTENT(IN) :: EXPANSION_VALUE                            ! Input real (real64): expansion_value.
      REAL(R8), INTENT(IN) :: EXPANSION_GRADIENT(3)                      ! Input real (real64): expansion_gradient(3).
      REAL(R8), INTENT(OUT) :: VALUE                                     ! Output real (real64): value.
      REAL(R8), INTENT(OUT) :: GRADIENT(3)                               ! Output real (real64): gradient(3).

      VALUE = STRUCTURAL_VALUE*EXPANSION_VALUE                           ! Set value to structural_value*expansion_value.
      GRADIENT = STRUCTURAL_GRADIENT*EXPANSION_VALUE+                    ! Set gradient to structural_gradient*expansion_value+ structural_value*expansion_gradient.
     &           STRUCTURAL_VALUE*EXPANSION_GRADIENT

      END SUBROUTINE COMPOSE_PRODUCT_BASIS                               ! End of the subroutine compose product basis.

      SUBROUTINE BUILD_DISPLACEMENT_COLUMN(COMPONENT, GRADIENT,          ! Subroutine build displacement column takes component, gradient, column, status.
     &                                     COLUMN, STATUS)

      INTEGER(I4), INTENT(IN) :: COMPONENT                               ! Input integer (int32): component.
      REAL(R8), INTENT(IN) :: GRADIENT(3)                                ! Input real (real64): gradient(3).
      REAL(R8), INTENT(OUT) :: COLUMN(6)                                 ! Output real (real64): column(6).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      COLUMN = 0.0_R8                                                    ! Set column to zero.
      SELECT CASE(COMPONENT)                                             ! Choose according to the value of component:
      CASE(1_I4)                                                         ! Case 1:
!       U: EXX=U,X; GXZ=U,Z; GXY=U,Y.
        COLUMN(1) = GRADIENT(1)                                          ! Set column(1) to gradient(1).
        COLUMN(4) = GRADIENT(3)                                          ! Set column(4) to gradient(3).
        COLUMN(6) = GRADIENT(2)                                          ! Set column(6) to gradient(2).
      CASE(2_I4)                                                         ! Case 2:
!       V: EYY=V,Y; GYZ=V,Z; GXY=V,X.
        COLUMN(2) = GRADIENT(2)                                          ! Set column(2) to gradient(2).
        COLUMN(5) = GRADIENT(3)                                          ! Set column(5) to gradient(3).
        COLUMN(6) = GRADIENT(1)                                          ! Set column(6) to gradient(1).
      CASE(3_I4)                                                         ! Case 3:
!       W: EZZ=W,Z; GXZ=W,X; GYZ=W,Y.
        COLUMN(3) = GRADIENT(3)                                          ! Set column(3) to gradient(3).
        COLUMN(4) = GRADIENT(1)                                          ! Set column(4) to gradient(1).
        COLUMN(5) = GRADIENT(2)                                          ! Set column(5) to gradient(2).
      CASE DEFAULT                                                       ! In every other case:
        CALL SET_ERROR(STATUS, 'BUILD_DISPLACEMENT_COLUMN',              ! Record an error in status: 'DISPLACEMENT COMPONENT MUST BE 1, 2 OR 3'.
     &                 'DISPLACEMENT COMPONENT MUST BE 1, 2 OR 3')
      END SELECT                                                         ! End of the case selection.

      END SUBROUTINE BUILD_DISPLACEMENT_COLUMN                           ! End of the subroutine build displacement column.

      SUBROUTINE BUILD_DISPLACEMENT_OPERATOR(GRADIENT,                   ! Subroutine build displacement operator takes gradient, operator, status.
     &                                       OPERATOR, STATUS)

      REAL(R8), INTENT(IN) :: GRADIENT(3)                                ! Input real (real64): gradient(3).
      REAL(R8), INTENT(OUT) :: OPERATOR(6,3)                             ! Output real (real64): operator(6,3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      INTEGER(I4) :: COMPONENT                                           ! Integer (int32): component.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPERATOR = 0.0_R8                                                  ! Set operator to zero.
      DO COMPONENT = 1_I4, 3_I4                                          ! Loop component from 1 to 3:
        CALL BUILD_DISPLACEMENT_COLUMN(COMPONENT, GRADIENT,              ! Call build displacement column with component, gradient, operator(:,component), local_status.
     &       OPERATOR(:,COMPONENT), LOCAL_STATUS)
        IF (LOCAL_STATUS%CODE .GE. 2_I4) THEN                            ! If local_status.code >= 2:
          CALL SET_ERROR(STATUS, 'BUILD_DISPLACEMENT_OPERATOR',          ! Record an error in status: trim(local_status.message).
     &                   TRIM(LOCAL_STATUS%MESSAGE))
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_DISPLACEMENT_OPERATOR                         ! End of the subroutine build displacement operator.

      END MODULE MUL2_LINEAR_KINEMATICS                                  ! End of the module mul2 linear kinematics.
