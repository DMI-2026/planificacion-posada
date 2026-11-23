# syntax=docker/dockerfile:1

# ---------- Etapa de compilación: Flutter web ----------
# No hay imagen oficial de Flutter 3.47, así que se instala el SDK sobre Debian.
FROM debian:bookworm-slim AS build

# pubspec exige Dart ^3.13.5 (Flutter 3.47). Se puede cambiar con --build-arg.
ARG FLUTTER_VERSION=3.47.7
# Argumentos extra para la compilación, p. ej. BUILD_ARGS="--dart-define=CLAVE=valor"
ARG BUILD_ARGS=""

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git curl unzip xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Se compila como root dentro de la etapa de build (no llega a la imagen final).
ENV FLUTTER_ROOT=/opt/flutter \
    PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}" \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    CI=true
RUN git clone https://github.com/flutter/flutter.git --depth 1 --branch ${FLUTTER_VERSION} ${FLUTTER_ROOT} \
    && git config --global --add safe.directory ${FLUTTER_ROOT} \
    && flutter config --no-analytics --enable-web \
       --no-enable-android --no-enable-ios --no-enable-linux-desktop \
       --no-enable-macos-desktop --no-enable-windows-desktop \
    && flutter precache --web

WORKDIR /app

# Capa de dependencias: solo se repite si cambian pubspec.yaml o pubspec.lock.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Código fuente y compilación.
COPY . .
RUN flutter build web --release ${BUILD_ARGS}

# ---------- Etapa de ejecución: nginx ----------
FROM nginx:1.30.6-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1/ || exit 1
