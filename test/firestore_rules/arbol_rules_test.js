// Prueba de las reglas de `arbol_adornos` (bloque en lib/features/arbol/arbol.rules,
// que debe estar pegado en firestore.rules antes del `match /{document=**}` final).
// Cómo correrla (desde la raíz del proyecto, requiere Node 18+ y firebase-tools):
//   firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/arbol_rules_test.js"
// Usa FIRESTORE_EMULATOR_HOST (host:puerto) si existe; si no, 127.0.0.1:8080.
// Roles: admin1 (tiene admins/admin1), u1 y u2 (participantes), u3 (con sesión, sin participante).
// Cada línea imprime PASS/FAIL; el proceso termina con código distinto de 0 si algo falla.
const P = 'demo-posada', H = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080', B = `http://${H}/v1/projects/${P}/databases/(default)/documents`;
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const now = Math.floor(Date.now()/1000);
const tok = uid => 'Bearer ' + b64({alg:'none',typ:'JWT'}) + '.' + b64({sub:uid,user_id:uid,iss:`https://securetoken.google.com/${P}`,aud:P,iat:now,exp:now+3600,auth_time:now,firebase:{sign_in_provider:'password',identities:{}}}) + '.';
const U1 = tok('u1'), U2 = tok('u2'), U3 = tok('u3'), ADMIN = tok('admin1'), OWNER = 'Bearer owner';
const D = n => ({__d: n}); // doble forzado (p. ej. 1.0)
const enc = v => v === null ? {nullValue:null} : v instanceof Date ? {timestampValue:v.toISOString()} : typeof v === 'string' ? {stringValue:v}
  : typeof v === 'boolean' ? {booleanValue:v} : (v && v.__d !== undefined) ? {doubleValue:v.__d} : v === 'SERVER' ? v
  : typeof v === 'number' ? (Number.isInteger(v) ? {integerValue:String(v)} : {doubleValue:v}) : v;
