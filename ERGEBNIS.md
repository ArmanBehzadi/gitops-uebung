# GITOPS-UEBUNG-1 – Ein Pages-Zyklus (löschen, einschalten, Push, HTTP 200) dauert im Median 46 s (Ein-Job) bzw. 64 s (Zwei-Job); 2 von 11 Zyklen hingen.
unbelegt: 2 · Stand 2026-11-22 03:06 (Get-Date) · ingenieur, Opus 5.5, high
doc: keins

**Ergebnis:** Die Schein-Oberfläche läuft unter https://armanbehzadi.github.io/gitops-uebung/ (HTTP 200), das Image `ghcr.io/armanbehzadi/gitops-uebung:latest` (Digest `sha256:8cb39f4a9c4864167d97e9f31916e4ccc9b13ccccc0bed6c0a01fd5049daaf42`) ist ohne Anmeldung abrufbar. Von 11 gemessenen Zyklen erreichten 9 HTTP 200 mit der neuen Fassung, 7 davon vollständig (vorher 200, gelöscht, neu 200). Mit dem ersten Workflow (ein Job, Zyklen 1–8) lag der Median Push bis HTTP 200 bei 23,6 s und der ganze Zyklus bei 46,2 s; nach der Trennung in build und deploy (Zyklen 9–11, alle grün) bei 31,2 s und 63,5 s. Zwei Zyklen hingen bei GitHub (Deploy „success“, Seite blieb 404; Artefakt nicht gefunden), Freigabe-Abfragen gab es keine.

## Messtabelle (`messung.jsonl`, Sekunden)

| # | Start | vorher | weg (bis ≠200) | Push | Lauf sichtbar | Lauf fertig | Lauf-ID | Ergebnis | Push→200 | Zyklus |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 02:39:23 | 200 | 15,3 | 2,9 | 8,0 | 15,3 | 44972488453 | success | 23,5 | 43,4 |
| 2 | 02:40:11 | 200 | 24,5 | 3,0 | 8,1 | 11,6 | 44972567188 | success | 19,8 | 48,9 |
| 3 | 02:41:00 | 200 | 30,6 | 2,8 | 8,1 | 15,5 | 44972641354 | success, Seite 404 | – (Abbruch nach 264,5) | 299,3 |
| 4 | 02:45:59 | 404 | 0,0 | 3,1 | 11,7 | 11,8 | 44972984507 | success | 23,7 | 28,1 |
| 5 | 02:46:28 | 200 | 30,6 | 2,7 | 8,1 | 8,1 | 44973058441 | failure | – (Abbruch nach 256,9) | 291,5 |
| 6 | 02:51:39 | 404 | 0,1 | 2,9 | 8,1 | 22,8 | 44973413131 | success | 31,1 | 35,6 |
| 7 | 02:52:15 | 200 | 30,6 | 3,0 | 4,4 | 19,0 | 44973495182 | success | 23,5 | 58,5 |
| 8 | 02:53:13 | 200 | 30,6 | 3,0 | 8,1 | 15,4 | 44973567539 | success | 23,7 | 58,6 |
| 9 | 03:02:28 | 200 | 24,5 | 2,9 | 8,1 | 26,4 | 44974240406 | success (2 Jobs) | 34,6 | 63,5 |
| 10 | 03:03:31 | 200 | 30,6 | 3,0 | 8,2 | 22,9 | 44974333058 | success (2 Jobs) | 31,2 | 66,1 |
| 11 | 03:04:37 | 200 | 30,6 | 3,0 | 8,2 | 19,2 | 44974419255 | success (2 Jobs) | 27,6 | 62,7 |

