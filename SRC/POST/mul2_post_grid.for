!=======================================================================
!  VISUALIZATION GRID: HEXAHEDRAL CELLS SAMPLING EVERY ELEMENT.
!
!  EACH ELEMENT / EXPANSION SUB-ELEMENT IS DIVIDED INTO R X S X L
!  CELLS. A CELL HAS 3 X 3 X 3 (QUADRATIC) OR 2 X 2 X 2 (LINEAR) NODES
!  AT NATURAL COORDINATES (XI, ETA, NU) IN [-1,1], ORDERED WITH XI
!  OUTERMOST AND NU INNERMOST. THE NATURAL TRIPLE IS SPLIT BETWEEN THE
!  STRUCTURAL ELEMENT AND THE EXPANSION ELEMENT BY ELEMENT DIMENSION:
!    BEAM  (1D): STRUCTURAL = (ETA)      EXPANSION = (XI, NU)
!    PLATE (2D): STRUCTURAL = (XI, ETA)  EXPANSION = (NU)
!    SOLID (3D): STRUCTURAL = (XI, ETA, NU)
!  TRIANGULAR PARENTS ARE REACHED WITH THE COLLAPSED MAP A = (1+X)/2,
!  B = (1+Y)/2 (1-A).
!=======================================================================
      MODULE MUL2_POST_GRID                                              ! Module mul2 post grid begins.

      USE MUL2_KINDS, ONLY: I4, R8                                       ! Use from module mul2 kinds: i4, r8.
      USE MUL2_STATUS, ONLY: STATUS_TYPE, CLEAR_STATUS, SET_ERROR,       ! Use from module mul2 status: status type, clear status, set error, status is ok.
     &                       STATUS_IS_OK
      USE MUL2_MODEL, ONLY: MODEL_TYPE                                   ! Use from module mul2 model: model type.
      USE MUL2_EXPANSION_MESHES, ONLY: FIND_EXPANSION_INDEX              ! Use from module mul2 expansion meshes: find expansion index.
      USE MUL2_TOPOLOGIES, ONLY: TOPOLOGY_NATURAL_DIMENSION,             ! Use from module mul2 topologies: topology natural dimension, topology t3, topology t6.
     &                           TOPOLOGY_T3, TOPOLOGY_T6

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      TYPE, PUBLIC :: POST_GRID_TYPE                                     ! Definition of the derived type post grid type.
        INTEGER(I4) :: NODES_PER_CELL = 27_I4                            ! Integer (int32): nodes_per_cell = 27.
        INTEGER(I4) :: CELL_COUNT = 0_I4                                 ! Integer (int32): cell_count = 0.
        INTEGER(I4) :: NODE_COUNT = 0_I4                                 ! Integer (int32): node_count = 0.
        INTEGER(I4), ALLOCATABLE :: CELL_ELEMENT(:)                      ! Allocatable integer (int32): cell_element(:).
        INTEGER(I4), ALLOCATABLE :: CELL_SUB_ELEMENT(:)                  ! Allocatable integer (int32): cell_sub_element(:).
        INTEGER(I4), ALLOCATABLE :: CELL_DIMENSION(:)                    ! Allocatable integer (int32): cell_dimension(:).
        REAL(R8), ALLOCATABLE :: NATURAL_STRUCTURAL(:,:)                 ! Allocatable real (real64): natural_structural(:,:).
        REAL(R8), ALLOCATABLE :: NATURAL_EXPANSION(:,:)                  ! Allocatable real (real64): natural_expansion(:,:).
      END TYPE POST_GRID_TYPE                                            ! End of the type definition post grid type.

      PUBLIC :: BUILD_POST_GRID                                          ! Export: build post grid.
      PUBLIC :: CLEAR_POST_GRID                                          ! Export: clear post grid.
      PUBLIC :: VTK_CELL_ORDER                                           ! Export: vtk cell order.
      PUBLIC :: GMSH_CELL_ORDER                                          ! Export: gmsh cell order.

      CONTAINS                                                           ! The procedures of the module follow.

