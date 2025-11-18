# Build Script for Vue Rivue
# Handles building, bundling, and optimizing the Rivue

param(
    [switch]$Bundle,      # Create optimized bundle with darklua
    [switch]$Clean,       # Clean build directory before building
    [switch]$SkipTests,   # Skip running tests before build
    [switch]$All          # Build all variants (rbxl, rbxm, bundle)
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Vue Rivue Build Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Clean build directory if requested
if ($Clean) {
    Write-Host "[1/5] Cleaning build directory..." -ForegroundColor Yellow
    if (Test-Path "build") {
        Remove-Item -Path "build" -Recurse -Force
        Write-Host "  ✓ Build directory cleaned" -ForegroundColor Green
    } else {
        Write-Host "  ℹ Build directory doesn't exist, skipping" -ForegroundColor Gray
    }
} else {
    Write-Host "[1/5] Skipping clean (use -Clean to clean build directory)" -ForegroundColor Gray
}

# Create build directory
Write-Host ""
Write-Host "[2/5] Setting up build directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "build" | Out-Null
Write-Host "  ✓ Build directory ready" -ForegroundColor Green

# Run tests unless skipped
if (-not $SkipTests) {
    Write-Host ""
    Write-Host "[3/5] Running tests..." -ForegroundColor Yellow
    & ".\scripts\run-tests.ps1" -Build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Tests failed! Build aborted." -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ All tests passed" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[3/5] Skipping tests (use without -SkipTests to run)" -ForegroundColor Gray
}

# Generate sourcemap for darklua
Write-Host ""
Write-Host "[4/5] Generating Rojo sourcemap..." -ForegroundColor Yellow
rojo sourcemap default.project.json --output sourcemap.json
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Sourcemap generated: sourcemap.json" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to generate sourcemap" -ForegroundColor Red
    exit 1
}

# Build variants
Write-Host ""
Write-Host "[5/5] Building Rivue..." -ForegroundColor Yellow

# Build rbxl place file
if ($All -or -not $Bundle) {
    Write-Host "  Building place file (rbxl)..." -ForegroundColor Cyan
    rojo build default.project.json -o build/vue-Rivue.rbxl
    if ($LASTEXITCODE -eq 0) {
        $size = (Get-Item "build/vue-Rivue.rbxl").Length / 1KB
        Write-Host "  ✓ Place file built: build/vue-Rivue.rbxl ($("{0:N2}" -f $size) KB)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to build place file" -ForegroundColor Red
        exit 1
    }
}

# Build rbxm model file
if ($All) {
    Write-Host "  Building model file (rbxm)..." -ForegroundColor Cyan
    rojo build default.project.json -o build/VueRivue.rbxm
    if ($LASTEXITCODE -eq 0) {
        $size = (Get-Item "build/VueRivue.rbxm").Length / 1KB
        Write-Host "  ✓ Model file built: build/VueRivue.rbxm ($("{0:N2}" -f $size) KB)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to build model file" -ForegroundColor Red
        exit 1
    }
}

# Create optimized bundle with darklua
if ($Bundle -or $All) {
    Write-Host "  Creating optimized bundle with darklua..." -ForegroundColor Cyan
    
    # Create bundle directory
    New-Item -ItemType Directory -Force -Path "build/bundle" | Out-Null
    
    # Process with darklua
    darklua process src/shared/Rivue build/bundle/Rivue --config .darklua.json
    
    if ($LASTEXITCODE -eq 0) {
        # Count files and calculate total size
        $files = Get-ChildItem -Path "build/bundle" -Recurse -File
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum / 1KB
        
        Write-Host "  ✓ Bundle created: build/bundle/ ($($files.Count) files, $("{0:N2}" -f $totalSize) KB)" -ForegroundColor Green
        Write-Host "    - Optimizations: remove_comments, convert_require (Roblox mode), compute_expression" -ForegroundColor Gray
        Write-Host "    - Require mode: Roblox (WaitForChild indexing)" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ Failed to create bundle" -ForegroundColor Red
        exit 1
    }
}

# Summary
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Build Complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Build artifacts:" -ForegroundColor White
if ($All -or -not $Bundle) {
    Write-Host "  • build/vue-Rivue.rbxl (Roblox place file)" -ForegroundColor Gray
}
if ($All) {
    Write-Host "  • build/VueRivue.rbxm (Roblox model file)" -ForegroundColor Gray
}
if ($Bundle -or $All) {
    Write-Host "  • build/bundle/ (Optimized source bundle)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  • Open build/vue-Rivue.rbxl in Roblox Studio" -ForegroundColor Gray
Write-Host "  • Publish to Roblox.com or use in your game" -ForegroundColor Gray
if ($Bundle -or $All) {
    Write-Host "  • Use build/bundle/ for manual integration" -ForegroundColor Gray
}
Write-Host ""

# Examples section
Write-Host "Examples:" -ForegroundColor Yellow
Write-Host "  .\scripts\build.ps1                    # Build place file only" -ForegroundColor Gray
Write-Host "  .\scripts\build.ps1 -Bundle            # Create optimized bundle only" -ForegroundColor Gray
Write-Host "  .\scripts\build.ps1 -All               # Build all variants" -ForegroundColor Gray
Write-Host "  .\scripts\build.ps1 -Clean -All        # Clean build + build all" -ForegroundColor Gray
Write-Host "  .\scripts\build.ps1 -SkipTests -Bundle # Bundle without running tests" -ForegroundColor Gray
Write-Host ""
