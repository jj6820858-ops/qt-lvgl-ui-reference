# Security policy

## Reporting

Do not open a public issue for a security problem. Email the maintainer with a
description, reproduction steps and the affected version.

## Scope

This template has no network surface and persists no data. For projects derived
from it, the relevant concerns are:

- **Input validation at the transport boundary**, in `infrastructure/`, before
  values reach `domain`. Nothing below that layer should ever see unvalidated
  bytes.
- **Dependency currency** — track Qt security advisories for your LTS branch.
- **Deployment integrity** — signing and notarisation on desktop, verified
  images on embedded targets.
