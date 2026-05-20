/// single-project-app recipe — webhook on Cloud Run with private Cloud SQL,
/// Pub/Sub event ingestion, and Monitoring coverage. Single-GCP-project
/// pattern: all resources live in one project, no cross-project IAM, local
/// `tf-out/` working dir.
///
/// The Stack composition is split across per-service files (`apis.dart`,
/// `network.dart`, `datastore.dart`, `iam.dart`, `service.dart`,
/// `observability.dart`), each exposing one extension method on
/// `SingleProjectAppStack`. The constructor calls them in dependency order.
library;

import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/cloud_run.dart';
import 'package:terradart_google/cloud_sql.dart';
import 'package:terradart_google/compute.dart';
import 'package:terradart_google/iam.dart';
import 'package:terradart_google/provider.dart';
import 'package:terradart_google/secret_manager.dart';
import 'package:terradart_google/service_networking.dart';

import 'apis.dart';
import 'datastore.dart';
import 'iam.dart';
import 'network.dart';
import 'observability.dart';
import 'service.dart';

class SingleProjectAppStack extends Stack {
  SingleProjectAppStack({
    required this.projectId,
    required this.dbPassword,
    required this.alertEmail,
  }) : super(
          providers: [
            GoogleProvider(project: projectId, region: 'asia-northeast1'),
          ],
        ) {
    addApis();
    addNetwork();
    addDatastore();
    addIam();
    addService();
    addObservability();
  }

  final String projectId;
  final String dbPassword;
  final String alertEmail;

  // Cross-extension shared refs (set by the corresponding extension method).
  // Public to allow extensions in separate libraries to read/write.
  late final GoogleComputeNetwork vpc;
  late final GoogleServiceNetworkingConnection psaConnection;
  late final GoogleSqlDatabaseInstance sqlInstance;
  late final GoogleSqlDatabase sqlDatabase;
  late final GoogleSecretManagerSecret dbPasswordSecret;
  late final GoogleServiceAccount runSa;
  late final GoogleCloudRunV2Service coffeeService;

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
