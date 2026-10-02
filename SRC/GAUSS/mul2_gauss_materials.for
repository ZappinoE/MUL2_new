!=======================================================================
!  SHARED CONSTITUTIVE CACHE AND GAUSS-POINT MATERIAL INDIRECTION.
!=======================================================================
      MODULE MUL2_GAUSS_MATERIALS                                        ! Module mul2 gauss materials begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       SET_ERROR, STATUS_IS_OK
      USE MUL2_GAUSS_POINTS, ONLY: GAUSS_LAYOUT_TYPE                     ! Use from module mul2 gauss points: gauss layout type.
      USE MUL2_MATERIALS, ONLY: MATERIAL_DB_TYPE                         ! Use from module mul2 materials: material db type.
      USE MUL2_LAMINATIONS, ONLY: LAMINATION_DB_TYPE,                    ! Use from module mul2 laminations: lamination db type, find lamination index.
     &                            FIND_LAMINATION_INDEX
      USE MUL2_MATERIAL_RESOLUTION, ONLY: RESOLVE_LAMINATION             ! Use from module mul2 material resolution: resolve lamination.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: MATERIAL_CACHE_TYPE                                ! Definition of the derived type material cache type.
        INTEGER(I4) :: COUNT = 0_I4                                      ! Integer (int32): count = 0.
        INTEGER(I4), ALLOCATABLE :: LAMINATION_ID(:)                     ! Allocatable integer (int32): lamination_id(:).
        INTEGER(I4), ALLOCATABLE :: MATERIAL_ID(:)                       ! Allocatable integer (int32): material_id(:).
        REAL(R8), ALLOCATABLE :: DENSITY(:)                              ! Allocatable real (real64): density(:).
        REAL(R8), ALLOCATABLE :: MATERIAL_FROM_LOCAL(:,:,:)              ! Allocatable real (real64): material_from_local(:,:,:).
        REAL(R8), ALLOCATABLE :: STIFFNESS_LOCAL(:,:,:)                  ! Allocatable real (real64): stiffness_local(:,:,:).
!       PIEZOELECTRIC COEFFICIENTS AND PERMITTIVITY IN THE ELEMENT FRAME.
        LOGICAL :: ANY_PIEZO = .FALSE.                                   ! Logical: any_piezo = false.
        REAL(R8), ALLOCATABLE :: PIEZO_LOCAL(:,:,:)                      ! Allocatable real (real64): piezo_local(:,:,:).
        REAL(R8), ALLOCATABLE :: PERMITTIVITY_LOCAL(:,:,:)               ! Allocatable real (real64): permittivity_local(:,:,:).
!       THERMAL EXPANSION STRAINS AND CONDUCTIVITY IN THE ELEMENT FRAME.
        LOGICAL :: ANY_THERMAL = .FALSE.                                 ! Logical: any_thermal = false.
        REAL(R8), ALLOCATABLE :: EXPANSION_LOCAL(:,:)                    ! Allocatable real (real64): expansion_local(:,:).
        REAL(R8), ALLOCATABLE :: CONDUCTIVITY_LOCAL(:,:,:)               ! Allocatable real (real64): conductivity_local(:,:,:).
