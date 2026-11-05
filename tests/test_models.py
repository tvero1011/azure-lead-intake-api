import pytest
from pydantic import ValidationError

from models import LeadSubmission


def test_valid_lead_normalizes_fields():
    lead = LeadSubmission(
        name="  Trevor   Santos  ",
        email=" TREVOR@EXAMPLE.COM ",
        message="  I need more information.  ",
    )

    assert lead.name == "Trevor Santos"
    assert lead.email == "trevor@example.com"
    assert lead.message == "I need more information."


def test_rejects_invalid_email():
    with pytest.raises(ValidationError):
        LeadSubmission(
            name="Trevor Santos",
            email="not-an-email",
            message="I need more information.",
        )


def test_rejects_short_message():
    with pytest.raises(ValidationError):
        LeadSubmission(
            name="Trevor Santos",
            email="trevor@example.com",
            message="Hi",
        )


def test_rejects_short_name():
    with pytest.raises(ValidationError):
        LeadSubmission(
            name="T",
            email="trevor@example.com",
            message="I need more information.",
        )