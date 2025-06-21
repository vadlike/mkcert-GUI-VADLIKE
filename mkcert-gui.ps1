Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Management.Automation

# --- Константы ---
$settingsFile = "$PSScriptRoot\mkcert-gui-settings.json"

# --- Загрузка настроек ---
function Load-Settings {
    if (Test-Path $settingsFile) {
        try {
            return Get-Content $settingsFile | ConvertFrom-Json
        } catch {
            return @{}
        }
    }
    return @{}
}

# --- Сохранение настроек ---
function Save-Settings($settings) {
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile
}

# --- Локализация ---
$strings = @{
    en = @{
        title = "mkcert GUI VADLIKE"
        enterDomain = "Enter domain(s), comma separated (e.g. google.com, localhost):"
        selectFolder = "Select folder to save certificates:"
        btnSelectFolder = "Select Folder"
        btnInstallRootCA = "Install Root CA"
        btnUninstallRootCA = "Uninstall Root CA"
        btnGenerate = "Generate Certificate(s)"
        btnHelp = "Help / Docs"
        statusRootInstalled = "Root CA is installed."
        statusRootNotInstalled = "Root CA NOT installed."
        msgEnterDomain = "Please enter at least one domain."
        msgMkcertNotFound = "mkcert.exe not found in current folder."
        msgRootInstalledSuccess = "Root CA installed successfully!"
        msgRootUninstalledSuccess = "Root CA uninstalled successfully!"
        msgCertCreated = "Certificate(s) created!"
        msgError = "Error"
        msgSuccess = "Success"
        msgOpenFolder = "Open Certificates Folder"
        msgDeleteCert = "Delete selected certificate(s)?"
        logTitle = "Log Output"
        lblVersion = "mkcert version: "
        confirmUninstall = "Are you sure you want to uninstall Root CA?"
        promptInstallRoot = "Root CA is not installed. Install now?"
    }
    ru = @{
        title = "mkcert GUI"
        enterDomain = "Введите домены через запятую (например nnm.gf, localhost):"
        selectFolder = "Выберите папку для сохранения сертификатов:"
        btnSelectFolder = "Выбрать папку"
        btnInstallRootCA = "Установить Root CA"
        btnUninstallRootCA = "Удалить Root CA"
        btnGenerate = "Создать сертификат(ы)"
        btnHelp = "Помощь / Документация"
        statusRootInstalled = "Root CA установлен."
        statusRootNotInstalled = "Root CA НЕ установлен."
        msgEnterDomain = "Пожалуйста, введите хотя бы один домен."
        msgMkcertNotFound = "mkcert.exe не найден в текущей папке."
        msgRootInstalledSuccess = "Root CA успешно установлен!"
        msgRootUninstalledSuccess = "Root CA успешно удалён!"
        msgCertCreated = "Сертификат(ы) созданы!"
        msgError = "Ошибка"
        msgSuccess = "Успех"
        msgOpenFolder = "Открыть папку сертификатов"
        msgDeleteCert = "Удалить выбранные сертификаты?"
        logTitle = "Лог"
        lblVersion = "Версия mkcert: "
        confirmUninstall = "Вы уверены, что хотите удалить Root CA?"
        promptInstallRoot = "Root CA не установлен. Установить сейчас?"
    }
}

# --- Загрузка настроек ---
$settings = Load-Settings
if (-not $settings.Language) { $settings.Language = "en" }
if (-not $settings.SaveFolder) { $settings.SaveFolder = "$PSScriptRoot\certs" }
if (-not (Test-Path $settings.SaveFolder)) { New-Item -ItemType Directory -Path $settings.SaveFolder | Out-Null }

# --- Выбор языка ---
$lang = $strings[$settings.Language]

