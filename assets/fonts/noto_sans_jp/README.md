# Noto Sans JP（可変フォント）

ゲーム内のすべての文字に使うフォント。

| 項目 | 内容 |
|---|---|
| フォント名 | Noto Sans JP（Noto Sans Japanese） |
| ファイル | `NotoSansJP-VariableFont_wght.ttf`（可変フォント。太さの軸 `wght` 100〜900） |
| バージョン | Version 2.004（フォント内の表記: `Version 2.004-H2`） |
| 作者 | Google / Adobe（Source Han Sans がもと） |
| ライセンス | SIL Open Font License 1.1（`OFL.txt`）。商用・非商用を問わず、同梱・再配布できる。フォント単体を売ることはできない |
| 入手元 | GitHub `google/fonts` リポジトリの `ofl/notosansjp/NotoSansJP[wght].ttf`（2026-11-26 に取得。ファイル名だけ変えている） |
| 元のソース | https://github.com/notofonts/noto-cjk （commit `523d033d`） |
| SHA-256 | `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f` |

## 使い方のルール
- 直接使わず、テーマ `assets/theme/main_theme.tres` の FontVariation（太さ違い）を通して使う
  - 通常: wght 400 ／ ボタン: wght 500 ／ 見出し・大きい文字: wght 700
- このフォントはなめらかな文字なので、インポート設定のアンチエイリアスは有効のままにする
- 文字の大きさは `main_theme.tres` の種類（`SmallLabel`・`HeaderLabel`・`LargeLabel`）で決め、各シーンで数字を直接書かない
