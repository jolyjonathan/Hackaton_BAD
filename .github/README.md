# Déploiement automatisé de GreenShop

Ce projet contient les workflows GitHub Actions pour le déploiement automatisé de l'application GreenShop sur plusieurs instances EC2 privées via un serveur bastion.

## Architecture

L'architecture de déploiement se compose de:

- **GitHub Actions**: Automatisation du workflow de déploiement
- **Serveur Bastion**: Serveur intermédiaire donnant accès au réseau privé
- **Instances EC2 privées**: Serveurs cibles où l'application est déployée
- **Conteneur Docker**: Execution de l'application GreenShop

```
GitHub Actions → Bastion → Instances EC2 privées
                            ├─ Instance 1 (Docker)
                            ├─ Instance 2 (Docker)
                            └─ Instance 3 (Docker)
```

## Prérequis

- Un compte GitHub avec GitHub Actions activé
- Accès SSH au serveur bastion
- Instances EC2 cibles dans un réseau privé
- La même clé SSH pour se connecter au bastion et aux instances cibles
- Docker installé sur les instances cibles ou privilèges pour l'installer

## Configuration

### Secrets GitHub Actions

Configurez les secrets suivants dans votre dépôt GitHub (Settings → Secrets and variables → Actions):

| Nom du secret | Description |
|---------------|-------------|
| `SSH_PRIVATE_KEY` | Clé SSH privée au format PEM pour se connecter au bastion et aux instances    |
| `BASTION_HOST`    | Adresse IP ou nom d'hôte du serveur bastion                                   |
| `BASTION_USER`    | Nom d'utilisateur pour se connecter au bastion (ex: ec2-user)                 |
| `TARGET_HOSTS`    | Liste des adresses IP des instances cibles, séparées par des virgules         |
| `TARGET_USER`     | Nom d'utilisateur pour se connecter aux instances cibles                      |

### Workflow de déploiement

Le workflow GitHub Actions se déclenche automatiquement sur un push vers la branche `main` ou manuellement via l'interface GitHub.

## Fonctionnement

Le processus de déploiement exécute les étapes suivantes:

1. **Connexion au serveur bastion**: Utilise la clé SSH pour se connecter au bastion
2. **Connexion aux instances cibles via le bastion**: Utilise le bastion comme proxy SSH
3. **Installation de Docker** (si nécessaire): Installe Docker sur les instances cibles
4. **Libération du port 80**: Arrête les services qui pourraient utiliser le port 80
5. **Déploiement du conteneur**: Télécharge et démarre le conteneur GreenShop
6. **Vérification du déploiement**: S'assure que le conteneur est bien démarré

## Résolution des problèmes courants

### Le workflow ne peut pas se connecter au bastion

Vérifiez que:
- Le groupe de sécurité du bastion autorise les connexions SSH depuis l'Internet (port 22)
- La clé SSH privée est correctement configurée dans les secrets GitHub
- Le bastion dispose d'une adresse IP publique accessible

### Erreur "Port 80 already in use"

Si le port 80 est déjà utilisé, le script tentera:
1. D'arrêter les services web courants (Apache, NGINX)
2. De tuer les processus utilisant le port 80
3. De basculer sur le port 8080 en dernier recours

### Problèmes de permissions Docker

Si vous rencontrez des erreurs de permission Docker, assurez-vous que:
- Toutes les commandes Docker utilisent `sudo`
- Ou l'utilisateur cible appartient au groupe `docker`

## Déploiement manuel

Si le déploiement automatisé échoue, vous pouvez utiliser le script de déploiement manuel:

1. Téléchargez le script `deploy_from_bastion.sh`
2. Transférez-le sur votre serveur bastion
3. Exécutez-le avec les paramètres appropriés:

```bash
./deploy_from_bastion.sh -h "10.0.1.166 10.0.1.150 10.0.2.85" -u ec2-user -v
```

## Structure du projet

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml    # Workflow de déploiement principal
├── scripts/
│   └── deploy_from_bastion.sh  # Script de déploiement manuel
└── README.md            # Ce fichier
```

## Maintenance

### Mise à jour de l'application

Pour mettre à jour l'application:

1. Mettez à jour l'image Docker `flemoi/greenshop` avec la nouvelle version
2. Déclenchez le workflow de déploiement pour redéployer l'application

### Nettoyage Docker

Pour libérer de l'espace disque, exécutez périodiquement sur les instances:

```bash
sudo docker system prune -af --volumes
```

## Sécurité

- N'exposez pas la clé SSH privée en dehors des secrets GitHub
- Limitez les connexions SSH au bastion en définissant des règles de groupe de sécurité strictes
- Envisagez d'utiliser AWS Systems Manager Session Manager comme alternative au bastion SSH
