# WinSW Rclone Cloud Mount Service

Instalador em estilo "dois cliques" para executar um mount do rclone como servico do Windows usando WinSW.

Este projeto e um template/instalador limpo para montar qualquer remoto suportado pelo rclone como uma letra de unidade no Windows, com cache VFS pensado para arquivos grandes, backups, midia e outros fluxos pesados de leitura.

## O Que Ele Faz

- Abre um assistente PowerShell com permissao de administrador.
- Baixa o rclone automaticamente.
- Baixa o WinSW automaticamente.
- Cria a pasta do servico.
- Cria a pasta de cache VFS.
- Abre `rclone config` quando ainda nao existe configuracao.
- Gera `RcloneService.xml`.
- Instala e inicia o servico do Windows.
- Monta um remoto rclone, como `remote:`, em uma letra de unidade, como `R:`.
- Salva logs na pasta local `logs`.

## Aviso De Seguranca

O launcher usa:

```text
PowerShell -ExecutionPolicy Bypass
```

Isso permite executar o assistente local sem alterar permanentemente a politica de execucao do PowerShell no sistema.

Antes de rodar qualquer script baixado da internet, revise os arquivos do projeto. O instalador pede administrador porque servicos do Windows exigem permissao elevada.

## O PowerShell Fica Aberto?

Nao. O PowerShell aparece apenas durante a instalacao, porque o assistente e interativo e pode precisar abrir o `rclone config`.

Depois da instalacao, o mount roda pelo WinSW como servico do Windows. O processo do rclone fica em segundo plano, e nenhuma janela do PowerShell precisa continuar aberta para a unidade permanecer montada.

Na inicializacao do Windows, o servico sobe de forma silenciosa em segundo plano:

```xml
<startmode>Automatic</startmode>
<delayedAutoStart>true</delayedAutoStart>
```

O servico do Windows nao abre uma janela visivel do PowerShell ou do CMD a cada boot. O WinSW inicia o `rclone.exe` diretamente como processo de servico, por isso a unidade pode continuar montada enquanto voce joga ou usa o PC sem uma janela de terminal aparecendo na tela.

## PowerShell Ou CMD?

Da para usar os dois, mas para coisas diferentes:

- `Install-WinSW-Rclone.cmd` e apenas um launcher de dois cliques.
- O assistente de instalacao e PowerShell porque ele e melhor para baixar arquivos, gerar XML, verificar servicos e rodar diagnosticos.
- O instalador totalmente automatico requer Windows PowerShell.
- Depois de instalado, nem PowerShell nem CMD precisam ficar abertos para manter o mount funcionando.
- Na inicializacao do Windows, quem sobe o `rclone.exe` oculto e o WinSW como servico.

O CMD tambem pode iniciar ou parar o servico manualmente:

```cmd
RcloneService.exe start
RcloneService.exe stop
RcloneService.exe restart
```

PowerShell fica reservado principalmente para instalacao, verificacao e diagnostico. Fazer tudo somente pelo CMD e possivel de forma manual, baixando rclone e WinSW, copiando ou escrevendo o `RcloneService.xml`, e depois rodando `RcloneService.exe install` e `RcloneService.exe start`.

## Linux

Este projeto e somente para Windows por enquanto.

O Linux tambem consegue rodar mounts do rclone, mas usa outra estrutura de servico, como systemd, em vez do WinSW. Suporte a Linux fica fora do escopo atual e nao foi testado aqui.

## Instalacao Rapida

Baixe ou clone este repositorio e execute:

```text
Install-WinSW-Rclone.cmd
```

O assistente pergunta:

- pasta do servico, padrao `C:\Tools\WinSW-Rclone`
- nome do remoto rclone, padrao `remote`
- letra da unidade, padrao `R:`
- pasta de cache, padrao `C:\rclone-cache`
- limite de cache, padrao `120G`
- caminho do config rclone, padrao `%APPDATA%\rclone\rclone.conf`

Os caminhos padrao sao exemplos. Voce pode altera-los no assistente.

