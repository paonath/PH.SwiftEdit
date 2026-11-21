---
description: "Start a hotfix branch from production (+1 -beta1) (HUMAN-ONLY TRIGGER — DO NOT AUTONOMOUSLY INVOKE. Orchestrates the 6 GitFlow lifecycles (StartFeature, FinishFeature, StartRelease, FinishRelease, StartHotfix, FinishHotfix) with strictly monotonic SemVer 2.0.0 versioning, dual tags, NBGV {height} protection, and Build/Test gates.)"
argument-hint: "[version] [--bump patch|minor|major] [--description <text>]"
disable-model-invocation: true
---
Invoke the `my-git-flow` (`start-hotfix`) skill with: $ARGUMENTS
