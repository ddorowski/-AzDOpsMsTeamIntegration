# Introduction 
The script checks if team members have changed the value of the field named RemainingWork since the last time the script was run. 
Then, send notifications on microsoft teams channel. Script uses a database to store informations about tasks.

# Getting Started
In folder called ScriptAzureCLI is located script named CheckRemainingWorkAzDevOpsScript. 
Some informations about script:

$organizationName - write in your organization name
$projectName = write in your project name

$MSTeamsWebhookUrl = write in your webhook url from miscrosoft teams

#SQL SERVER (SQL SERVER MANAGMENT STUDIO) 
$ServerName = write in your sql server name
$DatabaseName = write in your sql database name
$userName = write in your userName
$password = write in your password

$minAcceptableNumberOfHours = write in how much hours should employees worked.