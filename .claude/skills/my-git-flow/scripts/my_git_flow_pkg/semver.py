"""Semantic versioning engine, anti-ReDoS validation, and Dual-Baseline evaluation.

Supports 1-, 2-, and 3-segment versions, NBGV {height} tokens in base and prerelease,
linear integer prerelease counters (-alpha<N>, -beta<N>, -rc<N>), and branch slug guards.
"""

import re
import unicodedata
from typing import Optional, Tuple, Union

from .models import BumpLevel, DualBaselineResult, SemVer

MAX_VERSION_LEN = 128
MAX_FEATURE_LEN = 100
MAX_RAW_SLUG_LEN = 512

SEMVER_REGEX = re.compile(
    r"\A(?P<major>0|[1-9]\d{0,14})"
    r"(?:\.(?P<seg2>0|[1-9]\d{0,14}|\{height\}))?"
    r"(?:\.(?P<seg3>0|[1-9]\d{0,14}|\{height\}))?"
    r"(?:[-_](?P<prerelease>[0-9a-zA-Z.{}-]{1,64}))?"
    r"(?:\+(?P<buildmetadata>[0-9a-zA-Z.-]{1,64}))?\Z"
)

BRANCH_SLUG_REGEX = re.compile(r"\A[a-z0-9][a-z0-9_.-]{0,99}\Z")
_NON_SLUG_CHARS_RE = re.compile(r"[^a-z0-9._-]+")
_HYPHEN_RUN_RE = re.compile(r"-+")
LIFECYCLE_COUNTER_REGEX = re.compile(r"\A(?P<tag>alpha|beta|rc)(?P<digits>\d+)\Z")
PRERELEASE_ATOM_REGEX = re.compile(
    r"\A(?:\{height\}|0|[1-9]\d{0,14}|[0-9a-zA-Z-]*[a-zA-Z-][0-9a-zA-Z-]*)\Z"
)


def _has_forbidden_chars(text: str) -> bool:
    """Return True if text contains control bytes, newlines, NUL, or whitespace."""
    return any(ch in text for ch in ("\n", "\r", "\x00", "\t", " ")) or any(
        ord(ch) < 32 or ord(ch) == 127 for ch in text
    )


def _is_valid_prerelease(prerelease: str, allow_height: bool = True) -> bool:
    """Validate prerelease atoms, 1..6 digit bounds without leading zeros, and optional {height}."""
    if not prerelease or prerelease.startswith(".") or prerelease.endswith(".") or ".." in prerelease:
        return False
    for part in prerelease.split("."):
        if part == "{height}":
            if not allow_height:
                return False
            continue
        if "{" in part or "}" in part:
            return False
        lc_match = LIFECYCLE_COUNTER_REGEX.match(part)
        if lc_match:
            digits = lc_match.group("digits")
            if digits.startswith("0") or len(digits) > 6:
                return False
            continue
        if not PRERELEASE_ATOM_REGEX.match(part):
            return False
    return True


def normalize_branch_slug(raw: str) -> str:
    """Normalize a raw human title or version identifier into a safe lowercase GitFlow slug.

    Evaluates CWE-78/CWE-22 pre-guards (leading dash, slashes, ``..``, ``@{``, ``.lock``,
    trailing dot, and control bytes) prior to NFKD ASCII accent folding and punctuation
    replacement so hostile tokens never sanitize into seemingly benign slugs.

    Args:
        raw: Untrusted human branch title or SemVer identifier.

    Returns:
        Lowercase hyphenated slug (``[a-z0-9._-]``), or ``""`` when pre-guards reject ``raw``.
    """
    if not raw or len(raw) > MAX_RAW_SLUG_LEN or any(ord(ch) < 32 or ord(ch) == 127 for ch in raw):
        return ""
    trimmed = raw.strip(" ")
    lower_trimmed = trimmed.lower()
    if (
        not trimmed
        or trimmed.startswith("-")
        or "/" in trimmed
        or "\\" in trimmed
        or ".." in trimmed
        or "@{" in trimmed
        or lower_trimmed.endswith(".")
        or lower_trimmed.endswith(".lock")
    ):
        return ""
    ascii_folded = "".join(
        ch
        for ch in unicodedata.normalize("NFKD", lower_trimmed)
        if not unicodedata.combining(ch) and ord(ch) < 128
    )
    return _HYPHEN_RUN_RE.sub("-", _NON_SLUG_CHARS_RE.sub("-", ascii_folded)).strip("-")


