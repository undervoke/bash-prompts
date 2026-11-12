# bash-prompts

A lightweight Bash prompts library. The initial capability is a grouped,
dependency-aware checkbox selector: the user checks items in labeled groups
while required dependencies auto-check and stay locked with their reasons
until no longer needed.

Status: planned and in progress. There is no stable API, release, or
verified platform support yet; do not depend on an interface described here
until it ships.

## Roadmap

- [ ] Extract the generic selector from the current consumer implementations
      into a standalone, namespaced Bash source file.
- [ ] Define the small caller API: caller-supplied item labels, group labels,
      and dependency edges as input; direct/auto selection state and lock
      reasons as the result contract.
- [ ] Keep groups caller-defined; the library must not encode any consumer's
      group policy.
- [ ] Carry over transitive dependency closure, lock reasons, grouped
      scrolling display, confirmation-before-execution semantics, and
      terminal setup/restore.
- [ ] Preserve Bash 3.2 compatibility and rely only on Bash plus system
      terminal utilities, so rendering the selector needs no extra language
      runtime.
- [ ] Integrate into consumers by pinned vendoring: each consumer ships a
      version-pinned copy with MIT license and exact upstream provenance, so
      an ordinary clone runs without fetching a UI dependency.
- [ ] Verify on exercised environments only; do not advertise unverified
      platform support.
- [ ] Add usage documentation and MIT license packaging with the release.

## Runtime goal

Bash with system terminal utilities, and nothing else, is enough to display
the selector. Consumers include a pinned copy of the library source, so a
normal cloned checkout works without network downloads or extra runtimes.
