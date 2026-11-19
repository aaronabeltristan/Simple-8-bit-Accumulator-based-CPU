// Draws a modern block-level schematic of the CPU from the Yosys JSON netlist.
// Usage: node tools/schematic_modern.js cpu.json docs/cpu_netlist.svg
// Works for whatever module schematic.ys sets as top (hierarchy -top <module>).
//
// - Blocks are cards coloured by kind (memory, register, combinational, FSM)
// - Data buses are dark and thick, control signals from the CU are thin red
// - clk / rst_n are not drawn; clocked blocks carry a CLK tag instead
// - MUX inputs are split per select value, bus slices are labelled

const fs  = require('fs');
const ELK = require('elkjs/lib/elk.bundled.js');

const [, , IN = 'cpu.json', OUT = 'docs/cpu_netlist.svg'] = process.argv;
const json    = JSON.parse(fs.readFileSync(IN, 'utf8'));
const TOP     = Object.keys(json.modules).find(m => json.modules[m].attributes?.top) || Object.keys(json.modules)[0];
const IS_CPU  = TOP === 'cpu';
const GLOBALS = ['clk', 'rst_n'];                            // on module instances: drawn as a CLK tag, not wires
const HIDDEN  = IS_CPU ? ['pc', 'ir', 'acc', 'flags', 'state'] : [];   // CPU debug outputs

// ---------------- block info ----------------
const KIND = {
  memory: { fill: '#EFF5FF', head: '#DCE8FD', line: '#3B6FD4', text: '#1E4FB0', name: 'Memory' },
  seq:    { fill: '#F1F9EE', head: '#DDF0D5', line: '#3F8A2E', text: '#2C6B1E', name: 'Register' },
  comb:   { fill: '#FFFAEB', head: '#FDEFC3', line: '#C08A0B', text: '#8A6206', name: 'Combinational' },
  fsm:    { fill: '#FFF2F2', head: '#FBDCDC', line: '#C43D3D', text: '#9E2B2B', name: 'Control FSM' },
  io:     { fill: '#FFFFFF', head: '#F1F5F9', line: '#64748B', text: '#334155', name: 'Top-level port' },
};
const MODULES = {
  program_counter:      ['seq',    'Program Counter'],
  instruction_memory:   ['memory', 'Instruction ROM'],
  instruction_register: ['seq',    'Instruction Register'],
  instruction_decoder:  ['comb',   'Decoder'],
  control_unit:         ['fsm',    'Control Unit'],
  nto1mux:              ['comb',   'MUX'],
  alu:                  ['comb',   'ALU'],
  accumulator:          ['seq',    'Accumulator'],
  flag_register:        ['seq',    'Flag Register'],
  data_memory:          ['memory', 'Data Memory'],
};
// Yosys primitive cells (seen when a single module is the top)
const PRIMS = {
  $dff: ['seq', 'D Flip-Flop'], $dffe: ['seq', 'DFF + Enable'], $adff: ['seq', 'DFF, Async Reset'],
  $adffe: ['seq', 'DFF + Enable, Async Reset'], $sdff: ['seq', 'DFF, Sync Reset'], $sdffe: ['seq', 'DFF + Enable, Sync Reset'],
  $sdffce: ['seq', 'DFF + Enable, Sync Reset'], $dffsr: ['seq', 'DFF, Set/Reset'], $dlatch: ['seq', 'Latch'],
  $mem: ['memory', 'Memory'], $mem_v2: ['memory', 'Memory'], $memrd: ['memory', 'Memory Read'], $memrd_v2: ['memory', 'Memory Read'], $memwr: ['memory', 'Memory Write'], $memwr_v2: ['memory', 'Memory Write'],
  $mux: ['comb', 'MUX'], $tribuf: ['comb', 'Tri-state Buffer'], $pmux: ['comb', 'Parallel MUX'], $add: ['comb', 'Adder'], $sub: ['comb', 'Subtractor'],
  $and: ['comb', 'AND'], $or: ['comb', 'OR'], $xor: ['comb', 'XOR'], $not: ['comb', 'NOT'],
  $logic_not: ['comb', 'Logical NOT'], $logic_and: ['comb', 'Logical AND'], $logic_or: ['comb', 'Logical OR'],
  $reduce_or: ['comb', 'Reduce OR'], $reduce_and: ['comb', 'Reduce AND'], $reduce_bool: ['comb', 'Reduce OR'],
  $reduce_xor: ['comb', 'Reduce XOR'], $eq: ['comb', 'Equal'], $ne: ['comb', 'Not Equal'],
  $lt: ['comb', 'Less Than'], $le: ['comb', 'Less or Equal'], $gt: ['comb', 'Greater Than'], $ge: ['comb', 'Greater or Equal'],
  $shl: ['comb', 'Shift Left'], $shr: ['comb', 'Shift Right'], $shift: ['comb', 'Shifter'], $shiftx: ['comb', 'Shifter'],
};
const TITLES = { u_mux_b: 'Operand-B MUX', u_mux_acc: 'ACC Source MUX' };
// left-to-right column of each block, following the datapath
const COLUMN = { u_pc: 0, u_rom: 1, u_ir: 2, u_decoder: 3, u_cu: 4, port_input_device: 4,
                 u_dm: 5, port_output_device: 6, u_mux_b: 6, u_alu: 7, u_flags: 8, u_mux_acc: 8, u_acc: 9 };

