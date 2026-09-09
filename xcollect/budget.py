"""Hard spend ceiling, enforced in code.

A dashboard you have to remember to check is not a budget. Every provider call
goes through `BudgetGuard.charge`, which records the spend immediately rather
than at the end of the run: a crash mid-run must not lose the record of money
already spent, or the next run starts from an under-reported total and the
ceiling stops meaning anything.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .models import Page
from .store import Store


class BudgetExceeded(RuntimeError):
    """The monthly ceiling is reached. Not a failure: the collector treats it
    as a clean stop and records the run as 'capped'."""


@dataclass
class BudgetGuard:
    store: Store
    provider: str
    ceiling_usd: float
    dry_run: bool = False
    #: Totals for this run only, for the run summary.
    calls: int = field(default=0, init=False)
    billed_units: float = field(default=0.0, init=False)
    cost_usd: float = field(default=0.0, init=False)

    def __post_init__(self) -> None:
        self.month_total_usd = self.store.month_spend()

    @property
    def remaining_usd(self) -> float:
        return max(0.0, self.ceiling_usd - self.month_total_usd)

    def check(self, *, headroom_usd: float = 0.0) -> None:
        """Raise if we are at, or within `headroom_usd` of, the ceiling.

        `headroom_usd` lets a caller refuse to start a call it already knows it
        cannot afford, instead of discovering that after being billed for it.
        """
        if self.month_total_usd + headroom_usd >= self.ceiling_usd:
            raise BudgetExceeded(
                f"monthly ceiling ${self.ceiling_usd:.2f} reached "
                f"(spent ${self.month_total_usd:.4f} this month)"
            )

    def charge(self, page: Page) -> None:
        self.calls += 1
        self.billed_units += page.billed_units
        self.cost_usd += page.cost_usd
        self.month_total_usd += page.cost_usd
        if not self.dry_run:
            self.store.record_spend(
                self.provider,
                calls=1,
                billed_units=page.billed_units,
                cost_usd=page.cost_usd,
            )
