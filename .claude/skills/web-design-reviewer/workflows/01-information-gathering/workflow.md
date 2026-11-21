# Workflow 01: Information Gathering Phase (`web-design-reviewer`)

## Step 1: Information Gathering Phase

### 1.1 URL Confirmation

If the URL is not provided, ask the user:

> Please provide the URL of the website to review (e.g., `http://localhost:3000`)

### 1.2 Understanding Project Structure

When making fixes, gather the following information:

| Item | Example Question |
|------|------------------|
| Framework | Are you using React / Vue / Next.js, etc.? |
| Styling Method | CSS / SCSS / Tailwind / CSS-in-JS, etc. |
| Source Location | Where are style files and components located? |
| Review Scope | Specific pages only or entire site? |

### 1.3 Automatic Project Detection

Attempt automatic detection from files in the workspace:

```text
Detection targets:
├── package.json     -> Framework and dependencies
├── tsconfig.json    -> TypeScript usage
├── tailwind.config  -> Tailwind CSS
├── next.config      -> Next.js
├── vite.config      -> Vite
├── nuxt.config      -> Nuxt
└── src/ or app/     -> Source directory
```

### 1.4 Identifying Styling Method

See [framework-fixes.md](../../references/framework-fixes.md) for detection patterns and edit targets per styling method (Pure CSS, SCSS, Tailwind, styled-components, CSS Modules, etc.).

## Phase Requirements (EARS)

- IF the target website URL is omitted from the request, THEN the information gathering workflow SHALL prompt the user for the URL before browser inspection.
- WHEN workspace source files are accessible, the information gathering workflow SHALL detect the project framework, styling method, and source directories from workspace configuration manifests.