!  SPLIT(1:9) = BEAM (XI, ETA, NU), PLATE (XI, ETA, NU),
!  SOLID (XI, ETA, NU) SUBDIVISIONS (THE POSTPROCESSING.DAT LAYOUT).
      SUBROUTINE BUILD_POST_GRID(MODEL, NODES_PER_CELL, SPLIT,           ! Subroutine build post grid takes model, nodes per cell, split, grid, status.
     &                           GRID, STATUS)

      TYPE(MODEL_TYPE), INTENT(IN) :: MODEL                              ! Input of type model_type: model.
      INTEGER(I4), INTENT(IN) :: NODES_PER_CELL                          ! Input integer (int32): nodes_per_cell.
      INTEGER(I4), INTENT(IN) :: SPLIT(9)                                ! Input integer (int32): split(9).
      TYPE(POST_GRID_TYPE), INTENT(INOUT) :: GRID                        ! In/out of type post_grid_type: grid.
      TYPE(STATUS_TYPE), INTENT(OUT) :: STATUS                           ! Output of type status_type: status.
      REAL(R8) :: LIMIT(3,3)                                             ! Real (real64): limit(3,3).
      REAL(R8) :: NATURAL(3)                                             ! Real (real64): natural(3).
      INTEGER(I4) :: SPLITS(3)                                           ! Integer (int32): splits(3).
      INTEGER(I4) :: SUB_COUNT                                           ! Integer (int32): sub_count.
      INTEGER(I4) :: DIMENSION                                           ! Integer (int32): dimension.
      INTEGER(I4) :: POINTS                                              ! Integer (int32): points.
      INTEGER(I4) :: MESH                                                ! Integer (int32): mesh.
      INTEGER(I4) :: E                                                   ! Integer (int32): e.
      INTEGER(I4) :: S                                                   ! Integer (int32): s.
      INTEGER(I4) :: IX                                                  ! Integer (int32): ix.
      INTEGER(I4) :: IY                                                  ! Integer (int32): iy.
      INTEGER(I4) :: IZ                                                  ! Integer (int32): iz.
      INTEGER(I4) :: A                                                   ! Integer (int32): a.
      INTEGER(I4) :: B                                                   ! Integer (int32): b.
      INTEGER(I4) :: C                                                   ! Integer (int32): c.
      INTEGER(I4) :: CELL                                                ! Integer (int32): cell.
      INTEGER(I4) :: NODE                                                ! Integer (int32): node.

      CALL CLEAR_STATUS(STATUS)                                          ! Reset the status to "ok".
      CALL CLEAR_POST_GRID(GRID)                                         ! Call clear post grid with grid.
