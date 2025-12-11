# OCPA Specifications

[![OCPA: v1](https://img.shields.io/badge/OCPA-v1-blue.svg)](./VERSION)

The Opinionated Containerized Project Architecture (OCPA) is a pragmatic repository specification designed from years of experience with containerized apps.

Made to provide it to your favorite AI software (for bootstraping or refactoring), it provides a standardized way of developing & deploying, allowing seamless onboarding and integration with CI/CD tools (e.g., auto-pulls).

## Required

- Make ;
- Docker.

## Architecture

```txt
.
├── service 1 (e.g, api)
│   ├── Dockerfile
│   ├── prod.Dockerfile
│   └── src
├── [...]                   // other services (e.g., app)
├── docs
├── k8s
├── compose.prod.yml
├── compose.yml
├── Makefile
├── README.md
├── LICENSE.md
└── VERSION
```
