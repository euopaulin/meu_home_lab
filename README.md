# meu_home_lab

### Configurar SSH

1 - 
sudo apt update
sudo apt install -y openssh-server

2 - Ativar ssh
sudo systemctl enable --now ssh

3 - Verificar se está funcionando
sudo systemctl status ssh

4 - Descobrir IP para conectar
hostname -I

5 - Concetar pelo outro PC
ssh SEU_USUARIO@IP_DO_UBUNTU

### Fazer com que not não entre em suspensão após fechar tampa

1 - Acessar
sudo nano /etc/systemd/logind.conf

2 - Editar colocando sem #
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore

3 - Salvar

4 - Aplicar
sudo systemctl restart systemd-logind

5 - Reiniciar sistema
sudo reboot

### Ver porcentagem de bateria do not pelo terminal
upower -i $(upower -e | grep BAT)