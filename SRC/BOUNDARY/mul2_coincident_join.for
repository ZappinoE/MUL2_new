!=======================================================================
!  JOINING OF DEGREES OF FREEDOM BY COINCIDENCE OF THEIR POSITIONS.
!
!  THE ORDINARY JOINT IS THE SHARED NODE (SAME NODE NUMBER IN THE
!  ELEMENTS). WITH `JOIN COINCIDENT` IN ANALYSIS.DAT THE DEGREES OF
!  FREEDOM OF DIFFERENT NODES ARE ALSO IDENTIFIED WHEN THEY ARE THE SAME
!  FIELD AT THE SAME POINT OF SPACE, AS IN THE HISTORICAL CODE: A BEAM
!  WHOSE SECTION NODE LIES ON A PLATE JOINS THE PLATE EVEN IF THE
!  STRUCTURAL NODES OF THE TWO ELEMENTS ARE DIFFERENT.
!    LE  THE DOF OF A NODE OF THE EXPANSION MESH IS THE FIELD AT THE
!        POINT  X(NODE) + OFFSET(EXPANSION NODE).
!    TE  THE TERM 1 (THE FIELD AT THE NODE) IS JOINED AT THE SAME
!        POINT; THE HIGHER TERMS ONLY WHEN THE TWO ELEMENTS HAVE THE
!        SAME ORIENTATION (THEY ARE DERIVATIVES ALONG THE ELEMENT AXES).
!    HLE NOT JOINED (SIDE AND INTERNAL MODES ARE NOT VALUES).
!  THE DOF ARE RENUMBERED: THE ALIAS TABLE OF THE LAYOUT MAPS EVERY
!  PROVISIONAL DOF TO ITS FINAL NUMBER (GLOBAL_DOF APPLIES IT).
!=======================================================================
      MODULE MUL2_COINCIDENT_JOIN                                        ! Module mul2 coincident join begins.

      USE MUL2_KINDS, ONLY: I4, I8, R8                                   ! Use from module mul2 kinds: i4, i8, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS,                  ! Use from module mul2 status: status type, clear status, set warning, set error, status is ok.
     &                       SET_WARNING, SET_ERROR, STATUS_IS_OK
      USE MUL2_NODES, ONLY: NODE_DB_TYPE                                 ! Use from module mul2 nodes: node db type.
      USE MUL2_INCIDENCE, ONLY: NODE_INCIDENCE_TYPE,                     ! Use from module mul2 incidence: node incidence type, build node incidence.
     &                          BUILD_NODE_INCIDENCE
      USE MUL2_ELEMENTS, ONLY: ELEMENT_DB_TYPE                           ! Use from module mul2 elements: element db type.
      USE MUL2_KINEMATICS, ONLY: KINEMATICS_DB_TYPE, N_FIELDS,           ! Use from module mul2 kinematics: kinematics db type, n fields, expansion le, expansion te, find kinematic i...
     &     EXPANSION_LE, EXPANSION_TE, FIND_KINEMATIC_INDEX
      USE MUL2_EXPANSION_MESHES, ONLY: EXPANSION_DB_TYPE,                ! Use from module mul2 expansion meshes: expansion db type, find expansion index.
     &                                 FIND_EXPANSION_INDEX
      USE MUL2_REFERENCE_SYSTEMS, ONLY: ELEMENT_FRAME_DB_TYPE            ! Use from module mul2 reference systems: element frame db type.
      USE MUL2_GENERAL_GEOMETRY, ONLY: IS_GENERAL_ELEMENT                ! Use from module mul2 general geometry: is general element.
      USE MUL2_DOF_LAYOUT, ONLY: DOF_LAYOUT_TYPE, GLOBAL_DOF             ! Use from module mul2 dof layout: dof layout type, global dof.
      USE MUL2_BOUNDARY_APPLICATION, ONLY: PLACED_POINT                  ! Use from module mul2 boundary application: placed point.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      PUBLIC :: JOIN_COINCIDENT_DOFS                                     ! Export: join coincident dofs.

      CONTAINS                                                           ! The procedures of the module follow.

