!=======================================================================
!  DENSE PRODUCTS USED BY THE ELEMENT KERNELS.
!
!  MATRIX(I,J) += SUM_Q A(Q,I) * B(Q,J) FOR I <= J ONLY. THE CALLER
!  MIRRORS THE UPPER TRIANGLE. THE LOOPS ARE WRITTEN WITHOUT ARRAY
!  TEMPORARIES (NO STACK USE, SAFE INSIDE OPENMP REGIONS) AND WITH A
!  4-COLUMN REGISTER BLOCK TO REUSE EVERY STREAMED COLUMN OF A.
!=======================================================================
      MODULE MUL2_DENSE_PRODUCTS                                         ! Module mul2 dense products begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: ACCUMULATE_UPPER_PRODUCT                                 ! Export: accumulate upper product.
      PUBLIC :: ACCUMULATE_PRODUCT                                       ! Export: accumulate product.

      CONTAINS                                                           ! The procedures of the module follow.

!  A, B: (ROWS,N) WITH THE FIRST ROWS ROWS USED. INDEX (ASCENDING)
!  SELECTS THE COLUMNS OF A, B AND THEIR POSITION IN MATRIX; WITHOUT
!  IT THE COLUMNS ARE 1..SIZE(A,2).
      SUBROUTINE ACCUMULATE_UPPER_PRODUCT(A, B, ROWS, MATRIX, INDEX)     ! Subroutine accumulate upper product takes a, b, rows, matrix, index.

      REAL(R8), INTENT(IN) :: A(:,:)                                     ! Input real (real64): a(:,:).
      REAL(R8), INTENT(IN) :: B(:,:)                                     ! Input real (real64): b(:,:).
      INTEGER(I4), INTENT(IN) :: ROWS                                    ! Input integer (int32): rows.
      REAL(R8), INTENT(INOUT) :: MATRIX(:,:)                             ! In/out real (real64): matrix(:,:).
      INTEGER(I4), INTENT(IN), OPTIONAL :: INDEX(:)                      ! Input optional integer (int32): index(:).
      REAL(R8) :: S1                                                     ! Real (real64): s1.
      REAL(R8) :: S2                                                     ! Real (real64): s2.
      REAL(R8) :: S3                                                     ! Real (real64): s3.
      REAL(R8) :: S4                                                     ! Real (real64): s4.
      REAL(R8) :: S                                                      ! Real (real64): s.
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: J0                                                  ! Integer (int32): j0.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.
      INTEGER(I4) :: CI                                                  ! Integer (int32): ci.
      INTEGER(I4) :: CJ                                                  ! Integer (int32): cj.
      INTEGER(I4) :: JEND                                                ! Integer (int32): jend.
      INTEGER(I4) :: C1                                                  ! Integer (int32): c1.
      INTEGER(I4) :: C2                                                  ! Integer (int32): c2.
      INTEGER(I4) :: C3                                                  ! Integer (int32): c3.
      INTEGER(I4) :: C4                                                  ! Integer (int32): c4.
      LOGICAL :: SELECTED                                                ! Logical: selected.

      SELECTED = PRESENT(INDEX)                                          ! Set selected to present(index).
      N = SIZE(A,2)                                                      ! Set n to size(a,2).
      IF (SELECTED) N = SIZE(INDEX)                                      ! If selected, set n to the size of index.
      DO J0 = 1_I4, N, 4_I4                                              ! Loop j0 from 1 to n in steps of 4:
        JEND = MIN(J0+3_I4, N)                                           ! Set jend to the smaller of j0+3 and n.
        C1 = COLUMN(J0)                                                  ! Set c1 to column(j0).
        C2 = COLUMN(MIN(J0+1_I4,N))                                      ! Set c2 to column(min(j0+1,n)).
        C3 = COLUMN(MIN(J0+2_I4,N))                                      ! Set c3 to column(min(j0+2,n)).
        C4 = COLUMN(JEND)                                                ! Set c4 to column(jend).
        DO I = 1_I4, J0-1_I4                                             ! Loop i from 1 to j0-1:
          CI = I                                                         ! Set ci to i.
          IF (SELECTED) CI = INDEX(I)                                    ! If selected, set ci to index(i).
          IF (JEND .EQ. J0+3_I4) THEN                                    ! If jend = j0+3:
            S1 = 0.0_R8                                                  ! Set s1 to zero.
            S2 = 0.0_R8                                                  ! Set s2 to zero.
            S3 = 0.0_R8                                                  ! Set s3 to zero.
            S4 = 0.0_R8                                                  ! Set s4 to zero.
            DO Q = 1_I4, ROWS                                            ! Loop q from 1 to rows:
              S1 = S1 + A(Q,CI)*B(Q,C1)                                  ! Add a(q,ci)*b(q,c1) to s1.
              S2 = S2 + A(Q,CI)*B(Q,C2)                                  ! Add a(q,ci)*b(q,c2) to s2.
              S3 = S3 + A(Q,CI)*B(Q,C3)                                  ! Add a(q,ci)*b(q,c3) to s3.
              S4 = S4 + A(Q,CI)*B(Q,C4)                                  ! Add a(q,ci)*b(q,c4) to s4.
            END DO                                                       ! End of the loop.
            CALL ADD_ENTRY(CI, J0, S1)                                   ! Call add entry with ci, j0, s1.
            CALL ADD_ENTRY(CI, J0+1_I4, S2)                              ! Call add entry with ci, j0+1, s2.
            CALL ADD_ENTRY(CI, J0+2_I4, S3)                              ! Call add entry with ci, j0+2, s3.
            CALL ADD_ENTRY(CI, J0+3_I4, S4)                              ! Call add entry with ci, j0+3, s4.
          ELSE                                                           ! Otherwise:
            DO J = J0, JEND                                              ! Loop j from j0 to jend:
              S = 0.0_R8                                                 ! Set s to zero.
              DO Q = 1_I4, ROWS                                          ! Loop q from 1 to rows:
                S = S + A(Q,CI)*B(Q,COLUMN(J))                           ! Add a(q,ci)*b(q,column(j)) to s.
              END DO                                                     ! End of the loop.
              CALL ADD_ENTRY(CI, J, S)                                   ! Call add entry with ci, j, s.
            END DO                                                       ! End of the loop.
          END IF                                                         ! End of the IF block.
        END DO                                                           ! End of the loop.
