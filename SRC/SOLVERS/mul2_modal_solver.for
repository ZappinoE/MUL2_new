!=======================================================================
!  GENERALIZED SYMMETRIC EIGENPROBLEM  K X = LAMBDA M X.
!
!  ARPACK (DSAUPD/DSEUPD, MODE 3, BMAT = G) WITH SPECTRAL TRANSFORMATION
!  OP = INV(K - SIGMA*M)*M; THE LINEAR SYSTEMS ARE SOLVED WITH ONE
!  PARDISO FACTORIZATION. SMALL PROBLEMS (OR NEV NEAR N) USE DENSE
!  LAPACK DSYGV. THE K-SHIFT RESIDUAL IS RE-COMPUTED FROM THE MATRICES.
!
!  ARPACK IS BUILT WITH 64-BIT INTEGERS AND LOGICALS (ILP64 MKL).
!  EIGENVALUES ARE RETURNED IN ASCENDING ORDER, EIGENVECTORS ARE
!  M-ORTHONORMAL: X(I)**T M X(J) = DELTA(I,J).
!=======================================================================
      MODULE MUL2_MODAL_SOLVER                                           ! Module mul2 modal solver begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, set warning, status is ok.
     &                       SET_WARNING, STATUS_IS_OK
      USE MUL2_SPARSE_OPERATIONS, ONLY: SPARSE_MULTIPLY                  ! Use from module mul2 sparse operations: sparse multiply.
      USE MUL2_PARDISO_FACTOR, ONLY: PARDISO_FACTOR_TYPE,                ! Use from module mul2 pardiso factor: pardiso factor type, mtype symmetric positive, mtype symmetric indefin...
     &     MTYPE_SYMMETRIC_POSITIVE, MTYPE_SYMMETRIC_INDEFINITE,
     &     PARDISO_FACTORIZE, PARDISO_SOLVE, PARDISO_RELEASE

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I8), PARAMETER :: MAXIMUM_ITERATIONS = 500_I8              ! Constant integer (int64): maximum_iterations = 500.
      INTEGER(I4), PARAMETER :: DENSE_ORDER_LIMIT = 400_I4               ! Constant integer (int32): dense_order_limit = 400.

      TYPE, PUBLIC :: MODAL_INFO_TYPE                                    ! Definition of the derived type modal info type.
        CHARACTER(LEN=8) :: BACKEND = ' '                                ! Character (length 8): backend = ' '.
        INTEGER(I8) :: ORDER = 0_I8                                      ! Integer (int64): order = 0.
        INTEGER(I8) :: REQUESTED = 0_I8                                  ! Integer (int64): requested = 0.
        INTEGER(I8) :: CONVERGED = 0_I8                                  ! Integer (int64): converged = 0.
        INTEGER(I8) :: SUBSPACE = 0_I8                                   ! Integer (int64): subspace = 0.
        INTEGER(I8) :: ITERATIONS = 0_I8                                 ! Integer (int64): iterations = 0.
        INTEGER(I8) :: OPERATIONS = 0_I8                                 ! Integer (int64): operations = 0.
        REAL(R8) :: SIGMA = 0.0_R8                                       ! Real (real64): sigma = 0.0.
      END TYPE MODAL_INFO_TYPE                                           ! End of the type definition modal info type.

      PUBLIC :: SOLVE_MODAL_PROBLEM                                      ! Export: solve modal problem.
      PUBLIC :: SOLVE_BUCKLING_DENSE                                     ! Export: solve buckling dense.

      INTERFACE                                                          ! Declare a generic interface.
        SUBROUTINE DSAUPD(IDO, BMAT, N, WHICH, NEV, TOL, RESID, NCV,     ! Subroutine dsaupd takes ido, bmat, n, which, nev, tol, resid, ncv, v, ldv, iparam, ipntr, workd, workl, lwo...
     &                    V, LDV, IPARAM, IPNTR, WORKD, WORKL, LWORKL,
     &                    INFO)
        IMPORT I8, R8                                                    ! Import from the host: i8, r8.
        INTEGER(I8), INTENT(INOUT) :: IDO                                ! In/out integer (int64): ido.
        CHARACTER(LEN=1), INTENT(IN) :: BMAT                             ! Input character (length 1): bmat.
        INTEGER(I8), INTENT(IN) :: N                                     ! Input integer (int64): n.
        CHARACTER(LEN=2), INTENT(IN) :: WHICH                            ! Input character (length 2): which.
        INTEGER(I8), INTENT(IN) :: NEV                                   ! Input integer (int64): nev.
        REAL(R8), INTENT(INOUT) :: TOL                                   ! In/out real (real64): tol.
        REAL(R8), INTENT(INOUT) :: RESID(*)                              ! In/out real (real64): resid(*).
        INTEGER(I8), INTENT(IN) :: NCV                                   ! Input integer (int64): ncv.
        REAL(R8), INTENT(OUT) :: V(*)                                    ! Output real (real64): v(*).
        INTEGER(I8), INTENT(IN) :: LDV                                   ! Input integer (int64): ldv.
        INTEGER(I8), INTENT(INOUT) :: IPARAM(11)                         ! In/out integer (int64): iparam(11).
        INTEGER(I8), INTENT(INOUT) :: IPNTR(11)                          ! In/out integer (int64): ipntr(11).
        REAL(R8), INTENT(INOUT) :: WORKD(*)                              ! In/out real (real64): workd(*).
        REAL(R8), INTENT(INOUT) :: WORKL(*)                              ! In/out real (real64): workl(*).
        INTEGER(I8), INTENT(IN) :: LWORKL                                ! Input integer (int64): lworkl.
        INTEGER(I8), INTENT(INOUT) :: INFO                               ! In/out integer (int64): info.
        END SUBROUTINE DSAUPD                                            ! End of the subroutine dsaupd.

        SUBROUTINE DSEUPD(RVEC, HOWMNY, SELECT, D, Z, LDZ, SIGMA,        ! Subroutine dseupd takes rvec, howmny, select, d, z, ldz, sigma, bmat, n, which, nev, tol, resid, ncv, v, ld...
     &                    BMAT, N, WHICH, NEV, TOL, RESID, NCV, V,
     &                    LDV, IPARAM, IPNTR, WORKD, WORKL, LWORKL,
     &                    INFO)
        IMPORT I8, R8                                                    ! Import from the host: i8, r8.
        LOGICAL(I8), INTENT(IN) :: RVEC                                  ! Input logical (int64): rvec.
        CHARACTER(LEN=1), INTENT(IN) :: HOWMNY                           ! Input character (length 1): howmny.
        LOGICAL(I8), INTENT(INOUT) :: SELECT(*)                          ! In/out logical (int64): select(*).
        REAL(R8), INTENT(OUT) :: D(*)                                    ! Output real (real64): d(*).
        REAL(R8), INTENT(INOUT) :: Z(*)                                  ! In/out real (real64): z(*).
        INTEGER(I8), INTENT(IN) :: LDZ                                   ! Input integer (int64): ldz.
        REAL(R8), INTENT(IN) :: SIGMA                                    ! Input real (real64): sigma.
        CHARACTER(LEN=1), INTENT(IN) :: BMAT                             ! Input character (length 1): bmat.
        INTEGER(I8), INTENT(IN) :: N                                     ! Input integer (int64): n.
        CHARACTER(LEN=2), INTENT(IN) :: WHICH                            ! Input character (length 2): which.
        INTEGER(I8), INTENT(IN) :: NEV                                   ! Input integer (int64): nev.
        REAL(R8), INTENT(IN) :: TOL                                      ! Input real (real64): tol.
        REAL(R8), INTENT(INOUT) :: RESID(*)                              ! In/out real (real64): resid(*).
        INTEGER(I8), INTENT(IN) :: NCV                                   ! Input integer (int64): ncv.
        REAL(R8), INTENT(INOUT) :: V(*)                                  ! In/out real (real64): v(*).
        INTEGER(I8), INTENT(IN) :: LDV                                   ! Input integer (int64): ldv.
        INTEGER(I8), INTENT(INOUT) :: IPARAM(11)                         ! In/out integer (int64): iparam(11).
        INTEGER(I8), INTENT(INOUT) :: IPNTR(11)                          ! In/out integer (int64): ipntr(11).
        REAL(R8), INTENT(INOUT) :: WORKD(*)                              ! In/out real (real64): workd(*).
        REAL(R8), INTENT(INOUT) :: WORKL(*)                              ! In/out real (real64): workl(*).
        INTEGER(I8), INTENT(IN) :: LWORKL                                ! Input integer (int64): lworkl.
        INTEGER(I8), INTENT(INOUT) :: INFO                               ! In/out integer (int64): info.
        END SUBROUTINE DSEUPD                                            ! End of the subroutine dseupd.

        SUBROUTINE DSYGV(ITYPE, JOBZ, UPLO, N, A, LDA, B, LDB, W,        ! Subroutine dsygv takes itype, jobz, uplo, n, a, lda, b, ldb, w, work, lwork, info.
     &                   WORK, LWORK, INFO)
        IMPORT I8, R8                                                    ! Import from the host: i8, r8.
        INTEGER(I8), INTENT(IN) :: ITYPE                                 ! Input integer (int64): itype.
        CHARACTER(LEN=1), INTENT(IN) :: JOBZ                             ! Input character (length 1): jobz.
        CHARACTER(LEN=1), INTENT(IN) :: UPLO                             ! Input character (length 1): uplo.
        INTEGER(I8), INTENT(IN) :: N                                     ! Input integer (int64): n.
        REAL(R8), INTENT(INOUT) :: A(LDA,*)                              ! In/out real (real64): a(lda,*).
        INTEGER(I8), INTENT(IN) :: LDA                                   ! Input integer (int64): lda.
        REAL(R8), INTENT(INOUT) :: B(LDB,*)                              ! In/out real (real64): b(ldb,*).
        INTEGER(I8), INTENT(IN) :: LDB                                   ! Input integer (int64): ldb.
        REAL(R8), INTENT(OUT) :: W(*)                                    ! Output real (real64): w(*).
        REAL(R8), INTENT(INOUT) :: WORK(*)                               ! In/out real (real64): work(*).
        INTEGER(I8), INTENT(IN) :: LWORK                                 ! Input integer (int64): lwork.
        INTEGER(I8), INTENT(OUT) :: INFO                                 ! Output integer (int64): info.
        END SUBROUTINE DSYGV                                             ! End of the subroutine dsygv.

        SUBROUTINE DSYSV(UPLO, N, NRHS, A, LDA, IPIV, B, LDB, WORK,      ! Subroutine dsysv takes uplo, n, nrhs, a, lda, ipiv, b, ldb, work, lwork, info.
     &                   LWORK, INFO)
        IMPORT I8, R8                                                    ! Import from the host: i8, r8.
        CHARACTER(LEN=1), INTENT(IN) :: UPLO                             ! Input character (length 1): uplo.
        INTEGER(I8), INTENT(IN) :: N                                     ! Input integer (int64): n.
        INTEGER(I8), INTENT(IN) :: NRHS                                  ! Input integer (int64): nrhs.
        REAL(R8), INTENT(INOUT) :: A(LDA,*)                              ! In/out real (real64): a(lda,*).
        INTEGER(I8), INTENT(IN) :: LDA                                   ! Input integer (int64): lda.
        INTEGER(I8), INTENT(OUT) :: IPIV(*)                              ! Output integer (int64): ipiv(*).
        REAL(R8), INTENT(INOUT) :: B(LDB,*)                              ! In/out real (real64): b(ldb,*).
        INTEGER(I8), INTENT(IN) :: LDB                                   ! Input integer (int64): ldb.
        REAL(R8), INTENT(INOUT) :: WORK(*)                               ! In/out real (real64): work(*).
        INTEGER(I8), INTENT(IN) :: LWORK                                 ! Input integer (int64): lwork.
        INTEGER(I8), INTENT(OUT) :: INFO                                 ! Output integer (int64): info.
        END SUBROUTINE DSYSV                                             ! End of the subroutine dsysv.
      END INTERFACE                                                      ! End of the block.

      CONTAINS                                                           ! The procedures of the module follow.

