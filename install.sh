#!/bin/sh

	repo=https://raw.githubusercontent.com/quenorha/wpt


   grafanaimage=$"grafana/grafana-oss:10.1.2"
   portainerimage=$"portainer/portainer-ce:2.9.3"
   influxdbimage=$"influxdb:1.8.10"
   telegrafsnmpimage=$"quenorha/telegrafsnmp:arm"
   telegrafmqttimage=$"telegraf"
   telegrafdockerimage=$"telegraf"
   mosquittoimage=$"eclipse-mosquitto"

   normal=`echo "\033[m"`
    menu=`echo "\033[36m"` #blue
    number=`echo "\033[33m"` #yellow
    bgred=`echo "\033[41m"`
    fgred=`echo "\033[31m"`
	green=`echo "\e[92m"`

show_menu(){
    normal=`echo "\033[m"`
    menu=`echo "\033[36m"` #blue
    number=`echo "\033[33m"` #yellow
    bgred=`echo "\033[41m"`
    fgred=`echo "\033[31m"`

    printf "\n${menu}********* WAGO Provisioning Tool ***********${normal}\n"
    printf "${menu} ${number} 1)${menu} Installation automatisée ${normal}\n"
    printf "${menu} ${number} 2)${menu} Activation de l'IP Forwarding ${normal}\n"
	printf "${menu} ${number} 3)${menu} Synchronisation à un serveur NTP ${normal}\n"
    printf "${menu} ${number} 4)${menu} Installation de Docker sur la carte SD ${normal}\n"
	printf "${menu} ${number} 5)${menu} Installation de Docker sur la flash${normal}\n"
	printf "${menu} ${number} 6)${menu} Installation de containers > ${normal}\n"
	printf "${menu} ${number} 7)${menu} Suppression des containers, images et volumes Docker${normal}\n"
	printf "${menu} ${number} 8)${menu} Désinstallation de Docker${normal}\n"
    printf "${menu} ${number} 9)${menu} Redémarrage du contrôleur${normal}\n"
	printf "${menu} ${number} 10)${menu}Formatage de la carte SD${normal}\n"
	printf "${menu} ${number} 11)${menu}Génération de messages MQTT${normal}\n"
	printf "${menu} ${number} 13)${menu}Configuration de la connexion MQTT${normal}\n"
    printf "${menu}*********************************************${normal}\n"
    printf "Sélectionner une option ou ${fgred}x pour quitter. ${normal}"
    read opt
}

option_picked(){
    msgcolor=`echo "\033[01;31m"` # bold red
    normal=`echo "\033[00;00m"` # normal white
	green=`echo "\e[92m"`
    message=${@:-"${normal}Error: No message passed"}
    printf "${menu}${message}${normal}\n"
}

show_container_menu(){
    normal=`echo "\033[m"`
    menu=`echo "\033[36m"` #blue
    number=`echo "\033[33m"` #yellow
    bgred=`echo "\033[41m"`
    fgred=`echo "\033[31m"`
    printf "\n${menu}********* Containers Docker ***********${normal}\n"
    printf "${menu} ${number} a)${menu} Installation de Mosquitto ${normal}\n"
    printf "${menu} ${number} b)${menu} Installation de InfluxDB ${normal}\n"
    printf "${menu} ${number} c)${menu} Installation de Telegraf (MQTT) ${normal}\n"
    printf "${menu} ${number} d)${menu} Installation de Grafana ${normal}\n"
    printf "${menu} ${number} e)${menu} Installation de Portainer ${normal}\n"
    printf "${menu} ${number} f)${menu} Installation de Telegraf (SNMP) ${normal}\n"	
    printf "${menu} ${number} g)${menu} Installation de Telegraf (Docker) ${normal}\n"	
    printf "${menu} ${number} h)${menu} Menu Principal ${normal}\n"
    printf "${menu}*********************************************${normal}\n"
    printf "Sélectionner une option ou ${fgred}x pour quitter. ${normal}"
    read opt
}

checkifsdcardproperlymounted()
{ return=$(mount | grep /dev/mmcblk0p1 | awk -F" " '{print $3}')
		if [[ "$return" =~ "/media/" ]]; then
			printf "${green}Carte SD correctement montée${normal}\n"
		else
			 printf "${fgred}Carte SD mal montée${normal}\n"
		fi
}


