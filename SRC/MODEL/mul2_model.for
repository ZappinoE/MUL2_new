!=======================================================================
!  COMPLETE INPUT MODEL: ONE CONTAINER PASSED TO THE HIGH-LEVEL STEPS.
!=======================================================================
      MODULE MUL2_MODEL                                                  ! Module mul2 model begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_ANALYSIS_INPUT, ONLY: ANALYSIS_TYPE, POST_DB_TYPE         ! Use from module mul2 analysis input: analysis type, post db type.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE                      ! Use from module mul2 kinematics: kinematics db type.
      USE MUL2_NODES, ONLY: NODE_DB_TYPE                                 ! Use from module mul2 nodes: node db type.
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE                 ! Use from module mul2 expansion meshes: expansion db type.
      USE MUL2_REFERENCE_SYSTEMS, ONLY: REFERENCE_VECTOR_DB_TYPE         ! Use from module mul2 reference systems: reference vector db type.
      USE MUL2_MATERIALS, ONLY: MATERIAL_DB_TYPE                         ! Use from module mul2 materials: material db type.
      USE MUL2_LAMINATIONS, ONLY: LAMINATION_DB_TYPE                     ! Use from module mul2 laminations: lamination db type.
      USE MUL2_BOUNDARY_CONDITIONS, ONLY: BOUNDARY_DB_TYPE               ! Use from module mul2 boundary conditions: boundary db type.
      USE MUL2_FIELDS, ONLY: FIELD_DB_TYPE                               ! Use from module mul2 fields: field db type.
      USE MUL2_TIME_INPUT, ONLY: TIME_INPUT_TYPE, FREQ_INPUT_TYPE,       ! Use from module mul2 time input: time input type, freq input type, nl input type.
     &                           NL_INPUT_TYPE

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: MODEL_TYPE                                         ! Definition of the derived type model type.
        CHARACTER(LEN=512) :: INPUT_PATH = ' '                           ! Character (length 512): input_path = ' '.
        TYPE(ANALYSIS_TYPE) :: ANALYSIS                                  ! Of type analysis_type: analysis.
        TYPE(POST_DB_TYPE) :: POST                                       ! Of type post_db_type: post.
        TYPE(KINEMATICS_DB_TYPE) :: KINEMATICS                           ! Of type kinematics_db_type: kinematics.
        TYPE(NODE_DB_TYPE) :: NODES                                      ! Of type node_db_type: nodes.
        TYPE(ELEMENT_DB_TYPE) :: ELEMENTS                                ! Of type element_db_type: elements.
        TYPE(EXPANSION_DB_TYPE) :: EXPANSIONS                            ! Of type expansion_db_type: expansions.
        TYPE(REFERENCE_VECTOR_DB_TYPE) :: VECTORS                        ! Of type reference_vector_db_type: vectors.
        TYPE(MATERIAL_DB_TYPE) :: MATERIALS                              ! Of type material_db_type: materials.
        TYPE(LAMINATION_DB_TYPE) :: LAMINATIONS                          ! Of type lamination_db_type: laminations.
        TYPE(BOUNDARY_DB_TYPE) :: BOUNDARIES                             ! Of type boundary_db_type: boundaries.
        TYPE(FIELD_DB_TYPE) :: FIELDS                                    ! Of type field_db_type: fields.
        TYPE(TIME_INPUT_TYPE) :: TIME                                    ! Of type time_input_type: time.
        TYPE(FREQ_INPUT_TYPE) :: FREQ                                    ! Of type freq_input_type: freq.
        TYPE(NL_INPUT_TYPE) :: NL                                        ! Of type nl_input_type: nl.
      END TYPE MODEL_TYPE                                                ! End of the type definition model type.

      END MODULE MUL2_MODEL                                              ! End of the module mul2 model.
