# Recap — Progress Tracker

Document de suivi personnel, mis à jour au fur et à mesure de votre avancement (configuration
AWS/GitHub, tests des scénarios, répétitions). Ce n'est pas un artefact Spec Kit (ceux-là restent
figés sous `specs/001-cicd-devsecops-demo/`) — c'est le tableau de bord opérationnel de la mise en
prod de la démo elle-même.

Dites-moi simplement ce que vous avez fait/testé et je coche/mets à jour ce fichier en
conséquence.

**Dernière mise à jour** : 2026-09-23. Ce fichier était resté figé au 2026-09-22 (génération
initiale) alors que la configuration AWS/GitHub, plusieurs cycles de release réels, et l'ajout
de CodeQL/ADR 0008 ont eu lieu depuis — sections "Validation", "Configuration manuelle restante"
et "Conference checklist" corrigées ci-dessous pour refléter l'état actuel. Le détail de ce qui
s'est passé entre-temps reste dans le Journal d'avancement plus bas (dernière entrée : plafond de
permissions des workflows réutilisables) — les épisodes plus récents (correction du format `sub`
OIDC, licence `gitleaks-action`, inversion `APP_URL`, intégration Code Scanning, ajout CodeQL) ne
sont pour l'instant tracés que dans l'historique git et la conversation, pas encore reportés ici
entrée par entrée.

---

## Architecture retenue

Spec-Kit workflow complet exécuté dans `specs/001-cicd-devsecops-demo/` : constitution → spec →
plan/research (research.md compte maintenant D1–D11 ; 8 ADR, 0001–0008) → tasks (60 tâches
initiales) → implémentation. Repo `cicd-devsecops-demo` confirmé (remote
`github.com/eazysec/cicd-devsecops-demo`, **organisation** publique).

- **App** : Flask + Gunicorn, `GET /` (page de statut) + `GET /health` (JSON), respecte `PORT`.
- **Pipeline dynamique** : `scripts/classify_change.py` (testé unitairement) classe chaque
  changement (`docs_only` / `application` / `pipeline_infra`) ; les gates obligatoires (secret
  scan, lint) tournent toujours, sans jamais consulter la classification.
- **Sécurité** : Gitleaks (CLI directe, voir Amendements, bloquant sur toute PR), Bandit + pip-audit
  (SAST/SCA, conditionnels comme les tests, dans `pr-validation.yml`), Trivy (bloque seulement
  HIGH/CRITICAL **avec correctif dispo**, SARIF complet aussi envoyé vers Code Scanning), ZAP
  (DAST staging, informationnel), CodeQL (SAST approfondi, découplé du gate PR — push `main` +
  hebdomadaire, voir ADR 0008), toutes les Actions GitHub épinglées par SHA complet.
- **Build once / promote** : un seul job (`release.yml → build-scan-publish`) construit et pousse
  l'image ; le digest est réutilisé tel quel pour staging puis production (`deploy.yml`
  réutilisable).
- **Déploiement** : AWS EC2 (2× `t3.micro`, Docker) piloté via SSM Run Command (pas de SSH), auth
  GitHub OIDC → rôle IAM scopé par environnement.
- **Registry** : GHCR public.
- **Versioning** : Release Please (Conventional Commits → SemVer).
- **Rollback** : automatique si health-check/smoke-test échoue en production, ou manuel via
  `workflow_dispatch` (`rollback.yml`) — jamais de rebuild.
