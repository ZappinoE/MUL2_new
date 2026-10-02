!=======================================================================
!  GENERIC LINEAR CUF FUNDAMENTAL NUCLEI AT ONE INTEGRATION POINT.
!=======================================================================
      MODULE MUL2_FUNDAMENTAL_NUCLEUS                                    ! Module mul2 fundamental nucleus begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: STIFFNESS_NUCLEUS                                        ! Export: stiffness nucleus.
      PUBLIC :: STIFFNESS_BLOCK_NUCLEUS                                  ! Export: stiffness block nucleus.
      PUBLIC :: MASS_NUCLEUS                                             ! Export: mass nucleus.
      PUBLIC :: MASS_BLOCK_NUCLEUS                                       ! Export: mass block nucleus.
      PUBLIC :: ROTATE_BLOCK_TO_GLOBAL                                   ! Export: rotate block to global.

      CONTAINS                                                           ! The procedures of the module follow.

      REAL(R8) FUNCTION STIFFNESS_NUCLEUS(TEST_COLUMN,                   ! Function stiffness nucleus takes test column, stiffness, trial column, integration weight.
     &     STIFFNESS, TRIAL_COLUMN, INTEGRATION_WEIGHT)

      REAL(R8), INTENT(IN) :: TEST_COLUMN(6)                             ! Input real (real64): test_column(6).
      REAL(R8), INTENT(IN) :: STIFFNESS(6,6)                             ! Input real (real64): stiffness(6,6).
      REAL(R8), INTENT(IN) :: TRIAL_COLUMN(6)                            ! Input real (real64): trial_column(6).
      REAL(R8), INTENT(IN) :: INTEGRATION_WEIGHT                         ! Input real (real64): integration_weight.

      STIFFNESS_NUCLEUS = INTEGRATION_WEIGHT*                            ! Set stiffness_nucleus to integration_weight* dot_product(test_column,matmul(stiffness,trial_column)).
     & DOT_PRODUCT(TEST_COLUMN,MATMUL(STIFFNESS,TRIAL_COLUMN))

      END FUNCTION STIFFNESS_NUCLEUS                                     ! End of the function stiffness nucleus.

      SUBROUTINE STIFFNESS_BLOCK_NUCLEUS(TEST_OPERATOR,                  ! Subroutine stiffness block nucleus takes test operator, stiffness, trial operator, integration weight, block.
     &     STIFFNESS, TRIAL_OPERATOR, INTEGRATION_WEIGHT, BLOCK)

      REAL(R8), INTENT(IN) :: TEST_OPERATOR(6,3)                         ! Input real (real64): test_operator(6,3).
      REAL(R8), INTENT(IN) :: STIFFNESS(6,6)                             ! Input real (real64): stiffness(6,6).
      REAL(R8), INTENT(IN) :: TRIAL_OPERATOR(6,3)                        ! Input real (real64): trial_operator(6,3).
      REAL(R8), INTENT(IN) :: INTEGRATION_WEIGHT                         ! Input real (real64): integration_weight.
      REAL(R8), INTENT(OUT) :: BLOCK(3,3)                                ! Output real (real64): block(3,3).

      BLOCK = INTEGRATION_WEIGHT*MATMUL(TRANSPOSE(TEST_OPERATOR),        ! Set block to integration_weight*matmul(transpose(test_operator), matmul(stiffness,trial_operator)).
     &        MATMUL(STIFFNESS,TRIAL_OPERATOR))

      END SUBROUTINE STIFFNESS_BLOCK_NUCLEUS                             ! End of the subroutine stiffness block nucleus.

      REAL(R8) FUNCTION MASS_NUCLEUS(TEST_COMPONENT,                     ! Function mass nucleus takes test component, trial component, test value, trial value, density, integration ...
     &     TRIAL_COMPONENT, TEST_VALUE, TRIAL_VALUE,
     &     DENSITY, INTEGRATION_WEIGHT)

      INTEGER(I4), INTENT(IN) :: TEST_COMPONENT                          ! Input integer (int32): test_component.
      INTEGER(I4), INTENT(IN) :: TRIAL_COMPONENT                         ! Input integer (int32): trial_component.
      REAL(R8), INTENT(IN) :: TEST_VALUE                                 ! Input real (real64): test_value.
      REAL(R8), INTENT(IN) :: TRIAL_VALUE                                ! Input real (real64): trial_value.
      REAL(R8), INTENT(IN) :: DENSITY                                    ! Input real (real64): density.
      REAL(R8), INTENT(IN) :: INTEGRATION_WEIGHT                         ! Input real (real64): integration_weight.

      MASS_NUCLEUS = 0.0_R8                                              ! Set mass_nucleus to zero.
      IF (TEST_COMPONENT .EQ. TRIAL_COMPONENT) THEN                      ! If test_component = trial_component:
        MASS_NUCLEUS = DENSITY*TEST_VALUE*TRIAL_VALUE*                   ! Set mass_nucleus to density*test_value*trial_value* integration_weight.
     &                 INTEGRATION_WEIGHT
      END IF                                                             ! End of the IF block.

      END FUNCTION MASS_NUCLEUS                                          ! End of the function mass nucleus.

      SUBROUTINE MASS_BLOCK_NUCLEUS(TEST_VALUE, TRIAL_VALUE,             ! Subroutine mass block nucleus takes test value, trial value, density, integration weight, block.
     &     DENSITY, INTEGRATION_WEIGHT, BLOCK)

      REAL(R8), INTENT(IN) :: TEST_VALUE                                 ! Input real (real64): test_value.
      REAL(R8), INTENT(IN) :: TRIAL_VALUE                                ! Input real (real64): trial_value.
      REAL(R8), INTENT(IN) :: DENSITY                                    ! Input real (real64): density.
      REAL(R8), INTENT(IN) :: INTEGRATION_WEIGHT                         ! Input real (real64): integration_weight.
      REAL(R8), INTENT(OUT) :: BLOCK(3,3)                                ! Output real (real64): block(3,3).
      REAL(R8) :: VALUE                                                  ! Real (real64): value.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      VALUE = DENSITY*TEST_VALUE*TRIAL_VALUE*INTEGRATION_WEIGHT          ! Set value to density*test_value*trial_value*integration_weight.
      BLOCK = 0.0_R8                                                     ! Set block to zero.
      DO I = 1_I4, 3_I4                                                  ! Loop i from 1 to 3:
        BLOCK(I,I) = VALUE                                               ! Set block(i,i) to value.
      END DO                                                             ! End of the loop.

      END SUBROUTINE MASS_BLOCK_NUCLEUS                                  ! End of the subroutine mass block nucleus.

      SUBROUTINE ROTATE_BLOCK_TO_GLOBAL(BLOCK_LOCAL,                     ! Subroutine rotate block to global takes block local, global to local, block global.
     &     GLOBAL_TO_LOCAL, BLOCK_GLOBAL)

      REAL(R8), INTENT(IN) :: BLOCK_LOCAL(3,3)                           ! Input real (real64): block_local(3,3).
      REAL(R8), INTENT(IN) :: GLOBAL_TO_LOCAL(3,3)                       ! Input real (real64): global_to_local(3,3).
      REAL(R8), INTENT(OUT) :: BLOCK_GLOBAL(3,3)                         ! Output real (real64): block_global(3,3).

      BLOCK_GLOBAL = MATMUL(TRANSPOSE(GLOBAL_TO_LOCAL),                  ! Set block_global to matmul(transpose(global_to_local), matmul(block_local,global_to_local)).
     &               MATMUL(BLOCK_LOCAL,GLOBAL_TO_LOCAL))

      END SUBROUTINE ROTATE_BLOCK_TO_GLOBAL                              ! End of the subroutine rotate block to global.

      END MODULE MUL2_FUNDAMENTAL_NUCLEUS                                ! End of the module mul2 fundamental nucleus.
