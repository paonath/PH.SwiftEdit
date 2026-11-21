---
name: fluent-validator-generator
description: |
  Generates C# FluentValidation validators following best-practice layered patterns.
  Use when: (1) a user asks to create a validator for a request/DTO class,
  (2) a user says "generate validator for [Entity]Request",
  (3) adding a new service operation that needs input validation,
  (4) a user asks "how do I validate with FluentValidation in this project",
  (5) asked to add role-based or auth validation to an operation.
---

# FluentValidation Validator Generator

Generate `AbstractValidator<T>` subclasses following layered, best-practice patterns for C# projects.

## Pre-Generation Inspection

1. Locate target DTO or Request class via `tokensave_search` and `tokensave_context`.
2. Inspect project validator base classes (`SanitizerValidator<T>`, `BaseAuthenticatedValidator<T>`).
3. Follow `fluent-validation-csharp` and `dotnet-architect` service validation boundaries.

## Generation Workflow

1. **Select Base Class**: See [base-classes.md](references/base-classes.md); inherit authentication or role-checking base (`base(...)`), or `AbstractValidator<T>` if none exists.
2. **Define Error Constants**: Declare `public static string` constants in `SCREAMING_SNAKE_CASE`; never inline literals in `.WithMessage()`.
3. **Implement Validation Rules**: Group constructor rules per [validation-patterns.md](references/validation-patterns.md).
4. **Register DI**: Register via `AddValidatorsFromAssemblyContaining<T>()` per [di-registration.md](references/di-registration.md).

## Verification Checklist

- [ ] Correct project base class inherited and registered via assembly scanning.
- [ ] Error messages defined as `public static string` constants (no inline `.WithMessage()` literals).
- [ ] Nullability annotations match the validated DTO or Request properties.

## Behavioral Requirements

- The fluent-validator-generator skill SHALL enforce the fluent-validation-csharp rule and dotnet-architect service validation boundaries.
- WHEN generating a validator for an authenticated or role-protected operation, the fluent-validator-generator skill SHALL inherit the project authentication or role-checking base class.
- WHERE no custom validator hierarchy exists, the fluent-validator-generator skill SHALL inherit AbstractValidator<T> and register via AddValidatorsFromAssemblyContaining<T>().
- IF an error message is passed to .WithMessage(), THEN the fluent-validator-generator skill SHALL reference a SCREAMING_SNAKE_CASE constant instead of an inline string literal.

## Behavioral Scenarios

```gherkin
Feature: FluentValidation Validator Generation
  @REQ-VAL-001
  Scenario: Generate role-aware validator with constant error messages and DI registration
    Given a request DTO requiring authenticated role validation
    When the developer requests a FluentValidation validator
    Then the fluent-validator-generator skill inherits the role-checking base class
    And registers the validator with AddValidatorsFromAssemblyContaining

  @REQ-VAL-002
  Scenario: Reject inline error message literals in validation rules
    Given a generated AbstractValidator subclass under review
    When a rule supplies a raw literal string to .WithMessage()
    Then the fluent-validator-generator skill flags the literal as non-compliant
    And requires a public static string SCREAMING_SNAKE_CASE constant
```
