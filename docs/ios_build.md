# iOS ビルドと配布の手順

方針は `docs/distribution.md` のとおりです（Macなし・無料・SideStoreで署名とインストール）。
GitHub Actions のmacランナーで**署名なしの .ipa** を作り、SideStore が無料 Apple ID で署名して端末に入れます。

## 仕組み
| もの | 場所 | 内容 |
|---|---|---|
| 書き出しプリセット | `export_presets.cfg` の「iOS」 | Xcode プロジェクトだけを書き出す（`export_project_only`） |
| ワークフロー | `.github/workflows/ios-build.yml` | Godot で書き出す → xcodebuild で署名なしビルド → .ipa を作る |
| アイコン（仮） | `icon.svg` → `assets/icon/icon_1024.png` | 作り直すときは `godot --headless --path . --script res://tests/tools/make_ios_icon.gd` |

### 書き出しの設定
- **バンドルID**: `com.XXXX.oneopeshokudo`。**今後変えない**（変えると別のアプリになり、セーブが引き継がれない）
- アプリ名: 「ワンオペ！食堂は戦場に！？」（`project.godot` の `config/name`）
- 対応端末: iPhone と iPad（`targeted_device_family=2`）。向きは横向きで固定（`project.godot` の `window/handheld/orientation`）
- iOS 15.0 以上
- **Team ID はダミー値（`ABCDE12345`）**です。Godot は Team ID が空だと書き出さないので、形だけの値を入れています。ビルドは `CODE_SIGNING_ALLOWED=NO` で署名しないため、この値は使われません
- 証明書・パスワードなどの秘密情報はリポジトリに入れていません（ワークフローが使うのは、GitHub が自動で用意する `GITHUB_TOKEN` だけです）
- iOS の書き出しには、プロジェクト設定の「ETC2/ASTC の読み込み」（`rendering/textures/vram_compression/import_etc2_astc`）が必要なので、有効にしています

## 1. .ipa を作る
### 手動で作る（ふだんはこちら）
1. GitHub のリポジトリのページを開き、上の **Actions** タブを押す
2. 左の一覧から **iOS Build** を選ぶ
3. 右の **Run workflow** を押し、ブランチ（main）を選んで、緑の **Run workflow** を押す
4. 一覧に実行中の行が出る。終わるまで待つ（1回目は Godot のダウンロードがあるので 15〜25分ほど、2回目からはキャッシュで少し速くなる）
5. 緑のチェックになれば完成

### バージョンのタグで作る
- `v` で始まるタグ（例: `v0.1.0`）を push すると、自動で動きます
- GitHub Desktop では、History でコミットを右クリック →「Create Tag...」→ 名前を入れる → Push origin（タグもいっしょに push されます）
- そのタグのリリース（Releases）に .ipa が添付されます

## 2. .ipa のダウンロード場所
- **Releases の「latest」**（手動実行のたびに作り直すプレリリース）
  - ページ: `https://github.com/<ユーザー名>/<リポジトリ名>/releases/tag/latest`
  - ファイルの直接リンク: `https://github.com/<ユーザー名>/<リポジトリ名>/releases/download/latest/OneOpeShokudo.ipa`
  - iPad の Safari で上のリンクを開くと、ダウンロードできます（ログイン不要。リポジトリが公開のとき）
  - 注意: `.../releases/latest`（`tag/` なし）は「最新の正式リリース」を指す GitHub の決まったURLで、プレリリースの「latest」とは別物です
- タグで作ったときは、そのタグのリリース（`.../releases/tag/v0.1.0`）
- **Artifacts**（予備）: Actions の実行結果のページの下の「Artifacts」にある `OneOpeShokudo-ipa`。30日で消えます。中身は zip に包まれ、ダウンロードには GitHub へのログインが必要なので、端末から直接入れるときは Releases を使います

## 3. SideStore でインストールする（初回）
SideStore 自体の導入（Windows PC が1回必要）は済んでいるものとします。
1. iPad / iPhone の Safari で、上の直接リンクから `OneOpeShokudo.ipa` をダウンロードする（「ファイル」アプリの「ダウンロード」に入る）
2. 接続用の VPN アプリ（LocalDevVPN など、SideStore の案内にあるもの）をオンにする
3. SideStore を開き、**My Apps** の左上の **＋** を押す
4. ダウンロードした `OneOpeShokudo.ipa` を選ぶ
5. Apple ID での署名が終わると、ホーム画面にアプリが出る

## 4. SideStore で更新する（2回目から）
**アプリを消さずに、上から入れます**。消すとセーブも消えます。
1. 新しい .ipa を、同じリンクからダウンロードする（古いファイルは消しておくと選び間違えない）
2. VPN アプリをオンにして、SideStore の **My Apps** → **＋** → 新しい `OneOpeShokudo.ipa` を選ぶ
3. バンドルIDが同じなので、今のアプリが上書きされ、セーブは残る

### 7日の期限
- SideStore は期限の前に自動で再署名します。ときどき SideStore を開き、My Apps の残り日数を確かめます
- 期限が切れても、アプリを**消さない**でください。SideStore で **Refresh** すれば、セーブはそのまま遊べます

## 5. 失敗したとき
### どこを見るか
1. Actions タブで、赤い × の実行を開く → **build** を押す → 赤い × の手順を開くと、ログが出ます
2. 実行結果のページの下の Artifacts に **build-logs** があれば、ダウンロードして中のファイルを見ます
   - `godot_import.log`: 素材の読み込み
   - `godot_export.log`: Godot での Xcode プロジェクトの書き出し
   - `xcodebuild.log`: Xcode でのビルド（長いので、`error:` で検索する）

### よくある原因
| 止まった手順 | 考えられる原因 | 直し方 |
|---|---|---|
| ダウンロードする | Godot のバージョンを変えたのに、その版がない／URLが変わった | `ios-build.yml` の `GODOT_VERSION` と `GODOT_STATUS` を確かめる |
| Xcode プロジェクトを書き出す | `Cannot export project with preset "iOS" due to configuration errors` | 続けて出る理由を読む。空の理由のときは、ETC2/ASTC の設定が外れていないか見る |
| 署名なしでビルドする | Xcode が古くて Godot のテンプレートと合わない | `runs-on` を新しい macOS（例: `macos-26`）にする |
| Releases に添付する | `Resource not accessible by integration` | リポジトリの Settings → Actions → General → Workflow permissions を「Read and write permissions」にする |
| SideStore で入れる | 「3つまで」の制限 | 使っていないサイドロードアプリを消す（`docs/distribution.md` の制限を参照） |

- Godot 本体とテンプレートは Actions のキャッシュに入ります。壊れたと思ったら、`ios-build.yml` のキャッシュのキー（`...-macos-ios-v1`）の数字を上げると、ダウンロードし直します
