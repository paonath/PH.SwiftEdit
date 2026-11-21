# .NET (C#) BDD Automation with Reqnroll

Reqnroll is the official, open-source community successor to SpecFlow for Modern .NET (net8/9/10).

## 1. Project Setup
```xml
<PackageReference Include="Reqnroll" Version="2.*" />
<PackageReference Include="Reqnroll.xUnit" Version="2.*" />
<PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="9.*" />
```

## 2. Idiomatic Step Definition Binding
```csharp
[Binding]
public class AuthenticationSteps
{
    private readonly WebApplicationFactory<Program> _factory;
    private HttpClient _client;
    private HttpResponseMessage _response;

    public AuthenticationSteps(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Given(@"a registered user with email ""(.*)""")]
    public void GivenARegisteredUser(string email)
    {
        _client = _factory.CreateClient();
    }

    [When(@"the user signs in with valid credentials")]
    public async Task WhenTheUserSignsIn()
    {
        _response = await _client.PostAsJsonAsync("/api/v1/auth/login", new { Email = "user@example.com", Password = "ValidPassword123!" });
    }

    [Then(@"access is granted to the personal dashboard")]
    public void ThenAccessIsGranted()
    {
        Assert.Equal(HttpStatusCode.OK, _response.StatusCode);
    }
}
```
