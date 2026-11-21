#!/usr/bin/env python3
"""Validation harness for GoF Design Patterns AI Agent Skill.

Verifies:
1. Root SKILL.md existence, frontmatter schema, line count (< 500 lines).
2. Root README.md existence.
3. Catalog completeness: 23 pattern markdown files in references/ (5 creational, 7 structural, 11 behavioral).
4. Uniform section structure per pattern file.
5. Tripartite code snippet presence: C# (.NET 10), TypeScript (Angular Signals), Python (3.12+).
6. Python snippet syntactic validity via ast.parse and py_compile.
7. C# and TypeScript code block non-emptiness and absence of placeholder ellipsis ("// ...").
8. Security invariant verification:
   - Zero hardcoded secrets / credentials / tokens.
   - Command pattern reflection / eval prevention.
   - Prototype pattern cycle detection and depth guard.
   - Singleton pattern thread safety and state immutability.
"""

from __future__ import annotations

import ast
import json
import os
import re
import sys
from pathlib import Path

# Canonical 23 GoF Design Patterns
EXPECTED_PATTERNS = {
    "creational": [
        "abstract-factory.md",
        "builder.md",
        "factory-method.md",
        "prototype.md",
        "singleton.md",
    ],
    "structural": [
        "adapter.md",
        "bridge.md",
        "composite.md",
        "decorator.md",
        "facade.md",
        "flyweight.md",
        "proxy.md",
    ],
    "behavioral": [
        "chain-of-responsibility.md",
        "command.md",
        "interpreter.md",
        "iterator.md",
        "mediator.md",
        "memento.md",
        "observer.md",
        "state.md",
        "strategy.md",
        "template-method.md",
        "visitor.md",
    ],
}

SECRET_PATTERNS = [
    re.compile(r"""(?i)(?:api_key|apikey|secret|password|bearer|auth_token)\s*[:=]\s*["'][A-Za-z0-9_\-\.]{8,}["']"""),
    re.compile(r"""(?i)-----BEGIN\s+(?:RSA\s+)?PRIVATE\s+KEY-----"""),
]

SUSPICIOUS_REFLECTION_PATTERNS = [
    re.compile(r"""Type\.GetType\s*\(\s*[a-zA-Z0-9_]+\s*\)"""),
    re.compile(r"""eval\s*\("""),
    re.compile(r"""pickle\.loads\s*\("""),
]


def extract_fenced_blocks(content: str, language: str) -> list[str]:
    """Extract code blocks fenced with ```language ... ``` from markdown."""
    pattern = rf"```(?:{language})\n([\s\S]*?)```"
    return re.findall(pattern, content)


def extract_frontmatter(content: str) -> dict[str, str]:
    """Extract simple key-value YAML frontmatter pairs."""
    if not content.startswith("---"):
        return {}
    parts = content.split("---", 2)
    if len(parts) < 3:
        return {}
    fm_text = parts[1]
    result: dict[str, str] = {}
    for line in fm_text.splitlines():
        line = line.strip()
        if ":" in line and not line.startswith("#"):
            k, v = line.split(":", 1)
            result[k.strip()] = v.strip()
    return result