// ---------------- read netlist ----------------
const top  = json.modules[TOP];
const modName = t => t.replace(/^\$paramod\$[0-9a-f]+\\/, '').replace(/^\$paramod\\/, '').split('\\')[0];

const nodes = {};                 // id -> { id, title, sub, kind, clocked, ins:[], outs:[] }
const drivers = {};               // bit -> { node, port, idx, width }
const sinks = [];                 // { node, port, bits }
const globalBits = new Set(GLOBALS.filter(n => top.ports[n]).map(n => top.ports[n].bits[0]));
const srcLine = c => ((c.attributes || {}).src || '').split('|')[0].replace(/^.*[\\/]/, '').replace(/\.\d+-\d+\.\d+$/, '');

for (const [inst, cell] of Object.entries(top.cells)) {
  if (cell.type.startsWith('$meminit')) continue;   // memory initial contents, not hardware
  const prim = cell.type.startsWith('$') && !cell.type.startsWith('$paramod');
  const m = prim ? cell.type : modName(cell.type);
  const [kind, title] = prim ? (PRIMS[m] || ['comb', m.slice(1).toUpperCase()]) : (MODULES[m] || ['comb', m]);
  const sub = prim ? [srcLine(cell), m].filter(Boolean).join(' · ') : `${inst} · ${m}`;
  const n = nodes[inst] = { id: inst, title: TITLES[inst] || title, sub, kind, clocked: false, ins: [], outs: [] };
  for (const [p, bits] of Object.entries(cell.connections)) {
    if (!prim && bits.length === 1 && globalBits.has(bits[0])) { n.clocked = true; continue; }
    if (cell.port_directions[p] === 'output') {
      n.outs.push({ name: p, width: bits.length });
      bits.forEach((b, i) => { drivers[b] = { node: inst, port: p, idx: i, width: bits.length }; });
    } else sinks.push({ node: inst, port: p, bits });
  }
}
for (const [p, port] of Object.entries(top.ports)) {
  if ((IS_CPU && GLOBALS.includes(p)) || HIDDEN.includes(p)) continue;
  const id = 'port_' + p;
  if (port.direction === 'input') {
    nodes[id] = { id, title: p, kind: 'io', io: 'in', ins: [], outs: [{ name: p, width: port.bits.length }] };
    port.bits.forEach((b, i) => { drivers[b] = { node: id, port: p, idx: i, width: port.bits.length }; });
  } else {
    nodes[id] = { id, title: p, kind: 'io', io: 'out', ins: [{ name: p, width: port.bits.length }], outs: [] };
    sinks.push({ node: id, port: p, bits: port.bits });
  }
}

