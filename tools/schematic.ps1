# Draws a schematic of the top module in tools/schematic.ys: Yosys netlist -> ELK layout -> docs/<top>_netlist.svg
# Usage (from anywhere):  powershell -ExecutionPolicy Bypass -File tools/schematic.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)   # run from the repository root: all paths below are relative to it

# Find Yosys (OSS CAD Suite) if it is not already on the PATH
if (-not (Get-Command yosys -ErrorAction SilentlyContinue)) {
    foreach ($root in @('C:\oss-cad-suite', "$HOME\oss-cad-suite")) {
        if (Test-Path "$root\bin\yosys.exe") { $env:PATH = "$root\bin;$root\lib;$env:PATH"; break }
    }
}

yosys -q tools/schematic.ys
if ($LASTEXITCODE -ne 0) { throw 'Yosys failed' }

# One-time install of the ELK layout engine into tools/node_modules
if (-not (Test-Path 'tools/node_modules/elkjs')) {
    npm install --prefix tools --no-save --no-package-lock elkjs
    if ($LASTEXITCODE -ne 0) { throw 'npm install elkjs failed' }
}

# Output is named after the top module set in tools/schematic.ys (hierarchy -top <module>)
$top = (Select-String -Path tools/schematic.ys -Pattern 'hierarchy\s+-top\s+(\S+)').Matches[0].Groups[1].Value
node tools/schematic_modern.js cpu.json "docs/${top}_netlist.svg"
if ($LASTEXITCODE -ne 0) { throw 'schematic_modern.js failed' }

Remove-Item cpu.json -ErrorAction SilentlyContinue
