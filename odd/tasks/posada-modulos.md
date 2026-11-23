# Posada de Navidad por módulos
Todo pasa a ser la posada de Navidad, sin eventos; módulos: participantes, votación de la comida, itinerario, aportaciones, árbol virtual e intercambio de regalos.

## Specs
- S1: "Vamos a cambiar todo sera para la posada de navidad ya no debe existir eventos, te voy a pasar el desglose de modulos: * Participantes * Votacion de la comida * Modulo de gestion del itinerario * Modulo de aportaciones"
- S2: "DEcide tu"
- S3: "Modulo de arbolito de navidad virtual en el los alumnos van a tener un creador de esferas y de regalos que se deberan colcar en tiempo real en el arbol virtual"
- S4: "Y el modulo para el intercambio de regalos"
- S5: "Ve liberando a main (crea pr y fusiona) lo qiue vas terminando"

## Tasks
- [x] T1 (S1) votación de la comida — worker, verificado por módulo
- [x] T2 (S1) gestión del itinerario — worker, verificado por módulo
- [x] T3 (S1) aportaciones material/económica — worker, verificado por módulo
- [x] T4 (S3) árbol de Navidad virtual — worker, verificado por módulo
- [x] T5 (S4) intercambio de regalos — worker, verificado por módulo
- [x] T6 (S1) rediseño login/inicio/participantes — worker, verificado por módulo
- [x] T7 integración: reglas unificadas, wiring, navegación de 7 destinos, tests y docs — worker (fragmentos .rules movidos fuera del repo por el parent)
- [x] T8 verificación independiente: 175 casos propios, sin escalamiento; corregido aviso de votación cerrada
- [ ] T9 PR, fusión y despliegue de reglas — parent

## Log
- L1: "Vamos a cambiar todo sera para la posada de navidad ya no debe existir eventos, te voy a pasar el desglose de modulos: * Participantes * Votacion de la comida * Modulo de gestion del itinerario * Modulo de aportaciones"
- L2: "DEcide tu"
- L3: "Modulo de arbolito de navidad virtual en el los alumnos van a tener un creador de esferas y de regalos que se deberan colcar en tiempo real en el arbol virtual"
- L4: "Y el modulo para el intercambio de regalos"
- L5: "Ve liberando a main (crea pr y fusiona) lo qiue vas terminando"
- L6: módulos implementados por 6 workers en paralelo; reglas probadas por módulo en emuladores aislados
- L7: T7 observado: `flutter analyze` sin problemas; `flutter test` 333 pasan; `flutter build web` OK; reglas finales (firestore.rules unificado) en emulador aislado: rest 129, votacion 69, itinerario 35, aportaciones 154, arbol 65, intercambio 63, config 23 (nuevo), todas 0 fallos. Pendiente de T7: borrar los 5 fragmentos lib/features/*/*.rules (el worker no puede borrar archivos).
- L7b: integración observada: `flutter analyze` sin problemas; 333 tests; reglas 538/538.
- L8: verificador independiente: sin escalamiento; hallazgo: con la votación cerrada el dueño aún podía borrar su platillo (con votos) y se podía proponer. Corregido (decisión del parent): cerrada => no se propone (nadie) ni borra salvo admin (moderación); VM, vista y reglas `comida_opciones`; tests VM + reglas (72 en votacion, 541 en total, 0 fallos). Avisos restantes: el `nombre` por defecto derivado de la parte local del correo es legible por usuarios con sesión; "quitar" participante del admin no es permanente porque el doc de participantes se recrea al iniciar sesión (preexistente, por diseño).
