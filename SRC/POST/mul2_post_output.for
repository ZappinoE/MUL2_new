!=======================================================================
!  SCIENTIFIC OUTPUT FILES OF THE STATIC AND MODAL ANALYSES.
!
!    STATIC/POST_POINT.dat         POINT RESULTS (PNT RECORDS)
!    STATIC/RESULTS_PARA_NN.vtk    PARAVIEW FIELDS (PARA RECORDS)
!    STATIC/RESULTS_GMSH_NN.msh    GMSH FIELDS (GMSH RECORDS)
!    DYNAMIC/FREQUENCIES.dat       NATURAL FREQUENCIES [HZ]
!    DYNAMIC/RESULTS_DYN_PARA.vtk  MODE SHAPES (PARAVIEW)
!    DYNAMIC/RESULTS_DYN_GMSH.msh  MODE SHAPES (GMSH)
!    WORK/K_MAT.dat M_MAT.dat FORCES.dat UNKNOWN.dat   MATRIX DUMPS
!
!  FILE NAMES AND COLUMN LAYOUTS FOLLOW THE BASELINE. THE DOF NUMBERING
!  OF THE DUMPS IS THE V3 FIELD-MAJOR ONE.
!=======================================================================
      MODULE MUL2_POST_OUTPUT                                            ! Module mul2 post output begins.

      USE, INTRINSIC :: IEEE_ARITHMETIC, ONLY: IEEE_VALUE,               ! Use from module ieee arithmetic: ieee value, ieee quiet nan.
     &                                         IEEE_QUIET_NAN
      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, set warning, status is ok, merge status.
     &                       SET_WARNING, STATUS_IS_OK, MERGE_STATUS
      USE MUL2_LOG, ONLY: LOG_INFO, LOG_WARNING                          ! Use from module mul2 log: log info, log warning.
      USE MUL2_FILES, ONLY: ENSURE_DIRECTORY                             ! Use from module mul2 files: ensure directory.
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE                       ! Use from module mul2 model cache: model cache type.
      USE MUL2_ANALYSIS_INPUT, ONLY: POST_FIELD_REQUEST_TYPE,            ! Use from module mul2 analysis input: post field request type, post format paraview, post format gmsh, post ...
     &     POST_FORMAT_PARAVIEW, POST_FORMAT_GMSH,
     &     POST_FRAME_LOCAL
      USE MUL2_ANALYSIS_RESULTS, ONLY: ANALYSIS_RESULTS_TYPE             ! Use from module mul2 analysis results: analysis results type.
      USE MUL2_SPARSE_ASSEMBLY, ONLY: SPARSE_SYSTEM_TYPE                 ! Use from module mul2 sparse assembly: sparse system type.
      USE MUL2_POST_GRID, ONLY: POST_GRID_TYPE, BUILD_POST_GRID,         ! Use from module mul2 post grid: post grid type, build post grid, clear post grid, vtk cell order, gmsh cell...
     &     CLEAR_POST_GRID, VTK_CELL_ORDER, GMSH_CELL_ORDER
      USE MUL2_RECOVERY, ONLY: PLACE_TYPE, POINT_STATE_TYPE,             ! Use from module mul2 recovery: place type, point state type, place setup, place evaluate, state from place,...
     &     PLACE_SETUP, PLACE_EVALUATE, STATE_FROM_PLACE,
     &     DISPLACEMENT_FROM_PLACE, LOCATE_POINT

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      CHARACTER(LEN=*), PARAMETER :: DIR_REPORT = 'REPORT'               ! Constant character (length *): dir_report = 'REPORT'.
      CHARACTER(LEN=*), PARAMETER :: DIR_STATIC = 'STATIC'               ! Constant character (length *): dir_static = 'STATIC'.
      CHARACTER(LEN=*), PARAMETER :: DIR_DYNAMIC = 'DYNAMIC'             ! Constant character (length *): dir_dynamic = 'DYNAMIC'.
      CHARACTER(LEN=*), PARAMETER :: DIR_WORK = 'WORK'                   ! Constant character (length *): dir_work = 'WORK'.
      REAL(R8), PARAMETER :: LOCATE_TOLERANCE = 1.0E-8_R8                ! Constant real (real64): locate_tolerance = 1.0e-8.
!     DIRECTORY AND STEP TAG OF THE FIELD FILES (TIME ANALYSES WRITE ONE
!     FILE PER OUTPUT STEP INTO DYNAMIC).
      CHARACTER(LEN=16), SAVE :: FIELD_DIR = 'STATIC'                    ! Saved character (length 16): field_dir = 'STATIC'.
      CHARACTER(LEN=16), SAVE :: STEP_TAG = ' '                          ! Saved character (length 16): step_tag = ' '.
!     POINTS OF POSTPROCESSING.DAT LOCATED ONCE (STEP 0) AND REUSED BY
!     THE TIME AND FREQUENCY HISTORIES: THE SEARCH IS A NEWTON ITERATION
!     OVER THE ELEMENTS AND DOES NOT DEPEND ON THE SOLUTION.
      LOGICAL, SAVE :: LOCATED = .FALSE.                                 ! Saved logical: located = false.
      INTEGER(I4), ALLOCATABLE, SAVE :: LOC_ELEMENT(:)                   ! Allocatable saved integer (int32): loc_element(:).
      INTEGER(I4), ALLOCATABLE, SAVE :: LOC_SUB(:)                       ! Allocatable saved integer (int32): loc_sub(:).
      REAL(R8), ALLOCATABLE, SAVE :: LOC_NS(:,:)                         ! Allocatable saved real (real64): loc_ns(:,:).
      REAL(R8), ALLOCATABLE, SAVE :: LOC_NE(:,:)                         ! Allocatable saved real (real64): loc_ne(:,:).
      LOGICAL, ALLOCATABLE, SAVE :: LOC_FOUND(:)                         ! Allocatable saved logical: loc_found(:).

      TYPE, PUBLIC :: WARNING_LIST_TYPE                                  ! Definition of the derived type warning list type.
        INTEGER(I4) :: COUNT = 0_I4                                      ! Integer (int32): count = 0.
        CHARACTER(LEN=200) :: TEXT(64) = ' '                             ! Character (length 200): text(64) = ' '.
      END TYPE WARNING_LIST_TYPE                                         ! End of the type definition warning list type.

      PUBLIC :: PREPARE_OUTPUT_DIRECTORIES                               ! Export: prepare output directories.
      PUBLIC :: WRITE_STATIC_OUTPUT                                      ! Export: write static output.
      PUBLIC :: WRITE_TIME_STEP_OUTPUT                                   ! Export: write time step output.
      PUBLIC :: WRITE_FREQUENCY_OUTPUT                                   ! Export: write frequency output.
      PUBLIC :: WRITE_MODAL_OUTPUT                                       ! Export: write modal output.
      PUBLIC :: WRITE_WARNING_FILE                                       ! Export: write warning file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE PREPARE_OUTPUT_DIRECTORIES(STATUS)                      ! Subroutine prepare output directories takes status.

      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL                                         ! Of type status_type: local.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL ENSURE_DIRECTORY(DIR_REPORT, LOCAL)                           ! Call ensure directory with dir_report, local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      CALL ENSURE_DIRECTORY(DIR_STATIC, LOCAL)                           ! Call ensure directory with dir_static, local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      CALL ENSURE_DIRECTORY(DIR_DYNAMIC, LOCAL)                          ! Call ensure directory with dir_dynamic, local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      CALL ENSURE_DIRECTORY(DIR_WORK, LOCAL)                             ! Call ensure directory with dir_work, local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.

      END SUBROUTINE PREPARE_OUTPUT_DIRECTORIES                          ! End of the subroutine prepare output directories.

