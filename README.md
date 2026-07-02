# Gold Miners Multiagentes (JaCaMo) — Projeto Final

Sistema multiagente no cenário **Gold Miners**, estendendo o tutorial oficial do JaCaMo
com **coordenação entre agentes**. Quatro mineradores formam **duas duplas** que
**cooperam internamente** e **competem entre si** (modelo de coalizões). Cada dupla usa os
mesmos mecanismos de coordenação — **reserva de tarefas, recrutamento por capacidade,
divisão de regiões e roteamento por proximidade** — e o objetivo é entregar mais ouro que
a dupla adversária.

**Equipe:** Breno Barroso Moreira (202404406), Rodrigo Artur Soares Novaes (202403935),
Gabriele Oliveira Nicolli (202404085).

---

## Início rápido

```bash
./gradlew run
```

Abre a GUI **Mining World** (grid 35×35 com réguas de coordenadas) + o **MAS Console** com
as mensagens dos agentes. É o **duelo**: duas duplas, **ambas com coordenação completa**,
disputando o mesmo ouro até esgotá-lo.

- **Time A = azul** (miner1, miner2) · **Time B = vermelho** (miner3, miner4).
- O número do agente fica **amarelo** enquanto ele carrega ouro.
- **Placar** no rodapé: caixinha azul (Team A) e vermelha (Team B).
- Ao coletar todo o ouro, o jogo **encerra** com `GAME OVER` e o vencedor.

Requisitos: JDK 21 e ambiente gráfico (a saída dos agentes vai para a GUI e para
`log/mas-0.log`, **não** para o stdout).

---

## O duelo — demonstração ao vivo (roteiro para a banca)

O `./gradlew run` já é a demonstração: **Time A × Time B, os dois coordenados**. A ideia é
mostrar, no console, os mecanismos de coordenação **disparando de verdade** enquanto as
duas duplas competem.

### Como ler o console

Cada linha começa com o **nome do agente entre colchetes**:

- `[miner1]`, `[miner2]` → **Time A (azul)**
- `[miner3]`, `[miner4]` → **Time B (vermelho)**
- `[leader]` → o líder (placar) · `[MiningPlanet]` → o ambiente (fim de jogo)

Cada mecanismo imprime uma linha **com tag** (`[F1]`…`[F3b]`), então dá para apontar cada
feature acontecendo ao vivo, nas duas duplas.

### As frases que importam (cola de apresentação)

**Coordenação (aparece nas duas duplas):**

| Frase no console | Feature | Fala de apoio |
|---|---|---|
| `[F1 reserva] reservei gold(X,Y) para teamA` | **Reserva** | "os parceiros da dupla não pegam o mesmo ouro" |
| `[F3b rota] compartilhando minha posicao (X,Y) com miner2` | **Rota dinâmica** | "comunicação direta: o parceiro mais perto pega" |
| `[F3a regioes] gold(X,Y) fora da minha regiao -> repasso a miner2` | **Regiões** | "cada parceiro cuida de metade do mapa" |
| `[F2 ajuda] ... pedindo ajuda / cruzando para ajudar / ocupado, nao posso ajudar` | **Capacidade** | "sobrecarregado recruta o parceiro; ocioso cruza; ocupado recusa" |

**Placar e fim (os dois times):**

| Frase | Quando |
|---|---|
| `[minerX] (teamA/teamB) I have dropped N pieces of gold` | cada entrega no depósito |
| `[leader] Agent minerX from teamY is winning with N pieces` | mudança de liderança |
| `[minerX] I am the greatest!!!` | o líder atual comemora |
| `[MiningPlanet] === GAME OVER: all 13 gold collected. Team A=.. Team B=.. -> winner: ..` | **fim** do jogo |

**Pode ignorar** (ruído de exploração): `I am going to go near...`, `I've reached...`,
`I am at (..) which is near (..)`, `Gold distances: ...`, `Next gold is ...`.

### Passo a passo sugerido

1. `./gradlew run` e espere a GUI abrir.
2. Para **assistir com calma**, arraste o slider de velocidade (canto inferior esquerdo;
   começa em *max*, arraste em direção a *min* para desacelerar).
3. No *MAS Console*, aponte as tags `[F1]`…`[F3b]` saindo dos quatro mineradores — as duas
   duplas coordenam internamente enquanto competem entre si.
4. Acompanhe o **placar** no rodapé enquanto o ouro é entregue.
5. **(Opcional) crie contenção:** clique em células do grid para adicionar ouro
   concentrado — é aí que reserva e ajuda mais aparecem.
6. Ao coletar todo o ouro, aparece o `GAME OVER` com o vencedor e os agentes **param**.

> Observação para o ao vivo: com exploração aleatória, coletar **todos** os 13 (incluindo o
> do canto (34,34)) pode levar 1–2 min. Se o tempo for curto, foque nas **tags de
> coordenação + placar** (aparecem em segundos) e deixe o `GAME OVER` como final.

---

## O que foi implementado

Toda a coordenação é contribuição do projeto; o tutorial forneceu apenas a mineração base
(perceber ouro, pegar, entregar, escolher o próximo).

### Modelo de duplas (coalizões)

