# 試し版 DMG の作り方

メンテナーに渡す試し版（`~/Downloads/krado-test.dmg`）は、毎回この手順で作ります。
リリースと同じデザインの DMG を作り、同じ「krado Self-Signed」証明書で署名するので、
入れ替えてもアクセシビリティの許可が引き継がれ、一覧に krado が増えません。

## 手順

1. 試したいコミットを `main`（または作業ブランチ）に push する。
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
