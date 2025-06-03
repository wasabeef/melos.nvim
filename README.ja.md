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

- 現在のプロジェクトの `melos.yaml` を解析し、定義されているスクリプトを抽出します。
- スクリプト名と、任意で設定された説明を `telescope.nvim` のインターフェースに分かりやすく一覧表示します。
- 選択されたスクリプトはカスタマイズ可能なフローティングターミナルで実行され、リアルタイムで出力を確認できます。
- 特定のスクリプトの定義箇所へ `melos.yaml` を開いてジャンプできます。
- プロジェクトの `melos.yaml` を素早く開けます。

## 要件

- Neovim >= 0.7
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `yq` コマンドラインツール (`melos.yaml` の解析に必要)
  - インストール方法は [yq のドキュメント](https://github.com/mikefarah/yq/#macos--linux-via-homebrew) を参照してください。

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
    })
  end,
}
```

## 使い方

このプラグインは以下のコマンドを提供します:

### `:MelosRun`

`melos.yaml` に定義されているスクリプトを `telescope.nvim` ピッカーに表示します。
スクリプトを選択して `<Enter>` を押すと、対応する `melos` コマンドがフローティングターミナルで実行されます。

```vim
:MelosRun
```

### `:MelosEdit`

`melos.yaml` に定義されているスクリプトを `telescope.nvim` ピッカーに表示します。
スクリプトを選択すると、`melos.yaml` が開き、選択したスクリプトの定義位置にカーソルが移動します。

```vim
:MelosEdit
```

### `:MelosOpen`

現在のプロジェクトの `melos.yaml` ファイルを直接開きます。

```vim
:MelosOpen
```

### キーマッピング例

```lua
-- init.lua または関連する設定ファイル内
vim.keymap.set('n', '<leader>mr', '<Cmd>MelosRun<CR>', { desc = 'Melos スクリプトを実行' })
vim.keymap.set('n', '<leader>me', '<Cmd>MelosEdit<CR>', { desc = 'melos.yaml で Melos スクリプトを編集' })
vim.keymap.set('n', '<leader>mo', '<Cmd>MelosOpen<CR>', { desc = 'melos.yaml を開く' })
```

## 設定

`setup` 関数を通じて以下のオプションを設定できます。

- `terminal_width` (数値, デフォルト: `100`): スクリプト実行時に開くフローティングターミナルの幅 (文字数)。
- `terminal_height` (数値, デフォルト: `30`): スクリプト実行時に開くフローティングターミナルの高さ (行数)。

例:

```lua
require("melos").setup({
  terminal_width = 120,
  terminal_height = 40,
})
```

## トラブルシューティング

- **`yq: command not found` のようなエラーが表示される場合:**
  - このプラグインは `melos.yaml` の解析に `yq` コマンドラインツールを使用します。
  - システムに `yq` がインストールされているか確認してください。インストールされていない場合は、[公式 yq ドキュメント](https://github.com/mikefarah/yq/#macos--linux-via-homebrew) に従ってインストールしてください。
- **`melos: command not found` のようなエラーが表示される場合:**
  - このプラグインは `melos` コマンドを直接実行します。
  - システムに `melos` がグローバルインストールされているか、またはプロジェクトの `dev_dependencies` に含まれていて実行可能になっているか (例: `dart pub global run melos` や `flutter pub global run melos` 経由) を確認してください。
  - インストール方法は [公式 Melos ドキュメント](https://melos.invertase.dev/getting-started) を参照してください。

## 貢献

バグ報告、機能リクエスト、プルリクエストはいつでも歓迎します。お気軽に Issue を作成したり、プルリクエストを送ってください。

## ライセンス

`melos.nvim` は MIT ライセンスのもとでリリースされています。詳細は `LICENSE` ファイルを参照してください。
