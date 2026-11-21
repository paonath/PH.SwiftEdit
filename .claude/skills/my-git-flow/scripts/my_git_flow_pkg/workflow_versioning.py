"""Pure GitFlow prerelease lifecycle transition calculations.

Encapsulates deterministic SemVer 2.0.0 and NBGV transition rules across Feature,
Release, and Hotfix start/finish workflows with zero filesystem or Git I/O.
"""

import re
from typing import Optional, Tuple, Union

from .models import BumpLevel, SemVer
from .semver import (
    base_version_str,
    bump_version,
    compare_base_semver,
    compare_semver,
    max_semver,
    normalize_branch_slug,
    parse_semver,
    validate_branch_slug,
)

_LIFECYCLE_ATOM_RE = re.compile(r"\A(?P<tag>alpha|beta|rc)(?P<n>[1-9]\d{0,5})\Z")
_RC_ATOM_RE = re.compile(r"\Arc(?P<n>[1-9]\d{0,5})\Z")
_BETA_ATOM_RE = re.compile(r"\Abeta(?P<n>[1-9]\d{0,5})\Z")


def _with_shape_from(
    template: SemVer, target_numeric: SemVer, prerelease: Optional[str] = None
) -> str:
    """Format target_numeric preserving template shape, promoting segment_count to prevent truncation."""
    seg_count = template.segment_count
    if template.height_index is None:
        if target_numeric.patch != 0 and seg_count < 3:
            seg_count = 3
        elif target_numeric.minor != 0 and seg_count < 2:
            seg_count = 2
    shaped = SemVer(
        major=target_numeric.major,
        minor=target_numeric.minor,
        patch=target_numeric.patch,
        prerelease=prerelease or None,
        segment_count=seg_count,
        height_index=template.height_index,
        raw_token=template.raw_token,
    )
    return str(shaped)


def compute_max_base_version(*versions: str) -> str:
    """Return the version with the highest numeric core, promoting shape if needed."""
    if not versions:
        raise ValueError("At least one version is required.")
    template = parse_semver(versions[0])
    highest = template
    for raw in versions[1:]:
        cand = parse_semver(raw)
        if compare_base_semver(str(cand), str(highest)) > 0:
            highest = cand
    return _with_shape_from(template, highest)


def increment_prerelease_suffix(version_str: str) -> Optional[str]:
    """Increment integer counter in -alphaN, -betaN, -rcN while preserving .{height}."""
    sv = parse_semver(version_str)
    if not sv.prerelease:
        return None
    parts = sv.prerelease.split(".")
    new_parts = list(parts)
    incremented = False
    for i, part in enumerate(parts):
        m = _LIFECYCLE_ATOM_RE.match(part)
        if m:
            tag, n = m.group("tag"), int(m.group("n"))
            new_parts[i] = f"{tag}{n + 1}"
            incremented = True
            break
        if part in ("alpha", "beta", "rc") and i + 1 < len(parts) and parts[i + 1].isdigit():
            new_parts[i + 1] = str(int(parts[i + 1]) + 1)
            incremented = True
            break
    if not incremented:
        return None
    return _with_shape_from(sv, sv, prerelease=".".join(new_parts))


def has_rc_suffix(version_str: str) -> bool:
    """Return True if version_str carries an -rc<N> or -rc.<N> prerelease identifier."""
    sv = parse_semver(version_str)
    if not sv.prerelease:
        return False
    parts = sv.prerelease.split(".")
    return any(_RC_ATOM_RE.match(p) or p == "rc" for p in parts)


def compute_start_feature_version(
    develop_ver: str,
    bump_level: Union[BumpLevel, str] = BumpLevel.PATCH,
    explicit_bump: bool = False,
) -> str:
    """Compute StartFeature version per Point 4.

    Increments the existing prerelease suffix counter when develop carries one;
    otherwise bumps the numeric base +1 and appends ``-alpha1``.
    """
    sv = parse_semver(develop_ver)
    if sv.prerelease and not explicit_bump:
        inc = increment_prerelease_suffix(develop_ver)
        if inc is not None:
            return inc
        bumped_base = bump_version(develop_ver, bump_level)
        return f"{bumped_base}-{sv.prerelease}"
    bumped_base = bump_version(develop_ver, bump_level)
    return f"{bumped_base}-alpha1"


