# Workflow 04: Re-verification & Reporting (`web-design-reviewer`)

## Step 4: Re-verification Phase

- Reload browser (or wait for HMR) and capture screenshots of fixed areas.
- Verify fixes haven't broken other areas; confirm responsive display is intact.
- If issues remain, return to [02-visual-inspection](../02-visual-inspection/workflow.md). If more than 3 attempts for a specific issue, consult the user.

### Troubleshooting: Fixes not reflected
1. Check if development server HMR is working
2. Clear browser cache
3. Rebuild if project requires build
4. Check CSS specificity issues

## Output Format

### Review Results Report

```markdown
# Web Design Review Results

## Summary

| Item | Value |
|------|-------|
| Target URL | {URL} |
| Framework | {Detected framework} |
| Styling | {CSS / Tailwind / etc.} |
| Tested Viewports | Desktop, Mobile |
| Issues Detected | {N} |
| Issues Fixed | {M} |

## Detected Issues

### [P1] {Issue Title}

- **Page**: {Page path}
- **Element**: {Selector or description}
- **Issue**: {Detailed description of the issue}
- **Fixed File**: `{File path}`
- **Fix Details**: {Description of changes}
- **Screenshot**: Before/After

### [P2] {Issue Title}
...

## Unfixed Issues (if any)

### {Issue Title}
- **Reason**: {Why it was not fixed/could not be fixed}
- **Recommended Action**: {Recommendations for user}

## Recommendations

- {Suggestions for future improvements}
```

## Phase Requirements (EARS)

- WHEN a source fix is applied, the re-verification workflow SHALL reload the browser, capture updated screenshots, and emit a `# Web Design Review Results` report documenting verified and unfixed issues.
- IF a single defect remains unresolved after more than 3 fix attempts, THEN the re-verification workflow SHALL stop retrying and escalate the unresolved defect to the user.
