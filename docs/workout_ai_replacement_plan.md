# 筋トレメニュー提案 ルールベース化＋論文ベース最適化 計画書（v5 確定版）

作成日: 2026-04-29 / 改訂: 2026-04-29（v5）
対象: `muscle-mate-app`（FastAPI + Flutter 構成）
提出先想定: Apple App Store / Google Play
作成者: Muscle Mate Tech Team

---

## 改訂履歴

| 版 | 主な変更 |
| --- | --- |
| v1 | Gemini → Groq 等の代替案。RAG 概念。 |
| v2 | 既定をルールベース単独へ。外部 AI を任意機能化。`/workout/next` のステートレス化。論文ライセンス厳格化。 |
| v3 | 外部 AI 送信ホワイトリストを 6 フィールドに統一。Privacy Details 三層分離。永続化禁止の実装要件。サーバー側二重ガード。KPI 再定義（審査通過は除外）。医療 UI 仕様。Ollama を本番初期対象外。 |
| v4 | `exercise_names` 間接漏えい対策、インフラメタデータ開示、同意撤回の意味論、ZDR 運用記録扱い、`APP_ENV` 分岐、レスポンス型拡張、カナリア値検査、Privacy Details 保守的分類、RAG 段階導入、Groq 課金保護。 |
| **v5（本書・実装着手版）** | **課金モードを `EXTERNAL_AI_BILLING_MODE` で明示分離**（`free_only`／`paid_capped`）。`MAX_EXTERNAL_AI_CALLS_PER_MONTH=0` の曖昧解釈を排除。**`/workout/next` は外部 AI を呼ばないことを明記**（`should_call_external_ai` の入口で `endpoint == "next"` なら早期 false）。**v3 期の表記ゆれを除去**: §8.1 の `ALLOWED_ORIGINS` 無条件起動失敗を `APP_ENV` 分岐に修正、§13 フェーズ 3 を「静的辞書から開始、必要時のみ FAISS」に再整列。 |

---

## 1. 背景と目的

### 1.1 元の課題
`backend/src/services/gemini_service.py` の Gemini 呼び出しに恒常的に課金が発生する。

### 1.2 v3 で固定する目的
- **第一目的: 有料 API 依存の廃止**。Gemini を恒常運用から外す。
- **第二目的: 外部 AI 依存そのものの最小化**。AI 推論は**任意の付加機能**。コアは端末／サーバー上のルールベース。
- **第三目的: App Store / Google Play の審査・プライバシー要件への完全準拠**。健康データを扱う以上、第三者 AI への送信は**最小限・明示同意済み・撤回可能・サーバー側で二重ガード**。
- **第四目的: 筋肥大・BIG3 強化のエビデンスベース化**。オープンアクセス論文の自作要約を**サーバー内**で参照（外部 AI へは渡さない、Flutter にも本文同梱しない）。

### 1.3 v3 から v4 への追加変更点
| 項目 | v3 | v4（本書） |
| --- | --- | --- |
| `exercise_names` 間接漏えい | 6 フィールドの 1 つとして送信可 | **痛み／怪我／`notes`／`target_muscles`／`priority_lift` が入力されたリクエストでは外部 AI 自動スキップ** |
| インフラメタデータ（IP 等） | ポリシー記載なし | **CDN/WAF/ホスティング事業者によるセキュリティ目的の処理が起こり得る旨を明記** |
| 同意撤回の意味論 | 「以後オフ」とのみ | **「以後の送信停止であり、第三者へ送信済みデータの遡及削除を保証しない」と明記** |
| ZDR | `GROQ_ZDR_ENABLED` 環境変数 | **環境変数は自己申告メモ。実設定は Groq 組織側。運用記録（`docs/operational_records.md`）で確認** |
| `ALLOWED_ORIGINS` | 未設定で常に起動失敗 | **`APP_ENV=production` 時のみ起動失敗。開発は `http://localhost:*` 既定** |
| レスポンス型 | `plan: null` を §9.2 で導入したのみ | **`WorkoutResponse` を拡張し、`advisory`／`safety_flags` をトップレベルに正式定義。Flutter 分岐仕様を §6.3／§9.2 に明記** |
| ログ漏えい検査 | 禁止フィールド名一致で検査 | **カナリア値（`notes="DO_NOT_LOG_SECRET_<request_id>"` 等）を CI で注入し、ログ／APM／エラー応答に出ないことを検査** |
| Privacy Details の `injury_history`／痛み | Health & Fitness | **保守的に Sensitive Info 相当としても申告候補に挙げる**（最終決定は提出時に公式選択肢で確定） |
| RAG | フェーズ 3 で FAISS | **静的辞書検索（メタデータ＋キーワード）から開始 → 必要時に FAISS 昇格**。Docker build 検証を追加 |
| Groq 課金 | 「月額 ¥0 KPI」 | **支払情報を登録しない Free 運用を既定**。やむを得ず有料化する場合は月額ハードキャップ設定 + サーバー側 `MAX_EXTERNAL_AI_CALLS_PER_MIN` で超過時 noop |

---

## 2. 現状アーキテクチャの整理（再掲・短縮）

| 層 | ファイル | 現状 |
| --- | --- | --- |
| ルーター | `backend/src/routers/workout.py` | `POST /workout/generate` を Gemini に委譲 |
| サービス | `backend/src/services/gemini_service.py` | **削除対象** |
| スキーマ | `backend/src/schemas/workout.py` | 拡張対象 |
| エントリ | `backend/main.py` | `ALLOWED_ORIGINS="*"` フォールバック → **削除対象** |
| Flutter モデル | `frontend/lib/models/workout_plan.dart` | 拡張対象 |
| 同意 | `frontend/lib/screens/consent_screen.dart` | 文言改訂対象 |
| ポリシー | `frontend/lib/screens/privacy_policy_screen.dart` | 全面差し替え対象 |

---

## 3. 推論基盤の方針（v3 確定）

### 3.1 既定構成: ルールベース単独
```
[Flutter]
   │ 入力（必要最小限・サーバー保存なし）
   ▼
[FastAPI / rule_engine_service]
   │ 決定論的にメニュー生成
   ▼
[Flutter] レスポンス
```
すべての利用シーンで、外部 AI が一切無くても完結する。

### 3.2 任意構成: 外部 AI 文章補強（既定オフ）
- 同意トグルが ON かつサーバー側 `LLM_PROVIDER` が `groq` の時のみ、**§7 の 6 フィールド**を Groq に送信。
- 用途は `coaching_point` `general_advice` の文章補強のみ。スケルトン構造は LLM では変更しない。
- 失敗時はルール結果がそのまま返る。

### 3.3 候補と採否
| # | 候補 | 採否 | 用途 |
| --- | --- | --- | --- |
| A | ルール単独 | **採用（既定）** | コア |
| B | Groq Free（OpenAI 互換 JSON） | **任意採用**（同意時のみ・本番版） | 文章補強 |
| C | **Ollama**（ローカル） | **本番初期対象外**。開発／セルフホスト用ドキュメントとして残す | — |
| D | HF Inference / Gemini | **不採用** | — |

> **Ollama の位置づけ**: モバイル App 内で動作させるわけではない。バックエンドサーバー側のセルフホスト LLM の選択肢として残すのみ。本番 App Store 提出版は `LLM_PROVIDER=noop` または `groq` のみを想定。Ollama 利用は OSS 配布物のドキュメントとして README に記載する。

