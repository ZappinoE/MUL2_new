!=======================================================================
!  LEGACY-COMPATIBLE MATERIAL.DAT READER FOR MECHANICAL MATERIALS.
!=======================================================================
      MODULE MUL2_READ_MATERIALS                                         ! Module mul2 read materials begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error, status is ok.
     &                       SET_WARNING, SET_ERROR, STATUS_IS_OK
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_MATERIALS, ONLY: MATERIAL_TYPE, MATERIAL_DB_TYPE,         ! Use from module mul2 materials: material type, material db type, build isotropic material, build orthotropi...
     &     BUILD_ISOTROPIC_MATERIAL, BUILD_ORTHOTROPIC_MATERIAL,
     &     BUILD_ANISOTROPIC_MATERIAL, FIND_MATERIAL_INDEX

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_MATERIALS_FILE                                      ! Export: read materials file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_MATERIALS_FILE(FILE_NAME, DATABASE, STATUS)        ! Subroutine read materials file takes file name, database, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(MATERIAL_DB_TYPE), INTENT(INOUT) :: DATABASE                  ! In/out of type material_db_type: database.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      TYPE(MATERIAL_TYPE) :: MATERIAL                                    ! Of type material_type: material.
      CHARACTER(LEN=4096) :: LINE                                        ! Character (length 4096): line.
      CHARACTER(LEN=16) :: KEYWORD                                       ! Character (length 16): keyword.
      REAL(R8) :: VALUE(36)                                              ! Real (real64): value(36).
      REAL(R8) :: STIFFNESS(6,6)                                         ! Real (real64): stiffness(6,6).
      REAL(R8) :: DENSITY                                                ! Real (real64): density.
      REAL(R8) :: ASYMMETRY                                              ! Real (real64): asymmetry.
      REAL(R8), ALLOCATABLE :: PENDING_VALUE(:,:)                        ! Allocatable real (real64): pending_value(:,:).
      INTEGER(I4), ALLOCATABLE :: PENDING_ID(:)                          ! Allocatable integer (int32): pending_id(:).
      INTEGER(I4), ALLOCATABLE :: PENDING_KIND(:)                        ! Allocatable integer (int32): pending_kind(:).
      INTEGER(I4) :: PENDING_COUNT                                       ! Integer (int32): pending_count.
      INTEGER(I4) :: INDEX                                               ! Integer (int32): index.
      INTEGER(I4) :: MATERIAL_COUNT                                      ! Integer (int32): material_count.
      INTEGER(I4) :: RECORD_COUNT                                        ! Integer (int32): record_count.
      INTEGER(I4) :: FOUND_COUNT                                         ! Integer (int32): found_count.
      INTEGER(I4) :: IGNORED_COUNT                                       ! Integer (int32): ignored_count.
      INTEGER(I4) :: ID                                                  ! Integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: L                                                   ! Integer (int32): l.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(DATABASE%ITEM)) DEALLOCATE(DATABASE%ITEM)            ! If allocated(database.item), free the memory of database.item.
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD',                   ! Open the file file_name.
     &     ACTION='READ', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                    ! Record an error in status: 'CANNOT OPEN: '//trim(file_name).
     &                 'CANNOT OPEN: '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                    ! Record an error in status: 'MISSING MATERIAL HEADER'.
     &                 'MISSING MATERIAL HEADER')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(LINE,*,IOSTAT=IOS) MATERIAL_COUNT, RECORD_COUNT               ! Read from the text line into material_count, record_count.
      IF (IOS .NE. 0 .OR. MATERIAL_COUNT .LT. 1_I4 .OR.                  ! If ios /= 0 or material_count < 1 or record_count < material_count:
     &    RECORD_COUNT .LT. MATERIAL_COUNT) THEN
        CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                    ! Record an error in status: 'INVALID MATERIAL HEADER'.
     &                 'INVALID MATERIAL HEADER')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(DATABASE%ITEM(MATERIAL_COUNT))                            ! Allocate memory for database.item(material_count).
      ALLOCATE(PENDING_VALUE(18,RECORD_COUNT), PENDING_ID(RECORD_COUNT), ! Allocate memory for pending_value(18,record_count), pending_id(record_count), pending_kind(record_count).
     &         PENDING_KIND(RECORD_COUNT))
      PENDING_COUNT = 0_I4                                               ! Set pending_count to zero.
      FOUND_COUNT = 0_I4                                                 ! Set found_count to zero.
      IGNORED_COUNT = 0_I4                                               ! Set ignored_count to zero.

      DO I = 1_I4, RECORD_COUNT                                          ! Loop i from 1 to record_count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                  ! Record an error in status: 'MATERIAL RECORDS ARE MISSING'.
     &                   'MATERIAL RECORDS ARE MISSING')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        READ(LINE,*,IOSTAT=IOS) KEYWORD                                  ! Read from the text line into keyword.
        CALL UPPERCASE(KEYWORD)                                          ! Call uppercase with keyword.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                  ! Record an error in status: 'INVALID MATERIAL RECORD'.
     &                   'INVALID MATERIAL RECORD')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.

        SELECT CASE(TRIM(KEYWORD))                                       ! Choose according to the value of trim(keyword):
        CASE('ISO-M')                                                    ! Case 'ISO-M':
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:3)                ! Read from the text line into keyword, id, value(1:3).
          IF (IOS .EQ. 0) CALL BUILD_ISOTROPIC_MATERIAL(ID,              ! If ios = 0, call build isotropic material with id, value(1), value(2), value(3), material, local_status.
     &      VALUE(1), VALUE(2), VALUE(3), MATERIAL, LOCAL_STATUS)
          CALL STORE_MATERIAL(IOS, MATERIAL, LOCAL_STATUS,               ! Call store material with ios, material, local_status, database, found_count, status.
     &         DATABASE, FOUND_COUNT, STATUS)
        CASE('ORT-M')                                                    ! Case 'ORT-M':
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:10)               ! Read from the text line into keyword, id, value(1:10).
!         LEGACY ORDER: E_L,E_T,E_Z,NU_LT,NU_LZ,NU_TZ,
!         G_LT,G_LZ,G_TZ,RHO. INTERNAL AXES ARE (T,L,Z).
          IF (IOS .EQ. 0) CALL BUILD_ORTHOTROPIC_MATERIAL(ID,            ! If ios = 0, call build orthotropic material with id, value(2), value(1), value(3), value(4), value(5), valu...
     &      VALUE(2), VALUE(1), VALUE(3), VALUE(4), VALUE(5),
     &      VALUE(6), VALUE(7), VALUE(8), VALUE(9), VALUE(10),
     &      MATERIAL, LOCAL_STATUS)
          CALL STORE_MATERIAL(IOS, MATERIAL, LOCAL_STATUS,               ! Call store material with ios, material, local_status, database, found_count, status.
     &         DATABASE, FOUND_COUNT, STATUS)
        CASE('MAT-C')                                                    ! Case 'MAT-C':
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:36),              ! Read from the text line into keyword, id, value(1:36), density.
     &                             DENSITY
          IF (IOS .EQ. 0) THEN                                           ! If ios = 0:
            K = 0_I4                                                     ! Set k to zero.
            DO J = 1_I4, 6_I4                                            ! Loop j from 1 to 6:
              DO L = 1_I4, 6_I4                                          ! Loop l from 1 to 6:
                K = K + 1_I4                                             ! Add 1 to k.
                STIFFNESS(J,L) = VALUE(K)                                ! Set stiffness(j,l) to value(k).
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
            READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:36),            ! Read from the text line into keyword, id, value(1:36), density.
     &                               DENSITY
            CALL BUILD_ANISOTROPIC_MATERIAL(ID, STIFFNESS,               ! Call build anisotropic material with id, stiffness, density, material, local_status.
     &           DENSITY, MATERIAL, LOCAL_STATUS)
          END IF                                                         ! End of the IF block.
          CALL STORE_MATERIAL(IOS, MATERIAL, LOCAL_STATUS,               ! Call store material with ios, material, local_status, database, found_count, status.
     &         DATABASE, FOUND_COUNT, STATUS)
          IF (.NOT. STATUS_IS_OK(STATUS)) THEN                           ! If not status is ok:
            CLOSE(UNIT)                                                  ! Close the file.
            RETURN                                                       ! Return to the caller.
          END IF                                                         ! End of the IF block.
          ASYMMETRY = MAXVAL(ABS(STIFFNESS-                              ! Set asymmetry to the maximum of abs(stiffness- transpose(stiffness)).
     &                        TRANSPOSE(STIFFNESS)))
          IF (ASYMMETRY .GT. 1.0E-10_R8*                                 ! If asymmetry > 1.0e-10* max(1.0,maxval(abs(stiffness))):
     &        MAX(1.0_R8,MAXVAL(ABS(STIFFNESS)))) THEN
            IGNORED_COUNT = IGNORED_COUNT + 1_I4                         ! Add 1 to ignored_count.
          END IF                                                         ! End of the IF block.
        CASE('Z-EXP')                                                    ! Case 'Z-EXP':
