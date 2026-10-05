\# Test the policy before deployment



A Kubernetes manifest describes the desired state of a workload. A manifest can be valid Kubernetes YAML while still requesting access that violates a security policy.



We will test two Deployment manifests against the same policy using the Kyverno CLI. These local checks do not create workloads in the cluster.



\## Open the exercise directory



Run the following command in the Killercoda terminal:



`cd /root/kyverno-tutorial/kubernetes-policy-as-code`{{exec}}



\## Understand the policy



Inspect the policy:



`cat policy/disallow-hostpath.yaml`{{exec}}



The policy matches Deployment creation and updates.



Its CEL expression allows a Deployment when either:



\- its Pod template has no volumes; or

\- every declared volume lacks a `hostPath` field.



The `Deny` action will reject violating requests once we install this policy in the cluster. For now, the CLI evaluates the policy against local manifest files.



\## Inspect the violating manifest



`cat manifests/insecure-deployment.yaml`{{exec}}



Find the volume named `node-config`. Its `hostPath` field refers to the node's `/etc` directory, which would be mounted inside the container at `/host-etc`.



A read-only mount still exposes the directory's contents. Preventing writes does not prevent access to sensitive node files.



\## Test the violating manifest



```bash

\# Capture the expected policy failure without interrupting the terminal session.

if kyverno apply policy/disallow-hostpath.yaml \\

&#x20; --resource manifests/insecure-deployment.yaml \\

&#x20; --detailed-results --remove-color; then

&#x20; echo "CLI exit code: 0"

else

&#x20; TUTORIAL\_CLI\_EXIT\_CODE=$?

&#x20; echo "CLI exit code: $TUTORIAL\_CLI\_EXIT\_CODE"

fi

```{{exec}}



Expected result:



```text

pass: 0, fail: 1, warn: 0, error: 0, skip: 0

CLI exit code: 1

```



The output should identify `disallow-hostpath` and explain that hostPath volumes are forbidden.



Exit code 1 alone is insufficient evidence: a technical error can also cause failure. Check that there is exactly one failed evaluation, with zero errors and zero skipped evaluations.



\## Inspect the corrected manifest



`cat manifests/secure-deployment.yaml`{{exec}}



The corrected manifest replaces the node directory mount with an `emptyDir` volume named `work-data`, mounted at `/work`.



This provides Pod-local working storage without requesting access to a node directory. Its contents are deleted when the Pod is removed.



Our example container does not require the node's `/etc` contents. Replacing hostPath with emptyDir would not preserve the behaviour of an application that depends on those files.



\## Test the corrected manifest



```bash

\# Evaluate the corrected manifest against exactly the same policy.

if kyverno apply policy/disallow-hostpath.yaml \\

&#x20; --resource manifests/secure-deployment.yaml \\

&#x20; --detailed-results --remove-color; then

&#x20; echo "CLI exit code: 0"

else

&#x20; TUTORIAL\_CLI\_EXIT\_CODE=$?

&#x20; echo "CLI exit code: $TUTORIAL\_CLI\_EXIT\_CODE"

fi

```{{exec}}



Expected result:



```text

pass: 1, fail: 0, warn: 0, error: 0, skip: 0

CLI exit code: 0

```



The corrected manifest satisfies this specific policy. Passing one policy does not establish that the workload is secure against every threat.



\## Verify both results



Run the automated check:



`bash verify-policy.sh`{{exec}}



It requires the expected exit code and evaluation counts for both manifests.



Expected final message:



```text

\[verify] Both policy checks passed.

```



\## Checkpoint



You have tested a policy before deployment, as a CI pipeline could do before allowing a change to proceed.



Consider why this check alone would not stop someone from submitting a different manifest directly to Kubernetes. In the next step, we enforce the policy at the Kubernetes API server.



\## References



\- \[Kyverno CLI: apply](https://kyverno.io/docs/kyverno-cli/reference/kyverno\_apply/)

\- \[Kubernetes volumes](https://kubernetes.io/docs/concepts/storage/volumes/)

