# Projeto Final — Gold Miners Multiagentes (JaCaMo)

## 1. Equipe

- Breno Barroso Moreira (202404406)
- Rodrigo Artur Soares Novaes (202403935)
- Gabriele Oliveira Nicolli (202404085)

## 2. Cenário escolhido

**Gold Miners.** Justificativa: estabilidade da integração com o JaCaMo e alta
quantidade de documentação disponível para o aprendizado prático da disciplina.

## 3. Cronograma

| Período | Atividade |
|---|---|
| Início de junho | Definição da estratégia inicial |
| Junho | Modelagem BDI básica dos agentes; implementação prática no JaCaMo |
| Início de julho | Testes de simulação e preparação da apresentação |
| Final de julho | Finalização dos experimentos práticos e entrega do relatório |

**Entregáveis:** implementação funcional, apresentação e relatório escrito.

## 4. Objetivo geral

Partir da arquitetura base do Gold Miners (agentes especialistas + quadro de avisos
compartilhado) e focar o desenvolvimento na **otimização da coordenação** entre os
agentes.

**Enquadramento: cooperação intra-time + competição inter-time (2 duplas).**
Em vez de um cenário puramente competitivo (cada minerador por si) ou puramente
cooperativo (todos no mesmo objetivo), adotamos um modelo **híbrido de coalizões**:

- **Cooperação DENTRO da dupla** — parceiros coordenam para não desperdiçar esforço.
- **Competição ENTRE as duplas** — cada time tenta coletar mais ouro que o outro.

Esse é um padrão clássico de SMA (times/coalizões): agentes **benevolentes dentro do
grupo** e **auto-interessados entre grupos**. Justifica tanto os mecanismos de
coordenação quanto a métrica competitiva de sucesso.

### 4.1. Times

4 mineradores organizados em 2 duplas:

- **Time A** = { miner1, miner2 }
- **Time B** = { miner3, miner4 }

### 4.2. Métrica de sucesso: placar de equipe

Aposentamos o placar/vitória **individual** (`score` / `winning` dos exercícios f–h,
que eram mecânica competitiva de indivíduo) e introduzimos um **placar de equipe**:

- `team_score(timeA, N)` vs `team_score(timeB, M)`.
- O `winning`/broadcast dos exercícios f–h é **repropósito** para o nível de time
  ("qual time está ganhando") — o trabalho não foi descartado, subiu de indivíduo → time.

---

## 5. Base já construída (tutorial Gold Miners)

O tutorial serviu de aquecimento e entregou os blocos de comunicação/coordenação que
o projeto final estende. Exercícios concluídos:

| Ex. | O que foi feito | Bloco reutilizável |
|---|---|---|
| a) | Minerador anuncia o destino aleatório sorteado | `.print`, seleção de plano |
| b) | Distingue "cheguei perto" vs. "alvo inalcançável" | contexto de planos |
| c) | Minerador conta ouro entregue (`score`) | crença + operador `-+` |
| d) | Entrega no depósito real via `depot(_,X,Y)` | consulta a crença (`?`) |
| e) | Minerador reporta entrega ao líder | `.send(leader,tell,dropped)` |
| f) | Líder anuncia mudança de liderança (`winning`) | comparação `S+1 > SL` |
| g) | Líder difunde o vencedor a todos | `.broadcast(tell, winning(...))` |
| h) | Vencedor comemora ao ser notificado | reação a `[source(leader)]`, `.my_name` |
| i) | Troca para ouro mais próximo visto no caminho | `.desire` / `.drop_desire`, `jia.dist` |
| j) | (Twitter) — **pulado** (restrição da API do X) | — |

Configuração atual: `leader` + 4 mineradores rodando `miner1.asl`, mapa id=3.

---

## 6. Features do projeto final

Escopo de cada feature no modelo de duplas:

### Feature 1 — Reserva de tarefas (intra-dupla) — ✅ CONCLUÍDA (branch feat1)

**Problema:** parceiros da mesma dupla podem perseguir o mesmo ouro — desperdício.

**Decisão-chave:** a reserva é **intra-dupla, NÃO global**. Assim:
- Parceiros **não colidem** (cooperação dentro do time).
- Os dois times **disputam** o mesmo ouro (corrida inter-time — coerente com a competição).