// ---------------- build edges (split concatenated inputs) ----------------
const edges = [];
const slice = (lo, hi, w) => (lo === 0 && hi === w - 1) ? '' : (lo === hi ? `[${lo}]` : `[${hi}:${lo}]`);
for (const s of sinks) {
  if (s.bits.every(b => b === 'x')) continue;       // unused pin (e.g. CLK of an async read)
  const runs = [];                                  // contiguous bits from one driver port
  s.bits.forEach((b, i) => {
    if (typeof b === 'string') {                    // constant bit '0' / '1' / 'x' / 'z'
      const r = runs[runs.length - 1];
      if (r && r.konst && r.end === i - 1) { r.val.push(b); r.end = i; }
      else runs.push({ konst: true, val: [b], at: i, end: i });
      return;
    }
    const d = drivers[b]; if (!d) return;
    const r = runs[runs.length - 1];
    if (r && r.node === d.node && r.port === d.port && d.idx === r.hi + 1) { r.hi = d.idx; r.end = i; }
    else runs.push({ node: d.node, port: d.port, lo: d.idx, hi: d.idx, width: d.width, at: i, end: i });
  });
  const n = nodes[s.node];
  const split = runs.length > 1;
  // equal pieces (a MUX data input) are numbered 0..N-1, otherwise named by bit range
  const equal = split && runs.every(r => r.end - r.at === runs[0].end - runs[0].at);
  runs.forEach((r, k) => {
    if (r.konst) {                                  // make a small constant node
      const v = r.val.slice().reverse().join('');
      const txt = /z/.test(v) ? `${v.length}'bz` : /x/.test(v) ? `${v.length}'bx`
                : `${v.length}'h${parseInt(v, 2).toString(16).toUpperCase()}`;
      const id = `const_${Object.keys(nodes).length}`;
      nodes[id] = { id, title: txt, kind: 'io', io: 'in', konst: true, ins: [], outs: [{ name: 'k', width: v.length }] };
      Object.assign(r, { node: id, port: 'k', lo: 0, hi: v.length - 1, width: v.length });
    }
    const w = r.end - r.at + 1;
    const pname = !split ? s.port : equal ? `${s.port}${k}` : `${s.port}${slice(r.at, r.end, s.bits.length)}`;
    if (!n.ins.find(p => p.name === pname))
      n.ins.push({ name: pname, width: split ? w : s.bits.length, sel: equal ? k : undefined, ranged: split && !equal });
    edges.push({
      id: `e${edges.length}`, src: r.node, srcPort: r.port, dst: s.node, dstPort: pname,
      width: r.hi - r.lo + 1, label: slice(r.lo, r.hi, r.width),
      control: nodes[r.node].kind === 'fsm',
    });
  });
}

for (const n of Object.values(nodes)) if (n.kind === 'io' && !edges.some(e => e.src === n.id || e.dst === n.id)) delete nodes[n.id];
for (const n of Object.values(nodes))
  n.outs = n.outs.filter(p => edges.some(e => e.src === n.id && e.srcPort === p.name));

// ---------------- sizes ----------------
const CH = 6.6, ROW = 22, HEAD = 44, PAD = 14;
const portLabel = p => p.sel !== undefined ? String(p.sel) : p.name;
const widthTag  = w => w > 1 ? `[${w - 1}:0]` : '';
const textW = p => (portLabel(p).length + (p.width > 1 && !p.ranged ? widthTag(p.width).length * 0.95 + 1 : 0)) * CH;
for (const n of Object.values(nodes)) {
  if (n.kind === 'io') { n.w = n.title.length * 7.2 + 44; n.h = 30; continue; }
  const li = Math.max(0, ...n.ins.map(textW)), lo = Math.max(0, ...n.outs.map(textW));
  n.w = Math.max(li + lo + 44, n.title.length * 7.8 + (n.clocked ? 70 : 34), n.sub.length * 6 + 30);
  n.h = HEAD + Math.max(n.ins.length, n.outs.length, 1) * ROW + PAD;
}

// ---------------- ELK layout ----------------
const graph = {
  id: 'root',
  layoutOptions: {
    'elk.algorithm': 'layered',
    'elk.direction': 'RIGHT',
    'elk.edgeRouting': 'ORTHOGONAL',
    'elk.layered.spacing.nodeNodeBetweenLayers': '90',
    'elk.spacing.nodeNode': '50',
    'elk.layered.spacing.edgeNodeBetweenLayers': '22',
    'elk.layered.spacing.edgeEdgeBetweenLayers': '12',
    'elk.spacing.edgeEdge': '12',
    'elk.spacing.edgeNode': '22',
    'elk.layered.nodePlacement.strategy': 'NETWORK_SIMPLEX',
    'elk.layered.crossingMinimization.semiInteractive': 'false',
    'elk.layered.thoroughness': '40',
    'elk.partitioning.activate': String(IS_CPU),
    'elk.padding': '[top=90,left=40,bottom=40,right=40]',
  },
  children: Object.values(nodes).map(n => ({
    id: n.id, width: n.w, height: n.h,
    layoutOptions: { 'elk.portConstraints': 'FIXED_POS', ...(IS_CPU && n.id in COLUMN ? { 'elk.partitioning.partition': String(COLUMN[n.id]) } : {}) },
    ports: [
      ...n.ins.map((p, i) => ({ id: `${n.id}.${p.name}`, width: 0, height: 0, x: 0,
        y: n.kind === 'io' ? n.h / 2 : HEAD + ROW * i + ROW / 2, layoutOptions: { 'elk.port.side': 'WEST' } })),
      ...n.outs.map((p, i) => ({ id: `${n.id}.${p.name}`, width: 0, height: 0, x: n.w,
        y: n.kind === 'io' ? n.h / 2 : HEAD + ROW * i + ROW / 2, layoutOptions: { 'elk.port.side': 'EAST' } })),
    ],
  })),
  edges: edges.map(e => ({ id: e.id, sources: [`${e.src}.${e.srcPort}`], targets: [`${e.dst}.${e.dstPort}`] })),
};

