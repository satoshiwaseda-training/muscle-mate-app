# このファイルは計画書 v5 フェーズ 1 で削除されました。
# Gemini API への依存は撤廃され、ルールベースのメニュー生成へ移行しています。
# 新しい実装: src.services.rule_engine_service
#
# 互換のため後方インポート可能なシムを残しますが、本モジュールから何も提供しません。
raise ImportError(
    "src.services.gemini_service は計画書 v5 フェーズ 1 で削除されました。"
    "src.services.rule_engine_service を使用してください。"
)