### 3.4 段階的廃止
- フェーズ 1 終了時に `gemini_service.py` を削除、`requirements.txt` から `google-generativeai` を除外。

---

## 4. 機能要件

### 4.1 初回メニュー提案
入力フィールドは v2 と同じ。**ただし「外部 AI 送信」列は §7 の確定ホワイトリストと一致させる**。本表は §7 / §10 / §12 / 付録 C と同一の真実源。

| フィールド | 既存/新規 | 端末保存 | サーバー一時処理 | サーバー永続保存 | **外部 AI 送信** |
| --- | --- | --- | --- | --- | --- |
| `goal` | 既存 | ○ | ○ | × | **○** |
| `level` | 既存 | ○ | ○ | × | **○** |
| `days_per_week` | 既存 | ○ | ○ | × | **○** |
| `session_duration_minutes` | 既存 | ○ | ○ | × | **○** |
| `equipment` | 既存 | ○ | ○ | × | **○** |
| 生成済 `exercise_names` | 派生 | ○ | ○ | × | **○** |
| `target_muscles` | 既存 | ○ | ○ | × | **×** |
| `big3_max`（数値） | 既存 | ○ | ○ | × | **×** |
| `priority_lift` | 新規（任意） | ○ | ○ | × | **×** |
| `years_of_training` | 新規（任意） | ○ | ○ | × | **×** |
| `age` | 既存 | ○ | ○ | × | **×** |
| `gender` | 新規（任意） | ○ | ○ | × | **×** |
| `body_weight_kg` | 新規（任意） | ○ | ○ | × | **×** |
| `injury_history` | 新規（任意） | ○ | ○ | × | **×** |
| `notes`（自由記述） | 既存 | ○ | ○ | × | **×** |
| 痛み・RPE・実施重量 | 新規 | ○ | ○ | × | **×** |

> v2 で見られた章間の不一致（`big3_max`, `priority_lift`, `years_of_training`, `target_muscles` を一部章で送信可としていた）を**廃止**。文章補強に必要十分な 6 フィールドへ最小化する。

処理フロー:
1. **特性プロファイラ**（純ロジック）でスプリット種別を選択。
2. `knowledge/programs/` の自作雛形を取得（サーバー内）。
3. ルールエンジンが種目・セット・レップ・休息・重量を埋める。
4. 同意フラグ ON かつサーバー側 `LLM_PROVIDER=groq` の時のみ、**§7 の 6 フィールドだけ** allowlist 経由で送信し、`coaching_point` / `general_advice` の文章を上書き。
5. リクエスト・レスポンスは**永続化しない**（§11）。

### 4.2 記録ベースの次回最適化（ステートレス・サーバー保存なし）
新エンドポイント `POST /workout/next` は **`user_id` を持たない**。

入力（端末から都度送信）:
- 直近の `SessionLog`（種目ごとの実施重量・実施レップ・RPE・痛み有無）
- 次に生成したい曜日・セッション ID

サーバー処理:
- 受信 → `progression_service` で純関数として最適化計算 → レスポンス返却。
- リクエスト本文を**ログ・APM・DB・キャッシュ**に書かない（§11.4）。

最適化ルール:
| シグナル | アクション |
| --- | --- |
| 全セット規定上限達成 & RPE ≤ 8 | コンパウンド +2.5kg / アイソ +1.0kg |
| 規定下回り | 同重量で再挑戦 |
| RPE ≥ 9 が連続 2 セッション | デロード（重量 -10%、ボリューム -30%） |
| **痛み有** | §9 の医療 UI フローへ（自動代替なし） |
| 4 週連続停滞 | 周期化雛形へ切替 |
| **増量幅ハードキャップ** | コンパウンド +5kg、アイソ +2kg／セッション |

### 4.3 論文ベース提案（サーバー内完結）
- ルールエンジンが `knowledge/summaries/` を**サーバー内で**参照。
- **論文要約本文は外部 AI へは送らない**。**Flutter にも要約本文を同梱しない**。
- レスポンスには `evidence_refs: List[str]`（要約 ID）を含める。
- Flutter には `assets/evidence_index.json`（**ID／タイトル／著者／年／DOI／自作短文サマリのみ**、`license` 列で OA 確認済みのもの）を同梱。INDEX.md 全文や本文サマリは含めない。

### 4.4 外部 AI 自動スキップ条件（v4 で追加・間接漏えい対策）

`exercise_names` 単体は §7 のホワイトリストに含まれるが、**痛み・怪我・自由記述・部位指定・優先種目** が入力されたリクエストでは、生成済み種目名一覧から「胸重点」「腰痛配慮」「下半身回避」等のセンシティブ属性が**間接的に推測**される懸念がある。これを避けるため、以下のいずれかに該当する場合は**外部 AI 補強を自動スキップ**し、ルールベースの結果のみを返す（同意トグル ON でも）。

スキップ条件（OR・サーバー側で判定）:
- `WorkoutRequest.injury_history` が空でない
- `WorkoutRequest.notes` が空でない
- `WorkoutRequest.target_muscles` が指定されている
- `WorkoutRequest.priority_lift` が `none` 以外で指定されている
- 直前の `SessionLog`（`/workout/next` 経由）で `pain == true` のセットが 1 つでもある
- 生成された `WorkoutPlan` の `safety_flags` が空でない

スキップ時の挙動:
- レスポンスに `external_ai_used: false` フラグを含める。
- Flutter は「今回の入力は本人推測リスクがあるため、外部 AI 補強をスキップしました」のヒントを **任意機能トグル ON のユーザーに対してのみ** 設定画面で過去履歴として確認できるようにする（ユーザーが意図せずスキップに気付かないと混乱するため）。

実装は `should_call_external_ai()`（§6.3）の判定式に AND 条件として追加する。

---

## 5. 論文ナレッジベースの構成（v2 を継承、配布物を厳格化）

### 5.1 取り扱い対象
- 収録可: オープンアクセス（CC-BY 等）の査読論文 PDF、PubMed/DOI のメタデータ、自作の二次著作物としての要約マークダウン。
- 収録不可: 商業書籍 PDF、許諾未確認 PDF、サブスクリプション論文の本文 PDF。

### 5.2 ディレクトリ構造
```
muscle-mate-app/
├── knowledge/
│   ├── papers/                       # OA論文PDF。リポジトリ外
│   │   └── .gitkeep                  # ディレクトリのみ管理
│   ├── summaries/                    # 自作要約MD（サーバー内利用）
│   ├── programs/                     # 自作雛形（商業名なし）
│   ├── glossary.md
│   ├── INDEX.md                      # サーバー内インデックス
│   └── LICENSES.md                   # ライセンス管理
└── frontend/assets/
    └── evidence_index.json           # ID/title/authors/year/doi/short_summary_ja のみ
```

`.gitignore` に以下を**明記**:
```
# 論文 PDF はリポジトリに含めない
knowledge/papers/**/*.pdf
knowledge/papers/**/*.PDF
```
（`knowledge/papers/.gitkeep` のみコミット可）

### 5.3 要約マークダウンテンプレート（変更なし）
v2 §5.3 と同じ。`license` `review_status` `reviewer` を必須化。

### 5.4 配布物の制限
Flutter に同梱できるのは `assets/evidence_index.json` のみで、各エントリは以下のフィールドに限定:
```json
{
  "evidence_id": "schoenfeld_2017_volume",
  "title": "...",
  "authors": ["..."],
  "year": 2017,
  "doi": "10.xxxx/...",
  "license": "CC-BY-4.0",
  "source_url": "https://...",
  "short_summary_ja": "週10セット以上で筋肥大効果が大きい（自作要約・40字以内）"
}
```
要約マークダウン本文や §2「定量的知見」の生数値はアプリに同梱しない。詳細はオプションで `source_url` を端末ブラウザで開く設計とする。

