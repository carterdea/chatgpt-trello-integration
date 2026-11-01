# ChatGPT Trello Integration

## CVE-2026-98432 deployment mitigation

[CVE-2026-98432](https://kernel.googlesource.com/pub/scm/linux/security/vulns/+/refs/heads/master/cve/published/2026/CVE-2026-98432.mbox) is a Linux IPv4 TCP use-after-free. The demonstrated remote root exploit uses an MPTCP listener; the underlying defect is not specific to MPTCP. Every Linux host accepting IPv4 TCP needs a vendor-fixed kernel and reboot, or provider confirmation that the running kernel includes the fix. Updating a container image does not patch its host kernel.

The Docker image sets `GODEBUG=multipathtcp=0` for Thruster. The [Go Security Team](https://groups.google.com/g/golang-announce/c/PCoQcdxoScw/m/aD-MgXEvAAAJ) describes this as an interim mitigation for Go's default listeners, not a complete fix. A runtime `GODEBUG` override can remove it; preserve other settings and keep `multipathtcp=0` last. Explicit per-socket MPTCP configuration can override the Go default.

The pinned Thruster 0.1.11 declares Go 1.23.6, and Kamal 2.5.2 selects kamal-proxy v0.8.4, which declares Go 1.23.3. Those declarations do not establish the shipped binaries' build settings or the running host's exposure. This change is precautionary; no deployed binary, listener, or kernel has been validated.

### Kamal proxy

The shared `kamal-proxy` container has its own environment. The application's Docker setting does not reach it. Kamal 2.5.2 uses `proxy boot_config`; it does not support `proxy.run` in `config/deploy.yml`.

For an approved maintenance window:

1. Inspect existing settings with `bin/kamal proxy boot_config get`.
2. Prepare `bin/kamal proxy boot_config set --docker-options env=GODEBUG=multipathtcp=0`, preserving every existing port, bind address, logging option, Docker option, and unrelated `GODEBUG` setting. `set` replaces the stored boot options. The command shown assumes default options and no existing `GODEBUG`; adapt it before use.
3. Obtain operational approval before applying the configuration and running `bin/kamal proxy reboot`. Rebooting the shared proxy briefly interrupts every app using it. An app deploy or proxy restart alone does not recreate the proxy with the new environment.
4. Check the recreated app and proxy container environments. Inspect `ss -Mlnp` on the host and inside each container's network namespace. No MPTCP listeners at one instant is only a snapshot; verify the running kernel's vendor advisory and backported fix after reboot.

These commands are operator instructions. This PR does not apply them or change a running host.

## Deployment check

Run `bundle exec ruby test/deployment_test.rb` to check that the final Docker image inherits the MPTCP opt-out. CI runs the same check. This source check does not build the image or reproduce the kernel race.
