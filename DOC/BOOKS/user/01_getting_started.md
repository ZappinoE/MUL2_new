# Getting started

## What MUL2_NEW does

MUL2_NEW analyses linear elastic **beams, plates and solids**, alone or mixed in the same model, with a family of refined structural theories (the Carrera Unified Formulation). It answers two questions:

1. **Static analysis (101):** how does the structure deform and what are the strains and stresses under point loads and supports?
2. **Free vibration (103):** what are its natural frequencies and mode shapes?

You describe the structure with a handful of text files, run one executable and read text, VTK and GMSH files. The workflow is:

![Typical workflow.](figures/workflow.svg){#fig:workflow-user}

## Requirements

- Windows 10/11 (64-bit).
- The Intel oneAPI runtime libraries (MKL and the Fortran/OpenMP runtime) must be found at run time: either install oneAPI or put its `mkl\...\bin` and `compiler\...\bin` directories in the `PATH` (the web interface does this for you).
- For visualisation: ParaView (VTK files) or GMSH (`.msh` files). Any text editor to edit the inputs.

The executable is `MUL2_V3.exe`. If you do not have it, build it as described in the Implementation Guide (`CREATE_VS_SOLUTION.cmd build`).

## Your first run in two minutes

The folder `DOC/BOOKS/examples/cases` contains ready-to-run inputs. Take the cantilever beam with Taylor order 2:

```bash
mkdir run1 & cd run1
mkdir STATIC DYNAMIC WORK REPORT
xcopy /E /I ..\DOC\BOOKS\examples\cases\beam_te2_static\INPUT INPUT
..\BUILD\WINDOWS_IFX\Release\MUL2_V3.exe INPUT
```

The console prints something like

```text
[INFO] MUL2_V3 RUNTIME INITIALIZED
[INFO] INPUT DIRECTORY: INPUT
[INFO] MODEL: 16 NODES, 5 ELEMENTS, SOLUTION 101
[INFO] PREPROCESSING: 288 DOF, 180 GAUSS POINTS
[INFO] K ASSEMBLED: 288 DOF, 24624 NNZ,     0.012 S
[INFO] STATIC SOLVE:     0.096 S, MAX |U| =   8.4935E-04
[INFO] WRITTEN STATIC/RESULTS_PARA_01.vtk
[INFO] TIMES [S] INPUT/PRE/ANALYSIS/OUT:    0.005    0.000    0.108    0.032
[INFO] CPU [S]:     0.171875  WALL [S]:     0.223000
```

> NOTE: `MAX |U|` is the largest *coefficient* of the solution vector. With a Taylor expansion the coefficients of the higher terms are not displacements of a point, so this number is only a sanity check (not the tip deflection). Read displacements from `POST_POINT.dat`.

The results are in `STATIC/POST_POINT.dat` (values at the requested points), `STATIC/RESULTS_PARA_01.vtk` (the field, to open in ParaView) and `REPORT/WARNING_file.dat` (warnings, if any). The exit code is 0 when everything went well.

> NOTE: The program writes its outputs in the **current directory**, in the folders `STATIC`, `DYNAMIC`, `WORK` and `REPORT` (it creates them if missing). The input directory can be given as the first argument; without an argument the program reads the name of the input directory from the first line of the file `PATH_input.dat` and, if that file does not exist, uses `INPUT`.

## Command line

```bash
MUL2_V3.exe [input_directory]
MUL2_V3.exe --version
```

Environment variables that change the behaviour:

Table: Environment variables. {#tab:envvars}

| Variable | Effect |
|---|---|
| `OMP_NUM_THREADS` | number of threads used for the assembly and the output (results do not depend on it) |
| `MUL2_DEBUG` | `1` prints extra debugging lines |
| `MUL2_GENERAL_KERNEL` | `1` uses the slower reference element kernel (for checks) |

## What is in a run directory

```text
my_run/
  INPUT/                  your input files (see Chapter 4)
  PATH_input.dat          (optional) one line: the name of the input directory
  STATIC/                 results of analysis 101
  DYNAMIC/                results of analysis 103
  WORK/                   matrix dumps and solver information
  REPORT/                 WARNING_file.dat
```

## The web interface

The folder `INTERFACE` contains a graphical **input editor and launcher**. Start it with `INTERFACE\Start-MUL2-Interface.cmd` and open `http://localhost:8765/` in a browser. It offers:

- **Editor**: one form per input file with checks of the cross-references between files;
- **Side-by-side** and **Raw text**: edit the text directly with the formatted view next to it;
- **3D Model**: a three-dimensional view of the structure (beams with their section, plates with exaggerated thickness, solids), supports and loads;
- **Run & Results**: send the current input set to the solver, read its console output and download the result files.

Use **New** to start from a template, **Load** to read files, **Folder** to work directly on a folder of your disk, **Save** and **Export** to write the files. Everything the interface does is writing input files and running the executable: you can always do the same by hand.
