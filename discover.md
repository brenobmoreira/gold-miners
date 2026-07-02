# Discover — achados técnicos (JaCaMo / Jason / CArtAgO)

Registro dos achados, armadilhas ("gotchas") e decisões de design encontrados durante
o desenvolvimento. Útil como referência para o time e material para o relatório.

---

## 1. CArtAgO mapeia `String` Java → **string** Jason (não átomo)

**Achado (crítico).** Quando um artefato CArtAgO publica uma propriedade observável
com valor `String` (ex.: `defineObsProperty("reserved", x, y, "teamA")`), esse valor
chega ao agente como uma **string Jason** `"teamA"` — **não** como o átomo `teamA`.

**Evidência.** Decompilando `jaca.JavaLibrary.objectToTerm(Object)` (jar `jaca-3.1`):
para `instanceof java.lang.String` ele chama
`ASSyntax.createString(...) -> StringTerm`. Números viram `NumberTerm`; `Boolean` vira
`true/false`; um objeto que já é `Term` é preservado.

**Consequência.** Em Jason, `"teamA"` (string) **não unifica** com `teamA` (átomo).
Um filtro `not reserved(X,Y,teamA)` (átomo) **nunca casaria** com a crença real
`reserved(5,10,"teamA")` (string) → a lógica compila mas **não faz efeito** em runtime.

**Correção adotada.** Representar o time como **string** também no lado Jason:
```jason
team("teamA") :- .my_name(miner1).
```
Assim `team(T)` devolve `T = "teamA"` (string) e casa com a propriedade observável.

**Regra geral.** Ao trocar valores entre artefato e agente, alinhar os tipos:
- inteiro Java ↔ número Jason ✔
- String Java ↔ string Jason `"..."` (NÃO átomo) ⚠
- para um átomo, passar um `jason.asSyntax.Term` já pronto (acopla o artefato ao Jason).

---

## 2. `hasObsPropertyByTemplate` em vez de `getObsPropertyByTemplate` + null

**Achado.** `getObsPropertyByTemplate(name, args...)` tem comportamento ambíguo quando
não há propriedade correspondente (retorno `null` vs. exceção não é óbvio pelo bytecode).

**Correção.** Usar `hasObsPropertyByTemplate(name, args...)` (retorna `boolean`) para
checar existência antes de definir/remover — evita depender do comportamento ambíguo.

```java
if (hasObsPropertyByTemplate("reserved", x, y, team)) { ok.set(false); }
else { defineObsProperty("reserved", x, y, team); ok.set(true); }
```

---

## 3. Operações de artefato são atômicas → resolvem corrida de reserva

**Achado / decisão.** Colocar a reserva de ouro num **artefato CArtAgO** (e não mediada
por mensagens entre agentes) faz com que `reserve`/`release` sejam **atômicas**. Isso
elimina de graça a condição de corrida de dois parceiros reservando ao mesmo tempo.

---

## 4. Reserva **intra-time** (não global) — decisão de design

**Decisão.** `reserve(X,Y,Team)` só falha se o **mesmo time** já reservou a peça.
- Parceiros da mesma dupla **não colidem** (cooperação intra-time).
- O outro time **não** é bloqueado → os dois times **disputam** o mesmo ouro (competição
  inter-time). Coerente com o modelo de coalizões (ver `plan.md`).

---

## 5. Corrida rara é auto-corrigida pela recuperação de falha existente

**Achado.** Não é preciso `if/else` + retry no `handle` para tratar a corrida em que dois
parceiros escolhem o mesmo ouro no mesmo instante:
- Caso comum: `choose_gold` já **filtra** o ouro reservado pela dupla.
- Corrida rara: quem chega segundo **falha no `pick`** (ouro já não está lá) → cai em
  `-!handle`, que **libera e reescolhe**.

Permitiu simplificar o `handle` para o estilo linear (só +2 linhas: `reserve`/`release`),
mantendo o comportamento (com um custo mínimo: uma viagem à toa no caso raro).

---

## 6. `.my_name(X)` para identidade e pertencimento

