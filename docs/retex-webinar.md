# RETEX — Construire ce pipeline, pour de vrai

Ce document n'est pas une liste de bonnes pratiques théoriques. Chaque point ci-dessous est un
incident ou une décision **réellement rencontrée** en construisant `cicd-devsecops-demo` — avec
la question posée sur le moment, les options considérées, et pourquoi tel choix plutôt qu'un
autre. Pensé comme matière première pour les slides du webinaire "DevSecOps moderne : intégrer
la sécurité dans une chaîne CI/CD" — chaque section peut devenir un point de discussion ou un
exemple concret, indépendamment des autres.

---

## 1. Sécurité — les pièges qu'on a vraiment rencontrés

### 1.1 Le faux secret "trop évidemment faux" ne déclenchait rien

**Le piège** : pour démontrer Gitleaks bloquant un merge, premier réflexe — committer une valeur
du type `AKIAFAKEFAKEFAKEFAKE`. Résultat : **Gitleaks ne trouve rien**. Testé, vérifié, confirmé.

**Pourquoi** : le ruleset par défaut de Gitleaks *allowlist* silencieusement les valeurs à faible
entropie ou contenant des marqueurs évidents (`EXAMPLE`, `TEST`, motifs répétés) — précisément
pour ne pas spammer chaque scan d'un repo qui cite la documentation AWS elle-même. Une démo de
sécurité construite avec un faux secret "trop faux" **ne teste rien du tout** — un check qui a
l'air de valider quelque chose sans réellement l'exercer. C'est la définition même du security
theatre, découvert en voulant justement l'illustrer.

**La correction** : un secret factice généré aléatoirement à la volée
(`scripts/generate-demo-secret.sh`), jamais stocké en dur nulle part — assez réaliste en entropie
pour déclencher la détection, jamais un vrai credential.

### 1.2 ...et une fois assez réaliste, il a bloqué notre propre documentation

**Le rebond** : en documentant la valeur qui fonctionne (pour que la démo soit reproductible), le
tout premier `git push` du projet a été **rejeté par GitHub lui-même** :

```
remote: - GITHUB PUSH PROTECTION
remote:   Amazon AWS Access Key ID — docs/recap.md, quickstart.md
```

La **Push Protection native de GitHub** (indépendante de notre pipeline, indépendante de
Gitleaks) a détecté la même valeur — preuve qu'elle était maintenant assez réaliste pour être
prise pour une vraie clé, y compris par un scanner qu'on ne contrôle pas.

**La leçon à double tranchant** : un secret factice doit être réaliste pour tester la détection,
mais alors il ne doit **jamais** être stocké en dur dans un fichier suivi par git — même en
documentation. Solution finale : génération dynamique uniquement, jamais de valeur figée dans
l'historique. Et un excellent exemple de défense en profondeur *déjà vécu*, pas hypothétique :
Push Protection (avant même que le code atteigne le repo) + Gitleaks en CI (portable, marche même
sans GitHub) — deux couches indépendantes, la deuxième existe justement pour les environnements
où la première n'est pas disponible.

### 1.3 Une vraie vulnérabilité Trivy — investiguée avant d'être excusée

**Le fait** : le premier vrai build a échoué le gate Trivy sur deux CVE HIGH, avec correctif
disponible (`setuptools`/`pkg_resources`, `msgpack`) — donc bloquant, par notre propre politique.

**Ce qu'on n'a pas fait** : ajouter une exception `.trivyignore` sans vérifier. Le raisonnement
initial ("ça vient sûrement de l'image de base") était même **faux** dans un premier temps —
vérifié empiriquement (`docker pull` de l'image de base, `pip list`) : l'image de base ne contient
que `pip`, pas `setuptools`.

**L'investigation réelle** : digest exact scanné retrouvé et pullé, `pip show` (paquets introuvables
en tant que tels), puis `find` sur le filesystem de l'image — révèle que les deux composants sont
**vendorisés à l'intérieur de `pip` lui-même** (`pip/_vendor/msgpack`, `pip/_vendor/pkg_resources`),
jamais installés comme paquets séparés, jamais atteignables par l'application.

**Pourquoi c'est le bon exemple pour "limites automatisation vs manuelle"** : une exception de
sécurité n'a de valeur que si elle est **prouvée**, pas supposée. Le jugement humain ici n'a pas
consisté à ignorer l'outil, mais à vérifier ce que l'outil disait avant de décider — avec des
preuves reproductibles, pas une intuition.

