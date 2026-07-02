# Mini-relatório do experimento de ablação — 2026-07-02 17:28

## Setup

- **Mapa:** id=3 (35×35), depósito em (0,0), ~13 peças de ouro iniciais.
- **Times:** Time A (azul, miner1/2) vs Time B (vermelho, miner3/4).
- **Protocolo:** Time B sempre **ingênuo** (sem flags); Time A avança C0→C4.
  Uma execução por config, janela fixa de ~40s, placar lido no ambiente
  (`goldsTeamA`/`goldsTeamB`) e nas mensagens de entrega do log.
- Capturas: `c0.png … c4.png` nesta pasta.

| Config | Time A (flags) | A | B |
|---|---|:--:|:--:|
| C0 | ingênuo | 3 | 5 |
| C1 | reserva | 4 | 4 |
| C2 | reserva + regiões (estático) + ajuda | 4 | 3 |
| C3 | reserva + proximidade (dinâmico) + ajuda | 4 | 5 |
| C4 | tudo | 5 | 4 |

## Interpretação — INCONCLUSIVO (resultado honesto)

**Não dá para concluir que a coordenação ajuda a partir destes números.** As
diferenças (±1–2 entregas) estão **dentro do ruído**, e não há tendência monotônica
(C0 tem A<B; C3 tem A<B). Ou seja: o experimento, como rodado, está **subdimensionado**.

## Por que ficou inconclusivo

1. **Contagens minúsculas (3–5):** 40s só rendem poucas entregas → ruído domina.
2. **Uma única execução por config:** sem média sobre seeds → alta variância
   (o mesmo C4 deu A:4/B:1 num teste e A:5/B:4 noutro).
3. **Viés de posição inicial:** as duplas começam em pontos diferentes do mapa; com
   poucas entregas, a posição pesa mais que a coordenação.
4. **Mapa pequeno/esparso (13 ouros):** teto baixo e pouca **contenção** — times
   ingênuos raramente colidem, então a coordenação tem pouco a melhorar.
5. **Depósito em (0,0):** viagens de ida/volta longas dominam o tempo e mascaram
   ganhos de coordenação.

## Recomendações para um experimento com poder estatístico

- **Rodadas longas:** até esgotar o ouro (ou vários minutos), não 40s.
- **Métrica melhor:** *tempo até coletar N ouros* (ou até esvaziar o mapa), não
  contagem num instante fixo.
- **Repetição:** N execuções por config, reportar **média ± desvio**.
- **Cancelar viés:** rodar cada config com os papéis dos times **trocados** e mediar.
- **Estressar contenção:** mapa maior/mais denso, mais agentes por time, ou adicionar
  ouro concentrado (clicando) — é sob contenção que a coordenação deve brilhar.

## Conclusão

A infraestrutura de ablação (flags por `.jcm`, placar no ambiente, capturas
automáticas) **funciona**. O que falta é **poder estatístico**: rodadas mais longas,
repetidas e sob maior contenção. Este é, em si, um aprendizado metodológico válido
para o relatório: *a primeira ablação foi subdimensionada e não separou sinal de ruído.*