**Achado.** `.my_name(X)` unifica `X` com o nome do próprio agente. Serve tanto para o
agente saber "sou eu?" (exercício h, comemoração) quanto para **derivar o time** por
regra sem precisar de configuração externa (Fase 1 do projeto):
```jason
team("teamA") :- .my_name(miner1).
```

---

## 7. `.jcm`: bug herdado `dummy.as l`

**Achado.** O `gold_miners.jcm` original tinha um typo — `agent miner2 : dummy.as l`
(espaço no meio de "asl"). Corrigido ao apontar todos os mineradores para `miner1.asl`.

---

## 8. Percepção de ouro é local e persistente

**Achado (comportamento do ambiente).** O `MiningPlanet` só publica `cell(X,Y,gold)`
para as **9 células ao redor** do agente. O minerador guarda como crença própria
(`+cell(X,Y,gold) <- +gold(X,Y)`), que **persiste** mesmo depois de sair de perto. Ou
seja: o agente conhece só o ouro que **já viu**, não o mapa todo.

---

## 10. Divisão de regiões (F3) vs. capacidade (F2): redundância → complementaridade

**Achado.** Ao introduzir a divisão de regiões (Feature 3), o repasse por capacidade
(Feature 2) ficou **redundante e desperdiçado**: um agente sobre carga repassava um ouro
da **própria** região ao parceiro, que — estando na **outra** região — não conseguia
tratá-lo (só guardava a crença). Visto no log:
`[miner4] forwarding gold(20,20) to miner3` (gold na região do miner4).

**Consequência conceitual.** A divisão de regiões já faz o balanceamento estático que a
capacidade buscava; mas **não** faz balanceamento **dinâmico** — se todo o ouro cai numa
região, um agente afoga e o outro fica ocioso.

**Reconciliação adotada.** Separar os dois papéis, tornando-os complementares:
- **Roteamento (`@pregion`):** ouro percebido **fora** da minha região → repasso ao
  parceiro (dono daquela região). `.send(P,tell,gold(X,Y))`.
- **Ajuda entre regiões (`@pcell3`, repropósito da F2):** ouro **da minha** região quando
  estou sobrecarregado (`in_my_region(X) & C > N`) → peço ao parceiro para cruzar e
  ajudar. `.send(P,achieve,help(gold(X,Y)))`; o parceiro **ocioso** cruza e trata
  (o `handle` não checa região), depois volta à sua região no `choose_gold`.

Lição: features de coordenação podem se **sobrepor**; vale checar se uma subsome a outra
e, se sim, redefinir papéis para que sejam complementares (estático + dinâmico).

---

## 9. Ambientes (world ids) têm depósitos diferentes

**Achado.** `WorldModel`: mapas 1–3 têm depósito em `(0,0)`; mapa 4 e 5 em `(5,27)`;
mapa 6 em `(16,16)`. Por isso o exercício d) (ler `depot(_,X,Y)` em vez de assumir
`(0,0)`) só é testável a partir do mapa 4. O id do mundo é o 1º parâmetro de
`MiningPlanet(id, agId)` no `.jcm`.

---

## 11. `.jcm`: injeção de crenças por agente + formato multi-linha obrigatório

**Achado (útil).** O `.jcm` suporta `beliefs: t1, t2, ...` por agente — as crenças
entram na base do agente no start. Usamos isso para **ligar as flags de ablação por
agente sem duplicar o `.asl`** (um mecanismo fica OFF simplesmente por estar ausente):
```
agent miner1 : miner1.asl {
    beliefs: use(reservation), use(regions)
    focus: mining.m1view, mining.goldReg
}
```
Verificado: a ajuda (`@pcell3`) só dispara quando `use(help)` é injetado.

**Armadilha.** O bloco de agente **em uma linha só** quebra o parser:
`agent miner3 : miner1.asl { focus: ... }` → `ParseException ... Was expecting ":"`.
Solução: usar sempre o formato **multi-linha** (chaves e cláusulas em linhas próprias),
como no `gold_miners.jcm`.

**Bônus.** Parametrizamos o `build.gradle` (`args findProperty('jcm') ?: 'gold_miners.jcm'`)
para rodar qualquer config: `./gradlew run -Pjcm=experiments/exp_c3.jcm`.