!  SOLVE FOR THE NEV EIGENVALUES CLOSEST TO SIGMA.
!    ROW_POINTER/COLUMN_INDEX: FULL SYMMETRIC CSR SHARED BY K AND M.
!    EIGENVALUE(1:NEV) ASCENDING; VECTOR(:,I) M-ORTHONORMAL;
!    RESIDUAL(I) = ||K X - LAMBDA M X|| / ||K X||.
      SUBROUTINE SOLVE_MODAL_PROBLEM(ORDER, ROW_POINTER, COLUMN_INDEX,   ! Subroutine solve modal problem takes order, row pointer, column index, stiffness, mass, nev, sigma, eigenva...
     &     STIFFNESS, MASS, NEV, SIGMA, EIGENVALUE, VECTOR, RESIDUAL,
     &     INFO, STATUS)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: STIFFNESS(:)                               ! Input real (real64): stiffness(:).
      REAL(R8), INTENT(IN) :: MASS(:)                                    ! Input real (real64): mass(:).
      INTEGER(I4), INTENT(IN) :: NEV                                     ! Input integer (int32): nev.
      REAL(R8), INTENT(IN) :: SIGMA                                      ! Input real (real64): sigma.
      REAL(R8), INTENT(OUT) :: EIGENVALUE(:)                             ! Output real (real64): eigenvalue(:).
      REAL(R8), INTENT(OUT) :: VECTOR(:,:)                               ! Output real (real64): vector(:,:).
      REAL(R8), INTENT(OUT) :: RESIDUAL(:)                               ! Output real (real64): residual(:).
      TYPE(MODAL_INFO_TYPE), INTENT(OUT) :: INFO                         ! Output of type modal_info_type: info.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      INFO%ORDER = ORDER                                                 ! Set info.order to order.
      INFO%REQUESTED = NEV                                               ! Set info.requested to nev.
      INFO%SIGMA = SIGMA                                                 ! Set info.sigma to sigma.
      EIGENVALUE = 0.0_R8                                                ! Set eigenvalue to zero.
      VECTOR = 0.0_R8                                                    ! Set vector to zero.
      RESIDUAL = 0.0_R8                                                  ! Set residual to zero.
      IF (NEV .LT. 1_I4 .OR. INT(NEV,I8) .GT. ORDER) THEN                ! If nev < 1 or int(nev,i8) > order:
        CALL SET_ERROR(STATUS, 'SOLVE_MODAL_PROBLEM',                    ! Record an error in status: 'INVALID NUMBER OF REQUESTED MODES'.
     &                 'INVALID NUMBER OF REQUESTED MODES')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (ORDER .LE. INT(DENSE_ORDER_LIMIT,I8) .OR.                      ! If order <= int(dense_order_limit,i8) or int(nev,i8) >= order-2:
     &    INT(NEV,I8) .GE. ORDER-2_I8) THEN
        CALL SOLVE_DENSE(ORDER, ROW_POINTER, COLUMN_INDEX, STIFFNESS,    ! Call solve dense with order, row_pointer, column_index, stiffness, mass, nev, eigenvalue, vector, info, sta...
     &       MASS, NEV, EIGENVALUE, VECTOR, INFO, STATUS)
      ELSE                                                               ! Otherwise:
        CALL SOLVE_ARPACK(ORDER, ROW_POINTER, COLUMN_INDEX,              ! Call solve arpack with order, row_pointer, column_index, stiffness, mass, nev, sigma, eigenvalue, vector, i...
     &       STIFFNESS, MASS, NEV, SIGMA, EIGENVALUE, VECTOR, INFO,
     &       STATUS)
      END IF                                                             ! End of the IF block.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      CALL SORT_MODES(EIGENVALUE(1:INFO%CONVERGED),                      ! Call sort modes with eigenvalue(1:info.converged), vector(:,1:info.converged).
     &                VECTOR(:,1:INFO%CONVERGED))
      CALL COMPUTE_RESIDUALS(ORDER, ROW_POINTER, COLUMN_INDEX,           ! Call compute residuals with order, row_pointer, column_index, stiffness, mass, int(info.converged,i4), eige...
     &     STIFFNESS, MASS, INT(INFO%CONVERGED,I4), EIGENVALUE,
     &     VECTOR, RESIDUAL)

      END SUBROUTINE SOLVE_MODAL_PROBLEM                                 ! End of the subroutine solve modal problem.