enableipforwarding(){
	printf "${green}Activation de l'IP Forwarding${normal}\n";
	/etc/config-tools/config_routing -c general state=enabled
    printf "${green}IP Forwarding activé${normal}\n";
}

enablentp(){
	printf "${green}Ajout du serveur de temps time.google.com${normal}\n";
	/etc/config-tools/config_sntp state=enabled time-server-1=216.239.35.0 update-time=600
	printf "${green}Mise à jour de l'heure${normal}\n";
	/etc/config-tools/config_sntp update
	printf "${green}Synchronisation NTP configurée${normal}\n";
	date
}

checkdocker(){
	#is_installed=$(opkg list-installed | grep docker | awk -e '{print $3}' | tr '\n' ' ');
	if docker -v > /dev/null 2>&1; then
       docker=1
		/etc/init.d/dockerd start &
		wait
		return=$(docker system info --format '{{.DockerRootDir}}')
		if [[ "$return" =~ "/media/" ]]; then
			printf "${green}Docker déjà installé sur la carte SD${normal}\n"
			dockeronsdcard=1
		else
			if [[ "$return" =~ "/home/docker" ]]; then
				dockeronsdcard=0
				printf "${menu}Docker déjà installé sur la flash interne${normal}\n"
			fi
		fi
    else
        docker=0
		printf "${menu}Docker non installé${normal}\n"
    fi

}

movedockertoSD() {

    

	printf "${green}Déplacement docker vers la carte SD${normal}\n"
	
	printf "${green}Copie répertoire flash vers carte SD ${normal}\n"
	cp -r /home/docker /media/sd
	#rm -r /home/docker
	printf "${green}Modification de la configuration de Docker ${normal}\n"
	printf "${green}Téléchargement du fichier de configuration Docker${normal}\n"
	mkdir -p /root/conf
	curl -L $repo/main/conf/daemon.json -o /root/conf/daemon.json
	
	cp /root/conf/daemon.json /etc/docker/daemon.json
	cat /root/conf/daemon.json &
	printf "${green}Redémarrage Docker${normal}\n"
	/etc/init.d/dockerd restart
	while ! pidof dockerd > /dev/null; do
    echo "Waiting for Docker daemon to start..."
    sleep 5
    done
	checkdocker
	docker ps -a
}

installdocker(){
	
	if [ -f "/etc/config-tools/config_docker" ]; then #Docker installation embedded from >FW20 on PFC
		printf "${green}Installation Docker (via script config-tools) ${normal}\n"
       /etc/config-tools/config_docker install && /etc/config-tools/config_docker activate
	    while ! pidof dockerd > /dev/null; do
		echo "Waiting for Docker daemon to start..."
		sleep 5
		done
	   
	else
		printf "${green}Téléchargement du package Docker${normal}\n"
		curl -L https://github.com/WAGO/docker-ipk/releases/download/v1.0.5-beta/docker_20.10.14_armhf.ipk -o /tmp/docker_20.10.14_armhf.ipk
		printf "${green}Téléchargement du fichier de configuration Docker${normal}\n"
		mkdir -p /root/conf
		printf "${green}Installation Docker${normal}\n"
		opkg install /tmp/docker_20.10.14_armhf.ipk
	
    fi
	docker=1
	dockeronsdcard=0;
	printf "${green}Docker installé${normal}\n"  
	
	
}

installmosquitto(){
	docker network inspect wago >/dev/null 2>&1 || docker network create --driver bridge wago
	printf "${green}Téléchargement du fichier de configuration mosquitto.conf${normal}\n"
	mkdir -p /root/conf
	curl -L $repo/main/conf/mosquitto.conf -o /root/conf/mosquitto.conf -s
	printf "${green}Démarrage Mosquitto${normal}\n"
	docker run -d -p 1883:1883 -p 9001:9001 --restart=unless-stopped --net=wago --name c_mosquitto -v /root/conf/mosquitto.conf:/mosquitto/config/mosquitto.conf "$mosquittoimage"
}

installtelegrafmqtt(){
	docker network inspect wago >/dev/null 2>&1 || docker network create --driver bridge wago
	printf "${green}Téléchargement du fichier de configuration telegrafmqtt.conf${normal}\n"
	mkdir -p /root/conf
	curl -L $repo/main/conf/telegrafmqtt.conf -o /root/conf/telegrafmqtt.conf -s
	printf "${green}Démarrage Telegraf${normal}\n"
	docker run -d --restart=unless-stopped  --net=wago  --name=c_telegrafmqtt -v /root/conf/telegrafmqtt.conf:/etc/telegraf/telegraf.conf:ro "$telegrafmqttimage"
	printf "${green}Telegraf démarré${normal}\n"
}

