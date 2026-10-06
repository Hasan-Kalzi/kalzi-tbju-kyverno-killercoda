# Enforce the policy during Kubernetes admission

The CLI check provides early feedback, but a user or automation tool could submit a different manifest directly to Kubernetes. We now enforce the same policy when the API server receives a matching request.

Kyverno is already installed by the scenario setup. In this step, we install our own policy and test its admission behaviour.

## Open the exercise directory

`cd /root/kyverno-tutorial/kubernetes-policy-as-code`{{exec}}

## Install the policy

`kubectl apply -f policy/disallow-hostpath.yaml`{{exec}}

This command creates the Kyverno `ValidatingPolicy` resource. Applying a policy is different from testing a local policy file with the CLI: the cluster can now use it to evaluate matching API requests.

Wait until Kyverno reports that the policy is ready:

```bash
# Wait for the installed policy to become ready before testing admission.
kubectl wait \
  --for=jsonpath='{.status.conditionStatus.ready}'=true \
  validatingpolicy/disallow-hostpath \
  --timeout=120s
```{{exec}}

The command should finish with `condition met`. If it fails or times out, stop and inspect the policy before attempting the next exercise.

`kubectl get validatingpolicy disallow-hostpath`{{exec}}

The `READY` column should show `true`.

## Understand the interacting components

| Component | Responsibility in this exercise |
| --- | --- |
| `kubectl` | Reads the manifest and submits the desired Deployment to the Kubernetes API server. |
| Kubernetes API server | Processes the request and invokes matching admission webhooks before persisting an accepted change. |
| Kyverno admission controller | Evaluates the installed policy against the submitted Deployment and returns an admission decision. |
| Deployment and ReplicaSet controllers | Reconcile an accepted Deployment into Pods after it has been stored. |

The policy checks the incoming Deployment's Pod template. When its CEL expression is false, the `Deny` action causes rejection. The API server returns the policy message to `kubectl` instead of storing the violating change.

For a rejected creation request, there is no new Deployment for the workload controllers to reconcile, so this request does not produce a Pod.

## Submit the violating manifest

```bash
# Attempt a real Deployment request and capture the expected rejection.
if kubectl apply -n default -f manifests/insecure-deployment.yaml \
  --request-timeout=30s; then
  echo "kubectl exit code: 0"
else
  TUTORIAL_KUBECTL_EXIT_CODE=$?
  echo "kubectl exit code: $TUTORIAL_KUBECTL_EXIT_CODE"
fi
```{{exec}}

The request should fail with exit code `1`. The response should identify the Kyverno admission webhook, name `disallow-hostpath`, and include this policy message:

```text
hostPath volumes are forbidden because they expose the Kubernetes node's filesystem to the workload.
```

A connection error, invalid manifest, or permission error does not demonstrate policy enforcement. Check the stated reason for rejection.

If the request succeeds, stop: admission enforcement is not behaving as expected.

## Check what was stored

`kubectl get deployment policy-demo -n default`{{exec}}

On a fresh run through the tutorial, the expected response is:

```text
Error from server (NotFound): deployments.apps "policy-demo" not found
```

This expected error confirms that the rejected creation request did not leave a Deployment behind.

If you repeat this exercise after deploying the corrected manifest in the next step, the existing Deployment remains. The rejected update does not replace it with the violating manifest.

## Verify admission rejection

`bash verify-rejection.sh`{{exec}}

The verifier requires a ready policy, then submits the violating manifest using a server-side dry run. This invokes admission without persisting a workload, making the check repeatable even when the corrected Deployment already exists.

The verifier checks the response for the intended Kyverno policy denial. It does not count an arbitrary command failure as success.

Expected final output:

```text
[verify] kubectl exit code: 1
[verify] Kyverno rejected the hostPath Deployment.
```

The verifier itself exits with code `0` when the expected rejection is confirmed.

## Scope and limitations

This cluster-scoped policy matches Deployment creation and updates across namespaces. We use `default` for the exercise.

Its rule does not match direct Pod creation, Jobs, or other workload kinds. Installing it also does not remove existing workloads. A production policy strategy would need appropriate coverage and a plan for existing resources.

## Checkpoint

You have now used the same policy for pre-deployment feedback and admission enforcement.

Explain why a failed CLI check and a rejected API request are different events, even though both evaluate the same rule. In the next step, we submit the corrected manifest and verify that its Pod becomes available.

## References

- [Kubernetes dynamic admission control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- [Kyverno ValidatingPolicy](https://kyverno.io/docs/policy-types/validating-policy/)
- [Kubernetes API dry runs](https://kubernetes.io/docs/reference/using-api/api-concepts/#dry-run)