def compute_finish_feature_version(
    branch_ver: str,
    start_parent_ver: str,
    current_parent_ver: str,
    bump_level: Union[BumpLevel, str] = BumpLevel.PATCH,
) -> str:
    """Compute FinishFeature version per Point 5 and Point 2 (Refinement R2).

    Increments the prerelease suffix +1 on closure (realigning to max(branch, parent) first)
    when branch_ver has a prerelease suffix; leaves clean manual versions untouched if >= parent.
    """
    highest = max_semver(branch_ver, start_parent_ver, current_parent_ver)
    branch_sv = parse_semver(branch_ver)
    highest_sv = parse_semver(highest)

    if branch_sv.prerelease:
        if compare_semver(branch_ver, highest) >= 0:
            inc = increment_prerelease_suffix(branch_ver)
            if inc is not None:
                return inc
            # Custom prerelease (e.g. -dev): never keep it unchanged, always advance strictly.
            return f"{bump_version(_with_shape_from(branch_sv, highest_sv), bump_level)}-alpha1"
        if highest_sv.prerelease:
            inc = increment_prerelease_suffix(highest)
            if inc is not None:
                inc_sv = parse_semver(inc)
                return _with_shape_from(branch_sv, inc_sv, inc_sv.prerelease)
        bumped = bump_version(_with_shape_from(branch_sv, highest_sv), bump_level)
        return f"{bumped}-alpha1"

    if (
        compare_semver(branch_ver, current_parent_ver) >= 0
        and compare_semver(branch_ver, start_parent_ver) >= 0
    ):
        return normalize_if_valid(branch_ver)
    return bump_version(_with_shape_from(branch_sv, highest_sv), bump_level)


def compute_start_release_version(
    develop_ver: str, bump_level: Union[BumpLevel, str] = BumpLevel.PATCH
) -> Tuple[str, Optional[str]]:
    """Compute StartRelease version per Point 6 and Point 2.

    Returns ``(manifest_version, optional_warning)``. Increments ``-rcN -> -rc(N+1)``;
    transitions ``-alphaN``/``-betaN`` to ``-rc1``; auto-bumps clean ``develop`` +1 + ``-rc1``
    with an explicit warning to prevent SemVer regression (``X.Y.Z-rc1 < X.Y.Z``).
    """
    sv = parse_semver(develop_ver)
    if has_rc_suffix(develop_ver):
        inc = increment_prerelease_suffix(develop_ver)
        if inc is not None:
            return inc, None
        bumped = bump_version(develop_ver, bump_level)
        return f"{bumped}-{sv.prerelease}", None

    if sv.prerelease:
        parts = sv.prerelease.split(".")
        cand = (
            f"{sv.format_base()}-rc1.{{height}}" if "{height}" in parts else f"{sv.format_base()}-rc1"
        )
        if compare_semver(cand, develop_ver) < 0:
            # A custom prerelease sorting above rc1 (e.g. -z1) must never be replaced by a lower -rc1.
            return f"{bump_version(develop_ver, bump_level)}-rc1", None
        return cand, None

    bumped = bump_version(develop_ver, bump_level)
    cand = f"{bumped}-rc1"
    warn = (
        f"WARNING [CLEAN_DEVELOP_BUMPED_FOR_RC]: develop was at clean version '{develop_ver}'; "
        f"auto-bumped to '{cand}' to preserve SemVer 2.0.0 monotonicity ('{develop_ver}-rc1' < '{develop_ver}')."
    )
    return cand, warn


def compute_finish_release_version(release_manifest_ver: str) -> str:
    """Strip prerelease suffix from the active release manifest preserving {height}."""
    return base_version_str(release_manifest_ver)


def compute_start_hotfix_version(
    prod_ver: str, bump_level: Union[BumpLevel, str] = BumpLevel.PATCH
) -> str:
    """Compute StartHotfix version: base(prod) + 1 + '-beta1'."""
    bumped_base = bump_version(prod_ver, bump_level)
    return f"{bumped_base}-beta1"


def compute_finish_hotfix_version(hotfix_manifest_ver: str) -> str:
    """Strip prerelease suffix from the active hotfix manifest preserving {height}."""
    return base_version_str(hotfix_manifest_ver)


