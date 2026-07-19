# LUKS2 no Arch Linux: remover a criptografia ou desbloquear via TPM2

Documento gerado em 2026-07-13 com base no estado atual deste sistema.

## Estado atual do sistema

| Item | Valor |
|---|---|
| Partição criptografada | `/dev/nvme1n1p2` (LUKS2) |
| UUID do LUKS | `a343b1de-d06d-4783-9068-15f32b0a09c5` |
| Volume aberto como | `/dev/mapper/cryptroot` (btrfs, label `archlinux`) |
| UUID do btrfs | `eb227d7f-080e-4560-8e8a-c0c6659bb7fa` |
| Boot | systemd-boot, entrada em `/boot/loader/entries/arch.conf` |
| initramfs | mkinitcpio com hook `sd-encrypt` (base systemd) |
| cryptsetup | 2.8.6 (suporta `reencrypt --decrypt` com header anexado) |
| fstab | Já usa o UUID do btrfs — **não precisa de alteração em nenhum dos dois processos** |
| Swap | zram (não criptografada, não é afetada) |
| TPM2 | Disponível no firmware (Secure Boot desabilitado) |

O UUID do btrfs **não muda** ao descriptografar; por isso o `/etc/fstab` fica intacto.

---

## Opção A — Remover o LUKS2 (descriptografia in-place)

O `cryptsetup reencrypt --decrypt` reescreve o disco inteiro, movendo os dados
descriptografados para o início da partição. Ao final, `/dev/nvme1n1p2` passa a
ser um btrfs puro.

### Avisos

- ⚠️ **Faça backup dos dados importantes antes. Não é opcional.** O processo
  reescreve ~1 TB de dados; queda de energia geralmente é retomável, mas erro
  de hardware ou de operação no meio pode corromper o sistema inteiro.
- O processo leva **algumas horas** em NVMe.
- Se for interrompido, rode o mesmo comando de novo — ele retoma de onde parou.
- Todo o processo é feito **offline**, a partir do pendrive do Arch ISO
  (a partição root não pode estar montada nem o volume LUKS aberto).

### Passo 1 — Boot pelo Arch ISO

Boot pelo pendrive de instalação do Arch. Não monte nada e não rode
`cryptsetup open`.

### Passo 2 — Descriptografar

```bash
cryptsetup reencrypt --decrypt --header /root/luks-header.img /dev/nvme1n1p2
```

Ele pedirá a senha do LUKS e confirmará a operação. O `--header` é
obrigatório: o cryptsetup exporta o cabeçalho LUKS2 para esse arquivo e passa a
usá-lo enquanto move os dados para o início da partição.

> **Importante:** `/root` do live ISO fica na RAM. Se o processo for
> interrompido por reboot, o arquivo de header some e a retomada fica bem mais
> complicada. Para mais segurança, salve o header em mídia persistente (por
> exemplo, monte um segundo pendrive e use `--header /mnt/usb/luks-header.img`).
> Se interromper com Ctrl+C (sem reboot), basta repetir o comando com o mesmo
> caminho de header.

Ao terminar, confirme:

```bash
blkid /dev/nvme1n1p2
# deve mostrar TYPE="btrfs" e UUID eb227d7f-080e-4560-8e8a-c0c6659bb7fa
```

### Passo 3 — Montar e entrar no sistema

```bash
mount -o subvol=@ /dev/nvme1n1p2 /mnt
mount /dev/nvme1n1p1 /mnt/boot
arch-chroot /mnt
```

### Passo 4 — Remover o hook de criptografia do initramfs

Em `/etc/mkinitcpio.conf`, remova `sd-encrypt` da linha `HOOKS`:

```bash
# Antes:
HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block sd-encrypt filesystems fsck)
# Depois:
HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)
```

Regenere o initramfs:

```bash
mkinitcpio -P
```

### Passo 5 — Ajustar o systemd-boot

Edite `/boot/loader/entries/arch.conf`. Remova o parâmetro `rd.luks.name=...`
e troque `root=/dev/mapper/cryptroot` pelo UUID do btrfs:

```bash
# Antes:
options rd.luks.name=a343b1de-d06d-4783-9068-15f32b0a09c5=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ mitigations=off nvidia-drm.modeset=1 rw quiet
# Depois:
options root=UUID=eb227d7f-080e-4560-8e8a-c0c6659bb7fa rootflags=subvol=@ mitigations=off nvidia-drm.modeset=1 rw quiet
```

