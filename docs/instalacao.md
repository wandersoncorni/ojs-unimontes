# Instalação e deploy do portal OJS

Este guia descreve os requisitos e a sequência de deploy usados por `deploy.sh`.
Execute os comandos a partir de `/opt/ojs-unimontes`, pois o script usa caminhos
relativos e espera que o arquivo de configuração esteja nesse local.

## Dependências do servidor

- Linux com acesso administrativo via `sudo`.
- Docker Engine em execução e plugin Docker Compose v2 (`docker compose`).
- Bash, OpenSSL, `sed`, `mktemp`, `install`, `chown`, `chmod` e utilitários GNU
  (`cp`, `mkdir`, `tail`, `wc`). São normalmente fornecidos pela distribuição.
- Acesso à internet para baixar as imagens base do OJS, Nginx e MariaDB.
- Portas TCP 80 e 443 liberadas no firewall e disponíveis no servidor.
- Espaço em disco para a imagem, o banco de dados e os arquivos enviados ao OJS.

O container OJS tem limites configurados de 2 CPUs, 1536 MB de memória e 250
processos. Garanta que o host tenha recursos suficientes além desses limites.

## Arquivos e diretórios necessários

- `.env`: variáveis do banco. `DB_NAME`, `DB_USER`, `DB_PASSWORD` e
  `DB_ROOT_PASSWORD` são obrigatórias. `APP_KEY` é opcional; se estiver ausente
  ou vazia, o script gera uma chave e a salva no arquivo.
- `ojs/config.inc.php`: configuração do OJS. O script atualiza a chave e as
  credenciais do banco nesse arquivo. Para uma instalação nova, prepare-o a
  partir de `ojs/config.inc.php.example` e mantenha `installed = Off`.
- `nginx/nginx.conf`: configuração do proxy e nome do host público.
- `nginx/certs/fullchain.pem` e `nginx/certs/privkey.pem`: certificado e chave
  privada TLS usados pelo Nginx.
- `/srv/portal/journals`: caminho do host montado como somente leitura no proxy.
  Crie-o antes do deploy e confirme que contém os arquivos públicos esperados.
- `data/files`, `data/journals` e `data/public`: o script cria esses diretórios e
  atribui sua propriedade ao UID/GID 33 (`www-data`).

Mantenha `.env`, `config.inc.php` e `privkey.pem` fora do controle de versão e
com acesso restrito. O segredo do OJS é montado no container; a cópia de runtime
fica em `tmpfs`. O filesystem raiz do container OJS permanece somente leitura.

## Certificado SSL

O deploy **não emite nem renova** certificados. Os dois arquivos precisam existir
antes de iniciar o Nginx:

- `fullchain.pem`: certificado do servidor seguido da cadeia intermediária.
- `privkey.pem`: chave privada PEM correspondente, sem senha interativa.

Para produção, use um certificado de uma autoridade certificadora confiável
(por exemplo, Let's Encrypt) e instale os arquivos nesses caminhos. O certificado
deve corresponder ao endereço usado pelos usuários:

- Para um domínio, inclua esse domínio no SAN do certificado.
- Para acesso direto por IP, o certificado precisa conter o IP como SAN do tipo
  `IP`. Um certificado autoassinado gera aviso no navegador até ser confiado
  explicitamente.

O valor `server_name` em ambos os blocos de `nginx/nginx.conf` ainda é um
placeholder (`periodicos.sua-instituicao.edu.br`); substitua-o pelo domínio real
ou pelo IP utilizado. Se o certificado for renovado ou substituído, valide e
recarregue o Nginx:

```bash
docker exec ojs_proxy nginx -t &&
docker exec ojs_proxy nginx -s reload
```

### Certificado autoassinado para teste

Use somente em desenvolvimento ou rede de teste. Substitua o IP pelo endereço
real do servidor:

```bash
SERVER_IP=192.168.2.108
mkdir -p nginx/certs
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/privkey.pem \
  -out nginx/certs/fullchain.pem \
  -subj "/CN=${SERVER_IP}" \
  -addext "subjectAltName=IP:${SERVER_IP}"
sudo chmod 0600 nginx/certs/privkey.pem
sudo chmod 0644 nginx/certs/fullchain.pem
```

Depois, configure `server_name` no Nginx para o mesmo IP. Este certificado não
será confiado automaticamente pelos navegadores.

## Preparar e executar

1. Confirme que o projeto está em `/opt/ojs-unimontes` e entre na raiz:

   ```bash
   cd /opt/ojs-unimontes
   ```

2. Crie `.env` com as quatro variáveis obrigatórias. Use valores fortes e
   compatíveis com atribuições Bash, pois `deploy.sh` carrega esse arquivo com
   `source`. Não publique os valores.

3. Prepare `ojs/config.inc.php`, configure o host em `nginx/nginx.conf` e
   instale o certificado TLS nos caminhos indicados. Defina também `base_url`
   em `config.inc.php` para a URL canônica que os usuários usarão, por exemplo
   `https://periodicos.exemplo.edu.br` ou `https://192.168.2.108`. Use o mesmo
   host no `server_name` e no certificado.

4. Garanta que `/srv/portal/journals` exista e que as portas 80 e 443 estejam
   liberadas.

5. Execute o deploy como root, conforme exigido pelo script:

   ```bash
   sudo ./deploy.sh
   ```

O script valida as variáveis, cria `APP_KEY` se necessário, atualiza a
configuração do OJS, ajusta permissões dos diretórios de dados, constrói a imagem
do portal e inicia os serviços. Ele não remove os volumes existentes.

## Verificação rápida

```bash
docker compose ps
docker compose logs --tail=80 db ojs nginx
```

Confirme que `db`, `ojs` e `nginx` estão `healthy`. Em uma instalação nova,
acesse:

```text
https://<host>/index/pt_BR/install
```

Se a página ficar incompleta ou o proxy retornar 503, consulte [proxy.md](./proxy.md)
para distinguir rate limit de falha no upstream.
