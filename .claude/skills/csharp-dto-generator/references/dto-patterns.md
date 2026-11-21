# C# DTO Record Patterns Reference

## Single-File Entity DTO Pair Pattern

Place both records in a single file `{Entity}Dto.cs`:

```csharp
namespace MyProject.Models.Dtos;

/// <summary>
/// DTO representing the {Entity} read model.
/// </summary>
public record {Entity}Dto : {Entity}CreateDto
{
    /// <summary>Gets the primary key.</summary>
    /// <remarks>This is the primary key.</remarks>
    public string Id { get; init; }

    public {Entity}Dto() : base() { }

    public {Entity}Dto(string id, string propA, int propB) : base(propA, propB)
    {
        Id = id;
    }

    public void Deconstruct(out string id, out string propA, out int propB)
    {
        id = Id;
        base.Deconstruct(out propA, out propB);
    }
}

/// <summary>
/// DTO representing the {Entity} creation payload.
/// </summary>
public record {Entity}CreateDto
{
    /// <summary>Gets or sets property A.</summary>
    public string PropA { get; init; }

    /// <summary>Gets or sets property B.</summary>
    public int PropB { get; init; }

    public {Entity}CreateDto() : this(string.Empty, 0) { }

    public {Entity}CreateDto(string propA, int propB)
    {
        PropA = propA;
        PropB = propB;
    }

    public void Deconstruct(out string propA, out int propB)
    {
        propA = PropA;
        propB = PropB;
    }
}
```

## Property Type Mapping Reference

| Entity Type | DTO Type | Default Value |
| :--- | :--- | :--- |
| `required string` | `string` | `string.Empty` |
| `string?` | `string?` | `null` |
| `required DateTime` | `DateTime` | `default` |
| `DateTime?` | `DateTime?` | `null` |
| `int` / `long` | `int` / `long` | `0` |
| `decimal` | `decimal` | `0m` |
| `bool` | `bool` | `false` |
