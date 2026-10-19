![krado — ウインドウをドラッグして、マス目に置くだけ。](docs/assets/cover.ja.png)

# krado

[English](README.md) | 日本語 · [変更履歴](CHANGELOG.ja.md)

<strong>ウインドウをドラッグして、マス目に置くだけ。</strong> krado は、macOS のウインドウを並べるメニューバーの小さなアプリです。設定は要りません。画面ごとに合ったマス目を自動で選びます。MacBook から、大きな画面や縦置きの画面まで使えます。

無料のオープンソースです（MIT ライセンス）。

![ウインドウをドラッグしてマス目に置く](docs/assets/demo/drag-snap.gif)

## 画面に合わせたマス目

Microsoft PowerToys の FancyZones に着想を得ています。krado はマス目を自動で作ります。決まりは1つだけで、どのマスも幅 640 pt・高さ 720 pt 以上になる間、画面を横と縦に半分ずつ分けていきます。そのため列は 1・2・4・8、段は 1・2・4 のどれかです。MacBook の内蔵画面は上下に分けず、一般的な 4K ディスプレイでも横は最大 4 列です。

<strong>システム設定 → ディスプレイ</strong>で選んでいる画面全体の大きさで決めるので、Dock やメニューバーを出し入れしてもマス目は変わりません。内蔵の画面も外付けの画面も、同じ決まりです。

| 画面 | マス目 | たとえば |
| --- | --- | --- |
| MacBook | <strong>2 × 1</strong> | 標準の大きさで使っている MacBook Air / Pro の画面 |
| フル HD クラス | <strong>2 × 1</strong> | 1920 × 1080、標準の大きさで使う 4K |
| 1440p クラス | <strong>4 × 2</strong> | 2560 × 1440、標準の大きさで使う 5K・6K、等倍で使う 4K |
| とても高い解像度 | <strong>8 × 4</strong> | 等倍で使う 5K・6K・8K |
| 縦置き | <strong>1 × 2</strong> または <strong>2 × 4</strong> | 1080 × 1920、縦向きにして等倍で使う 4K |
| ウルトラワイド | <strong>4 × 1</strong>〜<strong>8 × 2</strong> | 2560 × 1080 → 4 × 1、3440 × 1440 → 4 × 2、5120 × 1440 → 8 × 2 |
| 小さい画面 | <strong>1 × 1</strong> | 幅が 1280 pt より狭い横長の画面 |

![MacBook Air・1920 × 1080・2560 × 1440・等倍の 4K と 8K・縦置き 4K・ウルトラワイドのマス目](docs/assets/layouts.ja.png)

## 使い方

ウインドウのタイトルバーをドラッグします。ポインタのある画面にマス目が出るので、光っているマスで離すと、そこにぴったり収まります。マスの境目の近くでは、両側のマスにまたがります。

| 操作 | 見本 |
| --- | --- |
| <strong>Shift + ドラッグ</strong> — なぞったマスをまとめて覆います。 | ![Shift + ドラッグで複数のマスにまたがる](docs/assets/demo/shift-drag.gif) |
| <strong>Option を押したままドラッグ</strong> — 押している間だけマス目が消えます。Option を離すとマス目が戻るので、途中で決め直せます。 | ![Option + ドラッグでマス目を無視](docs/assets/demo/option-drag.gif) |
| <strong>ドラッグ中に Esc を一度押す</strong> — キーを離しても、そのドラッグの間はマス目が出ません。途中でやめたくなったとき用です。 | ![Esc でマスに収めるのを取り消す](docs/assets/demo/esc-cancel.gif) |
| <strong>キーボード</strong> — <strong>⌃⌘ + 矢印</strong>で、操作中のウインドウを1マス動かします（端では隣の画面へ）。<strong>⌃⌘⇧ + 矢印</strong>で広げ、反対向きの矢印で縮めます。 | ![キーボードで動かす・広げる・縮める](docs/assets/demo/keyboard.gif) |

メニューバーのアイコンで、krado が動いているかが分かります。メニューには<strong>ログイン時に起動</strong>（自分でオンにするまではオフです。最初の案内画面からワンクリックでオンにできます）と<strong>アップデートを確認…</strong>があります。アップデートは自動で確認し、入れる前に必ず聞きます。

## インストール

macOS 14 以降で使えます。

1. [Releases](https://github.com/KazinaG/krado/releases) から `krado-x.y.z.dmg` をダウンロードして開き、<strong>krado</strong> を<strong>「アプリケーション」</strong>へドラッグします。
2. krado を開きます。krado は Apple のノータリゼーション（公証）を受けていないため、初めて開くときだけ macOS が止めます。この手順は一度だけで、アップデートのあとはそのまま開けます。
   - <strong>macOS 15 以降：</strong><strong>「“krado.app”は開いていません」</strong>と出たら<strong>「完了」</strong>を押します。<strong>システム設定 → プライバシーとセキュリティ</strong>を開いて<strong>「セキュリティ」</strong>まで下にスクロールし、krado についての表示の横にある<strong>「このまま開く」</strong>を押して、パスワードで確かめます。このボタンは、krado を開こうとしてから約1時間表示されます。macOS 15 以降では、Control キーを押しながらクリックして「開く」を選ぶ方法は使えません。
   - <strong>macOS 14：</strong>「アプリケーション」の krado を Control キーを押しながらクリックし、<strong>「開く」</strong>を選んで、もう一度<strong>「開く」</strong>を押します。
3. krado に聞かれたら、<strong>アクセシビリティ</strong>を許可します。ほかのアプリのウインドウを動かしたり大きさを変えたりするのに必要です。許可すると krado が自動で気づきます。

リリースは毎回同じ証明書で署名しているので、アップデートしてもアクセシビリティの許可はそのまま使えます。それでももう一度求められたら、<strong>システム設定 → プライバシーとセキュリティ → アクセシビリティ</strong>で古い <strong>krado</strong> を削除し、新しい <strong>krado</strong> をオンにしてください。

## アンインストール

krado のメニューで<strong>アンインストール…</strong>を選びます。ログイン時の起動をオフにし、アクセシビリティの許可・設定・キャッシュを消してから、krado をゴミ箱に入れて終了します。

それができないとき（ディスクイメージから開いているときなど）は、<strong>システム設定 → 一般 → ログイン項目と機能拡張</strong>と<strong>プライバシーとセキュリティ → アクセシビリティ</strong>で <strong>krado</strong> を外し（選んで <strong>−</strong> を押します）、krado をゴミ箱に入れてください。

## プライバシー

krado が見るのは、マウスのドラッグ、ドラッグ中の Esc キー、krado 自身のショートカットだけです。ウインドウはアクセシビリティを通して動かします。入力した文字や画面の中身は見ません。Mac の外と通信するのは、GitHub から更新情報を取りにいくときだけです。

## 困ったとき

- <strong>ドラッグしてもマス目が出ない：</strong> krado のメニューで状態を確かめ、<strong>アクセシビリティ</strong>で krado がオンになっているか確認してから、krado を開き直してください。
- <strong>ウインドウがうまく収まらない：</strong> アプリによっては、ウインドウの大きさや位置を変えられないものがあります。krado はそのままにします。

## フィードバック

質問や不具合の報告は [GitHub Issues](https://github.com/KazinaG/krado/issues) へどうぞ。プルリクエストは受け付けていません。詳しくは [CONTRIBUTING.md](CONTRIBUTING.md) をご覧ください。

自分でビルドするには、`swift test` のあと `scripts/build-app.sh` を実行します（Swift 6 以降）。

## ライセンス

[MIT](LICENSE) © 2026 Kazina.
