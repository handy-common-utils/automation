# automation

Reusable GitHub Actions supporting build, test, and deployment automation for CI/CD pipelines in Node.js / TypeScript projects.

## GitHub Actions

- [`prepare-node`](#prepare-node): Check out repository code, resolve and set up Node.js (with `.nvmrc` auto-detection and dependency caching), and install dependencies via `npm ci`.
- [`ci-node`](#ci-node): End-to-end continuous integration — prepares environment, runs tests (`npm test` or custom test command), and uploads code coverage to Codecov.
- [`publish-npm`](#publish-npm): Automated package publishing to the NPM registry with authentication configuration, token support, and optional flags (such as `--provenance`).

---

### `prepare-node`

Prepares the Node.js development and CI environment.

#### Features
- Checks out code using `actions/checkout@v7`.
- Automatically detects Node.js version from `.nvmrc`, `.node-version`, or `package.json` (if `node-version` input is omitted), or accepts an explicit version spec (e.g. `20.x`, `22.x`, `24.x`).
- Configures npm dependency caching using `actions/setup-node@v7`.
- Installs dependencies using `npm ci` (customizable or skippable).

#### Inputs

| Input | Description | Required | Default |
|---|---|---|---|
| `node-version` | Version of Node.js (e.g. `"20.x"`, `"22.x"`), or version file name (`".nvmrc"`, `"package.json"`). If omitted, automatically detects `.nvmrc`, `.node-version`, or `package.json`. | No | `""` (auto-detect) |
| `fetch-depth` | Fetch depth for git history (`"0"` to fetch full history and tags). | No | `"1"` |
| `cache` | Package manager for dependency caching (`"npm"`, `"yarn"`, `"pnpm"`). Set to empty string `""` to disable. | No | `"npm"` |
| `cache-dependency-path` | Path to dependency lockfile(s) for cache key generation. | No | `package.json`<br>`package-lock.json` |
| `install-dependencies` | Whether to run dependency installation (`"true"` or `"false"`). | No | `"true"` |
| `install-command` | Command used to install dependencies. | No | `"npm ci"` |

#### Outputs

| Output | Description |
|---|---|
| `node-version` | The installed Node.js version. |
| `cache-hit` | Boolean indicating whether dependency cache was restored. |

#### Example Usage

```yaml
steps:
  - name: Prepare environment
    uses: handy-common-utils/automation/github/actions/prepare-node@main
```

Or specifying options explicitly:

```yaml
steps:
  - name: Prepare environment with full history
    uses: handy-common-utils/automation/github/actions/prepare-node@main
    with:
      node-version: .nvmrc
      fetch-depth: 0
```

---

### `ci-node`

Runs continuous integration tests and uploads coverage reports to Codecov.

#### Features
- Invokes `prepare-node` to check out code and prepare Node.js environment.
- Executes test command (`npm test` by default).
- Uploads coverage reports using `codecov/codecov-action@v7`.
- Supports Codecov authentication tokens (`codecov-token` or `CODECOV_TOKEN` environment variable).
- Configurable error tolerance (`fail-ci-if-error`) and flag tagging (`codecov-flags`).
- Can disable coverage upload via `upload-coverage: 'false'`.

#### Inputs

| Input | Description | Required | Default |
|---|---|---|---|
| `node-version` | Version of Node.js or version file name. Auto-detects if omitted. | No | `""` (auto-detect) |
| `fetch-depth` | Fetch depth for git history. | No | `"1"` |
| `cache` | Package manager for dependency caching (`"npm"`, `"yarn"`, `"pnpm"`). | No | `"npm"` |
| `cache-dependency-path` | Path to dependency lockfile(s) for caching. | No | `package.json`<br>`package-lock.json` |
| `install-command` | Command to install dependencies. | No | `"npm ci"` |
| `test-command` | Command to run test suite. | No | `"npm test"` |
| `upload-coverage` | Whether to upload test coverage to Codecov. | No | `"true"` |
| `codecov-token` | Token for Codecov upload (falls back to `CODECOV_TOKEN` env var). | No | `""` |
| `codecov-flags` | Flags for Codecov report. | No | `"unittests"` |
| `codecov-dir` | Directory containing coverage reports. | No | `"./coverage"` |
| `fail-ci-if-error` | Whether workflow fails if coverage upload fails. | No | `"false"` |

#### Example Usage

**Standard Matrix CI Workflow (`.github/workflows/ci.yml`):**

```yaml
name: CI

on:
  push:
    branches: [ '**' ]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [20.x, 22.x, 24.x]

    steps:
      - name: Run tests & upload coverage
        uses: handy-common-utils/automation/github/actions/ci-node@main
        with:
          node-version: ${{ matrix.node-version }}
          codecov-token: ${{ secrets.CODECOV_TOKEN }}
```

**Single-Version CI (Auto-Detecting `.nvmrc`):**

```yaml
name: CI

on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Run tests
        uses: handy-common-utils/automation/github/actions/ci-node@main
        with:
          codecov-token: ${{ secrets.CODECOV_TOKEN }}
```

---

### `publish-npm`

Publishes package to the NPM registry.

#### Features
- Prepares Node.js environment via `prepare-node`.
- Configures `.npmrc` authentication securely (creates or appends `_authToken` entry without overwriting existing settings).
- Sets `NODE_AUTH_TOKEN`, `NPM_PUBLISH_TOKEN`, and `NPM_TOKEN` environment variables for full compatibility with modern NPM tools and release scripts.
- Supports publishing flags (e.g. `--provenance`, `--access public`, `--tag`).

#### Inputs

| Input | Description | Required | Default |
|---|---|---|---|
| `npm-publish-token` | Token for publishing to the NPM registry. | **Yes** | — |
| `registry-url` | Target NPM registry URL (auto-detects `publishConfig.registry`, npm config, or defaults to `https://registry.npmjs.org/`). | No | `""` (auto-detect) |
| `node-version` | Version of Node.js or version file name. Auto-detects if omitted. | No | `""` (auto-detect) |
| `fetch-depth` | Fetch depth for git history. | No | `"1"` |
| `publish-command` | Command used to publish package. | No | `"npm publish"` |
| `publish-flags` | Extra flags passed to publish command (e.g. `--provenance`, `--access public`). | No | `""` |

#### Example Usage

**Publish on Version Tag Push (`.github/workflows/publish.yml`):**

```yaml
name: Publish

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+*'

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write # required if publishing with --provenance
    steps:
      - name: Publish to NPM registry
        uses: handy-common-utils/automation/github/actions/publish-npm@main
        with:
          npm-publish-token: ${{ secrets.NPM_PUBLISH_TOKEN }}
          publish-flags: '--provenance'
```
