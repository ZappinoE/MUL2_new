/* ============================================================
   CUF PREPROCESSOR TOOL — Application Logic
   ============================================================ */

// Created by Adrian Ehrenhofer during 2026 research stay at Politecnico die Torino
// Initial prompting in Google Antigravity with Claude Opus 4.6 (Thinking)
// Additional prompting with Gemini 3.8 Flash Medium
// Version: V02 (14.09.2026 - 13:36)

// ──────────────────────────────────────────────
//  STATE
// ──────────────────────────────────────────────
const state = {
  files: {},           // filename -> { raw, parsed, dirty }
  activeFile: null,
  activeView: 'editor', // 'editor' | 'raw' | 'split' | '3d' | 'run'
  projectDirectory: null,
  projectName: '',
  serverAvailable: false,
  runJob: null,
  runPollTimer: null
};

const FILE_ORDER = [
  'ANALYSIS.dat', 'NODES.dat', 'CONNECTIVITY.dat', 'VERSORS.dat',
  'MATERIAL.dat', 'LAMINATION.dat', 'EXP_CONN', 'EXP_MESH',
  'BC.dat', 'POSTPROCESSING.dat', 'FIELDS.dat', 'TIME_RESP.dat',
  'FREQ_RESP.dat', 'PF_INPUT.dat'
];

const FILE_META = {
  'ANALYSIS.dat': { icon: 'A', cls: 'analysis', label: 'Analysis Setup' },
  'NODES.dat': { icon: 'N', cls: 'nodes', label: 'Node Definitions' },
  'CONNECTIVITY.dat': { icon: 'C', cls: 'connectivity', label: 'Element Connectivity' },
  'VERSORS.dat': { icon: 'V', cls: 'versors', label: 'Coordinate Versors' },
  'MATERIAL.dat': { icon: 'M', cls: 'material', label: 'Material Properties' },
  'LAMINATION.dat': { icon: 'L', cls: 'lamination', label: 'Lamination Angles' },
  'BC.dat': { icon: 'B', cls: 'bc', label: 'Boundary Conditions' },
  'POSTPROCESSING.dat': { icon: 'P', cls: 'postproc', label: 'Post-Processing' },
  'FIELDS.dat': { icon: 'F', cls: 'fields', label: 'Field Definitions' },
  'TIME_RESP.dat': { icon: 'T', cls: 'analysis', label: 'Time Response' },
  'FREQ_RESP.dat': { icon: 'ω', cls: 'analysis', label: 'Frequency Response' },
  'PF_INPUT.dat': { icon: 'PF', cls: 'analysis', label: 'Panel Flutter' },
};

const ANALYSIS_TYPES = [
  { value: 101, label: '101 — Static mechanical', family: 'static' },
  { value: 103, label: '103 — Dynamic/modal mechanical', family: 'modal' },
];

const NODE_MODELS = ['TE', 'TEM', 'LE', 'HLE', 'LEM', 'LG', 'LGM', 'MS', 'MSM'];
const STRUCTURAL_ELEMENTS = ['B2', 'B3', 'B4', 'Q3', 'Q4', 'Q6', 'Q9', 'Q16', 'H8', 'H20', 'H27', 'T4', 'T10', 'P6'];
const FIELD_TYPES = ['CONST', 'X-EXP', 'Y-EXP', 'Z-EXP', 'ATNZX', 'COS-X', 'COS-Y', 'SIN-X', 'SIN-Y', 'B-SIN', 'HANN'];

// ──────────────────────────────────────────────
//  FORTRAN FORMATTING UTILITIES
// ──────────────────────────────────────────────
const Fortran = {
  /** Parse a Fortran double value string to JS number */
  parseFloat(s) {
    if (s === undefined || s === null || s === '') return 0;
    s = String(s).trim().toUpperCase();
    // Replace D/d exponent notation with E
    s = s.replace(/D([+-]?\d+)/i, 'E$1');
    s = s.replace(/D0$/i, '');
    s = s.replace(/D$/i, '');
    const v = parseFloat(s);
    return isNaN(v) ? 0 : v;
  },

  /** Format a JS number as Fortran double */
  formatFloat(n, precision) {
    if (n === undefined || n === null) n = 0;
    n = Number(n);
    if (precision === undefined) {
      // Try to be smart about precision
      const abs = Math.abs(n);
      if (abs === 0) return '0.0D0';
      if (abs >= 1e9 || abs < 1e-6) {
        // Use exponent notation
        const exp = Math.floor(Math.log10(abs));
        const mantissa = n / Math.pow(10, exp);
        const mStr = mantissa % 1 === 0 ? mantissa.toFixed(1) : String(mantissa);
        return mStr + 'D' + (exp >= 0 ? '+' : '') + exp;
      }
      if (n % 1 === 0) return n.toFixed(1) + 'D0';
      return n + 'D0';
    }
    return n.toFixed(precision) + 'D0';
  },

  /** Keep original formatting if it already has D notation, otherwise format */
  preserveOrFormat(original, value) {
    if (original !== undefined && original !== null) {
      const s = String(original).trim();
      if (/[dD][+-]?\d*$/.test(s) || /[eE][+-]?\d+$/.test(s)) {
        return s; // already has Fortran notation
      }
    }
    return Fortran.formatFloat(value);
  },

  /** Ensure spaces only (no tabs) */
  sanitizeLine(line) {
    return line.replace(/\t/g, '  ');
  }
};

// ──────────────────────────────────────────────
//  PARSERS
// ──────────────────────────────────────────────
const Parsers = {
  /** Generic: split file into header line count, data lines, description lines */
  splitFile(raw) {
    const lines = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    // First non-empty line is the count (possibly with extra data like MATERIAL "2  2")
    let headerLine = '';
    let headerIdx = 0;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].trim() !== '') { headerLine = lines[i].trim(); headerIdx = i; break; }
    }

    // Next: skip one blank line, then data lines
    const countParts = headerLine.split(/\s+/);
    const count = parseInt(countParts[0], 10) || 0;

    // Find where data starts (after the blank line following the header)
    let dataStart = headerIdx + 1;
    // Skip blank line(s) after header
    while (dataStart < lines.length && lines[dataStart].trim() === '') dataStart++;

    const dataLines = [];
    const descLines = [];
    for (let i = dataStart; i < lines.length; i++) {
      if (dataLines.length < count) {
        dataLines.push(lines[i]);
      } else {
        descLines.push(lines[i]);
      }
    }

    return { headerLine, headerParts: countParts, count, dataLines, descLines, allLines: lines };
  },

  parseAnalysis(raw) {
    // Records (blank lines ignored): analysis code, number of modes,
    // shear treatment of beam, plate and solid (NONE/REDI/SELI/MITC).
    // The historical files have an extra integer record (the solver code)
    // after the analysis code: it is recognised and dropped.
    const rec = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n')
      .map(l => l.trim()).filter(l => l.length > 0);
    const isInt = (s) => /^[+-]?\d+(\s|$)/.test(s || '');
    let k = 1;
    if (isInt(rec[1]) && isInt(rec[2])) k = 2;          // legacy solver record
    const getRec = (i) => rec[i] || '';
    const analysisCode = parseInt(getRec(0), 10) || 101;
    const modesLine = getRec(k);
    const modes = parseInt(modesLine, 10) || 20;
    const modesDesc = modesLine.replace(/^\d+\s*/, '');
    const shearBeam = getRec(k + 1).split(/\s+/)[0] || 'NONE';
    const shearBeamDesc = getRec(k + 1).replace(/^\S+\s*/, '');
    const shearPlate = getRec(k + 2).split(/\s+/)[0] || 'NONE';
    const shearPlateDesc = getRec(k + 2).replace(/^\S+\s*/, '');
    const shearSolid = getRec(k + 3).split(/\s+/)[0] || 'NONE';
    const shearSolidDesc = getRec(k + 3).replace(/^\S+\s*/, '');
    return { analysisCode, modes, modesDesc, shearBeam, shearBeamDesc, shearPlate, shearPlateDesc, shearSolid, shearSolidDesc, raw };
  },

  parseNodes(raw) {
    const { count, dataLines, descLines } = Parsers.splitFile(raw);
    const nodes = [];
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 5) continue;
      nodes.push({
        id: parseInt(parts[0], 10),
        x: parts[1], y: parts[2], z: parts[3],
        xVal: Fortran.parseFloat(parts[1]),
        yVal: Fortran.parseFloat(parts[2]),
        zVal: Fortran.parseFloat(parts[3]),
        expType: parts[4] || 'LE',
        expOrder: parseInt(parts[5], 10) || 1
      });
    }
    return { count, nodes, descLines };
  },

  parseConnectivity(raw) {
    const { count, dataLines, descLines } = Parsers.splitFile(raw);
    const elements = [];
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 3) continue;
      const type = parts[0]; // B4, B3, etc.
      const id = parseInt(parts[1], 10);
      // For B4: 4 nodes + versor ref + cs ref
      const numNodes = parseInt(type.replace(/[^\d]/g, ''), 10) || 4;
      const nodeIds = [];
      for (let i = 2; i < 2 + numNodes; i++) {
        nodeIds.push(parseInt(parts[i], 10));
      }
      const versorRef = parseInt(parts[2 + numNodes], 10) || 1;
      const csRef = parseInt(parts[2 + numNodes + 1], 10) || 1;
      elements.push({ type, id, nodeIds, versorRef, csRef });
    }
    return { count, elements, descLines };
  },

  parseVersors(raw) {
    const { count, dataLines, descLines } = Parsers.splitFile(raw);
    const versors = [];
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 5) continue;
      versors.push({
        id: parseInt(parts[1], 10),
        vx: parseFloat(parts[2]) || 0,
        vy: parseFloat(parts[3]) || 0,
        vz: parseFloat(parts[4]) || 0
      });
    }
    return { count, versors, descLines };
  },

  parseMaterial(raw) {
    const { headerParts, count, dataLines, descLines } = Parsers.splitFile(raw);
    const nMat = parseInt(headerParts[0], 10) || 0;
    const nRows = parseInt(headerParts[1], 10) || 0;
    const materials = [];
    const extraRows = []; // Z-EXP, Z-PRM, DAMP etc.
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 2) continue;
      const keyword = parts[0];
      if (keyword === 'ISO-M') {
        materials.push({
          type: 'ISO-M', id: parseInt(parts[1], 10),
          E: parts[2] || '0.0D0', nu: parts[3] || '0.3', rho: parts[4] || '0.0D0',
          EVal: Fortran.parseFloat(parts[2]), nuVal: Fortran.parseFloat(parts[3]), rhoVal: Fortran.parseFloat(parts[4])
        });
      } else if (keyword === 'ORT-M') {
        materials.push({
          type: 'ORT-M', id: parseInt(parts[1], 10),
          values: parts.slice(2),
          valuesNum: parts.slice(2).map(Fortran.parseFloat)
        });
      } else {
        extraRows.push({ keyword, id: parseInt(parts[1], 10) || 0, values: parts.slice(2), raw: line });
      }
    }
    return { nMat, nRows, materials, extraRows, descLines };
  },

  parseLamination(raw) {
    const { count, dataLines, descLines } = Parsers.splitFile(raw);
    const laminations = [];
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 5) continue;
      laminations.push({
        keyword: parts[0], // LAM2
        id: parseInt(parts[1], 10),
        matRef: parseInt(parts[2], 10),
        rotX: parts[3] || '0.000E+00',
        rotY: parts[4] || '0.00000000E+00',
        rotXVal: Fortran.parseFloat(parts[3]),
        rotYVal: Fortran.parseFloat(parts[4])
      });
    }
    return { count, laminations, descLines };
  },

  parseExpConn(raw) {
    const { count, dataLines, descLines } = Parsers.splitFile(raw);
    const elements = [];
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 4) continue;
      const type = parts[0]; // Q9
      const id = parseInt(parts[1], 10);
      const lamRef = parseInt(parts[2], 10);
      let nodeIds = parts.slice(3).map(v => parseInt(v, 10));
      const hle = Parsers.hleKind(type);
      if (hle) {
        // HLE sub-element: vertex nodes, polynomial order and (HQ4 only)
        // four optional mid-side nodes of curved sides (0 = straight).
        const nv = hle === 'HQ' ? 4 : 2;
        const order = nodeIds[nv];
        const mids = hle === 'HQ' && nodeIds.length >= nv + 5 ? nodeIds.slice(nv + 1, nv + 5) : null;
        elements.push({ type, id, lamRef, nodeIds: nodeIds.slice(0, nv), order: order || 1, mids });
        continue;
      }
      elements.push({ type, id, lamRef, nodeIds });
    }
    return { count, elements, descLines };
  },

  // 'HQ' / 'HB' for the HLE sub-elements (HQ4, HB2), '' otherwise.
  hleKind(type) {
    const t = (type || '').toUpperCase();
    if (t === 'HQ4' || t === 'HQ') return 'HQ';
    if (t === 'HB2' || t === 'HB') return 'HB';
    return '';
  },

  // Boundary ring of a section element, with the mid-side nodes of the
  // curved sides of an HQ4 inserted between its vertices.
  elementRing(e) {
    const nids = e.nodeIds || [];
    if (Parsers.hleKind(e.type) === 'HQ' && nids.length === 4) {
      const m = e.mids || [0, 0, 0, 0];
      const ring = [];
      for (let i = 0; i < 4; i++) {
        ring.push(nids[i]);
        if (m[i]) ring.push(m[i]);
      }
      return ring;
    }
    const t = (e.type || '').toUpperCase();
    if (t === 'T6' && nids.length >= 6) return [nids[0], nids[3], nids[1], nids[4], nids[2], nids[5]];
    if (t === 'Q16' && nids.length >= 12) return nids.slice(0, 12);
    if (t === 'Q9' && nids.length >= 8) return nids.slice(0, 8);
    if (nids.length >= 8) return nids.slice(0, 8);
    return nids.slice();
  },

  // Boundary loops of the whole section (outer loop first, counter-clockwise;
  // holes clockwise): the edges used by one element only, chained.
  sectionLoops(elements, nodes) {
    const map = {};
    for (const n of nodes) map[n.id] = n;
    const edges = new Map();
    for (const e of elements) {
      const ring = Parsers.elementRing(e);
      if (ring.length < 3) continue;
      for (let i = 0; i < ring.length; i++) {
        const a = ring[i], b = ring[(i + 1) % ring.length];
        const key = a < b ? a + '_' + b : b + '_' + a;
        const rec = edges.get(key);
        if (rec) rec.count++; else edges.set(key, { a, b, count: 1, used: false });
      }
    }
    const from = new Map();
    for (const r of edges.values()) {
      if (r.count !== 1) continue;
      if (!from.has(r.a)) from.set(r.a, []);
      from.get(r.a).push(r);
    }
    const loops = [];
    for (const start of edges.values()) {
      if (start.count !== 1 || start.used) continue;
      const ids = [];
      let cur = start;
      while (cur && !cur.used) {
        cur.used = true;
        ids.push(cur.a);
        cur = (from.get(cur.b) || []).find(r => !r.used);
      }
      const pts = ids.map(id => map[id]).filter(Boolean);
      if (pts.length >= 3) loops.push(pts);
    }
    const area = (lp) => {
      let s = 0;
      for (let i = 0; i < lp.length; i++) {
        const p = lp[i], q = lp[(i + 1) % lp.length];
        s += p.xVal * q.zVal - q.xVal * p.zVal;
      }
      return s / 2;
    };
    loops.sort((p, q) => Math.abs(area(q)) - Math.abs(area(p)));
    return loops.map((lp, i) => {
      const a = area(lp);
      return (i === 0 ? a < 0 : a > 0) ? lp.slice().reverse() : lp;
    });
  },

  parseExpMesh(raw) {
    const { count, dataLines, descLines } = Parsers.splitFile(raw);
    const nodes = [];
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 4) continue;
      nodes.push({
        id: parseInt(parts[0], 10),
        x: parts[1], y: parts[2], z: parts[3],
        xVal: Fortran.parseFloat(parts[1]),
        yVal: Fortran.parseFloat(parts[2]),
        zVal: Fortran.parseFloat(parts[3])
      });
    }
    return { count, nodes, descLines };
  },

  parseBC(raw) {
    const { count, dataLines, descLines } = Parsers.splitFile(raw);
    const conditions = [];
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 2) continue;
      const type = parts[0]; // D-PLANE, D-POINT, F-POINT
      const id = parseInt(parts[1], 10);
      if (type === 'D-PLANE') {
        // D-PLANE id A B C D ux uy uz
        conditions.push({
          type: 'D-PLANE', id,
          A: parseFloat(parts[2]) || 0, B: parseFloat(parts[3]) || 0,
          C: parseFloat(parts[4]) || 0, D: parseFloat(parts[5]) || 0,
          ux: parts[6] || '0.0', uy: parts[7] || '0.0', uz: parts[8] || '0.0'
        });
      } else if (type === 'D-POINT') {
        conditions.push({
          type: 'D-POINT', id,
          x: parts[2] || '0.0D0', y: parts[3] || '0.0D0', z: parts[4] || '0.0D0',
          ux: parts[5] || '0.0', uy: parts[6] || '0.0', uz: parts[7] || '0.0'
        });
      } else if (type === 'F-POINT') {
        conditions.push({
          type: 'F-POINT', id,
          x: parts[2] || '0.0D0', y: parts[3] || '0.0D0', z: parts[4] || '0.0D0',
          fx: parts[5] || '0.0D0', fy: parts[6] || '0.0D0', fz: parts[7] || '0.0D0'
        });
      } else {
        // Keep every solver-supported row losslessly even when a dedicated
        // visual form is not available yet (D-LINE, F-PRESS, OMEGA, ...).
        conditions.push({ type, id, raw: line, generic: true });
      }
    }
    return { count, conditions, descLines };
  },

  parsePostprocessing(raw) {
    const { count, dataLines, descLines } = Parsers.splitFile(raw);
    const entries = [];
    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 2) continue;
      const type = parts[0]; // PARA or PNT
      if (type === 'PARA') {
        entries.push({
          type: 'PARA',
          numNodes: parseInt(parts[1], 10) || 20,
          refSystem: parts[2] || 'GLB',
          subdivisions: parts.slice(3).map(v => parseInt(v, 10) || 1)
        });
      } else if (type === 'PNT') {
        entries.push({
          type: 'PNT',
          id: parseInt(parts[1], 10),
          x: parts[2] || '0.0D0', y: parts[3] || '0.0D0', z: parts[4] || '0.0D0',
          xVal: Fortran.parseFloat(parts[2]), yVal: Fortran.parseFloat(parts[3]), zVal: Fortran.parseFloat(parts[4])
        });
      } else {
        entries.push({ type, raw: line, generic: true });
      }
    }
    return { count, entries, descLines };
  },

  parseFields(raw) {
    const lines = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    let idx = 0;
    while (idx < lines.length && lines[idx].trim() === '') idx++;
    const count = parseInt(lines[idx]?.trim(), 10) || 0;
    idx++;

    const fields = [];
    while (idx < lines.length && fields.length < count) {
      while (idx < lines.length && lines[idx].trim() === '') idx++;
      if (idx >= lines.length) break;
      const headerParts = lines[idx].trim().split(/\s+/);
      if (headerParts[0] !== 'FIELD') break; // malformed block, stop and preserve the rest as descLines
      const field = { id: parseInt(headerParts[1], 10) || (fields.length + 1), subId: parseInt(headerParts[2], 10) || 1, definition: null };
      idx++;
      while (idx < lines.length && lines[idx].trim() === '') idx++;
      if (idx < lines.length && lines[idx].trim() !== '') {
        const defParts = lines[idx].trim().split(/\s+/);
        if (defParts[0] !== 'FIELD') {
          field.definition = { type: defParts[0], params: defParts.slice(1) };
          idx++;
        }
      }
      fields.push(field);
    }
    while (idx < lines.length && lines[idx].trim() === '') idx++;
    const descLines = lines.slice(idx);
    return { count, fields, descLines };
  },

  parseTimeResponse(raw) {
    const lines = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    const meaningful = lines.map((text, index) => ({ text, index, trim: text.trim() })).filter(x => x.trim !== '');
    const range = meaningful[0]?.trim.split(/\s+/) || [];
    const ti = range[0] || '0.0D0';
    const tf = range[1] || '1.0D0';
    const nstep = parseInt(meaningful[1]?.trim, 10) || 1;
    const postEvery = parseInt(meaningful[2]?.trim, 10) || 1;
    const specificCount = parseInt(meaningful[3]?.trim, 10) || 0;
    let cursor = 4;
    const specificTimes = [];
    for (let i = 0; i < specificCount && meaningful[cursor]; i++, cursor++) specificTimes.push(meaningful[cursor].trim.split(/\s+/)[0]);
    const loadCount = parseInt(meaningful[cursor]?.trim, 10) || 0;
    cursor++;
    const loads = [];
    for (let i = 0; i < loadCount && meaningful[cursor]; i++, cursor++) {
      const tokens = meaningful[cursor].trim.split(/\s+/);
      loads.push({ type: tokens[0].toUpperCase(), params: tokens.slice(1), raw: meaningful[cursor].text });
    }
    return { ti, tf, nstep, postEvery, specificTimes, loads, raw, trailing: meaningful.slice(cursor).map(x => x.text) };
  },

  parseFrequencyResponse(raw) {
    const rows = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').filter(x => x.trim() !== '');
    const range = (rows[0] || '').trim().split(/\s+/);
    return {
      fi: range[0] || '0.0D0', ff: range[1] || '1.0D0',
      steps: parseInt(rows[1], 10) || 1,
      postEvery: parseInt(rows[2], 10) || 1,
      trailing: rows.slice(3), raw
    };
  },

  parseGeneric(raw) {
    return { raw, generic: true };
  }
};

