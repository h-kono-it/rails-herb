# 開発ドキュメント

## 構成

| | バージョン |
|---|---|
| Ruby | 3.4.11 |
| Rails | 8.1.4（importmap / Turbo / Stimulus / Propshaft / SQLite） |
| reactionview | 0.6.0 |
| herb | 0.11.0 |

Rails 8.1 には Herb のテンプレートエンジンが入っていないので、ReActionView が持ち込んでいる。`config/initializers/reactionview.rb` で次を有効にしている。

- `intercept_erb = true`：すべての `.html.erb` を `Herb::Engine` でコンパイルする（Rails 8.2 の標準と同じ状態）
- `slots = true`：リアクティブテンプレート（`herb:state`、`data-herb-*` アクション、サーバーへの再取得）を使う

`.herb.yml` は `framework: actionview` にしてある。Herb linter の ActionView 向けルールが効く。

## 主なファイル

```
app/models/
  network.rb, node.rb, link.rb   道路網のデータ（DB）
  simulation.rb                  道路網のシミュレーション本体
  signal_plan.rb                 固定サイクルの信号
  ring_road.rb, intersection.rb  初期に作った環状道路・単独交差点のモデル
app/controllers/
  networks_controller.rb         道路網の画面（state を読んでシミュレーションを回す）
  nodes_controller.rb            流入量・信号設定の保存（PATCH）
  links_controller.rb            進行方向の重み・右折レーンの保存（PATCH）
app/views/networks/show.html.erb 道路網の画面
app/helpers/networks_helper.rb   地図上の座標計算、表示名（A, B… / 西1…）
app/javascript/controllers/
  autoplay_controller.js         自動再生（step を一定間隔で進める）
  autosave_controller.js         スライダーを離したら保存して再描画
app/assets/stylesheets/
  traffic.css                    共通の色・部品
  network.css                    道路網の画面
```

## データモデル

座標は 0〜60 の格子（`Network::SIZE`）。1マスが車1台分のセル。

| モデル | 主な列 | 意味 |
|---|---|---|
| `Network` | `name` | 道路網 |
| `Node` | `x`, `y` | 交差点か道路の端。つながっている相手が1つだけなら「端」とみなす（列では持たない） |
| | `signalized` | 信号の有無 |
| | `cycle`, `split`, `offset` | 信号の1周（ステップ）、東西に回す青の割合（%）、開始のずらし（ステップ） |
| | `inflow` | 端のとき、100ステップあたりに入ってくる台数 |
| `Link` | `from_node`, `to_node` | 一方通行の1車線。双方向の道路は2本（`Network#connect`） |
| | `speed_limit` | 最高速度（1〜5） |
| | `left_weight`, `straight_weight`, `right_weight` | 行き先の交差点で曲がる方向の重み |
| | `right_turn_lane` | 交差点手前の右折専用レーンの長さ（セル、0 でなし） |

長さは2つのノードの距離をセル数に丸めたもの。

## シミュレーション（`Simulation`）

DB には触らない。`Network#graph` が `Simulation::Graph`（`Data` の Node / Link）に変換して渡す。

各ステップの流れ：

1. 車線ごとに Nagel–Schreckenberg のルールで速度を決める（1加速 → 前との間隔で減速 → 確率 `slowdown` でランダムに1減速 → 前進）
2. 車線の端を越える車は、交差点を「長さゼロの点」として次の車線へ移る。同じ車線に入ろうとする車は、左折 → 直進 → 右折の順（同じ種類どうしはランダム）に1台ずつ入れる。入れなかった車は手前の車線の端で待つ
3. 道路の端では `inflow` の確率で車が来る。入口が詰まっているときは外で待たせる（入口待ち）

交差点でのルール：

- **行き先**：車線に入った時点で、その先の交差点で曲がる方向を重みで選ぶ。重みは実際に行ける方向だけで按分する。来た道に戻るのは、ほかに道がないときだけ
- **信号**：交差点ごとの `SignalPlan`。左右方向に走る車線は東西の現示、それ以外は南北の現示に従う。青 → 黄（2）→ 全赤（2）の繰り返し
- **右折**：左側通行なので右折は対向車線を横切る。対向の直進・左折車がそのステップで交差点に入ってくるなら、停止線で待つ。黄信号では対向車が止まっているので、停止線で待っていた右折車は曲がれる
- **右折専用レーン**：車線の最後の N セルを2車線にする。右折車はそこで待つので、後ろの直進・左折車を止めない。レーンが埋まっていれば本線で待つ。レーンが空なら、着いたステップでそのまま曲がれる。車線の始めの 6 セル（`POCKET_CLEARANCE`）にはレーンを作らない

乱数は seed で固定していて、同じ入力なら必ず同じ結果になる。画面は毎リクエストでステップ 0 から再計算しているので、上限を 2000 ステップ（`NetworksController::MAX_STEPS`）にしている。

