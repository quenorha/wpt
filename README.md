# mtig

## Description
Ce dépôt contient tout le nécessaire pour installer l'ensemble de containers suivant l'architecture suivante : 
<div style="text-align: center">
<img src="images/stack.png"
     alt="stack"/>
</div>

Des variables sont postées en MQTT via la bibliothèque e!COCKPIT WagoAppCloud. Le broker MQTT (Mosquitto) est hébergé sur le contrôleur. \
L'applicatif Telegraf est abonné au topic MQTT sur ce broker, et poste les données dans une base InfluxDB dans un container dédié. \
Enfin les données sont affichées via l'outil de visualisation Grafana.  \
Le client MQTT peut aussi bien être interne que distant.  \
L'outil de gestion de containers Portainer est également installé pour faciliter la maintenance des containers.

Le script dispose d'une interface graphique qui permet d'installer indépendamment différentes actions. \
En sélectionnant la première option, le script automatise l'installation de Docker sur la carte SD, le téléchargement des imagesD ocker, fichiers de configuration et package nécessaires et leurs installations.

Ce projet est en beta - son utilisation relève de votre responsabilité. 

## Prérequis

Ce script fonctionne sur les plateformes suivantes : 
- PFC200 G2
- Touch Panels 600
- Edge Controller

Le contrôleur doit être démarré depuis la flash interne, pas depuis une image bootable sur la carte SD.
Une carte SD (/media/sd) doit être insérée et préalablement formatée en ext4 via le WBM (Docker sera installé sur la carte SD).

Le PFC, Edge Controller ou TP600 doit disposer d'un accès à Internet (penser à renseigner DNS et Gateway).

La date et heure du contrôleur doivent être mises à jour pour éviter des erreurs lors de l'échange TLS. 
Dans le WBM, mettre à jour l'heure dans <em>Configuration / Clock</em> ou spécifier un serveur de temps dans <em>Ports and service / NTP Client</em>
En sélectionnant la synchronisation à un serveur de temps ou l'installation automatisée, le serveur time.google.com sera automatiquement ajouté.

## Installation
Se connecter en SSH au contrôleur via PuTTy par exemple, en tant que super utilisateur (<em>root / wago</em> par défaut, penser à le modifier).

Exécuter la commande suivante qui permet le téléchargement de ce script, lui donne les droits d'exécution et l'exécute.

```
wget https://raw.githubusercontent.com/quenorha/wpt/main/install.sh -O $PWD/install.sh && chmod +x $PWD/install.sh && $PWD/install.sh
```

## Configuration
 
###  1) Connexion au broker MQTT

Dans le cas où les données sont publiées en MQTT par un contrôleur WAGO, dans le WBM, au niveau de Configuration / Cloud Connectivity, configurer la connexion au broker comme suit :

	Service enabled : |X|
	Cloud Platform : MQTT AnyCloud
	Hostname : [Adresse IP du broker]
	Client ID  : NomduClientMQTT (ne peut être vide)
	Clean session : |X|
	TLS : | |
	Port : 1883
	CA file : /etc/ssl/certs/ca-certificates.crt (par défaut)
	User : 
	Password :
	Certification file : 
	Key file : 
	Use compression : | |
	Data protocol : Native MQTT
	Cache Mode : RAM (volatile)




### 2) Publication des données

Toujours dans le cas où les données sont publiées en MQTT par un contrôleur WAGO, télécharger et adapter le <a href="https://raw.githubusercontent.com/quenorha/mtig/main/WagoAppCloud_Influxdb_1.8.ecp">projet d'exemple e!COCKPIT</a>.

Le payload du message MQTT doit respecter le format InfluxDB line protocol :
	https://docs.influxdata.com/influxdb/v2.0/reference/syntax/line-protocol/
	
Dans cet exemple, le payload suivant est publié sur le topic wago/subtopic : 
 ```
collection1,type=simulation,name=Variable1 value=12
collection1,type=simulation,name=Variable2 value=5
...
 ```

Il est également possible de générer des données en MQTT directement depuis le script. \
Sélectionner l'<strong>Option 11 Génération de messages MQTT</strong> \

### 3) Telegraf
A l'installation de Telegraf, l'adresse IP de l'interface X1 est lue et proposée comme adresse de Broker, elle peut être modifiée au profit d'un broker distant. 
Si besoin le fichier <b>/root/config/telegraf.conf</b> (dans le dossier /root/conf) peut être modifié davantage pour modifier le topic MQTT par exemple.
Une fois la configuration modifiée, redémarrer le container Telegraf. 
 ```
 docker restart c_telegraf
 ```	 
Consulter les logs pour vérifier le bon fonctionnement (également possible depuis Portainer)
```
docker logs c_telegraf
```		 

### 4) Grafana

Se connecter à la page http://[adresseIPduContrôleur]:3000.  \
S'authentifier via admin / admin. \
Le mot de passe doit être modifié à la première connexion.  \
La connexion à la base de données InfluxDB est automatiquement configurée à la création du container.
Un dashboard d'exemple est aussi ajouté, il est disponible dans Dashboards / Manage.

## Evolution
Le MQTT doit être sécurisé en mettant en place les certificats TLS. 

## Crédits
L'interface sous forme de menu est basée sur le [WAGO Provisioning Tool](https://github.com/braunku/pfc-provisioning-tool) de Kurt Braun (braunku) 
