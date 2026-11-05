
import os

from azure.core.exceptions import ResourceExistsError
from azure.data.tables import TableServiceClient, UpdateMode
from azure.identity import DefaultAzureCredential


def get_table_service_client() -> TableServiceClient:
    # Local development: connect to Azurite.
    azurite_connection_string = os.getenv("AZURITE_CONNECTION_STRING")

    if azurite_connection_string:
        return TableServiceClient.from_connection_string(
            conn_str=azurite_connection_string
        )

    # Azure: authenticate using the Function App's Managed Identity.
    endpoint = os.getenv("LEADS_TABLE_ENDPOINT")
    client_id = os.getenv("AZURE_CLIENT_ID")

    if not endpoint:
        raise RuntimeError("LEADS_TABLE_ENDPOINT is not configured.")

    credential = DefaultAzureCredential(
        managed_identity_client_id=client_id or None
    )

    return TableServiceClient(
        endpoint=endpoint,
        credential=credential,
    )


def get_leads_table():
    service_client = get_table_service_client()

    return service_client.create_table_if_not_exists(
        table_name=os.getenv("LEADS_TABLE_NAME", "Leads")
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
        # Preserve the existing CRM status when updating a lead.
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
