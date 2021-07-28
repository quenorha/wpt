#!/bin/sh

	repo=https://raw.githubusercontent.com/quenorha/wpt

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
	printf "${menu} ${number} 6)${menu} Installation de containers${normal}\n"
	printf "${menu} ${number} 7)${menu} Suppression des containers, images et volumes Docker${normal}\n"
	printf "${menu} ${number} 8)${menu} Désinstaller Docker${normal}\n"
    printf "${menu} ${number} 9)${menu} Redémarrer le contrôleur${normal}\n"
	printf "${menu} ${number} 10)${menu}Formater la carte SD${normal}\n"
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
    printf "${menu} ${number} c)${menu} Installation de Telegraf ${normal}\n"
    printf "${menu} ${number} d)${menu} Installation de Grafana ${normal}\n"
    printf "${menu} ${number} e)${menu}Installation de Portainer ${normal}\n"
    printf "${menu} ${number} 8)${menu} Menu Principal ${normal}\n"
    printf "${menu}*********************************************${normal}\n"
    printf "Sélectionner une option ou ${fgred}x pour quitter. ${normal}"
    read opt
}

enableipforwarding(){
	/etc/config-tools/config_routing -c general state=enabled
    printf "${green}IP Forwarding activé${normal}\n";
}

enablentp(){
	/etc/config-tools/config_sntp state=enable time-server-n=time.google.com update-time=600
	printf "${green}Synchronisation NTP configurée${normal}\n";
}

checkdocker(){
	return=$(docker info | grep "Root Dir")
	if [ "$return" == " Docker Root Dir: /media/sdcard/docker" ]; then
		printf "${green}Docker déjà installé sur la carte SD${normal}\n"
		docker=1
		dockeronsdcard=1
	else
		if [ "$return" == " Docker Root Dir: /home/docker" ]; then
			docker=1
			dockeronsdcard=0
			printf "${menu}Docker déjà installé sur la flash interne${normal}\n"
		else
			docker=0
			dockeronsdcard=0
			printf "${menu}Docker pas installé${normal}\n"
		fi
		
	
	fi	

}

movedockertoSD() {
	printf "${green}Déplacement docker vers la carte SD${normal}\n"
	printf "${green}Arrêt Docker${normal}\n"
	/etc/init.d/dockerd stop
	sleep 3
	cp -r /home/docker /media/sd
	#rm -r /home/docker
	cp /root/conf/daemon.json /etc/docker/daemon.json
	rm /tmp/docker_20.10.5_armhf.ipk
	printf "${green}Démarrage Docker${normal}\n"
	/etc/init.d/dockerd start
	sleep 3
	docker ps -a
}

installdocker(){
	
	
	printf "${green}Téléchargement du package Docker${normal}\n"
	wget https://github.com/WAGO/docker-ipk/releases/download/v1.0.4-beta/docker_20.10.5_armhf.ipk -O /tmp/docker_20.10.5_armhf.ipk 
	printf "${green}Téléchargement du fichier de configuration Docker${normal}\n"
	mkdir -p /root/conf
	wget $repo/main/conf/daemon.json -O /root/conf/daemon.json
	printf "${green}Installation Docker${normal}\n"
	opkg install /tmp/docker_20.10.5_armhf.ipk
	docker=1
	dockeronsdcard=0;
	printf "${green}Docker installé${normal}\n"
}

installmosquitto(){
	printf "${green}Téléchargement du fichier de configuration mosquitto.conf${normal}\n"
	mkdir -p /root/conf
	wget $repo/main/conf/mosquitto.conf -O /root/conf/mosquitto.conf 
	printf "${green}Démarrage Mosquitto${normal}\n"
	docker run -d -p 1883:1883 -p 9001:9001 --restart=unless-stopped --name c_mosquitto -v /root/conf/mosquitto.conf:/mosquitto/config/mosquitto.conf eclipse-mosquitto:2.0.11
}

installtelegraf(){
	docker network create wago
	printf "${green}Téléchargement du fichier de configuration telegraf.conf${normal}\n"
	mkdir -p /root/conf
	wget $repo/main/conf/telegraf.conf.template -O /root/conf/telegraf.conf.template
	brokerplaceholder='adresseipdubroker'	#default placeholder in telegraf.conf.template
	ipaddress=$(/etc/config-tools/get_eth_config X1 ip-address)
	read -p "Adresse IP broker [$ipaddress]: " mqttbroker
	mqttbroker=${mqttbroker:-$ipaddress}
	cp /root/conf/telegraf.conf.template /root/conf/telegraf.conf
	sed -i "s/$brokerplaceholder/$mqttbroker/g" /root/conf/telegraf.conf
	printf "${green}Fichier telegraf.conf généré${normal}\n"
	printf "${green}Démarrage Telegraf${normal}\n"
	docker run -d --restart=unless-stopped  --net=wago  --name=c_telegraf -v /root/conf/telegraf.conf:/etc/telegraf/telegraf.conf:ro telegraf:1.19.1
	printf "${green}Telegraf démarré${normal}\n"
}

installinfluxdb(){
	docker network create wago
	printf "${green}Création du volume v_influxdb${normal}\n"
	docker volume create v_influxdb
	printf "${green}Démarrage InfluxDB${normal}\n"
	docker run -d -p 8086:8086 --name c_influxdb --net=wago --restart unless-stopped -v v_influxdb influxdb:1.8.6
	printf "${green}InfluxDB démarré${normal}\n"
}

