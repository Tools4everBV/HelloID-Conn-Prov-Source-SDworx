# HelloID-Conn-Prov-Source-SDworx

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<p align="center">
  <img src="https://user-images.githubusercontent.com/69046642/170068731-d6609cc7-2b27-416c-bbf4-df65e5063a36.png">
</p>

## Versioning
| Version | Description | Date |
| - | - | - |
| 2.0.0   | Updated performance and logging | 2022/11/07  |
| 1.0.0   | Initial release | 2020/10/30  |

## Table of contents
- [HelloID-Conn-Prov-Source-SDworx](#helloid-conn-prov-source-sdworx)
  - [Versioning](#versioning)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Endpoints implemented](#endpoints-implemented)
  - [Cobra API documentation](#cobra-api-documentation)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
    - [Mappings](#mappings)
    - [Scope](#scope)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)



## Introduction

This connector retrieves HR data from the Cobra HRM by SDworx API. Please be aware that there are several endpoints. This version only uses the endpoints we need for basic provisiioning. Please keep in mind that the setting of the endpoints can be managed by the application keyuser of Cobra. Some endpoints in this connector will not be usefull on specific client environements.

## Endpoints implemented

- /v3/odata/Person
- /v3/odata/CurrentEmployment
- /v3/odata/EmploymentHistory
- /v3/odata/SalaryEmployment
- /v3/odata/Function
- /v3/odata/Department
- /v3/odata/CompanyCostCenter
- /v3/odata/CostCenterAllocation
- /v3/odata/Address
- /v3/odata/Phone
- /v3/odata/Email

## Cobra API documentation
Please see the following website about the Cobra API documentation
- Available resources: https://api.ctbps.nl/v3/Resources

## Getting started
### Connection settings
The following settings are required to run the source import.

| Setting                                       | Description                                                               | Mandatory   |
| --------------------------------------------- | ------------------------------------------------------------------------- | ----------- |
| Client ID                                     | The Client ID to connect to the Cobra API.                             | Yes         |
| Client Secret                                 | The Client Secret to connect to the Cobra API.                         | Yes         |

### Prerequisites
- ClientID, ClientSecretto authenticate with Cobra-API Webservice

### Remarks
 - Currently, not all endpoints are implemented (we haven't had a use for them yet). For example: Position.

### Mappings
A basic mapping is provided. Make sure to further customize these accordingly.
Please choose the default mappingset to use with the configured configuration.

### Scope
The data collection retrieved by the queries is a default set which is sufficient for HelloID to provision persons.
The queries can be changed by the customer itself to meet their requirements.

## Getting help
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/