// ──────────────────────────────────────────────
//  GENERATORS (state -> Fortran text)
// ──────────────────────────────────────────────
const Generators = {
  analysis(parsed) {
    let out = parsed.analysisCode + '\n';
    out += '\n';
    out += parsed.modes + '           ' + parsed.modesDesc + '\n';
    out += '\n';
    out += parsed.shearBeam + '         ' + parsed.shearBeamDesc + '\n';
    out += parsed.shearPlate + '         ' + parsed.shearPlateDesc + '\n';
    out += parsed.shearSolid + '         ' + parsed.shearSolidDesc + '\n';
    return out;
  },

  nodes(parsed) {
    let out = parsed.nodes.length + '\n\n';
    for (const n of parsed.nodes) {
      out += n.id + '   ' + n.x + '   ' + n.y + '   ' + n.z + '  ' + n.expType + ' ' + n.expOrder + '\n';
    }
    out += '\n';
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  connectivity(parsed) {
    let out = parsed.elements.length + '\n\n';
    for (const e of parsed.elements) {
      const nodes = e.nodeIds.map(n => String(n).padStart(3)).join('  ');
      out += e.type + '  ' + e.id + '  ' + nodes + ' ' + e.versorRef + '  ' + e.csRef + ' \n';
    }
    out += '\n';
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  versors(parsed) {
    let out = parsed.versors.length + '\n\n';
    for (const v of parsed.versors) {
      out += 'VERSOR  ' + v.id + '   ' + v.vx + '  ' + v.vy + '  ' + v.vz + '  \n';
    }
    out += '\n';
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  material(parsed) {
    // Recalculate nMat and nRows
    const nMat = parsed.materials.length;
    let dataRows = [];
    for (const m of parsed.materials) {
      if (m.type === 'ISO-M') {
        dataRows.push('ISO-M  ' + m.id + '   ' + m.E + '   ' + m.nu + '  ' + m.rho);
      } else if (m.type === 'ORT-M') {
        dataRows.push('ORT-M  ' + m.id + '   ' + m.values.join('   '));
      }
    }
    for (const er of parsed.extraRows) {
      dataRows.push(er.raw.trim());
    }
    const nRows = dataRows.length;
    let out = nMat + '  ' + nRows + '\n\n';
    out += dataRows.join('\n') + '\n';
    out += '\n';
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  lamination(parsed) {
    let out = parsed.laminations.length + '\n\n';
    for (const l of parsed.laminations) {
      out += l.keyword + '   ' + l.id + '  ' + l.matRef + '  ' + l.rotX + '  ' + l.rotY + '\n';
    }
    out += '\n';
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  expConn(parsed) {
    let out = parsed.elements.length + '\n \n';
    for (const e of parsed.elements) {
      out += e.type + '  ' + e.id + '  ' + e.lamRef + '  ' + e.nodeIds.join('  ');
      if (Parsers.hleKind(e.type)) {
        out += '  ' + (e.order || 1);
        if (e.mids && e.mids.some(Boolean)) out += '  ' + e.mids.join('  ');
      }
      out += '\n';
    }
    out += '\n';
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  expMesh(parsed) {
    let out = parsed.nodes.length + '\n\n';
    for (const n of parsed.nodes) {
      out += n.id + '   ' + n.x + '   ' + n.y + '   ' + n.z + '\n';
    }
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  bc(parsed) {
    let out = parsed.conditions.length + '\n\n';
    for (const c of parsed.conditions) {
      if (c.type === 'D-PLANE') {
        out += 'D-PLANE  ' + c.id + ' ' + c.A + ' ' + c.B + ' ' + c.C + ' ' + c.D + '     ' + c.ux + ' ' + c.uy + ' ' + c.uz + '\n';
      } else if (c.type === 'D-POINT') {
        out += 'D-POINT  ' + c.id + ' ' + c.x + ' ' + c.y + ' ' + c.z + '  ' + c.ux + ' ' + c.uy + ' ' + c.uz + '\n';
      } else if (c.type === 'F-POINT') {
        out += 'F-POINT  ' + c.id + ' ' + c.x + ' ' + c.y + '   ' + c.z + '  ' + c.fx + '   ' + c.fy + '  ' + c.fz + '\n';
      } else if (c.raw) {
        out += c.raw.trimEnd() + '\n';
      }
    }
    out += '\n';
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  postprocessing(parsed) {
    let out = parsed.entries.length + '\n \n';
    for (const e of parsed.entries) {
      if (e.type === 'PARA') {
        out += 'PARA   ' + e.numNodes + '   ' + e.refSystem + '   ' + e.subdivisions.join('  ') + ' \n';
      } else if (e.type === 'PNT') {
        out += 'PNT ' + e.id + '    ' + e.x + '    ' + e.y + '    ' + e.z + '\n';
      } else if (e.raw) {
        out += e.raw.trimEnd() + '\n';
      }
    }
    if (parsed.descLines) out += parsed.descLines.join('\n');
    return out;
  },

  fields(parsed) {
    let out = parsed.fields.length + '\n\n';
    for (let i = 0; i < parsed.fields.length; i++) {
      const f = parsed.fields[i];
      out += 'FIELD    ' + f.id + '   ' + f.subId + '\n';
      if (f.definition) {
        out += f.definition.type + '    ' + f.definition.params.join('  ') + '\n';
      }
      if (i < parsed.fields.length - 1) out += '\n';
    }
    if (parsed.descLines && parsed.descLines.length) {
      out += '\n' + parsed.descLines.join('\n');
    }
    return out;
  },

  timeResponse(parsed) {
    let out = `${parsed.ti}    ${parsed.tf}    TI   TF\n`;
    out += `${parsed.nstep}           NSTEP\n`;
    out += `${parsed.postEvery}           post every\n`;
    out += `${parsed.specificTimes.length}\n`;
    for (const time of parsed.specificTimes) out += `${time}\n`;
    out += '---------------------------------------\n';
    out += `${parsed.loads.length}\n`;
    for (const load of parsed.loads) out += `${load.type}  ${load.params.join('  ')}\n`;
    if (parsed.trailing?.length) out += parsed.trailing.join('\n') + '\n';
    return out;
  },

  frequencyResponse(parsed) {
    let out = `${parsed.fi}    ${parsed.ff}    FI   FF\n`;
    out += `${parsed.steps}           FSTEP\n`;
    out += `${parsed.postEvery}           post every\n`;
    if (parsed.trailing?.length) out += parsed.trailing.join('\n') + '\n';
    return out;
  },

  generic(parsed) {
    return parsed.raw || '';
  }
};

// ──────────────────────────────────────────────
//  3D BEAM MODEL RENDERER (Carrera Unified Formulation)
// ──────────────────────────────────────────────
class Beam3DRenderer {
  constructor() {
    this.canvas = null;
    this.ctx = null;
    this.w = 0;
    this.h = 0;
    this.camera = { rotX: -0.42, rotY: 0.65, zoom: 1.0, panX: 0, panY: 0 };
    this.dragging = false;
    this.panning = false;
    this.lastMouse = { x: 0, y: 0 };
    this.hoveredItem = null;
    this.options = {
      showFaces: true,
      showWireframe: true,
      showNodes: true,
      showBCs: true,
      showPNT: true,
      showCenterline: true,
      showAxes: true
    };
    this.zScale = 'auto'; // 'auto' or number (1, 5, 10, 20, 40)
    this.autoRotate = false;
    this.animFrame = null;
    this._ro = null;
    this._boundHandlers = {};
  }

  attachToCanvas(canvas) {
    if (!canvas || typeof canvas.getContext !== 'function') return;
    if (this._ro) {
      this._ro.disconnect();
      this._ro = null;
    }
    this._unbindEvents();

    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this._bindEvents();
    this._resize();
    this.render();
  }

  _unbindEvents() {
    if (!this.canvas) return;
    const c = this.canvas;
    const h = this._boundHandlers;
    if (h.down) c.removeEventListener('mousedown', h.down);
    if (h.move) c.removeEventListener('mousemove', h.move);
    if (h.up) c.removeEventListener('mouseup', h.up);
    if (h.leave) c.removeEventListener('mouseleave', h.leave);
    if (h.wheel) c.removeEventListener('wheel', h.wheel);
    if (h.ctx) c.removeEventListener('contextmenu', h.ctx);
    this._boundHandlers = {};
  }

  _bindEvents() {
    const c = this.canvas;
    if (!c) return;

    const onMouseDown = e => {
      if (e.button === 2 || e.shiftKey) { this.panning = true; }
      else { this.dragging = true; }
      this.lastMouse = { x: e.clientX, y: e.clientY };
      e.preventDefault();
    };

    const onMouseMove = e => {
      const dx = e.clientX - this.lastMouse.x;
      const dy = e.clientY - this.lastMouse.y;
      if (this.dragging) {
        this.camera.rotY += dx * 0.008;
        this.camera.rotX += dy * 0.008;
        this.render();
      } else if (this.panning) {
        this.camera.panX += dx;
        this.camera.panY += dy;
        this.render();
      } else {
        // Hover detection
        this._checkHover(e);
      }
      this.lastMouse = { x: e.clientX, y: e.clientY };
    };

    const onMouseUp = () => { this.dragging = false; this.panning = false; };
    const onMouseLeave = () => { this.dragging = false; this.panning = false; this.hoveredItem = null; this.render(); };

    const onWheel = e => {
      this.camera.zoom *= e.deltaY > 0 ? 0.92 : 1.08;
      this.camera.zoom = Math.max(0.15, Math.min(12, this.camera.zoom));
      this.render();
      e.preventDefault();
    };

    const onContextMenu = e => e.preventDefault();

    c.addEventListener('mousedown', onMouseDown);
    c.addEventListener('mousemove', onMouseMove);
    c.addEventListener('mouseup', onMouseUp);
    c.addEventListener('mouseleave', onMouseLeave);
    c.addEventListener('wheel', onWheel, { passive: false });
    c.addEventListener('contextmenu', onContextMenu);

    this._boundHandlers = {
      down: onMouseDown,
      move: onMouseMove,
      up: onMouseUp,
      leave: onMouseLeave,
      wheel: onWheel,
      ctx: onContextMenu
    };

    if (c.parentElement) {
      this._ro = new ResizeObserver(() => {
        this._resize();
        this.render();
      });
      this._ro.observe(c.parentElement);
    }
  }

  _resize() {
    if (!this.canvas || !this.canvas.parentElement) return;
    const parent = this.canvas.parentElement;
    const dpr = window.devicePixelRatio || 1;
    const pw = parent.clientWidth || 400;
    const ph = parent.clientHeight || 350;
    this.canvas.width = pw * dpr;
    this.canvas.height = ph * dpr;
    this.canvas.style.width = pw + 'px';
    this.canvas.style.height = ph + 'px';
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.w = pw;
    this.h = ph;
  }

  setCameraPreset(preset) {
    if (preset === 'iso' || preset === 'reset') {
      this.camera.rotX = -0.42;
      this.camera.rotY = 0.65;
      this.camera.panX = 0;
      this.camera.panY = 0;
      this.camera.zoom = 1.0;
    } else if (preset === 'top') {
      this.camera.rotX = -Math.PI / 2 + 0.001;
      this.camera.rotY = 0;
      this.camera.panX = 0;
      this.camera.panY = 0;
      this.camera.zoom = 1.0;
    } else if (preset === 'front') {
      this.camera.rotX = 0;
      this.camera.rotY = 0;
      this.camera.panX = 0;
      this.camera.panY = 0;
      this.camera.zoom = 1.0;
    } else if (preset === 'side') {
      this.camera.rotX = 0;
      this.camera.rotY = Math.PI / 2;
      this.camera.panX = 0;
      this.camera.panY = 0;
      this.camera.zoom = 1.0;
    }
    this.render();
  }

  setZScale(val) {
    this.zScale = val;
    this.render();
  }

  toggleOption(opt, val) {
    if (val !== undefined) this.options[opt] = val;
    else this.options[opt] = !this.options[opt];
    this.render();
  }

  toggleTurntable() {
    this.autoRotate = !this.autoRotate;
    if (this.autoRotate) {
      const loop = () => {
        if (!this.autoRotate) return;
        this.camera.rotY += 0.007;
        this.render();
        this.animFrame = requestAnimationFrame(loop);
      };
      this.animFrame = requestAnimationFrame(loop);
    } else if (this.animFrame) {
      cancelAnimationFrame(this.animFrame);
      this.animFrame = null;
    }
    return this.autoRotate;
  }

  _computeModelBounds() {
    let xmin = 0, xmax = 0, ymin = 0, ymax = 0, zmin = 0, zmax = 0;
    let hasNodes = false, hasMesh = false;

    // 1D Nodes along beam
    const nodesData = state.files['NODES.dat']?.parsed;
    let beamNodes = [];
    if (nodesData && nodesData.nodes && nodesData.nodes.length > 0) {
      beamNodes = [...nodesData.nodes].sort((a, b) => a.yVal - b.yVal);
      ymin = beamNodes[0].yVal;
      ymax = beamNodes[beamNodes.length - 1].yVal;
      hasNodes = true;
    } else {
      ymin = 0;
      ymax = 0.4;
    }

    // Cross-section from EXP_MESH
    let csNodes = [];
    let csElements = [];
    for (const fname of Object.keys(state.files)) {
      if (fname.startsWith('EXP_MESH_') && state.files[fname]?.parsed) {
        csNodes = state.files[fname].parsed.nodes || [];
        const csNum = fname.match(/\d+/)?.[0];
        const connFname = 'EXP_CONN_' + csNum + '.dat';
        if (state.files[connFname]?.parsed) {
          csElements = state.files[connFname].parsed.elements || [];
        }
        break;
      }
    }

    if (csNodes.length > 0) {
      xmin = Math.min(...csNodes.map(n => n.xVal));
      xmax = Math.max(...csNodes.map(n => n.xVal));
      zmin = Math.min(...csNodes.map(n => n.zVal));
      zmax = Math.max(...csNodes.map(n => n.zVal));
      hasMesh = true;
    } else {
      xmin = -0.1;
      xmax = 0.1;
      zmin = -0.0005;
      zmax = 0.0005;
    }

    // Plate / solid models: geometry comes from the node coordinates.
    const connEls = state.files['CONNECTIVITY.dat']?.parsed?.elements || [];
    const mode = Beam3DRenderer.modelMode(connEls);
    let meshNodes = [];
    if (mode !== 'beam' && nodesData && nodesData.nodes && nodesData.nodes.length > 0) {
      meshNodes = nodesData.nodes;
      xmin = Math.min(...meshNodes.map(n => n.xVal));
      xmax = Math.max(...meshNodes.map(n => n.xVal));
      ymin = Math.min(...meshNodes.map(n => n.yVal));
      ymax = Math.max(...meshNodes.map(n => n.yVal));
      zmin = Math.min(...meshNodes.map(n => n.zVal));
      zmax = Math.max(...meshNodes.map(n => n.zVal));
      if (mode === 'plate') {
        // Thickness = EXP_MESH extent along Z (expansion of the plate section).
        const tz = csNodes.length > 0 ? csNodes.map(n => n.zVal) : [-0.0005, 0.0005];
        zmin += Math.min(...tz);
        zmax += Math.max(...tz);
      }
      hasNodes = true;
      hasMesh = true;
    }

    const W = Math.max(0.001, xmax - xmin);
    const L = Math.max(0.001, ymax - ymin);
    const H = Math.max(0.00001, zmax - zmin);
    const zmid = (zmin + zmax) / 2;

    // Determine thickness exaggeration (Z-Scale)
    let Sz = 1;
    if (this.zScale === 'auto') {
      const ratio = H / W;
      if (ratio < 0.04) {
        Sz = Math.min(50, Math.max(1, Math.round(W / (5 * H))));
      } else {
        Sz = 1;
      }
    } else {
      Sz = Number(this.zScale) || 1;
    }

    const zvis = (z) => zmid + (z - zmid) * Sz;
    const zminVis = zvis(zmin);
    const zmaxVis = zvis(zmax);
    const Hvis = zmaxVis - zminVis;

    const cx = (xmin + xmax) / 2;
    const cy = (ymin + ymax) / 2;
    const cz = zmid;
    const D = Math.max(W, L, Hvis, 0.01);

    // Cross-section perimeter polygon
    let poly = [];
    let loops = [];
    if (csElements.length > 0 && csNodes.length > 0) {
      loops = Parsers.sectionLoops(csElements, csNodes);
    }
    if (loops.length > 0) {
      poly = loops[0];
    } else if (csElements.length > 0 && csNodes.length > 0) {
      const nodeMap = {};
      for (const n of csNodes) nodeMap[n.id] = n;
      const elem = csElements[0];
      const nids = elem.nodeIds || [];
      if (Parsers.hleKind(elem.type) === 'HQ') {
        poly = Parsers.elementRing(elem).map(id => nodeMap[id]).filter(Boolean);
      } else if (nids.length >= 8) {
        // Q9 outer boundary: 1-2-3-6-9-8-7-4
        const ring = [nids[0], nids[1], nids[2], nids[3], nids[4], nids[5], nids[6], nids[7]];
        poly = ring.map(id => nodeMap[id]).filter(Boolean);
      } else if (nids.length === 4) {
        poly = nids.map(id => nodeMap[id]).filter(Boolean);
      }
    }

    if (poly.length === 0) {
      poly = [
        { xVal: xmin, zVal: zmin },
        { xVal: xmax, zVal: zmin },
        { xVal: xmax, zVal: zmax },
        { xVal: xmin, zVal: zmax }
      ];
    }

    if (loops.length === 0) loops = [poly];

    return {
      xmin, xmax, ymin, ymax, zmin, zmax,
      W, L, H, zmid, Sz, zvis, Hvis,
      cx, cy, cz, D, loops,
      beamNodes: mode !== 'beam' && meshNodes.length > 0 ? meshNodes : beamNodes,
      csNodes, csElements, poly, mode, meshElements: connEls,
      hasNodes, hasMesh
    };
  }

  project(x, y, z, bounds) {
    const cam = this.camera;
    const dx = x - bounds.cx;
    const dy = y - bounds.cy;
    const dz = bounds.zvis(z) - bounds.cz;

    // Rotate around X (pitch)
    const y1 = dy * Math.cos(cam.rotX) - dz * Math.sin(cam.rotX);
    const z1 = dy * Math.sin(cam.rotX) + dz * Math.cos(cam.rotX);
    // Rotate around Y (yaw)
    const x1 = dx * Math.cos(cam.rotY) + z1 * Math.sin(cam.rotY);
    const z2 = -dx * Math.sin(cam.rotY) + z1 * Math.cos(cam.rotY);

    const scale = (Math.min(this.w, this.h) * 0.62 * cam.zoom) / bounds.D;
    const sx = this.w / 2 + x1 * scale + cam.panX;
    const sy = this.h / 2 - y1 * scale + cam.panY;
    return { sx, sy, depth: z2, x1, y1, z1, scale };
  }

  _checkHover(e) {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;

    const bounds = this._computeModelBounds();
    let closest = null;
    let minD = 18;

    // Check beam nodes
    if (this.options.showNodes && bounds.beamNodes) {
      for (const n of bounds.beamNodes) {
        const p = this.project(n.xVal, n.yVal, n.zVal, bounds);
        const dist = Math.hypot(p.sx - mx, p.sy - my);
        if (dist < minD) {
          minD = dist;
          closest = { type: 'node', data: n, sx: p.sx, sy: p.sy };
        }
      }
    }

    // Check BCs
    if (this.options.showBCs) {
      const bcData = state.files['BC.dat']?.parsed;
      if (bcData) {
        for (const bc of bcData.conditions) {
          if (bc.type === 'F-POINT') {
            const px = Fortran.parseFloat(bc.x);
            const py = Fortran.parseFloat(bc.y);
            const pz = Fortran.parseFloat(bc.z);
            const p = this.project(px, py, pz, bounds);
            const dist = Math.hypot(p.sx - mx, p.sy - my);
            if (dist < minD) {
              minD = dist;
              closest = { type: 'bc-f', data: bc, sx: p.sx, sy: p.sy };
            }
          }
        }
      }
    }

    if (JSON.stringify(closest) !== JSON.stringify(this.hoveredItem)) {
      this.hoveredItem = closest;
      this.render();
    }
  }

  render() {
    if (!this.ctx || !this.w || !this.h) return;
    const ctx = this.ctx;
    const w = this.w, h = this.h;
    ctx.clearRect(0, 0, w, h);

    // Deep gradient background
    const grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, '#060a14');
    grad.addColorStop(1, '#0b1122');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);

    const bounds = this._computeModelBounds();

    // 1. Grid on the base plane (Z = zmin)
    this._drawFloorGrid(ctx, bounds);

    // 2. Collect all renderable 3D primitives
    const items = this._collectRenderItems(bounds);

    // Sort by depth (Painter's algorithm: farthest first)
    items.sort((a, b) => a.depth - b.depth);

    for (const item of items) {
      item.draw(ctx);
    }

    // 3. Axes indicator
    if (this.options.showAxes) {
      this._drawAxes(ctx);
    }

    // 4. Overlays & Tooltips
    this._drawHUD(ctx, bounds);
    if (this.hoveredItem) {
      this._drawTooltip(ctx, this.hoveredItem);
    }
  }

  _drawFloorGrid(ctx, bounds) {
    const ymin = bounds.ymin, ymax = bounds.ymax;
    const xmin = bounds.xmin * 1.6, xmax = bounds.xmax * 1.6;
    const zBase = bounds.zmin;

    ctx.strokeStyle = 'rgba(99, 140, 255, 0.05)';
    ctx.lineWidth = 0.5;

    const ySteps = 8;
    for (let i = 0; i <= ySteps; i++) {
      const y = ymin + (ymax - ymin) * (i / ySteps);
      const p1 = this.project(xmin, y, zBase, bounds);
      const p2 = this.project(xmax, y, zBase, bounds);
      ctx.beginPath(); ctx.moveTo(p1.sx, p1.sy); ctx.lineTo(p2.sx, p2.sy); ctx.stroke();
    }

    const xSteps = 6;
    for (let j = 0; j <= xSteps; j++) {
      const x = xmin + (xmax - xmin) * (j / xSteps);
      const p1 = this.project(x, ymin, zBase, bounds);
      const p2 = this.project(x, ymax, zBase, bounds);
      ctx.beginPath(); ctx.moveTo(p1.sx, p1.sy); ctx.lineTo(p2.sx, p2.sy); ctx.stroke();
    }
  }

  _drawAxes(ctx) {
    const len = 38;
    const ox = 52, oy = this.h - 52;
    const cam = this.camera;

    const axes = [
      { dx: 1, dy: 0, dz: 0, label: 'X', color: '#f87171' },
      { dx: 0, dy: 1, dz: 0, label: 'Y (Length)', color: '#34d399' },
      { dx: 0, dy: 0, dz: 1, label: 'Z', color: '#638cff' }
    ];

    for (const ax of axes) {
      const { dx, dy, dz } = ax;
      const y1 = dy * Math.cos(cam.rotX) - dz * Math.sin(cam.rotX);
      const z1 = dy * Math.sin(cam.rotX) + dz * Math.cos(cam.rotX);
      const x1 = dx * Math.cos(cam.rotY) + z1 * Math.sin(cam.rotY);

      const ex = ox + x1 * len;
      const ey = oy - y1 * len;

      ctx.strokeStyle = ax.color;
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(ox, oy); ctx.lineTo(ex, ey); ctx.stroke();

      ctx.fillStyle = ax.color;
      ctx.font = '600 10px Inter, sans-serif';
      ctx.fillText(ax.label, ex + 4, ey + 4);
    }
  }

  _drawHUD(ctx, bounds) {
    // Subtle Z-scale tag in top-left
    ctx.fillStyle = 'rgba(12, 18, 34, 0.75)';
    ctx.strokeStyle = 'rgba(99, 140, 255, 0.2)';
    ctx.lineWidth = 1;
    const tagText = `Z-Exaggeration: ${bounds.Sz}x ${bounds.Sz > 1 ? '(Scaled)' : '(True 1:1)'}`;
    ctx.font = '10px JetBrains Mono, monospace';
    const tw = ctx.measureText(tagText).width;
    ctx.beginPath();
    ctx.roundRect(14, 14, tw + 16, 22, 4);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = bounds.Sz > 1 ? '#60a5fa' : '#94a3b8';
    ctx.fillText(tagText, 22, 29);
  }

  _drawTooltip(ctx, item) {
    const { sx, sy, data, type } = item;
    let title = '', lines = [];
    if (type === 'node') {
      title = `Beam Node #${data.id}`;
      lines = [
        `Y (Length): ${data.yVal.toFixed(4)} m`,
        `X: ${data.xVal.toFixed(4)} m, Z: ${data.zVal.toFixed(5)} m`,
        `Expansion: ${data.expType || 'LE'} (order ${data.expOrder || 1})`
      ];
    } else if (type === 'bc-f') {
      title = `Point Load #${data.id}`;
      const fx = Fortran.parseFloat(data.fx);
      const fy = Fortran.parseFloat(data.fy);
      const fz = Fortran.parseFloat(data.fz);
      lines = [
        `Coordinates: (${Fortran.parseFloat(data.x).toFixed(2)}, ${Fortran.parseFloat(data.y).toFixed(2)}, ${Fortran.parseFloat(data.z).toFixed(5)})`,
        `Fz: ${fz.toFixed(1)} N`,
        fx !== 0 ? `Fx: ${fx.toFixed(1)} N` : null,
        fy !== 0 ? `Fy: ${fy.toFixed(1)} N` : null
      ].filter(Boolean);
    }

    ctx.font = '11px Inter, sans-serif';
    let maxW = ctx.measureText(title).width;
    for (const l of lines) maxW = Math.max(maxW, ctx.measureText(l).width);

    const pad = 10;
    const boxW = maxW + pad * 2;
    const boxH = (lines.length + 1) * 16 + pad * 2;
    const bx = Math.min(this.w - boxW - 10, Math.max(10, sx + 12));
    const by = Math.min(this.h - boxH - 10, Math.max(10, sy - 15));

    ctx.fillStyle = 'rgba(10, 15, 30, 0.92)';
    ctx.strokeStyle = '#638cff';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.roundRect(bx, by, boxW, boxH, 6);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#f8fafc';
    ctx.font = '600 11px Inter, sans-serif';
    ctx.fillText(title, bx + pad, by + pad + 11);

    ctx.font = '10px JetBrains Mono, monospace';
    ctx.fillStyle = '#94a3b8';
    lines.forEach((line, idx) => {
      ctx.fillText(line, bx + pad, by + pad + 28 + idx * 16);
    });
  }

  static modelMode(elements) {
    const type = (elements && elements[0] && elements[0].type || 'B4').toUpperCase();
    if (type[0] === 'B') return 'beam';
    if (type[0] === 'Q' || type === 'T3' || type === 'T6') return 'plate';
    return 'solid';
  }

  // Convex hull (monotone chain) of projected points, returns ordered ids.
  static _hull(pts) {
    const p = pts.slice().sort((a, b) => a.x - b.x || a.y - b.y);
    if (p.length < 3) return p;
    const cr = (o, a, b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
    const lo = [];
    for (const q of p) { while (lo.length >= 2 && cr(lo[lo.length - 2], lo[lo.length - 1], q) <= 0) lo.pop(); lo.push(q); }
    const up = [];
    for (let i = p.length - 1; i >= 0; i--) { const q = p[i]; while (up.length >= 2 && cr(up[up.length - 2], up[up.length - 1], q) <= 0) up.pop(); up.push(q); }
    lo.pop(); up.pop();
    return lo.concat(up);
  }

  // Faces (as arrays of 3D points {x,y,z}) of plate and solid elements.
  _meshFaces(bounds) {
    const nodeMap = {};
    for (const n of bounds.beamNodes) nodeMap[n.id] = n;
    const faces = [];
    const zlo = bounds.zmin, zhi = bounds.zmax;
    const edgeCount = new Map();
    const plateRings = [];
    for (const el of bounds.meshElements) {
      const type = (el.type || '').toUpperCase();
      const ids = el.nodeIds || [];
      const pt = (i) => nodeMap[ids[i]];
      if (bounds.mode === 'plate') {
        const pts = ids.map(id => nodeMap[id]).filter(Boolean).map(nd => ({ x: nd.xVal, y: nd.yVal, z: nd.zVal }));
        if (pts.length < 3) continue;
        const corners = (type === 'T3' || type === 'T6') ? pts.slice(0, 3) : pts;
        const ring = Beam3DRenderer._hull(corners.length >= 3 ? pts : pts);
        plateRings.push(ring);
        for (let i = 0; i < ring.length; i++) {
          const a = ring[i], b = ring[(i + 1) % ring.length];
          const key = [a.x, a.y, b.x, b.y].join(',');
          const rkey = [b.x, b.y, a.x, a.y].join(',');
          edgeCount.set(key, (edgeCount.get(key) || 0) + 1);
          edgeCount.set(rkey, (edgeCount.get(rkey) || 0) + 1);
        }
      } else {
        let idx;
        if (type === 'T4' || type === 'T10') idx = [[0, 1, 2], [0, 1, 3], [1, 2, 3], [2, 0, 3]];
        else if (type === 'P6') idx = [[0, 1, 2], [3, 4, 5], [0, 1, 4, 3], [1, 2, 5, 4], [2, 0, 3, 5]];
        else idx = [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]];
        for (const f of idx) {
          const v = f.map(pt);
          if (v.some(q => !q)) continue;
          faces.push(v.map(q => ({ x: q.xVal, y: q.yVal, z: q.zVal })));
        }
      }
    }
    if (bounds.mode === 'plate') {
      for (const ring of plateRings) {
        faces.push(ring.map(q => ({ x: q.x, y: q.y, z: zhi, top: true })));
        faces.push(ring.map(q => ({ x: q.x, y: q.y, z: zlo, bottom: true })));
        for (let i = 0; i < ring.length; i++) {
          const a = ring[i], b = ring[(i + 1) % ring.length];
          if (edgeCount.get([a.x, a.y, b.x, b.y].join(',')) > 2) continue;
          faces.push([{ x: a.x, y: a.y, z: zlo }, { x: b.x, y: b.y, z: zlo }, { x: b.x, y: b.y, z: zhi }, { x: a.x, y: a.y, z: zhi }]);
        }
      }
    }
    return faces;
  }

  _collectMeshItems(bounds, items) {
    const Ldir = { x: 0.38, y: 0.58, z: 0.72 };
    const faces = this._meshFaces(bounds);
    for (const f of faces) {
      const pr = f.map(v => this.project(v.x, v.y, v.z, bounds));
      const avgDepth = pr.reduce((s, q) => s + q.depth, 0) / pr.length;
      // Normal from scaled 3D coordinates
      const s = f.map(v => [v.x, v.y, bounds.zvis(v.z)]);
      const e1 = [s[1][0] - s[0][0], s[1][1] - s[0][1], s[1][2] - s[0][2]];
      const e2 = [s[2][0] - s[0][0], s[2][1] - s[0][1], s[2][2] - s[0][2]];
      let nx = e1[1] * e2[2] - e1[2] * e2[1];
      let ny = e1[2] * e2[0] - e1[0] * e2[2];
      let nz = e1[0] * e2[1] - e1[1] * e2[0];
      const nl = Math.hypot(nx, ny, nz) || 1;
      nx /= nl; ny /= nl; nz /= nl;
      const diff = Math.abs(nx * Ldir.x + ny * Ldir.y + nz * Ldir.z);
      const k = 0.3 + 0.7 * diff;
      const top = f[0].top;
      const base = top ? [56, 189, 248] : (f[0].bottom ? [45, 60, 180] : [80, 130, 245]);
      const fill = `rgba(${Math.round(base[0] * k)}, ${Math.round(base[1] * k)}, ${Math.round(base[2] * k)}, 0.85)`;
      const wire = this.options.showWireframe;
      items.push({
        depth: avgDepth,
        draw: (ctx) => {
          ctx.beginPath();
          ctx.moveTo(pr[0].sx, pr[0].sy);
          for (let i = 1; i < pr.length; i++) ctx.lineTo(pr[i].sx, pr[i].sy);
          ctx.closePath();
          ctx.fillStyle = fill;
          ctx.fill();
          if (wire) {
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.22)';
            ctx.lineWidth = 0.8;
            ctx.stroke();
          }
        }
      });
    }
  }
  _collectRenderItems(bounds) {
    const items = [];
    const poly = bounds.poly;
    const K = poly.length;

    // Longitudinal beam stations from beamNodes or element spans
    let stations = [];
    if (bounds.beamNodes && bounds.beamNodes.length > 0) {
      stations = bounds.beamNodes.map(n => n.yVal);
    } else {
      const N = 8;
      for (let i = 0; i <= N; i++) stations.push(bounds.ymin + (bounds.ymax - bounds.ymin) * (i / N));
    }
    // Unique and sorted
    stations = Array.from(new Set(stations)).sort((a, b) => a - b);

    // Light direction (camera-independent or slightly angled)
    const Ldir = { x: 0.38, y: 0.58, z: 0.72 };
    const Llen = Math.hypot(Ldir.x, Ldir.y, Ldir.z) || 1;
    Ldir.x /= Llen; Ldir.y /= Llen; Ldir.z /= Llen;

    if (bounds.mode !== 'beam') {
      this._collectMeshItems(bounds, items);
    } else {
    // A. 3D Extruded Beam Solid (Faces)
    if (this.options.showFaces && K >= 3 && stations.length >= 2) {
      for (let s = 0; s < stations.length - 1; s++) {
        const yA = stations[s];
        const yB = stations[s + 1];
        const dy = yB - yA;

        for (const lp of bounds.loops) for (let i = 0; i < lp.length; i++) {
          const pA = lp[i];
          const pB = lp[(i + 1) % lp.length];

          // Face vertices in 3D
          const v0 = { x: pA.xVal, y: yA, z: pA.zVal };
          const v1 = { x: pB.xVal, y: yA, z: pB.zVal };
          const v2 = { x: pB.xVal, y: yB, z: pB.zVal };
          const v3 = { x: pA.xVal, y: yB, z: pA.zVal };

          // Surface normal in scaled 3D space:
          // e1 = (v1.x - v0.x, 0, zvis(v1.z) - zvis(v0.z))
          // e2 = (0, dy, 0)
          // N = e1 x e2 = (-dz * dy, 0, dx * dy)
          const edx = pB.xVal - pA.xVal;
          const edz = bounds.zvis(pB.zVal) - bounds.zvis(pA.zVal);
          let nx = -edz * dy;
          let ny = 0;
          let nz = edx * dy;
          const nlen = Math.hypot(nx, nz) || 1;
          nx /= nlen; nz /= nlen;

          // Diffuse lighting
          const diff = Math.max(0, nx * Ldir.x + nz * Ldir.z);
          const intensity = 0.28 + 0.72 * diff;

          // Project to 2D screen
          const pr0 = this.project(v0.x, v0.y, v0.z, bounds);
          const pr1 = this.project(v1.x, v1.y, v1.z, bounds);
          const pr2 = this.project(v2.x, v2.y, v2.z, bounds);
          const pr3 = this.project(v3.x, v3.y, v3.z, bounds);

          const avgDepth = (pr0.depth + pr1.depth + pr2.depth + pr3.depth) / 4;

          // Realistic CAD color coding based on surface orientation
          let r, g, b, alpha = 0.85;
          if (nz > 0.4) {
            // Top Face: radiant cyan-blue
            r = Math.round(56 * intensity);
            g = Math.round(189 * intensity);
            b = Math.round(248 * intensity);
          } else if (nz < -0.4) {
            // Bottom Face: deep indigo
            r = Math.round(45 * intensity);
            g = Math.round(60 * intensity);
            b = Math.round(180 * intensity);
          } else if (nx > 0.4) {
            // Right Face: royal blue
            r = Math.round(80 * intensity);
            g = Math.round(130 * intensity);
            b = Math.round(245 * intensity);
          } else if (nx < -0.4) {
            // Left Face: slate blue
            r = Math.round(65 * intensity);
            g = Math.round(105 * intensity);
            b = Math.round(220 * intensity);
          } else {
            r = Math.round(60 * intensity);
            g = Math.round(110 * intensity);
            b = Math.round(230 * intensity);
          }

          const fillColor = `rgba(${r}, ${g}, ${b}, ${alpha})`;
          const showWire = this.options.showWireframe;

          items.push({
            depth: avgDepth,
            draw: (ctx) => {
              ctx.beginPath();
              ctx.moveTo(pr0.sx, pr0.sy);
              ctx.lineTo(pr1.sx, pr1.sy);
              ctx.lineTo(pr2.sx, pr2.sy);
              ctx.lineTo(pr3.sx, pr3.sy);
              ctx.closePath();
              ctx.fillStyle = fillColor;
              ctx.fill();

              if (showWire) {
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
                ctx.lineWidth = 0.8;
                ctx.stroke();
              }
            }
          });
        }
      }
    }

    // B. Root Cap (at ymin) and Tip Cap (at ymax)
    const capYList = [
      { y: bounds.ymin, normalY: -1, label: 'Root' },
      { y: bounds.ymax, normalY: 1, label: 'Tip' }
    ];

    for (const cap of capYList) {
      const prPts = poly.map(p => this.project(p.xVal, cap.y, p.zVal, bounds));
      const prLoops = bounds.loops.map(lp => lp.map(p => this.project(p.xVal, cap.y, p.zVal, bounds)));
      const avgDepth = prPts.reduce((acc, p) => acc + p.depth, 0) / prPts.length;

      // Shading for cap
      const diff = Math.max(0, cap.normalY * Ldir.y);
      const intensity = 0.35 + 0.65 * diff;
      const r = Math.round((cap.normalY > 0 ? 120 : 60) * intensity);
      const g = Math.round((cap.normalY > 0 ? 140 : 80) * intensity);
      const b = Math.round((cap.normalY > 0 ? 255 : 160) * intensity);
      const capColor = `rgba(${r}, ${g}, ${b}, 0.92)`;

      items.push({
        depth: avgDepth - (cap.normalY > 0 ? 0.002 : -0.002),
        draw: (ctx) => {
          ctx.beginPath();
          for (const pl of prLoops) {
            ctx.moveTo(pl[0].sx, pl[0].sy);
            for (let i = 1; i < pl.length; i++) ctx.lineTo(pl[i].sx, pl[i].sy);
            ctx.closePath();
          }
          ctx.fillStyle = capColor;
          ctx.fill('evenodd');

          // Cap outline
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.35)';
          ctx.lineWidth = 1.2;
          ctx.stroke();

          // Draw interior Q9 mesh lines if available
          if (bounds.csElements && bounds.csElements[0]) {
            const nodeMap = {};
            for (const n of bounds.csNodes) nodeMap[n.id] = n;
            const nids = bounds.csElements[0].nodeIds;
            if (nids && nids.length >= 9) {
              // Mid-cross lines connecting 2-8 and 4-6
              const p2 = nodeMap[nids[1]] && this.project(nodeMap[nids[1]].xVal, cap.y, nodeMap[nids[1]].zVal, bounds);
              const p8 = nodeMap[nids[5]] && this.project(nodeMap[nids[5]].xVal, cap.y, nodeMap[nids[5]].zVal, bounds);
              const p4 = nodeMap[nids[7]] && this.project(nodeMap[nids[7]].xVal, cap.y, nodeMap[nids[7]].zVal, bounds);
              const p6 = nodeMap[nids[3]] && this.project(nodeMap[nids[3]].xVal, cap.y, nodeMap[nids[3]].zVal, bounds);
              ctx.strokeStyle = 'rgba(99, 140, 255, 0.45)';
              ctx.lineWidth = 0.8;
              if (p2 && p8) { ctx.beginPath(); ctx.moveTo(p2.sx, p2.sy); ctx.lineTo(p8.sx, p8.sy); ctx.stroke(); }
              if (p4 && p6) { ctx.beginPath(); ctx.moveTo(p4.sx, p4.sy); ctx.lineTo(p6.sx, p6.sy); ctx.stroke(); }
            }
          }
        }
      });
    }

    // C. Intermediate Mesh Ribs (cross-section perimeter at each FE station)
    if (this.options.showWireframe && stations.length > 2) {
      for (let s = 1; s < stations.length - 1; s++) {
        const yVal = stations[s];
        const prPts = poly.map(p => this.project(p.xVal, yVal, p.zVal, bounds));
        const prLoops = bounds.loops.map(lp => lp.map(p => this.project(p.xVal, yVal, p.zVal, bounds)));
        const avgD = prPts.reduce((sum, p) => sum + p.depth, 0) / prPts.length;
        items.push({
          depth: avgD - 0.001,
          draw: (ctx) => {
            ctx.beginPath();
            for (const pl of prLoops) {
              ctx.moveTo(pl[0].sx, pl[0].sy);
              for (let i = 1; i < pl.length; i++) ctx.lineTo(pl[i].sx, pl[i].sy);
              ctx.closePath();
            }
            ctx.strokeStyle = 'rgba(99, 140, 255, 0.38)';
            ctx.lineWidth = 1;
            ctx.stroke();
          }
        });
      }
    }

    // D. Centerline Beam Axis & 1D Nodes
    if (this.options.showCenterline && stations.length >= 2) {
      const pStart = this.project(0, bounds.ymin, 0, bounds);
      const pEnd = this.project(0, bounds.ymax, 0, bounds);
      items.push({
        depth: (pStart.depth + pEnd.depth) / 2 - 0.003,
        draw: (ctx) => {
          ctx.strokeStyle = 'rgba(34, 211, 238, 0.6)';
          ctx.lineWidth = 1.5;
          ctx.setLineDash([4, 4]);
          ctx.beginPath();
          ctx.moveTo(pStart.sx, pStart.sy);
          ctx.lineTo(pEnd.sx, pEnd.sy);
          ctx.stroke();
          ctx.setLineDash([]);
        }
      });
    }

    }

    // E. 1D FE Nodes along beam
    if (this.options.showNodes && bounds.beamNodes) {
      for (const n of bounds.beamNodes) {
        const p = this.project(n.xVal, n.yVal, n.zVal, bounds);
        const isLE = n.expType !== 'TE';
        const isHover = this.hoveredItem?.type === 'node' && this.hoveredItem.data.id === n.id;
        items.push({
          depth: p.depth - 0.006,
          draw: (ctx) => {
            const rad = isHover ? 6 : 4;
            if (isHover) {
              ctx.beginPath();
              ctx.arc(p.sx, p.sy, rad + 4, 0, Math.PI * 2);
              ctx.fillStyle = 'rgba(52, 211, 153, 0.3)';
              ctx.fill();
            }

            ctx.beginPath();
            ctx.arc(p.sx, p.sy, rad, 0, Math.PI * 2);
            ctx.fillStyle = isLE ? '#10b981' : '#a855f7';
            ctx.fill();
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 1.2;
            ctx.stroke();

            // Node ID tag
            ctx.fillStyle = isHover ? '#34d399' : 'rgba(241, 245, 249, 0.85)';
            ctx.font = '600 9px JetBrains Mono, monospace';
            ctx.fillText(n.id, p.sx + 6, p.sy - 6);
          }
        });
      }
    }

    // F. Boundary Conditions (BCs)
    if (this.options.showBCs) {
      const bcData = state.files['BC.dat']?.parsed;
      if (bcData && bcData.conditions) {
        for (const bc of bcData.conditions) {
          if (bc.type === 'D-PLANE') {
            if (bounds.mode !== 'beam') {
              // Generic support plane A*x + B*y + C*z + D = 0 over the model extent
              const A = bc.A, B = bc.B, C = bc.C, Dd = bc.D;
              const ax = Math.abs(A) >= Math.abs(B) && Math.abs(A) >= Math.abs(C) ? 'x' : (Math.abs(B) >= Math.abs(C) ? 'y' : 'z');
              const c0 = ax === 'x' ? A : (ax === 'y' ? B : C);
              const pos = c0 !== 0 ? -Dd / c0 : 0;
              const padv = 0.03 * bounds.D;
              const xr = [bounds.xmin - padv, bounds.xmax + padv];
              const yr = [bounds.ymin - padv, bounds.ymax + padv];
              const zr = [bounds.zmin - padv, bounds.zmax + padv];
              let q;
              if (ax === 'x') q = [[pos, yr[0], zr[0]], [pos, yr[1], zr[0]], [pos, yr[1], zr[1]], [pos, yr[0], zr[1]]];
              else if (ax === 'y') q = [[xr[0], pos, zr[0]], [xr[1], pos, zr[0]], [xr[1], pos, zr[1]], [xr[0], pos, zr[1]]];
              else q = [[xr[0], yr[0], pos], [xr[1], yr[0], pos], [xr[1], yr[1], pos], [xr[0], yr[1], pos]];
              const cp = q.map(v => this.project(v[0], v[1], v[2], bounds));
              items.push({
                depth: cp.reduce((a, b) => a + b.depth, 0) / 4 + 0.005,
                draw: (ctx) => {
                  ctx.beginPath();
                  ctx.moveTo(cp[0].sx, cp[0].sy);
                  for (let c = 1; c < 4; c++) ctx.lineTo(cp[c].sx, cp[c].sy);
                  ctx.closePath();
                  ctx.fillStyle = 'rgba(239, 68, 68, 0.18)';
                  ctx.fill();
                  ctx.strokeStyle = 'rgba(239, 68, 68, 0.65)';
                  ctx.lineWidth = 1.5;
                  ctx.stroke();
                  ctx.fillStyle = '#f87171';
                  ctx.font = '600 10px Inter, sans-serif';
                  ctx.fillText('Clamp D' + bc.id + ' (' + ax + ' = ' + pos.toPrecision(3) + ')', cp[0].sx + 6, cp[0].sy - 6);
                }
              });
              continue;
            }
            // Clamped Root Plane at Y = 0 (or plane equation)
            // Draw a stylish 3D support plate / mounting block
            const clampY = bounds.ymin;
            const pw = bounds.W * 0.7;
            const ph = bounds.Hvis * 0.75;
            const corners = [
              this.project(-pw, clampY, -ph / bounds.Sz, bounds),
              this.project(pw, clampY, -ph / bounds.Sz, bounds),
              this.project(pw, clampY, ph / bounds.Sz, bounds),
              this.project(-pw, clampY, ph / bounds.Sz, bounds)
            ];
            const avgD = corners.reduce((a, b) => a + b.depth, 0) / 4;

            items.push({
              depth: avgD + 0.005,
              draw: (ctx) => {
                // Fixed plate face
                ctx.beginPath();
                ctx.moveTo(corners[0].sx, corners[0].sy);
                for (let c = 1; c < 4; c++) ctx.lineTo(corners[c].sx, corners[c].sy);
                ctx.closePath();
                ctx.fillStyle = 'rgba(239, 68, 68, 0.18)';
                ctx.fill();
                ctx.strokeStyle = 'rgba(239, 68, 68, 0.65)';
                ctx.lineWidth = 1.5;
                ctx.stroke();

                // Ground hatch lines on support
                ctx.strokeStyle = 'rgba(239, 68, 68, 0.35)';
                ctx.lineWidth = 1;
                for (let h = 0; h < 6; h++) {
                  const frac = (h + 1) / 7;
                  const x1 = -pw + 2 * pw * frac;
                  const pTop = this.project(x1, clampY, ph / bounds.Sz, bounds);
                  const pBot = this.project(x1 - pw * 0.15, clampY, -ph / bounds.Sz, bounds);
                  ctx.beginPath();
                  ctx.moveTo(pTop.sx, pTop.sy);
                  ctx.lineTo(pBot.sx, pBot.sy);
                  ctx.stroke();
                }

                // Root clamp badge
                const midTop = this.project(0, clampY, ph / bounds.Sz, bounds);
                ctx.fillStyle = '#f87171';
                ctx.font = '600 10px Inter, sans-serif';
                ctx.fillText('⟂ Root Clamp (Fixed)', midTop.sx - 48, midTop.sy - 8);
              }
            });
          } else if (bc.type === 'F-POINT') {
            // 3D Point Load arrow
            const px = Fortran.parseFloat(bc.x);
            const py = Fortran.parseFloat(bc.y);
            const pz = Fortran.parseFloat(bc.z);
            const fx = Fortran.parseFloat(bc.fx);
            const fy = Fortran.parseFloat(bc.fy);
            const fz = Fortran.parseFloat(bc.fz);

            const fmag = Math.hypot(fx, fy, fz);
            if (fmag > 0) {
              const arrowLen = bounds.D * 0.18;
              const dirX = fx / fmag;
              const dirY = fy / fmag;
              const dirZ = fz / fmag;

              const pBase = this.project(px, py, pz, bounds);
              const tipX = px + dirX * arrowLen;
              const tipY = py + dirY * arrowLen;
              const tipZ = pz + (dirZ * arrowLen) / bounds.Sz;
              const pTip = this.project(tipX, tipY, tipZ, bounds);

              const isHover = this.hoveredItem?.type === 'bc-f' && this.hoveredItem.data.id === bc.id;

              items.push({
                depth: pBase.depth - 0.008,
                draw: (ctx) => {
                  const color = fz < 0 ? '#34d399' : '#fbbf24';
                  ctx.strokeStyle = color;
                  ctx.lineWidth = isHover ? 3.5 : 2.5;

                  // Arrow shaft
                  ctx.beginPath();
                  ctx.moveTo(pBase.sx, pBase.sy);
                  ctx.lineTo(pTip.sx, pTip.sy);
                  ctx.stroke();

                  // Arrow head cone
                  const angle = Math.atan2(pTip.sy - pBase.sy, pTip.sx - pBase.sx);
                  const headLen = 10;
                  ctx.fillStyle = color;
                  ctx.beginPath();
                  ctx.moveTo(pTip.sx, pTip.sy);
                  ctx.lineTo(
                    pTip.sx - headLen * Math.cos(angle - Math.PI / 6),
                    pTip.sy - headLen * Math.sin(angle - Math.PI / 6)
                  );
                  ctx.lineTo(
                    pTip.sx - headLen * Math.cos(angle + Math.PI / 6),
                    pTip.sy - headLen * Math.sin(angle + Math.PI / 6)
                  );
                  ctx.closePath();
                  ctx.fill();

                  // Load label
                  ctx.fillStyle = 'rgba(10, 15, 30, 0.8)';
                  const label = `F${bc.id}: ${fz.toFixed(0)}N`;
                  ctx.font = '600 9px JetBrains Mono, monospace';
                  const tw = ctx.measureText(label).width;
                  ctx.fillRect(pTip.sx + 4, pTip.sy - 14, tw + 6, 14);

                  ctx.fillStyle = color;
                  ctx.fillText(label, pTip.sx + 7, pTip.sy - 3);
                }
              });
            }
          }
        }
      }
    }

    // G. Post-Processing Evaluation Points (PNT)
    if (this.options.showPNT) {
      const postData = state.files['POSTPROCESSING.dat']?.parsed;
      if (postData && postData.entries) {
        for (const e of postData.entries) {
          if (e.type === 'PNT') {
            const p = this.project(e.xVal, e.yVal, e.zVal, bounds);
            items.push({
              depth: p.depth - 0.007,
              draw: (ctx) => {
                // Target reticle
                ctx.strokeStyle = '#06b6d4';
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.arc(p.sx, p.sy, 6, 0, Math.PI * 2);
                ctx.stroke();

                ctx.fillStyle = 'rgba(6, 182, 212, 0.4)';
                ctx.beginPath();
                ctx.arc(p.sx, p.sy, 2.5, 0, Math.PI * 2);
                ctx.fill();

                // Crosshair ticks
                ctx.beginPath();
                ctx.moveTo(p.sx - 9, p.sy); ctx.lineTo(p.sx - 3, p.sy);
                ctx.moveTo(p.sx + 3, p.sy); ctx.lineTo(p.sx + 9, p.sy);
                ctx.moveTo(p.sx, p.sy - 9); ctx.lineTo(p.sx, p.sy - 3);
                ctx.moveTo(p.sx, p.sy + 3); ctx.lineTo(p.sx, p.sy + 9);
                ctx.stroke();

                ctx.fillStyle = '#22d3ee';
                ctx.font = '600 9px JetBrains Mono, monospace';
                ctx.fillText(`PNT ${e.id}`, p.sx + 9, p.sy - 4);
              }
            });
          }
        }
      }
    }

    return items;
  }
}

// Global renderer instance
window.beamRenderer = new Beam3DRenderer();
const Renderer3D = Beam3DRenderer;
let renderer3d = window.beamRenderer;

// ──────────────────────────────────────────────
//  CROSS-SECTION 2D RENDERER
// ──────────────────────────────────────────────
function renderCrossSection2D(canvas, meshData, connData) {
  const ctx = canvas.getContext('2d');
  const dpr = window.devicePixelRatio || 1;
  const parent = canvas.parentElement;
  canvas.width = parent.clientWidth * dpr;
  canvas.height = parent.clientHeight * dpr;
  canvas.style.width = parent.clientWidth + 'px';
  canvas.style.height = parent.clientHeight + 'px';
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  const w = parent.clientWidth, h = parent.clientHeight;

  // Background
  ctx.fillStyle = '#060a14';
  ctx.fillRect(0, 0, w, h);

  if (!meshData || !meshData.nodes.length) return;

  // Find bounds in x-z (cross-section plane)
  let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
  for (const n of meshData.nodes) {
    minX = Math.min(minX, n.xVal); maxX = Math.max(maxX, n.xVal);
    minZ = Math.min(minZ, n.zVal); maxZ = Math.max(maxZ, n.zVal);
  }

  const rangeX = maxX - minX || 1;
  const rangeZ = maxZ - minZ || 1;
  const margin = 50;
  const scaleX = (w - 2 * margin) / rangeX;
  const scaleZ = (h - 2 * margin) / rangeZ;
  const scale = Math.min(scaleX, scaleZ);
  const cx = w / 2, cy = h / 2;
  const midX = (minX + maxX) / 2, midZ = (minZ + maxZ) / 2;

  const toScreen = (x, z) => ({
    sx: cx + (x - midX) * scale,
    sy: cy - (z - midZ) * scale
  });

  // Draw element edges
  if (connData) {
    const nodeMap = {};
    for (const n of meshData.nodes) nodeMap[n.id] = n;
    for (const elem of connData.elements) {
      const nids = elem.nodeIds;
      const baseRing = Parsers.elementRing(elem);
      const outerRing = [...baseRing, baseRing[0]];
      ctx.strokeStyle = 'rgba(167, 139, 250, 0.5)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      for (let i = 0; i < outerRing.length; i++) {
        const n = nodeMap[outerRing[i]];
        if (!n) continue;
        const p = toScreen(n.xVal, n.zVal);
        if (i === 0) ctx.moveTo(p.sx, p.sy);
        else ctx.lineTo(p.sx, p.sy);
      }
      ctx.stroke();

      // Fill lightly
      ctx.fillStyle = 'rgba(167, 139, 250, 0.05)';
      ctx.fill();
    }
  }

  // Draw nodes
  for (const n of meshData.nodes) {
    const p = toScreen(n.xVal, n.zVal);
    ctx.beginPath();
    ctx.arc(p.sx, p.sy, 5, 0, Math.PI * 2);
    ctx.fillStyle = '#638cff';
    ctx.fill();
    ctx.strokeStyle = '#3b5cc8';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.fillStyle = 'rgba(232, 236, 244, 0.8)';
    ctx.font = '10px JetBrains Mono, monospace';
    ctx.fillText(n.id, p.sx + 8, p.sy - 6);
  }

  // Axis labels
  ctx.fillStyle = 'rgba(139, 156, 192, 0.5)';
  ctx.font = '11px Inter, sans-serif';
  ctx.fillText('x →', w - 40, h - 15);
  ctx.fillText('z ↑', 10, 20);
}


// ──────────────────────────────────────────────
//  VALIDATION
// ──────────────────────────────────────────────
function validateAll() {
  const msgs = [];

  const nodes = state.files['NODES.dat']?.parsed;
  const conn = state.files['CONNECTIVITY.dat']?.parsed;
  const versors = state.files['VERSORS.dat']?.parsed;
  const material = state.files['MATERIAL.dat']?.parsed;
  const lamination = state.files['LAMINATION.dat']?.parsed;
  const bc = state.files['BC.dat']?.parsed;

  if (conn && nodes) {
    const nodeIds = new Set(nodes.nodes.map(n => n.id));
    for (const e of conn.elements) {
      for (const nid of e.nodeIds) {
        if (!nodeIds.has(nid)) {
          msgs.push({ type: 'error', text: `CONNECTIVITY: Element ${e.id} references non-existent node ${nid}` });
        }
      }
    }
  }

  if (conn && versors) {
    const vIds = new Set(versors.versors.map(v => v.id));
    for (const e of conn.elements) {
      if (!vIds.has(e.versorRef)) {
        msgs.push({ type: 'error', text: `CONNECTIVITY: Element ${e.id} references non-existent versor ${e.versorRef}` });
      }
    }
  }

  if (conn) {
    for (const e of conn.elements) {
      const fname = 'EXP_CONN_' + String(e.csRef).padStart(2, '0') + '.dat';
      if (!state.files[fname]) {
        msgs.push({ type: 'warning', text: `CONNECTIVITY: Element ${e.id} references cross-section ${e.csRef}, but ${fname} not found` });
      }
    }
  }

  if (lamination && material) {
    const matIds = new Set(material.materials.map(m => m.id));
    for (const l of lamination.laminations) {
      if (!matIds.has(l.matRef)) {
        msgs.push({ type: 'error', text: `LAMINATION: Entry ${l.id} references non-existent material ${l.matRef}` });
      }
    }
  }

  // EXP_CONN lamination refs
  for (const fname of Object.keys(state.files)) {
    if (!fname.startsWith('EXP_CONN_')) continue;
    const ecData = state.files[fname]?.parsed;
    if (!ecData || !lamination) continue;
    const lamIds = new Set(lamination.laminations.map(l => l.id));
    for (const e of ecData.elements) {
      if (!lamIds.has(e.lamRef)) {
        msgs.push({ type: 'error', text: `${fname}: Element ${e.id} references non-existent lamination ${e.lamRef}` });
      }
    }
  }

  // EXP_CONN node refs against EXP_MESH
  for (const fname of Object.keys(state.files)) {
    if (!fname.startsWith('EXP_CONN_')) continue;
    const num = fname.match(/\d+/)?.[0];
    const meshFname = 'EXP_MESH_' + num + '.dat';
    const ecData = state.files[fname]?.parsed;
    const emData = state.files[meshFname]?.parsed;
    if (!ecData || !emData) continue;
    const meshNodeIds = new Set(emData.nodes.map(n => n.id));
    for (const e of ecData.elements) {
      for (const nid of e.nodeIds.concat((e.mids || []).filter(Boolean))) {
        if (!meshNodeIds.has(nid)) {
          msgs.push({ type: 'error', text: `${fname}: Element ${e.id} references non-existent mesh node ${nid}` });
        }
      }
    }
  }

  if (msgs.length === 0) {
    msgs.push({ type: 'success', text: 'All cross-file references are valid ✓' });
  }

  return msgs;
}

// ──────────────────────────────────────────────
//  UI: Toast Notifications
// ──────────────────────────────────────────────
function showToast(msg, type = 'info') {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = 'toast ' + type;
  toast.textContent = msg;
  container.appendChild(toast);
  setTimeout(() => { toast.style.opacity = '0'; toast.style.transform = 'translateY(10px)'; setTimeout(() => toast.remove(), 300); }, 3000);
}

// ──────────────────────────────────────────────
//  UI: Sidebar
// ──────────────────────────────────────────────
function renderSidebar() {
  const container = document.getElementById('file-cards-container');
  container.innerHTML = '';

  // Sort files by FILE_ORDER
  const sortedNames = Object.keys(state.files).sort((a, b) => {
    const aOrder = FILE_ORDER.findIndex(f => a.startsWith(f.replace('.dat', '')));
    const bOrder = FILE_ORDER.findIndex(f => b.startsWith(f.replace('.dat', '')));
    return (aOrder === -1 ? 999 : aOrder) - (bOrder === -1 ? 999 : bOrder);
  });

  for (const fname of sortedNames) {
    const fdata = state.files[fname];
    const meta = FILE_META[fname] || guessFileMeta(fname);
    const card = document.createElement('div');
    card.className = 'file-card' + (state.activeFile === fname ? ' active' : '');
    card.dataset.file = fname;

    const countStr = getFileCountStr(fname, fdata);
    const isValid = true; // simplified

    card.innerHTML = `
      <div class="file-card-icon ${meta.cls}">${meta.icon}</div>
      <div class="file-card-info">
        <div class="file-card-name">${fname}</div>
        <div class="file-card-meta">${countStr}</div>
      </div>
      <div class="file-card-badge valid"></div>
    `;

    card.addEventListener('click', () => selectFile(fname));
    container.appendChild(card);
  }

  // Validation summary
  const valDiv = document.getElementById('validation-summary-sidebar');
  if (sortedNames.length === 0) {
    if (valDiv) valDiv.style.display = 'none';
    updateActionButtonsState();
    return;
  }

  const msgs = validateAll();
  const errors = msgs.filter(m => m.type === 'error').length;
  const warnings = msgs.filter(m => m.type === 'warning').length;
  if (errors > 0 || warnings > 0) {
    valDiv.style.display = 'block';
    valDiv.innerHTML = `
      <div style="font-size:11px; font-weight:600; margin-bottom:4px;">Validation</div>
      ${errors > 0 ? `<div class="validation-msg error" style="margin-bottom:4px;font-size:10px;">✗ ${errors} error(s)</div>` : ''}
      ${warnings > 0 ? `<div class="validation-msg warning" style="font-size:10px;">⚠ ${warnings} warning(s)</div>` : ''}
    `;
  } else {
    valDiv.style.display = 'block';
    valDiv.innerHTML = `<div class="validation-msg success" style="font-size:10px;">✓ All references valid</div>`;
  }
  updateActionButtonsState();
}

function guessFileMeta(fname) {
  if (fname.startsWith('EXP_CONN')) return { icon: 'EC', cls: 'exp-conn', label: 'Cross-Section Connectivity' };
  if (fname.startsWith('EXP_MESH')) return { icon: 'EM', cls: 'exp-mesh', label: 'Cross-Section Mesh' };
  return { icon: '?', cls: 'analysis', label: fname };
}

function getFileCountStr(fname, fdata) {
  if (!fdata.parsed) return '';
  if (fname === 'NODES.dat') return fdata.parsed.nodes.length + ' nodes';
  if (fname === 'CONNECTIVITY.dat') return fdata.parsed.elements.length + ' elements';
  if (fname === 'MATERIAL.dat') return fdata.parsed.materials.length + ' materials';
  if (fname === 'LAMINATION.dat') return fdata.parsed.laminations.length + ' laminations';
  if (fname === 'VERSORS.dat') return fdata.parsed.versors.length + ' versors';
  if (fname === 'BC.dat') return fdata.parsed.conditions.length + ' conditions';
  if (fname === 'POSTPROCESSING.dat') return fdata.parsed.entries.length + ' entries';
  if (fname === 'FIELDS.dat') return fdata.parsed.fields.length + ' fields';
  if (fname.startsWith('EXP_CONN')) return fdata.parsed.elements.length + ' elements';
  if (fname.startsWith('EXP_MESH')) return fdata.parsed.nodes.length + ' nodes';
  return '';
}

// ──────────────────────────────────────────────
//  UI: Select File & Render Editor
// ──────────────────────────────────────────────
function selectFile(fname) {
  state.activeFile = fname;
  document.getElementById('welcome-screen').style.display = 'none';

  // Show appropriate view
  setView(state.activeView);

  // Update header
  const meta = FILE_META[fname] || guessFileMeta(fname);
  document.getElementById('main-header-title').innerHTML = `
    <span class="file-card-icon ${meta.cls}" style="width:24px;height:24px;font-size:11px;">${meta.icon}</span>
    <span>${fname}</span>
    <span class="tag tag-blue">${meta.label}</span>
  `;

  // Render editor
  renderEditorForFile(fname);

  // Render raw text
  updateRawView(fname);

  // Update sidebar
  renderSidebar();
}

function setView(view) {
  state.activeView = view;
  const editorPanel = document.getElementById('editor-panel');
  const rawPanel = document.getElementById('raw-panel');
  const splitPanel = document.getElementById('split-panel');
  const panel3D = document.getElementById('panel-3d');
  const runPanel = document.getElementById('run-panel');

  if (editorPanel) editorPanel.style.display = 'none';
  if (rawPanel) rawPanel.style.display = 'none';
  if (splitPanel) splitPanel.style.display = 'none';
  if (panel3D) panel3D.style.display = 'none';
  if (runPanel) runPanel.style.display = 'none';

  if (view === 'editor') {
    if (editorPanel) editorPanel.style.display = 'block';
  } else if (view === 'raw') {
    if (rawPanel) rawPanel.style.display = 'flex';
  } else if (view === 'split') {
    if (splitPanel) splitPanel.style.display = 'flex';
    setTimeout(() => {
      const canvas = document.getElementById('split-viewport-canvas');
      if (canvas && window.beamRenderer) {
        window.beamRenderer.attachToCanvas(canvas);
      }
    }, 40);
  } else if (view === '3d') {
    if (panel3D) panel3D.style.display = 'flex';
    update3DMetrics();
    setTimeout(() => {
      const canvas = document.getElementById('full-viewport-canvas');
      if (canvas && window.beamRenderer) {
        window.beamRenderer.attachToCanvas(canvas);
      }
    }, 40);
  } else if (view === 'run') {
    if (runPanel) runPanel.style.display = 'block';
    checkServerAvailability();
  }

  // Update tabs
  document.querySelectorAll('.main-header-tab').forEach(t => {
    t.classList.toggle('active', t.dataset.view === view);
  });

  if (state.activeFile) {
    if (view === 'editor') renderEditorForFile(state.activeFile);
    if (view === 'split') renderSplitView(state.activeFile);
    updateRawView(state.activeFile);
  }
}

function update3DMetrics() {
  if (!window.beamRenderer) return;
  const bounds = window.beamRenderer._computeModelBounds();
  const grid = document.getElementById('metrics-grid');
  const csSummary = document.getElementById('cs-summary-content');
  if (!grid) return;

  const hudTag = document.getElementById('hud-beam-type');
  if (hudTag) hudTag.textContent = bounds.mode === 'beam' ? '1D Beam / 2D Cross-Section' : (bounds.mode === 'plate' ? '2D Plate / CUF Thickness Expansion' : '3D Solid');

  const L = bounds.L;
  const W = bounds.W;
  const H = bounds.H;
  const area = bounds.mode === 'beam' ? W * H : W * L;
  const volume = L * W * H;

  const nodesCount = bounds.beamNodes.length;
  const connData = state.files['CONNECTIVITY.dat']?.parsed;
  const numElems = connData ? connData.elements.length : 0;
  const elemType = connData && connData.elements[0] ? connData.elements[0].type : 'B4';

  const bcData = state.files['BC.dat']?.parsed;
  let numClamps = 0, numForces = 0;
  if (bcData && bcData.conditions) {
    for (const c of bcData.conditions) {
      if (c.type === 'D-PLANE') numClamps++;
      if (c.type === 'F-POINT') numForces++;
    }
  }

  grid.innerHTML = `
    <div class="metric-card">
      <div class="metric-card-label">Length (Y)</div>
      <div class="metric-card-val">${L.toFixed(3)} m</div>
      <div class="metric-card-sub">${(L * 1000).toFixed(1)} mm</div>
    </div>
    <div class="metric-card">
      <div class="metric-card-label">Width (X)</div>
      <div class="metric-card-val">${W.toFixed(3)} m</div>
      <div class="metric-card-sub">${(W * 1000).toFixed(1)} mm</div>
    </div>
    <div class="metric-card">
      <div class="metric-card-label">Thickness (Z)</div>
      <div class="metric-card-val">${H.toFixed(5)} m</div>
      <div class="metric-card-sub">${(H * 1000).toFixed(2)} mm</div>
    </div>
    <div class="metric-card">
      <div class="metric-card-label">Aspect Ratio (L/H)</div>
      <div class="metric-card-val">${(L / H).toFixed(0)} : 1</div>
      <div class="metric-card-sub">W/H = ${(W / H).toFixed(0)}:1</div>
    </div>
    <div class="metric-card">
      <div class="metric-card-label">${bounds.mode === 'beam' ? 'Cross-Section Area' : 'Plan Area (XY)'}</div>
      <div class="metric-card-val">${area < 0.001 ? area.toExponential(3) : area.toFixed(4)} m²</div>
      <div class="metric-card-sub">Rectangular Solid</div>
    </div>
    <div class="metric-card">
      <div class="metric-card-label">${bounds.mode === 'beam' ? 'Beam Volume' : 'Volume'}</div>
      <div class="metric-card-val">${volume < 0.001 ? volume.toExponential(3) : volume.toFixed(4)} m³</div>
      <div class="metric-card-sub">${(volume * 1e6).toFixed(1)} cm³</div>
    </div>
    <div class="metric-card">
      <div class="metric-card-label">${bounds.mode === 'beam' ? '1D FE Mesh' : (bounds.mode === 'plate' ? '2D FE Mesh' : '3D FE Mesh')}</div>
      <div class="metric-card-val">${numElems} &times; ${elemType}</div>
      <div class="metric-card-sub">${nodesCount} ${bounds.mode === 'beam' ? 'Beam' : 'Mesh'} Nodes</div>
    </div>
    <div class="metric-card">
      <div class="metric-card-label">Active BCs</div>
      <div class="metric-card-val">${numClamps} Clamp / ${numForces} Force</div>
      <div class="metric-card-sub">${bounds.mode === 'beam' ? 'Root Clamp &amp; Tip Loads' : 'Support planes &amp; point loads'}</div>
    </div>
  `;

  if (csSummary && bounds.mode !== 'beam') {
    const kind = bounds.mode === 'plate' ? '2D plate (CUF through-thickness expansion)' : '3D solid';
    csSummary.innerHTML = `<div>&bull; <strong>Model:</strong> ${kind}</div><div>&bull; <strong>Elements:</strong> ${numElems} &times; ${elemType}</div><div>&bull; <strong>Thickness (Z):</strong> ${(bounds.zmax - bounds.zmin).toPrecision(4)} m</div>`;
  } else if (csSummary) {
    const csNodesCount = bounds.csNodes.length;
    const csElemsCount = bounds.csElements.length;
    const csElemType = bounds.csElements[0]?.type || 'Q9';
    csSummary.innerHTML = `
      <div style="margin-bottom:6px;"><strong>Cross-Section:</strong> EXP_MESH / EXP_CONN (2D CUF Expansion)</div>
      <div>&bull; <strong>Elements:</strong> ${csElemsCount} &times; ${csElemType} element (${csNodesCount} Lagrange nodes)</div>
      <div>&bull; <strong>Kinematics:</strong> 1D Carrera Unified Formulation (CUF) beam with 2D cross-section expansion.</div>
      <div>&bull; <strong>Coordinate System:</strong> Y along length, X across width, Z through thickness.</div>
    `;
  }
}

function updateRawView(fname) {
  const fdata = state.files[fname];
  if (!fdata) return;

  // Generate text from parsed data
  const text = generateFileText(fname, fdata.parsed);

  const textarea = document.getElementById('raw-textarea');
  const splitTextarea = document.getElementById('split-raw-textarea');
  const lineNums = document.getElementById('raw-line-numbers');
  const splitLineNums = document.getElementById('split-line-numbers');
  const rawLabel = document.getElementById('raw-file-label');
  const splitLabel = document.getElementById('split-raw-label');

  textarea.value = text;
  if (splitTextarea) splitTextarea.value = text;
  rawLabel.textContent = fname;
  if (splitLabel) splitLabel.textContent = fname;

  // Line numbers
  const lines = text.split('\n');
  const numsHtml = lines.map((_, i) => {
    let cls = 'line-num';
    if (i === 0) cls += ' header-line';
    return `<span class="${cls}">${i + 1}</span>`;
  }).join('');
  lineNums.innerHTML = numsHtml;
  if (splitLineNums) splitLineNums.innerHTML = numsHtml;
}

function generateFileText(fname, parsed) {
  if (!parsed) return '';
  if (fname === 'ANALYSIS.dat') return Generators.analysis(parsed);
  if (fname === 'NODES.dat') return Generators.nodes(parsed);
  if (fname === 'CONNECTIVITY.dat') return Generators.connectivity(parsed);
  if (fname === 'VERSORS.dat') return Generators.versors(parsed);
  if (fname === 'MATERIAL.dat') return Generators.material(parsed);
  if (fname === 'LAMINATION.dat') return Generators.lamination(parsed);
  if (fname.startsWith('EXP_CONN_')) return Generators.expConn(parsed);
  if (fname.startsWith('EXP_MESH_')) return Generators.expMesh(parsed);
  if (fname === 'BC.dat') return Generators.bc(parsed);
  if (fname === 'POSTPROCESSING.dat') return Generators.postprocessing(parsed);
  if (fname === 'FIELDS.dat') return Generators.fields(parsed);
  if (fname === 'TIME_RESP.dat') return Generators.timeResponse(parsed);
  if (fname === 'FREQ_RESP.dat') return Generators.frequencyResponse(parsed);
  return Generators.generic(parsed);
}

function renderSplitView(fname) {
  const splitEditor = document.getElementById('split-editor');
  if (!splitEditor) return;
  splitEditor.innerHTML = '';
  const content = buildEditorContent(fname);
  splitEditor.appendChild(content);

  setTimeout(() => {
    const canvas = document.getElementById('split-viewport-canvas');
    const container = document.getElementById('split-3d-container');
    if (canvas && container && container.style.display !== 'none' && window.beamRenderer) {
      window.beamRenderer.attachToCanvas(canvas);
    }
  }, 40);
}

// ──────────────────────────────────────────────
//  EDITOR RENDERERS
// ──────────────────────────────────────────────
function renderEditorForFile(fname) {
  // Hide all editor sections
  document.querySelectorAll('.editor-section').forEach(s => s.classList.remove('active'));

  const editorPanel = document.getElementById('editor-panel');

  // Find or create section
  let section = document.querySelector(`.editor-section[data-file="${fname}"]`);
  if (!section) {
    section = document.createElement('div');
    section.className = 'editor-section';
    section.dataset.file = fname;
    editorPanel.appendChild(section);
  }

  section.classList.add('active');
  section.innerHTML = '';

  const content = buildEditorContent(fname);
  section.appendChild(content);
}

function buildEditorContent(fname) {
  const wrapper = document.createElement('div');
  wrapper.className = 'animate-in';

  const fdata = state.files[fname];
  if (!fdata || !fdata.parsed) {
    wrapper.innerHTML = '<div style="color:var(--text-muted);padding:40px;">No data loaded for this file.</div>';
    return wrapper;
  }

  if (fname === 'ANALYSIS.dat') buildAnalysisEditor(wrapper, fdata);
  else if (fname === 'NODES.dat') buildNodesEditor(wrapper, fdata);
  else if (fname === 'CONNECTIVITY.dat') buildConnectivityEditor(wrapper, fdata);
  else if (fname === 'VERSORS.dat') buildVersorsEditor(wrapper, fdata);
  else if (fname === 'MATERIAL.dat') buildMaterialEditor(wrapper, fdata);
  else if (fname === 'LAMINATION.dat') buildLaminationEditor(wrapper, fdata);
  else if (fname.startsWith('EXP_CONN_')) buildExpConnEditor(wrapper, fdata, fname);
  else if (fname.startsWith('EXP_MESH_')) buildExpMeshEditor(wrapper, fdata, fname);
  else if (fname === 'BC.dat') buildBCEditor(wrapper, fdata);
  else if (fname === 'POSTPROCESSING.dat') buildPostprocessingEditor(wrapper, fdata);
  else if (fname === 'FIELDS.dat') buildFieldsEditor(wrapper, fdata);
  else if (fname === 'TIME_RESP.dat') buildTimeResponseEditor(wrapper, fdata);
  else if (fname === 'FREQ_RESP.dat') buildFrequencyResponseEditor(wrapper, fdata);
  else buildGenericEditor(wrapper, fdata, fname);

  return wrapper;
}

// ─── ANALYSIS EDITOR ───
function buildAnalysisEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Analysis Configuration', 'A', 'analysis', 'Select analysis type, number of modes, and shear locking corrections.');

  const analysisTypes = ANALYSIS_TYPES;

  const body = card.querySelector('.editor-card-body');

  // Analysis type
  body.innerHTML += `
    <div class="form-group">
      <label class="form-label">Analysis Type</label>
      <select class="form-select" id="analysis-type">
        ${analysisTypes.map(t => `<option value="${t.value}" ${t.value === p.analysisCode ? 'selected' : ''}>${t.label}</option>`).join('')}
      </select>
    </div>
  `;

  // Number of modes
  body.innerHTML += `
    <div class="form-group">
      <label class="form-label">Number of Modes (Modal Analysis)</label>
      <input class="form-input" type="number" id="analysis-modes" value="${p.modes}" min="1" max="1000">
      <div class="form-hint">Used by modal, buckling and frequency-domain analyses.</div>
    </div>
  `;

  // Shear corrections
  const shearOptions = ['NONE', 'REDI', 'SELI', 'MITC'];
  for (const [key, label] of [['shearBeam', 'Beam'], ['shearPlate', 'Plate'], ['shearSolid', 'Solid']]) {
    body.innerHTML += `
      <div class="form-group">
        <label class="form-label">Shear Locking Correction — ${label}</label>
        <div class="radio-group" data-field="${key}">
          ${shearOptions.map(opt => `<div class="radio-option ${p[key] === opt ? 'active' : ''}" data-value="${opt}">${opt}</div>`).join('')}
        </div>
        <div class="form-hint">NONE full integration, REDI reduced integration, SELI selective (shear terms reduced), MITC tied shear strains.</div>
      </div>
    `;
  }

  wrapper.appendChild(card);

  // Event listeners
  setTimeout(() => {
    const typeSelect = wrapper.querySelector('#analysis-type');
    if (typeSelect) typeSelect.addEventListener('change', () => { p.analysisCode = parseInt(typeSelect.value, 10); onDataChange(); });

    const modesInput = wrapper.querySelector('#analysis-modes');
    if (modesInput) modesInput.addEventListener('input', () => { p.modes = parseInt(modesInput.value, 10) || 20; onDataChange(); });

    wrapper.querySelectorAll('.radio-group').forEach(group => {
      const field = group.dataset.field;
      group.querySelectorAll('.radio-option').forEach(opt => {
        opt.addEventListener('click', () => {
          group.querySelectorAll('.radio-option').forEach(o => o.classList.remove('active'));
          opt.classList.add('active');
          p[field] = opt.dataset.value;
          onDataChange();
        });
      });
    });
  }, 0);
}

// ─── NODES EDITOR ───
function buildNodesEditor(wrapper, fdata) {
  const p = fdata.parsed;

  // 3D viewport (only in single-editor mode, not in side-by-side split mode)
  if (state.activeView !== 'split') {
    const vpDiv = document.createElement('div');
    vpDiv.className = 'inline-viewport';
    vpDiv.innerHTML = `
      <canvas id="nodes-viewport-canvas"></canvas>
      <div class="viewport-overlay-info">Drag to rotate &middot; Scroll to zoom &middot; Shift+drag to pan</div>
      <div class="viewport-legend">
        <div class="viewport-legend-item"><div class="viewport-legend-dot" style="background:#10b981;"></div> LE nodes</div>
        <div class="viewport-legend-item"><div class="viewport-legend-dot" style="background:#a855f7;"></div> TE nodes</div>
        <div class="viewport-legend-item"><div class="viewport-legend-dot" style="background:#f87171;"></div> Clamp BC</div>
        <div class="viewport-legend-item"><div class="viewport-legend-dot" style="background:#34d399;"></div> Force BC</div>
        <div class="viewport-legend-item"><div class="viewport-legend-dot" style="background:#06b6d4;"></div> PNT marker</div>
      </div>
    `;
    wrapper.appendChild(vpDiv);
  }

  // Node table
  const card = createCard('Nodes', 'N', 'nodes', `${p.nodes.length} nodes defined. Y is beam length axis, X-Z is cross-section.`);
  const body = card.querySelector('.editor-card-body');

  body.innerHTML = `
    <div class="data-table-wrapper">
      <table class="data-table" id="nodes-table">
        <thead>
          <tr>
            <th>#</th><th>X</th><th>Y</th><th>Z</th><th>Expansion</th><th>Order</th><th></th>
          </tr>
        </thead>
        <tbody id="nodes-tbody"></tbody>
      </table>
    </div>
    <div style="margin-top:var(--sp-3);display:flex;gap:var(--sp-2);">
      <button class="btn btn-secondary btn-sm" id="btn-add-node">+ Add Node</button>
    </div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    rebuildNodesTable(p);

    // 3D viewport
    const canvas = wrapper.querySelector('#nodes-viewport-canvas');
    if (canvas && state.activeView === 'editor' && window.beamRenderer) {
      window.beamRenderer.attachToCanvas(canvas);
    }

    document.getElementById('btn-add-node')?.addEventListener('click', () => {
      const lastNode = p.nodes[p.nodes.length - 1];
      const newId = lastNode ? lastNode.id + 1 : 1;
      p.nodes.push({
        id: newId, x: '0.0D0', y: '0.0D0', z: '0.0D0', xVal: 0, yVal: 0, zVal: 0,
        expType: 'LE', expOrder: 1
      });
      rebuildNodesTable(p);
      onDataChange();
    });
  }, 0);
}

function rebuildNodesTable(p) {
  const tbody = document.getElementById('nodes-tbody');
  if (!tbody) return;
  tbody.innerHTML = '';

  for (let i = 0; i < p.nodes.length; i++) {
    const n = p.nodes[i];
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="row-num">${n.id}</td>
      <td><input class="cell-input" data-field="x" value="${escHtml(n.x)}" data-idx="${i}"></td>
      <td><input class="cell-input" data-field="y" value="${escHtml(n.y)}" data-idx="${i}"></td>
      <td><input class="cell-input" data-field="z" value="${escHtml(n.z)}" data-idx="${i}"></td>
      <td>
        <select class="cell-select" data-field="expType" data-idx="${i}">
          ${NODE_MODELS.map(model => `<option value="${model}" ${n.expType === model ? 'selected' : ''}>${model}</option>`).join('')}
        </select>
      </td>
      <td><input class="cell-input" type="number" data-field="expOrder" value="${n.expOrder}" data-idx="${i}" min="1" max="20" style="width:50px;"></td>
      <td>
        <div class="row-actions">
          <button class="btn btn-icon btn-ghost btn-sm" data-action="delete" data-idx="${i}" title="Delete node">✕</button>
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  }

  // Bind events
  tbody.querySelectorAll('.cell-input, .cell-select').forEach(input => {
    input.addEventListener('change', () => {
      const idx = parseInt(input.dataset.idx, 10);
      const field = input.dataset.field;
      const node = p.nodes[idx];
      if (!node) return;

      if (field === 'x' || field === 'y' || field === 'z') {
        node[field] = input.value;
        node[field + 'Val'] = Fortran.parseFloat(input.value);
      } else if (field === 'expType') {
        node.expType = input.value;
      } else if (field === 'expOrder') {
        node.expOrder = parseInt(input.value, 10) || 1;
      }
      onDataChange();
    });
  });

  tbody.querySelectorAll('[data-action="delete"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const idx = parseInt(btn.dataset.idx, 10);
      p.nodes.splice(idx, 1);
      // Re-number
      p.nodes.forEach((n, i) => n.id = i + 1);
      rebuildNodesTable(p);
      onDataChange();
    });
  });
}

// ─── CONNECTIVITY EDITOR ───
function buildConnectivityEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Element Connectivity', 'C', 'connectivity', `${p.elements.length} elements. Defines beam elements and their node connectivity.`);
  const body = card.querySelector('.editor-card-body');

  body.innerHTML = `
    <div class="data-table-wrapper">
      <table class="data-table">
        <thead>
          <tr><th>Type</th><th>#</th><th>Node IDs</th><th>Versor Ref</th><th>CS Ref</th><th></th></tr>
        </thead>
        <tbody id="conn-tbody"></tbody>
      </table>
    </div>
    <div style="margin-top:var(--sp-3);display:flex;gap:var(--sp-2);">
      <button class="btn btn-secondary btn-sm" id="btn-add-elem">+ Add Element</button>
    </div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    rebuildConnTable(p);
    document.getElementById('btn-add-elem')?.addEventListener('click', () => {
      const lastElem = p.elements[p.elements.length - 1];
      p.elements.push({
        type: lastElem?.type || 'B4', id: (lastElem?.id || 0) + 1,
        nodeIds: [1, 2, 3, 4], versorRef: 1, csRef: 1
      });
      rebuildConnTable(p);
      onDataChange();
    });
  }, 0);
}

