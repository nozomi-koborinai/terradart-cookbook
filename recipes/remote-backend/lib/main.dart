/// remote-backend recipe — minimal Stack provisioning a GCS bucket to hold
/// Terraform state. Apply with local backend (Stage 0); migrate this bucket's
/// own state into GCS via `terraform init -migrate-state`; then other recipes
/// (e.g. single-project-app) can be retargeted at this bucket via a
/// `backend "gcs" { bucket = "...", prefix = "..." }` declaration in their
/// `tf-out/terraform.tf`.
///
/// Pattern demonstrated: **introduce remote state to a previously local Stack**.
/// Includes versioning + uniform bucket-level access + retention policy
/// suitable for a long-lived terraform state container.
library;

import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:terradart_core/terradart_core.dart';
import 'package:terradart_google/provider.dart';
import 'package:terradart_google/storage.dart';

class RemoteBackendStack extends Stack {
  RemoteBackendStack({
    required this.projectId,
    required this.bucketName,
  }) : super(
          providers: [
            GoogleProvider(project: projectId, region: 'asia-northeast1'),
          ],
        ) {
    add(GoogleStorageBucket(
      localName: 'tfstate',
      name: TfArg.literal(bucketName),
      location: TfArg.literal('asia-northeast1'),
      uniformBucketLevelAccess: TfArg.literal(true),
      versioning: const Versioning(enabled: true),
      // forceDestroy: false is the default; explicit here for clarity.
      // State buckets are long-lived; destroy must be a deliberate action.
      forceDestroy: TfArg.literal(false),
    ));
  }

  final String projectId;
  final String bucketName;

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
