# Lateping ping

Find out when a scheduled GitHub Actions workflow stops running.

GitHub turns off scheduled workflows in public repos after 60 days without activity, and delays
or drops runs under load. Nothing fails, so nothing tells you. This action reports each run to
[Lateping](https://lateping.com): if a run doesn't report on schedule, or reports a failure, you
get an alert.

## Use it

1. Create a check at [app.lateping.com](https://app.lateping.com) with the same cron expression as
   your workflow, timezone `UTC`.
2. Save its ping URL as a repository secret named `LATEPING_URL`:

   ```bash
   gh secret set LATEPING_URL --body "https://lateping.com/p/<check-id>"
   ```

3. Add the action as the **last step** of the job:

   ```yaml
   on:
     schedule:
       - cron: "17 2 * * *"

   jobs:
     backup:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - run: ./scripts/backup.sh

         - uses: lateping/ping@v1
           if: always()
           with:
             url: ${{ secrets.LATEPING_URL }}
             status: ${{ job.status }}
   ```

`if: always()` makes the step run even when an earlier step failed. A successful job sends a
success ping; a failed or cancelled job sends `/fail`, which alerts within a minute. If the
workflow never runs at all, no ping arrives and the check alerts after its grace period.

### Time each run

Add a start ping as the first step. Lateping records how long each run took (run analytics are on
Pro and above).

```yaml
      - uses: lateping/ping@v1
        with:
          url: ${{ secrets.LATEPING_URL }}
          status: start
```

## Inputs

| Input | Default | |
|---|---|---|
| `url` | required | The check's ping URL. Keep it in a secret. |
| `status` | `success` | `start`, `success`, or `${{ job.status }}` (`success`, `failure`, `cancelled`). |
| `fail-on-error` | `false` | Fail this step if the ping can't be sent. Off by default, so monitoring never breaks your job. |

The step outputs `signal`: `start`, `success` or `fail`.

## How it works

One `curl` call: `POST` to the ping URL, `/start` or `/fail`, with a 10 second timeout and three
retries. No dependencies, no data beyond the request itself, and the URL is never printed to the
log. Guide: [GitHub Actions scheduled workflow not running](https://lateping.com/guides/github-actions).

## License

MIT. See [LICENSE](LICENSE).
