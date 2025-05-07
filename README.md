# Hackaton_BAD

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
