!=======================================================================
!  TOP-LEVEL FLOW OF ONE RUN:
!
!      READ_MODEL -> PREPROCESS -> RUN_ANALYSIS -> WRITE_RESULTS
!=======================================================================
      MODULE MUL2_DRIVER                                                 ! Module mul2 driver begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok, merge status.
     &                       STATUS_IS_OK, MERGE_STATUS
      USE MUL2_LOG, ONLY: LOG_INFO, LOG_ERROR                            ! Use from module mul2 log: log info, log error.
      USE MUL2_TIMER, ONLY: TIMER_TYPE, TIMER_START, TIMER_STOP,         ! Use from module mul2 timer: timer type, timer start, timer stop, timer wall seconds.
     &                      TIMER_WALL_SECONDS
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_MODEL_CACHE, ONLY: MODEL_CACHE_TYPE, BUILD_MODEL_CACHE    ! Use from module mul2 model cache: model cache type, build model cache.
      USE MUL2_READ_MODEL, ONLY: READ_MODEL                              ! Use from module mul2 read model: read model.
      USE MUL2_ANALYSIS_INPUT, ONLY: SOLUTION_STATIC, SOLUTION_MODAL,    ! Use from module mul2 analysis input: solution static, solution modal, solution time, solution buckling, sol...
     &     SOLUTION_TIME, SOLUTION_BUCKLING, SOLUTION_FREQUENCY,
     &     SOLUTION_NONLINEAR
      USE MUL2_ANALYSIS_RESULTS, ONLY: ANALYSIS_RESULTS_TYPE             ! Use from module mul2 analysis results: analysis results type.
      USE MUL2_ANALYSIS_101, ONLY: RUN_STATIC_ANALYSIS                   ! Use from module mul2 analysis 101: run static analysis.
      USE MUL2_ANALYSIS_103, ONLY: RUN_MODAL_ANALYSIS                    ! Use from module mul2 analysis 103: run modal analysis.
      USE MUL2_ANALYSIS_104, ONLY: RUN_TIME_ANALYSIS                     ! Use from module mul2 analysis 104: run time analysis.
      USE MUL2_ANALYSIS_105, ONLY: RUN_BUCKLING_ANALYSIS                 ! Use from module mul2 analysis 105: run buckling analysis.
      USE MUL2_ANALYSIS_106, ONLY: RUN_FREQUENCY_ANALYSIS                ! Use from module mul2 analysis 106: run frequency analysis.
      USE MUL2_ANALYSIS_108, ONLY: RUN_NONLINEAR_ANALYSIS                ! Use from module mul2 analysis 108: run nonlinear analysis.
      USE MUL2_POST_OUTPUT, ONLY: WARNING_LIST_TYPE,                     ! Use from module mul2 post output: warning list type, prepare output directories, write static output, write...
     &     PREPARE_OUTPUT_DIRECTORIES, WRITE_STATIC_OUTPUT,
     &     WRITE_MODAL_OUTPUT, WRITE_WARNING_FILE

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: RUN_MUL2                                                 ! Export: run mul2.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE RUN_MUL2(INPUT_PATH, STATUS)                            ! Subroutine run mul2 takes input path, status.

      CHARACTER(LEN=*), INTENT(IN) :: INPUT_PATH                         ! Input character (length *): input_path.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(MODEL_TYPE) :: MODEL                                          ! Of type model_type: model.
      TYPE(MODEL_CACHE_TYPE) :: CACHE                                    ! Of type model_cache_type: cache.
      TYPE(ANALYSIS_RESULTS_TYPE) :: RESULTS                             ! Of type analysis_results_type: results.
      TYPE(WARNING_LIST_TYPE) :: WARNINGS                                ! Of type warning_list_type: warnings.
      TYPE(STATUS_TYPE) :: LOCAL                                         ! Of type status_type: local.
      TYPE(TIMER_TYPE) :: TIMER                                          ! Of type timer_type: timer.
      CHARACTER(LEN=160) :: MESSAGE                                      ! Character (length 160): message.
      REAL(R8) :: INPUT_SECONDS                                          ! Real (real64): input_seconds.
      REAL(R8) :: CACHE_SECONDS                                          ! Real (real64): cache_seconds.
      REAL(R8) :: ANALYSIS_SECONDS                                       ! Real (real64): analysis_seconds.
      REAL(R8) :: OUTPUT_SECONDS                                         ! Real (real64): output_seconds.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL PREPARE_OUTPUT_DIRECTORIES(LOCAL)                             ! Call prepare output directories with local.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL TIMER_START(TIMER, 'INPUT')                                   ! Call timer start with timer, 'INPUT'.
      CALL READ_MODEL(INPUT_PATH, MODEL, LOCAL)                          ! Call read model with input_path, model, local.
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      INPUT_SECONDS = TIMER_WALL_SECONDS(TIMER)                          ! Set input_seconds to timer_wall_seconds(timer).
      CALL REMEMBER_WARNING(LOCAL, WARNINGS)                             ! Call remember warning with local, warnings.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      WRITE(MESSAGE,'(A,I0,A,I0,A,I0,A)') 'MODEL: ',                     ! Format into the text message: 'MODEL: ', size(model.nodes.item), ' NODES, ', size(model.elements.item), ' E...
     &  SIZE(MODEL%NODES%ITEM), ' NODES, ',
     &  SIZE(MODEL%ELEMENTS%ITEM), ' ELEMENTS, SOLUTION ',
     &  MODEL%ANALYSIS%SOLUTION, ' '
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      IF (MODEL%ANALYSIS%SOLUTION .NE. SOLUTION_STATIC .AND.             ! If model.analysis.solution /= solution_static and model.analysis.solution /= solution_modal and model.analy...
     &    MODEL%ANALYSIS%SOLUTION .NE. SOLUTION_MODAL .AND.
     &    MODEL%ANALYSIS%SOLUTION .NE. SOLUTION_TIME .AND.
     &    MODEL%ANALYSIS%SOLUTION .NE. SOLUTION_BUCKLING .AND.
     &    MODEL%ANALYSIS%SOLUTION .NE. SOLUTION_FREQUENCY .AND.
     &    MODEL%ANALYSIS%SOLUTION .NE. SOLUTION_NONLINEAR) THEN
        WRITE(MESSAGE,'(A,I0,A)') 'SOLUTION ',                           ! Format into the text message: 'SOLUTION ', model.analysis.solution, ' IS NOT SUPPORTED (101, 103-106, 108)'.
     &    MODEL%ANALYSIS%SOLUTION,
     &    ' IS NOT SUPPORTED (101, 103-106, 108)'
        CALL SET_ERROR(STATUS, 'RUN_MUL2', TRIM(MESSAGE))                ! Record an error in status: trim(message).
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      CALL TIMER_START(TIMER, 'PREPROCESSING')                           ! Call timer start with timer, 'PREPROCESSING'.
      CALL BUILD_MODEL_CACHE(MODEL, CACHE, LOCAL)                        ! Call build model cache with model, cache, local.
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      CACHE_SECONDS = TIMER_WALL_SECONDS(TIMER)                          ! Set cache_seconds to timer_wall_seconds(timer).
      CALL REMEMBER_WARNING(LOCAL, WARNINGS)                             ! Call remember warning with local, warnings.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      WRITE(MESSAGE,'(A,I0,A,I0,A)') 'PREPROCESSING: ',                  ! Format into the text message: 'PREPROCESSING: ', cache.dof_layout.total_dof, ' DOF, ', cache.gauss_layout.c...
     &  CACHE%DOF_LAYOUT%TOTAL_DOF, ' DOF, ',
     &  CACHE%GAUSS_LAYOUT%COUNT, ' GAUSS POINTS'
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      CALL TIMER_START(TIMER, 'ANALYSIS')                                ! Call timer start with timer, 'ANALYSIS'.
      SELECT CASE(MODEL%ANALYSIS%SOLUTION)                               ! Choose according to the value of model.analysis.solution:
      CASE(SOLUTION_STATIC)                                              ! Case solution_static:
        CALL RUN_STATIC_ANALYSIS(MODEL, CACHE, RESULTS, LOCAL)           ! Call run static analysis with model, cache, results, local.
      CASE(SOLUTION_MODAL)                                               ! Case solution_modal:
        CALL RUN_MODAL_ANALYSIS(MODEL, CACHE, RESULTS, LOCAL)            ! Call run modal analysis with model, cache, results, local.
      CASE(SOLUTION_TIME)                                                ! Case solution_time:
        CALL RUN_TIME_ANALYSIS(MODEL, CACHE, RESULTS, WARNINGS, LOCAL)   ! Call run time analysis with model, cache, results, warnings, local.
      CASE(SOLUTION_BUCKLING)                                            ! Case solution_buckling:
        CALL RUN_BUCKLING_ANALYSIS(MODEL, CACHE, RESULTS, LOCAL)         ! Call run buckling analysis with model, cache, results, local.
      CASE(SOLUTION_FREQUENCY)                                           ! Case solution_frequency:
        CALL RUN_FREQUENCY_ANALYSIS(MODEL, CACHE, RESULTS, WARNINGS,     ! Call run frequency analysis with model, cache, results, warnings, local.
     &                              LOCAL)
      CASE(SOLUTION_NONLINEAR)                                           ! Case solution_nonlinear:
        CALL RUN_NONLINEAR_ANALYSIS(MODEL, CACHE, RESULTS, WARNINGS,     ! Call run nonlinear analysis with model, cache, results, warnings, local.
     &                              LOCAL)
      END SELECT                                                         ! End of the case selection.
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      ANALYSIS_SECONDS = TIMER_WALL_SECONDS(TIMER)                       ! Set analysis_seconds to timer_wall_seconds(timer).
      CALL REMEMBER_WARNING(LOCAL, WARNINGS)                             ! Call remember warning with local, warnings.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL TIMER_START(TIMER, 'OUTPUT')                                  ! Call timer start with timer, 'OUTPUT'.
      SELECT CASE(MODEL%ANALYSIS%SOLUTION)                               ! Choose according to the value of model.analysis.solution:
      CASE(SOLUTION_STATIC, SOLUTION_NONLINEAR)                          ! Case solution_static, solution_nonlinear:
        CALL WRITE_STATIC_OUTPUT(MODEL, CACHE, RESULTS, WARNINGS,        ! Call write static output with model, cache, results, warnings, local.
     &                           LOCAL)
      CASE(SOLUTION_MODAL, SOLUTION_BUCKLING)                            ! Case solution_modal, solution_buckling:
        CALL WRITE_MODAL_OUTPUT(MODEL, CACHE, RESULTS, LOCAL)            ! Call write modal output with model, cache, results, local.
      END SELECT                                                         ! End of the case selection.
      CALL TIMER_STOP(TIMER)                                             ! Call timer stop with timer.
      OUTPUT_SECONDS = TIMER_WALL_SECONDS(TIMER)                         ! Set output_seconds to timer_wall_seconds(timer).
      CALL REMEMBER_WARNING(LOCAL, WARNINGS)                             ! Call remember warning with local, warnings.
      CALL MERGE_STATUS(LOCAL, STATUS)                                   ! Merge status local into status.
      CALL WRITE_WARNING_FILE(WARNINGS, LOCAL)                           ! Call write warning file with warnings, local.

      WRITE(MESSAGE,'(A,4F9.3)') 'TIMES [S] INPUT/PRE/ANALYSIS/OUT:',    ! Format into the text message: 'TIMES [S] INPUT/PRE/ANALYSIS/OUT:', input_seconds, cache_seconds, analysis_s...
     &  INPUT_SECONDS, CACHE_SECONDS, ANALYSIS_SECONDS, OUTPUT_SECONDS
      CALL LOG_INFO(MESSAGE)                                             ! Log: message.

      END SUBROUTINE RUN_MUL2                                            ! End of the subroutine run mul2.