!       DIAGONAL BLOCK: ONLY ENTRIES WITH I <= J
        DO J = J0, JEND                                                  ! Loop j from j0 to jend:
          CJ = COLUMN(J)                                                 ! Set cj to column(j).
          DO I = J0, J                                                   ! Loop i from j0 to j:
            CI = COLUMN(I)                                               ! Set ci to column(i).
            S = 0.0_R8                                                   ! Set s to zero.
            DO Q = 1_I4, ROWS                                            ! Loop q from 1 to rows:
              S = S + A(Q,CI)*B(Q,CJ)                                    ! Add a(q,ci)*b(q,cj) to s.
            END DO                                                       ! End of the loop.
            CALL ADD_ENTRY(CI, J, S)                                     ! Call add entry with ci, j, s.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      CONTAINS                                                           ! The procedures of the module follow.

      INTEGER(I4) FUNCTION COLUMN(K)                                     ! Function column takes k.
      INTEGER(I4), INTENT(IN) :: K                                       ! Input integer (int32): k.
      COLUMN = K                                                         ! Set column to k.
      IF (SELECTED) COLUMN = INDEX(K)                                    ! If selected, set column to index(k).
      END FUNCTION COLUMN                                                ! End of the function column.

      SUBROUTINE ADD_ENTRY(ROW_COLUMN, K, VALUE)                         ! Subroutine add entry takes row column, k, value.
      INTEGER(I4), INTENT(IN) :: ROW_COLUMN                              ! Input integer (int32): row_column.
      INTEGER(I4), INTENT(IN) :: K                                       ! Input integer (int32): k.
      REAL(R8), INTENT(IN) :: VALUE                                      ! Input real (real64): value.
      MATRIX(ROW_COLUMN,COLUMN(K)) = MATRIX(ROW_COLUMN,COLUMN(K))        ! Add value to matrix(row_column,column(k)).
     &                               + VALUE
      END SUBROUTINE ADD_ENTRY                                           ! End of the subroutine add entry.

      END SUBROUTINE ACCUMULATE_UPPER_PRODUCT                            ! End of the subroutine accumulate upper product.


