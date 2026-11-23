# Despliegue en Dokploy (solo web)

La app web se compila con el `Dockerfile` del repo (Flutter + nginx) y habla con el proyecto de Firebase **en la nube** (`posada-dmi-2026`). No usa emuladores.

## Requisitos

- Servidor con Dokploy funcionando.
- ~3 GB de RAM libres durante la compilación de Flutter.
- Un dominio con registro DNS A/AAAA apuntando a la IP del servidor.

## Pasos en Dokploy

1. **Create Project** → **Create Service** → **Application**.
2. **Provider:**
   - GitHub (si ya lo conectaste en Dokploy), o
   - Git con la URL `https://github.com/carsimax/planificacion-posada.git`.
   - Branch: `main`.
3. **Build Type:** `Dockerfile`; **Docker File:** `Dockerfile`; **Context:** `.`
4. **Domains** → agregar:
   - Host: tu dominio (p. ej. `posada.ejemplo.com`)
   - Path: `/`
   - Container port: `80`
   - HTTPS: activado, certificado **Let's Encrypt**.
5. **Deploy.** El primer despliegue tarda varios minutos (descarga el SDK de Flutter); los siguientes reutilizan capas en caché.
6. **Autodeploy:** activa Autodeploy (o copia el webhook en GitHub → Settings → Webhooks) para desplegar con cada push a `main`.

## Después del primer despliegue

1. Abre la URL y regístrate.
2. Pide al profesor que cree tu documento `admins/{uid}` en Firestore: ver [Cómo nombrar admin](como-correr.md#6-roles-participantes-y-admin).

## Notas

- Los datos son los de la nube (los mismos que usa la app en local sin emulador).
- Para un futuro inicio de sesión con Google: Firebase Console → Authentication → Settings → **Authorized domains** → agrega tu dominio.
- **Cambiar la versión de Flutter:** en Dokploy → Environment (Build args) define `FLUTTER_VERSION=<versión>` y vuelve a desplegar. Debe cumplir el Dart que pide `pubspec.yaml`.
- Argumentos extra de compilación: build arg `BUILD_ARGS` (p. ej. `--dart-define=CLAVE=valor`).
- Si el servidor tiene poca RAM, una alternativa es compilar en GitHub Actions y publicar una imagen que Dokploy solo descargue (no incluido en el repo).

## Problemas comunes

| Síntoma | Qué hacer |
|---|---|
| El build termina con `Killed` / OOM | Falta RAM: libera memoria, agrega swap o compila fuera (GitHub Actions). |
| 404 al abrir una ruta directa | No debería pasar: `nginx.conf` ya redirige a `index.html`. Revisa que el puerto del dominio sea 80. |
| No aparecen los cambios | Recarga forzada (Ctrl+Shift+R). `index.html` y `main.dart.js` se sirven sin caché; los assets duran 7 días. |
