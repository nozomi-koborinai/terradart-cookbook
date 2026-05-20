/// Coffee-shop recipe — webhook on Cloud Run with private Cloud SQL,
/// Pub/Sub event ingestion, and Monitoring coverage.
library;

import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/cloud_sql.dart';
import 'package:terradart_google/compute.dart';
import 'package:terradart_google/project.dart';
import 'package:terradart_google/provider.dart';
import 'package:terradart_google/secret_manager.dart';
import 'package:terradart_google/service_networking.dart';

class CoffeeShopStack extends Stack {
  CoffeeShopStack({
    required String projectId,
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
    // ignore: unused_local_variable
    final apiCompute = add(GoogleProjectService(
      localName: 'api_compute',
      service: TfArg.literal('compute.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));
    // ignore: unused_local_variable
    final apiServiceNetworking = add(GoogleProjectService(
      localName: 'api_servicenetworking',
      service: TfArg.literal('servicenetworking.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));


    // ===== Tier 2: Network (VPC + private services peering) ===============

    final vpc = add(GoogleComputeNetwork(
      localName: 'coffee_vpc',
      name: TfArg.literal('coffee-shop-vpc'),
      autoCreateSubnetworks: TfArg.literal(false),
    ));

    // ignore: unused_local_variable
    final psaRange = add(GoogleComputeGlobalAddress(
      localName: 'psa_range',
      name: TfArg.literal('coffee-shop-psa-range'),
      addressType: TfArg.literal(GlobalAddressType.internal),
      purpose: TfArg.literal(GlobalAddressPurpose.vpcPeering),
      prefixLength: TfArg.literal(16),
      network: TfArg.ref(vpc.selfLink),
    ));

    final psaConnection = add(GoogleServiceNetworkingConnection(
      localName: 'psa',
      network: TfArg.ref(vpc.selfLink),
      service: TfArg.literal('servicenetworking.googleapis.com'),
      reservedPeeringRanges: TfArg.literal([
        '\${google_compute_global_address.psa_range.name}',
      ]),
    ));

    // ===== Tier 3: Datastore (private Cloud SQL) + Secret =================

    final sqlInstance = add(GoogleSqlDatabaseInstance(
      localName: 'coffee_sql',
      name: TfArg.literal('coffee-shop-sql'),
      databaseVersion: TfArg.literal(DatabaseVersion.postgres15),
      region: TfArg.literal('asia-northeast1'),
      deletionProtection: TfArg.literal(false),
      settings: Settings(
        tier: TfArg.literal('db-f1-micro'),
        ipConfiguration: IpConfiguration(
          ipv4Enabled: TfArg.literal(false),
          privateNetwork: TfArg.ref(vpc.selfLink),
        ),
      ),
      // SQL instance requires PSA peering active; declared via the typed
      // ResourceDependency builder (terradart_core exposes a first-class
      // `dependsOn: List<DependencyTarget>?` parameter).
      dependsOn: [ResourceDependency(psaConnection)],
    ));

    // ignore: unused_local_variable
    final sqlDatabase = add(GoogleSqlDatabase(
      localName: 'coffee_db',
      name: TfArg.literal('coffee_orders'),
      instance: TfArg.ref(sqlInstance.nameRef),
    ));

    // ignore: unused_local_variable
    final sqlUser = add(GoogleSqlUser(
      localName: 'coffee_user',
      name: TfArg.literal('coffee_app'),
      instance: TfArg.ref(sqlInstance.nameRef),
      passwordWo: TfArg.literal(dbPassword),
      passwordWoVersion: TfArg.literal(1),
    ));

    final dbPasswordSecret = add(GoogleSecretManagerSecret(
      localName: 'db_password',
      secretId: TfArg.literal('coffee-shop-db-password'),
      replication: Replication.auto(),
    ));

    // ignore: unused_local_variable
    final dbPasswordSecretVersion = add(GoogleSecretManagerSecretVersion(
      localName: 'db_password_v1',
      secret: TfArg.ref(dbPasswordSecret.id),
      secretDataWo: TfArg.literal(dbPassword),
      secretDataWoVersion: TfArg.literal(1),
    ));

    // (Tier 4 through 6 added in subsequent tasks.)
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
