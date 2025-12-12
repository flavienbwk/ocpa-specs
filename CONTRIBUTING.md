# Contributing to OCPA Specifications

Thank you for your interest in contributing to the Opinionated Containerized Project Architecture (OCPA) specifications!

## Getting Started

### Prerequisites

- Make ;
- Docker ;
- Git.

### Setting Up Your Environment

1. Fork the repository
2. Clone your fork:

   ```bash
   git clone https://github.com/<your-username>/ocpa-specs.git
   cd ocpa-specs
   ```

3. Add the upstream remote:

   ```bash
   git remote add upstream https://github.com/<original-owner>/ocpa-specs.git
   ```

## Git Workflow

This project follows the [Flexible Git Workflow](https://book-devops.berwick.fr/eng/index.html#flexible-flow-a-balanced-git-workflow).

### Branches

- `main` - The main development branch
- `release` - Production deployment branch
- Feature branches - Created from `main` for each issue

### Creating a Feature Branch

1. Ensure your local `main` is up to date:

   ```bash
   git checkout main
   git pull upstream main
   ```

2. Create a new branch for your feature/fix:

   ```bash
   git checkout -b feature/<issue-number>-<short-description>
   ```

## Commit Guidelines

All commit messages **must** be prefixed with the issue number (OCPA-R6):

```bash
#<issue-number>: <description>
```

**Examples:**

- `#42: Added new rule for environment validation`
- `#15: Fixed typo in architecture overview`

Keep commits atomic and focused on a single change.

## Pull Request Guidelines

### Before Submitting

1. Ensure your changes follow the OCPA rules
2. Update documentation if necessary
3. Test your changes locally

### Submitting a Pull Request

1. Push your branch to your fork:

   ```bash
   git push origin feature/<issue-number>-<short-description>
   ```

2. Open a pull request against the `main` branch
3. Title your PR with the issue number prefix (OCPA-R5):

   ```bash
   #<issue-number>: <description>
   ```

**Examples:**

- `#38: Solving SEO problem`
- `#12: Adding Kubernetes deployment guide`

### Review Process

- All PRs require review before merging
- Pipelines must pass before merging (OCPA-R9)
- PRs are squash-merged to keep history clean (OCPA-R7)

## OCPA Rules Reference

When contributing, ensure your changes comply with [OCPA rules](./README.md#rules)

## Types of Contributions

### Reporting Issues

- Use GitHub Issues to report bugs or suggest enhancements
- Provide clear descriptions and reproduction steps
- Tag issues appropriately

### Documentation

- Improvements to existing documentation
- Adding examples and use cases
- Fixing typos or clarifying language

### Specification Changes

- Proposing new rules or modifications to existing ones
- Adding new architecture patterns
- Improving CI/CD workflow templates

## Questions?

If you have questions about contributing, feel free to open an issue for discussion.
