# Aircraft demonstrator (analysis 103)

Generate, run and plot:

    python make_aircraft.py --mesh fine --out RUN --modes 40
    cd RUN && MUL2_V3.exe INPUT
    python plot_modes.py RUN 4 5 6 8

Meshes: coarse, medium (68k DOF, 34 s), fine (129k DOF, 2 min). Description, rules and results: DOC/BOOKS/user/11_aircraft_demonstrator.md (User Guide, chapter *Complete-aircraft demonstrator*).


Static analysis 101 (nose ring clamped, force at each wing tip): python make_aircraft.py --mesh fine --out RUN --static 50000. Results of the 50 kN case: RESULTS_STATIC (about 0.34 m maximum displacement, 27 s).
