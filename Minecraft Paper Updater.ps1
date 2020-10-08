# Minecraft Paper.io Jar file updater
# This script assumes your paper.jar file is just called paper.jar! rename it if it isn't!
# It also assumes to start your server you have a scheduled task. Though you could change it out to start a script
# You would use this script as a scheduled task itself that runs however frequently you like to check for and update your paper minecraft server jar file.
# Andrew Lund
$lastUpdated = "10-7-20"

Clear-Variable RConDir,mcraftIP,rconpw,newestMCBuildVersion,matches,releaseTimeStampDateTimeObject,lastWriteTimePaperJar,params -ErrorAction SilentlyContinue

# Set SSL protocol type for internet scraping
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Change this to point to your paper directory
$pathToPaperDir = "C:\minecraft\Andy_Server\Paper"

# Make download cache for paper files
mkdir -Path "$pathToPaperDir\DownloadCache" -Force

# How long you give players on server until update is pushed
$updateDeferTimeInSeconds = "300" # Default 5 Min

# RCon directory location (mcrcon.exe)
$RConDir = "C:\minecraft\Andy_Server\Vanilla\mcrcon-0.0.5-bin-windows"

# Which address should rcon point to? (Minecraft server?), you may have to add port :25575
$mcraftIP = ""

# Rcon pass
$rConPW = ""

# Grab build version that paper is based off of with api
[version]$newestMCBuildVersion = (Invoke-RestMethod -uri "https://papermc.io/api/v1/paper").versions[0]

# Mostly static info. Only need ot change this when they change the minor version they build off of.
$paperMCDownloadLandingPage = "https://papermc.io/ci/job/Paper-$($newestMCBuildVersion.major.tostring()).$($newestMCBuildVersion.minor.tostring())/api/json?tree=builds[number,url,artifacts[fileName,relativePath],timestamp,changeSet[items[comment,commitId,msg]]]{,1}"

# Grab page contents based on above URL, save only the content
$pageContents = (IWR -Uri $paperMCDownloadLandingPage -UseBasicParsing).content

# Check timestamp from last paper file to compare to
[datetime]$lastWriteTimePaperJar = (Get-Item "$pathToPaperDir\paper.jar").LastWriteTime

# Timestamp from release
$unixTimeStamp = $pageContents -match "timestamp\`"\:(\d+)\," | % {$matches[1]}
[datetime]$UnixOrigin = '1970-01-01Z'
$releaseTimeStampDateTimeObject = $UnixOrigin.AddMilliSeconds($unixTimeStamp)

# If the last release from the page is newer than the file on hand start replacement process
if ($releaseTimeStampDateTimeObject -gt $lastWriteTimePaperJar)
    {
        # Warn players on server that the server will be updated (brought down)
        $params = @("-s", "-H", "$mcraftIP", "-p", "$rConPW", "say Server will be restarted for update in $([int]($updateDeferTimeInSeconds/60)) minute(s)!")
        & "$RConDir\mcrcon.exe" $params
        
        # Kill all files in download cache
        Remove-Item -Path "$pathToPaperDir\DownloadCache\*" -Force -Recurse

        # Grab the new version of Paper - Place in downloadCache directory
        Invoke-WebRequest -Uri "https://papermc.io/api/v1/paper/$($newestMCBuildVersion)/latest/download" -OutFile "$pathToPaperDir\DownloadCache\paper.jar"

        # Wait for some time for players to finish what they are doing
        Sleep -Seconds $($updateDeferTimeInSeconds - 30)

        # Final Warning
        $params = @("-s", "-H", "$mcraftIP", "-p", "$rConPW", "say Server will be restarted for update in 30 seconds!")
        & "$RConDir\mcrcon.exe" $params

        # Final wait
        sleep -Seconds 30

        # Process kill for server
        $params = @("-s", "-H", "$mcraftIP", "-p", "$rConPW", "stop")
        & "$RConDir\mcrcon.exe" $params

        # Replace older paper file
        Copy-Item -Path "$pathToPaperDir\DownloadCache\paper.jar" -Destination "$pathToPaperDir\paper.jar" -Force

        # Give it a teeeny bit wait for the server to start up again
        Sleep -Seconds 3

        # Restart server - For me, this was a schedule task
        Start-ScheduledTask -TaskName "Start Minecraft Server"
    }
