# Testing Principles (Universal)

## Philosophy

- **Test behavior, not implementation.** Good tests survive refactoring; they assert outcomes,
  not internal calls.
- **Arrange / Act / Assert** structure in every test.
- **One assertion concept per test.** Multiple `expect`s are fine if they verify one behavior.

## The FIRST properties

Tests must be **Fast, Isolated, Repeatable, Self-validating, Timely** (written with the code,
not bolted on later).

## Test pyramid

Many **unit** tests, fewer **integration** tests, few **e2e** tests. Push logic down to the
level where it's cheapest to test thoroughly.

## Mocking

- Mock **external** services (network, third-party APIs, clock/randomness when needed).
- **Don't mock your own code** you could exercise directly — prefer real collaborators or
  lightweight in-memory fakes (e.g. fake repositories) over heavy mocks.

## Naming

`"it should <expected behavior> when <condition>"`. The name describes the guarantee, not the
mechanics.

## Hygiene

- **Never skip flaky tests** — fix the flake or delete the test. A skipped test is a lie about
  coverage.
- No conditional logic or randomness that makes failures non-reproducible.
- Keep fixtures small and intention-revealing.
