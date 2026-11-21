# Declarative Domain Language vs Imperative UI Anti-Patterns

## The Imperative Anti-Pattern (Fragile & Brittle)
Imperative scenarios specify UI mechanics (clicking buttons, filling inputs, waiting for CSS selectors).
```gherkin
# FAULTY / ANTI-PATTERN
Scenario: User login
  Given I go to "https://app.example.com/login"
  When I fill in "#email-field" with "user@example.com"
  And I fill in "#pwd-input" with "secret123"
  And I click on "button.btn-primary[type=submit]"
  Then I should see the element "div.dashboard-welcome"
```

## The Declarative Pattern (Resilient & Domain-Driven)
Declarative scenarios specify user intent and business outcomes using Ubiquitous Language.
```gherkin
# COMPLIANT / DECLARATIVE
@REQ-AUTH-001
Scenario: Successful authentication with valid credentials
  Given a registered user with email "user@example.com"
  When the user signs in with valid credentials
  Then access is granted to the personal dashboard
```

## Refactoring Guidelines
- Keep step definitions focused on domain intent.
- Delegate UI clicks, locators, and wait conditions to Page Object Models (POM) or API clients inside the step definition implementation.