### 5.5 運用フロー（変更なし）
v2 §5.5 と同じ。`human_reviewed` のみインデックス化。

---

## 6. システム設計

### 6.1 新規・変更コンポーネント
v2 §6.1 を継承。差分:
- `frontend/lib/services/api_service.dart` は同意ヘッダ送信に加え、サーバー側で**ヘッダ単独で外部 AI を呼ばない**契約に対応（§6.3）。
- `frontend/assets/evidence_index.json` を新規（§5.4）。

### 6.2 推論パイプライン（v3 確定）
```
[Flutter] POST /workout/generate
    │ X-External-AI-Optin: true|false（同意トグルの値）
    ▼
[backend] Pydantic で WorkoutRequest 検証
    ▼
rule_engine_service.build_plan(req)   # 全フィールドはサーバー内のみで参照
    │  ├ rag_service.retrieve(...)     # サーバー内のみ
    │  └ INTENSITY_TABLE & BIG3 重量算出
    ▼
（任意 AI 補強の二重ガード判定）
    │  IF env LLM_PROVIDER == "groq"
    │  AND header X-External-AI-Optin == "true"
    │  AND payload allowlist 構築成功（不可フィールドが含まれていれば構築失敗）
    │  THEN llm_service.enrich(allowlisted_payload)
    │  ELSE skip
    ▼
Pydantic validate → WorkoutResponse
    ▼
[Flutter] 表示・端末内保存
[backend] リクエスト/レスポンス本文・派生データを永続化しない（§11.4）
```

`allowlisted_payload` に含まれるフィールドは **§7 の 6 フィールドのみ**。それ以外を含めると `llm_service` 入口の Pydantic モデルがバリデーションエラーで弾く（コードレベルの強制）。

### 6.3 LLM 抽象化レイヤ（サーバー側多重ガード・v4）
```python
# 擬似コード
class AllowlistedLLMPayload(BaseModel):
    """外部AI送信payload。送信可フィールドのみ列挙。extra=forbid で禁止フィールド混入を物理的に防止。"""
    model_config = ConfigDict(extra="forbid")

    goal: Goal
    level: Level
    equipment: List[Equipment]
    days_per_week: int
    session_duration_minutes: int
    exercise_names: List[str]

class LLMClient(Protocol):
    async def enrich_text(self, payload: AllowlistedLLMPayload) -> dict: ...

def should_call_external_ai(
    endpoint: Literal["generate", "next"],
    req: WorkoutRequest,
    plan: WorkoutPlan,
    session_log: Optional[SessionLog],
    req_headers,
    runtime_state,
) -> bool:
    # (0) /workout/next は外部 AI を呼ばない（v5 で明文化）
    #     セッションログ自体が痛み・RPE・実施重量を含むセンシティブ情報のため、
    #     たとえ allowlist が 6 フィールドであっても /next 経路では一切呼ばない。
    if endpoint == "next":
        return False
    # (1) 環境変数: noop なら絶対呼ばない
    if os.environ.get("LLM_PROVIDER", "noop") != "groq":
        return False
    # (2) クライアント同意ヘッダ
    if req_headers.get("X-External-AI-Optin") != "true":
        return False
    # (3) 間接漏えい防止スキップ（§4.4）
    if req.injury_history or req.notes or req.target_muscles:
        return False
    if req.priority_lift and req.priority_lift != "none":
        return False
    if plan.safety_flags:                  # 痛み・サスペンド等
        return False
    if session_log is not None:            # 念のため: 直前ログがあれば呼ばない
        return False
    # (4) サーバー側コール上限（無料枠保護・課金保護）
    if runtime_state.external_ai_calls_this_minute >= int(os.environ["MAX_EXTERNAL_AI_CALLS_PER_MIN"]):
        return False
    # (5) 課金モード（v5 で明示分離）
    if os.environ.get("EXTERNAL_AI_BILLING_MODE", "free_only") == "paid_capped":
        if runtime_state.external_ai_calls_this_month >= int(os.environ["MAX_EXTERNAL_AI_CALLS_PER_MONTH"]):
            return False
    # free_only モードでは月次カウンタを参照しない（Groq 側支払情報未登録で物理的に課金不可）
    return True

def build_allowlisted_payload(req, plan) -> AllowlistedLLMPayload:
    # extra=forbid により、req のフィールドを丸ごと渡すと例外
    return AllowlistedLLMPayload(
        goal=req.goal,
        level=req.level,
        equipment=req.equipment,
        days_per_week=req.days_per_week,
        session_duration_minutes=req.session_duration_minutes,
        exercise_names=[ex.name_ja for d in plan.weekly_schedule for ex in d.exercises],
    )
```
- `LLM_PROVIDER=noop`（既定）では**コードパスとして外部呼び出しが存在しない**（`NoOpClient` が常時 no-op）。
- ヘッダ単独で呼ばれることは構造上不可能（環境変数 AND ヘッダ AND 間接漏えい条件 AND コール上限の AND 条件）。
- `extra="forbid"` により、誤って禁止フィールドを混ぜたコードはユニットテストで即落ちる。
- `runtime_state.external_ai_calls_this_minute` の管理はサーバープロセスローカル（Redis 等の外部依存なし）。

### 6.4 レスポンス型の拡張（v4 で正式化）

既存 `WorkoutResponse` は `success: bool / plan: Optional / error_message: Optional` のみ。これに**`advisory` と `safety_flags` をトップレベルで追加**し、Flutter 側の分岐仕様を確定させる。

```python
class AdvisoryLevel(str, Enum):
    NONE          = "none"
    PARTIAL_SKIP  = "partial_skip"        # 該当部位の種目だけ除外
    REST_OR_CONSULT = "rest_or_consult"   # 当日中止＋専門家相談
    DELOAD        = "deload"              # 強制デロード提案

class Advisory(BaseModel):
    level: AdvisoryLevel
    title: Optional[str] = None
    body: Optional[str] = None
    actions: List[str] = Field(default_factory=list)  # 例: ["rest", "mobility_easy", "consult_pro"]

class WorkoutResponse(BaseModel):
    success: bool
    plan: Optional[WorkoutPlan] = None
    safety_flags: List[str] = Field(default_factory=list)
    advisory: Advisory = Field(default_factory=lambda: Advisory(level=AdvisoryLevel.NONE))
    external_ai_used: bool = False
    error_message: Optional[str] = None
```

Flutter 分岐仕様（`workout_result_screen.dart`／`workout_session_screen.dart` の挙動）:
1. `success == false` → エラーバナー表示。
2. `success == true` かつ `advisory.level == "rest_or_consult"` → **`plan` は無視し、休止モーダル**（OK しないと進めない）。
3. `success == true` かつ `advisory.level == "partial_skip"` → 警告バナー＋メニュー表示。
4. `success == true` かつ `advisory.level == "deload"` → デロード提案ダイアログ → ユーザー選択でメニュー表示。
5. `success == true` かつ `advisory.level == "none"` → 通常表示。
6. `external_ai_used` の表示は設定画面の履歴のみ（メニュー画面では表示しない、UX を散らかさないため）。