---

## 2. Architecture & conventions — les choix (et ce qu'on a rejeté)

### 2.1 Pourquoi pas un `security.yml` séparé

**La tentation** : regrouper Gitleaks, Trivy, ZAP (secrets, image, dynamique) dans un seul
fichier "sécurité" pour plus de lisibilité.

**Pourquoi rejeté** : les trois outils n'ont pas le même moment de vie dans le pipeline — Gitleaks
teste du code source (avant tout build), Trivy teste une image construite (après build), ZAP teste
une instance déployée (après déploiement staging). Les forcer dans un seul fichier déclenché par
trois types d'événements différents casse la convention "un workflow = un déclencheur cohérent",
sans rien simplifier en pratique. La vraie modularité, ici, c'est que chaque outil vit là où sa
donnée d'entrée existe — pas un regroupement artificiel par thème.

### 2.2 Pourquoi pas un job "Security" et un job "Quality" séparés

**La tentation logique** : deux jobs, un par catégorie, plutôt que de mélanger `pytest` (qualité)
avec Bandit/`pip-audit` (sécurité) dans le même job `test`.

**Pourquoi rejeté** : ça aurait cassé une distinction plus importante que la catégorie —
**obligatoire vs conditionnel**. Gitleaks tourne sur *chaque* changement, sans exception
(principe non négociable). Bandit/`pip-audit` n'ont de sens que sur du code applicatif, donc
conditionnels comme les tests. Regrouper par catégorie "sécurité" aurait forcé soit à rendre
Gitleaks skippable (contradiction directe avec sa raison d'être), soit à faire tourner
Bandit/`pip-audit` inutilement sur un changement de documentation. Le découpage retenu reste par
caractère obligatoire/conditionnel, avec "Security" et "Quality" simplement mentionnés dans le nom
du job pour le narratif, sans sacrifier la distinction structurelle.

### 2.3 Pourquoi pas `BREAKING CHANGE:` pour un correctif de sécurité

**La tentation** : en préparant un scénario de démo DAST (ZAP détecte des en-têtes de sécurité
manquants, on corrige), utiliser `BREAKING CHANGE:` pour signaler l'importance du correctif.

**Pourquoi rejeté** : `BREAKING CHANGE` a un sens précis et technique dans Conventional Commits —
le **contrat public de l'API change** d'une façon incompatible pour ses consommateurs. Une
correction de sécurité (ajout d'en-têtes HTTP) ne casse aucun contrat fonctionnel — le bon type
est `fix:` (PATCH). Utiliser `BREAKING CHANGE` pour dire "c'est grave" plutôt que "ça casse la
compatibilité" est un mésusage de la convention — exactement le genre de glissement qu'un public
averti repère, et qui nuirait à la crédibilité du webinaire.

### 2.4 Pourquoi le step de debug OIDC est togglable, pas permanent (ni définitivement supprimé)

**Le dilemme** : après avoir diagnostiqué un vrai échec `AssumeRoleWithWebIdentity` via un step
temporaire de decode du jeton OIDC, fallait-il le supprimer, le garder actif sur staging
uniquement, ou autre chose ?

**Pourquoi ni l'un ni l'autre** : le garder actif en permanence pollue les logs de chaque
déploiement pour une valeur utile 0,1% du temps. Le garder "staging seulement" ne couvre même pas
le bon cas d'usage — un futur problème OIDC pourrait être spécifique à `production`, jamais visible
depuis un step qui ne tourne que sur staging. Solution retenue : un input `workflow_dispatch`
booléen (`debug`, défaut `false`) — disponible à la demande, sur n'importe quel environnement,
sans coût sur le chemin normal.

### 2.5 Choix d'outils SAST/SCA — pourquoi Bandit + `pip-audit`, pas Safety/Snyk

`pip-audit` retenu plutôt que Safety (modèle commercial depuis 2022-2023, accès limité à sa base
en gratuit) ou Snyk (nécessite un compte) — outil officiel PyPA, gratuit, sans credential, cohérent
avec le principe "zéro credential superflu" déjà appliqué à tout le reste du projet (OIDC plutôt
que clés AWS statiques, GHCR public plutôt que registry privé).

**Point technique notable** : `pip-audit` et Trivy ont des angles morts différents et
complémentaires. `pip-audit` aurait détecté une dépendance déclarée vulnérable *avant même le
build* ; il n'aurait probablement *pas* vu les paquets vendorisés dans `pip` (même limite que
`pip show`, cf. §1.3) — c'est Trivy, en scannant le filesystem réel de l'image, qui les a trouvés.
Deux outils, deux méthodes de détection, deux angles morts différents.

---

## 3. Infrastructure & plateforme — les surprises d'environnement réel

### 3.1 Le sandbox Flatpak invisible

**Le symptôme** : `docker: commande introuvable`, alors que Docker fonctionnait ailleurs sur la
même machine.

**La cause** : l'environnement de développement (VSCode) tournait dans un sandbox Flatpak
(confirmé via `$FLATPAK_ID` et `/.flatpak-info`), avec sa propre vue isolée du système de
fichiers — sans accès à Docker ni à son socket, invisibles depuis l'intérieur du sandbox même si
présents sur la vraie machine hôte. Un rappel concret que l'environnement d'exécution d'un outil
n'est pas toujours ce qu'on croit qu'il est — vérifier avant de supposer.

### 3.2 Le format du `sub` claim OIDC avec IDs numériques

**Le symptôme** : `Not authorized to perform sts:AssumeRoleWithWebIdentity`, alors que la trust
policy AWS, l'ARN du rôle, et le nom de l'environment GitHub étaient tous vérifiés corrects, ligne
par ligne.

**La cause, trouvée en décodant le jeton réel plutôt qu'en supposant** : GitHub peut émettre un
`sub` claim sous la forme `repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:ENV` (IDs numériques
immuables, pour que la relation de confiance survive à un renommage d'org/repo) — pas seulement
la forme simple `repo:OWNER/REPO:environment:ENV`. Une trust policy écrite avec seulement la forme
simple rejette silencieusement, sans indice sur la cause réelle au-delà du message générique.

**La leçon méthodologique** : face à un échec "tout est pourtant correct sur le papier", décoder
la preuve réelle (le jeton lui-même) plutôt que de re-vérifier la configuration en boucle.

### 3.3 Le plafond de permissions des workflows réutilisables

**Le symptôme** : `Invalid workflow file ... is only allowed 'deployments: none, id-token: none'`.

**La cause** : un job qui appelle un workflow réutilisable (`uses: ./.github/workflows/deploy.yml`)
voit les permissions qu'il peut accorder **plafonnées par les permissions du job appelant** —
sans `permissions:` explicite sur le job appelant lui-même, le plafond par défaut du workflow
s'applique, indépendamment de ce que le workflow appelé demande. Trois jobs appelants ont dû être
corrigés (deux dans `release.yml`, un dans `rollback.yml`).

### 3.4 La licence payante cachée d'une Action GitHub populaire

**Le symptôme** : anticipé avant même d'échouer en CI — `gitleaks/gitleaks-action` (l'action
officielle "wrapper") exige une licence payante `GITLEAKS_LICENSE` pour tout repo appartenant à
une **organisation** GitHub (gratuit uniquement pour les comptes personnels).

**La correction** : utiliser le binaire `gitleaks` open-source directement (installation
épinglée, vérifiée par checksum), qui est lui-même MIT et sans restriction — l'outil sous-jacent
est libre, seul le wrapper commercial de confort a un modèle payant.

### 3.5 `APP_URL` inversé entre les deux environments

**Le symptôme** : déploiement production techniquement réussi (Docker tourne, SSM confirme), mais
la vérification de santé échoue : `expected 'production', got 'staging'`.

**La cause** : la variable d'environment GitHub `APP_URL` de `production` pointait vers l'IP
Elastic de `staging` — une erreur de configuration humaine ordinaire, mais qui illustre bien
pourquoi le health check vérifie le **contenu** de la réponse (le champ `environment` du JSON),
pas seulement "le serveur a répondu 200".

---

## Synthèse — si le public ne retient qu'une chose

Aucun de ces incidents n'était anticipé dans la conception initiale. Tous ont été trouvés en
construisant et en testant réellement le pipeline, pas en l'imaginant sur le papier. Le point
commun à presque tous : **vérifier la preuve réelle (le jeton décodé, le filesystem de l'image, le
digest exact) plutôt que de faire confiance à une hypothèse plausible** — que l'hypothèse vienne
d'un outil, d'une documentation officielle, ou de nous-mêmes.
