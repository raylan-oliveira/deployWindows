@echo off
setlocal enabledelayedexpansion

echo Checking firmware type...
set "firmware=BIOS"

:: Metodo para Windowsdows PE - verifica se a variavel de ambiente EFI existe
if defined efi set "firmware=UEFI"

:: Metodo alternativo - verifica se o diretorio EFI existe
if exist X:\EFI set "firmware=UEFI"
if exist \EFI set "firmware=UEFI"

:: Outro metodo - verifica se o diretorio efivars esta montado
if exist /sys/firmware/efi set "firmware=UEFI"

:: Metodo usando bcdedit
bcdedit | find "EFI" >nul 2>&1
if !errorlevel! equ 0 set "firmware=UEFI"

:: Metodo usando a chave de registro UEFI
reg query "HKLM\HARDWARE\UEFI" >nul 2>&1
if !errorlevel! equ 0 set "firmware=UEFI"

:: Metodo usando PEFirmwareType
for /f "tokens=3" %%a in ('reg query "HKLM\System\CurrentControlSet\Control" /v PEFirmwareType 2^>nul') do (
    if "%%a"=="0x2" set "firmware=UEFI"
)

echo Detected firmware type: !firmware!

:: Listar discos disponiveis usando diskpart diretamente
echo.
echo Available disks:
echo -----------------
(
echo list disk
echo exit
) | diskpart
echo -----------------
echo.

:: Solicitar ao usuario que escolha um disco (com 0 como padrao)
set /p "disknum=Enter the disk number for formatting (default: 0): " || set "disknum=0"
if "!disknum!"=="" set "disknum=0"

echo.
echo You selected disk !disknum!
echo WARNING: All data on this disk will be ERASED!
echo.

:: Verificar se o disco selecionado é um dispositivo USB
echo Checking if disk !disknum! is a USB device...
set "is_usb=0"
for /f "tokens=*" %%a in ('diskpart /s "%TEMP%\select_disk.txt" ^| find "USB"') do (
    set "is_usb=1"
)

:: Criar um script temporário para verificar detalhes do disco
(
echo select disk !disknum!
echo detail disk
echo exit
) > "%TEMP%\check_disk.txt"

:: Executar o script e verificar se é USB
for /f "tokens=*" %%a in ('diskpart /s "%TEMP%\check_disk.txt" ^| find /i "USB"') do (
    set "is_usb=1"
)

if "!is_usb!"=="1" (
    echo.
    echo WARNING: Disk !disknum! appears to be a USB device.
    echo This script should not be applied to USB devices.
    echo.
    set /p "usb_confirm=Are you ABSOLUTELY sure you want to continue anyway? (Y/N): "
    if /i not "!usb_confirm!"=="Y" (
        echo Operation cancelled - USB device detected.
        goto :end
    )
    echo Proceeding with USB device - NOT RECOMMENDED!
)

set /p "confirm=Are you sure you want to continue? (Y/N): "
if /i not "!confirm!"=="Y" (
    echo Operation cancelled by user.
    goto :end
)

echo Formatting disk !disknum!...

:: Criar arquivo temporario com o numero do disco selecionado
(
echo select disk !disknum!
) > "%TEMP%\select_disk.txt"

:: Executar diskpart com os arquivos de script existentes
if "!firmware!"=="UEFI" (
    echo Using UEFI partitioning...
    type "%TEMP%\select_disk.txt" > "%TEMP%\diskpart_commands.txt"
    type "%~dp0util\UEFI_-_1_Particao_-_Tamanho_total_do_disco.txt" >> "%TEMP%\diskpart_commands.txt"
    diskpart /s "%TEMP%\diskpart_commands.txt"
) else (
    echo Using BIOS partitioning...
    type "%TEMP%\select_disk.txt" > "%TEMP%\diskpart_commands.txt"
    type "%~dp0util\BIOS_-_1_Particao_-_Tamanho_total_do_disco.txt" >> "%TEMP%\diskpart_commands.txt"
    diskpart /s "%TEMP%\diskpart_commands.txt"
)

echo Detecting model...
rem $frabricante, use a ordem: BaseBoardManufacturer, SystemManufacturer, BIOSVendor; para o model_hardware use a ordem: SystemProductName, BaseBoardProduct
set "$model_hardware=Windows"
set "$frabricante=Microsoft"

:: Obter Manufacturer do registro na ordem especificada
:: 1. Tentar BaseBoardManufacturer
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v BaseBoardManufacturer  2^>nul') do (
    set "$frabricante=%%b"
)

:: 2. Se não encontrou, tentar SystemManufacturer
if "!$frabricante!"=="Microsoft" (
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v SystemManufacturer 2^>nul') do (
        set "$frabricante=%%b"
    )
)

