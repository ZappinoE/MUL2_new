# Element kernels {#sec:kernels}

This chapter follows a combined Gauss point from the cache to the element matrices. It first describes the small building blocks (shape functions, point factors, strain operator) and then the two complete kernels.

## Building blocks

### Shape functions and gradients

- `EVALUATE_SHAPE(topology, natural, N, DN_DNATURAL, STATUS)` returns the shape functions and their derivatives with respect to the natural coordinates; it dispatches on the topology to `SHAPE_B`, `SHAPE_Q4`, `SHAPE_Q9`, `SHAPE_Q16`, `SHAPE_T3`, `SHAPE_T6`, `SHAPE_H8`, `SHAPE_H27`. Tensor-product elements use `TENSOR_2D`/`TENSOR_3D` with the index tables `IX`, `IY`, `IZ` that define the node order, and `LAGRANGE_1D` for the 1D polynomials.
- `EVALUATE_SQUARE_JACOBIAN(coordinate, dn_dnatural, dimension, jacobian, determinant, inverse, dn_dphysical, status)` implements $\mathbf{J}=\mathbf{x}^T\partial N/\partial\xi$, $\det\mathbf{J}$, $\mathbf{J}^{-1}$ and $\partial N/\partial\mathbf{x}=\mathbf{J}^{-T}\partial N/\partial\xi$ for dimension 1, 2 or 3 (`INVERT_SMALL_MATRIX`).
- `EVALUATE_SHAPE_AND_GRADIENT(topology, node_local, natural, shape, gradient, status)` (module `MUL2_LOCAL_GRADIENTS`) combines the two for one structural element at an arbitrary natural point; it is used for the MITC tying points and for post-processing.

### Expansion functions

`EVALUATE_EXPANSION_FACTOR(spec, term, mesh, sub_element, dim, axes, coordinate_local, shape, gradient, F, dF, status)` (module `MUL2_POINT_BASES`) returns $F_\tau$ and its local gradient:

- *Taylor*: `EVALUATE_TAYLOR_TERM(order, dim, active_axis, coordinate, term, ...)` computes the monomial $x^az^b$ and its derivatives (`INTEGER_POWER` for the powers). The term ordering is: increasing degree and, inside a degree, increasing power of the second active axis ($z$).
- *Lagrange*: the term $\tau$ is the node `MESH%NODE(tau)`; if it belongs to the active sub-element the value is the sub-element shape function of that node (`EXPANSION_SHAPE(local node)`) and its gradient, otherwise it is **exactly zero** (this is what creates the structural zeros).

`EVALUATE_POINT_FACTORS(point, structural_node, term, spec, ..., structural_value, structural_gradient, factor_value, factor_gradient, status)` uses the Gauss layout to find the structural rule/point and the sub-element/expansion point of a global point number and returns $N_i$, $\nabla N_i$, $F_\tau$, $\nabla F_\tau$. `COMPOSE_PRODUCT_BASIS` builds $\phi=N F$ and $\nabla\phi=F\nabla N+N\nabla F$.

### Strain operator

`BUILD_DISPLACEMENT_OPERATOR(gradient, operator, status)` returns the $6\times3$ matrix $\mathbf{B}(\mathbf{g})$ of Chapter 4 of the Theoretical Guide (the strain operator of the fundamental nucleus), column by column through `BUILD_DISPLACEMENT_COLUMN`:

```fortran
#caption: Strain column of each displacement component (KINEMATICS/mul2_linear_kinematics.for)
CASE(1)   ! u:  exx = u,x ; gxz = u,z ; gxy = u,y
  COLUMN(1) = GRADIENT(1);  COLUMN(4) = GRADIENT(3);  COLUMN(6) = GRADIENT(2)
CASE(2)   ! v:  eyy = v,y ; gyz = v,z ; gxy = v,x
  COLUMN(2) = GRADIENT(2);  COLUMN(5) = GRADIENT(3);  COLUMN(6) = GRADIENT(1)
CASE(3)   ! w:  ezz = w,z ; gxz = w,x ; gyz = w,y
  COLUMN(3) = GRADIENT(3);  COLUMN(4) = GRADIENT(1);  COLUMN(5) = GRADIENT(2)
```

### Element DOF list