これにより v3 §9.2 で導入した `plan: null` のセマンティクスが**型として明示**され、既存 Flutter モデル（`workout_plan.dart`）の互換性も「`success=true => planあり` の暗黙仮定」を排除して安全に移行できる。

### 6.5 RAG（v4 で段階導入に変更）

**段階 A（フェーズ 3 前半・既定）: 静的辞書検索**
- `knowledge/summaries/*.md` のフロントマター（`tags`, `target_goals`, `target_lifts`, `evidence_level`）と `knowledge/INDEX.md` のキーワードのみで線形検索。
- 依存ライブラリ追加なし（FastAPI 内のみで完結）。
- Docker イメージサイズへの影響ゼロ。
- 8〜30 件規模の論文要約に対しては十分高速（<10ms）。

**段階 B（必要時のみ昇格）: FAISS + multilingual-e5-small**
- 段階 A で関連度が頭打ちになった、または論文数が増えた場合のみ昇格。
- 昇格判断基準: 論文要約 > 50 件 OR 段階 A の検索精度（ヒット率）が業務要件を下回る。
- 昇格時に **Docker build 検証**（Linux/amd64 と Linux/arm64 で sentence-transformers + FAISS のイメージサイズ・コールドスタートを計測）を必須タスクとしてフェーズ 3 後半に組み込む。
- 配布物制限（Flutter には `evidence_id` のみ）は段階 A／B 共通。

切替は環境変数 `RAG_BACKEND=static|faiss` で行い、既定は `static`。

### 6.6 プログレッション（純関数・変更なし）
v2 §6.5 と同じ。`SessionLog` は `user_id` を持たない。

---

## 7. 外部 AI 送信ホワイトリスト（**全章のシングルソース**）

**送信可（6 フィールドのみ）:**
- `goal`
- `level`
- `equipment`
- `days_per_week`
- `session_duration_minutes`
- `exercise_names`（生成済みスケルトンの種目名一覧）

**送信禁止（CI で検査）:**
- 個人属性: `age`, `gender`, `body_weight_kg`, `years_of_training`, `priority_lift`
- 健康・実績: `big3_max`, `target_muscles`, `injury_history`, `notes`, `pain`, `rpe`, `weight_kg`, `session_logs`
- 識別子: `user_id`, `email`, `device_id`, `ip`

**§4.1、§6.2、§10.3、§12、付録 C はすべて本表と一致させること**（差分が出たら本表を真と見なし他を直す）。

---

## 8. 既存コード差分

### 8.1 バックエンド
- `gemini_service.py` 削除、`requirements.txt` から `google-generativeai` 削除、`backend/scripts/test_gemini.py` 削除。
- `main.py` の `ALLOWED_ORIGINS` フォールバック `"*"` を**削除**。`APP_ENV=production` 時のみ未設定で起動失敗、`development` では `localhost` 既定（§11.2）。
- `workout.py`: `/generate` 差し替え、`/next` 新設、`/entertainment` 維持。
- `schemas/workout.py`: `Exercise` に `evidence_refs`, `safety_flags`, `progression_rule` を追加。`WorkoutRequest` に任意項目を追加。
- `schemas/log.py` 新規（`SetLog`/`ExerciseLog`/`SessionLog`、`user_id` 持たない）。
- `services/llm_service.py` 新規。`AllowlistedLLMPayload`（`extra="forbid"`）と二重ガード。
- 例外ハンドラ: FastAPI `RequestValidationError` を独自ハンドラで上書きし、**`exc.errors()` の `input` を返さない**（§11.4）。

### 8.2 フロントエンド
- `models/workout_plan.dart` に `evidenceRefs` `safetyFlags` `progressionRule` を追加。
- `models/session_log.dart` 新規（端末ローカル保存用）。
- `screens/consent_screen.dart` 文言改訂（§10.3）。
- `screens/settings_screen.dart` に「外部 AI 文章補強」トグル（既定オフ）。再同意ダイアログ。
- `screens/privacy_policy_screen.dart` 全面差し替え（§10.4）。
- `services/api_service.dart` で `X-External-AI-Optin` ヘッダ送信。**ただしサーバー側二重ガードがあるため、ヘッダ単独依存ではない**ことを実装コメントに明記。
- `assets/evidence_index.json` 新規同梱（§5.4 の限定スキーマ）。
- 痛み入力時の医療 UI（§9）。

### 8.3 削除予定
- `backend/scripts/test_gemini.py`
- `gemini_service.py`
- `requirements.txt` の `google-generativeai==0.8.4`

---

## 9. 安全性・医療表現（UI 仕様まで規定）

### 9.1 文言要件
- 「本アプリは情報提供を目的としたフィットネス支援であり、医療助言・診断・治療を提供するものではありません」
- 「痛みや違和感がある場合は運動を中止し、医療専門家にご相談ください」
- 「持病・術後・妊娠中・若年者は、運動開始前に主治医にご相談ください」

### 9.2 痛み入力時のロジック・UI（v3 で具体化）

`SessionLog` のいずれかの `SetLog.pain == true` を検出した場合のサーバー応答:

1. `safety_flags = ["pain_reported"]` を立てる。
2. **痛みの部位を含む種目を自動代替しない**。
3. **残りメニューが成立しない場合**（例: 当該部位が当日のメインなら、適切な代替を機械的に決められない）→ サーバーは以下のレスポンス形態を返す:
   ```json
   {
     "success": true,
     "plan": null,
     "safety_flags": ["pain_reported", "session_suspended"],
     "advisory": {
       "level": "rest_or_consult",
       "title": "今日はトレーニングを中止しましょう",
       "body": "痛みが報告されています。本日の該当部位のメニュー生成を中止します。軽い可動域運動と休養、必要に応じて医療専門家への相談をご検討ください。",
       "actions": ["rest", "mobility_easy", "consult_pro"]
     }
   }
   ```
4. **残りメニューが成立する場合**（例: 当日のメインが別部位）→ 該当部位の種目だけ除外し、`safety_flags = ["pain_reported", "partial_skip"]` を立て、`advisory.level = "partial_skip"` を返す。
5. Flutter は `safety_flags` に `pain_reported` が含まれていれば、メニュー表示前に **モーダル**を出す（OK しないと進めない）。モーダルには「中止」「軽い可動域・休養を見る」「専門家相談」の 3 ボタン。

### 9.3 高重量誘導の防止
- §4.2 のハードキャップ（コンパウンド +5kg／セッション、アイソ +2kg／セッション）。
- RPE ≥ 9 連続検知 → 強制デロード提案ダイアログ。

### 9.4 13 歳未満の扱い
- 同意画面で「**13 歳以上であることを自己申告するチェックボックス**」を必須化。**チェック状態は SharedPreferences に `age_gate_passed: bool` のみを保存し、年齢そのものは保存しない**。
- チェックなしで先に進めない。チェック後に取り消したい場合は「アカウントデータを削除」で全リセット可。
- これにより「年齢」を新たに収集する必要がなく、Privacy Details 上も年齢収集は発生しない（任意入力の `age` は別目的のフィットネス計算用で、UI 上「未入力で進めます」と明示）。

---

## 10. App Store / Google Play 対応（三層分離）

### 10.1 App Privacy Details（**端末内 / サーバー一時 / 第三者 AI** に分離）

> **注記**: App Store Connect の Data Type 選択肢は更新されることがある。本表は計画時点での申告候補であり、提出時に最新の選択肢で再確認する。`injury_history` と痛み情報は v3 では Health & Fitness のみとしていたが、**v4 では Sensitive Info 相当としても申告候補に挙げ、保守的に複数カテゴリで申告する**（最終決定は提出時の選択肢で確定）。

