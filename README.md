# Hackaton_BAD
Hackaton_BAD
# SETUP SSH and Ansible for ansible lxc server
```bash

TARGET_IP=192.168.50.82
TARGET_USER="localadm"
TARGET_PASSWORD="root"
SSH_PASSWORD="Azerty12345!"

ssh-keygen -t ecdsa -b 521 -N "$SSH_PASSWORD"

chmod 600 ~/.ssh/id_ecdsa

if ! command -v sshpass &> /dev/null; then
  sudo apt update
  sudo apt install -y sshpass
fi

sshpass -p "$TARGET_PASSWORD" \
  ssh-copy-id -o StrictHostKeyChecking=no \
    -i ~/.ssh/id_ecdsa.pub \
    "$TARGET_USER@$TARGET_IP"


touch ~/.ssh/config
cat > ~/.ssh/config << EOF
Host $TARGET_IP
    HostName $TARGET_IP
    User $TARGET_USER
    Port 22
    IdentityFile ~/.ssh/id_ecdsa
    # Utile pour la suite du projet ssh -J <jump server> <remote server>
EOF

if ! command -v ansible &> /dev/null; then
  sudo apt update
  sudo apt install -y ansible
fi

ansible -i "$TARGET_IP," all -m ping
```

# pas oublier à faire sur 192.168.50.82 (localadm)
pour pas demander password sudo (pas best pratice mais très pratique pour ansible)
```bash
echo 'localadm ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/99-localadm
sudo chmod 440 /etc/sudoers.d/99-localadm
```


# SETUP Ansible env
```bash
#!/usr/bin/env bash
set -euo pipefail

# 0. Répertoire racine de votre projet Ansible
BASE_DIR="$HOME/ansible"
mkdir -p "$BASE_DIR"/{roles,playbooks,inventory,requirements}

cd "$BASE_DIR"

# 1. Initialiser vos rôles locaux
ansible-galaxy init roles/common
ansible-galaxy init roles/webserver
ansible-galaxy init roles/dbserver

# 3. Collections externes
cat > requirements/collections.yml <<EOF
collections:
  - name: community.general
  - name: ansible.posix
EOF
ansible-galaxy collection install -r requirements/collections.yml

# 6. Préparer votre inventory (inventory/hosts.yml)
cat > inventory/hosts.yml <<EOF
all:
  hosts:
    192.168.50.82:
      ansible_user: localadm
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
      db_user: root
      db_pass: root
      db_name: greenshop

  children:
    bastion:
      hosts:
        54.145.230.86:
          ansible_user: ec2-user
          ansible_ssh_private_key_file: /root/.ssh/migration.pem

    web:
      children:
        server-web1:
        server-web2:

server-web1:
  hosts:
    10.0.0.2:
      ansible_user: ec2-user
      ansible_ssh_private_key_file: /root/.ssh/migration.pem
      ansible_ssh_common_args: >-
        -o ProxyCommand="ssh -W %h:%p
        -i /root/.ssh/migration.pem ec2-user@54.145.230.86"

server-web2:
  hosts:
    10.0.0.3:
      ansible_user: ec2-user
      ansible_ssh_private_key_file: /root/.ssh/migration.pem
      ansible_ssh_common_args: >-
        -o ProxyCommand="ssh -W %h:%p
        -i /root/.ssh/migration.pem ec2-user@54.145.230.86"

EOF

# 7. Écrire votre playbook principal (playbooks/site.yml)
cat > playbooks/site.yml <<EOF
- name: Provision de tous les serveurs
  hosts: all
  become: yes

  roles:
    - common
    - { role: geerlingguy.apache, when: "'web' in group_names" }
    - { role: geerlingguy.mysql,   when: "'db'  in group_names" }
EOF

# 6. Fichier de configuration Ansible
cat > ansible.cfg <<'EOF'
[defaults]
inventory       = ./inventory/hosts.yml
roles_path      = ./roles
retry_files_enabled = False
host_key_checking   = False
remote_user     = ec2-user

[privilege_escalation]
become          = True
become_method   = sudo
become_user     = root
become_ask_pass = False

[ssh_connection]
pipelining      = True
ssh_args        = -o ControlMaster=auto \
                  -o ControlPersist=60s \
                  -o StrictHostKeyChecking=no
scp_if_ssh      = True
EOF

# 7. Tests
echo "=== Inventory ==="
ansible-inventory -i inventory/hosts.yml --list

echo
echo "=== Dry-run playbook ==="
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --check


```




