/// Tier 5: Cloud Run v2 service.
library;

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/cloud_run.dart';
import 'package:terradart_google/cloud_sql.dart';
import 'package:terradart_google/iam.dart';
import 'package:terradart_google/secret_manager.dart';

GoogleCloudRunV2Service buildCloudRunService({
  required GoogleServiceAccount runSa,
  required GoogleSqlDatabaseInstance sqlInstance,
  required GoogleSqlDatabase sqlDatabase,
  required GoogleSecretManagerSecret dbPasswordSecret,
}) =>
    GoogleCloudRunV2Service(
      localName: 'coffee_service',
      name: TfArg.literal('coffee-shop'),
      location: TfArg.literal('asia-northeast1'),
      ingress: TfArg.literal(Ingress.all),
      deletionProtection: TfArg.literal(false),
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
    );

GoogleCloudRunV2ServiceIamMember buildCloudRunInvoker(
  GoogleCloudRunV2Service coffeeService,
) =>
    GoogleCloudRunV2ServiceIamMember(
      localName: 'coffee_invoker',
      name: TfArg.ref(coffeeService.nameRef),
      location: TfArg.literal('asia-northeast1'),
      role: TfArg.literal('roles/run.invoker'),
      // allUsers = public webhook. Acceptable for dogfood smoke; harden in
      // production by replacing with the upstream Pub/Sub push SA or similar.
      member: TfArg.literal('allUsers'),
    );
