#!/bin/bash

# Script de déploiement automatisé pour GreenShop DevOps Cloud Migration
# deploy.sh

# Fonctions pour améliorer l'affichage
function print_color() {
    COLOR=$1
    shift
    case $COLOR in
        "red")
            echo -e "\033[31m$@\033[0m"
            ;;
        "green")
            echo -e "\033[32m$@\033[0m"
            ;;
        "yellow")
            echo -e "\033[33m$@\033[0m"
            ;;
        "cyan")
            echo -e "\033[36m$@\033[0m"
            ;;
        "white")
            echo -e "\033[37m$@\033[0m"
            ;;
        *)
            echo -e "$@"
            ;;
    esac
}

function write_info_message() {
    print_color "green" "[INFO] $1"
}

function write_warning_message() {
    print_color "yellow" "[ATTENTION] $1"
}

function write_error_message() {
    print_color "red" "[ERREUR] $1"
}

function write_separator() {
    echo "================================================================="
}

# Affichage du titre
write_separator
print_color "cyan" "DÉPLOIEMENT AUTOMATISÉ GREENSHOP - AWS CLOUD MIGRATION"
write_separator
echo ""

# Vérification de l'exécution en tant que root
if [ "$EUID" -ne 0 ]; then
    write_warning_message "Ce script n'est pas exécuté en tant que root. Certaines opérations pourraient échouer."
    write_warning_message "Il est recommandé de l'exécuter avec sudo."
    echo ""
    read -p "Voulez-vous continuer quand même ? (O/N): " confirmation
    if [[ ! "$confirmation" =~ [oO] ]]; then
        write_error_message "Script interrompu par l'utilisateur."
        exit 1
    fi
fi

# Vérification de l'installation de Terraform
write_info_message "Vérification de l'installation de Terraform..."
if ! command -v terraform &> /dev/null; then
    write_warning_message "Terraform n'est pas installé ou n'est pas dans le PATH."
    write_info_message "Installation de Terraform..."
    
    # Détection de la distribution Linux
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        write_info_message "Détection de la distribution : Debian/Ubuntu"
        sudo apt-get update
        sudo apt-get install -y gnupg software-properties-common curl
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update
        sudo apt-get install -y terraform
    elif command -v dnf &> /dev/null; then
        # Fedora/RHEL/CentOS 8+
        write_info_message "Détection de la distribution : Fedora/RHEL/CentOS 8+"
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
        sudo dnf -y install terraform
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS 7
        write_info_message "Détection de la distribution : RHEL/CentOS 7"
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        sudo yum -y install terraform
    else
        write_warning_message "Distribution non prise en charge pour l'installation automatique."
        write_info_message "Installation manuelle de Terraform..."
        
        # Installation manuelle de Terraform
        TERRAFORM_VERSION="1.7.2"  # Mettre à jour avec la dernière version
        wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
        unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
        sudo mv terraform /usr/local/bin/
        rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    fi
    
    # Vérification de l'installation
    if ! command -v terraform &> /dev/null; then
        write_error_message "L'installation de Terraform a échoué. Veuillez l'installer manuellement."
        exit 1
    else
        write_info_message "Terraform a été installé avec succès."
    fi
fi

# Affichage de la version de Terraform
TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
write_info_message "Version de Terraform détectée: $TERRAFORM_VERSION"

# Vérification de l'installation d'AWS CLI
write_info_message "Vérification de l'installation d'AWS CLI..."
if ! command -v aws &> /dev/null; then
    write_warning_message "AWS CLI n'est pas installé ou n'est pas dans le PATH."
    write_info_message "Installation d'AWS CLI..."
    
    # Installation d'AWS CLI
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y unzip
    elif command -v dnf &> /dev/null || command -v yum &> /dev/null; then
        # Fedora/RHEL/CentOS
        sudo yum install -y unzip
    fi
    
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    
    # Vérification de l'installation
    if ! command -v aws &> /dev/null; then
        write_error_message "L'installation d'AWS CLI a échoué. Veuillez l'installer manuellement."
        exit 1
    else
        write_info_message "AWS CLI a été installé avec succès."
    fi
fi

