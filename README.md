# Projet Hackathon BAD 2025

Ce projet représente la migration complète de l'application GreenShop, un e-commerçant spécialisé dans les produits bio, depuis une infrastructure on-premise vers le cloud AWS. Il implémente une approche DevOps moderne avec Infrastructure as Code (IaC), conteneurisation et CI/CD pour répondre aux besoins de croissance et d'agilité de GreenShop.

# Lien du projet

https://github.com/jolyjonathan/Hackaton_BAD

## Contexte du projet

GreenShop était initialement hébergé sur une unique machine on-premise qui montrait ses limites:

* Déploiements manuels et risqués effectués en dehors des heures de bureau
* Performance insuffisante lors des pics de trafic
* Absence de traçabilité des changements d'infrastructure
* Aucun système de monitoring en place

Notre mission consiste à transformer cette infrastructure artisanale en une usine DevOps complète dans AWS, capable de:

1. Provisionner un réseau sécurisé avec des instances éphémères
2. Conteneuriser l'application pour la portabilité
3. Automatiser la configuration de chaque composant
4. Mettre en place un pipeline CI/CD pour une livraison continue
5. Assurer la haute disponibilité face aux pics de trafic
6. Superviser la santé de la plateforme
7. Fournir une documentation complète

## Architecture globale

```
GitHub   →   Jenkins   →   Terraform   →   Ansible   →   AWS Infrastructure
  |                                                         |
  |                                                         ↓
  └─────────────────────── Déploiement continu ─────→ Application GreenShop
```