!         PIEZOELECTRIC STRESS COEFFICIENTS, 3 X 6, ROW BY ROW.
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:18)               ! Read from the text line into keyword, id, value(1:18).
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                ! Record an error in status: 'INVALID Z-EXP RECORD'.
     &                     'INVALID Z-EXP RECORD')
          ELSE                                                           ! Otherwise:
            PENDING_COUNT = PENDING_COUNT + 1_I4                         ! Add 1 to pending_count.
            PENDING_ID(PENDING_COUNT) = ID                               ! Set pending_id(pending_count) to id.
            PENDING_KIND(PENDING_COUNT) = 1_I4                           ! Set pending_kind(pending_count) to 1.
            PENDING_VALUE(:,PENDING_COUNT) = VALUE(1:18)                 ! Set pending_value(:,pending_count) to value(1:18).
          END IF                                                         ! End of the IF block.
        CASE('Z-PRM')                                                    ! Case 'Z-PRM':
!         DIELECTRIC PERMITTIVITY, 3 X 3, ROW BY ROW.
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:9)                ! Read from the text line into keyword, id, value(1:9).
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                ! Record an error in status: 'INVALID Z-PRM RECORD'.
     &                     'INVALID Z-PRM RECORD')
          ELSE                                                           ! Otherwise:
            PENDING_COUNT = PENDING_COUNT + 1_I4                         ! Add 1 to pending_count.
            PENDING_ID(PENDING_COUNT) = ID                               ! Set pending_id(pending_count) to id.
            PENDING_KIND(PENDING_COUNT) = 2_I4                           ! Set pending_kind(pending_count) to 2.
            PENDING_VALUE(1:9,PENDING_COUNT) = VALUE(1:9)                ! Set pending_value(1:9,pending_count) to value(1:9).
            PENDING_VALUE(10:18,PENDING_COUNT) = 0.0_R8                  ! Set pending_value(10:18,pending_count) to zero.
          END IF                                                         ! End of the IF block.
        CASE('T-EXP')                                                    ! Case 'T-EXP':
