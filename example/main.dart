// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_sovos/otel_sovos.dart';

/// Traces Sovos calls with OpenTelemetry.
///
/// `otel_sovos` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Sovos call in
/// [tracedSovos]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'sovos-example');

  // Wraps a Sovos API call in a CLIENT span.
  final sovosId = await tracedSovos<String>(
    operation: 'e_invoicing.outbound.send',
    product: 'example',
    country: 'example',
    invoke: () async {
      // Make the Sovos call here, then report what it returned.
      const id = 'sovos_8f3a2c';
      return const SovosCallResult(
          value: id,
          result: SovosResult(
              documentId: 'document_8f3a2c',
              product: 'global_tax_determination',
              flow: 'inbound',
              country: 'example',
              totalTaxMinor: 1,
              currency: 'usd',
              clearanceStatus: 'not_required',
              governmentResponseCode: 'example',
              lineCount: 3,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedSovos e_invoicing.outbound.send returned $sovosId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSovosInstrumentationAsync.
  await runWithoutSovosInstrumentationAsync(
    () => tracedSovos<String>(
      operation: 'e_invoicing.outbound.send',
      product: 'example',
      country: 'example',
      invoke: () async {
        const id = 'sovos_8f3a2c';
        return const SovosCallResult(
            value: id,
            result: SovosResult(
                documentId: 'document_8f3a2c',
                product: 'global_tax_determination',
                flow: 'inbound',
                country: 'example',
                totalTaxMinor: 1,
                currency: 'usd',
                clearanceStatus: 'not_required',
                governmentResponseCode: 'example',
                lineCount: 3,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