# Phase 1 Copy files from 192.168.50.82

```yaml
# roles/webserver/tasks/main.yml
- name: Synchroniser les sources du site Greenshop
  ansible.posix.synchronize:
    src: /var/www/greenshop/
    dest: "{{ playbook_dir }}/../roles/dbserver/files/db_dump.sql""
    mode: pull
    recursive: yes
    rsync_opts:
      - "--archive"
      - "--delete"
  delegate_to: localhost
  when: inventory_hostname == '192.168.50.82'
  tags:
    - sync_web
```

```yaml
# roles/dbserver/tasks/main.yml

- name: Générer le dump de la base MariaDB sur 192.168.50.82
  ansible.builtin.shell: >
    mysqldump -u {{ db_user }} -p'{{ db_pass }}' {{ db_name }} > /tmp/db_dump.sql
  become: yes
  when: inventory_hostname == '192.168.50.82'
  tags:
    - dump_db

- name: Créer le répertoire local de destination pour le dump
  ansible.builtin.file:
    path: "{{ playbook_dir }}/../roles/dbserver/files"
    state: directory
    mode: '0755'
  delegate_to: localhost
  run_once: true
  tags:
    - dump_db

- name: Récupérer le dump MariaDB vers le serveur Ansible
  ansible.posix.synchronize:
    src: /tmp/db_dump.sql
    dest: "{{ playbook_dir }}/../roles/dbserver/files/db_dump.sql"
    mode: pull
    rsync_opts:
      - "--archive"
      - "--delete"
  delegate_to: localhost
  when: inventory_hostname == '192.168.50.82'
  tags:
    - dump_db

- name: Supprimer le dump temporaire sur le serveur distant
  ansible.builtin.file:
    path: /tmp/db_dump.sql
    state: absent
  become: yes
  when: inventory_hostname == '192.168.50.82'
  tags:
    - dump_db

```

# Phase 2 connect to aws

```bash
#!/usr/bin/env bash
set -euo pipefail

CRED_FILE="${HOME}/.aws/credentials"


if ! command -v aws &> /dev/null; then
  echo "aws CLI non trouvée, installation en cours..."
  if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y awscli
  else
    echo "⚠️ Pas de gestionnaire apt-get détecté, installez manuellement awscli." >&2
    exit 1
  fi
fi



mkdir -p "$(dirname "${CRED_FILE}")"


cat > "${CRED_FILE}" <<EOF


[default]
aws_access_key_id=ASIA3FLD5QC6YVI3K2IJ
aws_secret_access_key=mC5R4v+TwC8fKNWdR4aFheXG215EqK5tZt0sDhag
aws_session_token=IQoJb3JpZ2luX2VjELH//////////wEaCXVzLXdlc3QtMiJIMEYCIQC3KZKkzAZQOzbZksAHMJerjn73A6pUrRxAtDjuK35bXQIhAIN2zGP0764h/BqWmIxnMZwyKHgLI0xkpabZt7ag0+PoKqcCCFoQABoMNzY3Mzk4MDg0Nzk3Igw+G0t2MKApNQk+21IqhAJ4JvHzJGa50uoI3oNxKAjrBZSBLzeCaMxxoLJmX0nlCEuslOHuD5bgTFlhIrwJjTuJS1R+GCRHFcNP7F4JJJ7th+k6bsYcrAxhBjtKAPlG5OTz1qPpKXrPR3fUB+dlut3TKVJ1qTkU9QfUIKM1BJvrn3BDwoO+byYjWe3snA1FB2uWt2W2Uf7B/sVuY81esLgdngi12hHOUvaApg9Gf06SjM9KcrZhSw0AjA3KGqXShau47XbkaI0wOxVF6qRkQtrvaS4CLNEcfFtnMkKYp1l/omWyiyb9mTfZLhwv0W0iccq0zTYE9LGp3E+TKDcKekJTLa7hvCPzja6r+gsNSVv4ItsLtjDctuzABjqcAcgpO+atwMjvuslwi6PhYK2Y7vWtl6zzSUcQP2+z1lLusNTt7gAcIwbkwopkKTzV20QXmnx2+WIyKb7NNnUWui9jHK1uOylJNpmmBKDYY2sYYCKJLg+8uOnW/w/f7MXkHkRidX7be32yqkJagFeOF5Ds4NXYI1HVEPitFssMnmUdGdjZKQV6OC1SorgmY2TCf+wyA1rI2mt3EqF0WQ==


EOF


chmod 600 "${CRED_FILE}"

echo "AWS credentials écrits dans ${CRED_FILE}"

```