:: 3. Se não encontrou, tentar BIOSVendor
if "!$frabricante!"=="Microsoft" (
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v BIOSVendor 2^>nul') do (
        set "$frabricante=%%b"
    )
)

:: Remove espacos e caracteres especiais do fabricante
set "$frabricante=!$frabricante: =!"
set "$frabricante=!$frabricante:-=!"
set "$frabricante=!$frabricante::=!"
set "$frabricante=!$frabricante:/=!"
set "$frabricante=!$frabricante:\=!"

:: Obter model_hardware do registro na ordem especificada
:: 1. Tentar SystemProductName
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v BaseBoardProduct 2^>nul') do (
    set "$model_hardware=%%b"
)

:: 2. Se não encontrou, tentar BaseBoardProduct
:: Remove espacos e caracteres especiais do fabricante
set "$frabricante=!$frabricante: =!"
set "$frabricante=!$frabricante:-=!"
set "$frabricante=!$frabricante::=!"
set "$frabricante=!$frabricante:/=!"
set "$frabricante=!$frabricante:\=!"

:: Obter model_hardware do registro validando string (>=3 após normalização)
set "$model_hardware=Windows"
call :getValidRegValue BaseBoardProduct $model_hardware
if "!$model_hardware!"=="Windows" call :getValidRegValue SystemProductName $model_hardware
if "!$model_hardware!"=="Windows" call :getValidRegValue SystemFamily $model_hardware

:: Se ainda não encontrou, tentar SystemVersion como último recurso
if "!$model_hardware!"=="Windows" (
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v SystemVersion 2^>nul') do (
        set "$model_hardware=%%b"
    )
)

:: Remove espacos e caracteres especiais
set "$model_hardware=!$model_hardware: =!"
set "$model_hardware=!$model_hardware:-=!"
set "$model_hardware=!$model_hardware::=!"
set "$model_hardware=!$model_hardware:/=!"
set "$model_hardware=!$model_hardware:\=!"
echo Detected model: !$model_hardware!
echo Detected frabricante: !$frabricante!

:: Verificar se o nome do fabricante ou modelo está vazio ou tem menos de 2 caracteres
if "!$frabricante!"=="" set "$frabricante=Microsoft"
if "!$model_hardware!"=="" set "$model_hardware=Windows"

:: Validar se $frabricante tem pelo menos 2 caracteres
call :strlen $frabricante len
if !len! LSS 2 (
    echo Manufacturer name too short, using default: Microsoft
    set "$frabricante=Microsoft"
)

:: Validar se model_hardware tem pelo menos 2 caracteres
call :strlen $model_hardware len
if !len! LSS 2 (
    echo System family name too short, using default: Windows
    set "$model_hardware=Windows"
)

:: Verificar se o diretório de imagens existe, se não, criar
if not exist "%~dp0Imagens\Microsoft" (
    mkdir "%~dp0Imagens\Microsoft" 2>nul
    if !errorlevel! neq 0 (
        echo ERROR: Failed to create Microsoft images directory.
        goto :end
    )
)

:: Criar pasta Log dentro de Imagens se não existir
if not exist "%~dp0Imagens\Log" (
    mkdir "%~dp0Imagens\Log" 2>nul
    if !errorlevel! neq 0 (
        echo ERROR: Failed to create Log directory.
        goto :end
    )
)

:: Definir a imagem do Windows com base no fabricante
if "!$frabricante!"=="ItautecS.A." (
    echo Detected Itautec S.A. frabricante, using Windows 10 image...
    set "image_file=%~dp0Imagens\Microsoft\Windows10.wim"
) else (
    :: Usar Windows11.wim para outros fabricantes
    set "image_file=%~dp0Imagens\Microsoft\Windows11.wim"
)

if not exist "!image_file!" (
    echo ERROR: !image_file! not found
    goto :end
)

echo Applying Windows image...
:: /UnattendFile:"%~dp0util\autounattend.xml"
dism /Apply-Image /ImageFile:"!image_file!" /Index:1 /ApplyDir:W:\ /LogPath:"%~dp0Imagens\Log\dism_apply.log" /LogLevel:2

if !errorlevel! neq 0 (
    echo ERROR: Failed to apply Windows image. Check the log file: %~dp0Imagens\Log\dism_apply.log
    goto :end
)

:: Verificar se existem drivers específicos para o fabricante e modelo
set "driver_source_path=%~dp0Drivers\!$frabricante!\!$model_hardware!"
set "windows_default_drivers=%~dp0Drivers\Microsoft\Windows11"