!  RELATIVE_TOLERANCE IS A FRACTION OF THE DIAGONAL OF THE MODEL.
      SUBROUTINE JOIN_COINCIDENT_DOFS(NODES, ELEMENTS, KINEMATICS,       ! Subroutine join coincident dofs takes nodes, elements, kinematics, expansions, frames, relative tolerance, ...
     &     EXPANSIONS, FRAMES, RELATIVE_TOLERANCE, LAYOUT, STATUS)

      TYPE(NODE_DB_TYPE), INTENT(IN) :: NODES                            ! Input of type node_db_type: nodes.
      TYPE(ELEMENT_DB_TYPE), INTENT(IN) :: ELEMENTS                      ! Input of type element_db_type: elements.
      TYPE(KINEMATICS_DB_TYPE), INTENT(IN) :: KINEMATICS                 ! Input of type kinematics_db_type: kinematics.
      TYPE(EXPANSION_DB_TYPE), INTENT(IN) :: EXPANSIONS                  ! Input of type expansion_db_type: expansions.
      TYPE(ELEMENT_FRAME_DB_TYPE), INTENT(IN) :: FRAMES                  ! Input of type element_frame_db_type: frames.
      REAL(R8), INTENT(IN) :: RELATIVE_TOLERANCE                         ! Input real (real64): relative_tolerance.
      TYPE(DOF_LAYOUT_TYPE), INTENT(INOUT) :: LAYOUT                     ! In/out of type dof_layout_type: layout.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      TYPE(NODE_INCIDENCE_TYPE) :: INCIDENCE                             ! Of type node_incidence_type: incidence.
      TYPE(STATUS_TYPE) :: LOCAL_STATUS                                  ! Of type status_type: local_status.
      REAL(R8), ALLOCATABLE :: POS(:,:)                                  ! Allocatable real (real64): pos(:,:).
      INTEGER(I8), ALLOCATABLE :: PARENT(:)                              ! Allocatable integer (int64): parent(:).
      INTEGER(I8), ALLOCATABLE :: ENT_DOF(:)                             ! Allocatable integer (int64): ent_dof(:).
      INTEGER(I4), ALLOCATABLE :: ENT_FIELD(:)                           ! Allocatable integer (int32): ent_field(:).
      INTEGER(I4), ALLOCATABLE :: ENT_NODE(:)                            ! Allocatable integer (int32): ent_node(:).
      INTEGER(I4), ALLOCATABLE :: ENT_TERM(:)                            ! Allocatable integer (int32): ent_term(:).
      INTEGER(I4), ALLOCATABLE :: ENT_ELEM(:)                            ! Allocatable integer (int32): ent_elem(:).
      INTEGER(I4), ALLOCATABLE :: ENT_CLASS(:)                           ! Allocatable integer (int32): ent_class(:).
      INTEGER(I4), ALLOCATABLE :: BUCKET_FIRST(:)                        ! Allocatable integer (int32): bucket_first(:).
      INTEGER(I4), ALLOCATABLE :: BUCKET_ENTRY(:)                        ! Allocatable integer (int32): bucket_entry(:).
      INTEGER(I4), ALLOCATABLE :: BUCKET_OF(:)                           ! Allocatable integer (int32): bucket_of(:).
      INTEGER(I8), ALLOCATABLE :: NEW_ID(:)                              ! Allocatable integer (int64): new_id(:).
      REAL(R8) :: LOW(3)                                                 ! Real (real64): low(3).
      REAL(R8) :: HIGH(3)                                                ! Real (real64): high(3).
      REAL(R8) :: TOL                                                    ! Real (real64): tol.
      REAL(R8) :: CELL                                                   ! Real (real64): cell.
      REAL(R8) :: POINT(3)                                               ! Real (real64): point(3).
      REAL(R8) :: SHIFT(3)                                               ! Real (real64): shift(3).
      INTEGER(I8) :: N_PROVISIONAL                                       ! Integer (int64): n_provisional.
      INTEGER(I8) :: NEXT                                                ! Integer (int64): next.
      INTEGER(I8) :: P                                                   ! Integer (int64): p.
      INTEGER(I8) :: RA                                                  ! Integer (int64): ra.
      INTEGER(I8) :: RB                                                  ! Integer (int64): rb.
      INTEGER(I4) :: N_ENTRY                                             ! Integer (int32): n_entry.
      INTEGER(I4) :: N_BUCKET                                            ! Integer (int32): n_bucket.
      INTEGER(I4) :: N_JOINED                                            ! Integer (int32): n_joined.
      INTEGER(I4) :: I                                                   ! Integer (int32): i.
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: B                                                   ! Integer (int32): b.
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: F                                                   ! Integer (int32): f.
      INTEGER(I4) :: T                                                   ! Integer (int32): t.
      INTEGER(I4) :: K                                                   ! Integer (int32): k.
      INTEGER(I4) :: MESH_INDEX                                          ! Integer (int32): mesh_index.
      INTEGER(I4) :: KIND_INDEX                                          ! Integer (int32): kind_index.
      INTEGER(I4) :: IX                                                  ! Integer (int32): ix.
      INTEGER(I4) :: IY                                                  ! Integer (int32): iy.
      INTEGER(I4) :: IZ                                                  ! Integer (int32): iz.
      INTEGER(I4) :: CX                                                  ! Integer (int32): cx.
      INTEGER(I4) :: CY                                                  ! Integer (int32): cy.
      INTEGER(I4) :: CZ                                                  ! Integer (int32): cz.
      INTEGER(I4) :: BK                                                  ! Integer (int32): bk.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      N_PROVISIONAL = LAYOUT%TOTAL_DOF                                   ! Set n_provisional to layout.total_dof.
      IF (ALLOCATED(LAYOUT%ALIAS)) DEALLOCATE(LAYOUT%ALIAS)              ! If allocated(layout.alias), free the memory of layout.alias.
      IF (N_PROVISIONAL .LT. 2_I8) RETURN                                ! If n_provisional < 2, return to the caller.
      CALL BUILD_NODE_INCIDENCE(NODES, ELEMENTS, INCIDENCE,              ! Call build node incidence with nodes, elements, incidence, local_status.
     &                          LOCAL_STATUS)
      IF (.NOT. STATUS_IS_OK(LOCAL_STATUS)) THEN                         ! If not local_status is ok:
        STATUS = LOCAL_STATUS                                            ! Set status to local_status.
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.

