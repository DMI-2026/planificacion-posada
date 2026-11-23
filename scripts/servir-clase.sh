#!/usr/bin/env bash
# Modo clase: levanta emuladores de Firebase, compila la app web apuntando a
# tu IP y la sirve en la red local para que los alumnos entren desde Chrome.
set -euo pipefail

# --- Ir a la raíz del repo sin importar desde dónde se invoque ---
cd "$(dirname "${BASH_SOURCE[0]}")/.."

PUERTO="${PUERTO:-8000}"
AUTO=0
IP="${IP:-}"
DIR_ESTADO=".servir-clase"
LOG_EMU="$DIR_ESTADO/emuladores.log"
LOG_WEB="$DIR_ESTADO/servidor-web.log"
STAMP="$DIR_ESTADO/ultima-compilacion"

PID_EMU=""
PID_WEB=""
EMU_PROPIOS=0
LIMPIANDO=0

uso() {
  cat <<'USO'
Uso: ./scripts/servir-clase.sh [--auto] [IP]

Monta todo para dar clase: emuladores de Firebase, compilación web y
servidor HTTP. Los alumnos abren http://<IP>:<PUERTO> en Chrome.

Opciones:
  --auto       Vigila lib/ cada 2 s y recompila solo cuando algo cambia.
  -h, --help   Muestra esta ayuda.

Variables de entorno:
  IP       IP de tu máquina (también puede ser el primer argumento).
           Si no se da, se detecta (en0, en1 en macOS; hostname -I en Linux).
  PUERTO   Puerto del servidor web (por defecto 8000; el 5000 lo usa AirPlay).

Teclas durante la ejecución:
  Enter o r   Recompilar (los alumnos deben recargar con Ctrl+Shift+R)
  q           Salir (detiene el servidor y, si los inició este script,
              los emuladores guardando los datos)
USO
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) uso; exit 0 ;;
    --auto) AUTO=1 ;;
    -*) echo "Opción desconocida: $arg" >&2; uso >&2; exit 1 ;;
    *) IP="$arg" ;;
  esac
done

escuchando() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

# --- Limpieza (EXIT/INT/TERM) ---
limpiar() {
  [ "$LIMPIANDO" = 1 ] && return
  LIMPIANDO=1
  trap - EXIT INT TERM
  echo
  if [ -n "$PID_WEB" ] && kill -0 "$PID_WEB" 2>/dev/null; then
    echo "Deteniendo servidor web..."
    kill "$PID_WEB" 2>/dev/null || true
    wait "$PID_WEB" 2>/dev/null || true
  fi
  if [ "$EMU_PROPIOS" = 1 ] && [ -n "$PID_EMU" ]; then
    echo "Deteniendo emuladores (guardando datos, puede tardar)..."
    # Se señala el grupo de procesos completo (-PGID): el launcher de firebase
    # sale enseguida pero sus emuladores hijos siguen vivos si solo se le avisa a él.
    kill -INT -- -"$PID_EMU" 2>/dev/null || true
    local i=0
    while { escuchando 8080 || escuchando 9099; } && [ "$i" -lt 60 ]; do
      sleep 1; i=$((i + 1))
    done
    if escuchando 8080 || escuchando 9099; then
      echo "Los emuladores no respondieron a SIGINT; enviando SIGTERM."
      kill -TERM -- -"$PID_EMU" 2>/dev/null || true
      i=0
      while { escuchando 8080 || escuchando 9099; } && [ "$i" -lt 10 ]; do
        sleep 1; i=$((i + 1))
      done
    fi
    wait "$PID_EMU" 2>/dev/null || true
  fi
  echo "Listo. Hasta la próxima."
}
trap limpiar EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- IP ---
if [ -z "$IP" ] && command -v ipconfig >/dev/null 2>&1; then
  IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
  [ -z "$IP" ] && IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [ -z "$IP" ] && command -v hostname >/dev/null 2>&1; then
  IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
if [ -z "$IP" ]; then
  echo "No pude detectar tu IP. ¿Estás conectado a una red?" >&2
  echo "Indícala a mano: IP=192.168.x.x ./scripts/servir-clase.sh" >&2
  exit 1
fi

# --- Verificación previa ---
for cmd in flutter firebase python3 lsof; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Falta '$cmd' en el PATH. Instálalo antes de continuar (ver docs/como-correr.md)." >&2
    exit 1
  fi
done

mkdir -p "$DIR_ESTADO" build

# --- Puerto del servidor web libre ---
if escuchando "$PUERTO"; then
  echo "El puerto $PUERTO ya está en uso por:" >&2
  lsof -nP -iTCP:"$PUERTO" -sTCP:LISTEN >&2 || true
  echo "Libéralo o usa otro: PUERTO=8001 ./scripts/servir-clase.sh" >&2
  exit 1
