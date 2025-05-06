# Script de déploiement automatisé pour GreenShop DevOps Cloud Migration
# deploy.ps1

# Fonctions pour améliorer l'affichage
function Write-ColorOutput($ForegroundColor)
{
    # Sauvegarde de la couleur actuelle
    $currentForeground = $host.UI.RawUI.ForegroundColor
    
    # Définition de la nouvelle couleur
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    
    # Affichage du message (les arguments)
    if ($args) {
        Write-Output $args
    }
    
    # Restauration de la couleur d'origine
    $host.UI.RawUI.ForegroundColor = $currentForeground
}

function Write-InfoMessage($message) {
    Write-ColorOutput Green "[INFO] $message"
}

function Write-WarningMessage($message) {
    Write-ColorOutput Yellow "[ATTENTION] $message"
}

function Write-ErrorMessage($message) {
    Write-ColorOutput Red "[ERREUR] $message"
}

function Write-Separator {
    Write-Output "================================================================="
}

# Affichage du titre
Write-Separator
Write-ColorOutput Cyan "DÉPLOIEMENT AUTOMATISÉ GREENSHOP - AWS CLOUD MIGRATION"
Write-Separator
Write-Output ""

# Vérification de l'exécution en tant qu'administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-WarningMessage "Ce script n'est pas exécuté en tant qu'administrateur. Certaines opérations pourraient échouer."
    Write-WarningMessage "Il est recommandé de l'exécuter dans une console PowerShell en mode administrateur."
    Write-Output ""
    $confirmation = Read-Host "Voulez-vous continuer quand même ? (O/N)"
    if ($confirmation -ne "O" -and $confirmation -ne "o") {
        Write-ErrorMessage "Script interrompu par l'utilisateur."
        exit 1
    }
}

# Vérification de l'installation de Terraform
Write-InfoMessage "Vérification de l'installation de Terraform..."
$terraformInstalled = $null -ne (Get-Command terraform -ErrorAction SilentlyContinue)

if (-not $terraformInstalled) {
    Write-WarningMessage "Terraform n'est pas installé ou n'est pas dans le PATH."
    Write-InfoMessage "Installation de Terraform via Chocolatey..."
    
    # Vérification de l'installation de Chocolatey
    $chocoInstalled = $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
    
    if (-not $chocoInstalled) {
        Write-WarningMessage "Chocolatey n'est pas installé. Installation en cours..."
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            
            # Actualiser le PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            Write-InfoMessage "Chocolatey a été installé avec succès."
        }
        catch {
            Write-ErrorMessage "L'installation de Chocolatey a échoué. Veuillez l'installer manuellement."
            Write-ErrorMessage "Détails de l'erreur: $_"
            Write-InfoMessage "Vous pouvez installer Terraform manuellement depuis: https://www.terraform.io/downloads.html"
            exit 1
        }
    }
    
    # Installation de Terraform via Chocolatey
    try {
        choco install terraform -y
        
        # Actualiser le PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Vérification de l'installation
        $terraformInstalled = $null -ne (Get-Command terraform -ErrorAction SilentlyContinue)
        
        if ($terraformInstalled) {
            Write-InfoMessage "Terraform a été installé avec succès."
        }
        else {
            Write-ErrorMessage "L'installation de Terraform a échoué. Veuillez redémarrer PowerShell et réessayer, ou l'installer manuellement."
            exit 1
        }
    }
    catch {
        Write-ErrorMessage "L'installation de Terraform a échoué. Veuillez l'installer manuellement."
        Write-ErrorMessage "Détails de l'erreur: $_"
        exit 1
    }
}

# Affichage de la version de Terraform
$terraformVersion = (terraform version -json | ConvertFrom-Json).terraform_version
Write-InfoMessage "Version de Terraform détectée: $terraformVersion"

# Vérification de l'installation d'AWS CLI
Write-InfoMessage "Vérification de l'installation d'AWS CLI..."
$awsCliInstalled = $null -ne (Get-Command aws -ErrorAction SilentlyContinue)