# --- Функция для запуска mkcert ---
function Run-Mkcert {
    param(
        [string]$Arguments,
        [string]$WorkingDir = (Get-Location).Path
    )
    if (-not (Test-Path ".\mkcert.exe")) {
        [System.Windows.Forms.MessageBox]::Show($lang.msgMkcertNotFound, $lang.msgError, 0, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName = ".\mkcert.exe"
    $procInfo.Arguments = $Arguments
    $procInfo.WorkingDirectory = $WorkingDir
    $procInfo.UseShellExecute = $false
    $procInfo.RedirectStandardOutput = $true
    $procInfo.RedirectStandardError = $true
    $procInfo.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo
    $proc.Start() | Out-Null
    $output = $proc.StandardOutput.ReadToEnd()
    $errorOutput = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    # Логирование
    Add-Content -Path "$PSScriptRoot\mkcert-gui.log" -Value "---- $(Get-Date) ----"
    Add-Content -Path "$PSScriptRoot\mkcert-gui.log" -Value "Command: mkcert $Arguments"
    Add-Content -Path "$PSScriptRoot\mkcert-gui.log" -Value $output
    Add-Content -Path "$PSScriptRoot\mkcert-gui.log" -Value $errorOutput

    if ($proc.ExitCode -eq 0) {
        return $true
    } else {
        [System.Windows.Forms.MessageBox]::Show("$($lang.msgError):`n$errorOutput", $lang.msgError, 0, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

# --- Проверка Root CA ---
function Is-RootCAInstalled {
    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName = ".\mkcert.exe"
    $procInfo.Arguments = "-CAROOT"
    $procInfo.UseShellExecute = $false
    $procInfo.RedirectStandardOutput = $true
    $procInfo.CreateNoWindow = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo
    $proc.Start() | Out-Null
    $output = $proc.StandardOutput.ReadToEnd().Trim()
    $proc.WaitForExit()
    return (Test-Path $output)
}

# --- UI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = $lang.title
$form.Size = New-Object System.Drawing.Size(620,480)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Метка доменов
$lblDomains = New-Object System.Windows.Forms.Label
$lblDomains.Text = $lang.enterDomain
$lblDomains.Location = New-Object System.Drawing.Point(20,20)
$lblDomains.Size = New-Object System.Drawing.Size(580,20)
$form.Controls.Add($lblDomains)

# Ввод доменов
$txtDomains = New-Object System.Windows.Forms.TextBox
$txtDomains.Location = New-Object System.Drawing.Point(20,45)
$txtDomains.Size = New-Object System.Drawing.Size(560,25)
$form.Controls.Add($txtDomains)

# Кнопка выбора папки
$btnSelectFolder = New-Object System.Windows.Forms.Button
$btnSelectFolder.Text = $lang.btnSelectFolder
$btnSelectFolder.Location = New-Object System.Drawing.Point(20,85)
$btnSelectFolder.Size = New-Object System.Drawing.Size(130,30)
$form.Controls.Add($btnSelectFolder)

# Отображение папки
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = $lang.selectFolder + " `n" + $settings.SaveFolder
$lblFolder.Location = New-Object System.Drawing.Point(160,85)
$lblFolder.Size = New-Object System.Drawing.Size(420,40)
$lblFolder.AutoSize = $false
$form.Controls.Add($lblFolder)

# Кнопка установки Root CA
$btnInstallRoot = New-Object System.Windows.Forms.Button
$btnInstallRoot.Text = $lang.btnInstallRootCA
$btnInstallRoot.Location = New-Object System.Drawing.Point(20,140)
$btnInstallRoot.Size = New-Object System.Drawing.Size(130,30)
$form.Controls.Add($btnInstallRoot)

# Кнопка удаления Root CA
$btnUninstallRoot = New-Object System.Windows.Forms.Button
$btnUninstallRoot.Text = $lang.btnUninstallRootCA
$btnUninstallRoot.Location = New-Object System.Drawing.Point(160,140)
$btnUninstallRoot.Size = New-Object System.Drawing.Size(130,30)
$form.Controls.Add($btnUninstallRoot)

# Кнопка генерации сертификатов
$btnGenerate = New-Object System.Windows.Forms.Button
$btnGenerate.Text = $lang.btnGenerate
$btnGenerate.Location = New-Object System.Drawing.Point(320,140)
$btnGenerate.Size = New-Object System.Drawing.Size(180,30)
$form.Controls.Add($btnGenerate)

# Кнопка помощи
$btnHelp = New-Object System.Windows.Forms.Button
$btnHelp.Text = $lang.btnHelp
$btnHelp.Location = New-Object System.Drawing.Point(510,140)
$btnHelp.Size = New-Object System.Drawing.Size(70,30)
$form.Controls.Add($btnHelp)

# Статус Root CA
$lblRootStatus = New-Object System.Windows.Forms.Label
$lblRootStatus.Location = New-Object System.Drawing.Point(20,180)
$lblRootStatus.Size = New-Object System.Drawing.Size(560,25)
$form.Controls.Add($lblRootStatus)

# Версия mkcert
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Location = New-Object System.Drawing.Point(20,210)
$lblVersion.Size = New-Object System.Drawing.Size(560,25)
$form.Controls.Add($lblVersion)

# Лог - многострочный текст
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.WordWrap = $true
$txtLog.Location = New-Object System.Drawing.Point(20,250)
$txtLog.Size = New-Object System.Drawing.Size(580,180)
$form.Controls.Add($txtLog)

# --- Обновление статуса и версии ---
function Update-StatusAndVersion {
    $installed = Is-RootCAInstalled
    if ($installed) {
        $lblRootStatus.Text = $lang.statusRootInstalled
    } else {
        $lblRootStatus.Text = $lang.statusRootNotInstalled
    }

    # Версия mkcert
    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName = ".\mkcert.exe"
    $procInfo.Arguments = "-version"
    $procInfo.UseShellExecute = $false
    $procInfo.RedirectStandardOutput = $true
    $procInfo.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo
    $proc.Start() | Out-Null
    $version = $proc.StandardOutput.ReadToEnd().Trim()
    $proc.WaitForExit()

    $lblVersion.Text = "$($lang.lblVersion)$version"
}
Update-StatusAndVersion

# --- Обработчики кнопок ---

# Выбор папки
$btnSelectFolder.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = $lang.selectFolder
    $folderBrowser.SelectedPath = $settings.SaveFolder
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $settings.SaveFolder = $folderBrowser.SelectedPath
        $lblFolder.Text = $lang.selectFolder + " `n" + $settings.SaveFolder
        if (-not (Test-Path $settings.SaveFolder)) {
            New-Item -ItemType Directory -Path $settings.SaveFolder | Out-Null
        }
        Save-Settings $settings
    }
})

# Установка Root CA
$btnInstallRoot.Add_Click({
    $txtLog.AppendText("Running: mkcert -install`r`n")
    if (Run-Mkcert "-install") {
        [System.Windows.Forms.MessageBox]::Show($lang.msgRootInstalledSuccess, $lang.msgSuccess, 0, [System.Windows.Forms.MessageBoxIcon]::Information)
        $txtLog.AppendText("Root CA installed successfully.`r`n")
        Update-StatusAndVersion
    }
})

# Удаление Root CA
$btnUninstallRoot.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show($lang.confirmUninstall, $lang.msgError, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        $txtLog.AppendText("Running: mkcert -uninstall`r`n")
        if (Run-Mkcert "-uninstall") {
            [System.Windows.Forms.MessageBox]::Show($lang.msgRootUninstalledSuccess, $lang.msgSuccess, 0, [System.Windows.Forms.MessageBoxIcon]::Information)
            $txtLog.AppendText("Root CA uninstalled.`r`n")
            Update-StatusAndVersion
        }
    }
})