function rebuildConnTable(p) {
  const tbody = document.getElementById('conn-tbody');
  if (!tbody) return;
  tbody.innerHTML = '';

  for (let i = 0; i < p.elements.length; i++) {
    const e = p.elements[i];
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><input class="cell-input" data-field="type" value="${e.type}" data-idx="${i}" style="width:40px;"></td>
      <td class="row-num">${e.id}</td>
      <td><input class="cell-input" data-field="nodeIds" value="${e.nodeIds.join('  ')}" data-idx="${i}" style="min-width:120px;"></td>
      <td><input class="cell-input" type="number" data-field="versorRef" value="${e.versorRef}" data-idx="${i}" style="width:60px;" min="1"></td>
      <td><input class="cell-input" type="number" data-field="csRef" value="${e.csRef}" data-idx="${i}" style="width:60px;" min="1"></td>
      <td><div class="row-actions"><button class="btn btn-icon btn-ghost btn-sm" data-action="delete" data-idx="${i}">✕</button></div></td>
    `;
    tbody.appendChild(tr);
  }

  tbody.querySelectorAll('.cell-input').forEach(input => {
    input.addEventListener('change', () => {
      const idx = parseInt(input.dataset.idx, 10);
      const field = input.dataset.field;
      const elem = p.elements[idx];
      if (!elem) return;
      if (field === 'type') elem.type = input.value;
      else if (field === 'nodeIds') elem.nodeIds = input.value.trim().split(/\s+/).map(v => parseInt(v, 10));
      else if (field === 'versorRef') elem.versorRef = parseInt(input.value, 10) || 1;
      else if (field === 'csRef') elem.csRef = parseInt(input.value, 10) || 1;
      onDataChange();
    });
  });

  tbody.querySelectorAll('[data-action="delete"]').forEach(btn => {
    btn.addEventListener('click', () => {
      p.elements.splice(parseInt(btn.dataset.idx, 10), 1);
      p.elements.forEach((e, i) => e.id = i + 1);
      rebuildConnTable(p);
      onDataChange();
    });
  });
}

// ─── VERSORS EDITOR ───
function buildVersorsEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Coordinate Versors', 'V', 'versors', 'Unit vectors for local coordinate systems referenced by elements.');
  const body = card.querySelector('.editor-card-body');

  body.innerHTML = `
    <div class="data-table-wrapper">
      <table class="data-table">
        <thead><tr><th>#</th><th>vx</th><th>vy</th><th>vz</th><th></th></tr></thead>
        <tbody id="versors-tbody"></tbody>
      </table>
    </div>
    <div style="margin-top:var(--sp-3);"><button class="btn btn-secondary btn-sm" id="btn-add-versor">+ Add Versor</button></div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    rebuildVersorsTable(p);
    document.getElementById('btn-add-versor')?.addEventListener('click', () => {
      p.versors.push({ id: p.versors.length + 1, vx: 0, vy: 0, vz: 1 });
      rebuildVersorsTable(p);
      onDataChange();
    });
  }, 0);
}

