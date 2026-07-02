# Discover — achados conceituais e aprendizados (SMA / JaCaMo)

Registro dos **conceitos, decisões de design e lições** encontrados durante o
desenvolvimento — material para o relatório. (Detalhes de implementação/API/sintaxe
foram deixados de fora de propósito; eles vivem no próprio código e nos comentários.)

---

## 1. Reserva por artefato compartilhado é atômica → resolve a corrida

Colocar a reserva de ouro num **artefato compartilhado** (um quadro de avisos), e não
mediá-la por troca de mensagens entre agentes, faz com que reservar/liberar sejam
operações **atômicas**. Isso elimina a condição de corrida de dois parceiros reservarem
a mesma peça ao mesmo tempo. Lição de SMA: **estado compartilhado atômico** é uma forma
mais simples e robusta de coordenação do que um protocolo de mensagens equivalente.

---

## 2. Reserva **intra-time**, não global — decisão de design

A reserva só bloqueia o **mesmo time**:

- Parceiros da mesma dupla **não colidem** (cooperação intra-time).
- O outro time **não** é bloqueado → os dois times **disputam** o mesmo ouro (competição
  inter-time).

Coerente com o modelo de coalizões (ver `plan.md`): benevolência dentro do grupo,
auto-interesse entre grupos. O escopo da reserva é, ele próprio, uma escolha de design
que codifica a política de cooperação.

---

## 3. Corrida rara é auto-corrigida pela recuperação de falha

Não é preciso lógica extra (checagem + retry) para tratar a corrida em que dois parceiros
escolhem o mesmo ouro no mesmo instante:

- Caso comum: a escolha de alvo já **filtra** o ouro reservado pela dupla.
- Corrida rara: quem chega segundo **falha ao pegar** (o ouro já não está lá) e a
  recuperação de falha simplesmente **libera e reescolhe**.

Lição: em BDI, a **recuperação de falha** do próprio ciclo de raciocínio já cobre o caso
raro — dá para manter o plano linear e simples, ao custo de uma viagem à toa ocasional.

---

## 4. Percepção de ouro é local e persistente

O ambiente só revela o ouro nas células **ao redor** do agente. O minerador guarda o que
vê como crença própria, que **persiste** mesmo depois de sair de perto. Ou seja: o agente
conhece só o ouro que **já viu**, não o mapa todo. Isso torna a **comunicação** entre
parceiros (compartilhar avistamentos e posições) genuinamente útil — cada agente tem
informação **parcial** do mundo.

---

## 5. Regiões (estático) vs. capacidade (dinâmico): redundância → complementaridade

Ao introduzir a **divisão de regiões**, o **repasse por capacidade** ficou redundante e
desperdiçado: um agente sobrecarregado repassava um ouro da **própria** região ao
parceiro, que — estando na **outra** região — não conseguia tratá-lo.

**Consequência conceitual.** A divisão de regiões já faz o balanceamento **estático**;
mas **não** faz balanceamento **dinâmico** — se todo o ouro cai numa região, um agente
afoga e o outro fica ocioso.

**Reconciliação.** Separar os dois papéis para serem complementares:
- **Roteamento:** ouro percebido **fora** da minha região → repasso ao parceiro (dono
  daquela região).
- **Ajuda entre regiões:** ouro **da minha** região quando estou sobrecarregado → peço ao
  parceiro **ocioso** para cruzar e ajudar; depois ele volta à sua região.

Lição: features de coordenação podem se **sobrepor**; vale checar se uma subsome a outra
e, se sim, redefinir papéis (estático + dinâmico) para que sejam complementares.

---

## 6. Ambientes (mapas) têm depósitos diferentes

Cada mapa do cenário tem o depósito em uma posição distinta (alguns em `(0,0)`, outros
não). Por isso o agente deve **consultar** onde é o depósito em vez de assumir uma posição
fixa — caso contrário só funciona em parte dos mapas. Aprendizado geral: **não hardcodar**
o que o ambiente já informa.

---

## 7. Tipos precisam casar na fronteira agente ↔ artefato (falha silenciosa)

Ao trocar valores entre um artefato e um agente, os **tipos precisam casar**. Um
identificador que, no lado do artefato, é publicado como texto **não unifica** com um
símbolo (átomo) do lado do agente. O perigo é que isso **compila e não gera erro** — a
lógica simplesmente **nunca dispara** em tempo de execução.