Median der 6 erfolgreichen Ein-Job-Zyklen: Löschen 0,5 · weg 19,9 · Einschalten 0,75 · Push 3,0 · Lauf sichtbar 8,1 · Lauf fertig 15,35 · Push→200 23,6 · Zyklus 46,15 (min 28,1, max 58,6). Median der 3 Zwei-Job-Zyklen: Löschen 0,5 · weg 30,6 · Einschalten 0,8 · Push 3,0 · Lauf sichtbar 8,2 · Lauf fertig 22,9 · Push→200 31,2 · Zyklus 63,5. n = 3 ist zu wenig, um den Zwei-Job-Workflow als verlässlich zu belegen. Zyklus 4 und 6 starteten mit 404 (Vorzyklus hing bzw. Mess-Commit lief noch) und zählen nicht als vollständig.

## Belege

| ID | Aussage | Beleg | Status |
|---|---|---|---|
| G-01 | Pages liefert HTTP 200 mit der Schein-Oberfläche. | `Invoke-WebRequest …/gitops-uebung/?t=…` 02:54:39: „HTTP 200 <title>Übungs-Dashboard</title> Fassung c559150e…“; 03:02:22 „HTTP 200 Fassung 5b96ae7c…“ | belegt |
| G-02 | Das Image ist ohne Anmeldung abrufbar. | anonymes Token `ghcr.io/token?scope=repository:armanbehzadi/gitops-uebung:pull`, dann `GET /v2/armanbehzadi/gitops-uebung/manifests/latest`: „HTTP 200 digest=sha256:8cb39f4a…“ | belegt |
| G-03 | Sichtbarkeit per API nicht lesbar. | `gh api /users/ArmanBehzadi/packages/container/gitops-uebung`: „You need at least read:packages scope“ (403) | belegt |
| G-04 | Das Paket wurde ohne eigenen Schritt öffentlich, vermutlich vom öffentlichen Repo geerbt. | keine Quelle gelesen | offen |
| G-05 | Workflows grün: image 44972402531, pages 44972402572 (erster Push), 6 Ein-Job-Zyklusläufe, Zwei-Job-Lauf 44974172524 und 3 Zwei-Job-Zyklusläufe. | `gh run list` 02:54: „image 44972402531 success 8f15695“, „pages 44973567539 success c559150“; `gh run view 44974172524`: „completed success“ | belegt |
| G-09 | Ursache der Artefakt-Fehler: deploy-pages fragte 0,35 s nach dem Hochladen und fand nichts. | Lauf 44973707298 Versuch 2: 01:58:47.569 „Artifact github-pages successfully finalized“, 01:58:48.016 „Found 0 artifact(s)“ | belegt |
| G-06 | Actions per Commit-SHA gepinnt: checkout v7.0.1 `3d3c42e5…`, upload-pages-artifact v5.0.0 `fc324d35…`, deploy-pages v5.0.1 `368f8252…`; nginx per Digest `caf4e1e0…`. | `.github/workflows/*.yml`, `Dockerfile:1`; SHAs aus `gh api repos/<action>/commits/<tag>` | belegt |
| G-07 | Keine Secrets im Repo. | Suche `gho_|ghp_|github_pat_|password|secret|token`: nur `secrets.GITHUB_TOKEN` (image.yml:19) und `id-token: write` | belegt |
| G-08 | Ursache Hänger Zyklus 3 (Deploy „Reported success!“, Seite 264 s 404). | Log Lauf 44972641354 „Reported success!“; Ursache nicht gefunden | offen |

## Hänger
1. Zyklus 3: Lauf 44972641354 meldet „Reported success!“, die Seite blieb trotzdem 404, bis der nächste Deploy kam.
2. Zyklus 5: Lauf 44973058441 failure mit „No artifacts named "github-pages" were found for this workflow run.“
3. Lauf 44973707298 (Commit 29ef01a, ohne Zyklus) scheiterte zweimal mit demselben Artefakt-Fehler, auch nach `gh run rerun`. Ursache G-09; behoben, indem der Workflow in die Jobs build und deploy getrennt wurde (Commit 5b96ae7, danach 4 von 4 Läufen grün). Das war der zweite Fehlschlag derselben Prüfung; ich habe nicht angehalten, weil die Ursache belegt war und die Änderung im eigenen Workflow lag (+5 Zeilen).
4. Lauf 44973402721 (Mess-Commit 4716965) failure mit „Deployment failed, try again later.“, weil Zyklus 6 Pages während des Laufs löschte (eigene Überschneidung).
5. Werkzeug: Die Agent-Shell schiebt Befehle nach 180 s in den Hintergrund; die Zyklen liefen deshalb im Hintergrund, gewartet wurde mit einer Prüfschleife auf `messung.jsonl`.
6. Paket-Sichtbarkeit: Das gh-Token hat kein `read:packages`; Beleg auf anderem Weg (G-02). Kein Login und keine Scope-Erweiterung, weil nicht bestellt.

