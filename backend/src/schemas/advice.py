"""
Advice card schema for /workout/advice endpoint.
Plan v5 + AI suggestion phase.

- Pure rule-based response (no external AI)
- Personalized from user inputs (body weight, age, goal, etc.)
- Each card carries evidence_refs to be displayed via Flutter assets
"""
from __future__ import annotations

from enum import Enum
from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class AdviceCategory(str, Enum):
    PROTEIN_INTAKE     = "protein_intake"
    FAT_BALANCE        = "fat_balance"
    CAFFEINE_TIMING    = "caffeine_timing"
    REST_INTERVAL      = "rest_interval"
    EQUIPMENT_GUIDANCE = "equipment_guidance"
    BIG3_PROGRESSION   = "big3_progression"
    VOLUME_TARGET      = "volume_target"
    SAFETY_NOTE        = "safety_note"
    INJURY_CARE        = "injury_care"
    WEIGHT_LOSS_DIET   = "weight_loss_diet"
    MUSCLE_GROUP_FOCUS = "muscle_group_focus"
    SESSION_TREND      = "session_trend"


class AdviceSeverity(str, Enum):
    INFO    = "info"
    TIP     = "tip"
    WARNING = "warning"


class AdviceCard(BaseModel):
    card_id: str = Field(...)
    category: AdviceCategory = Field(...)
    title: str = Field(...)
    body: str = Field(...)
    numeric_targets: Dict[str, float] = Field(default_factory=dict)
    evidence_refs: List[str] = Field(default_factory=list)
    severity: AdviceSeverity = Field(AdviceSeverity.INFO)


class AdviceResponse(BaseModel):
    success: bool = Field(...)
    cards: List[AdviceCard] = Field(default_factory=list)
    external_ai_used: bool = Field(False)
    error_message: Optional[str] = Field(None)
