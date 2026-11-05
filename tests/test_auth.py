
import base64
import json
from types import SimpleNamespace

from auth import get_authorization_status


def make_request(claims=None):
    headers = {}

    if claims is not None:
        principal = {
            "auth_typ": "aad",
            "claims": claims,
        }

        encoded = base64.b64encode(
            json.dumps(principal).encode("utf-8")
        ).decode("utf-8")

        headers["x-ms-client-principal"] = encoded

    return SimpleNamespace(headers=headers)


def test_authorized_with_lead_write_role():
    request = make_request([
        {"typ": "roles", "val": "Lead.Write"}
    ])

    assert get_authorization_status(request) == 200


def test_forbidden_when_role_is_missing():
    request = make_request([
        {"typ": "roles", "val": "Lead.Read"}
    ])

    assert get_authorization_status(request) == 403


def test_unauthorized_when_principal_is_missing():
    request = make_request()

    assert get_authorization_status(request) == 401


def test_unauthorized_with_malformed_base64():
    request = SimpleNamespace(
        headers={"x-ms-client-principal": "not-valid-base64!!!"}
    )

    assert get_authorization_status(request) == 401


def test_unauthorized_with_malformed_principal_json():
    request = SimpleNamespace(
        headers={
            "x-ms-client-principal": base64.b64encode(
                b"not-json"
            ).decode("utf-8")
        }
    )

    assert get_authorization_status(request) == 401