!         THERMAL EXPANSION: SIX VALUES (MATERIAL AXES, VOIGT ORDER) OR
!         ONE VALUE FOR AN ISOTROPIC MATERIAL.
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:6)                ! Read from the text line into keyword, id, value(1:6).
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            VALUE = 0.0_R8                                               ! Set value to zero.
            READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1)                ! Read from the text line into keyword, id, value(1).
            VALUE(2:3) = VALUE(1)                                        ! Set value(2:3) to value(1).
          END IF                                                         ! End of the IF block.
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                ! Record an error in status: 'INVALID T-EXP RECORD'.
     &                     'INVALID T-EXP RECORD')
          ELSE                                                           ! Otherwise:
            PENDING_COUNT = PENDING_COUNT + 1_I4                         ! Add 1 to pending_count.
            PENDING_ID(PENDING_COUNT) = ID                               ! Set pending_id(pending_count) to id.
            PENDING_KIND(PENDING_COUNT) = 3_I4                           ! Set pending_kind(pending_count) to 3.
            PENDING_VALUE(:,PENDING_COUNT) = 0.0_R8                      ! Set pending_value(:,pending_count) to zero.
            PENDING_VALUE(1:6,PENDING_COUNT) = VALUE(1:6)                ! Set pending_value(1:6,pending_count) to value(1:6).
          END IF                                                         ! End of the IF block.
        CASE('T-CON')                                                    ! Case 'T-CON':
