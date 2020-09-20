// Databricks notebook source
// MAGIC %md ## Steps
// MAGIC - Make sure Databricks and HDInsight HBase are both provisioned in the same VNET
// MAGIC - Provision a Databricks cluster with runtime Scala 2.11 e.g. Runtime v6.6. Runtimes with Scala 2.12 won't work
// MAGIC - Obtain the `hbase-site.xml` config from inside your HDInsight cluster at path `/etc/hbase/conf/hbase-site.xml` and upload it to DBFS
// MAGIC - Install the following libraries on the cluster and afterwards restart it
// MAGIC   - org.apache.hbase.connectors.spark:hbase-spark:1.0.0
// MAGIC   - org.apache.hbase:hbase-common:2.3.1
// MAGIC   - org.apache.hbase:hbase-server:2.3.1

// COMMAND ----------

import org.apache.hadoop.fs.Path
import org.apache.hadoop.hbase.HBaseConfiguration
import org.apache.hadoop.hbase.spark.HBaseContext

// COMMAND ----------

// MAGIC %sh cat /dbfs/mnt/hdi/hbase-site.xml

// COMMAND ----------

val conf = HBaseConfiguration.create()
conf.addResource(new Path("/dbfs/mnt/hdi/hbase-site.xml"))

//conf.get("hbase.zookeeper.quorum")
new HBaseContext(spark.sparkContext, conf)

// COMMAND ----------

val df = spark.read.format("org.apache.hadoop.hbase.spark")
 .option("hbase.columns.mapping",
   "rowkey STRING :key, officePhone STRING Office:Phone, officeAddress STRING Office:Address, personalName STRING Personal:Name, personalPhone STRING Personal:Phone")
 .option("hbase.table", "Contacts")
 .load()

display(df)
