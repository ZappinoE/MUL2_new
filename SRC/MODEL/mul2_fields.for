!=======================================================================
!  SPATIAL FIELDS (FIELDS.DAT): F(X,Y,Z) = SUM OF TERMS.
!
!  A BOUNDARY CONDITION MAY END WITH A FIELD NUMBER: ITS VALUE IS THEN
!  MULTIPLIED BY F AT THE POSITION OF EVERY NODE (OR INTEGRATION POINT
!  OF A SURFACE LOAD). TERMS (SAME GRAMMAR AS THE HISTORICAL CODE):
!      CONST C1                 C1
!      X-EXP C1 C2              C1 X**C2          (ALSO Y-EXP, Z-EXP)
!      COS-X C1 C2 C3           C1 COS(C2 X + C3) (ALSO COS-Y, COS-Z)
!      SIN-X C1 C2 C3           C1 SIN(C2 X + C3) (ALSO SIN-Y, SIN-Z)
!      ATNZX C1 C2 C3           C1 ATAN2(Z-C2,X-C3) IN DEGREES
!      B-SIN C1 C2 C3 C4 C5     C1 SIN(C2 PI X/C3) SIN(C4 PI Y/C5)
!=======================================================================
      MODULE MUL2_FIELDS                                                 ! Module mul2 fields begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: TERM_CONSTANT = 1_I4             ! Constant public integer (int32): term_constant = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_POWER_X = 2_I4              ! Constant public integer (int32): term_power_x = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_POWER_Y = 3_I4              ! Constant public integer (int32): term_power_y = 3.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_POWER_Z = 4_I4              ! Constant public integer (int32): term_power_z = 4.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_ARCTAN = 5_I4               ! Constant public integer (int32): term_arctan = 5.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_COS_X = 6_I4                ! Constant public integer (int32): term_cos_x = 6.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_COS_Y = 7_I4                ! Constant public integer (int32): term_cos_y = 7.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_SIN_X = 8_I4                ! Constant public integer (int32): term_sin_x = 8.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_SIN_Y = 9_I4                ! Constant public integer (int32): term_sin_y = 9.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_BI_SINE = 10_I4             ! Constant public integer (int32): term_bi_sine = 10.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_COS_Z = 11_I4               ! Constant public integer (int32): term_cos_z = 11.
      INTEGER(I4), PARAMETER, PUBLIC :: TERM_SIN_Z = 12_I4               ! Constant public integer (int32): term_sin_z = 12.

      REAL(R8), PARAMETER :: PI = 3.14159265358979323846_R8              ! Constant real (real64): pi = 3.14159265358979323846.

      TYPE, PUBLIC :: FIELD_TYPE                                         ! Definition of the derived type field type.
        INTEGER(I4) :: ID = 0_I4                                         ! Integer (int32): id = 0.
        INTEGER(I4), ALLOCATABLE :: TERM(:)                              ! Allocatable integer (int32): term(:).
        REAL(R8), ALLOCATABLE :: CONSTANT(:,:)                           ! Allocatable real (real64): constant(:,:).
      END TYPE FIELD_TYPE                                                ! End of the type definition field type.

      TYPE, PUBLIC :: FIELD_DB_TYPE                                      ! Definition of the derived type field db type.
        TYPE(FIELD_TYPE), ALLOCATABLE :: ITEM(:)                         ! Allocatable of type field_type: item(:).
      END TYPE FIELD_DB_TYPE                                             ! End of the type definition field db type.

      PUBLIC :: FIND_FIELD_INDEX                                         ! Export: find field index.
      PUBLIC :: EVALUATE_FIELD                                           ! Export: evaluate field.

      CONTAINS                                                           ! The procedures of the module follow.

      INTEGER(I4) FUNCTION FIND_FIELD_INDEX(DATABASE, ID)                ! Function find field index takes database, id.

      TYPE(FIELD_DB_TYPE), INTENT(IN) :: DATABASE                        ! Input of type field_db_type: database.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_FIELD_INDEX = 0_I4                                            ! Set find_field_index to zero.
      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (DATABASE%ITEM(I)%ID .EQ. ID) THEN                            ! If database.item(i).id = id:
          FIND_FIELD_INDEX = I                                           ! Set find_field_index to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_FIELD_INDEX                                      ! End of the function find field index.

