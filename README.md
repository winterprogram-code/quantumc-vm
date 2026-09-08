# QuantumCloud Provider — manual VPS provisioner

Admin-run tool: you type a command, answer a few prompts, and it spins up
one Docker container with SSH access. There is no public API — it only
runs when you run it.

## Setup
```bash
chmod +x *.sh
cp webhook.conf.example webhook.conf   # optional, for Discord notifications
nano webhook.conf                       # paste your real webhook URL
docker build -t quantum-vps-base .      # one-time
```

## Provision an instance
```bash
./provision.sh
```
Answer the prompts (node hostname, customer name, SSH username/password,
port). Password is shown as you type — some web terminals (like
freestyle.sh style dashboards) don't support hidden input reliably, so
this avoids input silently getting lost.

## Manage instances
```bash
./manage.sh list
./manage.sh show <customer_name>
./manage.sh remove <customer_name>
```

## Troubleshooting
- **"Broken pipe" text during token generation**: cosmetic only in the old
  version (caused by `tr | head` racing) — fixed in this version by using
  `openssl rand` instead. If you still see it, it's not affecting the result.
- **Docker image not found errors**: run `docker build -t quantum-vps-base .`
  again explicitly — some sandboxed/web-based Docker UIs build images in a
  session that isn't the same daemon your terminal talks to.
- **Script exits with no message**: run `bash -x ./provision.sh` to see
  exactly which line it stops on, and check the tail of the output.
