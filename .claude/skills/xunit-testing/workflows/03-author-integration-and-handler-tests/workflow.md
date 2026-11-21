# Workflow 03: Author Integration, Handler & Authorization Tests (`xunit-testing`)

## Setup and Teardown Patterns

- Use constructor setup for simple synchronous dependencies, `IDisposable` for synchronous cleanup, `IAsyncLifetime` for async setup/teardown, and fixture classes for expensive shared setup.

## Assertion Quality & Implementation Order

- For typed endpoint/handler results, assert exact result type first (see [assertions-guide.md](../../references/assertions-guide.md) and [patterns.md](../../references/patterns.md)), then assert payload values.
- Use collection assertions (`Single`, `Empty`, `Contains`, `All`) for queries and exception assertions (`Throws`, `ThrowsAsync`) for failure paths.
- Implement tests in order: (1) success path, (2) validation/error path, (3) authorization path, (4) boundary and edge cases.

## Behavioral Requirements

- The xunit-testing integration workflow SHALL author tests in strict order: success path, validation path, authorization path, and boundary edge cases.
- WHEN validating typed handler or endpoint responses, the xunit-testing integration workflow SHALL assert the exact result type before asserting payload properties.
- IF asynchronous fixture initialization or teardown is required, THEN the xunit-testing integration workflow SHALL implement IAsyncLifetime instead of blocking in constructors.

## Pattern Templates (Integration, Handler & Authorization)

### Pattern C: Integration Test With Fixture

```csharp
public sealed class OrderRepositoryTests : IClassFixture<TestDatabaseFixture>
{
    private readonly TestDatabaseFixture _fixture;

    public OrderRepositoryTests(TestDatabaseFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task Save_WithValidOrder_PersistsToDatabase()
    {
        // Arrange
        var sut = new OrderRepository(_fixture.Context);
        var order = new Order("ord-1", 3);

        // Act
        await sut.SaveAsync(order, CancellationToken.None);
        var saved = await sut.GetByIdAsync("ord-1", CancellationToken.None);

        // Assert
        Assert.NotNull(saved);
        Assert.Equal(3, saved!.Quantity);
    }
}
```

### Pattern D: Direct Handler Test

```csharp
public sealed class ProductHandlersTests
{
    [Fact]
    public async Task GetById_WithExistingId_ReturnsOk()
    {
        // Arrange
        var service = new StubProductService(new ProductDto("p-1", "Keyboard"));

        // Act
        var result = await ProductHandlers.GetById("p-1", service, CancellationToken.None);

        // Assert
        var ok = Assert.IsType<Ok<ProductDto>>(result.Result);
        Assert.Equal("p-1", ok.Value!.Id);
    }
}
```

### Pattern E: Authorization Test

```csharp
[Fact]
public async Task Delete_WhenUserHasNoRole_ReturnsForbid()
{
    // Arrange
    var ctx = HttpContextFactory.WithoutRoles();
    var service = new StubOrderService();

    // Act
    var result = await OrderHandlers.Delete("ord-1", ctx, service, CancellationToken.None);

    // Assert
    Assert.IsType<ForbidHttpResult>(result.Result);
}
```
