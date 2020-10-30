# Init auth
$clientId = "Y4s57bnxy2ZXFKl5F1eURfGAkBZxDJU1qWgE87WmxXJdb4dVpR"
$clientSecret = "ZmdJ3wkQ/+IhKwCT+HNOUnn8MBSQSobm8teYD/4vfUREIlSDAs3Jt67mj7O8S3kdxtNsg3+NC3oAaEbViM4ngrcjEBFp55UDZKXgYW0fBBcyjklELoe9m4PnOMwPrUAAj+7tDQ=="

# Init endpoints
$uriAuth = "https://api.ctbps.nl/v3/OAuth/Token"
$uriDepartment = "https://api.ctbps.nl/v3/odata/Department"

# Enable TLS 1.2
if ([Net.ServicePointManager]::SecurityProtocol -notmatch "Tls12") {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

Write-Verbose "Starting..." -Verbose

$pair = "${clientId}:${clientSecret}"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"
$headers = @{ "Authorization" = $basicAuthValue; }
$body = @{ "scope" = "customer"; "grant_type" = "client_credentials"; }

Write-Verbose "Authenticating..." -Verbose

$result = Invoke-WebRequest -Method POST -Uri $uriAuth -Headers $headers -Body $body -ContentType "application/x-www-form-urlencoded"
$content = $result.Content | ConvertFrom-Json
$accessToken = $content.access_token
$headers = @{ "Authorization" = "Bearer $accessToken" }

Write-Verbose "Retrieving data from endpoints..." -Verbose

try {
    $data = Invoke-RestMethod -Method GET -Uri $uriDepartment -Headers $headers
    $departments = $data.value
}
catch {
    Write-Verbose $_
    Write-Verbose "Failure in retrieving data from endpoints, aborting..." -Verbose
    exit
}

# Extend the persons with employments and required fields
Write-Verbose "Augmenting departments..." -Verbose
$departments | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
$departments | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
$departments | Add-Member -MemberType NoteProperty -Name "Name" -Value $null -Force
$departments | Add-Member -MemberType NoteProperty -Name "ManagerExternalId" -Value $null -Force
$departments | Add-Member -MemberType NoteProperty -Name "ParentExternalId" -Value $null -Force
$departments | ForEach-Object {
    $_.ExternalId = $_.DepartmentCode
    $_.DisplayName = $_.ShortName
    $_.Name = $_.ShortName
    $_.ManagerExternalId = $_.ManagerId
    $_.ParentExternalId = $_.ParentDepartmentId
}

# Export the json
Write-Verbose "Uploading departments..." -Verbose
$json = $departments | ConvertTo-Json -Depth 3
Write-Output $json