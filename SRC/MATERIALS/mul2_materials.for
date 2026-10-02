!=======================================================================
!  LINEAR MECHANICAL MATERIAL DATA AND CONSTITUTIVE BUILDERS.
!=======================================================================
      MODULE MUL2_MATERIALS                                              ! Module mul2 materials begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: MATERIAL_ISOTROPIC = 1_I4        ! Constant public integer (int32): material_isotropic = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: MATERIAL_ORTHOTROPIC = 2_I4      ! Constant public integer (int32): material_orthotropic = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: MATERIAL_ANISOTROPIC = 3_I4      ! Constant public integer (int32): material_anisotropic = 3.

      TYPE, PUBLIC :: MATERIAL_TYPE                                      ! Definition of the derived type material type.
        INTEGER(I4) :: ID = 0_I4                                         ! Integer (int32): id = 0.
        INTEGER(I4) :: MODEL = 0_I4                                      ! Integer (int32): model = 0.
        REAL(R8) :: DENSITY = 0.0_R8                                     ! Real (real64): density = 0.0.
!       MATERIAL AXES ARE (T,L,Z); VOIGT IS (TT,LL,ZZ,TZ,LZ,TL).
        REAL(R8) :: STIFFNESS(6,6) = 0.0_R8                              ! Real (real64): stiffness(6,6) = 0.0.
!       PIEZOELECTRIC STRESS COEFFICIENTS E(I,J): ELECTRIC DIRECTION
!       I = T,L,Z, STRAIN J IN THE VOIGT ORDER OF THE STIFFNESS, AND
!       DIELECTRIC PERMITTIVITY (MATERIAL AXES), BOTH AT CONSTANT STRAIN.
        LOGICAL :: HAS_PIEZO = .FALSE.                                   ! Logical: has_piezo = false.
        REAL(R8) :: PIEZO(3,6) = 0.0_R8                                  ! Real (real64): piezo(3,6) = 0.0.
        REAL(R8) :: PERMITTIVITY(3,3) = 0.0_R8                           ! Real (real64): permittivity(3,3) = 0.0.
!       THERMAL EXPANSION (STRAIN PER KELVIN, VOIGT ORDER OF THE
!       STIFFNESS, MATERIAL AXES) AND HEAT CONDUCTIVITY (MATERIAL AXES).
        LOGICAL :: HAS_EXPANSION = .FALSE.                               ! Logical: has_expansion = false.
        LOGICAL :: HAS_CONDUCTION = .FALSE.                              ! Logical: has_conduction = false.
        REAL(R8) :: EXPANSION(6) = 0.0_R8                                ! Real (real64): expansion(6) = 0.0.
        REAL(R8) :: CONDUCTIVITY(3,3) = 0.0_R8                           ! Real (real64): conductivity(3,3) = 0.0.
!       PYROELECTRIC COEFFICIENT (D PER KELVIN, MATERIAL AXES) MEASURED
!       AT ZERO STRESS: D = P T WHEN THE BODY EXPANDS FREELY AT E = 0.
        LOGICAL :: HAS_PYRO = .FALSE.                                    ! Logical: has_pyro = false.
        REAL(R8) :: PYRO(3) = 0.0_R8                                     ! Real (real64): pyro(3) = 0.0.
!       SPECIFIC HEAT [J/(KG K)] (THERMAL CAPACITY = DENSITY * C).
        REAL(R8) :: SPECIFIC_HEAT = 0.0_R8                               ! Real (real64): specific_heat = 0.0.
      END TYPE MATERIAL_TYPE                                             ! End of the type definition material type.

      TYPE, PUBLIC :: MATERIAL_DB_TYPE                                   ! Definition of the derived type material db type.
        TYPE(MATERIAL_TYPE), ALLOCATABLE :: ITEM(:)                      ! Allocatable of type material_type: item(:).