!-----------------------------------------------------------------------
!  ARPACK, SHIFT-INVERT, PARDISO
!-----------------------------------------------------------------------
      SUBROUTINE SOLVE_ARPACK(ORDER, ROW_POINTER, COLUMN_INDEX,          ! Subroutine solve arpack takes order, row pointer, column index, stiffness, mass, nev, sigma, eigenvalue, ve...
     &     STIFFNESS, MASS, NEV, SIGMA, EIGENVALUE, VECTOR, INFO,
     &     STATUS)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: STIFFNESS(:)                               ! Input real (real64): stiffness(:).
      REAL(R8), INTENT(IN) :: MASS(:)                                    ! Input real (real64): mass(:).
      INTEGER(I4), INTENT(IN) :: NEV                                     ! Input integer (int32): nev.
      REAL(R8), INTENT(IN) :: SIGMA                                      ! Input real (real64): sigma.
      REAL(R8), INTENT(OUT) :: EIGENVALUE(:)                             ! Output real (real64): eigenvalue(:).
      REAL(R8), INTENT(OUT) :: VECTOR(:,:)                               ! Output real (real64): vector(:,:).
      TYPE(MODAL_INFO_TYPE), INTENT(INOUT) :: INFO                       ! In/out of type modal_info_type: info.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(PARDISO_FACTOR_TYPE) :: FACTOR                                ! Of type pardiso_factor_type: factor.
      REAL(R8), ALLOCATABLE :: SHIFTED(:)                                ! Allocatable real (real64): shifted(:).
      REAL(R8), ALLOCATABLE :: RESID(:)                                  ! Allocatable real (real64): resid(:).
      REAL(R8), ALLOCATABLE :: V(:,:)                                    ! Allocatable real (real64): v(:,:).
      REAL(R8), ALLOCATABLE :: WORKD(:)                                  ! Allocatable real (real64): workd(:).
      REAL(R8), ALLOCATABLE :: WORKL(:)                                  ! Allocatable real (real64): workl(:).
      REAL(R8), ALLOCATABLE :: D(:)                                      ! Allocatable real (real64): d(:).
      REAL(R8), ALLOCATABLE :: TEMPORARY(:)                              ! Allocatable real (real64): temporary(:).
      LOGICAL(I8), ALLOCATABLE :: SELECT(:)                              ! Allocatable logical (int64): select(:).
      INTEGER(I8) :: IPARAM(11)                                          ! Integer (int64): iparam(11).
      INTEGER(I8) :: IPNTR(11)                                           ! Integer (int64): ipntr(11).
      INTEGER(I8) :: IDO                                                 ! Integer (int64): ido.
      INTEGER(I8) :: ARPACK_INFO                                         ! Integer (int64): arpack_info.
      INTEGER(I8) :: N                                                   ! Integer (int64): n.
      INTEGER(I8) :: NEV8                                                ! Integer (int64): nev8.
      INTEGER(I8) :: NCV                                                 ! Integer (int64): ncv.
      INTEGER(I8) :: LWORKL                                              ! Integer (int64): lworkl.
      INTEGER(I8) :: MTYPE                                               ! Integer (int64): mtype.
      REAL(R8) :: TOLERANCE                                              ! Real (real64): tolerance.
      CHARACTER(LEN=96) :: MESSAGE                                       ! Character (length 96): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      INFO%BACKEND = 'ARPACK'                                            ! Set info.backend to 'ARPACK'.
      N = ORDER                                                          ! Set n to order.
      NEV8 = NEV                                                         ! Set nev8 to nev.
      NCV = MIN(N, MAX(2_I8*NEV8+1_I8, NEV8+10_I8))                      ! Set ncv to the smaller of n and max(2*nev8+1, nev8+10).
      LWORKL = NCV*(NCV+8_I8)                                            ! Set lworkl to ncv*(ncv+8).
      INFO%SUBSPACE = NCV                                                ! Set info.subspace to ncv.

      ALLOCATE(SHIFTED(SIZE(STIFFNESS)))                                 ! Allocate memory for shifted(size(stiffness)).
      SHIFTED = STIFFNESS - SIGMA*MASS                                   ! Set shifted to stiffness - sigma*mass.
      MTYPE = MTYPE_SYMMETRIC_POSITIVE                                   ! Set mtype to mtype_symmetric_positive.
      IF (SIGMA .NE. 0.0_R8 .OR.                                         ! If sigma /= 0.0 or has_massless_row(order, row_pointer, mass), set mtype to mtype_symmetric_indefinite.
     &    HAS_MASSLESS_ROW(ORDER, ROW_POINTER, MASS))
     &  MTYPE = MTYPE_SYMMETRIC_INDEFINITE
      CALL PARDISO_FACTORIZE(ORDER, ROW_POINTER, COLUMN_INDEX,           ! Call pardiso factorize with order, row_pointer, column_index, shifted, mtype, factor, status.
     &     SHIFTED, MTYPE, FACTOR, STATUS)
      IF (.NOT. STATUS_IS_OK(STATUS)) THEN                               ! If not status is ok:
        CALL SET_ERROR(STATUS, 'SOLVE_ARPACK',                           ! Record an error in status: 'K-SIGMA*M CANNOT BE FACTORED: '//trim(status.message)// ' (MISSING SUPPORTS?)'.
     &    'K-SIGMA*M CANNOT BE FACTORED: '//TRIM(STATUS%MESSAGE)//
     &    ' (MISSING SUPPORTS?)')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      ALLOCATE(RESID(N), V(N,NCV), WORKD(3_I8*N), WORKL(LWORKL),         ! Allocate memory for resid(n), v(n,ncv), workd(3*n), workl(lworkl), d(nev8+1), select(ncv), temporary(n).
     &         D(NEV8+1_I8), SELECT(NCV), TEMPORARY(N))
      RESID = 0.0_R8                                                     ! Set resid to zero.
      V = 0.0_R8                                                         ! Set v to zero.
      WORKD = 0.0_R8                                                     ! Set workd to zero.
      WORKL = 0.0_R8                                                     ! Set workl to zero.
      IPARAM = 0_I8                                                      ! Set iparam to zero.
      IPNTR = 0_I8                                                       ! Set ipntr to zero.
      IPARAM(1) = 1_I8                                                   ! Set iparam(1) to 1.
      IPARAM(3) = MAXIMUM_ITERATIONS                                     ! Set iparam(3) to maximum_iterations.
      IPARAM(7) = 3_I8                                                   ! Set iparam(7) to 3.
      IDO = 0_I8                                                         ! Set ido to zero.
      ARPACK_INFO = 0_I8                                                 ! Set arpack_info to zero.
      TOLERANCE = 0.0_R8                                                 ! Set tolerance to zero.

      DO                                                                 ! Loop until an EXIT statement is reached:
        CALL DSAUPD(IDO, 'G', N, 'LM', NEV8, TOLERANCE, RESID, NCV, V,   ! Call dsaupd with ido, 'G', n, 'LM', nev8, tolerance, resid, ncv, v, n, iparam, ipntr, workd, workl, lworkl,...
     &       N, IPARAM, IPNTR, WORKD, WORKL, LWORKL, ARPACK_INFO)
        IF (IDO .EQ. -1_I8) THEN                                         ! If ido = -1:
