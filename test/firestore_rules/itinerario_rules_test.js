// Prueba del bloque de reglas del itinerario (lib/features/itinerario/itinerario.rules) ya insertado en firestore.rules.
// Cómo correrla (desde la raíz del proyecto, requiere Node 18+ y firebase-tools):
//   firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/itinerario_rules_test.js"
// Usa FIRESTORE_EMULATOR_HOST (host:puerto) si existe (emulators:exec lo define); si no, 127.0.0.1:8080.
// Roles: admin1 (tiene admins/admin1), u1 y u2 (usuarios normales). Ver "Cómo nombrar admin" en docs/como-correr.md.
// Cada línea imprime PASS/FAIL; el proceso termina con código distinto de 0 si algo falla.
// Si cambias itinerario.rules o LimitesItinerario, vuelve a correrla.
const P = 'demo-posada', H = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080', B = `http://${H}/v1/projects/${P}/databases/(default)/documents`;
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const now = Math.floor(Date.now()/1000);
const tok = uid => 'Bearer ' + b64({alg:'none',typ:'JWT'}) + '.' + b64({sub:uid,user_id:uid,iss:`https://securetoken.google.com/${P}`,aud:P,iat:now,exp:now+3600,auth_time:now,firebase:{sign_in_provider:'password',identities:{}}}) + '.';
const U1 = tok('u1'), U2 = tok('u2'), ADMIN = tok('admin1'), OWNER = 'Bearer owner';
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
const inicio = new Date('2026-12-24T19:00:00Z');
const it = (o = {}) => ({titulo:'Piñata', descripcion:'', inicio, duracion_min:30, responsable_id:null, ...o});
async function sembrar() {
  await fetch(`http://${H}/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  for (const [p,o] of [['admins/admin1',{nota:'organizador'}],['participantes/u1',{nombre:'Ana',asistencia:'si'}],['participantes/admin1',{nombre:'Admin',asistencia:'si'}],['itinerario/i1',it()]]) {
    const r = await set(p, OWNER, o); if (r.s!==200) throw new Error('seed '+p+' '+r.s);
  }
}
(async () => {
  await sembrar();
  // lectura
  await t('anon get', false, () => get('itinerario/i1'));
  await t('anon list', false, () => get('itinerario'));
  await t('u1 get', true, () => get('itinerario/i1', U1));
  await t('u1 list', true, () => get('itinerario', U1));
  await t('admin get', true, () => get('itinerario/i1', ADMIN));
  // no admin: nada de escritura
  await t('u1 create', false, () => set('itinerario/n1', U1, it()));
  await t('u1 add', false, () => add('itinerario', U1, it()));
  await t('u1 update', false, () => set('itinerario/i1', U1, it({titulo:'Hack'})));
  await t('u1 delete', false, () => del('itinerario/i1', U1));
  await t('anon create', false, () => set('itinerario/n1', null, it()));
  await t('anon delete', false, () => del('itinerario/i1'));
  // admin
  await t('admin create (set id)', true, () => set('itinerario/n1', ADMIN, it()));
  await t('admin add (auto id)', true, () => add('itinerario', ADMIN, it({titulo:'Cena'})));
  await t('admin update', true, () => set('itinerario/n1', ADMIN, it({titulo:'Nuevo', descripcion:'d', duracion_min:90})));
  await t('admin responsable existente (u1)', true, () => set('itinerario/n1', ADMIN, it({responsable_id:'u1'})));
  await t('admin limites 80/500/5', true, () => set('itinerario/n2', ADMIN, it({titulo:'t'.repeat(80), descripcion:'d'.repeat(500), duracion_min:5})));
  await t('admin duracion 600', true, () => set('itinerario/n2', ADMIN, it({duracion_min:600})));
  await t('admin delete', true, () => del('itinerario/n2', ADMIN));
  // forma, límites y tipos
  await t('extra key', false, () => set('itinerario/n3', ADMIN, {...it(), x:1}));
  await t('missing descripcion', false, () => { const o = it(); delete o.descripcion; return set('itinerario/n3', ADMIN, o); });
  await t('missing responsable_id', false, () => { const o = it(); delete o.responsable_id; return set('itinerario/n3', ADMIN, o); });
  await t('titulo vacío', false, () => set('itinerario/n3', ADMIN, it({titulo:''})));
  await t('titulo 81', false, () => set('itinerario/n3', ADMIN, it({titulo:'t'.repeat(81)})));
  await t('titulo int', false, () => set('itinerario/n3', ADMIN, it({titulo:5})));
  await t('descripcion 501', false, () => set('itinerario/n3', ADMIN, it({descripcion:'d'.repeat(501)})));
  await t('descripcion int', false, () => set('itinerario/n3', ADMIN, it({descripcion:1})));
  await t('inicio string', false, () => set('itinerario/n3', ADMIN, it({inicio:'2026-12-24'})));
  await t('duracion 4', false, () => set('itinerario/n3', ADMIN, it({duracion_min:4})));
  await t('duracion 601', false, () => set('itinerario/n3', ADMIN, it({duracion_min:601})));
  await t('duracion double', false, () => set('itinerario/n3', ADMIN, it({duracion_min:30.5})));
  await t('duracion string', false, () => set('itinerario/n3', ADMIN, it({duracion_min:'30'})));
  await t('responsable no participante', false, () => set('itinerario/n3', ADMIN, it({responsable_id:'ghost'})));
  await t('responsable int', false, () => set('itinerario/n3', ADMIN, it({responsable_id:7})));
  await t('update inválido (responsable fantasma)', false, () => set('itinerario/i1', ADMIN, it({responsable_id:'ghost'})));
  await t('subcolección denegada', false, () => set('itinerario/i1/sub/z', ADMIN, {a:1}));
  console.log(`TOTAL pass=${pass} fail=${fail}`); process.exit(fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
