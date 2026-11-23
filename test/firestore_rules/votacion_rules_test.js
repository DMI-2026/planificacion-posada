// Prueba del bloque de reglas de la votación de la comida
// (lib/features/votacion/votacion.rules, ya pegado en firestore.rules) contra el emulador.
// Cómo correrla (desde la raíz del proyecto, requiere Node 18+ y firebase-tools):
//   firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/votacion_rules_test.js"
// Usa FIRESTORE_EMULATOR_HOST (host:puerto) si existe; si no, 127.0.0.1:8080.
// Roles: admin1 (admins/admin1 y participante), u1 y u2 (participantes), u3 (con sesión, NO participante).
// Cada línea imprime PASS/FAIL; el proceso termina con código distinto de 0 si algo falla.
const P = 'demo-posada', H = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const DB = `projects/${P}/databases/(default)/documents`, B = `http://${H}/v1/${DB}`;
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const now = Math.floor(Date.now()/1000);
const tok = uid => 'Bearer ' + b64({alg:'none',typ:'JWT'}) + '.' + b64({sub:uid,user_id:uid,iss:`https://securetoken.google.com/${P}`,aud:P,iat:now,exp:now+3600,auth_time:now,firebase:{sign_in_provider:'password',identities:{}}}) + '.';
const U1 = tok('u1'), U2 = tok('u2'), U3 = tok('u3'), ADMIN = tok('admin1'), OWNER = 'Bearer owner';
const enc = v => v === null ? {nullValue:null} : v instanceof Date ? {timestampValue:v.toISOString()} : typeof v === 'string' ? {stringValue:v}
  : typeof v === 'boolean' ? {booleanValue:v} : Number.isInteger(v) ? {integerValue:String(v)} : typeof v === 'number' ? {doubleValue:v} : v;
const F = o => ({fields: Object.fromEntries(Object.entries(o).map(([k,v]) => [k, enc(v)]))});
async function http(method, url, auth, body) {
  const h = {'Content-Type':'application/json'}; if (auth) h.Authorization = auth;
  const r = await fetch(url, {method, headers:h, body: body ? JSON.stringify(body) : undefined});
  const t = await r.text(); return {s:r.status, j: t ? JSON.parse(t) : {}};
}
const get = (p,a) => http('GET', `${B}/${p}`, a);
const set = (p,a,o) => http('PATCH', `${B}/${p}`, a, F(o));          // setDoc
const del = (p,a) => http('DELETE', `${B}/${p}`, a);
// Crear con `creada = serverTimestamp()` (setToServerValue REQUEST_TIME), como hace la app.
const crearOpcion = (id,a,o) => http('POST', `http://${H}/v1/${DB}:commit`, a, {writes:[{
  update:{name:`${DB}/comida_opciones/${id}`, fields:F(o).fields}, currentDocument:{exists:false},
  updateTransforms:[{fieldPath:'creada', setToServerValue:'REQUEST_TIME'}]}]});