!       GLOBAL RAYLEIGH DAMPING OF THE DAMP RECORD: C = M_COEFF M +
!       K_COEFF K (HISTORICAL ORDER OF THE RECORD: K THEN M).
        REAL(R8) :: DAMP_MASS = 0.0_R8                                   ! Real (real64): damp_mass = 0.0.
        REAL(R8) :: DAMP_STIFFNESS = 0.0_R8                              ! Real (real64): damp_stiffness = 0.0.
      END TYPE MATERIAL_DB_TYPE                                          ! End of the type definition material db type.

      PUBLIC :: BUILD_ISOTROPIC_MATERIAL                                 ! Export: build isotropic material.
      PUBLIC :: BUILD_ORTHOTROPIC_MATERIAL                               ! Export: build orthotropic material.
      PUBLIC :: BUILD_ANISOTROPIC_MATERIAL                               ! Export: build anisotropic material.
      PUBLIC :: FIND_MATERIAL_INDEX                                      ! Export: find material index.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_ISOTROPIC_MATERIAL(ID, YOUNG, POISSON,            ! Subroutine build isotropic material takes id, young, poisson, density, material, status.
     &                                    DENSITY, MATERIAL, STATUS)

      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      REAL(R8), INTENT(IN) :: YOUNG                                      ! Input real (real64): young.
      REAL(R8), INTENT(IN) :: POISSON                                    ! Input real (real64): poisson.
      REAL(R8), INTENT(IN) :: DENSITY                                    ! Input real (real64): density.
      TYPE(MATERIAL_TYPE), INTENT(OUT) :: MATERIAL                       ! Output of type material_type: material.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: LAMBDA                                                 ! Real (real64): lambda.
      REAL(R8) :: SHEAR                                                  ! Real (real64): shear.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      MATERIAL = MATERIAL_TYPE()                                         ! Set material to material_type().
      IF (ID .LT. 1_I4 .OR. YOUNG .LE. 0.0_R8 .OR.                       ! If id < 1 or young <= 0.0 or density < 0.0 or poisson <= -1.0 or poisson >= 0.5:
     &    DENSITY .LT. 0.0_R8 .OR. POISSON .LE. -1.0_R8 .OR.
     &    POISSON .GE. 0.5_R8) THEN
        CALL SET_ERROR(STATUS, 'BUILD_ISOTROPIC_MATERIAL',               ! Record an error in status: 'INVALID ISOTROPIC MATERIAL PROPERTIES'.
     &                 'INVALID ISOTROPIC MATERIAL PROPERTIES')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      LAMBDA = YOUNG*POISSON/                                            ! Set lambda to young*poisson/ ((1.0+poisson)*(1.0-2.0*poisson)).
     &         ((1.0_R8+POISSON)*(1.0_R8-2.0_R8*POISSON))
      SHEAR = YOUNG/(2.0_R8*(1.0_R8+POISSON))                            ! Set shear to young/(2.0*(1.0+poisson)).
      MATERIAL%ID = ID                                                   ! Set material.id to id.
      MATERIAL%MODEL = MATERIAL_ISOTROPIC                                ! Set material.model to material_isotropic.
      MATERIAL%DENSITY = DENSITY                                         ! Set material.density to density.
      MATERIAL%STIFFNESS = 0.0_R8                                        ! Set material.stiffness to zero.
      DO I = 1_I4, 3_I4                                                  ! Loop i from 1 to 3:
        DO J = 1_I4, 3_I4                                                ! Loop j from 1 to 3:
          MATERIAL%STIFFNESS(I,J) = LAMBDA                               ! Set material.stiffness(i,j) to lambda.
        END DO                                                           ! End of the loop.
        MATERIAL%STIFFNESS(I,I) = LAMBDA + 2.0_R8*SHEAR                  ! Set material.stiffness(i,i) to lambda + 2.0*shear.
      END DO                                                             ! End of the loop.
      MATERIAL%STIFFNESS(4,4) = SHEAR                                    ! Set material.stiffness(4,4) to shear.
      MATERIAL%STIFFNESS(5,5) = SHEAR                                    ! Set material.stiffness(5,5) to shear.
      MATERIAL%STIFFNESS(6,6) = SHEAR                                    ! Set material.stiffness(6,6) to shear.

      END SUBROUTINE BUILD_ISOTROPIC_MATERIAL                            ! End of the subroutine build isotropic material.

      SUBROUTINE BUILD_ORTHOTROPIC_MATERIAL(ID, YOUNG_T,                 ! Subroutine build orthotropic material takes id, young t, young l, young z, nu lt, nu lz, nu tz, shear lt, s...
     &     YOUNG_L, YOUNG_Z, NU_LT, NU_LZ, NU_TZ,
     &     SHEAR_LT, SHEAR_LZ, SHEAR_TZ, DENSITY,
     &     MATERIAL, STATUS)

      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      REAL(R8), INTENT(IN) :: YOUNG_T                                    ! Input real (real64): young_t.
      REAL(R8), INTENT(IN) :: YOUNG_L                                    ! Input real (real64): young_l.
      REAL(R8), INTENT(IN) :: YOUNG_Z                                    ! Input real (real64): young_z.
      REAL(R8), INTENT(IN) :: NU_LT                                      ! Input real (real64): nu_lt.
      REAL(R8), INTENT(IN) :: NU_LZ                                      ! Input real (real64): nu_lz.
      REAL(R8), INTENT(IN) :: NU_TZ                                      ! Input real (real64): nu_tz.
      REAL(R8), INTENT(IN) :: SHEAR_LT                                   ! Input real (real64): shear_lt.
      REAL(R8), INTENT(IN) :: SHEAR_LZ                                   ! Input real (real64): shear_lz.
      REAL(R8), INTENT(IN) :: SHEAR_TZ                                   ! Input real (real64): shear_tz.
      REAL(R8), INTENT(IN) :: DENSITY                                    ! Input real (real64): density.
      TYPE(MATERIAL_TYPE), INTENT(OUT) :: MATERIAL                       ! Output of type material_type: material.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: COMPLIANCE(3,3)                                        ! Real (real64): compliance(3,3).
      REAL(R8) :: NORMAL_STIFFNESS(3,3)                                  ! Real (real64): normal_stiffness(3,3).
      REAL(R8) :: DETERMINANT                                            ! Real (real64): determinant.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      MATERIAL = MATERIAL_TYPE()                                         ! Set material to material_type().
      IF (ID .LT. 1_I4 .OR. MIN(YOUNG_T,YOUNG_L,YOUNG_Z)                 ! If id < 1 or min(young_t,young_l,young_z) <= 0.0 or min(shear_lt,shear_lz,shear_tz) <= 0.0 or density < 0.0:
     &    .LE. 0.0_R8 .OR.
     &    MIN(SHEAR_LT,SHEAR_LZ,SHEAR_TZ) .LE. 0.0_R8 .OR.
     &    DENSITY .LT. 0.0_R8) THEN
        CALL SET_ERROR(STATUS, 'BUILD_ORTHOTROPIC_MATERIAL',             ! Record an error in status: 'INVALID ORTHOTROPIC MATERIAL PROPERTIES'.
     &                 'INVALID ORTHOTROPIC MATERIAL PROPERTIES')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