!  WARNINGS OF A STEP GO INTO REPORT/WARNING_file.dat.
      SUBROUTINE REMEMBER_WARNING(STATUS, WARNINGS)                      ! Subroutine remember warning takes status, warnings.

      TYPE(STATUS_TYPE), INTENT(IN) :: STATUS                            ! Input of type status_type: status.
      TYPE(WARNING_LIST_TYPE), INTENT(INOUT) :: WARNINGS                 ! In/out of type warning_list_type: warnings.

      IF (STATUS%WARNING_COUNT .LT. 1_I4) RETURN                         ! If status.warning_count < 1, return to the caller.
      IF (WARNINGS%COUNT .GE. SIZE(WARNINGS%TEXT)) RETURN                ! If warnings.count >= size(warnings.text), return to the caller.
      WARNINGS%COUNT = WARNINGS%COUNT + 1_I4                             ! Add 1 to warnings.count.
      WARNINGS%TEXT(WARNINGS%COUNT) = TRIM(STATUS%SOURCE)//': '//        ! Set warnings.text(warnings.count) to trim(status.source)//': '// trim(status.message).
     &                                TRIM(STATUS%MESSAGE)

      END SUBROUTINE REMEMBER_WARNING                                    ! End of the subroutine remember warning.

      END MODULE MUL2_DRIVER                                             ! End of the module mul2 driver.
