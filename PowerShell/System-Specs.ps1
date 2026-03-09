# Perfect Key:Value Format - No Name/Value Headers
$info = [ordered]@{
    'Computer' = $env:COMPUTERNAME
    'Manufacturer' = (Get-CimInstance Win32_ComputerSystem).Manufacturer
    'Model' = (Get-CimInstance Win32_ComputerSystem).Model
    'Serial Number' = (Get-CimInstance Win32_BIOS).SerialNumber
    'Processor' = (Get-CimInstance Win32_Processor | Select -First 1).Name
    'Cores/Threads' = '{0}/{1}' -f ((Get-CimInstance Win32_Processor | Measure NumberOfCores -Sum).Sum), ((Get-CimInstance Win32_Processor | Measure NumberOfLogicalProcessors -Sum).Sum)
    'Total RAM' = '{0:N2} GB' -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    'RAM Speed' = '{0} MHz' -f ((Get-CimInstance Win32_PhysicalMemory | Select -First 1).Speed)
    'Motherboard' = (Get-CimInstance Win32_BaseBoard).Product
    'OS' = (Get-CimInstance Win32_OperatingSystem).Caption
    'Storage' = (Get-CimInstance Win32_DiskDrive | Where MediaType -eq 'Fixed hard disk media' | ForEach { '{0} ({1:N0}GB)' -f $_.Model, ($_.Size/1GB) }) -join '; '
}

# This gives EXACTLY your format
$info.GetEnumerator() | ForEach-Object { "$($_.Key) : $($_.Value)" }
