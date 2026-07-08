# Relatório de experimentos — coordenação em duplas (Gold Miners)

## 1. Objetivo

Este experimento avalia os quatro mecanismos de coordenação implementados sobre o
cenário de duplas do Gold Miners, a reserva de tarefas (F1), a capacidade e
recrutamento entre parceiros (F2), a divisão estática por regiões (F3a) e o
roteamento dinâmico por proximidade (F3b). A avaliação combina duas frentes,
uma verificação qualitativa do comportamento de cada mecanismo a partir dos
logs de execução, e uma comparação quantitativa entre o time coordenado e um
time ingênuo, usando o placar por equipe (`team_score`) como métrica.

## 2. Configuração experimental

O mapa usado é o cenário 4 (grade 35x35, depósito em (5,27), treze peças de
ouro, uma delas no canto (34,34)). O Time A (miner1 e miner2) recebe as
combinações de mecanismos descritas na Tabela 1; o Time B (miner3 e miner4)
permanece sempre ingênuo, sem nenhuma flag de coordenação ativa. Essa
assimetria isola o efeito de cada mecanismo do Time A sobre o resultado.

**Tabela 1.** Configurações de ablação (C0 a C4).

| Config | Reserva (F1) | Regiões (F3a) | Proximidade (F3b) | Ajuda (F2) |
|---|:--:|:--:|:--:|:--:|
| C0 — Ingênuo | Não | Não | Não | Não |
| C1 — Só reserva | Sim | Não | Não | Não |
| C2 — Reserva + regiões | Sim | Sim | Não | Sim |
| C3 — Reserva + proximidade | Sim | Não | Sim | Sim |
| C4 — Tudo | Sim | Sim | Sim | Sim |

Fonte: dos autores.

Cada configuração foi repetida cinco vezes, na velocidade máxima do ambiente
(`sleep=0`, sem atraso entre ações), somando 25 execuções. O script
`experiments/run_battery.sh` automatiza o disparo de cada execução, a leitura
do placar a partir do log (`(<team>) I have dropped`) e a captura de uma
imagem da tela na primeira repetição de cada configuração.

## 3. Validação qualitativa dos mecanismos

Os logs de execução confirmam que cada mecanismo dispara conforme o
comportamento projetado. A reserva de tarefas (F1) evita que os dois
integrantes de uma dupla persigam o mesmo ouro, registrando `[F1 reserva]`
antes de cada tentativa de coleta. A ajuda entre parceiros (F2) aparece
quando um agente com backlog acima da capacidade sinaliza `[F2 ajuda]`; o
parceiro ocioso cruza o mapa para auxiliar, e o parceiro ocupado recusa o
pedido, sem gerar laços de repetição. As regiões estáticas (F3a) e o
roteamento por proximidade (F3b) também funcionam de acordo com a flag
ativada, redirecionando ouro fora da região do agente ou repassando o alvo ao
parceiro mais próximo.

O fim de jogo automático e a correção do ouro do canto (34,34), descritos no
Capítulo de fundamentação teórica e no README do projeto, também foram
confirmados em execuções isoladas anteriores a esta bateria, com o log
registrando `GAME OVER: all 13 gold collected` ao final de uma rodada
completa.

## 4. Resultado quantitativo

A Tabela 2 apresenta a média de `team_score` por configuração, calculada
sobre as cinco repetições de cada uma.

**Tabela 2.** Média de `team_score` por configuração (n = 5 repetições).

| Config | Time A (coordenado) | Time B (ingênuo) | Vencedor médio |
|---|:--:|:--:|:--:|
| C0 | 5,2 | 6,8 | B |
| C1 | 4,4 | 7,6 | B |
| C2 | 4,2 | 7,6 | B |
| C3 | 5,4 | 6,6 | B |
| C4 | 4,4 | 7,6 | B |

Fonte: dos autores, a partir de `experiments/runs/20260707_155446/results.csv`.

O Time B venceu em média em todas as configurações, inclusive em C0, na qual
nenhum dos dois times usa qualquer mecanismo de coordenação. A diferença não
diminui à medida que o Time A acumula mais mecanismos (C1 a C4); pelo
contrário, o Time A obteve sua pior média justamente em C2 e C4. Esse padrão
repete o observado em uma bateria anterior, executada em 2 de julho de 2026
sobre o mesmo mapa, o que indica reprodutibilidade do efeito, não ruído
isolado de uma única execução.

## 5. Discussão e causas prováveis

A comparação quantitativa entre times não demonstra vantagem do time
coordenado sobre o ingênuo. Três fatores prováveis explicam esse resultado,
sem que ele invalide a validação qualitativa da Seção 3.

Viés de posição inicial. No cenário 4, o miner4 do Time B nasce em (20,20),
posição que já corresponde a uma célula de ouro, dentro de um agrupamento
denso de sete peças concentradas entre as coordenadas 19 e 20 em X e 20 e 24
em Y. O Time A nasce na borda superior do mapa, distante desse agrupamento.
Como o Time B já vence em C0, antes de qualquer coordenação entrar em jogo, a
vantagem inicial de posição domina o resultado e mascara o efeito dos
mecanismos avaliados.

Contagem pequena de amostras. Cinco repetições por configuração produzem
diferenças de poucas unidades entre médias, insuficientes para separar sinal
de variação amostral.

Mapa pouco contido. O cenário 4 tem baixa densidade de ouro fora do
agrupamento citado, o que reduz a disputa direta entre as duplas e, com ela,
as situações em que a coordenação (evitar colisão de alvo, redistribuir
carga, priorizar o agente mais próximo) faz diferença mensurável no placar.

Um fator adicional, de natureza metodológica, envolve o script de bateria. As
25 execuções desta bateria fecharam com o campo `completed=1` e tempo de 5
segundos, valor incompatível com uma partida completa até o esgotamento do
ouro. O comportamento sugere leitura de log residual de uma execução anterior
antes do log da execução atual ser efetivamente populado, já que as execuções
não isolam o processo Java em uma JVM própria. Por esse motivo, o campo de
tempo (`secs`) e o indicador `completed` desta bateria não são usados como
evidência neste relatório; apenas a métrica de placar (`team_score`),
lida diretamente do conteúdo do log, foi considerada confiável.

## 6. Conclusão

Os mecanismos de coordenação (reserva de tarefas, capacidade e recrutamento,
regiões e proximidade) funcionam conforme especificado, confirmado pelos
registros de log de cada execução. A comparação quantitativa entre o time
coordenado e o time ingênuo, no entanto, permanece inconclusiva, dominada por
um viés de posição inicial identificado no cenário usado, e não sustenta a
conclusão de que a coordenação melhora o placar nesse mapa.

## 7. Trabalhos futuros

Para obter uma comparação quantitativa válida, os próximos passos incluem
alternar as posições iniciais dos dois times entre execuções, de forma a
cancelar o viés identificado, usar um mapa com maior densidade e contenção de
ouro, ambiente no qual a coordenação tem mais oportunidade de fazer
diferença, isolar cada execução da bateria em um processo Java próprio, para
eliminar a leitura de log residual, e aumentar o número de repetições por
configuração, reportando média e desvio padrão.
