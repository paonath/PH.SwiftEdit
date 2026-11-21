"""Multi-stack version manifest discovery, DOM parsing, and atomic update engine.

Supports Nerdbank.GitVersioning (JSONC), .NET MSBuild, Node.js, Python ([project]/[tool.poetry]),
and VERSION files with expat XXE/DTD blocking, 1 MiB bounds, symlink confinement, and monotonic guard.
"""

import json
import os
import re
import tempfile
import xml.etree.ElementTree as ET
import xml.parsers.expat as expat
from pathlib import Path
from typing import Optional, Tuple, Union

from .models import ManifestInfo
from .semver import compare_semver, parse_semver

MAX_MANIFEST_BYTES = 1_048_576
XXE_PATTERN = re.compile(r"<!(?:DOCTYPE|ENTITY)\b", re.IGNORECASE)
_XML_COMMENT_RE = re.compile(r"<!--[\s\S]*?-->")
_JSONC_COMMENT_RE = re.compile(r'//[^\r\n]*|/\*[\s\S]*?\*/')
_TOML_SECTION_RE = re.compile(
    r"(?ms)^\[(?:project|tool\.poetry)\]\s*\r?\n(.*?)(?=^\[|\Z)"
)
_TOML_VERSION_LINE_RE = re.compile(r'(?m)^([ \t]*version[ \t]*=[ \t]*["\'])([^"\']+)(["\'])')


class NoVersionElementError(ValueError):
    """Raised when an MSBuild file is well-formed and safe but defines no version element."""


def _read_raw_text(file_path: Path) -> str:
    """Read UTF-8 text preserving exact line endings (CRLF/LF) and optional UTF-8 BOM."""
    with open(file_path, "r", encoding="utf-8", newline="") as handle:
        return handle.read()


def _safe_write_text(file_path: Path, content: str) -> None:
    """Atomically write text preserving exact newline sequences and avoiding WinError 32."""
    dir_path = file_path.parent
    dir_path.mkdir(parents=True, exist_ok=True)
    temp_file = tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", newline="", dir=dir_path, delete=False
    )
    temp_name = temp_file.name
    try:
        temp_file.write(content)
        temp_file.flush()
        temp_file.close()
        os.replace(temp_name, file_path)
    except Exception:
        if os.path.exists(temp_name):
            os.remove(temp_name)
        raise


def _local_name(tag: str) -> str:
    """Strip optional XML namespace URI prefix from an ElementTree tag."""
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def _mask_xml_comments(content: str) -> str:
    """Mask XML comments with equal-length spaces so span offsets match raw content 1-to-1."""
    return _XML_COMMENT_RE.sub(lambda m: " " * len(m.group(0)), content)


def _strip_jsonc_comments(content: str) -> str:
    """Strip // and /* */ comments outside JSON string literals for NBGV version.json parsing."""
    pattern = re.compile(r'("(?:\\.|[^"\\])*")|//[^\r\n]*|/\*[\s\S]*?\*/')
    stripped = pattern.sub(lambda m: m.group(1) if m.group(1) is not None else "", content)
    return re.sub(r",(\s*[}\]])", r"\1", stripped)


def _replace_outside_xml_comments(content: str, tag: str, new_inner: str) -> Tuple[str, bool]:
    """Replace the first non-comment <tag>...</tag> inner text using span slicing."""
    match = re.search(rf"(<{tag}(?:\s[^>]*)?>)([^<]*)(</{tag}>)", _mask_xml_comments(content))
    if not match:
        return content, False
    start, end = match.span(2)
    return f"{content[:start]}{new_inner}{content[end:]}", True


def _sub_first_field(content: str, pattern: str, new_ver: str) -> str:
    """Replace the first regex field match using a callable to avoid backreference injection."""
    return re.sub(pattern, lambda m: f"{m.group(1)}{new_ver}{m.group(2)}", content, count=1)


