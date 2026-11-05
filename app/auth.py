
import base64
import json

from azure.functions import HttpRequest


REQUIRED_ROLE = "Lead.Write"


def get_authorization_status(req: HttpRequest) -> int:
    principal_header = req.headers.get("x-ms-client-principal")

    if not principal_header:
        return 401

    try:
        decoded = base64.b64decode(
            principal_header,
            validate=True,
        )

        principal = json.loads(decoded)

        if not isinstance(principal, dict):
            return 401

        claims = principal.get("claims", [])

        roles = {
            claim.get("val")
            for claim in claims
            if isinstance(claim, dict)
            and claim.get("typ") in (
                "roles",
                "http://schemas.microsoft.com/ws/2008/06/identity/claims/role",
            )
        }

        return 200 if REQUIRED_ROLE in roles else 403

    except (ValueError, TypeError, json.JSONDecodeError):
        return 401
