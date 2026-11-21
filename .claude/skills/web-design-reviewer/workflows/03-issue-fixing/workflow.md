# Workflow 03: Issue Fixing Phase (`web-design-reviewer`)

## Step 3: Issue Fixing Phase

### 3.1 Issue Prioritization

- **P1**: Fix Immediately (Layout issues affecting functionality)
- **P2**: Fix Next (Visual issues degrading UX)
- **P3**: Fix If Possible (Minor visual inconsistencies)

### 3.2 Identifying Source Files

Identify source files from problematic elements:

1. **Selector-based Search**
   - Search codebase by class name or ID (TokenSave-first, see the `tokensave-first` rule).
2. **Component-based Search**
   - Identify components from element text or structure.
3. **File Pattern Filtering**
   ```text
   Style files: src/**/*.css, styles/**/*
   Components: src/components/**/*
   Pages: src/pages/**, app/**
   ```

### 3.3 Applying Fixes

See [framework-fixes.md](../../references/framework-fixes.md) for framework-specific fix patterns.

#### Fix Principles

1. **Minimal Changes**: Only make the minimum changes necessary to resolve the issue
2. **Respect Existing Patterns**: Follow existing code style in the project
3. **Avoid Breaking Changes**: Be careful not to affect other areas
4. **Add Comments**: Add comments to explain the reason for fixes where appropriate

## Best Practices

### DO (Recommended)
- Always save screenshots before making fixes
- Fix one issue at a time and verify each
- Follow the project's existing code style
- Confirm with user before major changes
- Document fix details thoroughly

### DON'T (Not Recommended)
- Large-scale refactoring without confirmation
- Ignoring design systems or brand guidelines
- Fixes that ignore performance
- Fixing multiple issues at once (difficult to verify)

## Troubleshooting Style & Scope Issues

- **Style files not found**: Check `package.json`, check for CSS-in-JS or build-time CSS generation, ask user about styling method.
- **Fixes affecting other areas**: Rollback changes, use more specific selectors, consider CSS Modules or scoped styles, consult user to confirm impact scope.

## Phase Requirements (EARS)

- The issue fixing workflow SHALL resolve `P1`, `P2`, and `P3` defects one issue at a time after locating source files via the `tokensave-first` rule and saving baseline screenshots.
- IF a proposed fix affects shared styles or requires broad refactoring, THEN the issue fixing workflow SHALL roll back unconfirmed edits and ask the user for scope confirmation.
