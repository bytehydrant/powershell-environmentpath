﻿using namespace System;

#Safety net
[bool]$TESTMODE = ("TESTMODE" -eq $args[0]) -or ($Host.Name -eq "Visual Studio Code Host")
[string]$DefaultEnvironmentVariable = if ($TESTMODE) { "TEST_PATH" } else { "PATH" }

class VariableNotFoundException : Exception { }

function Add-EnvPath() {
    Param (
        [Parameter(Position = 0)]
        [ValidateScript( { Test-Path $_ })]
        [string] $Path = (Get-Location).Path,
        [string] $EnvironmentVariable = $DefaultEnvironmentVariable,
        [switch] $Force = $false
    )

    if (((Get-EnvPath $EnvironmentVariable) | Where-Object { $_.Path -eq $Path }).count -ne 0) {
        throw "The current environment path already contains '" + $Path + "'"
    }

    if (!$Force) {
        $prompt = $Host.UI.PromptForChoice("This operation will globally modify the $EnvironmentVariable environment variable for the current user.", "Continue?", ("&Yes", "&No"), 1)
        if ($prompt -eq 1) {
            return
        }
    }

    $newPath = (getTrimmedPath -envvar $EnvironmentVariable -scope User) + ";" + $Path
    setEnvironmentVariable $EnvironmentVariable $newPath [EnvironmentVariableTarget]::User
    Update-EnvPath
    New-Object PSObject -Property @{Path = $Path; Scope = "User" }
}

function Get-EnvPath {
    Param (
        [string] $EnvironmentVariable = $DefaultEnvironmentVariable
    )

    $allScopes = @([EnvironmentVariableTarget]::Machine, [EnvironmentVariableTarget]::User, [EnvironmentVariableTarget]::Process)
    $exceptionCount = 0
    $allScopes | ForEach-Object {
        try {
            getPathArray -envvar $EnvironmentVariable -scope $_
        }
        catch [VariableNotFoundException] {
            $exceptionCount++
            if(!$firstException) {
                $firstException = $_
            }
        }
    }
    
    if ($exceptionCount -eq $allScopes.Count) {
        throw $firstException
    }
}

function Update-EnvPath {
    Param (
        [string] $EnvironmentVariable = $DefaultEnvironmentVariable
    )

    $machine = getTrimmedPath -envvar $EnvironmentVariable -scope Machine
    $user = getTrimmedPath -envvar $EnvironmentVariable -scope User
    $process = getTrimmedPath -envvar $EnvironmentVariable -scope Process
    $newpath = ($machine + ';' + $user + ';' + $process).trim(';');
    setEnvironmentVariable $EnvironmentVariable $newpath [EnvironmentVariableTarget]::Process
    Set-Item -Path Env:$EnvironmentVariable -Value $newpath
}

function getTrimmedPath {
    Param (
        [Parameter(Mandatory = $true)][string]$envvar, 
        [Parameter(Mandatory = $true)][EnvironmentVariableTarget]$scope
    )
    (getVariable -envvar $envvar -scope $scope).trim(";")
}

function getPathArray {
    Param (
        [Parameter(Mandatory = $true)][string]$envvar, 
        [Parameter(Mandatory = $true)][EnvironmentVariableTarget]$scope
    )
    (getTrimmedPath -envvar $EnvironmentVariable -scope $scope) -split ';' | ForEach-Object { New-Object PSObject -Property @{Path = $_; Scope = $scope } } 
}

function getVariable {
    Param (
        [Parameter(Mandatory = $true)][string]$envvar, 
        [Parameter(Mandatory = $true)][EnvironmentVariableTarget]$scope
    )

    $var = getEnvironmentVariable $envvar $scope
    if (!$var) {
        throw [VariableNotFoundException]::new()
    }
    $var
}

function setEnvironmentVariable {
    Param(
        [string]$EnvironmentVariable,
        [string]$Value,
        [EnvironmentVariableTarget]$Scope
    )
    [Environment]::SetEnvironmentVariable($EnvironmentVariable, $Value, $Scope)
}

function getEnvironmentVariable {
    Param(
        [string]$EnvironmentVariable,
        [EnvironmentVariableTarget]$Scope
    )
    [Environment]::GetEnvironmentVariable($EnvironmentVariable, $Scope)
}

if (!$TESTMODE) {
    Export-ModuleMember -Function Add-EnvPath, Get-EnvPath
}