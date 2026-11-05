from types import SimpleNamespace
from unittest.mock import Mock

from azure.core.exceptions import ResourceExistsError
from azure.data.tables import UpdateMode

import storage


def make_lead():
    return SimpleNamespace(
        email="trevor@example.com",
        name="Trevor Santos",
        message="Partnership inquiry.",
    )


def test_save_lead_returns_true_when_created(monkeypatch):
    table_mock = Mock()
    monkeypatch.setattr(storage, "get_leads_table", lambda: table_mock)

    result = storage.save_lead(make_lead())

    assert result is True
    table_mock.create_entity.assert_called_once()

    entity = table_mock.create_entity.call_args.kwargs["entity"]
    assert entity["PartitionKey"] == "leads"
    assert entity["RowKey"] == "trevor@example.com"
    assert entity["crm_status"] == "pending"


def test_save_lead_updates_existing_record(monkeypatch):
    table_mock = Mock()
    table_mock.create_entity.side_effect = ResourceExistsError(
        message="Entity already exists."
    )
    monkeypatch.setattr(storage, "get_leads_table", lambda: table_mock)

    result = storage.save_lead(make_lead())

    assert result is False
    table_mock.update_entity.assert_called_once()

    update = table_mock.update_entity.call_args.kwargs
    assert update["mode"] == UpdateMode.MERGE
    assert update["entity"]["RowKey"] == "trevor@example.com"
    assert "crm_status" not in update["entity"]

def test_update_crm_status_changes_only_status(monkeypatch):
    table_mock = Mock()
    monkeypatch.setattr(storage, "get_leads_table", lambda: table_mock)

    storage.update_crm_status(
        email="trevor@example.com",
        status="synced",
    )

    table_mock.update_entity.assert_called_once()

    update = table_mock.update_entity.call_args.kwargs

    assert update["entity"] == {
        "PartitionKey": "leads",
        "RowKey": "trevor@example.com",
        "crm_status": "synced",
    }
    assert update["mode"] == UpdateMode.MERGE