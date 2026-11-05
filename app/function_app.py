import json
import logging
import uuid

import azure.functions as func
from pydantic import ValidationError

from auth import get_authorization_status

from integrations import (
    downstream_enabled,
    notify_slack,
    sync_to_hubspot,
)
from logging_config import log_event
from models import LeadSubmission
from storage import save_lead, update_crm_status


app = func.FunctionApp()
logger = logging.getLogger("lead_intake")


@app.route(
    route="health",
    methods=["GET"],
    auth_level=func.AuthLevel.ANONYMOUS,
)
def health(req: func.HttpRequest) -> func.HttpResponse:
    correlation_id = (
        req.headers.get("x-correlation-id")
        or str(uuid.uuid4())
    )

    log_event(
        logger,
        event="health_check",
        correlation_id=correlation_id,
        status="healthy",
    )

    return func.HttpResponse(
        body=json.dumps({"status": "healthy"}),
        status_code=200,
        mimetype="application/json",
        headers={"X-Correlation-ID": correlation_id},
    )


@app.route(
    route="leads",
    methods=["POST"],
    auth_level=func.AuthLevel.ANONYMOUS,
)
def create_lead(req: func.HttpRequest) -> func.HttpResponse:
    correlation_id = (
        req.headers.get("x-correlation-id")
        or str(uuid.uuid4())
    )

    # Step 1: Authorize the caller.
    auth_status = get_authorization_status(req)

    if auth_status != 200:
        log_event(
            logger,
            event="lead_authorization_denied",
            correlation_id=correlation_id,
        )

        error_message = (
            "Authentication required."
            if auth_status == 401
            else "Forbidden: Lead.Write role required."
        )

        return func.HttpResponse(
            body=json.dumps({"error": error_message}),
            status_code=auth_status,
            mimetype="application/json",
            headers={"X-Correlation-ID": correlation_id},
        )

    # Step 2: Validate the incoming lead.
    try:
        payload = req.get_json()
        lead = LeadSubmission.model_validate(payload)

    except ValidationError as exc:
        errors = [
            {
                "field": ".".join(str(part) for part in error["loc"]),
                "message": error["msg"],
            }
            for error in exc.errors()
        ]

        return func.HttpResponse(
            body=json.dumps({
                "error": "Lead validation failed.",
                "details": errors,
            }),
            status_code=422,
            mimetype="application/json",
            headers={"X-Correlation-ID": correlation_id},
        )

    except ValueError:
        return func.HttpResponse(
            body=json.dumps({
                "error": "Invalid JSON request body."
            }),
            status_code=422,
            mimetype="application/json",
            headers={"X-Correlation-ID": correlation_id},
        )

    log_event(
        logger,
        event="lead_received",
        correlation_id=correlation_id,
        email_domain=lead.email.split("@")[-1],
    )

    # Step 3: Persist the lead before calling external services.
    # A storage failure must prevent a success response.
    try:
        is_new_lead = save_lead(lead)

    except Exception as exc:
        logger.error(
            "Lead persistence failed; correlation_id=%s error=%s",
            correlation_id,
            type(exc).__name__,
        )

        return func.HttpResponse(
            body=json.dumps({
                "error": "Unable to save lead. Please try again."
            }),
            status_code=503,
            mimetype="application/json",
            headers={"X-Correlation-ID": correlation_id},
        )

    lead_data = lead.model_dump()

    # Step 4: Notify Slack only when a lead is first created.
    if is_new_lead:
        try:
            notify_slack(lead_data)

        except Exception as exc:
            logger.error(
                "Slack processing failed; correlation_id=%s error=%s",
                correlation_id,
                type(exc).__name__,
            )

    # Step 5: Synchronize with HubSpot when downstream services are enabled.
    if downstream_enabled():
        try:
            synced = sync_to_hubspot(lead_data)

        except Exception as exc:
            synced = False

            logger.error(
                "HubSpot processing failed; correlation_id=%s error=%s",
                correlation_id,
                type(exc).__name__,
            )

        # Step 6: Record the CRM synchronization result.
        try:
            update_crm_status(
                email=lead.email,
                status="synced" if synced else "failed",
            )

        except Exception as exc:
            logger.error(
                "CRM status update failed; correlation_id=%s error=%s",
                correlation_id,
                type(exc).__name__,
            )

    # Step 7: Return success after the lead has been persisted.
    return func.HttpResponse(
        body=json.dumps({
            "status": "accepted",
            "lead": lead_data,
        }),
        status_code=200,
        mimetype="application/json",
        headers={"X-Correlation-ID": correlation_id},
    )