#### 10.1.1 端末内のみ（Apple ガイダンス上、collected ではない可能性が高い）
| Data Type | Notes |
| --- | --- |
| Health & Fitness（実施重量・レップ・RPE・痛み） | 端末内 SQLite。サーバーへ送らない場合あり。 |
| Personal Info（任意の age/gender/body_weight_kg/notes/injury_history） | 端末内 SharedPreferences。サーバー一時送信あり時は §10.1.2 に再掲。 |

#### 10.1.2 サーバー一時処理（**「Collected」として申告**。Linked to user: No、Used for tracking: No、Purpose: App Functionality）
| Data Type（v4 で保守的分類） | 送信される具体フィールド | 永続保存 |
| --- | --- | --- |
| Health & Fitness | `goal`, `level`, `equipment`, `days_per_week`, `session_duration_minutes`, `target_muscles`, `big3_max`（任意）, `priority_lift`（任意）, `years_of_training`（任意）, `body_weight_kg`（任意）, `SessionLog` 内の重量・レップ・RPE | **No**（§11.4 の実装で永続化しない） |
| Sensitive Info（保守的に申告） | `age`（任意）, `gender`（任意）, `notes`（任意）, **`injury_history`（任意）**, **`pain` フラグ** | **No** |
| Identifiers | アプリ独自の `user_id`/`email`/`device_id` は扱わない（§10.1.4 のインフラ側 IP 等を除く） | — |

#### 10.1.3 第三者 AI 送信（**ユーザー明示同意時かつ §4.4 の自動スキップ条件に該当しない時のみ・最小フィールドのみ**）
| Data Type | 送信フィールド | 第三者 | 用途 |
| --- | --- | --- | --- |
| Health & Fitness | `goal`, `level`, `equipment`, `days_per_week`, `session_duration_minutes`, `exercise_names` | Groq, Inc.（米国） | コーチングコメント文・総合アドバイス文の補強 |

#### 10.1.4 インフラメタデータ（v4 で追加）
本アプリのバックエンド運用上、以下の通信メタデータは **CDN/WAF/ホスティング事業者** によって処理される可能性がある:
- IP アドレス、User-Agent、TLS フィンガープリント等の通信メタデータ
- セキュリティ・不正利用防止・障害対応の目的で、各事業者の規約に従って一定期間保持される場合がある
- 本アプリのサーバープロセスはこれらを**永続保存せず、構造化ログにも書き出さない**（§11.4）。インフラ事業者側の処理は当該事業者のプライバシーポリシーに従う。

Privacy Details 上は「Diagnostics: Yes / Linked: No / Tracking: No / Purpose: App Functionality（不正防止・分析）」として申告候補。

> **Diagnostics（アプリサーバー由来）**: 構造化ログとしてサーバー側に `path`/`status`/`latency_ms`/`request_id`/`external_ai_used` のみ保存（本文・入力値・例外の入力コンテキストは含まない）。

### 10.2 ATT
- 第三者トラッキング行わない。ATT プロンプトなし。

### 10.3 同意フロー（`consent_screen.dart`）
初回同意で取得する内容:
- 13 歳以上の自己申告（チェックボックス、年齢非保存）
- 端末内データ保存とサーバー一時処理（永続化なし）の説明
- 「外部 AI による文章補強は既定オフ。設定からオンにできます」

外部 AI トグルを ON にする瞬間に**別個の同意ダイアログ**:

> Muscle Mate は既定では外部 AI を利用しません。本機能を有効にすると、メニュー生成時に **目標・レベル・使用器具・週頻度・セッション時間・生成された種目名のみ** を Groq, Inc.（米国）の AI 推論サービスに送信します。**年齢、性別、体重、BIG3 数値、ターゲット筋群、優先種目、トレーニング歴、怪我情報、自由記述、トレーニング記録、痛みの有無、RPE は送信されません。** Groq 社のデータ取り扱い方針は同社のドキュメント（https://console.groq.com/docs/your-data ）をご確認ください。同意は設定画面からいつでも撤回できます。

### 10.4 プライバシーポリシー改訂テキスト（v4）

- §3 メニュー生成の処理: ルールベースで完結。外部送信なし。
- **§4 外部 AI 利用（任意・既定オフ）**:
  - 送信される情報: 目標 / レベル / 使用器具 / 週頻度 / セッション時間 / 生成済み種目名一覧（**6 項目のみ**）
  - 送信されない情報: 年齢・性別・体重・BIG3 数値・ターゲット筋群・優先種目・トレーニング歴・怪我履歴・自由記述・実施記録・痛み有無・RPE
  - **自動スキップ**: 怪我履歴・自由記述・ターゲット筋群・優先種目・痛みフラグのいずれかが入力されたメニュー生成では、本機能を有効化していても**外部 AI への送信は自動的に行われません**（種目名から本人特性が間接的に推測されるリスクを避けるため）。
  - 目的: コーチングコメント文・総合アドバイス文の補強
  - データ保持: Groq 社の規約に準じます。Groq 社のアカウント設定で Zero Data Retention（ZDR）が利用可能な場合は有効化することを運用上の方針としていますが、**ZDR の実効状態は当社が直接保証するものではなく、Groq 社側の設定・規約変更により変動します**。最新の取り扱いは https://console.groq.com/docs/your-data をご確認ください。
  - **同意撤回の効力**: 設定画面のトグルをオフにすると、**それ以降のメニュー生成では Groq 社への送信を行いません**。ただし、撤回前に既に送信済みのデータの取扱い（保持・削除）は Groq 社の規約に従い、**当社が遡及的に削除できることを保証するものではありません**。
- §5 サーバー保存ポリシー: メニュー生成リクエストおよびトレーニング記録を**永続化せず、ログ・APM・データベース・キャッシュにも本文を書きません**。サーバーは構造化メタデータ（経路・ステータス・処理時間・リクエスト ID・外部 AI 利用フラグ）のみを保存します。
- **§6 インフラ事業者によるメタデータ処理**: 本サービスの提供にあたり、CDN・WAF・ホスティング事業者が、IP アドレス・User-Agent 等の通信メタデータをセキュリティ・不正利用防止・障害対応の目的で処理する場合があります。これらは各事業者の規約に従って一定期間保持され得ます。本アプリのサーバープロセスはこれらを永続保存せず、構造化ログにも本文を書き出しません。
- §7 端末内データ: 端末内 SQLite / SharedPreferences に保存。「アカウントデータを削除」で完全消去。
- §8 医療助言の不提供: 痛み・違和感がある場合は中止し医療専門家へ。
- §9 13 歳未満: 自己申告ゲート。年齢自体は保存しない。
- §10 同意撤回: 外部 AI 利用は設定画面で随時撤回可能（効力は §4 の通り）。

### 10.5 Google Play Data Safety
上記と同内容を Data Safety フォームで宣言。

---

## 11. 本番セキュリティと運用

### 11.1 ネットワーク防御の階層
- **CDN/WAF**（Cloudflare 等）: L7 攻撃・既知の悪性パターン・地域制限を最前段で処理。
- **リバースプロキシ**: HTTPS 強制、リクエストサイズ上限（例: 32KB）、タイムアウト（例: 10s）、ヘッダ正規化。
- **FastAPI**: Pydantic バリデーション、レート制限（`slowapi`）、ホワイトリスト構築。
- **外部 AI 呼び出しサーバー側上限**: 1 サーバープロセスあたり `MAX_EXTERNAL_AI_CALLS_PER_MIN`（例: 30）を超過した分はルール結果のみ返す（無料枠保護）。

