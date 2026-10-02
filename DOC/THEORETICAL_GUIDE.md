# MUL2_NEW – Theoretical Guide

Scope: the formulation behind analyses **101** (linear static) and **103**
(linear free vibration) of MUL2_NEW. It describes *what is computed*;
*how it is coded* is in `IMPLEMENTATION_GUIDE.md`, *how to run it* in
`USER_GUIDE.md`.

---

## 1. Problem statement

A linear elastic body occupies a volume Ω with boundary ∂Ω. With
displacement **u** = (u, v, w), small-strain tensor **ε** and Cauchy stress
**σ**, the equilibrium problem is

    ∫Ω δεᵀ σ dΩ = ∫Ω δuᵀ b dΩ + Σ δuᵀ F     (virtual work, static)

    ∫Ω δεᵀ σ dΩ + ∫Ω ρ δuᵀ ü dΩ = 0          (free vibration)

Conventions used everywhere in the code:

    σ = [σxx, σyy, σzz, σxz, σyz, σxy]ᵀ
    ε = [εxx, εyy, εzz, γxz, γyz, γxy]ᵀ      (engineering shear strains)

Only the mechanical fields U, V, W are active in 101/103. The other fields
of the unified formulation (T, P, B, SZZ, SXZ, SYZ) are parsed but not
used in these analyses.

## 2. Carrera Unified Formulation (CUF)

Beams, plates and solids are treated with a single *structural* finite
element along the "long" directions and a *cross-section / thickness
expansion* over the remaining ones:

    u(x, y, z) = Σi Σt  Ni(ξ…) · Ft(ζ…) · u_ti

* `Ni` – structural shape function of node *i* of the FE (1D for beams,
  2D for plates, 3D for solids).
* `Ft` – expansion function *t* over the section (beam: 2D in x–z;
  plate: 1D through the thickness z; solid: none, a single constant term).
* `u_ti` – unknown coefficient of term *t* at node *i*.

The kernel is identical for every element type; only the set of shape
functions, the expansion and the geometric mapping change.

### 2.1 Expansion families

| Token | Family | Meaning |
|-------|--------|---------|
| `TE<N>` | Taylor | `Ft = xᵃ zᵇ` monomials, a+b ≤ N (beam) or `zᵇ`, b ≤ N (plate). TE0 is rigid, TE1 is linear (Euler–Bernoulli-like enrichment), TE2 parabolic… |
| `LE` | Lagrange | `Ft` are Lagrange polynomials defined by an expansion mesh (`EXP_MESH`, `EXP_CONN`). Each sub-element carries B2/B3/B4 (plate) or Q4/Q9/Q16 (beam) interpolation; the unknowns are physical nodal displacements, so layer-wise kinematics (a separate expansion per ply) is immediate. |

Field-dependent kinematics allows a different expansion for each of the
9 fields (U V W T P B SZZ SXZ SYZ). Tokens `HLE<N>` and `M<N>` exist in the
input syntax but are rejected in 101/103 with an explicit error.

### 2.2 Structural elements

| Family | Elements | Natural coordinates |
|--------|----------|---------------------|
| Beam (1D) | B2, B3, B4 | η ∈ [−1,1] along the axis (y) |
| Plate (2D) | Q4, Q9, Q16, T3, T6 | ξ, η in the plane (x–y) |
| Solid (3D) | H8, H27 | ξ, η, ν |

Geometry is isoparametric: x = Σ Ni xi. The Jacobian of the structural
mapping and the Jacobian of the expansion mapping are kept separate; the
physical gradient of a combined function Ni·Ft uses the inverse of each in
its own directions (the combined Jacobian is block-diagonal).

## 3. Strain–displacement relation

With the field gradient in the local element frame (the 1D beam axis, the
plate normal, or the global frame for solids), the linear strain is

    ε = B(ξ) u_e,    B = D · (Ni Ft)

where `D` is the geometric differential operator

    εxx = ∂u/∂x,  εyy = ∂v/∂y,  εzz = ∂w/∂z
    γxz = ∂u/∂z + ∂w/∂x,  γyz = ∂v/∂z + ∂w/∂y,  γxy = ∂u/∂y + ∂v/∂x

Because U, V and W may have different expansions, the column of **B**
belonging to a degree of freedom is built from the *scalar* basis function
and its gradient of that DOF's own field:

    B_A = B_OPERATOR(∇φ_A) · R(:,A)

(R = rotation of the displacement component into the local frame), never
from a fixed 3×3 block times a common basis.

## 4. Constitutive law

Material properties are given in the **material frame** and rotated to the
element frame at every Gauss point:

    σ = C ε,   C_elem = Tσ⁻¹ C_mat Tε

* `ISO-M`: E, ν, ρ → isotropic C (Lamé form).
* `ORT-M`: nine orthotropic constants.
* `MAT-C`: a full 6×6 matrix given by the user (may be non-symmetric in the
  input; MUL2_NEW rejects a non-symmetric C for the symmetric solvers).
* Lamination: each lamination references a material and rotation angles
  (about Y and Z); the rotation is included in the material frame before
  the transformation. Stress and strain transformations are **different**
  matrices because shear strains are engineering strains.