`BUILD_ELEMENT_DOF_LIST` creates, for one element, the local DOF arrays in the order **node, field, term**: `GLOBAL_DOF(I)` (field-major global number from `GLOBAL_DOF()`), `STRUCTURAL_NODE(I)` (local node 1…$N_n$), `FIELD(I)` (1, 2, 3), `TERM(I)` (1…$T$), plus `NODE_INDEX` and `KINEMATIC_INDEX` per local node.

## Choosing the kernel

`BUILD_LINEAR_ELEMENT_MATRICES` is the single entry point used by the assembly. After validation and DOF list it tries the separable kernel (unless `FORCE_GENERAL` is true, i.e. `MUL2_GENERAL_KERNEL=1`) and falls back to the reference kernel if `APPLICABLE` is false.

![Decision flow of the element kernel.](figures/flow_kernel.svg){#fig:flow-kernel}

## The separable kernel in detail {#sec:sepcode}

Module `MUL2_SEPARABLE_KERNEL`, routine `BUILD_SEPARABLE_MATRICES`. It receives the element DOF arrays and the caches and produces `STIFFNESS` (upper triangle) and `MASS`. The correspondence between the formulas of Chapter 7 of the Theoretical Guide and the variables of the code is:

Table: Dictionary of `BUILD_SEPARABLE_MATRICES`. {#tab:sepdict}

| Variable | Shape | Meaning |
|---|---|---|
| `NS`, `NP`, `NE` | scalars | structural nodes, structural points $P$, sub-elements |
| `PE(e)` | `NE` | global number of the first combined point of sub-element $e$ |
| `NQ(e)` | `NE` | expansion points $Q_e$ of sub-element $e$ |
| `QO(e)` | `NE` | offset of sub-element $e$ in the concatenated list of expansion points; `NQT = ΣNQ` |
| `MAT(e)` | `NE` | material cache index of sub-element $e$ (constant over its points; if not, the kernel returns `APPLICABLE=.FALSE.`) |
| `SW(p)` | `NP` | $w_p\det\mathbf{J}_{s,p}$ |
| `SN(p,i)`, `SG(:,p,i)` | `NP×NS`, `3×NP×NS` | $N_i$ and $\nabla N_i$ (local frame) |
| `STRUCTURAL_AXIS(d)` | logical(3) | $d\in S$ |
| `CLASS(r)` | int(6) | class of strain row $r$: 1 plain, $1+s$ tied by MITC set $s$ |
| `SIGMA(d,p,i,c)` | `3×NP×NS×NCLASS` | $\sigma_d$ of the Theoretical Guide, Chapter 7 (tied for classes $>1$) |
| `SM(i,j,d,d',c,c')` | `NS×NS×3×3×NCLASS²` | $S_{dd'}^{cc'}(i,j)=\sum_pw_p\sigma^c_d\sigma^{c'}_{d'}$ |
| `SNN(i,j)` | `NS×NS` | $\sum_pw_pN_iN_j$ for the mass |
| `BASIS(m)%SPEC`, `%TERMS`, `%EPS(q,t,0:3)` | per distinct specification $m$ | $F_\tau$ (index 0) and $\varepsilon_d$ (1…3) at all expansion points |
| `WQ(q)` | `NQT` | $w_q\det\mathbf{J}_{e,q}$ |
| `PRODUCT(a,b)%EM(t,s,k,e)` | per pair of specifications | $E^{(e)}_{dd'}(\tau,s)$ with $k=3(d-1)+d'$, $k=10$ for $F F$ |
| `W(6,d,f)` | `6×3×3` | $\mathbf{w}_{d,f}=\mathbf{B}(\mathbf{e}_d)\,\mathbf{R}\mathbf{e}_f$ |
| `GAMMA(f,h,d,d',c,c',e)` | | $\Gamma^{cc'}$ of Chapter 7 (coupling coefficient), split by row class |
| `LAMBDA(i,j,f,h,k,e)` | `NS×NS×3×3×10×NE` | $\sum_{cc'}\Gamma\,S$ |
| `OFFSET(i,f)`, `TERMS(i,f)`, `SPEC_OF(i,f)` | `NS×3` | first local DOF (minus one), number of terms, index of the specification of the block (node $i$, field $f$) |

The algorithm is the following (the numbers refer to the code sections):

1. **Layout recognition.** Walk the Gauss points of the element in the order sub-element → structural point → expansion point to fill `PE`, `NQ`, `QO`, `ERULE`, `MAT`; return `APPLICABLE=.FALSE.` if the number of points does not match, if some DOF terms are not numbered 1…$T$, or if the material index changes inside a sub-element.
2. **Structural factors.** For each structural point read `SW`, `SN`, `SG` from the structural cache (`DETERMINANT`, `DERIVATIVE_LOCAL`) and the rule (`WEIGHT`, `SHAPE`).
3. **Row classes and `SIGMA`.** Class 1: $\sigma_d=\partial_dN_i$ if $d\in S$ else $N_i$. For every MITC set $s$ (class $s+1$): the same quantity evaluated at each tying point from `MITC_DATA%GRADIENT/SHAPE` and interpolated with `INTERPOLATION_WEIGHT`.
4. **Structural matrices.** Accumulate `SM` and `SNN` over $p$.
5. **Distinct specifications.** Group the blocks (node, field) by (family, order, field reference, number of terms): `BASIS(m)`. For each one evaluate all expansion factors at all expansion points with `EVALUATE_POINT_FACTORS` (node 1, point $(e,1,q)$) and store `EPS(:,:,0)` = $F$ and `EPS(:,:,d)` = $F$ if $d\in S$ else $\partial_dF$. The expansion weights `WQ` come from the rule and the expansion determinant.
6. **Coupling coefficients.** Compute `W` from the frame, `GAMMA` from the constitutive matrix `MATERIAL_CACHE%STIFFNESS_LOCAL(:,:,MAT(e))`, then `LAMBDA`.
7. **Block assembly.** For every block pair $(i,f)\le(j,h)$: `PREPARE_PRODUCT` (once per pair of specifications) fills `EM` using `ACCUMULATE_PRODUCT`; the block of `STIFFNESS` is `Σ_e Σ_k LAMBDA(i,j,f,h,k,e)·EM(:,:,k,e)`; for the mass, if $f=h$, `Σ_e ρ_e SNN(i,j) EM(:,:,10,e)`.
8. The caller mirrors the upper triangle (`MIRROR_UPPER_TRIANGLE`).

> NOTE: The coupling of a Lagrange expansion with a Taylor expansion at different nodes is handled automatically: the pair of specifications selects the correct product `EM(a,b)`; the matrices of mixed pairs are not zero.

## The reference (point-by-point) kernel

The reference kernel is the direct implementation of the element integral at the start of Chapter 7 of the Theoretical Guide. Its structure:

```fortran
#caption: Reference kernel, structure (ELEMENTS/mul2_element_matrices.for, abridged)
DO WHILE (FIRST_POINT .LE. ELEMENT_LAST)             ! batches of up to BATCH points
  DO POINT = FIRST_POINT, LAST_POINT
    STIFFNESS_LOCAL = WEIGHT * C(material of POINT)  ! w C
    DO I = 1, N_DOF
      CALL EVALUATE_LOCAL_DOF(POINT, I, ..., BASIS_VALUE(Q,I), B_COLUMN, ...)
      B_TEST    (6*Q+1:6*Q+6, I) = B_COLUMN                      ! b_I
      B_WEIGHTED(6*Q+1:6*Q+6, I) = MATMUL(STIFFNESS_LOCAL, B_COLUMN)   ! w C b_I
    END DO
  END DO
  CALL ACCUMULATE_UPPER_PRODUCT(B_TEST, B_WEIGHTED, 6*COUNT, STIFFNESS)  ! K += B^T (w C B)
  IF (MASS_REQUESTED) CALL ADD_MASS(...)
END DO
```

`EVALUATE_LOCAL_DOF` evaluates the factors at the point, composes the basis, builds the strain column with `BUILD_DISPLACEMENT_OPERATOR` and multiplies by the frame column of the field (`GLOBAL_TO_LOCAL(:,FIELD,element)`); if MITC is active the tied rows are replaced by `MITC_TIE_COLUMN`. Processing the points in *batches* (the points of a batch are stacked in the rows of `B_TEST` and `B_WEIGHTED`, up to 128 points and 2 million entries per array) turns the accumulation into one large matrix product instead of one $6\times6$ nucleus per pair of DOFs. `ADD_MASS` computes the mass block of each displacement component as a product of the basis values (`BASIS_VALUE(point,dof)`) weighted by $w\rho$.

## Dense products

`MUL2_DENSE_PRODUCTS` contains the two loops used by both kernels, written without array temporaries (so that they are safe in threads with small stacks):

- `ACCUMULATE_UPPER_PRODUCT(A, B, ROWS, MATRIX, INDEX)`: $M_{IJ}\mathrel{+}=\sum_qA_{qI}B_{qJ}$ for $I\le J$ only; optional `INDEX` selects (ascending) the columns of `A`, `B` and their position in `MATRIX` (used for the mass blocks of one field).
- `ACCUMULATE_PRODUCT(A, B, ROWS, MATRIX)`: the same for all $I$, $J$ (used for the expansion products).

Both process four columns of the right factor at a time, so that each streamed column of `A` is reused four times; the inner loop over the integration rows is contiguous and vectorised.

## MITC in the code

`MUL2_MITC` contains the tying tables. `DEFINE_TYING(topology, data)` sets, for each topology, `ROW_SET(6)` (0 = untied, $s$ = tied by set $s$) and the tying sets (`COUNT_1D`, `COORDINATE_1D`: the tensor product of one list per direction). `MITC_PREPARE_ELEMENT` evaluates shapes and local gradients at all tying points and stores them in `SHAPE(node, point, set)` and `GRADIENT(3, node, point, set)`. `INTERPOLATION_WEIGHT(set, natural, weights)` evaluates the tensor Lagrange weights $M_l$. The reference kernel uses `MITC_TIE_COLUMN` per DOF; the separable kernel builds `SIGMA` for the tied classes once per structural point.

## Reduced and selective integration {#sec:redi-impl}

`REDI` and `SELI` (`ANALYSIS.dat`, see Chapter 8 of the Theoretical Guide) are implemented without touching the formulas of the kernels, by **changing the integration set** and the constitutive matrix they read.

1. **Rules.** `BUILD_REFERENCE_RULE_DATABASE` adds, for the structural elements of a dimension that asks for `REDI`/`SELI`, a second rule of the same topology with the marker `ORDER = -1` (`BUILD_REDUCED_QUADRATURE`: one point per direction less, `REDUCED_POINTS_PER_DIRECTION`). Expansion elements never use it, so a thickness line B3 keeps its rule. `FIND_STRUCTURAL_RULE` returns the reduced rule when asked and the default one otherwise.
2. **Second set.** `BUILD_MODEL_CACHE` builds, when some dimension is reduced, a second `REDUCED_SET_TYPE` (Gauss layout, structural geometry, combined geometry and point-material map). The expansion geometry and the material cache are shared.
3. **Constitutive parts.** `STIFFNESS_PART(CACHE, INDEX, PART, DIM)` returns $\mathbf{C}$, or its normal part `PART_NORMAL`, or its shear part `PART_SHEAR`; the shear part contains every entry whose row or column is a reduced strain (beam YZ and XY, plate XZ and YZ, solid XZ YZ XY), so the two parts add up to $\mathbf{C}$.
4. **Assembly.** `EVALUATE_ELEMENT` (`MUL2_MODEL_ASSEMBLY`) calls `BUILD_LINEAR_ELEMENT_MATRICES` once for `REDI` (reduced set, full $\mathbf{C}$, mass included) and twice for `SELI` (full set with `PART_NORMAL` and the mass; reduced set with `PART_SHEAR`, stiffness only; the two stiffness matrices are added). Both the separable and the reference kernel receive `PART` and `WITH_STIFFNESS`.
5. **Modal solver.** With `REDI` the mass is singular: `SOLVE_DENSE` falls back to $\mathbf{M}\mathbf{x}=\mu\mathbf{K}\mathbf{x}$ when LAPACK reports that $\mathbf{M}$ is not positive definite (ARPACK shift-invert accepts a semi-definite $\mathbf{M}$).

Tests: `MUL2_ANALYSIS_TEST` compares beam and plate, static (displacements, stresses, VTK) and modal, with the baseline program (cases `*_redi`, `*_seli` in `TESTS/CASES`); `MUL2_REDUCED_TESTS` (`TESTS/REDUCED/reduced_tests.py`) checks the format of `ANALYSIS.dat`, the patch tests, the exact pure bending, the removal of locking and the modal analysis with a singular mass.
