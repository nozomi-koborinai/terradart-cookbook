/// Coffee-shop recipe — webhook on Cloud Run with private Cloud SQL,
/// Pub/Sub event ingestion, and Monitoring coverage.
library;

import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/project.dart';
import 'package:terradart_google/provider.dart';

class CoffeeShopStack extends Stack {
  CoffeeShopStack({
    required String projectId,
    // ignore: unused_element_parameter
    required String dbPassword,
    // ignore: unused_element_parameter
    required String alertEmail,
  }) : super(
          providers: [
            GoogleProvider(project: projectId, region: 'asia-northeast1'),
          ],
        ) {
    // ===== Tier 1: API enablement ========================================

    add(GoogleProjectService(
      localName: 'api_run',
      service: TfArg.literal('run.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));
    add(GoogleProjectService(
      localName: 'api_sql',
      service: TfArg.literal('sqladmin.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));
    add(GoogleProjectService(
      localName: 'api_pubsub',
      service: TfArg.literal('pubsub.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));
    add(GoogleProjectService(
      localName: 'api_monitoring',
      service: TfArg.literal('monitoring.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));
    add(GoogleProjectService(
      localName: 'api_secret',
      service: TfArg.literal('secretmanager.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));
    add(GoogleProjectService(
      localName: 'api_iam',
      service: TfArg.literal('iam.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));

    // (Tier 2 through 6 added in subsequent tasks.)
  }

  @override
  Future<void> synth({required String outDir}) async {
    final result = StackSynth.synth(this);
    await Directory(outDir).create(recursive: true);
    final tfFile = File('$outDir/main.tf.json');
    await tfFile.writeAsString(
      const dart_convert.JsonEncoder.withIndent('  ').convert(result.tfJson),
    );
  }
}