installtelegrafdocker(){
	docker network inspect wago >/dev/null 2>&1 || docker network create --driver bridge wago
	printf "${green}Téléchargement du fichier de configuration telegrafdocker.conf${normal}\n"
	mkdir -p /root/conf
	curl -L $repo/main/conf/telegrafdocker.conf -o /root/conf/telegrafdocker.conf -s
	printf "${green}Démarrage Telegraf${normal}\n"
	docker run -d --user telegraf:$(stat -t /var/run/docker.sock | awk '{ print $6 }') --net=wago --restart=unless-stopped --name=c_telegrafdocker -v /var/run/docker.sock:/var/run/docker.sock -v /root/conf/telegrafdocker.conf:/etc/telegraf/telegraf.conf:ro "$telegrafdockerimage"
	printf "${green}Telegraf démarré${normal}\n"
}

installinfluxdb(){
	docker network inspect wago >/dev/null 2>&1 || docker network create --driver bridge wago
	printf "${green}Création du volume v_influxdb${normal}\n"
	docker volume create v_influxdb
	printf "${green}Démarrage InfluxDB${normal}\n"
	docker run -d -p 8086:8086 --name c_influxdb --net=wago --restart unless-stopped -v v_influxdb:/var/lib/influxdb "$influxdbimage"
	printf "${green}InfluxDB démarré${normal}\n"
}

installgrafana(){
	docker network inspect wago >/dev/null 2>&1 || docker network create --driver bridge wago
	mkdir -p /root/conf
	mkdir -p /root/conf/provisioning/
	mkdir -p /root/conf/provisioning/dashboards
	mkdir -p /root/conf/provisioning/datasources
	printf "${number}Autoriser l'ajout de script dans les Text Panels ? [y/n]${normal}"
    read opt
	printf "${green}Téléchargement des fichiers de configurations${normal}\n"
	curl -L $repo/main/conf/provisioning/dashboards/dashboards.yaml -o /root/conf/provisioning/dashboards/dashboards.yaml -s
	curl -L $repo/main/conf/provisioning/dashboards/example.json -o /root/conf/provisioning/dashboards/example.json -s
	curl -L $repo/main/conf/provisioning/dashboards/mqtt_status.json -o  /root/conf/provisioning/dashboards/mqtt_status.json -s
	curl -L $repo/main/conf/provisioning/datasources/influxdb.yaml -o  /root/conf/provisioning/datasources/influxdb.yaml -s
	if [ "$opt" == "y" ]; then
		curl -L $repo/main/conf/provisioning/dashboards/webvisu_example.json -o  /root/conf/provisioning/dashboards/webvisu_example.json -s
		ipaddress=$(/etc/config-tools/get_actual_eth_config X1 ip-address)
		brokerplaceholder='adresseIPducontroleur'
		sed -i "s/$brokerplaceholder/$ipaddress/g" /root/conf/provisioning/dashboards/webvisu_example.json
	fi
	printf "${green}Création du volume v_grafana${normal}\n"
	docker volume create v_grafana
	
	printf "${green}Démarrage Grafana${normal}\n"
	
	if [ "$opt" == "y" ]; then
		docker run -d -p 3000:3000 --name c_grafana -e GF_PANELS_DISABLE_SANITIZE_HTML=true --net=wago --restart unless-stopped -v v_grafana:/var/lib/grafana -v /root/conf/provisioning/:/etc/grafana/provisioning/ "$grafanaimage"
	else
		docker run -d -p 3000:3000 --name c_grafana --net=wago --restart unless-stopped -v v_grafana:/var/lib/grafana -v /root/conf/provisioning/:/etc/grafana/provisioning/ "$grafanaimage"
	fi
	printf "${green}Grafana démarré${normal}\n"
	printf "${green}Aller sur https://[adresseIP]:3000 pour y accéder${normal}\n"
	printf "${green}A la première connexion, se connecter avec admin/admin${normal}\n"
	printf "${green}Une datasource renvoyant vers la base Influxdb a été automatiquement ajoutée${normal}\n"
	printf "${green}Un exemple de dashboard est disponible en naviguant vers Dashboards/Manage${normal}\n"
}

