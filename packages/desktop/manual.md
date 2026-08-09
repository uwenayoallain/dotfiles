# Apps installed by hand on the old machine

These are on the current PC but were installed from a downloaded file rather
than a repository, so `install.sh` cannot fetch them reliably — the download
URLs are version-pinned and change with every release. Grab the current build
from the vendor page after the automated install finishes.

| App | Where it came from | Notes |
| --- | --- | --- |
| RStudio Desktop | <https://posit.co/download/rstudio-desktop/> | Needs `r-base`, which the `dev` tier installs. |
| OpenCode desktop (`opencode`, `open-code` debs, `/opt/OpenCode`) | <https://opencode.ai> | The `opencode` **CLI** is installed automatically via bun; only the desktop build is manual. The `.desktop` launcher override is already stowed from `applications/`. |
| Zen Browser (`/opt/zen`) | <https://zen-browser.app/download/> | Tarball extracted to `/opt/zen`; the `.desktop` entry is stowed from `applications/`. |
| Waterfox | <https://www.waterfox.net/download/> | |
| Android Studio (`/opt/android-studio`) | <https://developer.android.com/studio> | `install.sh --only sdk` installs this automatically; listed here only for reference. |
| Recordly AppImage | vendor download | Lives in `~/Applications`; AppImageLauncher registers it. |
| Terax AppImage | vendor download | Lives in `~/Applications`. |
| T3 Code AppImage | <https://t3.chat> | Lives in `~/Applications`; the `t3code.service` user unit is stowed from `systemd/`. |
| ScreenRec | <https://screenrec.com> | Repo is present in `sources.list.d` on the old machine but no package is currently installed. |

## Not tracked on purpose

`appimagelauncherd.service` is **not** in the `systemd/` stow package. The unit
ships with the AppImageLauncher package and is enabled as a symlink into
`/opt/appimagelauncher.AppDir/`, so a tracked copy would both conflict with
stow and hardcode a path that belongs to the vendor. Installing the package
(the `desktop` tier does this) sets it up.

## Accounts and licences to re-enter

TablePlus licence key, AnyDesk unattended-access password, ngrok authtoken,
Tailscale login, GitHub CLI login, and the AI CLI logins (Claude, Codex,
Gemini, OpenCode, Cursor Agent, CodeRabbit).
