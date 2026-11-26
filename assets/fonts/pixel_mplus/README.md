# PixelMplus（ピクセル・エムプラス）

ゲーム内のすべての文字に使っている日本語ドット絵フォント。

| ファイル | 用途 |
|---|---|
| `PixelMplus12-Regular.ttf` | 通常の文字（12px。大きい文字は24px＝2倍で使う） |
| `PixelMplus10-Regular.ttf` | 小さい文字（10px。テーマの `SmallLabel` で使う） |

- 作者: Itou Hiroki / M+ FONTS PROJECT
- 入手元: https://github.com/itouhiro/PixelMplus （リリース v1.0.0 / PixelMplus-20130602.zip）
- ライセンス: **M+ FONT LICENSE**（改変の有無・商用／非商用を問わず、使用・複製・再配布が自由）
  - 原文: `LICENSE_E`（英語）、`LICENSE_J`（日本語。文字コードはEUC-JP）、`README.txt`（配布物に同梱のもの）
- 収録文字: JIS第1・第2水準の漢字、かな、Latin-1、いくつかの記号

## 使い方のルール
- 文字の大きさは **12・24（PixelMplus12）** か **10（PixelMplus10）** にする。それ以外の大きさだとドットがつぶれる
- インポート設定でアンチエイリアス・ヒンティング・サブピクセル配置をオフにしている（`.ttf.import`）
- テーマ: `assets/theme/main_theme.tres`（プロジェクト設定 `gui/theme/custom` で全画面に適用）
