# HelloID-Conn-Prov-Source-SDworx

#### ⚠️ BREAKING CHANGE IN V2.0.0
> [!CAUTION]
> The `ExternalID` in `persons.ps1` is changed from `person.ID` to `person.PersonNumber`. This is a breaking change!
> The `ExternalID` used in the mapping now matches the `ExternalID` returned by the `persons.ps1` script. This ensures consistency between your mapping configuration and the data returned by the script.  

> [!IMPORTANT]  
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center"> 
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Source-SDworx/blob/main/Logo.png?raw=true">
</p>

## Introduction
HelloID-Conn-Prov-Source-SDworx is a source connector. SDworx cobra provides a set of REST API's that allow you to programmatically interact with its data.

## Getting Started
### Requirements
- HelloID Provisioning agent (cloud or on-prem).
- Connection settings
- Authorization on the required endpoints

> [!NOTE]  
> The required endpoints depend on the configuration and requirements.

### Connection settings

The following settings are required to connect to the API.

| Setting        | Description                                                                             | Mandatory |
| -------------- | --------------------------------------------------------------------------------------- | --------- |
| BaseUrl        | The URL to the SDworx cobra environment                                                 | Yes       |
| ClientID       | ClientID for authorization                                                              | Yes       |
| Apikey         | Apikey for authorization                                                                | Yes       |
| HistoricalDays | The number of days in the past from which the contracts will be imported (default 90)   | Yes       |
| FutureDays     | The number of days in the future from which the contracts will be imported (default 90) | Yes       |

## Remarks

- All persons are retrieved from SDworx Cobra. For this reason only persons with an contract are returned to HelloID.
- In `person.ps1`, phone numbers can be split by type. The default types currently used are **Work Phone** and **Mobile**.
- For email addresses, the email type (work / private) is not provided. Therefore, filtering is applied based on `index` **1** and **2**. As the index order is not consistent, it is possible that a private email address is mapped as a work email.
- Some endpoints are commented out in the `person.ps1` script. Adjust the script according to your requirements to enable or disable these endpoints.

## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint                    | Description                                                                  |
| --------------------------- | ---------------------------------------------------------------------------- |
| /OAuth/Token                | Retrieve OAuth access token                                                  |
| /odata/Person               | Retrieve personal details                                                    |
| /odata/CurrentEmployment    | Retrieve current employment information                                      |
| /odata/EmploymentHistory    | Retrieve employment history                                                  |
| /odata/Organization         | Retrieve organization information                                            |
| /odata/Phone                | Retrieve phone number information                                            |
| /odata/Email                | Retrieve email address information                                           |
| /odata/Department           | Retrieve department information                                              |
| /odata/Address              | Retrieve address information *(disabled in the script by default)*           |
| /odata/CostCenterAllocation | Retrieve cost center allocation *(disabled in the script by default)*        |
| /odata/Group                | Retrieve group information *(disabled in the script by default)*             |
| /odata/SalaryEmployment     | Retrieve salary employment information *(disabled in the script by default)* |
| /odata/GroupParticipant     | Retrieve group participant information *(disabled in the script by default)* |

### API documentation

[API documentation](https://apihrafdeling.cobra.sdworx.com/Resources)

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/