#!/c/Windows/System32/WindowsPowerShell/v1.0/powershell

$FolderName = (Get-Item $PSScriptRoot).Name

New-Item -Path "$env:USERPROFILE\Zomboid\Workshop\$FolderName" -ItemType SymbolicLink -Value $PSScriptRoot

