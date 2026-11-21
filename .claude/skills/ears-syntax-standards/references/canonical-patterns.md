# Canonical EARS Patterns & Formal Grammar

Based on Mavin et al. (IEEE RE'09, Atlanta, pp. 317–322) and IEEE Software (2019).

## 1. Pattern Breakdown

### 1.1 Ubiquitous Requirements
- **Grammar**: `The <system name> SHALL <system response>.`
- **When to Use**: For non-functional invariants, continuous standards, or universal rules that have no triggering condition.
- **Example**: `The Order API SHALL transmit all payload data in application/json format encoded in UTF-8.`

### 1.2 Event-Driven Requirements
- **Grammar**: `WHEN <trigger>, the <system name> SHALL <system response>.`
- **When to Use**: Triggered by a discrete, instantaneous event occurring at a specific point in time.
- **Example**: `WHEN the customer confirms payment, the Checkout Service SHALL create an Order entity in "Pending" status.`

### 1.3 State-Driven Requirements
- **Grammar**: `WHILE <state>, the <system name> SHALL <system response>.`
- **When to Use**: Behavior active continuously during a state interval.
- **Example**: `WHILE the export job is executing, the Worker Service SHALL update the progress percentage every 500 milliseconds.`

### 1.4 Optional Feature Requirements
- **Grammar**: `WHERE <feature is included>, the <system name> SHALL <system response>.`
- **When to Use**: Behavior that only applies in specific deployments, license tiers, or hardware variants.
- **Example**: `WHERE multi-factor authentication is enabled, the Auth Gateway SHALL request an OTP verification code.`

### 1.5 Unwanted Behaviour Requirements
- **Grammar**: `IF <unwanted condition>, THEN the <system name> SHALL <system response>.`
- **When to Use**: The primary defense against omission. Covers invalid inputs, network failures, timeouts, and authorization denial.
- **Example**: `IF the external payment gateway does not respond within 3000 milliseconds, THEN the Checkout Service SHALL return HTTP 504 Gateway Timeout.`

### 1.6 Complex Combinations
- **Grammar**: `WHILE <state>, WHEN <trigger>, the <system name> SHALL <system response>.`
- **Or**: `WHILE <state>, IF <unwanted condition>, THEN the <system name> SHALL <system response>.`
- **Example**: `WHILE an order is in "Shipped" status, WHEN the user requests order cancellation, the Order Service SHALL reject the request with code ORDER_ALREADY_SHIPPED.`
