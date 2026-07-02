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

| Ex. | O que foi feito | Conceito reutilizável |
|---|---|---|
| a) | Minerador anuncia o destino aleatório sorteado | anúncio; seleção de plano por contexto |
| b) | Distingue "cheguei perto" vs. "alvo inalcançável" | seleção por contexto do plano |
| c) | Minerador conta o ouro entregue | atualização de crença |
| d) | Entrega no depósito real (consultado, não fixo) | consulta a crença |
| e) | Minerador reporta a entrega ao líder | comunicação agente → agente |
| f) | Líder anuncia mudança de liderança | comparação de placar |
| g) | Líder difunde o vencedor a todos | difusão (broadcast) a todos |
| h) | Vencedor comemora ao ser notificado | reação a mensagem; identidade própria |
| i) | Troca para o ouro mais próximo visto no caminho | revisão de intenção; distância |
| j) | (Twitter) — **pulado** (restrição da API do X) | — |

Configuração atual: 1 líder + 4 mineradores, mapa id=3.

---

## 6. Features do projeto final

Escopo de cada feature no modelo de duplas:

### Feature 1 — Reserva de tarefas (intra-dupla) — ✅ CONCLUÍDA (branch feat1)

**Problema:** parceiros da mesma dupla podem perseguir o mesmo ouro — desperdício.

**Decisão-chave:** a reserva é **intra-dupla, NÃO global**. Assim:
- Parceiros **não colidem** (cooperação dentro do time).
- Os dois times **disputam** o mesmo ouro (corrida inter-time — coerente com a competição).

**Abordagem:** um **artefato compartilhado** como quadro de avisos, com operações
**atômicas** de reservar/liberar uma peça de ouro para um time. A atomicidade resolve a
condição de corrida entre parceiros. Ao escolher o próximo alvo, o agente filtra o ouro já
reservado **pela própria dupla**; reserva ao assumir e libera após entregar (ou ao
trocar/falhar de alvo).

**Reutiliza:** a lógica de escolha de alvo e o padrão de estado compartilhado.

**Como ficou:**
- Reserva **intra-dupla** via artefato compartilhado; o time é derivado do próprio nome
  do agente (decisões e armadilhas em `discover.md`).
- Plano de tratamento mantido **linear e simples** (estilo do professor): a corrida rara
  é auto-corrigida pela recuperação de falha, dispensando checagem + retry.
- **Visibilidade de time nas mensagens:** o minerador marca seus anúncios com o time e
  reporta a entrega ao líder, que anuncia o time do agente.
- Verificada em execução (mapa id=3): sem colisões intra-dupla, disputas apenas
  inter-time, sem exceções.

### Feature 2 — Gerenciamento de capacidade (recrutar o parceiro) — 🔜 branch feat2

**Problema:** se a carga de ouro conhecida ultrapassa o limite individual, acionar o parceiro.

**Abordagem (simples, à prova de loop):** um **limiar de capacidade** por agente e a
noção de **parceiro** (o outro membro da dupla). Quando o minerador está **ocupado** e sua
carga conhecida passa do limiar, ele **repassa** o ouro recém-percebido ao parceiro.

- O parceiro **ocioso** reage e vai minerar → recrutamento.
- O parceiro **ocupado** só guarda a informação (considera na próxima escolha de alvo).
- **Guarda contra ping-pong:** só repassa ouro que ele mesmo percebeu, nunca o que veio
  do parceiro.
- A **reserva** (Feature 1) evita que os dois tratem o mesmo ouro repassado.

**Reutiliza:** comunicação agente→agente (e), reação a mensagens (h), contagem de carga,
artefato de reserva.

### Feature 3 — Comunicação direta de rotas (intra-dupla)

**Problema:** parceiros cruzando caminhos ou indo à mesma região.

**Abordagem:** parceiros **trocam posição/alvo** e usam **distância** para dividir regiões
ou ceder alvos ao que estiver mais perto. Refinamento em cima da Feature 1.

**Reutiliza:** comunicação agente→agente, cálculo de distância, artefato de reserva.

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
- **Flags de ablação** por agente (reserva F1, regiões estáticas F3a, proximidade
  dinâmica F3b, ajuda por capacidade F2): cada mecanismo pode ser ligado/desligado por
  agente e fica OFF por estar ausente.
- **Métrica `team_score`** medida no ambiente e exibida no **placar da UI**
  (caixinha azul/vermelha).
- **Um arquivo por configuração** em `experiments/`, rodável individualmente
  (`./gradlew run -Pjcm=experiments/exp_c3.jcm`).

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

| Propriedade | Onde aparece no comportamento |
|---|---|
| Autonomia | cada minerador roda seu próprio ciclo de raciocínio e escolhe o que fazer |
| Reatividade | reage a percepções (avistar ouro, fim da simulação) e a mensagens (quem está ganhando) |
| Pró-atividade | persegue metas (escolher e tratar o ouro, ir a uma posição); vagueia para descobrir ouro |
| Habilidade social | comunica-se com parceiros e líder e reage a mensagens de outros agentes |

**Conceitos BDI no comportamento:**
- **Beliefs:** estado do agente (livre/ocupado, ouro conhecido, posição, placar, quem
  está ganhando, depósito, time).
- **Desires/metas:** ir para perto, tratar o ouro, escolher o próximo alvo.
- **Intentions:** metas em execução; o agente manipula as **próprias intenções**
  (raciocínio meta-nível) ao trocar de alvo quando aparece um ouro melhor.

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
- **`discover.md`** reúne os achados conceituais e aprendizados — material para a seção de
  "dificuldades/lições" do relatório.