// Los campos 'creado' y 'actualizado' se escriben con el valor de servidor (request.time).
const SERVER = {__server: true};
async function req(method, path, auth, body, qs='') {
  const h = {'Content-Type':'application/json'}; if (auth) h.Authorization = auth;
  const r = await fetch(B + '/' + path + qs, {method, headers:h, body: body ? JSON.stringify(body) : undefined});
  const t = await r.text(); return {s:r.status, j: t ? JSON.parse(t) : {}};
}
const fields = o => Object.fromEntries(Object.entries(o).filter(([,v]) => v !== SERVER).map(([k,v]) => [k, enc(v)]));
const serverKeys = o => Object.entries(o).filter(([,v]) => v === SERVER).map(([k]) => k);
// Escritura REST con transformaciones de servidor (equivale a FieldValue.serverTimestamp()).
async function commit(auth, writes) {
  const h = {'Content-Type':'application/json'}; if (auth) h.Authorization = auth;
  const r = await fetch(`http://${H}/v1/projects/${P}/databases/(default)/documents:commit`, {method:'POST', headers:h, body: JSON.stringify({writes})});
  const t = await r.text(); return {s:r.status, j: t ? JSON.parse(t) : {}};
}
const name = p => `projects/${P}/databases/(default)/documents/${p}`;
const transforms = o => serverKeys(o).map(k => ({fieldPath:k, setToServerValue:'REQUEST_TIME'}));
const set = (p,a,o) => commit(a, [{update:{name:name(p), fields:fields(o)}, updateTransforms: transforms(o)}]);
// update(): solo los campos dados; el documento debe existir.
const upd = (p,a,o) => commit(a, [{update:{name:name(p), fields:fields(o)}, updateMask:{fieldPaths:Object.keys(o)}, currentDocument:{exists:true}, updateTransforms: transforms(o)}]);
const get = (p,a) => req('GET', p, a);
const del = (p,a) => req('DELETE', p, a);
let pass=0, fail=0;
async function t(nombre, exp, fn) {
  const r = await fn(); const ok = exp ? r.s === 200 : r.s === 403;
  ok ? pass++ : fail++;
  console.log(ok ? 'PASS' : 'FAIL', exp ? 'allow' : 'deny ', 'http=' + r.s, nombre, ok ? '' : JSON.stringify(r.j).slice(0,200));
  return r;
}
const esf = (uid, o={}) => ({tipo:'esfera', autor_id:uid, color:'#D62839', patron:'rayas', mensaje:'Feliz Navidad', x:D(0.5), y:D(0.5), creado:SERVER, actualizado:SERVER, ...o});
const reg = (uid, o={}) => ({tipo:'regalo', autor_id:uid, color:'#FFC857', color_mono:'#D62839', mensaje:'Para ti', x:D(0.4), y:D(0.7), creado:SERVER, actualizado:SERVER, ...o});
const sinClave = (o, k) => { const c = {...o}; delete c[k]; return c; };
async function sembrar() {
  await fetch(`http://${H}/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  for (const [p,o] of [['admins/admin1',{nota:'organizador'}],['participantes/u1',{nombre:'Ana',asistencia:'si'}],['participantes/u2',{nombre:'Beto',asistencia:'si'}],['participantes/admin1',{nombre:'Admin',asistencia:'si'}]]) {
    const r = await set(p, OWNER, o); if (r.s!==200) throw new Error('seed '+p+' '+r.s);
  }
  for (const [p,o] of [['arbol_adornos/u1_0',esf('u1')],['arbol_adornos/u2_0',esf('u2')]]) {
    const r = await set(p, OWNER, o); if (r.s!==200) throw new Error('seed '+p+' '+r.s+JSON.stringify(r.j));
  }
}
(async () => {
  await sembrar();
  // --- lectura
  await t('anon lee un adorno', false, () => get('arbol_adornos/u1_0'));
  await t('anon lista la colección', false, () => get('arbol_adornos'));
  await t('con sesión lee un adorno', true, () => get('arbol_adornos/u1_0', U1));
  await t('con sesión (sin participante) lista', true, () => get('arbol_adornos', U3));

  // --- crear
  await t('participante crea esfera en su slot 1', true, () => set('arbol_adornos/u1_1', U1, esf('u1')));
  await t('participante crea regalo en su slot 9', true, () => set('arbol_adornos/u1_9', U1, reg('u1')));
  for (const s of [2,3,4,5,6,7,8]) await t(`participante crea slot ${s}`, true, () => set(`arbol_adornos/u1_${s}`, U1, esf('u1', {patron:['liso','rayas','puntos','estrellas'][s%4]})));
  await t('esfera con x=0 e y=1 (bordes) permitida', true, () => set('arbol_adornos/u2_1', U2, esf('u2', {x:0, y:D(1)})));
  await t('mensaje de 60 caracteres permitido', true, () => set('arbol_adornos/u2_2', U2, esf('u2', {mensaje:'a'.repeat(60)})));
  await t('mensaje vacío permitido', true, () => set('arbol_adornos/u2_3', U2, esf('u2', {mensaje:''})));
  await t('slot 10 denegado', false, () => set('arbol_adornos/u2_10', U2, esf('u2')));
  await t('slot sin número denegado', false, () => set('arbol_adornos/u2_x', U2, esf('u2')));
  await t('id con el uid de otra persona', false, () => set('arbol_adornos/u1_5', U2, esf('u2')));
  await t('autor_id de otra persona en mi slot', false, () => set('arbol_adornos/u2_4', U2, esf('u1')));
  await t('sin participante (u3) no crea', false, () => set('arbol_adornos/u3_0', U3, esf('u3')));
  await t('anon no crea', false, () => set('arbol_adornos/u2_5', null, esf('u2')));
  await t('color fuera de la paleta', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {color:'#123456'})));
  await t('color en minúsculas (no está en la paleta)', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {color:'#d62839'})));
  await t('color_mono fuera de la paleta', false, () => set('arbol_adornos/u2_5', U2, reg('u2', {color_mono:'#000000'})));
  await t('x mayor que 1', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {x:D(1.01)})));
  await t('x negativa', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {x:D(-0.1)})));
  await t('y mayor que 1', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {y:D(1.5)})));
  await t('y negativa', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {y:D(-0.01)})));
  await t('x como texto', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {x:'0.5'})));
  await t('mensaje de 61 caracteres', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {mensaje:'a'.repeat(61)})));
  await t('mensaje que no es texto', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {mensaje:5})));
  await t('tipo desconocido', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {tipo:'estrella'})));
  await t('patrón desconocido', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {patron:'lunares'})));
  await t('esfera sin patrón', false, () => set('arbol_adornos/u2_5', U2, sinClave(esf('u2'), 'patron')));
  await t('esfera con color_mono', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {color_mono:'#D62839'})));
  await t('regalo sin color_mono', false, () => set('arbol_adornos/u2_5', U2, sinClave(reg('u2'), 'color_mono')));
  await t('regalo con patrón', false, () => set('arbol_adornos/u2_5', U2, reg('u2', {patron:'liso'})));
  await t('clave extra', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {extra:1})));
  await t('sin mensaje', false, () => set('arbol_adornos/u2_5', U2, sinClave(esf('u2'), 'mensaje')));
  await t('sin x', false, () => set('arbol_adornos/u2_5', U2, sinClave(esf('u2'), 'x')));
  await t('creado con fecha de cliente', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {creado:new Date('2020-01-01T00:00:00Z')})));
  await t('actualizado con fecha de cliente', false, () => set('arbol_adornos/u2_5', U2, esf('u2', {actualizado:new Date('2020-01-01T00:00:00Z')})));
  await t('admin (participante) crea en su slot', true, () => set('arbol_adornos/admin1_0', ADMIN, esf('admin1')));

  // --- mover y editar (solo el autor)
  await t('autor mueve (x, y, actualizado)', true, () => upd('arbol_adornos/u1_1', U1, {x:D(0.45), y:D(0.55), actualizado:SERVER}));
  await t('autor mueve a x=1 y=0', true, () => upd('arbol_adornos/u1_1', U1, {x:D(1), y:D(0), actualizado:SERVER}));
  await t('autor edita color, patrón y mensaje', true, () => upd('arbol_adornos/u1_1', U1, {color:'#2EE6C8', patron:'estrellas', mensaje:'Nuevo', actualizado:SERVER}));
  await t('autor edita regalo (color_mono)', true, () => upd('arbol_adornos/u1_9', U1, {color_mono:'#2FBF71', mensaje:'', actualizado:SERVER}));
  await t('mover a otra persona', false, () => upd('arbol_adornos/u2_0', U1, {x:D(0.3), y:D(0.3), actualizado:SERVER}));
  await t('admin no mueve adornos ajenos', false, () => upd('arbol_adornos/u1_1', ADMIN, {x:D(0.3), y:D(0.3), actualizado:SERVER}));
  await t('anon no mueve', false, () => upd('arbol_adornos/u1_1', null, {x:D(0.3), y:D(0.3), actualizado:SERVER}));
  await t('mover x fuera de [0,1]', false, () => upd('arbol_adornos/u1_1', U1, {x:D(1.2), actualizado:SERVER}));
  await t('mover y fuera de [0,1]', false, () => upd('arbol_adornos/u1_1', U1, {y:D(-0.2), actualizado:SERVER}));
  await t('mover sin actualizar `actualizado`', false, () => upd('arbol_adornos/u1_1', U1, {x:D(0.3)}));
  await t('editar con color fuera de la paleta', false, () => upd('arbol_adornos/u1_1', U1, {color:'#000000', actualizado:SERVER}));
  await t('editar con mensaje de 61', false, () => upd('arbol_adornos/u1_1', U1, {mensaje:'a'.repeat(61), actualizado:SERVER}));
  await t('cambiar el tipo', false, () => upd('arbol_adornos/u1_1', U1, {tipo:'regalo', actualizado:SERVER}));
  await t('cambiar el autor', false, () => upd('arbol_adornos/u1_1', U1, {autor_id:'u2', actualizado:SERVER}));
  await t('cambiar creado', false, () => upd('arbol_adornos/u1_1', U1, {creado:SERVER, actualizado:SERVER}));
  await t('agregar clave extra al editar', false, () => upd('arbol_adornos/u1_1', U1, {extra:1, actualizado:SERVER}));

  // --- borrar
  await t('autor borra el suyo', true, () => del('arbol_adornos/u1_2', U1));
  await t('borrar el de otra persona', false, () => del('arbol_adornos/u2_0', U1));
  await t('anon no borra', false, () => del('arbol_adornos/u2_0'));
  await t('admin borra el de cualquiera', true, () => del('arbol_adornos/u2_0', ADMIN));
  await t('admin borra otro más', true, () => del('arbol_adornos/u1_3', ADMIN));

  console.log(`\n${pass} PASS, ${fail} FAIL`);
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