if (-not $awsCliInstalled) {
    Write-WarningMessage "AWS CLI n'est pas installé ou n'est pas dans le PATH."
    Write-InfoMessage "Installation d'AWS CLI..."
    
    try {
        # Téléchargement du programme d'installation d'AWS CLI
        $installerPath = "$env:TEMP\AWSCLIV2.msi"
        Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $installerPath
        
        # Installation d'AWS CLI
        Start-Process msiexec.exe -ArgumentList "/i", $installerPath, "/quiet", "/norestart" -Wait
        
        # Nettoyage
        Remove-Item $installerPath -Force
        
        # Actualiser le PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Vérification de l'installation
        $awsCliInstalled = $null -ne (Get-Command aws -ErrorAction SilentlyContinue)
        
        if ($awsCliInstalled) {
            Write-InfoMessage "AWS CLI a été installé avec succès."
        }
        else {
            Write-ErrorMessage "L'installation d'AWS CLI a échoué. Veuillez redémarrer PowerShell et réessayer, ou l'installer manuellement."
            exit 1
        }
    }
    catch {
        Write-ErrorMessage "L'installation d'AWS CLI a échoué. Veuillez l'installer manuellement."
        Write-ErrorMessage "Détails de l'erreur: $_"
        exit 1
    }
}

# Affichage de la version d'AWS CLI
$awsVersion = (aws --version) -split " " | Select-Object -First 1
Write-InfoMessage "Version d'AWS CLI détectée: $awsVersion"

# Vérification des credentials AWS
Write-InfoMessage "Vérification des credentials AWS..."
try {
    $awsAccountInfo = aws sts get-caller-identity | ConvertFrom-Json
    Write-InfoMessage "Connecté au compte AWS: $($awsAccountInfo.Account) ($($awsAccountInfo.Arn))"
    
    # Récupération de la région AWS configurée
    $awsRegion = aws configure get region
    if (-not $awsRegion) {
        $awsRegion = "us-east-1" # Région par défaut
    }
    Write-InfoMessage "Région AWS configurée: $awsRegion"
}
catch {
    Write-WarningMessage "Aucun credential AWS valide détecté. Configuration requise..."
    Write-InfoMessage "Veuillez saisir vos informations d'identification AWS ou editer le fichier ~/.aws/credentials :"
    
    aws configure
    
    # Vérification après configuration
    try {
        $awsAccountInfo = aws sts get-caller-identity | ConvertFrom-Json
        $awsRegion = aws configure get region
        if (-not $awsRegion) {
            $awsRegion = "us-east-1" # Région par défaut
        }
        Write-InfoMessage "Connecté au compte AWS: $($awsAccountInfo.Account) ($($awsAccountInfo.Arn))"
        Write-InfoMessage "Région AWS configurée: $awsRegion"
    }
    catch {
        Write-ErrorMessage "La configuration AWS a échoué. Veuillez vérifier vos credentials."
        exit 1
    }
}

