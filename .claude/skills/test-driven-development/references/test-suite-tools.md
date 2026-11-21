# Testing Tools Catalog (`dotnet-test-suite` plugin)

Load the `dotnet-test-suite` plugin when testing infrastructure analysis, execution command derivation, or quality planning is required.

## Polyglot & Language-Agnostic Skills
- `dotnet-test-suite__assertion-quality`: Evaluates assertion depth and variety to detect shallow tests relying only on presence or truthiness checks.
- `dotnet-test-suite__test-anti-patterns`: Audits test suites for common anti-patterns such as missing assertions, swallowed exceptions, and flaky sleeps.
- `dotnet-test-suite__test-smell-detection`: Performs deep audits against the 19 academic test smells from research literature.
- `dotnet-test-suite__test-gap-analysis`: Uncovers blind spots and untested boundary conditions using pseudo-mutations.
- `dotnet-test-suite__test-tagging`: Categorizes test methods with standardized traits (`smoke`, `regression`, `boundary`, `critical-path`).
- `dotnet-test-suite__find-untested-sources`: Maps source files to test files and locates untested modules using AST analysis.
- `dotnet-test-suite__code-testing-agent`: Orchestrates full test generation pipelines across any language.
- `test-quality-auditor`: Runs comprehensive multi-skill test suite quality assessments.

## .NET-Specific Skills & Agents
- `dotnet-test-suite__run-tests`: Auto-detects test platform (VSTest vs Microsoft.Testing.Platform) and framework (MSTest, xUnit, NUnit, TUnit) to execute `dotnet test` with exact filter syntax.
- `dotnet-test-suite__mtp-hot-reload`: Iterates on failing tests without rebuilding via Microsoft Testing Platform hot reload.
- `dotnet-test-suite__scaffold-dotnet-test-project`: Creates and registers the initial test project when none exists in the solution.
- `dotnet-test-suite__writing-mstest-tests`: Guides MSTest 3.x/4.x test authoring, modern assertion APIs, and lifecycle conventions.
- `dotnet-test-suite__detect-static-dependencies`: Scans C# source code for hard-to-test static dependencies (`DateTime.Now`, `File.*`, `Environment.*`).
- `dotnet-test-suite__generate-testability-wrappers`: Creates wrapper abstractions or guides adoption of `TimeProvider` and `IFileSystem`.
- `dotnet-test-suite__migrate-static-to-wrapper`: Migrates static call sites to injected abstractions across files or namespaces.
- `dotnet-test-suite__testability-obstacle`: Resolves ambient dependency blockers with deterministic in-memory implementations.
- `dotnet-test-suite__coverage-analysis`: Collects project-wide code coverage and identifies CRAP score risk hotspots.
- `dotnet-test-suite__crap-score`: Calculates targeted CRAP scores for individual C# methods or classes.
- `testability-migration`: Orchestrates end-to-end static dependency decoupling and deterministic test addition.
