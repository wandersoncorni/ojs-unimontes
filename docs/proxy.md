# Diagnóstico rápido: HTTP 503 no proxy

## Sintoma

Ao abrir o OJS, a página pode ficar incompleta porque alguns arquivos JavaScript, CSS, fontes ou imagens retornam `503`.

## Causa confirmada

O Nginx aplica `limit_req` às rotas gerais. O OJS carrega muitos assets em paralelo; se a rajada ultrapassa `burst=20`, o Nginx rejeita as requisições. O status padrão de rejeição do `limit_req` é `503`.

O log típico contém:

```text
limiting requests ... by zone "ojs_geral" ... request: "GET ... .js"
```

## Verificação rápida

No servidor:

```bash
cd /opt/ojs-unimontes
docker compose ps
docker compose logs --since=10m nginx | grep -E ' 503 |limiting requests|upstream|error'
```

- `limiting requests ... zone "ojs_geral"`: a zona geral limitou a requisição.
- `limiting requests ... zone "ojs_login"`: o limite específico de login foi atingido.
- `upstream`, `connect() failed` ou `timed out`: verifique a saúde do portal e a conexão Nginx → OJS; aumentar o rate limit não corrige essa causa.

## Solução atual

O `nginx.conf` tem uma localização sem `limit_req` para extensões estáticas (`.css`, `.js`, fontes, imagens etc.). As rotas dinâmicas continuam limitadas. Isso evita rejeitar a carga paralela normal do OJS sem remover o controle das demais requisições.

Se a alteração de configuração não entrar em vigor, valide e faça reload:

```bash
docker exec ojs_proxy nginx -t &&
docker exec ojs_proxy nginx -s reload
```

Editar o arquivo montado não recarrega automaticamente os workers do Nginx.

## Se o limite continuar sendo atingido

Se os logs confirmarem `ojs_geral` em rotas dinâmicas, ajuste gradualmente os valores em `nginx/nginx.conf`:

```nginx
limit_req_zone $binary_remote_addr zone=ojs_geral:10m rate=10r/s;
```

e na localização geral:

```nginx
limit_req zone=ojs_geral burst=20 nodelay;
```

Aumente `rate` e/ou `burst` conforme o tráfego observado, depois valide a configuração e faça reload. Para `ojs_login`, ajuste apenas a zona/localização de login. Confirme nos logs que os 503 cessaram.