### Passo 6 — Reiniciar

```bash
exit
umount -R /mnt
reboot
```

### Passo 7 — Limpeza (depois de confirmar que tudo funciona)

Apague o header exportado (`luks-header.img`) — ele contém material de chave e
não serve mais para nada. Se estiver em pendrive, apague de lá também.

---

## Opção B — Manter o LUKS2 e desbloquear automaticamente via TPM2

Alternativa se a motivação é apenas **não digitar a senha no boot**: a chave é
selada no TPM2 e o systemd desbloqueia o volume automaticamente. O disco
continua criptografado — se for removido da máquina ou o firmware for
adulterado (dependendo dos PCRs escolhidos), a senha volta a ser exigida.

Vantagens sobre a Opção A: reversível em segundos, sem reescrever o disco,
sem janela de risco, e mantém proteção contra roubo físico do disco.

### Passo 1 — Enrolar a chave no TPM2 (no sistema rodando, sem live USB)

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme1n1p2
```

Ele pede a senha atual do LUKS e grava um novo keyslot selado ao TPM.

Sobre os PCRs (registros de medição do firmware que "travam" a chave):

- `--tpm2-pcrs=7` (recomendado): a chave só é liberada se o estado do Secure
  Boot não mudar. Como seu Secure Boot está **desabilitado**, PCR 7 ainda
  funciona, mas a proteção prática é menor — qualquer sistema bootado nessa
  máquina consegue desbloquear o disco.
- `--tpm2-pcrs=0+7`: adiciona medição do firmware/UEFI; updates de BIOS
  passam a exigir a senha até re-enrolar.
- `--tpm2-pcrs=""` (vazio): sem vínculo a PCRs — conveniência máxima,
  proteção só contra o disco ser lido *fora* desta máquina.
- Para proteção real contra "evil maid", o ideal seria habilitar Secure Boot
  com UKI assinada — fora do escopo deste documento.

Opcional: `--tpm2-with-pin=yes` exige um PIN curto no boot (mais fraco de
digitar que a passphrase, mas ainda um segundo fator).

### Passo 2 — Garantir suporte a TPM no initramfs

Seu initramfs já usa os hooks systemd (`systemd` + `sd-encrypt`), que é o
requisito. Só é preciso garantir que o módulo do TPM entre no initramfs.
Em `/etc/mkinitcpio.conf`, adicione à linha `MODULES`:

```bash
MODULES=(tpm_crb)
```

(`tpm_crb` cobre TPMs de firmware Intel/AMD modernos; se não funcionar,
verifique o driver com `ls /sys/class/tpm/tpm0/device/driver` e use o módulo
correspondente, por exemplo `tpm_tis`.)

Regenere:

```bash
sudo mkinitcpio -P
```

### Passo 3 — Ativar o uso do TPM no boot

Adicione `rd.luks.options=tpm2-device=auto` às opções do kernel em
`/boot/loader/entries/arch.conf`:

```bash
options rd.luks.name=a343b1de-d06d-4783-9068-15f32b0a09c5=cryptroot rd.luks.options=tpm2-device=auto root=/dev/mapper/cryptroot rootflags=subvol=@ mitigations=off nvidia-drm.modeset=1 rw quiet
```

### Passo 4 — Reiniciar e testar

```bash
reboot
```

O boot deve seguir direto, sem pedir senha. **Não remova a passphrase
original** — ela continua num keyslot separado e é o seu fallback se o TPM
recusar a liberação (update de BIOS, troca de placa-mãe, mudança nos PCRs).

### Gerenciamento

```bash
# Ver keyslots enrolados:
sudo systemd-cryptenroll /dev/nvme1n1p2

# Re-enrolar depois de um update de BIOS que invalidou os PCRs:
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme1n1p2

# Reverter tudo (remover o slot TPM):
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme1n1p2
# e remover rd.luks.options=tpm2-device=auto do arch.conf
```

---

## Qual escolher?

- **Opção B (TPM2)** se o incômodo é só a senha no boot: reversível, rápida,
  sem risco de perda de dados e mantém o disco protegido contra roubo físico.
- **Opção A (remoção)** se você realmente não quer mais criptografia (por
  exemplo, para dual-boot ler a partição, ou por desempenho — embora em NVMe
  com AES-NI a diferença seja pequena). Exige backup e horas de reescrita.