!       PYROELECTRIC COEFFICIENT AT CONSTANT STRAIN, ELEMENT FRAME:
!       P_STRAIN = P_STRESS - E ALPHA (D = E S + EPS E + P_STRAIN T).
        LOGICAL :: ANY_PYRO = .FALSE.                                    ! Logical: any_pyro = false.
        REAL(R8), ALLOCATABLE :: PYRO_LOCAL(:,:)                         ! Allocatable real (real64): pyro_local(:,:).
        REAL(R8), ALLOCATABLE :: SPECIFIC_HEAT(:)                        ! Allocatable real (real64): specific_heat(:).
      END TYPE MATERIAL_CACHE_TYPE                                       ! End of the type definition material cache type.

      TYPE, PUBLIC :: GAUSS_MATERIAL_MAP_TYPE                            ! Definition of the derived type gauss material map type.
        INTEGER(I8) :: COUNT = 0_I8                                      ! Integer (int64): count = 0.
        INTEGER(I4), ALLOCATABLE :: CACHE_INDEX(:)                       ! Allocatable integer (int32): cache_index(:).
      END TYPE GAUSS_MATERIAL_MAP_TYPE                                   ! End of the type definition gauss material map type.

      PUBLIC :: BUILD_GAUSS_MATERIAL_CACHE                               ! Export: build gauss material cache.
      PUBLIC :: STIFFNESS_PART                                           ! Export: stiffness part.
      PUBLIC :: GENERALIZED_CONSTITUTIVE                                 ! Export: generalized constitutive.
      PUBLIC :: THERMAL_STRESS_COEFFICIENT                               ! Export: thermal stress coefficient.
      INTEGER(I4), PARAMETER, PUBLIC :: PART_FULL = 0_I4                 ! Constant public integer (int32): part_full = 0.
      INTEGER(I4), PARAMETER, PUBLIC :: PART_NORMAL = 1_I4               ! Constant public integer (int32): part_normal = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: PART_SHEAR = 2_I4                ! Constant public integer (int32): part_shear = 2.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE BUILD_GAUSS_MATERIAL_CACHE(LAYOUT, MATERIALS,           ! Subroutine build gauss material cache takes layout, materials, laminations, cache, point map, status.
     &     LAMINATIONS, CACHE, POINT_MAP, STATUS)

      TYPE(GAUSS_LAYOUT_TYPE), INTENT(IN) :: LAYOUT                      ! Input of type gauss_layout_type: layout.
      TYPE(MATERIAL_DB_TYPE), INTENT(IN) :: MATERIALS                    ! Input of type material_db_type: materials.
      TYPE(LAMINATION_DB_TYPE), INTENT(IN) :: LAMINATIONS                ! Input of type lamination_db_type: laminations.
      TYPE(MATERIAL_CACHE_TYPE), INTENT(INOUT) :: CACHE                  ! In/out of type material_cache_type: cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(INOUT) :: POINT_MAP          ! In/out of type gauss_material_map_type: point_map.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: LAMINATION_INDEX                                    ! Integer (int32): lamination_index.
      INTEGER(I8) :: POINT                                               ! Integer (int64): point.
      LOGICAL :: HAS_PIEZO                                               ! Logical: has_piezo.
      LOGICAL :: HAS_THERMAL                                             ! Logical: has_thermal.
      LOGICAL :: HAS_PYRO                                                ! Logical: has_pyro.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_MATERIAL_CACHE(CACHE, POINT_MAP)                        ! Call clear material cache with cache, point_map.
      IF (.NOT. ALLOCATED(LAMINATIONS%ITEM) .OR.                         ! If not allocated(laminations.item) or not allocated(layout.lamination_id):
     &    .NOT. ALLOCATED(LAYOUT%LAMINATION_ID)) THEN
        CALL SET_ERROR(STATUS, 'BUILD_GAUSS_MATERIAL_CACHE',             ! Record an error in status: 'MATERIAL INPUT IS NOT ALLOCATED'.
     &                 'MATERIAL INPUT IS NOT ALLOCATED')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CACHE%COUNT = SIZE(LAMINATIONS%ITEM)                               ! Set cache.count to the size of laminations.item.
      ALLOCATE(CACHE%LAMINATION_ID(CACHE%COUNT))                         ! Allocate memory for cache.lamination_id(cache.count).
      ALLOCATE(CACHE%MATERIAL_ID(CACHE%COUNT))                           ! Allocate memory for cache.material_id(cache.count).
      ALLOCATE(CACHE%DENSITY(CACHE%COUNT))                               ! Allocate memory for cache.density(cache.count).
      ALLOCATE(CACHE%MATERIAL_FROM_LOCAL(3,3,CACHE%COUNT))               ! Allocate memory for cache.material_from_local(3,3,cache.count).
      ALLOCATE(CACHE%STIFFNESS_LOCAL(6,6,CACHE%COUNT))                   ! Allocate memory for cache.stiffness_local(6,6,cache.count).
      ALLOCATE(CACHE%PIEZO_LOCAL(3,6,CACHE%COUNT))                       ! Allocate memory for cache.piezo_local(3,6,cache.count).
      ALLOCATE(CACHE%PERMITTIVITY_LOCAL(3,3,CACHE%COUNT))                ! Allocate memory for cache.permittivity_local(3,3,cache.count).
      ALLOCATE(CACHE%EXPANSION_LOCAL(6,CACHE%COUNT))                     ! Allocate memory for cache.expansion_local(6,cache.count).
      ALLOCATE(CACHE%CONDUCTIVITY_LOCAL(3,3,CACHE%COUNT))                ! Allocate memory for cache.conductivity_local(3,3,cache.count).
      ALLOCATE(CACHE%PYRO_LOCAL(3,CACHE%COUNT))                          ! Allocate memory for cache.pyro_local(3,cache.count).
      ALLOCATE(CACHE%SPECIFIC_HEAT(CACHE%COUNT))                         ! Allocate memory for cache.specific_heat(cache.count).
      CACHE%ANY_PYRO = .FALSE.                                           ! Set the flag cache.any_pyro to false.
      CACHE%ANY_PIEZO = .FALSE.                                          ! Set the flag cache.any_piezo to false.
      CACHE%ANY_THERMAL = .FALSE.                                        ! Set the flag cache.any_thermal to false.
      DO I = 1_I4, CACHE%COUNT                                           ! Loop i from 1 to cache.count:
        CACHE%LAMINATION_ID(I) = LAMINATIONS%ITEM(I)%ID                  ! Set cache.lamination_id(i) to laminations.item(i).id.
        CACHE%MATERIAL_ID(I) = LAMINATIONS%ITEM(I)%MATERIAL_ID           ! Set cache.material_id(i) to laminations.item(i).material_id.
        CALL RESOLVE_LAMINATION(CACHE%LAMINATION_ID(I),                  ! Call resolve lamination with cache.lamination_id(i), materials, laminations, cache.stiffness_local(:,:,i), ...
     &       MATERIALS, LAMINATIONS, CACHE%STIFFNESS_LOCAL(:,:,I),
     &       CACHE%DENSITY(I), CACHE%MATERIAL_FROM_LOCAL(:,:,I),
     &       STATUS, CACHE%PIEZO_LOCAL(:,:,I),
     &       CACHE%PERMITTIVITY_LOCAL(:,:,I), HAS_PIEZO,
     &       CACHE%EXPANSION_LOCAL(:,I),
     &       CACHE%CONDUCTIVITY_LOCAL(:,:,I), HAS_THERMAL,
     &       CACHE%PYRO_LOCAL(:,I), HAS_PYRO)
        CACHE%SPECIFIC_HEAT(I) = SPECIFIC_OF(MATERIALS,                  ! Set cache.specific_heat(i) to specific_of(materials, cache.material_id(i)).
     &    CACHE%MATERIAL_ID(I))
        IF (HAS_PYRO) THEN                                               ! If has_pyro:
          CACHE%ANY_PYRO = .TRUE.                                        ! Set the flag cache.any_pyro to true.
          CACHE%PYRO_LOCAL(:,I) = CACHE%PYRO_LOCAL(:,I) - MATMUL(        ! Subtract matmul( cache.piezo_local(:,:,i),cache.expansion_local(:,i)) from cache.pyro_local(:,i).
     &      CACHE%PIEZO_LOCAL(:,:,I),CACHE%EXPANSION_LOCAL(:,I))
        END IF                                                           ! End of the IF block.
        IF (HAS_PIEZO) CACHE%ANY_PIEZO = .TRUE.                          ! If has_piezo, set the flag cache.any_piezo to true.
        IF (HAS_THERMAL) CACHE%ANY_THERMAL = .TRUE.                      ! If has_thermal, set the flag cache.any_thermal to true.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.

      POINT_MAP%COUNT = LAYOUT%COUNT                                     ! Set point_map.count to layout.count.
      ALLOCATE(POINT_MAP%CACHE_INDEX(POINT_MAP%COUNT))                   ! Allocate memory for point_map.cache_index(point_map.count).
      DO POINT = 1_I8, POINT_MAP%COUNT                                   ! Loop point from 1 to point_map.count:
        LAMINATION_INDEX = FIND_LAMINATION_INDEX(LAMINATIONS,            ! Set lamination_index to find_lamination_index(laminations, layout.lamination_id(point)).
     &                      LAYOUT%LAMINATION_ID(POINT))
        IF (LAMINATION_INDEX .EQ. 0_I4) THEN                             ! If lamination_index = 0:
          CALL SET_ERROR(STATUS, 'BUILD_GAUSS_MATERIAL_CACHE',           ! Record an error in status: 'GAUSS POINT REFERENCES UNKNOWN LAMINATION'.
     &                   'GAUSS POINT REFERENCES UNKNOWN LAMINATION')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        POINT_MAP%CACHE_INDEX(POINT) = LAMINATION_INDEX                  ! Set point_map.cache_index(point) to lamination_index.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_GAUSS_MATERIAL_CACHE                          ! End of the subroutine build gauss material cache.

