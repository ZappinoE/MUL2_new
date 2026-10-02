# Specifica tecnica del nuovo codice MUL2/CUF in Fortran

Stato: baseline progettuale provvisoria, da consolidare dopo il completamento
della copia dei codici Original, Gauss-point, Nonlinear e Field-dependent.

Regola di prevalenza: in caso di conflitto, hanno priorita nell'ordine:
correttezza matematica verificata, requisiti espliciti dell'autore, risultati di
regressione, presente specifica, comportamento storico non documentato.

## 1. Scopo

Realizzare una nuova versione del codice FEM/CUF in Fortran moderno che:

1. mantenga la generalita delle formulazioni CUF 1D, 2D e 3D;
2. supporti Node-Dependent Kinematics (NDK) e cinematiche field-dependent;
3. usi una pipeline di integrazione centrata sui punti di Gauss;
4. riunisca in un'unica architettura le funzionalita corrette dei codici forniti;
5. elimini duplicazioni e stato globale non necessario;
6. sia leggibile e modificabile da uno studente con conoscenze FEM/CUF;
7. sia verificabile mediante test unitari, patch test e regressioni old/new;
8. possa essere compilato su Windows e Linux;
9. sia predisposto a parallelizzazione CPU e, successivamente, GPU;
10. non modifichi le cartelle dei codici di riferimento.

Il prodotto finale deve essere Fortran. Eventuali strumenti Python possono
essere usati esclusivamente fuori dal solver per generare dati di test,
confrontare risultati o costruire input; non devono essere una dipendenza del
programma Fortran.

## 2. Ambito funzionale

### 2.1 Solution ID da mantenere

Il dispatcher pubblico deve accettare soltanto:

`101, 103, 104, 105, 106, 111, 121, 123, 126, 131, 136`.

Mapping attualmente verificato sul codice precedentemente disponibile:

| ID | Analisi | Operatori principali | Stato |
|---:|---|---|---|
| 101 | statica meccanica | Kuu | verificato |
| 103 | modale meccanica, anche con contributi complessi | Kuu, M, Kui | verificato |
| 104 | risposta meccanica nel tempo | Kuu, M, damping, Newmark | verificato |
| 105 | buckling lineare dopo precarico | Kuu, Kgeo | verificato |
| 106 | risposta armonica meccanica | Kuu, M, damping/Kui | verificato |
| 111 | statica termo-meccanica | Kuu, KuT | verificato |
| 121 | statica piezo-meccanica | sistema accoppiato U-phi | verificato a livello di chiamate |
| 123 | analisi modale piezo-meccanica | sistema accoppiato, M | verificato a livello di chiamate |
| 126 | risposta armonica piezo-meccanica | sistema accoppiato, M, damping | verificato a livello di chiamate |
| 131 | dichiarata termo-piezo-meccanica | nel sorgente visto risultava attiva solo KuT | anomalia da risolvere |
| 136 | da determinare | nessuna procedura trovata nel sorgente visto | bloccato fino a evidenza |

Il numero dell'analisi non deve determinare implicitamente dimensione,
topologia o cinematica. Queste proprieta appartengono al modello e agli
elementi.

### 2.2 Famiglie cinematiche

La nuova architettura deve poter rappresentare senza duplicare le procedure FEM:

- Taylor Expansion (TE), ordine arbitrario supportato;
- Lagrange Expansion (LE), inclusi modelli layerwise;
- zig-zag/RMVT, se confermati e validati nei sorgenti forniti;
- 3D displacement-based come caso limite della stessa pipeline;
- NDK: tipo e ordine dell'espansione differenti per ogni nodo FEM;
- field-dependent kinematics: spazi di approssimazione diversi per campo;
- beam e plate con sezione/spessore variabile;
- laminazioni classiche, layerwise, compositi e VAT.

I token di input presenti ma privi di una implementazione completa non devono
essere dichiarati supportati. Devono produrre un errore diagnostico esplicito.

### 2.3 Elementi

Elementi da ricostruire e validare dai codici di riferimento:

- lineari: B2, B3, B4;
- quadrilateri: Q4, Q9, Q16;
- triangolari: T3/Q3 e T6/Q6, solo se l'integrazione originale e completa;
- esaedri: H8, H20, H27;
- tetraedri/prismi: T4, T10, P6 o codici equivalenti, solo dopo verifica;
- punti MITC tying, quando richiesti dalla formulazione.

