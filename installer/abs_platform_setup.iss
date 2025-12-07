; ABS Platform - Inno Setup Installer Script
; Creates a professional Windows installer with guided setup wizard
;
; Requirements:
;   1. Install Inno Setup: https://jrsoftware.org/isdl.php
;   2. Build Flutter app: flutter build windows --release
;   3. Open this file in Inno Setup Compiler
;   4. Click Build > Compile to create the installer
;
; Output: installer/Output/ABS_Platform_Setup.exe

#define MyAppName "ABS Platform"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "ABS Systems"
#define MyAppURL "https://github.com/summonwill/abs-platform"
#define MyAppExeName "abs_platform.exe"

[Setup]
; App identity
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Installation settings
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE.txt
InfoBeforeFile=..\INSTALL_README.txt
OutputDir=Output
OutputBaseFilename=ABS_Platform_Setup_{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; Permissions
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; Appearance
WizardImageFile=wizard_image.bmp
WizardSmallImageFile=wizard_small.bmp

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Main application files from Release build
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  AgentSetupPage: TInputQueryWizardPage;
  ProviderPage: TInputOptionWizardPage;
  ModelPage: TInputOptionWizardPage;
  SelectedProvider: Integer;
  APIKey: String;
  SelectedModel: String;

// Initialize custom wizard pages
procedure InitializeWizard;
begin
  // Page 1: AI Provider Selection
  ProviderPage := CreateInputOptionPage(wpSelectTasks,
    'AI Provider Setup', 'Choose your preferred AI provider',
    'ABS Platform works with multiple AI providers. Select your preferred provider below. You can change this later in Settings.',
    True, False);
  ProviderPage.Add('OpenAI (GPT-4o, GPT-4o-mini) - Recommended');
  ProviderPage.Add('Anthropic (Claude 3.5 Sonnet, Claude 3 Opus)');
  ProviderPage.Add('Google Gemini (Gemini 2.0, Gemini 1.5)');
  ProviderPage.Add('Skip for now - I''ll configure this later');
  ProviderPage.SelectedValueIndex := 0;

  // Page 2: API Key Entry
  AgentSetupPage := CreateInputQueryPage(ProviderPage.ID,
    'API Key Configuration', 'Enter your API key',
    'Enter your API key for the selected provider. Your key is stored locally and never shared.' + #13#10 + #13#10 +
    'Don''t have an API key? You can get one from:' + #13#10 +
    '• OpenAI: https://platform.openai.com/api-keys' + #13#10 +
    '• Anthropic: https://console.anthropic.com/' + #13#10 +
    '• Google: https://makersuite.google.com/app/apikey');
  AgentSetupPage.Add('API Key:', False);

  // Page 3: Model Selection
  ModelPage := CreateInputOptionPage(AgentSetupPage.ID,
    'Default Model', 'Choose your default AI model',
    'Select the default model to use. Faster models cost less but may be less capable.',
    True, False);
  // Will be populated dynamically based on provider selection
  ModelPage.Add('Standard - Balanced speed and quality');
  ModelPage.Add('Fast - Quicker responses, lower cost');
  ModelPage.Add('Advanced - Best quality, higher cost');
  ModelPage.SelectedValueIndex := 0;
end;

// Update model options based on selected provider
procedure UpdateModelOptions;
begin
  // Clear existing items
  while ModelPage.CheckListBox.Items.Count > 0 do
    ModelPage.CheckListBox.Items.Delete(0);
  
  case ProviderPage.SelectedValueIndex of
    0: begin // OpenAI
      ModelPage.Add('GPT-4o-mini - Fast & affordable (Recommended)');
      ModelPage.Add('GPT-4o - Most capable');
      ModelPage.Add('GPT-3.5 Turbo - Budget option');
    end;
    1: begin // Anthropic
      ModelPage.Add('Claude 3.5 Sonnet - Best balance (Recommended)');
      ModelPage.Add('Claude 3 Opus - Most capable');
      ModelPage.Add('Claude 3 Haiku - Fast & affordable');
    end;
    2: begin // Gemini
      ModelPage.Add('Gemini 2.0 Flash - Fast & capable (Recommended)');
      ModelPage.Add('Gemini 1.5 Pro - Most capable');
      ModelPage.Add('Gemini 1.5 Flash - Budget option');
    end;
    3: begin // Skip
      ModelPage.Add('Will configure later');
    end;
  end;
  ModelPage.SelectedValueIndex := 0;
end;

// Called when moving between pages
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  // Update model page when leaving provider page
  if CurPageID = ProviderPage.ID then
  begin
    UpdateModelOptions;
    
    // Skip API key page if user chose "Skip for now"
    if ProviderPage.SelectedValueIndex = 3 then
    begin
      AgentSetupPage.Values[0] := '';
    end;
  end;
end;

// Skip API key page if user chose "Skip for now"
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  
  if (PageID = AgentSetupPage.ID) and (ProviderPage.SelectedValueIndex = 3) then
    Result := True;
    
  if (PageID = ModelPage.ID) and (ProviderPage.SelectedValueIndex = 3) then
    Result := True;
end;

// Save configuration after install
procedure SaveConfiguration;
var
  ConfigFile: String;
  ConfigContent: String;
  ProviderName: String;
  ModelName: String;
begin
  // Only save if user configured settings
  if ProviderPage.SelectedValueIndex = 3 then
    Exit;
    
  // Map provider selection to name
  case ProviderPage.SelectedValueIndex of
    0: ProviderName := 'openai';
    1: ProviderName := 'anthropic';
    2: ProviderName := 'gemini';
  else
    ProviderName := 'openai';
  end;
  
  // Map model selection
  case ProviderPage.SelectedValueIndex of
    0: begin // OpenAI
      case ModelPage.SelectedValueIndex of
        0: ModelName := 'gpt-4o-mini';
        1: ModelName := 'gpt-4o';
        2: ModelName := 'gpt-3.5-turbo';
      else
        ModelName := 'gpt-4o-mini';
      end;
    end;
    1: begin // Anthropic
      case ModelPage.SelectedValueIndex of
        0: ModelName := 'claude-3-5-sonnet-20241022';
        1: ModelName := 'claude-3-opus-20240229';
        2: ModelName := 'claude-3-haiku-20240307';
      else
        ModelName := 'claude-3-5-sonnet-20241022';
      end;
    end;
    2: begin // Gemini
      case ModelPage.SelectedValueIndex of
        0: ModelName := 'gemini-2.0-flash-exp';
        1: ModelName := 'gemini-1.5-pro';
        2: ModelName := 'gemini-1.5-flash';
      else
        ModelName := 'gemini-2.0-flash-exp';
      end;
    end;
  end;
  
  // Create initial config JSON
  // Note: The app will read this on first launch and import settings
  ConfigFile := ExpandConstant('{app}\initial_config.json');
  ConfigContent := '{' + #13#10 +
    '  "provider": "' + ProviderName + '",' + #13#10 +
    '  "model": "' + ModelName + '",' + #13#10 +
    '  "apiKey": "' + AgentSetupPage.Values[0] + '"' + #13#10 +
    '}';
  
  SaveStringToFile(ConfigFile, ConfigContent, False);
end;

// Called after installation completes
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    SaveConfiguration;
  end;
end;
