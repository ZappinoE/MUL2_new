!=======================================================================
!  MECHANICAL BOUNDARY-CONDITION INPUT MODEL.
!=======================================================================
      MODULE MUL2_BOUNDARY_CONDITIONS                                    ! Module mul2 boundary conditions begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: BC_DISPLACEMENT_PLANE = 1_I4     ! Constant public integer (int32): bc_displacement_plane = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: BC_FORCE_POINT = 2_I4            ! Constant public integer (int32): bc_force_point = 2.
!     PRESCRIBED VALUE OF A FIELD (E.G. THE ELECTRIC POTENTIAL) AT A
!     POINT; ON A PLANE THE RECORD IS A BC_DISPLACEMENT_PLANE.
      INTEGER(I4), PARAMETER, PUBLIC :: BC_VALUE_POINT = 3_I4            ! Constant public integer (int32): bc_value_point = 3.
!     FLOATING ELECTRODE: THE POTENTIAL DOFS ON A PLANE SHARE ONE VALUE.
      INTEGER(I4), PARAMETER, PUBLIC :: BC_TIE_PLANE = 4_I4              ! Constant public integer (int32): bc_tie_plane = 4.
!     LOAD ON THE EXPOSED SURFACE (HEAT FLUX, SUN, CONVECTION): SEE
!     MUL2_SURFACE_LOADS. SURFACE = 1 FLUX, 2 SUN, 3 CONVECTION.
      INTEGER(I4), PARAMETER, PUBLIC :: BC_SURFACE = 5_I4                ! Constant public integer (int32): bc_surface = 5.

      TYPE, PUBLIC :: BOUNDARY_CONDITION_TYPE                            ! Definition of the derived type boundary condition type.
        INTEGER(I4) :: KIND = 0_I4                                       ! Integer (int32): kind = 0.
        INTEGER(I4) :: ID = 0_I4                                         ! Integer (int32): id = 0.
        REAL(R8) :: PLANE(4) = 0.0_R8                                    ! Real (real64): plane(4) = 0.0.
        REAL(R8) :: POINT(3) = 0.0_R8                                    ! Real (real64): point(3) = 0.0.
!       ONE ENTRY PER FIELD (U V W T P B SZZ SXZ SYZ).
        LOGICAL :: ACTIVE(9) = .FALSE.                                   ! Logical: active(9) = false.
        REAL(R8) :: VALUE(9) = 0.0_R8                                    ! Real (real64): value(9) = 0.0.
!       SPATIAL FIELD (FIELDS.DAT) MULTIPLYING THE VALUE, 0 = NONE.
        INTEGER(I4) :: FIELD_ID = 0_I4                                   ! Integer (int32): field_id = 0.
        INTEGER(I4) :: SURFACE = 0_I4                                    ! Integer (int32): surface = 0.
        REAL(R8) :: PARAM(6) = 0.0_R8                                    ! Real (real64): param(6) = 0.0.
      END TYPE BOUNDARY_CONDITION_TYPE                                   ! End of the type definition boundary condition type.

      TYPE, PUBLIC :: BOUNDARY_DB_TYPE                                   ! Definition of the derived type boundary db type.
        TYPE(BOUNDARY_CONDITION_TYPE), ALLOCATABLE :: ITEM(:)            ! Allocatable of type boundary_condition_type: item(:).
      END TYPE BOUNDARY_DB_TYPE                                          ! End of the type definition boundary db type.

      END MODULE MUL2_BOUNDARY_CONDITIONS                                ! End of the module mul2 boundary conditions.
