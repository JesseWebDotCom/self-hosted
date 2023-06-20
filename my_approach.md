A large environment leads to large compose and environment files which leads to all sorts of problems in terms of complexity, maintainability, readability, performance, scalability, security, privacy, and dependency management. My approach modularizes each environment, stack, and container into smaller chunks and manage them through a single, easy to use tool.

## Key Features

- **Modularized** - Containers (and their files) are grouped into "environments" & "stacks"
- **Organized** - Stacks display and are controllable in Docker Desktop, Portainer, and other docker GUI management tools
- **Easy to configure** - When composing an environment, simply add/remove your "stack" name from stacks.txt to include/exclude a stack from being managed
- **Easy to manage** - Simply call a single script to build, teardown, start, stop, pause, etc individual or all environments and or stacks
- **Security** - Separates secrets from compose and environment files
- **Privacy** - Only allow git to see files you specify (useful only if you git push to a repo)
- **Documented** - Automatically documented - check out the [documentation site](https://jessewebdotcom.github.io/self-hosted/)

## How To Use

Use `/tools/compose.sh` to perform any docker compose action (ex. up, down, start, restart, etc) on an environment, its stacks, and or its stack items

Some example commands

| Purpose                                                            | Example Command                     |
| ------------------------------------------------------------------ | ----------------------------------- |
| compose `up` all stacks in `production` environment                      | `compose.sh production up`                |
| compose `up` the `writing` stack in `production` environment            | `compose.sh production.writing up`       |
| compose `up` `ghost` in the `writing` stack in `production` environment | `compose.sh production.writing.ghost up` |

The examples above used the action `up` but you can use any docker compose action (ex. up, down, start, restart, etc).

For example, to `restart` all containers in the `production` environment `writing` stack:

```bash
/tools/compose.sh production.writing restart
```

You can also use the custom action `rebuild` to compose `down` and `up`.
For example, to compose `down` and `up` all containers in the `production` environment `writing` stack:

```bash
/tools/compose.sh production.writing rebuild
```

## Prerequisites

- docker
- docker compose
- make `.sh` files in `/tools` executable
   - ex. `chmod +x tools/*.sh`

## Configuration

1. create your desired environment and optional environment .env

   ex.
   `/environments/production`
   `/environments/production/.env`

2. create any stacks and optional stack .env

   ex.
   `/environments/production/writing`
   `/environments/production/writing/.env`

3. optionally create and fill a stacks.txt (with ordered stack names, only used by `tools/compose.sh` when composing an entire environment)

   ex.
   `/environments/production/stacks.txt`

4. create a compose file, optional environment file, and optional secrets file per container

   ex.
   `/environments/production/writing/ghost.yml`
   `/environments/production/writing/ghost.env`
   `/environments/production/writing/ghost.secrets`

5. optionally, include any files you want git to see in `/.gitignore`

### compose files

To make my compose files more readable (and smaller in size / line count), I place commonly repeated lines in `/environments/common-services.yml` and reference with an [`extends`](https://docs.docker.com/compose/extends/) keyword.

### .env and .secrets

`.env` and `.secrets` are both environment files where `.env`stores non-sensitive data (ex. timezone) and `.secrets` stores sensitive data (ex. password).

You can have overlapping key names which are resolved in the following order (from most to least precendence):

- item .secrets (ex. `/environments/production/writing/ghost.secrets`)
- item .env (ex. `/environments/production/writing/ghost.env`)
- stack .env (ex. `/environments/production/writing/.env`)
- environment .env (ex. `/environments/production/.env`)
- environments .env (ex. `/environments/.env`)

#### Variable Substitution

`/tools/compose.sh` will dynamically replace referenced variables in `.env` and `.secrets`. For example, let's say this is your environment `.env` file:

```ini
NETWORK_HOST=192.168.1.200
```

And `media/something.env` contains:

```ini
SOMETHING_URL=http://${NETWORK_HOST}:9999
```

The final environment variables used to compose would be:

```ini
NETWORK_HOST=192.168.1.200
SOMETHING_URL=http://192.168.1.200:9999
```

#### Example Secrets

`/tools/compose.sh` will automatically create a copy of every `.secrets` file, clear out the values (leaving key names), and add a `.example` extension. If you include these files in your `/.gitignore`, they can help others understand what secret variables are required without seeing your secret values.

### stacks.txt

`stacks.txt` is a filter for `/tools/compose.sh` when composing an environment. Normally, all stacks will be processed in alphabetical order when composing an environment (ex. `compose.sh production up`, `compose.sh production down`, `compose.sh production restart`, etc).

But if you have a non-empty `stacks.txt` with valid stack names (1 per line), each stack will be composed in the ordered specified.

## Troubleshooting

### Traefik not serving SSL certs

Probably need to chmod 600 acme.json

### s6-overlay-suexec: fatal: can only run as pid 1

if you see the error below and use `/environments/common-services.yml`, set the extends service to `base` or `with_networks`

```bash
s6-overlay-suexec: fatal: can only run as pid 1
```
