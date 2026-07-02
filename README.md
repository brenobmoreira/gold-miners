# Gold Miners Multiagentes (JaCaMo) — Projeto Final

Sistema multiagente no cenário **Gold Miners**, estendendo o tutorial oficial do JaCaMo
com **coordenação entre agentes**. Os mineradores formam **duas duplas** que **cooperam
internamente** e **competem entre si** (modelo de coalizões): reserva de tarefas,
recrutamento por capacidade e otimização de rotas.

**Equipe:** Breno Barroso Moreira (202404406), Rodrigo Artur Soares Novaes (202403935),
Gabriele Oliveira Nicolli (202404085).

---

## Início rápido

```bash
./gradlew run                                   # MAS padrão (coordenação completa)
./gradlew run -Pjcm=experiments/exp_c3.jcm      # uma configuração do experimento
```

Abre a GUI **Mining World** (grid com réguas de coordenadas) + o **MAS Console** com as
mensagens dos agentes. A saída dos agentes também vai para `log/mas-0.log`.

- **Time A = azul** (miner1, miner2) · **Time B = vermelho** (miner3, miner4).
- Número do agente fica **amarelo** enquanto carrega ouro.
- **Placar** no rodapé: caixinha azul (Team A) e vermelha (Team B) = `team_score`.

Requisitos: JDK 21, ambiente gráfico (a saída dos agentes NÃO vai para o stdout).

---

## Estrutura do repositório

| Caminho | O que é |
|---|---|
| `gold_miners.jcm` | **MAS padrão**: 1 líder + 4 mineradores (coordenação completa), mapa id=3 |
| `src/agt/miner1.asl` | **O minerador** (mineração base do tutorial + toda a nossa coordenação) |
| `src/agt/leader.asl` | Líder: placar e anúncio de liderança |
| `src/agt/miner.asl`, `dummy.asl` | Agentes do tutorial (só exploram / parados) — legado |
| `src/agt/jia/*.java` | Ações internas em Java (busca A\*, distância, aleatório) |
| `src/env/mining/MiningPlanet.java` | Artefato CArtAgO: o "mundo" (mover, `pick`, `drop`, percepções) |
| `src/env/mining/GoldRegistry.java` | **Artefato de reserva** de ouro (quadro de avisos, `reserve`/`release`) |
| `src/env/mining/WorldModel.java` | Modelo do grid + contadores de `team_score` |
| `src/env/mining/WorldView.java` | GUI: cores por time, réguas de coordenadas, placar |
| `experiments/exp_c{0..4}.jcm` | **Configurações do experimento** de ablação |
| `experiments/runs/<timestamp>/` | Resultados: capturas `cX.png` + `report.md` |
| `plan.md` | Plano do projeto (objetivos, features, fundamentação BDI) |
| `discover.md` | **Achados técnicos** (armadilhas JaCaMo/Jason/CArtAgO) e material de relatório |
| `solutions/` | Soluções de referência do professor (exercícios do tutorial) |
| `doc/` | Material do cenário original |

---

## O modelo multiagente

- **Líder** — coordena o placar; anuncia quando uma dupla assume a liderança.
- **4 Mineradores** (`miner1.asl`) — percebem ouro na vizinhança, pegam, entregam no
  depósito e escolhem o próximo. Organizados em 2 duplas:
  - **Time A** = miner1, miner2  ·  **Time B** = miner3, miner4.
- **Artefatos CArtAgO**: cada minerador tem sua `MiningPlanet` (interface com o mundo) e
  todos compartilham o `GoldRegistry` (reserva).

---

## Coordenação (as features) e as flags de ablação

Cada mecanismo é ligável/desligável por uma **flag** (crença `use(...)`), injetada por
agente no `.jcm` via `beliefs:`. Assim dá para medir a contribuição de cada um.

| Flag | Feature | O que faz |
|---|---|---|
| `use(reservation)` | **F1 — Reserva** | dupla não persegue o mesmo ouro (artefato atômico `GoldRegistry`); times disputam entre si |
| `use(help)` | **F2 — Capacidade/Ajuda** | agente sobrecarregado pede ao parceiro para cruzar e ajudar |
| `use(regions)` | **F3a — Regiões (estático)** | cada parceiro cuida de metade do mapa (por X); ouro fora da região é roteado ao parceiro |
| `use(routing)` | **F3b — Proximidade (dinâmico)** | parceiros trocam posição (comunicação direta); o **mais próximo** pega o ouro |

No `gold_miners.jcm` padrão, **todas as flags estão ligadas** para os dois times.
Detalhes de design e decisões (ex.: reserva intra-dupla, regiões vs. roteamento) em
`plan.md`; armadilhas técnicas em `discover.md`.

---

## Experimento de ablação

**Objetivo:** medir a contribuição de cada mecanismo de coordenação (não assumir que
ajuda — medir).

**Protocolo:** Time B sempre **ingênuo** (sem flags); Time A avança C0→C4:

| Config | reservation | regions | routing | help |
|---|:--:|:--:|:--:|:--:|
| `exp_c0` | ❌ | ❌ | ❌ | ❌ |
| `exp_c1` | ✅ | ❌ | ❌ | ❌ |
| `exp_c2` | ✅ | ✅ | ❌ | ✅ |
| `exp_c3` | ✅ | ❌ | ✅ | ✅ |
| `exp_c4` | ✅ | ✅ | ✅ | ✅ |

**Métrica:** `team_score` (contado no ambiente e exibido no placar).

```bash
./gradlew run -Pjcm=experiments/exp_c2.jcm
```

Resultados de cada bateria ficam em `experiments/runs/<timestamp>/` (capturas + relatório).
> A 1ª bateria (2026-07-02) ficou **inconclusiva** por estar subdimensionada — ver o
> `report.md` correspondente. Uma versão com poder estatístico (rodadas longas, repetidas,
> maior contenção) está planejada.

---

## Documentos

- **`plan.md`** — plano completo: equipe, cronograma, objetivos, features, experimento,
  fundamentação BDI (para o relatório).
- **`discover.md`** — achados técnicos e lições (para a seção de dificuldades do relatório).
