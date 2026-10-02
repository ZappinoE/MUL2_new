!=======================================================================
!  SINGLE MATERIAL-ORIENTATION TRANSFORMATION IMPLEMENTATION.
!=======================================================================
      MODULE MUL2_MATERIAL_ROTATIONS                                     ! Module mul2 material rotations begins.

      USE MUL2_KINDS, ONLY: R8                                           ! Use from module mul2 kinds: r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: BUILD_MATERIAL_ROTATION                                  ! Export: build material rotation.
      PUBLIC :: BUILD_ENGINEERING_STRAIN_TRANSFORM                       ! Export: build engineering strain transform.
      PUBLIC :: ROTATE_STIFFNESS                                         ! Export: rotate stiffness.
      PUBLIC :: ROTATE_PIEZO                                             ! Export: rotate piezo.
      PUBLIC :: ROTATE_PERMITTIVITY                                      ! Export: rotate permittivity.
      PUBLIC :: ROTATE_EXPANSION                                         ! Export: rotate expansion.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_MATERIAL_ROTATION(ANGLE_Y_DEG,                    ! Subroutine build material rotation takes angle y deg, angle z deg, material from local.
     &     ANGLE_Z_DEG, MATERIAL_FROM_LOCAL)

      REAL(R8), INTENT(IN) :: ANGLE_Y_DEG                                ! Input real (real64): angle_y_deg.
      REAL(R8), INTENT(IN) :: ANGLE_Z_DEG                                ! Input real (real64): angle_z_deg.
      REAL(R8), INTENT(OUT) :: MATERIAL_FROM_LOCAL(3,3)                  ! Output real (real64): material_from_local(3,3).
      REAL(R8), PARAMETER :: PI = ACOS(-1.0_R8)                          ! Constant real (real64): pi = acos(-1.0).
      REAL(R8) :: ANGLE_Y                                                ! Real (real64): angle_y.
      REAL(R8) :: ANGLE_Z                                                ! Real (real64): angle_z.
      REAL(R8) :: ROTATION_Y(3,3)                                        ! Real (real64): rotation_y(3,3).
      REAL(R8) :: ROTATION_Z(3,3)                                        ! Real (real64): rotation_z(3,3).

      ANGLE_Y = ANGLE_Y_DEG*PI/180.0_R8                                  ! Set angle_y to angle_y_deg*pi/180.0.
      ANGLE_Z = ANGLE_Z_DEG*PI/180.0_R8                                  ! Set angle_z to angle_z_deg*pi/180.0.
      ROTATION_Y = 0.0_R8                                                ! Set rotation_y to zero.
      ROTATION_Z = 0.0_R8                                                ! Set rotation_z to zero.
      ROTATION_Y(1,1) = COS(ANGLE_Y)                                     ! Set rotation_y(1,1) to cos(angle_y).
      ROTATION_Y(1,3) = SIN(ANGLE_Y)                                     ! Set rotation_y(1,3) to sin(angle_y).
      ROTATION_Y(2,2) = 1.0_R8                                           ! Set rotation_y(2,2) to 1.0.
      ROTATION_Y(3,1) = -SIN(ANGLE_Y)                                    ! Set rotation_y(3,1) to -sin(angle_y).
      ROTATION_Y(3,3) = COS(ANGLE_Y)                                     ! Set rotation_y(3,3) to cos(angle_y).
      ROTATION_Z(1,1) = COS(ANGLE_Z)                                     ! Set rotation_z(1,1) to cos(angle_z).
      ROTATION_Z(1,2) = SIN(ANGLE_Z)                                     ! Set rotation_z(1,2) to sin(angle_z).
      ROTATION_Z(2,1) = -SIN(ANGLE_Z)                                    ! Set rotation_z(2,1) to -sin(angle_z).
      ROTATION_Z(2,2) = COS(ANGLE_Z)                                     ! Set rotation_z(2,2) to cos(angle_z).
      ROTATION_Z(3,3) = 1.0_R8                                           ! Set rotation_z(3,3) to 1.0.
      MATERIAL_FROM_LOCAL = MATMUL(ROTATION_Z,ROTATION_Y)                ! Set material_from_local to matmul(rotation_z,rotation_y).

      END SUBROUTINE BUILD_MATERIAL_ROTATION                             ! End of the subroutine build material rotation.

      SUBROUTINE BUILD_ENGINEERING_STRAIN_TRANSFORM(A, TRANSFORM)        ! Subroutine build engineering strain transform takes a, transform.

      REAL(R8), INTENT(IN) :: A(3,3)                                     ! Input real (real64): a(3,3).
      REAL(R8), INTENT(OUT) :: TRANSFORM(6,6)                            ! Output real (real64): transform(6,6).

      TRANSFORM = 0.0_R8                                                 ! Set transform to zero.
      TRANSFORM(1,1:3) = [A(1,1)**2,A(1,2)**2,A(1,3)**2]                 ! Set transform(1,1:3) to [a(1,1)**2,a(1,2)**2,a(1,3)**2].
      TRANSFORM(1,4:6) = [A(1,3)*A(1,1),                                 ! Set transform(1,4:6) to [a(1,3)*a(1,1), a(1,2)*a(1,3),a(1,2)*a(1,1)].
     &                    A(1,2)*A(1,3),A(1,2)*A(1,1)]
      TRANSFORM(2,1:3) = [A(2,1)**2,A(2,2)**2,A(2,3)**2]                 ! Set transform(2,1:3) to [a(2,1)**2,a(2,2)**2,a(2,3)**2].
      TRANSFORM(2,4:6) = [A(2,3)*A(2,1),                                 ! Set transform(2,4:6) to [a(2,3)*a(2,1), a(2,3)*a(2,2),a(2,2)*a(2,1)].
     &                    A(2,3)*A(2,2),A(2,2)*A(2,1)]
      TRANSFORM(3,1:3) = [A(3,1)**2,A(3,2)**2,A(3,3)**2]                 ! Set transform(3,1:3) to [a(3,1)**2,a(3,2)**2,a(3,3)**2].
      TRANSFORM(3,4:6) = [A(3,3)*A(3,1),                                 ! Set transform(3,4:6) to [a(3,3)*a(3,1), a(3,3)*a(3,2),a(3,2)*a(3,1)].
     &                    A(3,3)*A(3,2),A(3,2)*A(3,1)]
      TRANSFORM(4,1:3) = 2.0_R8*                                         ! Set transform(4,1:3) to 2.0* [a(3,1)*a(1,1),a(3,2)*a(1,2), a(3,3)*a(1,3)].
     &                   [A(3,1)*A(1,1),A(3,2)*A(1,2),
     &                    A(3,3)*A(1,3)]
      TRANSFORM(4,4:6) =                                                 ! Set transform(4,4:6) to [a(3,3)*a(1,1)+a(3,1)*a(1,3), a(3,3)*a(1,2)+a(3,2)*a(1,3), a(3,1)*a(1,2)+a(3,2)*a(1...
     & [A(3,3)*A(1,1)+A(3,1)*A(1,3),
     &  A(3,3)*A(1,2)+A(3,2)*A(1,3),
     &  A(3,1)*A(1,2)+A(3,2)*A(1,1)]
      TRANSFORM(5,1:3) = 2.0_R8*                                         ! Set transform(5,1:3) to 2.0* [a(3,1)*a(2,1),a(3,2)*a(2,2), a(3,3)*a(2,3)].
     &                   [A(3,1)*A(2,1),A(3,2)*A(2,2),
     &                    A(3,3)*A(2,3)]
      TRANSFORM(5,4:6) =                                                 ! Set transform(5,4:6) to [a(3,3)*a(2,1)+a(3,1)*a(2,3), a(3,3)*a(2,2)+a(3,2)*a(2,3), a(3,1)*a(2,2)+a(3,2)*a(2...
     & [A(3,3)*A(2,1)+A(3,1)*A(2,3),
     &  A(3,3)*A(2,2)+A(3,2)*A(2,3),
     &  A(3,1)*A(2,2)+A(3,2)*A(2,1)]
      TRANSFORM(6,1:3) = 2.0_R8*                                         ! Set transform(6,1:3) to 2.0* [a(2,1)*a(1,1),a(1,2)*a(2,2), a(1,3)*a(2,3)].
     &                   [A(2,1)*A(1,1),A(1,2)*A(2,2),
     &                    A(1,3)*A(2,3)]
      TRANSFORM(6,4:6) =                                                 ! Set transform(6,4:6) to [a(1,3)*a(2,1)+a(1,1)*a(2,3), a(1,3)*a(2,2)+a(1,2)*a(2,3), a(1,1)*a(2,2)+a(1,2)*a(2...
     & [A(1,3)*A(2,1)+A(1,1)*A(2,3),
     &  A(1,3)*A(2,2)+A(1,2)*A(2,3),
     &  A(1,1)*A(2,2)+A(1,2)*A(2,1)]

      END SUBROUTINE BUILD_ENGINEERING_STRAIN_TRANSFORM                  ! End of the subroutine build engineering strain transform.

      SUBROUTINE ROTATE_STIFFNESS(STIFFNESS_MATERIAL,                    ! Subroutine rotate stiffness takes stiffness material, material from reference, stiffness reference.
     &     MATERIAL_FROM_REFERENCE, STIFFNESS_REFERENCE)

      REAL(R8), INTENT(IN) :: STIFFNESS_MATERIAL(6,6)                    ! Input real (real64): stiffness_material(6,6).
      REAL(R8), INTENT(IN) :: MATERIAL_FROM_REFERENCE(3,3)               ! Input real (real64): material_from_reference(3,3).
      REAL(R8), INTENT(OUT) :: STIFFNESS_REFERENCE(6,6)                  ! Output real (real64): stiffness_reference(6,6).
      REAL(R8) :: TRANSFORM(6,6)                                         ! Real (real64): transform(6,6).

      CALL BUILD_ENGINEERING_STRAIN_TRANSFORM(                           ! Call build engineering strain transform with material_from_reference, transform.
     &     MATERIAL_FROM_REFERENCE, TRANSFORM)
      STIFFNESS_REFERENCE = MATMUL(TRANSPOSE(TRANSFORM),                 ! Set stiffness_reference to matmul(transpose(transform), matmul(stiffness_material,transform)).
     &                   MATMUL(STIFFNESS_MATERIAL,TRANSFORM))

      END SUBROUTINE ROTATE_STIFFNESS                                    ! End of the subroutine rotate stiffness.

!  E_LOCAL = A^T E_MATERIAL T (D = E S: D VECTOR, S ENGINEERING STRAIN).
      SUBROUTINE ROTATE_PIEZO(PIEZO_MATERIAL, MATERIAL_FROM_REFERENCE,   ! Subroutine rotate piezo takes piezo material, material from reference, piezo reference.
     &                        PIEZO_REFERENCE)

      REAL(R8), INTENT(IN) :: PIEZO_MATERIAL(3,6)                        ! Input real (real64): piezo_material(3,6).
      REAL(R8), INTENT(IN) :: MATERIAL_FROM_REFERENCE(3,3)               ! Input real (real64): material_from_reference(3,3).
      REAL(R8), INTENT(OUT) :: PIEZO_REFERENCE(3,6)                      ! Output real (real64): piezo_reference(3,6).
      REAL(R8) :: TRANSFORM(6,6)                                         ! Real (real64): transform(6,6).

      CALL BUILD_ENGINEERING_STRAIN_TRANSFORM(                           ! Call build engineering strain transform with material_from_reference, transform.
     &     MATERIAL_FROM_REFERENCE, TRANSFORM)
      PIEZO_REFERENCE = MATMUL(TRANSPOSE(MATERIAL_FROM_REFERENCE),       ! Set piezo_reference to matmul(transpose(material_from_reference), matmul(piezo_material,transform)).
     &                  MATMUL(PIEZO_MATERIAL,TRANSFORM))

      END SUBROUTINE ROTATE_PIEZO                                        ! End of the subroutine rotate piezo.

      SUBROUTINE ROTATE_PERMITTIVITY(PERMITTIVITY_MATERIAL,              ! Subroutine rotate permittivity takes permittivity material, material from reference, permittivity reference.
     &     MATERIAL_FROM_REFERENCE, PERMITTIVITY_REFERENCE)

      REAL(R8), INTENT(IN) :: PERMITTIVITY_MATERIAL(3,3)                 ! Input real (real64): permittivity_material(3,3).
      REAL(R8), INTENT(IN) :: MATERIAL_FROM_REFERENCE(3,3)               ! Input real (real64): material_from_reference(3,3).
      REAL(R8), INTENT(OUT) :: PERMITTIVITY_REFERENCE(3,3)               ! Output real (real64): permittivity_reference(3,3).

      PERMITTIVITY_REFERENCE = MATMUL(                                   ! Set permittivity_reference to matmul( transpose(material_from_reference), matmul(permittivity_material,mate...
     &  TRANSPOSE(MATERIAL_FROM_REFERENCE),
     &  MATMUL(PERMITTIVITY_MATERIAL,MATERIAL_FROM_REFERENCE))

      END SUBROUTINE ROTATE_PERMITTIVITY                                 ! End of the subroutine rotate permittivity.

!  EXPANSION STRAINS (ENGINEERING VOIGT): E_REF = T(A^T) E_MATERIAL.
      SUBROUTINE ROTATE_EXPANSION(EXPANSION_MATERIAL,                    ! Subroutine rotate expansion takes expansion material, material from reference, expansion reference.
     &     MATERIAL_FROM_REFERENCE, EXPANSION_REFERENCE)

      REAL(R8), INTENT(IN) :: EXPANSION_MATERIAL(6)                      ! Input real (real64): expansion_material(6).
      REAL(R8), INTENT(IN) :: MATERIAL_FROM_REFERENCE(3,3)               ! Input real (real64): material_from_reference(3,3).
      REAL(R8), INTENT(OUT) :: EXPANSION_REFERENCE(6)                    ! Output real (real64): expansion_reference(6).
      REAL(R8) :: TRANSFORM(6,6)                                         ! Real (real64): transform(6,6).

      CALL BUILD_ENGINEERING_STRAIN_TRANSFORM(                           ! Call build engineering strain transform with transpose(material_from_reference), transform.
     &     TRANSPOSE(MATERIAL_FROM_REFERENCE), TRANSFORM)
      EXPANSION_REFERENCE = MATMUL(TRANSFORM,EXPANSION_MATERIAL)         ! Set expansion_reference to matmul(transform,expansion_material).

      END SUBROUTINE ROTATE_EXPANSION                                    ! End of the subroutine rotate expansion.

      END MODULE MUL2_MATERIAL_ROTATIONS                                 ! End of the module mul2 material rotations.