# Affichage de la version d'AWS CLI
AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
write_info_message "Version d'AWS CLI détectée: $AWS_VERSION"

# Vérification des credentials AWS
write_info_message "Vérification des credentials AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
    write_warning_message "Aucun credential AWS valide détecté. Configuration requise..."
    write_info_message "Veuillez saisir vos informations d'identification AWS ou éditer le fichier ~/.aws/credentials :"
    
    aws configure
    
    # Vérification après configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        write_error_message "La configuration AWS a échoué. Veuillez vérifier vos credentials."
        exit 1
    fi
fi

# Récupération des informations du compte AWS
AWS_ACCOUNT_INFO=$(aws sts get-caller-identity)
AWS_ACCOUNT_ID=$(echo $AWS_ACCOUNT_INFO | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
AWS_ARN=$(echo $AWS_ACCOUNT_INFO | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)

# Récupération de la région AWS configurée
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"  # Région par défaut
fi

write_info_message "Connecté au compte AWS: $AWS_ACCOUNT_ID ($AWS_ARN)"
write_info_message "Région AWS configurée: $AWS_REGION"

# Vérification de l'existence du fichier terraform.tfvars
write_info_message "Vérification du fichier terraform.tfvars..."
if [ ! -f "terraform.tfvars" ]; then
    write_warning_message "Le fichier terraform.tfvars n'existe pas. Création en cours..."
    
    # Obtention de l'IP publique
    IP_ADDRESS=$(curl -s "https://api.ipify.org")
    if [ -z "$IP_ADDRESS" ]; then
        write_warning_message "Impossible de récupérer l'adresse IP automatiquement. Utilisation d'une valeur par défaut."
        IP_ADDRESS="0.0.0.0"
    fi
    write_info_message "Adresse IP détectée : $IP_ADDRESS"
    
    # Vérification des paires de clés disponibles
    write_info_message "Vérification des paires de clés disponibles..."
    KEY_PAIRS=$(aws ec2 describe-key-pairs)
    KEY_PAIR_NAMES=$(echo $KEY_PAIRS | grep -o '"KeyName": "[^"]*"' | cut -d'"' -f4 | tr '\n' ', ' | sed 's/,$//')
    
    write_info_message "Paires de clés disponibles : $KEY_PAIR_NAMES"
    
    # Déterminer quelle clé utiliser
    if echo $KEY_PAIR_NAMES | grep -q "acces"; then
        KEY_NAME_TO_USE="acces"
    elif [ ! -z "$KEY_PAIR_NAMES" ]; then
        KEY_NAME_TO_USE=$(echo $KEY_PAIR_NAMES | cut -d',' -f1 | tr -d ' ')
    else
        write_error_message "Aucune paire de clés disponible. Veuillez en créer une avant de continuer."
        exit 1
    fi
    
    write_info_message "Utilisation de la paire de clés : $KEY_NAME_TO_USE"
    
    # Création du fichier terraform.tfvars
    cat > terraform.tfvars << EOF
aws_region           = "$AWS_REGION"
project_name         = "greenshop"
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["${AWS_REGION}a", "${AWS_REGION}b"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
bastion_ingress_cidr = ["$IP_ADDRESS/32"]
key_name             = "$KEY_NAME_TO_USE"
bastion_instance_type = "t2.micro"
app_instance_type    = "t2.small"
asg_min_size         = 2
asg_max_size         = 5
asg_desired_capacity = 2
db_allocated_storage = 20
db_engine            = "mysql"
db_engine_version    = "8.0"
db_instance_class    = "db.t3.small"
db_name              = "greenshop"
db_username          = "admin"
db_password          = "ChangeMe123!"
EOF
    
    write_info_message "Fichier terraform.tfvars créé avec succès."
    write_warning_message "IMPORTANT: Veuillez éditer le fichier terraform.tfvars pour modifier le mot de passe de la base de données !"
    echo ""
    read -p "Appuyez sur Entrée pour continuer après avoir modifié le fichier..."
else
    write_info_message "Le fichier terraform.tfvars existe déjà."
    # Obtention de l'IP publique
    IP_ADDRESS=$(curl -s "https://api.ipify.org")
    if [ -z "$IP_ADDRESS" ]; then
        write_warning_message "Impossible de récupérer l'adresse IP automatiquement. Utilisation d'une valeur existante."
    else
        write_info_message "Adresse IP détectée : $IP_ADDRESS"
        # Mise à jour du fichier terraform.tfvars avec la vraie adresse IP
        sed -i "s|bastion_ingress_cidr = \[\"[^\"]*\"\]|bastion_ingress_cidr = [\"$IP_ADDRESS/32\"]|g" terraform.tfvars
        write_info_message "Adresse IP configurée dans terraform.tfvars : $IP_ADDRESS/32"
    fi
fi

# Mettre à jour la paire de clés dans terraform.tfvars
write_info_message "Vérification des paires de clés disponibles..."
KEY_PAIRS=$(aws ec2 describe-key-pairs)
KEY_PAIR_NAMES=$(echo $KEY_PAIRS | grep -o '"KeyName": "[^"]*"' | cut -d'"' -f4 | tr '\n' ', ' | sed 's/,$//')

write_info_message "Paires de clés disponibles : $KEY_PAIR_NAMES"

# Déterminer quelle clé utiliser
if echo $KEY_PAIR_NAMES | grep -q "acces"; then
    KEY_NAME_TO_USE="acces"
elif [ ! -z "$KEY_PAIR_NAMES" ]; then
    KEY_NAME_TO_USE=$(echo $KEY_PAIR_NAMES | cut -d',' -f1 | tr -d ' ')
else
    write_error_message "Aucune paire de clés disponible. Veuillez en créer une avant de continuer."
    exit 1
fi

write_info_message "Utilisation de la paire de clés : $KEY_NAME_TO_USE"
sed -i "s|key_name *= *\"[^\"]*\"|key_name = \"$KEY_NAME_TO_USE\"|g" terraform.tfvars

# Fonction pour vérifier si une ressource existe dans AWS
function test_aws_resource() {
    local RESOURCE_TYPE=$1
    local RESOURCE_NAME=$2
    local REGION=$3
    
    write_info_message "Vérification de l'existence de $RESOURCE_TYPE : $RESOURCE_NAME"
    
    case $RESOURCE_TYPE in
        "vpc")
            if aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$RESOURCE_NAME" --region $REGION | grep -q "VpcId"; then
                return 0  # Existe
            else
                return 1  # N'existe pas
            fi
            ;;
        "loadbalancer")
            if aws elbv2 describe-load-balancers --names $RESOURCE_NAME --region $REGION &> /dev/null; then
                return 0  # Existe
            else
                return 1  # N'existe pas
            fi
            ;;
        "targetgroup")
            if aws elbv2 describe-target-groups --names $RESOURCE_NAME --region $REGION &> /dev/null; then
                return 0  # Existe
            else
                return 1  # N'existe pas
            fi
            ;;
        "dbsubnetgroup")
            if aws rds describe-db-subnet-groups --db-subnet-group-name $RESOURCE_NAME --region $REGION &> /dev/null; then
                return 0  # Existe
            else
                return 1  # N'existe pas
            fi
            ;;
        *)
            write_warning_message "Type de ressource non pris en charge: $RESOURCE_TYPE"
            return 1  # N'existe pas
            ;;
    esac
}

