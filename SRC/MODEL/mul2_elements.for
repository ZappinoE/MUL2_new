!=======================================================================
!  FINITE-ELEMENT CONNECTIVITY DEFINITIONS.
!=======================================================================
      MODULE MUL2_ELEMENTS                                               ! Module mul2 elements begins.

      USE MUL2_KINDS, ONLY: I4, I8                                       ! Use from module mul2 kinds: i4, i8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: ELEMENT_TYPE                                       ! Definition of the derived type element type.
        INTEGER(I8) :: ID = 0_I8                                         ! Integer (int64): id = 0.
        INTEGER(I4) :: TOPOLOGY = 0_I4                                   ! Integer (int32): topology = 0.
        INTEGER(I8), ALLOCATABLE :: NODE_ID(:)                           ! Allocatable integer (int64): node_id(:).
        INTEGER(I4) :: FRAME_ID = 0_I4                                   ! Integer (int32): frame_id = 0.
        INTEGER(I4) :: EXPANSION_ID = 0_I4                               ! Integer (int32): expansion_id = 0.
!       TRUE WHEN THE NAME OF THE ELEMENT FORCES THE GENERAL (CURVED)
!       GEOMETRY: S4 S9 S16 (SHELLS), CB2 CB3 CB4 (CURVED BEAMS).
        LOGICAL :: GENERAL = .FALSE.                                     ! Logical: general = false.
      END TYPE ELEMENT_TYPE                                              ! End of the type definition element type.

      TYPE, PUBLIC :: ELEMENT_DB_TYPE                                    ! Definition of the derived type element db type.
        TYPE(ELEMENT_TYPE), ALLOCATABLE :: ITEM(:)                       ! Allocatable of type element_type: item(:).
      END TYPE ELEMENT_DB_TYPE                                           ! End of the type definition element db type.

      END MODULE MUL2_ELEMENTS                                           ! End of the module mul2 elements.
