##################################################
# HelloID-Conn-Prov-Source-SDworx-Cobra-Department
#
# Version: 2.0.0
##################################################

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Initialize default value's
$config = $configuration | ConvertFrom-Json
$baseUrl = $config.BaseUrl
$clientId = $config.ClientId
$clientSecret = $config.Apikey

# Set debug logging
switch ($($config.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Resolve-SDworkx-CobraError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            $httpErrorObj.FriendlyMessage = "[$($errorDetailsObject.error)] [$($errorDetailsObject.error_description)]"
            if ($httpErrorObj.FriendlyMessage -eq '[] []') {
                $httpErrorObj.FriendlyMessage = $errorDetailsObject.'odata.error'.message.value
            }
        }
        catch {
            $httpErrorObj.FriendlyMessage = "[$($httpErrorObj.ErrorDetails)] [$($_.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    $actionMessage = "retrieving access token"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("${clientId}:${clientSecret}")
    $base64 = [System.Convert]::ToBase64String($bytes)
    $tokenHeaders = @{ Authorization = "Basic $base64" }
    $body = @{ "scope" = "customer"; "grant_type" = "client_credentials"; }
    $splatAccessTokenParams = @{
        Method      = 'POST'
        Uri         = "$baseUrl/OAuth/Token"
        Headers     = $tokenHeaders
        Body        = $body
        ContentType = 'application/x-www-form-urlencoded'
    }
    $tokenResponse = (Invoke-WebRequest @splatAccessTokenParams).content | ConvertFrom-Json
    $accessToken = $tokenResponse.access_token 
    $headers = @{
        Authorization = "Bearer $accessToken"
        Accept        = "application/json"
    }
    Write-Verbose "Access token retrieved successfully."

    $actionMessage = "retrieving persons"
    $splatPersonsParams = @{
        Method  = 'GET'
        Uri     = "$baseUrl/odata/Person"
        Headers = $headers
    }
    $persons = (Invoke-RestMethod @splatPersonsParams).value
    $personsGrouped = $persons | Group-Object -Property Id -AsHashTable
    Write-Information "Retrieved [$($persons.Count)] persons successfully."

    $actionMessage = "retrieving departments"
    $splatDepartmentsParams = @{
        Method  = 'GET'
        Uri     = "$baseUrl/odata/Department"
        Headers = $headers
    }
    $departments = (Invoke-RestMethod @splatDepartmentsParams).value
    $departmentsFiltered = $departments | Where-Object {$_.Active -eq '1'}
    Write-Information "Retrieved [$($departmentsFiltered.Count)] active departments successfully."

    $actionMessage = "enhancing and exporting department objects to HelloID"
    # Set counter to keep track of actual exported department objects
    $exportedDepartments = 0

    foreach ($department in $departmentsFiltered) {
        $managerId = $department.ManagerId
        if ($null -ne $managerId) {
            $manager = $personsGrouped[$managerId]
            if ($null -ne $manager) {
                $managerPersonNumber = $manager.PersonNumber
            }
            else {
                $managerPersonNumber = $null
            }
        }

        # Create department object to ensure only allowed properties are send to HelloID
        $departmentObject = [PSCustomObject]@{
            ExternalId        = $department.DepartmentCode
            DisplayName       = $department.Name
            ManagerExternalId = $managerPersonNumber
            ParentExternalId  = $department.ParentDepartmentId
        }

        # Sanitize and export the json
        Write-Output $departmentObject | ConvertTo-Json -Depth 10

        # Updated counter to keep track of actual exported department objects
        $exportedDepartments++
    }
    Write-Information "Successfully enhanced and exported department objects to HelloID. Result count: $($exportedDepartments)"
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-SDworkx-CobraError -ErrorObject $ex
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Error $($actionMessage). Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Error $($actionMessage). Error: $($ex.Exception.Message)"
    }
}