def compute_post_merge_develop_version(
    pre_merge_develop_ver: str,
    finalized_prod_ver: str,
    bump_level: Union[BumpLevel, str] = BumpLevel.PATCH,
) -> str:
    """Compute post-release/post-hotfix develop version per Point 8 (Option 8A) and Point 2.

    Always increments +1 on ``max_semver(pre_merge_develop_ver, finalized_prod_ver)``:
    increments the prerelease suffix if the maximum carries one, or bumps the numeric base +1 if clean.
    """
    dev_sv = parse_semver(pre_merge_develop_ver)
    highest = max_semver(pre_merge_develop_ver, finalized_prod_ver)
    highest_sv = parse_semver(highest)
    shaped_highest = _with_shape_from(dev_sv, highest_sv, highest_sv.prerelease)
    if highest_sv.prerelease:
        inc = increment_prerelease_suffix(shaped_highest)
        if inc is not None:
            return inc
        bumped = bump_version(shaped_highest, bump_level)
        return f"{bumped}-{highest_sv.prerelease}"
    return bump_version(shaped_highest, bump_level)


def compute_post_hotfix_develop_version(
    pre_merge_develop_ver: str,
    finalized_hotfix_ver: str,
    bump_level: Union[BumpLevel, str] = BumpLevel.PATCH,
) -> str:
    """Alias for compute_post_merge_develop_version preserving backward caller compatibility."""
    return compute_post_merge_develop_version(pre_merge_develop_ver, finalized_hotfix_ver, bump_level)


def compute_propagated_release_version(
    release_manifest_ver: str,
    finalized_hotfix_ver: str,
    bump_level: Union[BumpLevel, str] = BumpLevel.PATCH,
) -> str:
    """If base(release) <= hotfix, bump to base(hotfix) + 1 preserving -rc<N>; else keep release."""
    if compare_base_semver(release_manifest_ver, finalized_hotfix_ver) <= 0:
        rel_sv = parse_semver(release_manifest_ver)
        hf_sv = parse_semver(finalized_hotfix_ver)
        rc_sfx = rel_sv.prerelease if has_rc_suffix(release_manifest_ver) else "rc1"
        shaped_hf = _with_shape_from(rel_sv, hf_sv)
        bumped = bump_version(shaped_hf, bump_level)
        return f"{bumped}-{rc_sfx}"
    return normalize_if_valid(release_manifest_ver)


def normalize_if_valid(version_str: str) -> str:
    """Return canonical string form of version_str preserving shape and prerelease."""
    return str(parse_semver(version_str))


def resolve_start_release_plan(
    dev_ver: str,
    prod_ver: str,
    prod_branch: str,
    explicit_id: str | None = None,
    override: bool = False,
) -> tuple[int, str, str, Optional[str]]:
    """Compute (exit_code, branch_slug_or_err, manifest_ver, optional_warning) for StartRelease (R3)."""
    auto_ver, auto_warn = compute_start_release_version(dev_ver)
    auto_base = base_version_str(auto_ver)

    if explicit_id is None:
        if compare_base_semver(auto_base, prod_ver) <= 0:
            return (
                2,
                f"StartRelease gate blocked: candidate release '{auto_base}' (from develop '{dev_ver}') "
                f"does not exceed {prod_branch} ('{prod_ver}').",
                "",
                None,
            )
        return 0, auto_base, auto_ver, auto_warn

    norm_id = normalize_branch_slug(explicit_id)
    if not norm_id:
        return 2, f"Invalid release identifier '{explicit_id}'.", "", None

    try:
        sv = parse_semver(norm_id, allow_height=False)
        is_semver = True
    except ValueError:
        sv = None
        is_semver = False

    if is_semver and sv is not None:
        branch_slug = sv.format_base()
        if not sv.prerelease and compare_base_semver(branch_slug, dev_ver) == 0:
            if compare_base_semver(auto_base, prod_ver) <= 0:
                return 2, f"Release '{auto_base}' must exceed {prod_branch} '{prod_ver}'.", "", None
            return 0, auto_base, auto_ver, auto_warn

        if compare_base_semver(branch_slug, prod_ver) <= 0:
            return 2, f"Release '{branch_slug}' must exceed {prod_branch} '{prod_ver}'.", "", None
        cand_ver = (
            str(sv)
            if sv.prerelease
            else (auto_ver if compare_base_semver(branch_slug, auto_base) == 0 else f"{branch_slug}-rc1")
        )
        if compare_semver(cand_ver, dev_ver) < 0:
            return (
                2,
                f"Monotonic violation: release '{cand_ver}' cannot be lower than develop '{dev_ver}'.",
                "",
                None,
            )
        if (
            compare_base_semver(branch_slug, dev_ver) != 0
            and compare_base_semver(branch_slug, auto_base) != 0
            and not override
        ):
            return (
                2,
                f"Version '{branch_slug}' diverges from develop '{dev_ver}'; pass --override.",
                "",
                None,
            )
        if sv.prerelease and not has_rc_suffix(str(sv)):
            return 2, f"Invalid release prerelease '{sv.prerelease}'; must be -rc<N>.", "", None
        warn = auto_warn if compare_base_semver(branch_slug, auto_base) == 0 and auto_warn else None
        return 0, branch_slug, cand_ver, warn

    if not validate_branch_slug(norm_id):
        return 2, f"Invalid release identifier '{explicit_id}'.", "", None
    if compare_base_semver(auto_base, prod_ver) <= 0:
        return (
            2,
            f"StartRelease gate blocked for named release '{norm_id}': candidate '{auto_base}' "
            f"does not exceed {prod_branch} ('{prod_ver}').",
            "",
            None,
        )
    return 0, norm_id, auto_ver, auto_warn