!     1. THE POSITION OF EVERY JOINABLE DEGREE OF FREEDOM.
      ALLOCATE(POS(3,N_PROVISIONAL), ENT_DOF(N_PROVISIONAL))             ! Allocate memory for pos(3,n_provisional), ent_dof(n_provisional).
      ALLOCATE(ENT_FIELD(N_PROVISIONAL), ENT_NODE(N_PROVISIONAL))        ! Allocate memory for ent_field(n_provisional), ent_node(n_provisional).
      ALLOCATE(ENT_TERM(N_PROVISIONAL), ENT_ELEM(N_PROVISIONAL))         ! Allocate memory for ent_term(n_provisional), ent_elem(n_provisional).
      ALLOCATE(ENT_CLASS(N_PROVISIONAL))                                 ! Allocate memory for ent_class(n_provisional).
      N_ENTRY = 0_I4                                                     ! Set n_entry to zero.
      DO I = 1_I4, SIZE(NODES%ITEM)                                      ! Loop i from 1 to size(nodes.item):
        IF (INCIDENCE%FIRST(I+1) .EQ. INCIDENCE%FIRST(I)) CYCLE          ! If incidence.first(i+1) = incidence.first(i), skip to the next iteration.
        E = INCIDENCE%ELEMENT(INCIDENCE%FIRST(I))                        ! Set e to incidence.element(incidence.first(i)).
        KIND_INDEX = FIND_KINEMATIC_INDEX(KINEMATICS,                    ! Set kind_index to find_kinematic_index(kinematics, nodes.item(i).kinematic_id).
     &                                    NODES%ITEM(I)%KINEMATIC_ID)
        MESH_INDEX = FIND_EXPANSION_INDEX(EXPANSIONS,                    ! Set mesh_index to find_expansion_index(expansions, elements.item(e).expansion_id).
     &                                    ELEMENTS%ITEM(E)%EXPANSION_ID)
        IF (KIND_INDEX .EQ. 0_I4 .OR. MESH_INDEX .EQ. 0_I4) CYCLE        ! If kind_index = 0 or mesh_index = 0, skip to the next iteration.
        DO F = 1_I4, N_FIELDS                                            ! Loop f from 1 to n_fields:
          SELECT CASE (KINEMATICS%ITEM(KIND_INDEX)%FIELD(F)%FAMILY)      ! Choose according to the value of kinematics.item(kind_index).field(f).family:
          CASE (EXPANSION_LE)                                            ! Case expansion_le:
            DO T = 1_I4, LAYOUT%TERM_COUNT(I,F)                          ! Loop t from 1 to layout.term_count(i,f):
              IF (T .GT. SIZE(EXPANSIONS%ITEM(MESH_INDEX)%NODE)) EXIT    ! If t > size(expansions.item(mesh_index).node), leave the loop.
              CALL PLACED_POINT(NODES, ELEMENTS, FRAMES, E, I,           ! Call placed point with nodes, elements, frames, e, i, expansions.item(mesh_index).node(t).coordinate, point.
     &          EXPANSIONS%ITEM(MESH_INDEX)%NODE(T)%COORDINATE, POINT)
              CALL ADD_ENTRY(1_I4, T)                                    ! Call add entry with 1, t.
            END DO                                                       ! End of the loop.
          CASE (EXPANSION_TE)                                            ! Case expansion_te:
            DO T = 1_I4, LAYOUT%TERM_COUNT(I,F)                          ! Loop t from 1 to layout.term_count(i,f):
              POINT = NODES%ITEM(I)%COORDINATE                           ! Set point to nodes.item(i).coordinate.
              CALL ADD_ENTRY(2_I4, T)                                    ! Call add entry with 2, t.
            END DO                                                       ! End of the loop.
          CASE DEFAULT                                                   ! In every other case:
            CONTINUE                                                     ! No operation (loop terminator).
          END SELECT                                                     ! End of the case selection.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.
      IF (N_ENTRY .LT. 2_I4) GO TO 900                                   ! If n_entry < 2, jump to label 900.

