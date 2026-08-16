# SISLAB Sync

Sincronização de dados laboratoriais entre unidades sanitárias e o nível nacional.

A mesma aplicação corre em dois modos:

| Modo | Papel |
| --- | --- |
| `local` | Nó de uma unidade sanitária. Recebe pedidos do EMR, serve o SISLAB, gera números de rastreio e empurra tudo para o nacional. |
| `national` | Nó central. É a fonte do dicionário, recebe os eventos dos nós locais e encaminha as amostras referidas. |

O modo é decidido por `SISLAB_SYNC_MODE` e por mais nada. A aplicação recusa-se
a arrancar sem ele.

> Sucede ao NLIMS Controller. O plano completo da reconstrução está em
> [`docs/sislab-sync/plano.html`](docs/sislab-sync/plano.html).

## Arrancar

```bash
cp .env.local.example .env      # ou .env.national.example
docker compose up
```

Verificar que o nó está de pé e saber qual é:

```bash
curl -s localhost:3000/api/v3/health | jq
{
  "data": { "mode": "local", "node_code": "HCM", "version": "2.0.0-dev", "time": "…" },
  "meta": {},
  "errors": []
}
```

Correr os dois nós ao mesmo tempo: use directorias separadas com
`COMPOSE_PROJECT_NAME` e `APP_PORT` distintos em cada `.env`.

## Desenvolvimento sem Docker

Precisa de Ruby 3.3.8, MySQL 8 (ou MariaDB) e Redis a correr localmente.

```bash
bundle install
export SISLAB_SYNC_MODE=local SISLAB_SYNC_NODE_CODE=DEV
export DATABASE_HOST=127.0.0.1 DATABASE_USER=root DATABASE_PASSWORD=…
bin/rails db:prepare
bin/rails server
```

## Testes

```bash
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
```

A suite corre nos dois modos em CI. Uma rota, um job ou um initializer que só
funcione num deles falha lá, e não numa instalação.

## Estado

Em construção. Passo actual: **S1 — fundação e modo dual**. Os passos, com
critérios de aceitação e commits, estão no plano.
