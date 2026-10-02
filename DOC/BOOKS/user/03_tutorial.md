# Tutorial: a cantilever beam, step by step {#sec:tutorial}

In this chapter we build the input of a cantilever beam from scratch, run it, check the answer against beam theory and then change the model. All files are in `DOC/BOOKS/examples/cases/beam_te2_static/INPUT` and can be regenerated with `python DOC/BOOKS/examples/make_examples.py`.

**The problem.** A beam of length $L=1$ m, square section $0.1\times0.1$ m, aluminium ($E=70$ GPa, $\nu=0.3$, $\rho=2700$ kg/m³). It is clamped at $y=0$ and a force $P=1000$ N along $+z$ is applied at the centre of the free end. The beam axis is the global $Y$ axis.

![Workflow of the tutorial.](figures/workflow.svg){#fig:workflow-tut}

## Step 1 – the analysis (ANALYSIS.dat)

```text
101

4 modes

MITC
MITC
MITC
```

Record 1: the analysis (101 = static). Record 2 is the number of modes (used only by 103, ignored here). Records 3–5 select the shear-locking treatment for beams, plates and solids. We use `MITC` for all; it only acts on the family that is present.

## Step 2 – the structural mesh (NODES.dat and CONNECTIVITY.dat)

We use five cubic beam elements (B4, four nodes each), so the beam has $3\times5+1=16$ nodes spaced equally along $Y$, and every node uses a Taylor expansion of order 2 (`TE 2`):

@include examples/cases/beam_te2_static/INPUT/NODES.dat 8 NODES.dat (first records)

Each record is: node id, $X$, $Y$, $Z$, expansion model and its order. The elements join the nodes four by four:

@include examples/cases/beam_te2_static/INPUT/CONNECTIVITY.dat 8 CONNECTIVITY.dat

A record is: element type, element id, the four node ids (in order along the axis), the **versor** id (`1`, see Step 4) and the **section** number (`1` → `EXP_MESH_01.dat`).

## Step 3 – the section (EXP_MESH_01.dat and EXP_CONN_01.dat)

The section is a single Q9 element, $0.1\times0.1$ m, whose nine nodes sit at the section coordinates $(x,0,z)$:

@include examples/cases/beam_te2_static/INPUT/EXP_MESH_01.dat 12 EXP_MESH_01.dat

@include examples/cases/beam_te2_static/INPUT/EXP_CONN_01.dat 6 EXP_CONN_01.dat

The Q9 record reads: type, id, **lamination id** (`1`), and the nine node ids in the order of Figure {fig:el2d-user} (corners and mid-sides alternate counter-clockwise, the centre last). With a Taylor expansion this mesh only supplies the integration domain and the places where loads and constraints can be applied (the nodes); the displacement is a polynomial of the section coordinates, not an interpolation between these nodes.

![Node order of the quadrilateral elements.](figures/elements_2d.svg){#fig:el2d-user}

## Step 4 – the frame (VERSORS.dat)

```text
1

VERSOR 1  0 0 1
```

A beam needs one extra piece of information: which way is "up" in its section. The versor $(0,0,1)$ means that the local $z$ axis of the section points along the global $Z$. The beam axis is the local $y$ (here the global $Y$) and local $x$ completes the right-handed triad: $x=y\times z=(1,0,0)$. So the section coordinate $x$ of `EXP_MESH_01.dat` runs along the global $X$ and $z$ along the global $Z$. (Chapter {sec:refsys} shows how to choose the versor for other layouts.)

## Step 5 – material and lamination (MATERIAL.dat, LAMINATION.dat)

```text
1 1

ISO-M 1  7.0000000000D+10  0.3  2700.0
```

The first line says: one material, one record. `ISO-M id E nu rho`. And

```text
1

LAM2 1 1 0.0 0.0
```

A *lamination* is a material (`1`) with two orientation angles (here both zero: nothing to rotate). The lamination id `1` is the one referred to by the section element.

## Step 6 – supports and loads (BC.dat)

@include examples/cases/beam_te2_static/INPUT/BC.dat 8 BC.dat

`D-PLANE 1  0 1 0 0   0.0 0.0 0.0` clamps every degree of freedom lying on the **plane** $0\cdot X+1\cdot Y+0\cdot Z+0=0$, that is $Y=0$, to the three displacements $0.0\,0.0\,0.0$ ($u_x$, $u_y$, $u_z$). `F-POINT 2  0 1 0   0 0 1000` is a force $(0,0,1000)$ N at the point $(0,1,0)$: the centre node of the section of the last node of the beam.

> WARNING: A point load must be applied **at a node of the section mesh** (here the centre node of the Q9), at a structural node. For a Taylor model the load is distributed over the polynomial terms, so the same $P$ gives a different generalised force at a corner node than at the centre.

## Step 7 – what to compute (POSTPROCESSING.dat)

@include examples/cases/beam_te2_static/INPUT/POSTPROCESSING.dat 8 POSTPROCESSING.dat

The first line says three requests follow. `PARA 20 GLB 1 1 1 1 1 1 1 1 1` writes a ParaView file with 20-node cells, results in the global frame (`GLB`), one cell per element (the nine `1` are subdivisions). `PNT 1 ...` and `PNT 2 ...` ask for the values at two points: just before the tip and at mid-length near the top face.

## Step 8 – run

```bash
mkdir run & cd run
mkdir STATIC DYNAMIC WORK REPORT
xcopy /E /I ..\INPUT INPUT
MUL2_V3.exe INPUT
```

## Step 9 – read the results

`STATIC/POST_POINT.dat` has one row per point. The first row gives the tip displacement `U_Z = 5.674E-04` m. Beam theory predicts

$$
\delta_{EB}=\frac{PL^3}{3EI}=5.714\times10^{-4}\ \text{m},\qquad \delta_{Timoshenko}=5.759\times10^{-4}\ \text{m},
$$

so TE2 is 1.5 % lower than Timoshenko. The small difference is expected: the clamp of the model is a true three-dimensional clamp (the section cannot contract at $Y=0$), which stiffens the beam slightly.

Open `STATIC/RESULTS_PARA_01.vtk` in ParaView: choose `Displacements` as the "warp by vector" field to see the deformed beam, or colour by `Sigma_YY` to see the bending stress.

## Step 10 – change the model

**Higher order.** Replace `TE 2` by `TE 4` in all the node records (the DOF grow from 288 to 720) and rerun: the tip deflection becomes $5.685\times10^{-4}$ m. With `TE 1` it is $4.282\times10^{-4}$ m (−26 %): *Poisson locking* (the Theoretical Guide, chapter *The Carrera Unified Formulation*). TE2 is the lowest order for engineering use.

**Lagrange expansion.** Replace `TE 2` by `LE 2` (the second number is ignored for `LE`) and replace the section by a mesh of $2\times2$ Q9 elements (25 nodes). The tip deflection is $5.689\times10^{-4}$ m with 1 200 DOF.

**Natural frequencies.** Change `ANALYSIS.dat` to `103` with 4 modes and remove the load from `BC.dat` (keep the clamp). `DYNAMIC/FREQUENCIES.dat` then contains

```text
  Frequency  1:   8.242627792E+001
  Frequency  2:   8.242627792E+001
  Frequency  3:   4.963753952E+002
  Frequency  4:   4.963753952E+002
```

Modes 1 and 2 are the two bending modes (in the $x$–$y$ and in the $y$–$z$ plane: the same frequency because the section is square), modes 3 and 4 the second bending modes. Euler–Bernoulli gives $f_1=82.25$ Hz and $f_2=515.5$ Hz.

Table: The same beam with different models (5 B4 elements). {#tab:tutorial-results}

| Model | DOF | $w_{tip}$ [m] | $f_1$ [Hz] |
|---|---|---|---|
| Theory (Euler–Bernoulli / Timoshenko) | – | $5.714\times10^{-4}$ / $5.759\times10^{-4}$ | 82.25 |
| TE1 | 144 | $4.282\times10^{-4}$ | 94.61 |
| TE2 | 288 | $5.674\times10^{-4}$ | 82.43 |
| TE4 | 720 | $5.685\times10^{-4}$ | 82.32 |
| LE (2×2 Q9) | 1 200 | $5.689\times10^{-4}$ | 82.33 |
| Plate strip (Q9) | 459 | $5.666\times10^{-4}$ | 82.48 |
| Solid (H27) | 459 | $5.663\times10^{-4}$ | 82.53 |

## Common mistakes in this tutorial

- **Forgetting the output directories** (`STATIC`, `DYNAMIC`, `WORK`, `REPORT`): the program creates them, but if you run it from a read-only folder it cannot.
- **A load that is not on a section node**: `POINT LOAD LOCATION WAS NOT FOUND`.
- **A section mesh with the wrong node order** in `EXP_CONN`: distorted or negative areas; the node order of the Q9 must follow Figure {fig:el2d-user}.
- **No constraint**: PARDISO error −4 (zero pivot) for a static problem, or a failed factorisation for the modal one.
