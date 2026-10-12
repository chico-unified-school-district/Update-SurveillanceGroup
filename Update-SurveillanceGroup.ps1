<#
Syncs Active Directory security group members from a CSV list
into an Exchange distribution group.
#>
[cmdletbinding()]
param (
 [Parameter(Mandatory = $True)][PSCredential]$O365Credential,
 [Parameter(Mandatory = $True)][PSCredential]$ADCredential,
 [Parameter(Mandatory = $True)][string]$DistributionGroup,
 [Parameter(Mandatory = $True)][string[]]$ADGroup,
 [Parameter(Mandatory = $False)][switch]$ClearExisting,
 [Alias('wi')][switch]$WhatIf
)

function Get-GroupMembers( [pscredential]$cred) {
 process {
  $groupName = $_
  if (!$groupName) {
   Write-Host 'Skipping row due to missing group name' -Fore Red
   return
  }
  Write-Host ('Querying {0}' -f $groupName) -Fore Cyan
  try {
   Get-ADGroupMember -Identity $groupName -Recursive -ErrorAction Stop -Credential $cred |
    Where-Object { $_.objectClass -eq 'user' } | ForEach-Object { Get-ADUser -Identity $_.ObjectGUID -Credential $cred }
  }
  catch {
   Write-Host ('Error querying {0}: {1}' -f $groupName, $_.Exception.Message) -Fore Red
  }
 }
}

function New-MemberObject {
 process {
  $obj = '' | Select-Object ad, group
  $obj.ad = $_
  $obj.group = $DistributionGroup
  $obj
 }
}

function Skip-DuplicateUser {
 begin {
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
 }
 process {
  if (!$seen.Add($_.ad.DistinguishedName)) {
   return
  }
  $_
 }
}

function Skip-ExistingMember ($existing) {
 process {
  if ($existing -and ($existing -contains $_.ad.DistinguishedName -or $existing -contains $_.ad.SamAccountName)) {
   Write-Host ('Skipping {0} (already in {1})' -f $_.ad.SamAccountName, $_.group) -Fore Yellow
   return
  }
  $_
 }
}

function Clear-GroupMembers ($targetGroup) {
 $current = Get-DistributionGroupMember -Identity $targetGroup -ResultSize Unlimited -ErrorAction SilentlyContinue
 if ($current) {
  Write-Host ('Clearing {0} existing member(s) from {1}' -f $current.Count, $targetGroup) -Fore Yellow
  foreach ($member in $current) {
   Remove-DistributionGroupMember -Identity $targetGroup -Member $member.Identity -Confirm:$false -WhatIf:$WhatIf
  }
 }
}

function Add-ExchGroupMember {
 process {
  $msgVars = $MyInvocation.MyCommand.Name, $_.ad.SamAccountName, $_.group
  Write-Host ('{0},{1},{2}' -f $msgVars ) -Fore Blue
  try {
   Add-DistributionGroupMember -Identity $_.group -Member $_.ad.UserPrincipalName -Confirm:$false -WhatIf:$WhatIf
  }
  catch {
   Write-Host ('Error adding {0}: {1}' -f $_.ad.SamAccountName, $_.Exception.Message) -Fore Red
  }
 }
}

function Update-GroupMembers {
 Clear-SessionData
 $existing = if ($ClearExisting) {
  Clear-GroupMembers -targetGroup $DistributionGroup
  @()
 }
 else {
  @(Get-DistributionGroupMember -Identity $DistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DistinguishedName)
 }

 function Show-Object {
  process {
   Write-Verbose ($_ | Out-String)
  }
 }

 $ADGroup |
  Get-GroupMembers -cred $ADCredential |
   New-MemberObject |
    Skip-DuplicateUser |
     Skip-ExistingMember -existing $existing |
      Add-ExchGroupMember |
       Show-Object
}

# ================================= main ==================================
Import-Module -Name ActiveDirectory -Cmdlet Get-ADGroupMember, Get-ADUser
Import-Module -Name CommonScriptFunctions -Cmdlet Clear-SessionData, Show-BlockInfo, Show-TestRun
Import-Module -Name ExchangeOnlineManagement -Cmdlet Connect-ExchangeOnline, Disconnect-ExchangeOnline,
Get-DistributionGroupMember, Add-DistributionGroupMember, Remove-DistributionGroupMember
Show-BlockInfo main

Show-BlockInfo "Process started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if ($WhatIf) { Show-TestRun }
Disconnect-ExchangeOnline -Confirm:$false
Connect-ExchangeOnline -Credential $O365Credential -ShowBanner:$false

Update-GroupMembers

Disconnect-ExchangeOnline -Confirm:$false
Show-BlockInfo "Process completed $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
