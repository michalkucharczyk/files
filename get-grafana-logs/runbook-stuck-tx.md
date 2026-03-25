# Debugging Stuck Transactions

## Prerequisites

1. **Enable logs** — request `txpool=trace` to be enabled on the RPC node your app connects to (and sometimes on collators). We should keep pool's logs enabled to easily catch "rare" problems on our way to Web3 summit.

2. **Download logs** — obtain node logs for the relevant time range. If you have Grafana access, use the log download script ([`logs.sh`](https://github.com/michalkucharczyk/files/blob/main/get-grafana-logs/logs.sh)). Otherwise request logs from the node operator.

3. **Get the tx hash** — your application should be logging tx hashes.

## Quick Triage Checklist

Grep the tx hash in the downloaded logs, then follow these steps:

1. **Was it submitted?** — look for `fatp::submit_one` or `fatp::submit_and_watch`
2. **What was the validation result?** — ready, future, or invalid?
3. **Was it imported into a view?** — look for `Importing transaction` with `set="ready"` or `set="future"`
4. **Was it dropped?** — look for `Dropped (limits enforced)`, `Dropped (replaced)`, or `transaction_dropped`
5. **Was it invalidated?** — look for `Extrinsic invalid`, `transactions_invalidated`, or `Removed invalid transaction`
6. **Revalidation?** — look for `view::revalidate` results for your tx hash
7. **Was it finalized?** — look for `transaction_finalized` or `Pruned at`

## Grep Reference

| Lifecycle phase | What to grep | Notes |
|---|---|---|
| Submission | `fatp::submit_one`, `fatp::submit_and_watch` | Entry point into the pool |
| Mempool | `mempool::try_insert` | Added to the internal pool |
| Import into view | `Importing transaction` | Shows `set="ready"` or `set="future"` — tells you which queue |
| Watched tx events | `mvl sending out` | Only for `submit_and_watch`. Shows status transitions sent to the app |
| Dropped | `Dropped (limits enforced)`, `Dropped (replaced)`, `transaction_dropped` | Pool capacity or priority replacement |
| Invalid | `Extrinsic invalid`, `transactions_invalidated`, `Removed invalid transaction` | Runtime rejected the tx |
| Revalidation | `view::revalidate`, `mempool::revalidate_inner` | Periodic re-checks of pooled txs |
| Finalization | `transaction_finalized`, `Sent finalization event` | Tx included and finalized |
| Pruning | `Starting pruning of block`, `Pruned at` | Tx removed after block inclusion |

## Not All Errors Are Bugs

The fork-aware pool submits a tx to **all active views** (one per fork). It only needs one view to accept it. So you will routinely see per-view errors that look alarming but are normal:

- **`ValidatedPool::submit_one invalid`** — tx failed validation on a view. State-dependent errors like `Payment`, `Stale`, `ExhaustsResources` are fork-specific — the same tx can be valid on other forks. Expected in FATP, it only needs one view to accept the tx. **Watch out**: any `Invalid` result triggers a 30-minute ban in the view's rotator (`DEFAULT_BAN_TIME_SECS = 30 * 60`). Since new views are cloned from existing ones (`deep_clone_with_event_handler`), the ban propagates to all subsequent views. The tx stays in mempool (mempool revalidation bypasses the rotator) but silently fails `check_is_known` → `TemporarilyBanned` on every new view — no `view::submit_many` log appears. Symptom: a ~30-minute gap where you see only `validate_transaction_blocking` (mempool revalidation) and `Command::RemoveView ready views: {}`, but no view submissions for the tx.
- **`Importing transaction ... set="future"`** — tx has a nonce gap or unsatisfied dependency. It will move to `ready` once the dependency is met. This is normal pool behavior.
- **`Dropped (replaced)`** — tx was replaced by a higher-priority tx with the same nonce. Expected in priority auction scenarios.
- **`mempool::try_insert ... Err(AlreadyImported(...))`** — tx was already in the mempool. Typically means the tx arrived via gossip from peers but the node already knows it. Normal.
- **`Removed as part of the subtree` followed immediately by `Importing transaction`** — tx is being removed and re-added during view revalidation (`finish_revalidation` → `resubmit`). This is normal FATP churn — every time a view finishes revalidation, transactions are removed from the pool and re-imported with updated validation data. Looks alarming but is by design.
- **`TemporarilyBanned`** — tx was banned by the rotator after being marked invalid. Ban lasts 30 minutes (`DEFAULT_BAN_TIME_SECS = 30 * 60`). The ban is cloned into every new view. If you see this at the very end of a tx's life (during pruning/resubmit), it's because the tx was banned earlier and the ban is still active when the pool tries to resubmit dependents.

## Important: Logs Show a Local View

A node's logs only reflect **that node's local perspective**. A transaction can appear invalid or dropped on one node but still be valid and included by another peer.

Common scenarios where this matters:
- **Priority auctions** — your tx gets replaced locally but a different node includes it
- **Fork races** — tx is invalid on one fork but valid on another

## Transaction Lifecycle (Brief)

```
submit → validate → ready/future queue → revalidation → included in block → finalized
```

- **submit**: tx enters the node via RPC (`author_submitExtrinsic` / `author_submitAndWatchExtrinsic`)
- **validate**: runtime's `validate_transaction` checks the tx (nonce, signature, fees, custom logic)
- **ready/future queue**: valid txs go to `ready` (can be included now) or `future` (waiting on dependencies)
- **revalidation**: pool periodically re-validates txs against new blocks — txs can move between queues or be dropped
- **included**: block author picks txs from `ready` queue
- **finalized**: block containing the tx is finalized

## Further Reading

- [Transaction pool internals (HackMD)](https://hackmd.io/69SiexjfTY2xv-kvxNac9Q?view=)
- Run `cargo doc --document-private-items` on `sc-transaction-pool` for detailed internal documentation
