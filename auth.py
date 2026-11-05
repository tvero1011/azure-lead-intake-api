import base64
import json

from azure.functions import HttpRequest


REQUIRED_ROLE = "Lead.Write"


def has_required_role(req: HttpRequest) -> bool:
    principal_header = req.headers.get("x-ms-client-principal")

    if not principal_header:
        return False

    try:
        decoded = base64.b64decode(
            principal_header,
            validate=True,
        )

        principal = json.loads(decoded)

        claims = principal.get("claims", [])

        roles = {
            claim.get("val")
            for claim in claims
            if claim.get("typ") in (
                "roles",
                "http://schemas.microsoft.com/ws/2008/06/identity/claims/role",
            )
        }

        return REQUIRED_ROLE in roles

    except (ValueError, TypeError, json.JSONDecodeError):
        return False