## Conta Da Nuvem

Voce nao cola conta, senha, token ou OAuth manualmente neste projeto.

O login acontece dentro do:

```powershell
rclone config
```

O rclone abre o navegador quando o provedor exige autorizacao. Voce faz login no provedor escolhido e o rclone salva a autorizacao localmente em:

```text
%APPDATA%\rclone\rclone.conf
```

## Provedores Suportados

Funciona com qualquer backend suportado pelo rclone, por exemplo:

- Google Drive
- OneDrive
- Dropbox
- MEGA
- Box
- pCloud
- S3 compativel
- FTP
- SFTP
- WebDAV
- SMB
- outros

Links oficiais:

- rclone downloads: <https://rclone.org/downloads/>
- rclone install docs: <https://rclone.org/install/>
- rclone supported providers: <https://rclone.org/overview/>
- WinSW releases: <https://github.com/winsw/winsw/releases>

## Estrutura Recomendada

```text
C:\Tools\WinSW-Rclone
├─ RcloneService.exe
├─ RcloneService.xml
├─ scripts
├─ logs
└─ rclone
   └─ rclone.exe
```

## Instalacao Manual

Use este caminho se nao quiser usar o instalador automatico.

1. Baixe o rclone para Windows 64-bit:

```text
https://rclone.org/downloads/
```

2. Coloque `rclone.exe` em:

```text
C:\Tools\WinSW-Rclone\rclone\rclone.exe
```

3. Baixe o WinSW x64:

```text
https://github.com/winsw/winsw/releases
```

4. Renomeie o executavel do WinSW para:

```text
RcloneService.exe
```

5. Coloque em:

```text
C:\Tools\WinSW-Rclone\RcloneService.exe
```

6. Configure o remoto:

```powershell
C:\Tools\WinSW-Rclone\rclone\rclone.exe config
```

7. Copie `RcloneService.xml.example` para:

```text
C:\Tools\WinSW-Rclone\RcloneService.xml
```

8. Instale e inicie o servico em um PowerShell como administrador:

```powershell
cd C:\Tools\WinSW-Rclone
.\RcloneService.exe install
.\RcloneService.exe start
```

## Verificacao

Depois da instalacao, rode:

```powershell
.\scripts\verify-config.ps1
```

Ele verifica:

- pasta do servico
- executavel WinSW
- executavel rclone
- XML do servico
- config do rclone
- remoto configurado
- status do servico Windows
- visibilidade da unidade montada
- logs recentes

## Problemas Comuns

### A unidade nao aparece

Rode:

```powershell
.\scripts\verify-config.ps1
```

Veja se o servico esta rodando e se a letra escolhida ja nao esta em uso.

### O remoto nao foi encontrado

O nome criado no `rclone config` precisa ser igual ao informado no assistente. O assistente pede o nome sem dois-pontos. Exemplo:

```text
remote
```

No comando de mount, ele aparece como:

```text
remote:
```

### O servico instala mas nao inicia

Rode:

```powershell
.\scripts\diagnose.ps1
```

Confira tambem se `rclone.exe`, `RcloneService.exe` e `RcloneService.xml` existem na pasta escolhida.

### O download falha

Algumas VMs ou redes bloqueiam downloads. Nesse caso, baixe rclone e WinSW manualmente pelos links oficiais e siga a instalacao manual.

### O cache enche o disco

Reduza:

```text
--vfs-cache-max-size
```

ou escolha uma pasta de cache em uma unidade com mais espaco livre.

## Guia Offline Em PDF

Existe um guia opcional em PDF sobre uso com emuladores e diretorios de jogos:

```text
output\pdf\WinSW-Rclone-Emulation-Guide.pdf
```

O projeto principal nao e exclusivo para emulacao. O PDF e apenas um guia separado para esse caso de uso.

## Arquivos Que Nao Devem Ser Publicados

Nunca publique:

- `rclone.conf`
- tokens OAuth
- logs
- caminhos pessoais
- XML gerado com caminhos reais
- binarios baixados localmente
