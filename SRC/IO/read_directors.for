!=======================================================================
!  READER OF DIRECTORS.DAT (OPTIONAL FILE).
!
!  EXACT DIRECTORS (NORMALS) OF THE SHELL NODES, WHEN THE GEOMETRY IS
!  KNOWN (CAD, ANALYTIC SURFACE). WITHOUT THE FILE, OR FOR THE NODES
!  THAT ARE NOT LISTED, THE DIRECTOR IS THE AVERAGE OF THE NORMALS OF
!  THE ELEMENTS THAT SHARE THE NODE.
!      N_DIRECTORS
!      NODE_ID VX VY VZ          (N_DIRECTORS LINES, NOT NORMALISED)
!=======================================================================
      MODULE MUL2_READ_DIRECTORS                                         ! Module mul2 read directors begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR        ! Use from module mul2 status: status type, clear status, set error.
      USE MUL2_TEXT_IO, ONLY: NEXT_DATA_LINE                             ! Use from module mul2 text io: next data line.
      USE MUL2_NODES, ONLY: NODE_DB_TYPE, FIND_NODE_INDEX                ! Use from module mul2 nodes: node db type, find node index.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: READ_DIRECTORS_FILE                                      ! Export: read directors file.

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE READ_DIRECTORS_FILE(FILE_NAME, NODES, STATUS)           ! Subroutine read directors file takes file name, nodes, status.

      CHARACTER(LEN=*), INTENT(IN) :: FILE_NAME                          ! Input character (length *): file_name.
      TYPE(NODE_DB_TYPE), INTENT(INOUT) :: NODES                         ! In/out of type node_db_type: nodes.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      CHARACTER(LEN=512) :: LINE                                         ! Character (length 512): line.
      REAL(R8) :: V(3)                                                   ! Real (real64): v(3).
      REAL(R8) :: LENGTH                                                 ! Real (real64): length.
      INTEGER(I8) :: ID                                                  ! Integer (int64): id.
      INTEGER(I4) :: COUNT                                               ! Integer (int32): count.
      INTEGER(I4) :: INDEX                                               ! Integer (int32): index.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER :: UNIT                                                    ! Integer: unit.
      INTEGER :: IOS                                                     ! Integer: ios.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ',    ! Open the file file_name.
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) RETURN                                             ! If ios /= 0, return to the caller.
      CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                               ! Call next data line with unit, line, ios.
      IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) COUNT                      ! If ios = 0, read from the text line into count.
      IF (IOS .NE. 0 .OR. COUNT .LT. 0_I4) THEN                          ! If ios /= 0 or count < 0:
        CALL SET_ERROR(STATUS, 'READ_DIRECTORS_FILE',                    ! Record an error in status: 'INVALID NUMBER OF DIRECTORS'.
     &                 'INVALID NUMBER OF DIRECTORS')
        CLOSE(UNIT)                                                      ! Close the file.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      DO I = 1_I4, COUNT                                                 ! Loop i from 1 to count:
        CALL NEXT_DATA_LINE(UNIT, LINE, IOS)                             ! Call next data line with unit, line, ios.
        IF (IOS .EQ. 0) READ(LINE,*,IOSTAT=IOS) ID, V                    ! If ios = 0, read from the text line into id, v.
        IF (IOS .NE. 0) THEN                                             ! If ios /= 0:
          CALL SET_ERROR(STATUS, 'READ_DIRECTORS_FILE',                  ! Record an error in status: 'INVALID DIRECTOR (NODE_ID VX VY VZ)'.
     &                   'INVALID DIRECTOR (NODE_ID VX VY VZ)')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        INDEX = FIND_NODE_INDEX(NODES, ID)                               ! Set index to find_node_index(nodes, id).
        LENGTH = SQRT(DOT_PRODUCT(V,V))                                  ! Set length to the square root of dot_product(v,v).
        IF (INDEX .EQ. 0_I4 .OR. LENGTH .LE. 1.0E-12_R8) THEN            ! If index = 0 or length <= 1.0e-12:
          CALL SET_ERROR(STATUS, 'READ_DIRECTORS_FILE',                  ! Record an error in status: 'DIRECTOR OF AN UNKNOWN NODE OR ZERO VECTOR'.
     &                   'DIRECTOR OF AN UNKNOWN NODE OR ZERO VECTOR')
          CLOSE(UNIT)                                                    ! Close the file.
          RETURN                                                         ! Return to the caller.
        END IF                                                           ! End of the IF block.
        NODES%ITEM(INDEX)%DIRECTOR = V/LENGTH                            ! Set nodes.item(index).director to v/length.
        NODES%ITEM(INDEX)%HAS_DIRECTOR = .TRUE.                          ! Set the flag nodes.item(index).has_director to true.
      END DO                                                             ! End of the loop.
      CLOSE(UNIT)                                                        ! Close the file.

      END SUBROUTINE READ_DIRECTORS_FILE                                 ! End of the subroutine read directors file.

      END MODULE MUL2_READ_DIRECTORS                                     ! End of the module mul2 read directors.