installgrafana(){
	docker network create wago
	mkdir -p /root/conf
	mkdir -p /root/conf/provisioning/
	mkdir -p /root/conf/provisioning/dashboards
	mkdir -p /root/conf/provisioning/datasources
	printf "${green}Téléchargement des fichiers de configurations${normal}\n"
	wget $repo/main/conf/provisioning/dashboards/dashboards.yaml -O  /root/conf/provisioning/dashboards/dashboards.yaml
	wget $repo/main/conf/provisioning/dashboards/example.json -O  /root/conf/provisioning/dashboards/example.json
	wget $repo/main/conf/provisioning/datasources/influxdb.yaml -O  /root/conf/provisioning/datasources/influxdb.yaml
	printf "${green}Création du volume v_grafana${normal}\n"
	docker volume create v_grafana
	printf "${green}Démarrage Grafana${normal}\n"
	docker run -d -p 3000:3000 --name c_grafana -e GF_PANELS_DISABLE_SANITIZE_HTML=true --net=wago --restart unless-stopped -v v_grafana -v /root/conf/provisioning/:/etc/grafana/provisioning/ grafana/grafana:8.0.0
	printf "${green}Grafana démarré${normal}\n"
	ipaddress=$(/etc/config-tools/get_eth_config X1 ip-address)
	printf "${green}Aller sur http://$ipaddress:3000 pour y accéder${normal}\n"
	printf "${green}A la première connexion, se connecter avec admin/admin${normal}\n"
	printf "${green}Une datasource renvoyant vers la base Influxdb a été automatiquement ajoutée${normal}\n"
	printf "${green}Un exemple de dashboard est disponible en naviguant vers Dashboards/Manage${normal}\n"
}

installportainer(){
	
	printf "${green}Création du volume v_portainer${normal}\n"
	docker volume create v_portainer
	printf "${green}Démarrage Portainer${normal}\n"
	docker run -d -p 8000:8000 -p 9000:9000 --name=c_portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v v_portainer:/data portainer/portainer-ce:2.6.1
	printf "${green}Portainer démarré${normal}\n"
	printf "${green}Aller sur http://$ipaddress:9000 pour y accéder${normal}\n"
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
	printf "${green}Arrêt des containers${normal}\n"
	docker stop $(docker ps -aq)
	printf "${green}Suppression des containers${normal}\n"
	docker rm $(docker ps -aq)
	printf "${green}Suppression des volumes${normal}\n"
	docker volume rm $(docker volume ls -q)
	printf "${green}Suppression des images${normal}\n"
	docker rmi $(docker images -q)
	printf "${green}Désinstallation de Docker${normal}\n"
	opkg remove docker
	printf "${green}Suppression du répertoire de travail Docker${normal}\n"
	rm -r /media/sd/docker
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


formatsdcard() {
	 printf "${number}Formater la carte ? Toutes les données s'y trouvant seront définitivement effacées.[y/n]${normal}\n"
	 read answer
	 if [ "$answer" == "y" ]; then
		 printf "${number}Formatage de la carte SD en cours ...${normal}\n"
		/etc/config-tools/format_medium device=/dev/mmcblk0p1 volume-name=wago fs-type=ext4
		printf "${green}Carte SD formatée.${normal}\n"
	 else
		 printf "${fgred}Formatage de la carte SD annulé par l'utilisateur${normal}\n"
	 fi
	
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
			checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				enableipforwarding;
				enablentp;
				checkdocker;
					if [ "$docker" -eq "0" ]; then 
						installdocker;
					else
						if [ "$dockeronsdcard" -eq "0" ]; then 
						movedockertoSD;
						fi
					fi
				installmosquitto;
				installinfluxdb;
				installtelegraf;
				installgrafana;
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
			checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				checkdocker;
				if [ "$docker" -eq "0" ]; then 
					installdocker;
				else
					if [ "$dockeronsdcard" -eq "0" ]; then 
					movedockertoSD;
					fi
				fi
			fi
            show_menu;
        ;;
		
		5) clear;
            option_picked "Option $opt sélectionnée - Installation de Docker sur la flash";
			checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				checkdocker;
				if [ "$docker" -eq "0" ]; then 
					installdocker;
				else
					if [ "$dockeronsdcard" -eq "1" ]; then 
						printf "${fgred}Docker est déjà installé sur la carte SD${normal}\n"		
					fi
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
            option_picked "Option $opt sélectionnée - Installation de Telegraf";
            checkconnectivity;
			if [ "$internet" -eq "1" ]; then
				installtelegraf;
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
        6) clear; # Docker sub-menu
            option_picked "Option $opt sélectionnée - Installation de containers";
            printf "Select Container";
            show_container_menu;
        ;;
        7) clear;
            option_picked "Option $opt sélectionnée - Suppression des containers, images et volumes Docker";
			deletedockercontent;
            show_menu;
        ;; 
		8) clear; # Return to main menu
			option_picked "Option $opt sélectionnée - Désinstallation de Docker";
			uninstalldocker;
            show_menu;
        ;;
        9) clear;
            option_picked "Option $opt sélectionnée - Redémarrage";
            reboot now;
            printf "PLC will restart";
            show_menu;
        ;;
		
		 10) clear;
            option_picked "Option $opt sélectionnée - Formatage de la carte SD";
            formatsdcard;
            show_menu;
        ;;
        x) clear;
            chmod +x menu.sh;
            printf "Type ./menu.sh to re-open this tool";
            printf "\n";
            exit;
        ;;
        \n)exit;
        ;;
        *)clear;
            option_picked "Pick an option from the menu";
            show_menu;
        ;;
      esac
    fi
done    