!  CONSTITUTIVE MATRIX OF A LAMINATION, OR ONE OF ITS TWO PARTS FOR THE
!  SELECTIVE INTEGRATION. THE STRAINS THAT ARE REDUCED ARE THE TRANSVERSE
!  SHEARS OF THE ELEMENT (VOIGT ORDER XX YY ZZ XZ YZ XY, ELEMENT FRAME):
!    BEAM  (AXIS Y):        YZ, XY
!    PLATE (SURFACE X-Y):   XZ, YZ
!    SOLID:                 XZ, YZ, XY
!  PART_SHEAR KEEPS THE ENTRIES WHOSE ROW OR COLUMN IS A REDUCED STRAIN,
!  PART_NORMAL THE OTHERS: THE TWO PARTS ADD UP TO THE MATRIX.
      FUNCTION STIFFNESS_PART(CACHE, INDEX, PART, DIM) RESULT(C)         ! Function stiffness part takes cache, index, part, dim and returns c.

      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: CACHE                     ! Input of type material_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: INDEX                                   ! Input integer (int32): index.
      INTEGER(I4), INTENT(IN) :: PART                                    ! Input integer (int32): part.
      INTEGER(I4), INTENT(IN) :: DIM                                     ! Input integer (int32): dim.
      REAL(R8) :: C(6,6)                                                 ! Real (real64): c(6,6).
      LOGICAL :: REDUCED_ROW(6)                                          ! Logical: reduced_row(6).
      INTEGER(I4) :: R                                                   ! Integer (int32): r.
      INTEGER(I4) :: S                                                   ! Integer (int32): s.

      C = CACHE%STIFFNESS_LOCAL(:,:,INDEX)                               ! Set c to cache.stiffness_local(:,:,index).
      IF (PART .EQ. PART_FULL) RETURN                                    ! If part = part_full, return to the caller.
      REDUCED_ROW = .FALSE.                                              ! Set the flag reduced_row to false.
      SELECT CASE (DIM)                                                  ! Choose according to the value of dim:
      CASE (1_I4)                                                        ! Case 1:
        REDUCED_ROW(5:6) = .TRUE.                                        ! Set the flag reduced_row(5:6) to true.
      CASE (2_I4)                                                        ! Case 2:
        REDUCED_ROW(4:5) = .TRUE.                                        ! Set the flag reduced_row(4:5) to true.
      CASE DEFAULT                                                       ! In every other case:
        REDUCED_ROW(4:6) = .TRUE.                                        ! Set the flag reduced_row(4:6) to true.
      END SELECT                                                         ! End of the case selection.
      DO S = 1_I4, 6_I4                                                  ! Loop s from 1 to 6:
        DO R = 1_I4, 6_I4                                                ! Loop r from 1 to 6:
          IF ((REDUCED_ROW(R) .OR. REDUCED_ROW(S)) .EQV.                 ! If (reduced_row(r) or reduced_row(s)) equals (part = part_normal), set c(r,s) to zero.
     &        (PART .EQ. PART_NORMAL)) C(R,S) = 0.0_R8
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END FUNCTION STIFFNESS_PART                                        ! End of the function stiffness part.

