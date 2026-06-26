# DCMLockerUpdate

Shell scripts that physical lockers **fetch over the network and run as root** to self-update. No build step and no application code — just scripts the fleet pulls and executes. The locker firmware itself lives in the sibling `dcmlockerclienteubuntu` repo.

## ⚠️ Production-critical

- Lockers fetch these scripts from `main` at runtime and pipe them straight into `sudo bash`. **A change is live to the whole fleet the moment it lands on `main`** — no staging branch, no review gate, no CI between a push and a locker running it as root. Treat every commit to `main` as a production deploy.
- Test/prod separation lives in the update **channel** (`release` = production default, `latest` = test lockers only), not in this repo's branch.
- This repo is **publicly mirrored** — keep secrets, internal hostnames, and infra details out of it.

## Testing

Run any root/destructive script **unmodified** in a throwaway `almalinux:9` container — never against a real locker, and never by stripping a script's own guards. Real-hardware validation happens on the dedicated testing locker and gates fleet rollout.
