/// Coffee-shop recipe — webhook on Cloud Run with private Cloud SQL,
/// Pub/Sub event ingestion, and Monitoring coverage.
library;

import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/cloud_run.dart';
import 'package:terradart_google/cloud_sql.dart';
import 'package:terradart_google/compute.dart';
import 'package:terradart_google/iam.dart';
import 'package:terradart_google/monitoring.dart';
import 'package:terradart_google/project.dart';
import 'package:terradart_google/provider.dart';
import 'package:terradart_google/pubsub.dart';
import 'package:terradart_google/secret_manager.dart';
import 'package:terradart_google/service_networking.dart';

class CoffeeShopStack extends Stack {
  CoffeeShopStack({
    required String projectId,
    required String dbPassword,
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

    // ===== Tier 4: IAM (service account + role bindings) ==================

    final runSa = add(GoogleServiceAccount(
      localName: 'run_sa',
      accountId: TfArg.literal('coffee-run-sa'),
      displayName: TfArg.literal('Coffee Shop Cloud Run SA'),
    ));

    // ignore: unused_local_variable
    final runSaSqlClient = add(GoogleProjectIamMember(
      localName: 'run_sa_sql_client',
      project: TfArg.literal(projectId),
      role: TfArg.literal('roles/cloudsql.client'),
      member: TfArg.ref(runSa.member),
    ));

    // ignore: unused_local_variable
    final runSaLogWriter = add(GoogleProjectIamMember(
      localName: 'run_sa_log_writer',
      project: TfArg.literal(projectId),
      role: TfArg.literal('roles/logging.logWriter'),
      member: TfArg.ref(runSa.member),
    ));

    // ignore: unused_local_variable
    final runSaMonitoringWriter = add(GoogleProjectIamMember(
      localName: 'run_sa_monitoring_writer',
      project: TfArg.literal(projectId),
      role: TfArg.literal('roles/monitoring.metricWriter'),
      member: TfArg.ref(runSa.member),
    ));

    // ignore: unused_local_variable
    final dbPasswordSecretAccess = add(GoogleSecretManagerSecretIamMember(
      localName: 'db_password_access',
      secretId: TfArg.ref(dbPasswordSecret.id),
      role: TfArg.literal('roles/secretmanager.secretAccessor'),
      member: TfArg.ref(runSa.member),
    ));

    // ===== Tier 5: Cloud Run v2 service ====================================

    final coffeeService = add(GoogleCloudRunV2Service(
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

    // ===== Tier 6: Pub/Sub eventing + Monitoring ===========================

    final orderTopic = add(GooglePubsubTopic(
      localName: 'orders_topic',
      name: TfArg.literal('coffee-orders'),
    ));

    // Push subscription invokes the Cloud Run service with an OIDC token
    // signed for the runSa identity. The Cloud Run invoker IAM in Tier 5 was
    // set to allUsers, so runSa is a valid invoker.
    //
    // NOTE: `topic` must reference the topic's `.id` (full path
    // `projects/{project}/topics/{name}`), NOT `.nameRef`. See the dartdoc
    // on `google_pubsub_subscription.dart` — the provider expects the full
    // resource path here.
    // ignore: unused_local_variable
    final orderSubscription = add(GooglePubsubSubscription(
      localName: 'orders_subscription',
      name: TfArg.literal('coffee-orders-sub'),
      topic: TfArg.ref(orderTopic.id),
      pushConfig: PushConfig(
        pushEndpoint: TfArg.ref(coffeeService.uri),
        oidcToken: OidcToken(
          serviceAccountEmail: TfArg.ref(runSa.email),
        ),
      ),
    ));

    // ignore: unused_local_variable
    final emailChannel = add(GoogleMonitoringNotificationChannel(
      localName: 'email_channel',
      displayName: TfArg.literal('Coffee Shop email'),
      type: TfArg.literal('email'),
      labels: TfArg.literal({'email_address': alertEmail}),
    ));

    // ignore: unused_local_variable
    final uptimeCheck = add(GoogleMonitoringUptimeCheckConfig(
      localName: 'coffee_uptime',
      displayName: TfArg.literal('Coffee Shop uptime'),
      timeout: TfArg.literal('10s'),
      period: TfArg.literal('60s'),
      monitoredResource: MonitoringUptimeCheckMonitoredResource(
        type: 'uptime_url',
        labels: {
          'host':
              '\${replace(replace(google_cloud_run_v2_service.coffee_service.uri, "https://", ""), "/", "")}',
        },
      ),
      httpCheck: const MonitoringUptimeCheckHttpCheck(
        path: '/',
        port: 443,
        useSsl: true,
      ),
    ));

    // ignore: unused_local_variable
    final downAlert = add(GoogleMonitoringAlertPolicy(
      localName: 'coffee_down',
      displayName: TfArg.literal('Coffee Shop down'),
      combiner: TfArg.literal(AlertCombiner.or),
      conditions: [
        AlertCondition(
          displayName: TfArg.literal('uptime check failing'),
          conditionThreshold: ConditionThreshold(
            filter: TfArg.literal(
              'metric.type="monitoring.googleapis.com/uptime_check/check_passed" AND resource.type="uptime_url" AND metric.labels.check_id="\${google_monitoring_uptime_check_config.coffee_uptime.uptime_check_id}"',
            ),
            comparison: TfArg.literal(Comparison.lt),
            thresholdValue: TfArg.literal(1),
            duration: TfArg.literal('60s'),
            aggregations: [
              Aggregation(
                alignmentPeriod: TfArg.literal('60s'),
                perSeriesAligner: Aligner.nextOlder,
              ),
            ],
          ),
        ),
      ],
      notificationChannels: TfArg.literal([
        '\${google_monitoring_notification_channel.email_channel.name}',
      ]),
    ));
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