!         Y = INV(K-SIGMA*M) * (M*X)
          CALL SPARSE_MULTIPLY(ORDER, ROW_POINTER, COLUMN_INDEX, MASS,   ! Call sparse multiply with order, row_pointer, column_index, mass, workd(ipntr(1):ipntr(1)+n-1), temporary.
     &         WORKD(IPNTR(1):IPNTR(1)+N-1), TEMPORARY)
          CALL PARDISO_SOLVE(FACTOR, TEMPORARY,                          ! Call pardiso solve with factor, temporary, workd(ipntr(2):ipntr(2)+n-1), status.
     &         WORKD(IPNTR(2):IPNTR(2)+N-1), STATUS)
        ELSE IF (IDO .EQ. 1_I8) THEN                                     ! Otherwise, if ido = 1:
!         M*X IS IN WORKD(IPNTR(3)).
          TEMPORARY = WORKD(IPNTR(3):IPNTR(3)+N-1)                       ! Set temporary to workd(ipntr(3):ipntr(3)+n-1).
          CALL PARDISO_SOLVE(FACTOR, TEMPORARY,                          ! Call pardiso solve with factor, temporary, workd(ipntr(2):ipntr(2)+n-1), status.
     &         WORKD(IPNTR(2):IPNTR(2)+N-1), STATUS)
        ELSE IF (IDO .EQ. 2_I8) THEN                                     ! Otherwise, if ido = 2:
          CALL SPARSE_MULTIPLY(ORDER, ROW_POINTER, COLUMN_INDEX, MASS,   ! Call sparse multiply with order, row_pointer, column_index, mass, workd(ipntr(1):ipntr(1)+n-1), workd(ipntr...
     &         WORKD(IPNTR(1):IPNTR(1)+N-1),
     &         WORKD(IPNTR(2):IPNTR(2)+N-1))
        ELSE                                                             ! Otherwise:
          EXIT                                                           ! Leave the loop.
        END IF                                                           ! End of the IF block.
        IF (.NOT. STATUS_IS_OK(STATUS)) THEN                             ! If not status is ok:
          CALL PARDISO_RELEASE(FACTOR)                                   ! Call pardiso release with factor.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      CALL PARDISO_RELEASE(FACTOR)                                       ! Call pardiso release with factor.

      IF (ARPACK_INFO .LT. 0_I8) THEN                                    ! If arpack_info < 0:
        WRITE(MESSAGE,'(A,I0)') 'ARPACK DSAUPD ERROR CODE ',             ! Format into the text message: 'ARPACK DSAUPD ERROR CODE ', arpack_info.
     &                          ARPACK_INFO
        CALL SET_ERROR(STATUS, 'SOLVE_ARPACK', TRIM(MESSAGE))            ! Record an error in status: trim(message).
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      INFO%CONVERGED = IPARAM(5)                                         ! Set info.converged to iparam(5).
      INFO%ITERATIONS = IPARAM(3)                                        ! Set info.iterations to iparam(3).
      INFO%OPERATIONS = IPARAM(9)                                        ! Set info.operations to iparam(9).
      IF (INFO%CONVERGED .LT. NEV8) THEN                                 ! If info.converged < nev8:
        WRITE(MESSAGE,'(A,I0,A,I0,A)') 'ARPACK CONVERGED ONLY ',         ! Format into the text message: 'ARPACK CONVERGED ONLY ', info.converged, ' OF ', nev8, ' MODES'.
     &    INFO%CONVERGED, ' OF ', NEV8, ' MODES'
        CALL SET_WARNING(STATUS, 'SOLVE_ARPACK', TRIM(MESSAGE))          ! Record a warning in status: trim(message).
      END IF                                                             ! End of the IF block.
      IF (INFO%CONVERGED .LT. 1_I8) THEN                                 ! If info.converged < 1:
        CALL SET_ERROR(STATUS, 'SOLVE_ARPACK',                           ! Record an error in status: 'ARPACK DID NOT CONVERGE ANY MODE'.
     &                 'ARPACK DID NOT CONVERGE ANY MODE')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

      ARPACK_INFO = 0_I8                                                 ! Set arpack_info to zero.
      SELECT = .TRUE.                                                    ! Set the flag select to true.
      D = 0.0_R8                                                         ! Set d to zero.
      CALL DSEUPD(.TRUE._I8, 'A', SELECT, D, V, N, SIGMA, 'G', N,        ! Call dseupd with true_i8, 'A', select, d, v, n, sigma, 'G', n, 'LM', nev8, tolerance, resid, ncv, v, n, ipa...
     &     'LM', NEV8, TOLERANCE, RESID, NCV, V, N, IPARAM, IPNTR,
     &     WORKD, WORKL, LWORKL, ARPACK_INFO)
      IF (ARPACK_INFO .NE. 0_I8) THEN                                    ! If arpack_info /= 0:
        WRITE(MESSAGE,'(A,I0)') 'ARPACK DSEUPD ERROR CODE ',             ! Format into the text message: 'ARPACK DSEUPD ERROR CODE ', arpack_info.
     &                          ARPACK_INFO
        CALL SET_ERROR(STATUS, 'SOLVE_ARPACK', TRIM(MESSAGE))            ! Record an error in status: trim(message).
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      EIGENVALUE(1:INFO%CONVERGED) = D(1:INFO%CONVERGED)                 ! Set eigenvalue(1:info.converged) to d(1:info.converged).
      VECTOR(:,1:INFO%CONVERGED) = V(:,1:INFO%CONVERGED)                 ! Set vector(:,1:info.converged) to v(:,1:info.converged).

      END SUBROUTINE SOLVE_ARPACK                                        ! End of the subroutine solve arpack.

!-----------------------------------------------------------------------
!  DENSE LAPACK FALLBACK
!-----------------------------------------------------------------------
!  A ROW OF M WITHOUT ANY NON-ZERO VALUE (A DOF THAT CARRIES NO MASS,
!  E.G. AN ELECTRIC POTENTIAL).
      LOGICAL FUNCTION HAS_MASSLESS_ROW(ORDER, ROW_POINTER, MASS)        ! Function has massless row takes order, row pointer, mass.

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      REAL(R8), INTENT(IN) :: MASS(:)                                    ! Input real (real64): mass(:).
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.

      HAS_MASSLESS_ROW = .FALSE.                                         ! Set the flag has_massless_row to false.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        IF (ALL(MASS(ROW_POINTER(ROW):ROW_POINTER(ROW+1_I8)-1_I8)        ! If all(mass(row_pointer(row):row_pointer(row+1)-1) = 0.0):
     &      .EQ. 0.0_R8)) THEN
          HAS_MASSLESS_ROW = .TRUE.                                      ! Set the flag has_massless_row to true.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION HAS_MASSLESS_ROW                                      ! End of the function has massless row.

      SUBROUTINE SOLVE_DENSE(ORDER, ROW_POINTER, COLUMN_INDEX,           ! Subroutine solve dense takes order, row pointer, column index, stiffness, mass, nev, eigenvalue, vector, in...
     &     STIFFNESS, MASS, NEV, EIGENVALUE, VECTOR, INFO, STATUS)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: STIFFNESS(:)                               ! Input real (real64): stiffness(:).
      REAL(R8), INTENT(IN) :: MASS(:)                                    ! Input real (real64): mass(:).
      INTEGER(I4), INTENT(IN) :: NEV                                     ! Input integer (int32): nev.
      REAL(R8), INTENT(OUT) :: EIGENVALUE(:)                             ! Output real (real64): eigenvalue(:).
      REAL(R8), INTENT(OUT) :: VECTOR(:,:)                               ! Output real (real64): vector(:,:).
      TYPE(MODAL_INFO_TYPE), INTENT(INOUT) :: INFO                       ! In/out of type modal_info_type: info.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: A(:,:)                                    ! Allocatable real (real64): a(:,:).
      REAL(R8), ALLOCATABLE :: B(:,:)                                    ! Allocatable real (real64): b(:,:).
      REAL(R8), ALLOCATABLE :: KUU(:,:)                                  ! Allocatable real (real64): kuu(:,:).
      REAL(R8), ALLOCATABLE :: MUU(:,:)                                  ! Allocatable real (real64): muu(:,:).
      REAL(R8), ALLOCATABLE :: X(:,:)                                    ! Allocatable real (real64): x(:,:).
      REAL(R8), ALLOCATABLE :: KZZ(:,:)                                  ! Allocatable real (real64): kzz(:,:).
      REAL(R8), ALLOCATABLE :: WORK(:)                                   ! Allocatable real (real64): work(:).
      REAL(R8), ALLOCATABLE :: W(:)                                      ! Allocatable real (real64): w(:).
      REAL(R8), ALLOCATABLE :: V(:,:)                                    ! Allocatable real (real64): v(:,:).
      INTEGER(I8), ALLOCATABLE :: IPIV(:)                                ! Allocatable integer (int64): ipiv(:).
      INTEGER(I8), ALLOCATABLE :: IU(:)                                  ! Allocatable integer (int64): iu(:).
      INTEGER(I8), ALLOCATABLE :: IZ(:)                                  ! Allocatable integer (int64): iz(:).
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I8) :: NU                                                  ! Integer (int64): nu.
      INTEGER(I8) :: NZ                                                  ! Integer (int64): nz.
      INTEGER(I8) :: LAPACK_INFO                                         ! Integer (int64): lapack_info.
      INTEGER(I8) :: LWORK                                               ! Integer (int64): lwork.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      CHARACTER(LEN=96) :: MESSAGE                                       ! Character (length 96): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      INFO%BACKEND = 'DENSE'                                             ! Set info.backend to 'DENSE'.
      ALLOCATE(A(ORDER,ORDER), B(ORDER,ORDER))                           ! Allocate memory for a(order,order), b(order,order).
      A = 0.0_R8                                                         ! Set a to zero.
      B = 0.0_R8                                                         ! Set b to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        DO POSITION = ROW_POINTER(ROW), ROW_POINTER(ROW+1_I8)-1_I8       ! Loop position from row_pointer(row) to row_pointer(row+1)-1:
          A(ROW,COLUMN_INDEX(POSITION)) = STIFFNESS(POSITION)            ! Set a(row,column_index(position)) to stiffness(position).
          B(ROW,COLUMN_INDEX(POSITION)) = MASS(POSITION)                 ! Set b(row,column_index(position)) to mass(position).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
