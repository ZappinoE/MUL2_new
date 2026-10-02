# Chapter 14 - Complete-aircraft demonstrator (analysis 103)

`EXAMPLES/AIRCRAFT/make_aircraft.py` writes the input of a twin-engine transport aircraft of the 737 class (38 m, span 36.6 m) and `MUL2_V3.exe` computes its free-vibration modes with analysis 103. It is a *dimensional* demonstrator: the sizes, the thicknesses and the masses are of the right order, not those of a real aircraft. Its purpose is to show that 1D, 2D and 3D elements, curved and flat, are put together with nothing but shared nodes and node-dependent kinematics.

```
python EXAMPLES/AIRCRAFT/make_aircraft.py --mesh fine --out RUN --modes 40
cd RUN
MUL2_V3.exe INPUT
python EXAMPLES/AIRCRAFT/plot_modes.py . 4 5 6 8
```

## The model

| Part | Elements | Notes |
|---|---|---|
| fuselage skin (nose, cylinder, tail cone) | `S9` shells, curved | surface of revolution; the thickness comes from the expansion mesh of the zone (`EXP_MESH_nn`), as for plates |
| frames, floor, floor beams | `S9` (web and flange), `S9` plate and `S9` strips | the floor beams carry the payload mass in their density |
| wings, horizontal and vertical tails | `S9` skins, spars and ribs | the skins of the lifting surface share the nodes of the fuselage at the root; skin, spar and rib share the nodes along their edges |
| leading- and trailing-edge fairings | `S9` | |
| engine pylon | four `S9` plates (box) | |
| engine | `H8` sheared solid blocks | joined to the pylon at isolated `TE 0` nodes |
| tie rods (pylon / wing skin) | `CB3` straight and curved | `TE 0` at the two end nodes |

The fine mesh has 14 433 nodes, 3 706 shells, 4 curved beams, 48 solids and 129 093 degrees of freedom. The materials are aluminium (skin, frames, ribs), an orthotropic carbon-epoxy ply (`ORT-M`, laminations 5/6, available for the skins), an equivalent material for the engines and two aluminium variants with a larger density that carry the **mass of the fuel (wing webs) and of the payload (floor beams)**. No mass element is used: the masses are smeared in the densities.

All the families are joined with **shared coincident nodes** (no multipliers, no constraint equations). The shells use `TE 2` at every node, also at the edges between skin, spar and rib (the first-order term of the node is the rotation of the node there, Chapter 13). The beams and the solids are joined at nodes with `TE 0`.

## Modelling rules that the demonstrator confirms

1. **Name the shells `S9`** (or `S4`, `S16`): the elements are then general elements and the edges between shells work as rigid edges. Shells of the same family that meet at a node must all be general.
2. **A `TE 0` node is a point, not a line.** A row of `TE 0` nodes along a rib or a ring suppresses the bending slope of the skin and makes the structure several times too stiff. The first versions of the demonstrator had stringers and longerons modelled as rows of `CB3` rods, and the clamped wing came out 4 to 6 times stiffer than beam theory; the stiffeners are now represented by the thicker skin (the bending of the box is carried by the skins), and the rods are used only for the tie rods of the engines.
3. A concentrated mass can be given as a larger density of the part that carries it (floor beams, fuel webs).

Check of the wing: the clamped wing box (uniform section, no fairings and no engines) with a tip load of $10\,\mathrm{kN}$ deflects $13.9$ mm, against $13.8$ mm of the beam theory ($PL^3/3EI$ with the thin-walled section).

## Results (fine mesh, 40 modes, 122 s wall, ARPACK 60 s)

The model is free: the first six modes are the rigid-body modes (three of them come out as numerically negative eigenvalues of the order of $10^{-6}$ and are discarded with a warning). The first elastic modes are:

| Mode | f [Hz] | Character |
|---|---|---|
| 4 | 0.89 | vertical bending of wings and fuselage, with the fin |
| 5 | 1.55 | lateral bending of the fuselage and of the fin |
| 6 | 2.25 | wing bending, symmetric |
| 7 | 2.61 | vertical, wing and tail |
| 8 | 2.63 | wing bending, antisymmetric, with fin |
| 9 | 3.82 | lateral, fin |
| 10 | 3.95 | wing in-plane |
| 11 | 4.76 | outer wing |
| 14 | 7.45 | fuselage |

From about $9$ Hz the spectrum is a mixture of global modes and of local modes of the floor and of the fuselage skin between frames (the table printed by `plot_modes.py` gives, for every mode, the fraction of the points that move and the share of the modal displacement in fuselage, wings and fin). The pictures `aircraft_mode_NN.png` show the plan and side view, the colour is the modulus of the modal displacement and the points are moved by the mode.

## Static analysis (101)

`--static F` writes the same model as an analysis 101: fuselage clamped at the nose ring (`D-PLANE` at $x=5$ m) and a vertical force $F$ at the tip of each wing. With $F=50$ kN the maximum displacement is $0.34$ m, the two tips deflect $0.3301$ m (symmetric to $5\cdot10^{-5}$) and the run takes 27 s (assembly $4.8$ s, solution $2.5$ s). The results are in `EXAMPLES/AIRCRAFT/RESULTS_STATIC`.

## Time

Assembly of $K$ and $M$: $4.9$ s; ARPACK, 40 modes: $60$ s; the writing of the VTK/GMSH output of 40 modes is $56$ s. The medium mesh (7 600 nodes, 68 000 DOF) takes 34 s for 30 modes, the coarse one a few seconds.

## Limits

* Idealised aircraft: the sizes are plausible, the stiffnesses of the stiffeners and the masses are not those of a real design (the first bending frequency of a real aircraft with fuel is higher).
* No stringers modelled as separate beams over the skin: a stringer is a row of beam nodes with `TE 0` and the skin would be locked along it (Chapter 13, limits). A full stringer model needs a beam element with the rotation of the skin, which is a future extension.
* Curved elements are available in every analysis (101, 103, 104, 105, 106, 108); only the surface loads are not available on them.
