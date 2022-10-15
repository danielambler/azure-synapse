<####################################################################################################################
#
# Author        : Dan Ambler
# Purpose       : Applies necessary security permissions for a Synapse - Dataverse link
# Prerequisites : Must have an ADLS Gen 2 account with Owner and Storage Blob Data Contributor access
#               : Storage replication must be read-access geo-redundant (at the moment only standard tier is supported)
#               : Public network access must be enabled on the storage account (due to the fabric not providing public network address space)
#               : TODO - Check azure permissions first
####################################################################################################################>
param(
    [Parameter(Mandatory = $true,
                HelpMessage = "The user name being granted permission e.g bob@somecompany.com")]
    [string]$user_name,
    [Parameter(Mandatory = $true,
                HelpMessage = "The storage account name on which to grant access")]
    [string]$storage_account_name,
    [Parameter(Mandatory = $true,
                HelpMessage = "The Synapse Workspace name on which to grant access")]
    [string]$synapse_workspace_name,
    [Parameter(Mandatory = $true,
                HelpMessage = "The Power app environment where the link will be setup N.B this is the GUID of the environment")]
    [string]$power_app_environment_name
)

# Dont change!!
$storage_blob_data_contributor_role_name = "Storage Blob Data Contributor"
$owner_role_name = "Owner"
$synapse_workspace_administrator_role_name = "Synapse Administrator"

<#
Are all resources and environments available to us?
#>
$user = Get-AzADUser -UserPrincipalName $user_name
    if ($null -eq $user) { throw "User ${user_name} does not exist or could not be accessed" }

$owner_role = Get-AzRoleDefinition -Name $owner_role_name
    if ($null -eq $owner_role) { throw "Group ${owner_role_name} does not exist or could not be accessed" }

$storage_blob_data_contributor_role = Get-AzRoleDefinition -Name $storage_blob_data_contributor_role_name
    if ($null -eq $storage_blob_data_contributor_role) { throw "Group ${storage_blob_data_contributor_role_name} does not exist or could not be accessed" }

$storage_account = Get-AzResource -Name $storage_account_name
    if ($null -eq $storage_account) { throw "Storage account ${storage_account_name} does not exist or could not be accessed" }

$synapse_workspace = Get-AzSynapseWorkspace -Name $synapse_workspace_name
    if ($null -eq $synapse_workspace) { throw "Synapse Workspace ${synapse_workspace_name} does not exist or could not be accessed" }

$synapse_workspace_administrator_role = Get-AzSynapseRoleDefinition -WorkspaceName $synapse_workspace_name -Name $synapse_workspace_administrator_role_name
    if ($null -eq $synapse_workspace_administrator_role) { throw "Synapse Workspace role ${synapse_workspace_administrator_role_name} does not exist or could not be accessed" }

$power_app_environment = Get-AdminPowerAppEnvironment -EnvironmentName $power_app_environment_name
    if ($null -eq $power_app_environment.EnvironmentName) { throw "It appears you may not be an admin of the Power Platform environment with guid ${power_app_environment_name} or this environment may not exist.  Please check with your environment admin." }

<#
Assign the necessary permissions to ADLS
#>
if ($null -eq (Get-AzRoleAssignment -ObjectId ($user).Id -Scope ($storage_account).Id -RoleDefinitionId ($owner_role).Id)) {
    try {
        New-AzRoleAssignment -ObjectId ($user).Id -Scope ($storage_account).Id -RoleDefinitionId ($owner_role).Id -ErrorAction Continue    
    }
    catch {
        Write-Output("An error occurred assigning the ${owner_role_name} role to ${user_name} on the storage account ${storage_account_name}.  
            Please check with your administrator and verify you have permission to perform the task")
    }
}

if ($null -eq (Get-AzRoleAssignment -ObjectId ($user).Id -Scope ($storage_account).Id -RoleDefinitionId ($storage_blob_data_contributor_role).Id)) {
    try {
        New-AzRoleAssignment -ObjectId ($user).Id -Scope ($storage_account).Id -RoleDefinitionId ($storage_blob_data_contributor_role).Id -ErrorAction Continue    
    }
    catch {
        Write-Output("An error occurred assigning the ${storage_blob_data_contributor_role_name} role to ${user_name} on the storage account ${storage_account_name}.  
            Please check with your administrator and verify you have permission to perform the task")
    }
}


<#
Assign the necessary permissions to the Synapse Workspace
#>
if ($null -eq (Get-AzSynapseRoleAssignment -WorkspaceObject $synapse_workspace -RoleDefinitionId ($synapse_workspace_administrator_role).Id -ObjectId ($user).id  )) {
    try {
        New-AzSynapseRoleAssignment -ObjectId ($user).id -WorkspaceObject $synapse_workspace -RoleDefinitionId ($synapse_workspace_administrator_role).Id -ErrorAction Continue    
    }
    catch {
        Write-Output("An error occurred assigning the ${synapse_workspace_administrator_role_name} role to ${user_name} on the Synapse Workspace ${synapase_workspace_name}.  
            Please check with your administrator and verify you have permission to perform the task")
    }
}

Write-Output("It appears you can go ahead and setup the Azure Synapse Link For Dataverse - happy days!!")