!  GENERALISED CONSTITUTIVE MATRIX OF THE MECHANICAL, ELECTRIC AND
!  THERMAL FIELDS: ROWS/COLUMNS 1-6 ARE THE STRAINS, 7-9 THE POTENTIAL
!  GRADIENT AND 10-12 THE TEMPERATURE GRADIENT (BLOCK +K: Q = -K GRAD T).
!  THE THERMAL EXPANSION ONLY ENTERS THE LOAD, NOT THIS MATRIX.
!      [ SIGMA ]   [ C   E^T ] [  S   ]
!      [   D   ] = [ E  -EPS ] [ GRAD ]      (D = E S - EPS GRAD PHI)
!  PART_NORMAL / PART_SHEAR SPLIT THE ENTRIES AS IN STIFFNESS_PART (THE
!  ELECTRIC ROWS ARE NEVER REDUCED).
      FUNCTION GENERALIZED_CONSTITUTIVE(CACHE, INDEX, PART, DIM)         ! Function generalized constitutive takes cache, index, part, dim and returns m.
     &         RESULT(M)

      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: CACHE                     ! Input of type material_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: INDEX                                   ! Input integer (int32): index.
      INTEGER(I4), INTENT(IN) :: PART                                    ! Input integer (int32): part.
      INTEGER(I4), INTENT(IN) :: DIM                                     ! Input integer (int32): dim.
      REAL(R8) :: M(12,12)                                               ! Real (real64): m(12,12).
      LOGICAL :: REDUCED_ROW(12)                                         ! Logical: reduced_row(12).
      INTEGER(I4) :: R                                                   ! Integer (int32): r.
      INTEGER(I4) :: S                                                   ! Integer (int32): s.

      M = 0.0_R8                                                         ! Set m to zero.
      M(1:6,1:6) = CACHE%STIFFNESS_LOCAL(:,:,INDEX)                      ! Set m(1:6,1:6) to cache.stiffness_local(:,:,index).
      IF (CACHE%ANY_PIEZO) THEN                                          ! If cache.any_piezo:
        M(7:9,1:6) = CACHE%PIEZO_LOCAL(:,:,INDEX)                        ! Set m(7:9,1:6) to cache.piezo_local(:,:,index).
        M(1:6,7:9) = TRANSPOSE(CACHE%PIEZO_LOCAL(:,:,INDEX))             ! Set m(1:6,7:9) to transpose(cache.piezo_local(:,:,index)).
        M(7:9,7:9) = -CACHE%PERMITTIVITY_LOCAL(:,:,INDEX)                ! Set m(7:9,7:9) to -cache.permittivity_local(:,:,index).
      END IF                                                             ! End of the IF block.
      IF (CACHE%ANY_THERMAL) THEN                                        ! If cache.any_thermal:
        M(10:12,10:12) = CACHE%CONDUCTIVITY_LOCAL(:,:,INDEX)             ! Set m(10:12,10:12) to cache.conductivity_local(:,:,index).
      END IF                                                             ! End of the IF block.
      IF (PART .EQ. PART_FULL) RETURN                                    ! If part = part_full, return to the caller.
      REDUCED_ROW = .FALSE.                                              ! Set the flag reduced_row to false.
      SELECT CASE (DIM)                                                  ! Choose according to the value of dim:
      CASE (1_I4)                                                        ! Case 1:
        REDUCED_ROW(5:6) = .TRUE.                                        ! Set the flag reduced_row(5:6) to true.
      CASE (2_I4)                                                        ! Case 2:
        REDUCED_ROW(4:5) = .TRUE.                                        ! Set the flag reduced_row(4:5) to true.
      CASE DEFAULT                                                       ! In every other case:
        REDUCED_ROW(4:6) = .TRUE.                                        ! Set the flag reduced_row(4:6) to true.
      END SELECT                                                         ! End of the case selection.
      DO S = 1_I4, 12_I4                                                 ! Loop s from 1 to 12:
        DO R = 1_I4, 12_I4                                               ! Loop r from 1 to 12:
          IF ((REDUCED_ROW(R) .OR. REDUCED_ROW(S)) .EQV.                 ! If (reduced_row(r) or reduced_row(s)) equals (part = part_normal), set m(r,s) to zero.
     &        (PART .EQ. PART_NORMAL)) M(R,S) = 0.0_R8
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END FUNCTION GENERALIZED_CONSTITUTIVE                              ! End of the function generalized constitutive.