!         HEAT CONDUCTIVITY: 3 X 3 ROW BY ROW OR ONE ISOTROPIC VALUE.
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:9)                ! Read from the text line into keyword, id, value(1:9).
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            VALUE = 0.0_R8                                               ! Set value to zero.
            READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1)                ! Read from the text line into keyword, id, value(1).
            VALUE(5) = VALUE(1)                                          ! Set value(5) to value(1).
            VALUE(9) = VALUE(1)                                          ! Set value(9) to value(1).
          END IF                                                         ! End of the IF block.
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                ! Record an error in status: 'INVALID T-CON RECORD'.
     &                     'INVALID T-CON RECORD')
          ELSE                                                           ! Otherwise:
            PENDING_COUNT = PENDING_COUNT + 1_I4                         ! Add 1 to pending_count.
            PENDING_ID(PENDING_COUNT) = ID                               ! Set pending_id(pending_count) to id.
            PENDING_KIND(PENDING_COUNT) = 4_I4                           ! Set pending_kind(pending_count) to 4.
            PENDING_VALUE(:,PENDING_COUNT) = 0.0_R8                      ! Set pending_value(:,pending_count) to zero.
            PENDING_VALUE(1:9,PENDING_COUNT) = VALUE(1:9)                ! Set pending_value(1:9,pending_count) to value(1:9).
          END IF                                                         ! End of the IF block.
        CASE('PIROE')                                                    ! Case 'PIROE':
!         PYROELECTRIC COEFFICIENT (T,L,Z AXES) AT ZERO STRESS.
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1:3)                ! Read from the text line into keyword, id, value(1:3).
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                ! Record an error in status: 'INVALID PIROE RECORD'.
     &                     'INVALID PIROE RECORD')
          ELSE                                                           ! Otherwise:
            PENDING_COUNT = PENDING_COUNT + 1_I4                         ! Add 1 to pending_count.
            PENDING_ID(PENDING_COUNT) = ID                               ! Set pending_id(pending_count) to id.
            PENDING_KIND(PENDING_COUNT) = 5_I4                           ! Set pending_kind(pending_count) to 5.
            PENDING_VALUE(:,PENDING_COUNT) = 0.0_R8                      ! Set pending_value(:,pending_count) to zero.
            PENDING_VALUE(1:3,PENDING_COUNT) = VALUE(1:3)                ! Set pending_value(1:3,pending_count) to value(1:3).
          END IF                                                         ! End of the IF block.
        CASE('T-SPC')                                                    ! Case 'T-SPC':
!         SPECIFIC HEAT: ONE VALUE (THERMAL CAPACITY = DENSITY * C).
          VALUE = 0.0_R8                                                 ! Set value to zero.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, ID, VALUE(1)                  ! Read from the text line into keyword, id, value(1).
          IF (IOS .NE. 0) THEN                                           ! If ios /= 0:
            CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                ! Record an error in status: 'INVALID T-SPC RECORD'.
     &                     'INVALID T-SPC RECORD')
          ELSE                                                           ! Otherwise:
            PENDING_COUNT = PENDING_COUNT + 1_I4                         ! Add 1 to pending_count.
            PENDING_ID(PENDING_COUNT) = ID                               ! Set pending_id(pending_count) to id.
            PENDING_KIND(PENDING_COUNT) = 6_I4                           ! Set pending_kind(pending_count) to 6.
            PENDING_VALUE(:,PENDING_COUNT) = 0.0_R8                      ! Set pending_value(:,pending_count) to zero.
            PENDING_VALUE(1,PENDING_COUNT) = VALUE(1)                    ! Set pending_value(1,pending_count) to value(1).
          END IF                                                         ! End of the IF block.
        CASE('DAMP')                                                     ! Case 'DAMP':