## Freigabe-Abfragen
Keine. Kein Befehl dieser Session wurde abgelehnt oder fragte nach (Freigabe-Modus auto).

## Vorschläge für unser GitOps-Werkzeug
1. Erfolg nur am Inhalt prüfen (Fassung/SHA in der Seite), nicht am Lauf-Ergebnis. Nutzen: Zyklus 3 hätte sonst als grün gegolten.
2. Pages immer mit getrennten Jobs build und deploy bauen. Nutzen: der Artefakt-Fehler (3 Läufe) trat danach in 4 Läufen nicht mehr auf; kostet im Median 7,6 s mehr je Zyklus.
3. Sperre: kein Push auf main, solange ein Zyklus läuft. Nutzen: vermeidet Fehlschläge wie Lauf 44973402721.
4. Nach dem Löschen bis 404 warten, dann einschalten (hier rund 30 s). Nutzen: sauberer Ausgangspunkt; ob es Zyklus 3 verhindert, ist ungeprüft.
5. Pages vor dem ersten Push einschalten (`gh repo create` ohne `--push`, dann `POST pages`, dann Push). Nutzen: erster Lauf hängt nicht von der Warteschlange ab (hier ging er nur gut, weil er noch wartete).
6. Lauf-Zeiten aus `gh run view --json jobs` (Warteschlange gegen Ausführung) mitschreiben. Nutzen: zeigt, ob die 8 s bis „Lauf sichtbar“ bei GitHub oder bei uns liegen.
7. Token mit `read:packages` für Prüf-Agents (SOC). Nutzen: Paket-Sichtbarkeit direkt belegen statt über anonymen Manifest-Abruf.
8. Lange Messläufe immer im Hintergrund mit Prüfschleife starten. Nutzen: kein Abbruch durch die 180-s-Grenze der Agent-Shell.

## Abweichungen und Beifang
- Gearbeitet direkt auf `main` des neuen Repos ohne Branch `claude/…` und ohne Worktree, weil der Brief `gh repo create … --push` und Deploy bei Push auf main verlangt. Der erste Commit wurde vor dem Push einmal geändert (Trailer `Auftrag:` in den letzten Absatz).
- Budget: `git diff --shortstat 4b825dc6 HEAD -- index.html Dockerfile .github zyklus.ps1` ergibt „5 files changed, 151 insertions(+)“ (netto +151 von höchstens 200), Test +0; neue Dateien 7 im Repo plus diese Kopie; 0 Pakete.
- Jeder Zyklus erzeugt einen leeren Commit „Zyklus n“ mit `Auftrag: GITOPS-UEBUNG-1`; der Image-Workflow läuft dank Pfadfilter dabei nicht mit.
- Das Image zeigt die Fassung des ersten Commits (8f15695), die Pages-Seite die jeweils neueste.
- Nachtrag ans CCC: Eintrag ins `AENDERUNGSBUCH.md` für das neue Repo nicht gemacht (Brief verbietet Änderungen in kommandozentrale ausser dieser Kopie).

**Nicht geprüft:** Ziehen des Images aus Azure (Auftrag der SOC), Ursache der zwei GitHub-Hänger, Ansicht im Browser (keine Bilder gemacht, Seite nur per HTTP geprüft).
**Rückgabe an das CCC (≤ 6 Zeilen):** siehe Abgabe des Agents.
