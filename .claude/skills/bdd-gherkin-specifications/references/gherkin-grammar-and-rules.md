# Standard Gherkin v6+ Grammar & Reference Specification

Based on official Cucumber Gherkin reference specifications.

## 1. Primary Structural Keywords

- `Feature`: Title and description of the business capability.
- `Rule`: (Gherkin 6+) Encloses business rules and groups related scenarios illustrating that rule.
- `Background`: Common preparatory context run before each scenario in the feature/rule block.
- `Scenario`: A single concrete example of system behavior.
- `Scenario Outline` (or `Scenario Template`): Parameterized scenario executed once per row in `Examples:`.
- `Examples` (or `Scenarios`): Markdown pipe table (`| col1 | col2 |`) supplying parameter values.

## 2. Step Keywords

- `Given`: Sets up the initial context or pre-conditions.
- `When`: The decisive event, stimulus, or action taken by the actor.
- `Then`: The observable outcome or verifiable post-condition.
- `And` / `But`: Step continuation keywords matching the preceding step type.

## 3. Data Tables & Doc Strings

```gherkin
Scenario: Create user with complex attributes
  Given the administration database is initialized
  When the administrator creates the following account:
    | field    | value            |
    | username | paolo            |
    | role     | QualityArchitect |
  Then the account is created successfully
  And the generated welcome payload matches:
    """json
    {
      "status": "ACTIVE",
      "tier": "ENTERPRISE"
    }
    """
```