!         RAYLEIGH DAMPING (HISTORICAL RECORD, NO ID): DAMP K_COEFF
!         M_COEFF, C = M_COEFF M + K_COEFF K.
          READ(LINE,*,IOSTAT=IOS) KEYWORD, DATABASE%DAMP_STIFFNESS,      ! Read from the text line into keyword, database.damp_stiffness, database.damp_mass.
     &                            DATABASE%DAMP_MASS
          IF (IOS .NE. 0) CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',  ! If ios /= 0, record an error in status: 'INVALID DAMP RECORD'.
     &                                   'INVALID DAMP RECORD')
        CASE('S-EXP','VISCO',                                            ! Case 'S-EXP','VISCO', 'M-EXP','M-PRM','H-EXP','H-DIF', 'PIROM','PZ-MG','MZ-PZ':
     &       'M-EXP','M-PRM','H-EXP','H-DIF',
     &       'PIROM','PZ-MG','MZ-PZ')
!         RECOGNIZED FOR INPUT COMPATIBILITY; NOT ACTIVE IN 101/103.
          IGNORED_COUNT = IGNORED_COUNT + 1_I4                           ! Add 1 to ignored_count.
        CASE DEFAULT                                                     ! In every other case:
          CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                  ! Record an error in status: 'UNKNOWN MATERIAL RECORD: '//trim(keyword).
     &                   'UNKNOWN MATERIAL RECORD: '//TRIM(KEYWORD))
        END SELECT                                                       ! End of the case selection.
        IF (.NOT. STATUS_IS_OK(STATUS)) THEN                             ! If not status is ok:
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      IF (FOUND_COUNT .NE. MATERIAL_COUNT) THEN                          ! If found_count /= material_count:
        CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                    ! Record an error in status: 'MECHANICAL MATERIAL COUNT DOES NOT MATCH'.
     &                 'MECHANICAL MATERIAL COUNT DOES NOT MATCH')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
