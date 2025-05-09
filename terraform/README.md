# Hackaton_BAD

# Infrastructure GreenShop - Guide de déploiement

Ce répertoire contient les configurations Terraform pour déployer l'infrastructure GreenShop sur AWS. L'architecture inclut un VPC, des sous-réseaux publics et privés, un bastion host, un groupe d'autoscaling, un load balancer, et une base de données RDS.

## Prérequis

* [Terraform](https://www.terraform.io/downloads.html) (version ≥ 1.0.0)
* [AWS CLI](https://aws.amazon.com/cli/) configuré avec des identifiants valides
* Droits suffisants pour créer des ressources AWS
* Bash (Linux/macOS) ou PowerShell (Windows)

## Architecture déployée

L'infrastructure déployée comprend :

1. **VPC** (Réseau virtuel) : Contient tout votre environnement
   * Sous-réseaux publics : Contiennent le bastion et l'ALB (load balancer)
   * Sous-réseaux privés : Contiennent vos instances d'application et la base de données
2. **Bastion** : Une instance EC2 dans un sous-réseau public
   * Sert de "sas d'entrée" sécurisé vers votre infrastructure privée
   * A une adresse IP publique accessible depuis Internet
3. **Instances d'application** : Dans l'Auto Scaling Group (ASG) en sous-réseau privé
   * Minimum 3 instances, maximum 5 instances (t2.small)
   * Ne sont pas directement accessibles depuis Internet
   * Peuvent communiquer avec la base de données
4. **Base de données RDS** : Dans un sous-réseau privé
   * Instance MySQL 8.0 (db.t3.small) en configuration multi-AZ
   * N'est pas directement accessible depuis Internet
   * Est accessible depuis les instances d'application et le bastion

## Création de la clé SSH

Avant de déployer l'infrastructure, vous devez créer une paire de clés SSH qui sera utilisée pour se connecter aux instances EC2.

### Linux/macOS

```bash
# Générer une paire de clés SSH
aws ec2 create-key-pair --key-name acces --query 'KeyMaterial' --output text > acces.pem

# Définir les permissions appropriées
chmod 400 acces.pem
```

### Windows (PowerShell)

```powershell
# Générer une paire de clés SSH
aws ec2 create-key-pair --key-name acces --query 'KeyMaterial' --output text | Out-File -Encoding ascii -FilePath acces.pem

# S'assurer que seul le propriétaire peut lire le fichier
icacls .\acces.pem /inheritance:r
icacls .\acces.pem /grant:r "$($env:USERNAME):(R)"
```

## Structure du projet

```
terraform/
├── main.tf               # Configuration principale
├── variables.tf          # Définition des variables
├── outputs.tf            # Définition des sorties
├── terraform.tfvars      # Valeurs des variables
├── deploy.ps1            # Script de déploiement PowerShell
├── deploy.sh             # Script de déploiement Bash
└── modules/              # Modules Terraform
    ├── vpc/              # Configuration du VPC
    ├── security/         # Groupes de sécurité
    ├── bastion/          # Configuration du bastion host
    ├── asg/              # Configuration du groupe d'autoscaling
    ├── alb/              # Configuration du load balancer
    └── database/         # Configuration de la base de données RDS
```

## Utilisation du script de déploiement

Le script de déploiement automatise la vérification des prérequis, la configuration et le déploiement de l'infrastructure.

### Linux (script deploy.sh)

```bash
# Rendre le script exécutable
chmod +x deploy.sh

# Exécuter le script
./deploy.sh
```

Le script effectuera les opérations suivantes :

1. Vérification de l'installation de Terraform et AWS CLI
2. Vérification des paires de clés disponibles dans AWS
3. Création du fichier terraform.tfvars avec la configuration adaptée
4. Vérification de l'existence des ressources AWS et gestion des conflits
5. Initialisation et application de la configuration Terraform

### Options du script

Le script de déploiement inclut une fonction de vérification des ressources existantes dans AWS. Si des ressources sont déjà présentes, vous aurez trois options :

1. **Supprimer les ressources existantes et redéployer** - Nettoie complètement l'environnement
2. **Importer les ressources existantes dans l'état Terraform** - Intègre les ressources existantes
3. **Continuer le déploiement** - Poursuit malgré les possibles erreurs

## Vérification du déploiement de la base de données

### Via la console AWS RDS

Pour vérifier que votre base de données est opérationnelle dans l'interface graphique AWS :

1. Connectez-vous à la console AWS
2. Naviguez vers le service "RDS" (Relational Database Service)
3. Dans le menu latéral gauche, cliquez sur "Bases de données"
4. Recherchez votre base de données nommée "greenshop-db" dans la liste

Une fois que vous l'avez localisée, vous pouvez vérifier son statut :

* Le statut devrait indiquer "Available" ou "Disponible" si elle est opérationnelle
* Vous pouvez cliquer sur l'identifiant de la base de données pour voir plus de détails

Dans la vue détaillée, vous pourrez vérifier :

* L'état de connexion
* Les métriques de performance
* Les informations de connectivité (endpoint, port)
* La configuration multi-AZ
* Les paramètres de stockage et de sécurité

## Obtention de l'endpoint de la base de données

### Via la console AWS

1. Connectez-vous à la console AWS
2. Allez dans le service RDS
3. Cliquez sur "Bases de données" dans le menu gauche
4. Sélectionnez votre base de données "greenshop-db"
5. Dans la section "Connectivité et sécurité", vous trouverez l'endpoint de la base de données (ressemble à `greenshop-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com`)

### Via Terraform

Après le déploiement, vous pouvez obtenir l'endpoint en exécutant :

```bash
terraform output db_endpoint
```

## Comment pousser un dump vers la base de données

Étant donné l'architecture, vous devrez passer par le bastion host pour accéder à la base de données, car elle se trouve dans un sous-réseau privé.

1. D'abord, connectez-vous au bastion host :

   ```bash
   ssh -i acces.pem ec2-user@<BASTION_PUBLIC_IP>
   ```

   * L'IP du bastion est disponible via `terraform output bastion_public_ip`
2. Assurez-vous que le client MySQL est installé sur le bastion :

   ```bash
   sudo yum install mysql -y
   ```
3. Pour transférer votre fichier de dump vers le bastion :

   ```bash
   scp -i acces.pem votre_dump.sql ec2-user@<BASTION_PUBLIC_IP>:/home/ec2-user/
   ```
4. Depuis le bastion, vous pouvez maintenant importer le dump :

   ```bash
   mysql -h <DB_ENDPOINT> -u admin -p greenshop < votre_dump.sql
   ```

   * Remplacez `admin` par le nom d'utilisateur configuré dans Terraform
   * Le mot de passe vous sera demandé (c'est celui défini dans la configuration Terraform)
   * Attention ne mettez pas le port dans la commande d'import de la base de donné !

## Accès aux instances d'application

Une fois le déploiement terminé, vous pouvez accéder au bastion host puis aux instances via SSH :

```bash
# Connexion au bastion
ssh -i acces.pem ec2-user@<BASTION_PUBLIC_IP>

# Depuis le bastion, connexion aux instances
ssh -i acces.pem ec2-user@<INSTANCE_PRIVATE_IP>
```

Les adresses IP privées des instances peuvent être obtenues en exécutant la commande suivante depuis le bastion :

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=greenshop-asg-instance" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --output text
```

## Outputs

Après un déploiement réussi, Terraform affichera les sorties suivantes :

* `vpc_id` - ID du VPC créé
* `public_subnet_ids` - IDs des sous-réseaux publics
* `private_subnet_ids` - IDs des sous-réseaux privés
* `bastion_public_ip` - Adresse IP publique du bastion host
* `alb_dns_name` - Nom DNS du load balancer
* `db_endpoint` - Point de terminaison de la base de données RDS

## Nettoyage des ressources

Pour supprimer toutes les ressources créées :

```bash
terraform destroy -auto-approve
```

## Dépannage

### Ressources déjà existantes

Si vous rencontrez des erreurs indiquant que des ressources existent déjà, vous pouvez utiliser le script de nettoyage inclus dans le script de déploiement pour les supprimer.

### Problèmes de connexion SSH

Vérifiez que :

* Les groupes de sécurité autorisent le trafic SSH (port 22)
* Vous utilisez la bonne clé privée
* Vous utilisez le bon nom d'utilisateur (ec2-user pour Amazon Linux)
* Les ACLs de réseau n'empêchent pas la connexion

### Problèmes de connexion à la base de données

Vérifiez que :

* Le groupe de sécurité de la base de données autorise les connexions depuis le groupe de sécurité du bastion
* Vous utilisez le bon endpoint, nom d'utilisateur et mot de passe
* La base de données est dans l'état "Available"

### Délais de suppression

La suppression de certaines ressources (comme les instances RDS) peut prendre plusieurs minutes. Soyez patient lors de l'exécution de `terraform destroy` ou du script de nettoyage.

# Infrastructure GreenShop - Guide de déploiement

Ce répertoire contient les configurations Terraform pour déployer l'infrastructure GreenShop sur AWS. L'architecture inclut un VPC, des sous-réseaux publics et privés, un bastion host, un groupe d'autoscaling, un load balancer, et une base de données RDS.

## Prérequis

* [Terraform](https://www.terraform.io/downloads.html) (version ≥ 1.0.0)
* [AWS CLI](https://aws.amazon.com/cli/) configuré avec des identifiants valides
* Droits suffisants pour créer des ressources AWS
* Bash (Linux/macOS) ou PowerShell (Windows)

## Création de la clé SSH

Avant de déployer l'infrastructure, vous devez créer une paire de clés SSH qui sera utilisée pour se connecter aux instances EC2.

### Linux/macOS

```bash
# Générer une paire de clés SSH
aws ec2 create-key-pair --key-name acces --query 'KeyMaterial' --output text > acces.pem

# Définir les permissions appropriées
chmod 400 acces.pem
```

### Windows (PowerShell)

```powershell
# Générer une paire de clés SSH
aws ec2 create-key-pair --key-name acces --query 'KeyMaterial' --output text | Out-File -Encoding ascii -FilePath acces.pem

# S'assurer que seul le propriétaire peut lire le fichier
icacls .\acces.pem /inheritance:r
icacls .\acces.pem /grant:r "$($env:USERNAME):(R)"
```

## Structure du projet

```
terraform/
├── main.tf               # Configuration principale
├── variables.tf          # Définition des variables
├── outputs.tf            # Définition des sorties
├── terraform.tfvars      # Valeurs des variables
├── deploy.ps1            # Script de déploiement PowerShell
├── deploy.sh             # Script de déploiement Bash
└── modules/              # Modules Terraform
    ├── vpc/              # Configuration du VPC
    ├── security/         # Groupes de sécurité
    ├── bastion/          # Configuration du bastion host
    ├── asg/              # Configuration du groupe d'autoscaling
    ├── alb/              # Configuration du load balancer
    └── database/         # Configuration de la base de données RDS
```

## Utilisation du script de déploiement

Le script de déploiement automatise la vérification des prérequis, la configuration et le déploiement de l'infrastructure.

### Linux (script deploy.sh)

```bash
# Rendre le script exécutable
chmod +x deploy.sh

# Exécuter le script
./deploy.sh
```

Le script effectuera les opérations suivantes :

1. Vérification de l'installation de Terraform et AWS CLI
2. Vérification des paires de clés disponibles dans AWS
3. Création du fichier terraform.tfvars avec la configuration adaptée
4. Vérification de l'existence des ressources AWS et gestion des conflits
5. Initialisation et application de la configuration Terraform

### Options du script

Le script de déploiement inclut une fonction de vérification des ressources existantes dans AWS. Si des ressources sont déjà présentes, vous aurez trois options :

1. **Supprimer les ressources existantes et redéployer** - Nettoie complètement l'environnement
2. **Importer les ressources existantes dans l'état Terraform** - Intègre les ressources existantes
3. **Continuer le déploiement** - Poursuit malgré les possibles erreurs

## Accès à l'infrastructure

Une fois le déploiement terminé, vous pouvez accéder au bastion host puis aux instances via SSH :

```bash
# Connexion au bastion
ssh -i acces.pem ec2-user@<BASTION_PUBLIC_IP>

# Depuis le bastion, connexion aux instances
ssh -i acces.pem ec2-user@<INSTANCE_PRIVATE_IP>
```

Les adresses IP privées des instances peuvent être obtenues en exécutant la commande suivante depuis le bastion :

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=greenshop-asg-instance" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --output text
```

## Outputs

Après un déploiement réussi, Terraform affichera les sorties suivantes :

* `vpc_id` - ID du VPC créé
* `public_subnet_ids` - IDs des sous-réseaux publics
* `private_subnet_ids` - IDs des sous-réseaux privés
* `bastion_public_ip` - Adresse IP publique du bastion host
* `alb_dns_name` - Nom DNS du load balancer
* `db_endpoint` - Point de terminaison de la base de données RDS

## Nettoyage des ressources

Pour supprimer toutes les ressources créées :

```bash
terraform destroy -auto-approve
```

## Dépannage

### Ressources déjà existantes

Si vous rencontrez des erreurs indiquant que des ressources existent déjà, vous pouvez utiliser le script de nettoyage inclus dans le script de déploiement pour les supprimer.

### Problèmes de connexion SSH

Vérifiez que :

* Les groupes de sécurité autorisent le trafic SSH (port 22)
* Vous utilisez la bonne clé privée
* Vous utilisez le bon nom d'utilisateur (ec2-user pour Amazon Linux)
* Les ACLs de réseau n'empêchent pas la connexion

### Délais de suppression

La suppression de certaines ressources (comme les instances RDS) peut prendre plusieurs minutes. Soyez patient lors de l'exécution de `terraform destroy` ou du script de nettoyage.

Hackaton_BAD
