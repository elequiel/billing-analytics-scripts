$aspIds=az appservice plan list --query "[].id" | convertfrom-json
$endDate = get-date -format "yyyy-MM-ddT00:00:00Z"
$startDate = get-date (get-date).AddDays(-30) -Format "yyyy-MM-ddT00:00:00Z"

$aspOutput = @()

foreach($aspId in $aspIds){
    $aspName=$aspId.Split("/")[-1]
    $ds = az monitor metrics list --resource $aspId `
        --metrics "CpuPercentage" `
        --aggregation maximum `
        --start-time $startDate `
        --end-time $endDate `
        --interval PT1H `
        --query '{max:value[].timeseries[].data[].maximum}' | ConvertFrom-Json

    $sumPercentage=0
    foreach ($value in $ds.max) {
        $sumPercentage+=$value
    }
    try{
        $mediaMax=($sumPercentage/$ds.max.Count).tostring("#.##")
        Write-Output "$aspName $mediaMax%"
        $asp = [PSCustomObject]@{
            aspName = "$aspName"
            cpuMax = $mediaMax
        }
        $aspOutput += $asp
    }
    catch{
        $mediaMax=0
        $asp = [PSCustomObject]@{
            aspName = "$aspName"
            cpuMax = $mediaMax
        }
        $aspOutput += $asp
        Write-Output "$aspName $mediaMax%"
    }
}
$aspOutput | Sort-Object -Property cpuMax -Descending