# Fonction pour supprimer les ressources AWS
function remove_aws_resources() {
    local PROJECT_NAME=$1
    local REGION=$2
    
    write_info_message "Récupération des informations sur les ressources existantes..."
    
    # Récupérer l'ARN du Load Balancer
    local LB_ARN=$(aws elbv2 describe-load-balancers --region $REGION 2>/dev/null | grep -A 3 "\"LoadBalancerName\": \"$PROJECT_NAME-alb\"" | grep "\"LoadBalancerArn\"" | cut -d'"' -f4)
    
    # Récupérer l'ARN du Target Group
    local TG_ARN=$(aws elbv2 describe-target-groups --region $REGION 2>/dev/null | grep -A 3 "\"TargetGroupName\": \"$PROJECT_NAME-tg\"" | grep "\"TargetGroupArn\"" | cut -d'"' -f4)
    
    # Supprimer Load Balancer
    if [ ! -z "$LB_ARN" ]; then
        write_info_message "Suppression du Load Balancer..."
        aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN --region $REGION &> /dev/null
        # Attendre que le Load Balancer soit supprimé
        sleep 30
    fi
    
    # Supprimer Target Group
    if [ ! -z "$TG_ARN" ]; then
        write_info_message "Suppression du Target Group..."
        aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION &> /dev/null
    fi
    
    # Vérifier l'existence de l'instance DB
    local DB_EXISTS=$(aws rds describe-db-instances --region $REGION 2>/dev/null | grep -c "\"DBInstanceIdentifier\": \"$PROJECT_NAME-db\"")
    
    # Supprimer l'instance DB si elle existe
    if [ $DB_EXISTS -gt 0 ]; then
        write_info_message "Suppression de l'instance de base de données... (cela peut prendre plusieurs minutes)"
        aws rds delete-db-instance --db-instance-identifier "$PROJECT_NAME-db" --skip-final-snapshot --region $REGION &> /dev/null
        
        # Attendre que l'instance soit supprimée
        write_info_message "En attente de la suppression de l'instance DB..."
        while true; do
            sleep 30
            if ! aws rds describe-db-instances --db-instance-identifier "$PROJECT_NAME-db" --region $REGION &> /dev/null; then
                break
            fi
            write_info_message "L'instance DB est toujours en cours de suppression..."
        done
    fi
    
    # Supprimer DB Subnet Group
    write_info_message "Suppression du DB Subnet Group..."
    if aws rds delete-db-subnet-group --db-subnet-group-name "$PROJECT_NAME-db-subnet-group" --region $REGION &> /dev/null; then
        write_info_message "DB Subnet Group supprimé avec succès."
    else
        write_warning_message "Impossible de supprimer le DB Subnet Group pour le moment. Il est peut-être encore utilisé par une instance en cours de suppression."
        write_info_message "Vous pouvez réessayer plus tard avec la commande: aws rds delete-db-subnet-group --db-subnet-group-name $PROJECT_NAME-db-subnet-group"
    fi
    
    write_info_message "Ressources supprimées avec succès."
}

