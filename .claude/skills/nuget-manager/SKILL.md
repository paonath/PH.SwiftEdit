---
name: nuget-manager
description: 'Manage NuGet packages in .NET projects/solutions. Use this skill when adding, removing, or updating NuGet package versions. It enforces using `dotnet` CLI for package management and provides strict procedures for direct file edits only when updating versions.'
---

# NuGet Manager

## Overview

Ensure consistent NuGet package management across .NET solutions using the `dotnet` CLI for additions and removals and strict verification before version edits.
Prerequisites: .NET 8.0+ SDK, `dotnet` CLI on `PATH`, and `jq` or PowerShell for JSON parsing.

## Core Rules

- The nuget-manager skill SHALL execute dotnet add package and dotnet remove package for all package additions and removals.
- WHEN updating an existing package version, the nuget-manager skill SHALL verify version existence via dotnet package search before editing project files.
- WHERE Directory.Packages.props exists at the solution root, the nuget-manager skill SHALL update PackageVersion elements centrally instead of individual .csproj files.
- IF a direct file edit attempts to add or remove a package, THEN the nuget-manager skill SHALL reject the edit and require dotnet CLI commands.
- IF dotnet restore fails after a version update, THEN the nuget-manager skill SHALL revert the version change and investigate.

## Workflows

### Adding and Removing Packages

- **Add**: `dotnet add [<PROJECT>] package <PACKAGE_NAME> [--version <VERSION>]` (example: `dotnet add src/WebApi/WebApi.csproj package Serilog`).
- **Remove**: `dotnet remove [<PROJECT>] package <PACKAGE_NAME>` (example: `dotnet remove src/MyProject/MyProject.csproj package Newtonsoft.Json`).

### Updating Package Versions

1. **Verify Version Existence** using exact-match JSON search:
   - `jq`: `dotnet package search <PACKAGE_NAME> --exact-match --format json | jq -e '.searchResult[].packages[] | select(.version == "<VERSION>")'`
   - PowerShell: `(dotnet package search <PACKAGE_NAME> --exact-match --format json | ConvertFrom-Json).searchResult.packages | Where-Object { $_.version -eq "<VERSION>" }`
2. **Locate Version File**: Edit `<PackageVersion Include="Package.Name" Version="1.2.3" />` in `Directory.Packages.props` if present at the solution root; otherwise edit `<PackageReference Include="Package.Name" Version="1.2.3" />` in `.csproj`.
3. **Apply and Restore**: Update the version string in the identified file and immediately run `dotnet restore`.

## Behavioral Scenarios

```gherkin
Feature: Safe NuGet Package Management
  @REQ-NUGET-001
  Scenario: Add and centrally update a verified NuGet package
    Given a .NET solution managing versions in Directory.Packages.props
    When the developer adds Serilog and updates Newtonsoft.Json to verified version 13.0.3
    Then the nuget-manager skill runs dotnet add package and updates PackageVersion centrally
    And verifies dependency graph stability with dotnet restore

  @REQ-NUGET-002
  Scenario: Reject direct file edits for package removal
    Given a .NET project file managed inside the solution
    When a user attempts to remove a package by editing the .csproj file directly
    Then the nuget-manager skill blocks the direct file edit
    And requires execution through dotnet remove package
```