!     20 AND 27 BOTH MEAN A QUADRATIC CELL: THE 3X3X3 NODE BLOCK IS
!     SAMPLED AND THE OUTPUT FORMAT KEEPS THE 20 (VTK) OR 27 (GMSH)
!     NODES IT NEEDS.
      IF (NODES_PER_CELL .NE. 8_I4 .AND. NODES_PER_CELL .NE. 20_I4       ! If nodes_per_cell /= 8 and nodes_per_cell /= 20 and nodes_per_cell /= 27:
     &    .AND. NODES_PER_CELL .NE. 27_I4) THEN
        CALL SET_ERROR(STATUS, 'BUILD_POST_GRID',                        ! Record an error in status: 'CELLS MUST HAVE 8, 20 OR 27 NODES'.
     &                 'CELLS MUST HAVE 8, 20 OR 27 NODES')
        RETURN                                                           ! Return to the caller.
      END IF                                                             ! End of the IF block.
      GRID%NODES_PER_CELL = 27_I4                                        ! Set grid.nodes_per_cell to 27.
      POINTS = 3_I4                                                      ! Set points to 3.
      IF (NODES_PER_CELL .EQ. 8_I4) THEN                                 ! If nodes_per_cell = 8:
        GRID%NODES_PER_CELL = 8_I4                                       ! Set grid.nodes_per_cell to 8.
        POINTS = 2_I4                                                    ! Set points to 2.
      END IF                                                             ! End of the IF block.

      GRID%CELL_COUNT = 0_I4                                             ! Set grid.cell_count to zero.
      DO E = 1_I4, SIZE(MODEL%ELEMENTS%ITEM)                             ! Loop e from 1 to size(model.elements.item):
        MESH = FIND_EXPANSION_INDEX(MODEL%EXPANSIONS,                    ! Set mesh to find_expansion_index(model.expansions, model.elements.item(e).expansion_id).
     &         MODEL%ELEMENTS%ITEM(E)%EXPANSION_ID)
        CALL ELEMENT_SPLITS(TOPOLOGY_NATURAL_DIMENSION(                  ! Call element splits with topology_natural_dimension( model.elements.item(e).topology), split, splits, dimen...
     &       MODEL%ELEMENTS%ITEM(E)%TOPOLOGY), SPLIT, SPLITS,
     &       DIMENSION)
        GRID%CELL_COUNT = GRID%CELL_COUNT + PRODUCT(SPLITS)*             ! Add product(splits)* size(model.expansions.item(mesh).element) to grid.cell_count.
     &    SIZE(MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT)
      END DO                                                             ! End of the loop.
      GRID%NODE_COUNT = GRID%CELL_COUNT*GRID%NODES_PER_CELL              ! Set grid.node_count to grid.cell_count*grid.nodes_per_cell.
      ALLOCATE(GRID%CELL_ELEMENT(GRID%CELL_COUNT))                       ! Allocate memory for grid.cell_element(grid.cell_count).
      ALLOCATE(GRID%CELL_SUB_ELEMENT(GRID%CELL_COUNT))                   ! Allocate memory for grid.cell_sub_element(grid.cell_count).
      ALLOCATE(GRID%CELL_DIMENSION(GRID%CELL_COUNT))                     ! Allocate memory for grid.cell_dimension(grid.cell_count).
      ALLOCATE(GRID%NATURAL_STRUCTURAL(3,GRID%NODE_COUNT))               ! Allocate memory for grid.natural_structural(3,grid.node_count).
      ALLOCATE(GRID%NATURAL_EXPANSION(3,GRID%NODE_COUNT))                ! Allocate memory for grid.natural_expansion(3,grid.node_count).
      GRID%NATURAL_STRUCTURAL = 0.0_R8                                   ! Set grid.natural_structural to zero.
      GRID%NATURAL_EXPANSION = 0.0_R8                                    ! Set grid.natural_expansion to zero.

      CELL = 0_I4                                                        ! Set cell to zero.
      NODE = 0_I4                                                        ! Set node to zero.
      DO E = 1_I4, SIZE(MODEL%ELEMENTS%ITEM)                             ! Loop e from 1 to size(model.elements.item):
        MESH = FIND_EXPANSION_INDEX(MODEL%EXPANSIONS,                    ! Set mesh to find_expansion_index(model.expansions, model.elements.item(e).expansion_id).
     &         MODEL%ELEMENTS%ITEM(E)%EXPANSION_ID)
        CALL ELEMENT_SPLITS(TOPOLOGY_NATURAL_DIMENSION(                  ! Call element splits with topology_natural_dimension( model.elements.item(e).topology), split, splits, dimen...
     &       MODEL%ELEMENTS%ITEM(E)%TOPOLOGY), SPLIT, SPLITS,
     &       DIMENSION)
        SUB_COUNT = SIZE(MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT)            ! Set sub_count to the size of model.expansions.item(mesh).element.
        DO S = 1_I4, SUB_COUNT                                           ! Loop s from 1 to sub_count:
          DO IX = 1_I4, SPLITS(1)                                        ! Loop ix from 1 to splits(1):
            DO IY = 1_I4, SPLITS(2)                                      ! Loop iy from 1 to splits(2):
              DO IZ = 1_I4, SPLITS(3)                                    ! Loop iz from 1 to splits(3):
                CELL = CELL + 1_I4                                       ! Add 1 to cell.
                GRID%CELL_ELEMENT(CELL) = E                              ! Set grid.cell_element(cell) to e.
                GRID%CELL_SUB_ELEMENT(CELL) = S                          ! Set grid.cell_sub_element(cell) to s.
                GRID%CELL_DIMENSION(CELL) = DIMENSION                    ! Set grid.cell_dimension(cell) to dimension.
                CALL CELL_LIMITS(IX, SPLITS(1), POINTS, LIMIT(:,1))      ! Call cell limits with ix, splits(1), points, limit(:,1).
                CALL CELL_LIMITS(IY, SPLITS(2), POINTS, LIMIT(:,2))      ! Call cell limits with iy, splits(2), points, limit(:,2).
                CALL CELL_LIMITS(IZ, SPLITS(3), POINTS, LIMIT(:,3))      ! Call cell limits with iz, splits(3), points, limit(:,3).
                DO A = 1_I4, POINTS                                      ! Loop a from 1 to points:
                  DO B = 1_I4, POINTS                                    ! Loop b from 1 to points:
                    DO C = 1_I4, POINTS                                  ! Loop c from 1 to points:
                      NODE = NODE + 1_I4                                 ! Add 1 to node.
                      NATURAL = [LIMIT(A,1),LIMIT(B,2),LIMIT(C,3)]       ! Set natural to [limit(a,1),limit(b,2),limit(c,3)].
                      CALL SPLIT_NATURAL(NATURAL, DIMENSION,             ! Call split natural with natural, dimension, model.elements.item(e).topology, model.expansions.item(mesh).el...
     &                  MODEL%ELEMENTS%ITEM(E)%TOPOLOGY,
     &                  MODEL%EXPANSIONS%ITEM(MESH)%ELEMENT(S)%
     &                  TOPOLOGY, GRID%NATURAL_STRUCTURAL(:,NODE),
     &                  GRID%NATURAL_EXPANSION(:,NODE))
                    END DO                                               ! End of the loop.
                  END DO                                                 ! End of the loop.
                END DO                                                   ! End of the loop.
              END DO                                                     ! End of the loop.
            END DO                                                       ! End of the loop.
          END DO                                                         ! End of the loop.
        END DO                                                           ! End of the loop.
      END DO                                                             ! End of the loop.

      END SUBROUTINE BUILD_POST_GRID                                     ! End of the subroutine build post grid.

