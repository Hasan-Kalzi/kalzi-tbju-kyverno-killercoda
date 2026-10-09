# Deploy the corrected workload and verify the outcome

The policy rejected the hostPath manifest. We will now keep the policy enforced, deploy the corrected manifest, and check that Kubernetes creates an available workload.

Acceptance by admission and successful execution are separate outcomes. A permitted manifest can still fail to run because of an image pull error, insufficient resources, or an application failure.

## Open the exercise directory

`cd /root/kyverno-tutorial/kubernetes-policy-as-code`{{exec}}

## Review the correction

`cat manifests/secure-deployment.yaml`{{exec}}

The corrected Deployment uses an `emptyDir` volume named `work-data`, mounted at `/work`. The node directory and its `/host-etc` mount are removed.

The workload name, container image, replica count, and resource requests remain the same. We correct the workload's storage request rather than weakening or deleting the policy.

The file name `secure-deployment.yaml` refers to this tutorial's correction. It does not imply that the manifest satisfies every possible security requirement.

## Deploy the corrected manifest

`kubectl apply -n default -f manifests/secure-deployment.yaml --request-timeout=30s`{{exec}}

On a fresh run, the expected response is:

```text
deployment.apps/policy-demo created
```

On a repeated run, `configured` or `unchanged` can also be expected.

The API server accepts this request after admission checks. The Deployment controller creates a ReplicaSet, the ReplicaSet controller creates a Pod, the scheduler assigns it to a node, and the kubelet starts its container.

## Wait for the rollout

```bash
# Wait for the requested replica to become available before claiming success.
kubectl rollout status deployment/policy-demo -n default \
  --timeout=120s --request-timeout=130s
```{{exec}}

Expected final message:

```text
deployment "policy-demo" successfully rolled out
```

Inspect the Deployment and its labelled Pods:

`kubectl get deployment policy-demo -n default`{{exec}}

`kubectl get pods -n default -l app=policy-demo`{{exec}}

The Deployment should show `READY` as `1/1`, with one up-to-date and one available replica. Its Pod should show `1/1` ready containers and `Running` status. Generated Pod names and ages will vary.

If the rollout fails, inspect the Pod's events and container status before continuing:

`kubectl describe pods -n default -l app=policy-demo`{{exec}}

A Pod in `Pending` or `ImagePullBackOff` indicates a different failure stage from the admission rejection observed earlier: Kubernetes has accepted and created resources, but the workload has not become available.

## Verify the live Deployment

`bash verify-deployment.sh`{{exec}}

The verifier checks the live Deployment, not just the local YAML file. It requires:

- no hostPath volumes in the Pod template;
- an emptyDir volume named `work-data`;
- the `demo` container mounting that volume at `/work`;
- one desired, updated, ready, and available replica.

A Deployment scaled to zero cannot satisfy this check.

Expected final output:

```text
[verify] The corrected Deployment uses emptyDir at /work.
[verify] One updated replica is ready and available.
[verify] Deployment verification passed.
```

The verifier exits with code `0` on success. Our BusyBox container only sleeps: availability here demonstrates that this example starts, rather than testing a real application's functionality.

## Check the complete workflow

Each script verifies a different stage:

| Script | What it checks |
| --- | --- |
| `verify-policy.sh` | Runs both local CLI evaluations and compares their exit codes and exact evaluation counts with the expected results. |
| `verify-rejection.sh` | Requires a ready policy, submits the violating manifest using a server-side dry run, and checks the rejection's exit code, webhook text, policy name and reason. |
| `verify-deployment.sh` | Inspects the live Deployment's volume and mount, waits for rollout, and requires one desired, updated, ready and available replica. |

The shell's `&&` operator starts each command only when the preceding command succeeds. The final message therefore appears only when all three scripts return `0`. An expected rejection inside a script can return `1`; the script checks that result and reports whether the test succeeded.

Run all three verifiers after deploying the corrected workload:

```bash
# Continue only when each verification succeeds.
bash verify-policy.sh &&
  bash verify-rejection.sh &&
  bash verify-deployment.sh &&
  echo "[verify] Complete workflow passed."
```{{exec}}

The rejection verifier now exercises admission against an existing Deployment using a server-side dry run. The violating update must still be denied while the corrected workload remains available.

Expected final message:

```text
[verify] Complete workflow passed.
```

## Design decisions and trade-offs

| Decision | Benefit | Limit or trade-off |
| --- | --- | --- |
| Use one policy for CLI checks and admission | Gives early feedback and enforces the rule when matching requests reach the cluster. | Local manifest checks cannot predict image pulls, scheduling, or application behaviour. |
| Reject the violating request | Makes the failure and required correction visible to the developer. | The developer must correct the manifest before deployment can proceed. |
| Use emptyDir for this example | Provides temporary working storage without requesting a node directory. | Data survives container crashes within the same Pod but is lost when the Pod is removed. |
| Use a small, single-replica workload | Keeps the browser exercise quick and easy to inspect. | Does not demonstrate production availability or application health checks. |

## Reflection

Consider these questions before finishing:

1. Why retain admission enforcement when the CLI check already rejects the violating manifest?
2. Why does a successful `kubectl apply` not prove that the workload is running?
3. Would replacing hostPath with emptyDir preserve the behaviour of an application that needs the node's configuration files?
4. What would need to change before applying this policy strategy to production?

The CLI provides feedback before deployment, while admission also covers matching direct API submissions. Rollout verification checks a later stage of the workflow. The storage correction suits this example because its container does not need the node's configuration; a real application needs storage chosen for its actual requirements.

For production, extend policy coverage to the required resource kinds, test both allowed and denied cases, control who can modify policies, and plan how to handle existing workloads. Also consider the availability of the admission service: a webhook `failurePolicy` of `Fail` rejects requests when calling the webhook fails, while `Ignore` lets requests continue past that error. This error-handling choice is separate from an explicit policy denial, which rejects the request regardless of the webhook failure policy.

## Checkpoint

You have tested a manifest before deployment, enforced the same rule during admission, corrected the manifest, and verified the resulting workload. Together, these steps connect development feedback, deployment controls, and operational verification in one DevOps workflow.

## References

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [kubectl rollout status](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_status/)
- [Kubernetes volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Admission webhook failure policy](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#failure-policy)