!     NU_LT=NU_21, NU_LZ=NU_23, NU_TZ=NU_13 IN (T,L,Z) AXES.
      COMPLIANCE = 0.0_R8                                                ! Set compliance to zero.
      COMPLIANCE(1,1) = 1.0_R8/YOUNG_T                                   ! Set compliance(1,1) to 1.0/young_t.
      COMPLIANCE(2,2) = 1.0_R8/YOUNG_L                                   ! Set compliance(2,2) to 1.0/young_l.
      COMPLIANCE(3,3) = 1.0_R8/YOUNG_Z                                   ! Set compliance(3,3) to 1.0/young_z.
      COMPLIANCE(1,2) = -NU_LT/YOUNG_L                                   ! Set compliance(1,2) to -nu_lt/young_l.
      COMPLIANCE(2,1) = COMPLIANCE(1,2)                                  ! Set compliance(2,1) to compliance(1,2).
      COMPLIANCE(2,3) = -NU_LZ/YOUNG_L                                   ! Set compliance(2,3) to -nu_lz/young_l.
      COMPLIANCE(3,2) = COMPLIANCE(2,3)                                  ! Set compliance(3,2) to compliance(2,3).
      COMPLIANCE(1,3) = -NU_TZ/YOUNG_T                                   ! Set compliance(1,3) to -nu_tz/young_t.
      COMPLIANCE(3,1) = COMPLIANCE(1,3)                                  ! Set compliance(3,1) to compliance(1,3).

      IF (COMPLIANCE(1,1)*COMPLIANCE(2,2)-                               ! If compliance(1,1)*compliance(2,2)- compliance(1,2)**2 <= 0.0:
     &    COMPLIANCE(1,2)**2 .LE. 0.0_R8) THEN
        CALL SET_ERROR(STATUS, 'BUILD_ORTHOTROPIC_MATERIAL',             ! Record an error in status: 'ORTHOTROPIC COMPLIANCE IS NOT POSITIVE'.
     &                 'ORTHOTROPIC COMPLIANCE IS NOT POSITIVE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL INVERT_SYMMETRIC_3X3(COMPLIANCE, NORMAL_STIFFNESS,            ! Call invert symmetric 3x3 with compliance, normal_stiffness, determinant.
     &                          DETERMINANT)
      IF (DETERMINANT .LE. 0.0_R8) THEN                                  ! If determinant <= 0.0:
        CALL SET_ERROR(STATUS, 'BUILD_ORTHOTROPIC_MATERIAL',             ! Record an error in status: 'ORTHOTROPIC COMPLIANCE IS SINGULAR'.
     &                 'ORTHOTROPIC COMPLIANCE IS SINGULAR')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      MATERIAL%ID = ID                                                   ! Set material.id to id.
      MATERIAL%MODEL = MATERIAL_ORTHOTROPIC                              ! Set material.model to material_orthotropic.
      MATERIAL%DENSITY = DENSITY                                         ! Set material.density to density.
      MATERIAL%STIFFNESS = 0.0_R8                                        ! Set material.stiffness to zero.
      MATERIAL%STIFFNESS(1:3,1:3) = NORMAL_STIFFNESS                     ! Set material.stiffness(1:3,1:3) to normal_stiffness.
      MATERIAL%STIFFNESS(4,4) = SHEAR_TZ                                 ! Set material.stiffness(4,4) to shear_tz.
      MATERIAL%STIFFNESS(5,5) = SHEAR_LZ                                 ! Set material.stiffness(5,5) to shear_lz.
      MATERIAL%STIFFNESS(6,6) = SHEAR_LT                                 ! Set material.stiffness(6,6) to shear_lt.

      END SUBROUTINE BUILD_ORTHOTROPIC_MATERIAL                          ! End of the subroutine build orthotropic material.

      SUBROUTINE BUILD_ANISOTROPIC_MATERIAL(ID, STIFFNESS,               ! Subroutine build anisotropic material takes id, stiffness, density, material, status.
     &                                      DENSITY, MATERIAL,
     &                                      STATUS)

      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      REAL(R8), INTENT(IN) :: STIFFNESS(6,6)                             ! Input real (real64): stiffness(6,6).
      REAL(R8), INTENT(IN) :: DENSITY                                    ! Input real (real64): density.
      TYPE(MATERIAL_TYPE), INTENT(OUT) :: MATERIAL                       ! Output of type material_type: material.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      MATERIAL = MATERIAL_TYPE()                                         ! Set material to material_type().
      IF (ID .LT. 1_I4 .OR. DENSITY .LT. 0.0_R8) THEN                    ! If id < 1 or density < 0.0:
        CALL SET_ERROR(STATUS, 'BUILD_ANISOTROPIC_MATERIAL',             ! Record an error in status: 'INVALID ANISOTROPIC MATERIAL PROPERTIES'.
     &                 'INVALID ANISOTROPIC MATERIAL PROPERTIES')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      MATERIAL%ID = ID                                                   ! Set material.id to id.
      MATERIAL%MODEL = MATERIAL_ANISOTROPIC                              ! Set material.model to material_anisotropic.
      MATERIAL%DENSITY = DENSITY                                         ! Set material.density to density.
      MATERIAL%STIFFNESS = STIFFNESS                                     ! Set material.stiffness to stiffness.

      END SUBROUTINE BUILD_ANISOTROPIC_MATERIAL                          ! End of the subroutine build anisotropic material.

      INTEGER(I4) FUNCTION FIND_MATERIAL_INDEX(DATABASE, ID)             ! Function find material index takes database, id.

      TYPE(MATERIAL_DB_TYPE), INTENT(IN) :: DATABASE                     ! Input of type material_db_type: database.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_MATERIAL_INDEX = 0_I4                                         ! Set find_material_index to zero.
      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (DATABASE%ITEM(I)%ID .EQ. ID) THEN                            ! If database.item(i).id = id:
          FIND_MATERIAL_INDEX = I                                        ! Set find_material_index to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_MATERIAL_INDEX                                   ! End of the function find material index.

      SUBROUTINE INVERT_SYMMETRIC_3X3(A, INVERSE, DETERMINANT)           ! Subroutine invert symmetric 3x3 takes a, inverse, determinant.

      REAL(R8), INTENT(IN) :: A(3,3)                                     ! Input real (real64): a(3,3).
      REAL(R8), INTENT(OUT) :: INVERSE(3,3)                              ! Output real (real64): inverse(3,3).
      REAL(R8), INTENT(OUT) :: DETERMINANT                               ! Output real (real64): determinant.

      DETERMINANT = A(1,1)*(A(2,2)*A(3,3)-A(2,3)*A(3,2))-                ! Set determinant to a(1,1)*(a(2,2)*a(3,3)-a(2,3)*a(3,2))- a(1,2)*(a(2,1)*a(3,3)-a(2,3)*a(3,1))+ a(1,3)*(a(2,...
     & A(1,2)*(A(2,1)*A(3,3)-A(2,3)*A(3,1))+
     & A(1,3)*(A(2,1)*A(3,2)-A(2,2)*A(3,1))
      INVERSE = 0.0_R8                                                   ! Set inverse to zero.
      IF (ABS(DETERMINANT) .LE. TINY(1.0_R8)) RETURN                     ! If abs(determinant) <= tiny(1.0), return to the caller.
      INVERSE(1,1) = (A(2,2)*A(3,3)-A(2,3)*A(3,2))/DETERMINANT           ! Set inverse(1,1) to (a(2,2)*a(3,3)-a(2,3)*a(3,2))/determinant.
      INVERSE(1,2) = (A(1,3)*A(3,2)-A(1,2)*A(3,3))/DETERMINANT           ! Set inverse(1,2) to (a(1,3)*a(3,2)-a(1,2)*a(3,3))/determinant.
      INVERSE(1,3) = (A(1,2)*A(2,3)-A(1,3)*A(2,2))/DETERMINANT           ! Set inverse(1,3) to (a(1,2)*a(2,3)-a(1,3)*a(2,2))/determinant.
      INVERSE(2,1) = INVERSE(1,2)                                        ! Set inverse(2,1) to inverse(1,2).
      INVERSE(2,2) = (A(1,1)*A(3,3)-A(1,3)*A(3,1))/DETERMINANT           ! Set inverse(2,2) to (a(1,1)*a(3,3)-a(1,3)*a(3,1))/determinant.
      INVERSE(2,3) = (A(1,3)*A(2,1)-A(1,1)*A(2,3))/DETERMINANT           ! Set inverse(2,3) to (a(1,3)*a(2,1)-a(1,1)*a(2,3))/determinant.
      INVERSE(3,1) = INVERSE(1,3)                                        ! Set inverse(3,1) to inverse(1,3).
      INVERSE(3,2) = INVERSE(2,3)                                        ! Set inverse(3,2) to inverse(2,3).
      INVERSE(3,3) = (A(1,1)*A(2,2)-A(1,2)*A(2,1))/DETERMINANT           ! Set inverse(3,3) to (a(1,1)*a(2,2)-a(1,2)*a(2,1))/determinant.

      END SUBROUTINE INVERT_SYMMETRIC_3X3                                ! End of the subroutine invert symmetric 3x3.

      END MODULE MUL2_MATERIALS                                          ! End of the module mul2 materials.
