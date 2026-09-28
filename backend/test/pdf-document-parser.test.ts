import assert from "node:assert/strict";
import { test } from "node:test";

import {
  buildPensionProjection,
  parseLoanText,
  parsePensionText,
} from "../src/imports/pdf-document-service.js";

/** Fixture com uma parcela paga no passado, duas em aberto e uma amortizada no futuro. */
const renovacaoFunci = `
    11/08/2026, 23:29 Banco do Brasil
    BB CRÉDITO RENOVAÇÃO FUNCI
    168042637
    R$ 78.576,27
    28/10/2024
    Data do contrato 28/10/2024
    Dia do débito 20
    Taxa de juros mensal / anual 1,34% a.m. / 17,31% a.a.
    Custo efetivo mensal / anual 1,34% a.m. / 17,35% a.a.
    Valor total do empréstimo (base para CET) R$ 78.621,90
    1 20/07/2026 Pago R$ 1.300,00
    2 20/08/2026 A vencer R$ 1.385,43
    3 20/09/2026 A vencer R$ 1.385,43
    4 20/10/2026 Pago R$ 900,00
`;

test("preserva parcelas pagas no futuro como amortizações", () => {
  // Data anterior ao vencimento da parcela 2, para isolar a amortização.
  const parsed = parseLoanText(renovacaoFunci, "2026-08-11");

  assert.equal(parsed.contractNumber, "168042637");
  assert.equal(parsed.productName, "BB Crédito Renovação Funci");
  assert.equal(parsed.repaymentKind, "MONTHLY");
  assert.equal(parsed.payrollDeducted, false);
  assert.equal(parsed.currentBalanceMinorUnits, 7_857_627);
  assert.equal(parsed.totalInstallments, 4);
  assert.equal(parsed.paidInstallments, 2);
  assert.equal(parsed.remainingInstallments, 2);
  assert.equal(parsed.amortizedInstallments, 1);
  assert.equal(parsed.nextDueDate, "2026-08-20");
  assert.equal(parsed.projectedEndDate, "2026-09-20");
  assert.equal(parsed.installments[3]?.paymentKind, "AMORTIZED");
});

test("dá baixa na parcela assim que o dia do débito chega", () => {
  const antes = parseLoanText(renovacaoFunci, "2026-08-19");
  const noDia = parseLoanText(renovacaoFunci, "2026-08-20");

  assert.equal(antes.paidInstallments, 2);
  assert.equal(antes.remainingInstallments, 2);
  assert.equal(antes.nextDueDate, "2026-08-20");

  // No dia 20 a parcela vira liquidada sem rotina agendada e sem novo import.
  assert.equal(noDia.paidInstallments, 3);
  assert.equal(noDia.remainingInstallments, 1);
  assert.equal(noDia.nextDueDate, "2026-09-20");
  assert.equal(noDia.installments[1]?.status, "PAID");
  assert.equal(noDia.installments[1]?.paymentKind, "REGULAR");
});

test("separa desembolso futuro de custo de quitação", () => {
  const parsed = parseLoanText(renovacaoFunci, "2026-08-20");

  // Resta só a parcela 3, de R$ 1.385,43 vencendo em 20/09.
  assert.equal(parsed.remainingPaymentsMinorUnits, 138_543);
  // Descontada um mês a 1,34% a.m.: 138543 / 1.0134 = 136_711.
  assert.equal(parsed.payoffMinorUnits, 136_711);
  assert.ok(parsed.payoffMinorUnits < parsed.remainingPaymentsMinorUnits);
});

test("desconto usa a distância até o vencimento, não a posição na lista", () => {
  // Cronograma com buraco: a 2 foi quitada adiantado, então a 3 continua a três
  // meses de distância e não pode ser descontada como se fosse a próxima.
  const comBuraco = parseLoanText(
    `
    11/08/2026, 23:29 Banco do Brasil
    BB CRÉDITO RENOVAÇÃO FUNCI
    168042637
    R$ 1.000,00
    Data do contrato 28/10/2024
    Dia do débito 20
    Taxa de juros mensal / anual 1,34% a.m. / 17,31% a.a.
    Valor total do empréstimo (base para CET) R$ 1.000,00
    1 20/09/2026 Pago R$ 1.000,00
    2 20/10/2026 Pago R$ 1.000,00
    3 20/11/2026 A vencer R$ 1.000,00
  `,
    "2026-08-20",
  );

  // 3 meses até 20/11: 100000 / 1.0134^3 = 96_085. Pela posição daria 98_678.
  assert.equal(comBuraco.remainingInstallments, 1);
  assert.equal(comBuraco.payoffMinorUnits, 96_085);
});