### 11.2 CORS の位置づけ（過大評価しない）
- CORS はブラウザ向けの制御であり、ネイティブアプリ・curl・他のサーバーには効かない。
- Flutter Web の場合のみ Origin 固定で意味がある。
- 本 API 全体の保護は**レート制限・WAF・入力サイズ上限・タイムアウト・サーバー側多重ガード**で行う、と明記。
- **`APP_ENV` による分岐（v4）**: `main.py` で起動時に下記を実行する。
  - `APP_ENV=production` の時のみ `ALLOWED_ORIGINS` 未設定で `SystemExit`。
  - `APP_ENV=development`（既定）の時は `ALLOWED_ORIGINS` 未設定なら `["http://localhost:*", "http://127.0.0.1:*"]` を内部既定として使用（フォールバック `*` は撤廃済）。
  - 開発環境で本番 Origin を設定したい場合は明示的に `ALLOWED_ORIGINS` を渡せる。
- これにより本番セキュリティを担保しつつ、ローカル開発体験を壊さない。

### 11.3 認証・レート制限
- 全エンドポイント匿名（`user_id` を扱わないため）。
- `slowapi` で IP ベース: `/workout/generate` 5 req/min/IP、`/workout/next` 10 req/min/IP。
- IP 単独では集合 NAT 等で誤遮断・回避双方が起こり得るため、**WAF・リクエストサイズ・タイムアウト・外部 AI サーバー側上限**と組み合わせる（§11.1）。
- 上限超過時は `429`、`Retry-After` ヘッダ。

### 11.4 永続化禁止の実装要件（v3 で具体化、v4 でカナリア検査追加）
- **構造化ログ**: `structlog` を導入。ハンドラに「リクエスト本文・レスポンス本文・派生データを出さない」フィルタを設定。残すのは `path`, `status`, `latency_ms`, `request_id`, `external_ai_used: bool` のみ。
- **Pydantic / FastAPI バリデーションエラー**: `RequestValidationError` を**独自ハンドラ**で受け、`{"errors": [{"loc": ..., "msg": ..., "type": ...}]}` を返す（**`input` フィールドを含めない**）。デフォルトハンドラは入力値を含めるため必ず上書き。
- **Uvicorn アクセスログ**: `--access-log` を有効化する場合も**クエリストリングと本文を出力しない**フォーマットに固定。`--no-access-log` 推奨。
- **APM（Sentry 等）**: `send_default_pii=False`、`before_send` で本文・例外コンテキスト中の入力値をスクラブ。`request.body` を取得しないコールバックに固定。
- **DB / キャッシュ**: 本系には DB を持たない。レスポンスキャッシュを使う場合は**ホワイトリスト 6 フィールドのハッシュをキー**にし、**禁止フィールドを含むリクエストはキャッシュ対象外**。
- **外部 AI 入口**: `AllowlistedLLMPayload(extra="forbid")` で構造的に禁止フィールド混入を不可能化。CI で fuzz テスト。
- **設定**: `LOG_REQUEST_BODY` を環境変数として持つが、コード側で常に `false` を強制（true 設定があっても無視）。

#### 11.4.1 カナリア値による漏えい検査（v4 で追加）

「禁止フィールド名がログに出ない」だけでは、フィールド値や自由記述本文の漏えいは検出できない。CI に**カナリア値検査**を追加する。

検査の流れ:
1. 統合テストで以下のリクエストを発行する。
   ```
   POST /workout/generate
   {
     "goal": "muscle_gain",
     ...
     "notes": "DO_NOT_LOG_SECRET_<request_id>",          ← カナリア
     "injury_history": [{"region": "DO_NOT_LOG_INJURY_<request_id>", ...}],
     "big3_max": {"bench_press_max": 99999.99}            ← 数値カナリア（特異値）
   }
   ```
2. レスポンス・サーバー標準出力ログ・APM サンプルイベント・エラーレスポンス JSON を全て収集。
3. 各収集結果を文字列検索:
   - `DO_NOT_LOG_SECRET_*`、`DO_NOT_LOG_INJURY_*` の出現 → fail
   - `99999.99` の出現 → fail（数値カナリアの特異値）
4. fail があれば CI を red にする。
5. バリデーションエラーケース（空文字や不正値）も同様にカナリアを混ぜて検査する（`RequestValidationError` ハンドラの `input` 漏えいの最終防衛）。

カナリアは `request_id` と組み合わせて**毎回ユニーク**にし、過去のログとの偶然一致を防ぐ。

### 11.5 シークレット
- `GROQ_API_KEY` はサーバー側のみ。Flutter には組み込まない。
- `.env` を `.gitignore`、CI で gitleaks。

### 11.6 第三者 AI（Groq）設定（v4 で運用記録扱いを明記）

**ZDR は運用記録、コードフラグではない**:
- ZDR の実体は Groq 組織アカウント側の設定であり、`GROQ_ZDR_ENABLED=true` という環境変数はあくまで「自己申告メモ」として持つ。
- 実際の有効状態は `docs/operational_records.md`（新設）に運用担当者が記録する:
  - 確認日時、確認者、Groq Console 上のスクリーンショット参照、規約バージョン
  - 月次レビューで再確認
- 起動時チェックリストに「Groq ZDR 設定の確認済みか」を含め、未確認なら起動ログに WARN を出力する（ブロックはしない）。

**失敗時の挙動**:
- API エラー、レート超過、タイムアウト、JSON パース失敗、いずれもルール結果をそのまま返す（ユーザー体験への影響を「コーチングコメント文章が控えめになる」程度に抑える）。

**運用観測**:
- 月次でレート制限超過率を観測。

### 11.7 Groq 課金保護（v4 で追加）

「月額 ¥0 KPI」と Groq 任意採用の緊張関係を解消するため、課金が発生し得ないことをコード・運用の両面で担保する。

**既定運用（推奨）**: `EXTERNAL_AI_BILLING_MODE=free_only`
- Groq アカウントに**支払情報を登録しない**運用を既定とする。
- 無料枠超過時は API がエラーを返し、サーバーは自動的に NoOp フォールバック（ルール結果のみ）。
- これにより制限変更時も「意図せず課金される」ことが原理的に起こらない。
- このモードでは**月次カウンタを参照しない**（v5 で明示）。`MAX_EXTERNAL_AI_CALLS_PER_MONTH` の値が誤って `0` でも `1000` でも挙動は変わらず「分単位上限のみで制御」となる。

**やむを得ず有料プランを使う場合**: `EXTERNAL_AI_BILLING_MODE=paid_capped`
- Groq 側で月額のハードキャップ（Spending Limit 等、提供される機能の範囲で最低額）を設定。
- サーバー側で `MAX_EXTERNAL_AI_CALLS_PER_MONTH` を必須化し、超過時は `LLM_PROVIDER=noop` 同等の挙動（呼び出さない）にロールオーバー。
- カウンタはサーバープロセスローカル（再起動でリセットされ得るため、月次切替時は意図的にリセット）。
- 月次レビューで実消費を `operational_records.md` に記録。

---

## 12. KPI（v3 再定義）

「Apple 審査一発合格」「BIG3 5% 増」は v2 で KPI 化したが、前者は開発側で完全制御不能、後者はサーバー集計しないプライバシー方針と矛盾するため、KPI から外す。