```yaml
# playbooks/check_aws.yml
- name: Vérifier la CLI AWS sur le serveur Ansible
  hosts: localhost
  connection: local
  gather_facts: false

  tasks:
    - name: Vérifier que la CLI AWS est installée
      ansible.builtin.command: aws --version
      register: aws_cli_check
      changed_when: false
      failed_when: aws_cli_check.rc != 0
      tags:
        - aws_check

    - name: Vérifier la validité des credentials AWS
      ansible.builtin.command: >
        aws sts get-caller-identity --output json
      register: aws_identity
      changed_when: false
      failed_when: aws_identity.rc != 0
      tags:
        - aws_check

    - name: Afficher l’ARN de l’utilisateur AWS configuré
      ansible.builtin.debug:
        msg: "AWS configuré pour l’ARN {{ (aws_identity.stdout | from_json).Arn }}"
      when: aws_identity is succeeded
      tags:
        - aws_check

```

```bash
ansible-playbook playbooks/check_aws.yml --tags aws_check
```


# Script push key pub ssh bastion aws

```bash
#!/usr/bin/env bash
set -euo pipefail

KEY_PATH="${HOME}/.ssh/migration.pem"


if [[ ! -d "${HOME}/.ssh" ]]; then
  mkdir -m 700 "${HOME}/.ssh"
fi


cat > "${KEY_PATH}" <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAwf8lod2glJxjp8USE6g44KficqRheR3NW5rjLd/0X2LEXyLB
SlmHxgDjQ6LtQz9vLmoiP6ABZWKN7bkzVFvs9SnyUA5y8LZVrXxIB4HFW3SDXx56
NAMLJl4ZUyeSkIv/iKIc0RzEr41ljoLYmtO1k3cxJpxLQOZIggpimAh2fhpTdp0u
wxCMG9L5yHEbRXMINzAJ0kLdumVGd2Nr3OjQDTUEjaz4M+dyZSVLK/lflFlMVHfW
UwRF6Dh0S+M4L7XH0Oo+9ztdZHMfjZqFz5FB19QgU4qzixbbfdcfkY+0Z7LovWPB
gZLHUtwTcX4qQ6AgDYAZUHP2YW/zFPfIqS0H3QIDAQABAoIBAQCiVprtOwM3mS8j
o5we6vS9un+ao8gVjETe1VwqdXCPqZzeZ70MNKOTpAaKAPs+/QRS+Om0CHdimfhe
6E311/8QoYtuRskUeeB0jr3P2l6Gy5drr5tfjvRzpObYWRMi9qRdeBtZOhO1PEOx
3/jWhzc5MdLlloC6zHn8qCgdRWey2Wqd3MuNbmfVuNJwp2IPN1OI4/AKb1bbzRKb
kYOBwIpJf/8Wy5vrlHe4oh3y9NYTqd5YvlB+AiCGeYbZSdwjK18qMKpY1YCdh6Hs
d7Ryg9+HUyZC07B9iEmsLi/7nfzqm2YbXlza2KYpVDG6LEsC2ZKW9lWSjRvdHiWA
wqbljBvBAoGBAPIylzTATguBrPFWfZzVWVW+NAIvf/7UbatiO+K0jb693i/flDhp
Zc/kbOd9gF4JvsTq4fUAYmKrTmn8S0L1aelApwVVDiDN21a4Ulc+grwj4GBFSpZl
XryGR/54eCfqgN5G2ADvwpCAqNwBPFEhtjxNkzEPLZKm89jrwVem1PyZAoGBAM0N
WuFOkUvTXYP69z5c3KfM9qXjFqnuLH3nqPRYvlhzCdNQNiUGK53xFooQ12yyWMt1
g4BW/6oUqFP1RlFso0xzATCSF3Vkd52R7zc6tRfoM7ssT/NkNc4A+syxZe47tkCx
GTpB7aLgAZdc/0StRJ5fP2zDx0nd7uTGJgozgIvlAoGATLhp3XPtRQfW2LwlHkEX
A2o031xcl0SDWP7NKYs4O2u5rkCMmzIH5krdlJbUyvUbURV2bj2o7MiHFlutG5DR
8+le/vlqeEm9aUMKEkji8OYMdXJ9phaGZAHFXH6c0UgfeknGssVARLX8x3Q8vxaG
u6N3NNsx/HqWU+iaXkGixkECgYAcTMyPLf3Fnk1YyslW1RArJJGiAX5+Q33mfpOF
7b2PjYj8niRq5bgdW0nGEl75BIBWzEgy7U7p1WIJ/F8RG9JJ2dF/N5p/PDd6Csse
Lz8RJp4FJi9+owT+Aoqat50ezSTxNsAJl1HJ2eq+Tjp46wT+apzhUP/vRO8UqfhU
DhmetQKBgQDRDW6y5a2lX9gHtButsypeYecqIVSBl43syFfWE4eBjHizy2S4I6fU
Q7gpEEjVAtiNB5lTTl6/2b1qFTu2BNSJB1Br5fzmcbykWVZIzE1brnFjvPQwACOV
3sVAyPeFJENScBxGzm/M0kqvaFseyjp3/gLz0Lj/CQuGPFB8zck2rg==
-----END RSA PRIVATE KEY-----
EOF

chmod 400 "${KEY_PATH}"

echo "La clé a été installée dans ${KEY_PATH} avec permission 400."

```