function rebuildVersorsTable(p) {
  const tbody = document.getElementById('versors-tbody');
  if (!tbody) return;
  tbody.innerHTML = '';

  for (let i = 0; i < p.versors.length; i++) {
    const v = p.versors[i];
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="row-num">${v.id}</td>
      <td><input class="cell-input" type="number" data-field="vx" value="${v.vx}" data-idx="${i}" step="1" style="width:60px;"></td>
      <td><input class="cell-input" type="number" data-field="vy" value="${v.vy}" data-idx="${i}" step="1" style="width:60px;"></td>
      <td><input class="cell-input" type="number" data-field="vz" value="${v.vz}" data-idx="${i}" step="1" style="width:60px;"></td>
      <td><div class="row-actions"><button class="btn btn-icon btn-ghost btn-sm" data-action="delete" data-idx="${i}">✕</button></div></td>
    `;
    tbody.appendChild(tr);
  }

  tbody.querySelectorAll('.cell-input').forEach(input => {
    input.addEventListener('change', () => {
      const idx = parseInt(input.dataset.idx, 10);
      const field = input.dataset.field;
      if (p.versors[idx]) { p.versors[idx][field] = parseFloat(input.value) || 0; onDataChange(); }
    });
  });

  tbody.querySelectorAll('[data-action="delete"]').forEach(btn => {
    btn.addEventListener('click', () => {
      p.versors.splice(parseInt(btn.dataset.idx, 10), 1);
      p.versors.forEach((v, i) => v.id = i + 1);
      rebuildVersorsTable(p);
      onDataChange();
    });
  });
}

// ─── MATERIAL EDITOR ───
function buildMaterialEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Material Properties', 'M', 'material', `${p.materials.length} material(s) defined.`);
  const body = card.querySelector('.editor-card-body');

  let materialsHtml = '';
  for (let i = 0; i < p.materials.length; i++) {
    const m = p.materials[i];
    if (m.type === 'ISO-M') {
      materialsHtml += `
        <div class="material-card" data-idx="${i}">
          <div class="material-card-header">
            <div class="material-card-number">
              <div class="material-number-badge tag-blue">${m.id}</div>
              <span>Isotropic Material (ISO-M)</span>
            </div>
            <button class="btn btn-ghost btn-sm" data-action="delete-mat" data-idx="${i}">✕</button>
          </div>
          <div class="material-properties">
            <div class="form-group">
              <label class="form-label">Elastic Modulus E</label>
              <input class="form-input" data-field="E" data-midx="${i}" value="${escHtml(m.E)}">
              <div class="form-hint">${m.EVal.toExponential(2)} Pa</div>
            </div>
            <div class="form-group">
              <label class="form-label">Poisson Ratio ν</label>
              <input class="form-input" data-field="nu" data-midx="${i}" value="${escHtml(m.nu)}">
            </div>
            <div class="form-group">
              <label class="form-label">Density ρ</label>
              <input class="form-input" data-field="rho" data-midx="${i}" value="${escHtml(m.rho)}">
              <div class="form-hint">${m.rhoVal} kg/m³</div>
            </div>
          </div>
        </div>
      `;
    } else if (m.type === 'ORT-M') {
      const labels = ['E₁₁', 'E₂₂', 'E₃₃', 'ν₁₂', 'ν₂₃', 'ν₁₃', 'G₁₂', 'G₂₃', 'G₁₃', 'ρ'];
      materialsHtml += `
        <div class="material-card" data-idx="${i}">
          <div class="material-card-header">
            <div class="material-card-number">
              <div class="material-number-badge tag-orange">${m.id}</div>
              <span>Orthotropic Material (ORT-M)</span>
            </div>
            <button class="btn btn-ghost btn-sm" data-action="delete-mat" data-idx="${i}">✕</button>
          </div>
          <div class="material-properties">
            ${m.values.map((v, j) => `
              <div class="form-group">
                <label class="form-label">${labels[j] || 'Param ' + (j + 1)}</label>
                <input class="form-input" data-field="ortval" data-midx="${i}" data-vidx="${j}" value="${escHtml(v)}">
              </div>
            `).join('')}
          </div>
        </div>
      `;
    }
  }

  // Extra rows (Z-EXP, Z-PRM, DAMP)
  if (p.extraRows.length > 0) {
    materialsHtml += `<div class="editor-card-title" style="margin-top:var(--sp-4);margin-bottom:var(--sp-3);font-size:12px;">Additional Data Rows</div>`;
    for (let i = 0; i < p.extraRows.length; i++) {
      const er = p.extraRows[i];
      materialsHtml += `
        <div class="form-group">
          <label class="form-label">${er.keyword} (ID: ${er.id})</label>
          <input class="form-input" data-field="extrarow" data-eidx="${i}" value="${escHtml(er.raw.trim())}">
        </div>
      `;
    }
  }

  body.innerHTML = materialsHtml + `
    <div style="margin-top:var(--sp-3);display:flex;gap:var(--sp-2);">
      <button class="btn btn-secondary btn-sm" id="btn-add-iso">+ ISO Material</button>
      <button class="btn btn-secondary btn-sm" id="btn-add-ort">+ ORT Material</button>
    </div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    // Bind material property inputs
    wrapper.querySelectorAll('[data-field="E"], [data-field="nu"], [data-field="rho"]').forEach(input => {
      input.addEventListener('change', () => {
        const idx = parseInt(input.dataset.midx, 10);
        const m = p.materials[idx];
        if (!m) return;
        const field = input.dataset.field;
        m[field] = input.value;
        if (field === 'E') m.EVal = Fortran.parseFloat(input.value);
        if (field === 'nu') m.nuVal = Fortran.parseFloat(input.value);
        if (field === 'rho') m.rhoVal = Fortran.parseFloat(input.value);
        onDataChange();
      });
    });

    wrapper.querySelectorAll('[data-field="ortval"]').forEach(input => {
      input.addEventListener('change', () => {
        const idx = parseInt(input.dataset.midx, 10);
        const vidx = parseInt(input.dataset.vidx, 10);
        if (p.materials[idx]) { p.materials[idx].values[vidx] = input.value; onDataChange(); }
      });
    });

    wrapper.querySelectorAll('[data-field="extrarow"]').forEach(input => {
      input.addEventListener('change', () => {
        const eidx = parseInt(input.dataset.eidx, 10);
        if (p.extraRows[eidx]) { p.extraRows[eidx].raw = input.value; onDataChange(); }
      });
    });

    wrapper.querySelectorAll('[data-action="delete-mat"]').forEach(btn => {
      btn.addEventListener('click', () => {
        p.materials.splice(parseInt(btn.dataset.idx, 10), 1);
        p.materials.forEach((m, i) => m.id = i + 1);
        renderEditorForFile('MATERIAL.dat');
        onDataChange();
      });
    });

    document.getElementById('btn-add-iso')?.addEventListener('click', () => {
      const newId = p.materials.length + 1;
      p.materials.push({ type: 'ISO-M', id: newId, E: '0.0D9', nu: '0.3', rho: '0.0D0', EVal: 0, nuVal: 0.3, rhoVal: 0 });
      renderEditorForFile('MATERIAL.dat');
      onDataChange();
    });

    document.getElementById('btn-add-ort')?.addEventListener('click', () => {
      const newId = p.materials.length + 1;
      p.materials.push({
        type: 'ORT-M', id: newId,
        values: ['0.0D9', '0.0D9', '0.0D9', '0.3', '0.3', '0.3', '0.0D9', '0.0D9', '0.0D9', '0.0D0'],
        valuesNum: [0, 0, 0, 0.3, 0.3, 0.3, 0, 0, 0, 0]
      });
      renderEditorForFile('MATERIAL.dat');
      onDataChange();
    });
  }, 0);
}

