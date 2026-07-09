# CloudStack role

> 🇫🇷 Version française de [README.md](README.md). En cas de divergence, le README anglais fait foi (ce dépôt est un fork upstream).

Auteur : Brad House<br/>
Licence : MIT<br/>
Dépôt d'origine : https://github.com/bradh352/ansible-role-service-cloudstack

## Vue d'ensemble

Ce rôle est conçu pour déployer des nœuds de management CloudStack et des nœuds hyperviseurs kvm.

Ce rôle cible initialement Ubuntu, et a été testé sur 24.04LTS.

Ce rôle peut également partir du principe qu'il a été déployé conjointement
avec ceux-ci, exécutés dans l'ordre ci-dessous :
 - [base_linux](https://github.com/bradh352/ansible-role-base-linux)
   - Utilisé pour le durcissement système.
 - [network_vxlanevpn](https://github.com/bradh352/ansible-role-network-vxlanevpn)
   - Si VXLAN doit être utilisé, ce rôle est utile, bien que non strictement
     requis.
 - [service_ceph](https://github.com/bradh352/ansible-role-service-ceph)
   - Nécessite la création d'un export NFS associé à un export CephFS.
 - [service_mariadb](https://github.com/bradh352/ansible-role-service-mariadb)
   - S'il y a plus d'un nœud de management, nécessite une configuration en cluster galera.
 - [service_keepalived](https://github.com/bradh352/ansible-role-service-keepalived)
   - S'il y a plus d'un nœud de management, requis pour créer des IP Virtuelles pour
     l'accès à la base de données (le verrouillage cloudstack ne permet pas d'utiliser n'importe quel nœud).
   - Il peut également être souhaitable de créer une IP Virtuelle pour l'interface
     de management cloudstack, cependant, quelque chose comme HAProxy pourrait aussi être utilisé
     pour répartir le trafic entre les nœuds
 - [service_certbot](https://github.com/bradh352/ansible-role-service-certbot)
   - Utilisé pour provisionner les certificats TLS

## Groupes utilisés par ce rôle
- `cloudstack_mgmt` : Membres sur lesquels des nœuds de management seront déployés
- `cloudstack_kvm` : Membres qui seront mis en service en tant qu'Hyperviseurs KVM

## Variables principales utilisées par ce rôle

***NOTE*** : La base de données cloudstack est toujours nommée `cloud` et la base de
données d'usage est toujours `cloud_usage`. Il n'est pas possible de les modifier.

### Variables utilisées à la fois par les nœuds de Management et d'Hyperviseur

- `cloudstack_version` : Série de version (release series) à utiliser. Par ex. 4.20

### Variables utilisées uniquement par les nœuds hyperviseurs KVM

- `cloudstack_zone` : Optionnel. Nom de la zone (parmi `cloudstack_zones`
  ci-dessous) sous laquelle enregistrer cet hôte. Si absent, l'hôte n'est pas
  enregistré dans CloudStack (seulement installé/configuré comme agent).
- `cloudstack_pod` : Requis si `cloudstack_zone` est défini. Nom du pod sous
  lequel enregistrer cet hôte.
- `cloudstack_cluster` : Requis si `cloudstack_zone` est défini. Nom du
  cluster sous lequel enregistrer cet hôte.

### Variables utilisées par les nœuds de Management

- `cloudstack_hostname` : Nom d'hôte par lequel les utilisateurs accéderont à cloudstack.
  Cela mettra automatiquement à jour le paramètre `endpoint.url` ainsi :
  `https://{cloudstack_hostname}/client/api`. Un enregistrement DNS `A` est requis pour
  pointer vers ce nom avec l'IP Virtuelle assignée à l'instance cloudstack.
- `cloudstack_tlscert` : Le chemin vers le certificat TLS complet incluant
  les intermédiaires.
  NOTE : Devrait être le chemin de sortie de certbot.
- `cloudstack_tlskey` : Le chemin vers la clé privée TLS du certificat.
- `cloudstack_console_hostname` : Suffixe de domaine pour les proxies de console. Les proxies
  seront automatiquement créés en utilisant `NNN-NNN-NNN-NNN.{{ cloudstack_console_hostname }}`.
  Doit disposer d'une entrée DNS wildcard pour ce suffixe.
- `cloudstack_console_tlscert` : Le chemin vers le certificat TLS complet incluant
  les intermédiaires pour `*.{{ cloudstack_console_hostname }}`.
  NOTE : Devrait être le chemin de sortie de certbot.
- `cloudstack_console_tlskey` : Le chemin vers la clé privée TLS du certificat.
- `cloudstack_ssvm_hostname` : Suffixe de domaine pour les vms de stockage secondaire. Les VMs
  seront automatiquement créées en utilisant `NNN-NNN-NNN-NNN.{{ cloudstack_ssvm_hostname }}`.
  Doit disposer d'une entrée DNS wildcard pour ce suffixe.
- `cloudstack_ssvm_tlscert` : Le chemin vers le certificat TLS complet incluant
  les intermédiaires pour `*.{{ cloudstack_ssvm_hostname }}`.
  NOTE : Devrait être le chemin de sortie de certbot.
- `cloudstack_ssvm_tlskey` : Le chemin vers la clé privée TLS du certificat.
- `cloudstack_public_subnet` : Le sous-réseau du réseau public. Ceci est utilisé
  pour générer une règle pour les adresses ip de proxy autorisées pour ssvm et consoleproxy.
  par ex. `192.168.1.0/24` ou `10.10.16.0/20`
- `mariadb_root_password` : Requis. Même mot de passe que celui utilisé lors du déploiement de
  mariadb. Suppose actuellement que MariaDB s'exécute sur le même nœud dans le cadre du
  cluster. Devrait être stocké dans le vault.
- `cloudstack_db_user` : Utilisateur de base de données à créer pour 'cloudstack'.
- `cloudstack_db_password` : Requis. Mot de passe à associer à l'utilisateur de la base de
  données cloudstack. Devrait être stocké dans le vault.
- `cloudstack_mgmt_key` : Requis. Clé de chiffrement utilisée pour stocker les identifiants dans
  le fichier de propriétés Cloudstack. Cela devrait être une chaîne de texte générée
  aléatoirement (par ex. de la même forme qu'un mot de passe fort).
- `cloudstack_db_key` : Requis. Clé de chiffrement utilisée pour stocker les identifiants dans
  la base de données Cloudstack. Cela devrait être une chaîne de texte générée
  aléatoirement (par ex. de la même forme qu'un mot de passe fort).
- `cloudstack_ceph_fs` : Requis. Nom du ceph fs à utiliser pour le stockage secondaire.
- `cloudstack_mgmt_interface` : Requis. Nom de l'interface réseau sur le
  système à utiliser pour la communication entre hyperviseurs ainsi que la communication
  avec les nœuds de management. Il ne s'agit généralement pas de la même interface utilisée
  pour la communication publique vers les nœuds de management ni même pour l'accès SSH aux
  nœuds hyperviseurs, et pour cette raison elle peut avoir les Jumbo frames activées.
- `cloudstack_cpu_overprovision` : Multiplicateur utilisé pour permettre le
  surprovisionnement CPU. Par défaut 4.
- `cloudstack_disk_overprovision` : Multiplicateur utilisé pour permettre le
  surprovisionnement Disque. Par défaut 10.
- `cloudstack_allow_pci_passthrough` : Autoriser le PCI Passthrough. Par défaut `false`.

#### Variables relatives à TLS

- `cloudstack_dns_email` : Utilisé par certbot pour spécifier l'email au fournisseur.
- `cloudstack_dns_provider` : Fournisseur DNS utilisé pour effectuer le challenge
  DNS-01. Les valeurs valides sont actuellement : `godaddy`, `cloudflare`
- `cloudstack_dns_apikey` : Clé d'API du fournisseur DNS permettant de créer
  un enregistrement TXT pour `_acme-challenge.{{ cloudstack_hostname }}`. Cette API devrait
  être restreinte exactement à cet accès et rien de plus. Utilisez `Key:Secret` pour
  les clés Godaddy. Pour GoDaddy voir quelques informations ici :
  https://community.letsencrypt.org/t/godaddy-dns-and-certbot-dns-challenge-scripts/210189

#### Variables relatives à SAML / IDP
- `cloudstack_saml_enable` : Booléen. Utiliser ou non l'authentification SAML pour les utilisateurs.
  Par défaut `false`. Veuillez consulter la section
  [SAML / External IDP](#saml---external-idp) pour plus d'informations.
  Les valeurs de configuration `cloudstack_saml_*` restantes devraient être définies lorsque ceci
  est activé.
- `cloudstack_saml_metadata_url` : Requis. URL de métadonnées pour l'authentification
  SAML.
- `cloudstack_saml_user_attribute` : Attribut, qui doit être configuré au sein
  du fournisseur SAML, qui contiendra le nom d'utilisateur utilisé pour l'authentification.
  Cloudstack n'utilise pas le NameID SAML à cette fin. Par défaut
  `uid` si non spécifié.
- `cloudstack_saml_ldap_server` : Requis. Serveur pour la synchronisation LDAP des
  utilisateurs / groupes.
- `cloudstack_saml_use_ssl` : Booléen, si SSL / TLS est requis ou non.
  Par défaut `true`.
- `cloudstack_saml_binddn` : Requis. Bind DN pour la requête des utilisateurs/groupes.
- `cloudstack_saml_bindpass` : Requis. Mot de passe du Bind DN pour la requête des
  utilisateurs/groupes.
- `cloudstack_saml_userdn` : Requis. Base du User DN pour LDAP.
- `cloudstack_saml_groupdn` : Requis. Base du Group DN pour LDAP.
- `cloudstack_saml_ignore_users` : Liste des utilisateurs à NE PAS importer depuis l'IDP upstream.
- `cloudstack_saml_ignore_cloudstack_users` : Liste des utilisateurs à ignorer au sein de
  cloudstack lors de la prise en compte des utilisateurs existants ainsi que de l'appartenance aux groupes.
- `cloudstack_saml_ignore_projects` : Liste des projets dans cloudstack à ignorer
  (en gros, ne pas les désactiver s'ils n'existent pas).
- `cloudstack_saml_groups_allowed` : Requis. Liste des groupes à utiliser pour
  déterminer si les utilisateurs qu'ils contiennent doivent être ajoutés à cloudstack. Ceci
  permet également de faire correspondre les groupes à l'aide de motifs fnmatch(), tels que `cs_*`.
- `cloudstack_saml_admin_groups` : Liste des groupes dans LDAP qui seront traduits
  en administrateurs cloudstack. Les groupes listés ici n'ont *pas* besoin d'être également
  ajoutés à `groups_allowed`. Ceci permet également de faire correspondre les groupes à l'aide de
  motifs fnmatch(), tels que `cs_*`.
- `cloudstack_saml_project_groups` : Liste des groupes pour lesquels un projet sera
  créé, et les utilisateurs qu'ils contiennent seront ajoutés au projet. Les groupes listés
  ici n'ont *pas* besoin d'être également ajoutés à `groups_allowed`. Ceci permet également de faire
  correspondre les groupes à l'aide de motifs fnmatch(), tels que `cs_*`.
- `cloudstack_saml_network_groups` : Dictionnaire de correspondances Network ID vers groupes.
  Le network ID est l'UUID dans Cloudstack, le groupe est un groupe IdP qui est
  soit un unique nom de groupe sous forme de chaîne, soit une liste de noms de groupe. Chaque membre des
  groupes spécifiés se verra accorder l'accès au réseau donné. Ceci peut être utilisé
  pour des choses comme les réseaux L2. Par ex. :
```
"783536ad-c803-40c6-bc10-93d6ba112083":
  - "Software Engineering"
  - "TPS Group"
```
- `cloudstack_saml_attr_username` : Attribut LDAP pour le nom d'utilisateur, par défaut
  `uid`.
- `cloudstack_saml_attr_fname` : Attribut LDAP pour le prénom, par défaut
  `givenName`.
- `cloudstack_saml_attr_lname` : Attribut LDAP pour le nom de famille, par défaut `sn`.
- `cloudstack_saml_attr_email` : Attribut LDAP pour l'email, par défaut `mail`.
- `cloudstack_saml_attr_group` : Attribut LDAP pour le nom de groupe, par défaut `cn`.
- `cloudstack_saml_attr_group_members` : Attribut LDAP contenant les membres du groupe,
  par défaut `uniqueMember`.

### Legacy
- `cloudstack_systemvm` : Chemin pour télécharger systemvm,
  Par ex. http://download.cloudstack.org/systemvm/4.20/systemvmtemplate-4.20.0-x86_64-kvm.qcow2.bz2
  Prétendument plus requis car il est fourni avec le paquet cloudstack-management.

### Variables pour la Configuration de Cloudstack

- `cloudstack_zones` : Liste des Zones à créer dans Cloudstack. La plupart des déploiements
  créeront une seule zone par Datacenter.
  - `name` : Requis. Nom de la zone. Recommandé de le garder court mais
    identifiable. Par ex. `us-east-1`
  - `public_dns` : Liste des serveurs DNS IPv4 utilisés pour résoudre les noms DNS des
    Instances/VMs créées par les utilisateurs. Au moins un serveur est requis, maximum 2.
  - `internal_dns` : Liste des serveurs DNS IPv4 utilisés par les SystemVMs pour résoudre les noms
    des services internes. Au moins un serveur est requis, maximum 2. Peut être le
    même que le DNS public. Les scripts de déploiement actuels utilisent des adresses IP
    et non des noms.
  - `domain`. Optionnel. Nom de domaine réseau pour les réseaux de la zone.
  - `subnet`. Optionnel. Sous-réseau par défaut avec masque pour tout réseau privé
    créé. Ils peuvent se chevaucher d'un réseau à l'autre. Par ex. `10.1.1.0/24`.
  - `networks` : Liste des réseaux physiques définis dans cette zone. Doit avoir au
    moins 3 réseaux, un de chaque `management`, `public`, et `guest`.
    - `name` : Requis. Nom du réseau.
    - `usage` : Requis. Valeurs : `management`, `public`, ou `guest`.
    - `isolation` : Requis. Valeurs : `VLAN` ou `VXLAN`.
    - `subnet` : Requis. par ex. `192.168.1.0/24`
    - `bridge` : Requis. Nom de l'interface bridge sur l'hôte à associer à
      ce réseau.
    - `vni` : Optionnel. Si untagged, laisser vide. Sinon, il s'agit du vni VLAN ou
      VXLAN.
    - `start_ip` : Optionnel, utilisé seulement si `usage: public`. Adresse IP de
      début de la plage d'IP publiques VLAN distribuée aux Virtual Routers/instances.
      Si absent (ainsi que `end_ip`), aucune plage IP publique ni service réseau
      Virtual Router n'est provisionné pour ce réseau — à ajouter plus tard via
      l'UI une fois le reste de la zone en place.
    - `end_ip` : Optionnel, utilisé seulement si `usage: public`. Adresse IP de fin
      de la plage d'IP publiques VLAN. Voir `start_ip`.
    - `gateway` : Requis si `start_ip`/`end_ip` sont définis. Adresse de
      passerelle pour la plage d'IP publiques VLAN, par ex. `192.168.1.1`.
  - `pods` : Requis. Liste des PODs. Les PODs sont une unité organisationnelle qui n'est
    pas directement visible par les utilisateurs finaux. Souvent un pod représente une baie ou une rangée
    et généralement tous les hôtes du POD partageront le même sous-réseau. Il est
    acceptable de n'avoir qu'un seul POD dans une zone.
    - `name` : Requis. Nom du POD.
    - `gateway` : Requis. Adresse de passerelle avec sous-réseau sur le réseau Management
      pour toute System VM (Console, Secondary Storage, Virtual Router) créée.
      ***NOTE :*** Il semble que cette passerelle ne soit utilisée que pour l'accès distant aux
      SystemVMs et ne semble pas être utilisée.
    - `start_ip` : Requis. Adresse IP de début pour toute SystemVM créée dans
      ce pod. Doit être dans le même sous-réseau que la passerelle.
    - `end_ip` : Requis. Adresse IP de fin pour toute SystemVM créée dans
      ce pod. Doit être dans le même sous-réseau que la passerelle.
    - `clusters` : Requis. Liste des clusters. Un cluster est un regroupement d'hôtes
      au sein d'un POD. Les hôtes doivent être identiques (CPU, Mémoire).
      - `name` : Requis. Nom du cluster.
  - `primary_storage` : Optionnel. Pool de stockage primaire NFS, créé avec
    `scope=cluster` pour chaque cluster de la zone, une fois que le premier
    hôte KVM de ce cluster s'enregistre (CloudStack refuse de créer un pool
    de stockage dans un cluster sans hôte). Si absent, les hôtes/clusters
    sont tout de même créés mais n'ont pas de stockage primaire utilisable tant
    qu'un n'est pas ajouté manuellement.
    - `name` : Requis. Nom du pool de stockage.
    - `nfs_path` : Requis. Chemin d'export NFS, ex. `10.1.1.5:/export/primary`.
  - `secondary_storage` : Optionnel. Stockage secondaire NFS (image store) pour
    la zone, ajouté dès que le premier hôte KVM de la zone s'enregistre. Si
    absent, aucun stockage secondaire n'est provisionné automatiquement.
    - `name` : Requis. Nom de l'image store.
    - `nfs_path` : Requis. Chemin d'export NFS, ex. `10.1.1.5:/export/secondary`.

## Authentification SAML / External IDP

L'authentification SAML dans Cloudstack comporte 2 parties. La première partie est l'activation du
fournisseur SAML, en le pointant vers le endpoint de Métadonnées SAML approprié. Du côté
IDP, l'Entity ID ou SP ID doit être défini à `org.apache.cloudstack` et un
attribut personnalisé doit être spécifié pour annoncer le nom d'utilisateur à cloudstack.
Le nom de l'attribut est défini dans `user_attribute` ci-dessus. Le
`cloudstack_hostname` doit également être configuré à une valeur appropriée en raison
des redirections. Cependant cela peut être une adresse ip si nécessaire lors des tests.

La deuxième partie est la synchronisation et l'association des utilisateurs dans cloudstack avec l'IDP
externe. La partie synchronisation suppose que LDAP est disponible depuis l'IDP à cette
fin. L'authentification LDAP n'est pas utilisée car l'IDP peut exiger une 2FA, et
ne fournit pas assez de flexibilité pour l'assignation des utilisateurs aux projets.


## Dépannage / Recherche

Le stockage secondaire nécessite HTTPS, vous pouvez donc obtenir une erreur réseau à moins que TLS ne soit configuré correctement conformément à https://www.shapeblue.com/securing-cloudstack-4-11-with-https-tls/
Un contournement consiste à accepter le certificat en allant sur https://{{ ssvm ip }} et accepter le certificat puis réessayer
