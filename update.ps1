param(
    [Parameter()]
    [switch]$Clear,
    [switch]$Help
)

# Function that get version from file name and return a version object
Function GetVersionAndName($fileName) {
    $fileName -match "(.*)\.(\d+\.\d+\.\d+).nupkg"
    $name = $matches[1]
    $version = New-Object Version($matches[2])
    return [PSCustomObject]@{
        Name    = $name;
        Version = $version;
    }
}

Function RemoveFileInPackageIfClearIsActive($fileName) {
    if ($Clear -eq $true) {
        Remove-Item "./packages/$fileName" -Force -ErrorAction SilentlyContinue
    }
}

# Show Help if help parameter is active
If ($Help -eq $true) {
    Write-Host "Usage: update.ps1 [-Clear] [-Help]"
    Write-Host "  -Clear: Remove duplicate and old packages from ./packages folder"
    Write-Host "  -Help:  Show this help"
    Exit
}

# Check if ./packages folder exist
if (!(Test-Path -Path "./packages")) {
    # Create ./packages folder
    New-Item -Path "./packages" -Force -ItemType Directory | Out-Null
}

# Get list of all files in ./packages folder

$files = Get-ChildItem -Path "./packages" -File | Where-Object { $_.Name -match ".*\.nupkg" } | % { $_.Name }

# Check if files is empty
if ($null -eq $files) {
    Write-Host "No packages found, you must add them to the ./packages folder"
    exit 1
}

$filesUniques = @{}

# Remove duplicate with same name and only keep the latest version
$files | ForEach-Object {
    $toTest = GetVersionAndName($_)
    #check if in filesUniques if not add it and return
    if (!($filesUniques.ContainsKey($toTest.Name))) {
        $filesUniques.Add($toTest.Name, $_)
        return
    }

    #if in filesUniques check if version is greater than current one
    $current = GetVersionAndName($filesUniques[$toTest.Name])
    
    if ($toTest.Version -gt $current.Version) {
        $oldFileName = $filesUniques[$toTest.Name]
        $filesUniques[$toTest.Name] = $_
        RemoveFileInPackageIfClearIsActive($oldFileName)
    }
}


#For each file in the list, get the version and name regex => ".*\.(\d+\.\d+\.\d+).*" optinally there is -something
$filesUniques.Values | ForEach-Object {
    $_ -match "(.*)\.(\d+\.\d+\.\d+.*).nupkg" | Out-Null
    $name = $matches[1]
    $version = $matches[2]

    Write-Output "Checking if $name $version is latest"

    $findResult = Find-Package -Name $name -Source "https://www.nuget.org/api/v2" -ProviderName "NuGet"

    # Check if version is same if so skip
    if ($findResult.Version -eq $version) {
        Write-Output "Version is same, skipping"
        return
    }

    ./nuget.exe install $name -OutputDirectory "./packages"

    # Move *.nupkg to ./packages from ./packages/$name.$findResult.version.nupkg
    $newVersion = $findResult.Version
    Move-Item -Path "./packages/$name.$newVersion/*.nupkg" -Destination "./packages"
    # Delete the folder
    Remove-Item -Path "./packages/$name.$newVersion" -Force -Recurse

    Write-Output "Package $name updated to version $newVersion"

    # Remove the old file in ./packages if Clear is active
    RemoveFileInPackageIfClearIsActive($_)
}
