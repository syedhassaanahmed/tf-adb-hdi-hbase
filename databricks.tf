terraform {
  required_providers {
    databricks = {
      source  = "databrickslabs/databricks"
      version = "0.2.5"
    }
  }
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.adb.id
}

resource "databricks_cluster" "default" {
  cluster_name            = "Default Cluster"
  spark_version           = "6.6.x-scala2.11"
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 20

  autoscale {
    min_workers = 1
    max_workers = 10
  }

  library {
    maven {
      coordinates = "org.apache.hbase.connectors.spark:hbase-spark:1.0.0"
    }
  }

  library {
    maven {
      coordinates = "org.apache.hbase:hbase-common:2.3.1"
    }
  }

  library {
    maven {
      coordinates = "org.apache.hbase:hbase-server:2.3.1"
    }
  }
}

resource "databricks_secret_scope" "terraform" {
  name                     = "terraform"
  initial_manage_principal = "users"
}

resource "databricks_secret" "storage_key" {
  key          = "blob_storage_key"
  string_value = azurerm_storage_account.blob.primary_access_key
  scope        = databricks_secret_scope.terraform.name
}

resource "databricks_azure_blob_mount" "hdi" {
  container_name       = azurerm_storage_container.hdi.name
  storage_account_name = azurerm_storage_account.blob.name
  mount_name           = "hdi"
  auth_type            = "ACCESS_KEY"
  token_secret_scope   = databricks_secret_scope.terraform.name
  token_secret_key     = databricks_secret.storage_key.key
  cluster_id           = databricks_cluster.default.id
}

resource "databricks_notebook" "test_hbase" {
  content   = filebase64("${path.module}/TestHBase.scala")
  path      = "/Shared/TestHBase.scala"
  overwrite = true
  language  = "SCALA"
}
