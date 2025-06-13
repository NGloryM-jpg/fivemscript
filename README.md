# AimShield FiveM Script

**AimShield** is an advanced anti-aimbot detection solution designed exclusively for FiveM servers. It detects cheats such as aimbot, silent aimbot, and aimlock in real time and provides detailed logs so you can take informed action to maintain fair gameplay.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Support](#support)
- [License](#license)

## Overview

AimShield is built to protect your FiveM server by detecting common cheating methods. While it does not automatically block cheaters, it provides instant alerts and comprehensive logs to help you maintain control of your server. All packages (1 Week, 1 Month, Lifetime) offer robust detection features to ensure a fair gaming environment.

## Installation

1. **Download the Script:**  
   After purchasing a package via our Tebex store, download the AimShield script from your account.

2. **Place the Script:**  
   Copy the downloaded AimShield folder into your server's `resources` directory.

3. **Server Configuration:**  
   Add the following line to your `server.cfg` file to ensure the script starts when your server boots up:
   ```plaintext
   ensure init-Frost
   ```
   Make sure that the resource name in your `server.cfg` matches the folder name.

4. **Dependencies:**  
   AimShield requires the following resources:
   - **Screenshot-Basic:** Essential for capturing evidence during cheat detection.
   - **txAdmin:** Recommended for seamless server management and to enable in-game menu permissions and notifications.  
   - **Custom Permissions:** Alternatively, you can use custom permissions by adding Discord IDs directly in the configuration. This allows you to manage permissions without txAdmin.

## Configuration

- **Configuration Method:**  
  AimShield is configured through the web dashboard:
  - Main settings: [aimshield.xyz/login](https://aimshield.xyz/dashboard/settings)
  - Database settings: [aimshield.xyz/login](https://aimshield.xyz/dashboard/settings/database)

  All configuration is now managed through the web interface for easier management and updates.

- **Adjust Settings:**  
  Modify detection thresholds, logging options, and other parameters through the web dashboard. Detailed instructions are provided in the documentation included with the resource.

## Usage

- **Real-Time Monitoring:**  
  Once installed, AimShield will automatically begin monitoring your server for suspicious activity. When a cheat is detected, you will receive instant alerts along with detailed logs.

- **Log Review:**  
  Use the log files (discord webhook link) or the in-game admin panel to review detected incidents and take appropriate action.

- **Updates:**  
  AimShield is regularly updated to handle new cheating methods. Always check our website [aimshield.xyz](https://aimshield.xyz) or our support channels for the latest releases and update instructions.

## Troubleshooting

- **Script Fails to Start:**  
  Ensure the script folder is correctly placed in the `resources` directory and that your `server.cfg` includes the correct `ensure init-Frost` command.

- **Logging Issues:**  
  Verify that the log file path (discord webhook link) exists and that your server has the necessary write permissions.

## Support

For any questions or assistance, please reach out to us:

- **Email:** aimshield2025@gmail.com
- **Discord:** [Join our Discord server](https://discord.gg/aimshield)

For more details, updates, and documentation, please visit our website at [aimshield.xyz](https://aimshield.xyz).
