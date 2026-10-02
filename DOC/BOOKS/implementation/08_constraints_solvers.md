# Constraints, loads and solvers {#sec:solvers}

## Boundary data

`BUILD_MECHANICAL_BOUNDARY_DATA(boundaries, nodes, elements, kinematics, expansions, frames, dof_layout, tolerance, constraints, force, status)` (module `MUL2_BOUNDARY_APPLICATION`) converts the records of `BC.dat` into

- `CONSTRAINT_SET_TYPE`: `ACTIVE(dof)` (logical), `VALUE(dof)` (prescribed value), `COUNT`;
- `FORCE(dof)`: the global load vector.

The geometric tolerance is $10^{-9}$ (relative, with a scale of at least one).

### Planes

`ADD_PLANE_CONSTRAINT(plane, component_active, component_value, ...)` loops over all nodes. For a node it takes the *first incident element* (`FIRST_ELEMENT`, from the incidence table) to know the expansion mesh and the frame, computes the physical position of every expansion node (`EXPANDED_POINT`: node + `LOCAL_TO_GLOBAL × local coordinate`) and tests `POINT_ON_PLANE`. For each active displacement component:

- Lagrange: every term whose point is on the plane is constrained (`SET_DOF_CONSTRAINT(GLOBAL_DOF(...), value)`).
- Taylor: if all section points are on the plane, term 1 gets the value and the others zero; otherwise the error `PARTIAL PLANE CONSTRAINT REQUIRES MPC FOR TE`.
- Hierarchical / user-defined: explicit "not implemented" error.

`SET_DOF_CONSTRAINT` refuses two different values for the same DOF (`CONFLICTING PRESCRIBED VALUES`). If a plane selects no DOF a warning is issued.

### Point loads

`ADD_POINT_FORCE(point, load, ...)` scans nodes and expansion nodes for the one whose physical position coincides with `point` (relative tolerance). Lagrange: `FORCE(GLOBAL_DOF(node, field, term)) += load(field)` where the term is the expansion node. Taylor: for every term $\tau$, `FORCE(...) += load(field) × EVALUATE_TAYLOR_TERM(...)` evaluated at the coordinates of the expansion node. Failure: `POINT LOAD LOCATION WAS NOT FOUND`.

### Static elimination

`APPLY_STATIC_CONSTRAINTS(system, force, constraints, status)` performs the two loops of the algorithm of Chapter 9 of the Theoretical Guide in place:

1. $F_r\leftarrow F_r-\sum_{c\in\text{constrained}}K_{rc}\,\bar q_c$ for every row;
2. for every constrained row or column set the entry to 0; set the constrained diagonal to 1 and the right-hand side to $\bar q_r$.

The CSR pattern is unchanged. A constrained row without a diagonal entry would be an error (`CONSTRAINED CSR ROW HAS NO DIAGONAL`); the pattern builder guarantees the diagonal.

