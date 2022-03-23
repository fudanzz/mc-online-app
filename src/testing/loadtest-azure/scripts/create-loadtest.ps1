param
(
  # Azure Load Test Resource Group
  #[string] $resourceGroupName,
  # Azure Load Test Resource Name
  [string] $loadTestName,
  # Load Test Id - auto-generated when empty
  [string] $loadTestId,
  # Load Test Displayname shown in Azure Portal
  [string] $loadTestDisplayName,
  # Load Test Description shown in Azure Portal
  [string] $loadTestDescription,
  [string] $engineSize,
  [int] $engineInstances = "0",
  [bool] $pipeline = $false 
)

# the testId is auto-generated (if not set)
if (!$loadTestId) {
  $loadTestId = (New-Guid).toString()
}

if (!$loadTestDisplayName) {
  $loadTestDisplayName = $loadTestName
}

function GetTestBody {
  param
  (
    [string] $loadTestDisplayName,
    [string] $loadTestDescription,
    [string] $engineSize,
    [int] $engineInstances
  )

  $result = @"
  {
      "displayName": "$loadTestDisplayName",
      "description": "$loadTestDescription",
      "loadTestConfig": {
          "engineSize": "$engineSize",
          "engineInstances": $engineInstances
      }
  }
"@

  return $result
}

. "$PSScriptRoot/common.ps1"

# Write test data to file as this avoids request too long as well as
# PS1+az cli quoting issues - see https://github.com/Azure/azure-cli/blob/dev/doc/quoting-issues-with-powershell.md#best-practice-use-file-input-for-json
$testDataFileName = $loadTestId + ".txt"
GetTestBody -loadTestDisplayName $loadTestDisplayName `
            -loadTestDescription $loadTestDescription `
            -engineSize $engineSize `
            -engineInstances $engineInstances

#$resourceScope = "/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.LoadTestService/loadtests/" + $loadTestName

$urlRoot = $apiEndpoint + "/loadtests/" + $loadTestId

# Create a new load test resource or update existing, if loadTestId already exists
az rest --url $urlRoot `
  --method PATCH `
  --skip-authorization-header `
  --headers ('@' + $accessTokenFileName) "Content-Type=application/merge-patch+json" `
  --url-parameters testId=$loadTestId api-version=$apiVersion `
  --body ('@' + $testDataFileName) `
  -o none $verbose #  --resource $resourceScope   --url-parameters resourceId=$resourceScope

# Outputs and exports for pipeline usage
if($pipeline) {
  echo "##vso[task.setvariable variable=loadTestId]$loadTestId" # contains the loadTestId for in-pipeline usage
}

# Delete the access token and test data files
Remove-Item $accessTokenFileName
Remove-Item $testDataFileName

return $loadTestId