Foi o bug mais custoso do projeto: um filtro de reserva que "estava certo" mas não fazia
efeito. Lição de SMA: na integração entre a dimensão de **agentes** e a de **ambiente**,
uma incompatibilidade de tipos vira um **erro silencioso** — alinhar os tipos nas duas
pontas é parte do design, não um detalhe.

---

## 8. A primeira ablação foi subdimensionada (aprendizado metodológico)

A primeira bateria (5 configs, uma execução curta cada — ver
`experiments/runs/<ts>/report.md`) deu **inconclusiva**: diferenças de ±1–2 entregas,
dentro do ruído, sem tendência. Causas: contagens minúsculas, execução única (sem média),
viés de posição inicial e **mapa esparso** (pouca contenção — justamente onde a
coordenação deveria brilhar).

Lição: a infraestrutura de ablação funciona; falta **poder estatístico** — rodadas longas
(até esgotar o ouro), repetidas (média ± desvio), com papéis dos times trocados (cancelar
viés) e sob **maior contenção**. Reportar isso honestamente é, em si, um bom item de
"método e limitações" no relatório.

---

# Material para o relatório (demonstração, resultados, aprendizados)

## Demonstração

- **Como rodar:** `./gradlew run` (mapa id=3, 35×35).
- **O que se vê:** 2 duplas competindo — **Time A azul** (miner1,2), **Time B vermelho**
  (miner3,4); o número do agente fica **amarelo** ao carregar ouro.
- **Evidências de coordenação:** a dupla não duplica o mesmo alvo e os times disputam
  entre si (reserva/roteamento); parceiro ocioso cruza para ajudar o sobrecarregado, e o
  ocupado recusa (capacidade); parceiros trocam posição e o mais próximo pega o ouro
  (roteamento dinâmico); o placar por equipe evolui.

## Método — experimento de ablação

Cada mecanismo é uma **flag** ligável/desligável (todas ON por padrão): reserva (F1),
regiões estáticas (F3a), proximidade dinâmica (F3b), ajuda por capacidade (F2). Permite
**medir a contribuição de cada um** em vez de assumir. Configurações-alvo (Time B sempre
ingênuo; Time A avança C0→C4), medindo `team_score`:

| Config | reserva | regiões | proximidade | ajuda |
|---|:--:|:--:|:--:|:--:|
| Ingênuo (baseline) | ❌ | ❌ | ❌ | ❌ |
| Só reserva | ✅ | ❌ | ❌ | ❌ |
| Reserva + regiões (estático) | ✅ | ✅ | ❌ | ✅ |
| Reserva + proximidade (dinâmico) | ✅ | ❌ | ✅ | ✅ |
| Tudo | ✅ | ✅ | ✅ | ✅ |

## Resultados qualitativos (até aqui)

- Reserva intra-dupla **funciona**: sem colisões dentro do time; disputas só entre times.
- Ajuda entre parceiros **funciona**: parceiro ocioso cruza e ajuda; ocupado recusa.
- Roteamento dinâmico e estático **coexistem** via flags (comparáveis no experimento).
- **Quantitativo (qual config vence) ainda não medido de forma conclusiva** — depende de
  um experimento com poder estatístico (ver aprendizado #8).

## Aprendizados (para discussão no relatório)

1. **Contribuição própria vs. base:** toda a coordenação (times, reserva, capacidade,
   regiões, roteamento) é nossa; o tutorial só forneceu a mineração base.
2. **Features de coordenação podem se sobrepor** (achado #5): a divisão de regiões
   subsumiu o balanceamento da capacidade → redefinimos a capacidade como *ajuda entre
   regiões* para serem complementares.
3. **Divisão estática de regiões é uma proxy fraca** de "otimizar rotas": rígida, força
   detours e desbalanceia. O **roteamento dinâmico por proximidade** (parceiros trocam
   posição, o mais perto pega) cumpre melhor o objetivo de comunicação direta.
4. **Ceticismo guia o método:** não assumir que um mecanismo ajuda — medir por ablação.
5. **Cooperação vs. competição:** o cenário-base é competitivo (placar individual);
   reenquadramos como **coalizões** (cooperação intra-dupla, competição inter-dupla).
