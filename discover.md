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

## 9. Ambientes (world ids) têm depósitos diferentes

**Achado.** `WorldModel`: mapas 1–3 têm depósito em `(0,0)`; mapa 4 e 5 em `(5,27)`;
mapa 6 em `(16,16)`. Por isso o exercício d) (ler `depot(_,X,Y)` em vez de assumir
`(0,0)`) só é testável a partir do mapa 4. O id do mundo é o 1º parâmetro de
`MiningPlanet(id, agId)` no `.jcm`.
