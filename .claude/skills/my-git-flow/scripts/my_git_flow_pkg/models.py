"""Data models and enums for my-git-flow.

Defines core data structures for workflows, versioning, and status codes.
"""

from dataclasses import dataclass
from enum import Enum
from typing import Optional


class ExitCode(int, Enum):
    """Standardized process exit codes for my-git-flow CLI."""

    SUCCESS = 0
    VALIDATION_ERROR = 1
    PARSE_ERROR = 2
    SECURITY_REJECTION = 3
    CHECKPOINT_HALT = 10
    DIRTY_TREE_ABORT = 20


class WorkflowType(str, Enum):
    """Supported GitFlow workflow types."""

    START_FEATURE = "start-feature"
    FINISH_FEATURE = "finish-feature"
    START_RELEASE = "start-release"
    FINISH_RELEASE = "finish-release"
    START_HOTFIX = "start-hotfix"
    FINISH_HOTFIX = "finish-hotfix"


class BumpLevel(str, Enum):
    """Semantic version bump levels."""

    PATCH = "patch"
    MINOR = "minor"
    MAJOR = "major"


@dataclass(frozen=True)
class SemVer:
    """Semantic version value object preserving manifest segment granularity and NBGV tokens."""

    major: int
    minor: int
    patch: int
    prerelease: Optional[str] = None
    build_metadata: Optional[str] = None
    raw_token: Optional[str] = None
    segment_count: int = 3
    height_index: Optional[int] = None

    def format_base(self) -> str:
        """Render the core version without prerelease or build metadata preserving segment shape."""
        if self.segment_count == 1:
            return f"{self.major}"
        if self.segment_count == 2:
            if self.height_index == 1:
                return f"{self.major}.{{height}}"
            return f"{self.major}.{self.minor}"
        if self.height_index == 2 or self.raw_token == "{height}":
            return f"{self.major}.{self.minor}.{{height}}"
        return f"{self.major}.{self.minor}.{self.patch}"

    def __str__(self) -> str:
        """Format complete semantic version string preserving precision and tokens."""
        base = self.format_base()
        if self.prerelease:
            base = f"{base}-{self.prerelease}"
        if self.build_metadata:
            base = f"{base}+{self.build_metadata}"
        return base


@dataclass(frozen=True)
class DualBaselineResult:
    """Evaluation result for the Dual-Baseline Version Gate."""

    valid: bool
    branch_version: str
    start_parent_version: str
    current_parent_version: str
    error_message: str = ""


@dataclass(frozen=True)
class ManifestInfo:
    """Metadata regarding a discovered project version manifest."""

    manifest_type: str
    relative_path: str
    raw_version: str
