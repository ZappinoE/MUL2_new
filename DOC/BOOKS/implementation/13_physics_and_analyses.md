# Multiphysics and the new analyses {#sec:impl-physics}

This chapter lists what was added to the program in the multiphysics and analysis extension, where it lives and how the pieces fit. The routine-by-routine reference (Appendix) is generated from the sources and includes all the new modules.

## 1. New and extended modules

| Module (file) | Role |
|---|---|
| `MUL2_MATERIALS` (`MODEL`) | adds `PIEZO(3,6)`, `PERMITTIVITY`, `EXPANSION(6)`, `CONDUCTIVITY(3,3)`, `PYRO(3)`, `SPECIFIC_HEAT` and the global `DAMP_*` coefficients |
| `MUL2_READ_MATERIALS` | records `Z-EXP`, `Z-PRM`, `T-EXP`, `T-CON`, `T-SPC`, `PIROE`, `DAMP`; records of a material may precede it (a pending list is attached at the end) |
| `MUL2_MATERIAL_ROTATIONS`, `MUL2_MATERIAL_RESOLUTION` | rotation of the tensors into the element frame (strain transform $T$, $A^T e T$, $A^T\epsilon A$, $T(A^T)\alpha$, $A^Tp$) |
| `MUL2_GAUSS_MATERIALS` | the cache of every lamination stores the rotated tensors; `GENERALIZED_CONSTITUTIVE` returns the $12\times12$ matrix $\mathbf M$ |
| `MUL2_ELEMENT_MATRICES` | the point-by-point kernel with $NR=6/9/12$ rows (mechanics, +potential, +temperature) and four extra modes: `COUPLING` (block $K_{uT}$, $K_{\varphi T}$), `GEOMETRIC` ($K_G$ of a state), the heat capacity in the mass, and `BUILD_NONLINEAR_ELEMENT_MATRICES` |
| `MUL2_FIELDS`, `MUL2_READ_FIELDS` | spatial functions of `FIELDS.dat` |
| `MUL2_TIME_INPUT`, `MUL2_READ_TIME` | `TIME_RESP.dat` (load amplitude $a(t)$), `FREQ_RESP.dat`, `NL_INFO.dat` |
| `MUL2_BOUNDARY_APPLICATION` | the constraints and loads of all the fields, the floating electrodes (`APPLY_DOF_TIES`, `EXPAND_TIES`) and the field multiplier |
| `MUL2_SURFACE_LOADS` | surface integration of heat flux, sun and convection |
| `MUL2_MODEL_ASSEMBLY` | parallel assembly of $K$, $M$ and the coupling block; `ASSEMBLE_GEOMETRIC_VALUES`; `ASSEMBLE_NONLINEAR_VALUES` |
| `MUL2_PARDISO_FACTOR` | adds the non-symmetric type 11 with the full CSR |
| `MUL2_MODAL_SOLVER` | `SOLVE_BUCKLING_DENSE`; the condensation of the massless potential rows in the modal problem |
| `MUL2_ANALYSIS_104/105/106/108` | time response, buckling, frequency response, nonlinear statics |
| `MUL2_POST_OUTPUT`, `MUL2_RECOVERY` | temperature, heat flux and potential recovery; `WRITE_TIME_STEP_OUTPUT`, `WRITE_FREQUENCY_OUTPUT` |

## 2. How a model flows through the analyses

```text
READ_MODEL (FIELDS, TIME/FREQ/NL files by analysis id)
  -> BUILD_MODEL_CACHE (DOF layout of 5 fields, frames, Gauss data, materials)
  -> ASSEMBLE_MODEL_SYSTEM (K, M [, K_uT])
  -> BUILD_MECHANICAL_BOUNDARY_DATA (constraints, F)  -> APPLY_SURFACE_LOADS
  -> analysis 101 | 103 | 104 | 105 | 106 | 108
  -> output
```

**DOF classes.** The analyses 104 and 106 classify each degree of freedom by its field: class 1 (fields 1-3, second order in time), 2 (field 4, temperature, first order) and 3 (field 5, potential, algebraic). The effective matrix is one pass over the CSR pattern in which every row takes the scalar that belongs to its class.

**The monolithic system.** The pattern of $K$ is built from the degree-of-freedom lists of the elements, so it already contains every coupling pair; the non-symmetric blocks are only *values*. `APPLY_STATIC_CONSTRAINTS` works entry by entry and therefore on non-symmetric matrices. Whether PARDISO uses the symmetric type 2 (with the automatic fallback to the indefinite type -2) or the non-symmetric type 11 depends only on the presence of the temperature.

**Chunked parallel assembly.** `ASSEMBLE_MODEL_SYSTEM` and `ASSEMBLE_NONLINEAR_VALUES` evaluate the elements of a chunk in parallel (OpenMP, one element per thread) into private arrays and scatter them **serially in element order**, so the result does not depend on the number of threads.

## 3. Conventions that are easy to get wrong

- The potential row of the element matrix is the **negative** of the permittivity block: the matrix is symmetric indefinite.
- The heat conductivity block is $+k$ (positive definite); a heat flux or power is a positive load into the body.
- A pyroelectric coefficient is stored at constant strain; the input (zero stress) is converted in the material cache.
- In the nonlinear element the column of a displacement degree of freedom is the MITC-tied linear strain **plus** $H^Td\otimes g$; the temperature columns only hold the gradient and carry the value separately for the coupling.
- The geometric matrix does not use MITC; it only needs the gradients and the local direction of every degree of freedom.
- A time-analysis output step writes rows with the time first; the nonlinear analysis uses the same file with the load factor as time.

## 4. Extending

To add a physics: a new field token in `KINEMATICS.dat` and `N_SOLVED_FIELDS`, its row block in `GENERALIZED_CONSTITUTIVE` and the column of its degree of freedom in `EVALUATE_LOCAL_DOF`; the coupling blocks go in the `COUPLING` branch; the recovery (`STATE_FROM_PLACE`) and the output follow. To add an analysis: an id in `MUL2_ANALYSIS_INPUT`, a module that fills `ANALYSIS_RESULTS_TYPE`, its input reader in `READ_MODEL` and a case in `MUL2_DRIVER`.

## 5. Tests

| Suite | Content |
|---|---|
| `MUL2_PIEZO_TESTS` | slab statics, thickness resonance (short, open and floating electrode), beam/plate/solid equivalence, pyroelectric slab |
| `MUL2_THERMAL_TESTS` | expansion, clamped stress, conduction, heat power, flux, convection, sun (areas and power of beam, plate and solid), thermal bending, `FIELDS.dat` |
| `MUL2_DYNAMICS_TESTS` | Newmark period and amplitude, Rayleigh damping, ramp, conduction with capacity, thermoelastic damping, piezoelectric actuation, harmonic response, piezoelectric resonance, lumped sun and convection |
| `MUL2_BUCKLING_TESTS` | cantilever (beam and solid), clamped-clamped (mechanical and thermal) |
| `MUL2_NONLINEAR_TESTS` | linear limit, elastica, beam-column, solid, Green-measure thermal expansion |

All the suites run in the Release and Debug configurations (`ctest -C Release`, `-C Debug`); the Debug build checks array bounds and uninitialised variables.
