# OpenApp

## Overview

OpenApp is a simple macOS application designed to launch or focus applications using global hotkeys like [rcmd](https://lowtechguys.com/rcmd). It runs in the background, listening for specific key combinations, and responds by opening or bringing to the foreground the associated application.

## Features

*   **Global Hotkeys:** Define custom global hotkeys to launch or focus applications.
*   **Configuration File:** Uses a JSON configuration file for easy customization of hotkeys and application mappings.
*   **Lightweight:** Minimal resource usage, designed to run unobtrusively in the background.
*   **Open at Login:** Option to automatically launch OpenApp when the user logs in.


## Configuration

OpenApp uses a JSON file named `openapp_config.json` to store its configuration. This file is located in the Application Support directory: `~/Library/Application Support/OpenApp/`.

### Example Configuration
```
{
  "trigger": "rightCommand", // Options: rightCommand, leftCommand, rightShift, leftShift, rightOption, leftOption, rightControl, leftControl
  "a": "Safari",
  "m": "Mail",
  "c": "Calendar"
}
```
*   `trigger`: Specifies the modifier key that must be pressed along with the character key.
*   `[character]`: Specifies the application to launch or focus when the modifier key and the character key are pressed together.

### Editing the Configuration

You can edit the configuration file directly using a text editor. OpenApp provides a menu item to open the configuration file in the default editor.

*Happy Coding!*