!  SUBDIVISIONS (X, Y, Z) OF THE CELLS OF AN ELEMENT OF GIVEN DIMENSION.
      SUBROUTINE ELEMENT_SPLITS(DIMENSION, SPLIT, SPLITS, KIND)          ! Subroutine element splits takes dimension, split, splits, kind.

      INTEGER(I4), INTENT(IN) :: DIMENSION                               ! Input integer (int32): dimension.
      INTEGER(I4), INTENT(IN) :: SPLIT(9)                                ! Input integer (int32): split(9).
      INTEGER(I4), INTENT(OUT) :: SPLITS(3)                              ! Output integer (int32): splits(3).
      INTEGER(I4), INTENT(OUT) :: KIND                                   ! Output integer (int32): kind.

      KIND = MAX(1_I4,MIN(3_I4,DIMENSION))                               ! Set kind to the larger of 1 and min(3,dimension).
      SPLITS = SPLIT(3*(KIND-1)+1:3*(KIND-1)+3)                          ! Set splits to split(3*(kind-1)+1:3*(kind-1)+3).

      END SUBROUTINE ELEMENT_SPLITS                                      ! End of the subroutine element splits.

!  NATURAL COORDINATES OF THE NODES OF CELL NUMBER I OF N ALONG ONE
!  DIRECTION: POINTS = 3 (END, MIDDLE, END) OR 2 (ENDS).
      SUBROUTINE CELL_LIMITS(I, N, POINTS, LIMIT)                        ! Subroutine cell limits takes i, n, points, limit.

      INTEGER(I4), INTENT(IN) :: I                                       ! Input integer (int32): i.
      INTEGER(I4), INTENT(IN) :: N                                       ! Input integer (int32): n.
      INTEGER(I4), INTENT(IN) :: POINTS                                  ! Input integer (int32): points.
      REAL(R8), INTENT(OUT) :: LIMIT(3)                                  ! Output real (real64): limit(3).
      REAL(R8) :: FIRST                                                  ! Real (real64): first.
      REAL(R8) :: LAST                                                   ! Real (real64): last.

      FIRST = -1.0_R8 + REAL(I-1_I4,R8)*2.0_R8/REAL(N,R8)                ! Set first to -1.0 + real(i-1,r8)*2.0/real(n,r8).
      LAST = -1.0_R8 + REAL(I,R8)*2.0_R8/REAL(N,R8)                      ! Set last to -1.0 + real(i,r8)*2.0/real(n,r8).
      LIMIT = 0.0_R8                                                     ! Set limit to zero.
      IF (POINTS .EQ. 3_I4) THEN                                         ! If points = 3:
        LIMIT(1) = FIRST                                                 ! Set limit(1) to first.
        LIMIT(2) = 0.5_R8*(FIRST+LAST)                                   ! Set limit(2) to 0.5*(first+last).
        LIMIT(3) = LAST                                                  ! Set limit(3) to last.
      ELSE                                                               ! Otherwise:
        LIMIT(1) = FIRST                                                 ! Set limit(1) to first.
        LIMIT(2) = LAST                                                  ! Set limit(2) to last.
      END IF                                                             ! End of the IF block.

      END SUBROUTINE CELL_LIMITS                                         ! End of the subroutine cell limits.

      SUBROUTINE SPLIT_NATURAL(NATURAL, KIND, STRUCTURAL_TOPOLOGY,       ! Subroutine split natural takes natural, kind, structural topology, expansion topology, structural, expansion.
     &     EXPANSION_TOPOLOGY, STRUCTURAL, EXPANSION)

      REAL(R8), INTENT(IN) :: NATURAL(3)                                 ! Input real (real64): natural(3).
      INTEGER(I4), INTENT(IN) :: KIND                                    ! Input integer (int32): kind.
      INTEGER(I4), INTENT(IN) :: STRUCTURAL_TOPOLOGY                     ! Input integer (int32): structural_topology.
      INTEGER(I4), INTENT(IN) :: EXPANSION_TOPOLOGY                      ! Input integer (int32): expansion_topology.
      REAL(R8), INTENT(OUT) :: STRUCTURAL(3)                             ! Output real (real64): structural(3).
      REAL(R8), INTENT(OUT) :: EXPANSION(3)                              ! Output real (real64): expansion(3).

      STRUCTURAL = 0.0_R8                                                ! Set structural to zero.
      EXPANSION = 0.0_R8                                                 ! Set expansion to zero.
      SELECT CASE(KIND)                                                  ! Choose according to the value of kind:
      CASE(1_I4)                                                         ! Case 1:
        STRUCTURAL(1) = NATURAL(2)                                       ! Set structural(1) to natural(2).
        EXPANSION(1) = NATURAL(1)                                        ! Set expansion(1) to natural(1).
        EXPANSION(2) = NATURAL(3)                                        ! Set expansion(2) to natural(3).
      CASE(2_I4)                                                         ! Case 2:
        STRUCTURAL(1) = NATURAL(1)                                       ! Set structural(1) to natural(1).
        STRUCTURAL(2) = NATURAL(2)                                       ! Set structural(2) to natural(2).
        EXPANSION(1) = NATURAL(3)                                        ! Set expansion(1) to natural(3).
      CASE DEFAULT                                                       ! In every other case:
        STRUCTURAL = NATURAL                                             ! Set structural to natural.
      END SELECT                                                         ! End of the case selection.
      IF (STRUCTURAL_TOPOLOGY .EQ. TOPOLOGY_T3 .OR.                      ! If structural_topology = topology_t3 or structural_topology = topology_t6, call collapse triangle with stru...
     &    STRUCTURAL_TOPOLOGY .EQ. TOPOLOGY_T6)
     &  CALL COLLAPSE_TRIANGLE(STRUCTURAL)
      IF (EXPANSION_TOPOLOGY .EQ. TOPOLOGY_T3 .OR.                       ! If expansion_topology = topology_t3 or expansion_topology = topology_t6, call collapse triangle with expans...
     &    EXPANSION_TOPOLOGY .EQ. TOPOLOGY_T6)
     &  CALL COLLAPSE_TRIANGLE(EXPANSION)

      END SUBROUTINE SPLIT_NATURAL                                       ! End of the subroutine split natural.

      SUBROUTINE COLLAPSE_TRIANGLE(NATURAL)                              ! Subroutine collapse triangle takes natural.

      REAL(R8), INTENT(INOUT) :: NATURAL(3)                              ! In/out real (real64): natural(3).
      REAL(R8) :: A                                                      ! Real (real64): a.
      REAL(R8) :: B                                                      ! Real (real64): b.

      A = 0.5_R8*(1.0_R8+NATURAL(1))                                     ! Set a to 0.5*(1.0+natural(1)).
      B = 0.5_R8*(1.0_R8+NATURAL(2))*(1.0_R8-A)                          ! Set b to 0.5*(1.0+natural(2))*(1.0-a).
      NATURAL(1) = A                                                     ! Set natural(1) to a.
      NATURAL(2) = B                                                     ! Set natural(2) to b.

      END SUBROUTINE COLLAPSE_TRIANGLE                                   ! End of the subroutine collapse triangle.

