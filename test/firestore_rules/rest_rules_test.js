// Prueba de las reglas de Firestore (firestore.rules) contra el emulador.
// Cómo correrla (desde la raíz del proyecto, requiere Node 18+ y firebase-tools):
//   firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/rest_rules_test.js"
// Usa FIRESTORE_EMULATOR_HOST (host:puerto) si existe (emulators:exec lo define); si no, 127.0.0.1:8080.
// Roles: admin1 (tiene admins/admin1), u1 y u2 (usuarios normales). Ver "Cómo nombrar admin" en docs/como-correr.md.
// Cada línea imprime PASS/FAIL; el proceso termina con código distinto de 0 si algo falla.
// Si cambias firestore.rules o lib/core/validacion/limites.dart, vuelve a correrla.
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
const fecha = new Date('2026-12-18T19:00:00Z');
const ev = {nombre:'Posada', fecha, lugar:'', notas:''};
const pa = n => ({nombre:n, asistencia:'tal_vez'});
const ap = (resp=null, lista=false) => ({articulo:'Ponche', cantidad:2, responsable_id:resp, lista});
// Estado inicial: admin1 es admin; u1, u2 y admin1 están registrados; a1 libre, a2 de u1, a3 de u2.
async function sembrar() {
  await fetch(`http://${H}/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  for (const [p,o] of [['admins/admin1',{nota:'organizador'}],['evento/actual',ev],['participantes/u1',pa('Ana')],['participantes/u2',pa('Beto')],['participantes/admin1',pa('Admin')],
    ['aportaciones/a1',ap()],['aportaciones/a2',ap('u1')],['aportaciones/a3',ap('u2')],['otra/x',{a:1}]]) {
    const r = await set(p, OWNER, o); if (r.s!==200) throw new Error('seed '+p+' '+r.s);
  }
}
(async () => {
  await sembrar();
  // --- sin sesión: todo denegado
  for (const [p,o] of [['evento/actual',ev],['participantes/u1',pa('Ana')],['aportaciones/a1',ap()],['admins/admin1',{}]]) {
    await t('anon read '+p, false, () => get(p)); await t('anon set '+p, false, () => set(p, null, o));
    await t('anon delete '+p, false, () => del(p));
  }
  await t('anon list participantes', false, () => get('participantes'));
  for (const [p] of [['evento/actual'],['participantes/u1'],['aportaciones/a1']]) await t('auth read '+p, true, () => get(p, U1));
  for (const c of ['participantes','aportaciones','evento']) await t('auth list '+c, true, () => get(c, U1));

  // --- admins
  await t('admins: u1 lee su propio doc (no existe) -> permitido', true, () => get('admins/u1', U1).then(r => ({...r, s: r.s === 404 ? 200 : r.s})));
  await t('admins: admin lee su doc', true, () => get('admins/admin1', ADMIN));
  await t('admins: u1 lee el doc de admin1', false, () => get('admins/admin1', U1));
  await t('admins: u1 lista la colección', false, () => get('admins', U1));
  await t('admins: admin lista la colección', false, () => get('admins', ADMIN));
  await t('admins: u1 se crea admins/u1', false, () => set('admins/u1', U1, {}));
  await t('admins: admin crea admins/u1', false, () => set('admins/u1', ADMIN, {}));
  await t('admins: admin edita su doc', false, () => set('admins/admin1', ADMIN, {nota:'x'}));
  await t('admins: admin borra su doc', false, () => del('admins/admin1', ADMIN));

  // --- evento: solo admin
  await t('evento: admin actualiza', true, () => set('evento/actual', ADMIN, {...ev, nombre:'Posada 2', lugar:'Aula', notas:'x'}));
  await t('evento: no admin edita', false, () => set('evento/actual', U1, {...ev, nombre:'Hack'}));
  await t('evento: no admin crea (doc inexistente)', false, async () => { await del('evento/actual', OWNER); return set('evento/actual', U1, ev); });
  await t('evento: admin crea', true, () => set('evento/actual', ADMIN, ev));
  await t('evento: admin limits 100/200/1000', true, () => set('evento/actual', ADMIN, {...ev, nombre:'n'.repeat(100), lugar:'l'.repeat(200), notas:'n'.repeat(1000)}));
  await t('evento: admin id otro', false, () => set('evento/otro', ADMIN, ev));
  await t('evento: admin add (auto id)', false, () => add('evento', ADMIN, ev));
  await t('evento: admin delete', false, () => del('evento/actual', ADMIN));
  await t('evento: no admin delete', false, () => del('evento/actual', U1));
  await t('evento: extra key', false, () => set('evento/actual', ADMIN, {...ev, x:1}));
  await t('evento: missing notas', false, () => set('evento/actual', ADMIN, {nombre:'a', fecha, lugar:''}));
  await t('evento: fecha string', false, () => set('evento/actual', ADMIN, {...ev, fecha:'2026-12-18'}));
  await t('evento: nombre empty', false, () => set('evento/actual', ADMIN, {...ev, nombre:''}));
  await t('evento: nombre 101', false, () => set('evento/actual', ADMIN, {...ev, nombre:'n'.repeat(101)}));
  await t('evento: lugar 201', false, () => set('evento/actual', ADMIN, {...ev, lugar:'l'.repeat(201)}));
  await t('evento: notas 1001', false, () => set('evento/actual', ADMIN, {...ev, notas:'n'.repeat(1001)}));
  await t('evento: nombre int', false, () => set('evento/actual', ADMIN, {...ev, nombre:5}));
  await t('evento: update deleteField notas', false, () => upd('evento/actual', ADMIN, {}, ['notas']));

  // --- participantes
  await sembrar();
  await del('participantes/u1', OWNER);
  await t('participante: u1 se crea su doc (asegurar)', true, () => set('participantes/u1', U1, pa('Ana')));
  await t('participante: u1 crea el doc de u2 (suplantar)', false, async () => { await del('participantes/u2', OWNER); return set('participantes/u2', U1, pa('Beto')); });
  await t('participante: u2 se crea su doc', true, () => set('participantes/u2', U2, pa('Beto')));
  await t('participante: add con id automático', false, () => add('participantes', U1, pa('Ana')));
  await t('participante: nombre 100', true, async () => { await del('participantes/u1', OWNER); return set('participantes/u1', U1, pa('n'.repeat(100))); });
  await t('participante: nombre 101', false, async () => { await del('participantes/u1', OWNER); return set('participantes/u1', U1, pa('n'.repeat(101))); });
  await t('participante: nombre vacío', false, () => set('participantes/u1', U1, pa('')));
  await t('participante: nombre bool', false, () => set('participantes/u1', U1, {nombre:true, asistencia:'si'}));
  await t('participante: clave extra (correo)', false, () => set('participantes/u1', U1, {...pa('Ana'), correo:'a@b.mx'}));
  await t('participante: sin asistencia', false, () => set('participantes/u1', U1, {nombre:'A'}));
  await t('participante: asistencia inválida al crear', false, () => set('participantes/u1', U1, {nombre:'A', asistencia:'quizas'}));
  await sembrar();
  for (const a of ['si','no','tal_vez']) await t('participante: u1 cambia su asistencia='+a, true, () => upd('participantes/u1', U1, {asistencia:a}));
  await t('participante: u1 cambia la de u2', false, () => upd('participantes/u2', U1, {asistencia:'si'}));
  await t('participante: u1 cambia la del admin', false, () => upd('participantes/admin1', U1, {asistencia:'si'}));
  await t('participante: admin cambia la de u1', true, () => upd('participantes/u1', ADMIN, {asistencia:'no'}));
  await t('participante: admin cambia la suya', true, () => upd('participantes/admin1', ADMIN, {asistencia:'si'}));
  await t('participante: u1 cambia su nombre', false, () => upd('participantes/u1', U1, {nombre:'Otro'}));
  await t('participante: admin cambia nombre de u1', false, () => upd('participantes/u1', ADMIN, {nombre:'Otro'}));
  await t('participante: u1 asistencia quizas', false, () => upd('participantes/u1', U1, {asistencia:'quizas'}));
  await t('participante: u1 asistencia talVez', false, () => upd('participantes/u1', U1, {asistencia:'talVez'}));
  await t('participante: u1 asistencia int', false, () => upd('participantes/u1', U1, {asistencia:1}));
  await t('participante: u1 clave extra al actualizar', false, () => upd('participantes/u1', U1, {x:1}));
  await t('participante: u1 deleteField asistencia', false, () => upd('participantes/u1', U1, {}, ['asistencia']));
  await t('participante: update inexistente', false, () => upd('participantes/nope', ADMIN, {asistencia:'si'}));
  await t('participante: u1 borra el suyo', false, () => del('participantes/u1', U1));
  await t('participante: u1 borra el de u2', false, () => del('participantes/u2', U1));
  await t('participante: admin quita a u2', true, () => del('participantes/u2', ADMIN));
  await t('participante: admin borra inexistente no falla por reglas', true, () => del('participantes/u2', ADMIN));

  // --- aportaciones
  await sembrar();
  // crear
  await t('aportacion: u1 agrega libre (toMap)', true, () => add('aportaciones', U1, ap()));
  await t('aportacion: u1 agrega a su nombre', true, () => add('aportaciones', U1, ap('u1')));
  await t('aportacion: u1 agrega asignada a u2', false, () => add('aportaciones', U1, ap('u2')));
  await t('aportacion: u1 agrega ya lista', false, () => add('aportaciones', U1, ap(null, true)));
  await t('aportacion: admin agrega ya lista', true, () => add('aportaciones', ADMIN, ap(null, true)));
  await t('aportacion: admin agrega a nombre de u2', false, () => add('aportaciones', ADMIN, ap('u2')));
  await t('aportacion: cantidad 1', true, () => add('aportaciones', U1, {...ap(), cantidad:1}));
  await t('aportacion: cantidad 999', true, () => add('aportaciones', U1, {...ap(), cantidad:999}));
  for (const [n,v] of [['0',0],['1000',1000],['-1',-1],['2.5',2.5],['doubleValue 2.0',{doubleValue:2}],['"2"','2']]) await t('aportacion: cantidad '+n, false, () => add('aportaciones', U1, {...ap(), cantidad:v}));
  await t('aportacion: clave extra', false, () => add('aportaciones', U1, {...ap(), x:1}));
  await t('aportacion: sin responsable_id', false, () => add('aportaciones', U1, {articulo:'a', cantidad:1, lista:false}));
  await t('aportacion: artículo vacío', false, () => add('aportaciones', U1, {...ap(), articulo:''}));
  await t('aportacion: artículo 100', true, () => add('aportaciones', U1, {...ap(), articulo:'a'.repeat(100)}));
  await t('aportacion: artículo 101', false, () => add('aportaciones', U1, {...ap(), articulo:'a'.repeat(101)}));
  // asignar / desasignar (no admin)
  await t('aportacion: u1 se asigna la libre a1', true, () => upd('aportaciones/a1', U1, {responsable_id:'u1'}));
  await t('aportacion: u1 se quita de a1', true, () => upd('aportaciones/a1', U1, {responsable_id:null}));
  await t('aportacion: u1 asigna la libre a1 a u2', false, () => upd('aportaciones/a1', U1, {responsable_id:'u2'}));
  await t('aportacion: u1 roba a3 (de u2)', false, () => upd('aportaciones/a3', U1, {responsable_id:'u1'}));
  await t('aportacion: u1 quita a u2 de a3', false, () => upd('aportaciones/a3', U1, {responsable_id:null}));
  await t('aportacion: u1 reasigna su a2 a u2', false, () => upd('aportaciones/a2', U1, {responsable_id:'u2'}));
  await t('aportacion: responsable_id int', false, () => upd('aportaciones/a1', U1, {responsable_id:7}));
  // lista (no admin)
  await t('aportacion: u1 marca lista la suya (a2)', true, () => upd('aportaciones/a2', U1, {lista:true}));
  await t('aportacion: u1 desmarca lista la suya (a2)', true, () => upd('aportaciones/a2', U1, {lista:false}));
  await t('aportacion: u1 marca lista la libre a1', false, () => upd('aportaciones/a1', U1, {lista:true}));
  await t('aportacion: u1 marca lista la de u2 (a3)', false, () => upd('aportaciones/a3', U1, {lista:true}));
  await t('aportacion: u1 asigna y marca a la vez a1 (suya al terminar)', true, () => upd('aportaciones/a1', U1, {responsable_id:'u1', lista:true}));
  await t('aportacion: u1 se quita y desmarca a la vez (lista cambia, queda libre)', false, () => upd('aportaciones/a1', U1, {responsable_id:null, lista:false}));
  await t('aportacion: u1 se quita de a1 dejando lista', true, () => upd('aportaciones/a1', U1, {responsable_id:null}));
  await t('aportacion: lista string', false, () => upd('aportaciones/a2', U1, {lista:'true'}));
  // campos protegidos
  await t('aportacion: u1 cambia cantidad de la suya', false, () => upd('aportaciones/a2', U1, {cantidad:5}));
  await t('aportacion: u1 cambia artículo de la suya', false, () => upd('aportaciones/a2', U1, {articulo:'Otro'}));
  await t('aportacion: u1 cambia cantidad y marca', false, () => upd('aportaciones/a2', U1, {cantidad:5, lista:true}));
  await t('aportacion: deleteField lista', false, () => upd('aportaciones/a2', U1, {}, ['lista']));
  // admin
  await t('aportacion: admin asigna a1 a u2', true, () => upd('aportaciones/a1', ADMIN, {responsable_id:'u2'}));
  await t('aportacion: admin reasigna a3 (de u2) a u1', true, () => upd('aportaciones/a3', ADMIN, {responsable_id:'u1'}));
  await t('aportacion: admin quita responsable de a3', true, () => upd('aportaciones/a3', ADMIN, {responsable_id:null}));
  await t('aportacion: admin marca lista cualquiera (a1)', true, () => upd('aportaciones/a1', ADMIN, {lista:true}));
  await t('aportacion: admin desmarca lista (a1)', true, () => upd('aportaciones/a1', ADMIN, {lista:false}));
  await t('aportacion: admin cantidad 0', false, () => upd('aportaciones/a1', ADMIN, {cantidad:0}));
  await t('aportacion: admin cantidad 7 válido', true, () => upd('aportaciones/a1', ADMIN, {cantidad:7}));
  await t('aportacion: admin deleteField lista', false, () => upd('aportaciones/a1', ADMIN, {}, ['lista']));
  // borrar
  await t('aportacion: u1 borra la suya', false, () => del('aportaciones/a2', U1));
  await t('aportacion: u1 borra la de u2', false, () => del('aportaciones/a3', U1));
  await t('aportacion: admin borra', true, () => del('aportaciones/a2', ADMIN));

  // --- ruta desconocida
  await t('unknown read otra/x', false, () => get('otra/x', ADMIN));
  await t('unknown write otra/y', false, () => set('otra/y', ADMIN, {a:1}));
  await t('subcollection participantes/u1/sub/z', false, () => set('participantes/u1/sub/z', U1, {a:1}));
  await t('old prefix posada_participantes', false, () => set('posada_participantes/z', ADMIN, pa('A')));
  console.log(`TOTAL pass=${pass} fail=${fail}`); process.exit(fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