// ─── LAMINATION EDITOR ───
function buildLaminationEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Lamination Definitions', 'L', 'lamination', 'Material rotation angles (sequential: first around x, then around y).');
  const body = card.querySelector('.editor-card-body');

  // Get material IDs for dropdown
  const matIds = state.files['MATERIAL.dat']?.parsed?.materials?.map(m => m.id) || [];

  body.innerHTML = `
    <div class="data-table-wrapper">
      <table class="data-table">
        <thead><tr><th>#</th><th>Material Ref</th><th>Rotation X (°)</th><th>Rotation Y (°)</th><th></th></tr></thead>
        <tbody id="lam-tbody"></tbody>
      </table>
    </div>
    <div style="margin-top:var(--sp-3);"><button class="btn btn-secondary btn-sm" id="btn-add-lam">+ Add Lamination</button></div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    const tbody = document.getElementById('lam-tbody');
    for (let i = 0; i < p.laminations.length; i++) {
      const l = p.laminations[i];
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td class="row-num">${l.id}</td>
        <td>
          <select class="cell-select" data-field="matRef" data-idx="${i}">
            ${matIds.map(mid => `<option value="${mid}" ${mid === l.matRef ? 'selected' : ''}>${mid}</option>`).join('')}
            ${!matIds.includes(l.matRef) ? `<option value="${l.matRef}" selected>${l.matRef} ⚠</option>` : ''}
          </select>
        </td>
        <td><input class="cell-input" data-field="rotX" value="${escHtml(l.rotX)}" data-idx="${i}" style="min-width:100px;"></td>
        <td><input class="cell-input" data-field="rotY" value="${escHtml(l.rotY)}" data-idx="${i}" style="min-width:100px;"></td>
        <td><div class="row-actions"><button class="btn btn-icon btn-ghost btn-sm" data-action="delete" data-idx="${i}">✕</button></div></td>
      `;
      tbody.appendChild(tr);
    }

    tbody.querySelectorAll('.cell-input, .cell-select').forEach(input => {
      input.addEventListener('change', () => {
        const idx = parseInt(input.dataset.idx, 10);
        const field = input.dataset.field;
        const lam = p.laminations[idx];
        if (!lam) return;
        if (field === 'matRef') lam.matRef = parseInt(input.value, 10);
        else if (field === 'rotX') { lam.rotX = input.value; lam.rotXVal = Fortran.parseFloat(input.value); }
        else if (field === 'rotY') { lam.rotY = input.value; lam.rotYVal = Fortran.parseFloat(input.value); }
        onDataChange();
      });
    });

    tbody.querySelectorAll('[data-action="delete"]').forEach(btn => {
      btn.addEventListener('click', () => {
        p.laminations.splice(parseInt(btn.dataset.idx, 10), 1);
        p.laminations.forEach((l, i) => l.id = i + 1);
        renderEditorForFile('LAMINATION.dat');
        onDataChange();
      });
    });

    document.getElementById('btn-add-lam')?.addEventListener('click', () => {
      const newId = p.laminations.length + 1;
      p.laminations.push({ keyword: 'LAM2', id: newId, matRef: 1, rotX: '0.000E+00', rotY: '0.00000000E+00', rotXVal: 0, rotYVal: 0 });
      renderEditorForFile('LAMINATION.dat');
      onDataChange();
    });
  }, 0);
}

