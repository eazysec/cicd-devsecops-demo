# Roadmap — Déroulé live du webinaire

Ce fichier est la version **détaillée et personnelle** du déroulé live — commandes exactes,
clics précis, minutage. La version condensée et publique reste le [🎤 Conference
Runbook](../README.md#-conference-runbook) du README ; les deux racontent la même séquence, celui-
ci descend juste au niveau "que faire concrètement avec les mains". Si les deux divergent un jour,
le README fait foi pour le *concept* montré à chaque étape, ce fichier pour la *mécanique*.

Ce n'est plus un artefact Spec Kit ni un journal de progression (ce fichier s'appelait `recap.md`
et trackait la mise en place initiale — terminée et validée, voir git history si besoin de ce
détail). Les leçons apprises pendant la construction vivent dans
[`docs/retex-webinar.md`](retex-webinar.md), pas ici.

---

## J-1 (la veille) — checklist de préparation

Ne rien faire de ce qui suit en direct sur scène — tout ça se prépare à froid :

```
[ ] main à jour, tag vX.Y.Z le plus récent identifié, staging/production déployés et sains
    → curl -s $STAGING_URL/health | python3 -m json.tool
    → curl -s $PROD_URL/health | python3 -m json.tool
[ ] fix/security-headers : PR ouverte, verte, prête à merger — jamais mergée avant le live
    → vérifier le statut des checks sur la PR, pas juste "je me souviens qu'elle était verte"
[ ] Working tree propre (git status), aucune branche de démo oubliée d'une répétition précédente
    → git branch -a | grep -E "demo/|fix/broken-test|docs/update-readme"
[ ] ghcr.io/zaproxy/zaproxy:2.17.0 pré-pullé localement (docker pull) — pour l'Emergency Demo Plan
[ ] Gitleaks + Trivy installés localement (voir README § Emergency Demo Plan pour les commandes
    d'install exactes) — au cas où la démo bascule en Plan B
[ ] URLs $STAGING_URL / $PROD_URL bookmarkées dans le navigateur utilisé sur scène
[ ] scripts/demo-local.sh testé une fois dans la journée (bash scripts/demo-local.sh), pour
    confirmer que Docker tourne sur la machine de la conférence, pas juste sur la machine perso
[ ] Onglets pré-ouverts : Actions, Security → Code scanning, Environments, la PR fix/security-
    headers, le terminal sur le repo
```

## Déroulé minute par minute (critical path, ~10-15 min)

Numérotation alignée sur le tableau README § Conference Runbook — s'y référer pour le "concept"
montré à chaque étape ; ici, uniquement la mécanique.

**1. État production actuel** (~30s) — ouvrir `$PROD_URL` dans le navigateur déjà bookmarké.
Montrer version/environment/git_sha/build_time affichés sur la page. Ne rien taper.

**2. PR docs-only** (~2 min)
```bash
git checkout main && git pull
git checkout -b docs/update-readme
echo "<!-- demo $(date +%H:%M) -->" >> README.md
git add -A && git commit -m "docs: tweak readme"
git push -u origin HEAD
```
→ ouvrir la PR sur GitHub, montrer le Job Summary : Secret Scan ✅, Lint ✅, Tests ⏭️ (raison
affichée). Ne pas merger — ou merger si le temps le permet, c'est sans conséquence (docs_only).

**3-4. Test qui casse puis qui passe** (~3 min)
```bash
git checkout main && git checkout -b fix/broken-test
# casser une assertion dans tests/unit/test_version.py
git add -A && git commit -m "test: break an assertion on purpose"
git push -u origin HEAD
```
→ PR, montrer "Quality & Security Gate" ❌, merge bloqué. Puis :
```bash
# corriger l'assertion
git add -A && git commit -m "fix: restore the assertion"
git push
```
→ checks passent, bouton Merge actif. Fermer la PR sans merger (ou merger, sans conséquence).

