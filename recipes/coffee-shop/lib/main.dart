/// Coffee-shop recipe — webhook on Cloud Run with private Cloud SQL,
/// Pub/Sub event ingestion, and Monitoring coverage.
library;

import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/compute.dart';
import 'package:terradart_google/project.dart';
import 'package:terradart_google/provider.dart';
import 'package:terradart_google/service_networking.dart';

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
    final apiCompute = add(GoogleProjectService(
      localName: 'api_compute',
      service: TfArg.literal('compute.googleapis.com'),
      disableOnDestroy: TfArg.literal(false),
    ));
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

    // ignore: unused_local_variable
    final psaConnection = add(GoogleServiceNetworkingConnection(
      localName: 'psa',
      network: TfArg.ref(vpc.selfLink),
      service: TfArg.literal('servicenetworking.googleapis.com'),
      reservedPeeringRanges: TfArg.literal([
        '\${google_compute_global_address.psa_range.name}',
      ]),
    ));

    // (Tier 3 through 6 added in subsequent tasks.)
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
