# Log usage disks (IOPS usage <= 40%) should be resized (Premium -> Std, Std -> Hdd).


# Replace with your tenantId
$tenantId = "a680bede-9e00-4d2c-a1f0-8df2bea6b6f6"
Connect-AzAccount -TenantId $tenantId
$subscriptions = Get-AzSubscription | Where-Object { $_.TenantId -eq $tenantId }


# Date range
$startDate = (Get-Date).AddDays(-30)
$endDate = Get-Date

function Get-VMOSDiskIoUsage {

    param ($resourceId)     

    $metricsResult = Get-AzMetric -ResourceId $resourceId -MetricName "OS Disk IOPS Consumed Percentage" -StartTime $startDate -EndTime $endDate -TimeGrain "01:00:00" -AggregationType Maximum
    $result = $metricsResult.Data | Where-Object { $_.Maximum -gt 40 }
    if ($result.Count -gt 5) { return $true } else { return $false }
}


function Get-VMDataDiskIoUsage {

    param ($resourceId)     

    $metricsResult = Get-AzMetric -ResourceId $resourceId -MetricName "Data Disk IOPS Consumed Percentage" -StartTime $startDate -EndTime $endDate -TimeGrain "01:00:00" -AggregationType Maximum
    $result = $metricsResult.Data | Where-Object { $_.Maximum -gt 40 }
    if ($result.Count -gt 5) { return $true } else { return $false }
}


$lowUsageVmOsDisks = New-Object Collections.Generic.List[object]
$lowUsageVmDataDisks = New-Object Collections.Generic.List[object]

$subscriptions = Get-AzSubscription | Where-Object { $_.TenantId -eq $tenantId }

foreach ($subscription in $subscriptions) {
    Write-Host "Getting recommendations for "$subscription.name
    Set-AzContext -Subscription $subscription.Id
    $virtualMachines = Get-AzVM

    foreach ($vm in $virtualMachines) {
        $isOsHighUsage = Get-VMOSDiskIoUsage -resourceId $vm.Id;
        $isDataHighUsage = Get-VMDataDiskIoUsage -resourceId $vm.Id;
        if ($isOsHighUsage -eq $false) {
            Write-Host "Found! "$vm.name
            $lowUsageVmOsDisks.Add($vm)
        }

        if ($isDataHighUsage -eq $true) {
            Write-Host "Found! "$vm.name
            $lowUsageVmDataDisks.Add($vm)
        }
    }
}

Write-Host "VMs with low usage OS disk"
Write-Host "------------------------------"
$lowUsageVmOsDisks | Format-Table

Write-Host "VMs with low usage Data disks"
Write-Host "------------------------------"
$lowUsageVmDataDisks | Format-Table
