import json
import logging
from datetime import datetime, timezone


def log_event(
    logger: logging.Logger,
    event: str,
    correlation_id: str,
    **fields,
) -> None:
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": "INFO",
        "event": event,
        "correlation_id": correlation_id,
        **fields,
    }

    logger.info(json.dumps(record))
