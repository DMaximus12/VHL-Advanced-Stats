# OK so I want to lookup the last game I have in my spreadsheet, then I want to see if there's a newer game posted on the website.
# If there's a newer game, run this script to get the latest game and add it to the spreadsheet.
# of course this should be run recursively until there are no new games (seems like the whole thing should be part of a function call, then run the function in the try part
# or exit if the catch is thrown

$StatusCode = 0
$GameNumber = 0
$statsFilePath = "C:\Temp\"
$statsFileName = "S38AdvanceMetrics.csv"
$statsFile = $statsFilePath + $statsFileName

if (!(Test-Path -Path $statsFile))
{ New-Item -path $statsFilePath -name $statsFileName -type "file"}
 


while ($StatusCode -ne 404)
{

$AMResults = get-content $statsFile -tail 1
$lastGameNumberArray = $AMResults -split ','
$lastGameNumber = $lastGameNumberArray[2] -replace '"', ""
$GameNumber = [int]$lastGameNumber + 1


$baseurl = "https://vhlportal.com/VHL/38/VHL38-$GameNumber.html"



[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try
{
    $gamepage = Invoke-WebRequest $baseurl -ErrorAction Stop
    # This will only execute if the Invoke-WebRequest is successful.
    $StatusCode = $gamepage.StatusCode
}
catch
{
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Output "Failed web request with $StatusCode on URL $baseurl"
    if ($StatusCode -eq 404)
    {exit}
}



#Put webapge in a txt file so we can manipluate it easier
$thetext = $gamepage.Content
$thetext > "C:\Temp\VHLGame.txt"

#look through content and grab the full period summaries (will start with normal, powerplay, or penalty kill)
#The entire full period summary is on one line. We need to split it to single lines to read better
#Split on . to create a new line for each event, save that to another temp file.

$lfpbp = $null
$gamefromtext = gc C:\Temp\VHLGame.txt
foreach ($line in $gamefromtext)
{
if ($line.StartsWith("Normal Lineup")){
    $lfpbp += $line.Split('.')
    }
elseif ($line.StartsWith("PowerPlay Lineup"))
{$lfpbp += $line.Split('.')}
elseif ($line.StartsWith("Penalty Kill Lineup"))
{$lfpbp += $line.Split('.')}
elseif ($line.StartsWith("Penalty Kill 3vs5 Lineup"))
{$lfpbp += $line.Split('.')}
elseif ($line.StartsWith("4 vs 4 Lineup"))
{$lfpbp += $line.Split('.')}
elseif ($line.StartsWith("3 vs 3 Lineup"))
{$lfpbp += $line.Split('.')}

}

$lfpbp > "C:\Temp\VHLGamewLines.txt"


$FailedPassCount = 0
$ReceivedPasscount = 0
$INTPassCount = 0
$LoosePuckPickupCount = 0
$staArray = @()
$passersplitarray = $null
$passername =$null
$passHash=@{}

$gamepbp = gc "C:\Temp\VHLGamewLines.txt"

function Add-AdvanceStats([PSCustomObject]$currentobject){

$currentplayer = $currentobject.PlayerName 
$MadePassCount = 0
$MadeShotCount = 0
$MissedShotCount = 0
$BlockedShotCount = 0
$ShotHitPost = 0
$ShotDeflect = 0
$FailedPassCount = 0
$hitAndLost = 0
$GACount = 0
$straightLost = 0
$totalGA = 0
$TACount = 0 
$totalTA = 0 
$INTPassCount = 0
$HitsCauseLoosePuck = 0 
#$FailedPassCount = ($gamepbp | Select-String "Pass by $currentplayer intercepted").count
$INTPassCount = ($gamepbp | Select-String "intercepted by $currentplayer").count
$LoosePuckPickupCount = ((($gamepbp | Select-String "Puck Retrieved by $currentplayer").count) + (($gamepbp | Select-String "Puck retreived by $currentplayer").count)) 
$ReceivedPassCount = ($gamepbp | Select-String "Pass to $currentplayer").count
#$HitsCauseLoosePuck = ($gamepbp | Select-String "hit by $currentplayer and loses puck").count
$dumpIn = ($gamepbp | Select-String "\s+Puck is dumped.*by $currentplayer").count
$icings = ($gamepbp | Select-String "Icing by $currentplayer").count
#$hitAndLost = ($gamepbp | Select-String "\s+$currentplayer is hit by.*and loses puck").count
#$straightLost = ($gamepbp | Select-String "$currentplayer loses puck").count
#$ShotDeflect = ($gamepbp | Select-String "Deflect By $currentplayer").count


# parsing through pass and shot data
# need to elimiate lines where player is mentioned but they didn't make a pass or take a shot
# like losing a faceoff: Thomas Kennedy wins face-off versus Markus Lulic Descheneaux in Las Vegas Aces zone
# hitting a player but they don't lose the puck: Aleksander Rodriguez is hit by Mitch Matthews
# that players pass gets intercepted: Pass by Codrick Past intercepted by Rocky LaGarza in neutral zone


$allActions = $gamepbp | Select-String "$currentplayer" -context 0,2
foreach ($action in $allActions){
    # player's name mentioned when they lose a faceoff
    if ($action -like "*versus $currentplayer*")
    {}
    # player's name mentioned when the receive a hit
    elseif ($action -like "*is hit by $currentplayer*")
    {}
    # player's name mentioned when they make a pass that is intercepted
    elseif ($action -like "*Pass by $currentplayer* intercepted*")
    {$FailedPassCount++}
    # player takes a shot - need to figure out what happens next for stat tracking
    elseif ($action -like "*Shot by $currentplayer*")
    {
        # have to handle the possible case where the time marker is the next line after the shot.
        if ($action.context.postcontext[0] -like '*<br /><br /><b>Time :*')
        {
            if ($action.Context.PostContext[1] -like "*Shot Misses the Net*")
            {$MissedShotCount++}
            elseif ($action.Context.PostContext[1] -like "*Shot Hit the Post*")
            {$ShotHitPost++}
            elseif ($action.Context.PostContext[1] -like "*Shot Blocked By*")
            {$BlockedShotCount++}
            elseif ($action.Context.PostContext[1] -like "*Deflect By*")
            {$MadePassCount++}
            else
            {$MadeShotCount++}
        }
        elseif ($action.Context.PostContext[0] -like "*Shot Misses the Net*")
        {$MissedShotCount++}
        elseif ($action.Context.PostContext[0] -like "*Shot Hit the Post*")
        {$ShotHitPost++ }
        elseif ($action.Context.PostContext[0] -like "*Shot Blocked By*")
        {$BlockedShotCount++}
        elseif ($action.Context.PostContext[0] -like "*Deflect By*")
        {$MadePassCount++}
        else
        {$MadeShotCount++}
    }
        # player mentioned when they deflect a shot
    elseif ($action -like "*Deflect by $currentplayer*")
    {
        $ShotDeflect++

        if ($action.Context.PostContext[0] -like "*Shot Misses the Net*")
        {$MissedShotCount++}
        elseif ($action.Context.PostContext[0] -like "*Shot Hit the Post*")
        {$ShotHitPost++}
        elseif ($action.Context.PostContext[0] -like "*Shot Blocked By*")
        {$BlockedShotCount++}
        elseif ($action.Context.PostContext[0] -like "*Deflect By*")
        {$MadePassCount++}
        else
        {$MadeShotCount++}
    }
    else
    {   # at this point we've already prossesed all mentions of a player that do not involve them having possession of the puck.
        # so now we look at the line after a player is mentioned, if that line is Pass to... that means the player mentioned made a successful pass
        # we're also handling the special case where the next line is a time marker, we then look at the 2nd line to see if the pass was successful or not
        if ($action.context.postcontext[0] -like "*Pass to*")
        {$MadePassCount++}
        elseif ($action.context.postcontext[0] -like '*<br /><br /><b>Time :*')
        {
            if ($action.context.postcontext[1] -like "*Pass to*")
            {$MadePassCount++}
        }
    } #end if/else statment for counting passes and shots (and passes intercepted and deflections


<#   To figure out giveaways/takeaways/turnovers, we need to do addtional processing of lines after the event to figure out what team the person that recovers the puck is on
    Giveaway - when a player directly loses the puck to the other team
    Pass Intercepted - already capturing this ($FailedPassCount)
    Hit + lose puck + loose puck pick up by other team
    lose puck + loose puck pick up by other team

    Takeaway - When a player's direct action result in them getting possession of the puck
    Intercept Pass ($INTPassCount)
    Hit player + pickup loose puck.

    Turnover - Anytime a player touches the puck and it ends up in possession of the other team.
    All Giveaways +
    missed shots that are recovered by opposing team +
    Dumpins that are recovered by opposing teams

#>
    # Giveaways
    # counting situation where player is hit and loses puck, then determining if it was a giveaway based on which team gets the loose puck
    if ($action -match "\s+$currentplayer is hit by.*and loses puck")
    {
        $hitAndLost++
        if ($action.context.postcontext[0] -like '*<br /><br /><b>Time :*')
        {
            if ($action.context.postcontext[1] -like "*Free Puck Retrieved by*")
            {
                $hitsplit = $action.context.postcontext[1] -split "for "
                if ($hitsplit[1].trim() -eq $currentobject.TeamName)
                {}
                else 
                { $GACount++}  
            }
            
        
        }
        elseif ($action.context.postcontext[0] -like "*Free Puck Retrieved by*")
        {
            $hitsplit = $action.context.postcontext[0] -split "for "
            if ($hitsplit[1].trim() -eq $currentobject.TeamName)
            {}
            else 
            { $GACount++}
        }
    }

    # counting situation where player loses puck unprovoked
    if ($action -like "*$currentplayer loses puck*")
    {
        $straightLost++

        if ($action.context.postcontext[0] -like '*<br /><br /><b>Time :*')
        {
            if ($action.context.postcontext[1] -like "*Free Puck Retrieved by*")
            {
                $hitsplit = $action.context.postcontext[1] -split "for "
                if ($hitsplit[1].trim() -eq $currentobject.TeamName)
                {}
                else 
                { $GACount++}  
            }
            
        
        }
        elseif ($action.context.postcontext[0] -like "*Free Puck Retrieved by*")
        {
            $hitsplit = $action.context.postcontext[0] -split "for "
            if ($hitsplit[1].trim() -eq $currentobject.TeamName)
            {}
            else 
            { $GACount++}
        }
    }

    # Takeaways
    # counting situation where player hits opponent and retrieves puck
    if ($action -like "*hit by $currentplayer and loses puck*")
    {
        $HitsCauseLoosePuck++
        if ($action.context.postcontext[0] -like '*<br /><br /><b>Time :*')
        {
            if ($action.context.postcontext[1] -like "*Free Puck Retrieved by $currentplayer*")
                {$TACount++}
        }
        if ($action.context.postcontext[0] -like "*Free Puck Retrieved by $currentplayer*")
            {$TACount++}
    }

}

$totalPasses = ($MadePassCount + $FailedPassCount)
if ($totalPasses -eq 0)
{ $PassPct = 0}
else{$PassPct = [math]::Round((($MadePassCount / $totalPasses) * 100),0)}

$totalShots = ($MadeShotCount + $MissedShotCount + $BlockedShotCount + $ShotHitPost)
if ($totalShots -eq 0)
{ $shotPct = 0}
else{$ShotPct = [math]::Round((($MadeShotCount / $totalShots) * 100),0)}

$totalGA = ($GACount + $FailedPassCount)
$totalTA = ($TACount + $INTPassCount)

# GA% total the number of touches the of the puck the player had and calculate what percentage of those were giveaways
if ($totalGA -eq 0)
{$GAPct = 0}
else {$GAPct = [math]::Round((([int]$totalGA / ([int]$LoosePuckPickupCount + [int]$ReceivedPassCount + [int]$INTPassCount)) * 100),0)}


    #PlayerName = $currentplayer
    add-member -inputobject $currentobject -notepropertyname HitLP  -notepropertyvalue $HitsCauseLoosePuck
    add-member -inputobject $currentobject -notepropertyname PassINT  -notepropertyvalue $INTPassCount
    add-member -inputobject $currentobject -notepropertyname LPPickup  -notepropertyvalue $LoosePuckPickupCount 
    add-member -inputobject $currentobject -notepropertyname RPass  -notepropertyvalue $ReceivedPassCount
    add-member -inputobject $currentobject -notepropertyname DumpIns  -notepropertyvalue $dumpIn
    add-member -inputobject $currentobject -notepropertyname Icings  -notepropertyvalue $icings
    add-member -inputobject $currentobject -notepropertyname LPfromHit  -notepropertyvalue $hitAndLost
    add-member -inputobject $currentobject -notepropertyname LostPuck  -notepropertyvalue $straightLost
#    add-member -inputobject $currentobject -notepropertyname MadePasses  -notepropertyvalue $MadePassCount
#    add-member -inputobject $currentobject -notepropertyname FailedPasses  -notepropertyvalue $FailedPassCount
    add-member -inputobject $currentobject -notepropertyname Passes  -notepropertyvalue ([string]$MadePassCount + '/' + [string]$totalPasses)
    add-member -inputobject $currentobject -notepropertyname PassPct  -notepropertyvalue ([string]$PassPct + '%')
    add-member -inputobject $currentobject -notepropertyname SDelfect  -notepropertyvalue $ShotDeflect
    add-member -inputobject $currentobject -notepropertyname SMiss  -notepropertyvalue $MissedShotCount
    add-member -inputobject $currentobject -notepropertyname SBlock  -notepropertyvalue $BlockedShotCount
    add-member -inputobject $currentobject -notepropertyname SHitPost  -notepropertyvalue $ShotHitPost
    add-member -inputobject $currentobject -notepropertyname Shots  -notepropertyvalue ([string]$MadeShotCount + '/' + [string]$totalShots)
    add-member -inputobject $currentobject -notepropertyname SOGPct  -notepropertyvalue ([string]$ShotPct + '%')
    $currentobject.GA = $totalGA
    $currentobject.TA = $totalTA
    add-member -inputobject $currentobject -notepropertyname GA/TA  -notepropertyvalue ([int]$totalTA - [int]$totalGA)
    add-member -inputobject $currentobject -notepropertyname GA%  -notepropertyvalue ([string]$GAPct + '%')

return $currentobject 
} #end function Add-AdvanceStats

#Grab Rosters to use player names for later
$rawteamname = $gamepage.AllElements | where {$_.TagName -eq "title"} 
$tempteamname = $rawteamname.innerText -split "- "
$tnseparated = $tempteamname[2] -split "vs"
$VisitorTeamName = $tnseparated[0].trim()
$HomeTeamName = $tnseparated[1].trim()
$rosters = $gamepage.AllElements | Where Class -eq "STHSGame_PlayerStatTable" | Select -ExpandProperty innerText

$srosters = $rosters -split "------------------------------------------------------------------------------------"
$rawAwayTeam = $srosters[1]
$rawHomeTeam = $srosters[3]

$parseAwayTeam = $rawAwayTeam -split ([Environment]::NewLine)

$names = @()
$statArray = @()
$VisitorstatArray = @()
$HomestatArray = @()
foreach ($line in $parseAwayTeam)
{
if ([string]::IsNullOrWhiteSpace($line))
{}
else{
 $playerStats = $line -split ' {1}(?=\d|\-\d)'
 $names += $playerStats[0].trim()
 $teamname = $VisitorTeamName
 $goals = $playerStats[1]
 $assists = $playerStats[2]
 $points = $playerStats[3]
 $plusminus = $playerStats[4]
 $PIM = $playerStats[5]
 $shots = $playerStats[6]
 $hits = $playerStats[7]
 $shotblock = $playerStats[8]
 $giveaways = $playerStats[9]
 $takeaways = $playerStats[10]
 $faceoffs = $playerStats[11]
 $MinutesPlayed = $playerStats[12]
 $PPMinutes = $playerStats[13]
 $PKMinutes = $playerStats[14]

 $statObject = [PSCustomObject]@{
 PlayerName = $playerStats[0].trim()
 TeamName = $teamname
 G = $goals
 A = $assists
 P = $points
 "+/-" = $plusminus
 PIM = $PIM
 S = $shots
 H = $hits
 SB = $shotblock
 GA = $giveaways
 TA = $takeaways
 FO = $faceoffs
 MP = $MinutesPlayed
 "PP MP" = $PPMinutes
 "PK MP" = $PKMinutes

}
$VisitorstatArray += Add-AdvanceStats($statObject)
}}

$parseHomeTeam = $rawHomeTeam -split ([Environment]::NewLine)
foreach ($line in $parseHomeTeam)
{
if ([string]::IsNullOrWhiteSpace($line))
{}
else{
 $playerStats = $line -split ' {1}(?=\d|\-\d)'
 $names += $playerStats[0].trim()
 $teamname = $HomeTeamName
 $goals = $playerStats[1]
 $assists = $playerStats[2]
 $points = $playerStats[3]
 $plusminus = $playerStats[4]
 $PIM = $playerStats[5]
 $shots = $playerStats[6]
 $hits = $playerStats[7]
 $shotblock = $playerStats[8]
 $giveaways = $playerStats[9]
 $takeaways = $playerStats[10]
 $faceoffs = $playerStats[11]
 $MinutesPlayed = $playerStats[12].Trim()
 $PPMinutes = $playerStats[13].Trim()
 $PKMinutes = $playerStats[14].Trim()

 $statObject = [PSCustomObject]@{
 PlayerName = $playerStats[0].trim()
 TeamName = $teamname
 G = $goals
 A = $assists
 P = $points
 "+/-" = $plusminus
 PIM = $PIM
 S = $shots
 H = $hits
 SB = $shotblock
 GA = $giveaways
 TA = $takeaways
 FO = $faceoffs
 MP = $MinutesPlayed
 "PP MP" = $PPMinutes
 "PK MP" = $PKMinutes
}
$HomestatArray += Add-AdvanceStats($statObject)
}}

#build out visiting team totals
$vteamgoals = 0
$vteamassists = 0
$vteampoints = 0
$vteamplusminus = 0
$vteamPIM = 0 
$vteamshots = 0
$vteamshits = 0
$vteamSB = 0
$vteamGA = 0
$vteamTA = 0
$vteamHitLP = 0
$vteamPassINT = 0
$vteamLPPickup = 0
$vteamRPass = 0
$vteamDumpIns = 0
$vteamIcings = 0
$vteamLPfromHit = 0
$vteamLostPuck = 0
$vteamSDeflect = 0
$vteamSMiss = 0
$vteamSBlock = 0
$vteamSHitPost = 0
$vteamPassesMade = 0
$vteamPassesAttempted = 0
$vteamShotsMade = 0 
$vteamShotsAttempted = 0 
$vteamFOWon = 0
$vteamFOTotal = 0
$vteamGATATotal = 0


Foreach ($objStat in $VisitorstatArray)
{

        [int]$vteamgoals += [int]$objStat.G
        [int]$vteamassists += [int]$objStat.A
        [int]$vteampoints += [int]$objStat.P
        [int]$vteamplusminus += [int]$objStat.'+/-'
        [int]$vteamPIM += [int]$objStat.PIM
        [int]$vteamshots += [int]$objStat.S
        [int]$vteamshits += [int]$objStat.H
        [int]$vteamSB += [int]$objStat.SB
        [int]$vteamGA += [int]$objStat.GA
        [int]$vteamTA += [int]$objStat.TA
        $vteamfosplit = $objStat.FO.split("/")
        [int]$vteamFOWon += [int]$vteamfosplit[0]
        [int]$vteamFOTotal += [int]$vteamfosplit[1]
        #probably don't need to total minutes played for the team
        [int]$vteamHitLP += [int]$objStat.HitLP
        [int]$vteamPassINT += [int]$objStat.PassINT
        [int]$vteamLPPickup += [int]$objStat.LPPickup
        [int]$vteamRPass += [int]$objStat.RPass
        [int]$vteamDumpIns += [int]$objStat.DumpIns
        [int]$vteamIcings += [int]$objStat.Icings
        [int]$vteamLPfromHit += [int]$objStat.LPfromHit
        [int]$vteamLostPuck += [int]$objStat.LostPuck
        $vteampassessplit = $objStat.Passes.split("/")
        [int]$vteamPassesMade += [int]$vteampassessplit[0]
        [int]$vteamPassesAttempted += [int]$vteampassessplit[1]
        [int]$vteamSDeflect += [int]$objStat.SDeflect
        [int]$vteamSMiss += [int]$objStat.SMiss
        [int]$vteamSBlock += [int]$objStat.SBlock
        [int]$vteamSHitPost += [int]$objStat.SHitPost
        $vteamshotsplit = $objStat.SHots.split("/")
        [int]$vteamShotsMade += [int]$vteamshotsplit[0]
        [int]$vteamShotsAttempted += [int]$vteamshotsplit[1]
        [int]$vteamGATATotal += [int]$objStat."GA/TA"

        
}
if ($vteamPassesAttempted -eq 0)
{ $vteamnPassPct = 0}
else{$vteamnPassPct = [math]::Round((($vteamPassesMade / $vteamPassesAttempted) * 100),0)}

if ($vteamShotsAttempted -eq 0)
{ $vteamshotPct = 0}
else{$vteamShotPct = [math]::Round((($vteamShotsMade / $vteamShotsAttempted) * 100),0)}

if ($vteamGA -eq 0)
{ $vteamGAPct = 0}
else{ $vteamGAPct = [math]::Round((($vteamGA / ($vteamLPPickup + $vteamRPass + $vteamPassINT)) * 100),0)}

$vteamtotals = [PSCustomObject]@{
 PlayerName = "Team Totals"
 TeamName = $VisitorTeamName
 G = $vteamgoals
 A = $vteamassists
 P = $vteampoints
 "+/-" = $vteamplusminus
 PIM = $vteamPIM
 S = $vteamshots
 H = $vteamshits
 SB = $vteamSB
 GA = $vteamGA
 TA = $vteamTA
 FO = ([string]$vteamFOWon + '/' + [string]$vteamFOTotal)
 MP = "N/A"
 "PP MP" = "N/A"
 "PK MP" = "N/A"
 HitLP  = $vteamHitLP
 PassINT = $vteamPassINT
 LPPickup = $vteamLPPickup
 RPass = $vteamRPass
 DumpIns = $vteamDumpIns
 Icings = $vteamIcings
 LPfromHit = $vteamLPfromHit
 LostPuck = $vteamLostPuck
 Passes = ([string]$vteamPassesMade + '/' + [string]$vteamPassesAttempted)
 PassPct = ([string]$vteamnPassPct + '%')
 SDelfect = $vteamSDeflect
 SMiss = $vteamSMiss
 SBlock = $vteamSBlock
 SHitPost = $vteamSHitPost
 Shots = ([string]$vteamShotsMade + '/' + [string]$vteamShotsAttempted)
 SOGPct = ([string]$vteamShotPct + '%')
 "GA/TA" = $vteamGATATotal
 "GA%" = ([string] $vteamGAPct + '%')
 }



$VisitorstatArray += $vteamtotals

#$VisitorstatArray |ft PlayerName,TeamName,G,A,P,"+/-",PIM,S,H,SB,GA,TA,"GA/TA","GA%",FO,MP,"PP MP","PK MP",HitLP,PassINT,LPPickup,RPass,DumpIns,Icings,LPfromHit,LostPuck,Passes,PassPct,SDelfect,SMiss,SBlock,SHitPost,Shots,SOGPct -autosize


#build out home team totals
$hteamgoals = 0
$hteamassists = 0
$hteampoints = 0
$hteamplusminus = 0
$hteamPIM = 0 
$hteamshots = 0
$hteamshits = 0
$hteamSB = 0
$hteamGA = 0
$hteamTA = 0
$hteamHitLP = 0
$hteamPassINT = 0
$hteamLPPickup = 0
$hteamRPass = 0
$hteamDumpIns = 0
$hteamIcings = 0
$hteamLPfromHit = 0
$hteamLostPuck = 0
$hteamSDeflect = 0
$hteamSMiss = 0
$hteamSBlock = 0
$hteamSHitPost = 0
$hteamPassesMade = 0
$hteamPassesAttempted = 0
$hteamShotsMade = 0 
$hteamShotsAttempted = 0
$hteamFOWon = 0
$hteamFOTotal = 0 
$hteamGATATotal = 0

Foreach ($objStat in $HomestatArray)
{

        [int]$hteamgoals += [int]$objStat.G
        [int]$hteamassists += [int]$objStat.A
        [int]$hteampoints += [int]$objStat.P
        [int]$hteamplusminus += [int]$objStat.'+/-'
        [int]$hteamPIM += [int]$objStat.PIM
        [int]$hteamshots += [int]$objStat.S
        [int]$hteamshits += [int]$objStat.H
        [int]$hteamSB += [int]$objStat.SB
        [int]$hteamGA += [int]$objStat.GA
        [int]$hteamTA += [int]$objStat.TA
        $hteamfosplit = $objStat.FO.split("/")
        [int]$hteamFOWon += [int]$hteamfosplit[0]
        [int]$hteamFOTotal += [int]$hteamfosplit[1]
        #probably don't need to total minutes played for the team
        [int]$hteamHitLP += [int]$objStat.HitLP
        [int]$hteamPassINT += [int]$objStat.PassINT
        [int]$hteamLPPickup += [int]$objStat.LPPickup
        [int]$hteamRPass += [int]$objStat.RPass
        [int]$hteamDumpIns += [int]$objStat.DumpIns
        [int]$hteamIcings += [int]$objStat.Icings
        [int]$hteamLPfromHit += [int]$objStat.LPfromHit
        [int]$hteamLostPuck += [int]$objStat.LostPuck
        $hteampassessplit = $objStat.Passes.split("/")
        [int]$hteamPassesMade += [int]$hteampassessplit[0]
        [int]$hteamPassesAttempted += [int]$hteampassessplit[1]
        [int]$hteamSDeflect += [int]$objStat.SDeflect
        [int]$hteamSMiss += [int]$objStat.SMiss
        [int]$hteamSBlock += [int]$objStat.SBlock
        [int]$hteamSHitPost += [int]$objStat.SHitPost
        $hteamshotsplit = $objStat.SHots.split("/")
        [int]$hteamShotsMade += [int]$hteamshotsplit[0]
        [int]$hteamShotsAttempted += [int]$hteamshotsplit[1]
        [int]$hteamGATATotal += [int]$objStat."GA/TA"

}
if ($hteamPassesAttempted -eq 0)
{ $hteamnPassPct = 0}
else{$hteamnPassPct = [math]::Round((($hteamPassesMade / $hteamPassesAttempted) * 100),0)}

if ($hteamShotsAttempted -eq 0)
{ $hteamshotPct = 0}
else{$hteamShotPct = [math]::Round((($hteamShotsMade / $hteamShotsAttempted) * 100),0)}

if ($hteamGA -eq 0)
{ $hteamGAPct = 0}
else{ $hteamGAPct = [math]::Round((($hteamGA / ($hteamLPPickup + $hteamRPass + $hteamPassINT)) * 100),0)}


$hteamtotals = [PSCustomObject]@{
 PlayerName = "Team Totals"
 TeamName = $HomeTeamName
 G = $hteamgoals
 A = $hteamassists
 P = $hteampoints
 "+/-" = $hteamplusminus
 PIM = $hteamPIM
 S = $hteamshots
 H = $hteamshits
 SB = $hteamSB
 GA = $hteamGA
 TA = $hteamTA
 FO = ([string]$hteamFOWon + '/' + [string]$hteamFOTotal)
 MP = "N/A"
 "PP MP" = "N/A"
 "PK MP" = "N/A"
 HitLP  = $hteamHitLP
 PassINT = $hteamPassINT
 LPPickup = $hteamLPPickup
 RPass = $hteamRPass
 DumpIns = $hteamDumpIns
 Icings = $hteamIcings
 LPfromHit = $hteamLPfromHit
 LostPuck = $hteamLostPuck
 Passes = ([string]$hteamPassesMade + '/' + [string]$hteamPassesAttempted)
 PassPct = ([string]$hteamnPassPct + '%')
 SDelfect = $hteamSDeflect
 SMiss = $hteamSMiss
 SBlock = $hteamSBlock
 SHitPost = $hteamSHitPost
 Shots = ([string]$hteamShotsMade + '/' + [string]$hteamShotsAttempted)
 SOGPct = ([string]$hteamShotPct + '%')
 "GA/TA" = $hteamGATATotal
  "GA%" = ([string] $hteamGAPct + '%')
 }



$HomestatArray += $hteamtotals

#$HomestatArray |ft PlayerName,TeamName,G,A,P,"+/-",PIM,S,H,SB,GA,TA,"GA/TA","GA%",FO,MP,"PP MP","PK MP",HitLP,PassINT,LPPickup,RPass,DumpIns,Icings,LPfromHit,LostPuck,Passes,PassPct,SDelfect,SMiss,SBlock,SHitPost,Shots,SOGPct -autosize


# Create Corsi numbers - 
# 
#Corsi For (CF) = Shot attempts for at even strength: Shots + Blocks + Misses
#Corsi Against (CA) = Shot attempts against at even strength: Shots + Blocks + Misses
#Corsi (C) = CF - CA
#Corsi For % (CF%) = CF / (CF + CA)
$vteamCF = $vteamShotsAttempted
$vteamCA = $hteamShotsAttempted
$vteamCorsi = $vteamCF - $vteamCA
$vteamCFPct = [math]::Round((($vteamCF / ($vteamCF + $vteamCA)) * 100),2) 


$hteamCF = $hteamShotsAttempted
$hteamCA = $vteamShotsAttempted
$hteamCorsi = $hteamCF - $hteamCA
$hteamCFPct = [math]::Round((($hteamCF / ($hteamCF + $hteamCA)) * 100),2)


# Fenwick is the same as Corsi, except you ignore blocked shots
# Fenwick = (Shots on goal FOR + missed shots FOR) – (Shots on goal AGAINST + missed shots AGAINST)
$vteamFF = ($vteamShotsAttempted - $vteamSBlock)
$vteamFA = ($hteamShotsAttempted - $hteamSBlock)
$vteamFenwick = $vteamFF - $vteamFA
$vteamFFPct = [math]::Round((($vteamFF / ($vteamFF + $vteamFA)) * 100),2) 


$hteamFF = ($hteamShotsAttempted - $hteamSBlock)
$hteamFA = ($vteamShotsAttempted - $vteamSBlock)
$hteamFenwick = $hteamFF - $hteamFA
$hteamFFPct = [math]::Round((($hteamFF / ($hteamFF + $hteamFA)) * 100),2) 

#PDO is team's shooting % + team's save % * 100
$vteamPDOSP = ($vteamgoals / $vteamshots)
$vteamPDOSAP = (($hteamshots - $hteamgoals) / $hteamshots)
$vteamPDO = [math]::Round((($vteamPDOSP + $vteamPDOSAP) * 100),3) 

$hteamPDOSP = ($hteamgoals / $hteamshots)
$hteamPDOSAP = (($vteamshots - $vteamgoals) / $vteamshots)
$hteamPDO = [math]::Round((($hteamPDOSP + $hteamPDOSAP) * 100),3)

#negative numbers make the formatting look different, but we probably will display this data differently anyway, so I'm not too worried about it. 
#Write-Output "$VisitorTeamName Advance Metrics `nCorsi For: $vteamCF `t`tCorsi Against: $vteamCA `t`tCorsi: $vteamCorsi `t`t`tCorsi For %: $vteamCFPct `nFenwick For: $vteamFF `tFenwick Against: $vteamFA `tFenwick: $vteamFenwick `t`tFenwick For %: $vteamFFPct`nPDO: $vteamPDO`n"
#Write-Output "$HomeTeamName Advance Metrics `nCorsi For: $hteamCF `t`tCorsi Against: $hteamCA `t`tCorsi: $hteamCorsi `t`t`tCorsi For %: $hteamCFPct `nFenwick For: $hteamFF `tFenwick Against: $hteamFA `tFenwick: $hteamFenwick `t`tFenwick For %: $hteamFFPct `nPDO: $hteamPDO`n"





$vteamAM = [PSCustomObject]@{
TeamName = $VisitorTeamName
Opponent = $HomeTeamName
GameNumber = $gamenumber
CorsiFor = $vteamCF
CorsiAgainst = $vteamCA
Corsi = $vteamCorsi
CorsiForPct = $vteamCFPct
FenwickFor = $vteamFF
FenwickAgainst = $vteamFA
Fenwick = $vteamFenwick
FenwickForPct = $vteamFFPct
PDO = $vteamPDO
}

$vteamAM |export-csv $statsFile -NoTypeInformation -Append

$hteamAM = [PSCustomObject]@{
TeamName = $HomeTeamName
Opponent = $VisitorTeamName
GameNumber = $gamenumber
CorsiFor = $hteamCF
CorsiAgainst = $hteamCA
Corsi = $hteamCorsi
CorsiForPct = $hteamCFPct
FenwickFor = $hteamFF
FenwickAgainst = $hteamFA
Fenwick = $hteamFenwick
FenwickForPct = $hteamFFPct
PDO = $hteamPDO
}
$hteamAM |export-csv $statsFile -NoTypeInformation -Append


$baseurl = ""


} #end while loop

# should do some cleanup here to delete the temp files I created

<#

Stat Description
GA - Giveaway - player directly loses the puck to the other team (Player Pass Intercepted, player hit + loses puck + loose puck pick up by other team, player loses puck + loose puck pick up by other team)
TA - Takeaway - player's direct action result in them getting possession of the puck (player intercepts pass from opponent, player hits opponent + player picks up loose puck)
GA/TA = player giveaways minus player takeaways
GA% = percentage of total player touches that resulted in a giveaway
HitLP = when player hits an opponent and opponent loses the puck
PassINT = when player intercepts a pass from opponent
LPPickup = when player picks up a loose puck
RPass = when player receives a pass
DumpIns = when player dumps the puck into the zone
Icings = when player ices the puck
LPfromHit = when player gets hit and loses the puck
LostPuck = when player loses the puck without being hit
Passes = Successful Passes / Attempted Passes
PassPct = Percentage of successful passes
SDeflect = Shot deflected by player (counts as a shot attempt)
SMiss = Shots by player that missed the net
SBlock = Shots by player that were blocked by opponent
SHitPost = Shots by player that hit a post
Shots =  Shots on target / Attempted Shots
SOGPct = Percentage of attempted shots that were a shot on goal

#>




# Below this line are old ideas that don't work
#------------------------------------------------------------------------------------------------------------------------------