# Vérification de l'existence du fichier terraform.tfvars
Write-InfoMessage "Vérification du fichier terraform.tfvars..."
if (-not (Test-Path -Path "terraform.tfvars")) {
    Write-WarningMessage "Le fichier terraform.tfvars n'existe pas. Création en cours..."
    
    # Obtention de l'IP publique
    try {
        $ipAddress = (Invoke-RestMethod -Uri "https://api.ipify.org" -UseBasicParsing)
        Write-InfoMessage "Adresse IP détectée : $ipAddress"
    }
    catch {
        Write-WarningMessage "Impossible de récupérer l'adresse IP automatiquement. Utilisation d'une valeur par défaut."
        $ipAddress = "0.0.0.0"
    }
    
    # Vérification des paires de clés disponibles
    Write-InfoMessage "Vérification des paires de clés disponibles..."
    $keyPairs = aws ec2 describe-key-pairs | ConvertFrom-Json
    $keyPairNames = $keyPairs.KeyPairs.KeyName

    Write-InfoMessage "Paires de clés disponibles : $($keyPairNames -join ', ')"

    # Déterminer quelle clé utiliser
    if ($keyPairNames -contains "acces") {
        $keyNameToUse = "acces"
    } elseif ($keyPairNames.Count -gt 0) {
        $keyNameToUse = $keyPairNames[0]
    } else {
        Write-ErrorMessage "Aucune paire de clés disponible. Veuillez en créer une avant de continuer."
        exit 1
    }

    Write-InfoMessage "Utilisation de la paire de clés : $keyNameToUse"


    $tfvarsContent = @"
aws_region           = "$awsRegion"
project_name         = "greenshop"
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["${awsRegion}a", "${awsRegion}b"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
bastion_ingress_cidr = ["$ipAddress/32"]
key_name             = "$keyNameToUse"
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
"@
    
    Set-Content -Path "terraform.tfvars" -Value $tfvarsContent
    
    Write-InfoMessage "Fichier terraform.tfvars créé avec succès."
    Write-WarningMessage "IMPORTANT: Veuillez éditer le fichier terraform.tfvars pour modifier le mot de passe de la base de données !"
    Write-Output ""
    Read-Host "Appuyez sur Entrée pour continuer après avoir modifié le fichier..."
}
else {
    Write-InfoMessage "Le fichier terraform.tfvars existe déjà."
    # Obtention de l'IP publique
    try {
        $ipAddress = (Invoke-RestMethod -Uri "https://api.ipify.org" -UseBasicParsing)
        Write-InfoMessage "Adresse IP détectée : $ipAddress"
    }
    catch {
        Write-WarningMessage "Impossible de récupérer l'adresse IP automatiquement. Utilisation d'une valeur par défaut."
        $ipAddress = "0.0.0.0"
    }
    # Mise à jour du fichier terraform.tfvars avec la vraie adresse IP
    (Get-Content -Path "terraform.tfvars") -replace 'bastion_ingress_cidr = \["YOUR_IP/32"\]', "bastion_ingress_cidr = [""$ipAddress/32""]" | Set-Content -Path "terraform.tfvars"
    Write-InfoMessage "Adresse IP configurée dans terraform.tfvars : $ipAddress/32"
}


# Initialisation de Terraform
Write-Separator
Write-InfoMessage "Initialisation de Terraform..."
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMessage "L'initialisation de Terraform a échoué."
    exit 1
}
else {
    Write-InfoMessage "Terraform initialisé avec succès."
}

# Plan d'exécution
Write-Separator
Write-InfoMessage "Création du plan d'exécution..."
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMessage "La création du plan Terraform a échoué."
    exit 1
}
else {
    Write-InfoMessage "Plan Terraform créé avec succès."
}

# Vérifier les paires de clés disponibles
Write-InfoMessage "Vérification des paires de clés disponibles..."
$keyPairs = aws ec2 describe-key-pairs | ConvertFrom-Json
$keyPairNames = $keyPairs.KeyPairs.KeyName

Write-InfoMessage "Paires de clés disponibles : $($keyPairNames -join ', ')"

# Mettre à jour le fichier terraform.tfvars avec la première paire de clés disponible ou "acces" si elle existe
if ($keyPairNames -contains "acces") {
    $keyNameToUse = "acces"
} elseif ($keyPairNames.Count -gt 0) {
    $keyNameToUse = $keyPairNames[0]
} else {
    Write-ErrorMessage "Aucune paire de clés disponible. Veuillez en créer une avant de continuer."
    exit 1
}

Write-InfoMessage "Utilisation de la paire de clés : $keyNameToUse"
(Get-Content -Path "terraform.tfvars") -replace 'key_name\s*=\s*"[^"]+"', "key_name = ""$keyNameToUse""" | Set-Content -Path "terraform.tfvars"

# Fonction pour vérifier si une ressource existe dans AWS
function Test-AwsResource {
    param (
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$Region = "us-east-1"
    )
    
    Write-InfoMessage "Vérification de l'existence de $ResourceType : $ResourceName"
    
    switch ($ResourceType) {
        "vpc" {
            $resource = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$ResourceName" --region $Region | ConvertFrom-Json
            return $resource.Vpcs.Count -gt 0
        }
        "loadbalancer" {
            $resource = aws elbv2 describe-load-balancers --names $ResourceName --region $Region 2>$null
            return $LASTEXITCODE -eq 0
        }
        "targetgroup" {
            $resource = aws elbv2 describe-target-groups --names $ResourceName --region $Region 2>$null
            return $LASTEXITCODE -eq 0
        }
        "dbsubnetgroup" {
            $resource = aws rds describe-db-subnet-groups --db-subnet-group-name $ResourceName --region $Region 2>$null
            return $LASTEXITCODE -eq 0
        }
        default {
            Write-WarningMessage "Type de ressource non pris en charge: $ResourceType"
            return $false
        }
    }
}

