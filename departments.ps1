# ####################################################
# HelloID-Conn-Prov-Source-AFAS-SDWorx-Departments
#
# Version: 2.0.0
# ####################################################

$c = $configuration | ConvertFrom-Json

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($c.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$clientId = $c.clientId
$clientSecret = $c.clientSecret
$baseUri = 'https://api.ctbps.nl'

Write-Information "Start department import: Base URL '$baseUri', Client ID: '$clientId'"

#region functions
function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }
        Write-Output $httpErrorObj
    }
}
#endregion functions

# Create Access Token
try {
    Write-Verbose "Creating access token"

    $pair = "${clientId}:${clientSecret}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $basicAuthValue = "Basic $base64"
    $headers = @{ "Authorization" = $basicAuthValue; }
    $body = @{ "scope" = "customer"; "grant_type" = "client_credentials"; }

    $splatGetAccessTokenParams = @{
        Uri         = "$($baseUri)/v3/OAuth/Token"
        Method      = 'POST'
        Headers     = $headers
        Body        = $body
        ContentType = "application/x-www-form-urlencoded"
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $accessTokenResult = Invoke-RestMethod @splatGetAccessTokenParams
    $accessToken = $accessTokenResult.access_token
    $headers = @{ "Authorization" = "Bearer $accessToken" }

    Write-Information "Successfully created access token. Token length: $($accessToken.length)"
}
catch {
    $ex = $PSItem
    if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObject = Resolve-HTTPError -Error $ex

        $verboseErrorMessage = $errorObject.ErrorMessage

        $auditErrorMessage = $errorObject.ErrorMessage
    }

    # If error message empty, fall back on $ex.Exception.Message
    if ([String]::IsNullOrEmpty($verboseErrorMessage)) {
        $verboseErrorMessage = $ex.Exception.Message
    }
    if ([String]::IsNullOrEmpty($auditErrorMessage)) {
        $auditErrorMessage = $ex.Exception.Message
    }

    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"        
    throw "Could not create access token. Error: $auditErrorMessage"
}

# Query Persons
try {
    Write-Verbose "Querying Persons"

    $persons = [System.Collections.ArrayList]::new()
    $splatGetPersonsParams = @{
        Uri         = "$($baseUri)/v3/odata/Person"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $persons = (Invoke-RestMethod @splatGetPersonsParams).Value

    # Sort on ID (to make sure the order is always the same)
    $persons = $persons | Sort-Object -Property ID

    # Group on ID (to match to department)
    $personsGrouped = $persons | Group-Object -Property ID -AsString -AsHashTable

    Write-Information "Successfully queried Persons. Result count: $($persons.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'persons' 
}
catch {
    $ex = $PSItem
    if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObject = Resolve-HTTPError -Error $ex

        $verboseErrorMessage = $errorObject.ErrorMessage

        $auditErrorMessage = $errorObject.ErrorMessage
    }

    # If error message empty, fall back on $ex.Exception.Message
    if ([String]::IsNullOrEmpty($verboseErrorMessage)) {
        $verboseErrorMessage = $ex.Exception.Message
    }
    if ([String]::IsNullOrEmpty($auditErrorMessage)) {
        $auditErrorMessage = $ex.Exception.Message
    }

    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"        
    throw "Could not query Persons. Error: $auditErrorMessage"
}

# Query Departments
try {
    Write-Verbose "Querying Departments"

    $departments = [System.Collections.ArrayList]::new()
    $splatGetDepartmentsParams = @{
        Uri         = "$($baseUri)/v3/odata/Department"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $departments = (Invoke-RestMethod @splatGetDepartmentsParams).Value

    # Sort on ID (to make sure the order is always the same)
    $departments = $departments | Sort-Object -Property ID

    Write-Information "Successfully queried Departments. Result count: $($departments.count)"
}
catch {
    $ex = $PSItem
    if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObject = Resolve-HTTPError -Error $ex

        $verboseErrorMessage = $errorObject.ErrorMessage

        $auditErrorMessage = $errorObject.ErrorMessage
    }

    # If error message empty, fall back on $ex.Exception.Message
    if ([String]::IsNullOrEmpty($verboseErrorMessage)) {
        $verboseErrorMessage = $ex.Exception.Message
    }
    if ([String]::IsNullOrEmpty($auditErrorMessage)) {
        $auditErrorMessage = $ex.Exception.Message
    }

    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"        
    throw "Could not query Departments. Error: $auditErrorMessage"
}

try {
    Write-Information 'Enhancing and exporting department objects to HelloID'

    # Set counter to keep track of actual exported department objects
    $exportedDepartments = 0

    $departments | ForEach-Object {
        $department = [PSCustomObject]@{
            ExternalId        = $_.DepartmentCode
            ShortName         = $_.ShortName
            DisplayName       = $_.Name
            ManagerExternalId = $null
            ParentExternalId  = $_.ParentDepartmentId
        }

        if ($null -ne $_.ManagerId) {
            $manager = $personsGrouped[$_.ManagerId]
            if ($null -ne $manager) {
                $department.ManagerExternalId = $manager.PersonNumber
            }
        }

        # Sanitize and export the json
        $department = $department | ConvertTo-Json -Depth 10
        $department = $department.Replace("._", "__")

        Write-Output $department

        # Update counter to keep track of actual exported department objects
        $exportedDepartments++
    }
    Write-Information "Succesfully enhanced and exported department objects to HelloID. Result count: $($exportedDepartments)"
    Write-Information "Department import completed"
}
catch {
    $ex = $PSItem
    if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObject = Resolve-HTTPError -Error $ex

        $verboseErrorMessage = $errorObject.ErrorMessage

        $auditErrorMessage = $errorObject.ErrorMessage
    }

    # If error message empty, fall back on $ex.Exception.Message
    if ([String]::IsNullOrEmpty($verboseErrorMessage)) {
        $verboseErrorMessage = $ex.Exception.Message
    }
    if ([String]::IsNullOrEmpty($auditErrorMessage)) {
        $auditErrorMessage = $ex.Exception.Message
    }

    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"   
    throw "Could not enhance and export department objects to HelloID. Error: $auditErrorMessage"
}