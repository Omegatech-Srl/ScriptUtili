<div align="center">
<img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT3HkrFkToxF0Hgrq_-LdbaUvDcHcNehHhQug&s" />
</div>

Script per effettuare rapido speedtest, da powershell eseguire:

```
irm https://raw.githubusercontent.com/matteomegatech/ScriptUtili/main/speedtest | iex
```

Per rimuovere Office dal PC

```
irm https://raw.githubusercontent.com/matteomegatech/ScriptUtili/main/RimozioneMSOffice | iex
```

Lo script per esecuzione comandi remoti su Sophos deve essere eseguito da una macchina UNIX su cui è installato il pacchetto sshpass

Per installare agent Zabbix e puntarlo a 145.14.161.84

```
irm https://raw.githubusercontent.com/Omegatech-Srl/ScriptUtili/main/Installazione%20Zabbix%20Agent | iex
```

Su Windows server >2016 è necessario forzare l'utilizzo di TLS 1.2 con il comando sotto
```
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```
