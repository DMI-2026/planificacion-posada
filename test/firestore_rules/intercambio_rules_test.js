// Prueba de las reglas del intercambio (lib/features/intercambio/intercambio.rules)
// contra el emulador de Firestore. Requiere que esos bloques estén dentro de las reglas
// que carga el emulador (firestore.rules con los bloques pegados). Cómo correrla:
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:<puerto> firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/intercambio_rules_test.js"
// Roles: admin1 (tiene admins/admin1), u1, u2 (participantes), u3 (con sesión pero sin documento
// en `participantes`). Cada línea imprime PASS/FAIL; sale con código distinto de 0 si algo falla.
const P = 'demo-posada', H = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080', B = `http://${H}/v1/projects/${P}/databases/(default)/documents`;
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const now = Math.floor(Date.now()/1000);
const tok = uid => 'Bearer ' + b64({alg:'none',typ:'JWT'}) + '.' + b64({sub:uid,user_id:uid,iss:`https://securetoken.google.com/${P}`,aud:P,iat:now,exp:now+3600,auth_time:now,firebase:{sign_in_provider:'password',identities:{}}}) + '.';
const U1 = tok('u1'), U2 = tok('u2'), U3 = tok('u3'), ADMIN = tok('admin1'), OWNER = 'Bearer owner';
const enc = v => v === null ? {nullValue:null} : v instanceof Date ? {timestampValue:v.toISOString()} : typeof v === 'string' ? {stringValue:v}
  : typeof v === 'boolean' ? {booleanValue:v} : Array.isArray(v) ? {arrayValue:{values:v.map(enc)}} : Number.isInteger(v) ? {integerValue:String(v)} : typeof v === 'number' ? {doubleValue:v} : v;
