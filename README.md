# tf-adb-hdi-hbase
![Terraform](https://github.com/syedhassaanahmed/tf-adb-hdi-hbase/workflows/Terraform/badge.svg)

This Terraform template shows an E2E demonstration of how to connect from Azure Databricks to an HDInsight HBase cluster using the [hbase-spark](https://github.com/apache/hbase-connectors/tree/master/spark) connector.

## Caveats
- The [Hortwonworks shc](https://github.com/hortonworks-spark/shc) connector is broken on Databricks, see [this issue](https://stackoverflow.com/questions/58306725/how-to-write-to-hbase-in-azure-databricks).
- `hbase-spark` and `shc` have some subtle but important differences in package and data source names. Correct usage can be seen in this [example published by Cloudera](https://docs.cloudera.com/runtime/7.2.1/managing-hbase/topics/hbase-example-using-hbase-spark-connector.html).
- Databricks and HDInsight HBase must be provisioned in the same VNET.
- Authentication to HBase is done via config `hbase-site.xml`. This file exists on HDInsight head node and is copied to the attached Blob Storage. This blob storage container is then also mounted to Databricks i.e. the config file becomes available to all Databricks cluster nodes at `/dbfs/mnt/hdi/hbase-site.xml`.
- Databricks Cluster must be provisioned with runtime Scala 2.11 e.g. Runtime v6.6. Runtimes with Scala 2.12 won't work yet.
- The following 3 libraries must be attached to the cluster. Note the extra two in addition to `hbase-spark`;
```java
org.apache.hbase.connectors.spark:hbase-spark:1.0.0
org.apache.hbase:hbase-common:2.3.1
org.apache.hbase:hbase-server:2.3.1
```

## Requirements
- [Terraform](https://www.terraform.io/downloads.html)
- [Terraform authenticated via Service Principal](https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html)
- [sshpass](https://www.cyberciti.biz/faq/noninteractive-shell-script-ssh-password-provider/)

## Azure resources
- Virtual Network
- Blob Storage
- Azure Databricks Workspace
- HDInsight HBase cluster
>**Note:** The HBase cluster is provisioned with cheapest possible VMs for Head, Region and Zookeeper nodes. It will cost you ~$550 / month in Western Europe.

## Smoke Test
Once `terraform apply` has succeeded, navigate to the Databricks workspace and run the notebook `/Shared/TestHBase.scala`. This notebook connects to the HBase cluster and loads `Contacts` table into a `DataFrame`. This table was populated into HBase as part of the Terraform provisioning.
