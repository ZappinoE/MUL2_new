# Critical analysis of the multiphysics and analysis extension

Date: 1 October 2026. Scope: piezoelectric, thermal and pyroelectric physics in 101; the analyses 104 (time), 105 (buckling), 106 (frequency response), 108 (geometrically nonlinear); `FIELDS.dat`; the surface loads (flux, sun, convection).

## 1. What was verified

| Area | Evidence | Result |
|---|---|---|
| Preservation of 101/103 | `MUL2_ANALYSIS_TEST` (frozen baseline of the historical executable), `MUL2_REDUCED_TESTS`, `MUL2_HLE_*`, the validation campaign `TESTS/VALIDATION` | unchanged |
| Piezoelectricity | closed forms of the slab, thickness resonance (short, open, floating), beam = plate = solid | $10^{-6}$ ... 0.03 % |
| Thermal statics | expansion, clamped stress, conduction, power, flux, convection, sun on beam/plate/solid | $10^{-9}$ ... exact |
| Pyroelectricity | slab, closed and open circuit | $5\cdot10^{-7}$ |
| 104 | period of the first mode ($10^{-4}$), $2u_s$ amplitude (2.4 %), Rayleigh, heat conduction with capacity (< 0.3 %), thermoelastic damping, piezoelectric actuation ($5\cdot10^{-4}$), lumped sun and convection ($2\cdot10^{-3}$) | pass |
| 105 | Euler (0.06 %), Timoshenko higher factors (0.7 %), clamped-clamped mechanical (1.8 %) and thermal (4.9 %) | pass |
| 106 | resonance position, $1/(2\zeta)$ amplitude fraction (0.969), piezoelectric resonance (0.03 %) | pass |
| 108 | elastica (0.3 %, 0.06 %), beam-column (0.7 %), solid (1.6 %), plate (0.7 %), thermal Green strain ($10^{-10}$), thread invariance (bitwise) | pass |
| Robustness | Debug build (bounds, uninitialised data) with all the suites; error messages of the new inputs | one bug found and fixed (below) |

Release and Debug `ctest`: 12 suites (plus the extended campaign `TESTS/EXTENDED`), all passing.

## 2. Defects found during the campaign (fixed)

1. **Debug-only out-of-bounds read** in the nonlinear element: the local direction of a temperature or potential degree of freedom was read from an array of three displacement directions. It was never used, so Release results were correct; the Debug build caught it.
2. **Reference of the Newton convergence test**: a self-equilibrated thermal load has no external force and its internal force vanishes at convergence; a reference that follows the current iteration made the test fail forever. The reference is now the largest force seen.
3. **Missing material data** (a temperature field without `T-CON`, a potential without `Z-PRM`) ended with "the solution contains NaN"; the data are now checked at pre-processing with the lamination number in the message.
4. **Mapping of the degree-of-freedom classes** in the time analysis (fields 1-3 were mapped to three classes): found by the first test (no inertia in the response), fixed.

## 3. What does not work or is approximate

| # | Limitation | Consequence | Effort |
|---|---|---|---|
| 1 | Floating electrodes (`V-FLOAT`) in 104, 105, 106, 108 | error message | the tie transformation must act on $K$, $M$, $C$ and on the history vectors |
| 2 | 103 does not solve the temperature | error message; use 106 | a thermal modal analysis is non-symmetric (complex eigenvalues) |
| 3 | Buckling is dense (8000 free DOF) | large models are rejected | ARPACK in buckling mode (shift-and-invert of $K - \sigma K_G$) |
| 3b | Curved beams and shells (general geometry, `TESTS/CURVED`) are not available in 105 and 108 and have no surface loads (`Q-*`) | an error message stops the run | buckling and total-Lagrangian terms from `GENERAL_POINT_COLUMNS`; area element $\|g_1\times g_2\|$ for the surface loads |
| 3c | A beam and a shell can only share nodes of order 0 (the number of terms of a 1D and a 2D expansion differs otherwise) | the skin is rotationally restrained at the node: a row of such nodes (stringer, ring) locks the bending of the skin and makes the structure several times too stiff; only isolated nodes are admissible | node-dependent kinematics with equal term counts (e.g. beam section of one term per layer) |
| 3f | `JOIN COINCIDENT` joins `LE` DOFs with `LE` and `TE` with `TE` of the same field at the same point (higher `TE` terms only with equal orientation); not `HLE`, not shell edges with node rotation; the tolerance is relative to the model diagonal; only beam-beam is tested | beam-plate and plate-solid joints are not covered by a test; nodes that must stay apart at the same position are joined too | tests for beam-plate and plate-solid; an absolute tolerance option |
| 3e | At an edge between shells of different normals the first-order term is the rotation of the node (rigid edge); it needs TE of order 1-2 (not LE) and all the shells at the node general (S*) | LE shells cannot be joined at a kink; a flat Q* plate and an S* shell at an edge are inconsistent | extend the node rotation to LE and to the ordinary plate kernel |
| 3d | Shell directors from the polynomial surface are a few degrees off the exact normal on coarse meshes | LE point loads are not found; small stiffness errors | `DIRECTORS.dat` (exact normals) or a finer mesh |
| 4 | Arc length (108, technique 2) needs zero prescribed values and uses only the displacement norm | displacement-controlled limit points are not followed | Crisfield done; add a displacement-control variant |
| 5 | 108 has no material nonlinearity and no follower loads | | plasticity at the Gauss points; the follower pressure needs the surface integral of the current configuration |
| 6 | MITC ties only the linear strain in 108 | slender shells with large rotations may lock | tie the Green strain |
| 7 | Output stresses of 108 are the linearised ones | final PK2/Cauchy stress is not written | recovery of $E$, $S$ with $H$ |
| 8 | 104 has one amplitude for all loads, zero initial conditions, constant $\Delta t$ | | one amplitude per BC record; initial-condition file; adaptive step |
| 9 | 106: one factorization per frequency of a system twice as large | slow on large models | modal superposition; parallel frequencies |
| 10 | Sun: no shadowing, no radiation, loads act on faces of beams, plates, solids, H8/H27, Q, T (not H20, T4, T10, P6) | | ray casting; emission $\sigma\epsilon(T^4-T_\infty^4)$ (non-linear) |
| 11 | `FIELDS.dat` multiplies BC values only | laminate angles, point forces and `F-PRESS` do not use it | the interpreter is available |
| 12 | `F-PRESS` of the historical code (pressure on a section edge) is not implemented | | the surface integral exists (heat flux); it needs the normal-direction load |
| 13 | HLE sections: surface integration uses the straight (vertex) map | curved HLE skins are integrated on the chord | use the blending map |
| 14 | Thermal buckling of a clamped-clamped bar is 5 % below the Timoshenko reference (mechanical analogue 1.8 %) | end restraint of the lateral expansion | analyse with a finer end mesh |
| 15 | The linear and the thermal solutions of 101 share one nonsymmetric factorization even without coupling blocks | memory x2 for thermal models | detect $K_{uT}=0$ and split |

Items 1-3 and 8 are the ones most likely to be needed by users and are the proposed next steps.

## 4. Performance notes

The element kernel of the temperature and potential fields, the nonlinear element and the geometric matrix use the point-by-point path (the separable CUF kernel covers the displacement fields only), so those problems cost more per element than a purely mechanical one. The assembly is parallel in all analyses, with a deterministic reduction. The review of the code with the optimisation work is described in `DOC/OPTIMIZATION_NOTES.md`.