!     2. TOLERANCE: A FRACTION OF THE DIAGONAL OF THE POINTS.
      LOW = MINVAL(POS(:,1:N_ENTRY), DIM=2)                              ! Set low to minval(pos(:,1:n_entry), dim=2).
      HIGH = MAXVAL(POS(:,1:N_ENTRY), DIM=2)                             ! Set high to maxval(pos(:,1:n_entry), dim=2).
      TOL = RELATIVE_TOLERANCE*SQRT(SUM((HIGH-LOW)**2))                  ! Set tol to relative_tolerance*sqrt(sum((high-low)**2)).
      IF (TOL .LE. 0.0_R8) GO TO 900                                     ! If tol <= 0.0, jump to label 900.
      CELL = 2.0_R8*TOL                                                  ! Set cell to 2.0*tol.

!     3. BUCKETS OF A SPATIAL HASH (COUNTING SORT).
      N_BUCKET = MAX(N_ENTRY, 16_I4)                                     ! Set n_bucket to the larger of n_entry and 16.
      ALLOCATE(BUCKET_FIRST(N_BUCKET+1), BUCKET_ENTRY(N_ENTRY))          ! Allocate memory for bucket_first(n_bucket+1), bucket_entry(n_entry).
      ALLOCATE(BUCKET_OF(N_ENTRY))                                       ! Allocate memory for bucket_of(n_entry).
      BUCKET_FIRST = 0_I4                                                ! Set bucket_first to zero.
      DO A = 1_I4, N_ENTRY                                               ! Loop a from 1 to n_entry:
        CALL CELL_OF(POS(:,A), IX, IY, IZ)                               ! Call cell of with pos(:,a), ix, iy, iz.
        BUCKET_OF(A) = BUCKET_INDEX(IX, IY, IZ)                          ! Set bucket_of(a) to bucket_index(ix, iy, iz).
        BUCKET_FIRST(BUCKET_OF(A)+1) = BUCKET_FIRST(BUCKET_OF(A)+1) +    ! Add 1 to bucket_first(bucket_of(a)+1).
     &                                 1_I4
      END DO                                                             ! End of the loop.
      BUCKET_FIRST(1) = 1_I4                                             ! Set bucket_first(1) to 1.
      DO K = 1_I4, N_BUCKET                                              ! Loop k from 1 to n_bucket:
        BUCKET_FIRST(K+1) = BUCKET_FIRST(K+1) + BUCKET_FIRST(K)          ! Add bucket_first(k) to bucket_first(k+1).
      END DO                                                             ! End of the loop.
      DO A = 1_I4, N_ENTRY                                               ! Loop a from 1 to n_entry:
        BUCKET_ENTRY(BUCKET_FIRST(BUCKET_OF(A))) = A                     ! Set bucket_entry(bucket_first(bucket_of(a))) to a.
        BUCKET_FIRST(BUCKET_OF(A)) = BUCKET_FIRST(BUCKET_OF(A)) + 1_I4   ! Add 1 to bucket_first(bucket_of(a)).
      END DO                                                             ! End of the loop.