!  VALUE OF FIELD ID AT A POINT (1 FOR ID = 0: NO FIELD).
      REAL(R8) FUNCTION EVALUATE_FIELD(DATABASE, ID, X, Y, Z)            ! Function evaluate field takes database, id, x, y, z.

      TYPE(FIELD_DB_TYPE), INTENT(IN) :: DATABASE                        ! Input of type field_db_type: database.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      REAL(R8), INTENT(IN) :: X                                          ! Input real (real64): x.
      REAL(R8), INTENT(IN) :: Y                                          ! Input real (real64): y.
      REAL(R8), INTENT(IN) :: Z                                          ! Input real (real64): z.
      INTEGER(I4) :: INDEX                                               ! Integer (int32): index.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      EVALUATE_FIELD = 1.0_R8                                            ! Set evaluate_field to 1.0.
      IF (ID .EQ. 0_I4) RETURN                                           ! If id = 0, return to the caller.
      INDEX = FIND_FIELD_INDEX(DATABASE, ID)                             ! Set index to find_field_index(database, id).
      IF (INDEX .EQ. 0_I4) RETURN                                        ! If index = 0, return to the caller.
      EVALUATE_FIELD = 0.0_R8                                            ! Set evaluate_field to zero.
      ASSOCIATE (C => DATABASE%ITEM(INDEX)%CONSTANT)                     ! Use short names (c) for longer expressions:
        DO I = 1_I4, SIZE(DATABASE%ITEM(INDEX)%TERM)                     ! Loop i from 1 to size(database.item(index).term):
          SELECT CASE (DATABASE%ITEM(INDEX)%TERM(I))                     ! Choose according to the value of database.item(index).term(i):
          CASE (TERM_CONSTANT)                                           ! Case term_constant:
            EVALUATE_FIELD = EVALUATE_FIELD + C(I,1)                     ! Add c(i,1) to evaluate_field.
          CASE (TERM_POWER_X)                                            ! Case term_power_x:
            EVALUATE_FIELD = EVALUATE_FIELD + C(I,1)*X**C(I,2)           ! Add c(i,1)*x**c(i,2) to evaluate_field.
          CASE (TERM_POWER_Y)                                            ! Case term_power_y:
            EVALUATE_FIELD = EVALUATE_FIELD + C(I,1)*Y**C(I,2)           ! Add c(i,1)*y**c(i,2) to evaluate_field.
          CASE (TERM_POWER_Z)                                            ! Case term_power_z:
            EVALUATE_FIELD = EVALUATE_FIELD + C(I,1)*Z**C(I,2)           ! Add c(i,1)*z**c(i,2) to evaluate_field.
          CASE (TERM_ARCTAN)                                             ! Case term_arctan:
            EVALUATE_FIELD = EVALUATE_FIELD + C(I,1)*                    ! Add c(i,1)* atan2(z-c(i,2),x-c(i,3))*180.0/pi to evaluate_field.
     &        ATAN2(Z-C(I,2),X-C(I,3))*180.0_R8/PI
          CASE (TERM_COS_X)                                              ! Case term_cos_x:
            EVALUATE_FIELD = EVALUATE_FIELD +                            ! Add c(i,1)*cos(c(i,2)*x+c(i,3)) to evaluate_field.
     &        C(I,1)*COS(C(I,2)*X+C(I,3))
          CASE (TERM_COS_Y)                                              ! Case term_cos_y:
            EVALUATE_FIELD = EVALUATE_FIELD +                            ! Add c(i,1)*cos(c(i,2)*y+c(i,3)) to evaluate_field.
     &        C(I,1)*COS(C(I,2)*Y+C(I,3))
          CASE (TERM_COS_Z)                                              ! Case term_cos_z:
            EVALUATE_FIELD = EVALUATE_FIELD +                            ! Add c(i,1)*cos(c(i,2)*z+c(i,3)) to evaluate_field.
     &        C(I,1)*COS(C(I,2)*Z+C(I,3))
          CASE (TERM_SIN_X)                                              ! Case term_sin_x:
            EVALUATE_FIELD = EVALUATE_FIELD +                            ! Add c(i,1)*sin(c(i,2)*x+c(i,3)) to evaluate_field.
     &        C(I,1)*SIN(C(I,2)*X+C(I,3))
          CASE (TERM_SIN_Y)                                              ! Case term_sin_y:
            EVALUATE_FIELD = EVALUATE_FIELD +                            ! Add c(i,1)*sin(c(i,2)*y+c(i,3)) to evaluate_field.
     &        C(I,1)*SIN(C(I,2)*Y+C(I,3))
          CASE (TERM_SIN_Z)                                              ! Case term_sin_z:
            EVALUATE_FIELD = EVALUATE_FIELD +                            ! Add c(i,1)*sin(c(i,2)*z+c(i,3)) to evaluate_field.
     &        C(I,1)*SIN(C(I,2)*Z+C(I,3))
          CASE (TERM_BI_SINE)                                            ! Case term_bi_sine:
            EVALUATE_FIELD = EVALUATE_FIELD + C(I,1)*                    ! Add c(i,1)* sin(c(i,2)*x*pi/c(i,3))*sin(c(i,4)*y*pi/c(i,5)) to evaluate_field.
     &        SIN(C(I,2)*X*PI/C(I,3))*SIN(C(I,4)*Y*PI/C(I,5))
          END SELECT                                                     ! End of the case selection.
        END DO                                                           ! End of the loop.
      END ASSOCIATE                                                      ! End of the shorthand names.

      END FUNCTION EVALUATE_FIELD                                        ! End of the function evaluate field.

      END MODULE MUL2_FIELDS                                             ! End of the module mul2 fields.
