"""
Rest Engine — Input Validators
Validates DutyInput before passing to the engine.
Returns clear error messages for bad inputs.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from .calculator import DutyInput
from .timezone_utils import duration_minutes


@dataclass
class ValidationResult:
    is_valid: bool
    errors:   list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


class DutyInputValidator:

    MAX_DUTY_HOURS         = 20
    MAX_LEGS               = 12
    MAX_CARRY_OVER_HOURS   = 100.0
    MIN_DUTY_HOURS         = 0.25   # 15 minutes minimum

    def validate(self, inp: DutyInput) -> ValidationResult:
        errors:   list[str] = []
        warnings: list[str] = []

        # Datetime order
        if inp.duty_end_utc <= inp.duty_start_utc:
            errors.append(
                "duty_end_utc must be after duty_start_utc. "
                f"Got start={inp.duty_start_utc.isoformat()}, "
                f"end={inp.duty_end_utc.isoformat()}"
            )
        else:
            duty_mins = duration_minutes(inp.duty_start_utc, inp.duty_end_utc)
            if duty_mins < self.MIN_DUTY_HOURS * 60:
                warnings.append(
                    f"Duty period is very short ({duty_mins} minutes). "
                    "Verify inputs."
                )
            if duty_mins > self.MAX_DUTY_HOURS * 60:
                errors.append(
                    f"Duty period of {duty_mins} minutes exceeds "
                    f"the maximum plausible value of "
                    f"{self.MAX_DUTY_HOURS * 60} minutes. "
                    "Verify inputs."
                )

        # Next duty ordering
        if inp.next_duty_start_utc:
            if inp.next_duty_start_utc < inp.duty_end_utc:
                errors.append(
                    "next_duty_start_utc must be after duty_end_utc. "
                    "Rest period cannot be negative."
                )

        # Leg counts
        if inp.num_operating_legs < 0:
            errors.append("num_operating_legs cannot be negative.")
        if inp.num_operating_legs > self.MAX_LEGS:
            warnings.append(
                f"num_operating_legs={inp.num_operating_legs} is unusually high. "
                "Verify."
            )
        if inp.num_deadhead_legs < 0:
            errors.append("num_deadhead_legs cannot be negative.")

        # Report hour
        if not 0 <= inp.report_local_hour <= 23:
            errors.append(
                f"report_local_hour must be 0–23. Got {inp.report_local_hour}."
            )

        # Block minutes
        if inp.block_minutes < 0:
            errors.append("block_minutes cannot be negative.")

        # Carry-over
        if inp.carry_over_hours < 0:
            errors.append("carry_over_hours cannot be negative.")
        if inp.carry_over_hours > self.MAX_CARRY_OVER_HOURS:
            warnings.append(
                f"carry_over_hours={inp.carry_over_hours:.1f} is unusually high. "
                "Verify."
            )

        return ValidationResult(
            is_valid = len(errors) == 0,
            errors   = errors,
            warnings = warnings,
        )