# Fonction pour vérifier toutes les ressources principales avant le déploiement
function Test-AllResources {
    $projectName = "greenshop"
    $region = "us-east-1"
    
    $vpcExists = Test-AwsResource -ResourceType "vpc" -ResourceName "$projectName-vpc" -Region $region
    $lbExists = Test-AwsResource -ResourceType "loadbalancer" -ResourceName "$projectName-alb" -Region $region
    $tgExists = Test-AwsResource -ResourceType "targetgroup" -ResourceName "$projectName-tg" -Region $region
    $dbsgExists = Test-AwsResource -ResourceType "dbsubnetgroup" -ResourceName "$projectName-db-subnet-group" -Region $region
    
    # Afficher un résumé des ressources existantes
    Write-InfoMessage "Ressources existantes dans AWS:"
    Write-InfoMessage "VPC: $(if ($vpcExists) { 'Existe' } else { 'N''existe pas' })"
    Write-InfoMessage "Load Balancer: $(if ($lbExists) { 'Existe' } else { 'N''existe pas' })"
    Write-InfoMessage "Target Group: $(if ($tgExists) { 'Existe' } else { 'N''existe pas' })"
    Write-InfoMessage "DB Subnet Group: $(if ($dbsgExists) { 'Existe' } else { 'N''existe pas' })"
    
    # Si l'une des ressources existe déjà, proposer des options
    if ($vpcExists -or $lbExists -or $tgExists -or $dbsgExists) {
        Write-WarningMessage "Certaines ressources existent déjà dans AWS."
        Write-InfoMessage "Options disponibles:"
        Write-InfoMessage "1. Supprimer les ressources existantes et redéployer"
        Write-InfoMessage "2. Importer les ressources existantes dans l'état Terraform"
        Write-InfoMessage "3. Continuer le déploiement (possibilité d'erreurs)"
        
        do {
            $choice = Read-Host "Choisissez une option (1-3)"
        } until ($choice -match '^[1-3]$')
        
        switch ($choice) {
            "1" {
                # Supprimer les ressources existantes
                Write-InfoMessage "Suppression des ressources existantes..."
                Remove-AwsResources -ProjectName "$projectName" -Region "$region"
                # Attention: Supprimer un VPC est plus complexe car il faut d'abord supprimer toutes ses dépendances
                Write-InfoMessage "Ressources supprimées, prêt pour le déploiement."
            }
            "2" {
                # Importer les ressources existantes (vous devrez compléter les ARN réels)
                Write-InfoMessage "Cette option nécessite de connaître les ARN exacts des ressources."
                Write-InfoMessage "Veuillez consulter la documentation Terraform pour l'importation."
            }
            "3" {
                Write-WarningMessage "Continuez à vos risques et périls - des erreurs de déploiement sont probables."
            }
        }
    }
    else {
        Write-InfoMessage "Aucune ressource n'existe déjà. Prêt pour un déploiement propre."
    }
}

