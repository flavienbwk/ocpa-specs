# ODPA Specifications

[![ODPA: v1](https://img.shields.io/badge/ODPA-v1-blue.svg)](./VERSION)

The Opinionated Docker Project Architecture (ODPA) is a recommended repo architecture.

It provides a standardized way of developing & deploying, allowing seamless onboarding and integration with CI/CD tools (e.g., auto-pulls).

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
├── prod.docker-compose.yml
├── docker-compose.yml
├── Makefile
├── README.md
├── LICENSE.md
└── VERSION
```
