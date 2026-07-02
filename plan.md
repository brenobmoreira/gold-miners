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

### Feature 1 — Reserva de tarefas (intra-dupla)

**Problema:** parceiros da mesma dupla podem perseguir o mesmo ouro — desperdício.

**Decisão-chave:** a reserva é **intra-dupla, NÃO global**. Assim:
- Parceiros **não colidem** (cooperação dentro do time).
- Os dois times **disputam** o mesmo ouro (corrida inter-time — coerente com a competição).

**Abordagem:** artefato CArtAgO `GoldRegistry` como quadro de avisos, com operações
atômicas `reserve(X,Y,Team)` / `release(X,Y,Team)` e propriedade observável
`reserved(X,Y,Team)`. Operações atômicas resolvem a condição de corrida entre parceiros.

- No `!choose_gold`: filtrar ouros já reservados **pela própria dupla**.
- Antes de `!handle(gold)`: `reserve(X,Y,MeuTime)` (se falhar, escolher outro).
- Ao entregar/desistir: `release(X,Y,MeuTime)`.

**Reutiliza:** `.findall`, lógica do `choose_gold`, padrão de estado compartilhado.

### Feature 2 — Gerenciamento de capacidade (recrutar o parceiro)

**Problema:** se a carga de ouro conhecida ultrapassa o limite individual, acionar o parceiro.

**Abordagem:** Contract-Net simplificado, **dentro da dupla**. Ao detectar fila de ouro
conhecido acima de um limiar `capacity(N)`, o agente faz `.send(Parceiro, tell, help_needed(...))`.
O parceiro ocioso (`free`) reage com `+help_needed(...)` e assume parte da carga.

**Reutiliza:** `.send` (e), reação a crenças (h), lógica de limiar (f).

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

Com as duas duplas, montamos um experimento controlado:

- **Time A** — usa coordenação completa (reserva + recrutamento + rotas).
- **Time B** — "ingênuo": cada agente por si, sem coordenação (o `miner1.asl` atual).
- Roda-se a simulação e mede-se o **`team_score`** de cada time.

**Hipótese:** o Time A (coordenado) coleta mais ouro que o Time B (ingênuo) no mesmo
tempo/mapa — prova quantitativa de que a coordenação melhora a eficiência.

**Variáveis a registrar:** ouro coletado por time, movimentos desperdiçados, colisões
de alvo evitadas, tempo até esgotar o ouro do mapa. Repetir em múltiplos mapas/seeds.

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

- Rodar: `./gradlew run` (o usuário sempre executa; abre a GUI com réguas de coordenadas).
- Desenvolver o projeto final num branch `projeto-final`, mantendo o tutorial concluído
  intacto na `master`.