function Remove-AwsResources {
    param (
        [string]$ProjectName,
        [string]$Region = "us-east-1"
    )
   
    Write-InfoMessage "Récupération des informations sur les ressources existantes..."
   
    # Récupérer l'ARN du Load Balancer
    $lbInfo = aws elbv2 describe-load-balancers --region $Region | ConvertFrom-Json
    $lb = $lbInfo.LoadBalancers | Where-Object { $_.LoadBalancerName -eq "$ProjectName-alb" }
   
    # Récupérer les ARNs des Target Groups
    $tgInfo = aws elbv2 describe-target-groups --region $Region | ConvertFrom-Json
    $tg = $tgInfo.TargetGroups | Where-Object { $_.TargetGroupName -eq "$ProjectName-tg" }
   
    # Supprimer Load Balancer
    if ($lb) {
        Write-InfoMessage "Suppression du Load Balancer..."
        aws elbv2 delete-load-balancer --load-balancer-arn $lb.LoadBalancerArn --region $Region | Out-Null
        # Attendre que le Load Balancer soit supprimé
        Start-Sleep -Seconds 30
    }
   
    # Supprimer Target Group
    if ($tg) {
        Write-InfoMessage "Suppression du Target Group..."
        aws elbv2 delete-target-group --target-group-arn $tg.TargetGroupArn --region $Region | Out-Null
    }
   
    # Vérifier l'existence de l'instance DB
    $dbInfo = aws rds describe-db-instances --region $Region | ConvertFrom-Json
    $db = $dbInfo.DBInstances | Where-Object { $_.DBInstanceIdentifier -eq "$ProjectName-db" }
   
    # Supprimer l'instance DB si elle existe
    if ($db) {
        Write-InfoMessage "Suppression de l'instance de base de données... (cela peut prendre plusieurs minutes)"
        aws rds delete-db-instance --db-instance-identifier "$ProjectName-db" --skip-final-snapshot --region $Region | Out-Null
       
        # Attendre que l'instance soit supprimée
        Write-InfoMessage "En attente de la suppression de l'instance DB..."
        do {
            Start-Sleep -Seconds 30
            $dbStatus = $null
            try {
                $dbStatus = aws rds describe-db-instances --db-instance-identifier "$ProjectName-db" --region $Region | Out-Null
                Write-InfoMessage "L'instance DB est toujours en cours de suppression..."
            } catch {
                # L'instance n'existe plus
                break
            }
        } while ($dbStatus -ne $null)
    }
   
    # Supprimer DB Subnet Group
    Write-InfoMessage "Suppression du DB Subnet Group..."
    try {
        aws rds delete-db-subnet-group --db-subnet-group-name "$ProjectName-db-subnet-group" --region $Region | Out-Null
        Write-InfoMessage "DB Subnet Group supprimé avec succès."
    } catch {
        Write-WarningMessage "Impossible de supprimer le DB Subnet Group pour le moment. Il est peut-être encore utilisé par une instance en cours de suppression."
        Write-InfoMessage "Vous pouvez réessayer plus tard avec la commande: aws rds delete-db-subnet-group --db-subnet-group-name $ProjectName-db-subnet-group"
    }
   
    Write-InfoMessage "Ressources supprimées avec succès."
}

# Exécuter la vérification avant le déploiement
Test-AllResources

# Demande de confirmation
Write-Separator
Write-WarningMessage "Cette opération va créer des ressources AWS qui peuvent entraîner des frais."
$confirmation = Read-Host "Voulez-vous déployer l'infrastructure ? (O/N)"

if ($confirmation -eq "O" -or $confirmation -eq "o") {
    # Déploiement
    Write-Separator
    Write-InfoMessage "Déploiement de l'infrastructure en cours... (cela peut prendre plusieurs minutes)"
    terraform apply tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Le déploiement a échoué."
        exit 1
    }
    
    # Récupération des outputs
    Write-InfoMessage "Récupération des informations de connexion..."
    
    # Vérification des outputs
    try {
        $outputs = terraform output -json | ConvertFrom-Json
        
        $bastionIp = if ($outputs.bastion_public_ip) { $outputs.bastion_public_ip.value } else { "Non disponible" }
        $albDns = if ($outputs.alb_dns_name) { $outputs.alb_dns_name.value } else { "Non disponible" }
        $dbEndpoint = if ($outputs.db_endpoint) { $outputs.db_endpoint.value } else { "Non disponible" }
        
        Write-Output ""
        Write-Separator
        Write-ColorOutput Cyan "               DÉPLOIEMENT TERMINÉ               "
        Write-Separator
        Write-ColorOutput White "INFORMATIONS DE CONNEXION:"
        Write-Separator
        Write-Output "IP du bastion: $bastionIp"
        Write-Output "DNS du load balancer: $albDns"
        Write-Output "Endpoint de base de données: $dbEndpoint"
        Write-Separator
        Write-Output "Pour vous connecter au bastion:"
        Write-Output "ssh -i $keyNameToUse.pem ec2-user@$bastionIp"
        Write-Separator
        
        # Sauvegarde des informations
        Write-InfoMessage "Sauvegarde des informations de connexion dans le fichier deployment_info.txt..."
        terraform output | Out-File -FilePath "deployment_info.txt"
    }
    catch {
        Write-WarningMessage "Impossible de récupérer les outputs. Vérifiez la console AWS."
        Write-ErrorMessage "Détails de l'erreur: $_"
    }
}
else {
    Write-WarningMessage "Déploiement annulé."
}

Write-Separator
Write-InfoMessage "Script terminé."