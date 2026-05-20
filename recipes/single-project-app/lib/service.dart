/// Tier 5: Cloud Run v2 service.
library;

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/cloud_run.dart';

import 'main.dart';

extension ServiceOnSingleProjectAppStack on SingleProjectAppStack {
  void addService() {
    coffeeService = add(GoogleCloudRunV2Service(
      localName: 'coffee_service',
      name: TfArg.literal('coffee-shop'),
      location: TfArg.literal('asia-northeast1'),
      ingress: TfArg.literal(Ingress.all),
      template: Template(
        serviceAccount: TfArg.ref(runSa.email),
        containers: [
          ServiceContainer(
            image: TfArg.literal(
              'us-docker.pkg.dev/cloudrun/container/hello',
            ),
            env: [
              EnvVar(
                name: 'DB_INSTANCE',
                source: EnvVarFromLiteral(
                  TfArg.ref(sqlInstance.connectionName),
                ),
              ),
              EnvVar(
                name: 'DB_NAME',
                source: EnvVarFromLiteral(
                  TfArg.ref(sqlDatabase.nameRef),
                ),
              ),
              EnvVar(
                name: 'DB_USER',
                source: EnvVarFromLiteral(TfArg.literal('coffee_app')),
              ),
              EnvVar(
                name: 'DB_PASSWORD',
                source: EnvVarFromSecret(
                  secret: TfArg.ref(dbPasswordSecret.id),
                  version: TfArg.literal('latest'),
                ),
              ),
            ],
          ),
        ],
      ),
    ));

    // ignore: unused_local_variable
    final coffeeServiceInvoker = add(GoogleCloudRunV2ServiceIamMember(
      localName: 'coffee_invoker',
      name: TfArg.ref(coffeeService.nameRef),
      location: TfArg.literal('asia-northeast1'),
      role: TfArg.literal('roles/run.invoker'),
      // allUsers = public webhook. Acceptable for dogfood smoke; harden in
      // production by replacing with the upstream Pub/Sub push SA or similar.
      member: TfArg.literal('allUsers'),
    ));
  }
}