!     THE FILL ABOVE ADVANCED THE POINTERS: RESTORE THE STARTS.
      DO K = N_BUCKET, 2_I4, -1_I4                                       ! Loop k from n_bucket to 2 in steps of -1:
        BUCKET_FIRST(K) = BUCKET_FIRST(K-1)                              ! Set bucket_first(k) to bucket_first(k-1).
      END DO                                                             ! End of the loop.
      BUCKET_FIRST(1) = 1_I4                                             ! Set bucket_first(1) to 1.

!     4. UNION OF THE COINCIDENT PAIRS.
      ALLOCATE(PARENT(N_PROVISIONAL))                                    ! Allocate memory for parent(n_provisional).
      DO P = 1_I8, N_PROVISIONAL                                         ! Loop p from 1 to n_provisional:
        PARENT(P) = P                                                    ! Set parent(p) to p.
      END DO                                                             ! End of the loop.
      DO A = 1_I4, N_ENTRY                                               ! Loop a from 1 to n_entry:
        CALL CELL_OF(POS(:,A), IX, IY, IZ)                               ! Call cell of with pos(:,a), ix, iy, iz.
        DO CX = IX-1_I4, IX+1_I4                                         ! Loop cx from ix-1 to ix+1:
          DO CY = IY-1_I4, IY+1_I4                                       ! Loop cy from iy-1 to iy+1:
            DO CZ = IZ-1_I4, IZ+1_I4                                     ! Loop cz from iz-1 to iz+1:
              BK = BUCKET_INDEX(CX, CY, CZ)                              ! Set bk to bucket_index(cx, cy, cz).
              DO K = BUCKET_FIRST(BK), BUCKET_FIRST(BK+1)-1_I4           ! Loop k from bucket_first(bk) to bucket_first(bk+1)-1:
                B = BUCKET_ENTRY(K)                                      ! Set b to bucket_entry(k).
                IF (B .LE. A) CYCLE                                      ! If b <= a, skip to the next iteration.
                IF (.NOT. JOINABLE(A, B)) CYCLE                          ! If not joinable(a, b), skip to the next iteration.
                RA = FIND_ROOT(ENT_DOF(A))                               ! Set ra to find_root(ent_dof(a)).
                RB = FIND_ROOT(ENT_DOF(B))                               ! Set rb to find_root(ent_dof(b)).
                IF (RA .NE. RB) PARENT(MAX(RA,RB)) = MIN(RA,RB)          ! If ra /= rb, set parent(max(ra,rb)) to the smaller of ra and rb.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

