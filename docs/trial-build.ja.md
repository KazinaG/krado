# 試し版 DMG の作り方

メンテナーに渡す試し版（`~/Downloads/krado-test.dmg`）は、毎回この手順で作ります。
リリースと同じデザインの DMG を作り、同じ「krado Self-Signed」証明書で署名するので、
入れ替えてもアクセシビリティの許可が引き継がれ、一覧に krado が増えません。

## 手順

1. 試したいコミットを push する（作業ブランチで試すときは下の `--ref` をその枝名にする）。
2. バージョン番号を指定して Release ワークフローを手動実行する（タグ・リリースは作られない）：

   ```sh
   gh workflow run release.yml -R KazinaG/krado --ref main -f trial_version=0.1.7
   ```

3. 終わったら `dryrun` アーティファクトを取り出す：

   ```sh
   gh run download <run-id> -R KazinaG/krado -n dryrun -D <保存先>
   ```

4. Mac で確かめてから `~/Downloads/krado-test.dmg` に上書きする：

   ```sh
   scripts/check-trial-dmg.sh krado-0.1.7.dmg 0.1.7
   ```

   `OK:` で始まる1行が出れば、デザイン済みのインストール画面・bundle ID `io.github.kazinag.krado`・
   固定証明書の署名要件（`certificate leaf = H"ed2ab20f…"`）を確認できています。

## してはいけないこと

- Mac で `scripts/make-dmg.sh` を直接動かして試し版にしない。Mac のキーチェーンには
  証明書がないので ad-hoc 署名になり、`DMG_STYLE=plain` だと背景のないインストール画面になる。
  `make-dmg.sh` はどちらの場合も止まる（デザインの実験時のみ `KRADO_UNSIGNED_DMG_OK=1`）。
- 証明書を作り直さない。Mac のキーチェーンに証明書を入れるのはメンテナーの OK が要る。
- タグ・リリース・公開はメンテナーの OK が要る。`trial_version` の実行はアーティファクト
  （7日で消える）しか作らない。

## バージョンと実際の更新確認

メンテナーが確認する試し版 DMG は毎回パッチ番号 `x.y.Z` を上げ、番号を再利用しない。
上の例も、すでに確認済みなら次の未使用番号に置き換える。
Mac の試し版は `0.1.13`、最新の公開版は `v0.1.5` の想定なので、次の公開版は
`0.1.14` 以上にする。タグを付ける前に `scripts/build-app.sh` の既定値
`version="${KRADO_VERSION:-…}"` もその番号に上げる。
次回からタグは `v` なしの `X.Y.Z`（SemVer 2.0.0）とし、公開済みの `v` 付きタグは変更しない。

更新確認は、Mac に入れた試し版より大きい番号の正式リリースを公開し、
その試し版の「アップデートを確認…」から実際の更新を受け取り、インストール後の番号を確かめる。
試し版と公開版は同じ Release ワークフローで作られ、bundle ID `io.github.kazinag.krado`、
`SUPublicEDKey`、EdDSA 署名鍵の secret、コード署名証明書、`SUFeedURL`
（`releases/latest/download/appcast.xml`）が共通。この URL はドラフトとプレリリースを無視する。
Sparkle は `build-app.sh` がバージョン番号に設定する `CFBundleVersion` を比較する。

この更新確認が必要なのは、Sparkle、appcast/feed、EdDSA 鍵、コード署名証明書、bundle ID
など更新・署名に変更があるリリースの前だけで、毎回のリリース前ではない。
詳細は [実際の更新確認](signing-and-update-test.md#checking-a-real-update) を参照。
