# DeepSeek Harness (`dsh`)

Runs the [deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) Web UI on top of
`lscr.io/linuxserver/baseimage-ubuntu:jammy`.

## Published images

Pushing a `dsh-v*` tag publishes this image as `latest` to Docker Hub and to Aliyun ACR
(`.github/workflows/release-docker-image.yml`) once `release-cli-archive.yml` has attached that
release's CLI archive, which the image installs:

```sh
docker pull wybioinfo/dsh:latest
docker pull registry.cn-hangzhou.aliyuncs.com/wybioinfo/dsh:latest
```

## Build

```sh
docker build -t dsh .
# pin another release of the biox-dev prebuilt bundle:
docker build --build-arg DSH_VERSION=0.1.10 -t dsh .
```

## Run

```sh
docker run --rm -it \
  -p 3080:3080 \
  -e PUID=$(id -u) -e PGID=$(id -g) \
  -e DEEPSEEK_API_KEY=sk-your-key-here \
  -v dsh-config:/config \
  dsh
```

`HOME` defaults to `/config` (the persistent volume) and `dsh` starts there. To use a different
directory as home — for example a bind-mounted project — set `DSH_WORKSPACE` and mount it:

```sh
docker run --rm -it \
  -p 3080:3080 \
  -e PUID=$(id -u) -e PGID=$(id -g) \
  -e DEEPSEEK_API_KEY=sk-your-key-here \
  -v dsh-config:/config \
  -e DSH_WORKSPACE=/workspace \
  -v "$PWD":/workspace \
  dsh
```

The startup URL carries a one-time process token, so read it from the logs rather than guessing it:

```sh
docker logs <container> | grep 'dsh web:'
```

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `PUID` / `PGID` | `1000` | Ownership of `/config` (and of `DSH_WORKSPACE`, when relocated). |
| `DSH_HOME` | `/config/.dsh` | Harness home: profiles, sessions, credentials, skills. Lives under the `/config` volume so it survives a rebuild. |
| `DSH_WORKSPACE` | `/config` | Relocates the user's `HOME`, and therefore the directory the agent and the Web UI start in. Unset falls back to `/config`. |
| `DSH_PORT` | `3080` | Port bound inside the container. |
| `DSH_TRUSTED_HOSTS` | empty | Space-separated extra authorities accepted by the `/api` trust fence, for a deployment reached through a name that is neither `localhost` nor a LAN IP, e.g. `dsh.example.com dsh.internal:3080`. |
| `DEEPSEEK_API_KEY` | — | Model credential. `DEEPSEEK_BASE_URL` overrides the API endpoint. |

## Notes on the design

- **Node 22 + pnpm 11.** deepseek-harness pins Node.js `^22.19 || >=24` and pnpm 11; Ubuntu jammy
  ships neither, so Node comes from NodeSource and pnpm is installed globally — `dsh plugin` and
  the Web plugin manager shell out to `pnpm`.
- **Installed from the prebuilt release bundle, not npm.** The CLI is unpacked from the
  `biox-dev/deepseek-harness` release archive (`dsh-v<version>.zip`) into `/opt/dsh`, with
  `/usr/local/bin/dsh` symlinked to it. That archive is self-contained — it ships a `dsh` launcher
  plus a vendored `node_modules`, including the frontend dist — so it needs no `npm install` and no
  compilation from source. `DSH_VERSION` selects the release tag.
- **The bind address comes from a patch, not a flag.** The shipped `dsh web` command deliberately
  binds `127.0.0.1` and *rejects* `--host 0.0.0.0` so a local launch cannot expose remote code
  execution by accident. A container must be reachable through its published port, so
  `/etc/cont-init.d/10-workspace` writes `/etc/dsh/webserver.patch.yml` and the service passes it
  with `--patch`. Since a patch replaces the addressed row's *whole* config, the shipped gzip
  policy (level 1, 1024-byte threshold) is restated there.
- **`--no-open` is always passed**, because the default-browser handoff cannot work in a container.
- **`HOME` is configurable.** The service sets `HOME="${DSH_WORKSPACE:-/config}"` and starts `dsh`
  in `HOME`, so the default home stays on the persistent `/config` volume while `DSH_WORKSPACE`
  relocates it to another directory (such as a bind-mounted project).
- **Binding all interfaces is a real exposure.** The Host carries no TLS of its own; the `/api`
  trust fence plus browser-session authentication are the only controls. Terminate TLS in a
  reverse proxy and list its hostname in `DSH_TRUSTED_HOSTS`.
