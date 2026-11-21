---
name: tdd-pytest-unittest-and-docstrings
description: "Deterministic Python TDD workflows using unittest and pytest, sandboxed TemporaryDirectory fixtures, and PEP 257/484 docstrings."
---

# TDD (`unittest` / `pytest`) and Docstring Standards in Python

## Red-Green-Refactor TDD Workflow

- Enforce strict RED-GREEN-REFACTOR-DOC cycles: author failing tests covering both positive (`P#`) and negative/security (`N#`) scenarios before implementing production code.
- Keep unit and governance tests fast (`< 100ms` per test), hermetic, and deterministic with zero network calls or mutations to the real workspace outside `tempfile.TemporaryDirectory()`.

## Sandboxed Fixture Architecture

- Isolate every filesystem or CLI test inside a `tempfile.TemporaryDirectory()` context:
  ```python
  class TestCliEngine(unittest.TestCase):
      def setUp(self) -> None:
          self._tmp = tempfile.TemporaryDirectory()
          self.root = Path(self._tmp.name)

      def tearDown(self) -> None:
          self._tmp.cleanup()
  ```
- Test both in-process domain classes and blackbox CLI entrypoints (`subprocess.run([sys.executable, str(script), "--help"], capture_output=True, text=True, check=False)`) to verify exit codes (`0`, `1`, `2`) and JSON schema contracts.
- Use `subTest(case=...)` in `unittest` (or `@pytest.mark.parametrize` in `pytest`) to test boundary tables concisely without duplicating boilerplate.

## PEP 257 and PEP 484 Documentation Standards

- Every Python module, public class, and public function must carry a concise English docstring adhering to **PEP 257** alongside full **PEP 484** type hints:
  ```python
  def validate_slug(slug: str) -> str:
      """Validate that a reference filename slug conforms to the safe kebab-case regex.

      Args:
          slug: Candidate filename (for example, 'clean-ddd-architecture.md').

      Returns:
          The validated slug string.

      Raises:
          ValueError: If slug contains path traversal tokens or violates the regex.
      """
  ```
- Include `[Path: P# | N#]` and `[Trait: positive | negative | security]` tags in test method docstrings to maintain 100% traceability with OpenSpec delta scenarios (`myspec-verify`).
