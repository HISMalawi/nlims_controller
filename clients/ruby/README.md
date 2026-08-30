# sislab_sync_client

O cliente de referência para um nó SISLAB Sync, em Ruby.

Três perfis, porque são três integrações e não são o mesmo trabalho:

| Perfil | Quem o usa | O que faz |
| --- | --- | --- |
| `Emr` | Um sistema clínico | Pede análises e recolhe resultados |
| `Lab` | Uma instalação SISLAB | Puxa o trabalho, executa-o e publica-o |
| `Node` | Outro nó | Entrega eventos à capital e traz o que lá está |

O que os três partilham é o que esta biblioteca existe para resolver: um único
envelope, uma única maneira de paginar um cursor, uma excepção por cada recusa
que o nó pode dar, e a idempotência que torna seguro repetir um pedido numa
linha que cai.

Sem dependências, de propósito. Um servidor de laboratório sem rota para o
rubygems pode instalar isto na mesma — ou simplesmente copiar `lib/`.

## Instalação

```ruby
gem "sislab_sync_client"
```

Ou, a partir deste repositório:

```ruby
gem "sislab_sync_client", path: "clients/ruby"
```

## Começar

A chave emite-se no nó, no ecrã **Clientes e chaves**. O segredo aparece uma vez.

```ruby
require "sislab_sync_client"

emr = SislabSyncClient.emr(base_url: "http://localhost:3000", api_key: ENV.fetch("SISLAB_KEY"))

emr.health   # => que nó é este, e que versão corre
emr.me       # => o que esta chave é e o que pode fazer
```

`me` é a primeira chamada a fazer quando alguma coisa não funciona: distingue
uma chave errada de um âmbito errado de um nó errado, que de outra maneira se
parecem todos com "não funciona".

## Pedir análises

```ruby
recibo = emr.create_order(
  patient: { national_id: "110100234567A", name: "Ana Macuácua", sex: "F", birthdate: "1991-04-12" },
  order: {
    priority: "routine",
    requested_by: "Dr. J. Sitoe",
    specimen_type: "MOZ-SP-0001"     # o código nacional basta
  },
  tests: [ "MOZ-TT-0042" ]           # uma análise, ou um painel, que se expande
)

recibo["tracking_number"]  # => o número que se escreve no tubo
```

A resposta é um recibo e não o pedido: o número de seguimento é o que interessa
guardar, e tudo o resto está a um `emr.order(tracking_number)` de distância.

`sending_facility_code` não é preciso — a chave já sabe por que unidade fala. O
laboratório também não: um nó é uma unidade sanitária, o pedido chega à unidade,
e a bancada que o executar reclama-o.

Um LIS submete em nome de um dos seus laboratórios e diz qual, no `lab:`. Um
laboratório que o nó nunca viu é registado a partir daqui, e não recusado:

```ruby
emr.create_order(
  lab: { code: "LAB01", name: "Laboratório de Bioquímica", phone: "840000111" },
  patient: { ... },
  order: { priority: "routine" },
  tests: [ "MOZ-TT-0042" ]
)
```

### Repetir sem duplicar

`create_order` gera uma `Idempotency-Key` e é por isso que se pode repetir. As
redes entre uma clínica e o seu laboratório caem a meio de um pedido; sem a
chave, uma repetição é uma segunda amostra que ninguém colheu.

Passe a sua própria quando tiver um identificador do seu lado — assim até uma
repetição feita por outro processo é reconhecida:

```ruby
emr.create_order(..., idempotency_key: "pedido-do-emr-#{id_interno}")
```

## Recolher resultados

Não se pergunta por cada pedido alguma vez levantado. Sonda-se um cursor:

```ruby
feed = emr.results(since: cursor_guardado)

feed.each_page do |leituras, cursor|
  leituras.each { |leitura| arquivar(leitura) }
  guardar_cursor(cursor)          # depois de cada página, não no fim
end
```

Guardar o cursor **a cada página** é o que permite ao processo morrer entre
páginas e continuar sem perder nem repetir uma leitura.

O cursor é uma revisão de um contador com fecho, nunca uma data: nada pode ser
gravado devagar ao ponto de ficar atrás de um cursor que já passou por ele.

Cada leitura traz o contexto para a arquivar — a amostra, o doente, a análise —
sem uma segunda chamada.

```ruby
emr.acknowledge(leitura["uuid"])   # diz ao nó que chegou ao processo clínico
```

Uma leitura que entretanto foi corrigida é recusada com `Conflict`, e o erro
nomeia a que a substituiu. Arquivar um valor substituído é precisamente o erro
que o `replaced_by_uuid` existe para evitar.