```yaml
---
# roles/webserver/tasks/main.yml

- name: Installer Apache et PHP8 sur Debian/Ubuntu
  apt:
    name: "{{ php_packages.debian + ['apache2'] }}"
    state: present
    update_cache: yes
  when: ansible_os_family == 'Debian'

- name: Activer PHP module Apache sur Debian/Ubuntu
  apache2_module:
    name: php8.0
    state: present
  when: ansible_os_family == 'Debian'

- name: Installer Apache et PHP8 sur RHEL/AMZN
  yum:
    name: "{{ php_packages.redhat + ['httpd'] }}"
    state: present
  when: ansible_os_family == 'RedHat'

- name: Sur RHEL/AMZN, activer le repo php8 via amazon-linux-extras
  shell: amazon-linux-extras enable php8.0
  become: yes
  args:
    creates: /etc/yum.repos.d/amzn2-extras.repo
  when: ansible_distribution == 'Amazon' and ansible_distribution_major_version|version_compare('2', '==')

- name: S'assurer que le service Apache est démarré et activé
  service:
    name: "{{ 'apache2' if ansible_os_family == 'Debian' else 'httpd' }}"
    state: started
    enabled: yes

- name: Créer le dossier de l'application
  file:
    path: "{{ doc_root }}"
    state: directory
    owner: www-data
    group: www-data
    mode: '0755'

- name: Synchroniser les fichiers de l'application
  copy:
    src: "{{ playbook_dir }}/roles/webserver/files/"
    dest: "{{ doc_root }}/"
    owner: www-data
    group: www-data
    mode: '0644'
    recurse: yes

- name: Donner les droits de write sur uploads
  file:
    path: "{{ doc_root }}/uploads"
    owner: www-data
    group: www-data
    mode: '0755'
    recurse: yes

- name: Redémarrer Apache pour prendre en compte les changements
  service:
    name: "{{ 'apache2' if ansible_os_family == 'Debian' else 'httpd' }}"
    state: restarted

```

```bash
scp -r -P 22 \
  -o 'ProxyCommand=ssh -i /root/.ssh/migration.pem ec2-user@54.237.134.137 -W %h:%p' \
  -i /root/.ssh/migration.pem \
  roles/webserver/files/ \
  ec2-user@10.0.2.103:/home/ec2-user/tmp_upload/ \
&& ssh -i /root/.ssh/migration.pem \
  -o 'ProxyCommand=ssh -i /root/.ssh/migration.pem ec2-user@54.237.134.137 -W %h:%p' \
  ec2-user@10.0.2.103 \
  'sudo mkdir -p /var/www && sudo rm -r /var/www && sudo mv /home/ec2-user/tmp_upload/* /var/www && sudo rmdir /home/ec2-user/tmp_upload && ls /var/www'

```