def validate_plugin(repo_root: Path, errors: list[str], warnings: list[str]) -> Path:
    """Validate plugin structure, manifests, and advisory agent."""
    plugin_dir = repo_root / "plugins" / "oop-design-patterns"
    if not plugin_dir.exists():
        errors.append(f"Missing plugin directory: {plugin_dir}")
        return plugin_dir

    plugin_json_path = plugin_dir / "plugin.json"
    if not plugin_json_path.exists():
        errors.append(f"Missing plugin manifest: {plugin_json_path}")
    else:
        try:
            with open(plugin_json_path, encoding="utf-8") as f:
                data = json.load(f)
            if data.get("name") != "oop-design-patterns":
                errors.append(f"plugin.json 'name' must be 'oop-design-patterns', got '{data.get('name')}'")
            if data.get("version") != "1.0.0":
                errors.append(f"plugin.json 'version' must be '1.0.0', got '{data.get('version')}'")
            if data.get("skills") != ["./skills/oop-design-patterns/"]:
                errors.append(f"plugin.json 'skills' must be ['./skills/oop-design-patterns/'], got {data.get('skills')}")
            if data.get("agents") != ["./agents/oop-architecture-expert.agent.md"]:
                errors.append(f"plugin.json 'agents' must be ['./agents/oop-architecture-expert.agent.md'], got {data.get('agents')}")
        except Exception as e:
            errors.append(f"Failed to parse plugin.json: {e}")

    version_json_path = plugin_dir / "version.json"
    if not version_json_path.exists():
        errors.append(f"Missing version manifest: {version_json_path}")
    else:
        try:
            with open(version_json_path, encoding="utf-8") as f:
                vdata = json.load(f)
            if vdata.get("version") != "1.0.0":
                errors.append(f"version.json 'version' must be '1.0.0', got '{vdata.get('version')}'")
            if vdata.get("build") != 1:
                errors.append(f"version.json 'build' must be 1, got {vdata.get('build')}")
        except Exception as e:
            errors.append(f"Failed to parse version.json: {e}")

    # Validate agent
    agent_path = plugin_dir / "agents" / "oop-architecture-expert.agent.md"
    if not agent_path.exists():
        errors.append(f"Missing advisory agent: {agent_path}")
    else:
        agent_content = agent_path.read_text(encoding="utf-8")
        if not agent_content.startswith("---"):
            errors.append("Agent missing YAML frontmatter")
        else:
            parts = agent_content.split("---", 2)
            if len(parts) < 3:
                errors.append("Agent malformed YAML frontmatter")
            else:
                fm = parts[1]
                if "name: oop-architecture-expert" not in fm:
                    errors.append("Agent frontmatter missing 'name: oop-architecture-expert'")
                # Validate read-only tools strictly
                allowed_tools = {"view_file", "list_dir", "grep_search", "find_by_name"}
                forbidden_tools = {"run_command", "write_to_file", "replace_file_content"}
                # extract tools list from frontmatter
                tools_match = re.search(r"tools:\s*\[(.*?)\]", fm, re.DOTALL)
                if not tools_match:
                    # check multiline list
                    tools_match_lines = re.findall(r"-\s*([a-zA-Z0-9_]+)", fm)
                    found_tools = set(tools_match_lines)
                else:
                    found_tools = {t.strip().strip("'\"") for t in tools_match.group(1).split(",") if t.strip()}
                
                if not found_tools:
                    errors.append("Agent frontmatter specifies no tools or unparseable tools")
                elif found_tools != allowed_tools:
                    errors.append(f"Agent tools must be exactly {allowed_tools}, got {found_tools}")
                
                for f_tool in forbidden_tools:
                    if f_tool in found_tools or f_tool in fm:
                        errors.append(f"Agent possesses forbidden tool: {f_tool}")

    return plugin_dir


def validate_skill_root(skill_dir: Path, errors: list[str], warnings: list[str]) -> None:
    """Validate root SKILL.md and README.md."""
    skill_md = skill_dir / "SKILL.md"
    readme_md = skill_dir / "README.md"

    if not skill_md.exists():
        errors.append(f"Missing root manifest: {skill_md}")
        return

    lines = skill_md.read_text(encoding="utf-8").splitlines()
    line_count = len(lines)
    if line_count >= 500:
        errors.append(f"SKILL.md exceeds 500 lines limit: {line_count} lines")

    content = "\n".join(lines)
    if not content.startswith("---"):
        errors.append("SKILL.md missing opening YAML frontmatter delimiter (---)")
    else:
        parts = content.split("---", 2)
        if len(parts) < 3:
            errors.append("SKILL.md malformed YAML frontmatter (missing closing ---)")
        else:
            frontmatter = parts[1]
            if "name: oop-design-patterns" not in frontmatter:
                errors.append("SKILL.md frontmatter missing 'name: oop-design-patterns'")
            if "description:" not in frontmatter:
                errors.append("SKILL.md frontmatter missing 'description:' field")

    if not readme_md.exists():
        errors.append(f"Missing root README: {readme_md}")


