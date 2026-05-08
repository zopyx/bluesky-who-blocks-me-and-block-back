# Milestone Plan: Four-Star App Quality

## Goal
Raise the app from a capable internal tool to a polished, dependable product that feels trustworthy, efficient, and clear enough to earn roughly a 4 out of 5 star user impression.

## Quality Bar
For this milestone, “4 out of 5 stars” means:
- Core workflows feel stable and predictable
- Users understand what the app does without external explanation
- Large or repetitive moderation tasks feel manageable
- Errors are understandable and recoverable
- The interface feels intentional, not merely functional
- Accessibility and performance are good enough that they are not common complaints

## Scope
In scope for this milestone:
- Workflow simplification and UX polish
- Reliability hardening and regression prevention
- Better performance for large lists and long sessions
- Accessibility improvements
- Stronger information architecture and visual refinement
- Better user guidance, onboarding, and recovery states
- Practical settings and trust-building details

Out of scope for this milestone:
- Full cloud sync
- Team collaboration / multi-user moderation
- Advanced analytics or ML-based moderation intelligence
- A full social client experience beyond moderation needs

## Phases

### Phase 1: Core Workflow Audit and Simplification
Goal: reduce friction in the highest-value paths so users can complete tasks with less confusion and fewer taps.

Deliverables:
- Audit the top workflows: account setup, list loading, search, import, compare, profile moderation
- Remove confusing or redundant controls
- Reorder major sections based on frequency and importance
- Tighten wording for buttons, alerts, and state messages
- Ensure destructive actions are clearly separated from exploratory tools

Verification:
- A new user can add an account and reach list moderation without explanation
- A returning user can find import, compare, and profile tools in under 10 seconds
- No alert or action label feels ambiguous in common flows

### Phase 2: Visual and Interaction Polish
Goal: make the app feel intentional, calm, and production-grade rather than like a stacked set of forms.

Deliverables:
- Refine spacing, hierarchy, and section grouping across main screens
- Improve dashboard layout and signal priority
- Add consistent empty, loading, and partial-result states
- Improve affordances for selection, bulk actions, and long-running operations
- Standardize iconography, emphasis color use, and status chips

Verification:
- The moderation dashboard clearly highlights what matters first
- List detail no longer feels overcrowded even with all tools enabled
- Selection and bulk-action states are visually obvious without reading fine print

### Phase 3: Reliability and Error Recovery
Goal: make the app resilient enough that ordinary network or data issues do not feel like breakage.

Deliverables:
- Normalize networking and decoding error handling
- Add retry and recovery patterns for the most common failure paths
- Prevent stale async state from overriding current user intent
- Improve state restoration after account switching or app relaunch
- Add defensive guards around repeated taps and overlapping tasks

Verification:
- Temporary network failures surface clear recovery options
- Repeated searches, refreshes, and bulk actions do not corrupt visible state
- Account switching reliably updates all relevant screens

### Phase 4: Performance and Scale
Goal: keep the app responsive during larger list sessions and heavier moderation activity.

Deliverables:
- Profile and optimize list rendering and diff-heavy screens
- Reduce unnecessary reloads and repeated API fetches
- Improve batch operation efficiency where safe
- Optimize snapshot/history handling for repeated use
- Add instrumentation or lightweight metrics for key operations

Verification:
- Large lists remain responsive while filtering, selecting, and paginating
- Refreshing and revisiting screens does not cause obvious redundant work
- Batch operations provide progress without making the UI feel stuck

### Phase 5: Accessibility and Inclusive Usability
Goal: ensure the app is broadly usable and does not fail basic iOS accessibility expectations.

Deliverables:
- Audit VoiceOver labels and control descriptions
- Improve Dynamic Type behavior and truncation handling
- Review contrast and emphasis color choices
- Ensure tap targets are comfortable and destructive actions are clearly announced
- Improve keyboard and switch-control friendliness where relevant

Verification:
- Core flows are usable with VoiceOver enabled
- Large Dynamic Type does not break primary list and profile screens
- Important actions remain discoverable without relying on color alone

### Phase 6: Guidance, Trust, and Product Clarity
Goal: help users understand the app’s value, limits, and safety characteristics.

Deliverables:
- Add lightweight onboarding or first-run guidance
- Improve the Info and Settings surfaces with clearer capability and privacy explanations
- Clarify what data stays local versus what is sent to Bluesky
- Add help text for imports, diff workflows, and audit history
- Improve status messaging around authentication and moderation side effects

Verification:
- A first-time user understands the app’s purpose and boundaries from inside the app
- Users can tell which features are local-only and which mutate live Bluesky data
- Support-style questions about “what does this do?” drop substantially

### Phase 7: Architecture Hardening and Maintainability
Goal: reduce code fragility so the app can keep improving without a quality cliff.

Deliverables:
- Break up oversized view models and views, especially list detail
- Split `LiveBlueskyClient` into smaller endpoint or domain-focused components
- Extract reusable batch-operation and snapshot/history logic
- Add focused unit tests for critical state transitions and failure paths
- Add a small regression checklist for manual release validation

Verification:
- The largest feature files are materially smaller and easier to reason about
- Critical moderation paths have direct automated test coverage
- Future changes no longer require touching one giant file for unrelated behavior

### Phase 8: Release Candidate and User-Perception Pass
Goal: polish the app as a coherent product, not just a set of completed tickets.

Deliverables:
- Full simulator pass across all primary flows
- Bug bash and cleanup of rough copy, layout issues, and edge-case alerts
- Final dashboard tuning and settings/info review
- App icon / launch / branding sanity check if needed
- Release notes and a concise known-limitations list

Verification:
- End-to-end manual pass completes without major confusion or blocking defects
- No obviously “unfinished” copy or dead-end flows remain
- The app feels cohesive from launch to advanced moderation workflows

## Success Criteria
This milestone is done when:
- The app feels stable in repeated day-to-day moderation use
- The main workflows are understandable without handholding
- Large-list and bulk-action experiences feel reliable and responsive
- Visual polish and information hierarchy feel deliberate
- Accessibility and recovery states meet a solid baseline
- The codebase is in better shape to support future product work

## Execution Order
1. Core workflow audit and simplification
2. Visual and interaction polish
3. Reliability and error recovery
4. Performance and scale
5. Accessibility and inclusive usability
6. Guidance, trust, and product clarity
7. Architecture hardening and maintainability
8. Release candidate and user-perception pass

## Risks
- Quality work can sprawl unless each phase stays tied to concrete user complaints or observable friction.
- Visual polish without structural simplification can create a prettier but still confusing app.
- Reliability improvements may surface architectural debt that slows feature-level progress.
- Accessibility retrofits can expose layout assumptions that require broader UI refactors.
- “Feels like 4 stars” is subjective, so each phase needs testable acceptance checks.

## Recommended Principle
Prioritize user trust over feature count.
If a choice exists between one more capability and making an existing capability clearer, safer, or more reliable, choose the latter for this milestone.
