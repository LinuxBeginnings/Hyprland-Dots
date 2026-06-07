# yatline-githead.yazi

Manual clone of [githead.yazi](https://github.com/llanosrocas/githead.yazi) for supporting [yatline.yazi](https://github.com/imsi32/yatline.yazi)

> [!IMPORTANT]
> This repository will not add new features other than coming from original repository.  
> The latest commit in there is 317d09f728928943f0af72ff6ce31ea335351202.
> Which can be found in [here](https://github.com/llanosrocas/githead.yazi/commit/317d09f728928943f0af72ff6ce31ea335351202)

All supported features are listed [here](#features)

## Requirements

- yazi version >= 25.5.28.
- Font with symbol support. For example [Nerd Fonts](https://www.nerdfonts.com/).
- [yatline.yazi](https://github.com/imsi32/yatline.yazi) (Mandatory)

> [!IMPORTANT]
> Recommended to use [githead.yazi](https://github.com/llanosrocas/githead.yazi), if you are not using yatline.yazi

## Installation

```sh
ya pkg add imsi32/yatline-githead
```

## Usage

Add this to your `~/.config/yazi/init.lua`, after yatline.yazi configuration:

```lua
require("yatline-githead"):setup()
```

### Default Configuration

```lua
require("yatline-githead"):setup({
  order = {
    "branch",
    "remote",
    "tag",
    "commit",
    "behind_ahead_remote",
    "stashes",
    "state",
    "staged",
    "unstaged",
    "untracked",
  },

  show_numbers = true, -- shows staged, unstaged, untracked, stashes count

  show_branch = true,
  branch_prefix = "",
  branch_color = "blue",
  branch_symbol = "",
  branch_borders = "",

  show_remote_branch = true, -- only shown if different from local branch
  always_show_remote_branch = false, -- always show remote branch even if it the same as local branch
  always_show_remote_repo = false, -- Adds `origin/` if `always_show_remote_branch` is enabled
  remote_branch_prefix = ":",
  remote_branch_color = "bright magenta",

  show_tag = true, -- only shown if branch is not available
  always_show_tag = false,
  tag_color = "magenta",
  tag_symbol = "#",

  show_commit = true, -- only shown if branch AND tag are not available
  always_show_commit = false,
  commit_color = "bright magenta",
  commit_symbol = "@",

  show_behind_ahead_remote = true,
  behind_remote_color = "bright magenta",
  behind_remote_symbol = "⇣",
  ahead_remote_color = "bright magenta",
  ahead_remote_symbol = "⇡",

  show_stashes = true,
  stashes_color = "bright magenta",
  stashes_symbol = "$",

  show_state = true,
  show_state_prefix = true,
  state_color = "red",
  state_symbol = "~",

  show_staged = true,
  staged_color = "bright yellow",
  staged_symbol = "+",

  show_unstaged = true,
  unstaged_color = "bright yellow",
  unstaged_symbol = "!",

  show_untracked = true,
  untracked_color = "blue",
  untracked_symbol = "?",
})
```

### Theme

You can also use a [theme](https://github.com/imsi32/yatline-themes):

```lua
local your_theme = {
  branch_color = "blue",
  remote_branch_color = "bright magenta",
  tag_color = "magenta",
  commit_color = "bright magenta",
  behind_remote_color = "bright magenta",
  ahead_remote_color = "bright magenta",
  stashes_color = "bright magenta",
  state_color = "red",
  staged_color = "bright yellow",
  unstaged_color = "bright yellow",
  untracked_color = "blue",
}

require("yatline-githead"):setup({
-- ===
    
  theme = your_theme,

-- ===
})
```

### Adding as a Component

If you are using yatline.yazi, you can use this component:

``` lua
-- ===

  {type = "coloreds", custom = false, name = "githead"},

-- ===
```

``` text
/cwd on ( feature):origin/main #v1.0.0 #1234567 ⇣2⇡3 $1 rebase 1/2 ~2 +4 !1 ?5
|    |   |  |     ││ |     |    |       |        | |  |  |          |  |  |  |
|    |   |  |     ││ |     |    |       |        | |  |  |          |  |  |  └─── untracked_symbol
|    |   |  |     ││ |     |    |       |        | |  |  |          |  |  └────── unstaged_symbol
|    |   |  |     ││ |     |    |       |        | |  |  |          |  └───────── staged_symbol
|    |   |  |     ││ |     |    |       |        | |  |  |          └──────────── state_symbol
|    |   |  |     ││ |     |    |       |        | |  |  └─────────────────────── state_prefix
|    |   |  |     ││ |     |    |       |        | |  └────────────────────────── stashes_symbol
|    |   |  |     ││ |     |    |       |        | └───────────────────────────── ahead_symbol
|    |   |  |     ││ |     |    |       |        └─────────────────────────────── behind_symbol
|    |   |  |     ││ |     |    |       └──────────────────────────────────────── commit_symbol
|    |   |  |     ││ |     |    └──────────────────────────────────────────────── tag_symbol
|    |   |  |     ││ |     └───────────────────────────────────────────────────── remote_branch
|    |   |  |     ││ └─────────────────────────────────────────────────────────── remote_repo
|    |   |  |     |└───────────────────────────────────────────────────────────── remote_branch_prefix
|    |   |  |     └────────────────────────────────────────────────────────────── branch_borders
|    |   |  └──────────────────────────────────────────────────────────────────── branch
|    |   └─────────────────────────────────────────────────────────────────────── branch_symbol
|    └─────────────────────────────────────────────────────────────────────────── branch_prefix
└──────────────────────────────────────────────────────────────────────────────── cwd
```

## Features

- [x] Current branch
- [x] Remote and remote branch
- [x] Latest tag
- [x] Latest commit
- [x] Behind/Ahead of the remote
- [x] Stashes
- [x] States
  - [x] merge
  - [x] cherry
  - [x] rebase (+ done counter)
  - [x] revert
  - [x] bisect
- [x] Staged
- [x] Unstaged
- [x] Untracked

### Under the hood

The goal is to use minimum amount of shell commands.

- Branch, stashes, staged files, unstaged files, untracked files.

```shell
git status --ignore-submodules=dirty --branch --show-stash --ahead-behind
```

- Remote branch and repo:

```shell
git rev-parse --abbrev-ref --symbolic-full-name @{upstream}
```

- Latest tag and commit:

```shell
git log --format="commit %h%d" -n 1
```

## Credits

- [githead.yazi](https://github.com/llanosrocas/githead.yazi)
- [yazi source code](https://github.com/sxyazi/yazi)
- [powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [twio142](https://github.com/twio142/githead.yazi)
