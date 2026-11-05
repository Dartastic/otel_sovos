// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_sovos_suppression.dart';

const _tracerName = 'dartastic_otel_libs_sovos';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class SovosResult {
  /// Creates a result.
  const SovosResult({
    this.documentId,
    this.product,
    this.flow,
    this.country,
    this.totalTaxMinor,
    this.currency,
    this.clearanceStatus,
    this.governmentResponseCode,
    this.lineCount,
    this.requestId,
    this.statusCode,
  });

  /// `documentId`.
  final String? documentId;

  /// `global_tax_determination` / `vat` / `sui` / `cdt` / `1099` /
  /// `unclaimed_property` / `e_invoicing` — Sovos sells separate
  /// products with distinct quotas.
  final String? product;

  /// `inbound` / `outbound` for e-invoicing flows.
  final String? flow;

  /// ISO 3166 jurisdiction.
  final String? country;

  /// Total tax in minor units.
  final int? totalTaxMinor;

  /// ISO 4217.
  final String? currency;

  /// e-invoicing clearance state: `not_required` / `pending` /
  /// `cleared` / `rejected` / `partially_cleared`.
  final String? clearanceStatus;

  /// Country-specific government response code (SAT, AFIP, GST, etc.)
  /// — keep cardinality bounded; truncate to short codes only.
  final String? governmentResponseCode;

  /// Lines on the document.
  final int? lineCount;

  /// `X-Correlation-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class SovosCallResult<T> {
  /// Creates a call result.
  const SovosCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final SovosResult? result;
}

/// Wraps a Sovos API call in a CLIENT span. [operation] is one of
/// `tax_determination.calculate`, `tax_determination.commit`,
/// `e_invoicing.outbound.send`, `e_invoicing.inbound.receive`,
/// `e_invoicing.status.get`, `withholding.calculate`,
/// `returns.list`, `returns.file`, `1099.list`, `1099.create`,
/// `iPT.calculate`.
Future<T> tracedSovos<T>({
  required String operation,
  required Future<SovosCallResult<T>> Function() invoke,
  String? product,
  String? country,
}) async {
  if (sovosInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'sovos',
    'rpc.method': operation,
    'sovos.operation': operation,
  };
  if (product != null) m['sovos.product'] = product;
  if (country != null) m['sovos.country'] = country;

  final span = _tracer().startSpan(
    'sovos $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.documentId != null) {
        extras.add(OTelAPI.attributeString(
          'sovos.document.id',
          r.result!.documentId!,
        ));
      }
      if (r.result!.product != null) {
        extras.add(OTelAPI.attributeString(
          'sovos.product',
          r.result!.product!,
        ));
      }
      if (r.result!.flow != null) {
        extras.add(OTelAPI.attributeString('sovos.flow', r.result!.flow!));
      }
      if (r.result!.country != null) {
        extras.add(OTelAPI.attributeString(
          'sovos.country',
          r.result!.country!,
        ));
      }
      if (r.result!.totalTaxMinor != null) {
        extras.add(OTelAPI.attributeInt(
          'sovos.tax.total.minor',
          r.result!.totalTaxMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTelAPI.attributeString(
          'sovos.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.clearanceStatus != null) {
        extras.add(OTelAPI.attributeString(
          'sovos.clearance.status',
          r.result!.clearanceStatus!,
        ));
        if (r.result!.clearanceStatus == 'rejected') {
          span.setStatus(
            SpanStatusCode.Error,
            'Sovos clearance rejected',
          );
        }
      }
      if (r.result!.governmentResponseCode != null) {
        extras.add(OTelAPI.attributeString(
          'sovos.government.response_code',
          r.result!.governmentResponseCode!,
        ));
      }
      if (r.result!.lineCount != null) {
        extras.add(OTelAPI.attributeInt(
          'sovos.line_count',
          r.result!.lineCount!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'sovos.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Sovos HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
