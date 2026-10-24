# setup-bcdock

Install the [bcdock CLI](https://github.com/bcdock/cli) in a GitHub Actions job, authenticate it, and optionally create a Business Central environment for the job to test against.

Runs on Linux, macOS and Windows runners (x86_64; arm64 on Linux and macOS).

## Install and authenticate

```yaml
- uses: bcdock/setup-bcdock@v1
  with:
    token: ${{ secrets.BCDOCK_TOKEN }}

- run: bcdock env list
```

The action checks the token with `bcdock auth whoami` and fails the step if it is not accepted. Later steps in the same job are authenticated: you do not pass the token again.

Mint the token at [app.bcdock.io/profile/api-keys](https://app.bcdock.io/profile/api-keys) with the `env:read` and `env:write` scopes, and store it as a repository secret.

## Create an environment

```yaml
- uses: bcdock/setup-bcdock@v1
  id: bcdock
  with:
    token: ${{ secrets.BCDOCK_TOKEN }}
    create: true
    name: pr-${{ github.event.pull_request.number }}
    bc-version: "28.5"  # the newest ready build of BC 28.5
    country: au

- run: echo "BC is at ${{ steps.bcdock.outputs.env-url }}"

# ... publish your extension, run your tests ...

- name: Delete environment
  if: always()
  run: bcdock env delete "pr-${{ github.event.pull_request.number }}" --force --wait
```

The step waits until the environment is running: a few minutes when a pool is ready, about 15 when one has to start. If the create fails, the step fails with the CLI's exit code; see [exit codes](https://docs.bcdock.io/cli/exit-codes/).

**The action never deletes what it creates.** Add the delete step yourself, with `if: always()`, and delete by the name you chose so it also cleans up after a failed create. To keep an environment between pushes, hibernate it instead: `bcdock env hibernate <name> --wait`.

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `token` | yes | | BCDock API token. Pass it from a secret. |
| `version` | no | `latest` | CLI version to install, e.g. `0.5.10`. A `bc-version` like `28.5` needs 0.5.10 or later. |
| `create` | no | `false` | Create an environment and wait until it is running. |
| `name` | no | generated | Environment name. |
| `bc-version` | with `create` | | BC version: `28.5` takes the newest ready build of 28.5, and `28` the newest ready minor of 28. Prefer these. A full version (e.g. `28.5.54151.56140`) pins one exact build, but when a newer build of the same release is ready, older builds are retired, so a pin can stop working. List what is ready: `bcdock artifacts list --region <region> --fast-only`. |
| `country` | with `create` | | Country localisation, e.g. `au`, `us`, `gb`. |
| `region` | no | | Azure region, e.g. `australiaeast`. |
| `wait-timeout` | no | `30m` | How long to wait for the environment to be running. |

## Outputs

| Output | Description |
|---|---|
| `version` | The CLI version installed. |
| `env-id` | Id of the created environment. |
| `env-name` | Name of the created environment. |
| `env-url` | Web client URL of the created environment. |

## Security

The token is masked in logs and is passed to the CLI only through the environment, never on a command line. The download is checked against the release's published SHA-256 checksums before it runs.

## Privacy

The action sends data to one place, the BCDock API: your token, and with `create`, the environment's name, BC version, country and region. The API also sees the IP address of the runner. Nothing from GitHub is sent: no repository content, no workflow details, and no GitHub token.

To install the CLI, the action downloads the release and its checksums from GitHub. Nothing is uploaded in that step.

BCDock's [privacy policy](https://bcdock.io/legal/privacy-policy) covers what the API does with this data.

## Terms

Using the action means using BCDock, which is covered by the [BCDock Terms of Service](https://bcdock.io/legal/terms-of-service). The action's own code is MIT licensed (see License below).

## Support

Email [support@bcdock.io](mailto:support@bcdock.io), or [open an issue](https://github.com/bcdock/setup-bcdock/issues) on this repository.

## More

- [GitHub Actions guide](https://docs.bcdock.io/guides/github-actions/): a complete per-pull-request workflow.
- [CLI reference](https://docs.bcdock.io/cli/reference/bcdock/)

## License

MIT
