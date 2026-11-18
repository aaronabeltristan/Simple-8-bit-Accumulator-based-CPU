# Draws the CPU schematic: Yosys netlist -> ELK layout -> docs/cpu_netlist.svg
# Usage:  powershell -ExecutionPolicy Bypass -File schematic.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Find Yosys (OSS CAD Suite) if it is not already on the PATH
if (-not (Get-Command yosys -ErrorAction SilentlyContinue)) {
    foreach ($root in @('C:\oss-cad-suite', "$HOME\oss-cad-suite")) {
        if (Test-Path "$root\bin\yosys.exe") { $env:PATH = "$root\bin;$root\lib;$env:PATH"; break }
    }
}

yosys -q schematic.ys
if ($LASTEXITCODE -ne 0) { throw 'Yosys failed' }

# One-time install of the ELK layout engine into tools/node_modules
if (-not (Test-Path 'tools/node_modules/elkjs')) {
    npm install --prefix tools --no-save --no-package-lock elkjs
    if ($LASTEXITCODE -ne 0) { throw 'npm install elkjs failed' }
}

node tools/schematic_modern.js cpu.json docs/cpu_netlist.svg
if ($LASTEXITCODE -ne 0) { throw 'schematic_modern.js failed' }

Remove-Item cpu.json -ErrorAction SilentlyContinue