const F = o => ({fields: Object.fromEntries(Object.entries(o).map(([k,v]) => [k, enc(v)]))});
async function req(method, path, auth, body, qs='') {
  const h = {'Content-Type':'application/json'}; if (auth) h.Authorization = auth;
  const r = await fetch(B + '/' + path + qs, {method, headers:h, body: body ? JSON.stringify(body) : undefined});
  const t = await r.text(); return {s:r.status, j: t ? JSON.parse(t) : {}};
}
const get = (p,a) => req('GET', p, a);
const set = (p,a,o) => req('PATCH', p, a, F(o));
const del = (p,a) => req('DELETE', p, a);
// Batch atómico (commit) como el que hace el admin al sortear.
async function commit(auth, writes) {
  const h = {'Content-Type':'application/json'}; if (auth) h.Authorization = auth;
  const base = `projects/${P}/databases/(default)/documents/`;
  const body = {writes: writes.map(([p, o]) => o === null ? {delete: base + p} : {update: {name: base + p, ...F(o)}})};
  const r = await fetch(`http://${H}/v1/projects/${P}/databases/(default)/documents:commit`, {method:'POST', headers:h, body: JSON.stringify(body)});
  const t = await r.text(); return {s:r.status, j: t ? JSON.parse(t) : {}};
}
let pass=0, fail=0;
async function t(name, exp, fn) {
  const r = await fn(); const ok = exp ? r.s === 200 : r.s === 403;
  ok ? pass++ : fail++;
  console.log(ok ? 'PASS' : 'FAIL', exp ? 'allow' : 'deny ', 'http=' + r.s, name, ok ? '' : JSON.stringify(r.j).slice(0,160));
  return r;
}
const pa = n => ({nombre:n, asistencia:'tal_vez'});
const cfg = (o={}) => ({inscripcion_abierta:true, sorteado:false, revelado:false, presupuesto_centavos:25000, fecha:null, ...o});
async function sembrar(c = cfg()) {
  await fetch(`http://${H}/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  for (const [p,o] of [['admins/admin1',{nota:'organizador'}],['participantes/u1',pa('Ana')],['participantes/u2',pa('Beto')],['participantes/admin1',pa('Admin')],
    ['config/intercambio', c]]) {
    const r = await set(p, OWNER, o); if (r.s!==200) throw new Error('seed '+p+' '+r.s);
  }
}
(async () => {
  // ---------- inscripción abierta
  await sembrar();
  await t('u1 se inscribe con 2 deseos', true, () => set('intercambio_inscritos/u1', U1, {deseos:['Libro','Taza']}));
  await t('u1 edita sus deseos', true, () => set('intercambio_inscritos/u1', U1, {deseos:['Bufanda']}));
  await t('u1 sin deseos (lista vacía)', true, () => set('intercambio_inscritos/u1', U1, {deseos:[]}));
  await t('u1 con 3 deseos', true, () => set('intercambio_inscritos/u1', U1, {deseos:['a','b','c']}));
  await t('u1 con deseo de exactamente 80 caracteres', true, () => set('intercambio_inscritos/u1', U1, {deseos:['x'.repeat(80)]}));
  await t('u2 lee la lista de deseos de u1', true, () => get('intercambio_inscritos/u1', U2));
  await t('u1 lee todos los inscritos (colección)', true, () => get('intercambio_inscritos', U1));
  await t('u2 edita deseos de u1', false, () => set('intercambio_inscritos/u1', U2, {deseos:['hackeado']}));
  await t('u2 borra inscripción de u1', false, () => del('intercambio_inscritos/u1', U2));
  await t('admin edita deseos de u1 (no es su documento)', false, () => set('intercambio_inscritos/u1', ADMIN, {deseos:['x']}));
  await t('u3 (sin documento de participante) se inscribe', false, () => set('intercambio_inscritos/u3', U3, {deseos:['a']}));
  await t('u1 con 4 deseos', false, () => set('intercambio_inscritos/u1', U1, {deseos:['a','b','c','d']}));
  await t('u1 con deseo de 81 caracteres', false, () => set('intercambio_inscritos/u1', U1, {deseos:['x'.repeat(81)]}));
  await t('u1 con deseo vacío', false, () => set('intercambio_inscritos/u1', U1, {deseos:['']}));
  await t('u1 con deseo que no es texto', false, () => set('intercambio_inscritos/u1', U1, {deseos:[5]}));
  await t('u1 deseos no es lista', false, () => set('intercambio_inscritos/u1', U1, {deseos:'libro'}));
  await t('u1 con clave extra', false, () => set('intercambio_inscritos/u1', U1, {deseos:[], extra:1}));
  await t('u1 sin clave deseos', false, () => set('intercambio_inscritos/u1', U1, {}));
  await t('anon lee inscritos', false, () => get('intercambio_inscritos/u1'));
  await t('anon se inscribe', false, () => set('intercambio_inscritos/u1', null, {deseos:[]}));
  await t('u1 sale del intercambio (abierta)', true, () => del('intercambio_inscritos/u1', U1));

  // ---------- configuración
  await t('anon lee config', false, () => get('config/intercambio'));
  await t('u1 lee config', true, () => get('config/intercambio', U1));
  await t('u1 escribe config', false, () => set('config/intercambio', U1, cfg({presupuesto_centavos:1})));
  await t('u1 borra config', false, () => del('config/intercambio', U1));
  await t('admin actualiza presupuesto y fecha', true, () => set('config/intercambio', ADMIN, cfg({presupuesto_centavos:30000, fecha:new Date('2026-12-18T19:00:00Z')})));
  await t('admin quita la fecha (null)', true, () => set('config/intercambio', ADMIN, cfg()));
  await t('admin presupuesto negativo', false, () => set('config/intercambio', ADMIN, cfg({presupuesto_centavos:-1})));
  await t('admin presupuesto sobre el máximo', false, () => set('config/intercambio', ADMIN, cfg({presupuesto_centavos:10000001})));
  await t('admin presupuesto decimal', false, () => set('config/intercambio', ADMIN, cfg({presupuesto_centavos:10.5})));
  await t('admin bool como string', false, () => set('config/intercambio', ADMIN, cfg({revelado:'si'})));
  await t('admin config sin clave fecha', false, () => { const c = cfg(); delete c.fecha; return set('config/intercambio', ADMIN, c); });
  await t('admin config con clave extra', false, () => set('config/intercambio', ADMIN, cfg({otra:1})));
  await t('admin fecha string', false, () => set('config/intercambio', ADMIN, cfg({fecha:'mañana'})));
  await t('admin borra config', false, () => del('config/intercambio', ADMIN));
  await t('config con otro id (config/otra) denegado', false, () => set('config/otra', ADMIN, cfg()));

  // ---------- sorteo (batch del admin)
  await set('intercambio_inscritos/u1', OWNER, {deseos:['Libro']});
  await set('intercambio_inscritos/u2', OWNER, {deseos:['Taza']});
  await t('admin hace el sorteo en un batch', true, () => commit(ADMIN, [
    ['intercambio_asignaciones/u1', {destinatario_id:'u2'}],
    ['intercambio_asignaciones/u2', {destinatario_id:'u1'}],
    ['config/intercambio', cfg({sorteado:true, inscripcion_abierta:false})],
  ]));
  await t('u1 intenta escribir asignaciones en batch', false, () => commit(U1, [['intercambio_asignaciones/u1', {destinatario_id:'u2'}]]));
  await t('u1 escribe su asignación', false, () => set('intercambio_asignaciones/u1', U1, {destinatario_id:'u2'}));
  await t('admin: asignación a sí mismo', false, () => set('intercambio_asignaciones/u1', ADMIN, {destinatario_id:'u1'}));
  await t('admin: asignación con clave extra', false, () => set('intercambio_asignaciones/u1', ADMIN, {destinatario_id:'u2', x:1}));
  await t('admin: destinatario vacío', false, () => set('intercambio_asignaciones/u1', ADMIN, {destinatario_id:''}));
  await t('admin: destinatario no texto', false, () => set('intercambio_asignaciones/u1', ADMIN, {destinatario_id:3}));
  await t('u1 lee su asignación', true, () => get('intercambio_asignaciones/u1', U1));
  await t('u1 lee la asignación de u2 antes de revelar', false, () => get('intercambio_asignaciones/u2', U1));
  await t('u1 lista todas las asignaciones antes de revelar', false, () => get('intercambio_asignaciones', U1));
  await t('admin lee la asignación de u2 (aceptado)', true, () => get('intercambio_asignaciones/u2', ADMIN));
  await t('anon lee asignación', false, () => get('intercambio_asignaciones/u1'));
  await t('u1 se inscribe tras el sorteo', false, () => set('intercambio_inscritos/u1', U1, {deseos:['nuevo']}));
  await t('u1 edita deseos tras el sorteo', false, () => set('intercambio_inscritos/u1', U1, {deseos:['otro']}));
  await t('u1 sale tras el sorteo', false, () => del('intercambio_inscritos/u1', U1));
  await t('admin rehace sorteo (borra y reescribe)', true, () => commit(ADMIN, [
    ['intercambio_asignaciones/u1', {destinatario_id:'u2'}],
    ['intercambio_asignaciones/u2', {destinatario_id:'u1'}],
    ['config/intercambio', cfg({sorteado:true, inscripcion_abierta:false})],
  ]));
  await t('admin borra una asignación', true, () => del('intercambio_asignaciones/u2', ADMIN));
  await t('u1 borra su asignación', false, () => del('intercambio_asignaciones/u1', U1));
  await set('intercambio_asignaciones/u2', OWNER, {destinatario_id:'u1'});

  // ---------- inscripción cerrada (sin sorteo)
  await sembrar(cfg({inscripcion_abierta:false}));
  await t('u1 se inscribe con la inscripción cerrada', false, () => set('intercambio_inscritos/u1', U1, {deseos:[]}));
  await set('intercambio_inscritos/u2', OWNER, {deseos:['Taza']});
  await t('u2 edita con la inscripción cerrada', false, () => set('intercambio_inscritos/u2', U2, {deseos:['otra']}));
  await t('u2 sale con la inscripción cerrada', false, () => del('intercambio_inscritos/u2', U2));

  // ---------- sin documento de config
  await fetch(`http://${H}/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  await set('participantes/u1', OWNER, pa('Ana'));
  await t('u1 se inscribe sin config/intercambio', false, () => set('intercambio_inscritos/u1', U1, {deseos:[]}));

  // ---------- revelado
  await sembrar(cfg({inscripcion_abierta:false, sorteado:true, revelado:true}));
  await set('intercambio_asignaciones/u1', OWNER, {destinatario_id:'u2'});
  await set('intercambio_asignaciones/u2', OWNER, {destinatario_id:'u1'});
  await t('revelado: u1 lee la asignación de u2', true, () => get('intercambio_asignaciones/u2', U1));
  await t('revelado: u3 (con sesión) lee todas las asignaciones', true, () => get('intercambio_asignaciones', U3));
  await t('revelado: anon sigue sin leer', false, () => get('intercambio_asignaciones/u2'));
  await t('revelado: u1 sigue sin poder escribir asignaciones', false, () => set('intercambio_asignaciones/u1', U1, {destinatario_id:'u2'}));
  await t('revelado: u1 sigue sin poder inscribirse', false, () => set('intercambio_inscritos/u1', U1, {deseos:[]}));

  console.log(`TOTAL pass=${pass} fail=${fail}`); process.exit(fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
