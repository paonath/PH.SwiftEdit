# Workflow 02: Author Unit & Theory Tests (`xunit-testing`)

## Core Rules — Naming, AAA, Determinism & Data-Driven Testing

### 1. Test Naming
- Use `Verb_Scenario_ExpectedResult` for all test methods (see [naming-conventions.md](../../references/naming-conventions.md)).
- Keep method names specific enough to understand behavior without opening production code.
- Use `Fact` for a single scenario; use `Theory` for data variation.

### 2. AAA Structure
- Keep explicit `Arrange`, `Act`, `Assert` sections in each test, testing one behavioral intent per method.

### 3. Determinism & Data-Driven Rules
- Use unique seeded data per test, await async flows fully, and avoid execution-order coupling, global mutable state, or time flakiness.
- Use `InlineData` for small static datasets, `MemberData` for computed or larger datasets, and `ClassData` for complex datasets.
- Keep parameter names explicit and consult [patterns.md](../../references/patterns.md) on demand.

## Behavioral Requirements

- The xunit-testing unit workflow SHALL name every test method using Verb_Scenario_ExpectedResult with explicit Arrange, Act, and Assert sections.
- WHEN testing data variations of one behavioral rule, the xunit-testing unit workflow SHALL author Theory tests with InlineData, MemberData, or ClassData.
- IF a test exhibits shared mutable state, unawaited async calls, or order dependency, THEN the xunit-testing unit workflow SHALL refactor it to use unique per-test seeded data.

## Pattern Templates (Unit & Theory)

### Pattern A: Unit Test

```csharp
public sealed class CalculatorTests
{
    [Fact]
    public void Add_WithTwoPositiveNumbers_ReturnsSum()
    {
        // Arrange
        var sut = new Calculator();

        // Act
        var result = sut.Add(2, 3);

        // Assert
        Assert.Equal(5, result);
    }
}
```

### Pattern B: Data-Driven Theory Test

```csharp
public sealed class EmailValidatorTests
{
    [Theory]
    [InlineData("user@example.com", true)]
    [InlineData("invalid", false)]
    [InlineData("", false)]
    public void Validate_WithVariousInputs_ReturnsExpected(string input, bool expected)
    {
        // Arrange
        var sut = new EmailValidator();

        // Act
        var result = sut.IsValid(input);

        // Assert
        Assert.Equal(expected, result);
    }
}
```
