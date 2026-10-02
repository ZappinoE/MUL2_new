!=======================================================================
!  READ A COMPLETE INPUT DIRECTORY INTO ONE MODEL.
!
!  THE DIRECTORY FOLLOWS THE HISTORICAL LAYOUT (ANALYSIS, NODES,
!  CONNECTIVITY, EXP_MESH_NN, EXP_CONN_NN, MATERIAL, LAMINATION,
!  VERSORS, BC, POSTPROCESSING). IF `KINEMATICS.dat` IS PRESENT THE V3
!  NODES.dat (WITH KINEMATIC_ID) IS EXPECTED, OTHERWISE THE HISTORICAL
!  NODES.dat IS CONVERTED BY MUL2_READ_LEGACY_NODES.
!=======================================================================
      MODULE MUL2_READ_MODEL                                             ! Module mul2 read model begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error, status is ok, merge status.
     &                       SET_WARNING, SET_ERROR, STATUS_IS_OK,
     &                       MERGE_STATUS
      USE MUL2_KINEMATICS, ONLY: APPLY_FIELD_SELECTION                   ! Use from module mul2 kinematics: apply field selection.
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_READ_ANALYSIS, ONLY: READ_ANALYSIS_FILE,                  ! Use from module mul2 read analysis: read analysis file, read postprocessing file.
     &                              READ_POSTPROCESSING_FILE
      USE MUL2_READ_KINEMATICS, ONLY: READ_KINEMATICS_FILE               ! Use from module mul2 read kinematics: read kinematics file.
      USE MUL2_READ_NODES, ONLY: READ_NODES_FILE                         ! Use from module mul2 read nodes: read nodes file.
      USE MUL2_READ_LEGACY_NODES, ONLY: READ_LEGACY_NODES_FILE           ! Use from module mul2 read legacy nodes: read legacy nodes file.
      USE MUL2_READ_CONNECTIVITY, ONLY: READ_CONNECTIVITY_FILE           ! Use from module mul2 read connectivity: read connectivity file.
      USE MUL2_READ_EXPANSIONS, ONLY: READ_EXPANSION_SET                 ! Use from module mul2 read expansions: read expansion set.
      USE MUL2_READ_REFERENCE_SYSTEMS, ONLY:                             ! Use from module mul2 read reference systems: read reference vectors file.
     &     READ_REFERENCE_VECTORS_FILE
      USE MUL2_READ_MATERIALS, ONLY: READ_MATERIALS_FILE                 ! Use from module mul2 read materials: read materials file.
      USE MUL2_READ_LAMINATIONS, ONLY: READ_LAMINATIONS_FILE             ! Use from module mul2 read laminations: read laminations file.
      USE MUL2_READ_BOUNDARY_CONDITIONS, ONLY:                           ! Use from module mul2 read boundary conditions: read boundary conditions file.
     &     READ_BOUNDARY_CONDITIONS_FILE
      USE MUL2_READ_FIELDS, ONLY: READ_FIELDS_FILE                       ! Use from module mul2 read fields: read fields file.
      USE MUL2_READ_DIRECTORS, ONLY: READ_DIRECTORS_FILE                 ! Use from module mul2 read directors: read directors file.
      USE MUL2_READ_TIME, ONLY: READ_TIME_FILE, READ_FREQ_FILE,          ! Use from module mul2 read time: read time file, read freq file, read nl file.
     &                          READ_NL_FILE

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_MODEL                                               ! Export: read model.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_MODEL(INPUT_PATH, MODEL, STATUS)                   ! Subroutine read model takes input path, model, status.

      CHARACTER(LEN=*), INTENT(IN) :: INPUT_PATH                         ! Input character (length *): input_path.
      TYPE(MODEL_TYPE), INTENT(INOUT) :: MODEL                           ! In/out of type model_type: model.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      LOGICAL :: HAS_KINEMATICS                                          ! Logical: has_kinematics.
      INTEGER(I4) :: EXPANSION_COUNT                                     ! Integer (int32): expansion_count.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      MODEL%INPUT_PATH = INPUT_PATH                                      ! Set model.input_path to input_path.

      CALL READ_ANALYSIS_FILE(FILE_OF('ANALYSIS.dat'),                   ! Call read analysis file with file_of('ANALYSIS.dat'), model.analysis, local_status.
     &                        MODEL%ANALYSIS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      INQUIRE(FILE=FILE_OF('KINEMATICS.dat'), EXIST=HAS_KINEMATICS)      ! Ask the file system whether the file exists, result in has_kinematics.
      IF (HAS_KINEMATICS) THEN                                           ! If has_kinematics:
        CALL READ_KINEMATICS_FILE(FILE_OF('KINEMATICS.dat'),             ! Call read kinematics file with file_of('KINEMATICS.dat'), model.kinematics, local_status.
     &                            MODEL%KINEMATICS, LOCAL_STATUS)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
        IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                           ! If not status is ok, return to the caller.
        IF (MODEL%ANALYSIS%FIELD_RECORD) THEN                            ! If model.analysis.field_record:
          CALL APPLY_FIELD_SELECTION(MODEL%KINEMATICS,                   ! Call apply field selection with model.kinematics, model.analysis.field_thermo, model.analysis.field_piezo, ...
     &      MODEL%ANALYSIS%FIELD_THERMO, MODEL%ANALYSIS%FIELD_PIEZO,
     &      LOCAL_STATUS)
          CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                        ! Merge status local_status into status.
          IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                         ! If not status is ok, return to the caller.
        END IF                                                           ! End of the IF block.
        CALL READ_NODES_FILE(FILE_OF('NODES.dat'), MODEL%KINEMATICS,     ! Call read nodes file with file_of('NODES.dat'), model.kinematics, model.nodes, local_status.
     &                       MODEL%NODES, LOCAL_STATUS)
      ELSE                                                               ! Otherwise:
        CALL READ_LEGACY_NODES_FILE(FILE_OF('NODES.dat'),                ! Call read legacy nodes file with file_of('NODES.dat'), model.kinematics, model.nodes, local_status.
     &       MODEL%KINEMATICS, MODEL%NODES, LOCAL_STATUS)
      END IF                                                             ! End of the IF block.
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL READ_CONNECTIVITY_FILE(FILE_OF('CONNECTIVITY.dat'),           ! Call read connectivity file with file_of('CONNECTIVITY.dat'), model.nodes, model.elements, local_status.
     &     MODEL%NODES, MODEL%ELEMENTS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      EXPANSION_COUNT = MAXVAL(MODEL%ELEMENTS%ITEM%EXPANSION_ID)         ! Set expansion_count to the maximum of model.elements.item.expansion_id.
      CALL READ_EXPANSION_SET(TRIM(INPUT_PATH), EXPANSION_COUNT,         ! Call read expansion set with trim(input_path), expansion_count, model.expansions, local_status.
     &                        MODEL%EXPANSIONS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL READ_REFERENCE_VECTORS_FILE(FILE_OF('VERSORS.dat'),           ! Call read reference vectors file with file_of('VERSORS.dat'), model.vectors, local_status.
     &                                 MODEL%VECTORS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL READ_MATERIALS_FILE(FILE_OF('MATERIAL.dat'),                  ! Call read materials file with file_of('MATERIAL.dat'), model.materials, local_status.
     &                         MODEL%MATERIALS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL READ_LAMINATIONS_FILE(FILE_OF('LAMINATION.dat'),              ! Call read laminations file with file_of('LAMINATION.dat'), model.materials, model.laminations, local_status.
     &     MODEL%MATERIALS, MODEL%LAMINATIONS, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL READ_FIELDS_FILE(FILE_OF('FIELDS.dat'), MODEL%FIELDS,         ! Call read fields file with file_of('FIELDS.dat'), model.fields, local_status.
     &                      LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL READ_DIRECTORS_FILE(FILE_OF('DIRECTORS.dat'), MODEL%NODES,    ! Call read directors file with file_of('DIRECTORS.dat'), model.nodes, local_status.
     &                         LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL READ_BOUNDARY_CONDITIONS_FILE(FILE_OF('BC.dat'),              ! Call read boundary conditions file with file_of('BC.dat'), model.boundaries, local_status.
     &                        MODEL%BOUNDARIES, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.

      CALL READ_POSTPROCESSING_FILE(FILE_OF('POSTPROCESSING.dat'),       ! Call read postprocessing file with file_of('POSTPROCESSING.dat'), model.post, local_status.
     &                              MODEL%POST, LOCAL_STATUS)
      CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                            ! Merge status local_status into status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      IF (MODEL%ANALYSIS%SOLUTION .EQ. 104_I4) THEN                      ! If model.analysis.solution = 104:
        CALL READ_TIME_FILE(FILE_OF('TIME_RESP.dat'), MODEL%TIME,        ! Call read time file with file_of('TIME_RESP.dat'), model.time, local_status.
     &                      LOCAL_STATUS)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
      END IF                                                             ! End of the IF block.
      IF (MODEL%ANALYSIS%SOLUTION .EQ. 108_I4) THEN                      ! If model.analysis.solution = 108:
        CALL READ_NL_FILE(FILE_OF('NL_INFO.dat'), MODEL%NL,              ! Call read nl file with file_of('NL_INFO.dat'), model.nl, local_status.
     &                    LOCAL_STATUS)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
      END IF                                                             ! End of the IF block.
      IF (MODEL%ANALYSIS%SOLUTION .EQ. 106_I4) THEN                      ! If model.analysis.solution = 106:
        CALL READ_FREQ_FILE(FILE_OF('FREQ_RESP.dat'), MODEL%FREQ,        ! Call read freq file with file_of('FREQ_RESP.dat'), model.freq, local_status.
     &                      LOCAL_STATUS)
        CALL MERGE_STATUS(LOCAL_STATUS, STATUS)                          ! Merge status local_status into status.
      END IF                                                             ! End of the IF block.

      CONTAINS                                                           ! The procedures of the module follow.

      CHARACTER(LEN=600) FUNCTION FILE_OF(NAME)                          ! Function file of takes name.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.

      FILE_OF = TRIM(INPUT_PATH)//'/'//NAME                              ! Set file_of to trim(input_path)//'/'//name.

      END FUNCTION FILE_OF                                               ! End of the function file of.

      END SUBROUTINE READ_MODEL                                          ! End of the subroutine read model.

      END MODULE MUL2_READ_MODEL                                         ! End of the module mul2 read model.