!     DOFS WITHOUT MASS (ELECTRIC POTENTIAL) ARE CONDENSED OUT:
!     K* = KUU - KUZ KZZ^-1 KZU, M* = MUU.
      NZ = 0_I8                                                          ! Set nz to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        IF (ALL(B(ROW,:) .EQ. 0.0_R8)) NZ = NZ + 1_I8                    ! If all(b(row,:) = 0.0), add 1 to nz.
      END DO                                                             ! End of the loop.
      NU = ORDER - NZ                                                    ! Set nu to order - nz.
      ALLOCATE(IU(NU), IZ(MAX(NZ,1_I8)))                                 ! Allocate memory for iu(nu), iz(max(nz,1)).
      NU = 0_I8                                                          ! Set nu to zero.
      NZ = 0_I8                                                          ! Set nz to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        IF (ALL(B(ROW,:) .EQ. 0.0_R8)) THEN                              ! If all(b(row,:) = 0.0):
          NZ = NZ + 1_I8                                                 ! Add 1 to nz.
          IZ(NZ) = ROW                                                   ! Set iz(nz) to row.
        ELSE                                                             ! Otherwise:
          NU = NU + 1_I8                                                 ! Add 1 to nu.
          IU(NU) = ROW                                                   ! Set iu(nu) to row.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      IF (NU .LT. 1_I8) THEN                                             ! If nu < 1:
        CALL SET_ERROR(STATUS, 'SOLVE_DENSE',                            ! Record an error in status: 'THE MODEL HAS NO MASS'.
     &                 'THE MODEL HAS NO MASS')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(KUU(NU,NU), MUU(NU,NU))                                   ! Allocate memory for kuu(nu,nu), muu(nu,nu).
      KUU = A(IU,IU)                                                     ! Set kuu to a(iu,iu).
      MUU = B(IU,IU)                                                     ! Set muu to b(iu,iu).
      IF (NZ .GT. 0_I8) THEN                                             ! If nz > 0:
        ALLOCATE(KZZ(NZ,NZ), X(NZ,NU), IPIV(NZ))                         ! Allocate memory for kzz(nz,nz), x(nz,nu), ipiv(nz).
        KZZ = A(IZ(1:NZ),IZ(1:NZ))                                       ! Set kzz to a(iz(1:nz),iz(1:nz)).
        X = A(IZ(1:NZ),IU)                                               ! Set x to a(iz(1:nz),iu).
        LWORK = MAX(1_I8, 64_I8*NZ)                                      ! Set lwork to the larger of 1 and 64*nz.
        ALLOCATE(WORK(LWORK))                                            ! Allocate memory for work(lwork).
        CALL DSYSV('U', NZ, NU, KZZ, NZ, IPIV, X, NZ, WORK, LWORK,       ! Call dsysv with 'U', nz, nu, kzz, nz, ipiv, x, nz, work, lwork, lapack_info.
     &             LAPACK_INFO)
        IF (LAPACK_INFO .NE. 0_I8) THEN                                  ! If lapack_info /= 0:
          WRITE(MESSAGE,'(A,I0)') 'LAPACK DSYSV ERROR CODE ',            ! Format into the text message: 'LAPACK DSYSV ERROR CODE ', lapack_info.
     &                            LAPACK_INFO
          CALL SET_ERROR(STATUS, 'SOLVE_DENSE', TRIM(MESSAGE))           ! Record an error in status: trim(message).
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        KUU = KUU - MATMUL(A(IU,IZ(1:NZ)),X)                             ! Subtract matmul(a(iu,iz(1:nz)),x) from kuu.
        DEALLOCATE(WORK)                                                 ! Free the memory of work.
      END IF                                                             ! End of the IF block.
      DEALLOCATE(A, B)                                                   ! Free the memory of a, b.

      ALLOCATE(W(NU), V(NU,NU))                                          ! Allocate memory for w(nu), v(nu,nu).
      CALL DENSE_GENERALIZED(NU, KUU, MUU, W, V, COUNT, STATUS)          ! Call dense generalized with nu, kuu, muu, w, v, count, status.
      IF (.NOT. STATUS_IS_OK(STATUS)) RETURN                             ! If not status is ok, return to the caller.
      COUNT = MIN(COUNT, NEV)                                            ! Set count to the smaller of count and nev.
      INFO%CONVERGED = COUNT                                             ! Set info.converged to count.
      INFO%SUBSPACE = ORDER                                              ! Set info.subspace to order.
      VECTOR = 0.0_R8                                                    ! Set vector to zero.
      EIGENVALUE(1:COUNT) = W(1:COUNT)                                   ! Set eigenvalue(1:count) to w(1:count).
      DO ROW = 1_I8, NU                                                  ! Loop row from 1 to nu:
        VECTOR(IU(ROW),1:COUNT) = V(ROW,1:COUNT)                         ! Set vector(iu(row),1:count) to v(row,1:count).
      END DO                                                             ! End of the loop.
      IF (NZ .GT. 0_I8) THEN                                             ! If nz > 0:
        VECTOR(IZ(1:NZ),1:COUNT) = -MATMUL(X,V(:,1:COUNT))               ! Set vector(iz(1:nz),1:count) to -matmul(x,v(:,1:count)).
      END IF                                                             ! End of the IF block.

      END SUBROUTINE SOLVE_DENSE                                         ! End of the subroutine solve dense.