def resolve_start_hotfix_plan(
    prod_ver: str,
    prod_branch: str,
    explicit_id: str | None = None,
    bump_level: Union[BumpLevel, str] = BumpLevel.PATCH,
) -> tuple[int, str, str]:
    """Compute (exit_code, branch_slug_or_err, manifest_ver) for StartHotfix."""
    if explicit_id is None:
        manifest_ver = compute_start_hotfix_version(prod_ver, bump_level)
        return 0, base_version_str(manifest_ver), manifest_ver

    norm_id = normalize_branch_slug(explicit_id)
    if not norm_id:
        return 2, f"Invalid hotfix identifier '{explicit_id}'.", ""

    try:
        sv = parse_semver(norm_id, allow_height=False)
        is_semver = True
    except ValueError:
        sv = None
        is_semver = False

    if is_semver and sv is not None:
        branch_slug = sv.format_base()
        if compare_base_semver(branch_slug, prod_ver) <= 0:
            return 2, f"Hotfix '{branch_slug}' must exceed {prod_branch} '{prod_ver}'.", ""
        if sv.prerelease and not any(_BETA_ATOM_RE.match(p) for p in sv.prerelease.split(".")):
            return 2, f"Invalid hotfix prerelease '{sv.prerelease}'; must be -beta<N>.", ""
        manifest_ver = str(sv) if sv.prerelease else f"{branch_slug}-beta1"
        return 0, branch_slug, manifest_ver

    if not validate_branch_slug(norm_id):
        return 2, f"Invalid hotfix identifier '{explicit_id}'.", ""
    manifest_ver = compute_start_hotfix_version(prod_ver, bump_level)
    return 0, norm_id, manifest_ver


def resolve_finish_target_slug(
    active_branch: str, family: str, explicit_id: str | None
) -> tuple[int, str]:
    """Validate active branch family against finish-<family> and return (exit_code, slug_or_err)."""
    norm_id: Optional[str] = None
    if explicit_id is not None:
        norm_id = normalize_branch_slug(explicit_id)
        if not validate_branch_slug(norm_id):
            return 2, f"Invalid {family} identifier '{explicit_id}'."

    if active_branch.startswith(("feature/", "release/", "hotfix/")):
        act_family, act_slug = active_branch.split("/", 1)
        if act_family != family:
            return (
                2,
                f"Active branch '{active_branch}' mismatches finish-{family}; "
                f"use finish-{act_family} '{act_slug}'.",
            )
        if norm_id and norm_id != act_slug:
            return 2, f"Active branch '{active_branch}' mismatches '{family}/{norm_id}'."
        return 0, act_slug
    if not norm_id:
        return 2, f"Active branch '{active_branch}' is not '{family}/*'; specify identifier explicitly."
    return 0, norm_id



