# Digital Ocean Kubernetes Challenge 12-2021
---
**Github Note: This README is syndicated at my blog over at **[davidjameshowell.com](https://davidjameshowell.com/post/digital-ocean-kubernetes-challenge-12-2021).**

## Preface

[Digital Ocean is hosting a Kubernetes challenge for the month of December, 2021.](https://www.digitalocean.com/community/pages/kubernetes-challenge) As someone who is still new to Kubernetes but tinkering with many of the internals, I decided this would be a great step to reach out of my comfort zone and try something new. I decided to select from the "medium" category in regards to *"Deploy a security and compliance system"*. These are real, applicable situations that can be applied to an actual company's posture, especially for a company new to Kubernetes adoption.

I would like to give my appreciation to Digital Ocean for being proactive in the Kubernetes community in not only providing us challenges with awesome rewards, but also providing credit to their services to achieve those challenges. *This work was completed entirely on the $120 30 day credit that Digital Ocean provided to use for these challenges.*

## How hard can image scanning be?

**tl;dr**: Image scanning on object submission is *not* as easy as it appeared...at least for the open-source tooling available at time of writing.

I started off intending to go into this project by completing it as container image scanning upon admission to the Kubernetes server. I had used tooling like Clair, Aqua, and Anchore Engine in the past. I looked around at tooling and landed mostly on Anchore Engine as it was open source and I had used it before Kubernetes made a full-force impact. I won't dive into intimate details but graze over my initial issues with this.

Setup comprised of two parts, an [admission controller](https://github.com/anchore/kubernetes-admission-controller) and the [Anchore Engine/API](https://github.com/anchore/anchore-engine). The controller works as a dynamic webhook controller that reads configurations coming in (such as deployments, statefulsets, and even one-off pods) and makes a request to the Anchore API based on a policy you set (breakglass, analyze the image, deny/allow based on policy). In short, anything other than breakglass was a nightmare and ends in a cyclic issue where the controller reaches out even for the images currently running and if they are not analyzed, will cause failures causing a cascading failure. I spent at least 3 days working on and off trying to get this to work, but in the end believe it's most likely just easier to do image scanning on a CI/CD before acceptance even comes into play. Additionally, much of the open-source software is very much DIY and pushes you heavily into enterprise offerings for "better" functionality, unfortunately. 

## Enter Kyverno 

Kyverno, as stated by themselves: "Kyverno (Greek for “govern”) is a policy engine designed specifically for Kubernetes". Kyverno allows us not only to alert and enforce policies but also to mutate resources (and keep running resources in check). Their policy engine is multifaceted, with extreme flexibility on the level of granularity and control you have for policy manufacturing. Its simple, readable language along with dead simple startup is what drew me to it over other solutions. It can be as lightweight or as heavy as you wish.

## The scenario

The scenario that we will set the stage for this challenge is that we are a small start-up company that manages properties. We have a finance team, a development team, and a facilities team. Each plays a pivotal role and has software that supports their duties.

The development team is the core of the business, as they create software that drives the data behind their purchasing decisions for the finance team! They are always working on some new software and deploying a lot of experimental applications into Kubernetes. On the other hand, the finance and facilities team only consumes applications that were deployed into the cluster.

As a small start-up, we want to make sure we can attribute costs to each department and validate infrastructure as being charged to certain cost centers. As such, we want to ensure that every pod regardless of type (Deployment/Statefulset/ReplicaSet/etc) has labels the appropriately detail their respective function.
Each pod shall container a `department` label that is `finance/facilities/development` as well as a `cost-center` label that details what cost center their resources are charged to (in this example, can be any arbitrary value as it is not important).

The cluster administrator has also deemed it that pods in the `finance` and `facilities` team should not be able to be exec into the pods. This may pose a security risk and should only be completed by an administrator of the cluster.

## The Setup

For this setup, we will be use Digital Ocean's Managed Kubernetes service along with their Spaces offering, which is a S3 compliant storage to hold our Terraform state files and Terraform to standup infrastructure related to the Kubernetes cluster. For Terraform deployments and Kubernetes management, we will be using Github Actions. I also use GitGuardian to ensure that no sensitive credentials are exposed in my Github repos, as there can be the possibility for leaks with Terraform and Kubernetes.

### Terraform State Backend via DO Spaces
```
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
  backend "s3" {
    bucket                      = "djh-projects-do-challenge-statefiles"
    key                         = "do-challenge-12-2021-k8-cluster"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    region                      = "us-west-2"
    endpoint                    = "sfo3.digitaloceanspaces.com"
  }
}
```

Some explanation is warranted here regarding the above Terraform state file. When using non-AWS S3 compliant storage, we need to ensure that we set endpoints as well as skipping credentials and metadata check. This is because we have to forgo features of AWS that are not supported on non-S3 storage platforms. All other features are standard, except for region in which we set a dummy one due to incompatability. Information regarding spaces and configuration outside of Terraform can be found [here](https://docs.digitalocean.com/reference/api/spaces-api/).

### Terraform

Our Terraform is very simple as we require only a VPC (not required but suggested) and the managed Kubernetes cluster. Terraform can be found in the aptly named Terraform folder. 

Terraform plans are conducted via Github Pull Requests using Github Actions. Upon PR creation, a plan will be ran and generated from. The contents of the plan will be added as comment in the PR for review to be considered for merging.

After a merge back to the main branch, that then kicks off an apply from the output of the original PR's plan contents. This will apply the contents and ensure that everything matches. This ensures that infrastructure deviations are caught early on. To be considered useful, you would need to enable branch protection to disable direct pushes to the main branch so all workflows go through the PR method.

### Kubernetes

Kyverno is configured through a manual job, as it is not necessary to run each commit. This workflow will download doctl used to obtain a low expiration Kubeconfig for our cluster, install kubectl, and finally install Kyverno from manifests from their main branch on Github. Note this is not considered production ready and you should always pin versions so you have an expected and repeatable output each time.

The next workflow is responsible for creating seed data, which is currently just namepsaces for `development/finances/facilities`.

And lastly we have a workflow for creating and updating policies for Kyverno, where we currently have two policies:

---
`deny-exec-by-namespace-name` - This policy is responsible for ensuring that only development namespaces have the ability to sh/exec into pods. For example, take this pod configuration here:
`run fin-nginx --image=nginx -l department=finance,cost-center=123 -n finance`

If we were to attempt to exec into this pod, we would receive the following error from Kyverno:
```
kubectl exec -ti fin-nginx -n finance -- bash
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request: 

resource PodExecOptions/finance/ was blocked due to the following policies

deny-exec-by-namespace-name:
  deny-exec-ns-pci: Pods in this namespace may not be exec'd into.
```

The policy is working as expected as we have restricted `finance` and `facilities` from exec'ing into those namespaces pods.

---
`require-labels` - This ensures that all pods have at least a `department` and `cost-center` label attached to their pod configurations. For example, creating a pod from kubectl:

```
k run fin-nginx-nolabels --image=nginx -n finance
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request: 

resource Pod/finance/fin-nginx-nolabels was blocked due to the following policies

require-labels:
  check-for-labels: 'validation error: The label `department` and `cost-center` is
    required for all namesapces. Rule check-for-labels failed at path /metadata/labels/department/'
```

Now if we add `department` but forget `cost-center`:

```
k run fin-nginx-nolabels --image=nginx -l department=finance -n finance
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request: 

resource Pod/finance/fin-nginx-nolabels was blocked due to the following policies

require-labels:
  check-for-labels: 'validation error: The label `department` and `cost-center` is
    required for all namesapces. Rule check-for-labels failed at path /metadata/labels/cost-center/'
```

We receive the same error, but indicating we're missing the `cost-center` label on the pod.

---

## Conclusion

This challenge showed me a fault in where I thought something might be easy (read: image scanning) but turned out to be more difficult than I could have imagined. I was able to work additionally further with alternative clouds (there are more providers than AWS, right??) and in depth with Github Actions. Github Aciton work can be considered a fundamental skill as more companies move from self hosted VCS and Jenkins to Github/Gitlab and built in CI/CD systems.

Lastly, compliance in the enterprise is extremely important so Kyverno is always worth reading and exploring more. Even for simple home applications, it can be valuable to QA deployments before they even reach running status to prevent embarassing errors. If you are on the fence of doing the challenge, I implore you to attempt it even if it's a simple one that gets your hands back on Kubernetes and into the Digital Ocean ecosystem! Thanks again to Digital Ocean and other related sponsors of this event, I cannot wait to make it rain with $150 to give to my favorite software on OpenCollective!
