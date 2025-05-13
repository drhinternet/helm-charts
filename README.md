# GreenArrow on Kubernetes

This feature is currently in alpha testing. Not all aspects of GreenArrow are currently supported.

Please contact us if you encounter any bugs and we will help to resolve them.


## Introduction

This repository contains a [Helm](https://helm.sh/) chart for installing [GreenArrow Email](https://greenarrowemail.com) in Kubernetes.

To configure GreenArrow using Helm, you'll create a `values.yaml` file. The available keys can be seen in the [`greenarrow/values.yaml`](./greenarrow/values.yaml) file.

Here's what's currently supported by this Helm chart:

* Configuration validation
* Message injection via HTTP Submission API or SMTP
* Outbound message delivery via an external HAProxy or GreenArrow Proxy server
* Scaling in and out, messages will be distributed to other MTA pods when scaling in
* If messages cannot be distributed during a scale in, they can optionally be written to a PersistentVolumeClaim (drainFallbackVolumeClaim)
* If message drain fails entirely, a snapshot of the pod's persistent path will be saved to an optional PersistentVolumeClaim (drainFallbackVolumeClaim).

Coming soon:

* Event Tracker pods to handle inbound bounce/fbl/click/open events
* Inbound SMTP for bounce/fbl handling
* Inbound HTTP for click/open handling
* Redistribution of messages written to the PersistentVolumeClaim (drainFallbackVolumeClaim)
* Improved documentation describing more details about this Kubernetes integration

Caveats to be aware of:

* When injecting via SMTP, the MTA pods will see the "client ip" of the load balancer, not the source client. This can
  break IP-based SMTP authorization and source IP logging. (A fix to this will be coming soon.)


## Directory Structure

| Path          | Description                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `bin/`        | Several scripts, described below, to make interacting with GreenArrow on Kubernetes with Helm simpler.                     |
| `config/`     | Directory for your GreenArrow configuration files that will be merged into `values.yaml` when you run `bin/config-rollup`. |
| `greenarrow/` | The definition of GreenArrow's Helm chart.                                                                                 |


## Configuration

To configure GreenArrow, create a `values.yaml` file at the root of this repository.

Here's an example of the configuration needed within `values.yaml`
(this document does not contain all available keys, see [`greenarrow/values.yaml`](./greenarrow/values.yaml) for the full list):

```yaml
# Version of GreenArrow to install.
greenarrowVersion: "0.1.0-0"

# mtaReplicaCount is the number of GreenArrow MTA pods that will be created.
mtaReplicaCount: 1

# licenseKey is your license key, as provided by GreenArrow (required).
licenseKey: "Z2EBn....1PaEvtn"

# defaultMessageHostname is the default hostname to use for injected messages (required).
defaultMessageHostname: "greenarrow.example.com"

# adminEmail and adminPasswordHash are used to initialize the first admin user (required).
#
# Generate adminPasswordHash with the following Docker command (you'll be prompted to enter the
# password you want to hash, twice):
#
#     docker run --pull always --rm -it greenarrowemail/greenarrow:latest generate_password_hash
adminEmail: "admin@example.com"
adminPasswordHash: "v1.09041b4e.c56b7dbc11...fc999451ef5062c3433660f85"

# secretConstant is used to generate unique security codes to be processed by this GreenArrow
# cluster. This value must be the same across all clusters that will process each others inbound
# events (such as clicks, opens, or bounces).
#
# This field is required and can be generated using this command:
#
#     docker run --pull always --rm -it greenarrowemail/greenarrow:latest generate_secret_constant
secretConstant: "229a595b...9f01487"

# ramQueueSize and bounceQueueSize represent the size of the in-memory delivery queues.
ramQueueSize: 1Gi
bounceQueueSize: 200Mi

# drainFallbackVolumeClaim is the name of an existing PersistentVolumeClaim that you want messages
# to be written to in the event that the instance cannot be fully drained.
#
# This PersistentVolumeClaim must have an accessMode of ReadWriteMany.
drainFallbackVolumeClaim: ""

config:
  greenarrow.conf: |-
    general {
        define_virtual_mtas_in_config_file yes
        define_url_domains_in_config_file yes
        define_mail_classes_in_config_file yes
        define_incoming_email_domains_in_config_file yes
        define_throttle_programs_in_config_file yes
        define_engine_users_in_config_file yes
        define_database_connections_in_config_file yes
        define_dkim_keys_in_config_file yes

        engine_time_zone UTC

        default_virtual_mta ipaddr-1

        accept_drain_from 10.244.0.0/24
    }

    greenarrow_proxy gaproxy1 {
        greenarrow_proxy_server gaproxy.example.com:807
        greenarrow_proxy_shared_secret "00000000000000000000000000000001"
        greenarrow_proxy_throttle_reconciliation_mode average
    }

    ip_address ipaddr-1 {
        smtp_source 127.0.0.1 ipaddr-1.example.com

        greenarrow_proxy gaproxy1
    }
  notifications_to: admin@example.com
```

All children keys beneath the `config:` key of this document are eventually written to the `/var/hvmail/control/` directory on the GreenArrow pods.

### Configuration Roll-up

If you prefer to not have to write all of your `greenarrow.conf` or other configuration files into `values.yaml` directly, we provide the `bin/config-rollup` script to update `values.yaml` for you.

1. Create the configuration files you want in the `config/` directory.
2. Run the `bin/config-rollup` script.
3. The `values.yaml` file is updated to contain the files from `config/` within the `config:` key.
4. You can then update your cluster using `helm upgrade`.


## Installation

You'll need to have configured `kubectl` to be connected to the Kubernetes cluster on which you're going to deploy.

Once you've done that and have written your `values.yaml` configuration, you are ready to install the GreenArrow Helm chart.

```
$ helm install ga2 ./greenarrow -f values.yaml
NAME: ga2
LAST DEPLOYED: Thu May  8 15:43:55 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

In the above command, `ga2` is the name of the Helm release we're installing. You can use whatever name makes sense for
your needs. This name will be used as a prefix to most of the Kubernetes resources created.


## Upgrade / Deploy New Configuration

To pull the latest changes to GreenArrow's Helm chart, you'll pull from Github into your local repository.

```
git pull --autostash origin
```

Upgrading to the new version of the Helm chart is accomplished via the `helm upgrade` command.

```
$ helm upgrade ga2 ./greenarrow -f values.yaml
Release "ga2" has been upgraded. Happy Helming!
NAME: ga2
LAST DEPLOYED: Thu May  8 15:46:49 2025
NAMESPACE: default
STATUS: deployed
REVISION: 2
TEST SUITE: None
```

The above `helm upgrade` command is the same one you'll use to apply your latest changes to `values.yaml` (for example,
if you are intending to deploy a change to `greenarrow.conf`). This command will result in your latest configuration
changes being used for freshly created pods, but not for pods that were running at the time you ran `helm upgrade`.

There are several ways to deploy the new configuration to running pods. First, you could issue Kubernetes a rolling
restart. This eliminates any variability in what commands need to be run, but does put extra load on your cluster as
each pod is drained of messages and recreated. In the command below, `ga2-mta` is the name of the deployment we're
restarting (that is, the `${release}-mta` deployment created by the GreenArrow Helm chart).

```
kubectl rollout restart deployment ga2-mta
```

The other, more fine tuned, way to engage the configuration changes is by using the provided `pod-run` command to deploy them.

```
bin/pod-run --release ga2 --deploy-config -- greenarrow_config reload
```

If there are other commands that need to be run, such as restarting the MTA services, you can run those using `pod-run` as well.

```
bin/pod-run --release ga2 --deploy-config -- hvmail_init restart
```

The `pod-run` command does the following:

1. Use `kubectl` to get a list of pods in the requested Helm release (ga2).
2. If the `--deploy-config` parameter is provided, wait for the updated ConfigMap/Secret resources to reach the pods (this can take up to a minute, depending on your cluster configuration), then install them in the local filesystem.
3. Run the requested command (`greenarrow_config reload`) on each pod.


## Configuration Validation

To validate your configuration prior to pushing it to your primary cluster, you can use a secondary cluster set to
"validator" mode. This has the effect of dropping replicas to 1 and eliminating unneccessary Kubernetes resources like
Services on the secondary cluster.

Here's how to install a cluster for validation:

```
helm install ga2validator ./greenarrow -f values.yaml --set validator=true
```

When you have an updated configuration to test, upgrade your secondary cluster with the same parameters:

```
helm upgrade ga2validator ./greenarrow -f values.yaml --set validator=true
```

To validate your new configuration:

```
bin/pod-run --release ga2validator --deploy-config -- greenarrow_config reload
```
