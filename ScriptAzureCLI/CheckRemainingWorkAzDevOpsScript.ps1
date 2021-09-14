#AZURE DEVOPS
$organizationName = "SynevoDevPl"
$projectName = "Intern projects"
az login --allow-no-subscriptions

#MICROSOFT TEAMS
$MSTeamsWebhookUrl = "https://medicover.webhook.office.com/webhookb2/a6514c74-3686-42f9-9586-ffb871f201cb@06acdef6-af30-4834-beac-4bab6f8f226f/IncomingWebhook/31e2cb9c07554c6cb3c73635da6c5b81/24c0f376-d221-46da-9cb8-d4b9ca26100d"

#SQL SERVER
$ServerName = "SYN228WAW69\SQLEXPRESS"
$DatabaseName = "EmployeesWorkInfo"
$userName = "DawidD"
$password = "dawid12345"

$connectionString = 'Data Source={0};database={1};User ID={2};Password={3};trusted_connection=true' -f $ServerName,$DatabaseName,$userName,$password
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$sqlConnection.Open()
if($sqlConnection.State -ne "Open")
{
    Write-Host "Connection with database failed!"
}
$deleteData = "DELETE FROM dbo.Info WHERE RemainingWork = 0"
Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query $deleteData

$minAcceptableNumberOfHours = 4

$userReminderGifs = @(
    "https://media.giphy.com/media/N5T214pFCntzoQciXh/giphy.gif",
    "https://media4.giphy.com/media/PjCXGdk2BcUVGJp8p5/giphy.gif",
    "https://media2.giphy.com/media/Z2ma2SQKva689hiqV7/giphy.gif",
    "https://media2.giphy.com/media/iIMc814xOnexcJf6DU/giphy.gif",
    "https://media3.giphy.com/media/Y5reUaW5MDbK8/giphy.gif",
    "https://media0.giphy.com/media/BmMU3LOfNMMeI/giphy.gif",
    "https://media4.giphy.com/media/xUOxf5Wo3ARawY0fBe/giphy.gif",
    "https://media1.giphy.com/media/8bjSeWd4JSMeQES46b/giphy.gif",
    "https://media1.giphy.com/media/BLJy2x6QwzgdrCfAlD/giphy.gif",
    "https://media3.giphy.com/media/T1WqKkLY753dZghbu6/giphy.gif"
)

$teamCelebrationGifs = @(
    "https://media3.giphy.com/media/YoibCgzdZEUOSWVwMl/giphy.gif",
    "https://media0.giphy.com/media/w1MpRl8T5GiZ7ItadE/giphy.gif",
    "https://media0.giphy.com/media/kigLtfDrV3K9N0wYCO/giphy.gif",
    "https://media3.giphy.com/media/Sseuxlv6zmhUXrrqrk/giphy.gif",
    "https://media2.giphy.com/media/WRXHb8GvNev1wU6u65/giphy.gif",
    "https://media0.giphy.com/media/XgN7BVqzswKxrLWNkj/giphy.gif",
    "https://media1.giphy.com/media/pII93gwUGJDGrPI8Yj/giphy.gif",
    "https://media1.giphy.com/media/9rlxoO1ETq0NPBziFm/giphy.gif"
)

$userTeams = [System.Collections.Hashtable]@{}
$users = [System.Collections.ArrayList]@()
$teamNames = [System.Collections.ArrayList]@()

$userNamesWithDescriptors = az devops user list --org https://dev.azure.com/$organizationName --query "members[].{Name:user.displayName ,Descriptor:user.descriptor}" --output json |
ConvertFrom-Json
$descriptors = $userNamesWithDescriptors.Descriptor
$teams = az devops team list --org https://dev.azure.com/$organizationName --project $projectName --output json |
ConvertFrom-Json 
$teamsId = $teams.id 
$count = $teamsId.Count

echo "numberOfTeams: $count"

