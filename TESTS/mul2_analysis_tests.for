!=======================================================================
!  END-TO-END TESTS OF ANALYSES 101 AND 103.
!
!  USAGE: MUL2_ANALYSIS_TESTS EXE SOURCE_ROOT RUN_ROOT
!    EXE          THE MUL2_V3 EXECUTABLE UNDER TEST
!    SOURCE_ROOT  THE PROJECT DIRECTORY (REFERENCES, TESTS/CASES)
!    RUN_ROOT     DIRECTORY WHERE THE RUNS ARE EXECUTED (NEVER THE
!                 SOURCE TREE)
!
!  * FROZEN BASELINE GOLDEN CASES (REFERENCES/GOLDEN)
!  * CASES GENERATED WITH THE FROZEN BASELINE (TESTS/CASES/*/REFERENCE)
!  * PATCH TESTS WITH KNOWN ANALYTICAL SOLUTION (UNIFORM STRAIN)
!  * INDEPENDENCE OF THE RESULT FROM THE NUMBER OF THREADS
!
!  TOLERANCES ARE RELATIVE TO THE LARGEST VALUE OF THE FIELD. THE
!  BASELINE IMPOSES CONSTRAINTS WITH A PENALTY (1E10 ON THE DIAGONAL),
!  V3 BY EXACT ELIMINATION: DIFFERENCES OF ABOUT 1E-7 ARE EXPECTED.
!=======================================================================
      PROGRAM MUL2_ANALYSIS_TESTS                                        ! Main program mul2 analysis tests begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_TEST_SUPPORT, ONLY: RUN_SOLVER, READ_POINT_ROWS,          ! Use from module mul2 test support: run solver, read point rows, read frequencies, read vtk block, max relat...
     &     READ_FREQUENCIES, READ_VTK_BLOCK,
     &     MAX_RELATIVE_DIFFERENCE, FILES_ARE_IDENTICAL

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.

      REAL(R8), PARAMETER :: POINT_TOLERANCE = 1.0E-4_R8                 ! Constant real (real64): point_tolerance = 1.0e-4.
      CHARACTER(LEN=512) :: EXE                                          ! Character (length 512): exe.
      CHARACTER(LEN=512) :: ROOT                                         ! Character (length 512): root.
      CHARACTER(LEN=512) :: RUNS                                         ! Character (length 512): runs.
      INTEGER :: FAILURES                                                ! Integer: failures.

      FAILURES = 0                                                       ! Set failures to zero.
      IF (COMMAND_ARGUMENT_COUNT() .LT. 3) THEN                          ! If command_argument_count() < 3:
        WRITE(*,'(A)') 'USAGE: MUL2_ANALYSIS_TESTS EXE ROOT RUN_ROOT'    ! Print: 'USAGE: MUL2_ANALYSIS_TESTS EXE ROOT RUN_ROOT'.
        STOP 2                                                           ! Stop the program.
      END IF                                                             ! End of the IF block.
      CALL GET_COMMAND_ARGUMENT(1, EXE)                                  ! Call get command argument with 1, exe.
      CALL GET_COMMAND_ARGUMENT(2, ROOT)                                 ! Call get command argument with 2, root.
      CALL GET_COMMAND_ARGUMENT(3, RUNS)                                 ! Call get command argument with 3, runs.

!     FROZEN BASELINE GOLDEN CASES. THE BEAM GOLDEN HAS SLIGHTLY
!     NON-UNIFORM NODES: THE BASELINE POST-PROCESSING USES THE
!     JACOBIAN OF THE EVALUATION POINT AT THE TYING POINTS, SO THE
!     TIED SHEAR STRAINS DIFFER BY ABOUT 1% (SEE REFACTORING_NOTES).
      CALL STATIC_CASE('GOLDEN_BEAM_101',                                ! Call static case with 'GOLDEN_BEAM_101', trim(root)//'/REFERENCES/BASELINE_INPUTS/101_BEAM_B4_LE', trim(roo...
     &  TRIM(ROOT)//'/REFERENCES/BASELINE_INPUTS/101_BEAM_B4_LE',
     &  TRIM(ROOT)//'/REFERENCES/GOLDEN/101_BEAM_B4_LE/STATIC',
     &  2.0E-6_R8, 5.0E-6_R8, 3.0E-2_R8)
      CALL STATIC_CASE('GOLDEN_PLATE_101',                               ! Call static case with 'GOLDEN_PLATE_101', trim(root)//'/REFERENCES/BASELINE_INPUTS/101_PLATE_Q9_LE', trim(r...
     &  TRIM(ROOT)//'/REFERENCES/BASELINE_INPUTS/101_PLATE_Q9_LE',
     &  TRIM(ROOT)//'/REFERENCES/GOLDEN/101_PLATE_Q9_LE/STATIC',
     &  2.0E-7_R8, 2.0E-7_R8, 2.0E-7_R8)
      CALL MODAL_CASE('GOLDEN_BEAM_103',                                 ! Call modal case with 'GOLDEN_BEAM_103', trim(root)//'/REFERENCES/BASELINE_INPUTS/'// '103_BEAM_B4_LE_DERIVE...
     &  TRIM(ROOT)//'/REFERENCES/BASELINE_INPUTS/'//
     &  '103_BEAM_B4_LE_DERIVED',
     &  TRIM(ROOT)//'/REFERENCES/GOLDEN/103_BEAM_B4_LE_DERIVED/'//
     &  'DYNAMIC', 20_I4, 1.0E-7_R8)

!     CASES GENERATED WITH THE FROZEN BASELINE.
      CALL GENERATED_STATIC('mixed_none', 2.0E-6_R8)                     ! Call generated static with 'mixed_none', 2.0e-6.
      CALL GENERATED_STATIC('mixed_mitc', 2.0E-6_R8)                     ! Call generated static with 'mixed_mitc', 2.0e-6.
      CALL GENERATED_STATIC('beam_b3_te2_mitc', 2.0E-6_R8)               ! Call generated static with 'beam_b3_te2_mitc', 2.0e-6.
      CALL GENERATED_STATIC('plate_q4_mitc', 2.0E-6_R8)                  ! Call generated static with 'plate_q4_mitc', 2.0e-6.
!     TAYLOR ORDER 8: THE EXPANSION RULE MUST HAVE 9 POINTS PER AXIS.
      CALL GENERATED_STATIC('beam_te8_unit', 2.0E-6_R8)                  ! Call generated static with 'beam_te8_unit', 2.0e-6.
      CALL GENERATED_STATIC('plate_q9x4_mitc', 4.0E-6_R8)                ! Call generated static with 'plate_q9x4_mitc', 4.0e-6.
      CALL GENERATED_STATIC('solid_h8_none', 1.0E-9_R8)                  ! Call generated static with 'solid_h8_none', 1.0e-9.
      CALL GENERATED_MODAL('modal_plate_q9x4_mitc', 12_I4, 2.0E-5_R8)    ! Call generated modal with 'modal_plate_q9x4_mitc', 12, 2.0e-5.
      CALL GENERATED_MODAL('modal_beam_b3_te2', 10_I4, 2.0E-5_R8)        ! Call generated modal with 'modal_beam_b3_te2', 10, 2.0e-5.
!     REDUCED AND SELECTIVE INTEGRATION AGAINST THE BASELINE (REDI, SELI).
      CALL GENERATED_STATIC('beam_b3_te2_redi', 4.0E-6_R8)               ! Call generated static with 'beam_b3_te2_redi', 4.0e-6.
      CALL GENERATED_STATIC('beam_b3_te2_seli', 4.0E-6_R8)               ! Call generated static with 'beam_b3_te2_seli', 4.0e-6.
!     THE BASELINE POST-PROCESSING OF PLATE SHEAR STRAINS IS WRONG
!     FOR REDI/SELI AS FOR NONE: ONLY THE DISPLACEMENTS ARE COMPARED.
      CALL STATIC_CASE('plate_q9x4_redi',                                ! Call static case with 'plate_q9x4_redi', trim(root)//'/TESTS/CASES/plate_q9x4_redi/INPUT', trim(root)//'/TE...
     &     TRIM(ROOT)//'/TESTS/CASES/plate_q9x4_redi/INPUT',
     &     TRIM(ROOT)//'/TESTS/CASES/plate_q9x4_redi/REFERENCE',
     &     4.0E-6_R8, 4.0E-6_R8, 1.0E30_R8)
!     THE BASELINE POST-PROCESSING OF PLATE SHEAR STRAINS IS WRONG
!     FOR REDI/SELI AS FOR NONE: ONLY THE DISPLACEMENTS ARE COMPARED.
      CALL STATIC_CASE('plate_q9x4_seli',                                ! Call static case with 'plate_q9x4_seli', trim(root)//'/TESTS/CASES/plate_q9x4_seli/INPUT', trim(root)//'/TE...
     &     TRIM(ROOT)//'/TESTS/CASES/plate_q9x4_seli/INPUT',
     &     TRIM(ROOT)//'/TESTS/CASES/plate_q9x4_seli/REFERENCE',
     &     4.0E-6_R8, 4.0E-6_R8, 1.0E30_R8)
      CALL GENERATED_MODAL('modal_beam_b3_te2_redi', 10_I4, 2.0E-5_R8)   ! Call generated modal with 'modal_beam_b3_te2_redi', 10, 2.0e-5.
      CALL GENERATED_MODAL('modal_beam_b3_te2_seli', 10_I4, 2.0E-5_R8)   ! Call generated modal with 'modal_beam_b3_te2_seli', 10, 2.0e-5.
      CALL GENERATED_MODAL('modal_plate_q9x4_redi', 12_I4, 2.0E-5_R8)    ! Call generated modal with 'modal_plate_q9x4_redi', 12, 2.0e-5.
      CALL GENERATED_MODAL('modal_plate_q9x4_seli', 12_I4, 2.0E-5_R8)    ! Call generated modal with 'modal_plate_q9x4_seli', 12, 2.0e-5.

!     PATCH TESTS: UNIFORM STRAIN 1E-3, NU = 0.
      CALL PATCH_CASE('patch_beam_b4_le_none', 2_I4, 2.1E8_R8,           ! Call patch case with 'patch_beam_b4_le_none', 2, 2.1e8, 7.3e7.
     &                7.3E7_R8)
      CALL PATCH_CASE('patch_beam_b4_le_mitc', 2_I4, 2.1E8_R8,           ! Call patch case with 'patch_beam_b4_le_mitc', 2, 2.1e8, 7.3e7.
     &                7.3E7_R8)
      CALL PATCH_CASE('patch_plate_q9_none', 2_I4, 7.3E7_R8, 7.3E7_R8)   ! Call patch case with 'patch_plate_q9_none', 2, 7.3e7, 7.3e7.
      CALL PATCH_CASE('patch_plate_q9_mitc', 2_I4, 7.3E7_R8, 7.3E7_R8)   ! Call patch case with 'patch_plate_q9_mitc', 2, 7.3e7, 7.3e7.
      CALL PATCH_CASE('patch_solid_h8_none', 3_I4, 7.3E7_R8, 7.3E7_R8)   ! Call patch case with 'patch_solid_h8_none', 3, 7.3e7, 7.3e7.

!     THE RESULT MUST NOT DEPEND ON THE NUMBER OF THREADS.
      CALL THREAD_CASE('mixed_mitc')                                     ! Call thread case with 'mixed_mitc'.
      CALL THREAD_CASE('beam_b3_te2_mitc')                               ! Call thread case with 'beam_b3_te2_mitc'.

      IF (FAILURES .GT. 0) THEN                                          ! If failures > 0:
        WRITE(*,'(A,I0,A)') 'TESTS FAILED: ', FAILURES, ' CHECKS'        ! Print: 'TESTS FAILED: ', failures, ' CHECKS'.
        STOP 1                                                           ! Stop the program.
      END IF                                                             ! End of the IF block.
      WRITE(*,'(A)') 'ALL ANALYSIS TESTS PASSED'                         ! Print: 'ALL ANALYSIS TESTS PASSED'.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE CHECK(CONDITION, MESSAGE)                               ! Subroutine check takes condition, message.

      LOGICAL, INTENT(IN) :: CONDITION                                   ! Input logical: condition.
      CHARACTER(LEN=*), INTENT(IN) :: MESSAGE                            ! Input character (length *): message.

      IF (.NOT. CONDITION) THEN                                          ! If not condition:
        WRITE(*,'(A,A)') 'FAIL: ', MESSAGE                               ! Print: 'FAIL: ', message.
        FAILURES = FAILURES + 1                                          ! Add 1 to failures.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE CHECK                                               ! End of the subroutine check.

      SUBROUTINE CHECK_CLOSE(LABEL, ERROR, TOLERANCE)                    ! Subroutine check close takes label, error, tolerance.

      CHARACTER(LEN=*), INTENT(IN) :: LABEL                              ! Input character (length *): label.
      REAL(R8), INTENT(IN) :: ERROR                                      ! Input real (real64): error.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.
      CHARACTER(LEN=160) :: TEXT                                         ! Character (length 160): text.

      WRITE(TEXT,'(A,A,ES10.3,A,ES9.2)') TRIM(LABEL), ': ERROR ',        ! Format into the text text: trim(label), ': ERROR ', error, ' > TOLERANCE ', tolerance.
     &  ERROR, ' > TOLERANCE ', TOLERANCE
      CALL CHECK(ERROR .LE. TOLERANCE, TRIM(TEXT))                       ! Call check with error <= tolerance, trim(text).

      END SUBROUTINE CHECK_CLOSE                                         ! End of the subroutine check close.

      SUBROUTINE RUN_CASE(NAME, INPUT, RUN, THREADS, OK)                 ! Subroutine run case takes name, input, run, threads, ok.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      CHARACTER(LEN=*), INTENT(IN) :: INPUT                              ! Input character (length *): input.
      CHARACTER(LEN=*), INTENT(OUT) :: RUN                               ! Output character (length *): run.
      INTEGER(I4), INTENT(IN) :: THREADS                                 ! Input integer (int32): threads.
      LOGICAL, INTENT(OUT) :: OK                                         ! Output logical: ok.

      RUN = TRIM(RUNS)//'/'//TRIM(NAME)                                  ! Set run to trim(runs)//'/'//trim(name).
      CALL RUN_SOLVER(TRIM(EXE), TRIM(INPUT), TRIM(RUN), THREADS, OK)    ! Call run solver with trim(exe), trim(input), trim(run), threads, ok.
      CALL CHECK(OK, TRIM(NAME)//': THE SOLVER RUN FAILED')              ! Call check with ok, trim(name)//': THE SOLVER RUN FAILED'.

      END SUBROUTINE RUN_CASE                                            ! End of the subroutine run case.

!  POINT FILE: ID, XEVAL(3), XREQ(3), LAM, ELE, SELE, U(3), EPS LOC(6),
!  EPS GLB(6), SIG LOC(6), SIG GLB(6), ... . COLUMNS 11-13 ARE U.
      SUBROUTINE COMPARE_POINTS(NAME, NEW_FILE, OLD_FILE, TOL_U,         ! Subroutine compare points takes name, new file, old file, tol u, tol sigma, tol shear.
     &                          TOL_SIGMA, TOL_SHEAR)

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      CHARACTER(LEN=*), INTENT(IN) :: NEW_FILE                           ! Input character (length *): new_file.
      CHARACTER(LEN=*), INTENT(IN) :: OLD_FILE                           ! Input character (length *): old_file.
      REAL(R8), INTENT(IN) :: TOL_U                                      ! Input real (real64): tol_u.
      REAL(R8), INTENT(IN) :: TOL_SIGMA                                  ! Input real (real64): tol_sigma.
      REAL(R8), INTENT(IN) :: TOL_SHEAR                                  ! Input real (real64): tol_shear.
      REAL(R8) :: NEW(46,16)                                             ! Real (real64): new(46,16).
      REAL(R8) :: OLD(46,16)                                             ! Real (real64): old(46,16).
      INTEGER(I4) :: N_NEW                                               ! Integer (int32): n_new.
      INTEGER(I4) :: N_OLD                                               ! Integer (int32): n_old.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      LOGICAL :: OK_NEW                                                  ! Logical: ok_new.
      LOGICAL :: OK_OLD                                                  ! Logical: ok_old.

      CALL READ_POINT_ROWS(NEW_FILE, NEW, N_NEW, OK_NEW)                 ! Call read point rows with new_file, new, n_new, ok_new.
      CALL READ_POINT_ROWS(OLD_FILE, OLD, N_OLD, OK_OLD)                 ! Call read point rows with old_file, old, n_old, ok_old.
      CALL CHECK(OK_NEW .AND. OK_OLD .AND. N_NEW .EQ. N_OLD,             ! Call check with ok_new and ok_old and n_new = n_old, trim(name)//': POST_POINT FILES ARE UNREADABLE'.
     &           TRIM(NAME)//': POST_POINT FILES ARE UNREADABLE')
      IF (.NOT. (OK_NEW .AND. OK_OLD .AND. N_NEW .EQ. N_OLD)) RETURN     ! If not (ok_new and ok_old and n_new = n_old), return to the caller.
!     DISPLACEMENTS, THEN NORMAL/SHEAR COMPONENTS OF STRESS (GLOBAL).
      DO I = 1_I4, N_NEW                                                 ! Loop i from 1 to n_new:
!       THE BASELINE LOCATES POINTS APPROXIMATELY (X_EVAL /= X_REQ BY
!       1E-7 OR MORE): POINT RESULTS HAVE A LOOSER TOLERANCE.
        CALL CHECK_CLOSE(TRIM(NAME)//' POINT U',                         ! Call check close with trim(name)//' POINT U', max_relative_difference(new(11:13,i),old(11:13,i)), max(tol_u...
     &       MAX_RELATIVE_DIFFERENCE(NEW(11:13,I),OLD(11:13,I)),
     &       MAX(TOL_U,POINT_TOLERANCE))
        CALL CHECK_CLOSE(TRIM(NAME)//' POINT SIGMA',                     ! Call check close with trim(name)//' POINT SIGMA', max_relative_difference(new(32:34,i),old(32:34,i)), max(t...
     &       MAX_RELATIVE_DIFFERENCE(NEW(32:34,I),OLD(32:34,I)),
     &       MAX(TOL_SIGMA,POINT_TOLERANCE))
        CALL CHECK_CLOSE(TRIM(NAME)//' POINT SHEAR',                     ! Call check close with trim(name)//' POINT SHEAR', maxval(abs(new(35:37,i)-old(35:37,i)))/ max(maxval(abs(ol...
     &       MAXVAL(ABS(NEW(35:37,I)-OLD(35:37,I)))/
     &       MAX(MAXVAL(ABS(OLD(32:34,I))),TINY(1.0_R8)),
     &       MAX(TOL_SHEAR,TOL_SIGMA,POINT_TOLERANCE))
      END DO                                                             ! End of the loop.

      END SUBROUTINE COMPARE_POINTS                                      ! End of the subroutine compare points.

      SUBROUTINE COMPARE_VTK_FIELDS(NAME, NEW_FILE, OLD_FILE, TOL_U,     ! Subroutine compare vtk fields takes name, new file, old file, tol u, tol sigma.
     &                              TOL_SIGMA)

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      CHARACTER(LEN=*), INTENT(IN) :: NEW_FILE                           ! Input character (length *): new_file.
      CHARACTER(LEN=*), INTENT(IN) :: OLD_FILE                           ! Input character (length *): old_file.
      REAL(R8), INTENT(IN) :: TOL_U                                      ! Input real (real64): tol_u.
      REAL(R8), INTENT(IN) :: TOL_SIGMA                                  ! Input real (real64): tol_sigma.
      CHARACTER(LEN=12), PARAMETER :: SCALAR_NAME(4) =                   ! Constant character (length 12): scalar_name(4) = ['Sigma_XX ', 'Sigma_YY ', 'Sigma_ZZ ', 'Epsilon_XX '].
     &  ['Sigma_XX    ','Sigma_YY    ','Sigma_ZZ    ','Epsilon_XX  ']
      REAL(R8), ALLOCATABLE :: NEW(:,:)                                  ! Allocatable real (real64): new(:,:).
      REAL(R8), ALLOCATABLE :: OLD(:,:)                                  ! Allocatable real (real64): old(:,:).
      INTEGER(I4) :: N_NEW                                               ! Integer (int32): n_new.
      INTEGER(I4) :: N_OLD                                               ! Integer (int32): n_old.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      LOGICAL :: OK_NEW                                                  ! Logical: ok_new.
      LOGICAL :: OK_OLD                                                  ! Logical: ok_old.

      CALL READ_VTK_BLOCK(NEW_FILE, 'Displacements', 3_I4, NEW, N_NEW,   ! Call read vtk block with new_file, 'Displacements', 3, new, n_new, ok_new.
     &                    OK_NEW)
      CALL READ_VTK_BLOCK(OLD_FILE, 'Displacements', 3_I4, OLD, N_OLD,   ! Call read vtk block with old_file, 'Displacements', 3, old, n_old, ok_old.
     &                    OK_OLD)
      CALL CHECK(OK_NEW .AND. OK_OLD .AND. N_NEW .EQ. N_OLD,             ! Call check with ok_new and ok_old and n_new = n_old, trim(name)//': DISPLACEMENT FIELD IS UNREADABLE'.
     &           TRIM(NAME)//': DISPLACEMENT FIELD IS UNREADABLE')
      IF (OK_NEW .AND. OK_OLD .AND. N_NEW .EQ. N_OLD) THEN               ! If ok_new and ok_old and n_new = n_old:
        CALL CHECK_CLOSE(TRIM(NAME)//' VTK DISPLACEMENT',                ! Call check close with trim(name)//' VTK DISPLACEMENT', max_relative_difference(reshape(new,[3*n_new]), resh...
     &       MAX_RELATIVE_DIFFERENCE(RESHAPE(NEW,[3*N_NEW]),
     &       RESHAPE(OLD,[3*N_OLD])), TOL_U)
      END IF                                                             ! End of the IF block.
      DO I = 1_I4, 4_I4                                                  ! Loop i from 1 to 4:
        IF (ALLOCATED(NEW)) DEALLOCATE(NEW)                              ! If allocated(new), free the memory of new.
        IF (ALLOCATED(OLD)) DEALLOCATE(OLD)                              ! If allocated(old), free the memory of old.
        CALL READ_VTK_BLOCK(NEW_FILE, TRIM(SCALAR_NAME(I)), 1_I4, NEW,   ! Call read vtk block with new_file, trim(scalar_name(i)), 1, new, n_new, ok_new.
     &                      N_NEW, OK_NEW)
        CALL READ_VTK_BLOCK(OLD_FILE, TRIM(SCALAR_NAME(I)), 1_I4, OLD,   ! Call read vtk block with old_file, trim(scalar_name(i)), 1, old, n_old, ok_old.
     &                      N_OLD, OK_OLD)
        CALL CHECK(OK_NEW .AND. OK_OLD .AND. N_NEW .EQ. N_OLD,           ! Call check with ok_new and ok_old and n_new = n_old, trim(name)//': '//trim(scalar_name(i))// ' IS UNREADAB...
     &             TRIM(NAME)//': '//TRIM(SCALAR_NAME(I))//
     &             ' IS UNREADABLE')
        IF (OK_NEW .AND. OK_OLD .AND. N_NEW .EQ. N_OLD) THEN             ! If ok_new and ok_old and n_new = n_old:
          CALL CHECK_CLOSE(TRIM(NAME)//' VTK '//                         ! Call check close with trim(name)//' VTK '// trim(scalar_name(i)), max_relative_difference(new(1,:),old(1,:)...
     &         TRIM(SCALAR_NAME(I)),
     &         MAX_RELATIVE_DIFFERENCE(NEW(1,:),OLD(1,:)), TOL_SIGMA)
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END SUBROUTINE COMPARE_VTK_FIELDS                                  ! End of the subroutine compare vtk fields.

      SUBROUTINE STATIC_CASE(NAME, INPUT, REFERENCE, TOL_U, TOL_SIGMA,   ! Subroutine static case takes name, input, reference, tol u, tol sigma, tol shear.
     &                       TOL_SHEAR)

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      CHARACTER(LEN=*), INTENT(IN) :: INPUT                              ! Input character (length *): input.
      CHARACTER(LEN=*), INTENT(IN) :: REFERENCE                          ! Input character (length *): reference.
      REAL(R8), INTENT(IN) :: TOL_U                                      ! Input real (real64): tol_u.
      REAL(R8), INTENT(IN) :: TOL_SIGMA                                  ! Input real (real64): tol_sigma.
      REAL(R8), INTENT(IN) :: TOL_SHEAR                                  ! Input real (real64): tol_shear.
      CHARACTER(LEN=512) :: RUN                                          ! Character (length 512): run.
      LOGICAL :: OK                                                      ! Logical: ok.

      CALL RUN_CASE(NAME, INPUT, RUN, 0_I4, OK)                          ! Call run case with name, input, run, 0, ok.
      IF (.NOT. OK) RETURN                                               ! If not ok, return to the caller.
      CALL COMPARE_POINTS(NAME, TRIM(RUN)//'/STATIC/POST_POINT.dat',     ! Call compare points with name, trim(run)//'/STATIC/POST_POINT.dat', trim(reference)//'/POST_POINT.dat', tol...
     &     TRIM(REFERENCE)//'/POST_POINT.dat', TOL_U, TOL_SIGMA,
     &     TOL_SHEAR)
      CALL COMPARE_VTK_FIELDS(NAME,                                      ! Call compare vtk fields with name, trim(run)//'/STATIC/RESULTS_PARA_01.vtk', trim(reference)//'/RESULTS_PAR...
     &     TRIM(RUN)//'/STATIC/RESULTS_PARA_01.vtk',
     &     TRIM(REFERENCE)//'/RESULTS_PARA_01.vtk', TOL_U, TOL_SIGMA)

      END SUBROUTINE STATIC_CASE                                         ! End of the subroutine static case.

      SUBROUTINE GENERATED_STATIC(NAME, TOLERANCE)                       ! Subroutine generated static takes name, tolerance.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      REAL(R8), INTENT(IN) :: TOLERANCE                                  ! Input real (real64): tolerance.

      CALL STATIC_CASE(NAME,                                             ! Call static case with name, trim(root)//'/TESTS/CASES/'//name//'/INPUT', trim(root)//'/TESTS/CASES/'//name/...
     &     TRIM(ROOT)//'/TESTS/CASES/'//NAME//'/INPUT',
     &     TRIM(ROOT)//'/TESTS/CASES/'//NAME//'/REFERENCE',
     &     TOLERANCE, TOLERANCE, TOLERANCE)

      END SUBROUTINE GENERATED_STATIC                                    ! End of the subroutine generated static.

!  FREQUENCIES AND MODE SHAPES (MAC) AGAINST A REFERENCE.
      SUBROUTINE MODAL_CASE(NAME, INPUT, REFERENCE, MODES, TOL_FREQ)     ! Subroutine modal case takes name, input, reference, modes, tol freq.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      CHARACTER(LEN=*), INTENT(IN) :: INPUT                              ! Input character (length *): input.
      CHARACTER(LEN=*), INTENT(IN) :: REFERENCE                          ! Input character (length *): reference.
      INTEGER(I4), INTENT(IN) :: MODES                                   ! Input integer (int32): modes.
      REAL(R8), INTENT(IN) :: TOL_FREQ                                   ! Input real (real64): tol_freq.
      CHARACTER(LEN=512) :: RUN                                          ! Character (length 512): run.
      CHARACTER(LEN=16) :: MODE_NAME                                     ! Character (length 16): mode_name.
      REAL(R8) :: NEW(128)                                               ! Real (real64): new(128).
      REAL(R8) :: OLD(128)                                               ! Real (real64): old(128).
      REAL(R8), ALLOCATABLE :: A(:,:)                                    ! Allocatable real (real64): a(:,:).
      REAL(R8), ALLOCATABLE :: B(:,:)                                    ! Allocatable real (real64): b(:,:).
      REAL(R8) :: MAC                                                    ! Real (real64): mac.
      REAL(R8) :: WORST                                                  ! Real (real64): worst.
      INTEGER(I4) :: N_NEW                                               ! Integer (int32): n_new.
      INTEGER(I4) :: N_OLD                                               ! Integer (int32): n_old.
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: M                                                   ! Integer (int32): m.
      LOGICAL :: OK                                                      ! Logical: ok.
      LOGICAL :: OK_A                                                    ! Logical: ok_a.
      LOGICAL :: OK_B                                                    ! Logical: ok_b.

      CALL RUN_CASE(NAME, INPUT, RUN, 0_I4, OK)                          ! Call run case with name, input, run, 0, ok.
      IF (.NOT. OK) RETURN                                               ! If not ok, return to the caller.
      CALL READ_FREQUENCIES(TRIM(RUN)//'/DYNAMIC/FREQUENCIES.dat', NEW,  ! Call read frequencies with trim(run)//'/DYNAMIC/FREQUENCIES.dat', new, n_new, ok_a.
     &                      N_NEW, OK_A)
      CALL READ_FREQUENCIES(TRIM(REFERENCE)//'/FREQUENCIES.dat', OLD,    ! Call read frequencies with trim(reference)//'/FREQUENCIES.dat', old, n_old, ok_b.
     &                      N_OLD, OK_B)
      CALL CHECK(OK_A .AND. OK_B .AND. N_NEW .EQ. MODES .AND.            ! Call check with ok_a and ok_b and n_new = modes and n_old = modes, trim(name)//': FREQUENCY FILES ARE INCON...
     &           N_OLD .EQ. MODES,
     &           TRIM(NAME)//': FREQUENCY FILES ARE INCONSISTENT')
      IF (.NOT. (OK_A .AND. OK_B .AND. N_NEW .EQ. MODES .AND.            ! If not (ok_a and ok_b and n_new = modes and n_old = modes), return to the caller.
     &    N_OLD .EQ. MODES)) RETURN
      CALL CHECK_CLOSE(TRIM(NAME)//' FREQUENCY',                         ! Call check close with trim(name)//' FREQUENCY', max_relative_difference(new(1:modes),old(1:modes)), tol_freq.
     &     MAX_RELATIVE_DIFFERENCE(NEW(1:MODES),OLD(1:MODES)),
     &     TOL_FREQ)

      WORST = 0.0_R8                                                     ! Set worst to zero.
      DO M = 1_I4, MODES                                                 ! Loop m from 1 to modes:
        WRITE(MODE_NAME,'(A,I3.3)') 'Mode:', M                           ! Write to unit mode_name: 'Mode:', m.
        CALL READ_VTK_BLOCK(TRIM(RUN)//'/DYNAMIC/RESULTS_DYN_PARA.vtk',  ! Call read vtk block with trim(run)//'/DYNAMIC/RESULTS_DYN_PARA.vtk', trim(mode_name), 3, a, n, ok_a.
     &       TRIM(MODE_NAME), 3_I4, A, N, OK_A)
        CALL READ_VTK_BLOCK(TRIM(REFERENCE)//'/RESULTS_DYN_PARA.vtk',    ! Call read vtk block with trim(reference)//'/RESULTS_DYN_PARA.vtk', trim(mode_name), 3, b, n, ok_b.
     &       TRIM(MODE_NAME), 3_I4, B, N, OK_B)
        IF (.NOT. (OK_A .AND. OK_B)) THEN                                ! If not (ok_a and ok_b):
          CALL CHECK(.FALSE., TRIM(NAME)//': MODE FIELD IS UNREADABLE')  ! Call check with false, trim(name)//': MODE FIELD IS UNREADABLE'.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        MAC = DOT_PRODUCT(RESHAPE(A,[3*N]),RESHAPE(B,[3*N]))**2/         ! Set mac to dot_product(reshape(a,[3*n]),reshape(b,[3*n]))**2/ (dot_product(reshape(a,[3*n]),reshape(a,[3*n]...
     &        (DOT_PRODUCT(RESHAPE(A,[3*N]),RESHAPE(A,[3*N]))*
     &         DOT_PRODUCT(RESHAPE(B,[3*N]),RESHAPE(B,[3*N])))
        WORST = MAX(WORST,1.0_R8-MAC)                                    ! Set worst to the larger of worst and 1.0-mac.
        DEALLOCATE(A, B)                                                 ! Free the memory of a, b.
      END DO                                                             ! End of the loop.
      CALL CHECK_CLOSE(TRIM(NAME)//' MODE SHAPE (1-MAC)', WORST,         ! Call check close with trim(name)//' MODE SHAPE (1-MAC)', worst, 1.0e-6.
     &                 1.0E-6_R8)

      END SUBROUTINE MODAL_CASE                                          ! End of the subroutine modal case.

      SUBROUTINE GENERATED_MODAL(NAME, MODES, TOL_FREQ)                  ! Subroutine generated modal takes name, modes, tol freq.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      INTEGER(I4), INTENT(IN) :: MODES                                   ! Input integer (int32): modes.
      REAL(R8), INTENT(IN) :: TOL_FREQ                                   ! Input real (real64): tol_freq.

      CALL MODAL_CASE(NAME,                                              ! Call modal case with name, trim(root)//'/TESTS/CASES/'//name//'/INPUT', trim(root)//'/TESTS/CASES/'//name//...
     &     TRIM(ROOT)//'/TESTS/CASES/'//NAME//'/INPUT',
     &     TRIM(ROOT)//'/TESTS/CASES/'//NAME//'/REFERENCE', MODES,
     &     TOL_FREQ)

      END SUBROUTINE GENERATED_MODAL                                     ! End of the subroutine generated modal.

!  UNIFORM-STRAIN PATCH TEST. THE DOMINANT STRESS COMPONENT OF THE
!  GLOBAL FRAME IS SIGMA_D, EVERY OTHER COMPONENT MUST VANISH (NU=0).
!  DIRECTION = 2 (Y, BEAM AND PLATE) OR 3 (Z, SOLID). THE FIRST POINT
!  LIES IN THE LAYER WITH MODULUS SIGMA_1/1E-3, THE SECOND IN SIGMA_2.
      SUBROUTINE PATCH_CASE(NAME, DIRECTION, SIGMA_1, SIGMA_2)           ! Subroutine patch case takes name, direction, sigma 1, sigma 2.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      INTEGER(I4), INTENT(IN) :: DIRECTION                               ! Input integer (int32): direction.
      REAL(R8), INTENT(IN) :: SIGMA_1                                    ! Input real (real64): sigma_1.
      REAL(R8), INTENT(IN) :: SIGMA_2                                    ! Input real (real64): sigma_2.
      CHARACTER(LEN=512) :: RUN                                          ! Character (length 512): run.
      REAL(R8) :: ROWS(46,16)                                            ! Real (real64): rows(46,16).
      REAL(R8) :: SIGMA(6)                                               ! Real (real64): sigma(6).
      REAL(R8) :: STRAIN(6)                                              ! Real (real64): strain(6).
      REAL(R8) :: EXPECTED                                               ! Real (real64): expected.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: MAP(3)                                              ! Integer (int32): map(3).
      LOGICAL :: OK                                                      ! Logical: ok.

      CALL RUN_CASE(NAME, TRIM(ROOT)//'/TESTS/CASES/'//NAME//'/INPUT',   ! Call run case with name, trim(root)//'/TESTS/CASES/'//name//'/INPUT', run, 0, ok.
     &              RUN, 0_I4, OK)
      IF (.NOT. OK) RETURN                                               ! If not ok, return to the caller.
      CALL READ_POINT_ROWS(TRIM(RUN)//'/STATIC/POST_POINT.dat', ROWS,    ! Call read point rows with trim(run)//'/STATIC/POST_POINT.dat', rows, count, ok.
     &                     COUNT, OK)
      CALL CHECK(OK .AND. COUNT .EQ. 2_I4,                               ! Call check with ok and count = 2, trim(name)//': POST_POINT.dat IS UNREADABLE'.
     &           TRIM(NAME)//': POST_POINT.dat IS UNREADABLE')
      IF (.NOT. (OK .AND. COUNT .EQ. 2_I4)) RETURN                       ! If not (ok and count = 2), return to the caller.
!     GLOBAL STRESS/STRAIN ORDER: XX, YY, ZZ, XZ, YZ, XY.
      MAP = [1_I4,2_I4,3_I4]                                             ! Set map to [1,2,3].
      DO I = 1_I4, 2_I4                                                  ! Loop i from 1 to 2:
        STRAIN = ROWS(20:25,I)                                           ! Set strain to rows(20:25,i).
        SIGMA = ROWS(32:37,I)                                            ! Set sigma to rows(32:37,i).
        EXPECTED = SIGMA_1                                               ! Set expected to sigma_1.
        IF (I .EQ. 2_I4) EXPECTED = SIGMA_2                              ! If i = 2, set expected to sigma_2.
        CALL CHECK_CLOSE(TRIM(NAME)//' UNIFORM STRAIN',                  ! Call check close with trim(name)//' UNIFORM STRAIN', abs(strain(direction)-1.0e-3)/1.0e-3, 1.0e-9.
     &       ABS(STRAIN(DIRECTION)-1.0E-3_R8)/1.0E-3_R8, 1.0E-9_R8)
        CALL CHECK_CLOSE(TRIM(NAME)//' UNIFORM STRESS',                  ! Call check close with trim(name)//' UNIFORM STRESS', abs(sigma(direction)-expected)/expected, 1.0e-9.
     &       ABS(SIGMA(DIRECTION)-EXPECTED)/EXPECTED, 1.0E-9_R8)
        DO K = 1_I4, 6_I4                                                ! Loop k from 1 to 6:
          IF (K .EQ. DIRECTION) CYCLE                                    ! If k = direction, skip to the next iteration.
          CALL CHECK_CLOSE(TRIM(NAME)//' OTHER STRESS',                  ! Call check close with trim(name)//' OTHER STRESS', abs(sigma(k))/expected, 1.0e-9.
     &         ABS(SIGMA(K))/EXPECTED, 1.0E-9_R8)
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE PATCH_CASE                                          ! End of the subroutine patch case.

      SUBROUTINE THREAD_CASE(NAME)                                       ! Subroutine thread case takes name.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      CHARACTER(LEN=512) :: RUN_1                                        ! Character (length 512): run_1.
      CHARACTER(LEN=512) :: RUN_4                                        ! Character (length 512): run_4.
      CHARACTER(LEN=512) :: INPUT                                        ! Character (length 512): input.
      LOGICAL :: OK_1                                                    ! Logical: ok_1.
      LOGICAL :: OK_4                                                    ! Logical: ok_4.

      INPUT = TRIM(ROOT)//'/TESTS/CASES/'//NAME//'/INPUT'                ! Set input to trim(root)//'/TESTS/CASES/'//name//'/INPUT'.
      CALL RUN_CASE(NAME//'_T1', INPUT, RUN_1, 1_I4, OK_1)               ! Call run case with name//'_T1', input, run_1, 1, ok_1.
      CALL RUN_CASE(NAME//'_T4', INPUT, RUN_4, 4_I4, OK_4)               ! Call run case with name//'_T4', input, run_4, 4, ok_4.
      IF (.NOT. (OK_1 .AND. OK_4)) RETURN                                ! If not (ok_1 and ok_4), return to the caller.
      CALL CHECK(FILES_ARE_IDENTICAL(                                    ! Call check with files_are_identical( trim(run_1)//'/STATIC/POST_POINT.dat', trim(run_4)//'/STATIC/POST_POIN...
     &     TRIM(RUN_1)//'/STATIC/POST_POINT.dat',
     &     TRIM(RUN_4)//'/STATIC/POST_POINT.dat'),
     &     TRIM(NAME)//': POINT RESULTS DEPEND ON THE THREAD COUNT')
      CALL CHECK(FILES_ARE_IDENTICAL(                                    ! Call check with files_are_identical( trim(run_1)//'/STATIC/RESULTS_PARA_01.vtk', trim(run_4)//'/STATIC/RESU...
     &     TRIM(RUN_1)//'/STATIC/RESULTS_PARA_01.vtk',
     &     TRIM(RUN_4)//'/STATIC/RESULTS_PARA_01.vtk'),
     &     TRIM(NAME)//': FIELD RESULTS DEPEND ON THE THREAD COUNT')

      END SUBROUTINE THREAD_CASE                                         ! End of the subroutine thread case.

      END PROGRAM MUL2_ANALYSIS_TESTS                                    ! End of the program mul2 analysis tests.
