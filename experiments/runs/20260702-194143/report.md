# Relatório — validação do fix do ouro do canto + 2ª ablação — 2026-07-02

## Setup

- **Mapa:** cenário 4 (35×35), depósito em (5,27), 13 peças de ouro (uma no canto (34,34)).
- **Times:** Time A (azul, miner1/2) vs Time B (vermelho, miner3/4).
- **Protocolo:** Time B sempre **ingênuo**; Time A avança C0→C4 (liga reserva, regiões,
  proximidade e ajuda). 5 repetições por config, velocidade máxima (`sleep=0`).
- **Métrica:** `team_score` (entregas por time, lidas do log).

## 1. Fix do ouro do canto (34,34) — ✅ PROVADO

O bug (exploração sorteava alvo com `jia.random(RX,W-1)`, nunca a última linha/coluna →
o ouro em (34,34) era **impossível** de descobrir) foi corrigido para `jia.random(RX,W)`.

**Evidência limpa (rodada isolada C4):** o log registra
`[miner*] I am going to go near (34,34)`, `Gold perceived: gold(34,34)`,
`Handling gold(34,34)` e o encerramento
`=== GAME OVER: all 13 gold collected ... ===`. Os 13 ouros — o do canto inclusive —
foram coletados. Antes do fix isso nunca acontecia (platô em 12/13). **Esta parte deu certo.**

Também foi adicionado **fim de jogo automático**: ao coletar todo o ouro, o ambiente
registra `GAME OVER` com o placar final e os mineradores param.

## 2. As features são melhores que o ingênuo? — ❌ SEM PROVA (e provavelmente enviesado)

Médias de `team_score` por config (5 reps):

| Config | Time A (coord) | Time B (ingênuo) | Vencedor |
|---|:--:|:--:|:--:|
| C0 (ambos ingênuos) | 5.4 | 6.6 | **B** |
| C1 | 5.4 | 6.6 | **B** |
| C2 | 4.4 | 7.4 | **B** |
| C3 | 5.0 | 7.0 | **B** |
| C4 (A com tudo) | 4.0 | 8.0 | **B** |

O Time B (ingênuo) vence em **todas** as configs, e a diferença **cresce** conforme o
Time A liga mais coordenação — o oposto de "coordenação ajuda".

### Causa raiz: viés de posição inicial (confound dominante)

Posições de largada no cenário 4:

- **Time A:** miner1 (1,0), miner2 (20,0) — na **borda superior**, longe do ouro.
- **Time B:** miner3 (3,20), **miner4 (20,20)** — e **(20,20) é uma célula de ouro**, no
  meio do **cluster denso** (7 peças em 19–20 × 20–24).

O Time B nasce **dentro da pilha de ouro**. Isso já aparece em **C0 (ambos ingênuos)**,
onde B > A (6.6 × 5.4) — ou seja, o viés existe **antes** de qualquer coordenação. A
coordenação do Time A não compensa a desvantagem; regiões inclusive prendem o miner1 na
metade esquerda (pobre em ouro). Direção corroborada por uma rodada limpa isolada
(C4: A=5, B=8).

### Ressalva de método

A bateria automatizada tem um **artefato de medição** (todas as linhas marcaram
`completed=1` em `5s` — a detecção de `GAME OVER` pegou log residual entre execuções no
modo de velocidade máxima). Por isso os **tempos** não são confiáveis; a **direção** (B ≥ A
em toda config) é que é sólida, apoiada na rodada limpa e na análise do mapa.

## Conclusão

- O **fix do canto (34,34) está provado e funcionando** (todos os 13 ouros coletados;
  `GAME OVER` dispara).
- **Não há prova de que as features batem o ingênuo.** O experimento está **enviesado**
  pela posição inicial (Time B nasce no cluster de ouro) e **subdimensionado** — mesma
  limitação metodológica da 1ª bateria.

## Para ter uma resposta de verdade (próximo passo)

1. **Trocar os papéis** dos times (rodar espelhado) e mediar → cancela o viés de largada.
2. **Mais contenção** (mapa denso / ouro concentrado) → onde a coordenação deve brilhar.
3. **Isolamento limpo por execução** (um JVM por run) → elimina o artefato de medição.
4. **N maior**, com média ± desvio.
