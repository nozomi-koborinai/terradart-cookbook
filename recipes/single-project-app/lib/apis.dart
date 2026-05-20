/// Tier 1: API enablement.
library;

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/project.dart';

import 'main.dart';

extension ApisOnSingleProjectAppStack on SingleProjectAppStack {
  void addApis() {
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
  }
}
