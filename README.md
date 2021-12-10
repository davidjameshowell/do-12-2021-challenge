# Digital Ocean Kubernetes Challenge 12-2021
---
## Preface

[Digital Ocean is hosting a Kubernetes challenge for the month of December, 2021.](https://www.digitalocean.com/community/pages/kubernetes-challenge) As someone who is still new to Kubernetes but tinkering with many of the internals, I decided this would be a great step to reach out of my comfort zone and try something new. I decided to select from the "medium" category in regards to *"Deploy a security and compliance system"*. These are real, applicable situations that can be applied to an actual company's posture, especially for a company new to Kubernetes adoption.

## How hard can image scanning be?

**tl;dr**: Image scanning on object submission is *not* as easy as it appeared...at least for the open-source tooling available at the time of writing.

I started off intending to go into this project by completing it as container image scanning upon admission to the Kubernetes server. I had used tooling like Clair, Aqua, and Anchore Engine in the past. I looked around at tooling and landed mostly on Anchore Engine as it was open source and I had used it before Kubernetes made a full-force impact. I won't dive into intimate details but graze over my initial issues with this.

Setup comprised of two parts, an [admission controller](https://github.com/anchore/kubernetes-admission-controller) and the [Anchore Engine/API](https://github.com/anchore/anchore-engine). The controller works as a dynamic webhook controller that reads configurations coming in (such as deployments, statefulsets, and even one-off pods) and makes a request to the Anchore API based on a policy you set (breakglass, analyze the image, deny/allow based on policy). In short, anything other than breakglass was a nightmare and ends in a cyclic issue where the controller reaches out even for the images currently running and if they are not analyzed, will cause failures causing a cascading failure. I spent at least 3 days working on and off trying to get this to work, but in the end believe it's most likely just easier to do image scanning on a CI/CD before acceptance even comes into play. Additionally, much of the open-source software is very much DIY and pushes you heavily into enterprise offerings for "better" functionality, unfortunately. 

## Enter Kyverno 

Kyverno, as stated by themselves: "Kyverno (Greek for “govern”) is a policy engine designed specifically for Kubernetes". Kyverno allows us not only to alert and enforce policies but also to mutate resources (and keep running resources in check). Their policy engine is multifaceted, with extreme flexibility on the level of granularity and control you have for policy manufacturing. Its simple, readable language along with dead simple startup is what drew me to it over other solutions. It can be as lightweight or as heavy as you wish.

mainternance 
## The scenario

The scenario that we will set the stage for this challenge is that we are a small start-up company that manages properties. We have a finance team, a development team, and a facilities team. Each plays a pivotal role and has software that supports their duties.

The development team is the core of the business, as they create software that drives the data behind their purchasing decisions for the finance team! They are always working on some new software and deploying a lot of experimental applications into Kubernetes. On the other hand, the finance and facilities team only consumes applications that were deployed into the cluster.

As a small start-up, we want to make sure we can attribute costs to each department and validate infrastructure as being charged to certain cost centers. As such, we want to ensure that every pod regardless of type (Deployment/Statefulset/ReplicaSet/etc) has labels the appropriately detail their respective function.
Each pod shall container a `department` label that is `finance/facilities/development` as well as a `cost-center` label that details what cost center their resources are charged to (this may be any number of values, so none is set by default).

The cluster administrator has also deemed that pods in the `finance` and `facilities` team should not be able to be exec into the pods. This may pose a security risk and should only be completed by an administrator of the cluster.

## The Setup

For this setup, we will be using Digital Ocean's Managed Kubernetes service along with their Spaces offering, which is S3 compliant storage to hold our Terraform state files. We will be using Github actions to do all of our deployments from Terraform to Kubernetes deployments.

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

Some explanation is warranted here regarding the above Terraform state file. When using non-AWS S3 compliant storage, we need to ensure that we set endpoints as well as skipping credentials and metadata checks. This is because we have to forgo features of AWS that are not supported on non-S3 storage platforms. All other features are standard, except for the region in which we set a dummy one due to incompatibility. Information regarding spaces and configuration outside of Terraform can be found [here](https://docs.digitalocean.com/reference/api/spaces-api/).