def apply_version_override(template_ver: str, override: str) -> str:
    """Map an explicit ``--set-version`` value onto the manifest shape, preserving NBGV ``{height}``.

    Only the numeric segments before ``{height}`` come from the override; any override segment at
    or after the ``{height}`` position must be ``0`` so a concrete number can never replace the token.

    Raises:
        ValueError: If the override is invalid, contains ``{height}``, or targets the height position.
    """
    ov = parse_semver(override, allow_height=False)
    template = parse_semver(template_ver)
    if template.height_index is not None:
        trailing = (ov.major, ov.minor, ov.patch)[template.height_index:]
        if ov.segment_count > template.height_index and any(trailing):
            raise ValueError(
                f"Override '{override}' sets a concrete number at the NBGV {{height}} position of '{template_ver}'."
            )
        return _with_shape_from(template, ov, ov.prerelease)
    return str(ov)


def _prerelease_matches(version: str, atom_re: "re.Pattern[str]") -> bool:
    """Return True when any prerelease identifier of version matches atom_re."""
    sv = parse_semver(version)
    return bool(sv.prerelease) and any(atom_re.match(p) for p in sv.prerelease.split("."))


def resolve_override_for_start(
    kind: str, template_ver: str, override: str, parent_ver: str, prod_ver: Optional[str] = None
) -> Tuple[int, str]:
    """Validate a start-* override; return ``(0, manifest_version)`` or ``(2, error)``.

    The result must strictly exceed ``parent_ver``. Release overrides must carry ``-rc<N>``
    (a clean value gets ``-rc1``) and exceed ``prod_ver`` by base; hotfix overrides must carry
    ``-beta<N>`` (clean gets ``-beta1``) and exceed ``prod_ver``.
    """
    try:
        shaped = apply_version_override(template_ver, override)
    except ValueError as exc:
        return 2, str(exc)
    sv = parse_semver(shaped)
    if kind == "release":
        if sv.prerelease and not _prerelease_matches(shaped, _RC_ATOM_RE):
            return 2, f"Release override '{override}' must use -rc<N> or be clean."
        shaped = shaped if sv.prerelease else f"{shaped}-rc1"
        if prod_ver is not None and compare_base_semver(shaped, prod_ver) <= 0:
            return 2, f"MONOTONIC VIOLATION: release override '{override}' must exceed production '{prod_ver}'."
    elif kind == "hotfix":
        if sv.prerelease and not _prerelease_matches(shaped, _BETA_ATOM_RE):
            return 2, f"Hotfix override '{override}' must use -beta<N> or be clean."
        shaped = shaped if sv.prerelease else f"{shaped}-beta1"
        if prod_ver is not None and compare_semver(shaped, prod_ver) <= 0:
            return 2, f"MONOTONIC VIOLATION: hotfix override '{override}' must exceed production '{prod_ver}'."
    if compare_semver(shaped, parent_ver) <= 0:
        return 2, f"MONOTONIC VIOLATION: override '{override}' must exceed parent version '{parent_ver}'."
    return 0, shaped


def resolve_override_for_finish_feature(
    template_ver: str, override: str, branch_ver: str, develop_ver: str
) -> Tuple[int, str]:
    """Validate a finish-feature override: ``>= branch_ver`` and strictly ``> develop_ver``."""
    try:
        shaped = apply_version_override(template_ver, override)
    except ValueError as exc:
        return 2, str(exc)
    if compare_semver(shaped, branch_ver) < 0 or compare_semver(shaped, develop_ver) <= 0:
        return 2, (
            f"MONOTONIC VIOLATION: override '{override}' must be >= branch '{branch_ver}' "
            f"and > develop '{develop_ver}'."
        )
    return 0, shaped


def resolve_override_for_finish_prod(
    template_ver: str, override: str, expected_final: str, prod_ver: str
) -> Tuple[int, str]:
    """Validate a finish-release/hotfix override: clean, ``>= expected_final`` and ``> prod_ver``."""
    try:
        shaped = apply_version_override(template_ver, override)
    except ValueError as exc:
        return 2, str(exc)
    if parse_semver(shaped).prerelease:
        return 2, f"MONOTONIC VIOLATION: production override '{override}' must not carry a prerelease."
    if compare_semver(shaped, expected_final) < 0 or compare_semver(shaped, prod_ver) <= 0:
        return 2, (
            f"MONOTONIC VIOLATION: override '{override}' must be >= '{expected_final}' "
            f"and > production '{prod_ver}'."
        )
    return 0, shaped
