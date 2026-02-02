##################################################
# HelloID-Conn-Prov-Source-SDworx-Cobra-Person
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
$contractRetentionPeriod = (Get-Date).AddDays(-[int]$($config.HistoricalDays))
$contractFuturePeriod = (Get-Date).AddDays([int]$($config.FutureDays))

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
    $persons = $persons | Where-Object { $_.TypePerson -eq 0 } # Exclude persons with status 4 (inflow workflow)
    $personsGrouped = $persons | Group-Object -Property Id -AsHashTable
    Write-Information "Retrieved [$($persons.Count)] persons successfully."

    $actionMessage = "retrieving current employments"
    $splatCurrentEmploymentsParams = @{
        Method  = 'GET'
        Uri     = "$baseUrl/odata/CurrentEmployment"
        Headers = $headers
    }
    $currentEmployments = (Invoke-RestMethod @splatCurrentEmploymentsParams).value
    $currentEmploymentsFiltered = $currentEmployments | Select-Object -Property * -ExcludeProperty SalaryId, SalaryStartDate, SalaryEndDate, SalaryTable, SalaryReason, Scale, Step, Period, VariantSalary, VariantHourlyWage, NettoHourlyWage1, NettoHourlyWage2
    $currentEmploymentsGrouped = $currentEmploymentsFiltered | Group-Object -Property PersonId -AsHashTable
    Write-Information "Retrieved [$($currentEmploymentsFiltered.Count)] current employments successfully."
    $currentEmployments = $null
    
    $actionMessage = "retrieving employment history"
    $episodeEndDateFilter = $contractRetentionPeriod.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $episodeStartDateFilter = $contractFuturePeriod.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $filter = "`$filter=(EpisodeEndDate eq null or EpisodeEndDate ge datetimeoffset'$episodeEndDateFilter') and (EpisodeStartDate eq null or EpisodeStartDate le datetimeoffset'$episodeStartDateFilter')"
    $splatEmploymentHistoryParams = @{
        Method  = 'GET'
        Uri     = "$baseUrl/odata/EmploymentHistory?$filter"
        Headers = $headers
    }
    $employmentHistory = (Invoke-RestMethod @splatEmploymentHistoryParams).value
    $employmentHistoryFiltered = $employmentHistory | Select-Object -Property * -ExcludeProperty SalaryId, SalaryStartDate, SalaryEndDate, SalaryTable, SalaryReason, Scale, Step, Period, VariantSalary, VariantHourlyWage, NettoHourlyWage1, NettoHourlyWage2
    $employmentHistoryGrouped = $employmentHistoryFiltered | Group-Object -Property PersonId -AsHashTable
    Write-Information "Retrieved [$($employmentHistoryFiltered.Count)] history employments successfully."
    $employmentHistory = $null

    $actionMessage = "retrieving functions"
    $splatFunctionsParams = @{
        Method  = 'GET'
        Uri     = "$baseUrl/odata/Function"
        Headers = $headers
    }
    $functions = (Invoke-RestMethod @splatFunctionsParams).value
    $functionsGrouped = $functions | Group-Object -Property Id -AsHashTable
    Write-Information "Retrieved [$($functions.Count)] functions successfully."
    $functions = $null

    $actionMessage = "retrieving organizations"
    $splatOrganizationsParams = @{
        Method  = 'GET'
        Uri     = "$baseUrl/odata/Organization"
        Headers = $headers
    }
    $organizations = (Invoke-RestMethod @splatOrganizationsParams).value
    $organizationsGrouped = $organizations | Group-Object -Property Id -AsHashTable
    Write-Information "Retrieved [$($organizations.Count)] organizations successfully."
    $organizations = $null

    $actionMessage = "retrieving phone numbers"
    $splatPhoneParams = @{
        Method  = 'GET'
        Uri     = "$baseUrl/odata/Phone"
        Headers = $headers
    }
    $phoneNumbers = (Invoke-RestMethod @splatPhoneParams).value
    $phoneNumbersFiltered = $phoneNumbers | Where-Object { $_.PhoneType -ne $null }
    $phoneNumbersGrouped = $phoneNumbersFiltered | Group-Object -Property PersonId -AsHashTable
    Write-Information "Retrieved [$($phoneNumbersFiltered.Count)] phone numbers successfully."
    $phoneNumbers = $null
    $phoneNumbersFiltered = $null

    $actionMessage = "retrieving email addresses"
    $splatEmailParams = @{
        Method  = 'GET'
        Uri     = "$baseUrl/odata/Email"
        Headers = $headers
    }
    $emailAddresses = (Invoke-RestMethod @splatEmailParams).value
    $emailAddressesFiltered = $emailAddresses | Where-Object { $_.EmailAddress -ne $null }
    $emailAddressesGrouped = $emailAddressesFiltered | Group-Object -Property PersonId -AsHashTable
    Write-Information "Retrieved [$($emailAddressesFiltered.Count)] email addresses successfully."
    $emailAddresses = $null
    $emailAddressesFiltered = $null

    ######################################################
    # Not used endpoints

    # $actionMessage = "retrieving addresses"
    # $splatAddressesParams = @{
    #     Method  = 'GET'
    #     Uri     = "$baseUrl/odata/Address"
    #     Headers = $headers
    # }
    # $addresses = (Invoke-RestMethod @splatAddressesParams).value
    # $addressesFiltered = $addresses | Where-Object { $_.isPostAddress -eq $true }
    # $addressesGrouped = $addressesFiltered | Group-Object -Property PersonId -AsHashTable
    # Write-Information "Retrieved [$($addressesFiltered.Count)] addresses successfully."
    # $addresses = $null
    # $addressesFiltered = $null

    # $actionMessage = "retrieving cost center allocations"
    # $splatCostCenterAllocationsParams = @{
    #     Method  = 'GET'
    #     Uri     = "$baseUrl/odata/CostCenterAllocation"
    #     Headers = $headers
    # }
    # $costCenterAllocations = (Invoke-RestMethod @splatCostCenterAllocationsParams).value
    # $costCenterAllocationsGrouped = $costCenterAllocations | Group-Object -Property SalaryEmploymentId -AsHashTable
    # Write-Information "Retrieved [$($costCenterAllocations.Count)] cost center allocations successfully."

    # $actionMessage = "retrieving cost center allocations"
    # $splatSalaryEmploymentParams = @{
    #     Method  = 'GET'
    #     Uri     = "$baseUrl/odata/SalaryEmployment"
    #     Headers = $headers
    # }
    # $salaryEmployments = (Invoke-RestMethod @splatSalaryEmploymentParams).value
    # $salaryEmploymentsFiltered = $salaryEmployments | Select-Object -Property ID, PersonId, StartDate, EndDate, HoursPerWeek, WorkPercentage
    # $salaryEmploymentsGrouped = $salaryEmploymentsFiltered | Group-Object -Property PersonId -AsHashTable
    # Write-Information "Retrieved [$($salaryEmploymentsFiltered.Count)] salary employments successfully."
    # $salaryEmployments = $null

    # $actionMessage = "retrieving departments"
    # $splatDepartmentsParams = @{
    #     Method  = 'GET'
    #     Uri     = "$baseUrl/odata/Department"
    #     Headers = $headers
    # }
    # $departments = (Invoke-RestMethod @splatDepartmentsParams).value
    # Write-Information "Retrieved [$($departments.Count)] departments successfully."

    # $actionMessage = "retrieving groups"
    # $splatGroupsParams = @{
    #     Method  = 'GET'
    #     Uri     = "$baseUrl/odata/Group"
    #     Headers = $headers
    # }
    # $groups = (Invoke-RestMethod @splatGroupsParams).value
    # $groupsGrouped = $groups | Group-Object -Property Id -AsHashTable
    # Write-Information "Retrieved [$($groups.Count)] groups successfully."

    # $actionMessage = "retrieving group participants"
    # $splatGroupParticipantsParams = @{
    #     Method  = 'GET'
    #     Uri     = "$baseUrl/odata/GroupParticipant"
    #     Headers = $headers
    # }
    # $groupParticipants = (Invoke-RestMethod @splatGroupParticipantsParams).value
    # $groupParticipantsGrouped = $groupParticipants | Group-Object -Property ParticipantId -AsHashTable
    # Write-Information "Retrieved [$($groupParticipants.Count)] group participants successfully."

    ######################################################

    $actionMessage = "enhancing and exporting person objects to HelloID"
    # Set counter to keep track of actual exported person objects
    $exportedPersons = 0
    # Enhance person model with required properties
    $persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "Addresses" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "PhoneNumberWork" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "PhoneNumberPrivate" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "EmailWork" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "EmailPrivate" -Value $null -Force

    foreach ($person in $persons) {        
        $person.ExternalID = $person.PersonNumber
        $person.DisplayName = "$($person.Nickname) $($person.Prefixes) $($person.LastName)".trim(' ') + " ($($person.PersonNumber))"

        # $personAddresses = $addressesGrouped[$person.Id]
        # if ($null -ne $personAddresses) {
        #     $person.Addresses = $personAddresses | Select-Object -First 1
        # }

        $phoneNumbers = $phoneNumbersGrouped[$person.Id]
        if ($null -ne $phoneNumbers) {
            $person.PhoneNumberWork = $phoneNumbers | Where-Object { $_.PhoneType -eq 'Werktelefoon' } | Select-Object -First 1 -ExpandProperty PhoneNumber
            $person.PhoneNumberPrivate = $phoneNumbers | Where-Object { $_.PhoneType -eq 'Mobiel' } | Select-Object -First 1 -ExpandProperty PhoneNumber
        }

        $personEmailAddresses = $emailAddressesGrouped[$person.Id]
        if ($null -ne $personEmailAddresses) {
            $person.EmailWork = $personEmailAddresses | Where-Object { $_.Index -eq 1 } | Select-Object -First 1 -ExpandProperty EmailAddress
            $person.EmailPrivate = $personEmailAddresses | Where-Object { $_.Index -eq 2 } | Select-Object -First 1 -ExpandProperty EmailAddress
        }

        $contractsList = [System.Collections.ArrayList]::new()
        $employments = $currentEmploymentsGrouped[$person.Id]
        if ($null -ne $employments) {
            $employments | Add-Member -MemberType NoteProperty -Name "EmploymentType" -Value 'Current' -Force
            $employments | Add-Member -MemberType NoteProperty -Name "OrganizationName" -Value $null -Force
            $employments | Add-Member -MemberType NoteProperty -Name "OrganizationNumber" -Value $null -Force
            $employments | Add-Member -MemberType NoteProperty -Name "FunctionLongName" -Value $null -Force
            $employments | Add-Member -MemberType NoteProperty -Name "ManagerPersonNumber" -Value $null -Force
            foreach ($employment in $employments) {
                $organizationId = $employment.OrganizationId
                if ($null -ne $organizationId) {
                    $organization = $organizationsGrouped[$organizationId]
                    if ($null -ne $organization) {
                        $employment.OrganizationName = $organization.Name
                        $employment.OrganizationNumber = $organization.OrganizationNumber
                    }
                }
                $functionId = $employment.FunctionId
                if ($null -ne $functionId) {
                    $function = $functionsGrouped[$functionId]
                    if ($null -ne $function) {
                        $employment.FunctionLongName = $function.LongName
                    }
                }
                $managerId = $employment.ManagerId
                if ($null -ne $managerId) {
                    $manager = $personsGrouped[$managerId]
                    if ($null -ne $manager) {
                        $employment.ManagerPersonNumber = $manager.PersonNumber
                    }
                }
                $employmentObject = [PSCustomObject]@{}
                $employment.psobject.properties | ForEach-Object {
                    $value = $_.Value
                    if ($_.Name -eq 'EpisodeStartDate' -or $_.Name -eq 'EpisodeEndDate') {
                        if (-not [string]::IsNullOrEmpty($value)) {
                            $value = ([DateTime]::Parse($value)).ToString('yyyy-MM-dd')
                            if ($value -eq '2100-01-01') { $value = $null }
                        }
                    }
                    $employmentObject | Add-Member -MemberType $_.MemberType -Name "$($_.Name)" -Value $value -Force
                }
                [Void]$contractsList.Add($employmentObject)
            }
        }

        $historyEmployments = $employmentHistoryGrouped[$person.Id]
        if ($null -ne $historyEmployments) {
            $historyEmployments | Add-Member -MemberType NoteProperty -Name "EmploymentType" -Value 'History' -Force
            $historyEmployments | Add-Member -MemberType NoteProperty -Name "OrganizationName" -Value $null -Force
            $historyEmployments | Add-Member -MemberType NoteProperty -Name "OrganizationNumber" -Value $null -Force
            $historyEmployments | Add-Member -MemberType NoteProperty -Name "FunctionLongName" -Value $null -Force
            $historyEmployments | Add-Member -MemberType NoteProperty -Name "ManagerPersonNumber" -Value $null -Force
            foreach ($historyEmployment in $historyEmployments) {
                # Only add history employment if not already present in current employments to avoid duplicate contracts
                if ($null -eq ($contractsList | Where-Object { $_.ContractId -eq $historyEmployment.ContractId })) { 
                    $organizationId = $historyEmployment.OrganizationId
                    if ($null -ne $organizationId) {
                        $organization = $organizationsGrouped[$organizationId]
                        if ($null -ne $organization) {
                            $historyEmployment.OrganizationName = $organization.Name
                            $historyEmployment.OrganizationNumber = $organization.OrganizationNumber
                        }
                    }
                    $functionId = $historyEmployment.FunctionId
                    if ($null -ne $functionId) {
                        $function = $functionsGrouped[$functionId]
                        if ($null -ne $function) {
                            $historyEmployment.FunctionLongName = $function.LongName
                        }
                    }
                    $managerId = $historyEmployment.ManagerId
                    if ($null -ne $managerId) {
                        $manager = $personsGrouped[$managerId]
                        if ($null -ne $manager) {
                            $historyEmployment.ManagerPersonNumber = $manager.PersonNumber
                        }
                    }
                    $historyEmploymentObject = [PSCustomObject]@{}
                    $historyEmployment.psobject.properties | ForEach-Object {
                        $value = $_.Value
                        if ($_.Name -eq 'EpisodeStartDate' -or $_.Name -eq 'EpisodeEndDate') {
                            if (-not [string]::IsNullOrEmpty($value)) {
                                $value = ([DateTime]::Parse($value)).ToString('yyyy-MM-dd')
                                if ($value -eq '2100-01-01') { $value = $null }
                            }
                        }
                        $historyEmploymentObject | Add-Member -MemberType $_.MemberType -Name "$($_.Name)" -Value $value -Force
                    }
                    [Void]$contractsList.Add($historyEmploymentObject)
                }
            }
        }
            
        if ($contractsList.Count -gt 0) {
            $person.Contracts = $contractsList
        }
        else {
            # All persons are retrieved for this reason person without a contract need to be excluded
            continue
        }

        Write-Output $person | ConvertTo-Json -Depth 10
        # Updated counter to keep track of actual exported person objects
        $exportedPersons++
    }
    Write-Information "Successfully enhanced and exported person objects to HelloID. Result count: $($exportedPersons)"
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