!=======================================================================
!  FIELD-DEPENDENT KINEMATICS DEFINITIONS.
!=======================================================================
      MODULE MUL2_KINEMATICS                                             ! Module mul2 kinematics begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, SET_ERROR                      ! Use from module mul2 status: status type, set error.
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: N_FIELDS = 9_I4                  ! Constant public integer (int32): n_fields = 9.
!     FIELDS SOLVED BY THE 101/103 ANALYSES: U, V, W, T, P.
      INTEGER(I4), PARAMETER, PUBLIC :: N_SOLVED_FIELDS = 5_I4           ! Constant public integer (int32): n_solved_fields = 5.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_U = 1_I4                   ! Constant public integer (int32): field_u = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_V = 2_I4                   ! Constant public integer (int32): field_v = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_W = 3_I4                   ! Constant public integer (int32): field_w = 3.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_T = 4_I4                   ! Constant public integer (int32): field_t = 4.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_P = 5_I4                   ! Constant public integer (int32): field_p = 5.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_B = 6_I4                   ! Constant public integer (int32): field_b = 6.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_SZZ = 7_I4                 ! Constant public integer (int32): field_szz = 7.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_SXZ = 8_I4                 ! Constant public integer (int32): field_sxz = 8.
      INTEGER(I4), PARAMETER, PUBLIC :: FIELD_SYZ = 9_I4                 ! Constant public integer (int32): field_syz = 9.

      INTEGER(I4), PARAMETER, PUBLIC :: EXPANSION_NONE = 0_I4            ! Constant public integer (int32): expansion_none = 0.
      INTEGER(I4), PARAMETER, PUBLIC :: EXPANSION_TE = 1_I4              ! Constant public integer (int32): expansion_te = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: EXPANSION_LE = 2_I4              ! Constant public integer (int32): expansion_le = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: EXPANSION_HLE = 3_I4             ! Constant public integer (int32): expansion_hle = 3.
      INTEGER(I4), PARAMETER, PUBLIC :: EXPANSION_MISC = 4_I4            ! Constant public integer (int32): expansion_misc = 4.

      TYPE, PUBLIC :: EXPANSION_SPEC_TYPE                                ! Definition of the derived type expansion spec type.
        INTEGER(I4) :: FAMILY = EXPANSION_NONE                           ! Integer (int32): family = expansion_none.
        INTEGER(I4) :: ORDER = 0_I4                                      ! Integer (int32): order = 0.
        INTEGER(I4) :: FIELD_REFERENCE = 0_I4                            ! Integer (int32): field_reference = 0.
      END TYPE EXPANSION_SPEC_TYPE                                       ! End of the type definition expansion spec type.

      TYPE, PUBLIC :: KINEMATIC_TYPE                                     ! Definition of the derived type kinematic type.
        INTEGER(I4) :: ID = 0_I4                                         ! Integer (int32): id = 0.
        TYPE(EXPANSION_SPEC_TYPE) :: FIELD(N_FIELDS)                     ! Of type expansion_spec_type: field(n_fields).
      END TYPE KINEMATIC_TYPE                                            ! End of the type definition kinematic type.

      TYPE, PUBLIC :: KINEMATICS_DB_TYPE                                 ! Definition of the derived type kinematics db type.
        TYPE(KINEMATIC_TYPE), ALLOCATABLE :: ITEM(:)                     ! Allocatable of type kinematic_type: item(:).
      END TYPE KINEMATICS_DB_TYPE                                        ! End of the type definition kinematics db type.

      PUBLIC :: PARSE_EXPANSION_TOKEN                                    ! Export: parse expansion token.
      PUBLIC :: HAS_KINEMATIC_ID                                         ! Export: has kinematic id.
      PUBLIC :: FIND_KINEMATIC_INDEX                                     ! Export: find kinematic index.
      PUBLIC :: APPLY_FIELD_SELECTION                                    ! Export: apply field selection.
      PUBLIC :: ANY_FIELD_ACTIVE                                         ! Export: any field active.

      CONTAINS                                                           ! The procedures of the module follow.

      LOGICAL FUNCTION HAS_KINEMATIC_ID(DATABASE, ID)                    ! Function has kinematic id takes database, id.

      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: DATABASE                   ! Input of type kinematics_db_type: database.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      HAS_KINEMATIC_ID = FIND_KINEMATIC_INDEX(DATABASE,ID)               ! Set has_kinematic_id to find_kinematic_index(database,id) /= 0.
     &                   .NE. 0_I4

      END FUNCTION HAS_KINEMATIC_ID                                      ! End of the function has kinematic id.