Ogni topologia deve avere una sola implementazione di valori e derivate delle
funzioni di forma.

### 2.4 Fisiche

Il nucleo iniziale deve coprire i campi necessari agli ID mantenuti:

- meccanico;
- termico;
- potenziale elettrico/piezoelettrico.

Magnetico, igroscopico, diffusivo, aeroelastico, fluidodinamico, impact/soft e
nonlinearita materiale sono estensioni ammesse dall'architettura ma devono essere
abilitate soltanto se presenti nei codici forniti e accompagnate da una
formulazione e da test verificabili.

## 3. Vincoli tecnologici

- Linguaggio: Fortran 2008 come baseline; estensioni Fortran 2018 soltanto se
  supportate dai compilatori selezionati.
- Formato sorgente obbligatorio: Fortran fixed form, estensione `.for`.
  Le colonne seguono la convenzione tradizionale: label 1-5, continuazione 6,
  istruzioni 7-72. Il nuovo codice deve restare entro colonna 72; le opzioni
  compilatore che accettano righe piu lunghe servono soltanto per importare e
  diagnosticare sorgenti legacy.
- Commenti fixed form con `!` nel campo istruzioni o `C` in colonna 1. Le nuove
  continuazioni usano `&` in colonna 6 in modo uniforme.
- I file che richiedessero preprocessore devono usare `.F`; il preprocessore
  non deve essere necessario per comprendere le formule scientifiche.
- Precisione: `real(real64)` da `iso_fortran_env`; vietati `REAL*8` e kind numerici.
- Interi: kind espliciti dove serve interoperabilita o grandi indici.
- Compilatori minimi: Intel oneAPI `ifx` su Windows; GNU `gfortran` su Linux.
- Build primaria: CMake con preset Debug/Release; file progetto Visual Studio
  generato da CMake, non mantenuto manualmente.
- Backend numerici dietro interfaccia: MKL/PARDISO e ARPACK quando disponibili;
  backend LAPACK/reference per test piccoli.
- OpenMP opzionale, disattivabile a build e runtime.
- Nessuna dipendenza obbligatoria da Python durante compilazione o esecuzione.

## 4. Principi architetturali obbligatori

1. Single source of truth: forma, derivata, trasformazione, quadratura,
   operatore e legge materiale sono implementati una sola volta.
2. Dipendenze unidirezionali: i moduli matematici di base non dipendono da
   mesh, analisi o solver.
3. Assenza di stato globale mutabile nei kernel: nessun `ELE_ID`, `I_ID`,
   `T_ID` o matrice costitutiva scratch condivisa durante l'integrazione.
4. Procedure corte: una routine deve svolgere una operazione matematica o
   orchestrativa chiaramente nominata.
5. Dati espliciti: input e output delle procedure devono comparire negli
   argomenti; `use` serve per tipi e costanti, non per trasferire stato nascosto.
6. Errori espliciti: niente prosecuzione con matrici nulle dopo un ramo non
   implementato.
7. Codice leggibile: formule riconoscibili, riferimenti alla notazione
   teorica e commenti sintetici ma chiari.
8. Separazione core/adapters: compatibilita con input e convenzioni legacy
   confinata in moduli di adattamento.

## 5. Struttura proposta dei sorgenti

```text
MUL2_FORTRAN/
  CMakeLists.txt
  cmake/
  app/
    mul2_main.for
  src/
    base/          kinds, constants, status, diagnostics, timing
    math/          small matrices, tensor/Voigt transforms, frames
    geometry/      nodes, frames, coordinate maps
    mesh/          connectivity, elements, sections, laminations
    interpolation/ shape functions and derivatives
    quadrature/    Gauss rules and MITC tying rules
    materials/     elastic and coupled material laws
    kinematics/    TE, LE, NDK and field-dependent layouts
    integration/   Gauss-point construction and caches
    operators/     B, field gradients and CUF nuclei
    elements/      local matrices/vectors
    assembly/      DOF map, sparsity, local-to-global assembly
    boundary/      essential and natural conditions
    analysis/      retained solution-ID drivers
    solvers/       linear, eigen, transient and harmonic interfaces
    post/          recovery, probes, VTK/text output
    restart/       optional checkpoint/restart
    legacy_io/     readers and conversion of existing files
  tests/
    unit/
    elements/
    patch/
    regression/
  docs/
```