test("sem taxa conhecida a quitação não é descontada", () => {
  const semTaxa = parseLoanText(
    `
    11/08/2026, 23:29 Banco do Brasil
    BB CRÉDITO VEÍCULO FUNCI
    168958745
    R$ 1.000,00
    Data do contrato 28/10/2024
    Dia do débito 20
    Valor total do empréstimo (base para CET) R$ 1.000,00
    1 20/09/2026 A vencer R$ 500,00
  `,
    "2026-08-20",
  );

  assert.equal(semTaxa.monthlyInterestRate, null);
  assert.equal(semTaxa.payoffMinorUnits, semTaxa.remainingPaymentsMinorUnits);
});

test("separa antecipação de 13º do comprometimento mensal", () => {
  const parsed = parseLoanText(`
    14/08/2026, 16:02 Banco do Brasil
    BB CRÉD. 13º SALÁRIO
    97186888
    R$ 1.893,71
    Data do contrato 25/11/2025
    Dia do débito 20
    Taxa de juros mensal / anual 1,46% a.m. / 18,99% a.a.
    Custo efetivo mensal / anual 1,75% a.m. / 23,18% a.a.
    Valor total do empréstimo (base para CET) R$ 1.959,81
    1 20/12/2026 A vencer R$ 2.366,18
  `);

  assert.equal(parsed.productName, "BB Crédito 13º Salário");
  assert.equal(parsed.repaymentKind, "THIRTEENTH_SALARY");
  assert.equal(parsed.payrollDeducted, false);
  assert.equal(parsed.remainingInstallments, 1);
});

test("identifica consignação como desconto em folha", () => {
  const parsed = parseLoanText(`
    14/08/2026, 16:04 Banco do Brasil
    BB CRÉDITO CONSIGNAÇÃO
    208926374
    R$ 5.000,00
    Data do contrato 08/04/2026
    Dia do débito 20
    Taxa de juros mensal / anual 1,46% a.m. / 18,99% a.a.
    Custo efetivo mensal / anual 1,59% a.m. / 20,89% a.a.
    Valor total do empréstimo (base para CET) R$ 5.155,88
    1 20/06/2026 Pago R$ 153,24
    2 20/07/2026 Pago R$ 153,24
    3 20/08/2026 A vencer R$ 153,24
  `);

  assert.equal(parsed.productName, "BB Crédito Consignação");
  assert.equal(parsed.repaymentKind, "MONTHLY");
  assert.equal(parsed.payrollDeducted, true);
});

test("mantém a Parte I fora do saldo patrimonial da PREVI", () => {
  const parsed = parsePensionText(`
    REGIME DE TRIBUTAÇÃO: PROGRESSIVO DATA DE FILIAÇÃO: 14/09/2023
    PERFIL DE INVESTIMENTO: CICLO DE VIDA 2050 ATUALIZADO ATÉ: 31/07/2026
    09/08/2026 SALDO DE CONTRIBUIÇÕES INDIVIDUAIS PARA A PARTE 1 2.010,03 0,00
    09/08/2026 RESERVA INDIVIDUAL DE POUPANÇA 0,00 24.040,32
    09/08/2026 RESERVA PATRONAL DE POUPANÇA 0,00 24.040,28
    09/08/2026 SALDO DE CONTA DO PARTICIPANTE 0,00 48.080,60
    CICLO DE VIDA 2050 1,33% 6,62% 19,14%
    JUL/2026 45.048,61 616,89 919,69 287,85 919,69 287,85 0,00 0,00 0,00 48.080,58
  `);

  assert.equal(parsed.profileName, "CICLO DE VIDA 2050");
  assert.equal(parsed.currentBalanceMinorUnits, 4_808_060);
  assert.equal(parsed.taxRegime, "PROGRESSIVO");
  assert.equal(parsed.updatedThrough, "2026-07-31");
  assert.equal(parsed.monthlyReturn, 1.33);
  assert.equal(parsed.history.length, 1);
  assert.equal(parsed.history[0]?.referenceMonth, "2026-07-01");
  assert.equal(parsed.history[0]?.returnsMinorUnits, 61_689);
});