The resolved constitutive matrix is cached per distinct lamination
(constant along the integration points of a layer).

## 5. Shear locking and MITC

Thin plates and beams with low-order interpolation produce spurious
transverse shear stiffness ("shear locking"). The **MITC** (Mixed
Interpolation of Tensorial Components) cure replaces the displacement-
derived transverse shear strains by an interpolation of the strains sampled
at *tying points*:

    γ̃(ξ) = Σp Lp(ξ) γ(ξp)

`Lp` are Lagrange polynomials over the tying set. Only the shear rows
are replaced; all other strain rows are standard.

Tying sets used (a = 1/√3, b = √(3/5)):

| Element | Modified rows | Tying points |
|---------|---------------|--------------|
| B2 | xz, yz (5, 6) | {0} |
| B3 | 5, 6 | {±a} |
| B4 | 5, 6 | {−b, 0, b} |
| Q4 | 4 | {0}×{1,−1}; 5: {1,−1}×{0} |
| Q9 | 1,4: {±a}×{−b,0,b}; 2,5: {−b,0,b}×{±a}; 6: {±a}×{±a} |
| H8 | 4,5,6 | centre |
| H20/H27 | 4,5,6 | {±a}³ |

Q16, T3 and T6 have no MITC table: the program emits a warning
and uses full integration. The shear-locking flag is chosen per family
(beam / plate / solid) in `ANALYSIS.dat`: `NONE`, `REDI` and `SELI` (reduced and selective integration,
implemented as in the baseline) and `MITC`.

(MITC on H8 was reported singular in an early version; the validation
campaign found it regular.)

## 6. Fundamental nucleus and matrix assembly

Substituting the CUF expansion, the element stiffness has the form

    K_e = Σ_g wg |J|g  Bᵀ(ξg) C_g B(ξg)

and the consistent mass

    M_e = Σ_g wg |J|g  ρ_g  Nᵀ(ξg) N(ξg),    N = Ni Ft

summed over the combined structural × expansion Gauss points. The
"fundamental nucleus" is the 3×3 block that couples field *i* and field *j*
(scalar basis × scalar basis with gradients); the full matrix is built by
looping over DOF pairs. Element matrices are scattered into a global CSR
matrix with field-major DOF numbering (all U, then all V, then all W; inside
each field node-major, then term index).

## 7. Boundary conditions

### 7.1 Static (analysis 101)

Constraints are imposed by **exact symmetric elimination**. Let *c* be the
constrained set and *f* the free set with prescribed values u_c:

    K_ff u_f = F_f − K_fc u_c

The system is solved directly (PARDISO, symmetric positive definite). The
reactions can be recovered from the constrained rows. This differs from the
baseline, which enforced constraints with a penalty of 10¹⁰; the two agree
to about 10⁻⁷ relative.

### 7.2 Constraint geometry

* `D-PLANE`: all terms of nodes (LE: nodal terms lying on the plane; TE:
  constant term gets the value, higher terms zero) whose *physical*
  coordinate lies on the plane `A x + B y + C z = D` are constrained in the
  flagged components.
* `F-POINT`: a point load at physical coordinate **x**. For LE nodes the
  load acts on the matching node term; for TE it is projected on every
  monomial evaluated at the point (Fᵗ = Ft(x) F).

## 8. Free vibration (analysis 103)

The generalised eigenproblem

    K φ = λ M φ,    λ = ω²,    f = √λ / (2π)

is reduced to the free DOFs (constrained DOFs removed, not penalised):

    K_ff φ = λ M_ff φ

Loads and non-zero prescribed displacements are ignored (with a warning).
Modes are computed by **shift-invert** Lanczos (ARPACK, `BMAT='G'`,
mode 3) with σ = 0 using a sparse factorisation of K_ff; for very small
problems, or when nearly all modes are requested, the dense LAPACK
`dsygv` is used. Modes are sorted by ascending frequency and M-normalised
(φᵀ M φ = 1). The residual ‖K φ − λ M φ‖ is reported for every mode.

Rigid-body modes (zero-frequency) appear if the model is under-constrained;
they break the shift-invert at σ = 0 and the program reports a singular
factorisation.

## 9. Post-processing

Given a point **x** in global coordinates, the element containing it is
found (bounding-box prefilter, Newton iteration on the isoparametric map),
the natural coordinates are obtained and the fields are evaluated:

* displacements: u = (Ni Ft) u_e,
* strains: ε = B u_e (with the MITC rows if active),
* stresses: σ = C ε in the material, local or global frame.

Output grids (VTK/GMSH) are built by splitting each element into sub-cells
and evaluating at the corner (and mid-edge) nodes; 20-/27-node cells are
written as quadratic hexahedra.

## 10. Known theoretical limitations

* Only displacement-based formulations: no mixed RMVT fields in 101/103.
* No geometric nonlinearity, no thermal, electrical or hygroscopic
  coupling in these analyses.
* TE with a partial-plane constraint would need a multi-point constraint
  and is rejected with an explicit error.
* MITC is available only for the element families listed in §5.