I moduli di livello inferiore non possono usare moduli di cartelle successive.
`analysis` orchestra i servizi ma non contiene formule elementari.

## 6. Modello dati

### 6.1 Tipi geometrici e mesh

`node_t`

- ID esterno;
- coordinate globali;
- eventuale frame o riferimento a un frame;
- metadati minimi, senza copie per elemento.

`element_t`

- ID e topology ID;
- lista di node ID;
- dimensione naturale e dimensione fisica;
- frame locale;
- region/material/lamination ID;
- kinematics layout ID;
- riferimenti alle liste dei punti di integrazione;
- DOF map locale-globale.

`mesh_t`

- array unico dei nodi;
- array unico degli elementi;
- tabelle di regioni, sezioni e connettivita;
- niente duplicazione completa delle coordinate dentro ogni elemento.

### 6.2 Cinematica e DOF

`expansion_t`

- family: TE, LE, 3D o estensione verificata;
- ordine/topologia dell'espansione;
- assi dell'espansione;
- layer/section mesh ID;
- funzioni per numero modi, valori e derivate.

`node_kinematics_t`

- expansion ID per ciascun campo;
- numero locale di modi per campo;
- offset nel vettore locale.

`dof_layout_t`

- chiavi esplicite `(node_id, mode_id, field_id, component_id)`;
- offset compatti: nessun padding al massimo ordine NDK;
- mapping locale-globale costruito una sola volta;
- ordinamento documentato e stabile nei file di restart/output.

### 6.3 Punto di Gauss

`gauss_point_t` deve rappresentare un punto fisico completo, anche quando nasce
dal prodotto tra quadratura FEM e quadratura CUF di sezione/spessore.

Campi minimi persistenti in configurazione standard:

- `element_id`, `local_point_id`;
- coordinate naturali FEM e CUF;
- coordinate fisiche globali;
- peso complessivo e misura `weight * detJ`;
- Jacobiano, determinante e inversa/pseudoinversa appropriata;
- valori delle shape FEM;
- derivate naturali e fisiche;
- material/lamination ID e orientation/frame ID;
- quadrature channel: full, reduced, shear, MITC, ecc.;
- chiavi/offset necessari per i modi NDK coinvolti.

Quantita calcolate on demand nella configurazione standard:

- matrice costitutiva, se variabile nello spazio o nello stato;
- valori/derivate dell'espansione se il costo di memoria supera il riuso;
- operatori B e nuclei accoppiati;
- stress, strain e variabili interne.

Configurazioni di cache:

- `minimal`: geometria e identificativi;
- `standard`: aggiunge shape e derivate mappate;
- `debug/full`: aggiunge espansioni e operatori per ispezione.

La rappresentazione operativa per grandi modelli deve essere
`gauss_batch_t`, structure-of-arrays, per accessi contigui e `do concurrent` /
OpenMP. Il record `gauss_point_t` resta disponibile per chiarezza, debug e test.

## 7. Pipeline di calcolo

1. Lettura e validazione sintattica degli input.
2. Conversione degli input legacy in un `model_input_t` tipizzato.
3. Costruzione di nodi, elementi, sezioni, laminazioni e frame.
4. Costruzione delle cinematiche per nodo e campo.
5. Enumerazione compatta dei DOF.
6. Generazione dei punti FEM, CUF e MITC per ogni elemento.
7. Mapping geometrico e controllo Jacobiano/orientamento.
8. Risoluzione di materiale, layer e orientazione per ogni punto.
9. Precalcolo secondo la cache policy.
10. Costruzione preventiva del pattern CSR globale.
11. Per ogni elemento o batch di punti: valutazione dei contributi locali.
12. Assemblaggio thread-safe.
13. Applicazione delle boundary conditions.
14. Soluzione secondo il solution ID.
15. Recovery ai punti richiesti, output e statistiche.

La forma concettuale obbligatoria del kernel e:

```fortran
do point = first_point, last_point
  call evaluate_point_contribution(model, state, points(point), contribution, status)
  call accumulate_local(contribution, element_matrix)
end do
```

La routine non deve leggere o modificare indici globali impliciti.

## 8. Formulazione FEM/CUF

La separazione matematica deve essere esplicita:

