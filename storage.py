import os

from azure.data.tables import TableServiceClient, UpdateMode
from azure.core.exceptions import ResourceExistsError


def get_table_service_client() -> TableServiceClient:
    connection_string = os.environ.get("AzureWebJobsStorage")

    if not connection_string:
        raise RuntimeError(
            "AzureWebJobsStorage is not configured."
        )

    return TableServiceClient.from_connection_string(
        conn_str=connection_string
    )

def get_leads_table():
    service_client = get_table_service_client()

    return service_client.create_table_if_not_exists(
        table_name="Leads"
    )

def save_lead(lead):
    table_client = get_leads_table()

    entity = {
        "PartitionKey": "leads",
        "RowKey": lead.email,
        "name": lead.name,
        "message": lead.message,
        "crm_status": "pending",
    }

    try:
        table_client.create_entity(entity=entity)
        return True

    except ResourceExistsError:
        # Update lead details without resetting the existing CRM status.
        table_client.update_entity(
            entity={
                "PartitionKey": "leads",
                "RowKey": lead.email,
                "name": lead.name,
                "message": lead.message,
            },
            mode=UpdateMode.MERGE,
        )
        return False

def update_crm_status(email: str, status: str) -> None:
    table_client = get_leads_table()

    table_client.update_entity(
        entity={
            "PartitionKey": "leads",
            "RowKey": email,
            "crm_status": status,
        },
        mode=UpdateMode.MERGE,
    )