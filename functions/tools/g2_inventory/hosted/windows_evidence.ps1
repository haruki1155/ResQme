param([Parameter(Mandatory=$true)][string]$LiteralDirectory)
$ErrorActionPreference = 'Stop'
try {
  if ($LiteralDirectory -notmatch '^[A-Za-z]:\\' -or $LiteralDirectory.StartsWith('\\')) { throw 'unsupported' }
  $item = Get-Item -LiteralPath $LiteralDirectory -Force
  if (-not $item.PSIsContainer) { throw 'unsupported' }
  $safe = $true
  $outsideGit = $true
  $walk = $item
  while ($null -ne $walk) {
    # Reparse, Offline, RecallOnOpen, RecallOnDataAccess.
    if (([int64]$walk.Attributes -band 0x441400) -ne 0) { $safe = $false }
    if (Test-Path -LiteralPath (Join-Path $walk.FullName '.git')) { $outsideGit = $false }
    $walk = $walk.Parent
  }
  foreach ($sync in @($env:OneDrive,$env:OneDriveCommercial,$env:OneDriveConsumer)) {
    if ($sync -and ($item.FullName.Equals($sync,[StringComparison]::OrdinalIgnoreCase) -or $item.FullName.StartsWith($sync.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase))) { $safe=$false }
  }
  $drive = New-Object System.IO.DriveInfo($item.PSDrive.Root)
  $letter = $drive.Name.Substring(0,2)
  $volume = Get-CimInstance Win32_Volume -Filter "DriveLetter='$letter'"
  if ($null -eq $volume -or $volume.DriveType -ne 3 -or $volume.FileSystem -ne 'NTFS') { throw 'unsupported' }
  $acl = Get-Acl -LiteralPath $item.FullName
  $raw = New-Object System.Security.AccessControl.RawSecurityDescriptor($acl.Sddl)
  $aces = @($raw.DiscretionaryAcl | ForEach-Object {
    $simple = $_ -is [System.Security.AccessControl.CommonAce] -and -not $_.IsCallback -and (([int]$_.AceFlags -band 8) -eq 0)
    @{sid=$_.SecurityIdentifier.Value;allow=($_.AceType -eq [System.Security.AccessControl.AceType]::AccessAllowed);simple=$simple;rights=[string]$_.AccessMask}
  })
  @{platform='win32';filesystem=$drive.DriveFormat;fixed=($drive.DriveType -eq [System.IO.DriveType]::Fixed);canonical=$item.FullName;ownerSid=$raw.Owner.Value;safePath=$safe;outsideGit=$outsideGit;protected=$acl.AreAccessRulesProtected;aces=$aces} | ConvertTo-Json -Depth 5 -Compress
} catch { Write-Error 'evidence_inspection_failed'; exit 1 }
