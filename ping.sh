#!/usr/bin/env bash
# Sends one Lateping ping. Inputs come from the environment (see action.yml).
set -uo pipefail

url="${LATEPING_URL%/}"
if [[ -z "$url" ]]; then
  echo "::error::No ping URL. Set 'url', for example: url: \${{ secrets.LATEPING_URL }}"
  exit 1
fi
if [[ ! "$url" =~ ^https?://[^/]+/p/[0-9a-fA-F-]{36}$ ]]; then
  echo "::error::That doesn't look like a Lateping ping URL (https://lateping.com/p/<check-id>)."
  exit 1
fi

case "$(echo "${LATEPING_STATUS:-success}" | tr '[:upper:]' '[:lower:]')" in
  start) signal=start path=/start ;;
  success | '') signal=success path= ;;
  failure | cancelled | fail) signal=fail path=/fail ;;
  *)
    echo "::error::Unknown status '${LATEPING_STATUS}'. Use start, success, failure, cancelled or \${{ job.status }}."
    exit 1
    ;;
esac
echo "signal=$signal" >>"$GITHUB_OUTPUT"

# -f: a wrong check ID (404) fails curl instead of passing silently. The URL is a secret, so it's
# never printed.
if out=$(curl -fsS -m 10 --retry 3 --retry-connrefused -X POST -o /dev/null -w '%{http_code}' "$url$path" 2>&1); then
  echo "Lateping: sent $signal ping ($out)."
  exit 0
fi
msg="Lateping: couldn't send the $signal ping: ${out//$url/<ping URL>}"
if [[ "${LATEPING_STRICT:-false}" == "true" ]]; then
  echo "::error::$msg"
  exit 1
fi
echo "::warning::$msg"
