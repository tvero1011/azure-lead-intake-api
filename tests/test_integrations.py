from unittest.mock import Mock

import requests

import integrations


def test_hubspot_skips_when_disabled(monkeypatch):
    monkeypatch.setenv("DOWNSTREAM_ENABLED", "false")
    monkeypatch.setenv("HUBSPOT_ACCESS_TOKEN", "test-token")

    result = integrations.sync_to_hubspot({
        "name": "Trevor Santos",
        "email": "trevor@example.com",
    })

    assert result is False


def test_hubspot_skips_when_token_missing(monkeypatch):
    monkeypatch.setenv("DOWNSTREAM_ENABLED", "true")
    monkeypatch.delenv("HUBSPOT_ACCESS_TOKEN", raising=False)

    result = integrations.sync_to_hubspot({
        "name": "Trevor Santos",
        "email": "trevor@example.com",
    })

    assert result is False


def test_hubspot_returns_true_on_success(monkeypatch):
    monkeypatch.setenv("DOWNSTREAM_ENABLED", "true")
    monkeypatch.setenv("HUBSPOT_ACCESS_TOKEN", "test-token")

    response = Mock()
    response.raise_for_status.return_value = None

    post_mock = Mock(return_value=response)
    monkeypatch.setattr(integrations.requests, "post", post_mock)

    result = integrations.sync_to_hubspot({
        "name": "Trevor Santos",
        "email": "trevor@example.com",
    })

    assert result is True
    post_mock.assert_called_once()

    payload = post_mock.call_args.kwargs["json"]
    assert payload["inputs"][0]["id"] == "trevor@example.com"
    assert payload["inputs"][0]["idProperty"] == "email"


def test_hubspot_returns_false_on_http_error(monkeypatch):
    monkeypatch.setenv("DOWNSTREAM_ENABLED", "true")
    monkeypatch.setenv("HUBSPOT_ACCESS_TOKEN", "test-token")

    response = Mock()
    response.status_code = 500

    error = requests.HTTPError("Server error")
    error.response = response

    post_mock = Mock()
    post_mock.return_value.raise_for_status.side_effect = error

    monkeypatch.setattr(integrations.requests, "post", post_mock)

    result = integrations.sync_to_hubspot({
        "name": "Trevor Santos",
        "email": "trevor@example.com",
    })

    assert result is False

def test_slack_skips_when_disabled(monkeypatch):
    monkeypatch.setenv("DOWNSTREAM_ENABLED", "false")
    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")

    result = integrations.notify_slack({
        "name": "Trevor Santos",
        "email": "trevor@example.com",
        "message": "Partnership inquiry.",
    })

    assert result is False


def test_slack_skips_when_webhook_missing(monkeypatch):
    monkeypatch.setenv("DOWNSTREAM_ENABLED", "true")
    monkeypatch.delenv("SLACK_WEBHOOK_URL", raising=False)

    result = integrations.notify_slack({
        "name": "Trevor Santos",
        "email": "trevor@example.com",
        "message": "Partnership inquiry.",
    })

    assert result is False


def test_slack_returns_true_on_success(monkeypatch):
    monkeypatch.setenv("DOWNSTREAM_ENABLED", "true")
    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")

    response = Mock()
    response.raise_for_status.return_value = None

    post_mock = Mock(return_value=response)
    monkeypatch.setattr(integrations.requests, "post", post_mock)

    result = integrations.notify_slack({
        "name": "Trevor Santos",
        "email": "trevor@example.com",
        "message": "Partnership inquiry.",
    })

    assert result is True
    post_mock.assert_called_once()

    payload = post_mock.call_args.kwargs["json"]
    assert "New lead received" in payload["text"]
    assert "Trevor Santos" in payload["text"]


def test_slack_returns_false_on_http_error(monkeypatch):
    monkeypatch.setenv("DOWNSTREAM_ENABLED", "true")
    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")

    response = Mock()
    response.status_code = 500

    error = requests.HTTPError("Server error")
    error.response = response

    post_mock = Mock()
    post_mock.return_value.raise_for_status.side_effect = error

    monkeypatch.setattr(integrations.requests, "post", post_mock)

    result = integrations.notify_slack({
        "name": "Trevor Santos",
        "email": "trevor@example.com",
        "message": "Partnership inquiry.",
    })

    assert result is False