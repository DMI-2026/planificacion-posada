// Prueba de las reglas de Firestore (firestore.rules) contra el emulador.
// Cómo correrla (desde la raíz del proyecto, requiere Node 18+ y firebase-tools):
//   firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/rest_rules_test.js"
// Cada línea imprime PASS/FAIL; el proceso termina con código distinto de 0 si algo falla.
// Si cambias firestore.rules o lib/core/validacion/limites.dart, vuelve a correrla.
const P = 'demo-posada', B = `http://127.0.0.1:8080/v1/projects/${P}/databases/(default)/documents`;
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const now = Math.floor(Date.now()/1000);
const TOK = b64({alg:'none',typ:'JWT'}) + '.' + b64({sub:'u1',user_id:'u1',iss:`https://securetoken.google.com/${P}`,aud:P,iat:now,exp:now+3600,auth_time:now,firebase:{sign_in_provider:'password',identities:{}}}) + '.';
const AUTH = 'Bearer ' + TOK, OWNER = 'Bearer owner';
const enc = v => v === null ? {nullValue:null} : v instanceof Date ? {timestampValue:v.toISOString()} : typeof v === 'string' ? {stringValue:v}
  : typeof v === 'boolean' ? {booleanValue:v} : Number.isInteger(v) && !(v && v.__d) ? {integerValue:String(v)} : typeof v === 'number' ? {doubleValue:v} : v;
