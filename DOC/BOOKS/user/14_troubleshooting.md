# Troubleshooting {#sec:trouble}

## Reading the messages

The program prints errors on the standard error stream as `[ERROR] ROUTINE: message` and returns exit code 1. Warnings are printed in `REPORT/WARNING_file.dat`. This chapter lists the messages you are likely to meet, with the usual cause and remedy.

## Errors

Table: Errors and what to do. {#tab:errors}

| Message (abridged) | Cause | Remedy |
|---|---|---|
| `CANNOT OPEN: INPUT/…` | a file is missing, or the input directory is wrong | check the name of the directory and that all the required files are present (Chapter {sec:inputref} checklist) |
| `INVALID …` count / record / header | the number of records of a file is not an integer, or a record cannot be read | check the first data line of the file and the number of fields of the failing record |
| `UNKNOWN ELEMENT TOPOLOGY: X` | the element name is not recognised | use `B2 B3 B4 Q4 Q9 Q16 T3 T6 H8 H27` |
| `CONNECTIVITY REFERENCES UNKNOWN NODE` | an element uses a node id not in `NODES.dat` | check the ids |
| `DUPLICATE … ID` | two records of the same file have the same id | make the ids unique |
| `SOLUTION n IS NOT SUPPORTED (ONLY 101 AND 103)` | `ANALYSIS.dat` asks for another analysis | use 101 or 103 |
| `UNKNOWN SHEAR-LOCKING CORRECTION` | a word other than `NONE`, `MITC`, `REDI`, `SELI` | correct the word |
| `THE FIELDS RECORD MUST CONTAIN MECH` | `FIELDS` without the displacements | add `MECH` |
| `UNKNOWN FIELD IN THE FIELDS RECORD: X` | a word other than `MECH`, `THERMO`, `PIEZO` | correct the word |
| `MIXED STRESS FIELDS (RMVT) ARE NOT IMPLEMENTED YET` | `STRESS` in the `FIELDS` record | remove it: the mixed principle is not available |
| `THERMO IS ACTIVE BUT NO KINEMATICS EXPANDS THE TEMPERATURE` (also `PIEZO` / the potential) | the field is switched on in `ANALYSIS.dat` but `KINEMATICS.dat` has no expansion for it | give the field an expansion in the kinematics of the nodes |
| `THE JOIN RECORD IS \`JOIN COINCIDENT [TOLERANCE]\`` / `THE TOLERANCE OF JOIN COINCIDENT MUST BE POSITIVE` | malformed `JOIN` record | write `JOIN COINCIDENT` or `JOIN COINCIDENT 1.0E-6` |
| warning `JOIN COINCIDENT FOUND NO COINCIDENT DEGREES OF FREEDOM` | no DOF of different nodes is at the same point (within the tolerance) | check the coordinates and the section meshes; increase the tolerance |
| `ONLY LAM2 IS ACTIVE FOR SOLUTIONS 101/103` | another lamination type in `LAMINATION.dat` | use `LAM2 id material angle_y angle_z` |
| `UNSUPPORTED NODE MODEL (ONLY TE, LE AND HLE)` | another token in the historical `NODES.dat` | use `TE n`, `LE` or `HLE` |
| `MISCELLANEOUS BASIS IS NOT IMPLEMENTED YET` | `Mn` in `KINEMATICS.dat` | use `TEn`, `LE` or `HLE` |
| `HLE NODES NEED A HLE SECTION MESH (HQ4/HB2) AND LE NODES A LAGRANGE ONE` | `HLE` node on a Lagrange mesh or `LE` node on an HQ4/HB2 mesh | match nodes and mesh; join the two with a Taylor node |
| `ONLY U, V AND W ARE SUPPORTED BY 101/103` | a field other than U, V, W is active in a kinematic | set the other fields to `NONE` |
| `LE NODE USES INCOMPATIBLE EXPANSIONS` | the elements that share a Lagrange node use different expansion meshes | give them the same section number, or use Taylor |
| `NODE HAS INCOMPATIBLE EXPANSION DIMENSIONS`, `EXPANSION HAS MIXED DIMENSIONS` | a node is shared by elements whose expansion meshes have different dimensions, or the sub-elements of one mesh mix dimensions | do not mix families at a node; check `EXP_CONN` |
| `ELEMENT REFERENCES UNKNOWN EXPANSION / SOR` | the section number or versor id of an element does not exist | add the files/records |
| `SOR IS PARALLEL TO BEAM AXIS` | the versor is parallel to the axis of a beam | choose another versor (Chapter {sec:refsys}) |
| `DEGENERATE BEAM AXIS`, `DEGENERATE SURFACE`, `SOR IS NORMAL TO SURFACE` | first and last node coincide; three corners are collinear; the versor is normal to a plate | correct the coordinates or the versor |
| `EXPANSION MESH IS DEGENERATE` | the nodes of an expansion mesh do not span the section (beam) or thickness (plate) | check `EXP_MESH` coordinates |
| `NO CONSTRAINED DEGREE OF FREEDOM: THE SYSTEM IS SINGULAR` | no `D-PLANE` selected a DOF in a static analysis | add a support |
| `PARTIAL PLANE CONSTRAINT REQUIRES MPC FOR TE` | a plane cuts the section of a Taylor node | constrain a plane that contains the whole section, or use `LE` |
| `CONFLICTING PRESCRIBED VALUES` | two constraints prescribe different values for the same DOF | remove the conflict |
| `POINT LOAD LOCATION WAS NOT FOUND` | the load is not at a section node of a structural node | use the exact coordinates of a section node (structural node + section node coordinates in the element frame) |
| `LOAD ACTS ON AN INACTIVE FIELD` | a load component on a field that is `NONE` | check the kinematic |
| `PARDISO FACTORIZATION ERROR CODE -4 (ZERO PIVOT: SINGULAR MATRIX, CHECK SUPPORTS)` | the matrix is singular: not enough supports, a part of the model not connected or not supported, `MITC` on H8, or a nearly singular Taylor basis | check the supports and the connectivity; remove `MITC` from H8; reduce the Taylor order or rescale the section |
| `PARDISO … ERROR CODE -2 (NOT ENOUGH MEMORY)` | the factor does not fit in memory | reduce the model, use a lower expansion order |
| `K-SIGMA*M CANNOT BE FACTORED … (MISSING SUPPORTS?)` | modal analysis of a structure with rigid-body modes | add supports |
| `THE SOLUTION CONTAINS NAN OR INFINITY` | numerical failure after the solution | check units, supports and Taylor order |

## Warnings

Table: Warnings. {#tab:warnings}

| Message (abridged) | Meaning |
|---|---|
| `EXTRA RECORDS AFTER DECLARED COUNT` | a file has more records than the first line says; the extras are ignored (check the count) |
| `FEWER RECORDS THAN DECLARED: THE REST IS IGNORED` | `POSTPROCESSING.dat` declares more records than present |
| `THE SOLVER RECORD OF ANALYSIS.DAT IS OBSOLETE: IGNORED` | the file has the old solver line; delete it (harmless) |
| `REDI/SELI IS NOT DEFINED FOR TRIANGLES: FULL INTEGRATION` | T3/T6 elements have no reduced rule; they were integrated fully |
| `REDI LEAVES HOURGLASS MODES IN Q4, H8 AND H27: USE SELI` | zero-energy modes can make the matrix singular (PARDISO error) or the solution meaningless: use `SELI` or `MITC` |
| `MITC IS NOT DEFINED FOR SOME TOPOLOGY: FULL INTEGRATION` | the element has no tying table; full integration was used (risk of locking) |
| `NON-MECHANICAL OR NONSYMMETRIC DATA WERE PRESERVED` | the material file has thermal/electrical records or a non-symmetric `MAT-C` |
| `UNUSED NODES HAVE NO DEGREES OF FREEDOM` | some nodes of `NODES.dat` belong to no element |
| `PLANE DID NOT SELECT ANY ACTIVE DOF` | a `D-PLANE` plane does not touch any node or section node: probably a sign or coordinate mistake (remember $AX+BY+CZ+D=0$) |
| `LOADS AND NON-ZERO PRESCRIBED DISPLACEMENTS ARE IGNORED` | analysis 103 ignores loads and imposed displacements; normal |
| `MORE MODES REQUESTED THAN FREE DEGREES OF FREEDOM` | the number of modes was reduced |
| `NEGATIVE EIGENVALUES: K IS NOT POSITIVE SEMI-DEFINITE` | rounding or rigid-body modes; check the supports |
| `CHOLESKY FAILED (ILL-CONDITIONED MATRIX): USED SYMMETRIC INDEFINITE FACTORIZATION` | the matrix is very ill-conditioned (typically high-order Taylor); the results are probably still good, but **verify** with another expansion |
| `POINT n IS OUTSIDE THE MODEL: NO RESULT` | a `PNT` point is not inside any element; the row of `POST_POINT.dat` contains `NaN` |

## Symptoms without a message

Table: Strange results. {#tab:symptoms}

| Symptom | Likely cause |
|---|---|
| displacements of the wrong sign or direction | the **element frame** is not what you think: versor, node order (plate normal) — Chapter {sec:refsys} recipes |
| the structure seems far too stiff | `TE 1`; `TE 0`; missing section terms; locking (`NONE` on a thin plate; B2/B3 without `MITC`); a constraint that is too severe |
| the structure seems far too flexible | missing or wrong supports (a plane with the wrong sign of $D$); a wrong unit (E in GPa instead of Pa) |
| laminate stiffness does not change with the stacking sequence | angles are in degrees, applied to the **lamination** that each sub-element refers to; check `EXP_CONN` lamination ids |
| strange wiggles in the VTK display | `PARA` output with `8` nodes per cell on a high-order model; use 20/27 nodes and subdivisions |
| point result is `NaN` | the point is outside the structure; check the global coordinates |
| high-order Taylor results change when the order grows | conditioning: rescale the section or use `LE` |
| modal frequencies too low by orders of magnitude | units of density or modulus; check consistency |
| the run takes too long or uses too much memory | the number of DOF is larger than expected; use the console line `PREPROCESSING: … DOF` to check, and Chapter {sec:modelling} for the cost estimate |

## Where to look for more information

- The console output and `REPORT/WARNING_file.dat` (always).
- `WORK/ARPACK_SOLVER_INFO.dat` for the convergence of the modes.
- Run with `MUL2_DEBUG=1` for extra lines.
- The Theoretical Guide explains the assumptions of every model; the Implementation Guide explains where each message is generated.