installportainer(){
	
	printf "${green}Création du volume v_portainer${normal}\n"
	docker volume create v_portainer
	printf "${green}Démarrage Portainer${normal}\n"
	docker run -d -p 8000:8000 -p 9443:9443 --name=c_portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v v_portainer:/data "$portainerimage"
	printf "${green}Portainer démarré${normal}\n"
	printf "${green}Aller sur https://[adresseIP]:9443 pour y accéder${normal}\n"
	printf "${green}En l'absence de connexion au bout de 5 min l'accès sera bloqué par mesure de sécurité${normal}\n"
}


installtelegrafsnmp(){
	docker network inspect wago >/dev/null 2>&1 || docker network create --driver bridge wago
	printf "${green}Téléchargement du fichier de configuration telegraf.conf pour SNMP ${normal}\n"
	mkdir -p /root/conf
	curl -L https://raw.githubusercontent.com/quenorha/snmp_monitoring/main/telegrafsnmp.conf  -o /root/conf/telegrafsnmp.conf -s
	printf "${green}Fichier telegraf.conf généré${normal}\n"
	printf "${green}Démarrage Telegraf${normal}\n"
	docker run -d --net=wago --restart=unless-stopped --name=c_telegrafsnmp -v /root/conf/telegrafsnmp.conf:/etc/telegraf/telegraf.conf:ro "$telegrafsnmpimage"	
	printf "${green}Telegraf SNMP démarré${normal}\n"
}



deletedockercontent(){
	printf "${green}Arrêt des containers${normal}\n"
	docker stop $(docker ps -aq)
	printf "${green}Suppression des containers${normal}\n"
	docker rm $(docker ps -aq)
	printf "${green}Suppression des volumes${normal}\n"
	docker volume rm $(docker volume ls -q)
	printf "${green}Suppression des images${normal}\n"
	docker rmi $(docker images -q)
}

uninstalldocker(){
	deletedockercontent;
	printf "${green}Désinstallation de Docker${normal}\n"
	if [ -f "/etc/config-tools/config_docker" ]; then #Docker installation embedded from >FW20 on PFC
		printf "${green}Désinstallation Docker (via script config-tools) ${normal}\n"
       /etc/config-tools/config_docker deactivate
	   /etc/config-tools/config_docker remove
	else
		printf "${green}Désinstallation Docker (via opkg) ${normal}\n"
		opkg remove docker
	fi
	printf "${green}Suppression du répertoire de travail Docker${normal}\n"
	if [ "$dockeronsdcard" -eq "1" ]; then 
		rm -r /media/sd/docker
	else	
		rm -r /home/docker
	fi
	
}


checkconnectivity() {
wget -q --spider http://google.com

if [ $? -eq 0 ]; then
    printf "${green}Accès Internet détecté${normal}\n"
	internet=1

else
	internet=0
    printf "${fgred}Aucun accès Internet détecté, vérifier les paramètres DNS et Gateway${normal}\n"
fi	
}

setbrokerconnection()
{
ipaddress=$(/etc/config-tools/get_actual_eth_config X1 ip-address)
read -p "Adresse IP broker [$ipaddress]: " mqttbroker
mqttbroker=${mqttbroker:-$ipaddress}
 printf "${green}Configuration de la connexion au broker${normal}\n"
/etc/config-tools/config_cloudconnectivity set -c 1 -p CloudType=AnyMQTT -p ClientId=PFC -p Host=$ipaddress -p Port=1883 -p UseTLS=false -p MessagingProtocol=NativeMQTT -p Enabled=true
 printf "${green}Redémarrage de la connexion Cloud${normal}\n"
/etc/init.d/dataagent stop && /etc/init.d/dataagent start
sleep 2
printf "${green}Connexion MQTT configurée, pour ajuster les paramètres, aller sur https://$ipaddress/wbm/#/configuration/cloud-connectivity/ccconnection1${normal}\n"
}



formatsdcard() {
	 printf "${number}Formater la carte ? Toutes les données s'y trouvant seront définitivement effacées.[y/n]${normal}\n"
	 read answer
	 if [ "$answer" == "y" ]; then
		 printf "${number}Formatage de la carte SD en cours ...${normal}\n"
		/etc/config-tools/format_medium device=/dev/mmcblk0 volume-name=sd fs-type=ext4
		wait
		printf "${green}Carte SD formatée.${normal}\n"
	 else
		 printf "${fgred}Formatage de la carte SD annulé par l'utilisateur${normal}\n"
	 fi
	
}


