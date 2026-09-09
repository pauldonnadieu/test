import pytest

from xcollect import providers
from xcollect.providers.base import ProviderError, ResponseShapeError
from xcollect.providers.twitterapi_io import TwitterApiIo, _parse_created_at
from xcollect.providers.twitterapis_com import TwitterApisCom

TWEET = {
    "id": "1800000000000000001",
    "text": "hello",
    "createdAt": "Wed Sep 09 11:22:33 +0000 2026",
    "likeCount": 42,
    "retweetCount": 7,
    "viewCount": "900",
    "lang": "en",
    "author": {"userName": "nasa", "id": "11348282"},
}


def test_io_maps_native_x_timestamp_format():
    tweet = TwitterApiIo("k")._map(TWEET)
    assert tweet.author_handle == "nasa"
    assert tweet.like_count == 42
    assert tweet.view_count == 900
    assert tweet.created_at.year == 2026
    assert tweet.url == "https://x.com/nasa/status/1800000000000000001"


def test_io_tolerates_missing_counts():
    tweet = TwitterApiIo("k")._map({"id": "1", "author": {"userName": "a"}})
    assert tweet.like_count == 0
    assert tweet.view_count is None


def test_io_rejects_a_tweet_with_no_id_loudly():
    with pytest.raises(ResponseShapeError):
        TwitterApiIo("k")._map({"text": "no id here"})


@pytest.mark.parametrize("value", ["Wed Sep 09 11:22:33 +0000 2026",
                                   "2026-09-09T11:22:33Z", 1788000000, None, "nonsense"])
def test_timestamp_parsing_never_raises(value):
    assert _parse_created_at(value).tzinfo is not None


def test_com_accepts_alternative_field_spellings():
    """The com adapter's mapping is provisional, so it is deliberately tolerant."""
    tweet = TwitterApisCom("k")._map({
        "id_str": "1800000000000000002",
        "full_text": "hi",
        "created_at": "2026-09-09T11:22:33Z",
        "favorite_count": 5,
        "user": {"screen_name": "esa", "id_str": "9"},
    })
    assert tweet.id == "1800000000000000002"
    assert tweet.author_handle == "esa"
    assert tweet.like_count == 5


def test_com_says_exactly_what_to_fix_when_the_shape_is_wrong(monkeypatch):
    provider = TwitterApisCom("k")
    monkeypatch.setattr(provider, "_get", lambda *a, **k: {"unexpected": {"nested": []}})
    with pytest.raises(ResponseShapeError, match="probe"):
        provider.search("from:nasa")


def test_com_finds_tweets_under_any_known_container_key(monkeypatch):
    provider = TwitterApisCom("k")
    monkeypatch.setattr(provider, "_get", lambda *a, **k: {
        "data": [{"id": "1", "user": {"screen_name": "nasa"}}], "nextCursor": "abc",
    })
    page = provider.search("from:nasa")
    assert len(page.tweets) == 1
    assert page.next_cursor == "abc"


def test_com_bills_per_call_regardless_of_result_count(monkeypatch):
    """The whole reason this adapter exists: an empty page still costs a call."""
    provider = TwitterApisCom("k")
    monkeypatch.setattr(provider, "_get", lambda *a, **k: {"tweets": []})
    empty = provider.search("from:nasa")
    monkeypatch.setattr(provider, "_get", lambda *a, **k: {
        "tweets": [{"id": str(i), "user": {"screen_name": "n"}} for i in range(20)]
    })
    full = provider.search("from:nasa")

    assert empty.cost_usd == full.cost_usd
    assert empty.billed_units == full.billed_units == 1.0


def test_io_bills_per_tweet_so_an_empty_poll_is_free(monkeypatch):
    provider = TwitterApiIo("k")
    monkeypatch.setattr(provider, "_get", lambda *a, **k: {"tweets": [], "has_next_page": False})
    page = provider.search("from:nasa")

    assert page.cost_usd == 0.0
    assert page.next_cursor is None


def test_io_ignores_a_cursor_when_there_is_no_next_page(monkeypatch):
    provider = TwitterApiIo("k")
    monkeypatch.setattr(provider, "_get", lambda *a, **k: {
        "tweets": [TWEET], "has_next_page": False, "next_cursor": "stale",
    })
    assert provider.search("q").next_cursor is None


def test_missing_api_key_is_a_clear_error(monkeypatch):
    for name in ("TWITTERAPI_IO_KEY", "XCOLLECT_API_KEY"):
        monkeypatch.delenv(name, raising=False)
    with pytest.raises(ProviderError, match="TWITTERAPI_IO_KEY"):
        providers.build("twitterapi_io")


def test_unknown_provider_lists_the_valid_ones():
    with pytest.raises(ProviderError, match="twitterapi_io"):
        providers.build("nope")


def test_registry_env_lookup(monkeypatch):
    monkeypatch.setenv("TWITTERAPI_IO_KEY", "secret")
    assert providers.build("twitterapi_io").api_key == "secret"
