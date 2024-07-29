#!/bin/bash

#COMPILARE IL CAMPO VARIABILI CON I DATI DEL FIREWALL SUL QUALE LANCIARE I COMANDI

#Variabili
HOST="INDIRIZZO_IP_FIREWALL"
USER="USERNAME"
PASS="PASSWORD"
COMMAND="COMANDO_DA_LANCIARE"
MAX_RETRIES=3
RETRY_DELAY=10  # secondi

# Funzione che esegue il comando e checka la risposta
execute_command() {
    echo "Executing command..."
    sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$USER@$HOST" "/bin/sh -c \"$COMMAND\"" > output.log 2> error.log
    
    # Cattura l'ouput e controlla se ha avuto successo o no
    OUTPUT=$(cat output.log)
    echo "Output:"
    echo "$OUTPUT"
    
    if echo "$OUTPUT" | grep -q "200 OK"; then
        echo "Riavvio servizio OK"
        return 0
    elif echo "$OUTPUT" | grep -q "503 Service Failed"; then
        echo "Riavvio servizio fallito"
        return 1
    else
        echo "Risposta inaspettata."
        return 2
    fi
}

# Logica di retry
retry_count=0
while [ $retry_count -lt $MAX_RETRIES ]; do
    execute_command
    result=$?

    if [ $result -eq 0 ]; then
        echo "Comando eseguito con successo"
        exit 0
    elif [ $result -eq 1 ]; then
        echo "Riprovo in  $RETRY_DELAY secondi..."
        sleep $RETRY_DELAY
        retry_count=$((retry_count + 1))
    else
        echo "Risposta inaspettata"
        exit 1
    fi
done

echo "Tentativi massimi eseguiti, esco"
exit 1
