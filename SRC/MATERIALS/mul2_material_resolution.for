!=======================================================================
!  RESOLVE A LAMINATION INTO CONSTITUTIVE DATA AT AN INTEGRATION POINT.
!=======================================================================
      MODULE MUL2_MATERIAL_RESOLUTION                                    ! Module mul2 material resolution begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_MATERIALS, ONLY: MATERIAL_DB_TYPE,                        ! Use from module mul2 materials: material db type, find material index.
     &                          FIND_MATERIAL_INDEX
      USE MUL2_LAMINATIONS, ONLY: LAMINATION_DB_TYPE,                    ! Use from module mul2 laminations: lamination db type, find lamination index.
     &                            FIND_LAMINATION_INDEX
      USE MUL2_MATERIAL_ROTATIONS, ONLY: BUILD_MATERIAL_ROTATION,        ! Use from module mul2 material rotations: build material rotation, rotate stiffness, rotate piezo, rotate pe...
     &                                  ROTATE_STIFFNESS,
     &                                  ROTATE_PIEZO,
     &                                  ROTATE_PERMITTIVITY,
     &                                  ROTATE_EXPANSION

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: RESOLVE_LAMINATION                                       ! Export: resolve lamination.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE RESOLVE_LAMINATION(LAMINATION_ID, MATERIALS,            ! Subroutine resolve lamination takes lamination id, materials, laminations, stiffness local, density, materi...
     &     LAMINATIONS, STIFFNESS_LOCAL, DENSITY,
     &     MATERIAL_FROM_LOCAL, STATUS, PIEZO_LOCAL,
     &     PERMITTIVITY_LOCAL, HAS_PIEZO, EXPANSION_LOCAL,
     &     CONDUCTIVITY_LOCAL, HAS_THERMAL, PYRO_LOCAL, HAS_PYRO)

      INTEGER(I4), INTENT(IN) :: LAMINATION_ID                           ! Input integer (int32): lamination_id.
      TYPE(MATERIAL_DB_TYPE), INTENT(IN) :: MATERIALS                    ! Input of type material_db_type: materials.
      TYPE(LAMINATION_DB_TYPE), INTENT(IN) :: LAMINATIONS                ! Input of type lamination_db_type: laminations.
      REAL(R8), INTENT(OUT) :: STIFFNESS_LOCAL(6,6)                      ! Output real (real64): stiffness_local(6,6).
      REAL(R8), INTENT(OUT) :: DENSITY                                   ! Output real (real64): density.
      REAL(R8), INTENT(OUT) :: MATERIAL_FROM_LOCAL(3,3)                  ! Output real (real64): material_from_local(3,3).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), INTENT(OUT), OPTIONAL :: PIEZO_LOCAL(3,6)                ! Output optional real (real64): piezo_local(3,6).
      REAL(R8), INTENT(OUT), OPTIONAL :: PERMITTIVITY_LOCAL(3,3)         ! Output optional real (real64): permittivity_local(3,3).
      LOGICAL, INTENT(OUT), OPTIONAL :: HAS_PIEZO                        ! Output optional logical: has_piezo.
      REAL(R8), INTENT(OUT), OPTIONAL :: EXPANSION_LOCAL(6)              ! Output optional real (real64): expansion_local(6).
      REAL(R8), INTENT(OUT), OPTIONAL :: CONDUCTIVITY_LOCAL(3,3)         ! Output optional real (real64): conductivity_local(3,3).
      LOGICAL, INTENT(OUT), OPTIONAL :: HAS_THERMAL                      ! Output optional logical: has_thermal.
      REAL(R8), INTENT(OUT), OPTIONAL :: PYRO_LOCAL(3)                   ! Output optional real (real64): pyro_local(3).
      LOGICAL, INTENT(OUT), OPTIONAL :: HAS_PYRO                         ! Output optional logical: has_pyro.
      INTEGER(I4) :: LAMINATION_INDEX                                    ! Integer (int32): lamination_index.
      INTEGER(I4) :: MATERIAL_INDEX                                      ! Integer (int32): material_index.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      STIFFNESS_LOCAL = 0.0_R8                                           ! Set stiffness_local to zero.
      DENSITY = 0.0_R8                                                   ! Set density to zero.
      MATERIAL_FROM_LOCAL = 0.0_R8                                       ! Set material_from_local to zero.
      LAMINATION_INDEX = FIND_LAMINATION_INDEX(LAMINATIONS,              ! Set lamination_index to find_lamination_index(laminations, lamination_id).
     &                                        LAMINATION_ID)
      IF (LAMINATION_INDEX .EQ. 0_I4) THEN                               ! If lamination_index = 0:
        CALL SET_ERROR(STATUS, 'RESOLVE_LAMINATION',                     ! Record an error in status: 'UNKNOWN LAMINATION ID'.
     &                 'UNKNOWN LAMINATION ID')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      MATERIAL_INDEX = FIND_MATERIAL_INDEX(MATERIALS,                    ! Set material_index to find_material_index(materials, laminations.item(lamination_index).material_id).
     & LAMINATIONS%ITEM(LAMINATION_INDEX)%MATERIAL_ID)
      IF (MATERIAL_INDEX .EQ. 0_I4) THEN                                 ! If material_index = 0:
        CALL SET_ERROR(STATUS, 'RESOLVE_LAMINATION',                     ! Record an error in status: 'UNKNOWN MATERIAL ID'.
     &                 'UNKNOWN MATERIAL ID')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL BUILD_MATERIAL_ROTATION(                                      ! Call build material rotation with laminations.item(lamination_index).angle_y_deg, laminations.item(laminati...
     & LAMINATIONS%ITEM(LAMINATION_INDEX)%ANGLE_Y_DEG,
     & LAMINATIONS%ITEM(LAMINATION_INDEX)%ANGLE_Z_DEG,
     & MATERIAL_FROM_LOCAL)
      CALL ROTATE_STIFFNESS(                                             ! Call rotate stiffness with materials.item(material_index).stiffness, material_from_local, stiffness_local.
     & MATERIALS%ITEM(MATERIAL_INDEX)%STIFFNESS,
     & MATERIAL_FROM_LOCAL, STIFFNESS_LOCAL)
      DENSITY = MATERIALS%ITEM(MATERIAL_INDEX)%DENSITY                   ! Set density to materials.item(material_index).density.
      IF (PRESENT(HAS_PIEZO)) HAS_PIEZO =                                ! If present(has_piezo), set has_piezo to materials.item(material_index).has_piezo.
     &  MATERIALS%ITEM(MATERIAL_INDEX)%HAS_PIEZO
      IF (PRESENT(PIEZO_LOCAL)) CALL ROTATE_PIEZO(                       ! If present(piezo_local), call rotate piezo with materials.item(material_index).piezo, material_from_local, ...
     &  MATERIALS%ITEM(MATERIAL_INDEX)%PIEZO, MATERIAL_FROM_LOCAL,
     &  PIEZO_LOCAL)
      IF (PRESENT(PERMITTIVITY_LOCAL)) CALL ROTATE_PERMITTIVITY(         ! If present(permittivity_local), call rotate permittivity with materials.item(material_index).permittivity, ...
     &  MATERIALS%ITEM(MATERIAL_INDEX)%PERMITTIVITY,
     &  MATERIAL_FROM_LOCAL, PERMITTIVITY_LOCAL)
      IF (PRESENT(HAS_THERMAL)) HAS_THERMAL =                            ! If present(has_thermal), set has_thermal to materials.item(material_index).has_expansion or materials.item(...
     &  MATERIALS%ITEM(MATERIAL_INDEX)%HAS_EXPANSION .OR.
     &  MATERIALS%ITEM(MATERIAL_INDEX)%HAS_CONDUCTION
      IF (PRESENT(EXPANSION_LOCAL)) CALL ROTATE_EXPANSION(               ! If present(expansion_local), call rotate expansion with materials.item(material_index).expansion, material_...
     &  MATERIALS%ITEM(MATERIAL_INDEX)%EXPANSION,
     &  MATERIAL_FROM_LOCAL, EXPANSION_LOCAL)
      IF (PRESENT(HAS_PYRO)) HAS_PYRO =                                  ! If present(has_pyro), set has_pyro to materials.item(material_index).has_pyro.
     &  MATERIALS%ITEM(MATERIAL_INDEX)%HAS_PYRO
!     VECTOR: V_REFERENCE = A^T V_MATERIAL.
      IF (PRESENT(PYRO_LOCAL)) PYRO_LOCAL = MATMUL(                      ! If present(pyro_local), set pyro_local to matmul( transpose(material_from_local), materials.item(material_i...
     &  TRANSPOSE(MATERIAL_FROM_LOCAL),
     &  MATERIALS%ITEM(MATERIAL_INDEX)%PYRO)
      IF (PRESENT(CONDUCTIVITY_LOCAL)) CALL ROTATE_PERMITTIVITY(         ! If present(conductivity_local), call rotate permittivity with materials.item(material_index).conductivity, ...
     &  MATERIALS%ITEM(MATERIAL_INDEX)%CONDUCTIVITY,
     &  MATERIAL_FROM_LOCAL, CONDUCTIVITY_LOCAL)

      END SUBROUTINE RESOLVE_LAMINATION                                  ! End of the subroutine resolve lamination.

      END MODULE MUL2_MATERIAL_RESOLUTION                                ! End of the module mul2 material resolution.
