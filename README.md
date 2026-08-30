# SISLAB Sync

Sistema de integração e sincronização transacional de dados laboratoriais entre unidades sanitárias e a base de dados central nacional.

A aplicação opera em dois modos mutuamente exclusivos:

| Modo | Descrição Funcional |
| --- | --- |
| `local` | Nó local instalado na unidade sanitária. Processa pedidos do EMR, faz a ponte operacional com o SISLAB, gera números de rastreio nacionais e enfileira eventos transacionais na outbox para envio ao nó nacional. |
| `national` | Nó central nacional. Mantém a autoridade sobre o catálogo de dados mestre (dicionário nacional), agrega o fluxo transacional de todos os nós locais e orquestra o encaminhamento de amostras referidas. |

O modo de operação é parametrizado exclusivamente pela variável de ambiente `SISLAB_SYNC_MODE`. A aplicação aborta a inicialização caso a variável não esteja definida. As rotas, jobs e tarefas específicas de cada modo são carregadas condicionalmente.

---

## 1. Requisitos do Sistema

O ambiente de execução padrão e suportado é baseado em contentores Docker:

- Docker Engine (versão 24.0 ou superior)
- Docker Compose (versão 2.20 ou superior)

Para execução nativa fora de contentores, consulte a [secção 7](#7-execução-em-ambiente-nativo-sem-docker). Para implantação em produção, consulte a [secção 8](#8-implantação-em-produção).

---

## 2. Inicialização em Ambiente de Desenvolvimento

A stack do Docker Compose constrói o estágio `development` da imagem, monta o código a partir do sistema de ficheiros anfitrião e opera em `RAILS_ENV=development`. Para implantação em produção, consulte a [secção 8](#8-implantação-em-produção).

### 2.1. Configuração do Ficheiro de Ambiente

Selecione o modelo de configuração correspondente ao modo de operação pretendido:

```bash
cp .env.local.example .env       # Para implantação de nó local (unidade sanitária)
# ou
cp .env.national.example .env    # Para implantação do nó nacional central
```

No modo `local`, configure obrigatoriamente a variável `SISLAB_SYNC_LAB_CODE` com o código do laboratório no registo nacional (`labs`). É a única identidade que um nó tem de receber: a unidade sanitária, o nome e o distrito são lidos da entrada correspondente do registo, replicada do nó nacional, e as chaves emitidas no nó herdam-nos. Enquanto o registo não chegar, o próprio código serve de prefixo aos números de rastreio.

A variável anterior, `SISLAB_SYNC_NODE_CODE`, continua a ser lida e significa o mesmo, para nós instalados antes de o registo existir.

### 2.2. Inicialização dos Serviços

Execute o provisionamento dos contentores e dependências:

```bash
docker compose up -d
```

Na primeira inicialização, o contentor de aplicação executa automaticamente a compilação, criação da base de dados, execução das migrações do ActiveRecord e, em ambiente `development`, a inserção de dados de demonstração.

### 2.3. Verificação de Estado Operacional (Healthcheck)

Valide a inicialização através do endpoint de diagnóstico:

```bash
curl -s http://localhost:3000/api/v3/health | jq
```

Resposta estruturada:

```json
{
  "data": {
    "mode": "local",
    "node_code": "HCM",
    "version": "2.0.0-dev",
    "time": "2026-08-18T11:40:00Z"
  },
  "meta": {},
  "errors": []
}
```

### 2.4. Acesso à Interface de Gestão

Em ambiente `development`, as credenciais administrativas geradas automaticamente são registadas no ficheiro temporário:

```bash
cat tmp/demo_credentials.txt
```

Aceda a `http://localhost:3000` e autentique-se com o utilizador `admin`.

Em ambiente de produção (`production`), crie a conta administrativa inicial via CLI:

```bash
docker compose exec app bin/rails "users:create[Nome Utilizador,email@instituicao.gov.mz,admin]"
```

A palavra-passe temporária é emitida uma única vez no stdout do comando. O sistema armazena apenas o hash criptográfico (bcrypt).

### 2.5. Emissão de Chaves de API para Sistemas Integrados

A emissão de credenciais de integração (para sistemas EMR ou SISLAB) pode ser realizada via interface web (**Clientes e chaves** → *Novo cliente* → *Emitir chave*) ou via linha de comandos:

```bash
docker compose exec app bin/rails api_client:create \
  NAME="EMR Unidade Central" KIND=emr

docker compose exec app bin/rails api_key:issue \
  CLIENT="EMR Unidade Central" SCOPES="orders:write,orders:read,results:read,dictionary:read"
```

Não é preciso indicar códigos. Um nó local é um laboratório e sabe qual: a chave herda o código do laboratório (`SISLAB_SYNC_LAB_CODE`) e o da unidade sanitária que consta da entrada correspondente no registo nacional. Um pedido que declare outros códigos não é recusado — o nó usa os seus.

---

## 3. Topologia de Serviços do Docker Compose

| Serviço | Descrição Técnica |
| --- | --- |
| `app` | Servidor de aplicação HTTP Puma na porta `APP_PORT` (padrão: 3000). Executa a rotina de verificação e migração de base de dados na inicialização. |
| `sidekiq` | Processador de tarefas assíncronas e agendadas em segundo plano (sincronização de outbox, pooling de dicionário e encaminhamentos). |
| `css` | Compilador do Tailwind CSS em modo de monitorização contínua (*watch*). Utilizado em ambiente de desenvolvimento. |
| `mysql` | Sistema de Gestão de Base de Dados Relacional MySQL 8.4 LTS. |
| `redis` | Servidor Redis 7 para gestão de filas do Sidekiq e armazenamento temporário de rate limiting. |

Comandos operacionais frequentes:

```bash
docker compose up -d mysql redis      # Inicialização exclusiva da infraestrutura de dados
docker compose logs -f app            # Acompanhamento contínuo de logs da aplicação
docker compose exec app bin/rails c   # Acesso à consola interativa do Rails
docker compose down                   # Encerramento dos contentores
docker compose down -v                # Encerramento com eliminação persistente dos volumes de dados
```

---

## 4. Execução Simultânea Multimodelo (Local e Nacional)

Para testes e validação de fluxos de sincronização em ambiente de desenvolvimento, execute duas instâncias isoladas com namespaces de projeto e portas distintas:

```bash
# Instância do Nó Nacional
COMPOSE_PROJECT_NAME=sislab_national APP_PORT=3100 docker compose up -d

# Instância do Nó Local (configurada no .env correspondente)
SISLAB_SYNC_NATIONAL_URL=http://host.docker.internal:3100
SISLAB_SYNC_NATIONAL_API_KEY=<token_emitido_no_nacional_com_escopos_sync>
```

A chave utilizada pelo nó local deve ser previamente emitida no nó nacional para um cliente de tipo `node` com os âmbitos `sync:push`, `sync:pull` e `dictionary:read`.

---

## 5. Especificação de Variáveis de Ambiente

### 5.1. Identificação do Nó

| Variável | Obrigatoriedade | Descrição |
| --- | --- | --- |
| `SISLAB_SYNC_MODE` | Obrigatória | Define o modo de operação: `local` ou `national`. |
| `SISLAB_SYNC_LAB_CODE` | Obrigatória em modo local | Código do laboratório no registo nacional (`labs`). Identifica o nó e prefixa os números de rastreio. |
| `SISLAB_SYNC_NATIONAL_URL` | Obrigatória em modo local | URL base de comunicação com o nó nacional central. |
| `SISLAB_SYNC_NATIONAL_API_KEY` | Obrigatória em modo local | Token de autenticação Bearer para comunicação com o nó nacional. |
| `SISLAB_SYNC_PUSH_BATCH` | Opcional | Quantidade máxima de eventos por lote de envio da outbox (padrão: 100). |
| `SISLAB_SYNC_TLS_TERMINATED` | Opcional | `false` num nó de produção servido em HTTP simples, sem proxy inverso a terminar TLS (padrão: `true`). Ver [secção 8.5](#85-terminação-tls). |

### 5.2. Base de Dados e Cache

| Variável | Descrição |
| --- | --- |
| `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_PASSWORD` | Parâmetros de ligação TCP ao servidor MySQL. |
| `DATABASE_NAME` | Nome da base de dados relacional da aplicação. |
| `TEST_DATABASE_NAME` | Nome da base de dados dedicada à execução de testes automatizados (padrão: `sislab_sync_test`). |
| `REDIS_URL` | URI de ligação ao servidor Redis. |

### 5.3. Agendamento de Trabalhos em Segundo Plano (Modo Local)

| Variável | Valor Padrão (Cron) | Descrição do Job |
| --- | --- | --- |
| `SYNC_PUSH_CRON` | `* * * * *` | Despacho periódico da outbox de eventos e sinal de heartbeat. |
| `SYNC_PULL_CRON` | `* * * * *` | Consulta e receção de amostras referidas e resultados concluídos. |
| `DICTIONARY_PULL_CRON` | `*/5 * * * *` | Sincronização incremental de atualizações do catálogo nacional. |

### 5.4. Parâmetros de Dimensionamento e Rate Limiting

| Variável | Descrição |
| --- | --- |
| `API_RATE_LIMIT_PER_MINUTE` | Limite de requisições por minuto por chave de API. |
| `MLAB_DB_*` | Configurações de conexão para importação do legado mLab (exclusivo do nó nacional). |
| `MLAB_API_URL`, `MLAB_API_TOKEN`, `MLAB_API_USER`, `MLAB_API_PASSWORD` | Endereço e credenciais da API do mLab, alternativa à ligação directa à base de dados na importação do catálogo. O token é opcional: na sua ausência a importação autentica-se em `/api/v1/auth/application_login`. |
| `LOINC_CSV` | Caminho no sistema de ficheiros para o ficheiro `Loinc.csv` oficial utilizado na curadoria. |
| `WEB_CONCURRENCY`, `RAILS_MAX_THREADS`, `SIDEKIQ_CONCURRENCY` | Parâmetros de paralelismo de processos e threads do servidor de aplicação e workers. |

---

## 6. Interface de Linha de Comandos (CLI) e Tarefas de Gestão

### 6.1. Utilitários em `bin/`

| Executável | Finalidade Técnica |
| --- | --- |
| `bin/rails` | Executável padrão do framework Rails. |
| `bin/setup` | Script de inicialização: instalação de dependências, migração de esquema e inicialização de serviços. |
| `bin/dev` | Inicializador de desenvolvimento com processos concorrentes via Foreman. |
| `bin/ci` | Execução integrada de análises estáticas (RuboCop, Bundler Audit, Brakeman). |
| `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit` | Execução modular de ferramentas de análise estática e auditoria de vulnerabilidades. |

### 6.2. Gestão de Utilizadores Administrativos e Operadores

```bash
bin/rails "users:create[Nome Completo,email@dominio.mz,admin]"   # Papéis disponíveis: admin, operator
bin/rails "users:reset_password[email@dominio.mz]"               # Invalidação de sessões e redefinição de credencial
bin/rails users:list                                             # Listagem de contas registadas
```

### 6.3. Gestão de Clientes e Chaves de API

```bash
bin/rails api_client:create NAME="EMR Local" KIND=emr
bin/rails api_client:list
bin/rails api_key:issue CLIENT="EMR Local" SCOPES="orders:write,results:read" [EXPIRES_AT=2027-01-01]
bin/rails api_key:list
bin/rails api_key:revoke KEY=<uuid_ou_prefixo>
```

Âmbitos estruturados: `orders:read`, `orders:write`, `results:read`, `results:write`, `referrals:write`, `dictionary:read`, `dictionary:write`, `sync:push`, `sync:pull`.

### 6.4. Registo Nacional de Laboratórios

O nó nacional conhece todos os laboratórios do país e publica a lista pelo mesmo canal do dicionário — `labs` é uma entidade do catálogo como qualquer outra, com a mesma sequência de revisões, o mesmo cursor e os mesmos ecrãs. Cada entrada acrescenta ao tronco comum a unidade sanitária onde o laboratório está, o distrito, a província e um contacto.

É esse registo que torna possível referenciar entre laboratórios sem ninguém escrever códigos:

- o pedido de encaminhamento indica apenas `to_lab_code`; a unidade sanitária de destino é lida do registo;
- um código que o registo não conheça é recusado, porque uma encomenda endereçada a uma gralha nunca chega;
- as chaves emitidas num nó herdam a unidade sanitária da entrada do próprio nó;
- um nó que ainda não tenha recebido o registo continua a funcionar: usa o seu próprio código como prefixo dos números de rastreio e aceita qualquer destino.

As entradas mantêm-se no nó nacional, pelos ecrãs do dicionário (**Dicionário** → *Laboratórios*), e chegam aos nós locais na sincronização seguinte.

### 6.5. Gestão e Sincronização do Dicionário Nacional

O catálogo é uma referência, não uma barreira. Um exame, painel, tipo de amostra, indicador ou motivo de rejeição pode ser indicado por `national_code`, por `uuid` ou por nome, e um termo que o nó não reconheça é aceite e guardado tal como chegou — com o nome e o código com que veio, sem entrada de dicionário associada. A ligação faz-se mais tarde, quando o catálogo alcançar o termo, sem reintroduzir a leitura. O mesmo vale na sincronização: o nó nacional deixou de bloquear a fila de um nó por um código que ainda não tenha.

A única recusa que resta é a de um termo que não indique nada — um teste sem exame, uma leitura sem indicador —, porque nesse caso ninguém saberia o que foi pedido ou medido.

A autoridade de escrita sobre o catálogo é restrita ao nó nacional:

```bash
# Executado no Nó Nacional:
bin/rails dictionary:seed                       # Carga inicial: catálogo distribuído com a release, já publicado
bin/rails dictionary:snapshot                   # Recolha de um novo catálogo a partir do mLab (SOURCE=api|database)
bin/rails dictionary:import_from_mlab           # Importação directa a partir da base legada mLab (estado draft)
bin/rails dictionary:import_from_mlab_api       # Importação equivalente através da API do mLab (estado draft)
bin/rails dictionary:quality                    # Geração de relatório de conformidade → tmp/dictionary_quality.csv
ACTOR="Administrador" SKIP_BLOCKED=1 \
  bin/rails dictionary:promote                  # Publicação e ativação estruturada de rascunhos válidos
bin/rails dictionary:status                     # Diagnóstico do estado quantitativo do catálogo

# Executado no Nó Local:
bin/rails dictionary:pull                       # Sincronização manual imediata com o nó nacional
```

#### Carga inicial do catálogo

O ficheiro `db/dictionary/mlab_catalog.json` acompanha a release e contém o catálogo do mLab tal como
estava no momento da recolha — departamentos, espécimes, fármacos, organismos, indicadores com os
respectivos intervalos de referência, exames, painéis e todas as ligações entre eles. `dictionary:seed`
importa-o, acrescenta os motivos de rejeição (o mLab não tem tabela para eles) e publica tudo,
registando o acto contra `ACTOR`. É idempotente: a identidade vem do id do mLab através de
`ExternalMapping`, pelo que uma segunda execução não duplica nem altera nada.

Esta é a carga **inicial**. A partir daí o catálogo é propriedade do nó nacional e os exames novos são
criados à mão na interface; `dictionary:snapshot` só volta a ser necessário para distribuir um catálogo
mais recente do mLab numa nova release.

| Entidade | Entradas na recolha de 2026-08-30 |
| --- | --- |
| Departamentos | 13 |
| Tipos de espécime | 28 |
| Fármacos | 30 |
| Organismos | 224 |
| Indicadores | 527 (3 recusados por não terem nome) |
| Intervalos de referência | 1061 |
| Exames | 115 |
| Painéis | 9 |
| Motivos de rejeição | 10 (deste repositório, não do mLab) |

O relatório de qualidade é gerado no fim da carga e não a bloqueia: a recolha de 2026-08-30 acusa 279
nomes duplicados e 199 indicadores sem exame associado, herdados do mLab. `SKIP_BLOCKED=1` retém os
exames sem indicadores ou sem espécime em rascunho, para serem corrigidos antes de chegarem aos
laboratórios.

#### Reimportação directa do mLab

As duas importações são intercambiáveis — partilham o mesmo importador, a mesma identidade por
`ExternalMapping` e a mesma idempotência — e diferem apenas na origem das linhas. A via API é a
indicada quando apenas o HTTP do mLab está acessível, com três limitações que decorrem da própria
API e que a tarefa comunica no final da execução:

- Exames e painéis pediátricos ou oncológicos são omitidos pelas listagens da API; uma importação
  por esta via retira os que uma importação anterior pela base de dados tenha criado.
- Um indicador chega através do exame que o utiliza, pelo que indicadores sem exame associado não
  são importados.
- Um exame cujo departamento esteja retirado no mLab não pode ser lido em detalhe (a API responde
  404), pelo que é importado sem indicadores nem organismos e é nomeado nos avisos da fonte.

### 6.6. Curadoria de Mapeamentos LOINC

```bash
bin/rails dictionary:loinc:coverage             # Métricas de cobertura de mapeamentos por entidade

LOINC_CSV=tmp/Loinc.csv \
  bin/rails dictionary:loinc:worksheet          # Extração de planilha de trabalho com candidatos → tmp/loinc_worksheet.csv

# Aplicação transacional do mapeamento validado:
LOINC_CSV=tmp/Loinc.csv \
  bin/rails "dictionary:loinc:apply[tmp/loinc_worksheet.csv]"             # Modo de simulação (dry-run)

LOINC_CSV=tmp/Loinc.csv ACTOR="Responsável Técnico" APPLY=1 \
  bin/rails "dictionary:loinc:apply[tmp/loinc_worksheet.csv]"             # Execução efetiva com persistência
```

### 6.7. Execução da Suite de Testes e Validação de Conformidade

```bash
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec
docker compose run --rm app bundle exec rubocop
docker compose run --rm app bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
docker compose run --rm app bin/bundler-audit
```

Execução segmentada por modo operacional:

```bash
# Execução da suite em modo Local:
docker compose run --rm -e RAILS_ENV=test \
  -e SISLAB_SYNC_MODE=local -e SISLAB_SYNC_LAB_CODE=LOCAL01 app bundle exec rspec

# Execução da suite em modo Nacional:
docker compose run --rm -e RAILS_ENV=test \
  -e SISLAB_SYNC_MODE=national -e SISLAB_SYNC_LAB_CODE=NATIONAL app bundle exec rspec
```

---

## 7. Execução em Ambiente Nativo (Sem Docker)

Requisitos de runtime: Ruby 3.3.8, MySQL 8.4 e Redis 7.

```bash
bundle install

export SISLAB_SYNC_MODE=local SISLAB_SYNC_LAB_CODE=DEV
export DATABASE_HOST=127.0.0.1 DATABASE_USER=root DATABASE_PASSWORD=...

bin/rails db:prepare
bin/dev
```

*Nota técnica*: O sistema requer isolamento de transação `READ-COMMITTED` configurado no MySQL (`config/database.yml`).

---

## 8. Implantação em Produção

Em produção utiliza-se a imagem final do `Dockerfile`, distinta do estágio `development` consumido pela stack do Docker Compose: executa sob utilizador não privilegiado, incorpora os assets pré-compilados e não monta código do sistema anfitrião.

### 8.1. Construção da Imagem

```bash
docker build -t sislab_sync:2.0.0 .
```

A mesma imagem serve ambos os tipos de nó. O modo de operação é lido do ambiente em tempo de execução e não é fixado na construção.

### 8.2. Segredo da Aplicação

Em ambiente `production` a aplicação requer um segredo, fornecido por uma das seguintes variáveis:

| Variável | Utilização |
| --- | --- |
| `RAILS_MASTER_KEY` | Conteúdo de `config/master.key`, para decifragem de `config/credentials.yml.enc`. |
| `SECRET_KEY_BASE` | Segredo fornecido diretamente, quando as credenciais cifradas não são utilizadas. |

`config/master.key` está excluído do controlo de versões e deve ser distribuído pelo mecanismo de gestão de segredos da infraestrutura.

### 8.3. Variáveis Obrigatórias

| Variável | Exemplo | Observação |
| --- | --- | --- |
| `RAILS_ENV` | `production` | |
| `SISLAB_SYNC_MODE` | `local` \| `national` | |
| `SISLAB_SYNC_LAB_CODE` | `HCM` | Obrigatória em modo `local`; identifica o laboratório no registo nacional e prefixa os números de rastreio. |
| `SISLAB_SYNC_TLS_TERMINATED` | `true` | `false` se o nó for servido em HTTP simples (ver 8.5). |
| `DATABASE_HOST`, `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_NAME` | | MySQL 8.4 com `transaction_isolation=READ-COMMITTED`. |
| `REDIS_URL` | `redis://redis:6379/0` | Cache, limitação de taxa e filas Sidekiq. |
| `SISLAB_SYNC_NATIONAL_URL`, `SISLAB_SYNC_NATIONAL_API_KEY` | | Modo `local`, para replicação com o nó nacional. |

A especificação completa consta da [secção 5](#5-especificação-de-variáveis-de-ambiente).

### 8.4. Execução

```bash
docker run -d --name sislab_sync \
  -e RAILS_ENV=production \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -e SISLAB_SYNC_MODE=local -e SISLAB_SYNC_LAB_CODE=HCM \
  -e DATABASE_HOST=... -e DATABASE_USER=... -e DATABASE_PASSWORD=... \
  -e DATABASE_NAME=sislab_sync_production \
  -e REDIS_URL=redis://... \
  -p 127.0.0.1:3000:3000 sislab_sync:2.0.0
```

Em modo `local`, um processo Sidekiq adicional executa o despacho da outbox, a receção de amostras referidas e a sincronização do dicionário (ver [secção 5.3](#53-agendamento-de-trabalhos-em-segundo-plano-modo-local)). Utiliza a mesma imagem e o mesmo conjunto de variáveis:

```bash
docker run -d --name sislab_sync_worker <mesmas variáveis> sislab_sync:2.0.0 bundle exec sidekiq
```

### 8.5. Terminação TLS

Por omissão, `config/environments/production.rb` define `force_ssl` e `assume_ssl`: a terminação TLS é realizada por um proxy reverso à frente do nó, que encaminha o cabeçalho `X-Forwarded-Proto`. O processo Puma serve exclusivamente HTTP simples na porta 3000, que não deve ser exposta fora da máquina — publique-a apenas no interface de loopback (`-p 127.0.0.1:3000:3000`) e coloque o proxy à frente.

```nginx
location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $host;
}
```

**Nó sem proxy TLS.** Um nó servido diretamente em HTTP simples tem de declarar `SISLAB_SYNC_TLS_TERMINATED=false`. Mantido no valor por omissão, `assume_ssl` marca todos os pedidos como seguros antes do redirecionamento de `force_ssl` ser avaliado — pelo que nenhum pedido é redirecionado e o nó apenas passa a declarar um esquema que não pratica:

| Efeito | Consequência observada |
| --- | --- |
| Cookie de sessão marcado `Secure` | O navegador aceita o cookie e nunca o devolve: a autenticação na interface web não persiste. |
| `request.base_url` resolve para `https://<host>:3000` | Os `fullUrl` e os `link` dos Bundles FHIR apontam para uma porta sem TLS. Um cliente que siga a paginação abre uma ligação TLS contra o Puma, que regista `Puma::HttpParserError: Invalid HTTP format`. |
| Cabeçalho `Strict-Transport-Security` emitido em HTTP simples | Ignorado por navegadores conformes (RFC 6797 §8.1); o comportamento de outros clientes não é uniforme. |

A variável não desativa proteção alguma que o transporte já possua: alinha a configuração da aplicação com o transporte efetivamente em uso. Num nó em HTTP simples, as credenciais e os resultados clínicos circulam em claro na rede, pelo que a colocação de um proxy com TLS permanece o destino correto.

### 8.6. Migrações de Base de Dados

`bin/docker-entrypoint` executa `db:prepare` quando o comando do contentor inclui `rails server`:

| Contentor | Comportamento |
| --- | --- |
| Aplicação | Migra a base de dados na inicialização. |
| Sidekiq | Não migra, evitando execução concorrente de migrações. |
| Efémero (manutenção) | Não migra; requer invocação explícita. |

```bash
docker run --rm <variáveis> sislab_sync:2.0.0 bin/rails db:prepare
```

### 8.7. Primeiro Arranque

```bash
# Verificação de estado operacional
curl -s https://<host>/api/v3/health | jq

# Conta administrativa inicial (palavra-passe emitida uma única vez no stdout)
docker exec sislab_sync bin/rails "users:create[Nome Utilizador,email@instituicao.gov.mz,admin]"

# Credenciais de integração para o sistema clínico
docker exec sislab_sync bin/rails api_client:create NAME="EMR Unidade Central" KIND=emr FACILITY_CODE=HCM
docker exec sislab_sync bin/rails api_key:issue CLIENT=HCM SCOPES="orders:write,orders:read,results:read,dictionary:read"

# Carga inicial do catálogo — apenas no nó nacional, uma única vez (ver 6.4)
docker exec sislab_sync bin/rails dictionary:seed ACTOR="Nome de quem aceita o catálogo"
```

*Nota técnica*: a inserção de dados de demonstração e a geração automática de credenciais administrativas (`tmp/demo_credentials.txt`) são exclusivas do ambiente `development`.

---

## 9. Interface de Gestão Web

Interface web integrada para operadores e administradores, com autenticação por sessão:

| Módulo | Finalidade Operacional | Modos Suportados |
| --- | --- | --- |
| Painel | Monitorização do estado da sincronização, outbox, cursores de revisão e latência de rede. | `local`, `national` |
| Pedidos | Consulta e rastreamento de pedidos por número de rastreio, NID do paciente ou nome. | `local`, `national` |
| Amostras Referidas | Gestão de amostras em trânsito, receções e rejeições de encaminhamento. | `local`, `national` |
| Dicionário | Navegação pelo catálogo ativo (leitura universal; edição e ativação restrita ao nacional). | `local`, `national` |
| Fila de Sincronização | Inspeção de eventos de outbox com falha e reprocessamento sob demanda. | `local` |
| Nós | Monitorização de nós locais conectados, versão de software e atraso de cursor. | `national` |
| Clientes e Chaves | Emissão, rotação e revogação de chaves de API com controlo de acessos baseado em âmbitos. | `local`, `national` (admin) |
| Auditoria | Histórico estruturado de requisições de API e tentativas de acesso negadas. | `local`, `national` (admin) |

---

## 10. Especificação OpenAPI e Documentação da API com Scalar

A especificação formal da API é disponibilizada diretamente pelo nó em `/api-docs`:

| Endpoint | Formato | Descrição |
| --- | --- | --- |
| `GET /api-docs` | HTML | Interface interativa de referência e consola de testes da API baseada em **Scalar**. |
| `GET /api-docs.json` | JSON | Especificação OpenAPI 3.1 filtrada dinamicamente para os endpoints ativos do nó. |
| `GET /api-docs.yaml` | YAML | Especificação OpenAPI 3.1 em formato YAML. |

O contrato global completo do sistema encontra-se no ficheiro [`docs/sislab-sync/openapi.yaml`](docs/sislab-sync/openapi.yaml).

### 10.1. Configuração e Script do Scalar

A interface interativa é gerida via gem `scalar_ruby` e configurada em [`config/initializers/scalar.rb`](config/initializers/scalar.rb):

```ruby
Scalar.setup do |config|
  config.page_title = "SISLAB Sync · Referência da API"
  config.configuration = {
    url: "/api-docs.json",
    theme: "saturn",
    layout: "modern",
    showSidebar: true,
    searchHotKey: "k"
  }
end
```

Na renderização da rota `/api-docs`, o `Scalar::UI` injecta o script de cliente autónomo que consome a especificação do nó:

```html
<div id="app"></div>
<script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
<script>
  Scalar.createApiReference(
    '#app',
    {
      "url": "/api-docs.json",
      "theme": "saturn",
      "layout": "modern",
      "showSidebar": true,
      "searchHotKey": "k"
    }
  )
</script>
```

### 10.2. Validação Contínua de Contrato

A conformidade da especificação OpenAPI é validada em pipeline de CI contra:
- As rotas ativas do framework em cada modo operacional.
- Os enums e constantes de domínio (`OrderStatus`, `TestStatus`, `Priority`, `ErrorCode`, `SyncEventType`).
- Os esquemas de validação JSON Schema draft 2020-12 aplicados sobre todas as respostas da suite de testes.

Coleção Postman para testes integrados manuais de ponta a ponta:
[`docs/sislab-sync/sislab-sync.postman_collection.json`](docs/sislab-sync/sislab-sync.postman_collection.json).

---

## 11. Fachada FHIR R4 para Sistemas EMR

Os pedidos, amostras e leituras servidos pela API REST nativa são igualmente expostos em HL7 FHIR R4 sob o prefixo `/fhir/r4`, em modo `local`. Cada recurso é projetado a partir dos modelos transacionais; a admissão de pedidos reutiliza o mesmo componente `OrderRequest` da API nativa, incluindo a validação de códigos de dicionário e a expansão de painéis.

### 11.1. Endpoints

| Endpoint | Âmbito | Descrição |
| --- | --- | --- |
| `GET /fhir/r4/metadata` | — | `CapabilityStatement` do nó. Não requer autenticação. |
| `POST /fhir/r4/ServiceRequest` | `orders:write` | Cria um pedido com a análise indicada. Um código de painel é expandido nas análises constituintes e a resposta passa a ser um `Bundle` de tipo `collection`. |
| `POST /fhir/r4` | `orders:write` | `Bundle` de tipo `transaction`: várias análises sobre uma amostra, agrupadas por `requisition`. Operação atómica. |
| `GET /fhir/r4/ServiceRequest/{id}` | `orders:read` | Uma análise pedida, identificada pelo uuid. |
| `GET /fhir/r4/ServiceRequest` | `orders:read` | Pesquisa por `requisition`, `identifier`, `patient`, `patient.identifier`, `status`, `_count`. |
| `GET /fhir/r4/DiagnosticReport/{id}` | `results:read` | Relatório de uma análise, com as leituras atuais em `contained`. |
| `GET /fhir/r4/DiagnosticReport` | `results:read` | Pesquisa por `identifier`, `patient`, `patient.identifier`, `status`, `_count`. |
| `GET /fhir/r4/Observation/{id}` | `results:read` | Uma leitura. |
| `GET /fhir/r4/Observation` | `results:read` | Feed de resultados por cursor `_since`, com paginação por `link[next]`. |
| `POST /fhir/r4/Observation/{id}/$acknowledge` | `results:read` | Regista a confirmação de arquivamento da leitura pelo sistema clínico. |
| `GET /fhir/r4/Patient/{id}`, `GET /fhir/r4/Patient` | `orders:read` | Doentes com amostras da unidade sanitária associada à chave. A pesquisa requer `identifier`. |
| `GET /fhir/r4/Specimen/{id}` | `orders:read` | A amostra, identificada pelo uuid do pedido. |

Autenticação, âmbitos, restrição por unidade sanitária, limitação de taxa, idempotência e trilho de auditoria são comuns à API REST nativa e regem-se pelas regras descritas nas secções anteriores. A fachada difere apenas no formato das respostas: recursos FHIR em `application/fhir+json`, e `OperationOutcome` em substituição do envelope `data`/`meta`/`errors`.

### 11.2. Codificação Terminológica

Cada `CodeableConcept` emitido transporta dois `coding`, pela seguinte ordem:

| Ordem | Sistema | Presença |
| --- | --- | --- |
| 1 | Código nacional (`https://sislab.misau.gov.mz/fhir/CodeSystem/test-types` e equivalentes) | Sempre presente. |
| 2 | LOINC (`http://loinc.org`) | Presente nas entradas de dicionário com mapeamento curado (ver [secção 6.5](#65-curadoria-de-mapeamentos-loinc)). |

Na admissão, o código da análise é aceite em qualquer um dos dois sistemas, ou como código nacional com o prefixo `MOZ-` sem sistema declarado. A cobertura LOINC do catálogo aumenta à medida que a curadoria progride, sem alteração dos clientes.

### 11.3. Estados Nativos em Extensões

O vocabulário de estados do FHIR é mais restrito que o do sistema: uma amostra recusada pelo laboratório e um pedido cancelado na unidade sanitária correspondem ambos a `revoked`. O estado nativo é publicado em extensão:

| Extensão | Conteúdo |
| --- | --- |
| `.../StructureDefinition/order-status` | Estado nativo do pedido (`requested`, `accepted`, `rejected`, `cancelled`, …). |
| `.../StructureDefinition/test-status` | Estado nativo da análise (`pending`, `in_progress`, `completed`, …). |
| `.../StructureDefinition/test-panel` | Painel de origem da análise, quando resultante de expansão. |
| `.../StructureDefinition/revision` | Revisão da leitura, para posicionamento do cursor. |
| `.../StructureDefinition/replaced-by` | Uuid da leitura que substituiu esta. |

### 11.4. Feed de Resultados e Correções

`_since` é uma revisão sequencial atribuída por contador com bloqueio, e não um timestamp: uma leitura cuja transação demore a confirmar não fica atrás de um cursor já avançado. O cliente segue `link[next]` até este deixar de existir e retém a última revisão para a consulta seguinte.

As correções não reescrevem a leitura anterior. A leitura substituída volta a mover-se no feed e é emitida como `Observation` com `status: "entered-in-error"` e a extensão `replaced-by`; o `DiagnosticReport` correspondente passa ao estado `corrected`, sem reabertura da análise. A operação `$acknowledge` sobre uma leitura substituída é recusada com `409`, identificando a substituta.

### 11.5. Exemplo de Admissão

```bash
curl -X POST http://localhost:3000/fhir/r4/ServiceRequest \
  -H "Authorization: Bearer ssk_dev_..." \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "ServiceRequest",
    "identifier": [{ "system": "http://emr.local/orders", "value": "EMR-000123" }],
    "status": "active", "intent": "order", "priority": "urgent",
    "code": { "coding": [{ "system": "http://loinc.org", "code": "718-7" }] },
    "subject": { "reference": "#doente" },
    "specimen": [{ "reference": "#amostra" }],
    "performer": [{ "identifier": { "value": "HCM-LAB" } }],
    "contained": [
      { "resourceType": "Patient", "id": "doente",
        "identifier": [{ "value": "110100234567A" }],
        "name": [{ "text": "Ana Macuácua" }], "gender": "female", "birthDate": "1991-04-12" },
      { "resourceType": "Specimen", "id": "amostra",
        "type": { "coding": [{ "code": "MOZ-SP-0001" }] },
        "collection": { "collectedDateTime": "2026-09-14T08:20:00+02:00" } }
    ]
  }'
```

*Nota técnica*: na ausência do cabeçalho `Idempotency-Key`, o campo `identifier` do pedido é utilizado como chave de idempotência. Uma repetição com o mesmo identificador e conteúdo devolve a resposta original, sinalizada pelo cabeçalho `Idempotent-Replay`.

### 11.6. Contrato e Validação

A fachada é descrita em dois documentos complementares, ambos validados em CI:

| Documento | Âmbito | Garantia |
| --- | --- | --- |
| [`docs/sislab-sync/openapi.yaml`](docs/sislab-sync/openapi.yaml) | Operações: rotas, parâmetros de pesquisa, âmbitos, códigos de estado e respostas de erro. | Verificação cruzada contra as rotas da aplicação em ambas as direções, em `spec/contracts/openapi_spec.rb`: uma rota não documentada e uma operação sem rota correspondente produzem falha. As respostas geradas pela suite são validadas contra os esquemas declarados. |
| `GET /fhir/r4/metadata` | `CapabilityStatement`, gerado a partir das constantes utilizadas pelos controladores. | Os parâmetros de pesquisa declarados correspondem aos efetivamente lidos, e os recursos declarados são comparados com os efetivamente roteados. |

Os esquemas dos recursos no `openapi.yaml` são parciais: declaram o subconjunto que o nó garante emitir e aceitar, mantêm `additionalProperties` aberto e remetem para a especificação HL7 quanto à definição completa dos recursos.

Cobertura de testes em [`spec/requests/fhir/`](spec/requests/fhir/) e [`spec/serializers/fhir/`](spec/serializers/fhir/).

---

## 12. Estado do Projeto

Desenvolvimento ativo no ramo `v2`. Etapas concluídas (S1 a S11): arquitetura dual, gestão de credenciais e âmbitos, motor de dados mestre de dicionário, feed transacional de alterações, API REST para EMR e SISLAB, pipeline assíncrono de outbox, orquestração de referências e interface web de gestão.

Fase atual: **S12 — Especificação de Contrato, SDK e Entrega**. Concluídos a especificação OpenAPI 3.1 com interface Scalar, validação de esquemas em CI, coleções de referência e a fachada FHIR R4 para sistemas EMR ([secção 11](#11-fachada-fhir-r4-para-sistemas-emr)). Em desenvolvimento: gem de cliente `sislab_sync_client` e documentação técnica de integração.

A cobertura LOINC do dicionário permanece por curar: a fachada FHIR opera com códigos nacionais e emite LOINC apenas onde este já foi mapeado.