!  A X = LAMBDA B X FOR SYMMETRIC A AND B. B SINGULAR: M X = MU K X WITH
!  K POSITIVE DEFINITE. RETURNS THE LAMBDA IN ASCENDING ORDER AND THE
!  B-ORTHONORMAL VECTORS (A AND B ARE DESTROYED).
      SUBROUTINE DENSE_GENERALIZED(N, A, B, W, V, COUNT, STATUS)         ! Subroutine dense generalized takes n, a, b, w, v, count, status.

      INTEGER(I8), INTENT(IN) :: N                                       ! Input integer (int64): n.
      REAL(R8), INTENT(INOUT) :: A(:,:)                                  ! In/out real (real64): a(:,:).
      REAL(R8), INTENT(INOUT) :: B(:,:)                                  ! In/out real (real64): b(:,:).
      REAL(R8), INTENT(OUT) :: W(:)                                      ! Output real (real64): w(:).
      REAL(R8), INTENT(OUT) :: V(:,:)                                    ! Output real (real64): v(:,:).
      INTEGER(I4), INTENT(OUT) :: COUNT                                  ! Output integer (int32): count.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: A0(:,:)                                   ! Allocatable real (real64): a0(:,:).
      REAL(R8), ALLOCATABLE :: B0(:,:)                                   ! Allocatable real (real64): b0(:,:).
      REAL(R8), ALLOCATABLE :: WORK(:)                                   ! Allocatable real (real64): work(:).
      REAL(R8), ALLOCATABLE :: MU(:)                                     ! Allocatable real (real64): mu(:).
      INTEGER(I8) :: LWORK                                               ! Integer (int64): lwork.
      INTEGER(I8) :: LAPACK_INFO                                         ! Integer (int64): lapack_info.
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      CHARACTER(LEN=96) :: MESSAGE                                       ! Character (length 96): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      ALLOCATE(A0(N,N), B0(N,N), MU(N))                                  ! Allocate memory for a0(n,n), b0(n,n), mu(n).
      A0 = A                                                             ! Set a0 to a.
      B0 = B                                                             ! Set b0 to b.
      LWORK = MAX(1_I8, 3_I8*N-1_I8)*8_I8                                ! Set lwork to max(1, 3*n-1)*8.
      ALLOCATE(WORK(LWORK))                                              ! Allocate memory for work(lwork).
      CALL DSYGV(1_I8, 'V', 'U', N, A, N, B, N, MU, WORK, LWORK,         ! Call dsygv with 1, 'V', 'U', n, a, n, b, n, mu, work, lwork, lapack_info.
     &           LAPACK_INFO)
      IF (LAPACK_INFO .GT. N) THEN                                       ! If lapack_info > n:
!       THE MASS IS SINGULAR (REDUCED INTEGRATION): SOLVE M X = MU K X
!       WITH K POSITIVE DEFINITE AND TAKE LAMBDA = 1/MU. MU = 0 ARE THE
!       INFINITE EIGENVALUES AND ARE DISCARDED.
        CALL DSYGV(1_I8, 'V', 'U', N, B0, N, A0, N, MU, WORK, LWORK,     ! Call dsygv with 1, 'V', 'U', n, b0, n, a0, n, mu, work, lwork, lapack_info.
     &             LAPACK_INFO)
        IF (LAPACK_INFO .NE. 0_I8) THEN                                  ! If lapack_info /= 0:
          WRITE(MESSAGE,'(A,I0)') 'LAPACK DSYGV ERROR CODE ',            ! Format into the text message: 'LAPACK DSYGV ERROR CODE ', lapack_info.
     &                            LAPACK_INFO
          CALL SET_ERROR(STATUS, 'SOLVE_DENSE', TRIM(MESSAGE))           ! Record an error in status: trim(message).
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        COUNT = 0_I4                                                     ! Set count to zero.
        DO ROW = N, 1_I8, -1_I8                                          ! Loop row from n to 1 in steps of -1:
          IF (MU(ROW) .LE. 1.0E-14_R8*MU(N)) EXIT                        ! If mu(row) <= 1.0e-14*mu(n), leave the loop.
          COUNT = COUNT + 1_I4                                           ! Add 1 to count.
          W(COUNT) = 1.0_R8/MU(ROW)                                      ! Set w(count) to 1.0/mu(row).
          V(:,COUNT) = B0(:,ROW)/SQRT(MU(ROW))                           ! Set v(:,count) to b0(:,row)/sqrt(mu(row)).
        END DO                                                           ! End of the loop.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      IF (LAPACK_INFO .NE. 0_I8) THEN                                    ! If lapack_info /= 0:
        WRITE(MESSAGE,'(A,I0)') 'LAPACK DSYGV ERROR CODE ',              ! Format into the text message: 'LAPACK DSYGV ERROR CODE ', lapack_info.
     &                          LAPACK_INFO
        CALL SET_ERROR(STATUS, 'SOLVE_DENSE', TRIM(MESSAGE))             ! Record an error in status: trim(message).
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      COUNT = INT(N,I4)                                                  ! Set count to int(n,i4).
      W(1:N) = MU                                                        ! Set w(1:n) to mu.
      V(:,1:N) = A                                                       ! Set v(:,1:n) to a.

      END SUBROUTINE DENSE_GENERALIZED                                   ! End of the subroutine dense generalized.

