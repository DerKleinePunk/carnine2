# Contributing to Carnine

We love your input! We want to make contributing to Carnine as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. Ensure the test suite passes.
4. Make sure your code lints.
5. Issue that pull request!

## Continuous Integration

Every push and pull request runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
on GitHub-hosted runners. You can run the same checks locally before pushing:

```bash
cd src/backend  && cargo fmt --check && cargo clippy --all-targets && cargo test
cd src/frontend && flutter analyze && flutter test
```

The workflow additionally builds the backend in release mode on a native arm64
runner, which is the architecture the Raspberry Pi target runs.

Two things deliberately stay out of CI: the Debos image build, which needs
privileged podman and KVM, and everything that needs real hardware - the
display panel, the audio sink and USB media. Those are verified on the test Pi.

## Pull Request Process

1. Update the README.md with details of changes to the interface, if applicable.
2. Increase version numbers in any examples files and the README.md to the new version that this Pull Request would represent.
3. Ensure all tests pass and the code builds successfully.
4. Your PR will be reviewed by maintainers and merged once approved.

## Reporting Bugs

Please use GitHub Issues to report bugs. When filing a bug report, include:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Suggesting Enhancements

Use GitHub Discussions or Issues to suggest enhancements. Include:

- Use case description
- Suggested solution
- Alternative solutions you've considered

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Questions?

Contact us at software@carnine.de

Thank you for contributing to Carnine!