**Abordagem:** artefato CArtAgO `GoldRegistry` como quadro de avisos, com operações
atômicas `reserve(X,Y,Team)` / `release(X,Y,Team)` e propriedade observável
`reserved(X,Y,Team)`. Operações atômicas resolvem a condição de corrida entre parceiros.

- No `!choose_gold`: filtrar ouros já reservados **pela própria dupla**.
- No `!handle(gold)`: `reserve` (melhor-esforço) e `release` após entregar.
- Ao falhar/trocar de alvo: `release`.

**Reutiliza:** `.findall`, lógica do `choose_gold`, padrão de estado compartilhado.

**Como ficou (implementação real):**
- `src/env/mining/GoldRegistry.java` — artefato com `reserve`/`release` (usa
  `hasObsPropertyByTemplate`).
- Times por regra de crença **string** (`team("teamA") :- .my_name(miner1).` etc.) —
  string (não átomo!) para casar com a propriedade observável (ver `discover.md` #1).
- `handle` mantido linear (estilo professor): a corrida rara é auto-corrigida pela
  recuperação de falha, então dispensa `if/else` + retry (ver `discover.md` #5).
- **Visibilidade de time nas mensagens:** o minerador marca seus prints com o time e
  envia `dropped(Team)` ao líder; o líder anuncia "Agent A from Team ...".
- Verificada em execução (`./gradlew run`, mapa id=3): sem colisões intra-dupla,
  disputas apenas inter-time, sem exceções.
- Achados técnicos documentados em `discover.md`.

### Feature 2 — Gerenciamento de capacidade (recrutar o parceiro) — 🔜 branch feat2

**Problema:** se a carga de ouro conhecida ultrapassa o limite individual, acionar o parceiro.

**Abordagem (simples, à prova de loop):** limiar `capacity(N)` por agente e regra
`partner(P)` (o outro membro da dupla). Quando o minerador está **ocupado** (`not free`)
e sua carga conhecida passa de `N`, ele **repassa** o ouro recém-percebido ao parceiro
com `.send(P, tell, gold(X,Y))`.

- O parceiro **ocioso** reage (plano `@pgold` existente) e vai minerar → recrutamento.
- O parceiro **ocupado** só guarda a crença (considera no próximo `choose_gold`).
- **Guarda contra ping-pong:** só repassa ouro de origem própria
  (`+gold(X,Y)[source(self)]`), nunca o que veio do parceiro.
- A **reserva** (Feature 1) evita que os dois tratem o mesmo ouro repassado.

**Reutiliza:** `.send` (e), reação a crenças (h), `.count` para o limiar, artefato de reserva.

### Feature 3 — Comunicação direta de rotas (intra-dupla)

**Problema:** parceiros cruzando caminhos ou indo à mesma região.

**Abordagem:** parceiros trocam `pos`/`target` via `.send` e usam `jia.dist` para dividir
regiões ou ceder alvos. Refinamento em cima da Feature 1.

**Reutiliza:** `.send`, `jia.dist`, artefato de reserva.

### Ordem de implementação

1. **Reserva de tarefas** — base; resolve o maior desperdício e cria o blackboard.
2. **Capacidade / recrutamento** — depende de detectar carga (usa dados da reserva).
3. **Rotas** — refinamento sobre as duas anteriores.

---

## 7. Abordagem em duas fases: Simples → Robusto

A organização em times será implementada em duas fases:

### Fase 1 — Simples (crenças)

Definir os times por **crenças** nos agentes: `team(miner1, timeA)`, etc. Rápido,
funciona de imediato, e é suficiente para validar a coordenação e rodar o experimento.

### Fase 2 — Robusto (Moise)

Migrar a organização em times para a dimensão **organizacional do JaCaMo (Moise)** —
grupos, papéis e missões formais. Mais "correto" academicamente; adiciona a terceira
dimensão do JaCaMo (além de Jason e CArtAgO). Se o tempo apertar, entra como
"trabalhos futuros" no relatório.

---

## 8. Experimento comparativo (resultado central do relatório)

**Infraestrutura (implementada):**
- **Flags de ablação** por agente, injetadas via `beliefs:` no `.jcm`:
  `use(reservation)` (F1), `use(regions)` (F3a estático), `use(routing)` (F3b dinâmico),
  `use(help)` (F2). Um mecanismo fica OFF por estar ausente.
- **Métrica `team_score`** medida no ambiente (`WorldModel.goldsTeamA/B`) e exibida no
  **placar da UI** (caixinha azul/vermelha).
- **Arquivos por config** em `experiments/exp_c{0..4}.jcm`; roda com
  `./gradlew run -Pjcm=experiments/exp_c3.jcm`.

**Protocolo:** Time B sempre **ingênuo** (sem flags); Time A avança C0→C4, para ver o
impacto de cada adição:

| Config | reservation | regions | routing | help |
|---|:--:|:--:|:--:|:--:|
| C0 | ❌ | ❌ | ❌ | ❌ |
| C1 | ✅ | ❌ | ❌ | ❌ |
| C2 | ✅ | ✅ | ❌ | ✅ |
| C3 | ✅ | ❌ | ✅ | ✅ |
| C4 | ✅ | ✅ | ✅ | ✅ |

**Resultado da 1ª bateria (2026-07-02): INCONCLUSIVO.** Diferenças dentro do ruído
(ver `experiments/runs/<ts>/report.md`). Causa: subdimensionado — contagens pequenas,
execução única, viés de posição inicial e mapa esparso (pouca contenção).

**Próximo passo (experimento com poder estatístico):** rodadas longas (até esgotar o
ouro), N repetições com **média ± desvio**, papéis dos times **trocados** (cancelar
viés) e **maior contenção** (mapa denso / mais agentes). Métrica: tempo até esgotar o
ouro, além do `team_score`.

---

## 9. Fundamentação BDI (para o relatório)

Definição de Wooldridge: *agente inteligente = ação autônoma flexível; flexível =
reativo + pró-ativo + social.*

| Propriedade | Onde aparece no código |
|---|---|
| Autonomia | cada minerador roda seu próprio ciclo de raciocínio; escolhe o que fazer |
| Reatividade | `+cell(X,Y,gold)`, `+gold(X,Y)`, `+winning(...)`, `+end_of_simulation` |
| Pró-atividade | `!choose_gold`, `!handle`, `!pos`; vaguear para descobrir ouro |
| Habilidade social | `.send`, `.broadcast`, reações a `[source(leader)]` |

**Conceitos BDI no código:**
- **Beliefs:** `free`, `gold(X,Y)`, `pos`, `score`, `winning`, `depot`, `team(...)`.
- **Desires/metas:** `!go_near`, `!handle`, `!choose_gold`, `!pos`.
- **Intentions:** metas em execução; manipuladas por `.desire` / `.drop_desire` /
  `.drop_all_desires` (raciocínio meta-nível — o agente lida com as próprias intenções).

**Raciocínio prático vs. teórico:**
- Teórico (o que é verdade): revisão de crenças a partir das percepções.
- Prático (o que fazer): deliberação (escolher a meta — ouro mais próximo, time ganhando)
  + means-ends (seleção de planos pelo contexto). É o ciclo de raciocínio do Jason.

**Mapeamento das features à teoria (para justificar decisões de design):**
- Modelo de duplas → **coalizões**: agentes benevolentes intra-grupo, auto-interessados inter-grupo.
- Reserva de tarefas → **habilidade social** (coordenação por estado compartilhado).
- Gerenciamento de capacidade → **pró-atividade** + **reatividade** + recrutamento social.
- Comunicação de rotas → **habilidade social** aplicada à eficiência.

---

## 10. Notas de execução

- Rodar: `./gradlew run` (abre a GUI com réguas de coordenadas; a saída dos agentes vai
  para `log/mas-0.log`, não para o stdout).
- **Branches:** cada feature na sua branch (`feat1`, `feat2`, ...), commits granulares;
  ao concluir e verificar, faz-se merge na `master`.
- **`discover.md`** reúne os achados técnicos (armadilhas JaCaMo/Jason/CArtAgO) — material
  para a seção de "dificuldades/lições" do relatório.
