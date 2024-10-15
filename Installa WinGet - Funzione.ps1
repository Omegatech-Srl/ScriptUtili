try {
  Install-PackageProvider -Name NuGet -Force | Out-Null
  Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
} catch {
  throw "Microsoft.Winget.Client was not installed successfully"
} finally {
  # Controlla che sia effettivamente installato
  if (-not(Get-Module -ListAvailable -Name Microsoft.Winget.Client)) {
    throw "Microsoft.Winget.Client was not found. Check that the Windows Package Manager PowerShell module was installed correctly."
  }
}
Repair-WinGetPackageManager
