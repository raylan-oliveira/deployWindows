# Deploy Windows com Drivers — 00_APPLY_WITH_DRIVER.cmd

Este repositório contém o script `00_APPLY_WITH_DRIVER.cmd` para automatizar a instalação do Windows (10/11) em ambientes Windows PE, incluindo:
- Detecção de firmware (`UEFI` ou `BIOS`).
- Particionamento e formatação do disco alvo via `diskpart`.
- Aplicação de imagem `.wim` do Windows via `DISM`.
- Instalação automática de drivers por fabricante/modelo, com fallback para drivers padrão.
- Criação dos arquivos de boot com `bcdboot` e limpeza de componentes com `DISM`.

## Avisos Importantes
- Apaga completamente todos os dados do disco selecionado (wipe total).
- Não aplique em dispositivos USB (o script avisa e bloqueia por padrão).
- Execute em ambiente Windows PE (WinPE) com privilégios elevados.
- Garanta que as letras de unidade `W:` (Windows) e `S:` (Sistema/EFI) existam ao final do particionamento.

## Pré-requisitos
- Ambiente: Windows PE (normalmente `X:`) com `DISM`, `diskpart`, `bcdedit` e `bcdboot` disponíveis.
- Imagens do Windows:
  - `./Imagens/Microsoft/Windows11.wim`
  - `./Imagens/Microsoft/Windows10.wim`
- Pasta de Drivers organizada por fabricante e modelo:
  - Exemplo: `./drivers/PositivoInformaticaSA/POSMIH61CF/FileRepository`
- Scripts de particionamento (obrigatórios) na pasta `./util/`:
  - `UEFI_-_1_Particao_-_Tamanho_total_do_disco.txt`
  - `BIOS_-_1_Particao_-_Tamanho_total_do_disco.txt`

## Estrutura de Pastas Sugerida
- `00_APPLY_WITH_DRIVER.cmd` — script principal.
- `Imagens/Microsoft/Windows11.wim` — imagem do Windows 11.
- `Imagens/Microsoft/Windows10.wim` — imagem do Windows 10 (usada para Itautec S.A.).
- `Imagens/Log/` — logs gerados pelo processo (criados automaticamente).
- `drivers/<Fabricante>/<Modelo>/` — drivers específicos por hardware.
- `drivers/Microsoft/Windows11/` — drivers padrão de fallback.
- `util/UEFI_-_1_Particao_-_Tamanho_total_do_disco.txt` — comandos `diskpart` para UEFI.
- `util/BIOS_-_1_Particao_-_Tamanho_total_do_disco.txt` — comandos `diskpart` para BIOS.

Observação: Windows não diferencia maiúsculas/minúsculas em nomes de pastas. Este README usa `Drivers/` por consistência, mas `drivers/` também funciona.

## Como Usar
1. Inicialize a máquina em Windows PE.
2. Copie este repositório para um volume acessível (USB/NAS/mapeamento de rede).
3. Garanta que as imagens `.wim` estejam em `./Imagens/Microsoft/`.
4. Garanta a estrutura de drivers em `./drivers/<Fabricante>/<Modelo>/` (ex.: `./drivers/PositivoInformaticaSA/POSMIH61CF/FileRepository`).
5. Garanta os scripts de `diskpart` em `./util/` (veja exemplos abaixo).
6. Execute `00_APPLY_WITH_DRIVER.cmd`.
7. Selecione o número do disco (ex.: `0`) quando solicitado.
8. Confirme os avisos; o processo iniciará: particionamento, aplicação da imagem, instalação de drivers, criação do boot e reinício.

## Fluxo do Script
- Detecta firmware (UEFI/BIOS) por múltiplos métodos: variável `efi`, diretórios `EFI`, `bcdedit`, registro (`PEFirmwareType` e chaves UEFI).
- Lista discos com `diskpart` e solicita seleção do usuário.
- Verifica se o disco parece ser USB e pede confirmação extra.
- Particiona e formata conforme firmware usando os arquivos de `./util/`.
- Detecta fabricante e modelo via registro (`HKLM\HARDWARE\DESCRIPTION\System\BIOS`) e normaliza strings.
- Escolhe a imagem:
  - Se `fabricante == ItautecS.A.` usa `Windows10.wim`.
  - Caso contrário, usa `Windows11.wim`.