!  NODE ORDER OF ONE CELL IN THE OUTPUT FORMATS (1-BASED POSITIONS IN
!  THE 3X3X3 OR 2X2X2 NODE BLOCK).
      SUBROUTINE VTK_CELL_ORDER(NODES_PER_CELL, ORDER, COUNT)            ! Subroutine vtk cell order takes nodes per cell, order, count.

      INTEGER(I4), INTENT(IN) :: NODES_PER_CELL                          ! Input integer (int32): nodes_per_cell.
      INTEGER(I4), INTENT(OUT) :: ORDER(20)                              ! Output integer (int32): order(20).
      INTEGER(I4), INTENT(OUT) :: COUNT                                  ! Output integer (int32): count.

      ORDER = 0_I4                                                       ! Set order to zero.
      IF (NODES_PER_CELL .EQ. 8_I4) THEN                                 ! If nodes_per_cell = 8:
        COUNT = 8_I4                                                     ! Set count to 8.
        ORDER(1:8) = [1_I4,5_I4,7_I4,3_I4,2_I4,6_I4,8_I4,4_I4]           ! Set order(1:8) to [1,5,7,3,2,6,8,4].
      ELSE                                                               ! Otherwise:
        COUNT = 20_I4                                                    ! Set count to 20.
        ORDER = [1_I4,19_I4,25_I4,7_I4,3_I4,21_I4,27_I4,9_I4,            ! Set order to [1,19,25,7,3,21,27,9, 10,22,16,4,12,24,18,6, 2,20,26,8].
     &           10_I4,22_I4,16_I4,4_I4,12_I4,24_I4,18_I4,6_I4,
     &           2_I4,20_I4,26_I4,8_I4]
      END IF                                                             ! End of the IF block.

      END SUBROUTINE VTK_CELL_ORDER                                      ! End of the subroutine vtk cell order.

      SUBROUTINE GMSH_CELL_ORDER(NODES_PER_CELL, ORDER, COUNT)           ! Subroutine gmsh cell order takes nodes per cell, order, count.

      INTEGER(I4), INTENT(IN) :: NODES_PER_CELL                          ! Input integer (int32): nodes_per_cell.
      INTEGER(I4), INTENT(OUT) :: ORDER(27)                              ! Output integer (int32): order(27).
      INTEGER(I4), INTENT(OUT) :: COUNT                                  ! Output integer (int32): count.

      ORDER = 0_I4                                                       ! Set order to zero.
      IF (NODES_PER_CELL .EQ. 8_I4) THEN                                 ! If nodes_per_cell = 8:
        COUNT = 8_I4                                                     ! Set count to 8.
        ORDER(1:8) = [1_I4,5_I4,7_I4,3_I4,2_I4,6_I4,8_I4,4_I4]           ! Set order(1:8) to [1,5,7,3,2,6,8,4].
      ELSE                                                               ! Otherwise:
        COUNT = 27_I4                                                    ! Set count to 27.
        ORDER = [1_I4,7_I4,9_I4,3_I4,19_I4,25_I4,27_I4,21_I4,            ! Set order to [1,7,9,3,19,25,27,21, 4,2,10,8,16,6,18,12, 22,20,26,24,5,13,11,17, 15,23,14].
     &           4_I4,2_I4,10_I4,8_I4,16_I4,6_I4,18_I4,12_I4,
     &           22_I4,20_I4,26_I4,24_I4,5_I4,13_I4,11_I4,17_I4,
     &           15_I4,23_I4,14_I4]
      END IF                                                             ! End of the IF block.

      END SUBROUTINE GMSH_CELL_ORDER                                     ! End of the subroutine gmsh cell order.

      SUBROUTINE CLEAR_POST_GRID(GRID)                                   ! Subroutine clear post grid takes grid.

      TYPE(POST_GRID_TYPE), INTENT(INOUT) :: GRID                        ! In/out of type post_grid_type: grid.

      IF (ALLOCATED(GRID%CELL_ELEMENT)) DEALLOCATE(GRID%CELL_ELEMENT)    ! If allocated(grid.cell_element), free the memory of grid.cell_element.
      IF (ALLOCATED(GRID%CELL_SUB_ELEMENT))                              ! If allocated(grid.cell_sub_element), free the memory of grid.cell_sub_element.
     &  DEALLOCATE(GRID%CELL_SUB_ELEMENT)
      IF (ALLOCATED(GRID%CELL_DIMENSION))                                ! If allocated(grid.cell_dimension), free the memory of grid.cell_dimension.
     &  DEALLOCATE(GRID%CELL_DIMENSION)
      IF (ALLOCATED(GRID%NATURAL_STRUCTURAL))                            ! If allocated(grid.natural_structural), free the memory of grid.natural_structural.
     &  DEALLOCATE(GRID%NATURAL_STRUCTURAL)
      IF (ALLOCATED(GRID%NATURAL_EXPANSION))                             ! If allocated(grid.natural_expansion), free the memory of grid.natural_expansion.
     &  DEALLOCATE(GRID%NATURAL_EXPANSION)
      GRID%CELL_COUNT = 0_I4                                             ! Set grid.cell_count to zero.
      GRID%NODE_COUNT = 0_I4                                             ! Set grid.node_count to zero.

      END SUBROUTINE CLEAR_POST_GRID                                     ! End of the subroutine clear post grid.

      END MODULE MUL2_POST_GRID                                          ! End of the module mul2 post grid.
