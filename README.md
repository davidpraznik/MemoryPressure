# Memory Pressure

A small macOS menu bar app that shows CPU use, RAM use and memory pressure. It warns you when memory pressure gets high and can free inactive memory with one click.

## What it shows

- CPU and RAM use in the menu bar, updated every two seconds.
- A popup with CPU, RAM (used and total), a 30 minute memory pressure chart with your limit marked on it, and the apps using the most memory, each with a quit button.
- Optional modules for GPU, disk, network and fans. Fans appear only on Macs that have one.

## Features

- **Reminder:** a card appears at the top right of the screen when memory pressure reaches your limit. It names the app using the most memory and offers to quit it or clear the cache.
- **Auto clear:** can clear memory by itself when the limit is reached, at most once every 10 minutes. It needs the passwordless rule described below.
- **Clear memory:** frees inactive memory (runs `purge`, which needs administrator rights). The button asks for your password, unless the passwordless rule is set up.
- **Limits:** memory pressure limit and CPU limit are set in Settings.
- **Accent colour:** multicolour or a single colour of your choice.
- **Language:** English or Slovenian.
- **Launch at login.**

## Memory pressure and RAM are not the same

macOS fills free RAM with cached files on purpose, so a high RAM percentage is normal. Memory pressure shows how hard macOS is working to free memory, and that is what the reminder uses.

## Requirements

macOS 14.6 or newer. Runs on Apple silicon and Intel Macs.

## Install

1. Download `MemoryPressure.zip` from the [latest release](https://github.com/davidpraznik/MemoryPressure/releases/latest) and unzip it.
2. Move `MemoryPressure.app` to your Applications folder.
3. Open it. macOS will warn that the app cannot be checked for malicious software, because it is not notarized. To open it anyway, go to System Settings, Privacy & Security, scroll down and click **Open Anyway**.

Alternatively, remove the quarantine flag in Terminal:

    xattr -dr com.apple.quarantine /Applications/MemoryPressure.app

## Clearing memory without a password

`purge` needs administrator rights. By default the Clear memory button shows the macOS password prompt every time, and Auto clear does nothing, because it cannot ask for a password.

To allow `purge` without a password, add a sudoers rule that covers only this one command. Run in Terminal:

    echo "$USER ALL=(root) NOPASSWD: /usr/sbin/purge" | sudo tee /etc/sudoers.d/memorypressure
    sudo chmod 440 /etc/sudoers.d/memorypressure
    sudo visudo -cf /etc/sudoers.d/memorypressure

The last command checks the syntax and should print `parsed OK`. If it reports an error, remove the file with `sudo rm /etc/sudoers.d/memorypressure` and try again.

To undo the rule later:

    sudo rm /etc/sudoers.d/memorypressure

## Build from source

Open `MemoryPressure.xcodeproj` in Xcode and run the `MemoryPressure` scheme.

## Author

© 2026 David Praznik
