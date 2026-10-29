# Contributing

Thanks for helping improve Halo Search!

## Reporting a problem

[Open an issue](https://github.com/buwaneka-halpage/halo-search/issues/new/choose) with your macOS version, what you
did and what happened. If searches stopped working altogether, Google probably changed a page: running the
[live self-test](docs/DEVELOPMENT.md#live-self-test) and pasting its output helps a lot.

## Making a change

1. Fork the repository and create a branch from `main`.
2. Build and test:
   ```sh
   scripts/test.sh
   scripts/build.sh --install
   ```
3. If you touched `GoogleSearch` or `PageScripts`, run the live self-test too.
4. Add an entry under **Unreleased** in [CHANGELOG.md](CHANGELOG.md) for anything a user would notice.
5. Open a pull request describing what changed and how you tested it. Screenshots or a short screen recording help
   for anything visual.

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) first for larger changes; for new features, opening an issue to
discuss the approach before writing code saves everyone time.

## Guidelines

- Keep logic that doesn't need AppKit in `HaloSearchCore`, with tests.
- Match the existing style: small focused types, comments that explain why.
- No new dependencies without discussion — the project currently uses only Apple's SDKs.
- Be kind. Everyone here is volunteering their time.
