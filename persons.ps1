# Init auth
$clientId = "<YOUR CLIENTID"
$clientSecret = "YOUR CLIENTSECRET"

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
$uriGroups = "https://api.ctbps.nl/v3/odata/Group"
$uriGroupParticipant = "https://api.ctbps.nl/v3/odata/GroupParticipant"
$uriEmail = "https://api.ctbps.nl/v3/odata/Email"
$uriCostCenters = "https://api.ctbps.nl/v3/odata/CompanyCostCenters(companyid=guid'0f699459-0391-e511-80cf-44a8421bf766')"
$uriCostCenterAllocations = "https://api.ctbps.nl/v3/odata/CostCenterAllocation"
$uriSalaryEmployments = "https://api.ctbps.nl/v3/odata/SalaryEmployment"
$uriCostCenters = 'https://api.ctbps.nl/v3/odata/CompanyCostCenter?$filter=CompanyId%20eq%20(guid%2753edff19-0391-e511-80cf-44a8421bf766%27)'

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
    $currentAssignments = $data.value

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

    $data = Invoke-RestMethod -Method GET -Uri $uriGroups -Headers $headers
    $Groups = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriGroupParticipant -Headers $headers
    $GroupParticipants = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriEmail -Headers $headers
    $Emailaddresses = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriCostCenterAllocations -Headers $headers
    $CCAllocations = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriSalaryEmployments -Headers $headers
    $SalaryEmployments = $data.value

    $data = Invoke-RestMethod -Method GET -Uri $uriCostCenters -Headers $headers
    $CostCenters = $data.value
    
}
catch {
    Write-Verbose $_
    Write-Verbose "Failure in retrieving data from endpoints, aborting..." -Verbose
    exit
}

# Group data for processing
Write-Verbose "Grouping data..." -Verbose
$currentEmployments = $currentEmployments | Group-Object PersonId -AsHashTable
$currentAssignments = $currentAssignments | Group-Object PersonId -AsHashTable
$employmentHistory = $employmentHistory | Group-Object PersonId -AsHashTable
$functions = $functions | Group-Object Code -AsHashTable
$organizations = $organizations | Group-Object ID -AsHashTable
$addresses = $addresses | Group-Object PersonId -AsHashTable
$telphoneNumbers = $telphoneNumbers | Group-Object PersonId -AsHashTable
$Groups = $Groups | Group-Object ID -AsHashTable
$GroupParticipants = $GroupParticipants | Group-Object ParticipantId -AsHashTable
$Emailaddresses = $Emailaddresses | Group-Object PersonId -AsHashTable
$SalaryEmployments = $SalaryEmployments | Group-Object PersonId -AsHashTable
$CCAllocations = $CCAllocations | Group-Object SalaryEmploymentId -AsHashTable
$CostCenters = $CostCenters | Group-Object ID -AsHashTable

# Extend the persons with employments and required fields
Write-Verbose "Augmenting persons..." -Verbose
$persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "Addresses" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "PrivateEmailAddress" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "MobileWork" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "Groups" -Value $null -Force

