# TDLib patches

`tdlib-ios6.patch` is the change set this project applies to the TDLib submodule. It existed only as
uncommitted modifications inside `third_party/tdlib/td` until it was captured here; an ordinary
`git submodule update` would have destroyed it without warning.

Base commit: `022d60202`. 22 files, 141 insertions, 85 deletions.

What it does: emulates thread-local storage for a toolchain that lacks it, and relaxes the socket
policy so a VoIP socket keeps the connection alive while the app is backgrounded.

Apply after checking the submodule out at the base commit:

    git -C third_party/tdlib/td apply ../patches/tdlib-ios6.patch

Verify the tree matches what the build expects:

    git -C third_party/tdlib/td diff --stat
