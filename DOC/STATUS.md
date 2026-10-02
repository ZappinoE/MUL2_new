# MUL2_NEW - STATO DI IMPLEMENTAZIONE

## AGGIORNAMENTO 2026-10-01: MULTIFISICA E NUOVE ANALISI

Analisi disponibili: 101 statica, 103 vibrazioni libere, **104 risposta nel
tempo (Newmark)**, **105 buckling lineare**, **106 risposta in frequenza**,
**108 statica non lineare geometrica (Lagrangiana totale, Newton-Raphson)**.

Fisiche (campi attivi in KINEMATICS.dat): spostamenti, **temperatura (T)**,
**potenziale elettrico (P)**, accoppiate nello stesso sistema monolitico
(non simmetrico quando c'e' la temperatura). Materiali: `Z-EXP`, `Z-PRM`,
`T-EXP`, `T-CON`, `T-SPC`, `PIROE`, `DAMP`. Condizioni al contorno: `V-PLANE`,
`V-POINT`, `V-FLOAT` (elettrodo flottante, 101/103), `T-PLANE`, `T-POINT`,
`T-CONST`, `Q-POINT`, `Q-PLANE`, `Q-SUN`, `Q-CONV`, campo spaziale opzionale
da `FIELDS.dat` sui valori. File di analisi: `TIME_RESP.dat`, `FREQ_RESP.dat`,
`NL_INFO.dat`.

Verifica: `ctest` (Release e Debug) 13 suite, campagna `TESTS/VALIDATION`
373 controlli senza errori, campagna estesa `TESTS/EXTENDED`. Analisi critica
in `CRITICAL_ANALYSIS.md`. Manuali aggiornati (guide teorica, implementativa,
utente).

**Travi curve e shell (2026-10-02)**: geometria generale per punto con triadi nodali (`MUL2_GENERAL_GEOMETRY`, `MUL2_GENERAL_KERNEL`), `CB2 CB3 CB4`, `S4 S9 S16` o rilevamento automatico (nodi fuori linea/piano), spessore dalla mesh di espansione, `DIRECTORS.dat` opzionale, MITC4/MITC9/trave, TE/LE/HLE, unione per nodi condivisi con cinematica nodo-dipendente (nessun moltiplicatore). Analisi 101/103/104/106. Test `MUL2_CURVED_TESTS`. Spigoli tra shell con normali diverse: il termine del primo ordine e la rotazione del nodo (scatola sottile entro il 3 % della teoria della trave). Dimostratore aereo completo (analisi 103, 129k DOF, 2 min): `EXAMPLES/AIRCRAFT`, cap. 14 della guida utente.

**Revisione 2026-10-02**: ottimizzazione/parallelizzazione e commenti a
margine (parafrasi oltre la colonna 72) in tutti i sorgenti; vedi
`OPTIMIZATION_NOTES.md` e `TOOLS/paraphrase.py`.

---

Questo documento aggiorna lo stato reale rispetto a `IMPLEMENTATION_PLAN.md`
(scritto per lo skeleton). Ambito: solo analisi 101 (statica lineare) e
103 (vibrazioni libere lineari). Altre analisi: errore esplicito del driver.

## COSA E' IMPLEMENTATO

- Lettura input legacy: ANALYSIS, NODES (legacy `TE|LE` oppure KINEMATICS.dat),
  CONNECTIVITY, MATERIAL, LAMINATION, VERSORS, EXP_MESH/EXP_CONN, BC,
  POSTPROCESSING (record mancanti in coda: warning come nella baseline).