!  ASCENDING ORDER OF THE EIGENVALUES (SELECTION SORT, VECTORS FOLLOW).
      SUBROUTINE SORT_MODES(EIGENVALUE, VECTOR)                          ! Subroutine sort modes takes eigenvalue, vector.

      REAL(R8), INTENT(INOUT) :: EIGENVALUE(:)                           ! In/out real (real64): eigenvalue(:).
      REAL(R8), INTENT(INOUT) :: VECTOR(:,:)                             ! In/out real (real64): vector(:,:).
      REAL(R8), ALLOCATABLE :: COLUMN(:)                                 ! Allocatable real (real64): column(:).
      REAL(R8) :: VALUE                                                  ! Real (real64): value.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: BEST                                                ! Integer (int32): best.

      ALLOCATE(COLUMN(SIZE(VECTOR,1)))                                   ! Allocate memory for column(size(vector,1)).
      DO I = 1_I4, SIZE(EIGENVALUE)-1_I4                                 ! Loop i from 1 to size(eigenvalue)-1:
        BEST = I                                                         ! Set best to i.
        DO J = I+1_I4, SIZE(EIGENVALUE)                                  ! Loop j from i+1 to size(eigenvalue):
          IF (EIGENVALUE(J) .LT. EIGENVALUE(BEST)) BEST = J              ! If eigenvalue(j) < eigenvalue(best), set best to j.
        END DO                                                           ! End of the loop.
        IF (BEST .EQ. I) CYCLE                                           ! If best = i, skip to the next iteration.
        VALUE = EIGENVALUE(I)                                            ! Set value to eigenvalue(i).
        EIGENVALUE(I) = EIGENVALUE(BEST)                                 ! Set eigenvalue(i) to eigenvalue(best).
        EIGENVALUE(BEST) = VALUE                                         ! Set eigenvalue(best) to value.
        COLUMN = VECTOR(:,I)                                             ! Set column to vector(:,i).
        VECTOR(:,I) = VECTOR(:,BEST)                                     ! Set vector(:,i) to vector(:,best).
        VECTOR(:,BEST) = COLUMN                                          ! Set vector(:,best) to column.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SORT_MODES                                          ! End of the subroutine sort modes.

      SUBROUTINE COMPUTE_RESIDUALS(ORDER, ROW_POINTER, COLUMN_INDEX,     ! Subroutine compute residuals takes order, row pointer, column index, stiffness, mass, count, eigenvalue, ve...
     &     STIFFNESS, MASS, COUNT, EIGENVALUE, VECTOR, RESIDUAL)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: STIFFNESS(:)                               ! Input real (real64): stiffness(:).
      REAL(R8), INTENT(IN) :: MASS(:)                                    ! Input real (real64): mass(:).
      INTEGER(I4), INTENT(IN) :: COUNT                                   ! Input integer (int32): count.
      REAL(R8), INTENT(IN) :: EIGENVALUE(:)                              ! Input real (real64): eigenvalue(:).
      REAL(R8), INTENT(IN) :: VECTOR(:,:)                                ! Input real (real64): vector(:,:).
      REAL(R8), INTENT(OUT) :: RESIDUAL(:)                               ! Output real (real64): residual(:).
      REAL(R8), ALLOCATABLE :: KX(:)                                     ! Allocatable real (real64): kx(:).
      REAL(R8), ALLOCATABLE :: MX(:)                                     ! Allocatable real (real64): mx(:).
      REAL(R8) :: NORM                                                   ! Real (real64): norm.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      ALLOCATE(KX(ORDER), MX(ORDER))                                     ! Allocate memory for kx(order), mx(order).
      RESIDUAL = 0.0_R8                                                  ! Set residual to zero.
      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL SPARSE_MULTIPLY(ORDER, ROW_POINTER, COLUMN_INDEX,           ! Call sparse multiply with order, row_pointer, column_index, stiffness, vector(:,i), kx.
     &                       STIFFNESS, VECTOR(:,I), KX)
        CALL SPARSE_MULTIPLY(ORDER, ROW_POINTER, COLUMN_INDEX, MASS,     ! Call sparse multiply with order, row_pointer, column_index, mass, vector(:,i), mx.
     &                       VECTOR(:,I), MX)
        NORM = SQRT(DOT_PRODUCT(KX,KX))                                  ! Set norm to the square root of dot_product(kx,kx).
        IF (NORM .GT. 0.0_R8)                                            ! If norm > 0.0, set residual(i) to sqrt(sum((kx-eigenvalue(i)*mx)**2))/norm.
     &    RESIDUAL(I) = SQRT(SUM((KX-EIGENVALUE(I)*MX)**2))/NORM
      END DO                                                             ! End of the loop.

      END SUBROUTINE COMPUTE_RESIDUALS                                   ! End of the subroutine compute residuals.

