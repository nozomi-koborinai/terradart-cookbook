# Friction log

Findings from dogfooding terradart against the coffee-shop recipe. Each entry is a candidate for the v1.0 polish wave (sub-project A of the v1.0 design).

## Entry template

```markdown
### <short title>

**Context:** which tier / which terraform command / which env.

**Friction:** what was unexpected — symptom + observed behavior.

**Proposed fix:** rename / add abstraction / docs update / etc. (feeds into A wave scope).

**Tracked:** terradart#XXX (added after issue is filed).
```

## D1a (local backend)

### Backend block requires handwritten terraform.tf

**Context:** D1a tier 1 setup — synth produces `tf-out/main.tf.json` but does not emit a `terraform { backend "local" {} }` block.

**Friction:** terradart_core v0.8.0-dev exposes `StackBackend` + `GcsBackend` (via `setBackend(...)` on `Stack`), but ships no `LocalBackend` implementation. Consumers wanting a local backend must hand-author `tf-out/terraform.tf` alongside the synthesized JSON, and force-add it past the `recipes/*/tf-out/` gitignore (`git add -f`).

**Proposed fix:** add `LocalBackend` to `terradart_core` in sub-project A (lives next to existing `GcsBackend` in `src/backends.dart`); export from `terradart_core.dart`. Then `stack.setBackend(const LocalBackend())` would emit `terraform.backend.local: {}` in `main.tf.json` and the handwritten file disappears.

**Tracked:** terradart#XXX (filed in Task 13).

### `Stack.synth` is abstract — every quickstart re-implements file-write boilerplate

**Context:** D1a tier 1 setup — needed to override `synth({required String outDir})` in `CoffeeShopStack` to call `StackSynth.synth(this)`, then `Directory(outDir).create(recursive: true)`, then `File('$outDir/main.tf.json').writeAsString(...)` with `dart:convert`'s `JsonEncoder.withIndent('  ')`.

**Friction:** `Stack.synth` is declared abstract (`packages/terradart_core/lib/src/stack.dart:192`), so every consumer copies the same 6-line boilerplate. Also forces every consumer to alias `dart:convert` (e.g. `import 'dart:convert' as dart_convert;`) because `terradart_core.dart` exports its own `JsonEncoder` class, shadowing `dart:convert`'s.

**Proposed fix:** provide a concrete default `synth` on `Stack` that writes `main.tf.json` (and the `*.app.dart` constants file when present) under `outDir`. Subclasses can still override for custom side effects, but the 80% case becomes a no-boilerplate call. Rename the internal `JsonEncoder` export to `TfJsonEncoder` to avoid shadowing `dart:convert`.

**Tracked:** terradart#XXX (filed in Task 13).

### Synth emits `terraform.required_version` & `required_providers`, duplicating handwritten `terraform.tf`

**Context:** D1a tier 1 setup — handwritten `tf-out/terraform.tf` declares `required_version = ">= 1.5"` and the `hashicorp/google ~> 7.0` provider block; synth-emitted `main.tf.json` re-declares both (synth pins `required_version` to `">= 1.11.0"` and the provider block to `hashicorp/google ~> 7.0`).

**Friction:** Terraform merges duplicate declarations and the stricter `required_version` wins (`>= 1.11.0`), so the handwritten `>= 1.5` is silently ignored — confusing for users who think they control the floor. The duplicated `required_providers` block is harmless but visually noisy.

**Proposed fix:** if a `LocalBackend` abstraction lands (see first entry above), the handwritten `terraform.tf` disappears entirely and this becomes moot. Until then, document in the cookbook README that `terraform.tf`'s `required_version` is overridden by the synth-emitted `>= 1.11.0` value (or let users override via `stack.setRequiredVersion(...)`).

**Tracked:** terradart#XXX (filed in Task 13).

## D1b (GCS backend)

(filled in during the D1b apply cycle.)
