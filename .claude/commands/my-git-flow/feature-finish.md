---
description: "Finish active feature branch and merge into develop (HUMAN-ONLY TRIGGER — DO NOT AUTONOMOUSLY INVOKE. Orchestrates the 6 GitFlow lifecycles (StartFeature, FinishFeature, StartRelease, FinishRelease, StartHotfix, FinishHotfix) with strictly monotonic SemVer 2.0.0 versioning, dual tags, NBGV {height} protection, and Build/Test gates.)"
argument-hint: "[name] [--bump patch|minor|major] [--notes <text>]"
disable-model-invocation: true
---
Invoke the `my-git-flow` (`finish-feature`) skill with: $ARGUMENTS
