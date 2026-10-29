# Detections

Phase 4 output ([docs/04-detections.md](../docs/04-detections.md)):

- `aws/`: Athena SQL detections over the CloudTrail table, plus EventBridge
  patterns as JSON.
- `sigma/`: a portable Sigma version of each detection, product `aws` / service
  `cloudtrail`, with a valid UUIDv4.

Each detection is validated with a benign action against the lab's own test
identities; the alert record lives beside the claim in `evidence/phase4/`.