### 12.1 プロダクト KPI（運営計測可能なもの）
- **コスト**: 月間 AI 関連支出 ¥0。**実装担保**: Groq 支払情報未登録（§11.7）または `MAX_EXTERNAL_AI_CALLS_PER_MONTH` ハードキャップ。
- **可用性**: `/workout/generate` の成功率 ≥ 99.9%（ルール単独で完結）。
- **第三者 AI 失敗時のフォールバック成功率**: ≥ 99.9%（外部 AI 死亡時もルール結果が返る）。
- **禁止フィールドの第三者 AI 送信**: **0 件**（CI とランタイム双方で検証）。
- **カナリア値の漏えい検出**: **0 件**（§11.4.1 で月次フル走査）。
- **間接漏えいスキップ正答率**: 100%（§4.4 の各条件で `external_ai_used == false` になることを CI で検査）。

### 12.2 リリース品質目標（KPI ではなく提出準備の目標）
- **審査提出前チェックリスト完了率**: 100%（チェックリストは §13 末尾）。
- **Privacy Details とアプリ内文言の整合性**: 100%（§7・§10・付録 C を CI でテキスト一致検査）。

### 12.3 ユーザー本人向け進捗（端末内 UX のみ・運営は集計しない）
- 端末内 SQLite から計算する「BIG3 推移グラフ」「直近 4 週ボリューム」など。サーバーは集計しない。
- もし将来的に運営が匿名集計したい場合は、別途オプトイン同意フローを設計（v3 では Out of Scope）。

---

## 13. フェーズ別ロードマップ

### フェーズ 0: 準備（1 週間）
- 本計画書 v3 レビュー＆承認。
- `knowledge/` 雛形コミット、`LICENSES.md` 新設、`.gitignore` に `knowledge/papers/**/*.pdf` 明記。
- 初期収録対象論文のオープンアクセス確認。

### フェーズ 1: ルールエンジン単独（2 週間）
- `rule_engine_service.py` 実装、`/workout/generate` をルール単独で稼働。
- `gemini_service.py` 削除、`google-generativeai` 依存除外。
- `main.py` の CORS フォールバック削除、HTTPS／WAF／タイムアウト／サイズ上限を本番設定に追加。
- 永続化禁止ハンドラ（独自 `RequestValidationError`、構造化ログ、Uvicorn 設定）。
- ユニットテスト 50 パターン以上＋本文流出スナップショット検査。

### フェーズ 2: ステートレス次回最適化（1 週間）
- `progression_service.py` 実装、`/workout/next` 新設。
- 端末側 `SessionLog` SQLite 保存と「アカウントデータを削除」連動。
- 痛み時の医療 UI（§9.2）実装。

### フェーズ 3: 論文知識参照（2 週間、§6.5 の段階導入に従う）
- 要約マークダウン作成（人間レビュー、`review_status: human_reviewed`）。
- **段階 A: 静的辞書検索を既定として実装**（フロントマター＋INDEX.md の線形検索、依存追加なし）。`RAG_BACKEND=static` で動作。
- `assets/evidence_index.json` を Flutter 同梱（§5.4 の限定スキーマ）。
- 配布物に本文サマリが含まれていないことを CI で検査。
- **段階 B（必要時のみ）**: 論文 > 50 件 or ヒット率不足が確認されたら FAISS へ昇格。`build_index.py` 実装と Docker build 検証はこの段階で行う。

### フェーズ 4: 任意の外部 AI 補強（1 週間）
- `llm_service.py` 実装（`AllowlistedLLMPayload(extra="forbid")`、`NoOpClient` 既定）。
- 設定画面トグル＋同意ダイアログ。
- CI に「禁止フィールド混入で必ず失敗するテスト」を追加。
- ZDR 設定確認・契約面整備。

### フェーズ 5: App Store / Play 提出準備（1 週間）
- プライバシーポリシー差し替え、Privacy Details / Data Safety 提出。
- 同意画面・設定画面の文言レビュー。
- レート制限・ログマスキング・HTTPS 強制の本番デプロイ。
- 13 歳ゲート（年齢非保存）の動作確認。
- TestFlight / 内部テスト。
- **提出前チェックリスト（v4）**:
  - [ ] §7 ホワイトリストと §4.1／§4.4／§10.1.3／§10.3／§10.4／付録 C の文字列一致
  - [ ] CI で禁止フィールド送信テスト緑
  - [ ] CI で**カナリア値漏えい検査**緑（§11.4.1）
  - [ ] CI で**自動スキップ検査**緑（§4.4 の各条件で `external_ai_used == false`）
  - [ ] `LLM_PROVIDER=noop` で `/workout/generate` がルール単独で完結
  - [ ] 痛み時の医療モーダルが表示される（`advisory.level == "rest_or_consult"` 経路）
  - [ ] `WorkoutResponse` 拡張型（§6.4）に Flutter が分岐対応している
  - [ ] 13 歳ゲートで `age` が SharedPreferences に保存されないこと
  - [ ] `APP_ENV=production` 時、`ALLOWED_ORIGINS` 未設定で起動失敗すること（開発時は localhost 既定で起動可）
  - [ ] Privacy Details の **4 区分**（端末内／サーバー一時／第三者 AI／インフラメタデータ）が記入済み
  - [ ] `assets/evidence_index.json` に許可スキーマ以外のキーがないこと
  - [ ] `operational_records.md` に **Groq ZDR 確認記録**が直近 30 日以内に存在
  - [ ] Groq 支払情報未登録 OR `MAX_EXTERNAL_AI_CALLS_PER_MONTH` ハードキャップ設定済み
  - [ ] プライバシーポリシーに**インフラメタデータ処理条項（§10.4 §6）と同意撤回の遡及不能性（§10.4 §4）**が記載されている

---

## 14. リスクと対策（v4 更新）

| リスク | 影響 | 対策 |
| --- | --- | --- |
| ホワイトリスト矛盾の再発 | プライバシー違反 | §7 を真実源とし、CI でテキスト一致検査 |
| `exercise_names` 経由の間接漏えい | プライバシー違反 | §4.4 の自動スキップ条件で外部 AI を呼ばない |
| Pydantic デフォルトハンドラから入力流出 | プライバシー違反 | 独自 `RequestValidationError` ハンドラ必須 |
| Sentry / ログから本文・値流出 | プライバシー違反 | `before_send` スクラブ、Uvicorn `--no-access-log`、**カナリア値検査** |
| ヘッダ単独依存で外部 AI 誤呼出 | プライバシー違反 | `LLM_PROVIDER` 環境変数とのサーバー側 AND 条件で多重ガード |
| 配布物に論文本文同梱で著作権侵害 | 法務リスク | `assets/evidence_index.json` のスキーマを CI で検査 |
| 痛み時に残メニュー不成立 | 怪我助長 | §6.4 の `advisory.level == "rest_or_consult"` で当日中止 |
| Flutter が `plan: null` を想定せず落ちる | UX 障害 | §6.4 で `WorkoutResponse` 型を拡張、Flutter 分岐仕様を明記 |
| KPI が制御不能（審査） | KPI 未達評価 | KPI から外し、提出前チェックリストに置換 |
| 集合 NAT で IP レート制限が誤遮断 | UX 低下 | WAF・サイズ上限・タイムアウト・サーバー側 AI 上限と多層化 |
| Ollama を本番候補と誤解 | 実装混乱 | §3.3 で「本番初期対象外、開発／セルフホスト用ドキュメントのみ」と明示 |
| 商業書籍 PDF 混入 | 法務リスク | `papers/` を `.gitignore`、`LICENSES.md` レビュー必須 |
| 開発環境で起動失敗してチームが詰まる | DX 低下 | `APP_ENV=development` で `localhost` 既定（§11.2） |
| ZDR を環境変数で「設定済み」と誤認 | 実効性なし | `operational_records.md` への運用記録を必須化（§11.6） |
| Groq Free 廃止で意図せず課金 | 経済リスク | 支払情報未登録運用または `MAX_EXTERNAL_AI_CALLS_PER_MONTH` キャップ（§11.7） |
| sentence-transformers/FAISS 導入で Docker build 失敗 | リリース遅延 | 静的辞書から開始、必要時のみ FAISS 昇格＋ build 検証（§6.5） |
| 同意撤回後も既送信データが残ると誤解 | 苦情・信頼低下 | §10.4 §4 で「以後の送信停止」と明記、遡及削除を保証しない |
| インフラ事業者の IP 等処理が未開示 | 審査・法的指摘 | §10.4 §6 で開示（§10.1.4） |

