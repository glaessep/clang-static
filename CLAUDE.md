# clang-static

A build recipe for the static libraries of Clang's C++ API. It holds no LLVM source.

## Rules

- Describe everything in LLVM's and Clang's terms only. Name no downstream project,
  product or company. This covers files, comments, commit messages and branch names.
- Write plain words in short sentences (20 words or fewer), in the active voice, in English.
- Keep every command of the workflow in plain sight. The workflow calls `./build.sh` and
  `./smoke/run.sh`. A person can run both by hand the same way.
- Commit messages use Conventional Commits (`feat:`, `ci:`, `docs:`). Add no co-author
  line, no session link and no model name.
- Run `git config core.hooksPath .githooks` once in each clone. The `commit-msg` hook
  deletes such lines.
- Pin each action to a full commit sha, with the version in a comment.

## Build and test

- Check the configure step: `STOP_AFTER=configure ./build.sh linux-x86_64`
- Full build (over an hour): `./build.sh linux-x86_64`. The package lands in `out/`.
- Smoke test: `./smoke/run.sh out/clang-static-<version>-linux-x86_64`
- Change the LLVM version in `llvm.version` only. It holds the version and the source sha256.