test("projeta resgate PREVI Futuro com 20,5% da reserva patronal após 36 meses", () => {
  const history = Array.from({ length: 34 }, (_, index) => ({
    referenceMonth: new Date(Date.UTC(2023, 9 + index, 1))
      .toISOString()
      .slice(0, 10),
    openingBalanceMinorUnits: index === 0 ? 0 : 100_000 + index * 100_000,
    returnsMinorUnits: index === 0 ? 0 : 1_000,
    employerPart2aMinorUnits: 90_000,
    employerPart2bMinorUnits: 0,
    participantPart2aMinorUnits: 90_000,
    participantPart2bMinorUnits: 0,
    participantPart2cMinorUnits: 0,
    personalPortabilityMinorUnits: 0,
    employerPortabilityMinorUnits: 0,
    closingBalanceMinorUnits: 200_000 + index * 100_000,
  }));
  const projection = buildPensionProjection(
    {
      id: "3c26a7dd-5ce0-4f2b-a95f-95a63b3104b2",
      providerName: "PREVI",
      profileName: "CICLO DE VIDA 2050",
      taxRegime: "PROGRESSIVO",
      enrollmentDate: "2023-09-14",
      balanceDate: "2026-08-09",
      updatedThrough: "2026-07-31",
      currentBalanceMinorUnits: 5_009_063,
      partOneBalanceMinorUnits: 201_003,
      participantReserveMinorUnits: 2_404_032,
      employerReserveMinorUnits: 2_404_028,
      monthlyReturn: 1.33,
      yearlyReturn: 6.62,
      twelveMonthReturn: 19.14,
      latestSnapshot: null,
      history,
    },
    [{ referenceMonth: "2026-08-01", returnRate: 1.5 }],
    3,
    new Date("2026-08-14T12:00:00.000Z"),
  );

  assert.equal(projection.currentContributionCount, 36);
  assert.equal(projection.currentEmployerEligibleRate, 20.5);
  assert.equal(
    projection.currentGrossWithdrawableMinorUnits,
    Math.round(
      (2_404_032 * 1.015 + 90_000) +
        (2_404_028 * 1.015 + 90_000) * 0.205,
    ),
  );
  assert.equal(projection.returnOverrides[0]?.returnRate, 1.5);
  assert.equal(projection.points[0]?.year, 2026);
  assert.equal(projection.points[0]?.projectedContributionCount, 40);
});

test("snapshot parcial de agosto substitui a estimativa sem fechar a rentabilidade do mês", () => {
  const pension = {
    id: "3c26a7dd-5ce0-4f2b-a95f-95a63b3104b2",
    providerName: "PREVI",
    profileName: "CICLO DE VIDA 2050",
    taxRegime: "PROGRESSIVO",
    enrollmentDate: "2023-09-14",
    balanceDate: "2026-08-09",
    updatedThrough: "2026-07-31",
    currentBalanceMinorUnits: 5_009_063,
    partOneBalanceMinorUnits: 201_003,
    participantReserveMinorUnits: 2_404_032,
    employerReserveMinorUnits: 2_404_028,
    monthlyReturn: 1.33,
    yearlyReturn: 6.62,
    twelveMonthReturn: 19.14,
    latestSnapshot: null,
    history: [
      {
        referenceMonth: "2026-07-01",
        openingBalanceMinorUnits: 4_504_861,
        returnsMinorUnits: 61_689,
        employerPart2aMinorUnits: 91_969,
        employerPart2bMinorUnits: 28_785,
        participantPart2aMinorUnits: 91_969,
        participantPart2bMinorUnits: 28_785,
        participantPart2cMinorUnits: 0,
        personalPortabilityMinorUnits: 0,
        employerPortabilityMinorUnits: 0,
        closingBalanceMinorUnits: 4_808_058,
      },
    ],
  };
  const projection = buildPensionProjection(
    pension,
    [],
    3,
    new Date("2026-08-14T12:00:00.000Z"),
    [
      {
        referenceMonth: "2026-08-01",
        asOfDate: "2026-08-14",
        accumulatedReturnMinorUnits: -18_290,
        closingBalanceMinorUnits: 4_789_768,
        contributionApplied: false,
        projectedContributionMinorUnits: 0,
      },
    ],
  );

  const participantShare = 2_404_032 / 4_808_060;
  const participant = 4_789_768 * participantShare;
  const employer = 4_789_768 - participant;
  assert.equal(projection.currentPartTwoBalanceMinorUnits, 4_789_768);
  assert.equal(
    projection.currentGrossWithdrawableMinorUnits,
    Math.round(participant + employer * 0.205),
  );
  assert.equal(projection.latestSnapshot?.accumulatedReturnMinorUnits, -18_290);
  // A taxa vem do histórico, não dos 19,14% em 12 meses: julho/2026 com metade
  // da contribuição aplicada dá 1,3336%, e a PREVI divulgou 1,33% no mês.
  assert.equal(projection.monthlyReturnRateUsed, 1.3336);
  assert.ok(projection.points[0]!.projectedBalanceMinorUnits > 4_789_768);

  // Passar do dia 20 não mexe no saldo: a posição segue fiel à PREVI enquanto a
  // contribuição não for lançada, senão o valor medido mudaria sozinho.
  const semLancar = buildPensionProjection(
    pension,
    [],
    3,
    new Date("2026-08-20T12:00:00.000Z"),
    [
      {
        referenceMonth: "2026-08-01",
        asOfDate: "2026-08-14",
        accumulatedReturnMinorUnits: -18_290,
        closingBalanceMinorUnits: 4_789_768,
        contributionApplied: false,
        projectedContributionMinorUnits: 0,
      },
    ],
  );
  assert.equal(semLancar.currentPartTwoBalanceMinorUnits, 4_789_768);
});

