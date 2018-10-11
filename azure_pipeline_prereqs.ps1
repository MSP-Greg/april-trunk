<#                  azure_pipeline_prereqs_mingw.ps1
Code by MSP-Greg
Azure Pipeline mingw build 'Build variable' setup and prerequisite items:
ruby, 7zip, msys2/mingw system
#>

$cd      = $pwd
$path    = $env:path
$src     = $env:BUILD_SOURCESDIRECTORY
$drv     = (get-location).Drive.Name + ":"
$root    = [System.IO.Path]::GetFullPath("$src\..")
$dl_path = "$root\prereq"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$wc  = $(New-Object System.Net.WebClient)

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$base_path = "$env:SystemRoot\system32;$env:SystemRoot;$env:SystemRoot\System32\Wbem"

$7z_file = "7zip_ci.zip"
$7z_uri  = "https://dl.bintray.com/msp-greg/VC-OpenSSL/7zip_ci.zip"

$ruby_file = "ruby_trunk.7z"
$ruby_uri  = "https://ci.appveyor.com/api/projects/MSP-Greg/ruby-loco/artifacts"

# put all downloaded items in this folder
New-Item -Path $dl_path -ItemType Directory 1> $null

# make a temp folder on $drv
$tmpdir_w = "$root\temp"
$tmpdir   = "$root/temp"
New-Item  -Path $tmpdir_w -ItemType Directory 1> $null
(Get-Item -Path $tmpdir_w).Attributes = 'Normal'

#—————————————————————————————————————————————————————————————————————————  7Zip
$wc.DownloadFile($7z_uri, "$dl_path/$7z_file")
Expand-Archive -Path "$dl_path/$7z_file" -DestinationPath "$drv/7zip"
$env:path = "$drv/7zip;$base_path"
Write-Host "7zip installed"

#—————————————————————————————————————————————————————————————————————————  Ruby
$fp  = "$dl_path/$ruby_file"
$uri = "$ruby_uri/$ruby_file"
$wc.DownloadFile($uri, $fp)
$dir = "-o$src\install"
7z.exe x $fp $dir 1> $null
$env:ruby_path = "$src\install"
Write-Host "Ruby installed"
$env:path = "$src/install/bin;$env:path"
ruby -v

#——————————————————————————————————————————————————————————————————  MSYS2/MinGW
# updated 2018-10-01
$file      = "msys2-base-x86_64-20180531.tar"
$msys2_uri = "http://repo.msys2.org/distrib/x86_64"

$dir1 = "-o$dl_path"

Write-Host "Downloading $file"
$fp = "$dl_path\$file" + ".xz"
$uri = "$msys2_uri/$file" + ".xz"
$wc.DownloadFile($uri, $fp)
Write-Host "Processing $file"
7z.exe x $fp $dir1 1> $null
$fp = "$dl_path/$file"
$dir2 = "-o$src"
7z.exe x $fp $dir2 1> $null
Remove-Item $dl_path\*.*

$env:path =  "$drv\ruby\bin;$src\msys64\usr\bin;$drv\git\cmd;$env:path"

if ($env:PLATFORM -eq 'x64') {
  $march = "x86-64" ; $carch = "x86_64" ; $rarch = "x64-mingw32"  ; $mingw = "mingw64"
} else {
  $march = "i686"   ; $carch = "i686"   ; $rarch = "i386-mingw32" ; $mingw = "mingw32"
}
$chost   = "$carch-w64-mingw32"

$pre = "mingw-w64-$carch-"

$tools =  "___gdbm ___gmp ___ncurses ___openssl ___readline".replace('___', $pre)

bash.exe -c `"pacman-key --init`"
bash.exe -c `"pacman-key --populate msys2`"
bash.exe -c `"pacman-key --refresh-keys`"

$dash = "-"

Write-Host "$($dash * 78)  pacman.exe -Syu"
try   { pacman.exe -Syu --noconfirm --needed --noprogressbar 2> $null } catch {}
Write-Host "$($dash * 78)  pacman.exe -Su"
try   { pacman.exe -Su  --noconfirm --needed --noprogressbar 2> $null } catch {}
Write-Host "$($dash * 78)  pacman.exe -S base base-devel compression"
try   { pacman.exe -S   --noconfirm --needed --noprogressbar base base-devel compression 2> $null }
catch {}
Write-Host "$($dash * 78)  pacman.exe -S toolchain"
try   { pacman.exe -S   --noconfirm --needed --noprogressbar $($pre + 'toolchain') 2> $null }
catch {}
Write-Host "$($dash * 78)  pacman.exe -S ruby depends"
try   { pacman.exe -S   --noconfirm --needed --noprogressbar $tools.split(' ') 2> $null }
catch {}

$env:path = $path
