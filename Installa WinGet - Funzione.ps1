<#
  .SYNOPSIS
  Funzione di Installazione di WinGet v1.2.6

  .DESCRIPTION
  Lo script contiene una funzione che può essere utilizzata per installare WinGet (nel profilo utente corrente) automaticamente.
  
  La funzione è progettata per essere utilizzata come un metodo automatizzato per installare WinGet, anche subito dopo 
  la configurazione OOBE. Questo script gestisce tutte le particolarità dell'installazione di WinGet al primo avvio
  (incluso l'ottenimento di tutti i pacchetti richiesti da cui dipende per funzionare correttamente).
  
  Di default, la funzione scarica le versioni più recenti dei pacchetti necessari per il funzionamento di WinGet, e 
  la versione più recente di WinGet stesso. Ciò significa che è necessaria una connessione a Internet.

  Lo script non avvia automaticamente la funzione.

  .PARAMETER Help
  Visualizza questa pagina di aiuto, ma non esegue lo script.

  .INPUTS
  Script: Nessuno. Non puoi passare oggetti a questo script tramite pipe.
  Funzione: Opzione Force (forza l'installazione di WinGet).
            Per impostazione predefinita, senza l'opzione force, WinGet non verrà aggiornato se viene rilevata una versione funzionante.

  .OUTPUTS
  Script: Attiverà la funzione solo nella sessione PowerShell corrente.
  Funzione: Mostra eventuali errori, ma restituisce un valore booleano che indica se WinGet è stato installato correttamente.

  .EXAMPLE
  PS> Install-WinGet

  .EXAMPLE
  PS> Install-WinGet -Force

  .LINK
  Windows Package Manager (WinGet): https://github.com/microsoft/winget-cli

  .LINK
  Microsoft.UI.Xaml (requisito di WinGet): https://www.nuget.org/packages/Microsoft.UI.Xaml/
  
  .LINK
  Microsoft.VCLibs (requisito di WinGet): https://learn.microsoft.com/en-us/troubleshoot/developer/visualstudio/cpp/libraries/c-runtime-packages-desktop-bridge

  .LINK
  Script da: https://github.com/Andrew-J-Larson/OS-Scripts/blob/main/Windows/Wrapper-Functions/Install-WinGet-Function.ps1
#>

<# Copyright (C) 2024  Andrew Larson (github@andrew-larson.dev)

   Questo programma è software libero: puoi ridistribuirlo e/o modificarlo
   secondo i termini della Licenza Pubblica Generale GNU come pubblicata dalla
   Free Software Foundation, sia la versione 3 della Licenza, sia (a tua scelta) 
   qualsiasi versione successiva.

   Questo programma è distribuito nella speranza che sia utile,
   ma SENZA ALCUNA GARANZIA; senza neppure la garanzia implicita di
   COMMERCIABILITÀ o IDONEITÀ PER UN PARTICOLARE SCOPO. Consulta la
   Licenza Pubblica Generale GNU per maggiori dettagli.

   Dovresti aver ricevuto una copia della Licenza Pubblica Generale GNU
   insieme a questo programma. In caso contrario, vedi <https://www.gnu.org/licenses/>.
#>

param(
  [Alias("h")]
  [switch]$Help
)

# controlla i parametri ed esegui di conseguenza
if ($Help.IsPresent) {
  Get-Help $MyInvocation.MyCommand.Path
  exit
}

# Funzione PRINCIPALE
function Install-WinGet {
  param(
    [switch]$Force
  )

  # COSTANTI

  $osIsWindows = (-Not (Test-Path variable:global:isWindows)) -Or $isWindows # richiesto per PS 5.1
  $osIsARM = $env:PROCESSOR_ARCHITECTURE -match '^arm.*'
  $osIs64Bit = [System.Environment]::Is64BitOperatingSystem
  $osArch = $( # l'architettura è necessaria per alcune parti del processo di installazione
    if ($osIsARM) { 'arm' } else { 'x' }
  ) + $(
    if ($osIs64Bit) { '64' } elseif (-Not $osIsARM) { '86' }
  ) # = x86 | x64 | arm | arm64
  $osVersion = [System.Environment]::OSVersion.Version
  $osName = if ($PSVersionTable.OS) {
    $PSVersionTable.OS
  } else { # richiesto per PS 5.1
    ((([System.Environment]::OSVersion.VersionString.split() |
    Select-Object -Index 0,1,3) -join ' ').split('.') |
    Select-Object -First 3) -join '.'
  }
  $experimentalWindowsVersion = [System.Version]'10.0.16299.0' # prima versione di Windows con funzionalità MSIX: https://learn.microsoft.com/en-us/windows/msix/supported-platforms
  $supportedWindowsVersion = [System.Version]'10.0.17763.0' # versione più vecchia di Windows supportata da WinGet: https://github.com/microsoft/winget-cli?tab=readme-ov-file#installing-the-client
  $retiredWingetVersion = [System.Version]'1.2' # se si utilizza questa versione o versioni precedenti, WinGet deve essere aggiornato a causa di CDN ritirati
  $experimentalWarning = "(potrebbe non funzionare correttamente)"
  $continuePrompt = "Premi un tasto per continuare o CTRL+C per uscire"
  $envTEMP = (Get-Item -LiteralPath $( # Necessario a causa di un bug di PowerShell con nomi brevi che appaiono quando non dovrebbero
    if (Test-Path variable:global:TEMP) {
      $env:TEMP
    } else { # Necessario per non-Windows
      [System.IO.Path]::GetTempPath().TrimEnd('\')
    }
  )).FullName 
  $loopDelay = 1 # secondo
  $appxInstallDelay = 3 # secondi

  # Codici di errore di uscita

  $FAILED = @{
    INSTALL                = 6
    DEPENDENCIES_CHECK     = 5
    INVALID_FILE_EXTENSION = 4
    NO_INTERNET            = 3
    NO_MSIX_FEATURE        = 2
    NOT_WINDOWS            = 1
  }

  # FUNZIONI

  function Test-WinGet {
    return Get-Command 'winget.exe' -ErrorAction SilentlyContinue
  }

  # VARIABILI

  $forceWingetUpdate = $Force.IsPresent

  # PRINCIPALE

  # solo per Windows 10 e versioni successive
  Write-Host "Sistema Operativo = ${osName}`n"
  if (-Not $osIsWindows) {
    Write-Error "WinGet è disponibile solo per Windows 10 e versioni successive."
    return $FAILED.NOT_WINDOWS
  }

  # solo sperimentale su Windows 10 (1709) e successivi, dove le funzionalità MSIX sono disponibili
  $supportedWindowsBuild = "WinGet è supportato solo su Windows 10 (build $($supportedWindowsVersion.Build)) e versioni successive"
  if ($experimentalWindowsVersion -gt $osVersion) {
    Write-Error "${supportedWindowsBuild}, ed è solo sperimentale su versioni pari o superiori a Windows 10 (build $($experimentalWindowsVersion.Build)) ${experimentalWarning}."
    return $FAILED.NO_MSIX_FEATURE
  }

  # supportato solo su Windows 10 (1809) e versioni successive, avvisa riguardo versioni non supportate di Windows
  if ($supportedWindowsVersion -gt $osVersion) {
    Write-Warning "${supportedWindowsBuild} ${experimentalWarning}."
    Read-Host -Prompt $continuePrompt | Out-Null
    Write-Host '' # Migliora l'aspetto dei log
  }

  # supportato solo su versioni Windows (Work Station), avvisa riguardo versioni di Windows Server non supportate
  if ((Get-CimInstance Win32_OperatingSystem).ProductType -ne 1) {
    Write-Warning "WinGet non è supportato su versioni di Windows Server ${experimentalWarning}."
    Read-Host -Prompt $continuePrompt | Out-Null
    Write-Host '' # Migliora l'aspetto dei log
  }

  # controlla se PowerShell è eseguito con privilegi elevati e ottieni dati AppxPackage da tutti gli utenti
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  $elevatedPowershell = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  # L'installazione dei pacchetti si basa sul profilo utente attualmente caricato in PowerShell:
  #   Se l'account utente originale (senza diritti di amministratore) tenta di utilizzare un secondo account utente (con
  #   diritti di amministratore) per elevare in qualche modo la funzione Install-WinGet prima dell'elevazione automatica,
  #   allora caricherà il profilo del secondo account utente (amministratore), che probabilmente non è ciò che desideri.
  #   Di conseguenza, è necessario eseguire PowerShell con privilegi di amministratore per ottenere i dati completi da
  #   tutti gli utenti. Un esempio di errore comune che si verifica con queste limitazioni è che winget.exe sarà
  #   registrato nel profilo sbagliato se winget.exe è già installato su un account con diritti di amministratore.
  $AppxArgs = @{ Name = 'Microsoft.DesktopAppInstaller' }
  if ($elevatedPowershell) {
    $AppxArgs.User = 'All'
  } else {
    Write-Warning "Winget potrebbe non essere installato correttamente se PowerShell non è eseguito con privilegi di amministratore."
  }

  # se non troviamo WinGet, prova a registrarlo di nuovo (solo un problema al primo accesso)
  if ((Test-WinGet) -eq $null) {
    $wingetAppx = Get-AppxPackage @AppxArgs
    $wingetAppxLocation = $wingetAppx.InstallLocation
    Write-Host "WinGet trovato: ${wingetAppxLocation}"
    $wingetAppxRegistered = Get-Command "${wingetAppxLocation}\winget.exe" -ErrorAction SilentlyContinue
    if ($wingetAppxRegistered -ne $null) {
      $wingetAppxRegistered.Name
    } else {
      Write-Warning "WinGet non è stato trovato dopo aver tentato di registrarlo nuovamente."
    }
  } else {
    Write-Host 'WinGet è installato correttamente.'
  }

  # se la versione è sufficientemente nuova per includere WinGet, dovrebbe risolvere il problema
  $wingetAppxInstalled = $wingetAppx.Version
  $wingetAppxInstalledVersion = [Version]$wingetAppxInstalled
  if ($wingetAppxInstalledVersion -lt $retiredWingetVersion) {
    $forceWingetUpdate = $true
    Write-Warning 'Aggiornamento obbligatorio di WinGet (versione precedente ritirata).'
  }

  # se non troviamo ancora WinGet, scarica WinGet e tutti i pacchetti dipendenti e prova a installarlo
  if ((Test-WinGet) -eq $null -or $forceWingetUpdate) {
    Write-Warning 'Tentativo di installare WinGet...'
  }

  # controlla la connessione a Internet
  function Test-InternetConnection {
    try {
      $webRequest = Invoke-WebRequest -Uri 'https://www.microsoft.com' -UseBasicParsing -TimeoutSec 5
      return $true
    } catch {
      return $false
    }
  }

  if (-Not (Test-InternetConnection)) {
    Write-Error 'Connessione a Internet non rilevata. Riprova più tardi.'
    return $FAILED.NO_INTERNET
  }

  # scarica WinGet...
  function Download-WinGet {
    $wingetDownloadPath = "${envTEMP}\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    Invoke-WebRequest `
      -Uri 'https://aka.ms/getwinget' `
      -OutFile $wingetDownloadPath `
      -UseBasicParsing
    return $wingetDownloadPath
  }

  $wingetPath = Download-WinGet
  Write-Host 'Download completato.'

  # verifica le dipendenze di WinGet...
  function Test-WinGetDependencies {
    $vclibsPackage = Get-AppxPackage Microsoft.VCLibs.140.00
    return $vclibsPackage
  }

  if ((Test-WinGetDependencies) -eq $null) {
    Write-Warning 'Installazione di dipendenze rilevata.'
  }

  # controllo dei pacchetti di dipendenza
  function Get-WinGetDependencyPath {
    param($dependencyName)

    return "${envTEMP}\${dependencyName}.msixbundle"
  }

  function Download-WinGetDependency {
    param(
      [string]$url,
      [string]$outFile
    )
    Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
  }

  function Register-WinGetDependency {
    param($dependencyPath)
    Add-AppxPackage -Path $dependencyPath
  }

  # scarica una dipendenza per WinGet...
  $vclibsPath = Get-WinGetDependencyPath 'Microsoft.VCLibs'
  Download-WinGetDependency `
    -Url 'https://aka.ms/Microsoft.VCLibs' `
    -OutFile $vclibsPath

  Write-Host 'Dipendenze scaricate.'
  Register-WinGetDependency $vclibsPath

  # verifica se il pacchetto è uiXaml
  function Test-UIXamlDependency {
    Get-AppxPackage -Name Microsoft.UI.Xaml
  }

  if ((Test-UIXamlDependency) -eq $null) {
    Write-Host 'Dipendenze aggiuntive rilevate.'
  }
}

# Esegui la funzione se questo script è stato richiamato direttamente
if ($MyInvocation.InvocationName -eq '.') {
  Install-WinGet
}
