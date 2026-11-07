# My Tutor – Dars | درس

| Folder | What |
|---|---|
| `ANALYSIS.md` | Full teardown of the Modarby reference app + ideas for Dars |
| `my_tutor_app/` | Flutter mobile app + web app |
| `my_tutor_website/` | Next.js marketing website |
| `previews/` | Screenshots of the website |
| `.github/workflows/build.yml` | Cloud build: APK + web app + website, on every push |

## Get the APK and the test links (no installs on your PC)

0. **One-time:** in this folder create the folders `.github\workflows` (File Explorer → New folder `.github`, inside it `workflows`) and **move `build.yml` into `.github\workflows\`**.
   *(Windows Explorer may refuse a name starting with a dot — type it as `.github.` with a dot at the end and it will save as `.github`.)*
1. **GitHub Desktop** → *File → Add local repository…* → choose this folder → click **create a repository** → Name: `dars` → **Create repository**.
2. Click **Publish repository**. Untick **Keep this code private** if you want the website link (free GitHub Pages needs a public repo). The APK works either way.
3. On github.com open the repo → **Settings → Pages → Source: GitHub Actions**.
4. Open the **Actions** tab and wait for the green tick (about 10–15 min the first time).
   If you did step 3 after the build started and the *Publish to GitHub Pages* job failed, press **Re-run all jobs**.
5. On your phone:
   - **APK:** `https://github.com/<your-username>/dars/releases` → download **Dars.apk** → open it → allow *Install unknown apps*.
   - **Website:** `https://<your-username>.github.io/dars/`
   - **Web app:** `https://<your-username>.github.io/dars/app/`

Every later change you push from GitHub Desktop produces a new build automatically.

If a build shows a red ✗, open it, click the failed step, and send the error lines to Claude.
