CMAKE_MINIMUM_REQUIRED(VERSION 3.24)

PROJECT(MUL2_V3 VERSION 3.0.0 LANGUAGES Fortran)

OPTION(MUL2_ENABLE_OPENMP "ENABLE OPENMP" OFF)
OPTION(MUL2_ENABLE_MKL "ENABLE INTEL MKL/PARDISO" OFF)
OPTION(MUL2_MKL_ILP64 "USE THE 64-BIT MKL INTEGER INTERFACE" ON)
OPTION(MUL2_MKL_THREADED "THREADED MKL (PARDISO/BLAS): FASTER, NOT BIT-REPRODUCIBLE ACROSS THREAD COUNTS" OFF)

# ---------------------------------------------------------------------
#  CORE: MODEL, INPUT, GEOMETRY, CUF, MATERIALS, ASSEMBLY, POST.
#  NO DEPENDENCY ON MKL OR ARPACK.
# ---------------------------------------------------------------------
SET(MUL2_CORE_SOURCES
    SRC/BASE/mul2_kinds.for
    SRC/BASE/mul2_strings.for
    SRC/BASE/mul2_status.for
    SRC/BASE/mul2_log.for
    SRC/BASE/mul2_timer.for
    SRC/BASE/mul2_files.for
    SRC/BASE/mul2_sorting.for
    SRC/BASE/mul2_runtime.for
    SRC/FEM/mul2_hle_shape.for
    SRC/FEM/mul2_hle_map.for
    SRC/MODEL/mul2_kinematics.for
    SRC/MODEL/mul2_nodes.for
    SRC/MODEL/mul2_incidence.for
    SRC/MODEL/mul2_topologies.for
    SRC/MODEL/mul2_elements.for
    SRC/MODEL/mul2_expansion_meshes.for
    SRC/MODEL/mul2_hle_modes.for
    SRC/MODEL/mul2_reference_systems.for
    SRC/MODEL/mul2_laminations.for
    SRC/MODEL/mul2_boundary_conditions.for
    SRC/MATERIALS/mul2_materials.for
    SRC/MATERIALS/mul2_material_rotations.for
    SRC/MATERIALS/mul2_material_resolution.for
    SRC/KINEMATICS/mul2_linear_kinematics.for
    SRC/CUF/mul2_cuf_bases.for
    SRC/CUF/mul2_point_bases.for
    SRC/CUF/mul2_fundamental_nucleus.for
    SRC/IO/mul2_text_io.for
    SRC/IO/read_kinematics.for
    SRC/IO/read_nodes.for
    SRC/IO/read_connectivity.for
    SRC/IO/read_expansions.for
    SRC/IO/read_reference_systems.for
    SRC/IO/read_materials.for
    SRC/IO/read_laminations.for
    SRC/IO/read_boundary_conditions.for
    SRC/FEM/mul2_shape_functions.for
    SRC/GEOMETRY/mul2_jacobians.for
    SRC/GEOMETRY/mul2_local_gradients.for
    SRC/GEOMETRY/mul2_element_frames.for
    SRC/GEOMETRY/mul2_general_geometry.for
    SRC/QUADRATURE/mul2_quadrature.for
    SRC/GAUSS/mul2_gauss_points.for
    SRC/GAUSS/mul2_gauss_geometry.for
    SRC/GAUSS/mul2_gauss_materials.for
    SRC/ASSEMBLY/mul2_dof_layout.for
    SRC/ELEMENTS/mul2_mitc.for
    SRC/ELEMENTS/mul2_dense_products.for
    SRC/ELEMENTS/mul2_separable_kernel.for
    SRC/ELEMENTS/mul2_element_matrices.for
    SRC/ELEMENTS/mul2_general_kernel.for
    SRC/ASSEMBLY/mul2_sparse_assembly.for
    SRC/ASSEMBLY/mul2_sparse_operations.for
    SRC/MODEL/mul2_fields.for
    SRC/MODEL/mul2_time_input.for
    SRC/IO/read_time.for
    SRC/IO/read_fields.for
    SRC/IO/read_directors.for
    SRC/BOUNDARY/mul2_boundary_application.for
    SRC/BOUNDARY/mul2_coincident_join.for
    SRC/MODEL/mul2_analysis_input.for
    SRC/MODEL/mul2_model.for
    SRC/IO/read_analysis.for
    SRC/IO/read_legacy_nodes.for
    SRC/IO/read_model.for
    SRC/ANALYSES/mul2_model_cache.for
    SRC/ANALYSES/mul2_model_assembly.for
    SRC/ANALYSES/mul2_analysis_results.for
    SRC/ANALYSES/mul2_dynamic_common.for
    SRC/POST/mul2_recovery.for
    SRC/BOUNDARY/mul2_surface_loads.for
    SRC/POST/mul2_post_grid.for
    SRC/POST/mul2_post_output.for)

