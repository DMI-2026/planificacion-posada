// Prueba de las reglas de Realtime Database (database.rules.json) contra el emulador.
// Cómo correrla (desde la raíz del proyecto, requiere Node 18+ y firebase-tools):
//   firebase emulators:exec --only database --project demo-posada "node test/database_rules/cohetazo_rules_test.js"
// Usa FIREBASE_DATABASE_EMULATOR_HOST (host:puerto) si existe; si no, 127.0.0.1:9000.
// Cada línea imprime PASS/FAIL; el proceso termina con código distinto de 0 si algo falla.
const P = 'demo-posada', H = process.env.FIREBASE_DATABASE_EMULATOR_HOST || '127.0.0.1:9000';
const NS = P + '-default-rtdb';
const U1 = 'u1', U2 = 'u2', OWNER = 'owner';
const SV = {'.sv': 'timestamp'};
async function req(method, path, token, body) {
  // 'owner' = admin del emulador; un uid se simula con auth_variable_override; null = sin sesión.
  const q = new URLSearchParams({ns: NS});
  if (token === OWNER) q.set('access_token', OWNER);
  else if (token) { q.set('access_token', OWNER); q.set('auth_variable_override', JSON.stringify({uid: token})); }
  const r = await fetch(`http://${H}/${path}.json?${q}`, {method, body: body === undefined ? undefined : JSON.stringify(body)});
  const t = await r.text(); let j; try { j = t ? JSON.parse(t) : null; } catch { j = t; }
  return {s: r.status, j};
}
const put = (p, a, v) => req('PUT', 'cohetazo/' + p, a, v);
const get = (p, a) => req('GET', p, a);
const del = (p, a) => req('DELETE', 'cohetazo/' + p, a);
let pass = 0, fail = 0;
async function t(name, exp, fn) {
  const r = await fn(); const ok = exp ? r.s === 200 : r.s === 401 || r.s === 403;
  ok ? pass++ : fail++;
  console.log(ok ? 'PASS' : 'FAIL', exp ? 'allow' : 'deny ', 'http=' + r.s, name, ok ? '' : JSON.stringify(r.j).slice(0, 160));
}
const jug = (o = {}) => ({nombre:'Ana', x:1, y:1, dir:'abajo', vivo:true, reaparece:0, alcance:2, cohetes:1, velocidad:0, t:SV, ...o});
const coh = (o = {}) => ({uid:'u1', x:3, y:3, alcance:2, colocado:SV, ...o});
const elim = (o = {}) => ({victima:'u1', autor:'u2', t:SV, ...o});
(async () => {
  await req('DELETE', 'cohetazo', OWNER);
  // --- lecturas
  await put('jugadores/u2', U2, jug());
  await t('anon lee /cohetazo', false, () => get('cohetazo', null));
  await t('anon lee jugadores', false, () => get('cohetazo/jugadores', null));
  await t('auth lee /cohetazo', true, () => get('cohetazo', U1));
  await t('auth lee jugadores', true, () => get('cohetazo/jugadores', U1));
  await t('auth lee raíz (denegado)', false, () => get('', U1));
  await t('auth lee ruta desconocida /otro', false, () => get('otro', U1));
  await t('auth escribe ruta desconocida /otro', false, () => req('PUT', 'otro', U1, 1));
  await t('auth escribe /cohetazo/desconocido', false, () => put('desconocido', U1, 1));
  await t('anon escribe jugadores/u1', false, () => put('jugadores/u1', null, jug()));
  // --- jugadores
  await t('jugador propio válido', true, () => put('jugadores/u1', U1, jug()));
  await t('jugador propio actualizado (x=19,y=15)', true, () => put('jugadores/u1', U1, jug({x:19, y:15, dir:'derecha'})));
  await t('jugador límites máximos', true, () => put('jugadores/u1', U1, jug({x:20, y:16, alcance:6, cohetes:5, velocidad:3, reaparece:1700000000000, vivo:false})));
  await t('jugador límites mínimos', true, () => put('jugadores/u1', U1, jug({x:0, y:0, alcance:1, cohetes:1, velocidad:0, nombre:'A'})));
  await t('jugador de otro uid', false, () => put('jugadores/u2', U1, jug()));
  await t('jugador x=21', false, () => put('jugadores/u1', U1, jug({x:21})));
  await t('jugador x=-1', false, () => put('jugadores/u1', U1, jug({x:-1})));
  await t('jugador y=17', false, () => put('jugadores/u1', U1, jug({y:17})));
  await t('jugador x no entero', false, () => put('jugadores/u1', U1, jug({x:1.5})));
  await t('jugador dir inválida', false, () => put('jugadores/u1', U1, jug({dir:'norte'})));
  await t('jugador vivo no bool', false, () => put('jugadores/u1', U1, jug({vivo:'si'})));
  await t('jugador reaparece negativo', false, () => put('jugadores/u1', U1, jug({reaparece:-1})));
  await t('jugador alcance 0', false, () => put('jugadores/u1', U1, jug({alcance:0})));
  await t('jugador alcance 7', false, () => put('jugadores/u1', U1, jug({alcance:7})));
  await t('jugador cohetes 0', false, () => put('jugadores/u1', U1, jug({cohetes:0})));
  await t('jugador cohetes 6', false, () => put('jugadores/u1', U1, jug({cohetes:6})));
  await t('jugador velocidad 4', false, () => put('jugadores/u1', U1, jug({velocidad:4})));
  await t('jugador velocidad -1', false, () => put('jugadores/u1', U1, jug({velocidad:-1})));
  await t('jugador nombre vacío', false, () => put('jugadores/u1', U1, jug({nombre:''})));
  await t('jugador nombre 41 caracteres', false, () => put('jugadores/u1', U1, jug({nombre:'a'.repeat(41)})));
  await t('jugador nombre 40 caracteres', true, () => put('jugadores/u1', U1, jug({nombre:'a'.repeat(40)})));
  await t('jugador t no es now', false, () => put('jugadores/u1', U1, jug({t:12345})));
  await t('jugador campo extra', false, () => put('jugadores/u1', U1, jug({extra:1})));
  await t('jugador falta un campo', false, () => { const o = jug(); delete o.dir; return put('jugadores/u1', U1, o); });
  await t('borrar jugador de otro', false, () => del('jugadores/u2', U1));
  await t('borrar jugador propio (onDisconnect)', true, () => del('jugadores/u1', U1));
  // --- avatares
  await t('avatar propio', true, () => put('avatares/u1', U1, 'QUJD'));
  await t('avatar 20000 caracteres', true, () => put('avatares/u1', U1, 'a'.repeat(20000)));
  await t('avatar 20001 caracteres', false, () => put('avatares/u1', U1, 'a'.repeat(20001)));
  await t('avatar vacío', false, () => put('avatares/u1', U1, ''));
  await t('avatar no string', false, () => put('avatares/u1', U1, 5));
  await t('avatar de otro uid', false, () => put('avatares/u2', U1, 'QUJD'));
  await t('borrar avatar de otro', false, () => del('avatares/u2', U1) );
  await t('borrar avatar propio', true, () => del('avatares/u1', U1));
  // --- cohetes
  await t('cohete propio', true, () => put('cohetes/c1', U1, coh()));
  await t('cohete con uid de otro', false, () => put('cohetes/c2', U1, coh({uid:'u2'})));
  await t('cohete x fuera de rango', false, () => put('cohetes/c3', U1, coh({x:21})));
  await t('cohete y fuera de rango', false, () => put('cohetes/c3', U1, coh({y:17})));
  await t('cohete x no entero', false, () => put('cohetes/c3', U1, coh({x:2.5})));
  await t('cohete alcance 0', false, () => put('cohetes/c3', U1, coh({alcance:0})));
  await t('cohete alcance 7', false, () => put('cohetes/c3', U1, coh({alcance:7})));
  await t('cohete colocado no es now', false, () => put('cohetes/c3', U1, coh({colocado:1})));
  await t('cohete campo extra', false, () => put('cohetes/c3', U1, coh({extra:1})));
  await t('cohete anon', false, () => put('cohetes/c3', null, coh()));
  await t('cohete existente no se actualiza (dueño)', false, () => put('cohetes/c1', U1, coh({x:5})));
  await t('cohete existente no se actualiza (otro)', false, () => put('cohetes/c1', U2, coh({uid:'u2'})));
  await t('cohete existente: cambio parcial denegado', false, () => req('PUT', 'cohetazo/cohetes/c1/x', U1, 7));
  await t('cohete fresco no lo borra otro', false, () => del('cohetes/c1', U2));
  await t('cohete lo borra su dueño', true, () => del('cohetes/c1', U1));
  await req('PUT', 'cohetazo/cohetes/viejo', OWNER, coh({colocado: Date.now() - 20000}));
  await t('cohete viejo (>10 s) lo borra otro', true, () => del('cohetes/viejo', U2));
  await req('PUT', 'cohetazo/cohetes/reciente', OWNER, coh({colocado: Date.now() - 2000}));
  await t('cohete reciente (2 s) no lo borra otro', false, () => del('cohetes/reciente', U2));
  // --- cajas
  await t('caja válida', true, () => put('cajas/3_5', U1, {rota:SV, por:'u1'}));
  await t('caja la reescribe otro usuario', true, () => put('cajas/3_5', U2, {rota:SV, por:'u2'}));
  await t('caja por de otro uid', false, () => put('cajas/3_7', U1, {rota:SV, por:'u2'}));
  await t('caja rota no es now', false, () => put('cajas/3_7', U1, {rota:5, por:'u1'}));
  await t('caja clave inválida', false, () => put('cajas/abc', U1, {rota:SV, por:'u1'}));
  await t('caja clave 3-5', false, () => put('cajas/3-5', U1, {rota:SV, por:'u1'}));
  await t('caja campo extra', false, () => put('cajas/3_9', U1, {rota:SV, por:'u1', x:1}));
  await t('caja anon', false, () => put('cajas/3_9', null, {rota:SV, por:'u1'}));
  await t('caja borrar (rebrote)', true, () => del('cajas/3_5', U2));
  // --- mejoras
  await t('mejora reclamada', true, () => put('mejoras/3_5_1700000000000', U1, 'u1'));
  await t('mejora doble reclamo (otro)', false, () => put('mejoras/3_5_1700000000000', U2, 'u2'));
  await t('mejora doble reclamo (mismo)', false, () => put('mejoras/3_5_1700000000000', U1, 'u1'));
  await t('mejora con uid ajeno', false, () => put('mejoras/3_5_1700000000002', U1, 'u2'));
  await t('mejora valor no string', false, () => put('mejoras/3_5_1700000000003', U1, 5));
  await t('mejora borrar', false, () => del('mejoras/3_5_1700000000000', U1));
  await t('mejora anon', false, () => put('mejoras/3_5_1700000000004', null, 'u1'));
  // --- eliminaciones
  await t('eliminación válida', true, () => put('eliminaciones/e1', U1, elim()));
  await t('autoeliminación válida', true, () => put('eliminaciones/e2', U1, elim({autor:'u1'})));
  await t('eliminación víctima ajena', false, () => put('eliminaciones/e3', U1, elim({victima:'u2'})));
  await t('eliminación t no es now', false, () => put('eliminaciones/e3', U1, elim({t:1})));
  await t('eliminación autor no string', false, () => put('eliminaciones/e3', U1, elim({autor:3})));
  await t('eliminación campo extra', false, () => put('eliminaciones/e3', U1, elim({x:1})));
  await t('eliminación anon', false, () => put('eliminaciones/e3', null, elim()));
  await t('eliminación update denegado (dueño)', false, () => put('eliminaciones/e1', U1, elim({autor:'u1'})));
  await t('eliminación update denegado (otro)', false, () => put('eliminaciones/e1', U2, elim({victima:'u2'})));
  await t('eliminación delete denegado', false, () => del('eliminaciones/e1', U1));
  // --- T4: parent-path / multi-path writes (S2)
  await put('jugadores/u2', U2, jug({nombre:'Beto'}));
  await t('PATCH /cohetazo sobre jugador ajeno', false, () => req('PATCH', 'cohetazo', U1, {'jugadores/u2': jug({nombre:'hack'})}));
  await t('PATCH /cohetazo/jugadores sobre ajeno', false, () => req('PATCH', 'cohetazo/jugadores', U1, {u2: jug({nombre:'hack'})}));
  await t('PATCH raíz multi-ruta sobre ajeno', false, () => req('PATCH', '', U1, {'cohetazo/jugadores/u2/nombre': 'hack'}));
  await t('PUT /cohetazo/jugadores (borraría a otros)', false, () => req('PUT', 'cohetazo/jugadores', U1, {u1: jug()}));
  await t('PATCH mixto propio+ajeno es atómico', false, () => req('PATCH', 'cohetazo', U1, {'jugadores/u1': jug(), 'jugadores/u2': jug({nombre:'hack'})}));
  await t('PATCH multi-ruta propio válido', true, () => req('PATCH', 'cohetazo', U1, {'jugadores/u1': jug(), 'avatares/u1': 'QUJD'}));
  await t('jugador x por .sv increment', false, () => req('PATCH', 'cohetazo/jugadores/u1', U1, {x:{'.sv':{increment:100}}}));
  await t('jugador hijo bajo hoja x/sub', false, () => req('PUT', 'cohetazo/jugadores/u1/x/sub', U1, 1));
  await t('borrar jugadores/u1/t', false, () => del('jugadores/u1/t', U1));
  await t('PATCH /cohetazo/cohetes null a cohete fresco ajeno', false, async () => { await put('cohetes/f1', U1, coh()); return req('PATCH', 'cohetazo/cohetes', U2, {f1: null}); });
  await t('cohete viejo no se reemplaza (update)', false, async () => { await req('PUT', 'cohetazo/cohetes/v2', OWNER, coh({colocado: Date.now() - 20000})); return put('cohetes/v2', U2, coh({uid:'u2'})); });
  await t('PATCH /cohetazo/mejoras sobre existente', false, async () => { await put('mejoras/1_1_1700000000000', U2, 'u2'); return req('PATCH', 'cohetazo/mejoras', U1, {'1_1_1700000000000': 'u1'}); });
  await t('PATCH /cohetazo/eliminaciones null', false, () => req('PATCH', 'cohetazo/eliminaciones', U1, {e1: null}));
  await t('DELETE /cohetazo/eliminaciones completo', false, () => del('eliminaciones', U1));
  await t('DELETE /cohetazo/cajas completo', false, () => del('cajas', U1));
  await t('eliminación autor 1 MB', false, () => put('eliminaciones/big', U1, elim({autor:'x'.repeat(1000000)})));
  await t('eliminación autor vacío', false, () => put('eliminaciones/emp', U1, elim({autor:''})));
  await t('eliminación autor 128 caracteres', true, () => put('eliminaciones/a128', U1, elim({autor:'x'.repeat(128)})));
  await t('eliminación autor 129 caracteres', false, () => put('eliminaciones/a129', U1, elim({autor:'x'.repeat(129)})));
  await t('mejora clave arbitraria', false, () => put('mejoras/zzz', U1, 'u1'));
  await t('mejora clave válida', true, () => put('mejoras/12_16_1700000000123', U1, 'u1'));
  await t('caja fuera de la cuadrícula', false, () => put('cajas/99999_99999', U1, {rota:SV, por:'u1'}));
  await t('caja 20_16 (esquina)', true, () => put('cajas/20_16', U1, {rota:SV, por:'u1'}));
  await t('caja 21_0', false, () => put('cajas/21_0', U1, {rota:SV, por:'u1'}));
  await t('caja 0_17', false, () => put('cajas/0_17', U1, {rota:SV, por:'u1'}));
  await t('jugador con .priority enorme', false, () => put('jugadores/u1', U1, {...jug(), '.priority': 'p'.repeat(100000)}));
  await t('avatar con .priority', false, () => req('PUT', 'cohetazo/avatares/u1', U1, {'.value': 'QUJD', '.priority': 'p'.repeat(1000)}));
  await t('jugador reaparece muy futuro', false, () => put('jugadores/u1', U1, jug({reaparece: Date.now() + 10 * 60000})));
  await t('jugador reaparece cercano (now+30 s)', true, () => put('jugadores/u1', U1, jug({reaparece: Date.now() + 30000})));
  console.log(`\n${pass} PASS, ${fail} FAIL`);
  process.exit(fail ? 1 : 0);
})();
