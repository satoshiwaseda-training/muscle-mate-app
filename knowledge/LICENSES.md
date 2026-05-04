# 論文ライセンス管理

`knowledge/papers/` に配置する論文 PDF と `knowledge/summaries/` に作成する要約マークダウンの**ライセンス・引用条件**を一元管理する。

## 収録方針（v5 確定）

**収録可:**
- オープンアクセス（CC-BY 等）の査読論文 PDF
- PubMed / DOI 等で公開されているメタデータ
- 自作の二次著作物としての要約マークダウン

**収録不可:**
- 商業書籍 PDF（例: *Starting Strength*、*Beyond 5/3/1* 等）
- 著作権者の許諾が確認できない PDF
- 出版社の権利留保下にあるサブスクリプション論文の本文 PDF

## 登録済み論文（19 本中 19 本記録、PDF 配置可否は別欄）

| evidence_id | 年 | 雑誌 | DOI | ライセンス確認状況 | PDF 配置可否 |
| --- | --- | --- | --- | --- | --- |
| schoenfeld_2010_mechanisms | 2010 | JSCR | 10.1519/JSC.0b013e3181e840f3 | closed_access | ✗ |
| schoenfeld_2013_metabolic_stress | 2013 | Sports Med | 10.1007/s40279-013-0017-1 | closed_access | ✗ |
| mitchell_2012_load_hypertrophy | 2012 | J Appl Physiol | 10.1152/japplphysiol.00307.2012 | PMC 無料全文（要 CC 確認） | △ |
| west_phillips_2012_hormones | 2012 | Eur J Appl Physiol | 10.1007/s00421-011-2246-z | PMC 無料全文（要 CC 確認） | △ |
| moore_2009_protein_dose_response | 2009 | AJCN | 10.3945/ajcn.2008.26401 | closed_access | ✗ |
| macnaughton_2016_40g_vs_20g_whey | 2016 | Physiological Reports | 10.14814/phy2.12893 | **CC-BY 4.0 likely**（要最終確認） | ○ 確認後 |
| jager_2017_issn_protein | 2017 | JISSN | 10.1186/s12970-017-0177-8 | **CC-BY 4.0 確認済** | ○ |
| schoenfeld_2018_protein_per_meal | 2018 | JISSN | 10.1186/s12970-018-0215-1 | **CC-BY 4.0 likely**（要最終確認） | ○ 確認後 |
| van_vliet_2017_whole_egg | 2017 | AJCN | 10.3945/ajcn.117.159855 | closed_access | ✗ |
| elliot_2006_milk_mps | 2006 | MSSE | 10.1249/01.mss.0000210190.64458.25 | closed_access | ✗ |
| bagheri_2021_egg_vs_white | 2021 | JSCR | 10.1519/JSC.0000000000003922 | closed_access | ✗ |
| whittaker_2021_low_fat_testosterone | 2021 | J Steroid Biochem Mol Biol | 10.1016/j.jsbmb.2021.105878 | closed_access（arXiv preprint あり要確認） | ✗ |
| buresh_2009_rest_interval | 2009 | JSCR | 10.1519/JSC.0b013e318185f14a | closed_access | ✗ |
| schoenfeld_2016_longer_rest | 2016 | JSCR | 10.1519/JSC.0000000000001272 | closed_access | ✗ |
| henselmans_schoenfeld_2014_rest_intervals_review | 2014 | Sports Med | 10.1007/s40279-014-0228-0 | closed_access | ✗ |
| spennewyn_2008_free_vs_machine | 2008 | JSCR | 10.1519/JSC.0b013e31815ef5e7 | closed_access | ✗ |
| currier_2023_bjsm_meta_analysis | 2023 | BJSM | 10.1136/bjsports-2023-106807 | **CC-BY-NC 4.0 確認済** | ○（非商用・出典明記） |
| hodgson_2013_caffeine_endurance | 2013 | PLoS ONE | 10.1371/journal.pone.0059561 | **CC-BY 4.0 確認済** | ○ |
| trexler_2016_caffeine_strength | 2016 | Eur J Sport Sci | 10.1080/17461391.2015.1085097 | PMC 無料全文（要 CC 確認） | △ |

## 凡例

- **PDF 配置可否**:
  - ○: ライセンス確認済み・配置可（ただし商用配布は不可。本リポジトリでは `papers/` に配置・gitignore で配布物には含めない）
  - △: PMC 等で無料全文公開だが Creative Commons の有無を確認する必要あり
  - ✗: 購読制または許諾未確認のため配置不可（リンクとメタデータのみ保持）

## レビュープロセス

新規論文を追加する際は以下を実施:
1. オープンアクセス確認（CC-BY 等のライセンスが明示されているか）
2. PMC 全文の場合は copyright ブロックでライセンスを確認
3. 本表にライセンス情報を追記
4. 配置可（○）になったもののみ `knowledge/papers/<カテゴリ>/` に PDF 保存（gitignore 済）
5. `summaries/<カテゴリ>/<id>.md` に自作要約を作成（人手レビュー必須）
6. 要約マークダウンに `review_status: human_reviewed` を付与してインデックス対象化

## ライセンス略号

| 略号 | 名称 | 二次利用可否（要約作成・配布） |
| --- | --- | --- |
| CC-BY-4.0 | Creative Commons Attribution 4.0 | 可（出典明記必須） |
| CC-BY-NC-4.0 | Creative Commons Attribution-NonCommercial 4.0 | 可（非商用・出典明記必須） |
| CC-BY-SA-4.0 | Creative Commons Attribution-ShareAlike 4.0 | 可（同条件継承・出典明記必須） |
| CC0 | Public Domain Dedication | 可（出典明記推奨） |
| Closed | サブスクリプション・要許諾 | **不可**（要約も作成しない） |

## 引用形式

要約マークダウン §5「出典」には、原文を**転載せず**、以下の形式で引用のみ記載する:

```
著者ら (年). タイトル. 雑誌名. DOI: 10.xxxx/...
```

## 次のアクション

1. △ マークの 3 本（mitchell_2012, west_phillips_2012, trexler_2016）の PMC ライセンス末尾を実物確認 → ○ または ✗ に確定
2. macnaughton_2016 / schoenfeld_2018 の CC-BY 4.0 を `Physiological Reports` / `JISSN` の OA ポリシーで最終確認
3. whittaker_2021 の arXiv プレプリントのライセンス確認（preprint は通常 arXiv 任意ライセンス）
4. ✗ マークの論文は本文 PDF を扱わず、要約マークダウンも作成しない（リンク参照のみ）
5. ○ になったものから順に PDF を取得し、人手レビューによる要約マークダウンを `summaries/` に作成
