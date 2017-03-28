Write-Output "PowerShell Timer trigger function executed at:$(get-date)";

$SourceStorageAccountName = $env:Source_Storage_Account
$SourceStorageAccountKey = $env:Source_Storage_Key
$SourceContainerNames = [string[]]$env:Source_Containers -split ","
$DestinationStorageAccountName = $env:Destination_Storage_Account
$DestinationStorageAccountKey = $env:Destination_Storage_Key

$sourceContext = New-AzureStorageContext -StorageAccountName $SourceStorageAccountName -StorageAccountKey $SourceStorageAccountKey
$destinationContext = New-AzureStorageContext -StorageAccountName $DestinationStorageAccountName -StorageAccountKey $DestinationStorageAccountKey 

foreach($containerName in $SourceContainerNames) {
    Write-Output "Copying container $SourceStorageAccountName\$containerName to $DestinationStorageAccountName\$containerName"

    try {
        $destContainer = Get-AzureStorageContainer -Context $destinationContext -Name $containerName -ErrorAction Stop
        Write-Output "Destination container exists."
    }
    catch [Microsoft.WindowsAzure.Commands.Storage.Common.ResourceNotFoundException] {
        Write-Output "Destination container does not exist.  Creating."
        $newContainer = New-AzureStorageContainer -Context $destinationContext -Name $containerName -Permission Off
    }
   
    $blobs = Get-AzureStorageBlob -Context $sourceContext -Container $containerName

    foreach ($blob in $blobs) {

        try {
            $destBlob = Get-AzureStorageBlob -Blob $blob.Name -Container $containerName -Context $destinationContext -ErrorAction Stop
            
            Write-Output "$($blob.Name) found on destination.  Skipping."
        }
        catch [Microsoft.WindowsAzure.Commands.Storage.Common.ResourceNotFoundException] {
       
            Write-Output "$($blob.Name) not found on destination.  Copying."

            $fileName = $blob.Name
            $sourceUrl = "https://$SourceStorageAccountName.blob.core.windows.net/$containerName/$fileName"
            $targetUri = $destinationContext.BlobEndPoint + $containerName + "/" + $fileName    
 
            $BlobResult = Start-AzureStorageBlobCopy -Context $sourceContext -SrcUri $sourceUrl -DestContext $destinationContext -DestContainer $containerName -DestBlob $fileName 

            $status = $BlobResult | Get-AzureStorageBlobCopyState

            While ($status.Status -eq "Pending") {
                $status = $BlobResult | Get-AzureStorageBlobCopyState 
                Write-Output "Copying: $fileName, $($status.BytesCopied) of $($status.TotalBytes) bytes."
                Start-Sleep 10 
            }

            Write-Output "Copied: $sourceUrl to $targetUri, $($status.BytesCopied) bytes."
        }
    }
 }