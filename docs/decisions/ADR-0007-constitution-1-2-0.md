# ADR-0007 — Constitution 1.2.0: VisualCore reuse, push cadence, A01 app rules

**Date:** 2026-11-10 · **Status:** accepted (owner instructions 2026-11-10; `/speckit-constitution` for A01)

## Context

Three changes needed recording in the suite constitution:

- Gate A01-P00 runs Generative Art Studio's manual constitution prompt.
- The owner ruled that most app logic belongs in reusable VisualCore modules.
- The owner authorized committing and pushing after every task. The constitution still said "no push without
  authorization".

## Decision

Version 1.1.0 becomes 1.2.0 (MINOR: a section was added and guidance materially expanded):

1. Principle II gains **Maximize reuse**. App-reusable logic goes into VisualCore with tests, docs, an API baseline
   update and the reference regression; the owner's instruction is the approval.
2. The Development Workflow states the authorized commit-and-push cadence to `origin` `main`, with no force-push.
3. A new **App-Scoped Rules** section holds A01 Generative Art Studio's rules, taken from its manual prompt.

The manual's separate-repository advice is replaced by the monorepo layout (CLAUDE.md §4).

## Consequences

Later apps append their own subsection when their P00 constitution prompt runs. App plans name the
owning VisualCore module for each component.
