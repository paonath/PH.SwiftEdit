namespace MyProject.Services;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using FluentValidation;

/// <summary>
/// Reference template for CRUD service implementations.
/// </summary>
public interface IProductService
{
    Task<ProductDto?[]> GetAllAsync(CancellationToken ct = default);
    Task<ProductDto?> GetByIdAsync(string id, CancellationToken ct = default);
    Task<(ValidationResultFlow Validation, ProductDto? Item)> CreateAsync(ProductCreateRequest request, CancellationToken ct = default);
    Task<(ValidationResultFlow Validation, ProductDto? Item)> EditAsync(ProductDto dto, CancellationToken ct = default);
    Task<(ValidationResultFlow Validation, bool Success)> DeleteAsync(string id, CancellationToken ct = default);
}

public class ProductService : ServiceBase, IProductService
{
    private readonly AppDbContext _db;
    private readonly IValidator<ProductCreateRequest> _createValidator;
    private readonly IValidator<ProductDto> _editValidator;
    private readonly ILogger<ProductService> _logger;

    public ProductService(
        AppDbContext db,
        IValidator<ProductCreateRequest> createValidator,
        IValidator<ProductDto> editValidator,
        ILogger<ProductService> logger)
    {
        _db = db;
        _createValidator = createValidator;
        _editValidator = editValidator;
        _logger = logger;
    }

    public async Task<ProductDto?[]> GetAllAsync(CancellationToken ct = default)
    {
        _logger.LogTrace("{Method} started", nameof(GetAllAsync));
        return await _db.Products
            .AsNoTracking()
            .Select(p => p.ToDto())
            .ToArrayAsync(ct);
    }

    public async Task<ProductDto?> GetByIdAsync(string id, CancellationToken ct = default)
    {
        _logger.LogTrace("{Method} started for ID: {Id}", nameof(GetByIdAsync), id);
        var entity = await _db.Products.FindAsync(new object[] { id }, ct);
        return entity?.ToDto();
    }

    public async Task<(ValidationResultFlow Validation, ProductDto? Item)> CreateAsync(ProductCreateRequest request, CancellationToken ct = default)
    {
        var validation = await ValidateAsync(_createValidator, request, ct);
        if (!validation.IsValid) return (validation, null);

        var entity = request.ToEntity();
        _db.Products.Add(entity);
        await _db.SaveChangesAsync(ct);
        return (validation, entity.ToDto());
    }

    public async Task<(ValidationResultFlow Validation, ProductDto? Item)> EditAsync(ProductDto dto, CancellationToken ct = default)
    {
        var validation = await ValidateAsync(_editValidator, dto, ct);
        if (!validation.IsValid) return (validation, null);

        var entity = await _db.Products.FindAsync(new object[] { dto.Id }, ct);
        if (entity == null) return (ValidationResultFlow.NotFound(nameof(Product), dto.Id), null);

        dto.ApplyTo(entity);
        await _db.SaveChangesAsync(ct);
        return (validation, entity.ToDto());
    }

    public async Task<(ValidationResultFlow Validation, bool Success)> DeleteAsync(string id, CancellationToken ct = default)
    {
        var entity = await _db.Products.FindAsync(new object[] { id }, ct);
        if (entity == null) return (ValidationResultFlow.NotFound(nameof(Product), id), false);

        _db.Products.Remove(entity);
        await _db.SaveChangesAsync(ct);
        return (ValidationResultFlow.Valid(), true);
    }
}