$persons | ForEach-Object {
    # Map required fields
    $_.ExternalId = $_.ID
    $_.DisplayName = "$($_.NameComplete) ($($_.PersonNumber))"

    # Add the contracts with full function name and clear salary values
    $contracts = @();

    $personContracts = $currentEmployments[$_.ID]
    if ($null -ne $personContracts) {
        foreach($contractitem in $personContracts){
            $Contract = [PSCustomObject]@{
                ID = $contractitem.ID
                PersonId = $contractitem.PersonId
                OrganizationId = $contractitem.OrganizationId
                EpisodeStartDate = $contractitem.EpisodeStartDate
                EpisodeEndDate = $contractitem.EpisodeEndDate
                EmploymentId = $contractitem.EmploymentId
                EmploymentStatus = $contractitem.EmploymentStatus
                EmploymentStartDate = $contractitem.EmploymentStartDate
                AnniversaryEmploymentDate = $contractitem.AnniversaryEmploymentDate
                EmploymentStartReason = $contractitem.EmploymentStartReason
                EmploymentEndDate = $contractitem.EmploymentEndDate
                EmploymentEndReason = $contractitem.EmploymentEndReason
                ProbationDuration = $contractitem.ProbationDuration
                ProbationEndDate = $contractitem.ProbationEndDate
                ResignationPeriod = $contractitem.ResignationPeriod
                ResignationRequestDate = $contractitem.ResignationRequestDate
                ContractId = $contractitem.ContractId
                ContractStartDate = $contractitem.ContractStartDate
                ContractEndDate = $contractitem.ContractEndDate
                ContractType = $contractitem.ContractType
                ContractDuration = $contractitem.ContractDuration
                ContractIndex = $contractitem.ContractIndex
                ParttimePercentage = $contractitem.ParttimePercentage
                DaysPerWeek = $contractitem.DaysPerWeek
                IsMinMaxWorker = $contractitem.IsMinMaxWorker
                MinHoursPerWeek = $contractitem.MinHoursPerWeek
                MaxHoursPerWeek = $contractitem.MaxHoursPerWeek
                IsOnCallWorker = $contractitem.IsOnCallWorker
                PersonFunctionId = $contractitem.PersonFunctionId
                FunctionId = $contractitem.FunctionId
                FunctionStartDate = $contractitem.FunctionStartDate
                FunctionEndDate = $contractitem.FunctionEndDate
                FunctionStartReason = $contcontractitemract.FunctionStartReason
                FunctionCode = $contractitem.FunctionCode
                FunctionName = $contractitem.FunctionName
                RoomNumber = $contractitem.RoomNumber
                DepartmentId = $contractitem.DepartmentId
                DepartmentCode = $contractitem.DepartmentCode
                DepartmentName = $contractitem.DepartmentName
                DepartmentNameShort = $contractitem.DepartmentNameShort
                CostCenterId = $contractitem.CostCenterId
                CostCenterCode = $contractitem.CostCenterCode
                CostCenterName = $contractitem.CostCenterName
                PersonSalaryId = $contractitem.PersonSalaryId
                SalaryId = $contractitem.SalaryId
                SalaryStartDate = $contcontractitemract.SalaryStartDate
                SalaryEndDate = $contractitem.SalaryEndDate
                SalaryTable = $null
                SalaryReason = $contractitem.SalaryReason
                Scale = $contractitem.Scale
                Step = $contractitem.Step
                Period = $contractitem.Period
                VariantSalary = $null
                VariantHourlyWage = $contractitem.VariantHourlyWage
                NettoHourlyWage1 = $contractitem.NettoHourlyWage1
                NettoHourlyWage2 = $contractitem.NettoHourlyWage2
                ManagerName = $contractitem.ManagerName
                ManagerId = $contractitem.ManagerId
                SubstituteManagerName = $contractitem.SubstituteManagerName
                SubstituteManagerId = $contractitem.SubstituteManagerId
                TimeScheduleId = $contractitem.TimeScheduleId
                TimeScheduleStartDate = $contractitem.TimeScheduleStartDate
                TimeScheduleEndDate = $contractitem.TimeScheduleEndDate
                PersonStandardHoursPerWeek = $contractitem.PersonStandardHoursPerWeek
                ReasonContractChange = $contractitem.ReasonContractChange
                Payment = $contractitem.Payment
                EmployeeType = $contractitem.EmployeeType
                LocationName = $contractitem.LocationName
                LocationId = $contractitem.LocationId
                }

                $fullfunction = $functions[$contractitem.FunctionCode]
                If($null -ne $fullfunction){
                    $value = $fullfunction.LongName
                    $contractitem | Add-Member -MemberType NoteProperty -Name "FunctionLongName" -Value $value -Force
                }
                if($null -eq $fullfunction){
                    $contractitem | Add-Member -MemberType NoteProperty -Name "FunctionLongName" -Value $null -Force
                }
        }      
        $contracts += $Contract
    }

    $PersonSalaryEmployments = $SalaryEmployments[$_.ID]
    if ($null -ne $PersonSalaryEmployments){
        foreach($employment in $PersonSalaryEmployments){
            $salaryID = $employment.ID
            $assignedCC = $CCAllocations[$salaryID]
            if ($null -ne $assignedCC){
                foreach($cc in $assignedCC){
                    $tmp_assignedCC = $null
                    $tmp_costcenter = $null
                    $tmp_department = $null
                    $additionalDepID = $null
                    $additionalDepCode = $null
                    $additionalDepName = $null
                    $additionalDepNameShort = $null
                    if($null -ne $cc.CompanyCostCenterId){
                        $tmp_assignedCC = $cc.CompanyCostCenterId
                        $tmp_costcenter = $CostCenters[$tmp_assignedCC]
                        If($null -ne $tmp_costcenter){
                            $costingCode = $tmp_costcenter.CostingCode
                            $tmp_department = $departments | Where-Object DepartmentCode -eq $costingCode
                            $additionalDepID = $tmp_department.ID
                            $additionalDepCode = $tmp_department.DepartmentCode
                            $additionalDepName = $tmp_Department.Name
                            $additionalDepNameShort = $tmp_Department.ShortName
                            $personAssignments = $currentEmployments[$_.ID]
                            if ($null -ne $personAssignments) {
                                foreach($assignment in $personAssignments){
                                    If($additionalDepCode -ne $assignment.DepartmentCode){
                                        $assignment = [PSCustomObject]@{
                                            ID = $assignment.ID
                                            PersonId = $assignment.PersonId
                                            OrganizationId = $assignment.OrganizationId
                                            EpisodeStartDate = $assignment.EpisodeStartDate
                                            EpisodeEndDate = $assignment.EpisodeEndDate
                                            EmploymentId = $assignment.EmploymentId
                                            EmploymentStatus = $assignment.EmploymentStatus
                                            EmploymentStartDate = $assignment.EmploymentStartDate
                                            AnniversaryEmploymentDate = $assignment.AnniversaryEmploymentDate
                                            EmploymentStartReason = $assignment.EmploymentStartReason
                                            EmploymentEndDate = $assignment.EmploymentEndDate
                                            EmploymentEndReason = $assignment.EmploymentEndReason
                                            ProbationDuration = $assignment.ProbationDuration
                                            ProbationEndDate = $assignment.ProbationEndDate
                                            ResignationPeriod = $assignment.ResignationPeriod
                                            ResignationRequestDate = $assignment.ResignationRequestDate
                                            ContractId = $assignment.ContractId
                                            ContractStartDate = $assignment.ContractStartDate
                                            ContractEndDate = $assignment.ContractEndDate
                                            ContractType = $assignment.ContractType
                                            ContractDuration = $assignment.ContractDuration
                                            ContractIndex = $assignment.ContractIndex
                                            ParttimePercentage = $assignment.ParttimePercentage
                                            DaysPerWeek = $assignment.DaysPerWeek
                                            IsMinMaxWorker = $assignment.IsMinMaxWorker
                                            MinHoursPerWeek = $assignment.MinHoursPerWeek
                                            MaxHoursPerWeek = $assignment.MaxHoursPerWeek
                                            IsOnCallWorker = $assignment.IsOnCallWorker
                                            PersonFunctionId = $assignment.PersonFunctionId
                                            FunctionId = $assignment.FunctionId
                                            FunctionStartDate = $assignment.FunctionStartDate
                                            FunctionEndDate = $assignment.FunctionEndDate
                                            FunctionStartReason = $assignment.FunctionStartReason
                                            FunctionCode = $assignment.FunctionCode
                                            FunctionName = $assignment.FunctionName
                                            RoomNumber = $assignment.RoomNumber
                                            DepartmentId = $additionalDepID
                                            DepartmentCode = $additionalDepCode
                                            DepartmentName = $additionalDepName
                                            DepartmentNameShort = $additionalDepNameShort
                                            CostCenterId = $assignment.CostCenterId
                                            CostCenterCode = $assignment.CostCenterCode
                                            CostCenterName = $assignment.CostCenterName
                                            PersonSalaryId = $assignment.PersonSalaryId
                                            SalaryId = $assignment.SalaryId
                                            SalaryStartDate = $assignment.SalaryStartDate
                                            SalaryEndDate = $assignment.SalaryEndDate
                                            SalaryTable = $null
                                            SalaryReason = $assignment.SalaryReason
                                            Scale = $assignment.Scale
                                            Step = $assignment.Step
                                            Period = $assignment.Period
                                            VariantSalary = $null
                                            VariantHourlyWage = $assignment.VariantHourlyWage
                                            NettoHourlyWage1 = $assignment.NettoHourlyWage1
                                            NettoHourlyWage2 = $assignment.NettoHourlyWage2
                                            ManagerName = $assignment.ManagerName
                                            ManagerId = $assignment.ManagerId
                                            SubstituteManagerName = $assignment.SubstituteManagerName
                                            SubstituteManagerId = $assignment.SubstituteManagerId
                                            TimeScheduleId = $assignment.TimeScheduleId
                                            TimeScheduleStartDate = $assignment.TimeScheduleStartDate
                                            TimeScheduleEndDate = $assignment.TimeScheduleEndDate
                                            PersonStandardHoursPerWeek = $assignment.PersonStandardHoursPerWeek
                                            ReasonContractChange = $assignment.ReasonContractChange
                                            Payment = $assignment.Payment
                                            EmployeeType = $assignment.EmployeeType
                                            LocationName = $assignment.LocationName
                                            LocationId = $assignment.LocationId
                                            }
                                    
                                            $fullfunction = $functions[$assignment.FunctionCode]
                                            If($null -ne $fullfunction){
                                                $value = $fullfunction.LongName
                                                $assignment | Add-Member -MemberType NoteProperty -Name "FunctionLongName" -Value $value -Force
                                            }
                                            if($null -eq $fullfunction){
                                                $assignment | Add-Member -MemberType NoteProperty -Name "FunctionLongName" -Value $null -Force
                                            }
                                    }
                                }
                            }   
                                $contracts += $assignment
                            }
                        }
                    }
                }
            }
        }
    $_.Contracts = $contracts

    # Add the addresses
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

    # Add the Group Memberships
    $personGroups = @();
    $personGroupMemberships = $GroupParticipants[$_.ID]
    if ($null -ne $personGroupMemberships) {
        ForEach($groupItem in $personGroupMemberships){
            $groupItem | Add-Member -MemberType NoteProperty -Name "GroupName" -Value $null -Force
            $groupSelect = $groups[$groupItem.GroupId]
            $groupName = $groupSelect.Name
            $groupItem.GroupName = $groupName
            $personGroups += $groupItem
        }
    }
    $_.Groups = $personGroups

    # Add the private emailaddresses
    $personEmailAddress = $Emailaddresses[$_.ID]
    if ($null -ne $personEmailAddress) {
        ForEach($mail in $personEmailAddress){
            If($null -eq $mail.EmailType -And $mail.EmailAddress.length -gt 1){
                $emailAddressSelected = $mail.EmailAddress
                $_.PrivateEmailAddress = $emailAddressSelected
            }
        }
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