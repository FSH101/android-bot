#!/usr/bin/env bash
set -euo pipefail

WINDOWS_ASSET="openmp-win32.zip"
WINDOWS_URL="https://github.com/openmultiplayer/open.mp/releases/latest/download/${WINDOWS_ASSET}"
NODE_DLL_URL="https://github.com/AmyrAhmady/samp-node/releases/latest/download/omp-node.dll"

INSTALL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
RUNTIME_DIR="${INSTALL_ROOT}/runtime/windows"
SERVER_DIR="${RUNTIME_DIR}/openmp"
TMP_DIR="${INSTALL_ROOT}/.tmp-download"

for bin in curl unzip npm python3; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Необходимо установить утилиту '$bin' перед запуском скрипта." >&2
    exit 1
  fi
done

mkdir -p "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Скачиваю Windows-сборку сервера open.mp..."
ARCHIVE_PATH="${TMP_DIR}/${WINDOWS_ASSET}"
curl -L --fail --output "${ARCHIVE_PATH}" -H "User-Agent: openmp-setup-script" -H "Accept: application/octet-stream" "${WINDOWS_URL}"

echo "Подготавливаю директорию установки..."
rm -rf "${RUNTIME_DIR}"
mkdir -p "${SERVER_DIR}"

echo "Распаковываю сервер в ${SERVER_DIR}..."
unzip -q "${ARCHIVE_PATH}" -d "${SERVER_DIR}"

COMPONENTS_DIR="${SERVER_DIR}/components"
mkdir -p "${COMPONENTS_DIR}"

echo "Загружаю компонент Node.js (omp-node.dll)..."
curl -L --fail --output "${COMPONENTS_DIR}/omp-node.dll" -H "User-Agent: openmp-setup-script" -H "Accept: application/octet-stream" "${NODE_DLL_URL}"

cd "${SERVER_DIR}"

echo "Инициализирую проект Node.js..."
npm init -y >/dev/null

echo "Добавляю зависимость @open.mp/node..."
npm install @open.mp/node >/dev/null

echo "Обновляю package.json для поддержки ESM..."
python3 - "$SERVER_DIR/package.json" <<'PY'
import json
import pathlib
import sys

pkg_path = pathlib.Path(sys.argv[1])
with pkg_path.open('r', encoding='utf-8') as fh:
    data = json.load(fh)

data['type'] = 'module'

with pkg_path.open('w', encoding='utf-8') as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write('\n')
PY

echo "Создаю конфигурацию server.json..."
cat <<'JSON' > server.json
{
  "name": "Neural Server Project",
  "max_players": 50,
  "announce": true,
  "components": [
    "Pawn",
    "omp-node"
  ],
  "nodejs": {
    "main_scripts": ["gamemode"],
    "side_scripts": []
  },
  "pawn": {
    "main_scripts": [],
    "side_scripts": []
  },
  "rcon": {
    "enable": false,
    "password": ""
  }
}
JSON

echo "Создаю JavaScript-гейммод..."
mkdir -p gamemodes
cat <<'JS' > gamemodes/gamemode.js
import { server } from "@open.mp/node";

server.on("init", () => {
  console.log("✅ Сервер нейросети запущен!");
  server.sendClientMessageToAll("{00FF00}Сервер нейросети запущен!");
});

server.on("playerConnect", (player) => {
  player.sendMessage("{00FFAA}Добро пожаловать на сервер, {FFFFFF}" + player.name + "!");
});
JS

WINDOWS_PATH=$(python3 - "$SERVER_DIR" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1]).resolve()
print(str(path).replace('/', '\\'))
PY
)

echo "Готово! Структура Windows-сервера собрана в ${SERVER_DIR}."
echo "Для запуска используйте Windows и выполните команды:\n  cd \"${WINDOWS_PATH}\"\n  .\\omp-server.exe"
