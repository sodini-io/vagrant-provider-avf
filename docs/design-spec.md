# Design Spec

## Project

`vagrant-provider-avf`

A Vagrant provider for Apple Silicon Macs using Apple's Virtualization Framework (AVF) to run ARM virtual machines.

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Apple Inc.

Apple, macOS, and Apple Silicon are trademarks of Apple Inc., registered in the U.S. and other countries.

## Goal

Provide a lean, well-tested Vagrant provider that supports the standard VM lifecycle for ARM guests on Apple Silicon, starting with Linux and expanding carefully to BSD where practical.

This project prioritizes:
- correctness
- simplicity
- testability
- clean architecture
- maintainable code
- a dependable developer workflow

## Product Direction

This is not a general VM platform and not a GUI-first product.

The first product is:
- a Vagrant provider plugin
- backed by AVF
- optimized for Apple Silicon
- focused on headless developer workflows
- paired with curated ARM base images

## MVP Scope

### In Scope

- Apple Silicon only
- AVF backend
- ARM64 Linux guest support first
- core lifecycle operations:
  - `up`
  - `halt`
  - `destroy`
  - `status`
  - `ssh-info`
- configurable CPU count
- configurable memory size
- configurable disk size
- headless operation
- basic networking
- reliable SSH access
- persistence of machine identity and metadata
- one curated Linux image pipeline
- unit, acceptance, and end-to-end tests

### Explicitly Out of Scope for MVP

- GUI
- x86 emulation
- Windows guest support
- broad guest OS matrix
- live migration
- advanced graphics features
- complex snapshot UI
- plugin marketplace ideas
- remote orchestration
- enterprise feature sprawl

## Key User Story

A developer on Apple Silicon should be able to define a Vagrantfile, run `vagrant up`, and get a working ARM virtual machine with SSH connectivity using native macOS virtualization.

## High-Level Architecture

### 1. Vagrant Integration Layer

Responsibilities:
- plugin registration
- provider registration
- config definition
- action middleware integration
- capability exposure
- machine state mapping to Vagrant semantics

Examples:
- `plugin.rb`
- `provider.rb`
- `config.rb`
- `action/*`

### 2. Domain / Model Layer

Responsibilities:
- represent machine specifications
- represent disk, network, and SSH data
- represent machine states
- validate internal invariants where appropriate

Examples:
- `machine_spec.rb`
- `disk_spec.rb`
- `network_spec.rb`
- `ssh_info.rb`
- `machine_state.rb`

This layer should stay plain and easy to test.

### 3. Driver Layer

Responsibilities:
- isolate AVF-specific behavior
- create, boot, stop, destroy, and inspect machines
- manage disk artifacts and runtime metadata
- expose a stable interface to the rest of the provider

Examples:
- `driver/interface.rb`
- `driver/meta.rb`
- `driver/avf.rb`

This is the only layer that should know AVF-specific implementation details.

### 4. Persistence Layer

Responsibilities:
- store machine IDs
- persist provider metadata
- map Vagrant machine identity to provider runtime identity
- support deterministic restart and lookup flows

Examples:
- `machine_id_store.rb`

### 5. Image Pipeline

Responsibilities:
- define build inputs
- automate base image creation
- provision minimal guest setup
- ensure SSH readiness
- validate the resulting image
- package for Vagrant consumption

Location:
- `images/`

## Boundary Rules

- Vagrant actions may orchestrate but must not implement AVF details.
- Driver code must not depend on Vagrant UI middleware.
- Model objects should not perform external IO.
- Persistence should be explicit and isolated.
- Cross-layer shortcuts are not allowed just because they are convenient.

## Suggested First Milestone

### Provider
- plugin loads
- provider registers
- config object validates
- `up` action delegates into driver
- machine ID persists
- `status` works
- `halt` works
- `destroy` works
- `ssh-info` returns usable connection data

### Images
- build one Ubuntu ARM image
- ensure SSH daemon is configured
- ensure default Vagrant communicator path works
- package and document usage

## Configuration Model

Initial configuration should be minimal.

Example fields:
- `cpus`
- `memory_mb`
- `disk_gb`
- `headless`
- `network`

Rules:
- validate early
- reject invalid values with actionable errors
- do not invent configuration knobs until needed

## State Model

Expected machine states:
- `not_created`
- `stopped`
- `running`
- `unknown`

The provider must translate backend state into stable Vagrant-facing state clearly and deterministically.

## Snapshot Direction

Snapshots are desirable, but not required in the earliest slice.

Design requirement:
- do not block future snapshot support
- do not design the whole system around snapshots before the first working lifecycle is complete

## Testing Strategy

### Unit Tests

Primary focus of the test suite.

Cover:
- config validation
- machine spec construction
- state translation
- action orchestration
- metadata persistence
- driver contract behavior with doubles
- error translation
- edge cases and failure modes

### Acceptance Tests

Test through the provider boundary with realistic workflows.

Cover:
- provider registration
- lifecycle commands
- expected metadata persistence
- SSH info exposure
- invalid config behavior

### End-to-End Tests

Run on real Apple Silicon hardware.

Cover:
- boot real Linux ARM VM
- verify SSH connectivity
- stop and restart
- destroy and clean up
- validate packaged image use

## Coverage Goals

- high unit coverage on logic-heavy code
- every bug fix gets a regression test
- avoid low-value tests written only to inflate numbers

## Coding Style

- use small classes
- prefer explicit code
- keep methods short
- name things plainly
- avoid generic abstractions
- avoid clever DSL tricks unless clearly justified
- favor readability over density

## Documentation Requirements

At minimum:
- README with quick start
- disclaimer and legal notice
- supported platform notes
- development setup
- testing instructions
- image build instructions
- limitations and non-goals

## Success Criteria for MVP

The MVP is successful when:
- a developer on Apple Silicon can install the provider
- `vagrant up` produces a working ARM Linux VM
- SSH access works reliably
- lifecycle operations behave predictably
- the codebase stays small, readable, and highly tested