# ---------------------------------------------------------------------
#  SOLVERS AND ANALYSIS DRIVERS: REQUIRE MKL (PARDISO, LAPACK/BLAS).
# ---------------------------------------------------------------------
SET(MUL2_SOLVER_SOURCES
    SRC/SOLVERS/mul2_pardiso_factor.for
    SRC/SOLVERS/mul2_pardiso_solver.for
    SRC/SOLVERS/mul2_modal_solver.for
    SRC/ANALYSES/mul2_analysis_101.for
    SRC/ANALYSES/mul2_analysis_103.for
    SRC/ANALYSES/mul2_analysis_104.for
    SRC/ANALYSES/mul2_analysis_105.for
    SRC/ANALYSES/mul2_analysis_106.for
    SRC/ANALYSES/mul2_analysis_108.for
    SRC/ANALYSES/mul2_driver.for)

SET_SOURCE_FILES_PROPERTIES(${MUL2_CORE_SOURCES}
                            ${MUL2_SOLVER_SOURCES}
                            SRC/APP/mul2_main.for
                            SRC/APP/mul2_main_core.for
                            TESTS/mul2_tests.for
                            TESTS/mul2_hle_tests.for
                            TESTS/mul2_pardiso_tests.for
                            TESTS/mul2_analysis_tests.for
                            TESTS/mul2_test_support.for
                            PROPERTIES Fortran_FORMAT FIXED)

ADD_LIBRARY(MUL2_CORE STATIC ${MUL2_CORE_SOURCES})
SET_TARGET_PROPERTIES(MUL2_CORE PROPERTIES
                      Fortran_MODULE_DIRECTORY
                      "${CMAKE_BINARY_DIR}/MODULES")
TARGET_INCLUDE_DIRECTORIES(MUL2_CORE PUBLIC
                           "${CMAKE_BINARY_DIR}/MODULES")

FUNCTION(MUL2_SET_FORTRAN_OPTIONS TARGET_NAME)
  TARGET_COMPILE_OPTIONS(${TARGET_NAME} PRIVATE
    # ARRAY TEMPORARIES LARGER THAN 256 KB GO TO THE HEAP, NOT TO THE
    # (SMALL) STACK OF THE MAIN THREAD OR OF AN OPENMP WORKER.
    $<$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>:/heap-arrays:256>
    # MARGIN NOTES AFTER COLUMN 72 ARE INTENTIONAL (NO "TEXT IGNORED" WARNING).
    $<$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>:/Qdiag-disable:5194>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Debug>>:/Od>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Debug>>:/traceback>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Debug>>:/check:all>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Debug>>:/warn:all>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Release>>:/O2>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Release>>:/traceback>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Release>>:/fp:precise>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Release_Fast>>:/O3>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Release_Fast>>:/QxHost>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Release_Fast>>:/Qipo>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Release_Fast>>:/traceback>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Release_Fast>>:/fp:precise>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Debug>>:-O0>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Debug>>:-g3>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Debug>>:-fcheck=all>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Debug>>:-fbacktrace>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Debug>>:-Wall>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Debug>>:-Wextra>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Debug>>:-Wimplicit-interface>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Release>>:-O2>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Release>>:-fbacktrace>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Release_Fast>>:-O3>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Release_Fast>>:-march=native>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,GNU>,$<CONFIG:Release_Fast>>:-fbacktrace>)
ENDFUNCTION()

MUL2_SET_FORTRAN_OPTIONS(MUL2_CORE)

IF(MUL2_ENABLE_OPENMP)
  IF(WIN32 AND CMAKE_Fortran_COMPILER_ID STREQUAL "IntelLLVM")
    TARGET_COMPILE_OPTIONS(MUL2_CORE PUBLIC /Qopenmp)
  ELSE()
    FIND_PACKAGE(OpenMP REQUIRED COMPONENTS Fortran)
    TARGET_LINK_LIBRARIES(MUL2_CORE PUBLIC OpenMP::OpenMP_Fortran)
  ENDIF()
ENDIF()

