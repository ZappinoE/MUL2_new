# MUL2_NEW

Programma FEM/CUF unificato (Fortran, forma fissa, real64) per analisi
101 (statica lineare) e 103 (vibrazioni libere lineari).

- Eseguibile: `MUL2_V3.exe [cartella_input]`. Senza argomento legge
  `PATH_input.dat`, altrimenti usa `INPUT`. Uscita con codice 1 su errore.
- Formato input e nomi dei file di output: quelli legacy (vedi `DOC/`).
- Uscite: `STATIC/`, `DYNAMIC/`, `REPORT/WARNING_file.dat`, `WORK/`.
- Progetto Visual Studio: `CREATE_VS_SOLUTION.cmd open` (CMake e' l'unica
  sorgente di verita').
- Interfaccia web: `INTERFACE/Start-MUL2-Interface.cmd`.
- Stato, differenze dalla baseline e validazione: `DOC/STATUS.md`.
- Regole di codice: `SPECIFICHE_CODICE_FORTRAN.md`.
