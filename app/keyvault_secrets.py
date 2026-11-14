import os
from functools import lru_cache

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient


@lru_cache(maxsize=1)
def get_secret_client() -> SecretClient:
    vault_url = os.getenv("KEY_VAULT_URI")

    if not vault_url:
        raise RuntimeError("KEY_VAULT_URI is not configured.")

    client_id = os.getenv("AZURE_CLIENT_ID")

    credential = DefaultAzureCredential(
        managed_identity_client_id=client_id or None
    )

    return SecretClient(
        vault_url=vault_url,
        credential=credential,
    )


@lru_cache(maxsize=32)
def get_secret(secret_name: str) -> str:
    secret = get_secret_client().get_secret(secret_name)

    if not secret.value:
        raise RuntimeError(
            f"Key Vault secret '{secret_name}' has no value."
        )

    return secret.value