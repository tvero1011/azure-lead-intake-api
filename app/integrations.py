
import logging
import os

import requests

from keyvault_secrets import get_secret


logger = logging.getLogger("lead_intake.integrations")


def downstream_enabled() -> bool:
    return os.getenv("DOWNSTREAM_ENABLED", "false").lower() == "true"


def _get_integration_secret(secret_name: str, env_name: str) -> str | None:
    # Local development can use environment variables.
    local_value = os.getenv(env_name)

    if local_value:
        return local_value

    # Azure retrieves the secret from Key Vault.
    try:
        return get_secret(secret_name)
    except Exception as exc:
        logger.warning(
            "Integration credential unavailable; error=%s",
            type(exc).__name__,
        )
        return None


def sync_to_hubspot(lead: dict) -> bool:
    if not downstream_enabled():
        logger.info("HubSpot integration disabled.")
        return False

    token = _get_integration_secret(
        "hubspot-access-token",
        "HUBSPOT_ACCESS_TOKEN",
    )

    if not token:
        logger.warning("HubSpot sync skipped: credential not configured.")
        return False

    name_parts = lead["name"].split(maxsplit=1)

    properties = {
        "email": lead["email"],
        "firstname": name_parts[0],
    }

    if len(name_parts) > 1:
        properties["lastname"] = name_parts[1]

    payload = {
        "inputs": [
            {
                "id": lead["email"],
                "idProperty": "email",
                "properties": properties,
            }
        ]
    }

    url = (
        "https://api.hubapi.com/"
        "crm/objects/2026-09/contacts/batch/upsert"
    )

    try:
        response = requests.post(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=5,
        )

        response.raise_for_status()

        logger.info("HubSpot contact upsert succeeded.")
        return True

    except requests.RequestException as exc:
        status_code = (
            exc.response.status_code
            if exc.response is not None
            else "unavailable"
        )

        logger.warning(
            "HubSpot contact upsert failed; status=%s error=%s",
            status_code,
            type(exc).__name__,
        )
        return False


def notify_slack(lead: dict) -> bool:
    if not downstream_enabled():
        logger.info("Slack integration disabled.")
        return False

    webhook_url = _get_integration_secret(
        "slack-webhook-url",
        "SLACK_WEBHOOK_URL",
    )

    if not webhook_url:
        logger.warning("Slack notification skipped: webhook not configured.")
        return False

    message = (
        "*New lead received*\n"
        f"*Name:* {lead['name']}\n"
        f"*Email:* {lead['email']}\n"
        f"*Message:* {lead['message']}"
    )

    try:
        response = requests.post(
            webhook_url,
            json={"text": message},
            timeout=5,
        )

        response.raise_for_status()

        logger.info("Slack lead notification succeeded.")
        return True

    except requests.RequestException as exc:
        status_code = (
            exc.response.status_code
            if exc.response is not None
            else "unavailable"
        )

        logger.warning(
            "Slack notification failed; status=%s error=%s",
            status_code,
            type(exc).__name__,
        )
        return False
