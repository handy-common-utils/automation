# automation

Tools supporting build/test/deployment automation which is the core of CI/CD pipelines

## GitHub actions

- `prepare-node`
  1. checkout code
  2. `npm ci`
- `ci-node`
  1. `prepare-node`
  2. `npm test`
  3. upload test coverage report to `codecov`
- `publish-npm`
  1. `prepare-node`
  2. `npm publish`