!  STRESS PER KELVIN OF THE FULLY RESTRAINED EXPANSION, BETA = C ALPHA.
      FUNCTION THERMAL_STRESS_COEFFICIENT(CACHE, INDEX) RESULT(BETA)     ! Function thermal stress coefficient takes cache, index and returns beta.

      TYPE(MATERIAL_CACHE_TYPE), INTENT(IN) :: CACHE                     ! Input of type material_cache_type: cache.
      INTEGER(I4), INTENT(IN) :: INDEX                                   ! Input integer (int32): index.
      REAL(R8) :: BETA(6)                                                ! Real (real64): beta(6).

      BETA = MATMUL(CACHE%STIFFNESS_LOCAL(:,:,INDEX),                    ! Set beta to matmul(cache.stiffness_local(:,:,index), cache.expansion_local(:,index)).
     &              CACHE%EXPANSION_LOCAL(:,INDEX))

      END FUNCTION THERMAL_STRESS_COEFFICIENT                            ! End of the function thermal stress coefficient.

      REAL(R8) FUNCTION SPECIFIC_OF(MATERIALS, MATERIAL_ID)              ! Function specific of takes materials, material id.

      USE MUL2_MATERIALS, ONLY: FIND_MATERIAL_INDEX                      ! Use from module mul2 materials: find material index.
      TYPE(MATERIAL_DB_TYPE), INTENT(IN) :: MATERIALS                    ! Input of type material_db_type: materials.
      INTEGER(I4), INTENT(IN) :: MATERIAL_ID                             ! Input integer (int32): material_id.
      INTEGER(I4) :: INDEX                                               ! Integer (int32): index.

      SPECIFIC_OF = 0.0_R8                                               ! Set specific_of to zero.
      INDEX = FIND_MATERIAL_INDEX(MATERIALS, MATERIAL_ID)                ! Set index to find_material_index(materials, material_id).
      IF (INDEX .GT. 0_I4) SPECIFIC_OF = MATERIALS%ITEM(INDEX)%          ! If index > 0, set specific_of to materials.item(index). specific_heat.
     &                                   SPECIFIC_HEAT

      END FUNCTION SPECIFIC_OF                                           ! End of the function specific of.

      SUBROUTINE CLEAR_MATERIAL_CACHE(CACHE, POINT_MAP)                  ! Subroutine clear material cache takes cache, point map.

      TYPE(MATERIAL_CACHE_TYPE), INTENT(INOUT) :: CACHE                  ! In/out of type material_cache_type: cache.
      TYPE(GAUSS_MATERIAL_MAP_TYPE), INTENT(INOUT) :: POINT_MAP          ! In/out of type gauss_material_map_type: point_map.

      IF (ALLOCATED(CACHE%LAMINATION_ID))                                ! If allocated(cache.lamination_id), free the memory of cache.lamination_id.
     &  DEALLOCATE(CACHE%LAMINATION_ID)
      IF (ALLOCATED(CACHE%MATERIAL_ID))                                  ! If allocated(cache.material_id), free the memory of cache.material_id.
     &  DEALLOCATE(CACHE%MATERIAL_ID)
      IF (ALLOCATED(CACHE%DENSITY)) DEALLOCATE(CACHE%DENSITY)            ! If allocated(cache.density), free the memory of cache.density.
      IF (ALLOCATED(CACHE%MATERIAL_FROM_LOCAL))                          ! If allocated(cache.material_from_local), free the memory of cache.material_from_local.
     &  DEALLOCATE(CACHE%MATERIAL_FROM_LOCAL)
      IF (ALLOCATED(CACHE%STIFFNESS_LOCAL))                              ! If allocated(cache.stiffness_local), free the memory of cache.stiffness_local.
     &  DEALLOCATE(CACHE%STIFFNESS_LOCAL)
      IF (ALLOCATED(CACHE%PIEZO_LOCAL))                                  ! If allocated(cache.piezo_local), free the memory of cache.piezo_local.
     &  DEALLOCATE(CACHE%PIEZO_LOCAL)
      IF (ALLOCATED(CACHE%PERMITTIVITY_LOCAL))                           ! If allocated(cache.permittivity_local), free the memory of cache.permittivity_local.
     &  DEALLOCATE(CACHE%PERMITTIVITY_LOCAL)
      IF (ALLOCATED(CACHE%EXPANSION_LOCAL))                              ! If allocated(cache.expansion_local), free the memory of cache.expansion_local.
     &  DEALLOCATE(CACHE%EXPANSION_LOCAL)
      IF (ALLOCATED(CACHE%CONDUCTIVITY_LOCAL))                           ! If allocated(cache.conductivity_local), free the memory of cache.conductivity_local.
     &  DEALLOCATE(CACHE%CONDUCTIVITY_LOCAL)
      IF (ALLOCATED(CACHE%PYRO_LOCAL)) DEALLOCATE(CACHE%PYRO_LOCAL)      ! If allocated(cache.pyro_local), free the memory of cache.pyro_local.
      IF (ALLOCATED(CACHE%SPECIFIC_HEAT))                                ! If allocated(cache.specific_heat), free the memory of cache.specific_heat.
     &  DEALLOCATE(CACHE%SPECIFIC_HEAT)
      IF (ALLOCATED(POINT_MAP%CACHE_INDEX))                              ! If allocated(point_map.cache_index), free the memory of point_map.cache_index.
     &  DEALLOCATE(POINT_MAP%CACHE_INDEX)
      CACHE%COUNT = 0_I4                                                 ! Set cache.count to zero.
      POINT_MAP%COUNT = 0_I8                                             ! Set point_map.count to zero.

      END SUBROUTINE CLEAR_MATERIAL_CACHE                                ! End of the subroutine clear material cache.

      END MODULE MUL2_GAUSS_MATERIALS                                    ! End of the module mul2 gauss materials.