# Генерация сертификатов
$btnGenerate.Add_Click({
    $domainsRaw = $txtDomains.Text.Trim()
    if ([string]::IsNullOrEmpty($domainsRaw)) {
        [System.Windows.Forms.MessageBox]::Show($lang.msgEnterDomain, $lang.msgError, 0, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    $domains = $domainsRaw.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($domains.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show($lang.msgEnterDomain, $lang.msgError, 0, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $domainArgs = $domains -join " "
    $txtLog.AppendText("Running: mkcert $domainArgs`r`n")

    if (Run-Mkcert $domainArgs $settings.SaveFolder) {
        [System.Windows.Forms.MessageBox]::Show($lang.msgCertCreated, $lang.msgSuccess, 0, [System.Windows.Forms.MessageBoxIcon]::Information)
        $txtLog.AppendText("Certificates created in folder: $($settings.SaveFolder)`r`n")
    }
})

# Помощь
$btnHelp.Add_Click({
    [System.Diagnostics.Process]::Start("https://github.com/vadlike/mkcert-GUI-VADLIKE") | Out-Null
})

# --- Автоматический запрос установки Root CA ---
if (-not (Is-RootCAInstalled)) {
    $result = [System.Windows.Forms.MessageBox]::Show($lang.promptInstallRoot, $lang.msgError, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        if (Run-Mkcert "-install") {
            [System.Windows.Forms.MessageBox]::Show($lang.msgRootInstalledSuccess, $lang.msgSuccess, 0, [System.Windows.Forms.MessageBoxIcon]::Information)
            Update-StatusAndVersion
        }
    }
}

# --- Запуск формы ---
[void]$form.ShowDialog()