foreach ($teamId in $teamsId)
{
    $teamInfo = az devops team show --org https://dev.azure.com/$organizationName --project $projectName --team $teamId --output json |
    ConvertFrom-Json
    $teamName = $teamInfo.name   
    $teamNames.Add($teamName) 
    
    echo "############################################################################"   
    echo "Team name: $teamName"

    $members = az devops security group membership list --org https://dev.azure.com/$organizationName --id $teamId --output json |
    ConvertFrom-Json
    $names = [System.Collections.ArrayList]@()
    foreach ($descriptor in $descriptors)
    {
        if (($members.$descriptor.displayName -ne $null) -and ($members.$descriptor.displayName -is [string]))
        {
            $names.Add($members.$descriptor.displayName)
        }
    }
    foreach ($name in $names)
    {
        echo "name: $name"
        $userWorkedHours = 0
        $userWorkItems = az boards query --output json --org https://dev.azure.com/$organizationName --wiql "select [id],[Work Item Type],[Title],[Microsoft.VSTS.Scheduling.RemainingWork] from workitems where [system.assignedto] = '$name'" |
        ConvertFrom-Json

        foreach ($userWorkItem in $userWorkItems)
        {
            $userTitle = $userWorkItem.fields.'System.Title'
            $userId = $userWorkItem.fields.'System.Id'
            $userType = $userWorkItem.fields.'System.WorkItemType'
            $userRemainingWork = $userWorkItem.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
            echo "`ntitle:                   $userTitle "
            $query = "SELECT TOP (1) *FROM dbo.Info WHERE Name = '$name' AND Title = '$userTitle' AND Id = $userId ORDER BY RemainingWork ASC"
            $result = Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query $query
            $remainingWorkDb = $result.RemainingWork
            echo "Remaining work database: $remainingWorkDb"
            echo "Remaining work azure:    $userRemainingWork"

            if ($result -eq $null -and $userRemainingWork -ne 0)
            {
                
                $insertData = "INSERT INTO [dbo].[Info] ([Name],[Title],[Id],[Type],[RemainingWork],[DateAdded])
                               VALUES ('$name', '$userTitle', $userId, '$userType', $userRemainingWork, GETDATE())"
                Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query $insertData
                echo "$inserData"
            }
            else
            {
                $workedHours = $remainingWorkDb - $userRemainingWork
                echo "Worked hours:            $workedHours"
                $userWorkedHours += $workedHours
                if ($workedHours -ne 0)
                {
                    $updateData = "UPDATE [dbo].[Info] SET RemainingWork = $userRemainingWork, DateAdded = GETDATE() WHERE Id = $userId"
                    Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query $updateData
                    echo "$updateData"
                }
            }
        }

        echo "`na summary of the hours worked: $userWorkedHours"
        echo "------------------------------------------------------"

        $user = $users | Where-Object {$_.name -match $name}    
        if ($user -eq $null)
        {
            $person = @{
                name = $name 
                userHoursSummary = $userWorkedHours
                teams = [System.Collections.ArrayList]@()
                workedWell = $true
            }
            $person.teams.Add($teamName)
            $users.Add($person)
            
        }
        else
        {
            $user.userHoursSummary += $userWorkedHours
            $user.teams.Add($teamName)
        }
    }
}

foreach ($user in $users) 
{
    if($user.userHoursSummary -lt $minAcceptableNumberOfHours)
    {
            $user.workedWell = $false
            $url = Get-Random -InputObject $userReminderGifs | ?{$_ -ne $prev}

            $JSONBody = [PSCustomObject][Ordered]@{
            "@type" = "MessageCard"
            "@context" = "<http://schema.org/extensions>"
            "themeColor" = '0078D7'
            "title" = "User reminder"
            "textFormat" = "markdown"
            "text" = "`n 
            Name: $($user.name)
            Worked $($user.userHoursSummary) hours 
            `n![]($($url)) 
            "
            }

            $TeamMessageBody = ConvertTo-Json $JSONBody

            $parameters = @{
            "URI" = $MSTeamsWebhookUrl
            "Method" = 'POST'
             "Body" = $TeamMessageBody
            "ContentType" = 'application/json'
            }
            Invoke-RestMethod @parameters
    }
}

foreach ($NameTeam in $teamNames)
{
    $url = Get-Random -InputObject $teamCelebrationGifs | ?{$_ -ne $prev}
    $counter = 0
    $customUsers = $users | Where-Object {$_.teams -match $NameTeam}    
    foreach ($user in $customUsers)
    {
        if($user.workedWell -eq $false)
        {
            $counter++
        }
    }
    if($counter -eq 0)
    {
        $JSONBody = [PSCustomObject][Ordered]@{
        "@type" = "MessageCard"
        "@context" = "<http://schema.org/extensions>"
        "themeColor" = '0078D7'
        "title" = "Team congrats"
        "text" = "`n 
        TeamName: $NameTeam
        The whole team worked well, good job!
        `n![]($($url))
        "
        }

        $TeamMessageBody = ConvertTo-Json $JSONBody

        $parameters = @{
        "URI" = $MSTeamsWebhookUrl
        "Method" = 'POST'
        "Body" = $TeamMessageBody
        "ContentType" = 'application/json'
        }

        Invoke-RestMethod @parameters
    }
}
echo "=================================================================="
echo "SUMMARY"
echo "=================================================================="
foreach ($user in $users)
{
    echo "Name: $($user.name)"
    echo "Teams:"
    $userTeams = $user.teams
    foreach ($team in $userTeams)
    {
        echo " - $team"
    } 
    echo "Worked hours: $($user.userHoursSummary)"
    echo "Worked well: $($user.workedWell)"
    echo "-----------------------------------------"
}

$sqlConnection.Close()