- Aplica imagem com `DISM` em `W:\`.
- Instala drivers específicos (`drivers/<Fabricante>/<Modelo>`) ou, em fallback, drivers padrão (`drivers/Microsoft/Windows11`).
- Faz limpeza de componentes com `DISM` (offline).
- Cria arquivos de boot com `bcdboot` para `S:` e formato `ALL`.
- Reinicia a máquina.

## Detecção de Firmware e Particionamento
- UEFI: usa GPT e cria partição EFI (letra `S:`), MSR, e partição Windows (`W:`).
- BIOS: usa MBR e cria partição ativa de sistema (`S:`) e partição Windows (`W:`).
- Os arquivos de `./util/` devem conter os comandos pós-`select disk`.

### Exemplo de script `diskpart` — UEFI
Crie `./util/UEFI_-_1_Particao_-_Tamanho_total_do_disco.txt` com:

```
clean
convert gpt
create partition efi size=260
format quick fs=fat32 label="SYSTEM"
assign letter=S
create partition msr size=16
create partition primary
format quick fs=ntfs label="WINDOWS"
assign letter=W
```

### Exemplo de script `diskpart` — BIOS
Crie `./util/BIOS_-_1_Particao_-_Tamanho_total_do_disco.txt` com:

```
clean
convert mbr
create partition primary size=500
format quick fs=ntfs label="SYSTEM"
assign letter=S
active
create partition primary
format quick fs=ntfs label="WINDOWS"
assign letter=W
```

Importante: As letras `S:` e `W:` são usadas mais adiante por `bcdboot` e `DISM`. Ajuste somente se também atualizar o `.cmd`.

## Imagens do Windows
- Local esperado:
  - `./Imagens/Microsoft/Windows11.wim`
  - `./Imagens/Microsoft/Windows10.wim`
- Seleção automática:
  - Fabricante `Itautec S.A.` → `Windows10.wim`.
  - Demais fabricantes → `Windows11.wim`.
- Se a imagem não existir, o script aborta com erro.

## Drivers
- Caminho de drivers específicos: `./drivers/<Fabricante>/<Modelo>/`.
  - Exemplos: `./drivers/PositivoInformaticaSA/POSMIH61CF/FileRepository`.
- Fallback padrão: `./drivers/Microsoft/Windows11`.
- Instalação feita com `DISM /Image:W:\ /Add-Driver /Driver:<caminho> /Recurse /ForceUnsigned`.

## Logs Gerados
- `./Imagens/Log/dism_apply.log` — aplicação da imagem.
- `./Imagens/Log/Drivers/manufacturer_drivers.log` — instalação de drivers do fabricante.
- `./Imagens/Log/Drivers/windows_drivers.log` — instalação de drivers padrão (fallback).
- `./Imagens/Log/dism_cleanup.log` — limpeza de componentes offline.

## Personalização
- Autounattend: o comando possui a opção comentada `UnattendFile`. Para usar, ajuste no `.cmd`:
  - `dism /Apply-Image ... /UnattendFile:"%~dp0util\autounattend.xml"`
- Imagens: altere `Windows10.wim` ou `Windows11.wim` conforme necessidade.
- Drivers: adapte a estrutura por fabricante/modelo ao seu ambiente.
- Particionamento: ajuste os arquivos em `./util/` (tamanhos, letras de unidade, labels).

## Resolução de Problemas
- "Imagem não encontrada": confirme caminhos em `./Imagens/Microsoft/`.
- "Falha em drivers do fabricante": verifique o log e use o fallback.
- "Disco USB detectado": o script bloqueia o uso; confirme apenas se for intencional.
- "Firmware incorreto": revise a detecção e os scripts `./util/` para UEFI/BIOS.
- "Letras de unidade ausentes": garanta que `diskpart` está atribuindo `S:` e `W:`.

## Exemplos Rápidos
- Drivers: `./drivers/PositivoInformaticaSA/POSMIH61CF/FileRepository`.
- Imagem do Windows: `./Imagens/Microsoft/Windows11.wim` ou `Windows10.wim`.

---

Este README documenta integralmente o fluxo e os requisitos do `00_APPLY_WITH_DRIVER.cmd`, permitindo preparar o ambiente, executar com segurança e personalizar conforme as necessidades de implantação.
