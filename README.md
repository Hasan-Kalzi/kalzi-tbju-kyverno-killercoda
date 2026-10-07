# Kubernetes Policy-as-Code with Kyverno

A browser-executable tutorial for KTH DD2482 (2026), by **Hasan Kalzi** and **Tobias Bjurström**.

The tutorial combines Kyverno CLI checks before deployment with Kubernetes admission enforcement and verification of a running workload. It follows the scope of [accepted course proposal #3033](https://github.com/KTH/devops-course/pull/3033).

## Intended learning outcomes

After completing the tutorial, a learner should be able to:

1. Explain the complementary roles of pre-deployment CLI checks and admission enforcement.
2. Test allowed and denied Deployment manifests and distinguish a policy violation from a technical error.
3. Explain the interactions between the policy, kubectl, API server, Kyverno admission controller and workload controllers.
4. Correct the storage request, verify an available workload and explain the limits of the policy and storage choice.

## Run in the browser

Open **Kubernetes Policy-as-Code with Kyverno** from the connected [Killercoda](https://killercoda.com/) creator profile, or use the direct published scenario URL supplied by the authors.

The direct public scenario URL still needs to be recorded here before the final course hand-in. The repository and proposal links identify the source and registration; they do not launch the browser environment.

Killercoda supplies a temporary Kubernetes cluster and terminal. No local Kubernetes installation, cloud subscription or external secrets are used by this exercise.

1. Start a fresh scenario and wait for `[setup] Installation complete.`.
2. Follow steps 1-4 in order, running the commands inside Killercoda.
3. Use the **CHECK** buttons on steps 2-4.
4. In step 4, run all three verifiers together and confirm the final success message.

Do not copy `{{exec}}` into the terminal. It is a Killercoda Markdown action marker. The scenario automatically prepares the workspace; learners do not need to clone the repository manually.

## Architecture

![Local policy checks and Kubernetes admission enforcement, followed by workload reconciliation.](kubernetes-policy-as-code/architecture.svg)

| Component | Role |
| --- | --- |
| Policy and manifests | Versioned inputs describing the rule and the two workload variants. |
| Kyverno CLI | Evaluates local manifests without creating resources. |
| kubectl and API server | Submit and process a Deployment request. |
| Kyverno admission controller | Evaluates the installed policy and returns an admission decision. |
| Kubernetes workload controllers and node | Reconcile an accepted Deployment into a running Pod. |
| Verification scripts | Check the evaluation results, rejection reason and live workload state. |

The policy is a CEL-based `ValidatingPolicy` with `validationActions: [Deny]`. It matches `apps/v1` Deployments on creation and updates across namespaces. The corrected example uses `emptyDir` at `/work`; the violating example requests `hostPath` access to the node's `/etc`.

## Verification

Run this in the prepared Killercoda workspace:

```bash
cd /root/kyverno-tutorial/kubernetes-policy-as-code

# Print success only when all three independent verification scripts succeed.
bash verify-policy.sh &&
  bash verify-rejection.sh &&
  bash verify-deployment.sh &&
  echo "[verify] Complete workflow passed."
```

| Script | Required evidence |
| --- | --- |
| `verify-policy.sh` | Insecure: one failure, exit 1; corrected: one pass, exit 0; both with zero errors/skips. |
| `verify-rejection.sh` | Ready policy and a server-side dry-run rejection identifying the intended policy and message. |
| `verify-deployment.sh` | No hostPath, `work-data` emptyDir mounted at `/work`, and replica counts `1/1/1/1`. |

A verifier succeeds with exit code `0`. The rejection it tests has exit code `1`; that is an expected policy result, not an unexpected verification failure.

On **7 October 2026**, Hasan's Killercoda terminal output recorded all three verifiers succeeding together, including rejection of a dry-run update after the compliant Deployment existed. The Pod was `1/1 Running`, and the workflow printed its final success message. That evidence concerns the tested exercise files; it does not establish independent grader access or teacher acceptance.

## Reproducibility and limits

| Item | Configuration |
| --- | --- |
| Kyverno controller and CLI | `1.19.1`, with downloaded files checked against pinned SHA-256 values. |
| Exercise checkout | `9efb0fd4ef2b0d10534d3f876499852f9e603a33`. |
| Browser backend | `kubernetes-kubeadm-1node`; the platform's Kubernetes version can change. |
| Workload | One replica using `busybox:1.36.1`, a version tag rather than an immutable digest. |

Scenario pages follow the published source, while setup prepares the pinned exercise checkout at `/root/kyverno-tutorial`. Documentation edits do not require changing that exercise pin. Changes to the policy, manifests or verifiers require selecting and testing a new pin.

This rule does not cover direct Pods, Jobs or every other workload kind. Installing it does not evict existing workloads. An available sleeping container does not prove a real application is healthy. Strict denial provides enforcement; audit or warning behaviour offers a less disruptive adoption phase but allows violations.

The tutorial demonstrates a check that could be used in CI; it does not configure a hosted CI pipeline.

## Source files

| Path | Purpose |
| --- | --- |
| `kubernetes-policy-as-code/index.json` | Scenario pages, setup and CHECK script mappings. |
| `intro.md`, `step1.md`-`step4.md`, `finish.md` in that directory | Learning outcomes, exercises and reflection. |
| `architecture.svg` in that directory | Architecture figure shared by the introduction and this README. |
| `setup.sh` in that directory | Installation, readiness waits and pinned exercise checkout. |
| `policy/` and `manifests/` in that directory | The policy and workload variants. |
| `verify-*.sh` in that directory | Repeatable checks for the three stages. |

## Delivery checks for the authors

- Record the direct public scenario URL and verify access from a learner session without creator privileges or paid services.
- After publishing documentation changes, check the introduction, figure and closing page in Killercoda.
- Retain a fresh run through every step and all CHECK buttons.
- Obtain Tobias's independent walkthrough and the arranged reviewers' feedback.
- Submit the final artefact through a new PR updating the course proposal, following the current course submission instructions.

AI tools assisted with code and documentation preparation. The recorded Kubernetes results come from Hasan's execution in Killercoda, not from static source checks.

## References

- [DD2482 2026 tutorial grading criteria](https://github.com/KTH/devops-course/blob/2026/grading-criteria.md#executable-tutorial)
- [Killercoda creator documentation](https://killercoda.com/creators)
- [Kyverno ValidatingPolicy](https://kyverno.io/docs/policy-types/validating-policy/)
- [Kubernetes admission webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- [Kubernetes volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
