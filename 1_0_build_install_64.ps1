<# Code by MSP-Greg
Script for building & installing MinGW Ruby for CI
Assumes a Ruby exe is in path
Assumes 'Git for Windows' is installed at $env:ProgramFiles\Git
Assumes '7z             ' is installed at $env:ProgramFiles\7-Zip
For local use, set items in local.ps1
#>

#————————————————————————————————————————————————————————————————— Apply-Patches
# Applies patches
function Apply-Patches($p_dir) {
  $patch_exe = "$d_msys2/usr/bin/patch.exe"
  Push-Location "$d_repo/$p_dir"
  [string[]]$patches = Get-ChildItem -Include *.patch -Path . -Recurse |
    select -expand name
  Pop-Location
  Push-Location "$d_ruby"
  foreach ($p in $patches) {
    if ($p.substring(0,2) -eq "__") { continue }
    Write-Host $($dash * 55) $p -ForegroundColor $fc
    & $patch_exe -p1 -N --no-backup-if-mismatch -i "$d_repo/$p_dir/$p"
  }
  Pop-Location
  Write-Host ''
}

#———————————————————————————————————————————————————————————————— Print-Time-Log
function Print-Time-Log {
  $diff = New-TimeSpan -Start $script:time_start -End $script:time_old
  $script:time_info += ("{0:mm}:{0:ss} {1}" -f @($diff, "Total"))

  Write-Host $($dash * 80) -ForegroundColor $fc
  Write-Host $script:time_info
  $fn = "$d_logs/time_log_build.log"
  [IO.File]::WriteAllText($fn, $script:time_info, $UTF8)
  if ($is_av) {
    Add-AppveyorMessage -Message "Time Log Build" -Details $script:time_info
  }
}

#—————————————————————————————————————————————————————————————————————— Time-Log
function Time-Log($msg) {
  if ($script:time_old) {
    $time_new = Get-Date
    $diff = New-TimeSpan -Start $time_old -End $time_new
    $script:time_old = $time_new
    $script:time_info += ("{0:mm}:{0:ss} {1}`n" -f @($diff, $msg))
  } else {
    $script:time_old   = Get-Date
    $script:time_start = $script:time_old
  }
}

#———————————————————————————————————————————————————————————————————— Basic Info
function Basic-Info {
  $env:path = "$d_install/bin;$base_path"
  Write-Host $($dash * 80) -ForegroundColor $fc
  ruby -v
  bundler version
  ruby -ropenssl -e "puts OpenSSL::OPENSSL_LIBRARY_VERSION"
  Write-Host "gem --version" $(gem --version)
  rake -V
  Write-Host "$($dash * 80)`n" -ForegroundColor $fc
}

#———————————————————————————————————————————————————————————————————— Check-Exit
# checks whether to exit
function Check-Exit($msg, $pop) {
  if ($LastExitCode -and $LastExitCode -ne 0) {
    if ($pop) { Pop-Location }
    Write-Line "Failed - $msg" -ForegroundColor $fc
    exit 1
  }
}

#———————————————————————————————————————————————————————————————— Create-Folders
# creates build, install, log, and git folders at same place as ruby repo folder
# most of the code is for local builds, as the folders should be cleaned

function Create-Folders {
  # reset to read/write
  (Get-Item $d_repo).Attributes = 'Normal'

  # Don't erase contents of log folder
  if (Test-Path -Path $d_logs    -PathType Container ) {
    Remove-Read-Only  $d_logs
  } else {
    New-Item    -Path $d_logs    -ItemType Directory 1> $null
  }

  # create git symlink, which RubyGems seems to want
  if (!(Test-Path -Path $d_repo/git -PathType Container )) {
        New-Item  -Path $d_repo/git -ItemType Junction -Value $d_git 1> $null
  }

  New-Item -Path $d_build   -ItemType Directory 1> $null
  New-Item -Path $d_install -ItemType Directory 1> $null
}

#——————————————————————————————————————————————————————————————————————————— Run
# Run a command and check for error
function Run($exec, $silent = $false) {
  Write-Line "$exec"
  if ($silent) { iex $exec -ErrorAction SilentlyContinue }
  else         { iex $exec }
  Check-Exit $exec
}

#————————————————————————————————————————————————————————————————— Set-Variables
# set base variables, including MSYS2 location and bit related varis
function Set-Variables-Local {
  $script:ruby_path = $(ruby.exe -e "puts RbConfig::CONFIG['bindir']").trim().replace('\', '/')
  $script:time_info = ''
  $script:time_old  = $null
  $script:time_start = $null
}

#——————————————————————————————————————————————————————————————————————— Set-Env
# Set ENV, including gcc flags
function Set-Env {
  $env:path = "$ruby_path;$d_mingw;$d_repo/git/cmd;$d_msys2/usr/bin;$base_path"

  # used in Ruby scripts
  $env:D_MSYS2  = $d_msys2

  $env:CFLAGS   = "-march=$march -mtune=generic -O3 -pipe"
  $env:CXXFLAGS = "-march=$march -mtune=generic -O3 -pipe"
  $env:CPPFLAGS = "-D_FORTIFY_SOURCE=2 -D__USE_MINGW_ANSI_STDIO=1 -DFD_SETSIZE=2048"
  $env:LDFLAGS  = "-pipe"
}

#——————————————————————————————————————————————————————————————————— start build
# defaults to 64 bit
$script:bits = if ($args.length -eq 1 -and $args[0] -eq 32) { 32 } else { 64 }

cd $d_repo

. ./0_common.ps1
Set-Variables
Set-Variables-Local
Set-Env

Apply-Patches "patches"

Create-Folders

# below sets some directories to normal in case they're set to read-only
Remove-Read-Only $d_ruby

#$eap = $ErrorActionPreference
#$ErrorActionPreference = 'continue'
#$ErrorActionPreference = $eap

cd $d_repo

Basic-Info

# apply patches for testing
Apply-Patches "patches_basic_boot"
Apply-Patches "patches_spec"
Apply-Patches "patches_test"