!  MATRIX(I,J) += SUM_Q A(Q,I) * B(Q,J) FOR ALL I, J.
      SUBROUTINE ACCUMULATE_PRODUCT(A, B, ROWS, MATRIX)                  ! Subroutine accumulate product takes a, b, rows, matrix.

      REAL(R8), INTENT(IN) :: A(:,:)                                     ! Input real (real64): a(:,:).
      REAL(R8), INTENT(IN) :: B(:,:)                                     ! Input real (real64): b(:,:).
      INTEGER(I4), INTENT(IN) :: ROWS                                    ! Input integer (int32): rows.
      REAL(R8), INTENT(INOUT) :: MATRIX(:,:)                             ! In/out real (real64): matrix(:,:).
      REAL(R8) :: S1                                                     ! Real (real64): s1.
      REAL(R8) :: S2                                                     ! Real (real64): s2.
      REAL(R8) :: S3                                                     ! Real (real64): s3.
      REAL(R8) :: S4                                                     ! Real (real64): s4.
      INTEGER(I4) :: J0                                                  ! Integer (int32): j0.
      INTEGER(I4) :: J                                                   ! Integer (int32): j.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: Q                                                   ! Integer (int32): q.

      DO J0 = 1_I4, SIZE(B,2)-3_I4, 4_I4                                 ! Loop j0 from 1 to size(b,2)-3 in steps of 4:
        DO I = 1_I4, SIZE(A,2)                                           ! Loop i from 1 to size(a,2):
          S1 = 0.0_R8                                                    ! Set s1 to zero.
          S2 = 0.0_R8                                                    ! Set s2 to zero.
          S3 = 0.0_R8                                                    ! Set s3 to zero.
          S4 = 0.0_R8                                                    ! Set s4 to zero.
          DO Q = 1_I4, ROWS                                              ! Loop q from 1 to rows:
            S1 = S1 + A(Q,I)*B(Q,J0)                                     ! Add a(q,i)*b(q,j0) to s1.
            S2 = S2 + A(Q,I)*B(Q,J0+1_I4)                                ! Add a(q,i)*b(q,j0+1) to s2.
            S3 = S3 + A(Q,I)*B(Q,J0+2_I4)                                ! Add a(q,i)*b(q,j0+2) to s3.
            S4 = S4 + A(Q,I)*B(Q,J0+3_I4)                                ! Add a(q,i)*b(q,j0+3) to s4.
          END DO                                                         ! End of the loop.
          MATRIX(I,J0) = MATRIX(I,J0) + S1                               ! Add s1 to matrix(i,j0).
          MATRIX(I,J0+1_I4) = MATRIX(I,J0+1_I4) + S2                     ! Add s2 to matrix(i,j0+1).
          MATRIX(I,J0+2_I4) = MATRIX(I,J0+2_I4) + S3                     ! Add s3 to matrix(i,j0+2).
          MATRIX(I,J0+3_I4) = MATRIX(I,J0+3_I4) + S4                     ! Add s4 to matrix(i,j0+3).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      DO J = 4_I4*(SIZE(B,2)/4_I4)+1_I4, SIZE(B,2)                       ! Loop j from 4*(size(b,2)/4)+1 to size(b,2):
        DO I = 1_I4, SIZE(A,2)                                           ! Loop i from 1 to size(a,2):
          S1 = 0.0_R8                                                    ! Set s1 to zero.
          DO Q = 1_I4, ROWS                                              ! Loop q from 1 to rows:
            S1 = S1 + A(Q,I)*B(Q,J)                                      ! Add a(q,i)*b(q,j) to s1.
          END DO                                                         ! End of the loop.
          MATRIX(I,J) = MATRIX(I,J) + S1                                 ! Add s1 to matrix(i,j).
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE ACCUMULATE_PRODUCT                                  ! End of the subroutine accumulate product.
      END MODULE MUL2_DENSE_PRODUCTS                                     ! End of the module mul2 dense products.