!  THE `FIELDS` RECORD OF ANALYSIS.DAT DECIDES WHICH PHYSICS ARE
!  SOLVED: THE EXPANSIONS OF THE FIELDS THAT ARE SWITCHED OFF ARE
!  DISABLED (THE KINEMATICS KEEP THEIR DEFINITION), AND A FIELD THAT
!  IS SWITCHED ON MUST BE EXPANDED SOMEWHERE.
      SUBROUTINE APPLY_FIELD_SELECTION(DATABASE, THERMO, PIEZO,          ! Subroutine apply field selection takes database, thermo, piezo, status.
     &                                 STATUS)

      TYPE(KINEMATICS_DB_TYPE), INTENT(INOUT) :: DATABASE                ! In/out of type kinematics_db_type: database.
      LOGICAL, INTENT(IN) :: THERMO                                      ! Input logical: thermo.
      LOGICAL, INTENT(IN) :: PIEZO                                       ! Input logical: piezo.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      IF (THERMO .AND. .NOT. ANY_FIELD_ACTIVE(DATABASE, FIELD_T))        ! If thermo and not any_field_active(database, field_t), record an error in status: 'THERMO IS ACTIVE BUT NO ...
     &  CALL SET_ERROR(STATUS, 'APPLY_FIELD_SELECTION',
     &    'THERMO IS ACTIVE BUT NO KINEMATICS EXPANDS THE TEMPERATURE')
      IF (PIEZO .AND. .NOT. ANY_FIELD_ACTIVE(DATABASE, FIELD_P))         ! If piezo and not any_field_active(database, field_p), record an error in status: 'PIEZO IS ACTIVE BUT NO KI...
     &  CALL SET_ERROR(STATUS, 'APPLY_FIELD_SELECTION',
     &    'PIEZO IS ACTIVE BUT NO KINEMATICS EXPANDS THE POTENTIAL')
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (.NOT. THERMO) DATABASE%ITEM(I)%FIELD(FIELD_T) =              ! If not thermo, set database.item(i).field(field_t) to expansion_spec_type(expansion_none, 0, 0).
     &    EXPANSION_SPEC_TYPE(EXPANSION_NONE, 0_I4, 0_I4)
        IF (.NOT. PIEZO) DATABASE%ITEM(I)%FIELD(FIELD_P) =               ! If not piezo, set database.item(i).field(field_p) to expansion_spec_type(expansion_none, 0, 0).
     &    EXPANSION_SPEC_TYPE(EXPANSION_NONE, 0_I4, 0_I4)
      END DO                                                             ! End of the loop.

      END SUBROUTINE APPLY_FIELD_SELECTION                               ! End of the subroutine apply field selection.