![Elimination of constrained DOFs.](figures/bc_elimination.svg){#fig:elim-impl}

## Analysis 101

`RUN_STATIC_ANALYSIS(model, cache, results, status)`:

![Static analysis flow.](figures/flow_static.svg){#fig:flow-static}

The solve is done by `SOLVE_SYMMETRIC_POSITIVE_DEFINITE(system, rhs, solution, status, release_system)`:

1. `PARDISO_SET_SYSTEM`: copies the upper triangle (`EXTRACT_UPPER_TRIANGLE`) into the handle `PARDISO_FACTOR_TYPE` (arrays `ROW_POINTER`, `COLUMN_INDEX`, `VALUE`);
2. if `release_system` is true (no K/M dump requested) the caller's `STIFFNESS`, `COLUMN_INDEX`, `ROW_POINTER` and `MASS` are deallocated, saving half of the matrix memory during the factorisation;
3. `PARDISO_FACTOR_LOADED(mtype, factor, status)`: PARDISO phase 12 (reordering, symbolic and numerical factorisation). On error code $-4$ with `mtype = 2` the internal memory is freed (`PARDISO_FREE_INTERNAL`) and the factorisation is retried with `mtype = -2` and a warning;
4. `PARDISO_SOLVE`: phase 33, with `IPARM` at defaults;
5. `PARDISO_RELEASE`: phase −1 and deallocation.

`PARDISO_HINT(error)` translates the numeric error codes into the messages shown to the user (−2 not enough memory, −3 reordering failed, −4 zero pivot, −5/−6 internal).

The routine then checks the solution for NaN and infinity and logs `MAX |U|`.

## Analysis 103

`RUN_MODAL_ANALYSIS(model, cache, results, status)`:

![Modal analysis flow.](figures/flow_modal.svg){#fig:flow-modal}

`SOLVE_MODAL_PROBLEM(order, row_pointer, column_index, stiffness, mass, nev, sigma, eigenvalue, vector, residual, info, status)` chooses between `SOLVE_DENSE` (order ≤ `DENSE_ORDER_LIMIT` = 400 or `nev ≥ order−2`) and `SOLVE_ARPACK`. After either, `SORT_MODES` sorts ascending and `COMPUTE_RESIDUALS` evaluates $\|K\phi-\lambda M\phi\|/\|K\phi\|$ with `SPARSE_MULTIPLY`.

### The ARPACK reverse-communication loop

`SOLVE_ARPACK` builds `SHIFTED = K − σM` (same pattern), factorises it with `PARDISO_FACTORIZE` (`mtype 2` if $\sigma=0$, else −2) and runs the `dsaupd` loop:

```fortran
#caption: ARPACK mode 3 loop (SOLVERS/mul2_modal_solver.for, abridged)
IPARAM(1) = 1;  IPARAM(3) = 500;  IPARAM(7) = 3     ! exact shifts, max restarts, mode 3
IDO = 0
DO
  CALL DSAUPD(IDO, 'G', N, 'LM', NEV, TOL, RESID, NCV, V, N, IPARAM, IPNTR, WORKD, WORKL, LWORKL, INFO)
  SELECT CASE (IDO)
  CASE (-1, 1)   ! y <- (K - sigma M)^-1 M x
    CALL SPARSE_MULTIPLY(..., MASS, WORKD(IPNTR(1)), TEMPORARY)       ! M x
    CALL PARDISO_SOLVE(FACTOR, TEMPORARY, WORKD(IPNTR(2)), STATUS)    ! solve with the factors
  CASE (2)       ! y <- M x
    CALL SPARSE_MULTIPLY(..., MASS, WORKD(IPNTR(1)), WORKD(IPNTR(2)))
  CASE DEFAULT
    EXIT
  END SELECT
END DO
CALL DSEUPD(.TRUE., 'A', SELECT, D, V, N, SIGMA, 'G', ...)            ! eigenvalues, vectors
```

`IPNTR` points into `WORKD` for the input and the output vector; `INFO` tells the number of converged values; the eigenvalues of the original problem are recovered as $\lambda=\sigma+1/\mu$ by `dseupd`. `NCV = min(N, max(2 nev + 1, nev + 10))` Lanczos vectors are used. The ARPACK sources are compiled with 64-bit `INTEGER` and `LOGICAL` so that the `I8` arrays can be passed unchanged; the interface blocks in the module declare the external routines with `INTEGER(I8)` and `LOGICAL(I8)` arguments.

### Dense fallback

`SOLVE_DENSE` expands the CSR matrices into dense `A(N,N)`, `B(N,N)` and calls LAPACK `DSYGV(1, 'V', 'U', ...)`; the first `nev` eigenpairs are returned.

## Results and memory in the modal analysis

After the reduced matrices are built, `RUN_MODAL_ANALYSIS` frees `PATTERN%SOURCE_POSITION` and, unless `KMAT`/`MMAT` were requested, the full system. The solution vectors are stored in `RESULTS%MODE(order, k)` after `EXPAND_VECTOR`; `FREQUENCY(k) = sqrt(max(0, λ))/(2π)`.