---

## 12. Primeira ablação foi subdimensionada (aprendizado metodológico)

**Achado.** A primeira bateria (5 configs, mapa 3, 40s, 1 execução cada — ver
`experiments/runs/<ts>/report.md`) deu **inconclusiva**: diferenças de ±1–2 entregas,
dentro do ruído, sem tendência. Causas: contagens minúsculas (3–5), execução única (sem
média), viés de posição inicial, e **mapa pequeno/esparso** (13 ouros → pouca contenção,
que é justamente onde a coordenação deveria brilhar).

**Lição.** A infraestrutura de ablação funciona; falta **poder estatístico**: rodadas
longas (até esgotar o ouro), repetidas (média ± desvio), com papéis dos times trocados
(cancelar viés) e sob **maior contenção** (mapa denso / mais agentes). Reportar isso
honestamente é, em si, um bom item de "método e limitações" no relatório.

---

# Material para o relatório (demonstração, resultados, aprendizados)

## Demonstração

- **Como rodar:** `./gradlew run` (mapa id=3, 35×35). GUI com réguas de coordenadas; a
  saída dos agentes vai para `log/mas-0.log`.
- **O que se vê:** 2 duplas competindo — **Time A azul** (miner1,2), **Time B vermelho**
  (miner3,4); número do agente fica **amarelo** ao carregar ouro. Depósito em (0,0).
- **Mensagens que evidenciam a coordenação (no log):** reserva/roteamento (dupla não
  duplica alvo; times disputam entre si); ajuda (`asking ... to help` / `Crossing to
  help` / `Busy, can't help`); roteamento dinâmico (troca de posições `at(X,Y)`); placar
  (`(<time>) I have dropped N`, `Agent A from <time> is winning`).

## Método — experimento de ablação

Cada mecanismo é uma **flag** ligável/desligável (todas ON por padrão): `use(reservation)`
(F1), `use(regions)` (F3a estático), `use(routing)` (F3b dinâmico), `use(help)` (F2).
Permite **medir a contribuição de cada um** em vez de assumir. Configurações-alvo (rodar
em vários mapas/seeds, medir `team_score`):

| Config | reservation | regions | routing | help |
|---|:--:|:--:|:--:|:--:|
| Ingênuo (baseline) | ❌ | ❌ | ❌ | ❌ |
| Só reserva | ✅ | ❌ | ❌ | ❌ |
| Reserva + regiões (estático) | ✅ | ✅ | ❌ | ✅ |
| Reserva + proximidade (dinâmico) | ✅ | ❌ | ✅ | ✅ |
| Tudo | ✅ | ✅ | ✅ | ✅ |

> Métrica ainda a implementar: `team_score` (placar por equipe) para quantificar.

## Resultados qualitativos (até aqui)

- Reserva intra-dupla **funciona**: sem colisões dentro do time; disputas só entre times.
- Ajuda entre parceiros **funciona**: parceiro ocioso cruza e ajuda; ocupado recusa.
- Roteamento dinâmico e estático **coexistem** via flags (comparáveis no experimento).
- **Quantitativo (qual config vence) ainda não medido** — depende do `team_score`.

## Aprendizados (para discussão no relatório)

1. **Contribuição própria vs. base:** toda a coordenação (times, reserva, capacidade,
   regiões, roteamento) é nossa; o tutorial só forneceu a mineração base.
2. **Features de coordenação podem se sobrepor** (achado técnico #10): a divisão de
   regiões subsumiu o balanceamento da capacidade → redefinimos a capacidade como
   *ajuda entre regiões* para serem complementares.
3. **Divisão estática de regiões é uma proxy fraca** de "otimizar rotas": rígida, força
   detours e desbalanceia. O **roteamento dinâmico por proximidade** (parceiros trocam
   posição, o mais perto pega) cumpre melhor o objetivo de comunicação direta.
4. **Ceticismo guia o método:** não assumir que um mecanismo ajuda — medir por ablação.
5. **Cooperação vs. competição:** o cenário-base é competitivo (placar individual);
   reenquadramos como **coalizões** (cooperação intra-dupla, competição inter-dupla).