echo Checking for frabricante-specific drivers...
echo Manufacturer: !$frabricante!
echo Model: !$model_hardware!
echo Driver source path: !driver_source_path!

:: Criar pasta temporária para logs de DISM
if not exist "%~dp0Imagens\Log\Drivers" (
    mkdir "%~dp0Imagens\Log\Drivers" 2>nul
)

:: Verificar se existem drivers específicos do fabricante
if exist "!driver_source_path!" (
    echo Found frabricante-specific drivers. Installing to Windows...
    
    :: Usar DISM para adicionar os drivers ao Windows
    dism /Image:W:\ /Add-Driver /Driver:"!driver_source_path!" /Recurse /ForceUnsigned /LogPath:"%~dp0Imagens\Log\Drivers\manufacturer_drivers.log"
    
    if !errorlevel! neq 0 (
        echo WARNING: Failed to install some $frabricante drivers. Check log: %~dp0Imagens\Log\Drivers\manufacturer_drivers.log
        echo Attempting to continue with default Windows drivers...
        
        :: Tentar usar drivers padrão do Windows se os drivers do fabricante falharem
        if exist "!windows_default_drivers!" (
            echo Using default Windows drivers as fallback...
            dism /Image:W:\ /Add-Driver /Driver:"!windows_default_drivers!" /Recurse /ForceUnsigned /LogPath:"%~dp0Imagens\Log\Drivers\windows_drivers.log"
            
            if !errorlevel! neq 0 (
                echo WARNING: Failed to install default Windows drivers. Windows will use built-in drivers.
            ) else (
                echo Default Windows drivers installed successfully as fallback.
            )
        )
    ) else (
        echo Manufacturer-specific drivers installed successfully.
    )
) else (
    echo No $frabricante-specific drivers found at !driver_source_path!
    
    :: Verificar se existem drivers padrão do Windows
    if exist "!windows_default_drivers!" (
        echo Using default Windows drivers from !windows_default_drivers!
        
        :: Usar DISM para adicionar os drivers padrão do Windows
        dism /Image:W:\ /Add-Driver /Driver:"!windows_default_drivers!" /Recurse /ForceUnsigned /LogPath:"%~dp0Imagens\Log\Drivers\windows_drivers.log"
        
        if !errorlevel! neq 0 (
            echo WARNING: Failed to install default Windows drivers. Windows will use built-in drivers.
        ) else (
            echo Default Windows drivers installed successfully.
        )
    ) else (
        echo No default Windows drivers found at !windows_default_drivers!
        echo Windows will use built-in drivers.
    )
)

:: Commit das alterações para garantir que os drivers sejam registrados corretamente
echo Committing changes to Windows image...
dism /Image:W:\ /Cleanup-Image /StartComponentCleanup /ResetBase /LogPath:"%~dp0Imagens\Log\dism_cleanup.log"

echo Creating boot files...
W:\Windows\System32\bcdboot W:\Windows /s S: /f ALL

echo Installation completed successfully!

:: Verificar se todo o processo foi concluído sem erros
if !errorlevel! equ 0 (
    echo All operations completed successfully.
    echo The computer will restart in 5 seconds...
    timeout /t 5
    shutdown /r /t 0 /f /c "Windows installation completed successfully. Restarting..."
) else (
    echo There were some errors during the installation process.
    echo Please check the logs before restarting.
    pause
)

goto :end

:: Função para obter um valor válido do registro de BIOS
:getValidRegValue <RegValueName> <OutVarName>
setlocal enabledelayedexpansion
set "valname=%~1"
set "rawValue="
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v !valname! 2^>nul') do (
    set "rawValue=%%b"
)

:: Se não retornou nada, sair
if not defined rawValue (
    endlocal & goto :eof
)

:: Normalizar (remover espaços e alguns caracteres comuns)
set "norm=!rawValue: =!"
set "norm=!norm:-=!"
set "norm=!norm::=!"
set "norm=!norm:/=!"
set "norm=!norm:\=!"

:: Validar tamanho mínimo (>=3)
call :strlen norm _len
if !_len! LSS 3 (
    endlocal & goto :eof
)

:: Se passou, devolver no escopo do chamador
endlocal & set "%~2=%norm%"
goto :eof

:: Função para obter o comprimento de uma string
:strlen <stringVar> <resultVar>
setlocal enabledelayedexpansion
set "s=!%~1!"
set "len=0"
if defined s (
    for /L %%i in (0,1,8190) do (
        if "!s:~%%i,1!" NEQ "" (
            set /a "len+=1"
        ) else (
            goto :strlen_done
        )
    )
)
:strlen_done
endlocal & set "%~2=%len%"
goto :eof

:end
pause
endlocal