# ---------------------------------------------------------------------
#  MKL, ARPACK, SOLVER LIBRARY.
# ---------------------------------------------------------------------
IF(MUL2_ENABLE_MKL)
  IF(MUL2_MKL_ILP64)
    SET(MKL_INTERFACE ilp64)
  ELSE()
    SET(MKL_INTERFACE lp64)
  ENDIF()
  IF(MUL2_MKL_THREADED)
    SET(MKL_THREADING intel_thread)
  ELSE()
    SET(MKL_THREADING sequential)
  ENDIF()
  SET(MKL_LINK dynamic)
  FIND_PACKAGE(MKL CONFIG REQUIRED)
  ADD_LIBRARY(MUL2_SOLVER_MKL INTERFACE)
  TARGET_LINK_LIBRARIES(MUL2_SOLVER_MKL INTERFACE
                        "$<LINK_ONLY:MKL::MKL>")

  # ARPACK (SYMMETRIC DRIVERS ONLY). INTEGERS ARE 64 BIT TO MATCH THE
  # ILP64 BLAS/LAPACK; THE F90 DRIVER USES INTEGER(I8) ARGUMENTS.
  FILE(GLOB MUL2_ARPACK_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/SRC/ARPACK/*.f")
  ADD_LIBRARY(MUL2_ARPACK STATIC ${MUL2_ARPACK_SOURCES})
  SET_SOURCE_FILES_PROPERTIES(${MUL2_ARPACK_SOURCES}
                              PROPERTIES Fortran_FORMAT FIXED)
  SET_TARGET_PROPERTIES(MUL2_ARPACK PROPERTIES
                        Fortran_MODULE_DIRECTORY
                        "${CMAKE_BINARY_DIR}/MODULES_ARPACK")
  TARGET_INCLUDE_DIRECTORIES(MUL2_ARPACK PRIVATE
                             "${CMAKE_CURRENT_SOURCE_DIR}/SRC/ARPACK")
  TARGET_COMPILE_OPTIONS(MUL2_ARPACK PRIVATE
    $<$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>:/4I8>
    $<$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>:/w>
    $<$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>:/traceback>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<CONFIG:Debug>>:/Od>
    $<$<AND:$<COMPILE_LANG_AND_ID:Fortran,IntelLLVM>,$<NOT:$<CONFIG:Debug>>>:/O2>)
  TARGET_LINK_LIBRARIES(MUL2_ARPACK PRIVATE MUL2_SOLVER_MKL)

  ADD_LIBRARY(MUL2_SOLVERS STATIC ${MUL2_SOLVER_SOURCES})
  SET_TARGET_PROPERTIES(MUL2_SOLVERS PROPERTIES
                        Fortran_MODULE_DIRECTORY
                        "${CMAKE_BINARY_DIR}/MODULES_SOLVERS")
  TARGET_INCLUDE_DIRECTORIES(MUL2_SOLVERS PUBLIC
                             "${CMAKE_BINARY_DIR}/MODULES_SOLVERS")
  TARGET_LINK_LIBRARIES(MUL2_SOLVERS PUBLIC MUL2_CORE
                        PRIVATE MUL2_ARPACK MUL2_SOLVER_MKL)
  MUL2_SET_FORTRAN_OPTIONS(MUL2_SOLVERS)
  SET(MUL2_MAIN_SOURCE SRC/APP/mul2_main.for)
  SET(MUL2_MAIN_LIBRARY MUL2_SOLVERS)
ELSE()
  SET(MUL2_MAIN_SOURCE SRC/APP/mul2_main_core.for)
  SET(MUL2_MAIN_LIBRARY MUL2_CORE)
ENDIF()

ADD_EXECUTABLE(MUL2_V3 ${MUL2_MAIN_SOURCE})
TARGET_LINK_LIBRARIES(MUL2_V3 PRIVATE ${MUL2_MAIN_LIBRARY})
IF(MUL2_ENABLE_MKL)
  TARGET_LINK_LIBRARIES(MUL2_V3 PRIVATE MUL2_ARPACK MUL2_SOLVER_MKL)
ENDIF()
MUL2_SET_FORTRAN_OPTIONS(MUL2_V3)

ADD_EXECUTABLE(MUL2_TESTS TESTS/mul2_tests.for)
TARGET_LINK_LIBRARIES(MUL2_TESTS PRIVATE MUL2_CORE)
MUL2_SET_FORTRAN_OPTIONS(MUL2_TESTS)

ADD_EXECUTABLE(MUL2_HLE_TESTS TESTS/mul2_hle_tests.for)
TARGET_LINK_LIBRARIES(MUL2_HLE_TESTS PRIVATE MUL2_CORE)
MUL2_SET_FORTRAN_OPTIONS(MUL2_HLE_TESTS)

IF(MUL2_ENABLE_MKL)
  ADD_EXECUTABLE(MUL2_PARDISO_TESTS TESTS/mul2_pardiso_tests.for)
  TARGET_LINK_LIBRARIES(MUL2_PARDISO_TESTS PRIVATE
                        MUL2_SOLVERS MUL2_ARPACK MUL2_SOLVER_MKL)
  MUL2_SET_FORTRAN_OPTIONS(MUL2_PARDISO_TESTS)

  ADD_EXECUTABLE(MUL2_ANALYSIS_TESTS TESTS/mul2_test_support.for
                 TESTS/mul2_analysis_tests.for)
  TARGET_LINK_LIBRARIES(MUL2_ANALYSIS_TESTS PRIVATE
                        MUL2_SOLVERS MUL2_ARPACK MUL2_SOLVER_MKL)
  MUL2_SET_FORTRAN_OPTIONS(MUL2_ANALYSIS_TESTS)
ENDIF()

ENABLE_TESTING()
ADD_TEST(NAME MUL2_BASE_TESTS COMMAND MUL2_TESTS)
ADD_TEST(NAME MUL2_HLE_TESTS COMMAND MUL2_HLE_TESTS)
ADD_TEST(NAME MUL2_SMOKE_TEST COMMAND MUL2_V3 --version)
IF(MUL2_ENABLE_MKL)
  ADD_TEST(NAME MUL2_PARDISO_TEST COMMAND MUL2_PARDISO_TESTS)
  ADD_TEST(NAME MUL2_ANALYSIS_TEST COMMAND MUL2_ANALYSIS_TESTS
           $<TARGET_FILE:MUL2_V3> "${CMAKE_CURRENT_SOURCE_DIR}"
           "${CMAKE_BINARY_DIR}/TESTRUNS")
ENDIF()
IF(MUL2_ENABLE_MKL)
  FIND_PACKAGE(Python3 COMPONENTS Interpreter QUIET)
  IF(Python3_FOUND)
    ADD_TEST(NAME MUL2_HLE_SOLVER_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/HLE/hle_tests.py"
             $<TARGET_FILE:MUL2_V3> "${CMAKE_BINARY_DIR}/TESTRUNS/HLE")
    ADD_TEST(NAME MUL2_REDUCED_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/REDUCED/reduced_tests.py"
             $<TARGET_FILE:MUL2_V3>)
    ADD_TEST(NAME MUL2_PIEZO_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/PIEZO/piezo_tests.py"
             $<TARGET_FILE:MUL2_V3>)
    ADD_TEST(NAME MUL2_EXTENDED_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/EXTENDED/extended_tests.py"
             $<TARGET_FILE:MUL2_V3>)
    ADD_TEST(NAME MUL2_NONLINEAR_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/NONLINEAR/nonlinear_tests.py"
             $<TARGET_FILE:MUL2_V3>)
    ADD_TEST(NAME MUL2_JOIN_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/JOIN/join_tests.py"
             $<TARGET_FILE:MUL2_V3>)
    ADD_TEST(NAME MUL2_CURVED_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/CURVED/curved_tests.py"
             $<TARGET_FILE:MUL2_V3>)
    ADD_TEST(NAME MUL2_BUCKLING_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/BUCKLING/buckling_tests.py"
             $<TARGET_FILE:MUL2_V3>)
    ADD_TEST(NAME MUL2_DYNAMICS_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/DYNAMICS/dynamics_tests.py"
             $<TARGET_FILE:MUL2_V3>)
    ADD_TEST(NAME MUL2_THERMAL_TESTS
             COMMAND ${Python3_EXECUTABLE}
             "${CMAKE_CURRENT_SOURCE_DIR}/TESTS/THERMAL/thermal_tests.py"
             $<TARGET_FILE:MUL2_V3>)
  ENDIF()
ENDIF()
SET_TESTS_PROPERTIES(MUL2_BASE_TESTS PROPERTIES
                     WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
IF(MUL2_ENABLE_MKL)
  SET_TESTS_PROPERTIES(MUL2_ANALYSIS_TEST PROPERTIES
                       WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
ENDIF()

IF(WIN32 AND CMAKE_Fortran_COMPILER_ID STREQUAL "IntelLLVM")
  GET_FILENAME_COMPONENT(MUL2_IFX_RUNTIME_DIR
                         "${CMAKE_Fortran_COMPILER}" DIRECTORY)
  SET_TESTS_PROPERTIES(MUL2_BASE_TESTS MUL2_SMOKE_TEST PROPERTIES
    ENVIRONMENT_MODIFICATION
    "PATH=path_list_prepend:${MUL2_IFX_RUNTIME_DIR}")
  IF(MUL2_ENABLE_MKL)
    SET_TESTS_PROPERTIES(MUL2_PARDISO_TEST MUL2_ANALYSIS_TEST
      PROPERTIES ENVIRONMENT_MODIFICATION
      "PATH=path_list_prepend:${MUL2_IFX_RUNTIME_DIR};PATH=path_list_prepend:${MKL_ROOT}/bin")
  ENDIF()
ENDIF()

ADD_CUSTOM_TARGET(CHECK_FIXED_FORM ALL
  COMMAND "${CMAKE_COMMAND}"
          -DSOURCE_ROOT="${CMAKE_CURRENT_SOURCE_DIR}"
          -P "${CMAKE_CURRENT_SOURCE_DIR}/CMAKE/CHECK_FIXED_FORM.cmake"
  VERBATIM)