## 画面と ReActionView

`networks/show.html.erb` は server mode のリアクティブテンプレート。

```erb
<%# herb:state (step: 0, junction: 0, panel: "traffic", slowdown: 15, seed: 1, playing: false) %>
```

- ボタンは `data-herb-increment="step"`、`data-herb-toggle="playing"`、`data-herb-set="panel=junction"` のような属性だけで state を変える
- state が変わると、クライアントが同じ URL に `?format=slots` で問い合わせる。state は `Herb-State` ヘッダーに、テンプレートごとに入る（`{"app/views/networks/show.html.erb": {...}}`）。コントローラーは `herb_state("step", 0)` で読む
- サーバーは変わった部分の値だけを返して、クライアントがその場で差し替える

流入量や重みなどの**道路網の設定は DB に保存する**。state で持たない理由：

- state に持てるのは Boolean / String / Integer だけ
- ヘッダーの上限が 8KB
- 同じ partial を複数描画したときの state の扱いに未解決の不具合がある（marcoroth/reactionview#189）

保存は `autosave` コントローラーが `PATCH` してから `Runtime.get().refresh()` を呼んで再描画する。シミュレーションは止まらない。

## ReActionView で気をつけること

このプロジェクトで実際に踏んだもの。

1. **state の値をクライアントが計算できる形で読むと、サーバーに問い合わせない。** `<%= step %>` だけだと、数字はローカルで変わるが `@simulation` は再計算されない。サーバーで計算したい state は `<%= number_with_delimiter(step) %>` のようにヘルパー経由で読む。linter の `herb-state-valid-reads` が指摘するので `<%# herb:disable herb-state-valid-reads %>` を付ける
2. **`<% %>`（コードタグ）での代入などに使った読み取りは依存として扱われない。** `<% selected = selected_junction(nodes, junction) %>` だけでは、`junction` が変わってもサーバーに問い合わせない。出力タグ（`<%= %>`）でも読むこと。`<% if panel == "junction" %>` のような条件は追跡される
3. **ループには必ず `herb:key` を付ける。** key がない一覧は server mode で一切更新されない（marcoroth/herb#2812）。タブの中身のように、あとからサーバーで描かれる部分も同じ
4. **`herb:key` はループの直下に置く。** `if` の中に置くと黙って無視される。条件で絞りたいときは、先に `select` してからループする
5. **`<svg>` の中に、あとから要素を追加しない。** HTML の名前空間で作られて描画されない（marcoroth/herb#2811）。動くものは絶対配置した HTML 要素で描く
6. **`stylesheet_link_tag :app` は使えない。** slots が有効だと `stylesheet_path(:app)` に書き換えられて 500 になる（marcoroth/herb#2754）。レイアウトではファイル名を列挙している
7. **`data-herb-set` で複数の state を変えるときはスペース区切り。** `"junction=3 panel=junction"`。カンマ区切りは開発ツールが `herb-invalid-action` で指摘する
8. **表の行に入るのは `Simulation::Node` などの `Data`。** パスヘルパーには `node_path(node.id)` のように ID を渡す
9. **Stimulus の `connect` ですぐ `useState` を呼ばない。** Turbo でページを移った直後は ReActionView がまだ新しいページを読んでいなくて、前のページの state に結びつく。`autoplay_controller.js` は次のタスクまで待ってからつないでいる
10. **Turbo のスナップショットキャッシュは無効にしている**（`turbo-cache-control: no-cache`）。戻ってきたページで古い `playing` がよみがえるため

開発中は画面右上に Herb の開発ツールが出る。テンプレートの不正な入れ子、無効なアクション、N+1 クエリなどをそこで教えてくれる。

## テストとチェック

```sh
bin/rails test           # モデルとコントローラー
bin/rails test:system    # ヘッドレス Chrome での画面テスト
bin/rubocop
npx @herb-tools/linter app/views
bin/brakeman
```

CI（`.github/workflows/ci.yml`）でも同じものが走る。

シミュレーションのテストは、衝突しない、台数が保存される、赤で交差点を抜けない、同じ seed なら同じ結果、などの不変条件を数百〜千ステップ回して確かめている。挙動を変えたときは、乱数を固定して「変更前と後」を数字で比べるとよい。

## upstream に関係するもの

| | 状態 |
|---|---|
| marcoroth/herb#2754 `stylesheet_link_tag :app` の書き換え | 既存の issue |
| marcoroth/herb#2811 `<svg>` 内に追加した行の名前空間 | 報告済み |
| marcoroth/herb#2812 key なしの一覧が更新されない | 報告済み |
| #5 `if` の中の `herb:key` が無視される | 下書き（このリポジトリ） |
| #6 linter が state と同じ名前なだけのものを誤判定する | 下書き（このリポジトリ） |
| #7 Turbo 遷移直後の `useState` が前のページに結びつく | 下書き（このリポジトリ） |
