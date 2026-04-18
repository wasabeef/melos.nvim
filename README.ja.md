# melos.nvim

<div align="center">
  <p>
    <a href="https://github.com/wasabeef/melos.nvim/releases/latest">
      <img alt="Latest release" src="https://img.shields.io/github/v/release/wasabeef/melos.nvim" />
    </a>
    <a href="https://codeassist.google/">
      <img alt="Gemini AI" src="https://img.shields.io/badge/Gemini%20AI-Code%20Assist-4796E3?style=flat&logo=google%20gemini&logoColor=white" />
    </a>
  </p>
  <p>
    <a href="README.md">English</a>
  </p>
</div>

`melos.nvim` は、Dart / Flutter プロジェクトのためのモノレポ管理ツールである [melos](https://melos.invertase.dev/) によって定義されたスクリプトを簡単に一覧表示し、実行することができる Neovim プラグインです。

https://github.com/user-attachments/assets/e69f5d74-9080-490e-b21f-d68502987f89

## 機能

- **melos 6.x** (`melos.yaml`) と **melos 7.x** (`melos:` キーを持つ `pubspec.yaml`) の両方を自動検出します。
- plain string / `run` / `steps` / `exec` (オブジェクト形式含む、`env`・`packageFilters` 付き) すべてのスクリプト形式を解析します。
- スクリプト名と説明を `telescope.nvim` のインターフェースに一覧表示します。説明が無い場合は自動生成されたフォールバック文字列が表示されます。
- 選択されたスクリプトはカスタマイズ可能なフローティングターミナルで実行され、リアルタイムで出力を確認できます。
- `:MelosEdit` で config ファイル内のスクリプト定義位置へ直接ジャンプできます。
- `:MelosOpen` で検出された config ファイルを素早く開けます。

## 要件

- Neovim >= 0.7
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `yq` コマンドラインツール (config ファイルの解析に必要)
  - インストール方法は [yq のドキュメント](https://github.com/mikefarah/yq/#macos--linux-via-homebrew) を参照してください。
- **melos 6.x**: プロジェクトルートに `melos.yaml` が存在すること
- **melos 7.x**: `pubspec.yaml` にトップレベルの `melos:` キーと `scripts:` セクションが存在すること

## インストール

お好みのプラグインマネージャーを使用してインストールしてください。

### lazy.nvim

```lua
{
  "wasabeef/melos.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("melos").setup({
      -- スクリプト実行時のフローティングターミナルのサイズを設定 (任意)
      -- terminal_width = 100, -- 幅 (文字数)
      -- terminal_height = 30, -- 高さ (行数)
      -- config_file = 'auto', -- 'auto' | 'melos.yaml' | 'pubspec.yaml'
    })
  end,
}
```

### packer.nvim

```lua
use {
  "wasabeef/melos.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("melos").setup({
      -- スクリプト実行時のフローティングターミナルのサイズを設定 (任意)
      -- terminal_width = 100,
      -- terminal_height = 30,
      -- config_file = 'auto',
    })
  end,
}
```

## 使い方

このプラグインは以下のコマンドを提供します:

### `:MelosRun`

検出された config ファイルに定義されているスクリプトを `telescope.nvim` ピッカーに表示します。
スクリプトを選択して `<Enter>` を押すと、対応する `melos` コマンドがフローティングターミナルで実行されます。

```vim
:MelosRun
```

### `:MelosEdit`

検出された config ファイルに定義されているスクリプトを `telescope.nvim` ピッカーに表示します。
スクリプトを選択すると、config ファイル (`melos.yaml` または `pubspec.yaml`) が開き、選択したスクリプトの定義位置にカーソルが移動します。

```vim
:MelosEdit
```

### `:MelosOpen`

現在のプロジェクトの検出された config ファイル (`melos.yaml` または `pubspec.yaml`) を直接開きます。

```vim
:MelosOpen
```

### キーマッピング例

```lua
-- init.lua または関連する設定ファイル内
vim.keymap.set('n', '<leader>mr', '<Cmd>MelosRun<CR>', { desc = 'Melos スクリプトを実行' })
vim.keymap.set('n', '<leader>me', '<Cmd>MelosEdit<CR>', { desc = 'config ファイルで Melos スクリプトを編集' })
vim.keymap.set('n', '<leader>mo', '<Cmd>MelosOpen<CR>', { desc = 'Melos config ファイルを開く' })
```

## 設定

`setup` 関数を通じて以下のオプションを設定できます。

- `terminal_width` (数値, デフォルト: `100`): スクリプト実行時に開くフローティングターミナルの幅 (文字数) 。
- `terminal_height` (数値, デフォルト: `30`): スクリプト実行時に開くフローティングターミナルの高さ (行数) 。
- `config_file` (文字列, デフォルト: `'auto'`): プラグインが読み取る config ファイルを制御します。
  - `'auto'`: 自動検出。`melos.yaml` が存在する場合はそれを使用し、なければ `melos:` キーを持つ `pubspec.yaml` を使用します。両方存在する場合は `melos.yaml` が優先され、警告が表示されます。
  - `'melos.yaml'`: 常に `melos.yaml` を使用します。ファイルが見つからない場合はエラーを表示します。
  - `'pubspec.yaml'`: 常に `pubspec.yaml` を使用し、`melos:` キーを必須とします。ファイルが見つからないかキーが存在しない場合はエラーを表示します。
  - 不正値を渡すと warning が通知され、`'auto'` に fallback します。

例:

```lua
require("melos").setup({
  terminal_width = 120,
  terminal_height = 40,
  config_file = 'auto',
})
```

## melos 7.x (pub workspaces) サポート

melos 7.x では設定が `pubspec.yaml` に統合されました。プラグインは `melos:` キーを自動検出します。`pubspec.yaml` の例:

```yaml
name: my_workspace
environment:
  sdk: '>=3.9.0'

melos:
  scripts:
    build:
      description: 'APK をビルド'
      run: flutter build apk
    check:
      steps:
        - dart analyze
        - dart format --set-exit-if-changed .
    format:
      exec: dart format .
      packageFilters:
        dirExists: lib
    ci:
      description: 'CI パイプライン'
      run: dart run ci_tool
      env:
        CI: 'true'
```

melos 7.x がサポートするすべてのスクリプト形式 (plain string / `run` / `steps` / `exec` (文字列またはオブジェクト)) と、オプションフィールド `env`・`packageFilters` を認識します。

## 制限事項

- **スクリプトグループ (melos 7.3+)**: ネストされた `scripts:` テーブルを持つエントリ (スクリプトグループ) は展開されません。ピッカーから除外され、スキップされたグループ名を示す集約警告通知が 1 回表示されます。グループの完全なサポートは将来のリリースで予定しています。
- **実行可能コマンドのないスクリプト**: `description` フィールドのみ (`run` / `steps` / `exec` なし) のスクリプトエントリはピッカーに表示されますが、実行できません。`:MelosRun` で選択すると警告が表示され、実行は中断されます。

## トラブルシューティング

- **`yq: command not found` のようなエラーが表示される場合:**
  - このプラグインは config ファイルの解析に `yq` コマンドラインツールを使用します。
  - システムに `yq` がインストールされているか確認してください。インストールされていない場合は、 [公式 yq ドキュメント](https://github.com/mikefarah/yq/#macos--linux-via-homebrew) に従ってインストールしてください。
- **`melos: command not found` のようなエラーが表示される場合:**
  - このプラグインは `melos` コマンドを直接実行します。
  - システムに `melos` がグローバルインストールされているか、またはプロジェクトの `dev_dependencies` に含まれていて実行可能になっているか (例: `dart pub global run melos` や `flutter pub global run melos` 経由) を確認してください。
  - インストール方法は [公式 Melos ドキュメント](https://melos.invertase.dev/getting-started) を参照してください。
- **`Neither melos.yaml nor pubspec.yaml(melos:) found in cwd` が表示される場合:**
  - 現在の作業ディレクトリに有効な config ファイルが見つかりませんでした。
  - melos 6.x の場合: プロジェクトルートに `melos.yaml` が存在するか確認してください。
  - melos 7.x の場合: `pubspec.yaml` にトップレベルの `melos:` キーと `scripts:` セクションが含まれているか確認してください。
- **`config_file = 'pubspec.yaml'` 使用時に `pubspec.yaml with melos: key not found` が表示される場合:**
  - `pubspec.yaml` が存在しないか、`melos:` キーが含まれていません。`melos:` セクションを追加するか、`config_file` を `'auto'` に戻してください。

## 貢献

バグ報告、機能リクエスト、プルリクエストはいつでも歓迎します。お気軽に Issue を作成したり、プルリクエストを送ってください。

## ライセンス

`melos.nvim` は MIT ライセンスのもとでリリースされています。詳細は `LICENSE` ファイルを参照してください。
