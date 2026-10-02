!=======================================================================
!  ANALYSIS CONFIGURATION AND POST-PROCESSING REQUESTS.
!
!  SHEAR(1:3) HOLDS THE SHEAR-LOCKING TREATMENT OF BEAM, PLATE AND
!  SOLID ELEMENTS: NONE (FULL INTEGRATION), REDI (REDUCED INTEGRATION
!  OF THE STRUCTURAL ELEMENT), SELI (SELECTIVE: THE TERMS WITH A SHEAR
!  STRAIN ARE REDUCED, THE OTHERS FULL) OR MITC (TIED SHEAR STRAINS).
!=======================================================================
      MODULE MUL2_ANALYSIS_INPUT                                         ! Module mul2 analysis input begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: SOLUTION_STATIC = 101_I4         ! Constant public integer (int32): solution_static = 101.
      INTEGER(I4), PARAMETER, PUBLIC :: SOLUTION_MODAL = 103_I4          ! Constant public integer (int32): solution_modal = 103.
      INTEGER(I4), PARAMETER, PUBLIC :: SOLUTION_TIME = 104_I4           ! Constant public integer (int32): solution_time = 104.
      INTEGER(I4), PARAMETER, PUBLIC :: SOLUTION_BUCKLING = 105_I4       ! Constant public integer (int32): solution_buckling = 105.
      INTEGER(I4), PARAMETER, PUBLIC :: SOLUTION_FREQUENCY = 106_I4      ! Constant public integer (int32): solution_frequency = 106.
      INTEGER(I4), PARAMETER, PUBLIC :: SOLUTION_NONLINEAR = 108_I4      ! Constant public integer (int32): solution_nonlinear = 108.

      INTEGER(I4), PARAMETER, PUBLIC :: SHEAR_NONE = 0_I4                ! Constant public integer (int32): shear_none = 0.
      INTEGER(I4), PARAMETER, PUBLIC :: SHEAR_REDUCED = 1_I4             ! Constant public integer (int32): shear_reduced = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: SHEAR_SELECTIVE = 2_I4           ! Constant public integer (int32): shear_selective = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: SHEAR_MITC = 3_I4                ! Constant public integer (int32): shear_mitc = 3.

      INTEGER(I4), PARAMETER, PUBLIC :: SHEAR_BEAM = 1_I4                ! Constant public integer (int32): shear_beam = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: SHEAR_PLATE = 2_I4               ! Constant public integer (int32): shear_plate = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: SHEAR_SOLID = 3_I4               ! Constant public integer (int32): shear_solid = 3.

      INTEGER(I4), PARAMETER, PUBLIC :: POST_FORMAT_PARAVIEW = 1_I4      ! Constant public integer (int32): post_format_paraview = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: POST_FORMAT_GMSH = 2_I4          ! Constant public integer (int32): post_format_gmsh = 2.
      INTEGER(I4), PARAMETER, PUBLIC :: POST_FRAME_LOCAL = 1_I4          ! Constant public integer (int32): post_frame_local = 1.
      INTEGER(I4), PARAMETER, PUBLIC :: POST_FRAME_GLOBAL = 2_I4         ! Constant public integer (int32): post_frame_global = 2.

      TYPE, PUBLIC :: ANALYSIS_TYPE                                      ! Definition of the derived type analysis type.
        INTEGER(I4) :: SOLUTION = 0_I4                                   ! Integer (int32): solution = 0.
        INTEGER(I4) :: MODE_COUNT = 0_I4                                 ! Integer (int32): mode_count = 0.