// order ports top-to-bottom by the average position of what they connect to (2 passes)
function orderPorts(laid) {
  const pos = {};
  for (const c of laid.children) pos[c.id] = c.y + c.height / 2;
  for (const n of Object.values(nodes)) {
    if (n.kind === 'io') continue;
    const key = (p, side) => {
      const ys = edges.filter(e => side === 'in' ? (e.dst === n.id && e.dstPort === p.name) : (e.src === n.id && e.srcPort === p.name))
                      .map(e => pos[side === 'in' ? e.src : e.dst]);
      return ys.length ? ys.reduce((a, b) => a + b) / ys.length : 0;
    };
    if (n.id !== 'u_alu' && !n.ins.some(p => p.sel !== undefined)) n.ins.sort((a, b) => key(a, 'in') - key(b, 'in'));
    n.outs.sort((a, b) => key(a, 'out') - key(b, 'out'));
  }
  for (const c of graph.children) {
    const n = nodes[c.id]; if (n.kind === 'io') continue;
    for (const p of c.ports) {
      const name = p.id.slice(n.id.length + 1);
      const list = p.layoutOptions['elk.port.side'] === 'WEST' ? n.ins : n.outs;
      p.y = HEAD + ROW * list.findIndex(q => q.name === name) + ROW / 2;
    }
  }
}

// ---------------- SVG helpers ----------------
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
function roundedPath(pts, r = 7) {
  let d = `M${pts[0].x},${pts[0].y}`;
  for (let i = 1; i < pts.length - 1; i++) {
    const a = pts[i - 1], b = pts[i], c = pts[i + 1];
    const l1 = Math.hypot(b.x - a.x, b.y - a.y), l2 = Math.hypot(c.x - b.x, c.y - b.y);
    const k = Math.min(r, l1 / 2, l2 / 2);
    const p1 = { x: b.x - (b.x - a.x) / l1 * k, y: b.y - (b.y - a.y) / l1 * k };
    const p2 = { x: b.x + (c.x - b.x) / l2 * k, y: b.y + (c.y - b.y) / l2 * k };
    d += ` L${p1.x.toFixed(1)},${p1.y.toFixed(1)} Q${b.x},${b.y} ${p2.x.toFixed(1)},${p2.y.toFixed(1)}`;
  }
  const z = pts[pts.length - 1];
  return d + ` L${z.x},${z.y}`;
}
function junctions(polys) {           // points where wires of one net branch
  const out = [], key = p => `${Math.round(p.x)},${Math.round(p.y)}`, seen = new Set();
  const dirsAt = (pt) => {
    const dirs = new Set();
    for (const pl of polys) for (let i = 0; i < pl.length - 1; i++) {
      const a = pl[i], b = pl[i + 1];
      const onSeg = Math.abs((b.x - a.x) * (pt.y - a.y) - (b.y - a.y) * (pt.x - a.x)) < 0.5 &&
        pt.x >= Math.min(a.x, b.x) - 0.5 && pt.x <= Math.max(a.x, b.x) + 0.5 &&
        pt.y >= Math.min(a.y, b.y) - 0.5 && pt.y <= Math.max(a.y, b.y) + 0.5;
      if (!onSeg) continue;
      const d = (q) => q.x > pt.x + 0.5 ? 'E' : q.x < pt.x - 0.5 ? 'W' : q.y > pt.y + 0.5 ? 'S' : q.y < pt.y - 0.5 ? 'N' : null;
      [d(a), d(b)].forEach(x => x && dirs.add(x));
    }
    return dirs;
  };
  for (const pl of polys) for (const pt of pl.slice(1, -1)) {
    if (seen.has(key(pt))) continue; seen.add(key(pt));
    if (dirsAt(pt).size >= 3) out.push(pt);
  }
  return out;
}

