import pytest

from xcollect.config import (
    AccountsConfig, Config, ConfigError, TopicConfig,
    accounts_query, batch_handles, topic_query,
)


def test_handles_are_normalised_and_at_stripped():
    config = Config.from_dict({"accounts": {"handles": ["@nasa", " esa ", ""]}})
    assert config.accounts.handles == ["nasa", "esa"]


def test_unknown_option_is_a_clear_error_not_a_typeerror():
    with pytest.raises(ConfigError, match="unknown option"):
        Config.from_dict({"accounts": {"handles": ["nasa"], "cadence_hrs": 1}})


def test_empty_config_is_rejected():
    with pytest.raises(ConfigError, match="nothing to collect"):
        Config.from_dict({})


def test_topic_without_keywords_is_rejected():
    with pytest.raises(ConfigError, match="at least one keyword"):
        Config.from_dict({"topics": [{"name": "x", "keywords": []}]})


def test_batching_respects_both_count_and_length_caps():
    handles = [f"account{i:03d}" for i in range(45)]
    batches = batch_handles(handles, per_batch=20, max_chars=480)
    assert sum(len(b) for b in batches) == 45
    assert all(len(b) <= 20 for b in batches)
    for batch in batches:
        assert len(accounts_query(batch, 0, AccountsConfig())) < 512


def test_long_handles_force_smaller_batches():
    handles = ["a" * 40 for _ in range(20)]
    batches = batch_handles(handles, per_batch=20, max_chars=200)
    assert len(batches) > 1


def test_account_query_shape():
    query = accounts_query(["nasa", "esa"], 1757400000, AccountsConfig())
    assert query.startswith("(from:nasa OR from:esa)")
    assert "since_time:1757400000" in query
    assert "-filter:replies" in query
    assert "-filter:nativeretweets" in query


def test_multiword_keywords_are_quoted_once():
    topic = TopicConfig(name="t", keywords=['AI safety', '"already quoted"', "llm"], min_faves=300)
    query = topic_query(topic, 1757400000)
    assert '"AI safety"' in query
    assert '""already quoted""' not in query
    assert "min_faves:300" in query


def test_min_faves_omitted_when_zero():
    topic = TopicConfig(name="t", keywords=["llm"], min_faves=0)
    assert "min_faves" not in topic_query(topic, 0)