!=======================================================================
!  STATIC ANALYSIS OUTPUT
!=======================================================================
      SUBROUTINE WRITE_STATIC_OUTPUT(MODEL, CACHE, RESULTS, WARNINGS,    ! Subroutine write static output takes model, cache, results, warnings, status.
     &                               STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(IN) :: RESULTS                 ! Input of type analysis_results_type: results.
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL                                         ! Of type status_type: local.
      TYPE(POST_GRID_TYPE) :: GRID                                       ! Of type post_grid_type: grid.
      TYPE(POINT_STATE_TYPE), ALLOCATABLE :: STATE(:)                    ! Allocatable of type point_state_type: state(:).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (SIZE(MODEL%POST%POINT) .GT. 0_I4) THEN                         ! If size(model.post.point) > 0:
        CALL WRITE_POST_POINTS(MODEL, CACHE, RESULTS%SOLUTION,           ! Call write post points with model, cache, results.solution, warnings, local.
     &                         WARNINGS, LOCAL)
        CALL MERGE_STATUS(LOCAL, STATUS)                                 ! Merge status local into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END IF                                                             ! End of the IF block.

      DO I = 1_I4, SIZE(MODEL%POST%FIELD)                                ! Loop i from 1 to size(model.post.field):
        CALL BUILD_POST_GRID(MODEL, MODEL%POST%FIELD(I)%CELL_NODES,      ! Call build post grid with model, model.post.field(i).cell_nodes, model.post.field(i).split, grid, local.
     &       MODEL%POST%FIELD(I)%SPLIT, GRID, LOCAL)
        CALL MERGE_STATUS(LOCAL, STATUS)                                 ! Merge status local into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        CALL EVALUATE_GRID_STATES(MODEL, CACHE, GRID,                    ! Call evaluate grid states with model, cache, grid, results.solution, state, local.
     &       RESULTS%SOLUTION, STATE, LOCAL)
        CALL MERGE_STATUS(LOCAL, STATUS)                                 ! Merge status local into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        IF (MODEL%POST%FIELD(I)%FORMAT .EQ. POST_FORMAT_GMSH) THEN       ! If model.post.field(i).format = post_format_gmsh:
          CALL WRITE_STATIC_GMSH(MODEL, CACHE, MODEL%POST%FIELD(I),      ! Call write static gmsh with model, cache, model.post.field(i), i, grid, state, local.
     &         I, GRID, STATE, LOCAL)
        ELSE                                                             ! Otherwise:
          CALL WRITE_STATIC_VTK(MODEL, CACHE, MODEL%POST%FIELD(I),       ! Call write static vtk with model, cache, model.post.field(i), i, grid, state, local.
     &         I, GRID, STATE, LOCAL)
        END IF                                                           ! End of the IF block.
        CALL MERGE_STATUS(LOCAL, STATUS)                                 ! Merge status local into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.
      CALL CLEAR_POST_GRID(GRID)                                         ! Call clear post grid with grid.

      CALL WRITE_MATRIX_DUMPS(MODEL, RESULTS, LOCAL)                     ! Call write matrix dumps with model, results, local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.

      END SUBROUTINE WRITE_STATIC_OUTPUT                                 ! End of the subroutine write static output.

!  VALUES OF DISPLACEMENT, STRAIN AND STRESS AT EVERY GRID NODE.
!  CELLS ARE INDEPENDENT AND EVALUATED IN PARALLEL.
      SUBROUTINE EVALUATE_GRID_STATES(MODEL, CACHE, GRID, SOLUTION,      ! Subroutine evaluate grid states takes model, cache, grid, solution, state, status.
     &                                STATE, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      REAL(R8), INTENT(IN) :: SOLUTION(:)                                ! Input real (real64): solution(:).
      TYPE(POINT_STATE_TYPE), ALLOCATABLE, INTENT(INOUT) :: STATE(:)     ! Allocatable in/out of type point_state_type: state(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE), ALLOCATABLE :: CELL_STATUS(:)                   ! Allocatable of type status_type: cell_status(:).
      INTEGER(I4) :: CELL                                                ! Integer (int32): cell.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(STATE)) DEALLOCATE(STATE)                            ! If allocated(state), free the memory of state.
      ALLOCATE(STATE(GRID%NODE_COUNT))                                   ! Allocate memory for state(grid.node_count).
      ALLOCATE(CELL_STATUS(GRID%CELL_COUNT))                             ! Allocate memory for cell_status(grid.cell_count).
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(CELL) SCHEDULE(DYNAMIC,16)
      DO CELL = 1_I4, GRID%CELL_COUNT                                    ! Loop cell from 1 to grid.cell_count:
        CALL EVALUATE_CELL_STATES(MODEL, CACHE, GRID, SOLUTION, CELL,    ! Call evaluate cell states with model, cache, grid, solution, cell, state, cell_status(cell).
     &                            STATE, CELL_STATUS(CELL))
      END DO                                                             ! End of the loop.
!$OMP END PARALLEL DO
      DO CELL = 1_I4, GRID%CELL_COUNT                                    ! Loop cell from 1 to grid.cell_count:
        CALL MERGE_STATUS(CELL_STATUS(CELL), STATUS)                     ! Merge status cell_status(cell) into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_GRID_STATES                                ! End of the subroutine evaluate grid states.

      SUBROUTINE EVALUATE_CELL_STATES(MODEL, CACHE, GRID, SOLUTION,      ! Subroutine evaluate cell states takes model, cache, grid, solution, cell, state, status.
     &                                CELL, STATE, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      REAL(R8), INTENT(IN) :: SOLUTION(:)                                ! Input real (real64): solution(:).
      INTEGER(I4), INTENT(IN) :: CELL                                    ! Input integer (int32): cell.
      TYPE(POINT_STATE_TYPE), INTENT(INOUT) :: STATE(:)                  ! In/out of type point_state_type: state(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PLACE_TYPE) :: PLACE                                          ! Of type place_type: place.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL PLACE_SETUP(MODEL, CACHE, GRID%CELL_ELEMENT(CELL),            ! Call place setup with model, cache, grid.cell_element(cell), grid.cell_sub_element(cell), place, status.
     &                 GRID%CELL_SUB_ELEMENT(CELL), PLACE, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      DO K = 1_I4, GRID%NODES_PER_CELL                                   ! Loop k from 1 to grid.nodes_per_cell:
        NODE = (CELL-1_I4)*GRID%NODES_PER_CELL + K                       ! Set node to (cell-1)*grid.nodes_per_cell + k.
        CALL PLACE_EVALUATE(PLACE, MODEL, CACHE,                         ! Call place evaluate with place, model, cache, grid.natural_structural(:,node), grid.natural_expansion(:,nod...
     &       GRID%NATURAL_STRUCTURAL(:,NODE),
     &       GRID%NATURAL_EXPANSION(:,NODE), .TRUE., STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        CALL STATE_FROM_PLACE(MODEL, CACHE, PLACE, SOLUTION,             ! Call state from place with model, cache, place, solution, state(node), status.
     &                        STATE(NODE), STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_CELL_STATES                                ! End of the subroutine evaluate cell states.
!  LOCATE EVERY POINT REQUEST ONCE AND KEEP THE RESULT (SEE LOCATED).
      SUBROUTINE LOCATE_ALL_POINTS(MODEL, CACHE)                         ! Subroutine locate all points takes model, cache.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(STATUS_TYPE) :: LOCAL                                         ! Of type status_type: local.
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      N = SIZE(MODEL%POST%POINT)                                         ! Set n to the size of model.post.point.
      IF (ALLOCATED(LOC_ELEMENT)) DEALLOCATE(LOC_ELEMENT, LOC_SUB,       ! If allocated(loc_element), free the memory of loc_element, loc_sub, loc_ns, loc_ne, loc_found.
     &                                       LOC_NS, LOC_NE, LOC_FOUND)
      ALLOCATE(LOC_ELEMENT(N), LOC_SUB(N), LOC_NS(3,N), LOC_NE(3,N),     ! Allocate memory for loc_element(n), loc_sub(n), loc_ns(3,n), loc_ne(3,n), loc_found(n).
     &         LOC_FOUND(N))
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        CALL LOCATE_POINT(MODEL, CACHE, MODEL%POST%POINT(I)%COORDINATE,  ! Call locate point with model, cache, model.post.point(i).coordinate, locate_tolerance, loc_element(i), loc_...
     &       LOCATE_TOLERANCE, LOC_ELEMENT(I), LOC_SUB(I), LOC_NS(:,I),
     &       LOC_NE(:,I), LOC_FOUND(I), LOCAL)
      END DO                                                             ! End of the loop.
      LOCATED = .TRUE.                                                   ! Set the flag located to true.

      END SUBROUTINE LOCATE_ALL_POINTS                                   ! End of the subroutine locate all points.

!=======================================================================
!  OUTPUT OF ONE STEP OF A TIME ANALYSIS: DYNAMIC/TIME_HISTORY.dat
!  GETS ONE ROW PER POINT (THE POST_POINT COLUMNS AFTER THE TIME) AND
!  EVERY FIELD REQUEST WRITES DYNAMIC/RESULTS_PARA_NN_SSSSSS.vtk.
!=======================================================================
      SUBROUTINE WRITE_TIME_STEP_OUTPUT(MODEL, CACHE, SOLUTION, STEP,    ! Subroutine write time step output takes model, cache, solution, step, time value, warnings, status.
     &                                  TIME_VALUE, WARNINGS, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      REAL(R8), INTENT(IN) :: SOLUTION(:)                                ! Input real (real64): solution(:).
      INTEGER(I4), INTENT(IN) :: STEP                                    ! Input integer (int32): step.
      REAL(R8), INTENT(IN) :: TIME_VALUE                                 ! Input real (real64): time_value.
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PLACE_TYPE) :: PLACE                                          ! Of type place_type: place.
      TYPE(POINT_STATE_TYPE) :: STATE                                    ! Of type point_state_type: state.
      TYPE(POINT_STATE_TYPE), ALLOCATABLE :: GRID_STATE(:)               ! Allocatable of type point_state_type: grid_state(:).
      TYPE(POST_GRID_TYPE) :: GRID                                       ! Of type post_grid_type: grid.
      TYPE(STATUS_TYPE) :: LOCAL                                         ! Of type status_type: local.
      REAL(R8) :: NATURAL_S(3)                                           ! Real (real64): natural_s(3).
      REAL(R8) :: NATURAL_E(3)                                           ! Real (real64): natural_e(3).
      REAL(R8) :: NOT_A_NUMBER                                           ! Real (real64): not_a_number.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: SUB                                                 ! Integer (int32): sub.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      LOGICAL :: FOUND                                                   ! Logical: found.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      NOT_A_NUMBER = IEEE_VALUE(1.0_R8, IEEE_QUIET_NAN)                  ! Set not_a_number to ieee_value(1.0, ieee_quiet_nan).
      IF (SIZE(MODEL%POST%POINT) .GT. 0_I4) THEN                         ! If size(model.post.point) > 0:
        IF (STEP .EQ. 0_I4) THEN                                         ! If step = 0:
          OPEN(NEWUNIT=UNIT, FILE=DIR_DYNAMIC//'/TIME_HISTORY.dat',      ! Open the file dir_dynamic//'/TIME_HISTORY.dat'.
     &         STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
        ELSE                                                             ! Otherwise:
          OPEN(NEWUNIT=UNIT, FILE=DIR_DYNAMIC//'/TIME_HISTORY.dat',      ! Open the file dir_dynamic//'/TIME_HISTORY.dat'.
     &         STATUS='OLD', POSITION='APPEND', ACTION='WRITE',
     &         IOSTAT=IOS)
        END IF                                                           ! End of the IF block.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'WRITE_TIME_STEP_OUTPUT',               ! Record an error in status: 'CANNOT OPEN DYNAMIC/TIME_HISTORY.dat'.
     &                   'CANNOT OPEN DYNAMIC/TIME_HISTORY.dat')
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        IF (STEP .EQ. 0_I4) THEN                                         ! If step = 0:
          WRITE(UNIT,'(A18)',ADVANCE='NO') 'TIME'                        ! Write to unit unit: 'TIME'.
          CALL WRITE_POINT_HEADER(UNIT)                                  ! Call write point header with unit.
        END IF                                                           ! End of the IF block.
        IF (STEP .EQ. 0_I4 .OR. .NOT. LOCATED) CALL LOCATE_ALL_POINTS(   ! If step = 0 or not located, call locate all points with model, cache.
     &                                              MODEL, CACHE)
        DO I = 1_I4, SIZE(MODEL%POST%POINT)                              ! Loop i from 1 to size(model.post.point):
          ELEMENT = LOC_ELEMENT(I)                                       ! Set element to loc_element(i).
          SUB = LOC_SUB(I)                                               ! Set sub to loc_sub(i).
          NATURAL_S = LOC_NS(:,I)                                        ! Set natural_s to loc_ns(:,i).
          NATURAL_E = LOC_NE(:,I)                                        ! Set natural_e to loc_ne(:,i).
          FOUND = LOC_FOUND(I)                                           ! Set found to loc_found(i).
          IF (FOUND) THEN                                                ! If found:
            CALL PLACE_SETUP(MODEL, CACHE, ELEMENT, SUB, PLACE, LOCAL)   ! Call place setup with model, cache, element, sub, place, local.
            CALL PLACE_EVALUATE(PLACE, MODEL, CACHE, NATURAL_S,          ! Call place evaluate with place, model, cache, natural_s, natural_e, true, local.
     &           NATURAL_E, .TRUE., LOCAL)
            IF (STATUS_IS_OK(LOCAL))                                     ! If local is ok, call state from place with model, cache, place, solution, state, local.
     &        CALL STATE_FROM_PLACE(MODEL, CACHE, PLACE, SOLUTION,
     &                              STATE, LOCAL)
            IF (.NOT. STATUS_IS_OK(LOCAL)) FOUND = .FALSE.               ! If not local is ok, set the flag found to false.
          END IF                                                         ! End of the IF block.
          WRITE(UNIT,'(ES18.9)',ADVANCE='NO') TIME_VALUE                 ! Write to unit unit: time_value.
          IF (FOUND) THEN                                                ! If found:
            CALL WRITE_POINT_ROW(UNIT, MODEL, MODEL%POST%POINT(I)%ID,    ! Call write point row with unit, model, model.post.point(i).id, model.post.point(i).coordinate, state.
     &           MODEL%POST%POINT(I)%COORDINATE, STATE)
          ELSE                                                           ! Otherwise:
            CALL WRITE_MISSING_POINT_ROW(UNIT,                           ! Call write missing point row with unit, model.post.point(i).id, model.post.point(i).coordinate, not_a_number.
     &           MODEL%POST%POINT(I)%ID,
     &           MODEL%POST%POINT(I)%COORDINATE, NOT_A_NUMBER)
            IF (STEP .EQ. 0_I4) CALL ADD_WARNING(WARNINGS, 'POINT '//    ! If step = 0, call add warning with warnings, 'POINT '// trim(integer_text(model.post.point(i).id))// ' IS O...
     &           TRIM(INTEGER_TEXT(MODEL%POST%POINT(I)%ID))//
     &           ' IS OUTSIDE THE MODEL: NO RESULT')
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        CLOSE(UNIT)                                                      ! Close the file.
      END IF                                                             ! End of the IF block.

      FIELD_DIR = DIR_DYNAMIC                                            ! Set field_dir to dir_dynamic.
      WRITE(STEP_TAG,'(A,I6.6)') '_S', STEP                              ! Write to unit step_tag: '_S', step.
      DO I = 1_I4, SIZE(MODEL%POST%FIELD)                                ! Loop i from 1 to size(model.post.field):
        CALL BUILD_POST_GRID(MODEL, MODEL%POST%FIELD(I)%CELL_NODES,      ! Call build post grid with model, model.post.field(i).cell_nodes, model.post.field(i).split, grid, local.
     &       MODEL%POST%FIELD(I)%SPLIT, GRID, LOCAL)
        CALL MERGE_STATUS(LOCAL, STATUS)                                 ! Merge status local into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        CALL EVALUATE_GRID_STATES(MODEL, CACHE, GRID, SOLUTION,          ! Call evaluate grid states with model, cache, grid, solution, grid_state, local.
     &       GRID_STATE, LOCAL)
        CALL MERGE_STATUS(LOCAL, STATUS)                                 ! Merge status local into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
        IF (MODEL%POST%FIELD(I)%FORMAT .EQ. POST_FORMAT_GMSH) THEN       ! If model.post.field(i).format = post_format_gmsh:
          CALL WRITE_STATIC_GMSH(MODEL, CACHE, MODEL%POST%FIELD(I),      ! Call write static gmsh with model, cache, model.post.field(i), i, grid, grid_state, local.
     &         I, GRID, GRID_STATE, LOCAL)
        ELSE                                                             ! Otherwise:
          CALL WRITE_STATIC_VTK(MODEL, CACHE, MODEL%POST%FIELD(I),       ! Call write static vtk with model, cache, model.post.field(i), i, grid, grid_state, local.
     &         I, GRID, GRID_STATE, LOCAL)
        END IF                                                           ! End of the IF block.
        CALL MERGE_STATUS(LOCAL, STATUS)                                 ! Merge status local into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) EXIT                             ! If not status is ok, leave the loop.
      END DO                                                             ! End of the loop.
      FIELD_DIR = DIR_STATIC                                             ! Set field_dir to dir_static.
      STEP_TAG = ' '                                                     ! Set step_tag to ' '.
      CALL CLEAR_POST_GRID(GRID)                                         ! Call clear post grid with grid.

      END SUBROUTINE WRITE_TIME_STEP_OUTPUT                              ! End of the subroutine write time step output.

!=======================================================================
!  OUTPUT OF ONE FREQUENCY OF A HARMONIC RESPONSE: DYNAMIC/
!  FREQ_HISTORY.dat HAS ONE ROW PER POINT AND FREQUENCY:
!    F[HZ] ID RE/IM OF UX UY UZ TEMPERATURE VOLTAGE
!=======================================================================
      SUBROUTINE WRITE_FREQUENCY_OUTPUT(MODEL, CACHE, REAL_PART,         ! Subroutine write frequency output takes model, cache, real part, imaginary part, step, frequency, warnings,...
     &     IMAGINARY_PART, STEP, FREQUENCY, WARNINGS, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      REAL(R8), INTENT(IN) :: REAL_PART(:)                               ! Input real (real64): real_part(:).
      REAL(R8), INTENT(IN) :: IMAGINARY_PART(:)                          ! Input real (real64): imaginary_part(:).
      INTEGER(I4), INTENT(IN) :: STEP                                    ! Input integer (int32): step.
      REAL(R8), INTENT(IN) :: FREQUENCY                                  ! Input real (real64): frequency.
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PLACE_TYPE) :: PLACE                                          ! Of type place_type: place.
      TYPE(POINT_STATE_TYPE) :: STATE_R                                  ! Of type point_state_type: state_r.
      TYPE(POINT_STATE_TYPE) :: STATE_I                                  ! Of type point_state_type: state_i.
      TYPE(STATUS_TYPE) :: LOCAL                                         ! Of type status_type: local.
      REAL(R8) :: NATURAL_S(3)                                           ! Real (real64): natural_s(3).
      REAL(R8) :: NATURAL_E(3)                                           ! Real (real64): natural_e(3).
      REAL(R8) :: NOT_A_NUMBER                                           ! Real (real64): not_a_number.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: SUB                                                 ! Integer (int32): sub.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      LOGICAL :: FOUND                                                   ! Logical: found.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (SIZE(MODEL%POST%POINT) .EQ. 0_I4) RETURN                       ! If size(model.post.point) = 0, return to the caller.
      NOT_A_NUMBER = IEEE_VALUE(1.0_R8, IEEE_QUIET_NAN)                  ! Set not_a_number to ieee_value(1.0, ieee_quiet_nan).
      IF (STEP .EQ. 0_I4) THEN                                           ! If step = 0:
        OPEN(NEWUNIT=UNIT, FILE=DIR_DYNAMIC//'/FREQ_HISTORY.dat',        ! Open the file dir_dynamic//'/FREQ_HISTORY.dat'.
     &       STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
      ELSE                                                               ! Otherwise:
        OPEN(NEWUNIT=UNIT, FILE=DIR_DYNAMIC//'/FREQ_HISTORY.dat',        ! Open the file dir_dynamic//'/FREQ_HISTORY.dat'.
     &       STATUS='OLD', POSITION='APPEND', ACTION='WRITE',
     &       IOSTAT=IOS)
      END IF                                                             ! End of the IF block.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_FREQUENCY_OUTPUT',                 ! Record an error in status: 'CANNOT OPEN DYNAMIC/FREQ_HISTORY.dat'.
     &                 'CANNOT OPEN DYNAMIC/FREQ_HISTORY.dat')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (STEP .EQ. 0_I4) WRITE(UNIT,'(A)')                              ! If step = 0, write to unit unit: 'FREQ[HZ] ID RE(UX) IM(UX) RE(UY) IM(UY) RE(UZ) IM(UZ) '// 'RE(T) IM(T) RE...
     &  'FREQ[HZ] ID  RE(UX) IM(UX) RE(UY) IM(UY) RE(UZ) IM(UZ) '//
     &  'RE(T) IM(T) RE(V) IM(V)'
      IF (STEP .EQ. 0_I4 .OR. .NOT. LOCATED) CALL LOCATE_ALL_POINTS(     ! If step = 0 or not located, call locate all points with model, cache.
     &                                            MODEL, CACHE)
      DO I = 1_I4, SIZE(MODEL%POST%POINT)                                ! Loop i from 1 to size(model.post.point):
        ELEMENT = LOC_ELEMENT(I)                                         ! Set element to loc_element(i).
        SUB = LOC_SUB(I)                                                 ! Set sub to loc_sub(i).
        NATURAL_S = LOC_NS(:,I)                                          ! Set natural_s to loc_ns(:,i).
        NATURAL_E = LOC_NE(:,I)                                          ! Set natural_e to loc_ne(:,i).
        FOUND = LOC_FOUND(I)                                             ! Set found to loc_found(i).
        IF (FOUND) THEN                                                  ! If found:
          CALL PLACE_SETUP(MODEL, CACHE, ELEMENT, SUB, PLACE, LOCAL)     ! Call place setup with model, cache, element, sub, place, local.
          CALL PLACE_EVALUATE(PLACE, MODEL, CACHE, NATURAL_S,            ! Call place evaluate with place, model, cache, natural_s, natural_e, true, local.
     &         NATURAL_E, .TRUE., LOCAL)
          IF (STATUS_IS_OK(LOCAL)) THEN                                  ! If local is ok:
            CALL STATE_FROM_PLACE(MODEL, CACHE, PLACE, REAL_PART,        ! Call state from place with model, cache, place, real_part, state_r, local.
     &                            STATE_R, LOCAL)
            IF (STATUS_IS_OK(LOCAL))                                     ! If local is ok, call state from place with model, cache, place, imaginary_part, state_i, local.
     &        CALL STATE_FROM_PLACE(MODEL, CACHE, PLACE,
     &                              IMAGINARY_PART, STATE_I, LOCAL)
          END IF                                                         ! End of the IF block.
          IF (.NOT. STATUS_IS_OK(LOCAL)) FOUND = .FALSE.                 ! If not local is ok, set the flag found to false.
        END IF                                                           ! End of the IF block.
        IF (FOUND) THEN                                                  ! If found:
          WRITE(UNIT,'(ES18.9,I5,10ES18.9)') FREQUENCY,                  ! Write to unit unit: frequency, model.post.point(i).id, state_r.displacement(1), state_i.displacement(1), st...
     &      MODEL%POST%POINT(I)%ID, STATE_R%DISPLACEMENT(1),
     &      STATE_I%DISPLACEMENT(1), STATE_R%DISPLACEMENT(2),
     &      STATE_I%DISPLACEMENT(2), STATE_R%DISPLACEMENT(3),
     &      STATE_I%DISPLACEMENT(3), STATE_R%TEMPERATURE,
     &      STATE_I%TEMPERATURE, STATE_R%POTENTIAL, STATE_I%POTENTIAL
        ELSE                                                             ! Otherwise:
          WRITE(UNIT,'(ES18.9,I5,10ES18.9)') FREQUENCY,                  ! Write to unit unit: frequency, model.post.point(i).id, (not_a_number, sub=1,10).
     &      MODEL%POST%POINT(I)%ID, (NOT_A_NUMBER, SUB=1,10)
          IF (STEP .EQ. 0_I4) CALL ADD_WARNING(WARNINGS, 'POINT '//      ! If step = 0, call add warning with warnings, 'POINT '// trim(integer_text(model.post.point(i).id))// ' IS O...
     &      TRIM(INTEGER_TEXT(MODEL%POST%POINT(I)%ID))//
     &      ' IS OUTSIDE THE MODEL: NO RESULT')
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE WRITE_FREQUENCY_OUTPUT                              ! End of the subroutine write frequency output.

!=======================================================================
!  POINT RESULTS
!=======================================================================
      SUBROUTINE WRITE_POST_POINTS(MODEL, CACHE, SOLUTION, WARNINGS,     ! Subroutine write post points takes model, cache, solution, warnings, status.
     &                             STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      REAL(R8), INTENT(IN) :: SOLUTION(:)                                ! Input real (real64): solution(:).
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PLACE_TYPE) :: PLACE                                          ! Of type place_type: place.
      TYPE(POINT_STATE_TYPE) :: STATE                                    ! Of type point_state_type: state.
      TYPE(STATUS_TYPE) :: LOCAL                                         ! Of type status_type: local.
      REAL(R8) :: NATURAL_S(3)                                           ! Real (real64): natural_s(3).
      REAL(R8) :: NATURAL_E(3)                                           ! Real (real64): natural_e(3).
      REAL(R8) :: NOT_A_NUMBER                                           ! Real (real64): not_a_number.
      INTEGER(I4) :: ELEMENT                                             ! Integer (int32): element.
      INTEGER(I4) :: SUB                                                 ! Integer (int32): sub.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      LOGICAL :: FOUND                                                   ! Logical: found.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      NOT_A_NUMBER = IEEE_VALUE(1.0_R8, IEEE_QUIET_NAN)                  ! Set not_a_number to ieee_value(1.0, ieee_quiet_nan).
      OPEN(NEWUNIT=UNIT, FILE=DIR_STATIC//'/POST_POINT.dat',             ! Open the file dir_static//'/POST_POINT.dat'.
     &     STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_POST_POINTS',                      ! Record an error in status: 'CANNOT OPEN STATIC/POST_POINT.dat'.
     &                 'CANNOT OPEN STATIC/POST_POINT.dat')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL WRITE_POINT_HEADER(UNIT)                                      ! Call write point header with unit.

      DO I = 1_I4, SIZE(MODEL%POST%POINT)                                ! Loop i from 1 to size(model.post.point):
        CALL LOCATE_POINT(MODEL, CACHE,                                  ! Call locate point with model, cache, model.post.point(i).coordinate, locate_tolerance, element, sub, natura...
     &       MODEL%POST%POINT(I)%COORDINATE, LOCATE_TOLERANCE,
     &       ELEMENT, SUB, NATURAL_S, NATURAL_E, FOUND, LOCAL)
        IF (FOUND) THEN                                                  ! If found:
          CALL PLACE_SETUP(MODEL, CACHE, ELEMENT, SUB, PLACE, LOCAL)     ! Call place setup with model, cache, element, sub, place, local.
          CALL PLACE_EVALUATE(PLACE, MODEL, CACHE, NATURAL_S,            ! Call place evaluate with place, model, cache, natural_s, natural_e, true, local.
     &         NATURAL_E, .TRUE., LOCAL)
          IF (STATUS_IS_OK(LOCAL))                                       ! If local is ok, call state from place with model, cache, place, solution, state, local.
     &      CALL STATE_FROM_PLACE(MODEL, CACHE, PLACE, SOLUTION,
     &                            STATE, LOCAL)
          IF (.NOT. STATUS_IS_OK(LOCAL)) FOUND = .FALSE.                 ! If not local is ok, set the flag found to false.
        END IF                                                           ! End of the IF block.
        IF (FOUND) THEN                                                  ! If found:
          CALL WRITE_POINT_ROW(UNIT, MODEL, MODEL%POST%POINT(I)%ID,      ! Call write point row with unit, model, model.post.point(i).id, model.post.point(i).coordinate, state.
     &         MODEL%POST%POINT(I)%COORDINATE, STATE)
        ELSE                                                             ! Otherwise:
          CALL WRITE_MISSING_POINT_ROW(UNIT, MODEL%POST%POINT(I)%ID,     ! Call write missing point row with unit, model.post.point(i).id, model.post.point(i).coordinate, not_a_number.
     &         MODEL%POST%POINT(I)%COORDINATE, NOT_A_NUMBER)
          CALL ADD_WARNING(WARNINGS, 'POINT '//                          ! Call add warning with warnings, 'POINT '// trim(integer_text(model.post.point(i).id))// ' IS OUTSIDE THE MO...
     &         TRIM(INTEGER_TEXT(MODEL%POST%POINT(I)%ID))//
     &         ' IS OUTSIDE THE MODEL: NO RESULT')
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE WRITE_POST_POINTS                                   ! End of the subroutine write post points.

      SUBROUTINE WRITE_POINT_HEADER(UNIT)                                ! Subroutine write point header takes unit.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.

      WRITE(UNIT,'(A4)',ADVANCE='NO') 'ID'                               ! Write to unit unit: 'ID'.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3A18)',ADVANCE='NO') 'X_EVAL','Y_EVAL','Z_EVAL'       ! Write to unit unit: 'X_EVAL', 'Y_EVAL', 'Z_EVAL'.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '  '                               ! Write to unit unit: ' '.
      WRITE(UNIT,'(3A18)',ADVANCE='NO') 'X_REQ','Y_REQ','Z_REQ'          ! Write to unit unit: 'X_REQ', 'Y_REQ', 'Z_REQ'.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(A7)',ADVANCE='NO') 'LAM'                              ! Write to unit unit: 'LAM'.
      WRITE(UNIT,'(A7)',ADVANCE='NO') 'ELE'                              ! Write to unit unit: 'ELE'.
      WRITE(UNIT,'(A7)',ADVANCE='NO') 'S_ELE'                            ! Write to unit unit: 'S_ELE'.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3A18)',ADVANCE='NO') 'U_X','U_Y','U_Z'                ! Write to unit unit: 'U_X', 'U_Y', 'U_Z'.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6A18)',ADVANCE='NO') 'EPS_XX(LOC)','EPS_YY(LOC)',     ! Write to unit unit: 'EPS_XX(LOC)', 'EPS_YY(LOC)', 'EPS_ZZ(LOC)', 'EPS_XZ(LOC)', 'EPS_YZ(LOC)', 'EPS_XY(LOC)'.
     &  'EPS_ZZ(LOC)','EPS_XZ(LOC)','EPS_YZ(LOC)','EPS_XY(LOC)'
      WRITE(UNIT,'(A4)',ADVANCE='NO') '      '                           ! Write to unit unit: ' '.
      WRITE(UNIT,'(6A18)',ADVANCE='NO') 'EPS_XX(GLB)','EPS_YY(GLB)',     ! Write to unit unit: 'EPS_XX(GLB)', 'EPS_YY(GLB)', 'EPS_ZZ(GLB)', 'EPS_XZ(GLB)', 'EPS_YZ(GLB)', 'EPS_XY(GLB)'.
     &  'EPS_ZZ(GLB)','EPS_XZ(GLB)','EPS_YZ(GLB)','EPS_XY(GLB)'
      WRITE(UNIT,'(A6)',ADVANCE='NO') '      '                           ! Write to unit unit: ' '.
      WRITE(UNIT,'(6A18)',ADVANCE='NO') 'SIG_XX(LOC)','SIG_YY(LOC)',     ! Write to unit unit: 'SIG_XX(LOC)', 'SIG_YY(LOC)', 'SIG_ZZ(LOC)', 'SIG_XZ(LOC)', 'SIG_YZ(LOC)', 'SIG_XY(LOC)'.
     &  'SIG_ZZ(LOC)','SIG_XZ(LOC)','SIG_YZ(LOC)','SIG_XY(LOC)'
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6A18)',ADVANCE='NO') 'SIG_XX(GLB)','SIG_YY(GLB)',     ! Write to unit unit: 'SIG_XX(GLB)', 'SIG_YY(GLB)', 'SIG_ZZ(GLB)', 'SIG_XZ(GLB)', 'SIG_YZ(GLB)', 'SIG_XY(GLB)'.
     &  'SIG_ZZ(GLB)','SIG_XZ(GLB)','SIG_YZ(GLB)','SIG_XY(GLB)'
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3A18)',ADVANCE='NO') 'DT','VOLT','%H'                 ! Write to unit unit: 'DT', 'VOLT', '%H'.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6A18)',ADVANCE='NO') 'E11','E22','E33',               ! Write to unit unit: 'E11', 'E22', 'E33', 'D11', 'D22', 'D33'.
     &                                  'D11','D22','D33'
      WRITE(UNIT,'(A)') ''                                               ! Write to unit unit: ''.

      END SUBROUTINE WRITE_POINT_HEADER                                  ! End of the subroutine write point header.

      SUBROUTINE WRITE_POINT_ROW(UNIT, MODEL, ID, REQUEST, STATE)        ! Subroutine write point row takes unit, model, id, request, state.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.
      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      REAL(R8), INTENT(IN) :: REQUEST(3)                                 ! Input real (real64): request(3).
      TYPE(POINT_STATE_TYPE), INTENT(IN) :: STATE                        ! Input of type point_state_type: state.
      REAL(R8), PARAMETER :: ZERO(6) = 0.0_R8                            ! Constant real (real64): zero(6) = 0.0.
      INTEGER(I4) :: SUB_ID                                              ! Integer (int32): sub_id.

      SUB_ID = INT(MODEL%EXPANSIONS%ITEM(FIND_MESH(MODEL,                ! Set sub_id to int(model.expansions.item(find_mesh(model, state.element)).element(state.sub_element).id,i4).
     &  STATE%ELEMENT))%ELEMENT(STATE%SUB_ELEMENT)%ID,I4)
      WRITE(UNIT,'(I4)',ADVANCE='NO') ID                                 ! Write to unit unit: id.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3E18.9)',ADVANCE='NO') STATE%COORDINATE               ! Write to unit unit: state.coordinate.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '  '                               ! Write to unit unit: ' '.
      WRITE(UNIT,'(3E18.9)',ADVANCE='NO') REQUEST                        ! Write to unit unit: request.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(I7)',ADVANCE='NO') STATE%LAMINATION_ID                ! Write to unit unit: state.lamination_id.
      WRITE(UNIT,'(I7)',ADVANCE='NO')                                    ! Write to unit unit: int(model.elements.item(state.element).id,i4).
     &  INT(MODEL%ELEMENTS%ITEM(STATE%ELEMENT)%ID,I4)
      WRITE(UNIT,'(I7)',ADVANCE='NO') SUB_ID                             ! Write to unit unit: sub_id.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3ES18.9E3)',ADVANCE='NO') STATE%DISPLACEMENT          ! Write to unit unit: state.displacement.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') STATE%STRAIN_LOCAL             ! Write to unit unit: state.strain_local.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '      '                           ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') STATE%STRAIN_GLOBAL            ! Write to unit unit: state.strain_global.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '      '                           ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') STATE%STRESS_LOCAL             ! Write to unit unit: state.stress_local.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') STATE%STRESS_GLOBAL            ! Write to unit unit: state.stress_global.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3E18.9)',ADVANCE='NO') [STATE%TEMPERATURE,            ! Write to unit unit: [state.temperature, state.potential, 0.0].
     &                                     STATE%POTENTIAL, 0.0_R8]
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') STATE%ELECTRIC_FIELD_GLOBAL,   ! Write to unit unit: state.electric_field_global, state.electric_displacement_global.
     &  STATE%ELECTRIC_DISPLACEMENT_GLOBAL
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3E18.9)',ADVANCE='NO') STATE%HEAT_FLUX_GLOBAL         ! Write to unit unit: state.heat_flux_global.
      WRITE(UNIT,'(A)') ''                                               ! Write to unit unit: ''.

      END SUBROUTINE WRITE_POINT_ROW                                     ! End of the subroutine write point row.

      SUBROUTINE WRITE_MISSING_POINT_ROW(UNIT, ID, REQUEST, NAN)         ! Subroutine write missing point row takes unit, id, request, nan.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.
      INTEGER(I4), INTENT(IN) :: ID                                      ! Input integer (int32): id.
      REAL(R8), INTENT(IN) :: REQUEST(3)                                 ! Input real (real64): request(3).
      REAL(R8), INTENT(IN) :: NAN                                        ! Input real (real64): nan.
      REAL(R8) :: EMPTY(6)                                               ! Real (real64): empty(6).

      EMPTY = NAN                                                        ! Set empty to nan.
      WRITE(UNIT,'(I4)',ADVANCE='NO') ID                                 ! Write to unit unit: id.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3E18.9)',ADVANCE='NO') EMPTY(1:3)                     ! Write to unit unit: empty(1:3).
      WRITE(UNIT,'(A4)',ADVANCE='NO') '  '                               ! Write to unit unit: ' '.
      WRITE(UNIT,'(3E18.9)',ADVANCE='NO') REQUEST                        ! Write to unit unit: request.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3I7)',ADVANCE='NO') 0, 0, 0                           ! Write to unit unit: 0, 0, 0.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3ES18.9E3)',ADVANCE='NO') EMPTY(1:3)                  ! Write to unit unit: empty(1:3).
      WRITE(UNIT,'(A6)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') EMPTY                          ! Write to unit unit: empty.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '      '                           ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') EMPTY                          ! Write to unit unit: empty.
      WRITE(UNIT,'(A6)',ADVANCE='NO') '      '                           ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') EMPTY                          ! Write to unit unit: empty.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') EMPTY                          ! Write to unit unit: empty.
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(3E18.9)',ADVANCE='NO') EMPTY(1:3)                     ! Write to unit unit: empty(1:3).
      WRITE(UNIT,'(A4)',ADVANCE='NO') '    '                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(6E18.9)',ADVANCE='NO') EMPTY                          ! Write to unit unit: empty.
      WRITE(UNIT,'(A)') ''                                               ! Write to unit unit: ''.

      END SUBROUTINE WRITE_MISSING_POINT_ROW                             ! End of the subroutine write missing point row.

      INTEGER(I4) FUNCTION FIND_MESH(MODEL, ELEMENT)                     ! Function find mesh takes model, element.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      INTEGER(I4), INTENT(IN) :: ELEMENT                                 ! Input integer (int32): element.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      FIND_MESH = 1_I4                                                   ! Set find_mesh to 1.
      DO I = 1_I4, SIZE(MODEL%EXPANSIONS%ITEM)                           ! Loop i from 1 to size(model.expansions.item):
        IF (MODEL%EXPANSIONS%ITEM(I)%ID .EQ.                             ! If model.expansions.item(i).id = model.elements.item(element).expansion_id:
     &      MODEL%ELEMENTS%ITEM(ELEMENT)%EXPANSION_ID) THEN
          FIND_MESH = I                                                  ! Set find_mesh to i.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION FIND_MESH                                             ! End of the function find mesh.