// ---------------- render ----------------
(async () => {
  const elk = new ELK();
  orderPorts(await elk.layout(JSON.parse(JSON.stringify(graph))));
  const laid = await elk.layout(graph);
  const W = Math.ceil(laid.width), H = Math.ceil(laid.height) + 20;
  const at = {}; for (const c of laid.children) at[c.id] = c;

  const DATA = '#334155', CTRL = '#D9485F';
  const svg = [];
  svg.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`);
  svg.push(`<defs>
  <pattern id="dots" width="18" height="18" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r="1" fill="#E2E8F0"/></pattern>
  <filter id="shadow" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#0F172A" flood-opacity="0.10"/></filter>
  <style>
    text { font-family: Inter, 'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif; }
    .mono { font-family: 'JetBrains Mono', Consolas, 'SF Mono', Menlo, monospace; }
    .title { font-size: 13px; font-weight: 700; }
    .sub { font-size: 9.5px; fill: #94A3B8; }
    .port { font-size: 11px; fill: #334155; }
    .w { font-size: 9.5px; fill: #94A3B8; }
    .slice { font-size: 9.5px; font-weight: 600; paint-order: stroke; stroke: #F8FAFC; stroke-width: 4px; stroke-linejoin: round; }
    .wire { fill: none; stroke-linejoin: round; stroke-linecap: round; }
  </style>
</defs>`);
  svg.push(`<rect width="${W}" height="${H}" fill="#F8FAFC"/><rect width="${W}" height="${H}" fill="url(#dots)"/>`);
  svg.push(`<text x="40" y="42" style="font-size:20px;font-weight:700;fill:#0F172A">${IS_CPU ? 'Simple 8-bit Accumulator CPU' : esc(TOP)}</text>`);
  svg.push(`<text x="40" y="62" style="font-size:12px;fill:#64748B">Synthesized netlist · Yosys + ELK${IS_CPU ? ' · clk and rst_n go to every block tagged CLK' : ''}</text>`);

  // legend (top right)
  let lx = W - 40;
  const used = new Set(Object.values(nodes).map(n => n.kind));
  const items = ['memory', 'seq', 'comb', 'fsm'].filter(k => used.has(k)).map(k => [KIND[k].name, KIND[k]]);
  const leg = [];
  if (edges.some(e => e.control)) leg.push([`Control signal`, null, CTRL, 1.6]);
  if (edges.some(e => e.width > 1)) leg.push([`Bus`, null, DATA, 2.6]);
  leg.push([`Wire`, null, DATA, 1.6]);
  items.reverse().forEach(x => leg.push(x));
  for (const [name, k, col, sw] of leg) {
    const w = name.length * 6.6 + (k ? 22 : 34);
    lx -= w + 14;
    if (k) svg.push(`<rect x="${lx}" y="33" width="12" height="12" rx="3" fill="${k.head}" stroke="${k.line}"/>`);
    else svg.push(`<line x1="${lx}" y1="39" x2="${lx + 22}" y2="39" stroke="${col}" stroke-width="${sw}" stroke-linecap="round"/>`);
    svg.push(`<text x="${lx + (k ? 18 : 28)}" y="43" style="font-size:11.5px;fill:#475569">${esc(name)}</text>`);
  }

  // wires
  const bySrc = {};
  const wireSvg = [], labelSvg = [];
  for (const e of laid.edges) {
    const meta = edges.find(x => x.id === e.id);
    for (const s of e.sections || []) {
      const pts = [s.startPoint, ...(s.bendPoints || []), s.endPoint];
      const key = `${meta.src}.${meta.srcPort}`;
      (bySrc[key] = bySrc[key] || { col: meta.control ? CTRL : DATA, polys: [] }).polys.push(pts);
      const col = meta.control ? CTRL : DATA, sw = meta.width > 1 ? 2.6 : 1.6;
      wireSvg.push(`<path class="wire" d="${roundedPath(pts)}" stroke="${col}" stroke-width="${sw}"/>`);
      if (meta.label) {
        const z = s.endPoint;
        labelSvg.push(`<text class="slice mono" x="${z.x - 8}" y="${z.y - 5}" text-anchor="end" fill="${col}">${meta.label}</text>`);
      }
    }
  }
  svg.push('<g>' + wireSvg.join('') + '</g>');
  for (const { col, polys } of Object.values(bySrc))
    for (const p of junctions(polys)) svg.push(`<circle cx="${p.x}" cy="${p.y}" r="3.2" fill="${col}"/>`);

  // blocks
  for (const n of Object.values(nodes)) {
    const c = at[n.id], k = KIND[n.kind], x = c.x, y = c.y;
    if (n.kind === 'io') {
      const tip = 12, w = n.w, h = n.h;
      const d = n.io === 'in'
        ? `M${x},${y} H${x + w - tip} L${x + w},${y + h / 2} L${x + w - tip},${y + h} H${x} Z`
        : `M${x + tip},${y} H${x + w} V${y + h} H${x + tip} L${x},${y + h / 2} Z`;
      svg.push(`<path d="${d}" fill="#FFFFFF" stroke="${k.line}" stroke-width="1.3" stroke-linejoin="round" filter="url(#shadow)"/>`);
      svg.push(`<text class="mono" x="${x + w / 2 + (n.io === 'in' ? -5 : 5)}" y="${y + h / 2 + 4}" text-anchor="middle" style="font-size:11.5px;font-weight:600;fill:${k.text}">${esc(n.title)}</text>`);
      continue;
    }
    svg.push(`<g filter="url(#shadow)"><rect x="${x}" y="${y}" width="${n.w}" height="${n.h}" rx="10" fill="#FFFFFF" stroke="${k.line}" stroke-opacity="0.55"/></g>`);
    svg.push(`<path d="M${x},${y + HEAD - 6} V${y + 10} Q${x},${y} ${x + 10},${y} H${x + n.w - 10} Q${x + n.w},${y} ${x + n.w},${y + 10} V${y + HEAD - 6} Z" fill="${k.head}"/>`);
    svg.push(`<line x1="${x}" y1="${y + HEAD - 6}" x2="${x + n.w}" y2="${y + HEAD - 6}" stroke="${k.line}" stroke-opacity="0.35"/>`);
    svg.push(`<rect x="${x}" y="${y}" width="${n.w}" height="${n.h}" rx="10" fill="none" stroke="${k.line}" stroke-opacity="0.55"/>`);
    svg.push(`<text class="title" x="${x + 12}" y="${y + 18}" fill="${k.text}">${esc(n.title)}</text>`);
    svg.push(`<text class="sub mono" x="${x + 12}" y="${y + 31}">${esc(n.sub)}</text>`);
    if (n.clocked) {
      svg.push(`<rect x="${x + n.w - 46}" y="${y + 8}" width="36" height="16" rx="8" fill="#FFFFFF" stroke="${k.line}" stroke-opacity="0.6"/>`);
      svg.push(`<text class="mono" x="${x + n.w - 28}" y="${y + 19.5}" text-anchor="middle" style="font-size:9px;font-weight:700;fill:${k.text}">CLK</text>`);
    }
    const row = (p, i, side) => {
      const py = y + HEAD + ROW * i + ROW / 2, px = side === 'in' ? x : x + n.w;
      const tx = side === 'in' ? x + 12 : x + n.w - 12, anchor = side === 'in' ? 'start' : 'end';
      const tag = p.sel === undefined && !p.ranged && p.width > 1 ? ` <tspan class="w mono">${widthTag(p.width)}</tspan>` : '';
      const lbl = p.sel !== undefined ? `<tspan class="mono" style="font-weight:600">${p.sel}</tspan><tspan class="w mono"> [${p.width - 1}:0]</tspan>` : esc(p.name) + tag;
      svg.push(`<text class="port" x="${tx}" y="${py + 4}" text-anchor="${anchor}">${lbl}</text>`);
      svg.push(`<circle cx="${px}" cy="${py}" r="3.4" fill="#FFFFFF" stroke="${k.line}" stroke-width="1.5"/>`);
    };
    n.ins.forEach((p, i) => row(p, i, 'in'));
    n.outs.forEach((p, i) => row(p, i, 'out'));
  }
  svg.push(labelSvg.join(''));
  svg.push('</svg>');
  fs.writeFileSync(OUT, svg.join('\n'));
  console.log(`Schematic written to ${OUT} (${Object.keys(nodes).length} blocks, ${edges.length} connections)`);
})();
