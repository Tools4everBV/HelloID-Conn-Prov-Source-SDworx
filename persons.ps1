# ####################################################
# HelloID-Conn-Prov-Source-AFAS-SDWorx-Persons
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
$currentDate = Get-Date
$futureThreshold = ($currentDate).AddDays(90) # threshold of future employments to include, e.g. active now or within 90 days (EpisodeStartDate)
$pastThreshold = ($currentDate).AddDays(-31) # threshold of past employments to include, e.g. active now or at most 180 days ago (filtered on EpisodeEndDate)    

Write-Information "Start person import: Base URL '$baseUri', Client ID: '$clientId'"

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

    Write-Information "Successfully queried Persons. Result count: $($persons.count)"
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

# Query Current Employments
try {
    Write-Verbose "Querying Current Employments"

    $currentEmployments = [System.Collections.ArrayList]::new()
    $splatGetCurrentEmploymentsParams = @{
        Uri         = "$($baseUri)/v3/odata/CurrentEmployment"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $currentEmployments = (Invoke-RestMethod @splatGetCurrentEmploymentsParams).Value

    # Sort on ID (to make sure the order is always the same)
    $currentEmployments = $currentEmployments | Sort-Object -Property ID

    # Group on PersonId (to match to person)
    $currentEmploymentsGrouped = $currentEmployments | Group-Object -Property PersonId -AsString -AsHashTable

    Write-Information "Successfully queried Current Employments. Result count: $($currentEmployments.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'currentEmployments' 
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
    throw "Could not query Current Employments. Error: $auditErrorMessage"
}

# Query Employment Histories
try {
    Write-Verbose "Querying Employment Histories"

    $employmentHistories = [System.Collections.ArrayList]::new()
    $splatGetEmploymentHistoriesParams = @{
        Uri         = "$($baseUri)/v3/odata/EmploymentHistory"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $employmentHistories = (Invoke-RestMethod @splatGetEmploymentHistoriesParams).Value

    # Sort on ID (to make sure the order is always the same)
    $employmentHistories = $employmentHistories | Sort-Object -Property ID

    # Filter for employments only within thresholds
    $employmentHistories = $employmentHistories | Where-Object {
        [DateTime]$_.EpisodeStartDate -le $futureThreshold -and ([String]::IsNullOrEmpty($_.EpisodeEndDate) -or [DateTime]$_.EpisodeEndDate -ge $pastThreshold)
    }

    # Group on PersonId (to match to person)
    $employmentHistoriesGrouped = $employmentHistories | Group-Object -Property PersonId -AsString -AsHashTable

    Write-Information "Successfully queried Employment Histories. Result count: $($employmentHistories.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'employmentHistories' 
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
    throw "Could not query Employment Histories. Error: $auditErrorMessage"
}

# Query Salary Employments
try {
    Write-Verbose "Querying Salary Employments"

    $salaryEmployments = [System.Collections.ArrayList]::new()
    $splatGetSalaryEmploymentsParams = @{
        Uri         = "$($baseUri)/v3/odata/SalaryEmployment"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $salaryEmployments = (Invoke-RestMethod @splatGetSalaryEmploymentsParams).Value

    # Sort on ID (to make sure the order is always the same)
    $salaryEmployments = $salaryEmployments | Sort-Object -Property ID

    # Group on PersonId (to match to person)
    $salaryEmploymentsGrouped = $salaryEmployments | Group-Object -Property PersonId -AsString -AsHashTable

    Write-Information "Successfully queried Salary Employments. Result count: $($salaryEmployments.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'salaryEmployments' 
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
    throw "Could not query Salary Employments. Error: $auditErrorMessage"
}

# Query Functions
try {
    Write-Verbose "Querying Functions"

    $functions = [System.Collections.ArrayList]::new()
    $splatGetFunctionsParams = @{
        Uri         = "$($baseUri)/v3/odata/Function"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $functions = (Invoke-RestMethod @splatGetFunctionsParams).Value

    # Sort on ID (to make sure the order is always the same)
    $functions = $functions | Sort-Object -Property ID

    # Group on Code (to match to employments and assignments)
    $functionsGrouped = $functions | Group-Object -Property Code -AsString -AsHashTable

    Write-Information "Successfully queried Functions. Result count: $($functions.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'functions' 
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
    throw "Could not query Functions. Error: $auditErrorMessage"
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

    # Group on Code (to match to employments and assignments)
    $departmentsGrouped = $departments | Group-Object -Property DepartmentCode -AsString -AsHashTable

    Write-Information "Successfully queried Departments. Result count: $($departments.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'departments' 
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

# Query Company CostCenters
try {
    Write-Verbose "Querying Company CostCenters"

    $companyCostCenters = [System.Collections.ArrayList]::new()
    $splatGetCompanyCostCentersParams = @{
        Uri         = "$($baseUri)/v3/odata/CompanyCostCenter?`$filter=CompanyId%20eq%20(guid%2753edff19-0391-e511-80cf-44a8421bf766%27)"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $companyCostCenters = (Invoke-RestMethod @splatGetCompanyCostCentersParams).Value

    # Sort on ID (to make sure the order is always the same)
    $companyCostCenters = $companyCostCenters | Sort-Object -Property ID

    # Group on ID (to match to salary)
    $companyCostCentersGrouped = $companyCostCenters | Group-Object -Property ID -AsString -AsHashTable

    Write-Information "Successfully queried Company CostCenters. Result count: $($companyCostCenters.count)"
    
    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'companyCostCenters' 
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
    throw "Could not query Company CostCenters. Error: $auditErrorMessage"
}

# Query CostCenter Allocations
try {
    Write-Verbose "Querying CostCenter Allocations"

    $costCenterAllocations = [System.Collections.ArrayList]::new()
    $splatGetCostCenterAllocationsParams = @{
        Uri         = "$($baseUri)/v3/odata/CostCenterAllocation"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $costCenterAllocations = (Invoke-RestMethod @splatGetCostCenterAllocationsParams).Value

    # Sort on ID (to make sure the order is always the same)
    $costCenterAllocations = $costCenterAllocations | Sort-Object -Property ID

    # Group on SalaryEmploymentId (to match to Salary Employment)
    $costCenterAllocationsGrouped = $costCenterAllocations | Group-Object -Property SalaryEmploymentId -AsString -AsHashTable

    Write-Information "Successfully queried CostCenter Allocations. Result count: $($costCenterAllocations.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'costCenterAllocations'     
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
    throw "Could not query CostCenter Allocations. Error: $auditErrorMessage"
}

# Query Addresses
try {
    Write-Verbose "Querying Addresses"

    $addresses = [System.Collections.ArrayList]::new()
    $splatGetAddressesParams = @{
        Uri         = "$($baseUri)/v3/odata/Address"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $addresses = (Invoke-RestMethod @splatGetAddressesParams).Value

    # Sort on ID (to make sure the order is always the same)
    $addresses = $addresses | Sort-Object -Property ID

    # Group on PersonId (to match to person)
    $addressesGrouped = $addresses | Group-Object -Property PersonId -AsString -AsHashTable

    Write-Information "Successfully queried Addresses. Result count: $($addresses.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'addresses'
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
    throw "Could not query Addresses. Error: $auditErrorMessage"
}

# Query Phones
try {
    Write-Verbose "Querying Phones"

    $phones = [System.Collections.ArrayList]::new()
    $splatGetPhonesParams = @{
        Uri         = "$($baseUri)/v3/odata/Phone"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $phones = (Invoke-RestMethod @splatGetPhonesParams).Value

    # Sort on ID (to make sure the order is always the same)
    $phones = $phones | Sort-Object -Property ID

    # Group on PersonId (to match to person)
    $phonesGrouped = $phones | Group-Object -Property PersonId -AsString -AsHashTable

    Write-Information "Successfully queried Phones. Result count: $($phones.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'phones'
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
    throw "Could not query Phones. Error: $auditErrorMessage"
}

# Query Emails
try {
    Write-Verbose "Querying Emails"

    $emails = [System.Collections.ArrayList]::new()
    $splatGetEmailsParams = @{
        Uri         = "$($baseUri)/v3/odata/Email"
        Method      = 'GET'
        Headers     = $headers
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $emails = (Invoke-RestMethod @splatGetEmailsParams).Value

    # Sort on ID (to make sure the order is always the same)
    $emails = $emails | Sort-Object -Property ID

    # Group on PersonId (to match to person)
    $emailsGrouped = $emails | Group-Object -Property PersonId -AsString -AsHashTable

    Write-Information "Successfully queried Emails. Result count: $($emails.count)"

    # Clear variable to keep memory usage as low as possible
    Remove-Variable 'emails'
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
    throw "Could not query Emails. Error: $auditErrorMessage"
}

# $persons = $persons | Where-Object { $_.ID -eq "c0bac6f7-c0ec-4672-9566-6cae200c671c" }
try {
    Write-Verbose 'Enhancing and exporting person objects to HelloID'

    # Set counter to keep track of actual exported person objects
    $exportedPersons = 0

    # Enhance person model with required properties
    $persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force

    # Enhance person model with additional properties
    $persons | Add-Member -MemberType NoteProperty -Name "Addresses" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "MobileWork" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "BusinessEmailAddress" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "PrivateEmailAddress" -Value $null -Force

    $persons | ForEach-Object {
        # Set required fields for HelloID
        $_.ExternalId = $_.ID

        # Include ExternalId in DisplayName of HelloID Raw Data
        $_.DisplayName = $_.NameComplete + " ($($_.PersonNumber))" 

        # Enhance person with Address for for extra information, such as: city
        $personAddress = $addressesGrouped[$_.ID]
        if ($null -ne $personAddress) {
            $homeAddress = $personAddress | Where-Object isPostAddress -eq $true 
            # In the case multiple home addresses are found with the same ID, we always select the first one in the array
            if ($null -ne $homeAddress) {
                $_.Addresses = $homeAddress | Sort-Object | Select-Object -First 1
            }
        }

        # Enhance person with Phones for for extra information, such as: city
        $personPhones = $phonesGrouped[$_.ID]
        if ($null -ne $personPhones) {
            $businessMobilePhone = $personPhones | Where-Object PhoneType -eq "Mobiel Werk"
            # In the case multiple phones are found with the same ID, we always select the first one in the array
            if ($null -ne $businessMobilePhone) {
                $_.MobileWork = $businessMobilePhone.PhoneNumber | Sort-Object | Select-Object -First 1
            }
        }

        # Enhance person with Emails for for extra information
        $personEmails = $emailsGrouped[$_.ID]
        if ($null -ne $personEmails) {
            $personEmails = $personEmails | Sort-Object -Property EmailAddress
            foreach ($personEmail in $personEmails) {
                if ($null -ne $personEmail.EmailAddress) {
                    if ($personEmail.EmailAddress.length -gt 1 -and $personEmail.EmailAddress.endswith("@timon.nl")) {
                        # In the case multiple emails are found with the same ID, we always select the first one in the array
                        $_.BusinessEmailAddress = $personEmail.EmailAddress | Select-Object -First 1
                    }
                    else {
                        # In the case multiple emails are found with the same ID, we always select the first one in the array
                        $_.PrivateEmailAddress = $personEmail.EmailAddress | Select-Object -First 1
                    }
                }
            }
        }

        $contractsList = [System.Collections.ArrayList]::new()

        # Get employments for person
        $personEmployments = $employmentHistoriesGrouped[$_.ID]
        # $counter = 1
        if ($null -ne $personEmployments) {
            # Sort on ID (to make sure the order is always the same)
            $personEmployments = $personEmployments | Sort-Object -Property ID
            $personEmployments | ForEach-Object {
                # Enhance employment with Function for extra information, such as: fullName
                $employmentFunction = $null
                if (-not([string]::IsNullOrEmpty($_.FunctionCode))) {
                    $employmentFunction = $functionsGrouped[$_.FunctionCode]
                    if ($null -ne $employmentFunction) {
                        # In the case multiple jobProfiles are found with the same ID, we always select the first one in the array
                        $_ | Add-Member -MemberType NoteProperty -Name "Function" -Value $employmentFunction[0] -Force

                        # Remove unneccesary fields from  object (to avoid unneccesary large objects and confusion when mapping)
                        # Remove FunctionId, FunctionCode, FunctionName ,since the data is transformed into seperate object
                        $_.PSObject.Properties.Remove('FunctionId')
                        $_.PSObject.Properties.Remove('FunctionCode')
                        $_.PSObject.Properties.Remove('FunctionName')
                    }
                }

                # Enhance employment with Department for extra information, such as: fullName
                $employmentDepartment = $null
                if (-not([string]::IsNullOrEmpty($_.DepartmentCode))) {
                    $employmentDepartment = $departmentsGrouped[$_.DepartmentCode]
                    if ($null -ne $employmentDepartment) {
                        # In the case multiple jobProfiles are found with the same ID, we always select the first one in the array
                        $_ | Add-Member -MemberType NoteProperty -Name "Department" -Value $employmentDepartment[0] -Force

                        # Remove unneccesary fields from  object (to avoid unneccesary large objects and confusion when mapping)
                        # Remove DepartmentId, DepartmentCode, DepartmentName, DepartmentNameShort ,since the data is transformed into seperate object
                        $_.PSObject.Properties.Remove('DepartmentId')
                        $_.PSObject.Properties.Remove('DepartmentCode')
                        $_.PSObject.Properties.Remove('DepartmentName')
                        $_.PSObject.Properties.Remove('DepartmentNameShort')
                    }
                }

                # Create custom contract object
                $employmentObject = [PSCustomObject]@{}

                $_.psobject.properties | ForEach-Object {
                    $employmentObject | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value -Force
                }

                # Set to PrimaryContract to 1 to inidicate this is a primary contract
                $employmentObject | Add-Member -MemberType NoteProperty -Name "PrimaryContract" -Value 1 -Force

                [Void]$contractsList.Add($employmentObject)
            }

            # Include Salary Employments to include extra departments as active contracts
            $personSalaryEmployments = $salaryEmploymentsGrouped[$_.ID]
            if ($null -ne $personSalaryEmployments) {
                $personSalaryEmployments | ForEach-Object {
                    # Get Cost center for salary to define extra department
                    $salaryCostCenters = $costCenterAllocationsGrouped[$_.ID]
                    foreach ($salaryCostCenter in $salaryCostCenters) {
                        if ($null -ne $salaryCostCenter) {
                            if (-not([string]::IsNullOrEmpty($salaryCostCenter.CompanyCostCenterId))) {
                                $salaryCompanyCostCenter = $companyCostCentersGrouped[$salaryCostCenter.CompanyCostCenterId]
                                if ($null -ne $salaryCompanyCostCenter) {
                                    $salaryEmployments = $currentEmploymentsGrouped[$_.PersonId]
                                    if ($null -ne $salaryEmployments) {
                                        foreach ($salaryEmployment in $salaryEmployments) {
                                            # Only add if the department actually differs from current employment
                                            if ($salaryCompanyCostCenter.CostingCode -ne $salaryEmployment.DepartmentCode) {
                                                # Enhance salary employment with Function for extra information, such as: fullName
                                                $salaryFunction = $null
                                                if (-not([string]::IsNullOrEmpty($salaryEmployment.FunctionCode))) {
                                                    $salaryFunction = $functionsGrouped[$salaryEmployment.FunctionCode]
                                                    if ($null -ne $salaryFunction) {
                                                        # In the case multiple jobProfiles are found with the same ID, we always select the first one in the array
                                                        $salaryEmployment | Add-Member -MemberType NoteProperty -Name "Function" -Value $salaryFunction[0] -Force

                                                        # Remove unneccesary fields from  object (to avoid unneccesary large objects and confusion when mapping)
                                                        # Remove FunctionId, FunctionCode, FunctionName ,since the data is transformed into seperate object
                                                        $salaryEmployment.PSObject.Properties.Remove('FunctionId')
                                                        $salaryEmployment.PSObject.Properties.Remove('FunctionCode')
                                                        $salaryEmployment.PSObject.Properties.Remove('FunctionName')
                                                    }
                                                }

                                                # Enhance salary employment with Department for extra information, such as: fullName
                                                $salaryDepartment = $null
                                                if (-not([string]::IsNullOrEmpty($salaryCompanyCostCenter.CostingCode))) {
                                                    $salaryDepartment = $departmentsGrouped[$salaryCompanyCostCenter.CostingCode]
                                                    if ($null -ne $salaryDepartment) {
                                                        # In the case multiple jobProfiles are found with the same ID, we always select the first one in the array
                                                        $salaryEmployment | Add-Member -MemberType NoteProperty -Name "Department" -Value $salaryDepartment[0] -Force

                                                        # Remove unneccesary fields from  object (to avoid unneccesary large objects and confusion when mapping)
                                                        # Remove DepartmentId, DepartmentCode, DepartmentName, DepartmentNameShort ,since the data is transformed into seperate object
                                                        $salaryEmployment.PSObject.Properties.Remove('DepartmentId')
                                                        $salaryEmployment.PSObject.Properties.Remove('DepartmentCode')
                                                        $salaryEmployment.PSObject.Properties.Remove('DepartmentName')
                                                        $salaryEmployment.PSObject.Properties.Remove('DepartmentNameShort')
                                                    }
                                                }

                                                # Create custom contract object
                                                $salaryEmploymentObject = [PSCustomObject]@{}

                                                $salaryEmployment.psobject.properties | ForEach-Object {
                                                    $salaryEmploymentObject | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value -Force
                                                }

                                                # Set ID to custom value
                                                $salaryEmploymentObject.ID = $salaryEmployment.ContractId + '-' + $salaryCompanyCostCenter.CostingCode

                                                # Set to PrimaryContract to 0 to inidicate this is an additional contract
                                                $salaryEmploymentObject | Add-Member -MemberType NoteProperty -Name "PrimaryContract" -Value 0 -Force

                                                [Void]$contractsList.Add($salaryEmploymentObject)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        else {
            # Write-Warning "No employments found for person: $($_.DisplayName)"  
        }

        # Add Contracts to person
        if ($null -ne $contractsList) {
            ## This example can be used by the consultant if you want to filter out persons with an empty array as contract
            ## *** Please consult with the Tools4ever consultant before enabling this code. ***
            if ($contractsList.Count -eq 0) {
                # Write-Warning "Excluding person from export: $($_.DisplayName). Reason: Contracts is an empty array"
                return
            }
            else {
                $_.Contracts = $contractsList
            }
        }
        ## This example can be used by the consultant if the date filters on the person/employment/positions do not line up and persons without a contract are added to HelloID
        ## *** Please consult with the Tools4ever consultant before enabling this code. ***    
        # else {
        #     Write-Warning "Excluding person from export: $($_.DisplayName). Reason: Person has no contract data"
        #     return
        # }

        # Sanitize and export the json
        $person = $_ | ConvertTo-Json -Depth 10
        $person = $person.Replace("._", "__")

        Write-Output $person

        # Updated counter to keep track of actual exported person objects
        $exportedPersons++
    }
    Write-Information "Succesfully enhanced and exported person objects to HelloID. Result count: $($exportedPersons)"
    Write-Information "Person import completed"
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
    throw "Could not enhance and export person objects to HelloID. Error: $auditErrorMessage"
}