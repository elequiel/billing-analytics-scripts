$disks = az disk list | ConvertFrom-Json

$disksOutput = @()

$disks | foreach { $sku = $_.sku.name
    try { $attached = $_.managedBy.Split("/")[-1] }
    catch{ $attached = "Unattached" }
    
    $disk = [PSCustomObject]@{
        DiskName = $_.name
        ManagedBy = $attached
        SKU = $_.sku.name
        Size = [System.Double]$_.diskSizeBytes/1gb
        #State = $_.diskState
    }
    $disksOutput += $disk
}

$disksOutput | Sort-Object -Property Size -Descending