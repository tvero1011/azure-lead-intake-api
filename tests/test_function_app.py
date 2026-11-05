import json
from unittest.mock import Mock

import pytest
import azure.functions as func

import function_app


def make_request(method, body=None, headers=None):
    return func.HttpRequest(
        method=method,
        url="http://localhost/api/test",
        headers=headers or {},
        params={},
        route_params={},
        body=json.dumps(body).encode("utf-8") if body is not None else b"",
    )


def test_health_returns_200():
    request = make_request("GET")

    response = function_app.health(request)

    assert response.status_code == 200
    assert json.loads(response.get_body()) == {
        "status": "healthy"
    }
    assert response.headers.get("X-Correlation-ID")


def test_create_lead_returns_403_without_role(monkeypatch):
    monkeypatch.setattr(
        function_app,
        "has_required_role",
        lambda req: False,
    )

    request = make_request("POST")

    response = function_app.create_lead(request)

    assert response.status_code == 403


def test_create_lead_saves_valid_lead(monkeypatch):
    monkeypatch.setattr(
        function_app,
        "has_required_role",
        lambda req: True,
    )
    save_mock = Mock()
    monkeypatch.setattr(function_app, "save_lead", save_mock)

    request = make_request(
        "POST",
        {
            "name": "Trevor Santos",
            "email": "TREVOR@EXAMPLE.COM",
            "message": "I need more information.",
        },
    )

    response = function_app.create_lead(request)

    assert response.status_code == 200
    assert json.loads(response.get_body())["lead"]["email"] == (
        "trevor@example.com"
    )
    save_mock.assert_called_once()


def test_create_lead_returns_422_for_invalid_email(monkeypatch):
    monkeypatch.setattr(
        function_app,
        "has_required_role",
        lambda req: True,
    )

    request = make_request(
        "POST",
        {
            "name": "Trevor Santos",
            "email": "not-an-email",
            "message": "I need more information.",
        },
    )

    response = function_app.create_lead(request)

    assert response.status_code == 422


def test_create_lead_returns_422_for_malformed_json(monkeypatch):
    monkeypatch.setattr(
        function_app,
        "has_required_role",
        lambda req: True,
    )

    request = func.HttpRequest(
        method="POST",
        url="http://localhost/api/leads",
        headers={},
        params={},
        route_params={},
        body=b"{invalid json",
    )

    response = function_app.create_lead(request)

    assert response.status_code == 422