!=======================================================================
!  PARAVIEW / GMSH WRITERS (SHARED BY STATIC AND MODAL OUTPUT)
!=======================================================================
      SUBROUTINE WRITE_VTK_GEOMETRY(UNIT, GRID, COORDINATE)              ! Subroutine write vtk geometry takes unit, grid, coordinate.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.
      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      REAL(R8), INTENT(IN) :: COORDINATE(:,:)                            ! Input real (real64): coordinate(:,:).
      INTEGER(I4) :: ORDER(20)                                           ! Integer (int32): order(20).
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: CELL                                                ! Integer (int32): cell.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.

      CALL VTK_CELL_ORDER(GRID%NODES_PER_CELL, ORDER, COUNT)             ! Call vtk cell order with grid.nodes_per_cell, order, count.
      WRITE(UNIT,'(A26)') '# vtk DataFile Version 2.0'                   ! Write to unit unit: '# vtk DataFile Version 2.0'.
      WRITE(UNIT,'(A29)') 'Generated by MUL2 - Zappino'                  ! Write to unit unit: 'Generated by MUL2 - Zappino'.
      WRITE(UNIT,'(A5)') 'ASCII'                                         ! Write to unit unit: 'ASCII'.
      WRITE(UNIT,'(A25)') 'DATASET UNSTRUCTURED_GRID'                    ! Write to unit unit: 'DATASET UNSTRUCTURED_GRID'.
      WRITE(UNIT,'(A7,I8,A7)') 'POINTS ', GRID%NODE_COUNT, ' double'     ! Write to unit unit: 'POINTS ', grid.node_count, ' double'.
      DO NODE = 1_I4, GRID%NODE_COUNT                                    ! Loop node from 1 to grid.node_count:
        WRITE(UNIT,'(3F15.9)') COORDINATE(:,NODE)                        ! Write to unit unit: coordinate(:,node).
      END DO                                                             ! End of the loop.
      WRITE(UNIT,'(A9)') ' '                                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(A6,I8,I8)') 'CELLS', GRID%CELL_COUNT,                 ! Write to unit unit: 'CELLS', grid.cell_count, grid.cell_count*(count+1).
     &                         GRID%CELL_COUNT*(COUNT+1_I4)
      DO CELL = 1_I4, GRID%CELL_COUNT                                    ! Loop cell from 1 to grid.cell_count:
        WRITE(UNIT,'(I9,20I9)') COUNT, (                                 ! Write to unit unit: count, ( (cell-1)*grid.nodes_per_cell+order(k)-1, k=1,count).
     &    (CELL-1_I4)*GRID%NODES_PER_CELL+ORDER(K)-1_I4,
     &    K=1_I4,COUNT)
      END DO                                                             ! End of the loop.
      WRITE(UNIT,'(A9)') ' '                                             ! Write to unit unit: ' '.
      WRITE(UNIT,'(A13,I8)') 'CELL_TYPES ', GRID%CELL_COUNT              ! Write to unit unit: 'CELL_TYPES ', grid.cell_count.
      DO CELL = 1_I4, GRID%CELL_COUNT                                    ! Loop cell from 1 to grid.cell_count:
        IF (COUNT .EQ. 8_I4) THEN                                        ! If count = 8:
          WRITE(UNIT,'(A2)') '12'                                        ! Write to unit unit: '12'.
        ELSE                                                             ! Otherwise:
          WRITE(UNIT,'(A2)') '25'                                        ! Write to unit unit: '25'.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      WRITE(UNIT,'(A11,I8)') 'POINT_DATA ', GRID%NODE_COUNT              ! Write to unit unit: 'POINT_DATA ', grid.node_count.

      END SUBROUTINE WRITE_VTK_GEOMETRY                                  ! End of the subroutine write vtk geometry.

      SUBROUTINE WRITE_VTK_VECTOR(UNIT, TITLE, VALUE)                    ! Subroutine write vtk vector takes unit, title, value.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.
      CHARACTER(LEN=*), INTENT(IN) :: TITLE                              ! Input character (length *): title.
      REAL(R8), INTENT(IN) :: VALUE(:,:)                                 ! Input real (real64): value(:,:).
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.

      WRITE(UNIT,'(A)') TITLE                                            ! Write to unit unit: title.
      DO NODE = 1_I4, SIZE(VALUE,2)                                      ! Loop node from 1 to size(value,2):
        WRITE(UNIT,'(3ES24.9E3)') VALUE(:,NODE)                          ! Write to unit unit: value(:,node).
      END DO                                                             ! End of the loop.

      END SUBROUTINE WRITE_VTK_VECTOR                                    ! End of the subroutine write vtk vector.

      SUBROUTINE WRITE_VTK_SCALAR(UNIT, NAME, VALUE)                     ! Subroutine write vtk scalar takes unit, name, value.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.
      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      REAL(R8), INTENT(IN) :: VALUE(:)                                   ! Input real (real64): value(:).
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.

      WRITE(UNIT,'(A)') ' SCALARS '//NAME//' double 1'                   ! Write to unit unit: ' SCALARS '//name//' double 1'.
      WRITE(UNIT,'(A)') ' LOOKUP_TABLE default'                          ! Write to unit unit: ' LOOKUP_TABLE default'.
      DO NODE = 1_I4, SIZE(VALUE)                                        ! Loop node from 1 to size(value):
        WRITE(UNIT,'(ES24.9E3)') VALUE(NODE)                             ! Write to unit unit: value(node).
      END DO                                                             ! End of the loop.

      END SUBROUTINE WRITE_VTK_SCALAR                                    ! End of the subroutine write vtk scalar.