!  TRUE WHEN SOME KINEMATIC EXPANDS THE FIELD (1..9) AT ALL.
      LOGICAL FUNCTION ANY_FIELD_ACTIVE(DATABASE, FIELD)                 ! Function any field active takes database, field.

      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: DATABASE                   ! Input of type kinematics_db_type: database.
      INTEGER(I4), INTENT(IN) :: FIELD                                   ! Input integer (int32): field.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      ANY_FIELD_ACTIVE = .FALSE.                                         ! Set the flag any_field_active to false.
      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (DATABASE%ITEM(I)%FIELD(FIELD)%FAMILY .NE. EXPANSION_NONE)    ! If database.item(i).field(field).family /= expansion_none, set the flag any_field_active to true.
     &    ANY_FIELD_ACTIVE = .TRUE.
      END DO                                                             ! End of the loop.

      END FUNCTION ANY_FIELD_ACTIVE                                      ! End of the function any field active.

      INTEGER(I4) FUNCTION FIND_KINEMATIC_INDEX(DATABASE, ID)            ! Function find kinematic index takes database, id.

      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: DATABASE                   ! Input of type kinematics_db_type: database.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_KINEMATIC_INDEX = 0_I4                                        ! Set find_kinematic_index to zero.
      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (DATABASE%ITEM(I)%ID .EQ. ID) THEN                            ! If database.item(i).id = id:
          FIND_KINEMATIC_INDEX = I                                       ! Set find_kinematic_index to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_KINEMATIC_INDEX                                  ! End of the function find kinematic index.

      SUBROUTINE PARSE_EXPANSION_TOKEN(TOKEN, SPEC, STATUS)              ! Subroutine parse expansion token takes token, spec, status.

      CHARACTER(LEN=*), INTENT(IN) :: TOKEN                              ! Input character (length *): token.
      TYPE(EXPANSION_SPEC_TYPE), INTENT(OUT) :: SPEC                     ! Output of type expansion_spec_type: spec.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.
      CHARACTER(LEN=32) :: CLEAN                                         ! Character (length 32): clean.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: VALUE                                               ! Integer (int32): value.

      SPEC%FAMILY = EXPANSION_NONE                                       ! Set spec.family to expansion_none.
      SPEC%ORDER = 0_I4                                                  ! Set spec.order to zero.
      SPEC%FIELD_REFERENCE = 0_I4                                        ! Set spec.field_reference to zero.
      CLEAN = TOKEN                                                      ! Set clean to token.
      CALL UPPERCASE(CLEAN)                                              ! Call uppercase with clean.
      CLEAN = ADJUSTL(CLEAN)                                             ! Set clean to adjustl(clean).

      IF (TRIM(CLEAN) .EQ. 'NONE') RETURN                                ! If trim(clean) = 'NONE', return to the caller.

      IF (TRIM(CLEAN) .EQ. 'LE') THEN                                    ! If trim(clean) = 'LE':
        SPEC%FAMILY = EXPANSION_LE                                       ! Set spec.family to expansion_le.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      IF (TRIM(CLEAN) .EQ. 'HLE') THEN                                   ! If trim(clean) = 'HLE':
        SPEC%FAMILY = EXPANSION_HLE                                      ! Set spec.family to expansion_hle.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      IF (INDEX(CLEAN,'HLE') .EQ. 1) THEN                                ! If index(clean,'HLE') = 1:
        CALL READ_SUFFIX(CLEAN, 4, VALUE, IOS)                           ! Call read suffix with clean, 4, value, ios.
        IF (IOS .NE. 0 .OR. VALUE .LT. 1_I4) THEN                        ! If ios /= 0 or value < 1:
          CALL INVALID_TOKEN(TOKEN, STATUS)                              ! Call invalid token with token, status.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        SPEC%FAMILY = EXPANSION_HLE                                      ! Set spec.family to expansion_hle.
        SPEC%ORDER = VALUE                                               ! Set spec.order to value.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      IF (INDEX(CLEAN,'TE') .EQ. 1) THEN                                 ! If index(clean,'TE') = 1:
        CALL READ_SUFFIX(CLEAN, 3, VALUE, IOS)                           ! Call read suffix with clean, 3, value, ios.
        IF (IOS .NE. 0 .OR. VALUE .LT. 0_I4) THEN                        ! If ios /= 0 or value < 0:
          CALL INVALID_TOKEN(TOKEN, STATUS)                              ! Call invalid token with token, status.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        SPEC%FAMILY = EXPANSION_TE                                       ! Set spec.family to expansion_te.
        SPEC%ORDER = VALUE                                               ! Set spec.order to value.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      IF (CLEAN(1:1) .EQ. 'M') THEN                                      ! If clean(1:1) = 'M':
        CALL READ_SUFFIX(CLEAN, 2, VALUE, IOS)                           ! Call read suffix with clean, 2, value, ios.
        IF (IOS .NE. 0 .OR. VALUE .LT. 1_I4) THEN                        ! If ios /= 0 or value < 1:
          CALL INVALID_TOKEN(TOKEN, STATUS)                              ! Call invalid token with token, status.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        SPEC%FAMILY = EXPANSION_MISC                                     ! Set spec.family to expansion_misc.
        SPEC%FIELD_REFERENCE = VALUE                                     ! Set spec.field_reference to value.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL INVALID_TOKEN(TOKEN, STATUS)                                  ! Call invalid token with token, status.

      END SUBROUTINE PARSE_EXPANSION_TOKEN                               ! End of the subroutine parse expansion token.

      SUBROUTINE READ_SUFFIX(TOKEN, FIRST, VALUE, IOS)                   ! Subroutine read suffix takes token, first, value, ios.

      CHARACTER(LEN=*), INTENT(IN) :: TOKEN                              ! Input character (length *): token.
      INTEGER, INTENT(IN) :: FIRST                                       ! Input integer: first.
      INTEGER(I4), INTENT(OUT) :: VALUE                                  ! Output integer (int32): value.
      INTEGER, INTENT(OUT) :: IOS                                        ! Output integer: ios.

      VALUE = 0_I4                                                       ! Set value to zero.
      IF (LEN_TRIM(TOKEN) .LT. FIRST) THEN                               ! If len_trim(token) < first:
        IOS = 1                                                          ! Set ios to 1.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      READ(TOKEN(FIRST:LEN_TRIM(TOKEN)),*,IOSTAT=IOS) VALUE              ! Read from unit token(first:len_trim(token)) into value.

      END SUBROUTINE READ_SUFFIX                                         ! End of the subroutine read suffix.

      SUBROUTINE INVALID_TOKEN(TOKEN, STATUS)                            ! Subroutine invalid token takes token, status.

      CHARACTER(LEN=*), INTENT(IN) :: TOKEN                              ! Input character (length *): token.
      TYPE(STATUS_TYPE), INTENT(INOUT) :: STATUS                         ! In/out of type status_type: status.

      CALL SET_ERROR(STATUS, 'PARSE_EXPANSION_TOKEN',                    ! Record an error in status: 'INVALID KINEMATIC TOKEN: '//trim(token).
     &               'INVALID KINEMATIC TOKEN: '//TRIM(TOKEN))

      END SUBROUTINE INVALID_TOKEN                                       ! End of the subroutine invalid token.

      END MODULE MUL2_KINEMATICS                                         ! End of the module mul2 kinematics.
