# Roteiro da migração do OJS de 3.4 para 3.5

Esse roteiro tem como objetivo organizar as ações para atualização do OJS

## 1. Criar a estrutura do projeto

```text
/opt/ojs-portal/
├── .env                          # Senhas e variáveis sensíveis (permissão 600)
├── docker-compose.yml            # Orquestração dos serviços principais
├── docker-compose.monitoring.yml # Stack de observabilidade (Uptime Kuma, Prometheus, Grafana)
├── backup-ojs.sh                 # Script automatizado de backup completo e imutável
├── ojs/
│   ├── Dockerfile                # Personalização leve sobre a imagem oficial do PKP
│   ├── php-custom.ini            # Ajustes de limite de upload, memória e hardening PHP
│   └── config.inc.php.example    # Modelo de configuração de segurança do OJS 3.5
├── nginx/
│   ├── nginx.conf                # Regras de segurança, SSL, headers e rate limiting
│   └── certs/                    # Certificados SSL (fullchain.pem / privkey.pem)
├── monitoring/
│   └── prometheus.yml            # Configuração de coleta de métricas (cAdvisor)
└── data/                         # Volumes persistentes (fora da raiz web)
    ├── files/                    # files_dir (manuscritos privados)
    ├── public/                   # Capas, logos e CSS das revistas
    └── monitoring/               # Dados do Uptime Kuma, Prometheus e Grafana
```
Vantagens da abordagem:
1. Leitura e escrita de arquivo mais eficiente
2. Contêineres descartáveis
3. Upgrades rápidos
4. Backups simples e nativos
5. Evita o esgotamento do armazenamento interno do Docker
6. Recuperação imediata em desastres
7. Inspeção e manutenção direta

## 2. Fazer o backup do banco de dados e arquivos
1. Fazer backup dos arquivos:  

    Extrair os arquivos do diretório ***files*** do container para o hospedeiro.
    ```shell
    docker cp <container_3_4>:/var/www/files/. /opt/ojs-portal/data/files
    ```  

    Extrair os arquivos do diretório ***public*** para o hospedeiro
    ```shell
    docker cp <container_3_4>:/var/www/html/public/. /opt/ojs-portal/data/public
    ```
2. Fazer o backup do banco de dados
    ```shell
    mysqdump -u root > /opt/ojs-portal/ojs_34.sql
    ```

## 3. Criar os containers da stack

```mermaid
    flowchart TD
    A@{ shape: cloud, label: "Internet" } --> B

    subgraph Host ["Hospedeiro Docker"]

        subgraph Nginx [" "]
            B[NGinx] 
            B<-.-> WAF{{"🛡️ ModSecurity"}}
        end

        B --> C

        subgraph Web [" "]
            C[OJS]           
            C <-.-> V1["📁 ./files"]
            C <-.-> V2["📁 ./public"]
        end

        C --> D[(MySQL)]     
    end

```
Descrição:
1. NGinx: proxy reverso e WAF (modesecurity);
2. OJS: servidor WEB;
3. MySQL: banco de dados

## 4. Preparar o upgrade
1. Colocar o portal em manutenção
2. Ajustar a configuração da nova versão para ***installed = Off***
3. Copiar o banco de dados
4. Sanitizar os dados do banco
5. Copiar os arquivos
6. Subir os containers e apontar o banco de dados cópia e o diretório cópia
7. Executar o script de upgrade
```shell
php tools/upgrade.php upgrade
```

## 5. Pós-atualização
* Reinstalar e validar plugins
* Limpar caches
* Fazer backup da nova versão
* Liberar o acesso e monitorar