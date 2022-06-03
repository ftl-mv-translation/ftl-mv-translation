## The drill for repo edits on `locale/` directory.

This doc is for the administrators of Weblate and this repository. Following these steps will ensure there's no errors
on Weblate when you're pushing changes from the repository. Some might seem overkill, but given the experience
I can confindently say they are nonetheless necessity.

Exceptions:
* If the changes don't involve `locale/` directory at all, you may freely push or merge PRs without problem.
  Weblate doesn't really care for them as long as it can rebase its local repo.
* If you're not editing but creating only new files in `locale/`, it also doesn't matter because Weblate may pick
  those changes without risk of simultaneous edits or conflicts.
  
---

0. Announce the site being locked beforehand in Discord.
1. Go to the [Repository maintenance](https://weblate.hyperq.be/projects/ftl-multiverse/#repository) of the project.
2. Click "Lock" to prevent further edits.
   > ### Why?
   > Weblate is quite bad in merging the changes. There was a case in one of the relatively small edits where a file
   > was corrupted (desynced from English) by Weblate because it tried to merge simultaneous edits from the site
   > and the repository.
3. Click "Maintenance" -> "Force synchronization" to commit the changes to Weblate's local repository.
   > #### Why?
   > The "Commit" button is not enough for this purpose. One of the issues in applying #23 was a merge conflict from
   > .po file headers, remaining in Weblate's internal memory but not in a pushed repo.
   > The Commit button did not push all the changes, but the Force synchronization button did.
4. Click "Push" to push the changes to this GitHub repo. Now the repo contains up-to-date translation.
5. Pull them into your local repo and make changes.
6. Push the changes to the repo.
7. Go to the [Repository maintenance](https://weblate.hyperq.be/projects/ftl-multiverse/#repository) menu again.
   **DO NOT UNLOCK** the repository yet.
8. **IMPORTANT**: If your changes involve addition, deletion or renaming ID of entries, click "Maintenance" -> "Reset".
   That will make sure of Weblate to sync with the changes.
   * Do not worry about things like Needs editing, suggestions and comments as they are be preserved even with Reset.
   > ### Why?
   > #23 had a major problem for this. Weblate refused to chew ID changes of a handful number of components
   > for no apparent reasons, desyncing itself from what's actually in the .po files. Reset forces it to reparse
   > every .po files so it ensures that such problem never happens. So unless you're going check every changed files,
   > just press Reset for safety. That will take more time but it's completely worth doing so.
9. Wait for Weblate to chew the changes.
   * It usually takes 15 minutes to process if you've hit Reset button. Otherwise it takes much less time depending on
     how many files you've changed.
   * To see if Weblate has done its job, see [History](https://weblate.hyperq.be/projects/ftl-multiverse/#history) page.
     If the latest activity was about a minute ago, it's safe to assume that the process is over.
   > ### Why?
   > If you press Reset and prematurely unlock the project, while it doesn't "desync" the content or repo, new edits happening
   > meanwhile don't persist after reparse, leading to loss of translation if any.
10. Hit "Unlock", finally. Announce that the job is done.