// ─── EXP_CONN EDITOR ───
function buildExpConnEditor(wrapper, fdata, fname) {
  const p = fdata.parsed;
  const csNum = fname.match(/\d+/)?.[0] || '01';
  const card = createCard(`Cross-Section Connectivity (${csNum})`, 'EC', 'exp-conn', 'Q9 element connectivity for the cross-section mesh. Node order: spiral from corner inward.');
  const body = card.querySelector('.editor-card-body');

  const lamIds = state.files['LAMINATION.dat']?.parsed?.laminations?.map(l => l.id) || [];

  body.innerHTML = `
    <div class="data-table-wrapper">
      <table class="data-table">
        <thead><tr><th>Type</th><th>#</th><th>Lam. Ref</th><th>Node IDs (spiral order)</th><th title="HLE only: polynomial order p, then optionally the 4 mid-side nodes of curved sides (0 = straight)">HLE order [mid nodes]</th><th></th></tr></thead>
        <tbody id="expconn-tbody"></tbody>
      </table>
    </div>
    <div style="margin-top:var(--sp-3);"><button class="btn btn-secondary btn-sm" id="btn-add-expconn">+ Add Q9</button> <button class="btn btn-secondary btn-sm" id="btn-add-hq4">+ Add HQ4 (HLE)</button> <button class="btn btn-secondary btn-sm" id="btn-add-hb2">+ Add HB2 (HLE)</button></div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    const tbody = document.getElementById('expconn-tbody');
    for (let i = 0; i < p.elements.length; i++) {
      const e = p.elements[i];
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><input class="cell-input" data-field="type" value="${e.type}" data-idx="${i}" style="width:40px;"></td>
        <td class="row-num">${e.id}</td>
        <td>
          <select class="cell-select" data-field="lamRef" data-idx="${i}">
            ${lamIds.map(lid => `<option value="${lid}" ${lid === e.lamRef ? 'selected' : ''}>${lid}</option>`).join('')}
            ${!lamIds.includes(e.lamRef) ? `<option value="${e.lamRef}" selected>${e.lamRef} ⚠</option>` : ''}
          </select>
        </td>
        <td><input class="cell-input" data-field="nodeIds" value="${e.nodeIds.join('  ')}" data-idx="${i}" style="min-width:180px;"></td>
        <td>${Parsers.hleKind(e.type) ? `<input class="cell-input" data-field="hle" value="${[e.order || 1].concat(e.mids && e.mids.some(Boolean) ? e.mids : []).join(' ')}" data-idx="${i}" style="width:110px;">` : ''}</td>
        <td><div class="row-actions"><button class="btn btn-icon btn-ghost btn-sm" data-action="delete" data-idx="${i}">✕</button></div></td>
      `;
      tbody.appendChild(tr);
    }

    tbody.querySelectorAll('.cell-input, .cell-select').forEach(input => {
      input.addEventListener('change', () => {
        const idx = parseInt(input.dataset.idx, 10);
        const field = input.dataset.field;
        const elem = p.elements[idx];
        if (!elem) return;
        if (field === 'type') elem.type = input.value;
        else if (field === 'lamRef') elem.lamRef = parseInt(input.value, 10);
        else if (field === 'nodeIds') elem.nodeIds = input.value.trim().split(/\s+/).map(v => parseInt(v, 10));
        else if (field === 'hle') {
          const v = input.value.trim().split(/\s+/).map(x => parseInt(x, 10)).filter(x => !isNaN(x));
          elem.order = Math.max(1, v[0] || 1);
          elem.mids = v.length >= 5 ? v.slice(1, 5) : null;
        }
        onDataChange();
      });
    });

    tbody.querySelectorAll('[data-action="delete"]').forEach(btn => {
      btn.addEventListener('click', () => {
        p.elements.splice(parseInt(btn.dataset.idx, 10), 1);
        p.elements.forEach((e, i) => e.id = i + 1);
        renderEditorForFile(fname);
        onDataChange();
      });
    });

    document.getElementById('btn-add-expconn')?.addEventListener('click', () => {
      const newId = p.elements.length + 1;
      p.elements.push({ type: 'Q9', id: newId, lamRef: 1, nodeIds: [1, 2, 3, 6, 9, 8, 7, 4, 5] });
      renderEditorForFile(fname);
      onDataChange();
    });
    document.getElementById('btn-add-hq4')?.addEventListener('click', () => {
      const newId = p.elements.length + 1;
      p.elements.push({ type: 'HQ4', id: newId, lamRef: 1, nodeIds: [1, 2, 3, 4], order: 3, mids: null });
      renderEditorForFile(fname);
      onDataChange();
    });
    document.getElementById('btn-add-hb2')?.addEventListener('click', () => {
      const newId = p.elements.length + 1;
      p.elements.push({ type: 'HB2', id: newId, lamRef: 1, nodeIds: [1, 2], order: 3, mids: null });
      renderEditorForFile(fname);
      onDataChange();
    });
  }, 0);
}

// ─── EXP_MESH EDITOR ───
function buildExpMeshEditor(wrapper, fdata, fname) {
  const p = fdata.parsed;
  const csNum = fname.match(/\d+/)?.[0] || '01';

  // 2D cross-section viewport
  const vpDiv = document.createElement('div');
  vpDiv.className = 'inline-viewport';
  vpDiv.style.height = '280px';
  vpDiv.innerHTML = `
    <canvas id="csmesh-viewport-canvas"></canvas>
    <div class="viewport-overlay-info">Cross-section (X-Z plane)</div>
  `;
  wrapper.appendChild(vpDiv);

  const card = createCard(`Cross-Section Mesh (${csNum})`, 'EM', 'exp-mesh', `${p.nodes.length} nodes. Defines cross-section geometry in the X-Z plane.`);
  const body = card.querySelector('.editor-card-body');

  body.innerHTML = `
    <div class="data-table-wrapper">
      <table class="data-table">
        <thead><tr><th>#</th><th>X</th><th>Y</th><th>Z</th><th></th></tr></thead>
        <tbody id="expmesh-tbody"></tbody>
      </table>
    </div>
    <div style="margin-top:var(--sp-3);"><button class="btn btn-secondary btn-sm" id="btn-add-meshnode">+ Add Node</button></div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    const tbody = document.getElementById('expmesh-tbody');
    for (let i = 0; i < p.nodes.length; i++) {
      const n = p.nodes[i];
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td class="row-num">${n.id}</td>
        <td><input class="cell-input" data-field="x" value="${escHtml(n.x)}" data-idx="${i}"></td>
        <td><input class="cell-input" data-field="y" value="${escHtml(n.y)}" data-idx="${i}"></td>
        <td><input class="cell-input" data-field="z" value="${escHtml(n.z)}" data-idx="${i}"></td>
        <td><div class="row-actions"><button class="btn btn-icon btn-ghost btn-sm" data-action="delete" data-idx="${i}">✕</button></div></td>
      `;
      tbody.appendChild(tr);
    }

    tbody.querySelectorAll('.cell-input').forEach(input => {
      input.addEventListener('change', () => {
        const idx = parseInt(input.dataset.idx, 10);
        const field = input.dataset.field;
        const node = p.nodes[idx];
        if (!node) return;
        node[field] = input.value;
        node[field + 'Val'] = Fortran.parseFloat(input.value);
        onDataChange();
        // Re-render 2D viewport
        const canvas = document.getElementById('csmesh-viewport-canvas');
        const connFname = 'EXP_CONN_' + csNum + '.dat';
        if (canvas) renderCrossSection2D(canvas, p, state.files[connFname]?.parsed);
      });
    });

    tbody.querySelectorAll('[data-action="delete"]').forEach(btn => {
      btn.addEventListener('click', () => {
        p.nodes.splice(parseInt(btn.dataset.idx, 10), 1);
        p.nodes.forEach((n, i) => n.id = i + 1);
        renderEditorForFile(fname);
        onDataChange();
      });
    });

    document.getElementById('btn-add-meshnode')?.addEventListener('click', () => {
      const newId = p.nodes.length + 1;
      p.nodes.push({ id: newId, x: '0.0D0', y: '0.0D0', z: '0.0D0', xVal: 0, yVal: 0, zVal: 0 });
      renderEditorForFile(fname);
      onDataChange();
    });

    // Render 2D cross-section
    const canvas = document.getElementById('csmesh-viewport-canvas');
    const connFname = 'EXP_CONN_' + csNum + '.dat';
    if (canvas) renderCrossSection2D(canvas, p, state.files[connFname]?.parsed);
  }, 0);
}

// ─── BC EDITOR ───
function buildBCEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Boundary Conditions', 'B', 'bc', `${p.conditions.length} boundary condition(s). Includes displacement constraints and applied forces.`);
  const body = card.querySelector('.editor-card-body');

  let bcHtml = '';
  for (let i = 0; i < p.conditions.length; i++) {
    const c = p.conditions[i];
    if (c.type === 'D-PLANE') {
      bcHtml += `
        <div class="material-card" data-idx="${i}">
          <div class="material-card-header">
            <div class="material-card-number">
              <div class="bc-type-icon clamp">⟂</div>
              <span>D-PLANE #${c.id}</span>
              <span class="tag tag-red">Displacement Plane</span>
            </div>
            <button class="btn btn-ghost btn-sm" data-action="delete-bc" data-idx="${i}">✕</button>
          </div>
          <div class="material-properties">
            <div class="form-group">
              <label class="form-label">A (plane eq.)</label>
              <input class="form-input" data-field="A" data-bidx="${i}" value="${c.A}" type="number" step="1">
            </div>
            <div class="form-group">
              <label class="form-label">B</label>
              <input class="form-input" data-field="B" data-bidx="${i}" value="${c.B}" type="number" step="1">
            </div>
            <div class="form-group">
              <label class="form-label">C</label>
              <input class="form-input" data-field="C" data-bidx="${i}" value="${c.C}" type="number" step="1">
            </div>
            <div class="form-group">
              <label class="form-label">D</label>
              <input class="form-input" data-field="D" data-bidx="${i}" value="${c.D}" type="number" step="any">
            </div>
            <div class="form-group">
              <label class="form-label">uₓ (or N)</label>
              <input class="form-input" data-field="ux" data-bidx="${i}" value="${escHtml(c.ux)}">
              <div class="form-hint">Use N for unconstrained</div>
            </div>
            <div class="form-group">
              <label class="form-label">u_y (or N)</label>
              <input class="form-input" data-field="uy" data-bidx="${i}" value="${escHtml(c.uy)}">
            </div>
            <div class="form-group">
              <label class="form-label">u_z (or N)</label>
              <input class="form-input" data-field="uz" data-bidx="${i}" value="${escHtml(c.uz)}">
            </div>
          </div>
          <div class="form-hint" style="margin-top:var(--sp-2);">Plane equation: ${c.A}x + ${c.B}y + ${c.C}z + ${c.D} = 0</div>
        </div>
      `;
    } else if (c.type === 'D-POINT') {
      bcHtml += `
        <div class="material-card" data-idx="${i}">
          <div class="material-card-header">
            <div class="material-card-number">
              <div class="bc-type-icon clamp">⊙</div>
              <span>D-POINT #${c.id}</span>
              <span class="tag tag-red">Displacement Point</span>
            </div>
            <button class="btn btn-ghost btn-sm" data-action="delete-bc" data-idx="${i}">✕</button>
          </div>
          <div class="material-properties">
            <div class="form-group"><label class="form-label">X</label><input class="form-input" data-field="x" data-bidx="${i}" value="${escHtml(c.x)}"></div>
            <div class="form-group"><label class="form-label">Y</label><input class="form-input" data-field="y" data-bidx="${i}" value="${escHtml(c.y)}"></div>
            <div class="form-group"><label class="form-label">Z</label><input class="form-input" data-field="z" data-bidx="${i}" value="${escHtml(c.z)}"></div>
            <div class="form-group"><label class="form-label">uₓ (or N)</label><input class="form-input" data-field="ux" data-bidx="${i}" value="${escHtml(c.ux)}"></div>
            <div class="form-group"><label class="form-label">u_y (or N)</label><input class="form-input" data-field="uy" data-bidx="${i}" value="${escHtml(c.uy)}"></div>
            <div class="form-group"><label class="form-label">u_z (or N)</label><input class="form-input" data-field="uz" data-bidx="${i}" value="${escHtml(c.uz)}"></div>
          </div>
        </div>
      `;
    } else if (c.type === 'F-POINT') {
      bcHtml += `
        <div class="material-card" data-idx="${i}">
          <div class="material-card-header">
            <div class="material-card-number">
              <div class="bc-type-icon force">→</div>
              <span>F-POINT #${c.id}</span>
              <span class="tag tag-green">Force Point</span>
            </div>
            <button class="btn btn-ghost btn-sm" data-action="delete-bc" data-idx="${i}">✕</button>
          </div>
          <div class="material-properties">
            <div class="form-group"><label class="form-label">X</label><input class="form-input" data-field="x" data-bidx="${i}" value="${escHtml(c.x)}"></div>
            <div class="form-group"><label class="form-label">Y</label><input class="form-input" data-field="y" data-bidx="${i}" value="${escHtml(c.y)}"></div>
            <div class="form-group"><label class="form-label">Z</label><input class="form-input" data-field="z" data-bidx="${i}" value="${escHtml(c.z)}"></div>
            <div class="form-group"><label class="form-label">Fₓ</label><input class="form-input" data-field="fx" data-bidx="${i}" value="${escHtml(c.fx)}"></div>
            <div class="form-group"><label class="form-label">F_y</label><input class="form-input" data-field="fy" data-bidx="${i}" value="${escHtml(c.fy)}"></div>
            <div class="form-group"><label class="form-label">F_z</label><input class="form-input" data-field="fz" data-bidx="${i}" value="${escHtml(c.fz)}"></div>
          </div>
        </div>
      `;
    }
  }

  body.innerHTML = bcHtml + `
    <div style="margin-top:var(--sp-3);display:flex;gap:var(--sp-2);flex-wrap:wrap;">
      <button class="btn btn-secondary btn-sm" id="btn-add-dplane">+ D-PLANE</button>
      <button class="btn btn-secondary btn-sm" id="btn-add-dpoint">+ D-POINT</button>
      <button class="btn btn-secondary btn-sm" id="btn-add-fpoint">+ F-POINT</button>
    </div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    wrapper.querySelectorAll('.form-input[data-bidx]').forEach(input => {
      input.addEventListener('change', () => {
        const idx = parseInt(input.dataset.bidx, 10);
        const field = input.dataset.field;
        const c = p.conditions[idx];
        if (!c) return;
        if (['A', 'B', 'C', 'D'].includes(field)) c[field] = parseFloat(input.value) || 0;
        else c[field] = input.value;
        onDataChange();
      });
    });

    wrapper.querySelectorAll('[data-action="delete-bc"]').forEach(btn => {
      btn.addEventListener('click', () => {
        p.conditions.splice(parseInt(btn.dataset.idx, 10), 1);
        p.conditions.forEach((c, i) => c.id = i + 1);
        renderEditorForFile('BC.dat');
        onDataChange();
      });
    });

    const addBC = (type, defaults) => {
      const newId = p.conditions.length + 1;
      p.conditions.push({ type, id: newId, ...defaults });
      renderEditorForFile('BC.dat');
      onDataChange();
    };

    document.getElementById('btn-add-dplane')?.addEventListener('click', () => addBC('D-PLANE', { A: 0, B: 1, C: 0, D: 0, ux: '0.0', uy: '0.0', uz: '0.0' }));
    document.getElementById('btn-add-dpoint')?.addEventListener('click', () => addBC('D-POINT', { x: '0.0D0', y: '0.0D0', z: '0.0D0', ux: '0.0', uy: '0.0', uz: '0.0' }));
    document.getElementById('btn-add-fpoint')?.addEventListener('click', () => addBC('F-POINT', { x: '0.0D0', y: '0.0D0', z: '0.0D0', fx: '0.0D0', fy: '0.0D0', fz: '0.0D0' }));
  }, 0);
}

// ─── POSTPROCESSING EDITOR ───
function buildPostprocessingEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Post-Processing', 'P', 'postproc', `${p.entries.length} entries. Configure Paraview output and evaluation points.`);
  const body = card.querySelector('.editor-card-body');

  let ppHtml = '';
  for (let i = 0; i < p.entries.length; i++) {
    const e = p.entries[i];
    if (e.type === 'PARA') {
      ppHtml += `
        <div class="material-card" data-idx="${i}">
          <div class="material-card-header">
            <div class="material-card-number">
              <div class="material-number-badge tag-cyan">P</div>
              <span>PARA — Paraview Output</span>
            </div>
            <button class="btn btn-ghost btn-sm" data-action="delete-pp" data-idx="${i}">✕</button>
          </div>
          <div class="material-properties">
            <div class="form-group">
              <label class="form-label">Nodes per Element</label>
              <input class="form-input" type="number" data-field="numNodes" data-pidx="${i}" value="${e.numNodes}" min="1">
              <div class="form-hint">e.g. 20 for quadratic brick</div>
            </div>
            <div class="form-group">
              <label class="form-label">Reference System</label>
              <div class="radio-group" data-pidx="${i}" data-field="refSystem">
                <div class="radio-option ${e.refSystem === 'GLB' ? 'active' : ''}" data-value="GLB">GLB</div>
                <div class="radio-option ${e.refSystem === 'LOC' ? 'active' : ''}" data-value="LOC">LOC</div>
              </div>
              <div class="form-hint">GLB = global, LOC = local (may lose accuracy with high-order kinematics)</div>
            </div>
            <div class="form-group" style="grid-column:1/-1;">
              <label class="form-label">Subdivisions</label>
              <input class="form-input" data-field="subdivisions" data-pidx="${i}" value="${e.subdivisions.join('  ')}">
              <div class="form-hint">Space-separated subdivision counts for each direction</div>
            </div>
          </div>
        </div>
      `;
    } else if (e.type === 'PNT') {
      ppHtml += `
        <div class="material-card" data-idx="${i}">
          <div class="material-card-header">
            <div class="material-card-number">
              <div class="material-number-badge tag-cyan">◇</div>
              <span>PNT #${e.id} — Evaluation Point</span>
            </div>
            <button class="btn btn-ghost btn-sm" data-action="delete-pp" data-idx="${i}">✕</button>
          </div>
          <div class="material-properties">
            <div class="form-group"><label class="form-label">X</label><input class="form-input" data-field="x" data-pidx="${i}" value="${escHtml(e.x)}"></div>
            <div class="form-group"><label class="form-label">Y</label><input class="form-input" data-field="y" data-pidx="${i}" value="${escHtml(e.y)}"></div>
            <div class="form-group"><label class="form-label">Z</label><input class="form-input" data-field="z" data-pidx="${i}" value="${escHtml(e.z)}"></div>
          </div>
          <div class="form-hint" style="margin-top:var(--sp-2);">⚠ Avoid placing points exactly on the body boundary (use slight offsets)</div>
        </div>
      `;
    }
  }

  body.innerHTML = ppHtml + `
    <div style="margin-top:var(--sp-3);display:flex;gap:var(--sp-2);">
      <button class="btn btn-secondary btn-sm" id="btn-add-para">+ PARA Entry</button>
      <button class="btn btn-secondary btn-sm" id="btn-add-pnt">+ PNT Entry</button>
    </div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    wrapper.querySelectorAll('.form-input[data-pidx]').forEach(input => {
      input.addEventListener('change', () => {
        const idx = parseInt(input.dataset.pidx, 10);
        const field = input.dataset.field;
        const e = p.entries[idx];
        if (!e) return;
        if (field === 'numNodes') e.numNodes = parseInt(input.value, 10) || 20;
        else if (field === 'subdivisions') e.subdivisions = input.value.trim().split(/\s+/).map(v => parseInt(v, 10) || 1);
        else if (['x', 'y', 'z'].includes(field)) {
          e[field] = input.value;
          e[field + 'Val'] = Fortran.parseFloat(input.value);
        }
        onDataChange();
      });
    });

    wrapper.querySelectorAll('.radio-group[data-pidx]').forEach(group => {
      group.querySelectorAll('.radio-option').forEach(opt => {
        opt.addEventListener('click', () => {
          const idx = parseInt(group.dataset.pidx, 10);
          group.querySelectorAll('.radio-option').forEach(o => o.classList.remove('active'));
          opt.classList.add('active');
          p.entries[idx].refSystem = opt.dataset.value;
          onDataChange();
        });
      });
    });

    wrapper.querySelectorAll('[data-action="delete-pp"]').forEach(btn => {
      btn.addEventListener('click', () => {
        p.entries.splice(parseInt(btn.dataset.idx, 10), 1);
        // Re-number PNTs
        let pntNum = 1;
        for (const e of p.entries) { if (e.type === 'PNT') e.id = pntNum++; }
        renderEditorForFile('POSTPROCESSING.dat');
        onDataChange();
      });
    });

    document.getElementById('btn-add-para')?.addEventListener('click', () => {
      p.entries.push({ type: 'PARA', numNodes: 20, refSystem: 'GLB', subdivisions: [1, 1, 1, 1, 1, 1, 1, 1, 1] });
      renderEditorForFile('POSTPROCESSING.dat');
      onDataChange();
    });

    document.getElementById('btn-add-pnt')?.addEventListener('click', () => {
      const pntCount = p.entries.filter(e => e.type === 'PNT').length;
      p.entries.push({ type: 'PNT', id: pntCount + 1, x: '0.0D0', y: '0.0D0', z: '0.0D0', xVal: 0, yVal: 0, zVal: 0 });
      renderEditorForFile('POSTPROCESSING.dat');
      onDataChange();
    });
  }, 0);
}

