!=======================================================================
!  MATERIAL ASSIGNMENTS AND ORIENTATIONS.
!=======================================================================
      MODULE MUL2_LAMINATIONS                                            ! Module mul2 laminations begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: LAMINATION_CONSTANT = 1_I4       ! Constant public integer (int32): lamination_constant = 1.

      TYPE, PUBLIC :: LAMINATION_TYPE                                    ! Definition of the derived type lamination type.
        INTEGER(I4) :: ID = 0_I4                                         ! Integer (int32): id = 0.
        INTEGER(I4) :: KIND = 0_I4                                       ! Integer (int32): kind = 0.
        INTEGER(I4) :: MATERIAL_ID = 0_I4                                ! Integer (int32): material_id = 0.
        REAL(R8) :: ANGLE_Y_DEG = 0.0_R8                                 ! Real (real64): angle_y_deg = 0.0.
        REAL(R8) :: ANGLE_Z_DEG = 0.0_R8                                 ! Real (real64): angle_z_deg = 0.0.
      END TYPE LAMINATION_TYPE                                           ! End of the type definition lamination type.

      TYPE, PUBLIC :: LAMINATION_DB_TYPE                                 ! Definition of the derived type lamination db type.
        TYPE(LAMINATION_TYPE), ALLOCATABLE :: ITEM(:)                    ! Allocatable of type lamination_type: item(:).
      END TYPE LAMINATION_DB_TYPE                                        ! End of the type definition lamination db type.

      PUBLIC :: FIND_LAMINATION_INDEX                                    ! Export: find lamination index.

      CONTAINS                                                           ! The procedures of the module follow.

      INTEGER(I4) FUNCTION FIND_LAMINATION_INDEX(DATABASE, ID)           ! Function find lamination index takes database, id.

      TYPE(LAMINATION_DB_TYPE), INTENT(IN) :: DATABASE                   ! Input of type lamination_db_type: database.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_LAMINATION_INDEX = 0_I4                                       ! Set find_lamination_index to zero.
      IF (.NOT. ALLOCATED(DATABASE%ITEM)) RETURN                         ! If not allocated(database.item), return to the caller.
      DO I = 1_I4, SIZE(DATABASE%ITEM)                                   ! Loop i from 1 to size(database.item):
        IF (DATABASE%ITEM(I)%ID .EQ. ID) THEN                            ! If database.item(i).id = id:
          FIND_LAMINATION_INDEX = I                                      ! Set find_lamination_index to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_LAMINATION_INDEX                                 ! End of the function find lamination index.

      END MODULE MUL2_LAMINATIONS                                        ! End of the module mul2 laminations.