!  NODAL DATA IN THE FRAME REQUESTED BY THE POST-PROCESSING RECORD.
      SUBROUTINE SELECT_FRAME(CACHE, REQUEST, STATE, DISPLACEMENT,       ! Subroutine select frame takes cache, request, state, displacement, strain, stress.
     &                        STRAIN, STRESS)

      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(POST_FIELD_REQUEST_TYPE), INTENT(IN) :: REQUEST               ! Input of type post_field_request_type: request.
      TYPE(POINT_STATE_TYPE), INTENT(IN) :: STATE(:)                     ! Input of type point_state_type: state(:).
      REAL(R8), INTENT(OUT) :: DISPLACEMENT(:,:)                         ! Output real (real64): displacement(:,:).
      REAL(R8), INTENT(OUT) :: STRAIN(:,:)                               ! Output real (real64): strain(:,:).
      REAL(R8), INTENT(OUT) :: STRESS(:,:)                               ! Output real (real64): stress(:,:).
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.

      DO NODE = 1_I4, SIZE(STATE)                                        ! Loop node from 1 to size(state):
        IF (REQUEST%FRAME .EQ. POST_FRAME_LOCAL) THEN                    ! If request.frame = post_frame_local:
          DISPLACEMENT(:,NODE) = MATMUL(STATE(NODE)%FRAME,               ! Set displacement(:,node) to matmul(state(node).frame, state(node).displacement).
     &      STATE(NODE)%DISPLACEMENT)
          STRAIN(:,NODE) = STATE(NODE)%STRAIN_LOCAL                      ! Set strain(:,node) to state(node).strain_local.
          STRESS(:,NODE) = STATE(NODE)%STRESS_LOCAL                      ! Set stress(:,node) to state(node).stress_local.
        ELSE                                                             ! Otherwise:
          DISPLACEMENT(:,NODE) = STATE(NODE)%DISPLACEMENT                ! Set displacement(:,node) to state(node).displacement.
          STRAIN(:,NODE) = STATE(NODE)%STRAIN_GLOBAL                     ! Set strain(:,node) to state(node).strain_global.
          STRESS(:,NODE) = STATE(NODE)%STRESS_GLOBAL                     ! Set stress(:,node) to state(node).stress_global.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SELECT_FRAME                                        ! End of the subroutine select frame.

      REAL(R8) FUNCTION VON_MISES(S)                                     ! Function von mises takes s.

      REAL(R8), INTENT(IN) :: S(6)                                       ! Input real (real64): s(6).

      VON_MISES = SQRT(((S(1)-S(2))**2+(S(2)-S(3))**2+                   ! Set von_mises to the square root of ((s(1)-s(2))**2+(s(2)-s(3))**2+ (s(3)-s(1))**2+6.0*(s(4)**2+s(5)**2+s(6...
     &  (S(3)-S(1))**2+6.0_R8*(S(4)**2+S(5)**2+S(6)**2))*0.5_R8)

      END FUNCTION VON_MISES                                             ! End of the function von mises.

      SUBROUTINE WRITE_STATIC_VTK(MODEL, CACHE, REQUEST, NUMBER, GRID,   ! Subroutine write static vtk takes model, cache, request, number, grid, state, status.
     &                            STATE, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(POST_FIELD_REQUEST_TYPE), INTENT(IN) :: REQUEST               ! Input of type post_field_request_type: request.
      INTEGER(I4), INTENT(IN) :: NUMBER                                  ! Input integer (int32): number.
      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      TYPE(POINT_STATE_TYPE), INTENT(IN) :: STATE(:)                     ! Input of type point_state_type: state(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: COORDINATE(:,:)                           ! Allocatable real (real64): coordinate(:,:).
      REAL(R8), ALLOCATABLE :: DISPLACEMENT(:,:)                         ! Allocatable real (real64): displacement(:,:).
      REAL(R8), ALLOCATABLE :: STRAIN(:,:)                               ! Allocatable real (real64): strain(:,:).
      REAL(R8), ALLOCATABLE :: STRESS(:,:)                               ! Allocatable real (real64): stress(:,:).
      REAL(R8), ALLOCATABLE :: WORK(:)                                   ! Allocatable real (real64): work(:).
      CHARACTER(LEN=64) :: FILE_NAME                                     ! Character (length 64): file_name.
      CHARACTER(LEN=16), PARAMETER :: STRESS_NAME(6) = [                 ! Constant character (length 16): stress_name(6) = [ 'Sigma_XX', 'Sigma_YY', 'Sigma_ZZ', 'Sigma_XZ', 'Sigma_Y...
     &  'Sigma_XX', 'Sigma_YY', 'Sigma_ZZ', 'Sigma_XZ', 'Sigma_YZ',
     &  'Sigma_XY']
      CHARACTER(LEN=16), PARAMETER :: STRAIN_NAME(6) = [                 ! Constant character (length 16): strain_name(6) = [ 'Epsilon_XX', 'Epsilon_YY', 'Epsilon_ZZ', 'Epsilon_XZ', ...
     &  'Epsilon_XX', 'Epsilon_YY', 'Epsilon_ZZ', 'Epsilon_XZ',
     &  'Epsilon_YZ', 'Epsilon_XY']
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      CHARACTER(LEN=2), PARAMETER :: FIELD_NAME(3) = ['EX', 'EY', 'EZ']  ! Constant character (length 2): field_name(3) = ['EX', 'EY', 'EZ'].

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N = GRID%NODE_COUNT                                                ! Set n to grid.node_count.
      WRITE(FILE_NAME,'(A,A,I2.2,A,A)') TRIM(FIELD_DIR)//'/',            ! Write to unit file_name: trim(field_dir)//'/', 'RESULTS_PARA_', number, trim(step_tag), '.vtk'.
     &  'RESULTS_PARA_', NUMBER, TRIM(STEP_TAG), '.vtk'
      OPEN(NEWUNIT=UNIT, FILE=TRIM(FILE_NAME), STATUS='REPLACE',         ! Open the file trim(file_name.
     &     ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_STATIC_VTK',                       ! Record an error in status: 'CANNOT OPEN '//trim(file_name).
     &                 'CANNOT OPEN '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(COORDINATE(3,N), DISPLACEMENT(3,N), STRAIN(6,N),          ! Allocate memory for coordinate(3,n), displacement(3,n), strain(6,n), stress(6,n), work(n).
     &         STRESS(6,N), WORK(N))
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        COORDINATE(:,I) = STATE(I)%COORDINATE                            ! Set coordinate(:,i) to state(i).coordinate.
      END DO                                                             ! End of the loop.
      CALL SELECT_FRAME(CACHE, REQUEST, STATE, DISPLACEMENT, STRAIN,     ! Call select frame with cache, request, state, displacement, strain, stress.
     &                  STRESS)

      CALL WRITE_VTK_GEOMETRY(UNIT, GRID, COORDINATE)                    ! Call write vtk geometry with unit, grid, coordinate.
      CALL WRITE_VTK_VECTOR(UNIT, 'VECTORS Displacements double',        ! Call write vtk vector with unit, 'VECTORS Displacements double', displacement.
     &                      DISPLACEMENT)
      WORK = 0.0_R8                                                      ! Set work to zero.
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        IF (REQUEST%FRAME .EQ. POST_FRAME_LOCAL) THEN                    ! If request.frame = post_frame_local:
          COORDINATE(:,I) = STATE(I)%ELECTRIC_DISPLACEMENT_LOCAL         ! Set coordinate(:,i) to state(i).electric_displacement_local.
        ELSE                                                             ! Otherwise:
          COORDINATE(:,I) = STATE(I)%ELECTRIC_DISPLACEMENT_GLOBAL        ! Set coordinate(:,i) to state(i).electric_displacement_global.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL WRITE_VTK_VECTOR(UNIT,                                        ! Call write vtk vector with unit, 'VECTORS ElectricDisplacements double', coordinate.
     &     'VECTORS  ElectricDisplacements double', COORDINATE)
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        COORDINATE(:,I) = [STRESS(6,I), 0.0_R8, STRESS(5,I)]             ! Set coordinate(:,i) to [stress(6,i), 0.0, stress(5,i)].
      END DO                                                             ! End of the loop.
      CALL WRITE_VTK_VECTOR(UNIT, 'VECTORS SHEAR double', COORDINATE)    ! Call write vtk vector with unit, 'VECTORS SHEAR double', coordinate.
      DO I = 1_I4, 6_I4                                                  ! Loop i from 1 to 6:
        CALL WRITE_VTK_SCALAR(UNIT, TRIM(STRESS_NAME(I)), STRESS(I,:))   ! Call write vtk scalar with unit, trim(stress_name(i)), stress(i,:).
      END DO                                                             ! End of the loop.
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        WORK(I) = VON_MISES(STRESS(:,I))                                 ! Set work(i) to von_mises(stress(:,i)).
      END DO                                                             ! End of the loop.
      CALL WRITE_VTK_SCALAR(UNIT, 'VonMises', WORK)                      ! Call write vtk scalar with unit, 'VonMises', work.
      DO I = 1_I4, 6_I4                                                  ! Loop i from 1 to 6:
        CALL WRITE_VTK_SCALAR(UNIT, TRIM(STRAIN_NAME(I)), STRAIN(I,:))   ! Call write vtk scalar with unit, trim(strain_name(i)), strain(i,:).
      END DO                                                             ! End of the loop.
      CALL WRITE_VTK_SCALAR(UNIT, 'TEMPERATURE_[C]',                     ! Call write vtk scalar with unit, 'TEMPERATURE_[C]', state(:).temperature.
     &                      STATE(:)%TEMPERATURE)
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        IF (REQUEST%FRAME .EQ. POST_FRAME_LOCAL) THEN                    ! If request.frame = post_frame_local:
          COORDINATE(:,I) = STATE(I)%HEAT_FLUX_LOCAL                     ! Set coordinate(:,i) to state(i).heat_flux_local.
        ELSE                                                             ! Otherwise:
          COORDINATE(:,I) = STATE(I)%HEAT_FLUX_GLOBAL                    ! Set coordinate(:,i) to state(i).heat_flux_global.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL WRITE_VTK_VECTOR(UNIT, 'VECTORS HeatFlux double',             ! Call write vtk vector with unit, 'VECTORS HeatFlux double', coordinate.
     &                      COORDINATE)
      WORK = 0.0_R8                                                      ! Set work to zero.
      CALL WRITE_VTK_SCALAR(UNIT, 'VOLTAGE[V]', STATE(:)%POTENTIAL)      ! Call write vtk scalar with unit, 'VOLTAGE[V]', state(:).potential.
      DO I = 1_I4, 3_I4                                                  ! Loop i from 1 to 3:
        DO K = 1_I4, N                                                   ! Loop k from 1 to n:
          IF (REQUEST%FRAME .EQ. POST_FRAME_LOCAL) THEN                  ! If request.frame = post_frame_local:
            WORK(K) = STATE(K)%ELECTRIC_FIELD_LOCAL(I)                   ! Set work(k) to state(k).electric_field_local(i).
          ELSE                                                           ! Otherwise:
            WORK(K) = STATE(K)%ELECTRIC_FIELD_GLOBAL(I)                  ! Set work(k) to state(k).electric_field_global(i).
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
        CALL WRITE_VTK_SCALAR(UNIT, FIELD_NAME(I), WORK)                 ! Call write vtk scalar with unit, field_name(i), work.
      END DO                                                             ! End of the loop.
      WORK = 0.0_R8                                                      ! Set work to zero.
      CALL WRITE_VTK_SCALAR(UNIT, 'Elem.Dimension',                      ! Call write vtk scalar with unit, 'Elem.Dimension', real(state(:).element_dimension,r8).
     &     REAL(STATE(:)%ELEMENT_DIMENSION,R8))
      CALL WRITE_VTK_SCALAR(UNIT, 'ID_LAM',                              ! Call write vtk scalar with unit, 'ID_LAM', real(state(:).lamination_id,r8).
     &     REAL(STATE(:)%LAMINATION_ID,R8))
      CALL WRITE_VTK_SCALAR(UNIT, 'ID_MAT',                              ! Call write vtk scalar with unit, 'ID_MAT', real(state(:).material_id,r8).
     &     REAL(STATE(:)%MATERIAL_ID,R8))
      CALL WRITE_VTK_SCALAR(UNIT, 'DOF_SET', WORK)                       ! Call write vtk scalar with unit, 'DOF_SET', work.
      CALL WRITE_VTK_SCALAR(UNIT, 'HYGRO', WORK)                         ! Call write vtk scalar with unit, 'HYGRO', work.
      CLOSE(UNIT)                                                        ! Close the file.
      CALL LOG_INFO('WRITTEN '//TRIM(FILE_NAME))                         ! Log: 'WRITTEN '//trim(file_name).

      END SUBROUTINE WRITE_STATIC_VTK                                    ! End of the subroutine write static vtk.

      SUBROUTINE WRITE_GMSH_GEOMETRY(UNIT, GRID, COORDINATE)             ! Subroutine write gmsh geometry takes unit, grid, coordinate.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.
      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      REAL(R8), INTENT(IN) :: COORDINATE(:,:)                            ! Input real (real64): coordinate(:,:).
      INTEGER(I4) :: ORDER(27)                                           ! Integer (int32): order(27).
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: CELL                                                ! Integer (int32): cell.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: TYPE_CODE                                           ! Integer (int32): type_code.

      CALL GMSH_CELL_ORDER(GRID%NODES_PER_CELL, ORDER, COUNT)            ! Call gmsh cell order with grid.nodes_per_cell, order, count.
      TYPE_CODE = 12_I4                                                  ! Set type_code to 12.
      IF (COUNT .EQ. 8_I4) TYPE_CODE = 5_I4                              ! If count = 8, set type_code to 5.
      WRITE(UNIT,'(A)') '$MeshFormat'                                    ! Write to unit unit: '$MeshFormat'.
      WRITE(UNIT,'(A)') '2.2 0 8'                                        ! Write to unit unit: '2.2 0 8'.
      WRITE(UNIT,'(A)') '$EndMeshFormat'                                 ! Write to unit unit: '$EndMeshFormat'.
      WRITE(UNIT,'(A)') '$Nodes'                                         ! Write to unit unit: '$Nodes'.
      WRITE(UNIT,'(I0)') GRID%NODE_COUNT                                 ! Write to unit unit: grid.node_count.
      DO NODE = 1_I4, GRID%NODE_COUNT                                    ! Loop node from 1 to grid.node_count:
        WRITE(UNIT,'(I9,3F15.9)') NODE, COORDINATE(:,NODE)               ! Write to unit unit: node, coordinate(:,node).
      END DO                                                             ! End of the loop.
      WRITE(UNIT,'(A)') '$EndNodes'                                      ! Write to unit unit: '$EndNodes'.
      WRITE(UNIT,'(A)') '$Elements'                                      ! Write to unit unit: '$Elements'.
      WRITE(UNIT,'(I0)') GRID%CELL_COUNT                                 ! Write to unit unit: grid.cell_count.
      DO CELL = 1_I4, GRID%CELL_COUNT                                    ! Loop cell from 1 to grid.cell_count:
        WRITE(UNIT,'(30I9)') CELL, TYPE_CODE, 0_I4, (                    ! Write to unit unit: cell, type_code, 0, ( (cell-1)*grid.nodes_per_cell+order(k), k=1,count).
     &    (CELL-1_I4)*GRID%NODES_PER_CELL+ORDER(K), K=1_I4,COUNT)
      END DO                                                             ! End of the loop.
      WRITE(UNIT,'(A)') '$EndElements'                                   ! Write to unit unit: '$EndElements'.

      END SUBROUTINE WRITE_GMSH_GEOMETRY                                 ! End of the subroutine write gmsh geometry.

      SUBROUTINE WRITE_GMSH_DATA(UNIT, TITLE, VALUE)                     ! Subroutine write gmsh data takes unit, title, value.

      INTEGER, INTENT(IN) :: UNIT                                        ! Input integer: unit.
      CHARACTER(LEN=*), INTENT(IN) :: TITLE                              ! Input character (length *): title.
      REAL(R8), INTENT(IN) :: VALUE(:,:)                                 ! Input real (real64): value(:,:).
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.

      WRITE(UNIT,'(A)') '$NodeData'                                      ! Write to unit unit: '$NodeData'.
      WRITE(UNIT,'(A)') '1'                                              ! Write to unit unit: '1'.
      WRITE(UNIT,'(A)') '"'//TITLE//'"'                                  ! Write to unit unit: '"'//title//'"'.
      WRITE(UNIT,'(A)') '1'                                              ! Write to unit unit: '1'.
      WRITE(UNIT,'(A)') '0.0'                                            ! Write to unit unit: '0.0'.
      WRITE(UNIT,'(A)') '3'                                              ! Write to unit unit: '3'.
      WRITE(UNIT,'(A)') '0'                                              ! Write to unit unit: '0'.
      WRITE(UNIT,'(I0)') SIZE(VALUE,1)                                   ! Write to unit unit: size(value,1).
      WRITE(UNIT,'(I0)') SIZE(VALUE,2)                                   ! Write to unit unit: size(value,2).
      DO NODE = 1_I4, SIZE(VALUE,2)                                      ! Loop node from 1 to size(value,2):
        IF (SIZE(VALUE,1) .EQ. 3_I4) THEN                                ! If size(value,1) = 3:
          WRITE(UNIT,'(I9,3ES24.9E3)') NODE, VALUE(:,NODE)               ! Write to unit unit: node, value(:,node).
        ELSE                                                             ! Otherwise:
          WRITE(UNIT,'(I9,ES24.9E3)') NODE, VALUE(1,NODE)                ! Write to unit unit: node, value(1,node).
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      WRITE(UNIT,'(A)') '$EndNodeData'                                   ! Write to unit unit: '$EndNodeData'.

      END SUBROUTINE WRITE_GMSH_DATA                                     ! End of the subroutine write gmsh data.

      SUBROUTINE WRITE_STATIC_GMSH(MODEL, CACHE, REQUEST, NUMBER, GRID,  ! Subroutine write static gmsh takes model, cache, request, number, grid, state, status.
     &                             STATE, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(POST_FIELD_REQUEST_TYPE), INTENT(IN) :: REQUEST               ! Input of type post_field_request_type: request.
      INTEGER(I4), INTENT(IN) :: NUMBER                                  ! Input integer (int32): number.
      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      TYPE(POINT_STATE_TYPE), INTENT(IN) :: STATE(:)                     ! Input of type point_state_type: state(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: COORDINATE(:,:)                           ! Allocatable real (real64): coordinate(:,:).
      REAL(R8), ALLOCATABLE :: DISPLACEMENT(:,:)                         ! Allocatable real (real64): displacement(:,:).
      REAL(R8), ALLOCATABLE :: STRAIN(:,:)                               ! Allocatable real (real64): strain(:,:).
      REAL(R8), ALLOCATABLE :: STRESS(:,:)                               ! Allocatable real (real64): stress(:,:).
      REAL(R8), ALLOCATABLE :: SCALAR(:,:)                               ! Allocatable real (real64): scalar(:,:).
      CHARACTER(LEN=64) :: FILE_NAME                                     ! Character (length 64): file_name.
      CHARACTER(LEN=12), PARAMETER :: STRESS_NAME(6) = [                 ! Constant character (length 12): stress_name(6) = [ 'Sigma XX ', 'Sigma YY ', 'Sigma ZZ ', 'Sigma XZ ', 'Sig...
     &  'Sigma XX   ', 'Sigma YY   ', 'Sigma ZZ   ', 'Sigma XZ   ',
     &  'Sigma YZ   ', 'Sigma XY   ']
      CHARACTER(LEN=12), PARAMETER :: STRAIN_NAME(6) = [                 ! Constant character (length 12): strain_name(6) = [ 'Epsilon XX ', 'Epsilon YY ', 'Epsilon ZZ ', 'Epsilon XZ...
     &  'Epsilon XX ', 'Epsilon YY ', 'Epsilon ZZ ', 'Epsilon XZ ',
     &  'Epsilon YZ ', 'Epsilon XY ']
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N = GRID%NODE_COUNT                                                ! Set n to grid.node_count.
      WRITE(FILE_NAME,'(A,A,I2.2,A,A)') TRIM(FIELD_DIR)//'/',            ! Write to unit file_name: trim(field_dir)//'/', 'RESULTS_GMSH_', number, trim(step_tag), '.msh'.
     &  'RESULTS_GMSH_', NUMBER, TRIM(STEP_TAG), '.msh'
      OPEN(NEWUNIT=UNIT, FILE=TRIM(FILE_NAME), STATUS='REPLACE',         ! Open the file trim(file_name.
     &     ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_STATIC_GMSH',                      ! Record an error in status: 'CANNOT OPEN '//trim(file_name).
     &                 'CANNOT OPEN '//TRIM(FILE_NAME))
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(COORDINATE(3,N), DISPLACEMENT(3,N), STRAIN(6,N),          ! Allocate memory for coordinate(3,n), displacement(3,n), strain(6,n), stress(6,n), scalar(1,n).
     &         STRESS(6,N), SCALAR(1,N))
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        COORDINATE(:,I) = STATE(I)%COORDINATE                            ! Set coordinate(:,i) to state(i).coordinate.
      END DO                                                             ! End of the loop.
      CALL SELECT_FRAME(CACHE, REQUEST, STATE, DISPLACEMENT, STRAIN,     ! Call select frame with cache, request, state, displacement, strain, stress.
     &                  STRESS)
      CALL WRITE_GMSH_GEOMETRY(UNIT, GRID, COORDINATE)                   ! Call write gmsh geometry with unit, grid, coordinate.
      CALL WRITE_GMSH_DATA(UNIT, 'Displacements', DISPLACEMENT)          ! Call write gmsh data with unit, 'Displacements', displacement.
      DO I = 1_I4, 6_I4                                                  ! Loop i from 1 to 6:
        SCALAR(1,:) = STRESS(I,:)                                        ! Set scalar(1,:) to stress(i,:).
        CALL WRITE_GMSH_DATA(UNIT, TRIM(STRESS_NAME(I)), SCALAR)         ! Call write gmsh data with unit, trim(stress_name(i)), scalar.
      END DO                                                             ! End of the loop.
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        SCALAR(1,I) = VON_MISES(STRESS(:,I))                             ! Set scalar(1,i) to von_mises(stress(:,i)).
      END DO                                                             ! End of the loop.
      CALL WRITE_GMSH_DATA(UNIT, 'Von Mises', SCALAR)                    ! Call write gmsh data with unit, 'Von Mises', scalar.
      DO I = 1_I4, 6_I4                                                  ! Loop i from 1 to 6:
        SCALAR(1,:) = STRAIN(I,:)                                        ! Set scalar(1,:) to strain(i,:).
        CALL WRITE_GMSH_DATA(UNIT, TRIM(STRAIN_NAME(I)), SCALAR)         ! Call write gmsh data with unit, trim(strain_name(i)), scalar.
      END DO                                                             ! End of the loop.
      SCALAR(1,:) = REAL(STATE(:)%MATERIAL_ID,R8)                        ! Set scalar(1,:) to real(state(:).material_id,r8).
      CALL WRITE_GMSH_DATA(UNIT, 'Material ID', SCALAR)                  ! Call write gmsh data with unit, 'Material ID', scalar.
      SCALAR(1,:) = REAL(STATE(:)%LAMINATION_ID,R8)                      ! Set scalar(1,:) to real(state(:).lamination_id,r8).
      CALL WRITE_GMSH_DATA(UNIT, 'Lamination ID', SCALAR)                ! Call write gmsh data with unit, 'Lamination ID', scalar.
      SCALAR(1,:) = REAL(STATE(:)%ELEMENT_DIMENSION,R8)                  ! Set scalar(1,:) to real(state(:).element_dimension,r8).
      CALL WRITE_GMSH_DATA(UNIT, 'Elem. Dimension', SCALAR)              ! Call write gmsh data with unit, 'Elem. Dimension', scalar.
      CLOSE(UNIT)                                                        ! Close the file.
      CALL LOG_INFO('WRITTEN '//TRIM(FILE_NAME))                         ! Log: 'WRITTEN '//trim(file_name).

      END SUBROUTINE WRITE_STATIC_GMSH                                   ! End of the subroutine write static gmsh.

!=======================================================================
!  MODAL ANALYSIS OUTPUT
!=======================================================================
      SUBROUTINE WRITE_MODAL_OUTPUT(MODEL, CACHE, RESULTS, STATUS)       ! Subroutine write modal output takes model, cache, results, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(IN) :: RESULTS                 ! Input of type analysis_results_type: results.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL                                         ! Of type status_type: local.
      TYPE(POST_GRID_TYPE) :: GRID                                       ! Of type post_grid_type: grid.
      REAL(R8), ALLOCATABLE :: DISPLACEMENT(:,:,:)                       ! Allocatable real (real64): displacement(:,:,:).
      REAL(R8), ALLOCATABLE :: COORDINATE(:,:)                           ! Allocatable real (real64): coordinate(:,:).
      INTEGER(I4) :: SPLIT(9)                                            ! Integer (int32): split(9).
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (RESULTS%SOLUTION_ID .EQ. 105_I4) THEN                          ! If results.solution_id = 105:
        OPEN(NEWUNIT=UNIT, FILE=DIR_DYNAMIC//'/BUCKLING_FACTORS.dat',    ! Open the file dir_dynamic//'/BUCKLING_FACTORS.dat'.
     &       STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
      ELSE                                                               ! Otherwise:
        OPEN(NEWUNIT=UNIT, FILE=DIR_DYNAMIC//'/FREQUENCIES.dat',         ! Open the file dir_dynamic//'/FREQUENCIES.dat'.
     &       STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
      END IF                                                             ! End of the IF block.
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_MODAL_OUTPUT',                     ! Record an error in status: 'CANNOT OPEN THE DYNAMIC EIGENVALUE FILE'.
     &                 'CANNOT OPEN THE DYNAMIC EIGENVALUE FILE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO I = 1_I4, RESULTS%MODE_COUNT                                    ! Loop i from 1 to results.mode_count:
        IF (RESULTS%SOLUTION_ID .EQ. 105_I4) THEN                        ! If results.solution_id = 105:
          WRITE(UNIT,'(A11,I3,A3,ES24.9E3)') 'LoadFactor', I, ':  ',     ! Write to unit unit: 'LoadFactor', i, ': ', results.frequency(i).
     &                                       RESULTS%FREQUENCY(I)
        ELSE                                                             ! Otherwise:
          WRITE(UNIT,'(A11,I3,A3,ES24.9E3)') 'Frequency', I, ':  ',      ! Write to unit unit: 'Frequency', i, ': ', results.frequency(i).
     &                                       RESULTS%FREQUENCY(I)
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

!     MODE SHAPES ARE ALWAYS SAMPLED ON ONE QUADRATIC CELL PER ELEMENT.
      SPLIT = 1_I4                                                       ! Set split to 1.
      CALL BUILD_POST_GRID(MODEL, 27_I4, SPLIT, GRID, LOCAL)             ! Call build post grid with model, 27, split, grid, local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL EVALUATE_GRID_MODES(MODEL, CACHE, GRID, RESULTS%MODE,         ! Call evaluate grid modes with model, cache, grid, results.mode, coordinate, displacement, local.
     &     COORDINATE, DISPLACEMENT, LOCAL)
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL WRITE_MODAL_VTK(GRID, COORDINATE, DISPLACEMENT,               ! Call write modal vtk with grid, coordinate, displacement, results.frequency, local.
     &                     RESULTS%FREQUENCY, LOCAL)
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL WRITE_MODAL_GMSH(GRID, COORDINATE, DISPLACEMENT,              ! Call write modal gmsh with grid, coordinate, displacement, results.frequency, local.
     &                      RESULTS%FREQUENCY, LOCAL)
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL CLEAR_POST_GRID(GRID)                                         ! Call clear post grid with grid.

      CALL WRITE_SOLVER_INFO(RESULTS, LOCAL)                             ! Call write solver info with results, local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      CALL WRITE_MATRIX_DUMPS(MODEL, RESULTS, LOCAL)                     ! Call write matrix dumps with model, results, local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.

      END SUBROUTINE WRITE_MODAL_OUTPUT                                  ! End of the subroutine write modal output.

!  WORK/ARPACK_SOLVER_INFO.dat: EIGENVALUES, RESIDUALS, ITERATIONS.
      SUBROUTINE WRITE_SOLVER_INFO(RESULTS, STATUS)                      ! Subroutine write solver info takes results, status.

      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(IN) :: RESULTS                 ! Input of type analysis_results_type: results.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=DIR_WORK//'/ARPACK_SOLVER_INFO.dat',       ! Open the file dir_work//'/ARPACK_SOLVER_INFO.dat'.
     &     STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_SOLVER_INFO',                      ! Record an error in status: 'CANNOT OPEN WORK/ARPACK_SOLVER_INFO.dat'.
     &                 'CANNOT OPEN WORK/ARPACK_SOLVER_INFO.dat')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      WRITE(UNIT,'(A)') ' '                                              ! Write to unit unit: ' '.
      WRITE(UNIT,'(A)') ' Ritz values (Real,Imag) and relative '//       ! Write to unit unit: ' Ritz values (Real,Imag) and relative '// 'residuals'.
     &                  'residuals'
      WRITE(UNIT,'(A)') ' ----------------------------------------'//    ! Write to unit unit: ' ----------------------------------------'// '------'.
     &                  '------'
      WRITE(UNIT,'(A)') '               Col   1       Col   2       '//  ! Write to unit unit: ' Col 1 Col 2 '// 'Col 3'.
     &                  'Col   3'
      DO I = 1_I4, RESULTS%MODE_COUNT                                    ! Loop i from 1 to results.mode_count:
        WRITE(UNIT,'(A,I3,A,3(1PD13.5,2X))') '  Row ', I, ':  ',         ! Write to unit unit: ' Row ', i, ': ', results.eigenvalue(i), 0.0, results.residual(i).
     &    RESULTS%EIGENVALUE(I), 0.0_R8, RESULTS%RESIDUAL(I)
      END DO                                                             ! End of the loop.
      WRITE(UNIT,'(A)') ' '                                              ! Write to unit unit: ' '.
      WRITE(UNIT,'(A,A)') '  Backend: ', TRIM(RESULTS%SOLVER_BACKEND)    ! Write to unit unit: ' Backend: ', trim(results.solver_backend).
      WRITE(UNIT,'(A,I0)') '  Size of the matrix is ',                   ! Write to unit unit: ' Size of the matrix is ', results.system.order.
     &                     RESULTS%SYSTEM%ORDER
      WRITE(UNIT,'(A,I0)') '  Number of converged modes ',               ! Write to unit unit: ' Number of converged modes ', results.mode_count.
     &                     RESULTS%MODE_COUNT
      WRITE(UNIT,'(A,I0)') '  Dimension of the Krylov subspace ',        ! Write to unit unit: ' Dimension of the Krylov subspace ', results.solver_subspace.
     &                     RESULTS%SOLVER_SUBSPACE
      WRITE(UNIT,'(A,I0)') '  Implicit Arnoldi update iterations ',      ! Write to unit unit: ' Implicit Arnoldi update iterations ', results.solver_iterations.
     &                     RESULTS%SOLVER_ITERATIONS
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE WRITE_SOLVER_INFO                                   ! End of the subroutine write solver info.

!  MODE DISPLACEMENTS AT THE GRID NODES: DISPLACEMENT(3,NODE,MODE).
      SUBROUTINE EVALUATE_GRID_MODES(MODEL, CACHE, GRID, MODE,           ! Subroutine evaluate grid modes takes model, cache, grid, mode, coordinate, displacement, status.
     &                               COORDINATE, DISPLACEMENT, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      REAL(R8), INTENT(IN) :: MODE(:,:)                                  ! Input real (real64): mode(:,:).
      REAL(R8), ALLOCATABLE, INTENT(INOUT) :: COORDINATE(:,:)            ! Allocatable in/out real (real64): coordinate(:,:).
      REAL(R8), ALLOCATABLE, INTENT(INOUT) :: DISPLACEMENT(:,:,:)        ! Allocatable in/out real (real64): displacement(:,:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE), ALLOCATABLE :: CELL_STATUS(:)                   ! Allocatable of type status_type: cell_status(:).
      INTEGER(I4) :: CELL                                                ! Integer (int32): cell.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (ALLOCATED(COORDINATE)) DEALLOCATE(COORDINATE)                  ! If allocated(coordinate), free the memory of coordinate.
      IF (ALLOCATED(DISPLACEMENT)) DEALLOCATE(DISPLACEMENT)              ! If allocated(displacement), free the memory of displacement.
      ALLOCATE(COORDINATE(3,GRID%NODE_COUNT))                            ! Allocate memory for coordinate(3,grid.node_count).
      ALLOCATE(DISPLACEMENT(3,GRID%NODE_COUNT,SIZE(MODE,2)))             ! Allocate memory for displacement(3,grid.node_count,size(mode,2)).
      ALLOCATE(CELL_STATUS(GRID%CELL_COUNT))                             ! Allocate memory for cell_status(grid.cell_count).
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(CELL) SCHEDULE(DYNAMIC,16)
      DO CELL = 1_I4, GRID%CELL_COUNT                                    ! Loop cell from 1 to grid.cell_count:
        CALL EVALUATE_CELL_MODES(MODEL, CACHE, GRID, MODE, CELL,         ! Call evaluate cell modes with model, cache, grid, mode, cell, coordinate, displacement, cell_status(cell).
     &       COORDINATE, DISPLACEMENT, CELL_STATUS(CELL))
      END DO                                                             ! End of the loop.
!$OMP END PARALLEL DO
      DO CELL = 1_I4, GRID%CELL_COUNT                                    ! Loop cell from 1 to grid.cell_count:
        CALL MERGE_STATUS(CELL_STATUS(CELL), STATUS)                     ! Merge status cell_status(cell) into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_GRID_MODES                                 ! End of the subroutine evaluate grid modes.

      SUBROUTINE EVALUATE_CELL_MODES(MODEL, CACHE, GRID, MODE, CELL,     ! Subroutine evaluate cell modes takes model, cache, grid, mode, cell, coordinate, displacement, status.
     &                               COORDINATE, DISPLACEMENT, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(MODEL_CACHE_TYPE), INTENT(IN) :: CACHE                        ! Input of type model_cache_type: cache.
      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      REAL(R8), INTENT(IN) :: MODE(:,:)                                  ! Input real (real64): mode(:,:).
      INTEGER(I4), INTENT(IN) :: CELL                                    ! Input integer (int32): cell.
      REAL(R8), INTENT(INOUT) :: COORDINATE(:,:)                         ! In/out real (real64): coordinate(:,:).
      REAL(R8), INTENT(INOUT) :: DISPLACEMENT(:,:,:)                     ! In/out real (real64): displacement(:,:,:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PLACE_TYPE) :: PLACE                                          ! Of type place_type: place.
      REAL(R8), ALLOCATABLE :: VALUE(:,:)                                ! Allocatable real (real64): value(:,:).
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      ALLOCATE(VALUE(3,SIZE(MODE,2)))                                    ! Allocate memory for value(3,size(mode,2)).
      CALL PLACE_SETUP(MODEL, CACHE, GRID%CELL_ELEMENT(CELL),            ! Call place setup with model, cache, grid.cell_element(cell), grid.cell_sub_element(cell), place, status.
     &                 GRID%CELL_SUB_ELEMENT(CELL), PLACE, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      DO K = 1_I4, GRID%NODES_PER_CELL                                   ! Loop k from 1 to grid.nodes_per_cell:
        NODE = (CELL-1_I4)*GRID%NODES_PER_CELL + K                       ! Set node to (cell-1)*grid.nodes_per_cell + k.
        CALL PLACE_EVALUATE(PLACE, MODEL, CACHE,                         ! Call place evaluate with place, model, cache, grid.natural_structural(:,node), grid.natural_expansion(:,nod...
     &       GRID%NATURAL_STRUCTURAL(:,NODE),
     &       GRID%NATURAL_EXPANSION(:,NODE), .FALSE., STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        COORDINATE(:,NODE) = PLACE%POINT_GLOBAL                          ! Set coordinate(:,node) to place.point_global.
        CALL DISPLACEMENT_FROM_PLACE(MODEL, CACHE, PLACE, MODE,          ! Call displacement from place with model, cache, place, mode, value, status.
     &       VALUE, STATUS)
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        DISPLACEMENT(:,NODE,:) = VALUE                                   ! Set displacement(:,node,:) to value.
      END DO                                                             ! End of the loop.

      END SUBROUTINE EVALUATE_CELL_MODES                                 ! End of the subroutine evaluate cell modes.
      SUBROUTINE WRITE_MODAL_VTK(GRID, COORDINATE, DISPLACEMENT,         ! Subroutine write modal vtk takes grid, coordinate, displacement, frequency, status.
     &                           FREQUENCY, STATUS)

      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      REAL(R8), INTENT(IN) :: COORDINATE(:,:)                            ! Input real (real64): coordinate(:,:).
      REAL(R8), INTENT(IN) :: DISPLACEMENT(:,:,:)                        ! Input real (real64): displacement(:,:,:).
      REAL(R8), INTENT(IN) :: FREQUENCY(:)                               ! Input real (real64): frequency(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=96) :: TITLE                                         ! Character (length 96): title.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=DIR_DYNAMIC//'/RESULTS_DYN_PARA.vtk',      ! Open the file dir_dynamic//'/RESULTS_DYN_PARA.vtk'.
     &     STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_MODAL_VTK',                        ! Record an error in status: 'CANNOT OPEN DYNAMIC/RESULTS_DYN_PARA.vtk'.
     &                 'CANNOT OPEN DYNAMIC/RESULTS_DYN_PARA.vtk')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL WRITE_VTK_GEOMETRY(UNIT, GRID, COORDINATE)                    ! Call write vtk geometry with unit, grid, coordinate.
      DO M = 1_I4, SIZE(FREQUENCY)                                       ! Loop m from 1 to size(frequency):
        WRITE(TITLE,'(A,I3.3,A,E10.4,A)') 'VECTORS Mode:', M,            ! Write to unit title: 'VECTORS Mode:', m, '-Freq:', frequency(m), 'Hz double'.
     &    '-Freq:', FREQUENCY(M), 'Hz double'
        CALL WRITE_VTK_VECTOR(UNIT, TRIM(TITLE), DISPLACEMENT(:,:,M))    ! Call write vtk vector with unit, trim(title), displacement(:,:,m).
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.
      CALL LOG_INFO('WRITTEN DYNAMIC/RESULTS_DYN_PARA.vtk')              ! Log: 'WRITTEN DYNAMIC/RESULTS_DYN_PARA.vtk'.

      END SUBROUTINE WRITE_MODAL_VTK                                     ! End of the subroutine write modal vtk.

      SUBROUTINE WRITE_MODAL_GMSH(GRID, COORDINATE, DISPLACEMENT,        ! Subroutine write modal gmsh takes grid, coordinate, displacement, frequency, status.
     &                            FREQUENCY, STATUS)

      TYPE(POST_GRID_TYPE), INTENT(IN) :: GRID                           ! Input of type post_grid_type: grid.
      REAL(R8), INTENT(IN) :: COORDINATE(:,:)                            ! Input real (real64): coordinate(:,:).
      REAL(R8), INTENT(IN) :: DISPLACEMENT(:,:,:)                        ! Input real (real64): displacement(:,:,:).
      REAL(R8), INTENT(IN) :: FREQUENCY(:)                               ! Input real (real64): frequency(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=32) :: TITLE                                         ! Character (length 32): title.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=DIR_DYNAMIC//'/RESULTS_DYN_GMSH.msh',      ! Open the file dir_dynamic//'/RESULTS_DYN_GMSH.msh'.
     &     STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_MODAL_GMSH',                       ! Record an error in status: 'CANNOT OPEN DYNAMIC/RESULTS_DYN_GMSH.msh'.
     &                 'CANNOT OPEN DYNAMIC/RESULTS_DYN_GMSH.msh')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      CALL WRITE_GMSH_GEOMETRY(UNIT, GRID, COORDINATE)                   ! Call write gmsh geometry with unit, grid, coordinate.
      DO M = 1_I4, SIZE(FREQUENCY)                                       ! Loop m from 1 to size(frequency):
        IF (FREQUENCY(M) .LT. 99999.0_R8) THEN                           ! If frequency(m) < 99999.0:
          WRITE(TITLE,'(A,I3,A,F8.2)') '[', M, ']_F', FREQUENCY(M)       ! Write to unit title: '[', m, ']_F', frequency(m).
        ELSE                                                             ! Otherwise:
          WRITE(TITLE,'(A,I3,A,ES10.3)') '[', M, ']_F', FREQUENCY(M)     ! Write to unit title: '[', m, ']_F', frequency(m).
        END IF                                                           ! End of the IF block.
        CALL WRITE_GMSH_DATA(UNIT, TRIM(TITLE), DISPLACEMENT(:,:,M))     ! Call write gmsh data with unit, trim(title), displacement(:,:,m).
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.
      CALL LOG_INFO('WRITTEN DYNAMIC/RESULTS_DYN_GMSH.msh')              ! Log: 'WRITTEN DYNAMIC/RESULTS_DYN_GMSH.msh'.

      END SUBROUTINE WRITE_MODAL_GMSH                                    ! End of the subroutine write modal gmsh.

!=======================================================================
!  MATRIX AND VECTOR DUMPS (WORK DIRECTORY)
!=======================================================================
      SUBROUTINE WRITE_MATRIX_DUMPS(MODEL, RESULTS, STATUS)              ! Subroutine write matrix dumps takes model, results, status.

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      TYPE(ANALYSIS_RESULTS_TYPE), INTENT(IN) :: RESULTS                 ! Input of type analysis_results_type: results.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (MODEL%POST%WRITE_STIFFNESS)                                    ! If model.post.write_stiffness, call write csr with dir_work//'/K_MAT.dat', results.system, results.system.s...
     &  CALL WRITE_CSR(DIR_WORK//'/K_MAT.dat', RESULTS%SYSTEM,
     &                 RESULTS%SYSTEM%STIFFNESS, STATUS)
      IF (MODEL%POST%WRITE_MASS .AND. STATUS_IS_OK(STATUS)) THEN         ! If model.post.write_mass and status is ok:
        IF (ALLOCATED(RESULTS%SYSTEM%MASS)) THEN                         ! If allocated(results.system.mass):
          CALL WRITE_CSR(DIR_WORK//'/M_MAT.dat', RESULTS%SYSTEM,         ! Call write csr with dir_work//'/M_MAT.dat', results.system, results.system.mass, status.
     &                   RESULTS%SYSTEM%MASS, STATUS)
        ELSE                                                             ! Otherwise:
          CALL SET_WARNING(STATUS, 'WRITE_MATRIX_DUMPS',                 ! Record a warning in status: 'MMAT REQUESTED BUT M WAS NOT ASSEMBLED'.
     &                     'MMAT REQUESTED BUT M WAS NOT ASSEMBLED')
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      IF (MODEL%POST%WRITE_FORCE .AND. ALLOCATED(RESULTS%FORCE)          ! If model.post.write_force and allocated(results.force) and status is ok, call write vector with dir_work//'...
     &    .AND. STATUS_IS_OK(STATUS))
     &  CALL WRITE_VECTOR(DIR_WORK//'/FORCES.dat', RESULTS%FORCE,
     &                    STATUS)
      IF (MODEL%POST%WRITE_UNKNOWN .AND. ALLOCATED(RESULTS%SOLUTION)     ! If model.post.write_unknown and allocated(results.solution) and status is ok, call write vector with dir_wo...
     &    .AND. STATUS_IS_OK(STATUS))
     &  CALL WRITE_VECTOR(DIR_WORK//'/UNKNOWN.dat', RESULTS%SOLUTION,
     &                    STATUS)
      IF (MODEL%POST%WRITE_ENERGY .AND. STATUS_IS_OK(STATUS))            ! If model.post.write_energy and status is ok, record a warning in status: 'ENRG IS NOT AVAILABLE IN V3 YET: ...
     &  CALL SET_WARNING(STATUS, 'WRITE_MATRIX_DUMPS',
     &                   'ENRG IS NOT AVAILABLE IN V3 YET: IGNORED')

      END SUBROUTINE WRITE_MATRIX_DUMPS                                  ! End of the subroutine write matrix dumps.

      SUBROUTINE WRITE_CSR(FILE_NAME, SYSTEM, VALUE, STATUS)             ! Subroutine write csr takes file name, system, value, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(SPARSE_SYSTEM_TYPE), INTENT(IN) :: SYSTEM                     ! Input of type sparse_system_type: system.
      REAL(R8), INTENT(IN) :: VALUE(:)                                   ! Input real (real64): value(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='REPLACE',               ! Open the file file_name.
     &     ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_CSR',                              ! Record an error in status: 'CANNOT OPEN '//file_name.
     &                 'CANNOT OPEN '//FILE_NAME)
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO ROW = 1_I8, SYSTEM%ORDER                                        ! Loop row from 1 to system.order:
        DO POSITION = SYSTEM%ROW_POINTER(ROW),                           ! Loop position from system.row_pointer(row) to system.row_pointer(row+1)-1:
     &                SYSTEM%ROW_POINTER(ROW+1_I8)-1_I8
          WRITE(UNIT,'(2I12,ES25.15E3)') ROW,                            ! Write to unit unit: row, system.column_index(position), value(position).
     &      SYSTEM%COLUMN_INDEX(POSITION), VALUE(POSITION)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE WRITE_CSR                                           ! End of the subroutine write csr.

      SUBROUTINE WRITE_VECTOR(FILE_NAME, VALUE, STATUS)                  ! Subroutine write vector takes file name, value, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      REAL(R8), INTENT(IN) :: VALUE(:)                                   ! Input real (real64): value(:).
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER(I8) :: I                                                   ! Integer (int64): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='REPLACE',               ! Open the file file_name.
     &     ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_VECTOR',                           ! Record an error in status: 'CANNOT OPEN '//file_name.
     &                 'CANNOT OPEN '//FILE_NAME)
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO I = 1_I8, SIZE(VALUE,KIND=I8)                                   ! Loop i from 1 to size(value,kind=i8):
        WRITE(UNIT,'(I12,ES25.15E3)') I, VALUE(I)                        ! Write to unit unit: i, value(i).
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE WRITE_VECTOR                                        ! End of the subroutine write vector.

!=======================================================================
!  REPORT FILES
!=======================================================================
      SUBROUTINE ADD_WARNING(WARNINGS, TEXT)                             ! Subroutine add warning takes warnings, text.

      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.
      CHARACTER(LEN=*), INTENT(IN) :: TEXT                               ! Input character (length *): text.

      IF (WARNINGS%COUNT .GE. SIZE(WARNINGS%TEXT)) RETURN                ! If warnings.count >= size(warnings.text), return to the caller.
      WARNINGS%COUNT = WARNINGS%COUNT + 1_I4                             ! Add 1 to warnings.count.
      WARNINGS%TEXT(WARNINGS%COUNT) = TEXT                               ! Set warnings.text(warnings.count) to text.

      END SUBROUTINE ADD_WARNING                                         ! End of the subroutine add warning.

!  REPORT/WARNING_file.dat IN THE BASELINE LAYOUT.
      SUBROUTINE WRITE_WARNING_FILE(WARNINGS, STATUS)                    ! Subroutine write warning file takes warnings, status.

      TYPE(WARNING_LIST_TYPE), INTENT(IN) :: WARNINGS                    ! Input of type warning_list_type: warnings.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      IF (WARNINGS%COUNT .LT. 1_I4) RETURN                               ! If warnings.count < 1, return to the caller.
      OPEN(NEWUNIT=UNIT, FILE=DIR_REPORT//'/WARNING_file.dat',           ! Open the file dir_report//'/WARNING_file.dat'.
     &     STATUS='REPLACE', ACTION='WRITE', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN                                               ! If ios /= 0:
        CALL SET_ERROR(STATUS, 'WRITE_WARNING_FILE',                     ! Record an error in status: 'CANNOT OPEN REPORT/WARNING_file.dat'.
     &                 'CANNOT OPEN REPORT/WARNING_file.dat')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      WRITE(UNIT,'(A)') ' '                                              ! Write to unit unit: ' '.
      WRITE(UNIT,'(A)') '-------- BEGIN OF WARNING FILE --------'        ! Write to unit unit: '-------- BEGIN OF WARNING FILE --------'.
      WRITE(UNIT,'(A)') ' '                                              ! Write to unit unit: ' '.
      DO I = 1_I4, WARNINGS%COUNT                                        ! Loop i from 1 to warnings.count:
        WRITE(UNIT,'(A)') '    '//TRIM(WARNINGS%TEXT(I))                 ! Write to unit unit: ' '//trim(warnings.text(i)).
      END DO                                                             ! End of the loop.
      WRITE(UNIT,'(A)') ' '                                              ! Write to unit unit: ' '.
      WRITE(UNIT,'(A)') '--------- END OF WARNING FILE ---------'        ! Write to unit unit: '--------- END OF WARNING FILE ---------'.
      CLOSE(UNIT)                                                        ! Close the file.
      DO I = 1_I4, WARNINGS%COUNT                                        ! Loop i from 1 to warnings.count:
        CALL LOG_WARNING(TRIM(WARNINGS%TEXT(I)))                         ! Call log warning with trim(warnings.text(i)).
      END DO                                                             ! End of the loop.

      END SUBROUTINE WRITE_WARNING_FILE                                  ! End of the subroutine write warning file.

      CHARACTER(LEN=16) FUNCTION INTEGER_TEXT(VALUE)                     ! Function integer text takes value.

      INTEGER(I4), INTENT(IN) :: VALUE                                   ! Input integer (int32): value.

      WRITE(INTEGER_TEXT,'(I0)') VALUE                                   ! Write to unit integer_text: value.

      END FUNCTION INTEGER_TEXT                                          ! End of the function integer text.

      END MODULE MUL2_POST_OUTPUT                                        ! End of the module mul2 post output.
