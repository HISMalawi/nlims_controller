# SISLAB Sync

Sincronização de dados laboratoriais entre unidades sanitárias e o nível nacional.

A mesma aplicação corre em dois modos:

| Modo | Papel |
| --- | --- |
| `local` | Nó de uma unidade sanitária. Recebe pedidos do EMR, serve o SISLAB, gera números de rastreio e empurra tudo para o nacional. |
| `national` | Nó central. É a fonte do dicionário, recebe os eventos dos nós locais e encaminha as amostras referidas. |

O modo é decidido por `SISLAB_SYNC_MODE` e por mais nada. A aplicação recusa-se
a arrancar sem ele, e as rotas que só existem num dos modos não são sequer
desenhadas no outro.

> Sucede ao NLIMS Controller. O plano completo da reconstrução está em
> [`docs/sislab-sync/plano.html`](docs/sislab-sync/plano.html).

---

## 1. Requisitos

Docker é o caminho suportado. Precisa apenas de:

- Docker e Docker Compose

Para correr fora do Docker, veja a [secção 7](#7-desenvolvimento-sem-docker).

---

## 2. Arrancar em cinco passos

### 2.1. Escolher o que este nó é

```bash
cp .env.local.example .env       # nó de unidade sanitária
# ou
cp .env.national.example .env    # nó nacional
```

Edite o `.env`. O mínimo a rever num nó local é `SISLAB_SYNC_NODE_CODE` — deve
ser o código da unidade sanitária, porque é por ele que o nó se identifica ao
nacional e é ele que entra nos números de rastreio.

### 2.2. Levantar os serviços

```bash
docker compose up
```

Na primeira vez isto constrói a imagem, cria a base de dados, corre as migrações
e — em `development` — semeia dados de demonstração.

### 2.3. Confirmar que está de pé, e o que é

```bash
curl -s localhost:3000/api/v3/health | jq
```

```json
{
  "data": { "mode": "local", "node_code": "HCM", "version": "2.0.0-dev", "time": "…" },
  "meta": {},
  "errors": []
}
```

### 2.4. Entrar na interface

Em `development`, a semente cria dois utilizadores e uma chave de API de
demonstração. As credenciais **não são escritas para o log** — ficam num
ficheiro só legível por si:

```bash
cat tmp/demo_credentials.txt
```

Abra `http://localhost:3000` e entre com o utilizador `admin` que lá está.

Num nó a sério não há semente nenhuma. Crie a primeira conta à mão:

```bash
docker compose exec app bin/rails "users:create[Ana Machava,ana@hcm.gov.mz,admin]"
```

A palavra-passe é gerada e mostrada **uma única vez**. Não há registo dela em
lado nenhum: só o resumo criptográfico é guardado.

### 2.5. Emitir a chave que o EMR ou o SISLAB vai usar

Pela interface, em **Clientes e chaves** → *Novo cliente* → *Emitir chave*. O
segredo aparece uma vez e não volta a aparecer.

Ou pela linha de comandos:

```bash
docker compose exec app bin/rails api_client:create \
  NAME="EMR do HCM" KIND=emr FACILITY_CODE=HCM

docker compose exec app bin/rails api_key:issue \
  CLIENT=HCM SCOPES="orders:write,orders:read,results:read,dictionary:read"
```

---

## 3. Os serviços do `docker compose`

| Serviço | O que faz |
| --- | --- |
| `app` | Puma, na porta `APP_PORT` (3000 por omissão). Prepara a base de dados ao arrancar. |
| `sidekiq` | Os trabalhos periódicos: puxar o dicionário, empurrar a outbox, puxar as entregas. Só num nó local é que há trabalhos agendados. |
| `css` | O compilador do Tailwind em modo *watch*. Só faz falta em desenvolvimento. |
| `mysql` | MySQL 8.4. |
| `redis` | Redis 7, para o Sidekiq e para o contador de rate limit. |

```bash
docker compose up -d mysql redis      # só a infra-estrutura
docker compose logs -f app            # seguir a aplicação
docker compose exec app bin/rails c   # consola
docker compose down                   # parar
docker compose down -v                # parar e apagar os dados
```

---

## 4. Correr os dois nós ao mesmo tempo

Necessário a partir do passo S9, e é como se prova que a sincronização funciona.
Use directorias separadas, cada uma com o seu `.env`, e dê a cada uma um
`COMPOSE_PROJECT_NAME` e um `APP_PORT` distintos:

```bash
# na directoria do nó nacional
COMPOSE_PROJECT_NAME=sislab_national APP_PORT=3100 docker compose up

# na directoria do nó local, com o .env a apontar para o nacional
SISLAB_SYNC_NATIONAL_URL=http://host.docker.internal:3100
SISLAB_SYNC_NATIONAL_API_KEY=<chave de tipo `node` emitida no nacional>
```

A chave que o nó local usa é emitida **no nacional**, para um cliente de tipo
`node`, com os âmbitos `sync:push`, `sync:pull` e `dictionary:read`.

---

## 5. Variáveis de ambiente

### Identidade do nó

| Variável | Obrigatória | Para que serve |
| --- | --- | --- |
| `SISLAB_SYNC_MODE` | sim | `local` ou `national`. Sem ela a aplicação não arranca. |
| `SISLAB_SYNC_NODE_CODE` | em modo local | Como este nó se identifica. Use o código da unidade sanitária. |
| `SISLAB_SYNC_NATIONAL_URL` | em modo local | Onde vive o nó nacional. |
| `SISLAB_SYNC_NATIONAL_API_KEY` | em modo local | A chave com que este nó fala com o nacional. |
| `SISLAB_SYNC_PUSH_BATCH` | não | Eventos por lote no envio da outbox. 100 por omissão. |

### Base de dados e cache

| Variável | Notas |
| --- | --- |
| `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_PASSWORD` | Ligação ao MySQL. |
| `DATABASE_NAME` | A base de dados **deste nó**. |
| `TEST_DATABASE_NAME` | Só para a suite. Existe separada de propósito: se o ambiente de teste lesse `DATABASE_NAME`, correr os testes truncava a base de dados do nó. `sislab_sync_test` por omissão. |
| `REDIS_URL` | Sidekiq e rate limit. |

### Trabalhos periódicos (só em modo local)

| Variável | Omissão | O que agenda |
| --- | --- | --- |
| `SYNC_PUSH_CRON` | `* * * * *` | Envia a outbox e o heartbeat. |
| `SYNC_PULL_CRON` | `* * * * *` | Puxa as entregas de amostras referidas e resultados. |
| `DICTIONARY_PULL_CRON` | `*/5 * * * *` | Puxa as alterações do dicionário. |

### Outras

| Variável | O que serve |
| --- | --- |
| `API_RATE_LIMIT_PER_MINUTE` | Pedidos por minuto por chave. |
| `MLAB_DB_*` | Base de dados de origem para importar o dicionário do mLab. Só no nacional. |
| `LOINC_CSV` | Caminho para o `Loinc.csv` da versão LOINC, usado na curação. |
| `WEB_CONCURRENCY`, `RAILS_MAX_THREADS`, `SIDEKIQ_CONCURRENCY` | Dimensionamento. |

---

## 6. Scripts e tarefas

### 6.1. `bin/`

| Comando | O que faz |
| --- | --- |
| `bin/rails` | O de sempre. |
| `bin/setup` | Instala as gems, prepara a base de dados, limpa logs e arranca o servidor. `--skip-server` para não arrancar; `--reset` para recriar a base de dados. |
| `bin/dev` | Servidor **e** compilador de Tailwind ao mesmo tempo, via `foreman`. Fora do Docker. |
| `bin/ci` | Estilo e segurança: RuboCop, `bundler-audit`, auditoria do importmap e Brakeman. **Não corre a suite** — essa corre em separado (ver 6.6). |
| `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit` | Cada verificação por si. |
| `bin/docker-entrypoint` | Usado pela imagem: prepara a base de dados antes de arrancar o Puma. |

### 6.2. Utilizadores da interface

Nada a ver com as chaves de API: uma pessoa tem palavra-passe, um sistema tem
chave, e nunca autenticam o mesmo pedido.

```bash
bin/rails "users:create[Ana Machava,ana@hcm.gov.mz,admin]"   # papéis: admin, operator
bin/rails "users:reset_password[ana@hcm.gov.mz]"             # termina todas as sessões abertas
bin/rails users:list
```

### 6.3. Clientes e chaves de API

```bash
bin/rails api_client:create NAME="EMR do HCM" KIND=emr FACILITY_CODE=HCM
bin/rails api_client:list

bin/rails api_key:issue CLIENT=HCM SCOPES="orders:write,results:read" [EXPIRES_AT=2027-01-01]
bin/rails api_key:list
bin/rails api_key:revoke KEY=a1b2c3d4        # uuid ou prefixo
```

Âmbitos disponíveis: `orders:read`, `orders:write`, `results:read`,
`results:write`, `referrals:write`, `dictionary:read`, `dictionary:write`,
`sync:push`, `sync:pull`.

### 6.4. Dicionário

Só o nó nacional é dono do dicionário. As tarefas de escrita recusam-se a correr
noutro modo.

```bash
bin/rails dictionary:import_from_mlab           # importa do mLab; tudo entra como rascunho
bin/rails dictionary:quality                    # relatório de problemas → tmp/dictionary_quality.csv
ACTOR="Ana Machava" SKIP_BLOCKED=1 \
  bin/rails dictionary:promote                  # publica os rascunhos utilizáveis
bin/rails dictionary:status                     # o que o dicionário tem neste momento

bin/rails dictionary:pull                       # (nó local) puxa as alterações do nacional
```

### 6.5. Curação de códigos LOINC

O catálogo importado chegou sem nenhum código LOINC. Sem eles, um código `MOZ-`
não significa nada fora do país. A versão LOINC não está neste repositório — tem
licença própria e descarrega-se de [loinc.org](https://loinc.org).

```bash
bin/rails dictionary:loinc:coverage             # onde estamos, por entidade

LOINC_CSV=tmp/Loinc.csv \
  bin/rails dictionary:loinc:worksheet          # → tmp/loinc_worksheet.csv, com candidatos

# ... alguém do laboratório preenche a coluna loinc_code ...

LOINC_CSV=tmp/Loinc.csv \
  bin/rails "dictionary:loinc:apply[tmp/loinc_worksheet.csv]"        # simulação

LOINC_CSV=tmp/Loinc.csv ACTOR="Ana Machava" APPLY=1 \
  bin/rails "dictionary:loinc:apply[tmp/loinc_worksheet.csv]"        # a sério
```

Os candidatos são uma ajuda de leitura, não uma decisão: a coluna `loinc_code`
vem sempre vazia, mesmo quando a correspondência parece óbvia. A aplicação é
tudo-ou-nada — um ficheiro com um código errado não altera nada.

### 6.6. Testes e verificações

```bash
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec
docker compose run --rm app bundle exec rubocop
docker compose run --rm app bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
docker compose run --rm app bin/bundler-audit
```

A suite corre nos **dois modos**, e é assim que corre em CI:

```bash
docker compose run --rm -e RAILS_ENV=test \
  -e SISLAB_SYNC_MODE=local -e SISLAB_SYNC_NODE_CODE=LOCAL01 app bundle exec rspec

docker compose run --rm -e RAILS_ENV=test \
  -e SISLAB_SYNC_MODE=national -e SISLAB_SYNC_NODE_CODE=NATIONAL app bundle exec rspec
```

Uma rota, um job ou um initializer que só funcione num dos modos falha lá, e não
numa instalação. Os testes que só fazem sentido num modo declaram-no com
`mode: :local` ou `mode: :national` e são saltados no outro.

---

## 7. Desenvolvimento sem Docker

Precisa de Ruby 3.3.8, MySQL 8 (ou MariaDB) e Redis a correr localmente.

```bash
bundle install

export SISLAB_SYNC_MODE=local SISLAB_SYNC_NODE_CODE=DEV
export DATABASE_HOST=127.0.0.1 DATABASE_USER=root DATABASE_PASSWORD=…

bin/rails db:prepare
bin/dev                 # servidor + Tailwind
```

Nota: o compose e o CI usam MySQL 8.4. O MariaDB já divergiu três vezes de
maneiras que não davam erro nenhum — colunas `json` lidas como `longtext`,
`UPDATE ... WHERE` a falhar sob concorrência, e o `innodb_snapshot_isolation`.
Por isso é que o `config/database.yml` fixa `transaction_isolation` em
`READ-COMMITTED`. Qualquer trabalho de esquema ou de concorrência deve ser
confirmado em Docker antes de se dar por feito.

---

## 8. A interface

Em português, na mesma aplicação, com sessão de utilizador separada das chaves
de API.

| Ecrã | Serve para | Modo |
| --- | --- | --- |
| Painel | Estado da sincronização, outbox, último contacto, cursores | ambos |
| Pedidos | Pesquisa por tracking number, NID ou nome; detalhe com o histórico completo | ambos |
| Amostras referidas | Em trânsito, recebidas, rejeitadas, com tempo de transporte | ambos |
| Dicionário | Navegação em qualquer modo; edição, promoção e retirada só no nacional | ambos |
| Fila de sincronização | Eventos falhados com o erro e botão de reprocessar | local |
| Nós | Último contacto, versão, atraso do cursor | nacional |
| Clientes e chaves | Emitir, rodar, revogar, ver última utilização | ambos (admin) |
| Auditoria | Que cliente chamou o quê, e o que foi recusado | ambos (admin) |

Dois papéis: **operador** lê tudo e reprocessa eventos; **administrador** também
emite chaves e altera o dicionário.

---

## 9. Estado

Em construção, no ramo `v2`. Concluídos S1 a S11 — fundação e modo dual, chaves
de API, dicionário, importação do mLab, feed de alterações, núcleo
transaccional, API do EMR, API do SISLAB, outbox e envio, referências ponta a
ponta, e a interface.

A seguir: **S12 — contrato, SDK e entrega**. Os passos, com critérios de
aceitação e commits, estão no [plano](docs/sislab-sync/plano.html).