![Architecture GreenShop](https://raw.githubusercontent.com/jolyjonathan/Hackaton_BAD/main/docs/architecture.png)

L'architecture mise en place s'articule autour de:

* Un VPC sécurisé avec sous-réseaux publics et privés
* Un bastion host comme point d'entrée sécurisé
* Un Application Load Balancer (ALB) pour la répartition du trafic
* Un Auto Scaling Group avec 3 à 5 instances EC2 en sous-réseaux privés
* Une base de données RDS MySQL en configuration multi-AZ

## Structure du projet

```
.
├── terraform/                # Infrastructure AWS (VPC, EC2, RDS, etc.)
│   ├── main.tf               # Configuration principale
│   ├── variables.tf          # Définition des variables
│   ├── outputs.tf            # Définition des sorties
│   ├── terraform.tfvars      # Valeurs des variables
│   ├── deploy.sh             # Script de déploiement Bash
│   ├── deploy.ps1            # Script de déploiement PowerShell
│   └── modules/              # Modules Terraform
│       ├── vpc/              # Configuration du VPC
│       ├── security/         # Groupes de sécurité
│       ├── bastion/          # Configuration du bastion host
│       ├── asg/              # Configuration du groupe d'autoscaling
│       ├── alb/              # Configuration du load balancer
│       └── database/         # Configuration de la base de données RDS
├── ansible/                  # Configuration des serveurs et déploiement
│   ├── ansible.cfg           # Configuration Ansible
│   ├── inventory/            # Inventaire des hôtes
│   ├── group_vars/           # Variables de groupe
│   ├── roles/                # Rôles Ansible réutilisables
│   │   ├── common/           # Configurations de base
│   │   ├── dbserver/         # Gestion de la base de données
│   │   ├── webserver/        # Configuration web et déploiement
│   │   └── docker/           # Installation Docker et déploiement conteneurs
│   └── playbooks/            # Playbooks de haut niveau
├── .github/                  # GitHub Actions workflows
│   └── workflows/            # Configuration des workflows
│       └── deploy.yml        # Workflow de déploiement
├── jenkins/                  # Configuration Jenkins et Jenkinsfile
│   └── Jenkinsfile           # Pipeline de CI/CD
└── README.md                 # Ce fichier
```

## Infrastructure (Terraform)

Terraform est utilisé pour provisionner l'infrastructure AWS complète de GreenShop, suivant l'approche Infrastructure as Code (IaC).

### Architecture déployée

* **VPC** avec sous-réseaux publics et privés séparés sur plusieurs zones de disponibilité
* **Bastion host** dans un sous-réseau public pour l'administration sécurisée
* **Auto Scaling Group** avec 3-5 instances d'application (t2.small) dans des sous-réseaux privés
* **Application Load Balancer** pour distribuer le trafic et assurer la haute disponibilité
* **Base de données RDS** MySQL 8.0 (db.t3.small) en configuration multi-AZ pour la durabilité

### Prérequis

* **Terraform** (version ≥ 1.0.0)
* **AWS CLI** configuré avec des identifiants valides
* Droits suffisants pour créer des ressources AWS
* Bash (Linux/macOS) ou PowerShell (Windows)

### Utilisation de Terraform

```bash
# Étape 1: Créer la clé SSH pour l'accès aux instances
## Linux/macOS
aws ec2 create-key-pair --key-name acces --query 'KeyMaterial' --output text > acces.pem
chmod 400 acces.pem

## Windows (PowerShell)
aws ec2 create-key-pair --key-name acces --query 'KeyMaterial' --output text | Out-File -Encoding ascii -FilePath acces.pem
icacls .\acces.pem /inheritance:r
icacls .\acces.pem /grant:r "$($env:USERNAME):(R)"

# Étape 2: Déployer l'infrastructure
cd terraform
./deploy.sh  # ou deploy.ps1 sous Windows
```

Le script de déploiement automatise:

1. La vérification des prérequis (Terraform, AWS CLI)
2. La vérification des paires de clés disponibles
3. La création du fichier terraform.tfvars avec la configuration adaptée
4. La vérification et gestion des conflits avec des ressources existantes
5. L'initialisation et application de la configuration Terraform

## Configuration et déploiement (Ansible)

Ansible est utilisé pour automatiser la configuration des serveurs et déployer l'application GreenShop sur les instances EC2 privées via le bastion.

### Rôles principaux

* **common** : Configuration de base des serveurs (utilisateurs, firewall, mises à jour)
* **webserver** : Installation d'Apache/PHP, configuration des VirtualHosts et déploiement du code
* **dbserver** : Dump et synchronisation de la base de données MariaDB, import vers RDS
* **docker** : Installation de Docker et déploiement des conteneurs de l'application

### Structure d'inventaire

L'inventaire Ansible définit trois groupes principaux:

* **target** : La machine source contenant le code et la base de données d'origine
* **bastion** : Le serveur bastion EC2 pour accéder au réseau privé
* **web** : Les serveurs web dans le réseau privé qui hébergeront l'application

### Playbooks clés

```bash
# Installer les dépendances requises
ansible-galaxy install -r requirements/roles.yml
ansible-galaxy collection install -r requirements/collections.yml

# Vérifier la configuration AWS
ansible-playbook -i inventory/hosts.yml playbooks/0_check_aws.yml

# Vérifier l'accès au bastion
ansible-playbook -i inventory/hosts.yml playbooks/1_check_bastion.yml

# Synchroniser le code et les dumps de base de données
ansible-playbook -i inventory/hosts.yml playbooks/2_sync_and_dump.yml

# Déployer l'application sur les serveurs web
ansible-playbook -i inventory/hosts.yml playbooks/3_deploy.yml

# Importer la base de données dans RDS via le bastion
ansible-playbook -i inventory/hosts.yml playbooks/4_import_db_playbook.yml
```

Les playbooks sont conçus pour être idempotents et peuvent être exécutés de manière séquentielle pour assurer un déploiement complet et reproductible.

## Conteneurisation de l'application

L'application GreenShop a été conteneurisée pour faciliter son déploiement, sa scalabilité et sa portabilité.

### Images Docker

* Image principale **flemoi/greenshop** hébergée sur DockerHub
* Dockerfile optimisé disponible dans `ansible_old/roles/docker/webapp/Dockerfile`
* Configuration pour exécution sur les instances EC2 via Ansible

### Déploiement des conteneurs

Les conteneurs sont déployés sur les instances EC2 via:

1. Un role Ansible `docker` qui installe Docker et configure les conteneurs
2. Une configuration automatisée qui s'assure que les conteneurs sont toujours disponibles
3. Une gestion des ports permettant au load balancer de répartir le trafic

## Pipeline CI/CD (Jenkins)

Jenkins est utilisé pour automatiser le build et le déploiement des images Docker de GreenShop.

### Pipeline de build Docker

Le pipeline défini dans le Jenkinsfile comporte les étapes suivantes:

1. **Clone du dépôt GitHub** (branche ansible)
   ```groovy
   git branch: 'ansible', url: 'https://github.com/jolyjonathan/Hackaton_BAD.git'
   ```
2. **Vérification intelligente des modifications**
   ```groovy
   def changes = sh(script: "git diff --name-only HEAD~1 HEAD", returnStdout: true).trim()
   if (changes =~ /Dockerfile/ || changes =~ /files\//) {
     env.BUILD_DOCKER = "true"
   }
   ```
3. **Build de l'image Docker** (uniquement si nécessaire)
   ```groovy
   def commit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
   def dateTag = sh(script: 'date +%Y%m%d-%H%M', returnStdout: true).trim()
   def imageTag = "${IMAGE}:${dateTag}-${commit}"
   sh "docker build -t ${imageTag} -t ${IMAGE}:${TAG} -f ${DOCKERFILE_PATH} ."
   ```
4. **Push vers DockerHub** avec tags pour la traçabilité
   ```groovy
   sh "docker push ${IMAGE_TAG}"
   sh "docker push ${IMAGE}:${TAG}"
   ```

### Configuration Jenkins requise

* Plugin Git
* Plugin Docker
* Credentials DockerHub configurés (`dockerhub-credentials-id`)
* Accès à Docker sur l'agent Jenkins

### Déclenchement du pipeline

* **Automatique**: Webhook GitHub sur push vers la branche ansible
* **Manuel**: Via l'interface Jenkins
* **Optimisé**: Ne déclenche le build que lorsque des fichiers pertinents sont modifiés

## Intégration GitHub

GitHub est utilisé pour la gestion du code source et l'intégration avec les outils CI/CD.

### Workflows GitHub Actions

Des workflows GitHub Actions sont configurés pour:

* **Validation**: Linting et tests unitaires du code
* **Déploiement**: Déploiement automatisé via SSH sur le serveur bastion
* **Notifications**: Alertes en cas d'échec de déploiement

Le workflow principal de déploiement s'exécute à chaque push sur main ou manuellement:

```yaml
name: Deploy GreenShop

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup SSH to Bastion
        uses: webfactory/ssh-agent@v0.7.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
      - name: Deploy via Bastion
        run: |
          chmod +x ./scripts/deploy_from_bastion.sh
          scp -o StrictHostKeyChecking=no ./scripts/deploy_from_bastion.sh ${{ secrets.BASTION_USER }}@${{ secrets.BASTION_HOST }}:/tmp/
          ssh -o StrictHostKeyChecking=no ${{ secrets.BASTION_USER }}@${{ secrets.BASTION_HOST }} "chmod +x /tmp/deploy_from_bastion.sh && /tmp/deploy_from_bastion.sh -h '${{ secrets.TARGET_HOSTS }}' -u ${{ secrets.TARGET_USER }} -v"
```

### Secrets GitHub Actions

Configurez les secrets suivants pour le déploiement:

* `SSH_PRIVATE_KEY`: Clé SSH privée au format PEM pour se connecter au bastion et aux instances
* `BASTION_HOST`: Adresse IP ou nom d'hôte du serveur bastion
* `BASTION_USER`: Nom d'utilisateur pour se connecter au bastion (ex: ec2-user)
* `TARGET_HOSTS`: Liste des adresses IP des instances cibles, séparées par des virgules
* `TARGET_USER`: Nom d'utilisateur pour se connecter aux instances cibles

## Flux de travail complet

1. **Développement**: Le développeur pousse ses modifications vers GitHub
   * Mise à jour du code source dans la branche principale
   * Ou modification du Dockerfile/fichiers sources dans la branche ansible
2. **CI/CD**: Jenkins détecte automatiquement les changements
   * Analyse intelligente des fichiers modifiés
   * Construction d'une nouvelle image Docker uniquement si nécessaire
   * Push de l'image vers DockerHub avec tags de traçabilité (date et commit)
3. **Infrastructure**: Terraform maintient l'infrastructure AWS
   * VPC, sous-réseaux, groupes de sécurité
   * Bastion, Load Balancer, Auto Scaling Group
   * Base de données RDS multi-AZ
4. **Déploiement**: Déploiement automatisé sur les instances
   * Via GitHub Actions pour déclencher le déploiement complet
   * Ou via Ansible pour des mises à jour ciblées

## Première utilisation

1. **Préparation**:
   ```bash
   # Cloner le dépôt
   git clone https://github.com/jolyjonathan/Hackaton_BAD.git
   cd Hackaton_BAD
   ```
2. **Déploiement de l'infrastructure**:
   ```bash
   # Créer la clé SSH
   aws ec2 create-key-pair --key-name acces --query 'KeyMaterial' --output text > acces.pem
   chmod 400 acces.pem

   # Déployer avec Terraform
   cd terraform
   ./deploy.sh
   ```
3. **Configuration Jenkins**:
   * Installer Jenkins ou utiliser une instance existante
   * Installer les plugins Git et Docker
   * Configurer les identifiants DockerHub (`dockerhub-credentials-id`)
   * Créer un pipeline avec le Jenkinsfile fourni
4. **Configuration GitHub Actions**:
   * Configurer les secrets dans votre dépôt GitHub
   * S'assurer que les workflows sont activés
5. **Déploiement initial**:
   ```bash
   # Installer les dépendances Ansible
   cd ansible
   ansible-galaxy install -r requirements/roles.yml
   ansible-galaxy collection install -r requirements/collections.yml

   # Lancer les playbooks de déploiement
   ansible-playbook -i inventory/hosts.yml playbooks/0_check_aws.yml
   ansible-playbook -i inventory/hosts.yml playbooks/1_check_bastion.yml
   ansible-playbook -i inventory/hosts.yml playbooks/2_sync_and_dump.yml
   ansible-playbook -i inventory/hosts.yml playbooks/3_deploy.yml
   ansible-playbook -i inventory/hosts.yml playbooks/4_import_db_playbook.yml
   ```

## Maintenance

### Mise à jour de l'application

1. Poussez vos modifications vers la branche appropriée:
   ```bash
   # Pour les changements de code source
   git checkout main
   # Modifiez les fichiers nécessaires
   git add .
   git commit -m "Update application code"
   git push origin main

   # Pour les changements de Dockerfile
   git checkout ansible
   # Modifiez le Dockerfile
   git add .
   git commit -m "Update Dockerfile"
   git push origin ansible
   ```
2. Jenkins construira automatiquement une nouvelle image Docker si nécessaire:
   * Le pipeline détecte intelligemment si un build est nécessaire
   * L'image est taguée avec la date et le hash du commit pour la traçabilité
3. Déclenchez le workflow GitHub Actions pour déployer la nouvelle version:
   * Automatiquement sur push vers main
   * Ou manuellement via l'interface GitHub Actions

### Mise à jour de l'infrastructure

1. Modifiez les fichiers Terraform selon vos besoins:
   ```bash
   cd terraform
   # Modifiez main.tf, variables.tf, etc.
   ```
2. Exécutez `terraform plan` pour vérifier les changements:
   ```bash
   terraform init
   terraform plan -out=tfplan
   ```
3. Exécutez `terraform apply` pour appliquer les modifications:
   ```bash
   terraform apply tfplan
   ```

### Nettoyage et suppression de l'environnement

Pour supprimer l'ensemble de l'infrastructure:

```bash
cd terraform
terraform destroy -auto-approve
```

Pour nettoyer les images Docker obsolètes sur les instances:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/clean_docker.yml
```

## Résolution des problèmes

### Infrastructure AWS

Si vous rencontrez des problèmes avec les ressources AWS:

* Vérifiez les logs dans la console AWS (CloudWatch, EC2, RDS)
* Consultez `terraform.tfstate` pour l'état actuel de l'infrastructure
* Utilisez la fonction de nettoyage du script `deploy.sh` si nécessaire:
  ```bash
  cd terraform./deploy.sh --cleanup
  ```
* Pour les ressources qui restent bloquées lors de la suppression, vérifiez les dépendances dans la console AWS

### Problèmes de base de données

Si vous rencontrez des problèmes avec la base de données RDS:

* Vérifiez que la base de données est "Available" dans la console RDS
* Assurez-vous que les groupes de sécurité permettent les connexions depuis le bastion
* Pour importer un dump manuellement:
  ```bash
  # Depuis le bastionmysql -h <DB_ENDPOINT> -u admin -p greenshop < votre_dump.sql
  ```

### Connexion aux instances

Via le bastion host:

```bash
# Connexion au bastion
ssh -i acces.pem ec2-user@<BASTION_PUBLIC_IP>

# Depuis le bastion, connexion aux instances
ssh -i acces.pem ec2-user@<INSTANCE_PRIVATE_IP>
```

Pour trouver les adresses IP privées des instances:

```bash
# Depuis le bastion
aws ec2 describe-instances --filters "Name=tag:Name,Values=greenshop-asg-instance" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --output text
```

### Pipeline Jenkins

Si le pipeline échoue:

* Vérifiez les logs de build Jenkins pour identifier l'étape problématique
* Assurez-vous que les identifiants DockerHub sont correctement configurés
* Vérifiez que le Dockerfile est valide et peut être construit localement
* Vérifiez les permissions du jenkins agent pour accéder à Docker

### Déploiement GitHub Actions

Si le déploiement via GitHub Actions échoue:

* Vérifiez que les secrets sont correctement configurés
* Assurez-vous que le bastion est accessible depuis Internet
* Vérifiez les logs du workflow dans l'interface GitHub Actions

## Sécurité

* **Gestion des clés**: Protégez votre fichier `acces.pem` et ne le partagez jamais publiquement
* **Secrets**: Utilisez Ansible Vault pour les secrets sensibles:
  ```bash
  # Chiffrer un fichieransible-vault encrypt group_vars/all/vault.yml# Utiliser un fichier chiffréansible-playbook playbook.yml --ask-vault-pass
  ```
* **Accès réseau**:
  * Limitez l'accès SSH au bastion avec des règles strictes de groupe de sécurité
  * Assurez-vous que les instances privées sont uniquement accessibles via le bastion
  * Utilisez les groupes de sécurité pour contrôler les communications entre les composants
* **Identifiants**: Conservez les identifiants uniquement dans Jenkins Credentials ou GitHub Secrets
* **Images Docker**: Scannez régulièrement les images Docker pour les vulnérabilités
