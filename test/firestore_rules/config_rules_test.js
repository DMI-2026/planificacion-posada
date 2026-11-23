// Reglas de los documentos `config/*`: cada uno solo acepta SU forma (las reglas de
// Firestore se suman con OR, así que un comodín en `config/{id}` abriría los demás).
// Cómo correrla (desde la raíz del proyecto, requiere Node 18+ y firebase-tools):
//   firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/config_rules_test.js"
// Roles: admin1 (tiene admins/admin1) y u1 (usuario normal).
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
const votacion = {cerrada:false};
const aportaciones = {meta_centavos:5000};
const intercambio = {inscripcion_abierta:true, sorteado:false, revelado:false, presupuesto_centavos:10000, fecha:null};
(async () => {
  await fetch(`http://${H}/emulator/v1/projects/${P}/databases/(default)/documents`, {method:'DELETE'});
  await set('admins/admin1', OWNER, {nota:'organizador'});
  // Cada documento acepta su propia forma (admin) y la rechaza el usuario normal.
  await t('admin escribe config/votacion válido', true, () => set('config/votacion', ADMIN, votacion));
  await t('admin escribe config/aportaciones válido', true, () => set('config/aportaciones', ADMIN, aportaciones));
  await t('admin escribe config/intercambio válido', true, () => set('config/intercambio', ADMIN, intercambio));
  for (const id of ['votacion','aportaciones','intercambio']) await t('u1 no escribe config/'+id, false, () => set('config/'+id, U1, {votacion,aportaciones,intercambio}[id]));
  // Formas cruzadas: denegadas aunque el admin las escriba.
  await t('admin: {meta_centavos} en config/votacion', false, () => set('config/votacion', ADMIN, aportaciones));
  await t('admin: forma de intercambio en config/votacion', false, () => set('config/votacion', ADMIN, intercambio));
  await t('admin: {cerrada} en config/aportaciones', false, () => set('config/aportaciones', ADMIN, votacion));
  await t('admin: {cerrada} en config/intercambio', false, () => set('config/intercambio', ADMIN, votacion));
  await t('admin: {meta_centavos} en config/intercambio', false, () => set('config/intercambio', ADMIN, aportaciones));
  await t('admin: forma de intercambio en config/aportaciones', false, () => set('config/aportaciones', ADMIN, intercambio));
  // Otros ids de config: denegados.
  await t('admin: config/otro', false, () => set('config/otro', ADMIN, votacion));
  await t('admin: config/otro con {meta_centavos}', false, () => set('config/otro', ADMIN, aportaciones));
  // Nadie borra.
  for (const id of ['votacion','aportaciones','intercambio']) await t('admin no borra config/'+id, false, () => del('config/'+id, ADMIN));
  // Lectura: cualquier usuario con sesión; sin sesión, no.
  for (const id of ['votacion','aportaciones','intercambio']) {
    await t('u1 lee config/'+id, true, () => get('config/'+id, U1));
    await t('anon no lee config/'+id, false, () => get('config/'+id));
  }
  console.log(`\n${pass} PASS, ${fail} FAIL`);
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