1. interpolazione FEM `N_i`;
2. espansione CUF `F_tau`;
3. composizione del campo `N_i F_tau`;
4. operatore cinematico/gradiente;
5. legge costitutiva al punto;
6. Fundamental Nucleus;
7. integrazione;
8. matrice/vettore elementare;
9. assemblaggio globale.

Per l'elasticita lineare:

`K_e += B_tau^T C(x_gp) B_s dOmega`

`M_e += rho(x_gp) N_tau^T N_s dOmega`

Non devono esistere copie manuali del nucleo per ordine TE, numero di layer o
combinazione NDK. Le ottimizzazioni analitiche possono essere introdotte solo
dopo confronto con il kernel generale e devono condividere gli stessi test.

La quadratura ridotta/selettiva deve usare canali nominati associati ai blocchi
di strain; non e ammesso modificare una variabile `NGP` condivisa e riutilizzarla
implicitamente in formule differenti.

## 9. Materiali e convenzioni tensoriali

Convenzione meccanica compatibile con il nucleo MUL2 precedentemente analizzato:

- stress: `[sigma_xx, sigma_yy, sigma_zz, sigma_xz, sigma_yz, sigma_xy]`;
- strain: `[eps_xx, eps_yy, eps_zz, gamma_xz, gamma_yz, gamma_xy]`;
- shear strain ingegneristiche: `gamma_ij = 2 eps_ij`.

Questa convenzione deve comparire in una sola enumerazione/modulo e in tutta la
documentazione. Le trasformazioni di stress e strain devono essere distinte per
gestire correttamente i fattori 2.

`material_t` deve contenere:

- material ID e kind;
- proprieta nel frame materiale;
- densita e coefficienti accoppiati;
- legge spaziale/field/layer opzionale;
- identificativo della legge costitutiva e delle variabili interne.

La matrice globale viene richiesta tramite una sola API, ad esempio:

```fortran
call evaluate_material(material, x, time, fields, orientation, state, response, status)
```

`response` specifica chiaramente il frame e contiene tangenti/coupling coerenti.
L'adattatore ORT-M legacy deve documentare lo scambio storico dei primi due
moduli e le direzioni dei coefficienti di Poisson. Nessuna trasformazione deve
essere duplicata nei nuclei elementari.

Per la nonlinearita materiale, le variabili interne devono risiedere in uno
storage separato indicizzato per punto, con stati committed/trial. Non devono
essere inserite nel record geometrico immutabile.

## 10. Assemblaggio e parallelizzazione

- Formato globale di riferimento: CSR a indici 1-based, compatibile con
  PARDISO. Il record contiene `row_ptr`, `col_ind`, `values`, dimensioni, NNZ,
  index kind e real/complex kind dichiarati.
- Il pattern CSR deve essere costruito prima dell'assemblaggio numerico a partire
  dalla connettivita dei DOF: raccolta delle adiacenze, ordinamento per riga,
  rimozione dei duplicati e costruzione di `row_ptr/col_ind`.
- L'assemblaggio numerico deve aggiornare soltanto `values`. E vietato inserire
  colonne spostando dinamicamente array di riga nel loop FEM, come avviene nella
  struttura a righe espandibili del codice storico.
- Per ogni elemento si usa una scatter map locale->posizione CSR quando il costo
  di memoria e conveniente; in alternativa una ricerca binaria nella riga. La
  policy deve essere selezionabile e misurata, non duplicata nei kernel.
- COO/triplette sono ammesse come formato temporaneo thread-local per costruire
  il pattern o per un assembler parallelo; non sono il formato del solver.
- La baseline memorizza la matrice completa, anche se simmetrica. Lo storage del
  solo triangolo superiore e un'ottimizzazione successiva, abilitabile soltanto
  dopo test di equivalenza per ogni backend e per i sistemi accoppiati.
- K, M, damping, Kgeo e matrici accoppiate possono avere pattern CSR separati per
  evitare zeri strutturali; lo stesso pattern simbolico viene riusato tra step o
  iterazioni finche mesh e DOF non cambiano.
- BCSR non e il formato iniziale: i blocchi NDK hanno dimensione variabile e
  ridurrebbero la semplicita. Una decomposizione a blocchi per campo puo essere
  aggiunta a livello solver senza cambiare i nuclei.