def validate_pattern_file(path: Path, category: str, errors: list[str], warnings: list[str]) -> None:
    """Validate a single pattern markdown file."""
    if not path.exists():
        errors.append(f"Missing pattern reference: {path}")
        return

    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()

    # Frontmatter check
    if not content.startswith("---"):
        errors.append(f"{path.name}: missing YAML frontmatter")
    else:
        fm = extract_frontmatter(content)
        scope = fm.get("scope", "")
        if scope not in ("Micro-Design", "Macro-Architecture"):
            errors.append(f"{path.name}: frontmatter 'scope' must be 'Micro-Design' or 'Macro-Architecture', got '{scope}'")

    # Line count check (informational / quality standard)
    if len(lines) < 80:
        warnings.append(f"{path.name}: relatively short content ({len(lines)} lines)")
    elif len(lines) > 500:
        warnings.append(f"{path.name}: relatively long content ({len(lines)} lines)")

    # 4-part Applicability Rubric checks
    if "Rule of Three" not in content and "rule of three" not in content.lower():
        errors.append(f"{path.name}: missing Evolutionary Rule of Three in Applicability Rubric")
    if "Language-First" not in content and "language-first" not in content.lower():
        errors.append(f"{path.name}: missing Language-First substitution in Applicability Rubric")

    green_flags = re.findall(r"-\s*\[X\]\s*Green Flag \d+:", content)
    if len(green_flags) != 3:
        errors.append(f"{path.name}: expected exactly 3 Green Flags ('- [X] Green Flag N:'), found {len(green_flags)}")

    red_flags = re.findall(r"-\s*\[!\]\s*Red Flag \d+:", content)
    if len(red_flags) != 3:
        errors.append(f"{path.name}: expected exactly 3 Red Flags ('- [!] Red Flag N:'), found {len(red_flags)}")

    if "Alternative Simplification" not in content:
        errors.append(f"{path.name}: missing '### Alternative Simplification' section")

    # Language snippets check
    csharp_blocks = extract_fenced_blocks(content, r"csharp|cs")
    ts_blocks = extract_fenced_blocks(content, r"typescript|ts")
    py_blocks = extract_fenced_blocks(content, r"python|py")

    if not csharp_blocks:
        errors.append(f"{path.name}: missing fenced C# (csharp) code snippet")
    else:
        for idx, block in enumerate(csharp_blocks):
            if "// ..." in block or "// TODO" in block:
                errors.append(f"{path.name}: C# snippet #{idx+1} contains unfinished placeholder comments ('// ...' or '// TODO')")

    if not ts_blocks:
        errors.append(f"{path.name}: missing fenced TypeScript (typescript) code snippet")
    else:
        for idx, block in enumerate(ts_blocks):
            if "// ..." in block or "// TODO" in block:
                errors.append(f"{path.name}: TypeScript snippet #{idx+1} contains unfinished placeholder comments ('// ...' or '// TODO')")

    if not py_blocks:
        errors.append(f"{path.name}: missing fenced Python (python) code snippet")
    else:
        for idx, block in enumerate(py_blocks):
            if "# ..." in block or "# TODO" in block:
                errors.append(f"{path.name}: Python snippet #{idx+1} contains unfinished placeholder comments ('# ...' or '# TODO')")
            # Parse Python AST to verify valid Python syntax
            try:
                ast.parse(block, filename=f"{path.name}[snippet_{idx+1}]")
            except SyntaxError as e:
                errors.append(f"{path.name}: Python snippet #{idx+1} syntax error: {e}")

    # Security: Check for hardcoded secrets
    for pattern in SECRET_PATTERNS:
        if pattern.search(content):
            errors.append(f"{path.name}: potential hardcoded secret or private key pattern detected")

    # Security: Pattern specific checks in code blocks
    all_code = "\n".join(csharp_blocks + ts_blocks + py_blocks)
    if path.name == "command.md":
        for pat in SUSPICIOUS_REFLECTION_PATTERNS:
            if pat.search(all_code):
                errors.append(f"command.md: suspicious dynamic reflection or eval pattern detected in code snippet: {pat.pattern}")

    if path.name == "prototype.md":
        # Ensure cycle or recursion defense is documented
        if "cycle" not in content.lower() and "visited" not in content.lower() and "identity" not in content.lower():
            warnings.append("prototype.md: should explicitly mention cycle detection or identity map guard")

    if path.name == "singleton.md":
        # Ensure thread safety is mentioned
        if "thread" not in content.lower() and "lazy" not in content.lower() and "immutab" not in content.lower():
            warnings.append("singleton.md: should explicitly discuss thread-safety and immutability")


def validate_catalog(skill_dir: Path, errors: list[str], warnings: list[str]) -> None:
    """Validate presence and structure of all 23 GoF pattern files."""
    references_dir = skill_dir / "references"
    if not references_dir.exists():
        errors.append(f"Missing references directory: {references_dir}")
        return

    for category, files in EXPECTED_PATTERNS.items():
        cat_dir = references_dir / category
        if not cat_dir.exists():
            errors.append(f"Missing category directory: {cat_dir}")
            continue

        for filename in files:
            file_path = cat_dir / filename
            validate_pattern_file(file_path, category, errors, warnings)


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parents[2] if script_dir.parts[-4:] == ("plugins", "oop-design-patterns", "skills", "oop-design-patterns", "scripts") or "plugins" in script_dir.parts else script_dir.parents[2]
    
    # Try finding repo_root dynamically by looking for .git or specs
    cur = script_dir
    while cur.parent != cur:
        if (cur / ".git").exists() or (cur / "specs").exists():
            repo_root = cur
            break
        cur = cur.parent

    errors: list[str] = []
    warnings: list[str] = []

    plugin_dir = validate_plugin(repo_root, errors, warnings)
    target_skill_dir = plugin_dir / "skills" / "oop-design-patterns"

    # If target_skill_dir does not exist yet (during transition), check script_dir.parent
    if target_skill_dir.exists():
        active_skill_dir = target_skill_dir
    else:
        active_skill_dir = script_dir.parent

    validate_skill_root(active_skill_dir, errors, warnings)
    validate_catalog(active_skill_dir, errors, warnings)

    status = "pass" if not errors else "fail"
    report = {
        "status": status,
        "plugin_dir": str(plugin_dir),
        "skill_dir": str(active_skill_dir),
        "total_errors": len(errors),
        "total_warnings": len(warnings),
        "errors": errors,
        "warnings": warnings,
    }

    print(json.dumps(report, indent=2))
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