**5. Faux secret** (~2 min) — voir `SECURITY.md` "Fake-secret demo" pour le pourquoi de chaque
détail (valeur générée à la volée, jamais figée) :
```bash
git checkout main && git checkout -b demo/fake-secret
scripts/generate-demo-secret.sh >> app/scratch_do_not_commit.py
git add -A && git commit -m "chore: trigger fake secret for demo"
git push -u origin HEAD
```
→ le plus probable : le `push` lui-même est rejeté par la **Push Protection GitHub**, avant même
d'atteindre le repo — c'est le résultat le plus spectaculaire, montrez le message de rejet dans le
terminal directement. Si la Push Protection ne bloque pas (config différente), la PR ouverte
montrera "Security Gate: Secret Scanning" ❌ à la place. Nettoyage après coup :
```bash
git push origin --delete demo/fake-secret 2>/dev/null  # si le push a réussi
git checkout main && git branch -D demo/fake-secret
```

**6. DAST trouve de vrais trous** (~1 min) — Actions → dernier run **Deploy** sur `staging` →
artifact `zap-baseline-report`, ou narrer directement les 7 `WARN-NEW` déjà connus (missing CSP,
X-Frame-Options, X-Content-Type-Options, Permissions-Policy, Cross-Origin-Embedder-Policy — voir
`app/security_headers.py` pour la liste complète et les 2 volontairement non corrigés).

**7. Ship le fix — seule étape vraiment tapée en direct : le clic Merge** (~2 min) — la PR
`fix/security-headers` est déjà ouverte et verte (préparée la veille). Sur scène : cliquer
**Merge**. Attendre l'apparition de la PR `chore(main): release ...` (Release Please), cliquer
**Merge** dessus aussi. Narrer pendant que `release.yml` tourne : premier merge = juste la
proposition de version, deuxième merge = build + scan + déploiement staging (ZAP re-scanne
automatiquement, propre sur les 5 findings corrigés).

**8. Approuver la promotion production** (~30s) — Actions → run en cours → "Review deployments" →
Approve.

**9. Nouvelle version en ligne** (~30s) — recharger `$PROD_URL`, comparer avec l'état de l'étape 1.
Montrer le digest identique staging/production dans l'onglet Environments.

## Scénarios bonus, si le temps le permet

**10. Rollback** (optionnel, ~1 min) — Actions → workflow `Rollback` → Run workflow →
`environment: production`. Skip si contraint par le temps ; mentionner que c'est unit-testé même
non démontré live (`tests/unit/test_resolve_previous_digest.py`).

**11. CodeQL trouve ce que Bandit rate** (optionnel, ~3 min) — voir
[`docs/codeql-demo-vulns.md`](codeql-demo-vulns.md) pour la procédure complète et le rappel
sécurité (branche jetable, jamais mergée). Résumé express :
```bash
git checkout main && git checkout -b demo/codeql-ssti
# appliquer le snippet SSTI de docs/codeql-demo-vulns.md à app/routes.py
git add -A && git commit -m "demo: SSTI for the CodeQL-vs-Bandit demo"
git push -u origin HEAD
```
→ Actions → CodeQL → Run workflow → branche `demo/codeql-ssti` → Security → Code scanning
(sélectionner la branche dans le menu déroulant) → montrer l'alerte `py/template-injection`. Pour
le contraste, ouvrir une PR juste pour montrer Bandit vert, **ne pas merger**, fermer la PR, puis :
```bash
git push origin --delete demo/codeql-ssti
git branch -D demo/codeql-ssti
```

## Après le webinaire

```
[ ] Toutes les branches de démo supprimées (locales et origin) — aucune ne doit survivre au live
[ ] fix/security-headers : mergée pendant le live, rien à faire
[ ] Si demo/codeql-ssti a été utilisée : confirmer sa suppression sur origin (pas seulement en
    local) — c'est la seule branche du live à contenir du code réellement exploitable
[ ] Nouvelle version en production confirmée stable (pas de rollback nécessaire après coup)
```