!     5. RENUMBERING.
      ALLOCATE(NEW_ID(N_PROVISIONAL))                                    ! Allocate memory for new_id(n_provisional).
      NEW_ID = 0_I8                                                      ! Set new_id to zero.
      IF (ALLOCATED(LAYOUT%ALIAS)) DEALLOCATE(LAYOUT%ALIAS)              ! If allocated(layout.alias), free the memory of layout.alias.
      ALLOCATE(LAYOUT%ALIAS(N_PROVISIONAL))                              ! Allocate memory for layout.alias(n_provisional).
      NEXT = 0_I8                                                        ! Set next to zero.
      DO P = 1_I8, N_PROVISIONAL                                         ! Loop p from 1 to n_provisional:
        RA = FIND_ROOT(P)                                                ! Set ra to find_root(p).
        IF (NEW_ID(RA) .EQ. 0_I8) THEN                                   ! If new_id(ra) = 0:
          NEXT = NEXT + 1_I8                                             ! Add 1 to next.
          NEW_ID(RA) = NEXT                                              ! Set new_id(ra) to next.
        END IF                                                           ! End of the IF block.
        LAYOUT%ALIAS(P) = NEW_ID(RA)                                     ! Set layout.alias(p) to new_id(ra).
      END DO                                                             ! End of the loop.
      N_JOINED = INT(N_PROVISIONAL - NEXT, I4)                           ! Set n_joined to int(n_provisional - next, i4).
      IF (N_JOINED .EQ. 0_I4) THEN                                       ! If n_joined = 0:
        DEALLOCATE(LAYOUT%ALIAS)                                         ! Free the memory of layout.alias.
      ELSE                                                               ! Otherwise:
        LAYOUT%TOTAL_DOF = NEXT                                          ! Set layout.total_dof to next.
      END IF                                                             ! End of the IF block.
      IF (N_JOINED .GT. 0_I4) THEN                                       ! If n_joined > 0:
        CALL SET_WARNING(STATUS, 'JOIN_COINCIDENT_DOFS',                 ! Record a warning in status: 'DEGREES OF FREEDOM JOINED BY COINCIDENCE (JOIN COINCIDENT)'.
     &    'DEGREES OF FREEDOM JOINED BY COINCIDENCE (JOIN COINCIDENT)')
      ELSE                                                               ! Otherwise:
        CALL SET_WARNING(STATUS, 'JOIN_COINCIDENT_DOFS',                 ! Record a warning in status: 'JOIN COINCIDENT FOUND NO COINCIDENT DEGREES OF FREEDOM'.
     &    'JOIN COINCIDENT FOUND NO COINCIDENT DEGREES OF FREEDOM')
      END IF                                                             ! End of the IF block.
      RETURN                                                             ! Return to the caller.

  900 CONTINUE                                                           ! No operation (loop terminator).
      CALL SET_WARNING(STATUS, 'JOIN_COINCIDENT_DOFS',                   ! Record a warning in status: 'JOIN COINCIDENT FOUND NO JOINABLE DEGREES OF FREEDOM'.
     &  'JOIN COINCIDENT FOUND NO JOINABLE DEGREES OF FREEDOM')

      CONTAINS                                                           ! The procedures of the module follow.

      SUBROUTINE ADD_ENTRY(CLASS, TERM)                                  ! Subroutine add entry takes class, term.
      INTEGER(I4), INTENT(IN) :: CLASS                                   ! Input integer (int32): class.
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.
      N_ENTRY = N_ENTRY + 1_I4                                           ! Add 1 to n_entry.
      POS(:,N_ENTRY) = POINT                                             ! Set pos(:,n_entry) to point.
      ENT_DOF(N_ENTRY) = GLOBAL_DOF_RAW(I, F, TERM)                      ! Set ent_dof(n_entry) to global_dof_raw(i, f, term).
      ENT_FIELD(N_ENTRY) = F                                             ! Set ent_field(n_entry) to f.
      ENT_NODE(N_ENTRY) = I                                              ! Set ent_node(n_entry) to i.
      ENT_TERM(N_ENTRY) = TERM                                           ! Set ent_term(n_entry) to term.
      ENT_ELEM(N_ENTRY) = E                                              ! Set ent_elem(n_entry) to e.
      ENT_CLASS(N_ENTRY) = CLASS                                         ! Set ent_class(n_entry) to class.
      END SUBROUTINE ADD_ENTRY                                           ! End of the subroutine add entry.

