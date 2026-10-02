# Assembly {#sec:assembly}

`ASSEMBLE_MODEL_SYSTEM(MODEL, CACHE, SYSTEM, STATUS, WITH_MASS)` (module `MUL2_MODEL_ASSEMBLY`) builds the global stiffness (and optionally mass) matrix. It never forms a dense global matrix and never needs all element matrices in memory at the same time.

![Assembly flow.](figures/flow_assembly.svg){#fig:flow-assembly}

## Step 1: DOF lists

For every element `BUILD_ELEMENT_DOF_LIST` fills the local DOF arrays; the global numbers are moved into a `DOF_LIST_TYPE` (`GLOBAL_DOF`), and `MARK_LAGRANGE_DOFS` adds two arrays that describe the *Lagrange* DOFs:

- `TABLE(k)`: index of the expansion mesh if the DOF belongs to a Lagrange expansion, 0 otherwise (Taylor DOFs are coupled with everything);
- `TERM(k)`: the expansion node (term) of the DOF.

`BUILD_COUPLING_TABLES` creates, for every expansion mesh, the logical matrix `COUPLED(t,s)`: true if the expansion nodes $t$ and $s$ belong to a common sub-element. It is $T\times T$ (81² for a $4\times4$ Q9 section) and is computed by scanning the sub-elements and locating each of their nodes in the node list.

## Step 2: pattern

`BUILD_PATTERN_FROM_DOF_LISTS(total_dof, lists, system, status, with_mass, tables)` builds the CSR pattern without any dense intermediate:

![Two-pass construction of the pattern.](figures/pattern_build.svg){#fig:pattern}

1. Build the *DOF → elements* table: `FIRST(dof)` (CSR pointer), `MEMBER(l)` (element) and `MEMBER_LOCAL(l)` (position of the DOF in the element list).
2. For every row (DOF) collect the unique columns: loop over the elements of the DOF and over the DOFs of each element, mark visited columns with the array `MARK(column) = row` (so no clearing is needed between rows), skip pairs for which `ARE_COUPLED` is false. **Pass 1** only counts, giving `ROW_POINTER` after a prefix sum; **pass 2** stores the columns and sorts each row with `SORT_SEGMENT` (insertion sort for short rows, heap sort otherwise).
3. Allocate `STIFFNESS` (and `MASS` if requested) with the same length.

`ARE_COUPLED(list, tables, k0, k1)` is `.FALSE.` only if both DOFs are Lagrange DOFs of the same table and `COUPLED(term_k0, term_k1)` is false. For Taylor expansions every pair is coupled.

## Step 3: chunks and parallel evaluation

The element matrices of a big model do not fit in memory, so the elements are processed in **chunks**:

```fortran
#caption: Chunked evaluation (ANALYSES/mul2_model_assembly.for, abridged)
CHUNK_SIZE = ...        ! multiple of the thread count, bounded by CHUNK_BYTES / (bytes per element)
DO FIRST = 1, N_ELEMENT, CHUNK_SIZE
  LAST = MIN(N_ELEMENT, FIRST + CHUNK_SIZE - 1)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(I) SCHEDULE(DYNAMIC,1)
  DO I = 1, LAST - FIRST + 1
    CALL EVALUATE_ELEMENT(MODEL, CACHE, FIRST+I-1, CHUNK(I), CHUNK_STATUS(I), MASS_REQUESTED, FORCE_GENERAL)
  END DO
!$OMP END PARALLEL DO
  DO I = 1, LAST - FIRST + 1                        ! serial, in element order
    CALL SCATTER_ELEMENT(SYSTEM, LISTS(FIRST+I-1)%GLOBAL_DOF, CHUNK(I)%STIFFNESS, CHUNK(I)%MASS, ...)
    CALL CLEAR_ELEMENT_MATRIX(CHUNK(I))
  END DO
END DO
```

`EVALUATE_ELEMENT` is thread-safe: it only reads the shared databases, prepares the MITC data of the element (`PREPARE_ELEMENT_MITC`) and calls `BUILD_LINEAR_ELEMENT_MATRICES`. The memory budget `CHUNK_BYTES` is $10^9$ bytes; the bytes per element are $8n^2$ if only K is built and $16n^2$ with M ($n$ = local DOFs). The number of elements per chunk is a multiple of the number of threads when memory allows, so that no thread idles inside a chunk.

## Step 4: scatter

`SCATTER_ELEMENT(system, global_dof, stiffness, mass, status)` adds the dense element matrices to the CSR arrays. For every local pair $(I,J)$:

1. If the stiffness entry is zero and the mass entry is zero (or absent) the pair is **skipped**: it is a structural zero.
2. Otherwise `FIND_CSR_POSITION` finds `(global_dof(I), global_dof(J))` by binary search in the sorted row and the values are added. If the position does not exist the routine raises `ENTRY IS MISSING FROM CSR PATTERN`, which guarantees that a non-zero entry never falls outside the pattern (a safeguard of the coupling tables).

The serial loop and the fixed element order make the sums reproducible for any number of threads.

## Reduction for the modal problem

`BUILD_REDUCED_PATTERN(order, row_pointer, column_index, constrained, pattern)` creates the pattern of the sub-matrix of the free DOFs: `FREE_TO_GLOBAL(f)` maps free to global numbers, `ROW_POINTER`/`COLUMN_INDEX` describe the reduced matrix and `SOURCE_POSITION(k)` is the position in the full CSR of the $k$-th reduced entry. `REDUCE_VALUES(pattern, full_value, reduced_value)` copies values through the map; `EXPAND_VECTOR(pattern, reduced, full)` scatters a reduced vector back (constrained entries zero). `SPARSE_MULTIPLY` computes $\mathbf{y}=\mathbf{A}\mathbf{x}$ for the full CSR (row-parallel).

## Complexity and memory

For a model with $n_{DOF}$ unknowns and $\bar r$ non-zeros per row:

- the pattern needs $O(n_{DOF}\bar r)$ operations and $16\,n_{DOF}\bar r$ bytes ($\bar r$ ≈ 200 for the Lagrange benchmark, ≈ 2000 for Taylor-15);
- the element evaluation costs $\sum_e O(PN^2+QT^2+n^2)$ (separable kernel);
- the scatter costs $\sum_e n^2\log\bar r$ (binary search) and is the only serial step. In the 100 000-DOF Taylor-15 benchmark it takes about 7 s of the 12 s of the assembly, so it is now the dominant part and the natural target of future optimisation (for instance a parallel scatter by row ranges).
