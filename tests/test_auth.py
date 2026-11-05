import base64
import json
from types import SimpleNamespace

from auth import has_required_role


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

    assert has_required_role(request) is True


def test_rejects_wrong_role():
    request = make_request([
        {"typ": "roles", "val": "Lead.Read"}
    ])

    assert has_required_role(request) is False


def test_rejects_missing_principal_header():
    request = make_request()

    assert has_required_role(request) is False

def test_rejects_malformed_base64():
    request = SimpleNamespace(
        headers={"x-ms-client-principal": "not-valid-base64!!!"}
    )

    assert has_required_role(request) is False


def test_rejects_malformed_principal_json():
    request = SimpleNamespace(
        headers={
            "x-ms-client-principal": base64.b64encode(
                b"not-json"
            ).decode("utf-8")
        }
    )

    assert has_required_role(request) is False