class VersionEngine:
    """Discovers, validates, parses, and atomically updates project version manifests."""

    def _validate_manifest_file(self, root: Path, file_path: Path) -> None:
        """Enforce non-symlink, repository confinement, and <= 1 MiB bounds on a manifest."""
        if file_path.is_symlink():
            raise ValueError(f"Symlinked manifest forbidden: {file_path}")
        if not file_path.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Manifest escapes repository root: {file_path}")
        if file_path.is_file() and file_path.stat().st_size > MAX_MANIFEST_BYTES:
            raise ValueError(f"Manifest exceeds 1 MiB safety limit: {file_path}")

    def detect_xml_xxe(self, xml_text: str) -> bool:
        """Return True if xml_text triggers DOCTYPE/ENTITY regex or expat entity hooks."""
        if XXE_PATTERN.search(xml_text) is not None:
            return True
        flagged = False
        parser = expat.ParserCreate()

        def _abort_dtd(*_args: object) -> None:
            nonlocal flagged
            flagged = True

        parser.StartDoctypeDeclHandler = _abort_dtd
        parser.EntityDeclHandler = _abort_dtd
        try:
            parser.Parse(xml_text.lstrip("\ufeff"), True)
        except expat.ExpatError:
            return flagged
        return flagged

    def parse_dotnet_xml_safely(self, xml_text: str) -> ET.Element:
        """Validate <= 1 MiB size and block DTD/XXE via expat before parsing ElementTree DOM."""
        if len(xml_text.encode("utf-8")) > MAX_MANIFEST_BYTES:
            raise ValueError("XML manifest exceeds 1 MiB safety cap (CWE-400/CWE-776).")
        if self.detect_xml_xxe(xml_text):
            raise ValueError("XML DTD or External Entity (XXE) declaration rejected (CWE-611).")
        return ET.fromstring(xml_text.lstrip("\ufeff"))

    def _inspect_dotnet_dom(self, xml_root: ET.Element) -> Tuple[str, str]:
        """Inspect PropertyGroup DOM in identical precedence (<Version> before <VersionPrefix>)."""
        for elem in xml_root.iter():
            if _local_name(elem.tag) != "PropertyGroup":
                continue
            ver_el = next((c for c in elem if _local_name(c.tag) == "Version"), None)
            if ver_el is not None and (ver_el.text or "").strip():
                val = (ver_el.text or "").strip()
                if "$(" in val:
                    raise ValueError(f"MSBuild macro expression '{val}' cannot be mutated directly.")
                return "version", val
            pfx_el = next((c for c in elem if _local_name(c.tag) == "VersionPrefix"), None)
            if pfx_el is not None and (pfx_el.text or "").strip():
                sfx_el = next((c for c in elem if _local_name(c.tag) == "VersionSuffix"), None)
                prefix = (pfx_el.text or "").strip()
                suffix = (sfx_el.text or "").strip() if sfx_el is not None else ""
                combined = f"{prefix}-{suffix}" if suffix else prefix
                if "$(" in combined:
                    raise ValueError(f"MSBuild macro expression '{combined}' cannot be mutated directly.")
                return "prefix_suffix", combined
        raise NoVersionElementError("No <Version> or <VersionPrefix> element found in MSBuild DOM.")

    def compute_bump_base(
        self, start_parent_ver: str, current_parent_ver: str, current_branch_base_ver: str
    ) -> str:
        """Return the highest semantic version among start parent, current parent, and branch."""
        highest = start_parent_ver
        for cand in (current_parent_ver, current_branch_base_ver):
            if compare_semver(cand, highest) > 0:
                highest = cand
        return highest

    def discover_manifest(self, root: Union[str, Path]) -> Optional[ManifestInfo]:
        """Discover the authoritative project version manifest in canonical priority order."""
        path = Path(root)
        candidates = [
            ("nbgv", path / "version.json", self._read_nbgv),
            ("dotnet", path / "Directory.Build.props", self._read_dotnet),
        ]
        for csproj in sorted(path.glob("*.csproj"))[:1]:
            candidates.append(("dotnet", csproj, self._read_dotnet))
        candidates.extend([
            ("node", path / "package.json", self._read_node),
            ("python", path / "pyproject.toml", self._read_python),
            ("plaintext", path / "VERSION", lambda p: _read_raw_text(p).lstrip("\ufeff").strip()),
        ])
        for mtype, fpath, reader in candidates:
            if fpath.exists() or fpath.is_symlink():
                self._validate_manifest_file(path, fpath)
                if fpath.is_file():
                    try:
                        return ManifestInfo(mtype, fpath.name, reader(fpath))
                    except NoVersionElementError:
                        # Safe (XXE/size/macro checks already passed) but version-less MSBuild
                        # property sheets, e.g. analyzer settings, must not shadow later manifests.
                        continue
        return None

    def read_version(self, root: Union[str, Path]) -> str:
        """Read the current project version from the primary manifest (default '0.1.0')."""
        manifest = self.discover_manifest(root)
        return manifest.raw_version if manifest else "0.1.0"

    def _parse_nbgv(self, text: str) -> str:
        return str(json.loads(_strip_jsonc_comments(text.lstrip("\ufeff"))).get("version", ""))

    def _parse_dotnet(self, text: str) -> str:
        _, version = self._inspect_dotnet_dom(self.parse_dotnet_xml_safely(text))
        return version

    def _parse_node(self, text: str) -> str:
        return str(json.loads(text.lstrip("\ufeff")).get("version", ""))

    def _parse_python(self, raw: str, label: str = "pyproject.toml") -> str:
        for sec_match in _TOML_SECTION_RE.finditer(raw):
            ver_match = _TOML_VERSION_LINE_RE.search(sec_match.group(1))
            if ver_match:
                return ver_match.group(2)
        match = _TOML_VERSION_LINE_RE.search(raw)
        if match:
            return match.group(2)
        raise ValueError(f"No version field found in [project] or [tool.poetry] of: {label}")

    def _read_nbgv(self, path: Path) -> str:
        return self._parse_nbgv(_read_raw_text(path))

    def _read_dotnet(self, path: Path) -> str:
        return self._parse_dotnet(_read_raw_text(path))

    def _read_node(self, path: Path) -> str:
        return self._parse_node(_read_raw_text(path))

    def _read_python(self, path: Path) -> str:
        return self._parse_python(_read_raw_text(path), str(path))

    def read_version_from_text(self, manifest_name: str, text: str) -> str:
        """Parse a version from manifest text (e.g. a ``git show <sha>:<file>`` blob) by file name.

        Applies the same XXE/size/macro protections as on-disk reads.

        Raises:
            ValueError: If the manifest name is unsupported or the content is unsafe/invalid.
        """
        name = manifest_name.lower()
        if name == "version.json":
            return self._parse_nbgv(text)
        if name == "package.json":
            return self._parse_node(text)
        if name == "pyproject.toml":
            return self._parse_python(text, manifest_name)
        if name == "version":
            return text.lstrip("\ufeff").strip()
        if name == "directory.build.props" or name.endswith(".csproj"):
            return self._parse_dotnet(text)
        raise ValueError(f"Unsupported manifest name: '{manifest_name}'")

    def _write_python(self, target: Path, new_version: str) -> None:
        raw = _read_raw_text(target)
        for sec_match in _TOML_SECTION_RE.finditer(raw):
            sec_body = sec_match.group(1)
            ver_match = _TOML_VERSION_LINE_RE.search(sec_body)
            if ver_match:
                sec_start = sec_match.start(1)
                v_start, v_end = sec_start + ver_match.start(2), sec_start + ver_match.end(2)
                _safe_write_text(target, f"{raw[:v_start]}{new_version}{raw[v_end:]}")
                return
        _safe_write_text(
            target, _sub_first_field(raw, r'(version\s*=\s*["\'])[^"\']+(["\'])', new_version)
        )

    def write_version(self, root: Union[str, Path], new_version: str) -> None:
        """Validate new_version, enforce monotonic non-regression, and atomically update the manifest."""
        parse_semver(new_version, allow_height=True)
        path = Path(root)
        manifest = self.discover_manifest(path)
        if not manifest:
            _safe_write_text(path / "VERSION", f"{new_version}\n")
            return

        if compare_semver(new_version, manifest.raw_version) < 0:
            raise ValueError(
                f"MONOTONIC VIOLATION: refusing to regress '{manifest.raw_version}' -> '{new_version}'."
            )

        target = path / manifest.relative_path
        self._validate_manifest_file(path, target)
        if manifest.manifest_type == "nbgv":
            _safe_write_text(
                target,
                _sub_first_field(_read_raw_text(target), r'("version"\s*:\s*")[^"]+(")', new_version),
            )
        elif manifest.manifest_type == "dotnet":
            if target.suffix.lower() == ".csproj":
                for csproj in sorted(path.glob("*.csproj")):
                    self._validate_manifest_file(path, csproj)
                    self._write_dotnet(csproj, new_version)
            else:
                self._write_dotnet(target, new_version)
        elif manifest.manifest_type == "node":
            self._write_node(path, new_version)
        elif manifest.manifest_type == "python":
            self._write_python(target, new_version)
        elif manifest.manifest_type == "plaintext":
            _safe_write_text(target, f"{new_version}\n")

    def _write_dotnet(self, props_path: Path, new_ver: str) -> None:
        """Update <Version> or <VersionPrefix>/<VersionSuffix> preserving comments, X.Y, and CRLF."""
        content = _read_raw_text(props_path)
        mode, _ = self._inspect_dotnet_dom(self.parse_dotnet_xml_safely(content))
        if mode == "version":
            updated, _ = _replace_outside_xml_comments(content, "Version", new_ver)
            _safe_write_text(props_path, updated)
            return

        sv = parse_semver(new_ver, allow_height=True)
        prefix, suffix = sv.format_base(), (sv.prerelease or "")
        updated, _ = _replace_outside_xml_comments(content, "VersionPrefix", prefix)
        updated_sfx, replaced_sfx = _replace_outside_xml_comments(updated, "VersionSuffix", suffix)
        if replaced_sfx:
            _safe_write_text(props_path, updated_sfx)
            return
        if suffix:
            eol = "\r\n" if "\r\n" in content else "\n"
            m_pfx = re.search(
                r"([ \t]*)<VersionPrefix(?:\s[^>]*)?>[^<]*</VersionPrefix>",
                _mask_xml_comments(updated),
            )
            if m_pfx:
                indent, end = m_pfx.group(1), m_pfx.end()
                updated = (
                    f"{updated[:end]}{eol}{indent}<VersionSuffix>{suffix}</VersionSuffix>{updated[end:]}"
                )
        _safe_write_text(props_path, updated)

    def _write_node(self, root: Path, new_ver: str) -> None:
        pkg_path = root / "package.json"
        _safe_write_text(
            pkg_path,
            _sub_first_field(_read_raw_text(pkg_path), r'("version"\s*:\s*")[^"]+(")', new_ver),
        )
        lock_path = root / "package-lock.json"
        if lock_path.exists() or lock_path.is_symlink():
            self._validate_manifest_file(root, lock_path)
            lock_data = json.loads(_read_raw_text(lock_path).lstrip("\ufeff"))
            lock_data["version"] = new_ver
            if "packages" in lock_data and "" in lock_data["packages"]:
                lock_data["packages"][""]["version"] = new_ver
            _safe_write_text(lock_path, json.dumps(lock_data, indent=2) + "\n")
