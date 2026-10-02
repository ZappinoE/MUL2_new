!=======================================================================
!  USER REFERENCE VECTORS AND ORTHONORMAL ELEMENT FRAMES.
!=======================================================================
      MODULE MUL2_REFERENCE_SYSTEMS                                      ! Module mul2 reference systems begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: REFERENCE_VECTOR_TYPE                              ! Definition of the derived type reference vector type.
        INTEGER(I4) :: ID = 0_I4                                         ! Integer (int32): id = 0.
        REAL(R8) :: DIRECTION(3) = 0.0_R8                                ! Real (real64): direction(3) = 0.0.
      END TYPE REFERENCE_VECTOR_TYPE                                     ! End of the type definition reference vector type.

      TYPE, PUBLIC :: REFERENCE_VECTOR_DB_TYPE                           ! Definition of the derived type reference vector db type.
        TYPE(REFERENCE_VECTOR_TYPE), ALLOCATABLE :: ITEM(:)              ! Allocatable of type reference_vector_type: item(:).
      END TYPE REFERENCE_VECTOR_DB_TYPE                                  ! End of the type definition reference vector db type.

      TYPE, PUBLIC :: ELEMENT_FRAME_DB_TYPE                              ! Definition of the derived type element frame db type.
        REAL(R8), ALLOCATABLE :: ORIGIN(:,:)                             ! Allocatable real (real64): origin(:,:).
        REAL(R8), ALLOCATABLE :: GLOBAL_TO_LOCAL(:,:,:)                  ! Allocatable real (real64): global_to_local(:,:,:).
        REAL(R8), ALLOCATABLE :: LOCAL_TO_GLOBAL(:,:,:)                  ! Allocatable real (real64): local_to_global(:,:,:).
!       CURVED BEAMS AND SHELLS (GENERAL GEOMETRY): INDEX OF THE ELEMENT
!       IN THE COMPACT ARRAYS BELOW (0 = ORDINARY STRAIGHT / FLAT ELEMENT),
!       THE TRIAD OF EVERY NODE (VECTORS A1, A2, A3 OF A SECTION OR OF A
!       SURFACE: SEE MUL2_GENERAL_GEOMETRY) AND THE REFERENCE VECTOR.
        INTEGER(I4), ALLOCATABLE :: GENERAL_INDEX(:)                     ! Allocatable integer (int32): general_index(:).
        REAL(R8), ALLOCATABLE :: GENERAL_TRIAD(:,:,:,:)                  ! Allocatable real (real64): general_triad(:,:,:,:).
        REAL(R8), ALLOCATABLE :: GENERAL_REFERENCE(:,:)                  ! Allocatable real (real64): general_reference(:,:).
!       SHELL NODES SHARED WITH ELEMENTS OF ANOTHER NORMAL (KINKS):
!       CODE 1: THE FIRST-ORDER TERM IS THE ROTATION OF THE NODE; CODE -1:
!       THE ELEMENT THICKNESS AXIS IS OPPOSITE TO THE ONE OF THE NODE.
        INTEGER(I4), ALLOCATABLE :: GENERAL_KINK(:,:)                    ! Allocatable integer (int32): general_kink(:,:).
      END TYPE ELEMENT_FRAME_DB_TYPE                                     ! End of the type definition element frame db type.

      END MODULE MUL2_REFERENCE_SYSTEMS                                  ! End of the module mul2 reference systems.