!  LINEAR BUCKLING  (K + LAMBDA G) X = 0  ON A FULL SYMMETRIC CSR
!  PATTERN, BY LAPACK. ROWS WITHOUT GEOMETRIC STIFFNESS (ELECTRIC
!  POTENTIAL) ARE CONDENSED OUT. WITH K POSITIVE DEFINITE THE PENCIL
!  G X = MU K X HAS MU = -1/LAMBDA: THE NEGATIVE MU GIVE THE POSITIVE
!  LOAD FACTORS, RETURNED IN ASCENDING ORDER (THE MODES ARE
!  K-ORTHONORMAL).
      SUBROUTINE SOLVE_BUCKLING_DENSE(ORDER, ROW_POINTER, COLUMN_INDEX,  ! Subroutine solve buckling dense takes order, row pointer, column index, stiffness, geometric, nev, factor, ...
     &     STIFFNESS, GEOMETRIC, NEV, FACTOR, VECTOR, COUNT, STATUS)

      INTEGER(I8), INTENT(IN) :: ORDER                                   ! Input integer (int64): order.
      INTEGER(I8), INTENT(IN) :: ROW_POINTER(:)                          ! Input integer (int64): row_pointer(:).
      INTEGER(I8), INTENT(IN) :: COLUMN_INDEX(:)                         ! Input integer (int64): column_index(:).
      REAL(R8), INTENT(IN) :: STIFFNESS(:)                               ! Input real (real64): stiffness(:).
      REAL(R8), INTENT(IN) :: GEOMETRIC(:)                               ! Input real (real64): geometric(:).
      INTEGER(I4), INTENT(IN) :: NEV                                     ! Input integer (int32): nev.
      REAL(R8), INTENT(OUT) :: FACTOR(:)                                 ! Output real (real64): factor(:).
      REAL(R8), INTENT(OUT) :: VECTOR(:,:)                               ! Output real (real64): vector(:,:).
      INTEGER(I4), INTENT(OUT) :: COUNT                                  ! Output integer (int32): count.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8), ALLOCATABLE :: A(:,:)                                    ! Allocatable real (real64): a(:,:).
      REAL(R8), ALLOCATABLE :: B(:,:)                                    ! Allocatable real (real64): b(:,:).
      REAL(R8), ALLOCATABLE :: KUU(:,:)                                  ! Allocatable real (real64): kuu(:,:).
      REAL(R8), ALLOCATABLE :: GUU(:,:)                                  ! Allocatable real (real64): guu(:,:).
      REAL(R8), ALLOCATABLE :: X(:,:)                                    ! Allocatable real (real64): x(:,:).
      REAL(R8), ALLOCATABLE :: KZZ(:,:)                                  ! Allocatable real (real64): kzz(:,:).
      REAL(R8), ALLOCATABLE :: WORK(:)                                   ! Allocatable real (real64): work(:).
      REAL(R8), ALLOCATABLE :: MU(:)                                     ! Allocatable real (real64): mu(:).
      INTEGER(I8), ALLOCATABLE :: IPIV(:)                                ! Allocatable integer (int64): ipiv(:).
      INTEGER(I8), ALLOCATABLE :: IU(:)                                  ! Allocatable integer (int64): iu(:).
      INTEGER(I8), ALLOCATABLE :: IZ(:)                                  ! Allocatable integer (int64): iz(:).
      INTEGER(I8) :: ROW                                                 ! Integer (int64): row.
      INTEGER(I8) :: POSITION                                            ! Integer (int64): position.
      INTEGER(I8) :: NU                                                  ! Integer (int64): nu.
      INTEGER(I8) :: NZ                                                  ! Integer (int64): nz.
      INTEGER(I8) :: LAPACK_INFO                                         ! Integer (int64): lapack_info.
      INTEGER(I8) :: LWORK                                               ! Integer (int64): lwork.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      CHARACTER(LEN=96) :: MESSAGE                                       ! Character (length 96): message.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      COUNT = 0_I4                                                       ! Set count to zero.
      IF (ORDER .GT. 8000_I8) THEN                                       ! If order > 8000:
        CALL SET_ERROR(STATUS, 'SOLVE_BUCKLING_DENSE',                   ! Record an error in status: 'THE BUCKLING EIGENSOLVER IS DENSE: AT MOST 8000 FREE DOF'.
     &    'THE BUCKLING EIGENSOLVER IS DENSE: AT MOST 8000 FREE DOF')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(A(ORDER,ORDER), B(ORDER,ORDER))                           ! Allocate memory for a(order,order), b(order,order).
      A = 0.0_R8                                                         ! Set a to zero.
      B = 0.0_R8                                                         ! Set b to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        DO POSITION = ROW_POINTER(ROW), ROW_POINTER(ROW+1_I8)-1_I8       ! Loop position from row_pointer(row) to row_pointer(row+1)-1:
          A(ROW,COLUMN_INDEX(POSITION)) = STIFFNESS(POSITION)            ! Set a(row,column_index(position)) to stiffness(position).
          B(ROW,COLUMN_INDEX(POSITION)) = GEOMETRIC(POSITION)            ! Set b(row,column_index(position)) to geometric(position).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      NZ = 0_I8                                                          ! Set nz to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        IF (ALL(B(ROW,:) .EQ. 0.0_R8)) NZ = NZ + 1_I8                    ! If all(b(row,:) = 0.0), add 1 to nz.
      END DO                                                             ! End of the loop.
      NU = ORDER - NZ                                                    ! Set nu to order - nz.
      IF (NU .LT. 1_I8) THEN                                             ! If nu < 1:
        CALL SET_ERROR(STATUS, 'SOLVE_BUCKLING_DENSE',                   ! Record an error in status: 'THE PRE-STRESS IS ZERO: NO BUCKLING LOAD'.
     &    'THE PRE-STRESS IS ZERO: NO BUCKLING LOAD')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      ALLOCATE(IU(NU), IZ(MAX(NZ,1_I8)))                                 ! Allocate memory for iu(nu), iz(max(nz,1)).
      NU = 0_I8                                                          ! Set nu to zero.
      NZ = 0_I8                                                          ! Set nz to zero.
      DO ROW = 1_I8, ORDER                                               ! Loop row from 1 to order:
        IF (ALL(B(ROW,:) .EQ. 0.0_R8)) THEN                              ! If all(b(row,:) = 0.0):
          NZ = NZ + 1_I8                                                 ! Add 1 to nz.
          IZ(NZ) = ROW                                                   ! Set iz(nz) to row.
        ELSE                                                             ! Otherwise:
          NU = NU + 1_I8                                                 ! Add 1 to nu.
          IU(NU) = ROW                                                   ! Set iu(nu) to row.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.
      ALLOCATE(KUU(NU,NU), GUU(NU,NU))                                   ! Allocate memory for kuu(nu,nu), guu(nu,nu).
      KUU = A(IU,IU)                                                     ! Set kuu to a(iu,iu).
      GUU = B(IU,IU)                                                     ! Set guu to b(iu,iu).
      IF (NZ .GT. 0_I8) THEN                                             ! If nz > 0:
        ALLOCATE(KZZ(NZ,NZ), X(NZ,NU), IPIV(NZ))                         ! Allocate memory for kzz(nz,nz), x(nz,nu), ipiv(nz).
        KZZ = A(IZ(1:NZ),IZ(1:NZ))                                       ! Set kzz to a(iz(1:nz),iz(1:nz)).
        X = A(IZ(1:NZ),IU)                                               ! Set x to a(iz(1:nz),iu).
        LWORK = MAX(1_I8, 64_I8*NZ)                                      ! Set lwork to the larger of 1 and 64*nz.
        ALLOCATE(WORK(LWORK))                                            ! Allocate memory for work(lwork).
        CALL DSYSV('U', NZ, NU, KZZ, NZ, IPIV, X, NZ, WORK, LWORK,       ! Call dsysv with 'U', nz, nu, kzz, nz, ipiv, x, nz, work, lwork, lapack_info.
     &             LAPACK_INFO)
        IF (LAPACK_INFO .NE. 0_I8) THEN                                  ! If lapack_info /= 0:
          WRITE(MESSAGE,'(A,I0)') 'LAPACK DSYSV ERROR CODE ',            ! Format into the text message: 'LAPACK DSYSV ERROR CODE ', lapack_info.
     &                            LAPACK_INFO
          CALL SET_ERROR(STATUS, 'SOLVE_BUCKLING_DENSE',                 ! Record an error in status: trim(message).
     &                   TRIM(MESSAGE))
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        KUU = KUU - MATMUL(A(IU,IZ(1:NZ)),X)                             ! Subtract matmul(a(iu,iz(1:nz)),x) from kuu.
        DEALLOCATE(WORK)                                                 ! Free the memory of work.
      END IF                                                             ! End of the IF block.
      DEALLOCATE(A, B)                                                   ! Free the memory of a, b.
      ALLOCATE(MU(NU))                                                   ! Allocate memory for mu(nu).
      LWORK = MAX(1_I8, 3_I8*NU-1_I8)*8_I8                               ! Set lwork to max(1, 3*nu-1)*8.
      ALLOCATE(WORK(LWORK))                                              ! Allocate memory for work(lwork).
      CALL DSYGV(1_I8, 'V', 'U', NU, GUU, NU, KUU, NU, MU, WORK, LWORK,  ! Call dsygv with 1, 'V', 'U', nu, guu, nu, kuu, nu, mu, work, lwork, lapack_info.
     &           LAPACK_INFO)
      IF (LAPACK_INFO .NE. 0_I8) THEN                                    ! If lapack_info /= 0:
        WRITE(MESSAGE,'(A,I0,A)') 'LAPACK DSYGV ERROR CODE ',            ! Format into the text message: 'LAPACK DSYGV ERROR CODE ', lapack_info, ' (THE STIFFNESS IS NOT POSITIVE DEF...
     &    LAPACK_INFO, ' (THE STIFFNESS IS NOT POSITIVE DEFINITE?)'
        CALL SET_ERROR(STATUS, 'SOLVE_BUCKLING_DENSE', TRIM(MESSAGE))    ! Record an error in status: trim(message).
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      VECTOR = 0.0_R8                                                    ! Set vector to zero.
      DO ROW = 1_I8, NU                                                  ! Loop row from 1 to nu:
        IF (MU(ROW) .GE. -1.0E-14_R8*MAXVAL(ABS(MU))) EXIT               ! If mu(row) >= -1.0e-14*maxval(abs(mu)), leave the loop.
        IF (COUNT .GE. NEV) EXIT                                         ! If count >= nev, leave the loop.
        COUNT = COUNT + 1_I4                                             ! Add 1 to count.
        FACTOR(COUNT) = -1.0_R8/MU(ROW)                                  ! Set factor(count) to -1.0/mu(row).
        VECTOR(IU(1:NU),COUNT) = GUU(:,ROW)                              ! Set vector(iu(1:nu),count) to guu(:,row).
        IF (NZ .GT. 0_I8) VECTOR(IZ(1:NZ),COUNT) =                       ! If nz > 0, set vector(iz(1:nz),count) to -matmul(x,guu(:,row)).
     &    -MATMUL(X,GUU(:,ROW))
      END DO                                                             ! End of the loop.
      DO K = 1_I4, COUNT                                                 ! Loop k from 1 to count:
!       NORMALISE TO UNIT MAXIMUM COMPONENT.
        VECTOR(:,K) = VECTOR(:,K)/MAXVAL(ABS(VECTOR(:,K)))               ! Divide vector(:,k) by maxval(abs(vector(:,k))).
      END DO                                                             ! End of the loop.
      IF (COUNT .LT. 1_I4) CALL SET_ERROR(STATUS,                        ! If count < 1, record an error in status: 'NO POSITIVE BUCKLING LOAD FACTOR (REVERSE THE LOAD)'.
     &  'SOLVE_BUCKLING_DENSE',
     &  'NO POSITIVE BUCKLING LOAD FACTOR (REVERSE THE LOAD)')

      END SUBROUTINE SOLVE_BUCKLING_DENSE                                ! End of the subroutine solve buckling dense.

      END MODULE MUL2_MODAL_SOLVER                                       ! End of the module mul2 modal solver.
