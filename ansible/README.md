# Ansible Deployment for GreenShop

Ce dossier contient toute la configuration Ansible nécessaire pour :

* Provisionner l’infrastructure (bastion, base de données, web).
* Synchroniser le code source et la base de données.
* Déployer l’application Greenshop sur des serveurs web Amazon Linux 2.

---

## Arborescence du projet

```text
ansible/                  # Répertoire principal Ansible
├── ansible.cfg           # Configuration Ansible (inventaire, roles path, SSH)
├── inventory/            # Inventaire statique des hôtes
│   └── hosts.yml         # Groupes et variables d’hôtes
├── group_vars/           # Variables appliquées à un groupe d’hôtes
│   └── web.yml           # Variables pour tous les hôtes du groupe "web"
├── roles/                # Rôles Ansible réutilisables
│   ├── common/           # Configurations de base (users, firewall, updates)
│   ├── dbserver/         # Tâches de dump et synchronisation de la base MariaDB
│   ├── webserver/        # Installation Apache/PHP, déploiement du code, VHost
│   ├── geerlingguy.apache # Rôle externe pour Apache (optionnel)
│   └── geerlingguy.mysql  # Rôle externe pour MySQL (optionnel)
├── playbooks/            # Playbooks de haut niveau
│   ├── 0_check_aws.yml          # Vérifie la CLI AWS en local
│   ├── 1_check_bastion.yml      # Teste la connectivité SSH au bastion
│   ├── 2_sync_and_dump.yml      # Synchronise code web + dump DB depuis 'target'
│   ├── 3_deploy.yml             # Déploie le rôle webserver sur le groupe 'web'
│   ├── 4_import_db_playbook.yml # Importe le dump SQL (via bastion) vers RDS
│   ├── copy_migration_key.yml   # Copie la clé migration.pem vers le bastion
│   └── regenerate_ssh_key.yml   # Génère et distribue une nouvelle paire SSH
├── requirements/         # Dépendances Ansible Galaxy
│   ├── collections.yml   # Collections requises
│   └── roles.yml         # Rôles externes à installer
└── README.md             # Ce fichier
```

> **À noter** : sous `roles/webserver/files/` se trouve le code PHP/CSS/HTML de Greenshop, qui sera déployé.

---

## Inventaire (`inventory/hosts.yml`)

* **groups** :

  * `target`   : hôte de base de données (alias `target01`, IP privée 192.168.50.82)
  * `bastion`  : bastion EC2 (alias `bastion01`, IP publique)
  * `web`      : serveurs web privés (aliases `web01`, `web02` derrière le bastion)
* **variables clés** :

  * `ansible_host`               : IP réelle à joindre
  * `ansible_user`               : utilisateur SSH
  * `ansible_ssh_private_key_file`: chemin de la clé privée sur le contrôleur
  * `ansible_ssh_common_args`    : ProxyCommand pour passer par le bastion
  * `db_user`, `db_pass`, `db_name`: credentials pour le dump MariaDB
  * `bastion_host`               : nom d’hôte du bastion utilisé en ProxyCommand

---

## Variables de groupe (`group_vars/web.yml`)

```yaml
ansible_user: ec2-user
ansible_ssh_private_key_file: ~/.ssh/migration.pem
ansible_ssh_common_args: >-
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o 'ProxyCommand=ssh -i /root/.ssh/migration.pem ec2-user@{{ hostvars[bastion_host].ansible_host }} -W %h:%p'
```

---

## Description des rôles

### `common`

* Mise à jour de l’OS, création d’utilisateurs, configuration firewall.

### `dbserver`

* **Dump** de la base MariaDB sur l’hôte `target01`.
* **Synchronisation** du dump vers la machine de contrôle.
* (Optionnel) **Import** dans un RDS via bastion.

### `webserver`

* **Installation** : `httpd`, PHP 8 sur Amazon Linux 2.
* **Création** du répertoire `/var/www/greenshop`.
* **Copie** du code depuis `roles/webserver/files/` vers `/home/ec2-user/tmp_upload` sur chaque web via `scp`+`ProxyCommand`.
* **Déploiement** : déplacement des fichiers dans `/var/www/greenshop`.
* **Configuration** :

  * VirtualHost dans `/etc/httpd/conf.d/greenshop.conf`.
  * Suppression de `welcome.conf`.
  * Adaptation de `DocumentRoot` et `<Directory>` dans `httpd.conf`.
* **Handlers** : reload du service `httpd`.

### Rôles externes (Galaxy)

* `geerlingguy.apache`
* `geerlingguy.mysql`

---

## Playbooks

| Playbook                   | Description                                               |
| -------------------------- | --------------------------------------------------------- |
| `0_check_aws.yml`          | Vérifie la présence & l’authentification AWS CLI          |
| `1_check_bastion.yml`      | Teste l’accès SSH au bastion                              |
| `2_sync_and_dump.yml`      | Synchronise le code web + dump DB depuis l’hôte `target`  |
| `3_deploy.yml`             | Exécute le rôle `webserver` sur les hôtes du groupe `web` |
| `4_import_db_playbook.yml` | Importe le dump SQL sur RDS via bastion                   |
| `copy_migration_key.yml`   | Copie `migration.pem` vers le bastion                     |
| `regenerate_ssh_key.yml`   | Génère et distribue une paire SSH Ed25519                 |

---

## Installation des dépendances

```bash
# Installer les rôles
ansible-galaxy install -r requirements/roles.yml

# Installer les collections
ansible-galaxy collection install -r requirements/collections.yml
```

---

## Exécution

```bash
ansible-playbook -i inventory/hosts.yml 0_check_aws.yml
ansible-playbook -i inventory/hosts.yml 1_check_bastion.yml
ansible-playbook -i inventory/hosts.yml 2_sync_and_dump.yml
ansible-playbook -i inventory/hosts.yml 3_deploy.yml
```

Vous pouvez également combiner :

```bash
ansible-playbook -i inventory/hosts.yml playbooks/3_deploy.yml --tags=webserver
```

---

## Bonnes pratiques

* **Ansible Vault** : chiffrez les mots de passe (`db_pass`, `ansible_ssh_pass`).
* **Inventaire dynamique** : passez au plugin AWS EC2 pour l’automatisation complète.
* **Tests Molecule/Testinfra** : ajoutez des scénarios de test dans `roles/*/tests/`.
* **CI/CD** : intégrez ces playbooks dans Jenkins/GitHub Actions (voir `jenkins/`).