## O percurso do laboratório

```ruby
lab = SislabSyncClient.lab(base_url: ..., api_key: ...)

lab.pending_orders(since: cursor, lab_code: "LAB01").each_page do |pedidos, cursor|
  pedidos.each { |pedido| por_na_bancada(pedido) }
  guardar_cursor(cursor)
end

lab.claim(tn, lab_code: "LAB01")                         # fica com a amostra
lab.transition(tn, status: "specimen_collected")
lab.transition(tn, status: "in_progress")

lab.record_results(tn, final: true, actor: "Téc. M. Nhaca", results: [
  { test_type: "MOZ-TT-0042", indicator: "MOZ-IN-0007", value: "12.4", unit: "g/dL" }
])

lab.transition(tn, status: "completed")                  # fechar é um passo próprio
```

Um nó é uma unidade sanitária e tem várias bancadas. `lab_code` diz qual está a
falar: no feed, restringe-o ao trabalho dessa bancada mais tudo o que ainda não
foi reclamado; na reclamação, é quem fica com a amostra — e um pedido vindo de um
EMR chegou sem laboratório nenhum, pelo que é aqui que ganha um. Sem `lab_code`,
o feed devolve a unidade inteira.

`final: true` termina as análises que aquelas leituras cobrem. Fechar o pedido é
uma transição à parte: um laboratório pode ter mais a acrescentar a uma amostra
cuja primeira análise já está pronta.

Uma correcção é uma leitura nova sobre uma análise que continua `completed` —
envia-se da mesma maneira, e o nó marca a antiga como substituída.

Ainda: `lab.add_tests`, `lab.reject`, `lab.dispatch_referral`,
`lab.receive_referral`, `lab.reject_referral`.

## Entre nós

```ruby
node = SislabSyncClient.node(base_url: url_do_nacional, api_key: chave_de_no)

node.heartbeat(node_code: "HCM", outbox_pending: 4, outbox_failing: 1)
node.push_events(node_code: "HCM", events: lote)      # no máximo 500 de cada vez
node.inbound(node_code: "HCM", since: cursor).each_page { |eventos, cursor| ... }
```

A entrega é **pelo menos uma vez** e guardar é idempotente por `event_uuid`: o
mesmo lote a chegar duas vezes é reconhecido, não duplicado. Aplicar é **em
sequência** por agregado — um evento cujo antecessor não chegou espera, e a
resposta nomeia em `rejected` o que a capital não conseguiu aplicar.

## Quando o nó recusa

Cada recusa tem a sua classe, e cada classe traz o `code` do nó:

| Excepção | `code` |
| --- | --- |
| `Unauthenticated` | `unauthenticated` |
| `InsufficientScope` | `insufficient_scope` |
| `FacilityMismatch` | `facility_mismatch` |
| `NodeMismatch` | `node_mismatch` |
| `NotFound` | `not_found` |
| `Conflict` | `conflict` |
| `Unprocessable` | `unprocessable` |
| `RateLimited` | `rate_limited` |
| `TransportError` | — o nó não respondeu |

```ruby
begin
  emr.create_order(...)
rescue SislabSyncClient::Unprocessable => e
  logger.warn("#{e.field}: #{e.message}")
end
```

Ramifique sempre pela **classe** ou pelo `code`. A `message` é portuguesa,
escrita para uma pessoa, e pode ser reescrita a qualquer momento.

`RateLimited` é respeitado sozinho: o cliente espera o que o cabeçalho
`Retry-After` disser e tenta de novo, até três vezes. Um erro de transporte só é
repetido onde repetir não pode fazer o trabalho duas vezes — uma leitura, ou
uma escrita que leve `Idempotency-Key`.

## Substituir o transporte

`Transport` é trocável. O nó usa isso para conduzir este cliente contra si
próprio nos seus testes, sem abrir um socket — qualquer objecto que responda a
`call(method:, path:, params:, body:, headers:)` com `[status, headers, body]`
serve.

```ruby
SislabSyncClient::Emr.new(
  connection: SislabSyncClient::Connection.new(base_url: ..., api_key: ..., transport: meu_transporte)
)
```

## O contrato

Este cliente segue [`docs/sislab-sync/openapi.yaml`](../../docs/sislab-sync/openapi.yaml),
que cada nó também serve em `/api-docs`. O contrato é verificado em CI contra as
rotas reais e contra cada resposta que a suite produz, e este cliente é
conduzido contra um nó a sério em `spec/clients/reference_client_spec.rb`.
