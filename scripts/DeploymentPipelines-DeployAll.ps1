param(
  [string]$deploymentPipelineName,
  [string]$sourceStageName,
  [string]$targetStageName,
  [string]$deploymentNote
)

$baseUrl = "https://api.fabric.microsoft.com/v1"

$token = $env:FABRIC_TOKEN
if ([string]::IsNullOrEmpty($token)) {
  throw "FABRIC_TOKEN not provided"
}

$headers = @{
  "Content-Type"  = "application/json"
  "Authorization" = "Bearer $token"
}

# Find the pipeline
$pipelines = Invoke-RestMethod `
  -Headers $headers `
  -Uri "$baseUrl/deploymentPipelines" `
  -Method GET

$pipeline = $pipelines.value |
  Where-Object { $_.DisplayName -eq $deploymentPipelineName }

if (-not $pipeline) {
  throw "Pipeline '$deploymentPipelineName' not found"
}

# Resolve stages
$stages = Invoke-RestMethod `
  -Headers $headers `
  -Uri "$baseUrl/deploymentPipelines/$($pipeline.id)/stages" `
  -Method GET

$source = $stages.value |
  Where-Object { $_.DisplayName -eq $sourceStageName }

$target = $stages.value |
  Where-Object { $_.DisplayName -eq $targetStageName }

if (-not $source -or -not $target) {
  throw "Stage validation failed"
}

# Trigger deployment
$deployBody = @{
  sourceStageId = $source.id
  targetStageId = $target.id
  note          = $deploymentNote
}

$deployResp = Invoke-WebRequest `
  -Headers $headers `
  -Method POST `
  -Uri "$baseUrl/deploymentPipelines/$($pipeline.id)/deploy" `
  -Body ($deployBody | ConvertTo-Json -Depth 10)

$operationId = $deployResp.Headers["x-ms-operation-id"]
if (-not $operationId) {
  throw "Operation ID not returned"
}

$retryAfter = $deployResp.Headers["Retry-After"]
if ($retryAfter) {
  $retryAfter = [int]$retryAfter[0]
}
else {
  $retryAfter = 5
}

# Poll until complete
$operationUrl = "$baseUrl/operations/$operationId"

do {
  $state = Invoke-RestMethod `
    -Headers $headers `
    -Uri $operationUrl `
    -Method GET

  Write-Host "Deployment status = $($state.Status)"

  if ($state.Status -in @("NotStarted", "Running")) {
    Start-Sleep -Seconds $retryAfter
  }
}
while ($state.Status -in @("NotStarted", "Running"))

if ($state.Status -eq "Failed") {
  throw "Deployment failed: $($state.Error | ConvertTo-Json -Depth 10)"
}

Write-Host "Deployment completed successfully"