# Guia De Emulacao, ROMs E Diretorios De Jogos

Este guia e opcional. O projeto principal nao e exclusivo para emuladores, Ryujinx ou jogos. Ele monta qualquer remoto rclone como uma unidade do Windows, e essa unidade pode ser usada tambem como biblioteca de ROMs/jogos.

## Ideia Principal

Use a unidade montada para arquivos grandes e quase sempre somente leitura:

```text
R:\Games
R:\ROMs
R:\Emulation
```

Mantenha dados sensiveis, pequenos ou muito gravados no SSD local:

```text
C:\EmulationData
C:\Emulators
C:\Saves
```

## Estrutura Recomendada

Exemplo usando a unidade montada como `R:`:

```text
R:\Games
├─ Switch
├─ WiiU
├─ PS2
├─ PS3
├─ Xbox360
├─ Retro
└─ Arcade
```

Dados locais recomendados:

```text
C:\EmulationData
├─ Saves
├─ SaveStates
├─ Configs
├─ ShaderCache
├─ Firmware
└─ Keys
```

## O Que Pode Ficar Na Unidade Montada

Bom para colocar no drive rclone:

- ROMs
- ISOs
- CHD
- RVZ
- XCI
- NSP
- WUX/WUD
- arquivos grandes de jogos
- backups compactados
- midia estatica, como capas e artes, se o frontend lidar bem com latencia

## O Que E Melhor Manter Local

Melhor deixar no SSD local:

- saves
- save states
- shader cache
- configuracoes dos emuladores
- firmware
- keys
- arquivos de conta
- jogos sendo instalados, convertidos, extraidos ou modificados

## Por Que Saves E Shader Cache Devem Ficar Locais?

Esses arquivos mudam com frequencia. Se ficarem na nuvem montada, podem ocorrer:

- atraso para salvar
- travamentos em escrita
- risco maior de cache sujo
- lentidao ao abrir o emulador
- stutter causado por shader cache em rede

## Configurando Um Emulador Ou Frontend

No emulador ou frontend, aponte apenas a pasta de jogos para o drive montado.

Exemplo:

```text
Game directory: R:\Games\Switch
```

Mantenha o emulador instalado localmente, por exemplo:

```text
C:\Emulators\Ryujinx
C:\Emulators\PCSX2
C:\Emulators\RPCS3
C:\Emulators\Dolphin
```

## Cache Recomendado

O projeto usa:

```text
--vfs-cache-mode full
--vfs-cache-max-size 120G
```

Para jogos grandes, aumente se tiver espaco livre:

```text
120G - uso geral
200G - jogos grandes
300G ou mais - bibliotecas pesadas
```

Um jogo maior que o cache pode funcionar, mas o ideal e ter cache pelo menos do tamanho do maior jogo usado com frequencia.

## Exemplo De Organizacao Por Plataforma

```text
R:\Games\Switch
R:\Games\PS2
R:\Games\PS3
R:\Games\WiiU
R:\Games\GameCube
R:\Games\Retro
```

No frontend, configure cada plataforma apontando para a pasta correspondente.

## Checklist Para Testar

1. Confirme que o servico esta rodando.
2. Confirme que a unidade `R:` apareceu.
3. Abra o emulador localmente.
4. Adicione uma pasta pequena de teste, por exemplo `R:\Games\Retro`.
5. Teste um jogo pequeno.
6. Depois teste um jogo grande.
7. Se houver stutter, teste uma copia local para comparar.
8. Mantenha saves e shader cache fora do `R:`.

## Observacao Legal

Use apenas jogos, BIOS, firmware e arquivos que voce tem direito legal de usar. Este projeto apenas monta armazenamento remoto com rclone; ele nao fornece jogos, ROMs, BIOS, firmware ou keys.

## PDF Offline

Tambem existe um guia em PDF:

```text
output\pdf\WinSW-Rclone-Emulation-Guide.pdf
```

