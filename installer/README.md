# ABS Platform Installer

This folder contains the Inno Setup script for creating a professional Windows installer.

## Prerequisites

1. **Install Inno Setup** (free): https://jrsoftware.org/isdl.php
2. **Build the Flutter app**:
   ```bash
   flutter build windows --release
   ```

## Creating the Installer

1. Open `abs_platform_setup.iss` in Inno Setup Compiler
2. Click **Build > Compile** (or press Ctrl+F9)
3. The installer will be created in `installer/Output/ABS_Platform_Setup_1.0.0.exe`

## What the Installer Does

1. **Welcome page** - Introduction
2. **License agreement** - MIT License
3. **Installation info** - What to expect
4. **Destination folder** - Where to install
5. **AI Provider Setup** - Choose OpenAI/Anthropic/Gemini/Skip
6. **API Key Entry** - Enter API key (optional)
7. **Model Selection** - Choose default model
8. **Install** - Copy files
9. **Finish** - Option to launch app

## Files Included

- `abs_platform_setup.iss` - Main Inno Setup script
- `../LICENSE.txt` - License shown during install
- `../INSTALL_README.txt` - Info shown before install

## Optional: Custom Images

For branding, create these BMP files:
- `wizard_image.bmp` - 164x314 pixels (left panel image)
- `wizard_small.bmp` - 55x58 pixels (header icon)

## Notes

- The installer saves config to `initial_config.json` in the app folder
- On first launch, the app imports this config and deletes the file
- API keys are stored locally via Hive, never transmitted to ABS servers
