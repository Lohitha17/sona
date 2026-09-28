import os
import tempfile

os.environ["AUREUM_DATA"] = tempfile.mkdtemp(prefix="aureum-test-")
os.environ["AUREUM_SEED"] = "0"

import pytest

from aureum_api.db import connect, init_db


@pytest.fixture(autouse=True)
def clean_db():
    init_db()
    with connect() as conn:
        conn.execute("DELETE FROM pieces")
        conn.execute(
            "UPDATE settings SET currency = 'INR', gold_rate_24k = 9860, updated_at = 'test'"
        )
        conn.commit()
