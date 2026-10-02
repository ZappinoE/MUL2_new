# MUL2_NEW - Note di ottimizzazione e commenti a margine

Revisione del codice dopo l'introduzione di multifisica e analisi 104-108.
Tutti gli interventi sono verificati: 13 suite `ctest` (Release e Debug) e
confronto bit a bit tra 1 e N thread (`TESTS/EXTENDED`).

## 1. Ottimizzazioni (dove il tempo va davvero)

| Zona | Prima | Intervento | Effetto |
|---|---|---|---|
| Kernel di punto (`mul2_element_matrices.for`) | tabelle ricalcolate a ogni punto | tabelle di punto (`POINT_WORK_TYPE`, `SETUP_POINT_WORK`, `EVALUATE_POINT_COLUMNS`, `COLUMN_FROM_BASIS`) costruite una volta per punto di Gauss | niente ricalcolo di base/derivate per DOF locale |
| Prodotti `BᵀMB` | doppio ciclo sui termini (NR 6/9/12) | prodotto impilato di rango 9 (`ACCUMULATE_UPPER_PRODUCT`), solo il triangolo superiore | assemblaggio non lineare 29 s -> 13 s, suite non lineare 40 s -> 18 s |
| Assemblaggio matrici | ciclo sugli elementi | blocchi di elementi in parallelo (OpenMP, `ASSEMBLE_*_VALUES`), accumulo per blocco nei puntatori CSR senza sezioni critiche | risultato identico per qualsiasi numero di thread |
| Matrice geometrica e non lineare | seriale | stesso schema a blocchi paralleli (`ASSEMBLE_GEOMETRIC_VALUES`, `ASSEMBLE_NONLINEAR_VALUES`) | scalabilita' come K |
| Temporanei di array | `MATMUL` sullo stack del thread -> stack overflow | `ACCUMULATE_PRODUCT` senza temporanei + opzione `/heap-arrays:256` | nessun crash, nessun costo misurabile |
| Smorzamento 104/106 | codice duplicato | `MUL2_DYNAMIC_COMMON`: classi di DOF, valori di Rayleigh/riscaldamento termoelastico, ricerca binaria nel pattern CSR (ciclo sulle righe parallelo) | meno codice, stesso risultato |
| Frequenza 106 | sistema complesso non simmetrico | blocco reale simmetrico quando non c'e' T | fattorizzazione ~2x piu' leggera |
| Post-processo | ricerca del punto per ogni uscita | cache `LOCATE_ALL_POINTS` (elemento e coordinate naturali) | uscite lineari nel numero di punti |
| Carichi superficiali | confronto tutti-contro-tutti | ricerca per centro con ordinamento/hash | 5184 pezzi in 0,03 s |

Colli di bottiglia residui (misurati): fattorizzazione PARDISO (domina 106:
~0,9 s per frequenza a 5,4k DOF), buckling denso (limite 8000 DOF liberi),
kernel puntuale ~10 volte piu' lento del separabile (usato solo con
rigidezza non separabile: multifisica/ibride).

### Elementi curvi (kernel generale)

`MUL2_GENERAL_KERNEL` ha lo stesso schema del kernel a punti (prodotti
a blocchi con `ACCUMULATE_UPPER_PRODUCT`, assemblaggio in parallelo per
elementi, nessuno stato). Misura (Release, shell `S9` con `TE 2`, 81 DOF e
27 punti per elemento): **1,3 ms per elemento** con un thread (tubo
quadrato di 192 elementi, 7200 DOF: 0,24 s); le tabelle di tying sono
calcolate una volta per elemento, i fattori di espansione una volta per
punto e per (cinematica, campo, termine). In Debug con `/check:all` lo
stesso assemblaggio costa 4 s: i tempi dei test Debug non rappresentano
la versione Release.

## 2. Pulizia del codice

- `ANY_FIELD_ACTIVE(DATABASE, FIELD)` (in `MUL2_KINEMATICS`) sostituisce i
  cicli ripetuti in 101, 103, 104, 106, 108.
- `BUILD_MECHANICAL_BOUNDARY_DATA` ha ora un wrapper con `FIELDS` opzionale e
  una routine interna con `FIELDS` obbligatorio (eliminato `MERGE_FIELDS`).
- Rimossi `EVALUATE_LOCAL_DOF`, variabili inutilizzate, matrice di massa
  superflua in 104.

## 3. Commenti a margine (parafrasi)

Ogni istruzione dei sorgenti (`SRC` e `TESTS`, 15393 istruzioni) porta dopo la
colonna 72 una frase in inglese che la riformula in linguaggio naturale
(`! Set cdamp(pos) to ...`). Il compilatore ignora il testo oltre la colonna
72 (avviso 5194 disattivato con `/Qdiag-disable:5194`); `CHECK_FIXED_FORM`
accetta oltre la 72 solo `spazi + !`.

Strumenti:

```
python TOOLS/paraphrase.py FILE ...    # (ri)genera le note, il codice non cambia
python TOOLS/annotate.py strip FILE    # toglie tutte le note
python TOOLS/annotate.py list FILE     # istruzioni senza nota
```

La parafrasi e' generata da regole (DO, IF, CALL, ALLOCATE, WRITE, dichiarazioni,
assegnazioni, ...): le parti di codice sono riportate in minuscolo e senza
suffissi di kind. Dopo aver modificato un file conviene fare `strip`, modificare
e rigenerare le note. Verificato: la parte di codice di tutti i file e'
identica a quella prima dell'annotazione e tutte le suite passano.
