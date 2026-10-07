# Policy testing, enforcement and rollout verified

You have followed a policy through three distinct checks: local evaluation before deployment, enforcement during Kubernetes admission, and verification of the accepted workload.

## Interpret the outcome

| Evidence | Meaning |
| --- | --- |
| The hostPath manifest produces one failed CLI evaluation and zero errors or skipped evaluations. | The local policy rejects the intended violation. |
| The emptyDir manifest produces one passed CLI evaluation. | The corrected file satisfies the same policy. |
| The admission response names `disallow-hostpath` and explains the forbidden hostPath volume. | The cluster rejects a matching request for the intended policy reason. |
| The live Deployment uses `emptyDir` at `/work`, with one desired, updated, ready and available replica. | The corrected workload has reached the state required by this exercise. |
| All three verifiers succeed and print `[verify] Complete workflow passed.` | The separate checks work together, including rejection of a violating dry-run update after the corrected Deployment exists. |

A command failure by itself is insufficient evidence of security enforcement. An unreachable API server, malformed YAML or an image pull failure represents a different problem. The verifiers check both the outcome and the reason.

## Explain the learning outcomes

Before finishing, explain these points in your own words:

1. **Why retain admission enforcement after a CLI check?** A caller can submit another manifest or bypass the local check. Admission applies the installed rule when matching requests reach the API server.
2. **Why does a successful apply not prove the application works?** Scheduling, image downloads and container startup happen later. Our replica check establishes availability for a BusyBox container that sleeps; it does not test business functionality.
3. **Why use emptyDir here?** The example needs temporary working storage and does not require the node's files. Data remains through container restarts in the same Pod but is lost when that Pod is removed. An application that needs persistent data or specific node files needs a different design.
4. **What exactly does the rule protect?** This policy checks Deployment Pod templates on creation and updates. It does not cover direct Pod creation, Jobs or every other workload kind, and it does not remove already running workloads.

## Strict enforcement and gradual adoption

This exercise uses `Deny` so that violating requests cannot proceed. That gives a clear enforcement result but requires workloads to be corrected before delivery.

A gradual rollout is an alternative: begin with audit or warning behaviour to identify the effect on existing workflows, resolve violations and test both allowed and denied cases, then enable denial for the intended scope. Audit or warning behaviour alone does not prevent a violating request. This tutorial does not exercise that alternative; keep the policy in `Deny` for the checks you have just completed.

Before production use, decide who can change policies, which resources and operations they cover, how exceptions are governed, and how the admission service remains available. A webhook's handling of connection failures is separate from its decision to reject an evaluated policy violation.

## Where this approach is useful

This pattern is useful for development and platform teams that want versioned, testable deployment constraints with both early feedback and an independent admission check.

It needs broader coverage and operational controls before it can enforce an organisation's security requirements. Passing one policy is not a complete security assessment, and replacing storage types cannot automatically preserve an application's behaviour.

## Keep the result reproducible

The exercise revision, Kyverno version and download checksums are pinned in `setup.sh`. Killercoda's Kubernetes environment can change, and the BusyBox image uses a version tag. Recheck compatibility when those dependencies or the policy change.

The Killercoda environment is temporary. Keep any observations you need outside the session before closing it. Avoid removing the policy as a workaround: the completed exercise demonstrates correction of the workload while enforcement stays active.

## References

- [Kyverno ValidatingPolicy](https://kyverno.io/docs/policy-types/validating-policy/)
- [Kubernetes volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Kubernetes admission webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
