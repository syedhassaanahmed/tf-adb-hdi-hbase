provider "azurerm" {
  version = "=2.28.0"
  features {}
}

resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${random_string.unique.result}"
  location = var.rg_location
}

resource "azurerm_databricks_workspace" "adb" {
  name                = "dbw-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "premium"

  custom_parameters {
    no_public_ip        = false
    virtual_network_id  = azurerm_virtual_network.vnet.id
    private_subnet_name = azurerm_subnet.adb_private.name
    public_subnet_name  = azurerm_subnet.adb_public.name
  }
}

resource "azurerm_storage_account" "blob" {
  name                     = "st${random_string.unique.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "hdi" {
  name                  = "hdinsight"
  storage_account_name  = azurerm_storage_account.blob.name
  container_access_type = "private"
}

resource "random_password" "hdi" {
  length           = 10
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "@#*()-_=+[]{}:?"
}

resource "azurerm_hdinsight_hbase_cluster" "hbase" {
  name                = "hbase-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  cluster_version     = "4.0"
  tier                = "Standard"

  component_version {
    hbase = "2.1"
  }

  gateway {
    enabled  = true
    username = var.hdi_cluster_username
    password = random_password.hdi.result
  }

  storage_account {
    storage_container_id = azurerm_storage_container.hdi.id
    storage_account_key  = azurerm_storage_account.blob.primary_access_key
    is_default           = true
  }

  roles {
    head_node {
      vm_size            = "standard_e2s_v3"
      virtual_network_id = azurerm_virtual_network.vnet.id
      subnet_id          = azurerm_subnet.hdi.id
      username           = var.hdi_ssh_username
      password           = random_password.hdi.result
    }

    worker_node {
      vm_size               = "standard_a2m_v2"
      virtual_network_id    = azurerm_virtual_network.vnet.id
      subnet_id             = azurerm_subnet.hdi.id
      username              = var.hdi_ssh_username
      password              = random_password.hdi.result
      target_instance_count = 1
    }

    zookeeper_node {
      vm_size            = "standard_d1_v2"
      virtual_network_id = azurerm_virtual_network.vnet.id
      subnet_id          = azurerm_subnet.hdi.id
      username           = var.hdi_ssh_username
      password           = random_password.hdi.result
    }
  }
}

locals {
  setup_hbase = "${path.module}/setup_hbase.txt"
}

# The following script populates HBase with a sample table and uploads the hbase-site.xml config to blob storage
resource "null_resource" "setup_hbase" {
  triggers = {
    hbase_cluster             = azurerm_hdinsight_hbase_cluster.hbase.id
    setup_hbase               = filesha1(local.setup_hbase)
    azurerm_storage_container = azurerm_storage_container.hdi.id
  }

  provisioner "local-exec" {
    environment = {
      HDI_SSH_ENDPOINT = "${var.hdi_ssh_username}@${azurerm_hdinsight_hbase_cluster.hbase.ssh_endpoint}"
      HDI_SSH_PASSWORD = random_password.hdi.result
      SETUP_HBASE      = file(local.setup_hbase)
    }
    command = <<EOF
      set -eu

      sshpass -p "$HDI_SSH_PASSWORD" \
        ssh -o StrictHostKeyChecking=no $HDI_SSH_ENDPOINT "echo -e \"$SETUP_HBASE\" | hbase shell -n"

      sshpass -p "$HDI_SSH_PASSWORD" \
        ssh -o StrictHostKeyChecking=no $HDI_SSH_ENDPOINT \
          "hdfs dfs -copyFromLocal /etc/hbase/conf/hbase-site.xml wasbs://${azurerm_storage_container.hdi.name}@${azurerm_storage_account.blob.primary_blob_host}/"
EOF
  }

  depends_on = [azurerm_hdinsight_hbase_cluster.hbase]
}