!       OPTIONAL `FIELDS` RECORD: THE PHYSICS THAT ARE SOLVED (THE
!       KINEMATICS ONLY DEFINE HOW EACH FIELD IS EXPANDED). WITHOUT THE
!       RECORD (FIELD_RECORD FALSE) EVERY FIELD EXPANDED IN KINEMATICS.DAT
!       IS SOLVED, AS IN THE HISTORICAL FORMAT.
        LOGICAL :: FIELD_RECORD = .FALSE.                                ! Logical: field_record = false.
        LOGICAL :: FIELD_MECH = .TRUE.                                   ! Logical: field_mech = true.
        LOGICAL :: FIELD_THERMO = .FALSE.                                ! Logical: field_thermo = false.
        LOGICAL :: FIELD_PIEZO = .FALSE.                                 ! Logical: field_piezo = false.
!       `JOIN COINCIDENT [TOL]`: DOFS OF DIFFERENT NODES ARE JOINED WHEN
!       THEY ARE THE SAME FIELD AT THE SAME POINT; TOL IS A FRACTION OF
!       THE DIAGONAL OF THE MODEL.
        LOGICAL :: JOIN_COINCIDENT = .FALSE.                             ! Logical: join_coincident = false.
        REAL(R8) :: JOIN_TOLERANCE = 1.0E-6_R8                           ! Real (real64): join_tolerance = 1.0e-6.
        INTEGER(I4) :: SHEAR(3) = SHEAR_NONE                             ! Integer (int32): shear(3) = shear_none.
      END TYPE ANALYSIS_TYPE                                             ! End of the type definition analysis type.

!  ONE `PARA` OR `GMSH` RECORD. SPLIT HOLDS THE NINE SUBDIVISION
!  COUNTS: BEAM (SECTION X, AXIS, SECTION Z), PLATE (X, Y, THICKNESS),
!  SOLID (X, Y, Z). CELL_NODES IS 8 (LINEAR) OR 20/27 (QUADRATIC).
      TYPE, PUBLIC :: POST_FIELD_REQUEST_TYPE                            ! Definition of the derived type post field request type.
        INTEGER(I4) :: FORMAT = POST_FORMAT_PARAVIEW                     ! Integer (int32): format = post_format_paraview.
        INTEGER(I4) :: FRAME = POST_FRAME_GLOBAL                         ! Integer (int32): frame = post_frame_global.
        INTEGER(I4) :: CELL_NODES = 20_I4                                ! Integer (int32): cell_nodes = 20.
        INTEGER(I4) :: SPLIT(9) = 1_I4                                   ! Integer (int32): split(9) = 1.
      END TYPE POST_FIELD_REQUEST_TYPE                                   ! End of the type definition post field request type.

      TYPE, PUBLIC :: POST_POINT_REQUEST_TYPE                            ! Definition of the derived type post point request type.
        INTEGER(I4) :: ID = 0_I4                                         ! Integer (int32): id = 0.
        REAL(R8) :: COORDINATE(3) = 0.0_R8                               ! Real (real64): coordinate(3) = 0.0.
      END TYPE POST_POINT_REQUEST_TYPE                                   ! End of the type definition post point request type.

      TYPE, PUBLIC :: POST_DB_TYPE                                       ! Definition of the derived type post db type.
        TYPE(POST_FIELD_REQUEST_TYPE), ALLOCATABLE :: FIELD(:)           ! Allocatable of type post_field_request_type: field(:).
        TYPE(POST_POINT_REQUEST_TYPE), ALLOCATABLE :: POINT(:)           ! Allocatable of type post_point_request_type: point(:).
        LOGICAL :: WRITE_STIFFNESS = .FALSE.                             ! Logical: write_stiffness = false.
        LOGICAL :: WRITE_MASS = .FALSE.                                  ! Logical: write_mass = false.
        LOGICAL :: WRITE_FORCE = .FALSE.                                 ! Logical: write_force = false.
        LOGICAL :: WRITE_UNKNOWN = .FALSE.                               ! Logical: write_unknown = false.
        LOGICAL :: WRITE_ENERGY = .FALSE.                                ! Logical: write_energy = false.
      END TYPE POST_DB_TYPE                                              ! End of the type definition post db type.

      END MODULE MUL2_ANALYSIS_INPUT                                     ! End of the module mul2 analysis input.
