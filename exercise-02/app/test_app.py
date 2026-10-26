import pytest
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_index_returns_200_and_message(client):
    r = client.get("/")
    assert r.status_code == 200
    assert "message" in r.get_json()


def test_health_returns_healthy(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json() == {"status": "healthy"}


def test_unknown_route_returns_404(client):
    assert client.get("/does-not-exist").status_code == 404