- **Time A** = { miner1, miner2 } · **Time B** = { miner3, miner4 }.
- **Cooperação dentro da dupla**, **competição entre as duplas** — agentes benevolentes
  intra-grupo e auto-interessados inter-grupo.
- **Placar de equipe** (`team_score`) no lugar do placar individual dos exercícios.

### Mecanismos de coordenação

- **F1 — Reserva de tarefas** (`GoldRegistry`, artefato compartilhado). Reserva **atômica**
  e **intra-dupla**: parceiros não perseguem o mesmo ouro; as duplas ainda disputam entre
  si. → `[F1 reserva]`
- **F2 — Capacidade / recrutamento.** Agente sobrecarregado (backlog acima da capacidade)
  pede ajuda ao parceiro; o ocioso cruza para ajudar, o ocupado recusa (sem loop). →
  `[F2 ajuda]`
- **F3a — Regiões (estático).** Cada parceiro cuida de metade do mapa (por X); ouro fora da
  região é roteado ao parceiro. → `[F3a regioes]`
- **F3b — Proximidade (dinâmico).** Parceiros trocam posição por comunicação direta; o mais
  próximo assume o ouro. → `[F3b rota]`

Cada mecanismo é uma **flag** (`use(...)`) ligável por agente no `.jcm`, então também é
possível ligá-los/desligá-los individualmente (ver *Flags* abaixo).

### Ambiente e correções

- **Fim de jogo automático.** Quando todo o ouro é entregue, o ambiente encerra a
  simulação: registra `=== GAME OVER ... -> winner: ... ===` com o placar final e os
  mineradores **param** (não voltam a vagar).
- **Ouro do canto (34,34) alcançável.** A exploração sorteava o alvo com
  `jia.random(RX,W-1)`; como `jia.random` já é exclusivo no topo, isso nunca sorteava a
  **última linha/coluna** (0..33 num mapa 35×35). Somado ao `go_near` (que para ao ficar
  *vizinho* do alvo), nenhum agente pisava na linha/coluna 34 e a percepção 3×3 nunca
  cobria o canto — o ouro em (34,34) era **impossível** de descobrir. Corrigido para
  `jia.random(RX,W)`/`jia.random(RY,H)`. Detalhe conceitual em `discover.md`.

### GUI

Réguas de coordenadas (estilo batalha naval), cores por time (azul/vermelho), número do
agente em **amarelo** ao carregar ouro, e o **placar** por equipe no rodapé.

---

## Estrutura do repositório

| Caminho | O que é |
|---|---|
| `gold_miners.jcm` | **MAS padrão / o duelo**: 1 líder + 4 mineradores, as duas duplas com coordenação completa, mapa 35×35 (cenário 4) |
| `src/agt/miner1.asl` | **O minerador** (mineração base do tutorial + toda a nossa coordenação) |
| `src/agt/leader.asl` | Líder: placar e anúncio de liderança |
| `src/agt/miner.asl`, `dummy.asl` | Agentes do tutorial (só exploram / parados) — legado |
| `src/agt/jia/*.java` | Ações internas em Java (busca A\*, distância, aleatório) |
| `src/env/mining/MiningPlanet.java` | Artefato CArtAgO: o "mundo" (mover, `pick`, `drop`, percepções, fim de jogo) |
| `src/env/mining/GoldRegistry.java` | **Artefato de reserva** de ouro (quadro de avisos, `reserve`/`release`) |
| `src/env/mining/WorldModel.java` | Modelo do grid + contadores de `team_score` |
| `src/env/mining/WorldView.java` | GUI: cores por time, réguas de coordenadas, placar |
| `experiments/exp_c{0..4}.jcm` | Configurações com flags ligadas/desligadas (ablação) |
| `experiments/run_battery.sh` | Runner de bateria (várias execuções, placar + captura) |
| `experiments/runs/<timestamp>/` | Resultados de cada bateria (capturas + `report.md`) |
| `plan.md` | Plano do projeto (objetivos, features, fundamentação BDI) |
| `discover.md` | **Achados técnicos** (armadilhas JaCaMo/Jason/CArtAgO) |
| `solutions/` | Soluções de referência do professor (exercícios do tutorial) |
| `doc/` | Material do cenário original |

---

## Flags (ligar/desligar cada mecanismo)

Cada feature é injetada por agente no `.jcm` via `beliefs:` — uma flag ausente deixa o
mecanismo **desligado**. No `gold_miners.jcm` (o duelo) **todas estão ligadas para as duas
duplas**. Os arquivos `experiments/exp_c{0..4}.jcm` trazem combinações diferentes, úteis
para inspecionar um mecanismo isolado:

| Flag | Feature |
|---|---|
| `use(reservation)` | F1 — Reserva |
| `use(help)` | F2 — Capacidade / Ajuda |
| `use(regions)` | F3a — Regiões (estático) |
| `use(routing)` | F3b — Proximidade (dinâmico) |

```bash
./gradlew run -Pjcm=experiments/exp_c1.jcm   # ex.: só reserva ligada no Time A
```

---

## Documentos

- **`plan.md`** — plano completo: equipe, cronograma, objetivos, features, fundamentação BDI.
- **`discover.md`** — achados técnicos e lições (para a seção de dificuldades do relatório).