- Elementi B2 B3 B4 Q4 Q9 Q16 T3 T6 H8 H27 (H20, T4, T10, P6 NON implementati: errore esplicito), cinematiche TE e LE.
- Trattamento del taglio per famiglia (ANALYSIS.dat): NONE, REDI (integrazione ridotta,
  rigidezza e massa), SELI (selettiva: termini con deformazioni di taglio ridotti, massa piena),
  MITC. REDI/SELI riproducono la baseline a 1e-7. Il record del solutore e' stato tolto
  da ANALYSIS.dat (il vecchio formato e' ancora letto, con warning).
  Tabelle di tying equivalenti alla baseline per B2 B3 B4 Q4 Q9 H8 H27.
  Nessuna tabella per Q16 T3 T6: warning e integrazione piena.
  H8 + MITC: regolare e utile (vedi VALIDAZIONE 2026-10-01; l'affermazione
  precedente di matrice singolare non e' piu' vera).
- Assemblaggio CSR 1-based ILP64, pattern condiviso K/M, valutazione elementi
  in parallelo OpenMP a blocchi con scatter seriale deterministico.
- 101: eliminazione esatta simmetrica dei vincoli + PARDISO (mtype 2).
- 103: riduzione ai DOF liberi, ARPACK shift-invert (dsaupd/dseupd, /4I8),
  fallback denso LAPACK dsygv per N<=400 o nev>=N-2; residui calcolati.
- Post-processing: POST_POINT.dat, VTK (PARA) e GMSH, FREQUENCIES.dat,
  RESULTS_DYN_*, dump K/M/FORCES/UNKNOWN in WORK, WARNING_file.dat.
- Interfaccia web `INTERFACE/` (run_interface.ps1): parla con il solver solo
  via file (INPUT/*.dat -> STATIC, DYNAMIC, REPORT). Solo 101 e 103 esposti.

## DIFFERENZE INTENZIONALI DALLA BASELINE

- Vincoli: eliminazione esatta invece della penalita' 1e10. Differenze sugli
  spostamenti ~1e-7 relativo; frequenze ~4e-6.
- MITC in post: la baseline usa lo Jacobiano del punto di valutazione nei
  tying point; MUL2_NEW quello del tying point. Le deformazioni a taglio
  differiscono ~1% solo con nodi non uniformi (identiche con nodi uniformi).
- Piastra NONE: la baseline produce deformazioni a taglio errate in post;
  qui sono corrette.
- Punti di post-processing non trovati: riga NaN + warning (la baseline
  restituiva zeri).
- Duplicati di nodi/elementi: controllo O(n log n) invece di O(n^2).

## VALIDAZIONE (ctest, tutte le configurazioni)

`MUL2_ANALYSIS_TEST` esegue l'exe su `TESTS/CASES/*` e confronta con i
riferimenti generati dalla baseline congelata (`MUL2_OPTIMIZED`):

| Caso | Esito |
|------|-------|
| beam golden 101 (MITC) | U ~1e-7, deformazioni ~2e-7 |
| plate golden 101 | 1e-8 |
| mixed B4+Q9+H27, NONE e MITC | 1e-15 |
| beam B3 TE2 MITC, plate Q4, Q9x4, solid H8 | 1e-6..1e-9 |
| modale golden 103 | frequenze 3e-9, MAC=1.000000 su 20 modi |
| modale piastra Q9x4 e beam B3 TE2 | ~4e-6 (effetto penalita' baseline) |
| patch test (B4 LE, Q9, H8), deformazione uniforme | esatti a 1e-9 |
| seriale vs 4 thread | identici bit a bit |

Debug, Release e Release_Fast: 4/4 test passati. `CHECK_FIXED_FORM` passa
(forma fissa, <=72 colonne). Prestazioni (Release, trave 200 elementi, 27k DOF):
assemblaggio 1.0 s, soluzione 0.43 s, output 1.8 s.

## NON VERIFICATO / APERTO

- Build gfortran/Linux: preset presenti ma mai eseguiti (senza MKL il
  solver restituisce errore esplicito).
- Runtime Intel/MKL linkato dinamicamente: per distribuire l'interfaccia su
  macchine senza oneAPI servono le DLL accanto all'exe (oppure link statico).
- Misc non supportato (errore esplicito); HLE implementato (HQ4/HB2). Q16 e T3/T6 senza MITC.
- T3 come sottoelemento di sezione: regola a 1 punto (come la baseline), da
  evitare (vedi report di validazione); usare T6 o Q9.
- Frame LOC con versori ruotati: validato solo dove coincide con GLB.
- Nessuna validazione ancora su laminati con angoli diversi da 0/90.

## COME SI COSTRUISCE

```
CREATE_VS_SOLUTION.cmd open      (genera BUILD\WINDOWS_IFX\MUL2_V3.sln e lo apre)
cmake --build BUILD/WINDOWS_IFX --config Release
ctest --test-dir BUILD/WINDOWS_IFX -C Release --output-on-failure
INTERFACE\Start-MUL2-Interface.cmd   (GUI su http://localhost:8765/)
```

## AGGIORNAMENTO 2026-10-01

- Corretto il bug dell'integrazione di espansioni Taylor di ordine > 2 (regola di Gauss con N+1 punti per direzione); nuovo caso TESTS/CASES/beam_te8_unit.
- Kernel elementare separabile CUF, pattern senza zeri strutturali (LE), fallback Cholesky verso indefinito, riduzioni di memoria: vedi DOC/BENCHMARK.md (confronto con la baseline a circa 100000 DOF: 2-3 volte piu' veloce, memoria uguale o minore).
- Viewer 3D dell'interfaccia: supporto a plate e solidi.


## VALIDAZIONE COMPLETA 2026-10-01

Campagna in TESTS/VALIDATION (python run_all.py; build_report.py): 373 controlli,
552 run, 0 FAIL, 18 informativi. Report: DOC/MUL2_NEW_Validation_Report.pdf.
Copre Taylor 1-20, LE (Q4 Q9 Q16 T3 T6), HLE, piastre, solidi, NDK
(TE-m/TE-n, TE/LE, HLE/TE, HLE/LE), multidimensionale (giunzioni TE0),
MITC vs integrazione piena. ctest Release e Debug 6/6 (corretto un falso
errore di bounds-check nel Debug in mul2_gauss_geometry.for).

**Verifica (2026-10-02)**: il capitolo Verification della guida teorica contiene ora una sezione per ogni funzione aggiunta (HLE, integrazione ridotta, multifisica, dinamica, buckling, non lineare con arc length, travi curve e shell, aereo). Tutti i 14 gruppi ctest passano in Release; sorgenti ri-annotati.

**Campi e unione (2026-10-02)**: attivazione dei campi da `ANALYSIS.dat` (`FIELDS MECH THERMO PIEZO`; `STRESS`/RMVT riservato, errore), unione dei DOF per coincidenza (`JOIN COINCIDENT [tol]`, test `MUL2_JOIN_TESTS`), validazione estesa con i gruppi multicampo e non lineare (report di validazione), guide A4 e A5 aggiornate.
