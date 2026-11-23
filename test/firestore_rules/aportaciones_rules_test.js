// Prueba de las reglas de aportaciones (material y económicas) y de
// config/aportaciones contra el emulador de Firestore.
// Reglas a probar: el bloque de lib/features/aportaciones/aportaciones.rules
// ya integrado en firestore.rules (o una copia de scratch con el bloque).
//   firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/aportaciones_rules_test.js"
// Usa FIRESTORE_EMULATOR_HOST (host:puerto) si existe; si no, 127.0.0.1:8080.
// Roles: admin1 (tiene admins/admin1), u1 y u2 (usuarios normales); ghost no es participante.
// Cada línea imprime PASS/FAIL; el proceso termina con código distinto de 0 si algo falla.
// Los límites deben coincidir con lib/features/aportaciones/utils/dinero.dart.
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

const mat = (resp=null, lista=false) => ({tipo:'material', articulo:'Ponche', cantidad:2, responsable_id:resp, lista});
const legacy = (resp=null, lista=false) => ({articulo:'Ponche', cantidad:2, responsable_id:resp, lista});
const eco = (resp, monto=5000, recibido=false) => ({tipo:'economica', responsable_id:resp, monto_centavos:monto, recibido});
const pa = n => ({nombre:n, asistencia:'tal_vez'});
// Estado: admin1 admin; u1, u2, admin1 participantes. m1 libre, m2 de u1, m3 de u2, l1 legado de u1,
// e1 económica de u1 sin recibir, e2 económica de u2 sin recibir, e3 de u1 ya recibida.
async function sembrar() {
  await fetch(`http://${H}/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  for (const [p,o] of [['admins/admin1',{nota:'organizador'}],['participantes/u1',pa('Ana')],['participantes/u2',pa('Beto')],['participantes/admin1',pa('Admin')],
    ['aportaciones/m1',mat()],['aportaciones/m2',mat('u1')],['aportaciones/m3',mat('u2')],['aportaciones/l1',legacy('u1')],
    ['aportaciones/e1',eco('u1')],['aportaciones/e2',eco('u2')],['aportaciones/e3',eco('u1',7000,true)],
    ['config/aportaciones',{meta_centavos:100000}]]) {
    const r = await set(p, OWNER, o); if (r.s!==200) throw new Error('seed '+p+' '+r.s);
  }
}
(async () => {
  await sembrar();
  // --- sin sesión
  for (const p of ['aportaciones/m1','aportaciones/e1','config/aportaciones']) {
    await t('anon read '+p, false, () => get(p)); await t('anon delete '+p, false, () => del(p));
  }
  await t('anon create económica', false, () => add('aportaciones', null, eco('u1')));
  await t('auth read económica', true, () => get('aportaciones/e1', U1));
  await t('auth read config', true, () => get('config/aportaciones', U1));
  await t('auth list aportaciones', true, () => get('aportaciones', U1));

  // === MATERIAL (mismos casos que rest_rules_test.js, con y sin `tipo`) ===
  for (const [etq, ap] of [['con tipo', mat], ['sin tipo (legado)', legacy]]) {
    await sembrar();
    await t(`material ${etq}: u1 agrega libre`, true, () => add('aportaciones', U1, ap()));
    await t(`material ${etq}: u1 agrega a su nombre`, true, () => add('aportaciones', U1, ap('u1')));
    await t(`material ${etq}: u1 agrega asignada a u2`, false, () => add('aportaciones', U1, ap('u2')));
    await t(`material ${etq}: u1 agrega ya lista`, false, () => add('aportaciones', U1, ap(null, true)));
    await t(`material ${etq}: admin agrega ya lista`, true, () => add('aportaciones', ADMIN, ap(null, true)));
    await t(`material ${etq}: admin agrega a nombre de u2`, false, () => add('aportaciones', ADMIN, ap('u2')));
    await t(`material ${etq}: cantidad 1`, true, () => add('aportaciones', U1, {...ap(), cantidad:1}));
    await t(`material ${etq}: cantidad 999`, true, () => add('aportaciones', U1, {...ap(), cantidad:999}));
    for (const [n,v] of [['0',0],['1000',1000],['-1',-1],['2.5',2.5],['doubleValue 2.0',{doubleValue:2}],['"2"','2']]) await t(`material ${etq}: cantidad ${n}`, false, () => add('aportaciones', U1, {...ap(), cantidad:v}));
    await t(`material ${etq}: clave extra`, false, () => add('aportaciones', U1, {...ap(), x:1}));
    await t(`material ${etq}: sin responsable_id`, false, () => add('aportaciones', U1, {articulo:'a', cantidad:1, lista:false}));
    await t(`material ${etq}: artículo vacío`, false, () => add('aportaciones', U1, {...ap(), articulo:''}));
    await t(`material ${etq}: artículo 100`, true, () => add('aportaciones', U1, {...ap(), articulo:'a'.repeat(100)}));
    await t(`material ${etq}: artículo 101`, false, () => add('aportaciones', U1, {...ap(), articulo:'a'.repeat(101)}));
  }
  await sembrar();
  await t('material: tipo desconocido', false, () => add('aportaciones', U1, {...mat(), tipo:'otro'}));
  await t('material: tipo económica con claves de material', false, () => add('aportaciones', U1, {...mat(), tipo:'economica'}));
  await t('material: u1 se asigna la libre m1', true, () => upd('aportaciones/m1', U1, {responsable_id:'u1'}));
  await t('material: u1 se quita de m1', true, () => upd('aportaciones/m1', U1, {responsable_id:null}));
  await t('material: u1 asigna la libre m1 a u2', false, () => upd('aportaciones/m1', U1, {responsable_id:'u2'}));
  await t('material: u1 roba m3 (de u2)', false, () => upd('aportaciones/m3', U1, {responsable_id:'u1'}));
  await t('material: u1 quita a u2 de m3', false, () => upd('aportaciones/m3', U1, {responsable_id:null}));
  await t('material: u1 reasigna su m2 a u2', false, () => upd('aportaciones/m2', U1, {responsable_id:'u2'}));
  await t('material: responsable_id int', false, () => upd('aportaciones/m1', U1, {responsable_id:7}));
  await t('material: u1 marca lista la suya (m2)', true, () => upd('aportaciones/m2', U1, {lista:true}));
  await t('material: u1 desmarca lista la suya (m2)', true, () => upd('aportaciones/m2', U1, {lista:false}));
  await t('material: u1 marca lista la libre m1', false, () => upd('aportaciones/m1', U1, {lista:true}));
  await t('material: u1 marca lista la de u2 (m3)', false, () => upd('aportaciones/m3', U1, {lista:true}));
  await t('material: u1 asigna y marca a la vez m1', true, () => upd('aportaciones/m1', U1, {responsable_id:'u1', lista:true}));
  await t('material: u1 se quita y desmarca a la vez', false, () => upd('aportaciones/m1', U1, {responsable_id:null, lista:false}));
  await t('material: u1 se quita de m1 dejando lista', true, () => upd('aportaciones/m1', U1, {responsable_id:null}));
  await t('material: lista string', false, () => upd('aportaciones/m2', U1, {lista:'true'}));
  await t('material: u1 cambia cantidad de la suya', false, () => upd('aportaciones/m2', U1, {cantidad:5}));
  await t('material: u1 cambia artículo de la suya', false, () => upd('aportaciones/m2', U1, {articulo:'Otro'}));
  await t('material: u1 cambia cantidad y marca', false, () => upd('aportaciones/m2', U1, {cantidad:5, lista:true}));
  await t('material: deleteField lista', false, () => upd('aportaciones/m2', U1, {}, ['lista']));
  await t('material: admin asigna m1 a u2', true, () => upd('aportaciones/m1', ADMIN, {responsable_id:'u2'}));
  await t('material: admin reasigna m3 a u1', true, () => upd('aportaciones/m3', ADMIN, {responsable_id:'u1'}));
  await t('material: admin quita responsable de m3', true, () => upd('aportaciones/m3', ADMIN, {responsable_id:null}));
  await t('material: admin marca lista (m1)', true, () => upd('aportaciones/m1', ADMIN, {lista:true}));
  await t('material: admin desmarca lista (m1)', true, () => upd('aportaciones/m1', ADMIN, {lista:false}));
  await t('material: admin cantidad 0', false, () => upd('aportaciones/m1', ADMIN, {cantidad:0}));
  await t('material: admin cantidad 7', true, () => upd('aportaciones/m1', ADMIN, {cantidad:7}));
  await t('material: admin deleteField lista', false, () => upd('aportaciones/m1', ADMIN, {}, ['lista']));
  await t('material: u1 borra la suya', false, () => del('aportaciones/m2', U1));
  await t('material: u1 borra la de u2', false, () => del('aportaciones/m3', U1));
  await t('material: admin borra', true, () => del('aportaciones/m2', ADMIN));
  // legado sin tipo
  await sembrar();
  await t('legado: u1 (responsable) marca lista', true, () => upd('aportaciones/l1', U1, {lista:true}));
  await t('legado: u1 (responsable) se quita', true, () => upd('aportaciones/l1', U1, {responsable_id:null}));
  await sembrar();
  await t('legado: u2 no marca lista el de u1', false, () => upd('aportaciones/l1', U2, {lista:true}));
  await t('legado: u1 no cambia cantidad', false, () => upd('aportaciones/l1', U1, {cantidad:9}));
  await t('legado: admin edita cantidad', true, () => upd('aportaciones/l1', ADMIN, {cantidad:9}));
  await t('legado: u1 no borra', false, () => del('aportaciones/l1', U1));
  await t('legado: admin borra', true, () => del('aportaciones/l1', ADMIN));

  // === ECONÓMICA ===
  await sembrar();
  await t('económica: u1 crea la suya', true, () => add('aportaciones', U1, eco('u1')));
  await t('económica: monto 1', true, () => add('aportaciones', U1, eco('u1', 1)));
  await t('económica: monto 10000000', true, () => add('aportaciones', U1, eco('u1', 10000000)));
  await t('económica: monto 0', false, () => add('aportaciones', U1, eco('u1', 0)));
  await t('económica: monto -5', false, () => add('aportaciones', U1, eco('u1', -5)));
  await t('económica: monto 10000001', false, () => add('aportaciones', U1, eco('u1', 10000001)));
  await t('económica: monto doble 50.5', false, () => add('aportaciones', U1, eco('u1', 50.5)));
  await t('económica: monto doble 50.0', false, () => add('aportaciones', U1, eco('u1', {doubleValue:50})));
  await t('económica: monto string', false, () => add('aportaciones', U1, eco('u1', '50')));
  await t('económica: u1 crea una de u2', false, () => add('aportaciones', U1, eco('u2')));
  await t('económica: u1 crea la suya ya recibida', false, () => add('aportaciones', U1, eco('u1', 5000, true)));
  await t('económica: admin crea de u2', true, () => add('aportaciones', ADMIN, eco('u2')));
  await t('económica: admin crea de u2 recibida', true, () => add('aportaciones', ADMIN, eco('u2', 5000, true)));
  await t('económica: admin crea de no participante', false, () => add('aportaciones', ADMIN, eco('ghost')));
  await t('económica: no participante se crea la suya', false, () => add('aportaciones', tok('ghost'), eco('ghost')));
  await t('económica: responsable null', false, () => add('aportaciones', ADMIN, {...eco('u1'), responsable_id:null}));
  await t('económica: responsable int', false, () => add('aportaciones', ADMIN, {...eco('u1'), responsable_id:5}));
  await t('económica: clave extra', false, () => add('aportaciones', U1, {...eco('u1'), x:1}));
  await t('económica: con claves de material', false, () => add('aportaciones', U1, {...eco('u1'), articulo:'a', cantidad:1, lista:false}));
  await t('económica: sin recibido', false, () => add('aportaciones', U1, {tipo:'economica', responsable_id:'u1', monto_centavos:5000}));
  await t('económica: sin tipo', false, () => add('aportaciones', U1, {responsable_id:'u1', monto_centavos:5000, recibido:false}));
  await t('económica: recibido string', false, () => add('aportaciones', U1, {...eco('u1'), recibido:'false'}));
  // editar
  await t('económica: u1 edita su monto (no recibida)', true, () => upd('aportaciones/e1', U1, {monto_centavos:9999}));
  await t('económica: u1 monto a 0', false, () => upd('aportaciones/e1', U1, {monto_centavos:0}));
  await t('económica: u1 monto 10000001', false, () => upd('aportaciones/e1', U1, {monto_centavos:10000001}));
  await t('económica: u1 monto doble', false, () => upd('aportaciones/e1', U1, {monto_centavos:12.5}));
  await t('económica: u1 edita la de u2', false, () => upd('aportaciones/e2', U1, {monto_centavos:100}));
  await t('económica: u1 edita su monto tras recibida (e3)', false, () => upd('aportaciones/e3', U1, {monto_centavos:100}));
  await t('económica: u1 marca recibido la suya', false, () => upd('aportaciones/e1', U1, {recibido:true}));
  await t('económica: u1 marca recibido y monto', false, () => upd('aportaciones/e1', U1, {recibido:true, monto_centavos:100}));
  await t('económica: u1 desmarca recibido (e3)', false, () => upd('aportaciones/e3', U1, {recibido:false}));
  await t('económica: u1 cambia responsable a u2', false, () => upd('aportaciones/e1', U1, {responsable_id:'u2'}));
  await t('económica: u1 cambia tipo a material', false, () => upd('aportaciones/e1', U1, {tipo:'material'}));
  await t('económica: u1 agrega claves de material', false, () => upd('aportaciones/e1', U1, {articulo:'x', cantidad:1, lista:false}));
  await t('económica: u1 clave extra', false, () => upd('aportaciones/e1', U1, {x:1}));
  await t('económica: deleteField monto', false, () => upd('aportaciones/e1', U1, {}, ['monto_centavos']));
  await t('económica: admin marca recibido', true, () => upd('aportaciones/e1', ADMIN, {recibido:true}));
  await t('económica: admin edita monto tras recibida', true, () => upd('aportaciones/e1', ADMIN, {monto_centavos:111}));
  await t('económica: admin desmarca recibido', true, () => upd('aportaciones/e1', ADMIN, {recibido:false}));
  await t('económica: admin edita la de u2', true, () => upd('aportaciones/e2', ADMIN, {monto_centavos:222}));
  await t('económica: admin monto fuera de rango', false, () => upd('aportaciones/e2', ADMIN, {monto_centavos:10000001}));
  await t('económica: admin responsable no participante', false, () => upd('aportaciones/e2', ADMIN, {responsable_id:'ghost'}));
  await t('económica: admin cambia tipo a material', false, () => upd('aportaciones/e2', ADMIN, {tipo:'material'}));
  await t('económica: admin cambia a material completo (set)', false, () => set('aportaciones/e2', ADMIN, mat()));
  await t('material: admin cambia m1 a económica (set)', false, () => set('aportaciones/m1', ADMIN, eco('u1')));
  await t('material: admin cambia m1 tipo a economica (upd)', false, () => upd('aportaciones/m1', ADMIN, {tipo:'economica'}));
  await t('legado: u1 agrega tipo=economica', false, () => upd('aportaciones/l1', U1, {tipo:'economica'}));
  // borrar
  await sembrar();
  await t('económica: u1 borra la suya (no recibida)', true, () => del('aportaciones/e1', U1));
  await t('económica: u1 borra la de u2', false, () => del('aportaciones/e2', U1));
  await t('económica: u1 borra la suya recibida (e3)', false, () => del('aportaciones/e3', U1));
  await t('económica: admin borra recibida', true, () => del('aportaciones/e3', ADMIN));
  await t('económica: admin borra la de u2', true, () => del('aportaciones/e2', ADMIN));

  // === META ===
  await sembrar();
  await t('meta: admin actualiza', true, () => set('config/aportaciones', ADMIN, {meta_centavos:250000}));
  await t('meta: admin 0', true, () => set('config/aportaciones', ADMIN, {meta_centavos:0}));
  await t('meta: admin null (sin meta)', true, () => set('config/aportaciones', ADMIN, {meta_centavos:null}));
  await t('meta: admin crea (doc inexistente)', true, async () => { await del('config/aportaciones', OWNER); return set('config/aportaciones', ADMIN, {meta_centavos:1000}); });
  await t('meta: admin negativa', false, () => set('config/aportaciones', ADMIN, {meta_centavos:-1}));
  await t('meta: admin doble', false, () => set('config/aportaciones', ADMIN, {meta_centavos:10.5}));
  await t('meta: admin string', false, () => set('config/aportaciones', ADMIN, {meta_centavos:'100'}));
  await t('meta: admin clave extra', false, () => set('config/aportaciones', ADMIN, {meta_centavos:100, x:1}));
  await t('meta: admin sin clave', false, () => set('config/aportaciones', ADMIN, {}));
  await t('meta: admin otro documento', false, () => set('config/otro', ADMIN, {meta_centavos:100}));
  await t('meta: admin borra', false, () => del('config/aportaciones', ADMIN));
  await t('meta: no admin escribe', false, () => set('config/aportaciones', U1, {meta_centavos:100}));
  await t('meta: no admin borra', false, () => del('config/aportaciones', U1));
  await t('meta: anónimo escribe', false, () => set('config/aportaciones', null, {meta_centavos:100}));
  await t('meta: listar la colección config se deniega (solo se lee cada documento por id)', false, () => get('config', U1));
  console.log(`TOTAL pass=${pass} fail=${fail}`); process.exit(fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
