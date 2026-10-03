\# Kubernetes Policy-as-Code with Kyverno



A Kubernetes manifest can be syntactically valid while requesting

unsafe access to the underlying node.



This tutorial explores two complementary security controls:

checking a manifest before deployment with the Kyverno CLI, and

enforcing a policy inside Kubernetes during admission.



\## Intended learning outcomes



After completing the full tutorial, you should be able to:



1\. Explain how the Kyverno CLI and Kubernetes admission enforcement

&#x20;  provide complementary policy checks.

2\. Identify a Deployment that violates a policy prohibiting hostPath

&#x20;  volumes, correct it, and verify the result.

3\. Explain the interactions between the policy, workload manifest,

&#x20;  Kubernetes API server, and Kyverno admission controller.



\## Environment



Killercoda provides a temporary Kubernetes cluster and a terminal

in your browser.



Run the tutorial commands in that terminal.



\## Development status



This initial version checks that the Kubernetes environment starts

correctly. The Kyverno installation and policy exercises will be

added in subsequent development steps.

