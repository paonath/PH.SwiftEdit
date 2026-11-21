---
description: "Finish active release branch, strip -rc, and tag production (HUMAN-ONLY TRIGGER — DO NOT AUTONOMOUSLY INVOKE. Orchestrates the 6 GitFlow lifecycles (StartFeature, FinishFeature, StartRelease, FinishRelease, StartHotfix, FinishHotfix) with strictly monotonic SemVer 2.0.0 versioning, dual tags, NBGV {height} protection, and Build/Test gates.)"
argument-hint: "[version] [--notes <text>]"
disable-model-invocation: true
---
Invoke the `my-git-flow` (`finish-release`) skill with: $ARGUMENTS
