"""Provider adapters. Add one here and it becomes selectable from config."""

from __future__ import annotations

from .base import Provider, ProviderError, ResponseShapeError, env_key
from .twitterapi_io import TwitterApiIo
from .twitterapis_com import TwitterApisCom

# Each entry maps a provider name to its class and the env vars its key can
# live in. Adding a provider is a two-line change here plus one new module.
REGISTRY: dict[str, tuple[type[Provider], tuple[str, ...]]] = {
    TwitterApiIo.name: (TwitterApiIo, ("TWITTERAPI_IO_KEY", "XCOLLECT_API_KEY")),
    TwitterApisCom.name: (TwitterApisCom, ("TWITTERAPIS_COM_KEY", "XCOLLECT_API_KEY")),
}


def build(name: str) -> Provider:
    try:
        cls, env_names = REGISTRY[name]
    except KeyError:
        raise ProviderError(
            f"unknown provider {name!r}; available: {', '.join(sorted(REGISTRY))}"
        ) from None
    key = env_key(*env_names)
    if not key:
        raise ProviderError(
            f"{name}: set one of {', '.join(env_names)} in the environment"
        )
    return cls(key)


__all__ = ["Provider", "ProviderError", "ResponseShapeError", "REGISTRY", "build"]