test("contribuição do mês só entra no saldo quando lançada", () => {
  const base = {
    id: "3c26a7dd-5ce0-4f2b-a95f-95a63b3104b2",
    providerName: "PREVI",
    profileName: "CICLO DE VIDA 2050",
    taxRegime: "PROGRESSIVO",
    enrollmentDate: "2023-09-14",
    balanceDate: "2026-08-09",
    updatedThrough: "2026-07-31",
    currentBalanceMinorUnits: 5_009_063,
    partOneBalanceMinorUnits: 201_003,
    participantReserveMinorUnits: 2_404_032,
    employerReserveMinorUnits: 2_404_028,
    monthlyReturn: 1.33,
    yearlyReturn: 6.62,
    twelveMonthReturn: 19.14,
    latestSnapshot: null,
    history: [
      {
        referenceMonth: "2026-07-01",
        openingBalanceMinorUnits: 4_504_861,
        returnsMinorUnits: 61_689,
        employerPart2aMinorUnits: 91_969,
        employerPart2bMinorUnits: 28_785,
        participantPart2aMinorUnits: 91_969,
        participantPart2bMinorUnits: 28_785,
        participantPart2cMinorUnits: 0,
        personalPortabilityMinorUnits: 0,
        employerPortabilityMinorUnits: 0,
        closingBalanceMinorUnits: 4_808_058,
      },
    ],
  };
  const snapshot = {
    referenceMonth: "2026-08-01",
    asOfDate: "2026-08-14",
    accumulatedReturnMinorUnits: -58_613,
    closingBalanceMinorUnits: 0,
    projectedContributionMinorUnits: 0,
  };

  const fielAPrevi = buildPensionProjection(
    base,
    [],
    3,
    new Date("2026-08-21T12:00:00.000Z"),
    [{ ...snapshot, contributionApplied: false }],
  );
  // 48.080,58 do fechamento de julho menos os 586,13 de rendimento negativo.
  assert.equal(fielAPrevi.currentPartTwoBalanceMinorUnits, 4_749_445);
  assert.equal(
    fielAPrevi.latestSnapshot?.projectedContributionMinorUnits,
    241_508,
  );

  const comContribuicao = buildPensionProjection(
    base,
    [],
    3,
    new Date("2026-08-21T12:00:00.000Z"),
    [{ ...snapshot, contributionApplied: true }],
  );
  assert.equal(
    comContribuicao.currentPartTwoBalanceMinorUnits,
    4_749_445 + 241_508,
  );
});

/** Mês do extrato PREVI sem portabilidade, com a contribuição meio a meio. */
function historyRow(
  referenceMonth: string,
  openingBalanceMinorUnits: number,
  returnsMinorUnits: number,
  contributionMinorUnits = 0,
) {
  return {
    referenceMonth,
    openingBalanceMinorUnits,
    returnsMinorUnits,
    employerPart2aMinorUnits: contributionMinorUnits / 2,
    employerPart2bMinorUnits: 0,
    participantPart2aMinorUnits: contributionMinorUnits / 2,
    participantPart2bMinorUnits: 0,
    participantPart2cMinorUnits: 0,
    personalPortabilityMinorUnits: 0,
    employerPortabilityMinorUnits: 0,
    closingBalanceMinorUnits:
      openingBalanceMinorUnits + returnsMinorUnits + contributionMinorUnits,
  };
}

