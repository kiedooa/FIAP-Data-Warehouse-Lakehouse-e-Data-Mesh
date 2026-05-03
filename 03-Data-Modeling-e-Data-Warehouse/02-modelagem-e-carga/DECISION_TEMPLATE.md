# Decisão de modelagem — Lab 03.1

> Copie este arquivo para `DECISION.md` na mesma pasta e preencha. Ele simula um ADR (Architecture Decision Record) real — documento curto que registra uma escolha técnica com contexto, alternativas e consequências.

---

## Autor e data

- **Aluno**: _______
- **RM**: _______
- **Data**: AAAA-MM-DD

---

## Contexto

Descreva em 3-5 linhas a pergunta de negócio que motivou a modelagem e o que se sabe sobre o dado disponível.

_(exemplo: "Precisamos responder 'receita líquida por segmento de cliente × região × ano'. Os dados vêm do ERP com reclassificações de segmento que acontecem esporadicamente. O histórico de classificações está em uma tabela separada.")_

---

## Três números observados

Preencha os resultados da query-âncora (receita AUTOMOBILE 1995, região AMERICA) nas três modelagens:

| Modelagem | Receita AUTOMOBILE 1995 (AMERICA) |
|-----------|-----------------------------------|
| A — Espelho OLTP | `N₁` = _______ |
| B — Star SCD1 | `N₂` = _______ |
| C — Star SCD2 | `N₃` = _______ |

**Diferença percentual entre a maior e a menor**: _______%

---

## Decisão

Marque uma opção e escreva por quê:

- [ ] Modelagem **A** (Espelho OLTP)
- [ ] Modelagem **B** (Star SCD1)
- [ ] Modelagem **C** (Star SCD2)

**Justificativa** (3-5 linhas):

_______

---

## Alternativas consideradas e descartadas

Para cada opção que você **não** escolheu, escreva uma linha dizendo por quê.

- **Opção X não escolhida**: _______
- **Opção Y não escolhida**: _______

---

## Consequências

### Positivas

- _______
- _______

### Negativas / pontos de atenção

- _______
- _______

---

## O que eu precisaria do negócio para validar esta escolha

Liste 2-3 perguntas que você faria para o stakeholder (CMO, diretor de operações, analista de receita) **antes** de colocar essa modelagem em produção.

1. _______
2. _______
3. _______

---

## Decisões técnicas secundárias

### Distribuição física da fato

- `DISTKEY` escolhida: _______
- `SORTKEY` escolhida: _______
- Por quê: _______

### Cálculo de receita

- Materializado em coluna (`vr_receita_liquida`) **ou** calculado em view / on-the-fly?
- Escolha: _______
- Por quê: _______

---

## Observações adicionais

_(espaço livre — comportamentos inesperados, descobertas, dúvidas que você quer anotar)_

_______
