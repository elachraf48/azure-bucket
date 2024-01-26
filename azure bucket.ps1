$credentialFile = "compte.txt"
$credentials = Get-Content $credentialFile | ForEach-Object {
    $parts = $_ -split ',' 
    [PSCustomObject]@{
        Email    = $parts[0]
        Password = $parts[1]
    }
}

$numberOfAccounts = Read-Host -Prompt "Enter the number of Storage accounts to create"
$nameOfFolder = Read-Host -Prompt "Enter the name of offer"
$pathOfFolder = "offre\" + $nameOfFolder
# Set default values  
$location = "West US 3"
# Write-Host $pathOfFolder
$files = Get-ChildItem -Path $pathOfFolder -Recurse 

foreach ($credential in $credentials) {

    # Log in to Azure
    $securePassword = ConvertTo-SecureString $credential.Password -AsPlainText -Force
    $azureCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList ($credential.Email, $securePassword) 
    Connect-AzAccount -Credential $azureCredentials | Out-Null

    # Get resource groups
    $resourceGroups = Get-AzResourceGroup

    if ($resourceGroups.Count -eq 0) {
        # No existing groups
    }
    else {
        
        # Select a resource group
        $randomResourceGroup = $resourceGroups | Get-Random
        $resourceGroupName = $randomResourceGroup.ResourceGroupName
        # Create storage accounts 
        for ($i = 1; $i -le $numberOfAccounts; $i++) {

            # Generate storage account name
            $storageAccountName = -join ((48..57) + (97..122) | Get-Random -Count 20 | ForEach-Object { [char]$_ })

            # Create storage account
            $storageContext = New-AzStorageAccount `
                -ResourceGroupName $resourceGroupName `
                -Name $storageAccountName `
                -Location $location `
                -SkuName Standard_LRS `
                -Kind StorageV2 `
                -AllowBlobPublicAccess $true 
            # Create a single container
            New-AzStorageContainer -Name $storageAccountName -Context $storageContext.Context | Out-Null

            # Allow public access to blobs
            Set-AzStorageContainerAcl -Context $storageContext.Context `
                -Container $storageAccountName `
                -Permission Blob
            $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName

            # Get all files in the folder
            $files = Get-ChildItem -Path $pathOfFolder
            # Upload each file to the container
            foreach ($file in $files) {
                $blobName = $file.Name
                $blobPath = $file.FullName
                $contentType = switch ($file.Extension) {
                    ".jpg" { "image/jpeg" } 
                    ".png" { "image/png" }
                    ".html" { "text/html" }
                    default { "application/octet-stream" }  
                }
                Set-AzStorageBlobContent -Context $storageAccount.Context `
                    -Container $storageAccountName `
                    -File $blobPath `
                    -Blob $blobName `
                    -Properties @{"ContentType" = $contentType}| Out-Null
            }


            $Ms= $storageAccountName
            $Ms | Out-File -FilePath bucket.txt -encoding utf8 -Append

        }

    }
}