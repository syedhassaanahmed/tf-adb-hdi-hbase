output rg_name {
  value = azurerm_resource_group.rg.name
}

output adb_workspace_url {
  value = "https://${azurerm_databricks_workspace.adb.workspace_url}/"
}
