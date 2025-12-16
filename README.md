# OCPA Specifications

:warning: This repo is under finalization. It may lack information.

[![OCPA: v1](https://img.shields.io/badge/OCPA-v1-blue.svg)](./VERSION)

The Opinionated Containerized Project Architecture (OCPA) is a pragmatic repository specification designed from years of experience with containerized apps.

Made to provide it to your favorite AI software (for bootstraping or refactoring), it provides a standardized way of developing & deploying, allowing seamless onboarding and integration with CI/CD tools (e.g., auto-pulls). Use this README as a statement of intent.

## Using OCPA? Show it!

If your project follows the OCPA specifications, add this badge to your README to let others know:

```markdown
[![OCPA: v1](https://img.shields.io/badge/OCPA-v1-blue.svg)](https://github.com/flavienbwk/ocpa-specs)
```

[![OCPA: v1](https://img.shields.io/badge/OCPA-v1-blue.svg)](https://github.com/flavienbwk/ocpa-specs)

This helps spread the word and builds a community of standardized, well-structured containerized projects.

## Required

- Make ;
- Docker.

## Architecture overview

```txt
.
├── .github/workflows
│   ├── build-push.yml      // Checks dev/prod build and pushes images to desired registry with appropriate tags depending on branch
│   ├── deploy.yml          // Deploys the Helm chart (K8s) of your app
│   └── linters.yml         // Include your project linters (envvars checks, secrets checks, markdownlint...)
├── service_1 (e.g, api)
│   ├── Dockerfile          // includes "dev" and "prod" targets
│   └── src
├── [...]                   // other services (e.g., app)
├── docs                    // For markdown resources
├── k8s                     // Helm template with production-ready configuration tailored for variables substitution
│   ├── Chart.yml
│   ├── templates
│   ├── values.example.yaml
├── scripts
│   ├── auto-pull.sh        // Must be called by a CRON job to auto-pull and redeploy the project on release branch push
│   ├── deploy-helm.sh      // Script that handles all the additional logics for Helm deployment (used by deploy.yml and make commands)
│   └── validate-envs.sh    // Used in CI to check for missing, inconsistent or invalid env variables
├── .env.example            // Your single source of truth for env variables
├── compose.prod.yml        // all-in-one production-ready (and secured) stack - can be tested locally
├── compose.yml             // all-in-one dev-ready hot-reload-enabled stack
├── Makefile                // Standardize commands to start dev or prod software, or deploy the project 
├── README.md               // Documentation entrypoint
└── VERSION                 // Current software version, can be suffixed by -alpha or -beta
```

## Git workflow

OCPA v1 is well-suited to be used along with the [_Flexible Git Workflow_](https://book-devops.berwick.fr/eng/index.html#flexible-flow-a-balanced-git-workflow).

Basically, the main branch is `main`, each developer creates and merge 1 feature branch per issue and deployment gets triggered by a pull request to the `release` branch:

![Flexible git workflow schematic by Flavien BERWICK](https://book-devops.berwick.fr/eng/images/flexible_flow_git.jpg)

## Rules

- **OCPA-R1**: All versions must be fixed: mandatory lock files or hard-coded (whether for code packages or CI references). Also use specific versions instead of `latest` tags. ;
- **OCPA-R2**: A single markdown file must be at root of directory: `README.md`. Others must be placed in the `docs/` directory ;
- **OCPA-R3**: Makefile commands must at least include `dev`, `dev-[build,up,restart,down]` with aliases `[build,up,restart,down]`, `prod`, `prod-[build,up,restart,down]`, `helm-[deploy,uninstall]`, and `downa` to remove orphan containers (without removing volumes) ;
- **OCPA-R4**: Use [Flexible Flow](https://book-devops.berwick.fr/eng/index.html#flexible-flow-a-balanced-git-workflow) as git workflow ;
- **OCPA-R5**: All pull requests must be prefixed by the issue number (e.g., `#38: Solving SEO problem`): this helps keeping track of the context for the commit ;
- **OCPA-R6**: Every commit message should be prefixed by issue number (e.g., `#38: Added better meta description`): this helps keeping track of the context for the commit ;
- **OCPA-R7**: Repo must be configured to squash a pull request commits on a feature branch merge to `main`;
- **OCPA-R8**: Repo must be configured to forbid force-push on `main` and `release` branches ;
- **OCPA-R9**: Repo must be configured to forbid force-merge on any branch, pipelines must succeed. If they are too slow, work on quickening them up! ;
- **OCPA-R10**: each service in compose file must declare logging limits, to avoid filling storage indefinitely with time ;

    ```bash
    myapp:
        logging:
            options:
                max-size: "1m"
    ```

- **OCPA-R11**: no trailing space nor inline comment in env variables, to avoid inconsistent processing of envs trailing spaces and comments among software ;

    Example of wrong declaration:

    ```env
    POSTGRES_PASSWORD=mysuperpassword  # Postgres password
    ```

    Example of good declaration:

    ```env
    # Postgres password
    POSTGRES_PASSWORD=mysuperpassword
    ```

- **OCPA-R12**: Don't define a compose network for your resources unless filling a specific purpose: it is often useless as compose already creates a network by default for your deployment ;

    Avoid this:

    ```yml
    networks:
        myservicesnetwork:
            driver: bridge
    ```

- **OCPA-R13**: set healthchecks for each service: it lets orchestrators automatically detect and replace unhealthy containers, ensuring service availability ;
- **OCPA-R14**: set `restart: always|unless-stopped` property so your services restart after computer's reset. Prefer using `unless-stopped` by default or `always` if your service is critical (e.g., reverse proxy, monitoring agent) ;
- **OCPA-R15**: don't set `container_name`s until specifically required for your use case: docker already establishes a DNS record from service names inside the compose deployment ;
- **OCPA-R16**: set `platform` property for each service for project's cross-platform compatibility (e.g., `platform: linux/amd64` for Apple Silicon) ;
- **OCPA-R17**: any port open in each service must be listed in the `exposed` property but internal services that should not be exposed must not use the `ports` property (e.g, databases, redis...) ;
- **OCPA-R19**: services that must be exposed (using the `ports` property) must use an environment variable to flexibly adapt different environments (dev, staging, prod) ;
- **OCPA-R20**: any environment variable used inside a service must be listed in the `environments` property (respectively a configmap or similar for its Kubernetes configuration): this makes sure each environment variable is defined intentionnally and introducing a new one is noticed ;
- **OCPA-R21**: any secret or global variable in each service must be using environment variables (e.g., Python's `os.getenv()`, PHP's `getenv('DB_HOST')`...). They shall not have default values so software crashes if not intentionally set (cf. OPCA-R20) ;

### Auto-Pull (CRON)

For automated deployments, set up a CRON job:

```bash
# Add to crontab
*/5 * * * * /path/to/project/scripts/auto-pull.sh >> /path/to/project/scripts/auto-pull.log 2>&1
```