---

## 15. Out of Scope（v3）
- 食事・栄養計算 AI。
- 動画フォーム解析。
- アカウント認証・サーバーバックアップ。
- 多言語対応。
- 運営による進捗 KPI の匿名集計（必要なら別途オプトイン同意フローを設計）。

---

## 16. 次のアクション
1. 本計画書 v4 をチームレビュー（Tech / Product / Legal）。
2. オープンアクセス確認結果を `LICENSES.md` に登録。
3. `docs/operational_records.md` を新設し、Groq ZDR 確認の運用ルールを記載。
4. フェーズ 1 のスプリント計画。`gemini_service.py` 削除・永続化禁止実装・`APP_ENV` 分岐・`WorkoutResponse` 拡張を含む。
5. App Store Connect / Google Play Console の Privacy Details / Data Safety ドラフト（**4 区分**: 端末内／サーバー一時／第三者 AI／インフラメタデータ）を作成。
6. Groq アカウントを **支払情報未登録**で作成し、Free 運用を確定。
7. CI に **カナリア値検査・自動スキップ検査** を組み込む。

---

## 付録 A: ディレクトリ構成（v3 最終形）
```
muscle-mate-app/
├── backend/
│   ├── src/
│   │   ├── routers/workout.py            # /generate, /next（ステートレス）, /entertainment
│   │   ├── services/
│   │   │   ├── rule_engine_service.py
│   │   │   ├── llm_service.py            # AllowlistedLLMPayload(extra="forbid")
│   │   │   ├── rag_service.py
│   │   │   └── progression_service.py
│   │   ├── schemas/{workout.py, log.py}
│   │   └── error_handlers.py             # RequestValidationError 上書き（input を返さない）
│   └── scripts/papers/{ingest_paper.py, build_index.py}
├── knowledge/
│   ├── papers/.gitkeep                   # PDF はコミット禁止（.gitignore）
│   ├── summaries/                        # 自作要約（サーバー側のみ）
│   ├── programs/                         # 自作雛形（商業名なし）
│   ├── glossary.md
│   ├── INDEX.md
│   └── LICENSES.md
├── data/embeddings/                      # FAISS（サーバー内のみ）
├── docs/workout_ai_replacement_plan.md
└── frontend/
    ├── assets/evidence_index.json        # ID/title/authors/year/doi/license/source_url/short_summary_ja のみ
    ├── lib/
    │   ├── models/{workout_plan.dart, session_log.dart}
    │   ├── screens/{consent_screen.dart, privacy_policy_screen.dart, settings_screen.dart, ...}
    │   └── services/api_service.dart
```

## 付録 B: 環境変数（v4）
| 変数名 | 例 | 必須 | 説明 |
| --- | --- | --- | --- |
| `APP_ENV` | `development`（既定）/ `production` | ○ | 本番のみ厳格チェック |
| `LLM_PROVIDER` | `noop`（既定）/ `groq` | ○ | `groq` 以外では外部送信が起きない |
| `GROQ_API_KEY` | `gsk_***` | `groq` 時 | サーバー側のみ |
| `GROQ_MODEL` | `llama-3.3-70b-versatile` | △ | |
| `GROQ_ZDR_ENABLED` | `true` | △ | **自己申告メモ。実設定は Groq 組織側。`operational_records.md` で確認** |
| `RAG_BACKEND` | `static`（既定）/ `faiss` | ○ | フェーズ 3 段階導入（§6.5） |
| `RAG_INDEX_PATH` | `./data/embeddings/faiss.index` | △（faiss 時） | |
| `EMBEDDING_MODEL` | `intfloat/multilingual-e5-small` | △（faiss 時） | |
| `ALLOWED_ORIGINS` | `https://app.example.com` | **`production` 時のみ未設定で起動失敗** | 開発時は `localhost` 既定 |
| `RATE_LIMIT_GENERATE` | `5/minute` | ○ | |
| `RATE_LIMIT_NEXT` | `10/minute` | ○ | |
| `MAX_REQUEST_BYTES` | `32768` | ○ | リバースプロキシで強制 |
| `REQUEST_TIMEOUT_SECONDS` | `10` | ○ | |
| `MAX_EXTERNAL_AI_CALLS_PER_MIN` | `30` | ○ | サーバー側分単位上限 |
| `EXTERNAL_AI_BILLING_MODE` | `free_only`（既定）/ `paid_capped` | ○ | **v5**: `free_only` では月次カウンタを参照しない。Groq 側支払情報未登録で物理的に課金不可 |
| `MAX_EXTERNAL_AI_CALLS_PER_MONTH` | `1000` | `paid_capped` 時のみ | 月次ハードキャップ。`free_only` モードでは無視される |
| `LOG_REQUEST_BODY` | `false` | ○ | コードで強制（true は無視） |

## 付録 C: 外部 AI 送信ホワイトリスト（**§7 の再掲・シングルソース**）

**送信可（6 フィールドのみ・他章と完全一致）:**
- `goal`
- `level`
- `equipment`
- `days_per_week`
- `session_duration_minutes`
- `exercise_names`

**送信可だが §4.4 の自動スキップ条件に該当する場合は送信しない**（v4 追加）:
- `injury_history` 入力あり、`notes` 入力あり、`target_muscles` 指定あり、`priority_lift != none`、痛み報告あり、`safety_flags` 非空 のいずれかに該当 → 6 フィールドであっても送信しない。

**送信禁止（CI 検査）:**
- 個人属性: `age`, `gender`, `body_weight_kg`, `years_of_training`, `priority_lift`
- 健康・実績: `big3_max`, `target_muscles`, `injury_history`, `notes`, `pain`, `rpe`, `weight_kg`, `session_logs`
- 識別子: `user_id`, `email`, `device_id`, `ip`

CI 検査:
1. `llm_service` 入口の Pydantic モデルが `extra="forbid"` で禁止フィールドを構造的に弾くこと。
2. 計画書本文（§4.1／§4.4／§7／§10.1.3／§10.3／§10.4／付録 C）に同じ 6 フィールド文字列が出現することをスナップショット比較。
3. **カナリア値検査（§11.4.1）**: ユニーク文字列・特異数値をリクエストに混ぜて、ログ／APM／エラー応答に出ないことを検査。
4. **自動スキップ検査**: §4.4 の各スキップ条件を含むリクエストで `external_ai_used == false` になることをテスト。

以上。
