# Participantes registrados y admin
Los participantes son las cuentas registradas; un admin (documento admins/{uid}) gestiona evento, participantes y aportaciones.

## Specs
- S1: "Podemos hacer que la vista de participantes sean todos los que se han registrado? y yo soy el admin. me registre con el usuario de maximilianocarsi@gmail.com"
- S2: Permisos del admin: "Editar el evento,Gestionar participantes,Gestionar aportaciones" (cada quien marca su propia asistencia)
- S3: Cómo se reconoce: "Documento admins/{uid} (Recommended)"
- S4: Invitados sin cuenta: "No, solo registrados"

## Tasks
- [x] T1 (S1, S4) participantes/{uid} creado al registrarse o iniciar sesión; vista sin botón de agregar — worker
- [x] T2 (S2, S3) esAdmin desde admins/{uid}; UI condicionada por rol — worker
- [x] T3 (S2, S3) firestore.rules con roles + pruebas de reglas — worker
- [x] T4 (S3) docs: cómo nombrar admin (nube y emulador) — worker
- [x] T5 verificación independiente de reglas — parent
- [ ] T6 crear admins/{uid} en emulador (uid del admin) y en nube tras registro — parent (emulador: hecho; nube: pendiente de registro)

## Log
- L1: "Podemos hacer que la vista de participantes sean todos los que se han registrado? y yo soy el admin. me registre con el usuario de maximilianocarsi@gmail.com"
- L2: respuestas: "Editar el evento,Gestionar participantes,Gestionar aportaciones"; "Documento admins/{uid} (Recommended)"; "No, solo registrados"
- L3: la cuenta del admin existe solo en el emulador local; en la nube aún no hay cuentas.
- L4: T1-T4 hechas. Evidencia: flutter analyze sin issues; flutter test 93 pass; flutter build web ok; reglas (emulador en puertos alternos) TOTAL pass=129 fail=0 (con mutación de reglas fallan 14 casos, así que las pruebas detectan regresiones). Pendiente del padre: T5 y T6.
- L5: T5 odd-verify independiente: 88 casos REST propios en emulador aislado; todas las escrituras de la app permitidas por rol; sin escalamiento. Avisos no bloqueantes: aportación sin clave responsable_id no la puede tomar un no admin (la app siempre escribe la clave); aportación lista=true que queda sin responsable solo la limpia el admin.
- L6: T6 parcial: admins/536OOuff1ZgSjTcBcUxJrXOT3POV creado en el emulador local (cuenta del admin). En la nube aún no hay cuentas.
- L7: Tema: "Tambien podemos hacer que la aplicacion tenga un diseño de fondo blanco con el sidebar en escala de grises?" — commit 0504025 (fondo blanco, navegación gris, acento festivo en acciones).