- **Emergency Demo Plan** : `scripts/demo-local.sh`, testé et fonctionnel (s'arrête proprement à
  l'étape Docker faute de démon disponible dans le sandbox de génération).

## Amendements par rapport à la proposition initiale

| Proposition initiale | Ma proposition | Pourquoi | Coût/compromis |
|---|---|---|---|
| Render | **AWS EC2 + SSM** | Demande explicite de l'utilisateur (compte AWS existant) après que j'ai signalé le risque de mise en veille du free tier Render | Setup manuel plus long (OIDC, IAM) — documenté dans `docs/aws-setup.md` |
| (non précisé) semantic-release vs Release Please | **Release Please** | Le "Release PR" est un moment visible et pilotable en direct sur scène ; pas d'écosystème npm pour un projet Python | Version live en retard d'un merge supplémentaire (le merge de la Release PR) |
| `gitleaks/gitleaks-action` (implicite via brief) | **CLI `gitleaks` en direct, épinglée + checksum vérifié** | **Découverte en cours de validation** : l'Action wrapper exige une licence payante pour les repos appartenant à une **organisation** GitHub — `eazysec` en est une. Le CLI open-source sous-jacent est gratuit sans restriction | Un peu plus de YAML, mais gratuit et déterministe |
| Secret factice figé `AKIAFAKEFAKEFAKEFAKE` (premier jet) | **Généré dynamiquement** par `scripts/generate-demo-secret.sh` (jamais stocké dans git) | **Deux découvertes successives, testées** : (1) un placeholder à faible entropie est silencieusement allowlisté par Gitleaks — ne déclenche rien ; (2) même une valeur figée *réaliste* committée en dur dans la doc a été bloquée par la **Push Protection native de GitHub** au tout premier `git push`. Générer la valeur à la volée règle les deux problèmes définitivement | Documenté dans `SECURITY.md` comme piège connu |
| Registry générique | GHCR (confirmé), **public** après 1er push | Gratuit, zéro credential sur les hôtes EC2 | Étape manuelle unique (changer la visibilité du package) |

## Validation

État initial (2026-09-22, sandbox sans Docker) vs. état réel confirmé depuis, en conditions
réelles (poste de l'utilisateur + GitHub Actions + AWS) :

```
Lint (Ruff)         PASS   — confirmé en CI à chaque run
Unit tests          PASS   — confirmé en CI à chaque run
Coverage            PASS
Gitleaks            PASS   — confirmé en conditions réelles : faux secret généré dynamiquement a
                              bloqué à la fois Push Protection GitHub et le job Gitleaks (voir
                              docs/retex-webinar.md §1.1/§1.2)
Docker build        PASS   — confirmé hors sandbox (terminal natif, Docker installé sur la machine)
Container run       PASS   — idem
Health check        PASS   — confirmé via conteneur réel + déploiements staging/production réels
Smoke tests         PASS   — idem
Trivy                PASS   — scan d'image réel confirmé ; un cas réel de CVE HIGH sur du code
                              vendorisé dans pip a été investigué et documenté (.trivyignore,
                              docs/retex-webinar.md §1.3) ; SARIF complet confirmé visible dans
                              GitHub Code Scanning
GitHub Actions       PASS   — 5 workflows (pr-validation, release, deploy, rollback, codeql),
                              actionlint + exécutions réelles multiples confirmées
Staging              PASS   — plusieurs cycles de déploiement réels confirmés (au moins jusqu'à
                              la release 1.3.0), ZAP DAST confirmé fonctionnel contre cette instance
Production           PASS   — au moins une promotion staging → production réelle confirmée,
                              approbation manuelle (required reviewer) exercée
Rollback              PASS (logique unit-testée) ; bout-en-bout en conditions réelles : à
                              reconfirmer avec l'utilisateur, pas explicitement rejoué depuis
CodeQL                NOT VERIFIED — workflow ajouté le 2026-09-23 (`feat/codeql-integration`,
                              pas encore mergé), pas encore exécuté en conditions réelles
```

*(Mettre à jour au fur et à mesure : dites-moi ce que vous testez/observez et je corrige ces
lignes en conséquence — en particulier pour confirmer/infirmer le statut Rollback ci-dessus.)*

## Configuration manuelle restante

- [x] **GitHub** : `docs/branch-protection.md` appliqué et confirmé — PR bloquées puis mergées
      avec succès à plusieurs reprises, noms de checks vérifiés cohérents (y compris après le
      renommage du job de test pour Bandit/pip-audit)
- [x] **GitHub** : Environments `staging`/`production` créés avec leurs variables
      (`docs/github-environments-setup.md`) — confirmé, déploiements réels réussis sur les deux
- [x] **GitHub** : approbateur requis configuré sur `production` — confirmé, flux "Review
      deployments" exercé en conditions réelles
- [x] **GitHub** : package GHCR public — confirmé, `docker pull` réel réussi depuis l'extérieur
- [x] **AWS** : provisionner les 2 EC2 (`docs/aws-setup.md`) — confirmé, `docker --version` testé OK
- [x] **AWS** : provider OIDC créé — confirmé fonctionnel (après correction du format `sub` claim,
      voir docs/retex-webinar.md §3.2)
- [x] **AWS** : les 2 rôles IAM scopés créés (staging, production) — confirmés fonctionnels

## Secrets et variables (noms uniquement)

| Nom | Type | Portée | Configuré ? |
|---|---|---|---|
| `GITHUB_TOKEN` | ambiant | tous les jobs | n/a (automatique) |
| `AWS_ROLE_ARN` | variable d'environnement | `staging`, `production` | [x] confirmé fonctionnel |
| `AWS_REGION` | variable d'environnement | `staging`, `production` | [x] confirmé fonctionnel |
| `EC2_INSTANCE_ID` | variable d'environnement | `staging`, `production` | [x] confirmé fonctionnel |
| `APP_URL` | variable d'environnement | `staging`, `production` | [x] confirmé fonctionnel — une inversion staging/production a été trouvée et corrigée (docs/retex-webinar.md §3.5) |

Aucune clé AWS statique nulle part (OIDC uniquement), aucun credential registry sur les hôtes
(GHCR public).

## Conference checklist

```
[x] Repository cicd-devsecops-demo prêt (code, tests, workflows, docs)
[x] Branch protection / ruleset configuré           → docs/branch-protection.md
[x] Checks obligatoires configurés                  → idem
[x] GitHub Environments configurés                  → docs/github-environments-setup.md
[x] Registry configuré (GHCR, public, pull réel confirmé)
[x] Staging configuré                               → docs/aws-setup.md
[x] Production configurée                           → idem
[x] Secrets configurés
[x] v1.0.0+ déployée (releases réelles au-delà de 1.0.0 confirmées, jusqu'à ~1.3.0)
[ ] PR failure testée (Scénario B) — pas explicitement confirmé comme répétition dédiée
[x] Gitleaks failure testé avec faux secret — confirmé en conditions réelles (Push Protection +
    Gitleaks CI, pas seulement en local)
[ ] Documentation-only skip testé en conditions réelles GitHub — à confirmer
[x] Release testée (plusieurs cycles réels au-delà de 1.0.1)
[x] Promotion staging → production testée — confirmée en conditions réelles
[x] Digest identique staging / production — mécaniquement garanti par l'architecture build-once
    (même digest passé aux deux appels de deploy.yml), non re-vérifié manuellement outil en main
[ ] Rollback testé (bout-en-bout ; logique déjà unit-testée) — à reconfirmer avec l'utilisateur
[x] Plan B local testé (scripts/demo-local.sh, confirmé fonctionnel hors sandbox)
[ ] CodeQL testé en conditions réelles — workflow ajouté 2026-09-23, PR pas encore mergée
[ ] `fix/security-headers` : PR prête pour la démo live — préparée, doit rester **non mergée**
    jusqu'à la conférence (technique "flawless demo")
```

## Commandes de conférence (dans l'ordre)

```bash
# Avant la conférence (une fois l'infra AWS/GitHub en place)
git log --oneline -5 && curl -s $PROD_URL/health   # état "avant"

# Étape 2 — docs-only
git checkout -b docs/update-readme
echo "..." >> README.md && git add -A && git commit -m "docs: tweak readme" && git push -u origin HEAD
# → ouvrir la PR, montrer le Job Summary

# Étape 3-4 — test qui casse puis qui passe
git checkout -b fix/broken-test
# casser tests/unit/test_version.py, push, PR, puis corriger, push

# Étape 5 — faux secret (généré à la volée, voir quickstart.md §2)
git checkout -b demo/fake-secret
scripts/generate-demo-secret.sh >> app/scratch_do_not_commit.py
git add -A && git commit -m "chore: trigger fake secret for demo" && git push -u origin HEAD
# → si la Push Protection GitHub bloque déjà le push ici, c'est le scénario "encore mieux" :
#   montrez ça en premier (bloqué avant même d'atteindre le repo), Gitleaks dans le pipeline
#   étant la double protection (portable, marche même hors GitHub)

# Étape 6-8 — vrai fix → release → production
git checkout main && git checkout -b fix/health-endpoint
# vrai petit fix, PR, merge → merger la Release PR de Release Please → approuver le déploiement prod

# Étape 9 (optionnelle) — rollback
# Actions → Rollback workflow → Run workflow → environment: production
```

---

## Journal d'avancement

*(J'ajoute une ligne ici à chaque fois que vous me rapportez une étape franchie.)*

- **2026-09-22** — Génération initiale du projet via Spec Kit (spec → plan → tasks →
  implémentation) + validation locale complète (lint, tests, gitleaks, shellcheck, actionlint).
  Rien n'est encore committé dans git, ni configuré côté AWS/GitHub.
- **2026-09-22** — Phase 0 en cours côté utilisateur. Deux découvertes en testant en conditions
  réelles (hors sandbox) :
  1. **Environnement** : la session de génération tournait dans le sandbox Flatpak de VSCode
     (`FLATPAK_ID=com.visualstudio.code`), sans accès à Docker — d'où le "NOT VERIFIED" initial
     sur build/run/health/smoke. Pas un bug du projet ; contournement = lancer les commandes
     Docker depuis un terminal système normal (Option A retenue).
  2. **Vrai bug corrigé** : `docker build` + `docker run` réussissaient, mais gunicorn plantait
     au boot (`APP_VERSION='0.0.0-local' does not match SemVer MAJOR.MINOR.PATCH`). Le regex de
     validation SemVer dans `app/version.py` était trop strict (rejetait les suffixes de
     pré-release), alors que les valeurs par défaut locales (`0.0.0-dev`, `0.0.0-local`) en
     utilisent un — contradiction interne. Corrigé : regex élargi au format SemVer 2.0.0 complet,
     dans `app/version.py`, `scripts/smoke-test.sh`, `tests/integration/test_endpoints.py`, +
     6 nouveaux tests de non-régression (34/34 tests passent). Contrat mis à jour dans
     `specs/001-cicd-devsecops-demo/contracts/app-endpoints.md` et `data-model.md`.
  3. **Amélioration** : `scripts/demo-local.sh` supprimait le conteneur (`trap cleanup EXIT`)
     avant que l'échec puisse être diagnostiqué. Le script affiche maintenant `docker logs`
     automatiquement avant nettoyage en cas d'échec.
  4. **Vrai bug corrigé (2)** : même après le fix ci-dessus, les 8 étapes passaient ("ALL STAGES
     PASSED") mais le navigateur ne pouvait pas se connecter — le même `trap cleanup EXIT`
     supprimait le conteneur **même en cas de succès**, juste après avoir affiché "App is running
     at...". Corrigé : le nettoyage automatique ne se déclenche plus que sur échec (`fail()`) ou
     interruption (Ctrl+C) ; en cas de succès le conteneur reste volontairement démarré, avec un
     rappel de la commande pour l'arrêter (`docker rm -f cicd-devsecops-demo-local`).
- **2026-09-22** — Premier `git push` refusé par la **Push Protection native de GitHub** (secret
  scanning côté serveur, indépendant de Gitleaks) : le faux secret figé (clé AWS factice + son
  secret pairé) dans `quickstart.md` et `docs/recap.md` a été détecté comme une vraie clé
  AWS — preuve qu'il était assez réaliste pour le job Gitleaks du pipeline, mais ça bloquait aussi
  la doc elle-même. Correction structurelle : plus aucune valeur figée ressemblant à un secret
  dans un fichier suivi par git. Nouveau script `scripts/generate-demo-secret.sh` qui génère une
  paire de clés factices aléatoire à la volée (jamais committée telle quelle) ; `.gitleaks.toml`,
  `quickstart.md`, `SECURITY.md`, `README.md` mis à jour en conséquence. Comme le commit initial
  n'avait jamais été accepté par GitHub (push refusé), il a été **amendé** (pas de nouveau commit
  par-dessus) pour que le secret disparaisse aussi de l'historique local — vérifié avec
  `gitleaks detect` sur tout l'historique + `git log -p --all | grep` : aucune trace. Nouveau SHA
  de commit : `df46b05` (remplace `4e5d50b`, jamais publié). Bonus pédagogique identifié : la
  Push Protection GitHub et Gitleaks-en-CI forment une défense en profondeur à deux niveaux —
  documenté dans `SECURITY.md`.
- **2026-09-22** — `df46b05` poussé et accepté par GitHub (après ajout du scope `workflow` sur le
  PAT). Phases 0-3 terminées côté utilisateur (AWS : 2 instances EC2 + 2 rôles IAM OIDC + rôle
  SSM partagé, tous vérifiés via `docker --version` en Run Command). Phase 4 (GitHub Environments)
  en cours. Branche `test/trigger-checks` créée pour faire tourner `pr-validation.yml` au moins
  une fois (nécessaire pour que les noms de check apparaissent dans la recherche de Settings →
  Branches — confirmé : le `push` seul suffit à déclencher le workflow, pas besoin d'ouvrir la PR).
- **2026-09-22** — **Vrai bug corrigé (3)** : le workflow `Release` échoue au tout premier run
  avec `Invalid workflow file ... is only allowed 'deployments: none, id-token: none'`. Cause :
  un workflow réutilisable (`uses: ./.github/workflows/deploy.yml`) voit ses permissions
  plafonnées par celles du **job appelant** — `deploy-staging`/`deploy-production` dans
  `release.yml`, et `deploy` dans `rollback.yml`, n'avaient pas de bloc `permissions:` explicite,
  donc héritaient du plafond par défaut du workflow (`contents: read` seul) au lieu de
  `id-token: write` + `deployments: write` dont `deploy.yml` a besoin. Corrigé dans les trois jobs
  appelants. Trouvé une deuxième fois le secret factice figé en toutes lettres, cette fois dans le
  texte du journal lui-même (en racontant l'incident précédent) — reformulé sans répéter la
  valeur littérale ; leçon retenue : ne jamais recopier la valeur, même en la décrivant.