generatemqttdata() {
angle=0
step_angle=5
vert_plot=0
horiz_plot=5
centreline=12
amplitude=11
PI=3.14159
clear

	ipaddress=$(/etc/config-tools/get_actual_eth_config X1 ip-address)
	read -p "Adresse IP broker [$ipaddress]: " mqttbroker
	mqttbroker=${mqttbroker:-$ipaddress}
# Do a single cycle, quantised graph.
while [ $angle -le 359 ]
do
       
        vert_plot=$(awk "BEGIN{ printf \"%.12f\", ((sin($angle*($PI/180))*$amplitude)+$centreline)}")
       
        vert_plot=$((24-${vert_plot/.*}))
       
        printf "\x1B["$vert_plot";"$horiz_plot"f*"
		#printf "\x1B[24;1f$angle/360"
        printf "\x1B[25;1fAngle : $angle => message : 'fakedata,location=Roissy,name=Angle value=$angle'"
		printf "\x1B[26;1fHauteur : $vert_plot => message : 'fakedata,location=Roissy,name=Hauteur value=$vert_plot'"
		printf "\x1B[27;1fLongueur : $horiz_plot => message : 'fakedata,location=Roissy,name=Longueur value=$horiz_plot'"
		printf "\x1B[28;1fAppuyer sur n'importe quelle touche pour arrêter..." 
		if read -r -N 1 -t 1; then
			break;
		fi	
        sleep 1
      
        angle=$((angle+step_angle))
        horiz_plot=$((horiz_plot+1))
        mosquitto_pub -h $mqttbroker -t wago/fakedata -m "fakedata,location=Roissy,name=Hauteur value=$vert_plot"
        mosquitto_pub -h $mqttbroker -t wago/fakedata -m "fakedata,location=Roissy,name=Longueur value=$horiz_plot"
        mosquitto_pub -h $mqttbroker -t wago/fakedata -m "fakedata,location=Roissy,name=Angle value=$angle"
done
clear
printf "${green}Fin de la génération de messages MQTT${normal}\n"

}


