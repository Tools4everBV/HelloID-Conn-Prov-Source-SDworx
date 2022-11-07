# HelloID-Conn-Prov-Source-SDworx

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />

Cobra HRM by SDworx

# Connector information
This connector retrieves the data from Cobra HRM. The persons and contracts are all data forwarded. The other endpoints are used to enrich data. Please keep in mind that the setting of the endpoints can be managed by the application keyuser of Cobra. Some endpoints in this connector will not be usefull on specific client environements.

# Cobra API endpoint resources

# Personal data:

• API method Person.

We retrieve person information from the https://stagingapi.ctbps.nl/klantv3/Resources#Person endpoint.
                
# Employment data:

• API method CurrentEmployment.
• API method EmploymentHistory.
• API method Position.

We collect employment information from https://stagingapi.ctbps.nl/klantv3/Resources#CurrentEmployment, https://stagingapi.ctbps.nl/klantv3/Resources#EmploymentHistory, and https://stagingapi.ctbps.nl / customerv3 / Resources # Position endpoints.

# Organization:

• API method Organization.

We retrieve organization information from the https://stagingapi.ctbps.nl/klantv3/Resources#Organization endpoint.

# Department information:

• API method Department.

We retrieve department information from the https://stagingapi.ctbps.nl/klantv3/Resources#Department endpoint.

# Function data:

• API method Function.

We retrieve function information from the https://stagingapi.ctbps.nl/klantv3/Resources#Function endpoint.


# Additionally
We can also retrieve the contact details by consulting the Cobra API endpoints below.

# Email addresses:

• API method Email.

We retrieve email address information from the https://stagingapi.ctbps.nl/klantv3/Resources#Email endpoint.
                

# Phone numbers:

• API method Phone.

We retrieve telephone numbers from the https://stagingapi.ctbps.nl/klantv3/Resources#Phone endpoint.

# Address for persons (additional):

•	API method Address

We retrieve telephone numbers from the https://stagingapi.ctbps.nl/klantv3/Resources#Addresses endpoint.

# Groups (additional):

•	API method Group

We retrieve telephone numbers from the https://stagingapi.ctbps.nl/klantv3/Resources#Group endpoint.

# Group Participant (additional):

•	API method GroupParticipant

We retrieve telephone numbers from the https://stagingapi.ctbps.nl/klantv3/Resources#GroupParticipant endpoint.

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
