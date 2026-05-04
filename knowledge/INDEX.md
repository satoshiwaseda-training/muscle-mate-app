# 論文要約インデックス

`knowledge/summaries/` 配下のマークダウン要約のうち、`review_status: human_reviewed` 済みのものをここに登録する。

このファイルは**サーバー内のみで参照**され、Flutter には同梱しない。Flutter 同梱物は `frontend/assets/evidence_index.json` のみ（計画書 §5.4）。

## 登録方法

1. `knowledge/papers/<カテゴリ>/<id>.pdf` にオープンアクセス確認済みの PDF を配置（`.gitignore` 済み）。
2. `knowledge/summaries/<カテゴリ>/<id>.md` に要約マークダウンを作成。
3. ピアレビュー後 `review_status: human_reviewed` に昇格。
4. 本 INDEX に下記の表形式で登録。
5. `LICENSES.md` にライセンス情報を併記。
6. `frontend/assets/evidence_index.json` を再生成（`backend/scripts/papers/build_evidence_index.py`）。

## 登録済みエントリ

| evidence_id | カテゴリ | タイトル（短縮） | target_goals | review_status | 登録日 |
| --- | --- | --- | --- | --- | --- |
| _（要約 MD はまだ未登録。フェーズ 3 後半で人手レビュー後に追加）_ | | | | | |

## メタデータ済み論文（19 本）

要約 MD 作成前のメタデータのみ登録済み。詳細は `papers/<カテゴリ>/<evidence_id>.metadata.md` を参照。

### hypertrophy/
- schoenfeld_2010_mechanisms — JSCR 2010
- schoenfeld_2013_metabolic_stress — Sports Med 2013
- mitchell_2012_load_hypertrophy — J Appl Physiol 2012
- west_phillips_2012_hormones — Eur J Appl Physiol 2012

### nutrition/
- moore_2009_protein_dose_response — AJCN 2009
- macnaughton_2016_40g_vs_20g_whey — Physiol Rep 2016
- jager_2017_issn_protein — JISSN 2017（CC-BY-4.0）
- schoenfeld_2018_protein_per_meal — JISSN 2018
- van_vliet_2017_whole_egg — AJCN 2017
- elliot_2006_milk_mps — MSSE 2006
- bagheri_2021_egg_vs_white — JSCR 2021
- whittaker_2021_low_fat_testosterone — J Steroid Biochem 2021

### training/
- buresh_2009_rest_interval — JSCR 2009
- schoenfeld_2016_longer_rest — JSCR 2016
- henselmans_schoenfeld_2014_rest_intervals_review — Sports Med 2014
- spennewyn_2008_free_vs_machine — JSCR 2008
- currier_2023_bjsm_meta_analysis — BJSM 2023（CC-BY-NC-4.0、Haugen 2023 要望の代替候補）

### caffeine/
- hodgson_2013_caffeine_endurance — PLoS ONE 2013（CC-BY-4.0）
- trexler_2016_caffeine_strength — Eur J Sport Sci 2016

## カテゴリ
- `hypertrophy/` 筋肥大関連
- `nutrition/` 栄養関連（タンパク質・脂質）
- `training/` トレーニング変数（休息・器具・頻度）
- `caffeine/` カフェインなど補助成分
- `recovery/` 回復・休養関連（将来）

## 関連ファイル
- `glossary.md`: 用語統一（RPE, 1RM, MEV, MRV 等）
- `LICENSES.md`: 各論文のライセンスと引用条件