- Gli indici sono configurabili LP64/ILP64. Il wrapper PARDISO deve verificare
  la corrispondenza tra kind Fortran, libreria collegata e massimo NNZ.
- Strategia CPU iniziale: matrici elementari thread-local e scatter per coloring,
  partizione per righe o triplette thread-local con merge deterministico.
- L'esecuzione seriale deve restare disponibile come riferimento.
- La riduzione parallela deve poter essere resa deterministica in modalita test.
- I kernel dei punti non devono fare I/O, allocation o deallocation.
- Le allocazioni devono avvenire per batch/fase, non dentro i loop caldi.
- GPU: nessuna dipendenza immediata, ma batch SoA, indici compatti e procedure
  pure devono permettere un backend futuro.

### 10.1 Decisione sul formato sparse

Il formato corrente usa righe sparse espandibili e, durante `ASSEMBLY`, inserisce
una nuova colonna spostando gli elementi successivi; solo dopo converte il
risultato in CSR. E funzionale, ma non e la scelta migliore per il nuovo codice:
il costo degli inserimenti cresce con la dimensione della riga, causa copie e
riallocazioni, ostacola il parallelismo e rende imprevedibile la memoria.

| Formato | Uso previsto | Decisione |
|---|---|---|
| righe dinamiche legacy | inserimento incrementale | non usare nel nuovo assembler |
| COO/triplette | pattern iniziale e raccolta thread-local | temporaneo |
| CSR completo 1-based | storage globale e solver | baseline obbligatoria |
| CSR triangolare | matrici sicuramente simmetriche | ottimizzazione futura |
| BCSR | blocchi regolari | non iniziale, poco adatto a NDK variabile |
| matrix-free | prodotti iterativi/GPU | estensione futura, non sostituisce CSR iniziale |

Il flusso scelto e quindi:

1. costruzione simbolica del grafo dei DOF;
2. CSR ordinato e senza duplicati;
3. eventuale scatter map per elemento;
4. azzeramento e solo accumulo dei valori;
5. riuso del pattern in step temporali, frequenze e iterazioni;
6. passaggio diretto ai wrapper PARDISO/ARPACK.

Criteri di accettazione sparse:

- stessa matrice della versione di riferimento entro la tolleranza stabilita;
- colonne strettamente ordinate in ogni riga e diagonale presente dove richiesta;
- nessuna allocation o spostamento di colonne durante l'assemblaggio numerico;
- memoria di pattern e scatter map riportata separatamente;
- test con indici LP64 e controllo overflow prima della chiamata al solver;
- assemblaggio seriale deterministico usato come riferimento del parallelo.

## 11. Boundary conditions e carichi

- Separare vincoli essenziali, carichi nodali, body forces, pressioni, carichi
  termici/elettrici e campi definiti analiticamente.
- Conservare gli input legacy tramite adapter.
- Implementare l'eliminazione coerente e simmetrica dei DOF prescritti; la
  penalizzazione e ammessa solo quando richiesta e documentata.
- I sistemi di riferimento dei carichi devono essere espliciti.
- Supportare campi e carichi field-dependent senza incorporare parser nei kernel.

## 12. Analisi e solver

Ogni solution ID deve avere un driver corto che compone operazioni comuni:

```text
build operators -> assemble -> apply BC -> solve -> recover -> output
```

K, M, damping, geometric stiffness e blocchi accoppiati devono essere servizi
riutilizzabili. I driver non devono ricopiare cicli di elemento o procedure di
allocazione.

I backend devono restituire `status_t`; solo il programma principale decide se
terminare. Informazioni di convergenza, numero iterazioni e residui devono essere
registrate in formato leggibile e, opzionalmente, machine-readable.

## 13. Input, output e interfaccia

- Politica predefinita: mantenere gli attuali nomi, suddivisione, keyword,
  ordinamento e significato dei file di input. Un caso esistente valido deve
  poter essere eseguito senza conversione quando la funzione corrispondente e
  supportata.
- I parser devono accettare gli attuali spazi, righe commentate e notazione
  numerica Fortran. Le ambiguita storiche vengono convertite esclusivamente nel
  modulo `legacy_io`, con warning contestuale quando necessario.
- Gli attuali file di output scientifico devono essere mantenuti, per quanto
  possibile, negli stessi nomi e formati. Differenze intenzionali di precisione,
  ordinamento o contenuto devono essere versionate e documentate.
