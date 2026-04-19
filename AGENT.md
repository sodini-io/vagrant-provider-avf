# AGENT.md

## Purpose

This repository builds `vagrant-provider-avf`, a Vagrant provider for Apple Silicon Macs using Apple's Virtualization Framework (AVF).

This project exists to be:
- small
- readable
- dependable
- boring in the best possible way

The code should feel like it was written by careful engineers with strong taste and limited patience for nonsense.

## Non-Negotiables

- Prefer the simplest design that can work.
- Use test-driven development whenever practical.
- Maintain high unit test coverage.
- Every bug fix must include a regression test.
- Avoid speculative abstractions.
- Avoid framework-style indirection unless it clearly earns its keep.
- Keep files small and cohesive.
- Keep public APIs minimal.
- Do not optimize for cleverness.
- Do not add code “for later.”
- Do not leave dead code behind.
- Do not use comments to explain confusing code when the code can be made clear instead.

## Design Philosophy

This project follows a lean, Kent Beck style approach:

- make the change easy, then make the easy change
- prefer explicit code over magic
- let tests drive shape
- separate concerns with hard boundaries
- remove duplication, but do not abstract prematurely
- use plain objects and clear names
- design for maintainability, not for admiration

## Code Smell Rules

Avoid:
- giant classes
- service objects for everything
- generic helpers
- utility dumping grounds
- deep inheritance
- nested conditionals when guard clauses will do
- hidden state
- hidden side effects
- long methods
- comments that narrate obvious behavior
- broad rescue blocks without precise intent
- “manager,” “processor,” or “helper” classes unless narrowly justified

Prefer:
- value objects
- small action objects
- clear boundaries
- explicit orchestration
- dependency injection where it improves testability
- names that reveal intent

## File and Class Guidelines

- A file should have one clear reason to change.
- A class should be small enough to explain quickly.
- A method should usually fit on one screen without scrolling.
- If a class is hard to name, the design may be muddy.
- If a test is hard to write, the design may be wrong.

## Testing Standards

### Test Pyramid

The suite must be dominated by unit tests.

1. Unit tests
   - fastest
   - most numerous
   - test domain logic, configuration validation, state transitions, metadata parsing, and action orchestration

2. Acceptance tests
   - test realistic Vagrant workflows through the provider boundary
   - confirm plugin registration, lifecycle actions, and config behavior

3. End-to-end tests
   - run on real Apple Silicon hardware
   - boot a real guest
   - verify SSH connectivity and lifecycle behavior

### TDD Expectations

Use Red-Green-Refactor whenever practical:
1. write the failing test
2. implement the smallest change to pass
3. refactor with tests green

TDD is strongly preferred for:
- config validation
- state resolution
- action behavior
- storage behavior
- driver contracts
- error mapping
- metadata parsing

### Coverage Expectations

- Unit test coverage should be high.
- Coverage is a guardrail, not a vanity metric.
- Do not game coverage with meaningless tests.
- Focus on behavior, contracts, and failure modes.

### Regression Policy

Every bug fix must come with:
- a failing test first, where practical
- a focused regression test after the fix

## Architecture Rules

The project has these major layers:

1. Vagrant integration layer
2. domain/model layer
3. backend driver layer
4. persistence layer
5. image pipeline

Rules:
- The Vagrant layer must not directly implement AVF logic.
- The AVF driver must not know about Vagrant UI or action middleware.
- The model layer should stay plain and dependency-light.
- Storage must be explicit and testable.
- Platform-specific behavior must stay behind the driver boundary.

## Dependency Policy

Before adding a dependency, ask:
- Does the standard library already solve this?
- Does this make the code clearly simpler?
- Does this improve reliability or testability?
- Is the maintenance cost worth it?

Default answer: do not add it.

## Logging and Errors

- Error messages must be specific and actionable.
- Fail fast on invalid configuration.
- Do not swallow exceptions silently.
- Translate low-level errors into user-meaningful errors at the correct boundary.
- Log enough to diagnose behavior without producing noise soup.

## Naming Rules

Names must be:
- literal
- boring
- precise
- easy to grep

Avoid:
- clever metaphors in code
- vague names
- overloaded terminology

Good:
- `machine_id_store`
- `read_state`
- `network_spec`

Bad:
- `engine`
- `manager`
- `toolbox`
- `utils`

## Comments

Use comments sparingly.

Good reasons for comments:
- legal notices
- public usage notes
- non-obvious constraints
- why a workaround exists
- links to external behavior contracts

Bad reasons for comments:
- narrating obvious code
- apologizing for bad design
- explaining what a method name already says

## AI Use Policy

This repository must not read like generated code.

That means:
- no generic scaffolding noise
- no repetitive comment style
- no bloated abstraction
- no speculative interfaces
- no fake extensibility
- no excessive symmetry for its own sake

Any generated draft must be treated as a rough starting point and aggressively edited for:
- clarity
- simplicity
- correctness
- style consistency
- testability

## Pull Request Expectations

A change is not done until:
- tests pass
- new behavior is covered
- docs are updated if behavior changed
- no dead code remains
- naming is clear
- the change feels smaller after refactoring than before

## Definition of Done

A change is done when:
- it solves the actual problem
- it is covered by tests at the right level
- it fits the existing architecture
- it does not introduce speculative design
- another engineer can read it without needing a tour guide
