$sqlServers = az sql server list --query "[].{name:name,rg:resourceGroup}" | ConvertFrom-Json
$endDate = get-date -format "yyyy-MM-ddT00:00:00Z"
$startDate = get-date (get-date).AddDays(-30) -Format "yyyy-MM-ddT00:00:00Z"

function Get-Databases {
    param ($server, $resourceGroup)

    $dbs = az sql db list --server $server --resource-group $resourceGroup | ConvertFrom-Json
    $objectToRemove = $dbs | Where-Object { $_.name -eq "master" }
    $dbs = $dbs | Where-Object { $_ -ne $objectToRemove }

    return $dbs
}

function Get-CPUDatabaseVcore {
    param ($database)

    $ds = az monitor metrics list --resource $database.id `
        --metrics "cpu_percent" `
        --aggregation Maximum `
        --start-time $startDate `
        --end-time $endDate `
        --interval PT6H `
        --query '{max:value[].timeseries[].data[].maximum}' | ConvertFrom-Json

    $sumPercentageMax=0
    foreach($value in $ds.max){
        $sumPercentageMax += $value
    }
    try {
        $mediaMax=($sumPercentageMax/$ds.max.Count).tostring("#.##")
        return $mediaMax
    }
    catch {
        return 0
    }
}

function Get-CPUDatabaseDTU {
    param ($database)

    $ds = az monitor metrics list --resource $dbDTU `
        --metrics "dtu_consumption_percent" `
        --aggregation Maximum `
        --start-time $startDate `
        --end-time $endDate `
        --interval PT6H `
        --query '{max:value[].timeseries[].data[].maximum}' | ConvertFrom-Json
    
    $sumPercentageMax=0
    foreach($value in $ds.max){
        $sumPercentageMax += $value
    }
    try {
        $mediaMax=($sumPercentageMax/$ds.max.Count).tostring("#.###")
    }
    catch {
        return 0
    }
}

$sqlBadatabesOutput = @()

foreach ($server in $sqlServers) {
    $databases = Get-Databases -server $server.name -resourceGroup $server.rg
    
    switch ($databases){
        {$databases | Where-Object { $_.requestedServiceObjectiveName -like "S" }} {
            write-output "executnado para db DTU"
            $databases | Where-Object { $_.requestedServiceObjectiveName -like "S" } | select name

        }
        {$databases | Where-Object { $_.requestedServiceObjectiveName -like "GP_G*" }} {
            $mediaCPU = Get-CPUDatabaseVcore -database $_
            $mediaCPU
            $db = [PSCustomObject]@{
                "DB Name" = $_.name
                "Server Name" = $_.id.Split("/")[8] 
                "SKU" = "GeneralPurpose"
                "CPU %" = [System.Int32]$mediaCPU
                }
            $sqlBadatabesOutput += $db
        }
        {$databases | Where-Object { $_.requestedServiceObjectiveName -like "GP_S*" }} {
            $mediaCPU = Get-CPUDatabaseVcore -database $_
            $mediaCPU
            $db = [PSCustomObject]@{
                "DB Name" = $_.name
                "Server Name" = $_.id.Split("/")[8] 
                "SKU" = "GeneralPurpose Serverless"
                "CPU %" = [System.Int32]$mediaCPU
                }
            $sqlBadatabesOutput += $db
        }
        {$databases | Where-Object { $_.requestedServiceObjectiveName -like "Basic" }} {
            $mediaCPU = Get-CPUDatabaseDTU -database $_
            $mediaCPU
            $db = [PSCustomObject]@{
                "DB Name" = $_.name
                "Server Name" = $_.id.Split("/")[8] 
                "SKU" = "Basic"
                "CPU %" = [System.Int32]$mediaCPU
                }
            $sqlBadatabesOutput += $db
        }
    }
}

$sqlBadatabesOutput | Sort-Object -Property 'CPU %' -Descending

foreach ($server in $sqlServers) {
    $dbsDTU = az sql db list --server $server.name --resource-group $server.rg --query "[?starts_with(requestedServiceObjectiveName, 'S')].{id:id,name:name}" | ConvertFrom-Json
    $dbsvCore = az sql db list --server $server.name --resource-group $server.rg --query "[?starts_with(requestedServiceObjectiveName, 'GP_')].{id:id,name:name}" | ConvertFrom-Json
    #$server.name
    #echo "-----------"
    foreach($dbvCore in $dbsvCore){
        $dbName=$dbvCore.name
        #$dbType = az resource show --ids $dbsvCore --query "{type:properties.requestedServiceObjectiveName}" | ConvertFrom-Json
        $ds = az monitor metrics list --resource $dbvCore.id `
            --metrics "cpu_percent" `
            --aggregation Maximum `
            --start-time $startDate `
            --end-time $endDate `
            --interval PT6H `
            --query '{max:value[].timeseries[].data[].maximum}' | ConvertFrom-Json
    
        $sumPercentageMax=0
        foreach($value in $ds.max){
            $sumPercentageMax += $value
        }
        $mediaMax=($sumPercentageMax/$ds.max.Count).tostring("#.##")
        #$mediaMax

        $dsAv = az monitor metrics list --resource $dbvCore.id `
            --metrics "cpu_percent" `
            --aggregation Average `
            --start-time $startDate `
            --end-time $endDate `
            --interval PT6H `
            --query '{max:value[].timeseries[].data[].average}' | ConvertFrom-Json
    
        $sumAv = 0
        foreach($value in $dsAv.max){$sumAv+=$value}
        $mediaAv=($sumAv/$dsAv.max.count).tostring("#.##")
        echo "$dbName $mediaMax $mediaAv"       
    }
}


$dbtest="/subscriptions/569992d7-82b7-4af3-bb36-8e5a80400c61/resourceGroups/FATE-NewSite/providers/Microsoft.Sql/servers/new-site-projects-db/databases/db-projecsts-newsite_Copy"

$dsAv = az monitor metrics list --resource $dbtest `
    --metrics "dtu_consumption_percent" `
    --aggregation Maximum `
    --start-time $startDate `
    --end-time $endDate `
    --interval PT6H `
    --query '{max:value[].timeseries[].data[].maximum}' | ConvertFrom-Json