def validate_branch_slug(slug: str) -> bool:
    """Validate that a normalized branch slug is strictly lowercase, bounded, and ref-safe.

    Args:
        slug: Candidate lowercase branch slug (without family prefix).

    Returns:
        True if ``slug`` matches ``BRANCH_SLUG_REGEX`` and excludes ``..``, ``.lock``, and slashes.
    """
    if not slug or len(slug) > MAX_FEATURE_LEN or _has_forbidden_chars(slug):
        return False
    if (
        slug.startswith("-")
        or slug.endswith(".")
        or slug.endswith(".lock")
        or "/" in slug
        or "\\" in slug
        or ".." in slug
        or "@{" in slug
    ):
        return False
    return BRANCH_SLUG_REGEX.match(slug) is not None


def validate_feature_name(name: str) -> bool:
    """Validate that a feature branch identifier is safe, bounded, and free of traversal or flags."""
    return validate_branch_slug(name)


def validate_version_str(version_str: str, allow_height: bool = True) -> bool:
    """Validate a version string; set allow_height=False to reject {height} in CLI overrides."""
    try:
        parse_semver(version_str, allow_height=allow_height)
        return True
    except ValueError:
        return False


def parse_semver(version_str: str, allow_height: bool = True) -> SemVer:
    """Parse a version string into a SemVer value object preserving segment granularity.

    Args:
        version_str: Manifest or CLI version string (<= 128 chars, <= 15 digits/segment).
        allow_height: Rejects ``{height}`` when False so explicit user overrides stay concrete.

    Returns:
        Frozen ``SemVer`` retaining original ``segment_count`` and ``height_index``.

    Raises:
        ValueError: If length/digit bounds, anchors, control bytes, or token rules are violated.
    """
    if (
        not version_str
        or len(version_str) > MAX_VERSION_LEN
        or _has_forbidden_chars(version_str)
        or version_str.startswith(("-", "v"))
    ):
        raise ValueError(f"Invalid semantic version string: '{version_str}'")

    match = SEMVER_REGEX.match(version_str)
    if not match:
        raise ValueError(f"Invalid semantic version string: '{version_str}'")

    major = int(match.group("major"))
    seg2, seg3 = match.group("seg2"), match.group("seg3")
    if (seg2 is None and seg3 is not None) or (seg2 == "{height}" and seg3 is not None):
        raise ValueError(f"Invalid semantic version string: '{version_str}'")

    height_index: Optional[int] = None
    raw_token: Optional[str] = None
    if seg2 is None:
        segment_count, minor, patch = 1, 0, 0
    elif seg3 is None:
        segment_count = 2
        minor, patch = (0, 0) if seg2 == "{height}" else (int(seg2), 0)
        if seg2 == "{height}":
            height_index, raw_token = 1, "{height}"
    else:
        segment_count, minor = 3, int(seg2)
        patch = 0 if seg3 == "{height}" else int(seg3)
        if seg3 == "{height}":
            height_index, raw_token = 2, "{height}"

    if height_index is not None and not allow_height:
        raise ValueError("NBGV '{height}' token is forbidden in explicit version overrides.")

    prerelease = match.group("prerelease")
    if prerelease is not None and not _is_valid_prerelease(prerelease, allow_height=allow_height):
        raise ValueError(f"Invalid prerelease identifier in version: '{version_str}'")

    return SemVer(
        major=major,
        minor=minor,
        patch=patch,
        prerelease=prerelease,
        build_metadata=match.group("buildmetadata"),
        raw_token=raw_token,
        segment_count=segment_count,
        height_index=height_index,
    )


def normalize_prerelease(version_str: str) -> str:
    """Normalize underscore prerelease separators into standard hyphens while preserving precision."""
    try:
        return str(parse_semver(version_str, allow_height=True))
    except ValueError:
        return version_str


def base_version_str(version_str: str) -> str:
    """Return the version string stripped of prerelease and build metadata, preserving {height}."""
    return parse_semver(version_str, allow_height=True).format_base()


def resolve_tag_version_3seg(version_str: str, resolved_height: int = 0) -> str:
    """Render a concrete 3-segment X.Y.Z string for v.{x.y.z} Git tags without touching version.json.

    Args:
        version_str: Source version string (1-, 2-, or 3-segment, optionally containing ``{height}``).
        resolved_height: Commit height integer (default ``0`` when NBGV CLI is unavailable).

    Returns:
        Normalized ``MAJOR.MINOR.PATCH`` string suitable for ``v.{x.y.z}`` tags.
    """
    sv = parse_semver(version_str, allow_height=True)
    minor = resolved_height if sv.height_index == 1 else sv.minor
    patch = resolved_height if sv.height_index == 2 else sv.patch
    return f"{sv.major}.{minor}.{patch}"