!     ATTACH THE PIEZOELECTRIC RECORDS (THEY MAY PRECEDE THE MATERIAL).
      DO I = 1_I4, PENDING_COUNT                                         ! Loop i from 1 to pending_count:
        INDEX = FIND_MATERIAL_INDEX(DATABASE, PENDING_ID(I))             ! Set index to find_material_index(database, pending_id(i)).
        IF (INDEX .EQ. 0_I4) THEN                                        ! If index = 0:
          CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                  ! Record an error in status: 'T-EXP, T-CON OR PIEZO RECORD FOR AN UNKNOWN MATERIAL'.
     &      'T-EXP, T-CON OR PIEZO RECORD FOR AN UNKNOWN MATERIAL')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (PENDING_KIND(I) .EQ. 1_I4) THEN                              ! If pending_kind(i) = 1:
          DATABASE%ITEM(INDEX)%HAS_PIEZO = .TRUE.                        ! Set the flag database.item(index).has_piezo to true.
          DO J = 1_I4, 3_I4                                              ! Loop j from 1 to 3:
            DATABASE%ITEM(INDEX)%PIEZO(J,:) =                            ! Set database.item(index).piezo(j,:) to pending_value(6*(j-1)+1:6*j,i).
     &        PENDING_VALUE(6*(J-1)+1:6*J,I)
          END DO                                                         ! End of the loop.
        ELSE IF (PENDING_KIND(I) .EQ. 2_I4) THEN                         ! Otherwise, if pending_kind(i) = 2:
          DO J = 1_I4, 3_I4                                              ! Loop j from 1 to 3:
            DATABASE%ITEM(INDEX)%PERMITTIVITY(J,:) =                     ! Set database.item(index).permittivity(j,:) to pending_value(3*(j-1)+1:3*j,i).
     &        PENDING_VALUE(3*(J-1)+1:3*J,I)
          END DO                                                         ! End of the loop.
        ELSE IF (PENDING_KIND(I) .EQ. 3_I4) THEN                         ! Otherwise, if pending_kind(i) = 3:
          DATABASE%ITEM(INDEX)%HAS_EXPANSION = .TRUE.                    ! Set the flag database.item(index).has_expansion to true.
          DATABASE%ITEM(INDEX)%EXPANSION = PENDING_VALUE(1:6,I)          ! Set database.item(index).expansion to pending_value(1:6,i).
        ELSE IF (PENDING_KIND(I) .EQ. 6_I4) THEN                         ! Otherwise, if pending_kind(i) = 6:
          DATABASE%ITEM(INDEX)%SPECIFIC_HEAT = PENDING_VALUE(1,I)        ! Set database.item(index).specific_heat to pending_value(1,i).
        ELSE IF (PENDING_KIND(I) .EQ. 5_I4) THEN                         ! Otherwise, if pending_kind(i) = 5:
          DATABASE%ITEM(INDEX)%HAS_PYRO = .TRUE.                         ! Set the flag database.item(index).has_pyro to true.
          DATABASE%ITEM(INDEX)%PYRO = PENDING_VALUE(1:3,I)               ! Set database.item(index).pyro to pending_value(1:3,i).
        ELSE                                                             ! Otherwise:
          DATABASE%ITEM(INDEX)%HAS_CONDUCTION = .TRUE.                   ! Set the flag database.item(index).has_conduction to true.
          DO J = 1_I4, 3_I4                                              ! Loop j from 1 to 3:
            DATABASE%ITEM(INDEX)%CONDUCTIVITY(J,:) =                     ! Set database.item(index).conductivity(j,:) to pending_value(3*(j-1)+1:3*j,i).
     &        PENDING_VALUE(3*(J-1)+1:3*J,I)
          END DO                                                         ! End of the loop.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) THEN                                               ! If ios = 0:
        CALL SET_WARNING(STATUS, 'READ_MATERIALS_FILE',                  ! Record a warning in status: 'EXTRA RECORDS AFTER DECLARED COUNT'.
     &                   'EXTRA RECORDS AFTER DECLARED COUNT')
      ELSE IF (IGNORED_COUNT .GT. 0_I4) THEN                             ! Otherwise, if ignored_count > 0:
        CALL SET_WARNING(STATUS, 'READ_MATERIALS_FILE',                  ! Record a warning in status: 'NON-MECHANICAL OR NONSYMMETRIC DATA WERE PRESERVED'.
     &       'NON-MECHANICAL OR NONSYMMETRIC DATA WERE PRESERVED')
      END IF                                                             ! End of the IF block.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_MATERIALS_FILE                                 ! End of the subroutine read materials file.

      SUBROUTINE STORE_MATERIAL(IOS, MATERIAL, LOCAL_STATUS,             ! Subroutine store material takes ios, material, local status, database, found count, status.
     &     DATABASE, FOUND_COUNT, STATUS)

      INTEGER, INTENT(IN) :: IOS                                         ! Input integer: ios.
      TYPE(MATERIAL_TYPE), INTENT(IN) :: MATERIAL                        ! Input of type material_type: material.
      TYPE(STATUS_TYPE), INTENT(IN) :: LOCAL_STATUS                      ! Input of type status_type: local_status.
      TYPE(MATERIAL_DB_TYPE), INTENT(INOUT) :: DATABASE                  ! In/out of type material_db_type: database.
      INTEGER(I4), INTENT(INOUT) :: FOUND_COUNT                          ! In/out integer (int32): found_count.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.

      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                    ! Record an error in status: 'INVALID MECHANICAL MATERIAL RECORD'.
     &                 'INVALID MECHANICAL MATERIAL RECORD')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                         ! If not local_status is ok:
        CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                    ! Record an error in status: trim(local_status.message).
     &                 TRIM(LOCAL_STATUS%MESSAGE))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (FIND_MATERIAL_INDEX(DATABASE,MATERIAL%ID) .NE. 0_I4) THEN      ! If find_material_index(database,material.id) /= 0:
        CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                    ! Record an error in status: 'DUPLICATE MATERIAL ID'.
     &                 'DUPLICATE MATERIAL ID')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (FOUND_COUNT .GE. SIZE(DATABASE%ITEM)) THEN                     ! If found_count >= size(database.item):
        CALL SET_ERROR(STATUS, 'READ_MATERIALS_FILE',                    ! Record an error in status: 'TOO MANY MECHANICAL MATERIALS'.
     &                 'TOO MANY MECHANICAL MATERIALS')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      FOUND_COUNT = FOUND_COUNT + 1_I4                                   ! Add 1 to found_count.
      DATABASE%ITEM(FOUND_COUNT) = MATERIAL                              ! Set database.item(found_count) to material.

      END SUBROUTINE STORE_MATERIAL                                      ! End of the subroutine store material.

      END MODULE MUL2_READ_MATERIALS                                     ! End of the module mul2 read materials.
