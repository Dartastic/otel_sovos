// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_sovos/otel_sovos.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_sovos-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('e_invoicing.outbound.send records clearance + flow + country',
      () async {
    await tracedSovos<String>(
      operation: 'e_invoicing.outbound.send',
      product: 'e_invoicing',
      country: 'MX',
      invoke: () async => const SovosCallResult(
        value: 'ok',
        result: SovosResult(
          documentId: 'd-1',
          product: 'e_invoicing',
          flow: 'outbound',
          country: 'MX',
          totalTaxMinor: 32100,
          currency: 'MXN',
          clearanceStatus: 'cleared',
          governmentResponseCode: 'SAT_OK',
          lineCount: 5,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(
      spans.findSpanByName('sovos e_invoicing.outbound.send')!,
    );
    expect(a['sovos.product'], 'e_invoicing');
    expect(a['sovos.flow'], 'outbound');
    expect(a['sovos.country'], 'MX');
    expect(a['sovos.clearance.status'], 'cleared');
    expect(a['sovos.government.response_code'], 'SAT_OK');
  });

  test('rejected clearance sets span error', () async {
    await tracedSovos<String>(
      operation: 'e_invoicing.outbound.send',
      invoke: () async => const SovosCallResult(
        value: 'ok',
        result: SovosResult(clearanceStatus: 'rejected'),
      ),
    );
    expect(
      spans.findSpanByName('sovos e_invoicing.outbound.send')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutSovosInstrumentationAsync(() async {
      await tracedSovos<String>(
        operation: 'tax_determination.calculate',
        invoke: () async => const SovosCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('sovos '), isEmpty);
  });
}