// ─── FIELDS EDITOR ───
function buildFieldsEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Field Definitions', 'F', 'fields', `${p.fields.length} field(s). Define spatial/temporal distributions.`);
  const body = card.querySelector('.editor-card-body');

  let fieldsHtml = '';
  const fieldTypes = FIELD_TYPES;
  for (let i = 0; i < p.fields.length; i++) {
    const f = p.fields[i];
    fieldsHtml += `
      <div class="material-card" data-idx="${i}">
        <div class="material-card-header">
          <div class="material-card-number">
            <div class="material-number-badge tag-green">${f.id}</div>
            <span>Field ${f.id} (Sub-ID: ${f.subId})</span>
          </div>
          <button class="btn btn-ghost btn-sm" data-action="delete-field" data-idx="${i}">✕</button>
        </div>
        <div class="material-properties">
          <div class="form-group">
            <label class="form-label">Field ID</label>
            <input class="form-input" type="number" data-field="id" data-fidx="${i}" value="${f.id}" min="1">
          </div>
          <div class="form-group">
            <label class="form-label">Sub ID</label>
            <input class="form-input" type="number" data-field="subId" data-fidx="${i}" value="${f.subId}" min="1">
          </div>
          <div class="form-group">
            <label class="form-label">Type</label>
            <select class="form-select" data-field="defType" data-fidx="${i}">
              ${fieldTypes.map(t => `<option value="${t}" ${f.definition?.type === t ? 'selected' : ''}>${t}</option>`).join('')}
            </select>
          </div>
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">Parameters</label>
            <input class="form-input" data-field="defParams" data-fidx="${i}" value="${f.definition ? f.definition.params.join('  ') : ''}">
            <div class="form-hint">${getFieldHint(f.definition?.type)}</div>
          </div>
        </div>
      </div>
    `;
  }

  body.innerHTML = fieldsHtml + `
    <div style="margin-top:var(--sp-3);">
      <button class="btn btn-secondary btn-sm" id="btn-add-field">+ Add Field</button>
    </div>
  `;

  wrapper.appendChild(card);

  setTimeout(() => {
    wrapper.querySelectorAll('.form-input[data-fidx], .form-select[data-fidx]').forEach(input => {
      input.addEventListener('change', () => {
        const idx = parseInt(input.dataset.fidx, 10);
        const field = input.dataset.field;
        const f = p.fields[idx];
        if (!f) return;
        if (field === 'id') f.id = parseInt(input.value, 10) || 1;
        else if (field === 'subId') f.subId = parseInt(input.value, 10) || 1;
        else if (field === 'defType') {
          if (!f.definition) f.definition = { type: input.value, params: [] };
          else f.definition.type = input.value;
        } else if (field === 'defParams') {
          if (!f.definition) f.definition = { type: 'CONST', params: [] };
          f.definition.params = input.value.trim().split(/\s+/);
        }
        onDataChange();
      });
    });

    wrapper.querySelectorAll('[data-action="delete-field"]').forEach(btn => {
      btn.addEventListener('click', () => {
        p.fields.splice(parseInt(btn.dataset.idx, 10), 1);
        renderEditorForFile('FIELDS.dat');
        onDataChange();
      });
    });

    document.getElementById('btn-add-field')?.addEventListener('click', () => {
      const newId = p.fields.length + 1;
      p.fields.push({ id: newId, subId: 1, definition: { type: 'CONST', params: ['0.0D0'] } });
      renderEditorForFile('FIELDS.dat');
      onDataChange();
    });
  }, 0);
}

function buildTimeResponseEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Time Response', 'T', 'analysis', 'Newmark time interval, output cadence and load histories.');
  const body = card.querySelector('.editor-card-body');
  body.innerHTML = `
    <div class="material-properties">
      <div class="form-group"><label class="form-label">Initial time</label><input class="form-input" data-time-field="ti" value="${escHtml(p.ti)}"></div>
      <div class="form-group"><label class="form-label">Final time</label><input class="form-input" data-time-field="tf" value="${escHtml(p.tf)}"></div>
      <div class="form-group"><label class="form-label">Time steps</label><input class="form-input" type="number" min="1" data-time-field="nstep" value="${p.nstep}"></div>
      <div class="form-group"><label class="form-label">Post every N steps</label><input class="form-input" type="number" min="1" data-time-field="postEvery" value="${p.postEvery}"></div>
      <div class="form-group" style="grid-column:1/-1"><label class="form-label">Specific output times</label><input class="form-input" data-time-field="specificTimes" value="${escHtml(p.specificTimes.join('  '))}"><div class="form-hint">Space-separated; the count is generated automatically.</div></div>
    </div>
    <div class="data-table-wrapper" style="margin-top:var(--sp-4)">
      <table class="data-table"><thead><tr><th>Load</th><th>Parameters</th><th></th></tr></thead><tbody id="time-loads-body"></tbody></table>
    </div>
    <div style="margin-top:var(--sp-3)"><button class="btn btn-secondary btn-sm" id="btn-add-time-load">+ Add time load</button></div>`;
  wrapper.appendChild(card);

  const renderLoads = () => {
    const tbody = wrapper.querySelector('#time-loads-body');
    tbody.innerHTML = '';
    p.loads.forEach((load, i) => {
      const tr = document.createElement('tr');
      const types = ['STEP', 'IMPU', 'RAMP', 'SINU', 'HASU', 'HACU', 'WPSU'];
      tr.innerHTML = `<td><select class="cell-select" data-load-type="${i}">${types.map(type => `<option ${type === load.type ? 'selected' : ''}>${type}</option>`).join('')}</select></td>
        <td><input class="cell-input" data-load-params="${i}" value="${escHtml(load.params.join('  '))}" style="min-width:320px"></td>
        <td><button class="btn btn-ghost btn-sm" data-delete-load="${i}">✕</button></td>`;
      tbody.appendChild(tr);
    });
    tbody.querySelectorAll('[data-load-type]').forEach(el => el.addEventListener('change', () => { p.loads[+el.dataset.loadType].type = el.value; onDataChange(); }));
    tbody.querySelectorAll('[data-load-params]').forEach(el => el.addEventListener('change', () => { p.loads[+el.dataset.loadParams].params = el.value.trim().split(/\s+/).filter(Boolean); onDataChange(); }));
    tbody.querySelectorAll('[data-delete-load]').forEach(el => el.addEventListener('click', () => { p.loads.splice(+el.dataset.deleteLoad, 1); renderLoads(); onDataChange(); }));
  };
  renderLoads();
  body.querySelectorAll('[data-time-field]').forEach(el => el.addEventListener('change', () => {
    const key = el.dataset.timeField;
    if (key === 'specificTimes') p.specificTimes = el.value.trim().split(/\s+/).filter(Boolean);
    else if (key === 'nstep' || key === 'postEvery') p[key] = Math.max(1, parseInt(el.value, 10) || 1);
    else p[key] = el.value;
    onDataChange();
  }));
  body.querySelector('#btn-add-time-load').addEventListener('click', () => { p.loads.push({ type: 'STEP', params: ['0.0D0', '1.0D0'] }); renderLoads(); onDataChange(); });
}

function buildFrequencyResponseEditor(wrapper, fdata) {
  const p = fdata.parsed;
  const card = createCard('Frequency Response', 'ω', 'analysis', 'Frequency sweep and result output cadence.');
  const body = card.querySelector('.editor-card-body');
  body.innerHTML = `<div class="material-properties">
    <div class="form-group"><label class="form-label">Initial frequency</label><input class="form-input" data-freq-field="fi" value="${escHtml(p.fi)}"></div>
    <div class="form-group"><label class="form-label">Final frequency</label><input class="form-input" data-freq-field="ff" value="${escHtml(p.ff)}"></div>
    <div class="form-group"><label class="form-label">Frequency steps</label><input class="form-input" type="number" min="1" data-freq-field="steps" value="${p.steps}"></div>
    <div class="form-group"><label class="form-label">Post every N steps</label><input class="form-input" type="number" min="1" data-freq-field="postEvery" value="${p.postEvery}"></div>
  </div>`;
  wrapper.appendChild(card);
  body.querySelectorAll('[data-freq-field]').forEach(el => el.addEventListener('change', () => {
    const key = el.dataset.freqField;
    p[key] = key === 'steps' || key === 'postEvery' ? Math.max(1, parseInt(el.value, 10) || 1) : el.value;
    onDataChange();
  }));
}

function buildGenericEditor(wrapper, fdata, fname) {
  const card = createCard(fname, '?', 'analysis', 'Lossless text editor for a solver input without a dedicated visual form.');
  const body = card.querySelector('.editor-card-body');
  body.innerHTML = `<div class="validation-msg info" style="margin-bottom:var(--sp-3)">This file is preserved exactly. Editing here updates the project and the solver run.</div>
    <textarea class="generic-file-editor" spellcheck="false">${escHtml(fdata.parsed.raw || '')}</textarea>`;
  wrapper.appendChild(card);
  body.querySelector('textarea').addEventListener('input', e => { fdata.parsed.raw = e.target.value; fdata.raw = e.target.value; History.recordChange(false); });
}

function getFieldHint(type) {
  const hints = {
    'CONST': 'Single constant value',
    'X-EXP': 'Amplitude, wavenumber, phase',
    'SIN-Y': 'Amplitude, wavenumber, phase',
    'COS-Y': 'Amplitude, wavenumber, phase',
    'SIN-X': 'Amplitude, wavenumber, phase',
    'COS-X': 'Amplitude, wavenumber, phase',
    'LIN-X': 'Slope, offset',
    'LIN-Y': 'Slope, offset'
  };
  return hints[type] || 'Space-separated parameters';
}

// ──────────────────────────────────────────────
//  HELPERS
// ──────────────────────────────────────────────
function createCard(title, iconText, iconClass, description) {
  const card = document.createElement('div');
  card.className = 'editor-card';
  card.innerHTML = `
    <div class="editor-card-header">
      <div>
        <div class="editor-card-title">
          <span class="icon file-card-icon ${iconClass}" style="width:24px;height:24px;font-size:11px;">${iconText}</span>
          ${title}
        </div>
        ${description ? `<div class="editor-card-description">${description}</div>` : ''}
      </div>
    </div>
    <div class="editor-card-body"></div>
  `;
  return card;
}

function escHtml(s) {
  if (s === null || s === undefined) return '';
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// ──────────────────────────────────────────────
//  UNDO / REDO HISTORY SYSTEM
// ──────────────────────────────────────────────
const History = {
  undoStack: [],
  redoStack: [],
  maxHistory: 80,
  _debounceTimer: null,
  _baselineState: null,

  _createSnapshot() {
    return {
      activeFile: state.activeFile,
      files: JSON.parse(JSON.stringify(state.files))
    };
  },

  init() {
    this._baselineState = this._createSnapshot();
    this.undoStack = [];
    this.redoStack = [];
    this.updateUI();
  },

  recordChange(immediate = false) {
    if (!this._baselineState) {
      this._baselineState = this._createSnapshot();
    }

    if (immediate) {
      if (this._debounceTimer) {
        clearTimeout(this._debounceTimer);
        this._debounceTimer = null;
      }
      this.undoStack.push(this._baselineState);
      if (this.undoStack.length > this.maxHistory) this.undoStack.shift();
      this.redoStack = [];
      this._baselineState = this._createSnapshot();
      this.updateUI();
    } else {
      if (!this._debounceTimer) {
        this.undoStack.push(this._baselineState);
        if (this.undoStack.length > this.maxHistory) this.undoStack.shift();
        this.redoStack = [];
        this.updateUI();
      }
      clearTimeout(this._debounceTimer);
      this._debounceTimer = setTimeout(() => {
        this._debounceTimer = null;
        this._baselineState = this._createSnapshot();
      }, 400);
    }
  },

  undo() {
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer);
      this._debounceTimer = null;
    }
    if (this.undoStack.length === 0) {
      showToast('Nothing to undo', 'info');
      return;
    }

    const current = this._createSnapshot();
    this.redoStack.push(current);

    const previous = this.undoStack.pop();
    this._baselineState = JSON.parse(JSON.stringify(previous));

    this._applySnapshot(previous);
    this.updateUI();
    showToast('Undo (Ctrl+Z)', 'info');
  },

  redo() {
    if (this.redoStack.length === 0) {
      showToast('Nothing to redo', 'info');
      return;
    }

    const current = this._createSnapshot();
    this.undoStack.push(current);

    const next = this.redoStack.pop();
    this._baselineState = JSON.parse(JSON.stringify(next));

    this._applySnapshot(next);
    this.updateUI();
    showToast('Redo (Ctrl+Y)', 'info');
  },

  _applySnapshot(snap) {
    state.files = JSON.parse(JSON.stringify(snap.files));
    const fileCount = Object.keys(state.files).length;
    updateActionButtonsState();

    if (fileCount === 0) {
      state.activeFile = null;
      const editorPanel = document.getElementById('editor-panel');
      const rawPanel = document.getElementById('raw-panel');
      const splitPanel = document.getElementById('split-panel');
      const panel3D = document.getElementById('panel-3d');
      if (editorPanel) editorPanel.style.display = 'none';
      if (rawPanel) rawPanel.style.display = 'none';
      if (splitPanel) splitPanel.style.display = 'none';
      if (panel3D) panel3D.style.display = 'none';

      const welcome = document.getElementById('welcome-screen');
      if (welcome) welcome.style.display = '';
      const headerTitle = document.getElementById('main-header-title');
      if (headerTitle) headerTitle.innerHTML = `<span>CUF Preprocessor Tool</span>`;
      renderSidebar();
      return;
    }

    if (snap.activeFile && state.files[snap.activeFile]) {
      state.activeFile = snap.activeFile;
    } else {
      state.activeFile = Object.keys(state.files)[0];
    }

    renderSidebar();
    if (state.activeFile) {
      selectFile(state.activeFile);
    }
    if (window.beamRenderer) window.beamRenderer.render();
    if (state.activeView === '3d') update3DMetrics();
  },

  updateUI() {
    const btnUndo = document.getElementById('btn-undo');
    const btnRedo = document.getElementById('btn-redo');
    if (btnUndo) btnUndo.disabled = this.undoStack.length === 0;
    if (btnRedo) btnRedo.disabled = this.redoStack.length === 0;
  }
};

window.History = History;

function updateActionButtonsState() {
  const hasFiles = Object.keys(state.files).length > 0;
  const btnExport = document.getElementById('btn-export-all');
  const btnClear = document.getElementById('btn-clear-all');
  const btnHeaderClear = document.getElementById('btn-header-clear');
  const btnSave = document.getElementById('btn-save-project');
  if (btnExport) btnExport.disabled = !hasFiles;
  if (btnClear) btnClear.disabled = !hasFiles;
  if (btnHeaderClear) btnHeaderClear.disabled = !hasFiles;
  if (btnSave) btnSave.disabled = !hasFiles;
}

function onDataChange(immediate = false) {
  History.recordChange(immediate);

  // Update raw view
  if (state.activeFile) {
    updateRawView(state.activeFile);
  }
  // Re-render sidebar counts and validation
  renderSidebar();
  // Re-render 3D if available
  if (window.beamRenderer) window.beamRenderer.render();
  if (state.activeView === '3d') update3DMetrics();
}

// ──────────────────────────────────────────────
//  FILE I/O
// ──────────────────────────────────────────────
function loadFiles(fileList) {
  let loadedCount = 0;
  for (const file of fileList) {
    const reader = new FileReader();
    reader.onload = (e) => {
      const raw = e.target.result;
      const fname = file.name;
      const parsed = parseFile(fname, raw);
      state.files[fname] = { raw, parsed };
      loadedCount++;
      if (loadedCount === fileList.length) {
        renderSidebar();
        // Select first file
        if (!state.activeFile && Object.keys(state.files).length > 0) {
          selectFile(Object.keys(state.files).sort((a, b) => {
            const aO = FILE_ORDER.findIndex(f => a.startsWith(f.replace('.dat', '')));
            const bO = FILE_ORDER.findIndex(f => b.startsWith(f.replace('.dat', '')));
            return (aO === -1 ? 999 : aO) - (bO === -1 ? 999 : bO);
          })[0]);
        }
        History.init();
        showToast(`Loaded ${loadedCount} file(s)`, 'success');
        updateActionButtonsState();
      }
    };
    reader.readAsText(file);
  }
}

async function openProjectFolder() {
  if (typeof window.showDirectoryPicker !== 'function') {
    showToast('Folder access requires Edge/Chrome over localhost. Use Load for individual files.', 'warning');
    return;
  }
  try {
    const handle = await window.showDirectoryPicker({ mode: 'readwrite', startIn: 'documents' });
    const loaded = {};
    for await (const [name, entry] of handle.entries()) {
      if (entry.kind !== 'file' || !/\.dat$/i.test(name)) continue;
      const file = await entry.getFile();
      const raw = await file.text();
      loaded[name] = { raw, parsed: parseFile(name, raw), dirty: false };
    }
    if (!Object.keys(loaded).length) {
      showToast('No .dat input files found in the selected folder.', 'warning');
      return;
    }
    state.files = loaded;
    state.projectDirectory = handle;
    state.projectName = handle.name;
    state.activeFile = null;
    renderSidebar();
    selectFile(Object.keys(loaded).sort(sortInputFileNames)[0]);
    History.init();
    updateActionButtonsState();
    showToast(`Opened ${Object.keys(loaded).length} files from ${handle.name}`, 'success');
  } catch (error) {
    if (error.name !== 'AbortError') showToast(`Could not open folder: ${error.message}`, 'error');
  }
}

function sortInputFileNames(a, b) {
  const order = name => {
    const index = FILE_ORDER.findIndex(item => name.startsWith(item.replace('.dat', '')));
    return index < 0 ? 999 : index;
  };
  return order(a) - order(b) || a.localeCompare(b);
}