# Fonction pour vérifier toutes les ressources principales avant le déploiement
function test_all_resources() {
    local PROJECT_NAME="greenshop"
    
    local VPC_EXISTS=false
    local LB_EXISTS=false
    local TG_EXISTS=false
    local DBSG_EXISTS=false
    
    if test_aws_resource "vpc" "$PROJECT_NAME-vpc" "$AWS_REGION"; then
        VPC_EXISTS=true
    fi
    
    if test_aws_resource "loadbalancer" "$PROJECT_NAME-alb" "$AWS_REGION"; then
        LB_EXISTS=true
    fi
    
    if test_aws_resource "targetgroup" "$PROJECT_NAME-tg" "$AWS_REGION"; then
        TG_EXISTS=true
    fi
    
    if test_aws_resource "dbsubnetgroup" "$PROJECT_NAME-db-subnet-group" "$AWS_REGION"; then
        DBSG_EXISTS=true
    fi
    
    # Afficher un résumé des ressources existantes
    write_info_message "Ressources existantes dans AWS:"
    write_info_message "VPC: $(if $VPC_EXISTS; then echo "Existe"; else echo "N'existe pas"; fi)"
    write_info_message "Load Balancer: $(if $LB_EXISTS; then echo "Existe"; else echo "N'existe pas"; fi)"
    write_info_message "Target Group: $(if $TG_EXISTS; then echo "Existe"; else echo "N'existe pas"; fi)"
    write_info_message "DB Subnet Group: $(if $DBSG_EXISTS; then echo "Existe"; else echo "N'existe pas"; fi)"
    
    # Si l'une des ressources existe déjà, proposer des options
    if $VPC_EXISTS || $LB_EXISTS || $TG_EXISTS || $DBSG_EXISTS; then
        write_warning_message "Certaines ressources existent déjà dans AWS."
        write_info_message "Options disponibles:"
        write_info_message "1. Supprimer les ressources existantes et redéployer"
        write_info_message "2. Importer les ressources existantes dans l'état Terraform"
        write_info_message "3. Continuer le déploiement (possibilité d'erreurs)"
        
        local CHOICE=""
        while [[ ! $CHOICE =~ ^[1-3]$ ]]; do
            read -p "Choisissez une option (1-3): " CHOICE
        done
        
        case $CHOICE in
            "1")
                # Supprimer les ressources existantes
                write_info_message "Suppression des ressources existantes..."
                remove_aws_resources "greenshop" "$AWS_REGION"
                write_info_message "Ressources supprimées, prêt pour le déploiement."
                ;;
            "2")
                # Importer les ressources existantes
                write_info_message "Cette option nécessite de connaître les ARN exacts des ressources."
                write_info_message "Veuillez consulter la documentation Terraform pour l'importation."
                ;;
            "3")
                write_warning_message "Continuez à vos risques et périls - des erreurs de déploiement sont probables."
                ;;
        esac
    else
        write_info_message "Aucune ressource n'existe déjà. Prêt pour un déploiement propre."
    fi
}

