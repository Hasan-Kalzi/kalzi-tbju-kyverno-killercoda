\# Check the Kubernetes environment



The browser terminal is connected to a temporary machine running

a single-node Kubernetes cluster.



`kubectl` is the command-line client used to communicate with the

Kubernetes API server.



\## Wait for the node



Run:



`kubectl wait --for=condition=Ready node --all --timeout=180s`{{exec}}



The command should complete successfully with a message indicating

that the Ready condition has been met.



\## Inspect the node



Run:



`kubectl get nodes`{{exec}}



Check that the node's STATUS is `Ready`.



\## Inspect the system components



Run:



`kubectl get pods -n kube-system`{{exec}}



These Pods provide Kubernetes services such as networking and DNS.



Most long-running system Pods should become `Running`. Some setup

tasks may appear as `Completed`.



If Pods remain `Pending`, `CrashLoopBackOff`, or `Error`, record

the output before continuing.



\## Checkpoint



Continue once the node is Ready and the system components have

settled.