let pass=0, fail=0;
async function t(name, exp, fn) {
  const r = await fn(); const ok = exp ? r.s === 200 : r.s === 403;
  ok ? pass++ : fail++;
  console.log(ok ? 'PASS' : 'FAIL', exp ? 'allow' : 'deny ', 'http=' + r.s, name, ok ? '' : JSON.stringify(r.j).slice(0,160));
  return r;
}
const fecha = new Date('2026-12-01T00:00:00Z');
const pa = n => ({nombre:n, asistencia:'tal_vez'});
const op = (por, nombre='Pozole') => ({nombre, descripcion:'Rojo', propuesta_por:por, creada:fecha});
// Estado: o1 propuesta por u1, o2 por u2; u2 ya votó o2; votación abierta (o cerrada).
async function sembrar(cerrada=false) {
  await fetch(`http://${H}/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  const docs = [['admins/admin1',{nota:'organizador'}],['participantes/u1',pa('Ana')],['participantes/u2',pa('Beto')],['participantes/admin1',pa('Admin')],
    ['comida_opciones/o1',op('u1')],['comida_opciones/o2',op('u2','Tamales')],['comida_votos/u2',{opcion_id:'o2'}]];
  if (cerrada) docs.push(['config/votacion',{cerrada:true}]);
  for (const [p,o] of docs) { const r = await set(p, OWNER, o); if (r.s!==200) throw new Error('seed '+p+' '+r.s); }
}
(async () => {
  await sembrar();
  // --- lectura: solo con sesión
  for (const p of ['comida_opciones/o1','comida_votos/u2','config/votacion','comida_opciones','comida_votos'])
    await t('anon read '+p, false, () => get(p));
  for (const p of ['comida_opciones/o1','comida_votos/u2','comida_opciones','comida_votos']) await t('u3 (no participante) read '+p, true, () => get(p, U3));
  await t('u3 lee config/votacion (no existe)', true, () => get('config/votacion', U3).then(r => ({...r, s: r.s === 404 ? 200 : r.s})));

  // --- proponer
  await t('u1 propone platillo', true, () => crearOpcion('n1', U1, {nombre:'Pavo', descripcion:'', propuesta_por:'u1'}));
  await t('u1 propone con nombre de 80 y descripción de 300', true, () => crearOpcion('n2', U1, {nombre:'a'.repeat(80), descripcion:'b'.repeat(300), propuesta_por:'u1'}));
  await t('admin (participante) propone', true, () => crearOpcion('n3', ADMIN, {nombre:'Flan', descripcion:'', propuesta_por:'admin1'}));
  await t('u3 no participante no propone', false, () => crearOpcion('x1', U3, {nombre:'Pavo', descripcion:'', propuesta_por:'u3'}));
  await t('anon no propone', false, () => crearOpcion('x2', null, {nombre:'Pavo', descripcion:'', propuesta_por:'u1'}));
  await t('u1 propone a nombre de u2', false, () => crearOpcion('x3', U1, {nombre:'Pavo', descripcion:'', propuesta_por:'u2'}));
  await t('nombre vacío', false, () => crearOpcion('x4', U1, {nombre:'', descripcion:'', propuesta_por:'u1'}));
  await t('nombre de 81', false, () => crearOpcion('x5', U1, {nombre:'a'.repeat(81), descripcion:'', propuesta_por:'u1'}));
  await t('descripción de 301', false, () => crearOpcion('x6', U1, {nombre:'Pavo', descripcion:'b'.repeat(301), propuesta_por:'u1'}));
  await t('nombre no es string', false, () => crearOpcion('x7', U1, {nombre:5, descripcion:'', propuesta_por:'u1'}));
  await t('clave extra', false, () => crearOpcion('x8', U1, {nombre:'Pavo', descripcion:'', propuesta_por:'u1', extra:'z'}));
  await t('falta descripcion', false, () => crearOpcion('x9', U1, {nombre:'Pavo', propuesta_por:'u1'}));
  await t('creada con fecha fija (no request.time)', false, () => set('comida_opciones/x10', U1, op('u1')));
  await t('actualizar platillo propio (update)', false, () => set('comida_opciones/o1', U1, op('u1', 'Otro')));
  await t('admin actualiza platillo', false, () => set('comida_opciones/o1', ADMIN, op('u1', 'Otro')));

  // --- votar (abierta)
  await t('u1 vota o1', true, () => set('comida_votos/u1', U1, {opcion_id:'o1'}));
  await t('u1 cambia su voto a o2', true, () => set('comida_votos/u1', U1, {opcion_id:'o2'}));
  await t('u1 quita su voto', true, () => del('comida_votos/u1', U1));
  await t('admin (participante) vota', true, () => set('comida_votos/admin1', ADMIN, {opcion_id:'o1'}));
  await t('u3 no participante no vota', false, () => set('comida_votos/u3', U3, {opcion_id:'o1'}));
  await t('anon no vota', false, () => set('comida_votos/u1', null, {opcion_id:'o1'}));
  await t('u1 vota en nombre de u2', false, () => set('comida_votos/u2', U1, {opcion_id:'o1'}));
  await t('admin vota en nombre de u1', false, () => set('comida_votos/u1', ADMIN, {opcion_id:'o1'}));
  await t('voto por opción inexistente', false, () => set('comida_votos/u1', U1, {opcion_id:'nada'}));
  await t('voto con opcion_id vacío', false, () => set('comida_votos/u1', U1, {opcion_id:''}));
  await t('voto con opcion_id no string', false, () => set('comida_votos/u1', U1, {opcion_id:7}));
  await t('voto con clave extra', false, () => set('comida_votos/u1', U1, {opcion_id:'o1', extra:1}));
  await t('voto sin opcion_id', false, () => set('comida_votos/u1', U1, {otra:'o1'}));
  await t('u1 borra el voto de u2', false, () => del('comida_votos/u2', U1));
  await t('admin borra el voto de u2', false, () => del('comida_votos/u2', ADMIN));
  await t('u3 borra voto ajeno', false, () => del('comida_votos/u2', U3));

  // --- borrar platillos
  await t('u1 borra platillo ajeno (o2)', false, () => del('comida_opciones/o2', U1));
  await t('u3 borra platillo ajeno', false, () => del('comida_opciones/o1', U3));
  await t('anon borra platillo', false, () => del('comida_opciones/o1'));
  await t('u1 borra su platillo (o1)', true, () => del('comida_opciones/o1', U1));
  await t('admin borra platillo ajeno (o2)', true, () => del('comida_opciones/o2', ADMIN));
  await t('u2 vota por opción borrada', false, () => set('comida_votos/u2', U2, {opcion_id:'o2'}));
  await t('el voto huérfano de u2 sigue legible', true, () => get('comida_votos/u2', U1));
  await t('u2 puede quitar su voto huérfano', true, () => del('comida_votos/u2', U2));

  // --- config/votacion
  await sembrar();
  await t('admin cierra (crea config)', true, () => set('config/votacion', ADMIN, {cerrada:true}));
  await t('admin reabre', true, () => set('config/votacion', ADMIN, {cerrada:false}));
  await t('admin cierra de nuevo', true, () => set('config/votacion', ADMIN, {cerrada:true}));
  await t('u1 no cierra/reabre', false, () => set('config/votacion', U1, {cerrada:false}));
  await t('anon no escribe config', false, () => set('config/votacion', null, {cerrada:false}));
  await t('admin: cerrada no booleano', false, () => set('config/votacion', ADMIN, {cerrada:'si'}));
  await t('admin: clave extra', false, () => set('config/votacion', ADMIN, {cerrada:true, extra:1}));
  await t('admin: sin cerrada', false, () => set('config/votacion', ADMIN, {otra:true}));
  await t('admin no borra config', false, () => del('config/votacion', ADMIN));
  await t('u1 lee config', true, () => get('config/votacion', U1));
  await t('otro doc de config denegado', false, () => set('config/otra', ADMIN, {cerrada:true}));

  // --- votación cerrada (config/votacion.cerrada == true)
  await sembrar(true);
  await t('cerrada: u1 no vota', false, () => set('comida_votos/u1', U1, {opcion_id:'o1'}));
  await t('cerrada: u2 no cambia su voto', false, () => set('comida_votos/u2', U2, {opcion_id:'o1'}));
  await t('cerrada: u2 no quita su voto', false, () => del('comida_votos/u2', U2));
  await t('cerrada: u1 no puede proponer', false, () => crearOpcion('c1', U1, {nombre:'Pavo', descripcion:'', propuesta_por:'u1'}));
  await t('cerrada: admin tampoco propone', false, () => crearOpcion('c2', ADMIN, {nombre:'Flan', descripcion:'', propuesta_por:'admin1'}));
  await t('cerrada: u1 no borra su platillo', false, () => del('comida_opciones/o1', U1));
  await t('cerrada: admin borra platillo ajeno (moderación)', true, () => del('comida_opciones/o2', ADMIN));
  await t('cerrada: todos leen', true, () => get('comida_votos', U3));
  await t('admin reabre', true, () => set('config/votacion', ADMIN, {cerrada:false}));
  await t('reabierta: u1 vota', true, () => set('comida_votos/u1', U1, {opcion_id:'o1'}));
  await t('reabierta: u2 quita su voto', true, () => del('comida_votos/u2', U2));
  await t('reabierta: u1 borra su platillo', true, () => del('comida_opciones/o1', U1));
  // config con cerrada:false explícito equivale a abierta; ya cubierto arriba.

  console.log(`\n${pass} PASS, ${fail} FAIL`);
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
