# EARS Anti-Patterns and Refactoring Remedies

## Anti-Pattern 1: Confusing Event (Instant) with State (Interval)
- **Problem**: Using `WHEN` for a sustained condition, or `WHILE` for an instantaneous trigger.
- **Faulty**: `WHEN the request is loading, the UI SHALL display a spinner.` (Loading is an interval, not an instant).
- **Refactored**: `WHILE the network request is in progress, the UI SHALL render the loading spinner.`

## Anti-Pattern 2: The Silent Failure Omission
- **Problem**: Authoring only the happy path and omitting what happens when an error occurs.
- **Rule**: For every `WHEN <trigger>`, ask: *What can fail?* Formulate the corresponding `IF ... THEN` requirement.
- **Refactoring**:
  - Happy Path: `WHEN the client provides valid credentials, the Auth Service SHALL issue a JWT access token.`
  - Error Path: `IF the client provides invalid credentials, THEN the Auth Service SHALL return HTTP 401 Unauthorized.`

## Anti-Pattern 3: Implementation Leakage
- **Problem**: Embedding UI implementation details (CSS classes, database table names) into the requirement.
- **Faulty**: `WHEN user clicks button #btn-send, the React component SHALL call axios.post to /api/v1.`
- **Refactored**: `WHEN the user submits the contact form, the Client SHALL dispatch a POST request to the Contact Endpoint.`
