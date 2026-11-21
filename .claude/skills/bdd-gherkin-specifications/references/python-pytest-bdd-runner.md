# Python BDD Automation with `pytest-bdd`

`pytest-bdd` removes the runner abstraction, allowing scenarios to execute natively as pytest test functions.

## 1. Setup
```bash
pip install pytest-bdd
```

## 2. Step Definition Implementation
```python
from pytest_bdd import scenarios, given, when, then, parsers
import pytest

scenarios('../features/authentication.feature')

@pytest.fixture
def auth_client():
    from my_app.client import TestClient
    return TestClient()

@given(parsers.parse('a registered user with email "{email}"'))
def registered_user(auth_client, email):
    auth_client.seed_user(email=email)

@when('the user signs in with valid credentials')
def user_sign_in(auth_client):
    auth_client.login(email="user@example.com", password="valid_password")

@then('access is granted to the personal dashboard')
def access_granted(auth_client):
    assert auth_client.get_current_status() == 200
```
