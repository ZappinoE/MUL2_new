!=======================================================================
!  HEAP SORT OF 64-BIT KEYS WITH A PERMUTATION, AND DUPLICATE SEARCH.
!=======================================================================
      MODULE MUL2_SORTING                                                ! Module mul2 sorting begins.

      USE MUL2_KINDS, ONLY: I4, I8                                       ! Use from module mul2 kinds: i4, i8.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: SORT_PERMUTATION                                         ! Export: sort permutation.
      PUBLIC :: BINARY_SEARCH                                            ! Export: binary search.
      PUBLIC :: HAS_DUPLICATE_KEYS                                       ! Export: has duplicate keys.

      CONTAINS                                                           ! The procedures of the module follow.

!  ORDER(1:N) = PERMUTATION SUCH THAT KEY(ORDER(1:N)) IS ASCENDING.
      SUBROUTINE SORT_PERMUTATION(KEY, ORDER)                            ! Subroutine sort permutation takes key, order.

      INTEGER(I8), INTENT(IN) :: KEY(:)                                  ! Input integer (int64): key(:).
      INTEGER(I4), INTENT(OUT) :: ORDER(:)                               ! Output integer (int32): order(:).
      INTEGER(I4) :: N                                                   ! Integer (int32): n.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: LAST                                                ! Integer (int32): last.
      INTEGER(I4) :: SWAP                                                ! Integer (int32): swap.

      N = SIZE(KEY)                                                      ! Set n to the size of key.
      DO I = 1_I4, N                                                     ! Loop i from 1 to n:
        ORDER(I) = I                                                     ! Set order(i) to i.
      END DO                                                             ! End of the loop.
      DO I = N/2_I4, 1_I4, -1_I4                                         ! Loop i from n/2 to 1 in steps of -1:
        CALL SIFT_DOWN(KEY, ORDER, I, N)                                 ! Call sift down with key, order, i, n.
      END DO                                                             ! End of the loop.
      DO LAST = N, 2_I4, -1_I4                                           ! Loop last from n to 2 in steps of -1:
        SWAP = ORDER(1)                                                  ! Set swap to order(1).
        ORDER(1) = ORDER(LAST)                                           ! Set order(1) to order(last).
        ORDER(LAST) = SWAP                                               ! Set order(last) to swap.
        CALL SIFT_DOWN(KEY, ORDER, 1_I4, LAST-1_I4)                      ! Call sift down with key, order, 1, last-1.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SORT_PERMUTATION                                    ! End of the subroutine sort permutation.

      SUBROUTINE SIFT_DOWN(KEY, ORDER, ROOT, LAST)                       ! Subroutine sift down takes key, order, root, last.

      INTEGER(I8), INTENT(IN) :: KEY(:)                                  ! Input integer (int64): key(:).
      INTEGER(I4), INTENT(INOUT) :: ORDER(:)                             ! In/out integer (int32): order(:).
      INTEGER(I4), INTENT(IN) :: ROOT                                    ! Input integer (int32): root.
      INTEGER(I4), INTENT(IN) :: LAST                                    ! Input integer (int32): last.
      INTEGER(I4) :: CURRENT                                             ! Integer (int32): current.
      INTEGER(I4) :: CHILD                                               ! Integer (int32): child.
      INTEGER(I4) :: SWAP                                                ! Integer (int32): swap.

      CURRENT = ROOT                                                     ! Set current to root.
      DO WHILE (2_I4*CURRENT .LE. LAST)                                  ! Repeat while 2*current <= last:
        CHILD = 2_I4*CURRENT                                             ! Set child to 2*current.
        IF (CHILD .LT. LAST) THEN                                        ! If child < last:
          IF (KEY(ORDER(CHILD)) .LT. KEY(ORDER(CHILD+1_I4)))             ! If key(order(child)) < key(order(child+1)), add 1 to child.
     &      CHILD = CHILD + 1_I4
        END IF                                                           ! End of the IF block.
        IF (KEY(ORDER(CURRENT)) .GE. KEY(ORDER(CHILD))) RETURN           ! If key(order(current)) >= key(order(child)), return to the caller.
        SWAP = ORDER(CURRENT)                                            ! Set swap to order(current).
        ORDER(CURRENT) = ORDER(CHILD)                                    ! Set order(current) to order(child).
        ORDER(CHILD) = SWAP                                              ! Set order(child) to swap.
        CURRENT = CHILD                                                  ! Set current to child.
      END DO                                                             ! End of the loop.

      END SUBROUTINE SIFT_DOWN                                           ! End of the subroutine sift down.