function previWithHistory(
  history: Array<ReturnType<typeof historyRow>>,
  updatedThrough: string,
) {
  return {
    id: "3c26a7dd-5ce0-4f2b-a95f-95a63b3104b2",
    providerName: "PREVI",
    profileName: "CICLO DE VIDA 2050",
    taxRegime: "PROGRESSIVO",
    enrollmentDate: "2023-09-14",
    balanceDate: updatedThrough,
    updatedThrough,
    currentBalanceMinorUnits: 200_000,
    partOneBalanceMinorUnits: 0,
    participantReserveMinorUnits: 100_000,
    employerReserveMinorUnits: 100_000,
    monthlyReturn: 1.82,
    yearlyReturn: 9.85,
    twelveMonthReturn: 18.59,
    latestSnapshot: null,
    history,
  };
}

test("taxa da projeção é a média de todo o histórico, sem o mês em aberto", () => {
  // Um mês de +10% e depois doze parados: só os últimos 12 meses dariam 0%.
  const history = [
    historyRow("2025-06-01", 100_000, 10_000),
    ...Array.from({ length: 12 }, (_, index) =>
      historyRow(
        new Date(Date.UTC(2025, 6 + index, 1)).toISOString().slice(0, 10),
        110_000,
        0,
      ),
    ),
    // Julho/2026 tem só nove dias de rendimento no extrato atualizado até 09/07.
    historyRow("2026-07-01", 110_000, 55_000),
  ];

  const aberto = buildPensionProjection(
    previWithHistory(history, "2026-07-09"),
    [],
    3,
    new Date("2026-07-16T12:00:00.000Z"),
  );
  assert.equal(
    aberto.monthlyReturnRateUsed,
    Math.round((Math.pow(1.1, 1 / 13) - 1) * 100 * 10_000) / 10_000,
  );

  // Com o mês fechado no extrato, julho entra na média.
  const fechado = buildPensionProjection(
    previWithHistory(history, "2026-07-31"),
    [],
    3,
    new Date("2026-08-02T12:00:00.000Z"),
  );
  assert.equal(
    fechado.monthlyReturnRateUsed,
    Math.round((Math.pow(1.1 * 1.5, 1 / 14) - 1) * 100 * 10_000) / 10_000,
  );
});

test("aumento de salário entra na contribuição projetada, pico de férias não", () => {
  // Quatro meses a 1.800,00, férias a 2.400,00 e o primeiro mês com o salário
  // novo, a 1.900,00.
  const history = [
    historyRow("2026-02-01", 100_000, 0, 180_000),
    historyRow("2026-03-01", 100_000, 0, 180_000),
    historyRow("2026-04-01", 100_000, 0, 180_000),
    historyRow("2026-05-01", 100_000, 0, 180_000),
    historyRow("2026-06-01", 100_000, 0, 240_000),
    historyRow("2026-07-01", 100_000, 0, 190_000),
  ];

  // Mediana dos três últimos: 1.800,00, 2.400,00 e 1.900,00. Pela janela de
  // seis meses o aumento só apareceria em outubro.
  const comAumento = buildPensionProjection(
    previWithHistory(history, "2026-07-31"),
    [],
    3,
    new Date("2026-08-02T12:00:00.000Z"),
  );
  assert.equal(comAumento.averageParticipantContributionMinorUnits, 95_000);
  assert.equal(comAumento.averageEmployerContributionMinorUnits, 95_000);

  // O mês de férias sozinho no fim do histórico continua descartado.
  const comFerias = buildPensionProjection(
    previWithHistory(history.slice(0, 5), "2026-06-30"),
    [],
    3,
    new Date("2026-07-02T12:00:00.000Z"),
  );
  assert.equal(comFerias.averageParticipantContributionMinorUnits, 90_000);
});

test("contribuição do mês rende só metade dele no cálculo da taxa", () => {
  // 75,00 de rendimento sobre 1.000,00 de saldo e 1.000,00 de contribuição:
  // pela abertura seriam 7,5%; com metade da contribuição aplicada, 5%.
  const projection = buildPensionProjection(
    previWithHistory([historyRow("2026-07-01", 100_000, 7_500, 100_000)], "2026-07-31"),
    [],
    3,
    new Date("2026-08-02T12:00:00.000Z"),
  );

  assert.equal(projection.monthlyReturnRateUsed, 5);
});