!     DOF NUMBER BEFORE ANY ALIAS (THE LAYOUT HAS NONE YET).
      INTEGER(I8) FUNCTION GLOBAL_DOF_RAW(NODE, FIELD, TERM)             ! Function global dof raw takes node, field, term.
      INTEGER(I4), INTENT(IN) :: NODE                                    ! Input integer (int32): node.
      INTEGER(I4), INTENT(IN) :: FIELD                                   ! Input integer (int32): field.
      INTEGER(I4), INTENT(IN) :: TERM                                    ! Input integer (int32): term.
      GLOBAL_DOF_RAW = GLOBAL_DOF(LAYOUT, NODE, FIELD, TERM)             ! Set global_dof_raw to global_dof(layout, node, field, term).
      END FUNCTION GLOBAL_DOF_RAW                                        ! End of the function global dof raw.

      SUBROUTINE CELL_OF(X, JX, JY, JZ)                                  ! Subroutine cell of takes x, jx, jy, jz.
      REAL(R8), INTENT(IN) :: X(3)                                       ! Input real (real64): x(3).
      INTEGER(I4), INTENT(OUT) :: JX                                     ! Output integer (int32): jx.
      INTEGER(I4), INTENT(OUT) :: JY                                     ! Output integer (int32): jy.
      INTEGER(I4), INTENT(OUT) :: JZ                                     ! Output integer (int32): jz.
      JX = INT(FLOOR((X(1)-LOW(1))/CELL), I4)                            ! Set jx to int(floor((x(1)-low(1))/cell), i4).
      JY = INT(FLOOR((X(2)-LOW(2))/CELL), I4)                            ! Set jy to int(floor((x(2)-low(2))/cell), i4).
      JZ = INT(FLOOR((X(3)-LOW(3))/CELL), I4)                            ! Set jz to int(floor((x(3)-low(3))/cell), i4).
      END SUBROUTINE CELL_OF                                             ! End of the subroutine cell of.

      INTEGER(I4) FUNCTION BUCKET_INDEX(JX, JY, JZ)                      ! Function bucket index takes jx, jy, jz.
      INTEGER(I4), INTENT(IN) :: JX                                      ! Input integer (int32): jx.
      INTEGER(I4), INTENT(IN) :: JY                                      ! Input integer (int32): jy.
      INTEGER(I4), INTENT(IN) :: JZ                                      ! Input integer (int32): jz.
      INTEGER(I8) :: H                                                   ! Integer (int64): h.
      H = IEOR(IEOR(INT(JX,I8)*73856093_I8, INT(JY,I8)*19349663_I8),     ! Set h to ieor(ieor(int(jx,i8)*73856093, int(jy,i8)*19349663), int(jz,i8)*83492791).
     &         INT(JZ,I8)*83492791_I8)
      BUCKET_INDEX = INT(MOD(ABS(H), INT(N_BUCKET,I8)), I4) + 1_I4       ! Set bucket_index to int(mod(abs(h), int(n_bucket,i8)), i4) + 1.
      END FUNCTION BUCKET_INDEX                                          ! End of the function bucket index.

      INTEGER(I8) FUNCTION FIND_ROOT(START)                              ! Function find root takes start.
      INTEGER(I8), INTENT(IN) :: START                                   ! Input integer (int64): start.
      INTEGER(I8) :: R                                                   ! Integer (int64): r.
      INTEGER(I8) :: Q                                                   ! Integer (int64): q.
      INTEGER(I8) :: NEXT_Q                                              ! Integer (int64): next_q.
      R = START                                                          ! Set r to start.
      DO WHILE (PARENT(R) .NE. R)                                        ! Repeat while parent(r) /= r:
        R = PARENT(R)                                                    ! Set r to parent(r).
      END DO                                                             ! End of the loop.
      Q = START                                                          ! Set q to start.
      DO WHILE (PARENT(Q) .NE. R .AND. Q .NE. R)                         ! Repeat while parent(q) /= r and q /= r:
        NEXT_Q = PARENT(Q)                                               ! Set next_q to parent(q).
        PARENT(Q) = R                                                    ! Set parent(q) to r.
        Q = NEXT_Q                                                       ! Set q to next_q.
      END DO                                                             ! End of the loop.
      FIND_ROOT = R                                                      ! Set find_root to r.
      END FUNCTION FIND_ROOT                                             ! End of the function find root.

      LOGICAL FUNCTION JOINABLE(X, Y)                                    ! Function joinable takes x, y.
      INTEGER(I4), INTENT(IN) :: X                                       ! Input integer (int32): x.
      INTEGER(I4), INTENT(IN) :: Y                                       ! Input integer (int32): y.
      JOINABLE = .FALSE.                                                 ! Set the flag joinable to false.
      IF (ENT_NODE(X) .EQ. ENT_NODE(Y)) RETURN                           ! If ent_node(x) = ent_node(y), return to the caller.
      IF (ENT_FIELD(X) .NE. ENT_FIELD(Y)) RETURN                         ! If ent_field(x) /= ent_field(y), return to the caller.
      IF (ENT_CLASS(X) .NE. ENT_CLASS(Y)) RETURN                         ! If ent_class(x) /= ent_class(y), return to the caller.
      IF (SQRT(SUM((POS(:,X)-POS(:,Y))**2)) .GT. TOL) RETURN             ! If sqrt(sum((pos(:,x)-pos(:,y))**2)) > tol, return to the caller.
      IF (ENT_CLASS(X) .EQ. 2_I4) THEN                                   ! If ent_class(x) = 2:
        IF (ENT_TERM(X) .NE. ENT_TERM(Y)) RETURN                         ! If ent_term(x) /= ent_term(y), return to the caller.
        IF (ENT_TERM(X) .GT. 1_I4) THEN                                  ! If ent_term(x) > 1:
          IF (IS_GENERAL_ELEMENT(FRAMES,ENT_ELEM(X)) .OR.                ! If is_general_element(frames,ent_elem(x)) or is_general_element(frames,ent_elem(y)), return to the caller.
     &        IS_GENERAL_ELEMENT(FRAMES,ENT_ELEM(Y))) RETURN
          IF (SUM(ABS(FRAMES%LOCAL_TO_GLOBAL(:,:,ENT_ELEM(X)) -          ! If sum(abs(frames.local_to_global(:,:,ent_elem(x)) - frames.local_to_global(:,:,ent_elem(y)))) > 1.0e-6, re...
     &        FRAMES%LOCAL_TO_GLOBAL(:,:,ENT_ELEM(Y)))) .GT.
     &        1.0E-6_R8) RETURN
        END IF                                                           ! End of the IF block.
      END IF                                                             ! End of the IF block.
      JOINABLE = .TRUE.                                                  ! Set the flag joinable to true.
      END FUNCTION JOINABLE                                              ! End of the function joinable.

      END SUBROUTINE JOIN_COINCIDENT_DOFS                                ! End of the subroutine join coincident dofs.

      END MODULE MUL2_COINCIDENT_JOIN                                    ! End of the module mul2 coincident join.
