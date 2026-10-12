# Update-SurveillanceGroup

`Update-SurveillanceGroup.ps1` synchronizes users from one or more Active Directory security groups into an Exchange Online distribution group. It queries each source group recursively, includes user objects only, deduplicates users across source groups, and adds users who are not already members of the target group.

## Requirements

- Windows PowerShell with the `ActiveDirectory` module and access to the relevant domain controllers.
- The `ExchangeOnlineManagement` module and an account with permission to manage the target distribution group.
- The `CommonScriptFunctions` module, which provides `Clear-SessionData`, `Show-BlockInfo`, and `Show-TestRun`.
- Credentials with permission to read the source AD groups and update the Exchange distribution group.

## Parameters

| Parameter               | Required | Description                                                                                                                            |
| ----------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `-O365Credential`       | Yes      | Credential used to connect to Exchange Online.                                                                                         |
| `-ADCredential`         | Yes      | Credential used to query Active Directory.                                                                                             |
| `-DistributionGroup`    | Yes      | Target Exchange distribution group identity, such as an email address.                                                                 |
| `-ADGroup`              | Yes      | One or more source AD group identities.                                                                                                |
| `-ClearExisting`        | No       | Removes all current target-group members before adding users from the source groups. Use with care.                                    |
| `-WhatIf` (alias `-wi`) | No       | Shows the requested Exchange add/remove operations without applying them. The script still connects to Exchange Online and queries AD. |

## Examples

Preview synchronization for several AD groups:

```powershell
$adCredential = Get-Credential
$o365Credential = Get-Credential

$params = @{
    ADCredential      = $adCredential
    O365Credential    = $o365Credential
    DistributionGroup = 'surveillance@onmicrosoft.com'
    ADGroup           = @('Site1-Surveillance-Record', 'Site2-Surveillance-Record')
    WhatIf            = $true
}

.\Update-SurveillanceGroup.ps1 @params
```

Apply the synchronization by omitting `WhatIf` or setting it to `$false`:

```powershell
$params.WhatIf = $false
.\Update-SurveillanceGroup.ps1 @params
```

To replace the target group's membership with the users found in the source groups, set `ClearExisting` to `$true`. Preview this operation with `WhatIf` first:

```powershell
$params.ClearExisting = $true
$params.WhatIf = $true
.\Update-SurveillanceGroup.ps1 @params
```

## Behavior and safety

- Without `-ClearExisting`, existing target members are retained and users already present are skipped.
- With `-ClearExisting`, every current target-group member is removed before source-group users are added. This can remove members who are not in the configured source groups.
- `-WhatIf` is passed to the Exchange add and remove commands. Review the output before running without it.
- Errors querying an individual AD group or adding an individual user are written to the console; the script continues processing other users/groups.
- The source group list must be supplied through `-ADGroup` (or a parameter hashtable such as `params.ps1`).

## Repository files

- `params.ps1` contains an example parameter hashtable for the surveillance groups.
- `jenkins.ps1` shows a Jenkins-style invocation with credentials provided by environment variables and `WhatIf` enabled for testing.