fi

# --- Emuladores ---
if escuchando 8080 && escuchando 9099; then
  echo "Emuladores ya activos (8080 y 9099): los reutilizo y no los detendré."
else
  if escuchando 8080 || escuchando 9099; then
    echo "Solo uno de los puertos 8080/9099 está ocupado; revisa qué lo usa:" >&2
    lsof -nP -iTCP:8080 -iTCP:9099 -sTCP:LISTEN >&2 || true
    exit 1
  fi
  ARGS_EMU=(emulators:start)
  [ -d datos-emulador ] && ARGS_EMU+=(--import=./datos-emulador --export-on-exit)
  [ -d datos-emulador ] || ARGS_EMU+=(--export-on-exit=./datos-emulador)
  echo "Iniciando emuladores (log: $LOG_EMU)..."
  # Con control de trabajos (set -m) el trabajo en segundo plano obtiene su
  # propio grupo de procesos (PGID == $PID_EMU) y no hereda "ignorar SIGINT".
  # Así la limpieza puede enviar SIGINT a todo el grupo (launcher + emuladores
  # hijos) y se dispara el --export-on-exit.
  set -m
  firebase "${ARGS_EMU[@]}" >"$LOG_EMU" 2>&1 </dev/null &
  PID_EMU=$!
  set +m
  EMU_PROPIOS=1
  esperado=0
  while [ "$esperado" -lt 120 ]; do
    if escuchando 8080 && escuchando 9099; then break; fi
    if ! kill -0 "$PID_EMU" 2>/dev/null; then
      echo "Los emuladores terminaron al arrancar. Últimas líneas del log:" >&2
      tail -n 15 "$LOG_EMU" >&2 || true
      EMU_PROPIOS=0
      exit 1
    fi
    sleep 1; esperado=$((esperado + 1))
  done
  if ! { escuchando 8080 && escuchando 9099; }; then
    echo "Los emuladores no respondieron en 120 s. Revisa $LOG_EMU" >&2
    exit 1
  fi
  echo "Emuladores listos."
fi

# --- Compilación ---
compilar() {
  touch "$STAMP"
  echo "Compilando (flutter build web)..."
  if flutter build web --dart-define=USAR_EMULADOR=true --dart-define=EMULADOR_HOST="$IP" >"$DIR_ESTADO/compilacion.log" 2>&1; then
    echo "Compilación lista a las $(date +%H:%M:%S). Pide a los alumnos Ctrl+Shift+R."
  else
    echo "La compilación FALLÓ; sigo sirviendo la versión anterior. Detalle:" >&2
    tail -n 20 "$DIR_ESTADO/compilacion.log" >&2 || true
  fi
}

compilar
if [ ! -f build/web/index.html ]; then
  echo "No hay ninguna compilación en build/web; no puedo servir nada." >&2
  exit 1
fi

# --- Servidor web ---
python3 -m http.server "$PUERTO" --bind 0.0.0.0 --directory build/web >"$LOG_WEB" 2>&1 </dev/null &
PID_WEB=$!
sleep 1
if ! kill -0 "$PID_WEB" 2>/dev/null; then
  echo "El servidor web no arrancó. Revisa $LOG_WEB" >&2
  PID_WEB=""
  exit 1
fi

# --- Resumen ---
cat <<MSG

+------------------------------------------------------------+
  MODO CLASE LISTO
  Alumnos (misma Wi-Fi), en Chrome:  http://$IP:$PUERTO
  Interfaz de emuladores (tú):       http://localhost:4000

  Teclas:  Enter o r = recompilar    q = salir
$( [ "$AUTO" = 1 ] && echo "  Modo --auto: recompila solo al cambiar lib/" || true )
  Tras recompilar, alumnos: Ctrl+Shift+R
  Aviso: cualquiera en esta red puede leer/escribir los emuladores.
+------------------------------------------------------------+
MSG

# --- Bucle de teclas ---
cambios_en_lib() {
  [ -n "$(find lib -type f -newer "$STAMP" 2>/dev/null | head -n 1)" ]
}

while true; do
  tecla=""
  rc=0
  if [ "$AUTO" = 1 ]; then
    IFS= read -rsn1 -t 2 tecla || rc=$?
  else
    IFS= read -rsn1 tecla || rc=$?
  fi
  if [ "$rc" -gt 128 ]; then
    # Tiempo agotado: revisar cambios (con espera para agrupar guardados)
    if cambios_en_lib; then
      sleep 1
      echo "Cambios detectados en lib/."
      compilar
    fi
    continue
  elif [ "$rc" -ne 0 ]; then
    echo "Entrada cerrada; saliendo."
    break
  fi
  case "$tecla" in
    ""|r|R) compilar ;;
    q|Q) break ;;
  esac
done