!  POSITION I OF TARGET IN SORTED_KEY(ORDER(1:N)) AS ORDER(I), OR 0.
      INTEGER(I4) FUNCTION BINARY_SEARCH(SORTED_KEY, ORDER, TARGET)      ! Function binary search takes sorted key, order, target.

      INTEGER(I8), INTENT(IN) :: SORTED_KEY(:)                           ! Input integer (int64): sorted_key(:).
      INTEGER(I4), INTENT(IN) :: ORDER(:)                                ! Input integer (int32): order(:).
      INTEGER(I8), INTENT(IN) :: TARGET                                  ! Input integer (int64): target.
      INTEGER(I4) :: LEFT                                                ! Integer (int32): left.
      INTEGER(I4) :: RIGHT                                               ! Integer (int32): right.
      INTEGER(I4) :: MIDDLE                                              ! Integer (int32): middle.

      BINARY_SEARCH = 0_I4                                               ! Set binary_search to zero.
      LEFT = 1_I4                                                        ! Set left to 1.
      RIGHT = SIZE(ORDER)                                                ! Set right to the size of order.
      DO WHILE (LEFT .LE. RIGHT)                                         ! Repeat while left <= right:
        MIDDLE = LEFT + (RIGHT-LEFT)/2_I4                                ! Set middle to left + (right-left)/2.
        IF (SORTED_KEY(ORDER(MIDDLE)) .EQ. TARGET) THEN                  ! If sorted_key(order(middle)) = target:
          BINARY_SEARCH = ORDER(MIDDLE)                                  ! Set binary_search to order(middle).
          RETURN                                                         ! Return to the caller.
        ELSE IF (SORTED_KEY(ORDER(MIDDLE)) .LT. TARGET) THEN             ! Otherwise, if sorted_key(order(middle)) < target:
          LEFT = MIDDLE + 1_I4                                           ! Set left to middle + 1.
        ELSE                                                             ! Otherwise:
          RIGHT = MIDDLE - 1_I4                                          ! Set right to middle - 1.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION BINARY_SEARCH                                         ! End of the function binary search.

      LOGICAL FUNCTION HAS_DUPLICATE_KEYS(KEY)                           ! Function has duplicate keys takes key.

      INTEGER(I8), INTENT(IN) :: KEY(:)                                  ! Input integer (int64): key(:).
      INTEGER(I4), ALLOCATABLE :: ORDER(:)                               ! Allocatable integer (int32): order(:).
      INTEGER(I4) :: I                                                   ! Integer (int32): i.

      HAS_DUPLICATE_KEYS = .FALSE.                                       ! Set the flag has_duplicate_keys to false.
      IF (SIZE(KEY) .LT. 2) RETURN                                       ! If size(key) < 2, return to the caller.
      ALLOCATE(ORDER(SIZE(KEY)))                                         ! Allocate memory for order(size(key)).
      CALL SORT_PERMUTATION(KEY, ORDER)                                  ! Call sort permutation with key, order.
      DO I = 2_I4, SIZE(KEY)                                             ! Loop i from 2 to size(key):
        IF (KEY(ORDER(I)) .EQ. KEY(ORDER(I-1_I4))) THEN                  ! If key(order(i)) = key(order(i-1)):
          HAS_DUPLICATE_KEYS = .TRUE.                                    ! Set the flag has_duplicate_keys to true.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
      END DO                                                             ! End of the loop.

      END FUNCTION HAS_DUPLICATE_KEYS                                    ! End of the function has duplicate keys.

      END MODULE MUL2_SORTING                                            ! End of the module mul2 sorting.