- Non e richiesta compatibilita byte-for-byte dei log diagnostici: errori,
  warning e timing adottano il nuovo sistema centralizzato.
- Nuove informazioni necessarie ma assenti nel formato corrente devono essere
  aggiunte preferibilmente tramite file opzionali o sezioni riconoscibili che non
  invalidino i casi precedenti.
- Un futuro formato esplicito con schema/versione puo affiancare quello attuale,
  ma non sostituirlo prima della validazione completa e dell'approvazione.
- La documentazione deve fornire per ogni file esistente: unita, frame, ID,
  significato delle colonne, valori ammessi e default effettivi.
- Controlli: ID duplicati/mancanti, connettivita, dimensioni, proprieta fisiche,
  ortogonalita dei frame, Jacobiani, layer coverage, DOF e compatibilita analisi.
- Output scientifici separati da log diagnostici.
- Livelli di log: ERROR, WARNING, INFO, DEBUG, TRACE.
- Nessuna stampa per routine nei loop caldi in modalita normale.
- L'interfaccia grafica o web deve invocare il solver tramite file/API stabile;
  non deve contenere formule FEM.

## 14. Errori, warning e debug

`status_t` deve contenere codice, severity, messaggio, modulo/procedura, element
ID e Gauss-point ID opzionali.

Condizioni almeno controllate:

- input non valido o feature non implementata;
- Jacobiano nullo/negativo o elemento degenerato;
- frame non ortonormale;
- materiale non fisico o tangente non simmetrica quando richiesta;
- DOF incoerenti e connettivita fuori intervallo;
- matrice singolare/indefinita quando non prevista;
- solver non convergente;
- NaN/Inf nei contributi e nella soluzione.

Build Debug:

- bounds, uninitialized, floating-point exception e backtrace;
- controlli di simmetria/dimensione attivabili;
- dump mirato di un elemento/punto, mai dump globale automatico.

Build Release:

- controlli fisici essenziali mantenuti;
- debug costoso disattivato;
- statistiche di timing per fase.

## 15. Timing, profiling e restart

Timer gerarchici minimi:

- input/check;
- preprocessing geometrico;
- costruzione punti/cache;
- pattern sparse;
- K/M/coupling assembly;
- BC;
- solver;
- post-processing;
- I/O.

Il formato di report deve includere wall time, CPU time, memoria stimata, numero
DOF, elementi, punti, NNZ e configurazione di build/parallelismo.

Restart opzionale ma previsto dall'architettura:

- versione del formato;
- hash/schema del modello;
- ordinamento DOF;
- tempo/load step;
- soluzione e derivate temporali;
- variabili interne committed;
- compatibilita verificata prima del resume.

## 16. Stile Fortran fixed form

- `implicit none (type, external)` in ogni modulo/procedura dove supportato;
- `private` di default, API esportata esplicitamente;
- estensione `.for`, istruzioni in colonne 7-72 e continuazione in colonna 6;
- nessuna informazione semantica affidata alle colonne 73-80;
- indentazione logica mantenuta entro i limiti fixed form; procedure e nomi non
  devono diventare criptici soltanto per evitare una continuazione;
- nomi inglesi consistenti e unita nei commenti;
- `intent(in/out/inout)` sempre dichiarato;
- funzioni `pure`/`elemental` quando matematicamente corrette;
- niente `common`, `equivalence`, `goto` o array a dimensioni magiche;
- niente unita file numeriche replicate: usare un gestore I/O;
- allocation ownership documentata;
- commenti che spiegano significato matematico e scelta, non la sintassi;
- formule lunghe suddivise in blocchi nominati verificabili;
- una routine di alto livello deve leggersi come la procedura scientifica.

## 17. Testing e verifica

### 17.1 Unit test

- shape functions: Kronecker, partition of unity, derivate;
- quadrature: integrazione esatta di polinomi;
- Jacobiano e trasformazione delle derivate;
- frame e trasformazioni tensoriali;
- matrici isotrope/ortotrope/anisotrope;
- rotazioni e fattori di shear;
- basi TE/LE e composizione NDK;
- DOF layout e local-to-global map;
- BC e sparse assembly.

### 17.2 Element test

