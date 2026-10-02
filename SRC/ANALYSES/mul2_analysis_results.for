!=======================================================================
!  RESULTS SHARED BY THE ANALYSIS DRIVERS AND THE POST-PROCESSING.
!=======================================================================
      MODULE MUL2_ANALYSIS_RESULTS                                       ! Module mul2 analysis results begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_BOUNDARY_APPLICATION, ONLY: CONSTRAINT_SET_TYPE           ! Use from module mul2 boundary application: constraint set type.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

!  SYSTEM: K (AFTER THE STATIC BOUNDARY CONDITIONS FOR 101, FULL AND
!  UNCONSTRAINED FOR 103) AND, FOR 103, M ON THE SAME PATTERN.
!  SOLUTION: DISPLACEMENT COEFFICIENTS IN FIELD-MAJOR DOF ORDER.
!  MODE(:,K): K-TH MODE, M-ORTHONORMAL, IN THE SAME ORDER (DOFS ON
!  CONSTRAINTS ARE ZERO). FREQUENCY IS IN HZ, EIGENVALUE IN (RAD/S)**2.
      TYPE, PUBLIC :: ANALYSIS_RESULTS_TYPE                              ! Definition of the derived type analysis results type.
        INTEGER(I4) :: SOLUTION_ID = 0_I4                                ! Integer (int32): solution_id = 0.
        TYPE(SPARSE_SYSTEM_TYPE) :: SYSTEM                               ! Of type sparse_system_type: system.
        TYPE(CONSTRAINT_SET_TYPE) :: CONSTRAINTS                         ! Of type constraint_set_type: constraints.
        REAL(R8), ALLOCATABLE :: FORCE(:)                                ! Allocatable real (real64): force(:).
        REAL(R8), ALLOCATABLE :: SOLUTION(:)                             ! Allocatable real (real64): solution(:).
        INTEGER(I4) :: MODE_COUNT = 0_I4                                 ! Integer (int32): mode_count = 0.
        REAL(R8), ALLOCATABLE :: EIGENVALUE(:)                           ! Allocatable real (real64): eigenvalue(:).
        REAL(R8), ALLOCATABLE :: FREQUENCY(:)                            ! Allocatable real (real64): frequency(:).
        REAL(R8), ALLOCATABLE :: MODE(:,:)                               ! Allocatable real (real64): mode(:,:).
        REAL(R8), ALLOCATABLE :: RESIDUAL(:)                             ! Allocatable real (real64): residual(:).
        CHARACTER(LEN=8) :: SOLVER_BACKEND = ' '                         ! Character (length 8): solver_backend = ' '.
        INTEGER(I8) :: SOLVER_ITERATIONS = 0_I8                          ! Integer (int64): solver_iterations = 0.
        INTEGER(I8) :: SOLVER_OPERATIONS = 0_I8                          ! Integer (int64): solver_operations = 0.
        INTEGER(I8) :: SOLVER_SUBSPACE = 0_I8                            ! Integer (int64): solver_subspace = 0.
        REAL(R8) :: ASSEMBLY_SECONDS = 0.0_R8                            ! Real (real64): assembly_seconds = 0.0.
        REAL(R8) :: SOLVER_SECONDS = 0.0_R8                              ! Real (real64): solver_seconds = 0.0.
      END TYPE ANALYSIS_RESULTS_TYPE                                     ! End of the type definition analysis results type.

      END MODULE MUL2_ANALYSIS_RESULTS                                   ! End of the module mul2 analysis results.
