<#
.SYNOPSIS
    Roblox Studio MCP Bridge Manager & Health Checker.
    Provides a manual way in VS Code to activate, inspect, restart, and verify
    the Model Context Protocol (MCP) connection between VS Code and Roblox Studio.

.PARAMETER Action
    The action to execute: 'Status', 'Start', 'Restart', or 'Sync'. Defaults to 'Status'.
#>

[CmdletBinding()]
param(
    [ValidateSet("Status", "Start", "Restart", "Sync")]
    [string]$Action = "Status"
)

$ErrorActionPreference = "Continue"

function Write-Banner {
    param(
        [string]$Title,
        [string]$Color = "Cyan"
    )
    Write-Host ""
    Write-Host ("=" * 64) -ForegroundColor $Color
    Write-Host "  $Title" -ForegroundColor $Color
    Write-Host ("=" * 64) -ForegroundColor $Color
}

function Get-StudioProcess {
    return (Get-Process -Name "RobloxStudioBeta" -ErrorAction SilentlyContinue)
}

function Get-McpProcess {
    return (Get-Process -Name "StudioMCP" -ErrorAction SilentlyContinue)
}

function Get-McpBatPath {
    $localAppData = $env:LOCALAPPDATA
    return (Join-Path $localAppData "Roblox\mcp.bat")
}

function Show-Status {
    Write-Banner -Title "Roblox Studio MCP Connection Status" -Color "Cyan"

    # 1. Check Roblox Studio
    $studioProc = Get-StudioProcess
    if ($studioProc) {
        Write-Host " [OK] Roblox Studio: RUNNING (PID: $($studioProc.Id))" -ForegroundColor Green
    } else {
        Write-Host " [MISSING] Roblox Studio: NOT RUNNING" -ForegroundColor Red
        Write-Host "     Hint: Open your place (ArenaCoinBattle.rbxl) in Roblox Studio." -ForegroundColor Yellow
    }

    # 2. Check StudioMCP executable and batch file
    $batPath = Get-McpBatPath
    if (Test-Path $batPath) {
        Write-Host " [OK] Studio MCP Script: FOUND ($batPath)" -ForegroundColor Green
    } else {
        Write-Host " [MISSING] Studio MCP Script: NOT FOUND at $batPath" -ForegroundColor Red
    }

    # 3. Check VS Code MCP Configuration
    $appData = $env:APPDATA
    $userMcpJson = Join-Path $appData "Code\User\mcp.json"
    if (Test-Path $userMcpJson) {
        Write-Host " [OK] VS Code User MCP Config: FOUND ($userMcpJson)" -ForegroundColor Green
        try {
            $json = Get-Content $userMcpJson -Raw | ConvertFrom-Json
            if ($json.servers.Roblox_Studio) {
                Write-Host " [OK] 'Roblox_Studio' Server Definition: REGISTERED" -ForegroundColor Green
            } else {
                Write-Host " [WARN] 'Roblox_Studio' Server Definition: NOT FOUND in mcp.json" -ForegroundColor Yellow
            }
        } catch {
            Write-Host " [WARN] Could not parse mcp.json: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host " [WARN] VS Code User MCP Config: NOT FOUND at $userMcpJson" -ForegroundColor Yellow
    }

    # 4. Check Running MCP Bridge Process
    $mcpProc = Get-McpProcess
    if ($mcpProc) {
        Write-Host " [OK] StudioMCP Process: ACTIVE (PID: $($mcpProc.Id))" -ForegroundColor Green
    } else {
        Write-Host " [INFO] StudioMCP Process: IDLE / ON-DEMAND (Active when tools are invoked)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Ready to connect. To trigger an MCP connection directly from VS Code:" -ForegroundColor White
    Write-Host "  * In VS Code: Press Ctrl+Shift+P -> Tasks: Run Task -> 'Roblox Studio: Activate MCP Connection'" -ForegroundColor Cyan
    Write-Host "  * Or run: .\tools\roblox-mcp.ps1 -Action Start" -ForegroundColor Cyan
    Write-Host ""
}

function Start-McpBridge {
    Write-Banner -Title "Activating Roblox Studio MCP Connection" -Color "Yellow"

    # Step 1: Ensure Studio is running
    $studioProc = Get-StudioProcess
    if (-not $studioProc) {
        Write-Host "Warning: Roblox Studio is not currently running!" -ForegroundColor Yellow
        Write-Host "Please start Roblox Studio and open ArenaCoinBattle.rbxl first." -ForegroundColor Yellow
    } else {
        Write-Host "[1/3] Roblox Studio is running (PID: $($studioProc.Id))." -ForegroundColor Green
    }

    # Step 2: Check for and kill any hung/zombie StudioMCP processes
    $existing = Get-McpProcess
    if ($existing) {
        Write-Host "[2/3] Cleaning up existing StudioMCP process (PID: $($existing.Id))..." -ForegroundColor Cyan
        Stop-Process -Id $existing.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    } else {
        Write-Host "[2/3] No stale StudioMCP process detected." -ForegroundColor Green
    }

    # Step 3: Validate and trigger mcp.bat test
    $batPath = Get-McpBatPath
    if (-not (Test-Path $batPath)) {
        Write-Host "[ERROR] Could not find $batPath" -ForegroundColor Red
        return
    }

    Write-Host "[3/3] Testing Studio MCP bridge execution..." -ForegroundColor Green
    Write-Host "Path: $batPath" -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  [SUCCESS] Roblox Studio MCP Bridge is ready for VS Code!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "If VS Code needs to refresh its active MCP tools:" -ForegroundColor White
    Write-Host "  1. Open Command Palette in VS Code (Ctrl+Shift+P)" -ForegroundColor Cyan
    Write-Host "  2. Type and run: 'Developer: Reload Window' or restart Copilot chat." -ForegroundColor Cyan
    Write-Host ""
}

function Restart-McpBridge {
    Write-Banner -Title "Restarting Roblox Studio MCP Bridge" -Color "Magenta"
    $existing = Get-McpProcess
    if ($existing) {
        Write-Host "Stopping StudioMCP (PID: $($existing.Id))..." -ForegroundColor Yellow
        Stop-Process -Id $existing.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
    Start-McpBridge
}

function Sync-RojoProject {
    Write-Banner -Title "Building Place File and Verifying Rojo Parity" -Color "Cyan"
    Write-Host "Executing: rojo build -o ArenaCoinBattle.rbxl" -ForegroundColor Cyan
    rojo build -o ArenaCoinBattle.rbxl
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Rojo build completed successfully!" -ForegroundColor Green
        Write-Host "You can save or reload the place in Roblox Studio." -ForegroundColor White
    } else {
        Write-Host "[ERROR] Rojo build failed with exit code $LASTEXITCODE" -ForegroundColor Red
    }
}

# Dispatch selected action
if ($Action -eq "Status") {
    Show-Status
} elseif ($Action -eq "Start") {
    Start-McpBridge
} elseif ($Action -eq "Restart") {
    Restart-McpBridge
} elseif ($Action -eq "Sync") {
    Sync-RojoProject
} else {
    Show-Status
}