- K e M per ogni topologia/formulazione mantenuta;
- simmetria e positivita attese;
- modi rigidi;
- integrazione full/reduced/MITC;
- orientazioni materiali e layer multipli;
- ordini differenti ai nodi NDK.

### 17.3 Patch e benchmark

- trazione/compressione e shear costanti;
- bending/shear locking;
- beam, plate e solid;
- laminato e VAT;
- termoelasticita e piezoelettricita;
- buckling, modal, transiente e frequenza.

### 17.4 Regressione

Con identico input confrontare fra Original, GP, NL/field-dependent e nuovo:

- matrici elementari;
- matrici globali e pattern;
- forze;
- displacement/potenziali/temperature;
- strain/stress e variabili interne;
- autovalori/frequenze;
- storia temporale;
- residui e bilanci energetici.

Ogni confronto deve registrare tolleranza assoluta e relativa, norma usata,
versione del caso e origine di ogni differenza. Non usare un solo confronto di
output formattato come prova di equivalenza.

## 18. Criteri di accettazione

Una feature e considerata implementata soltanto se:

1. la formulazione e documentata;
2. le convenzioni di indice/frame/unita sono esplicite;
3. esistono unit test e almeno un test fisico;
4. il risultato e confrontato con una fonte indipendente o un codice fornito;
5. Debug e Release compilano su almeno un compilatore;
6. non introduce duplicazioni di formule o pipeline;
7. errori di input producono diagnostica controllata;
8. la feature compare nella matrice di supporto con limiti noti.

La release iniziale e accettabile quando tutti gli ID mantenuti, tranne quelli
formalmente bloccati da informazioni mancanti, attraversano test end-to-end su
Windows; il core matematico e i test unitari devono compilare anche su Linux.

## 19. Fasi di sviluppo

### Gate 0 - Acquisizione

- attendere copia completa delle cartelle;
- generare manifest con hash senza modificare i riferimenti;
- identificare con certezza Original, GP, NL e Field-dependent;
- congelare casi benchmark e risultati.

### Gate 1 - Reverse engineering consolidato

- call graph, data flow, ID, formulazioni, convenzioni e differenze tra codici;
- catalogo delle parti corrette, incomplete, duplicate e obsolete;
- decisione documentata per ogni divergenza.

### Gate 2 - Skeleton Fortran

- build multipiattaforma fixed form con controllo automatico delle colonne;
- tipi base, diagnostica, timing;
- shape/quadrature/material/frame con test;
- nessun solver completo ancora.

### Gate 3 - Kernel Gauss/CUF

- punti/batch, TE/LE/NDK, B, K e M;
- element test e confronti locali.

### Gate 4 - Assemblaggio e analisi meccaniche

- CSR, BC, 101/103/104/105/106;
- regressione old/new.

### Gate 5 - Accoppiamenti

- 111/121/123/126/131;
- convenzioni e rotazioni accoppiate validate.

### Gate 6 - Consolidamento

- chiarimento/implementazione 136;
- NL e field-dependent confermati;
- parallelizzazione, restart, interfaccia e performance.

Ogni gate deve chiudersi con un aggiornamento di `ARCHITECTURE.md`,
`FORMULATIONS.md`, `MATERIALS.md`, `VALIDATION.md` e `REFACTORING_NOTES.md`.

## 20. Questioni da chiudere dopo la copia

1. Quale cartella corrisponde esattamente a GP_CODE, NL_CODE e Field-dependent?
2. Qual e il significato documentato dell'ID 136?
3. Per 131, il coupling piezoelettrico commentato e un bug, una feature sospesa
   o una scelta intenzionale?
4. Quali token cinematici oltre TE/LE sono effettivamente validati?
5. Quali elementi triangolari/tetraedrici/prismatici sono completi?
6. Quale codice contiene la sorgente autorevole per nonlinearita geometrica e
   materiale?
7. Quali casi e output sono considerati benchmark ufficiali?
8. Quali output scientifici richiedono compatibilita byte-for-byte e per quali e
   sufficiente l'equivalenza numerica?
9. Quali backend devono essere obbligatori in Linux?
10. L'interfaccia attuale deve essere mantenuta o soltanto resa compatibile con
    il nuovo eseguibile?

Fino alla chiusura del Gate 0 questa specifica definisce l'architettura target,
ma non certifica ancora l'inventario delle funzionalita presenti nei codici in
corso di copia.
