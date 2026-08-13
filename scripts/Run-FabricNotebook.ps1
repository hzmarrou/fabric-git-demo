param(
  [Parameter(Mandatory = $true)]
  [string]$deploymentPipelineName,

  [Parameter(Mandatory = $true)]
  [string]$targetStageName,

  [Parameter(Mandatory = $true)]
  [string]$notebookName
)

$baseUrl = "https://api.fabric.microsoft.com/v1"
$token = $env:FABRIC_TOKEN

if ([string]::IsNullOrWhiteSpace($token)) {
  throw "FABRIC_TOKEN not provided"
}

$headers = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json"
}

# Find the Fabric deployment pipeline.
$pipelines = Invoke-RestMethod `
  -Headers $headers `
  -Uri "$baseUrl/deploymentPipelines" `
  -Method GET

$pipeline = $pipelines.value |
  Where-Object { $_.displayName -eq $deploymentPipelineName } |
  Select-Object -First 1

if (-not $pipeline) {
  throw "Deployment pipeline '$deploymentPipelineName' not found"
}

# Resolve the target stage and its assigned workspace.
$stages = Invoke-RestMethod `
  -Headers $headers `
  -Uri "$baseUrl/deploymentPipelines/$($pipeline.id)/stages" `
  -Method GET

$targetStage = $stages.value |
  Where-Object { $_.displayName -eq $targetStageName } |
  Select-Object -First 1

if (-not $targetStage) {
  throw "Stage '$targetStageName' not found"
}

$workspaceId = $targetStage.workspaceId

if ([string]::IsNullOrWhiteSpace($workspaceId)) {
  throw "Stage '$targetStageName' has no assigned workspace"
}

# Find the deployed notebook in the target workspace.
$items = Invoke-RestMethod `
  -Headers $headers `
  -Uri "$baseUrl/workspaces/$workspaceId/items?type=Notebook" `
  -Method GET

$notebook = $items.value |
  Where-Object { $_.displayName -eq $notebookName } |
  Select-Object -First 1

if (-not $notebook) {
  throw "Notebook '$notebookName' not found in workspace '$workspaceId'"
}

Write-Host "Starting notebook '$notebookName' in stage '$targetStageName'"

# Start the notebook's default job.
$runResponse = Invoke-WebRequest `
  -Headers $headers `
  -Uri "$baseUrl/workspaces/$workspaceId/items/$($notebook.id)/jobs/instances?jobType=RunNotebook" `
  -Method POST

$jobLocation = $runResponse.Headers["Location"]

if ($jobLocation -is [array]) {
  $jobLocation = $jobLocation[0]
}

if ([string]::IsNullOrWhiteSpace($jobLocation)) {
  throw "Fabric did not return a notebook job Location header"
}

$retryAfter = $runResponse.Headers["Retry-After"]

if ($retryAfter -is [array]) {
  $retryAfter = $retryAfter[0]
}

if (-not $retryAfter) {
  $retryAfter = 10
}

do {
  Start-Sleep -Seconds ([int]$retryAfter)
  $job = Invoke-RestMethod `
    -Headers $headers `
    -Uri $jobLocation `
    -Method GET

  Write-Host "Notebook status = $($job.status)"
}
while ($job.status -in @("NotStarted", "InProgress"))

if ($job.status -ne "Completed") {
  throw "Notebook job finished with status '$($job.status)'"
}

Write-Host "Notebook '$notebookName' completed successfully in '$targetStageName'"