const F = o => ({fields: Object.fromEntries(Object.entries(o).map(([k,v]) => [k, enc(v)]))});
async function req(method, path, auth, body, qs='') {
  const h = {'Content-Type':'application/json'}; if (auth) h.Authorization = auth;
  const r = await fetch(B + '/' + path + qs, {method, headers:h, body: body ? JSON.stringify(body) : undefined});
  const t = await r.text(); return {s:r.status, j: t ? JSON.parse(t) : {}};
}
const get = (p,a) => req('GET', p, a);
const set = (p,a,o) => req('PATCH', p, a, F(o));                    // setDoc / DocumentReference.set
const add = (c,a,o) => req('POST', c, a, F(o));                     // CollectionReference.add
const upd = (p,a,o,del=[]) => req('PATCH', p, a, F(o), '?' + [...Object.keys(o), ...del].map(k=>'updateMask.fieldPaths='+k).join('&') + '&currentDocument.exists=true'); // update()
const del = (p,a) => req('DELETE', p, a);
let pass=0, fail=0;
async function t(name, exp, fn) {
  const r = await fn(); const ok = exp ? r.s === 200 : r.s === 403;
  ok ? pass++ : fail++;
  console.log(ok ? 'PASS' : 'FAIL', exp ? 'allow' : 'deny ', 'http=' + r.s, name, ok ? '' : JSON.stringify(r.j).slice(0,160));
  return r;
}
(async () => {
  await fetch(`http://127.0.0.1:8080/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  const fecha = new Date('2026-12-18T19:00:00Z');
  const ev = {nombre:'Posada', fecha, lugar:'', notas:''}, pa = {nombre:'Ana', asistencia:'tal_vez'}, ap = {articulo:'Ponche', cantidad:2, responsable_id:null, lista:false};
  for (const [p,o] of [['evento/actual',ev],['participantes/p1',pa],['aportaciones/a1',ap],['otra/x',{a:1}]]) { const r = await set(p, OWNER, o); if (r.s!==200) throw new Error('seed '+p+' '+r.s); }
  for (const [p,o] of [['evento/actual',ev],['participantes/p1',pa],['aportaciones/a1',ap]]) {
    await t('anon read '+p, false, () => get(p)); await t('anon set '+p, false, () => set(p, null, o));
    await t('anon delete '+p, false, () => del(p)); await t('auth read '+p, true, () => get(p, AUTH));
  }
  await t('anon add participantes', false, () => add('participantes', null, pa));
  await t('anon list participantes', false, () => get('participantes'));
  for (const c of ['participantes','aportaciones','evento']) await t('auth list '+c, true, () => get(c, AUTH));
  // evento
  await t('evento set update existing', true, () => set('evento/actual', AUTH, {...ev, nombre:'Posada 2', lugar:'Aula', notas:'x'}));
  await del('evento/actual', OWNER);
  await t('evento set create', true, () => set('evento/actual', AUTH, ev));
  await t('evento limits 100/200/1000', true, () => set('evento/actual', AUTH, {...ev, nombre:'n'.repeat(100), lugar:'l'.repeat(200), notas:'n'.repeat(1000)}));
  await t('evento id otro', false, () => set('evento/otro', AUTH, ev));
  await t('evento add (auto id)', false, () => add('evento', AUTH, ev));
  await t('evento delete', false, () => del('evento/actual', AUTH));
  await t('evento extra key', false, () => set('evento/actual', AUTH, {...ev, x:1}));
  await t('evento missing notas', false, () => set('evento/actual', AUTH, {nombre:'a', fecha, lugar:''}));
  await t('evento fecha string', false, () => set('evento/actual', AUTH, {...ev, fecha:'2026-12-18'}));
  await t('evento nombre empty', false, () => set('evento/actual', AUTH, {...ev, nombre:''}));
  await t('evento nombre 101', false, () => set('evento/actual', AUTH, {...ev, nombre:'n'.repeat(101)}));
  await t('evento lugar 201', false, () => set('evento/actual', AUTH, {...ev, lugar:'l'.repeat(201)}));
  await t('evento notas 1001', false, () => set('evento/actual', AUTH, {...ev, notas:'n'.repeat(1001)}));
  await t('evento nombre int', false, () => set('evento/actual', AUTH, {...ev, nombre:5}));
  await t('evento update deleteField notas', false, () => upd('evento/actual', AUTH, {}, ['notas']));
  // participantes
  const r = await t('participante add toMap', true, () => add('participantes', AUTH, pa));
  const pid = r.j.name ? r.j.name.split('/').pop() : 'p1';
  for (const a of ['si','no','tal_vez']) await t('participante update asistencia='+a, true, () => upd('participantes/p1', AUTH, {asistencia:a}));
  await t('participante asistencia quizas', false, () => upd('participantes/p1', AUTH, {asistencia:'quizas'}));
  await t('participante asistencia talVez', false, () => upd('participantes/p1', AUTH, {asistencia:'talVez'}));
  await t('participante asistencia int', false, () => upd('participantes/p1', AUTH, {asistencia:1}));
  await t('participante extra key add', false, () => add('participantes', AUTH, {...pa, x:1}));
  await t('participante extra key update', false, () => upd('participantes/p1', AUTH, {x:1}));
  await t('participante missing asistencia', false, () => add('participantes', AUTH, {nombre:'A'}));
  await t('participante nombre empty', false, () => add('participantes', AUTH, {...pa, nombre:''}));
  await t('participante nombre 100', true, () => add('participantes', AUTH, {...pa, nombre:'n'.repeat(100)}));
  await t('participante nombre 101', false, () => add('participantes', AUTH, {...pa, nombre:'n'.repeat(101)}));
  await t('participante nombre bool', false, () => add('participantes', AUTH, {...pa, nombre:true}));
  await t('participante deleteField asistencia', false, () => upd('participantes/p1', AUTH, {}, ['asistencia']));
  await t('participante update nonexistent', false, () => upd('participantes/nope', AUTH, {asistencia:'si'}));
  await t('participante delete', true, () => del('participantes/'+pid, AUTH));
  // aportaciones
  const r2 = await t('aportacion add toMap (responsable_id null)', true, () => add('aportaciones', AUTH, ap));
  const aid = r2.j.name ? r2.j.name.split('/').pop() : 'a1';
  await t('aportacion asignar string', true, () => upd('aportaciones/a1', AUTH, {responsable_id:'p1'}));
  await t('aportacion asignar null', true, () => upd('aportaciones/a1', AUTH, {responsable_id:null}));
  await t('aportacion marcarLista true', true, () => upd('aportaciones/a1', AUTH, {lista:true}));
  await t('aportacion marcarLista false', true, () => upd('aportaciones/a1', AUTH, {lista:false}));
  await t('aportacion cantidad 1', true, () => add('aportaciones', AUTH, {...ap, cantidad:1}));
  await t('aportacion cantidad 999', true, () => add('aportaciones', AUTH, {...ap, cantidad:999}));
  await t('aportacion cantidad 0', false, () => add('aportaciones', AUTH, {...ap, cantidad:0}));
  await t('aportacion cantidad 1000', false, () => add('aportaciones', AUTH, {...ap, cantidad:1000}));
  await t('aportacion cantidad -1', false, () => add('aportaciones', AUTH, {...ap, cantidad:-1}));
  await t('aportacion cantidad double 2.5', false, () => add('aportaciones', AUTH, {...ap, cantidad:2.5}));
  await t('aportacion cantidad doubleValue 2.0', false, () => add('aportaciones', AUTH, {...ap, cantidad:{doubleValue:2}}));
  await t('aportacion cantidad "2"', false, () => add('aportaciones', AUTH, {...ap, cantidad:'2'}));
  await t('aportacion extra key', false, () => add('aportaciones', AUTH, {...ap, x:1}));
  await t('aportacion missing responsable_id', false, () => add('aportaciones', AUTH, {articulo:'a', cantidad:1, lista:false}));
  await t('aportacion articulo empty', false, () => add('aportaciones', AUTH, {...ap, articulo:''}));
  await t('aportacion articulo 101', false, () => add('aportaciones', AUTH, {...ap, articulo:'a'.repeat(101)}));
  await t('aportacion responsable_id int', false, () => upd('aportaciones/a1', AUTH, {responsable_id:7}));
  await t('aportacion lista string', false, () => upd('aportaciones/a1', AUTH, {lista:'true'}));
  await t('aportacion update cantidad 0', false, () => upd('aportaciones/a1', AUTH, {cantidad:0}));
  await t('aportacion deleteField lista', false, () => upd('aportaciones/a1', AUTH, {}, ['lista']));
  await t('aportacion delete', true, () => del('aportaciones/'+aid, AUTH));
  // unknown
  await t('unknown read otra/x', false, () => get('otra/x', AUTH));
  await t('unknown write otra/y', false, () => set('otra/y', AUTH, {a:1}));
  await t('subcollection participantes/p1/sub/z', false, () => set('participantes/p1/sub/z', AUTH, {a:1}));
  await t('old prefix posada_participantes', false, () => set('posada_participantes/z', AUTH, pa));
  console.log(`TOTAL pass=${pass} fail=${fail}`); process.exit(fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
