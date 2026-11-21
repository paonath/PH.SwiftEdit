# Polyglot BDD Runners: Java, Go, Swift, and Bash

## 1. Java (`cucumber-jvm` + JUnit 5)
```java
@Given("a registered user with email {string}")
public void aRegisteredUser(String email) {
    this.email = email;
}
@When("the user signs in with valid credentials")
public void userSignsIn() {
    this.response = client.post("/auth/login", new Credentials(email, "secret"));
}
@Then("access is granted to the personal dashboard")
public void accessGranted() {
    assertEquals(200, response.getStatusCode());
}
```

## 2. Go (`godog`)
```go
func InitializeScenario(ctx *godog.ScenarioContext) {
    ctx.Step(`^a registered user with email "([^"]*)"$`, aRegisteredUser)
    ctx.Step(`^the user signs in with valid credentials$`, userSignsIn)
    ctx.Step(`^access is granted to the personal dashboard$`, accessGranted)
}
```

## 3. Swift (`Cucumberish` / `Swift-Cucumber`)
```swift
Given("a registered user with email (.*)") { args, userInfo in
    let email = args?[0] as? String
}
```

## 4. Bash (`BATS` + Given-When-Then helper)
```bash
@test "REQ-AUTH-001: User sign-in" {
  run ./scripts/auth_client.sh --login "user@example.com"
  [ "$status" -eq 0 ]
}
```