def _split_lifecycle_atom(atom: str) -> Optional[Tuple[str, int]]:
    """Extract (tag, counter) when atom is alpha<N>, beta<N>, or rc<N>."""
    m = LIFECYCLE_COUNTER_REGEX.match(atom)
    if not m:
        return None
    return m.group("tag"), int(m.group("digits"))


def _compare_prerelease_parts(p1: str, p2: str) -> int:
    """Compare two prerelease strings with integer precedence for alpha<N>/beta<N>/rc<N>."""
    if not p1 and not p2:
        return 0
    if not p1 and p2:
        return 1
    if p1 and not p2:
        return -1

    parts1, parts2 = p1.split("."), p2.split(".")
    for sub1, sub2 in zip(parts1, parts2):
        if sub1 == "{height}" and sub2 == "{height}":
            continue
        lc1, lc2 = _split_lifecycle_atom(sub1), _split_lifecycle_atom(sub2)
        if lc1 and lc2:
            if lc1[0] != lc2[0]:
                return 1 if lc1[0] > lc2[0] else -1
            if lc1[1] != lc2[1]:
                return 1 if lc1[1] > lc2[1] else -1
            continue
        is_num1 = sub1.isdigit() or sub1 == "{height}"
        is_num2 = sub2.isdigit() or sub2 == "{height}"
        if is_num1 and is_num2:
            n1 = 0 if sub1 == "{height}" else int(sub1)
            n2 = 0 if sub2 == "{height}" else int(sub2)
            if n1 != n2:
                return 1 if n1 > n2 else -1
        elif is_num1 != is_num2:
            return -1 if is_num1 else 1
        elif sub1 != sub2:
            return 1 if sub1 > sub2 else -1

    if len(parts1) != len(parts2):
        return 1 if len(parts1) > len(parts2) else -1
    return 0


def compare_semver(v1: str, v2: str) -> int:
    """Compare two SemVer strings according to SemVer 2.0.0 + integer lifecycle rules."""
    base_cmp = compare_base_semver(v1, v2)
    if base_cmp != 0:
        return base_cmp
    return _compare_prerelease_parts(
        parse_semver(v1).prerelease or "", parse_semver(v2).prerelease or ""
    )


def compare_base_semver(v1: str, v2: str) -> int:
    """Compare numeric core segments only, ignoring prerelease suffixes and {height} tokens."""
    sv1, sv2 = parse_semver(v1), parse_semver(v2)
    for a, b in ((sv1.major, sv2.major), (sv1.minor, sv2.minor), (sv1.patch, sv2.patch)):
        if a != b:
            return 1 if a > b else -1
    return 0


def max_semver(*versions: str) -> str:
    """Return the highest full semantic version among the given arguments."""
    if not versions:
        raise ValueError("At least one version is required.")
    best = versions[0]
    for cand in versions[1:]:
        if compare_semver(cand, best) > 0:
            best = cand
    return best


def bump_version(version_str: str, bump_level: Union[BumpLevel, str] = BumpLevel.PATCH) -> str:
    """Increment the target or least-significant numeric segment before {height}, preserving shape."""
    level = BumpLevel(bump_level) if isinstance(bump_level, str) else bump_level
    sv = parse_semver(version_str)
    numeric_count = sv.height_index if sv.height_index is not None else sv.segment_count

    if numeric_count == 1 or level == BumpLevel.MAJOR:
        major, minor, patch = sv.major + 1, 0, 0
    elif numeric_count == 2 or level == BumpLevel.MINOR:
        major, minor, patch = sv.major, sv.minor + 1, 0
    elif level == BumpLevel.PATCH:
        major, minor, patch = sv.major, sv.minor, sv.patch + 1
    else:
        raise ValueError(f"Unsupported bump level: {level}")

    return SemVer(
        major=major,
        minor=minor,
        patch=patch,
        segment_count=sv.segment_count,
        height_index=sv.height_index,
        raw_token=sv.raw_token,
    ).format_base()


def evaluate_dual_baseline(
    branch_ver: str, start_parent_ver: str, current_parent_ver: str
) -> DualBaselineResult:
    """Evaluate cryptographic Dual-Baseline version gate constraints."""
    for label, ref_ver in (
        ("CurrentParentVersion", current_parent_ver),
        ("StartParentVersion", start_parent_ver),
    ):
        if compare_semver(branch_ver, ref_ver) <= 0:
            msg = (
                f"Dual-Baseline violation: Branch version '{branch_ver}' must be strictly "
                f"greater than {label} '{ref_ver}'."
            )
            return DualBaselineResult(False, branch_ver, start_parent_ver, current_parent_ver, msg)
    return DualBaselineResult(True, branch_ver, start_parent_ver, current_parent_ver)
