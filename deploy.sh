#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Erro: execute este script com sudo: sudo ./deploy.sh"
  exit 1
fi

ENV_FILE=".env"
CONFIG_FILE="/opt/ojs-unimontes/ojs/config.inc.php"
REQUIRED_VARS=("DB_NAME" "DB_USER" "DB_PASSWORD" "DB_ROOT_PASSWORD")

# 1. Verifica se os arquivos necessários existem
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Erro: Arquivo $ENV_FILE não encontrado."
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Erro: Arquivo de configuração $CONFIG_FILE não encontrado."
  exit 1
fi

# 2. Carrega as variáveis do .env
set -a
source "$ENV_FILE"
set +a

# 3. Valida se todas as variáveis obrigatórias existem e não estão vazias
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    MISSING_VARS+=("$var")
  fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo "Erro: As seguintes variáveis obrigatórias estão ausentes ou vazias no $ENV_FILE:"
  for var in "${MISSING_VARS[@]}"; do
    echo "  - $var"
  done
  exit 1
fi

# 4. Gera APP_KEY apenas se ainda não existir ou estiver vazia no .env
if [[ -z "${APP_KEY:-}" ]]; then
  NEW_KEY="base64:$(openssl rand -base64 32)"
  [[ -s "$ENV_FILE" && "$(tail -c1 "$ENV_FILE" | wc -l)" -eq 0 ]] && echo "" >> "$ENV_FILE"
  echo "APP_KEY=${NEW_KEY}" >> "$ENV_FILE"
  export APP_KEY="$NEW_KEY"
  echo "Nova APP_KEY gerada e salva em $ENV_FILE."
else
  echo "APP_KEY já existente mantida."
fi

# 5. Atualiza app_key e credenciais de banco no arquivo de configuração do OJS
CONFIG_TMP="$(mktemp)"
cp "$CONFIG_FILE" "$CONFIG_TMP"
sed -i "s|^app_key =.*|app_key = \"${APP_KEY}\"|" "$CONFIG_TMP"
sed -i "s|^username =.*|username = \"${DB_USER}\"|" "$CONFIG_TMP"
sed -i "s|^password =.*|password = \"${DB_PASSWORD}\"|" "$CONFIG_TMP"
sed -i "s|^name =.*|name = \"${DB_NAME}\"|" "$CONFIG_TMP"
install -o 33 -g 33 -m 0440 "$CONFIG_TMP" "$CONFIG_FILE"
rm -f "$CONFIG_TMP"

# 6. Garante permissões restritas no arquivo de segredo (www-data = uid 33 / gid 33)
chown 33:33 "$CONFIG_FILE"
chmod 0440 "$CONFIG_FILE"

# 7. Garante permissões nos volumes locais do host para www-data (33:33)
mkdir -p ./data/files ./data/journals ./data/public
chown -R 33:33 ./data/files ./data/journals ./data/public

# 8. Constrói e sobe os containers
docker compose up -d --build
