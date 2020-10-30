# Init auth
$clientId = "Y4s57bnxy2ZXFKl5F1eURfGAkBZxDJU1qWgE87WmxXJdb4dVpR"
$clientSecret = "ZmdJ3wkQ/+IhKwCT+HNOUnn8MBSQSobm8teYD/4vfUREIlSDAs3Jt67mj7O8S3kdxtNsg3+NC3oAaEbViM4ngrcjEBFp55UDZKXgYW0fBBcyjklELoe9m4PnOMwPrUAAj+7tDQ=="

# Init endpoints
$uriAuth = "https://api.ctbps.nl/v3/OAuth/Token"
$uriPerson = "https://api.ctbps.nl/v3/odata/Person"
$uriCurrentEmployment = "https://api.ctbps.nl/v3/odata/CurrentEmployment"
$uriEmploymentHistory = "https://api.ctbps.nl/v3/odata/EmploymentHistory"
$uriFunction = "https://api.ctbps.nl/v3/odata/Function"
$uriDepartment = "https://api.ctbps.nl/v3/odata/Department"
$uriOrganization = "https://api.ctbps.nl/v3/odata/Organization"
$uriAddresses = "https://api.ctbps.nl/v3/odata/Address"
$uriTelephone = "https://api.ctbps.nl/v3/odata/Phone"

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
    $data = Invoke-RestMethod -Method GET -Uri $uriPerson -Headers $headers
    $persons = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriAddresses -Headers $headers
    $addresses = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriCurrentEmployment -Headers $headers
    $currentEmployments = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriEmploymentHistory -Headers $headers
    $employmentHistory = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriFunction -Headers $headers
    $functions = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriDepartment -Headers $headers
    $departments = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriOrganization -Headers $headers
    $organizations = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriTelephone -Headers $headers
    $telphoneNumbers = $data.value
    
}
catch {
    Write-Verbose $_
    Write-Verbose "Failure in retrieving data from endpoints, aborting..." -Verbose
    exit
}

# Group data for processing
Write-Verbose "Grouping data..." -Verbose
$currentEmployments = $currentEmployments | Group-Object PersonId -AsHashTable
$employmentHistory = $employmentHistory | Group-Object PersonId -AsHashTable
$functions = $functions | Group-Object Code -AsHashTable
$departments = $departments | Group-Object ID -AsHashTable
$organizations = $organizations | Group-Object ID -AsHashTable
$addresses = $addresses | Group-Object PersonId -AsHashTable
$telphoneNumbers = $telphoneNumbers | Group-Object PersonId -AsHashTable

# Extend the persons with employments and required fields
Write-Verbose "Augmenting persons..." -Verbose
$persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "Addresses" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "MobileWork" -Value $null -Force

$persons | ForEach-Object {
    # Map required fields
    $_.ExternalId = $_.ID
    $_.DisplayName = "$($_.NameComplete) ($($_.PersonNumber))"

    # Add the contracts with full function name and clear salary values
    $personContracts = $currentEmployments[$_.ID]
    if ($null -ne $personContracts) {
        foreach($item in $personContracts){
                $item.SalaryTable = $null
                $item.VariantSalary = $null
                $fullFunction = $functions[$item.FunctionCode]
                If($null -ne $fullfunction){
                    $value = $fullfunction.LongName
                    $personContracts | Add-Member -MemberType NoteProperty -Name "FunctionLongName" -Value $value -Force
                }
                if($null -eq $fullfunction){
                    $personContracts | Add-Member -MemberType NoteProperty -Name "FunctionLongName" -Value $null -Force
                }
        }
        
        $_.Contracts = $personContracts
    }

    # Add the addresses
    $personAddresses = $addresses[$_.ID]
    if ($null -ne $personAddresses) {
        $personHomeAddress = $personAddresses | Where-Object isPostAddress -eq $true
            $_.Addresses = $personHomeAddress
    }

    # Add the Mobile number Work
    $persontelphoneNumbers = $telphoneNumbers[$_.ID]
    if ($null -ne $persontelphoneNumbers) {
        $personMobileWork = $persontelphoneNumbers | Where-Object PhoneType -eq "Mobiel Werk"
        $MobileWorkSet = $personMobileWork | Select-Object PhoneNumber -First 1
            $_.MobileWork = $MobileWorkSet.PhoneNumber
    }
}

# Make sure persons are unique
$persons = $persons | Sort-Object ExternalId -Unique

# Make sure the persons have contracts
$persons = $persons | Where-Object { $null -ne $_.Contracts }

# Make sure to output per person to allow for streaming
Write-Verbose "Uploading persons..." -Verbose
$persons | ForEach-Object {
    $jsonPerson = $_ | ConvertTo-Json -Depth 3 -Compress
    Write-Output $jsonPerson
    Start-Sleep -Milliseconds 50
}

Write-Verbose "Done." -Verbose