async function saveProjectFolder() {
  if (typeof window.showDirectoryPicker !== 'function') {
    exportAllFiles();
    return;
  }
  try {
    let handle = state.projectDirectory;
    if (!handle) handle = await window.showDirectoryPicker({ mode: 'readwrite', startIn: 'documents' });
    if (handle.requestPermission && await handle.requestPermission({ mode: 'readwrite' }) !== 'granted') return;
    for (const [name, fdata] of Object.entries(state.files)) {
      const fileHandle = await handle.getFileHandle(name, { create: true });
      const writable = await fileHandle.createWritable();
      await writable.write(generateFileText(name, fdata.parsed).replace(/\t/g, '  '));
      await writable.close();
      fdata.dirty = false;
    }
    state.projectDirectory = handle;
    state.projectName = handle.name;
    showToast(`Saved ${Object.keys(state.files).length} files to ${handle.name}`, 'success');
  } catch (error) {
    if (error.name !== 'AbortError') showToast(`Save failed: ${error.message}`, 'error');
  }
}

async function checkServerAvailability() {
  const status = document.getElementById('server-status');
  const runButton = document.getElementById('btn-run-solver');
  try {
    const response = await fetch('/api/ping', { cache: 'no-store' });
    if (!response.ok) throw new Error('not available');
    const info = await response.json();
    state.serverAvailable = true;
    if (status) { status.className = 'server-status online'; status.textContent = `Runner connected · ${info.executable || 'MUL2_V3.exe'}`; }
    if (runButton) runButton.disabled = Object.keys(state.files).length === 0;
  } catch (_) {
    state.serverAvailable = false;
    if (status) { status.className = 'server-status offline'; status.textContent = 'Local runner not connected'; }
    if (runButton) runButton.disabled = true;
  }
}

async function runSolver() {
  if (!state.serverAvailable) return;
  const validationErrors = validateAll().filter(item => item.type === 'error');
  if (validationErrors.length && !confirm(`Validation found ${validationErrors.length} error(s). Run anyway?`)) return;
  const button = document.getElementById('btn-run-solver');
  const consoleEl = document.getElementById('run-console');
  button.disabled = true;
  consoleEl.textContent = 'Preparing isolated run...';
  try {
    const files = {};
    for (const [name, fdata] of Object.entries(state.files)) files[name] = generateFileText(name, fdata.parsed);
    const response = await fetch('/api/run', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ projectName: state.projectName || 'MUL2_Project', files }) });
    const job = await response.json();
    if (!response.ok) throw new Error(job.error || 'Run request failed');
    state.runJob = job;
    renderRunStatus(job);
    if (state.runPollTimer) clearInterval(state.runPollTimer);
    state.runPollTimer = setInterval(refreshRunStatus, 1000);
  } catch (error) {
    consoleEl.textContent = error.message;
    button.disabled = false;
    showToast(`Solver run failed: ${error.message}`, 'error');
  }
}

async function refreshRunStatus() {
  if (!state.runJob?.id) return;
  try {
    const response = await fetch(`/api/status?id=${encodeURIComponent(state.runJob.id)}`, { cache: 'no-store' });
    const job = await response.json();
    if (!response.ok) throw new Error(job.error || 'Status unavailable');
    state.runJob = job;
    renderRunStatus(job);
    if (job.status !== 'running') {
      clearInterval(state.runPollTimer);
      state.runPollTimer = null;
      document.getElementById('btn-run-solver').disabled = false;
      showToast(job.status === 'completed' ? 'MUL2 run completed' : 'MUL2 run failed', job.status === 'completed' ? 'success' : 'error');
    }
  } catch (error) {
    document.getElementById('run-console').textContent += `\n${error.message}`;
  }
}

function renderRunStatus(job) {
  const summary = document.getElementById('run-summary');
  const consoleEl = document.getElementById('run-console');
  const results = document.getElementById('result-files');
  if (summary) summary.innerHTML = `<strong>Status:</strong> ${escHtml(job.status || 'unknown')}<br><strong>Run:</strong> ${escHtml(job.id || '')}${job.exitCode !== undefined && job.exitCode !== null ? `<br><strong>Exit code:</strong> ${job.exitCode}` : ''}`;
  if (consoleEl) consoleEl.textContent = [job.stdout, job.stderr].filter(Boolean).join('\n');
  if (results) results.innerHTML = (job.results || []).map(file => `<div class="result-file"><span>${escHtml(file.name)}</span><a class="btn btn-xs btn-secondary" href="${file.url}" target="_blank" rel="noopener">Open</a></div>`).join('');
}

function parseFile(fname, raw) {
  if (fname === 'ANALYSIS.dat') return Parsers.parseAnalysis(raw);
  if (fname === 'NODES.dat') return Parsers.parseNodes(raw);
  if (fname === 'CONNECTIVITY.dat') return Parsers.parseConnectivity(raw);
  if (fname === 'VERSORS.dat') return Parsers.parseVersors(raw);
  if (fname === 'MATERIAL.dat') return Parsers.parseMaterial(raw);
  if (fname === 'LAMINATION.dat') return Parsers.parseLamination(raw);
  if (fname.startsWith('EXP_CONN_')) return Parsers.parseExpConn(raw);
  if (fname.startsWith('EXP_MESH_')) return Parsers.parseExpMesh(raw);
  if (fname === 'BC.dat') return Parsers.parseBC(raw);
  if (fname === 'POSTPROCESSING.dat') return Parsers.parsePostprocessing(raw);
  if (fname === 'FIELDS.dat') return Parsers.parseFields(raw);
  if (fname === 'TIME_RESP.dat') return Parsers.parseTimeResponse(raw);
  if (fname === 'FREQ_RESP.dat') return Parsers.parseFrequencyResponse(raw);
  return Parsers.parseGeneric(raw);
}

function exportFile(fname) {
  const fdata = state.files[fname];
  if (!fdata) return;
  const text = generateFileText(fname, fdata.parsed);
  // Sanitize: replace tabs with spaces
  const sanitized = text.replace(/\t/g, '  ');
  const blob = new Blob([sanitized], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = fname; a.click();
  URL.revokeObjectURL(url);
}

function exportAllFiles() {
  for (const fname of Object.keys(state.files)) {
    exportFile(fname);
  }
  showToast('All files downloaded', 'success');
}

// ──────────────────────────────────────────────
//  DEFAULT PROBLEM: TWO-LAYER CANTILEVER BEAM
// ──────────────────────────────────────────────
const DEFAULT_TWO_LAYER_CANTILEVER_FILES = {
  'ANALYSIS.dat': `101

20           Number of Modes for the Modal Analysis (** ATTENTION to ALL Modes choise)

MITC         Sheral locking correction beam (NONE/REDI/SELI/MITC)
MITC         Sheral locking correction plate (NONE/REDI/SELI/MITC)
MITC         Sheral locking correction solid (NONE/REDI/SELI/MITC)
`,

  'NODES.dat': `13

1   0.0000000D0   0.000000D0   0.0000000D0  LE 1
2   0.0000000D0   0.033333D0   0.0000000D0  LE 1
3   0.0000000D0   0.066667D0   0.0000000D0  LE 1
4   0.0000000D0   0.100000D0   0.0000000D0  LE 1
5   0.0000000D0   0.133333D0   0.0000000D0  LE 1
6   0.0000000D0   0.166667D0   0.0000000D0  LE 1
7   0.0000000D0   0.200000D0   0.0000000D0  LE 1
8   0.0000000D0   0.233333D0   0.0000000D0  LE 1
9   0.0000000D0   0.266667D0   0.0000000D0  LE 1
10  0.0000000D0   0.300000D0   0.0000000D0  LE 1
11  0.0000000D0   0.333333D0   0.0000000D0  LE 1
12  0.0000000D0   0.366667D0   0.0000000D0  LE 1
13  0.0000000D0   0.400000D0   0.0000000D0  LE 1
`,

  'CONNECTIVITY.dat': `4

B4  1   1   2   3   4  1  1  
B4  2   4   5   6   7  1  1 
B4  3   7   8   9   10 1  1  
B4  4  10  11  12  13 1  1 
`,

  'VERSORS.dat': `1

VERSOR  1   0  0  1  
`,

  'MATERIAL.dat': `2  2

ISO-M  1   73.0D9   0.3D0  2700.0D0
ISO-M  2   210.0D9  0.3D0  7800.0D0
`,

  'LAMINATION.dat': `2

LAM2   1   1   0.000D0   0.000D0
LAM2   2   2   0.000D0   0.000D0
`,

  'EXP_MESH_01.dat': `9

1   -0.10000D0   0.0000000D0   -0.0005000D0
2    0.0000000D0  0.0000000D0   -0.0005000D0
3    0.10000D0   0.0000000D0   -0.0005000D0
4   -0.10000D0   0.0000000D0    0.0000000D0
5    0.0000000D0  0.0000000D0    0.0000000D0
6    0.10000D0   0.0000000D0    0.0000000D0
7   -0.10000D0   0.0000000D0    0.0005000D0
8    0.0000000D0  0.0000000D0    0.0005000D0
9    0.10000D0   0.0000000D0    0.0005000D0
`,

  'EXP_CONN_01.dat': `1
 
Q9  1  1  1  2  3  6  9  8  7  4  5
`,

  'BC.dat': `4

D-PLANE  1 0 1 0 0     0.0D0 0.0D0 0.0D0
F-POINT  2  0.0D0  0.4D0   0.0005D0  0.0D0   0.0D0  -100.0D0
F-POINT  3  0.1D0  0.4D0   0.0005D0  0.0D0   0.0D0    50.0D0
F-POINT  4 -0.1D0  0.4D0   0.0005D0  0.0D0   0.0D0    50.0D0
`,

  'POSTPROCESSING.dat': `5
 
PARA   20   GLB   1  1 1 1 1 1 1 1  1 
PARA   20   GLB   3  3 3 1 1 1 1 1  1 
PNT 1    0.0D0    0.200D0    -0.0005D0
PNT 2    0.0D0    0.200D0     0.0005D0
PNT 3    0.0D0    0.400D0     0.0000D0
`,

  'FIELDS.dat': `2

FIELD    1   1
CONST    0.0D0

FIELD    2    1
X-EXP    360  1
`
};

function loadProblemFiles(fileMap) {
  History.recordChange(true);
  state.files = {};
  for (const [fname, raw] of Object.entries(fileMap)) {
    const parsed = parseFile(fname, raw);
    if (parsed) {
      state.files[fname] = { raw, parsed };
    }
  }
  renderSidebar();
  updateActionButtonsState();
  selectFile('NODES.dat');
  setView('split');
  History.init();
}

async function createNewProblemWithFolder() {
  if (Object.keys(state.files).length > 0) {
    const proceed = confirm('Creating a new problem will close current files. Any unsaved edits will be replaced. Proceed?');
    if (!proceed) return;
  }

  // Use File System Access API if supported by the browser
  if (typeof window.showDirectoryPicker === 'function') {
    try {
      const dirHandle = await window.showDirectoryPicker({
        mode: 'readwrite',
        startIn: 'documents'
      });

      let writtenCount = 0;
      for (const [fname, content] of Object.entries(DEFAULT_TWO_LAYER_CANTILEVER_FILES)) {
        try {
          const fileHandle = await dirHandle.getFileHandle(fname, { create: true });
          const writable = await fileHandle.createWritable();
          await writable.write(content);
          await writable.close();
          writtenCount++;
        } catch (writeErr) {
          console.error(`Error saving ${fname} to folder:`, writeErr);
        }
      }

      loadProblemFiles(DEFAULT_TWO_LAYER_CANTILEVER_FILES);
      showToast(`Created ${writtenCount} input files in "${dirHandle.name}" and loaded problem!`, 'success');
      return;
    } catch (err) {
      if (err.name === 'AbortError') {
        // User cancelled folder picker
        return;
      }
      console.warn('showDirectoryPicker failed, falling back to in-app load:', err);
    }
  }

  // Fallback for browsers without showDirectoryPicker
  const proceedFallback = confirm(
    'Direct folder writing is not supported in this browser (requires Chromium/Edge with File System Access API).\n\n' +
    'Do you want to initialize and load the two-layer cantilever beam problem into the editor now?\n' +
    '(You can then click "Export" to download the files to your folder.)'
  );
  if (proceedFallback) {
    loadProblemFiles(DEFAULT_TWO_LAYER_CANTILEVER_FILES);
    showToast('Loaded two-layer cantilever beam. Use "Export" to save files.', 'info');
  }
}

function clearAllFiles() {
  if (Object.keys(state.files).length === 0) return;
  if (!confirm('Close all open files and return to starting position?')) return;

  // Snapshot before clearing so that Undo (Ctrl+Z) can restore if desired
  History.recordChange(true);

  state.files = {};
  state.activeFile = null;
  state.activeView = 'editor';
  state.projectDirectory = null;
  state.projectName = '';

  // Hide all panels
  const editorPanel = document.getElementById('editor-panel');
  const rawPanel = document.getElementById('raw-panel');
  const splitPanel = document.getElementById('split-panel');
  const panel3D = document.getElementById('panel-3d');
  const runPanel = document.getElementById('run-panel');
  if (editorPanel) editorPanel.style.display = 'none';
  if (rawPanel) rawPanel.style.display = 'none';
  if (splitPanel) splitPanel.style.display = 'none';
  if (panel3D) panel3D.style.display = 'none';
  if (runPanel) runPanel.style.display = 'none';

  // Show welcome screen
  const welcome = document.getElementById('welcome-screen');
  if (welcome) welcome.style.display = '';

  // Reset main header title
  const headerTitle = document.getElementById('main-header-title');
  if (headerTitle) headerTitle.innerHTML = `<span>CUF Preprocessor Tool</span>`;

  // Reset tabs
  document.querySelectorAll('.main-header-tab').forEach(tab => {
    tab.classList.toggle('active', tab.dataset.view === 'editor');
  });

  // Empty sidebar cards and validation summary
  const container = document.getElementById('file-cards-container');
  if (container) container.innerHTML = '';
  const valSummary = document.getElementById('validation-summary-sidebar');
  if (valSummary) valSummary.style.display = 'none';

  updateActionButtonsState();
  History.updateUI();

  showToast('All files closed. Returned to starting position.', 'info');
}

window.DEFAULT_TWO_LAYER_CANTILEVER_FILES = DEFAULT_TWO_LAYER_CANTILEVER_FILES;
window.loadProblemFiles = loadProblemFiles;
window.createNewProblemWithFolder = createNewProblemWithFolder;
window.clearAllFiles = clearAllFiles;

// ──────────────────────────────────────────────
//  RAW TEXT SYNC
// ──────────────────────────────────────────────
function onRawTextChange(textarea) {
  const fname = state.activeFile;
  if (!fname) return;
  const raw = textarea.value;
  const parsed = parseFile(fname, raw);
  if (parsed) {
    History.recordChange(false);
    state.files[fname].parsed = parsed;
    state.files[fname].raw = raw;
    // Re-render editor in split view
    if (state.activeView === 'split') {
      renderSplitView(fname);
    }
    renderSidebar();
    if (window.beamRenderer) window.beamRenderer.render();
  }
}

// ──────────────────────────────────────────────
//  INIT
// ──────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  // New problem buttons (Sidebar & Welcome screen)
  document.getElementById('btn-new-project')?.addEventListener('click', createNewProblemWithFolder);
  document.getElementById('btn-welcome-new')?.addEventListener('click', createNewProblemWithFolder);
  document.getElementById('btn-welcome-load')?.addEventListener('click', () => {
    document.getElementById('file-input').click();
  });
  document.getElementById('btn-open-folder')?.addEventListener('click', openProjectFolder);
  document.getElementById('btn-save-project')?.addEventListener('click', saveProjectFolder);
  document.getElementById('btn-run-solver')?.addEventListener('click', runSolver);
  document.getElementById('btn-refresh-run')?.addEventListener('click', () => state.runJob ? refreshRunStatus() : checkServerAvailability());

  // Clear / Close buttons (Sidebar & Header)
  document.getElementById('btn-clear-all')?.addEventListener('click', clearAllFiles);
  document.getElementById('btn-header-clear')?.addEventListener('click', clearAllFiles);

  // Load button
  document.getElementById('btn-load-files').addEventListener('click', () => {
    document.getElementById('file-input').click();
  });

  document.getElementById('file-input').addEventListener('change', (e) => {
    if (e.target.files.length > 0) loadFiles(e.target.files);
  });

  // Dropzone
  const dropzone = document.getElementById('dropzone');
  dropzone.addEventListener('click', () => document.getElementById('file-input').click());
  dropzone.addEventListener('dragover', e => { e.preventDefault(); dropzone.classList.add('dragover'); });
  dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
  dropzone.addEventListener('drop', e => {
    e.preventDefault();
    dropzone.classList.remove('dragover');
    if (e.dataTransfer.files.length > 0) loadFiles(e.dataTransfer.files);
  });

  // Global drop on body
  document.body.addEventListener('dragover', e => e.preventDefault());
  document.body.addEventListener('drop', e => {
    e.preventDefault();
    if (e.dataTransfer.files.length > 0) loadFiles(e.dataTransfer.files);
  });

  // Undo / Redo Buttons
  document.getElementById('btn-undo')?.addEventListener('click', () => History.undo());
  document.getElementById('btn-redo')?.addEventListener('click', () => History.redo());

  // Global Keyboard Shortcuts (Ctrl+Z / Cmd+Z for Undo, Ctrl+Y / Ctrl+Shift+Z for Redo)
  window.addEventListener('keydown', (e) => {
    const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
    const modifier = isMac ? e.metaKey : e.ctrlKey;

    if (modifier && !e.altKey) {
      if (e.key === 'z' || e.key === 'Z') {
        if (e.shiftKey) {
          // Redo
          e.preventDefault();
          History.redo();
        } else {
          // Undo
          e.preventDefault();
          History.undo();
        }
      } else if (e.key === 'y' || e.key === 'Y') {
        // Redo
        e.preventDefault();
        History.redo();
      }
    }
  });

  // Export
  document.getElementById('btn-export-all').addEventListener('click', exportAllFiles);

  // View tabs
  document.querySelectorAll('.main-header-tab').forEach(tab => {
    tab.addEventListener('click', () => setView(tab.dataset.view));
  });

  // Split View Switcher (3D Beam Model vs. Raw Fortran)
  const btnSplit3D = document.getElementById('btn-split-show-3d');
  const btnSplitRaw = document.getElementById('btn-split-show-raw');
  const split3DContainer = document.getElementById('split-3d-container');
  const splitRawContainer = document.getElementById('split-raw-container');
  const splitToolbar = document.getElementById('split-3d-toolbar');

  if (btnSplit3D && btnSplitRaw) {
    btnSplit3D.addEventListener('click', () => {
      btnSplit3D.classList.add('active');
      btnSplitRaw.classList.remove('active');
      if (split3DContainer) split3DContainer.style.display = 'block';
      if (splitRawContainer) splitRawContainer.style.display = 'none';
      if (splitToolbar) splitToolbar.style.display = 'flex';
      const canvas = document.getElementById('split-viewport-canvas');
      if (canvas && window.beamRenderer) {
        window.beamRenderer.attachToCanvas(canvas);
      }
    });

    btnSplitRaw.addEventListener('click', () => {
      btnSplitRaw.classList.add('active');
      btnSplit3D.classList.remove('active');
      if (split3DContainer) split3DContainer.style.display = 'none';
      if (splitRawContainer) splitRawContainer.style.display = 'flex';
      if (splitToolbar) splitToolbar.style.display = 'none';
      if (state.activeFile) updateRawView(state.activeFile);
    });
  }

  // Camera preset buttons
  document.querySelectorAll('[data-cam]').forEach(btn => {
    btn.addEventListener('click', () => {
      if (window.beamRenderer) window.beamRenderer.setCameraPreset(btn.dataset.cam);
    });
  });

  // Z-Scale selectors
  const onZScaleChange = (val) => {
    if (window.beamRenderer) window.beamRenderer.setZScale(val);
    const s1 = document.getElementById('split-zscale-select');
    const s2 = document.getElementById('full-zscale-select');
    if (s1) s1.value = val;
    if (s2) s2.value = val;
  };
  document.getElementById('split-zscale-select')?.addEventListener('change', e => onZScaleChange(e.target.value));
  document.getElementById('full-zscale-select')?.addEventListener('change', e => onZScaleChange(e.target.value));

  // Turntable button
  document.getElementById('btn-turntable')?.addEventListener('click', function () {
    if (!window.beamRenderer) return;
    const active = window.beamRenderer.toggleTurntable();
    this.classList.toggle('active', active);
    this.innerHTML = active ? '&#10074;&#10074; Stop Rotate' : '&#9654; Auto-Rotate';
  });

  // Display Option Checkboxes
  const optMap = {
    'chk-faces': 'showFaces',
    'chk-wireframe': 'showWireframe',
    'chk-nodes': 'showNodes',
    'chk-bcs': 'showBCs',
    'chk-pnt': 'showPNT',
    'chk-axes': 'showAxes'
  };
  for (const [chkId, optKey] of Object.entries(optMap)) {
    const chk = document.getElementById(chkId);
    if (chk) {
      chk.addEventListener('change', () => {
        if (window.beamRenderer) window.beamRenderer.toggleOption(optKey, chk.checked);
      });
    }
  }

  // Raw text change
  document.getElementById('raw-textarea').addEventListener('input', function () { onRawTextChange(this); });
  document.getElementById('split-raw-textarea').addEventListener('input', function () { onRawTextChange(this); });

  // Raw text buttons
  document.getElementById('btn-raw-copy').addEventListener('click', () => {
    const text = document.getElementById('raw-textarea').value;
    navigator.clipboard.writeText(text).then(() => showToast('Copied to clipboard', 'success'));
  });

  document.getElementById('btn-raw-download').addEventListener('click', () => {
    if (state.activeFile) exportFile(state.activeFile);
  });

  // Auto-load example files if hosted on server
  async function autoLoadFilesIfAvailable() {
    const defaultFiles = [
      'ANALYSIS.dat', 'NODES.dat', 'CONNECTIVITY.dat', 'VERSORS.dat',
      'MATERIAL.dat', 'LAMINATION.dat', 'EXP_CONN_01.dat', 'EXP_MESH_01.dat',
      'BC.dat', 'POSTPROCESSING.dat', 'FIELDS.dat', 'TIME_RESP.dat',
      'FREQ_RESP.dat', 'PF_INPUT.dat'
    ];
    let loadedCount = 0;
    for (const fname of defaultFiles) {
      try {
        const res = await fetch(fname);
        if (res.ok) {
          const raw = await res.text();
          const parsed = parseFile(fname, raw);
          if (parsed) {
            state.files[fname] = { raw, parsed };
            loadedCount++;
          }
        }
      } catch (e) {
        // Fetch might fail if opened without HTTP server
      }
    }
    if (loadedCount > 0) {
      renderSidebar();
      updateActionButtonsState();
      selectFile('NODES.dat');
      // Show side-by-side view with 3D model
      setView('split');
      History.init();
      showToast(`Loaded ${loadedCount} CUF files`, 'success');
    }
  }

  autoLoadFilesIfAvailable();
  checkServerAvailability();
});
