!=======================================================================
!  NUMERIC KINDS USED BY THE WHOLE CODE.
!=======================================================================
      MODULE MUL2_KINDS                                                  ! Module mul2 kinds begins.

      USE, INTRINSIC :: ISO_FORTRAN_ENV, ONLY:                           ! Use from module iso fortran env: int32, int64, real64.
     &                  INT32, INT64, REAL64

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER, PARAMETER, PUBLIC :: I4 = INT32                           ! Constant public integer: i4 = int32.
      INTEGER, PARAMETER, PUBLIC :: I8 = INT64                           ! Constant public integer: i8 = int64.
      INTEGER, PARAMETER, PUBLIC :: R8 = REAL64                          ! Constant public integer: r8 = real64.

      END MODULE MUL2_KINDS                                              ! End of the module mul2 kinds.