# Initialisation de Terraform
write_separator
write_info_message "Initialisation de Terraform..."
terraform init

if [ $? -ne 0 ]; then
    write_error_message "L'initialisation de Terraform a échoué."
    exit 1
else
    write_info_message "Terraform initialisé avec succès."
fi

# Plan d'exécution
write_separator
write_info_message "Création du plan d'exécution..."
terraform plan -out=tfplan

if [ $? -ne 0 ]; then
    write_error_message "La création du plan Terraform a échoué."
    exit 1
else
    write_info_message "Plan Terraform créé avec succès."
fi

# Exécuter la vérification avant le déploiement
test_all_resources

# Demande de confirmation
write_separator
write_warning_message "Cette opération va créer des ressources AWS qui peuvent entraîner des frais."
read -p "Voulez-vous déployer l'infrastructure ? (O/N): " confirmation

if [[ $confirmation =~ [oO] ]]; then
    # Déploiement
    write_separator
    write_info_message "Déploiement de l'infrastructure en cours... (cela peut prendre plusieurs minutes)"
    terraform apply tfplan
    
    if [ $? -ne 0 ]; then
        write_error_message "Le déploiement a échoué."
        exit 1
    fi
    
    # Récupération des outputs
    write_info_message "Récupération des informations de connexion..."
    
    # Vérification des outputs
    OUTPUTS=$(terraform output -json 2>/dev/null)
    if [ $? -eq 0 ]; then
        BASTION_IP=$(echo $OUTPUTS | grep -o '"bastion_public_ip":{[^}]*"value":"[^"]*"' | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
        ALB_DNS=$(echo $OUTPUTS | grep -o '"alb_dns_name":{[^}]*"value":"[^"]*"' | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
        DB_ENDPOINT=$(echo $OUTPUTS | grep -o '"db_endpoint":{[^}]*"value":"[^"]*"' | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
        
        if [ -z "$BASTION_IP" ]; then BASTION_IP="Non disponible"; fi
        if [ -z "$ALB_DNS" ]; then ALB_DNS="Non disponible"; fi
        if [ -z "$DB_ENDPOINT" ]; then DB_ENDPOINT="Non disponible"; fi
        
        echo ""
        write_separator
        print_color "cyan" "               DÉPLOIEMENT TERMINÉ               "
        write_separator
        print_color "white" "INFORMATIONS DE CONNEXION:"
        write_separator
        echo "IP du bastion: $BASTION_IP"
        echo "DNS du load balancer: $ALB_DNS"
        echo "Endpoint de base de données: $DB_ENDPOINT"
        write_separator
        echo "Pour vous connecter au bastion:"
        echo "ssh -i $KEY_NAME_TO_USE.pem ec2-user@$BASTION_IP"
        write_separator
        
        # Sauvegarde des informations
        write_info_message "Sauvegarde des informations de connexion dans le fichier deployment_info.txt..."
        terraform output > deployment_info.txt
    else
        write_warning_message "Impossible de récupérer les outputs. Vérifiez la console AWS."
    fi
else
    write_warning_message "Déploiement annulé."
fi

write_separator
write_info_message "Script terminé."