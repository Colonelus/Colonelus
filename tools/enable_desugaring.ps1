$ErrorActionPreference = "Stop"
$root = Get-Location

function ReadUtf8([string]$p) { return Get-Content -Path $p -Raw -Encoding UTF8 }
function WriteUtf8([string]$p, [string]$c) { Set-Content -Path $p -Value $c -Encoding UTF8 }

$gradleGroovy = Join-Path $root "android\app\build.gradle"
$gradleKts    = Join-Path $root "android\app\build.gradle.kts"

if (Test-Path $gradleGroovy) {
  $p = $gradleGroovy
  $c = ReadUtf8 $p

  if ($c -notmatch "coreLibraryDesugaringEnabled\s+true") {
    if ($c -match "compileOptions\s*\{") {
      $c = [regex]::Replace($c, "compileOptions\s*\{", "compileOptions {`r`n            coreLibraryDesugaringEnabled true", 1)
    } else {
      if ($c -match "android\s*\{") {
        $c = [regex]::Replace($c, "android\s*\{", "android {`r`n    compileOptions {`r`n        sourceCompatibility JavaVersion.VERSION_1_8`r`n        targetCompatibility JavaVersion.VERSION_1_8`r`n        coreLibraryDesugaringEnabled true`r`n    }", 1)
      }
    }
  }

  if ($c -notmatch "coreLibraryDesugaring\s+'com\.android\.tools:desugar_jdk_libs:") {
    if ($c -match "dependencies\s*\{") {
      $c = [regex]::Replace($c, "dependencies\s*\{", "dependencies {`r`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'", 1)
    } else {
      $c = $c + "`r`n`r`ndependencies {`r`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'`r`n}`r`n"
    }
  }

  if ($c -match "minSdkVersion\s+(\d+)") {
    $ms = [int]$Matches[1]
    if ($ms -lt 21) {
      $c = [regex]::Replace($c, "minSdkVersion\s+\d+", "minSdkVersion 21", 1)
    }
  } elseif ($c -match "minSdk\s*=\s*(\d+)") {
    $ms = [int]$Matches[1]
    if ($ms -lt 21) {
      $c = [regex]::Replace($c, "minSdk\s*=\s*\d+", "minSdk = 21", 1)
    }
  }

  WriteUtf8 $p $c
  Write-Host "Updated: $p"
  exit 0
}

if (Test-Path $gradleKts) {
  $p = $gradleKts
  $c = ReadUtf8 $p

  if ($c -notmatch "isCoreLibraryDesugaringEnabled\s*=\s*true") {
    if ($c -match "compileOptions\s*\{") {
      $c = [regex]::Replace($c, "compileOptions\s*\{", "compileOptions {`r`n            isCoreLibraryDesugaringEnabled = true", 1)
    } else {
      if ($c -match "android\s*\{") {
        $c = [regex]::Replace($c, "android\s*\{", "android {`r`n    compileOptions {`r`n        sourceCompatibility = JavaVersion.VERSION_1_8`r`n        targetCompatibility = JavaVersion.VERSION_1_8`r`n        isCoreLibraryDesugaringEnabled = true`r`n    }", 1)
      }
    }
  }

  if ($c -notmatch "coreLibraryDesugaring\(\"com\.android\.tools:desugar_jdk_libs:") {
    if ($c -match "dependencies\s*\{") {
      $c = [regex]::Replace($c, "dependencies\s*\{", "dependencies {`r`n    coreLibraryDesugaring(\"com.android.tools:desugar_jdk_libs:2.0.4\")", 1)
    } else {
      $c = $c + "`r`n`r`ndependencies {`r`n    coreLibraryDesugaring(\"com.android.tools:desugar_jdk_libs:2.0.4\")`r`n}`r`n"
    }
  }

  if ($c -match "minSdk\s*=\s*(\d+)") {
    $ms = [int]$Matches[1]
    if ($ms -lt 21) {
      $c = [regex]::Replace($c, "minSdk\s*=\s*\d+", "minSdk = 21", 1)
    }
  } elseif ($c -match "minSdkVersion\s*\(\s*(\d+)\s*\)") {
    $ms = [int]$Matches[1]
    if ($ms -lt 21) {
      $c = [regex]::Replace($c, "minSdkVersion\s*\(\s*\d+\s*\)", "minSdkVersion(21)", 1)
    }
  }

  WriteUtf8 $p $c
  Write-Host "Updated: $p"
  exit 0
}

throw "android\app\build.gradle veya android\app\build.gradle.kts bulunamadı. Komutu proje kökünden (pubspec.yaml olan yerden) çalıştır."