clear
show_menu
while [ $opt != '' ]
    do
    if [ $opt = '' ]; then
      exit;
    else
      case $opt in
	  
		1) clear; 
			option_picked "Option $opt sélectionnée - Installation automatisée";
			printf "${number}Cette installation va réaliser les étapes suivantes :${normal}\n"
			printf "${menu} ${number} [ ]${menu} Activation de l'IP Forwarding ${normal}\n"
			printf "${menu} ${number} [ ]${menu} Synchronisation à un serveur NTP ${normal}\n"
			printf "${menu} ${number} [ ]${menu} Installation de Docker sur la carte SD ${normal}\n"
			printf "${menu} ${number} [ ]${menu} Installation de Portainer ${normal}\n"
			printf "${menu} ${number} [ ]${menu} Installation de Mosquitto ${normal}\n"
			printf "${menu} ${number} [ ]${menu} Installation de InfluxDB ${normal}\n"
			printf "${menu} ${number} [ ]${menu} Installation de Telegraf ${normal}\n"
			printf "${menu} ${number} [ ]${menu} Installation de Grafana ${normal}\n"
			printf "${number}Lancer l'installation ? [y/n]${normal}\n"
			 read answer
			clear
			
			 if [ "$answer" == "y" ]; then
				checkconnectivity; 
				
				if [ "$internet" -eq "1" ]; then
					enableipforwarding;
					
				
					enablentp;
					
					formatsdcard;
				
					
					checkdocker;
						if [ "$docker" -eq "0" ]; then 
								installdocker;
						fi
						if [ "$dockeronsdcard" -eq "0" ]; then 
								movedockertoSD;
						fi
					
					
					installportainer;
					
					
					installmosquitto;
					
					
					installinfluxdb;
					
				
					installtelegrafmqtt;
					
					
					installgrafana;
					
					docker ps -a;
				fi
			 else
				 printf "${fgred}Installation automatisée annulée par l'utilisateur${normal}\n"
			 fi
			
			
			show_menu;
			;;	
        2) clear;
            option_picked "Option $opt sélectionnée - Activation de l'IP Forwarding";
            enableipforwarding;
            show_menu;
        ;;
        3) clear;
            option_picked "Option $opt sélectionnée - Synchronisation à un serveur NTP";
			checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				enablentp;
			fi
            show_menu;
        ;;
        4) clear;
            option_picked "Option $opt sélectionnée - Installation de Docker sur la carte SD";
			checkdocker;
				if [ "$docker" -eq "0" ]; then 
					checkconnectivity;
					if [ "$internet" -eq "1" ]; then
						installdocker;
						movedockertoSD;
					fi
				else
					if [ "$dockeronsdcard" -eq "0" ]; then 
					movedockertoSD;
					fi
				fi
	
            show_menu;
        ;;
		
		5) clear;
            option_picked "Option $opt sélectionnée - Installation de Docker sur la flash";
		
				checkdocker;
				if [ "$docker" -eq "0" ]; then 
						checkconnectivity;
					if [ "$internet" -eq "1" ]; then
					installdocker;
					fi
				else
					if [ "$dockeronsdcard" -eq "1" ]; then 
						printf "${fgred}Docker est déjà installé sur la carte SD${normal}\n"		
					fi
				fi
			
            show_menu;
        ;;
		
		a) clear;
            option_picked "Option $opt sélectionnée - Installation de Mosquitto";
			checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				installmosquitto;
			fi
            show_container_menu;
        ;;
		
		b) clear;
            option_picked "Option $opt sélectionnée - Installation de InfluxDB";
            checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				installinfluxdb;
			fi
            show_container_menu;
        ;;
		
		c) clear;
            option_picked "Option $opt sélectionnée - Installation de Telegraf (MQTT)";
            checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				installtelegrafmqtt;
			fi
            show_container_menu;
        ;;
        d) clear;
           option_picked "Option $opt sélectionnée - Installation de Grafana";
           checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				installgrafana;
			fi
           show_container_menu;
		;; 
		e) clear;
           option_picked "Option $opt sélectionnée - Installation de Portainer";
            checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				installportainer;
			fi
           show_container_menu;
        ;;
		f) clear;
           option_picked "Option $opt sélectionnée - Installation de Telegraf SNMP";
            checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				installtelegrafsnmp;
			fi
           show_container_menu;
        ;;
		g) clear;
           option_picked "Option $opt sélectionnée - Installation de Telegraf Docker";
            checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				installtelegrafdocker;
			fi
           show_container_menu;
        ;;
		h) clear;
           option_picked "Option $opt sélectionnée - Retour au menu principal ";
           
          show_menu;
        ;;
        6) clear; # Docker sub-menu
            option_picked "Option $opt sélectionnée - Installation de containers";
            printf "Select Container";
            show_container_menu;
        ;;
        7) clear;
            option_picked "Option $opt sélectionnée - Suppression des containers, images et volumes Docker";
			printf "${number}Supprimer les containers, images et volumes Docker ? Toutes les données seront définitivement effacées.[y/n]${normal}\n"
			read answer
			if [ "$answer" == "y" ]; then
				deletedockercontent;
			fi	
            show_menu;
        ;; 
		8) clear; 
			option_picked "Option $opt sélectionnée - Suppression des containers, images et volumes Docker";
			printf "${number}Désinstaller Docker et supprimer les containers, images et volumes ? Toutes les données seront définitivement effacées.[y/n]${normal}\n"
			read answer
			if [ "$answer" == "y" ]; then
			option_picked "Option $opt sélectionnée - Désinstallation de Docker";
			uninstalldocker;
			fi
            show_menu;
        ;;
		9) clear;
            option_picked "Option $opt sélectionnée - Redémarrage";
            reboot now;
            printf "Le contrôleur va redémarrer";
        ;;
		
		 10) clear;
            option_picked "Option $opt sélectionnée - Formatage de la carte SD";
            formatsdcard;
            show_menu;
        ;;
		 11) clear;
			option_picked "Option $opt sélectionnée - Génération de messages MQTT";
			generatemqttdata;
			 show_menu;
		;;
		
		12) clear;
			option_picked "Option $opt sélectionnée - Configuration de la connexion au broker";
			setbrokerconnection;
			 show_menu;
		;;
        x) clear;
            #chmod +x menu.sh;
            printf "Saisir ./install.sh pour réouvrir cet outil";
            printf "\n";
            exit;
        ;;
        \n)exit;
        ;;
        *)clear;
            option_picked "Sélectionner une option dans le menu";
            show_menu;
        ;;
      esac
    fi
done    
