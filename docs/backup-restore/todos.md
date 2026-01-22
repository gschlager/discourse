Restoring backups still requires too many manual interventions when something unexpected happens. [This][1], [this][2] and [this][3] are just some recent examples of lengthy debugging sessions and I'm sure our TAs fix many smaller problems without my knowledge.

It's time to pick this task up again and get it over the finishing line. :checkered_flag:

But before I start implementing, I'd like to spec everything out and gather some feedback. I'd especially like to hear from @tshenry, @fzngagan, @markdoerr and everyone else who's encountered errors while restoring backups. Did I forget something in the spec below? Is there anything else that would make dealing with backups easier? Also, please feel free to make suggestions if you'd like to prioritize or solve something differently.

---

### :building_construction: Development workflow
This is a large task -- it's unfeasable to implement everything at once. And why wait for a cool new feature if you can start using it right now?

So, all incremental improvements should be implemented without the need of touching existing backup/restore code. The new CLI should (temporarily?) be available as `script/disco`. 🪩

---

### Streamlined CLI output ![priority medium|105x20](upload://3BcyOFXHQsIG8sqXQ575GcqPCRN.svg)

Say goodbye to thousands of lines of uninteresting output during backup and restore. Let's switch to a CLI that is made for humans.

![image|690x170](upload://zUt2ypvA8aUMKhBkBxjbX68sRpR.jpeg)

* Outputs details if an unhandled error occurs.
* The CLI should detect when it runs in a non-interactive TTY and act accordingly.
* Full log should be saved to a file.

>💡Most of it is already implemented in an old branch of mine.

### Gracefully handle database errors during restore ![priority high|84x20](upload://gCYARlyyMCnNovY9cwiZ3Uer3nI.svg)

The restore process should pause when it encounters an error during database restore. It should have the option to skip or retry the failed SQL. Skipping should only be available for unknown error types and not for errors like "could not create unique index" because that would lead to an incomplete schema.

> ```
> Database restore has been paused!
> 
>   ERROR:  could not create unique index "index_incoming_referers_on_path_and_incoming_domain_id"
>   DETAIL:  Key (path, incoming_domain_id)=(/web-design, 1814) is duplicated.
> 
> Retry? (Y/n)
> ```
> --- <small>CLI example</small>

This could be implemented by reading the database dump line by line and sending it via stdin to `psql`. That would also allow us to replace the [current usage of `sed`](https://github.com/discourse/discourse/blob/067c4deb4c34ad5100e51e91bf0668d125de7908/lib/backup_restore/database_restorer.rb#L95-L110), might be an opportunity to handle missing functions from the `discourse_functions` differently and could even improve performance since we could stream the gzipped database dump without needing to decompress it to disk.

###  Optional autocorrect for "could not create unique index" error ![priority low|79x20](upload://r2KfmsHUzkNQlz2lUIZrc8Wl3mV.svg)

There's only a handful of indexes that usually are causing problems during restore and the solution is always the same. But instead of fixing those problems manually, we could implement an autocorrect feature that fixes the offending rows (e.g. by deleting or merging) before resuming the database restore.

> ```
> Database restore has been paused!
> 
>   ERROR:  could not create unique index "index_incoming_referers_on_path_and_incoming_domain_id"
>   DETAIL:  Key (path, incoming_domain_id)=(/web-design, 1814) is duplicated.
> 
> Select an action (Press ↑/↓ arrow to move and Enter to select)
> ‣ Autocorrect (deletes duplicates)
>   Retry
>   Abort
> ```
> --- <small>CLI example</small>

### Allow restore on version mismatch ![priority medium|105x20](upload://3BcyOFXHQsIG8sqXQ575GcqPCRN.svg)

Sometimes backups fail with a "You're trying to restore a more recent version of the schema" error even though you are trying to restore on "latest". This happens because backups do not distinguish between core and plugin "versions" -- they simply get the version number from the most recent database migration.

This needs to be fixed in the `Backuper`, but there also should be a `--force` flag in order to restore a backup even if there's a problem with the version.

### Restoring uploads shouldn't fail ![priority high|84x20](upload://gCYARlyyMCnNovY9cwiZ3Uer3nI.svg)

Restoring uploads should never fail. Instead the restore process should show a warning if it failed to restore all uploads.

> ```
> Failed to restore some uploads!
> ===================================
> Upload records in database: 239,621
> Uploads in backup archive:   48,793
> Uploads downloaded:         171,412
> Missing uploads:             19,416
> ```
> --- <small>CLI example</small>

### Restore database without uploads ![priority high|84x20](upload://gCYARlyyMCnNovY9cwiZ3Uer3nI.svg)

There should be a `--no-uploads` flag to skip restoring uploads.

### Restore database without remapping uploads ![priority high|84x20](upload://gCYARlyyMCnNovY9cwiZ3Uer3nI.svg)

There should be a `--no-remap` flag to skip remapping uploads during restore. This would allow us to restore a backup and manually remap to get everything working.

### Download missing uploads ![priority medium|105x20](upload://3BcyOFXHQsIG8sqXQ575GcqPCRN.svg)

The restore process should try to download uploads that are missing from the backup archive.
1. Try to download from the upload `url`
2. Try to download from the upload `origin`
3. If secure media is enabled and the S3 bucket and access token are available as site settings, try to download from S3
4. Give up and mark as missing upload

There should be a `--no-download` flag to disable this behavior.

### Improve remapping of upload URLs ![priority medium|105x20](upload://3BcyOFXHQsIG8sqXQ575GcqPCRN.svg)

Remapping of uploads currently only works for local uploads or uploads stored on a single S3 bucket. In addition to that it should also support
* uploads stored in multiple locations (e.g. multiple S3 buckets)
* uploads stored on unsupported storage (e.g. Azure)

### Restore shouldn't fail when `migrate_to_new_scheme` failed ![priority low|79x20](upload://r2KfmsHUzkNQlz2lUIZrc8Wl3mV.svg)

This error is quite uncommon these days, but the restore process should continue when it detects uploads that haven't been migrated to the "new scheme" and it fails to migrate those uploads. Instead if should print a warning and the user to manually fix the uploads.

### Introduce new backup archive format ![priority low|79x20](upload://r2KfmsHUzkNQlz2lUIZrc8Wl3mV.svg)

I'd really like to ship a new backup archive format in the next version of Discourse. I have already worked a lot on it in 2021, but we never shipped it, because priorities shifted and the `Restorer` part hasn't been never implemented yet.

Anyway, here's the gist of the proposed format:

* Avoids double compression of database dump
* Minimizes disk space usage during backup creation by using [mini_tarball](https://github.com/discourse/mini_tarball) to stream everything into a tar archive
* Moves metadata (version) into a `meta.json` file inside of the archive. That has multiple benefits:
  * Renaming the archive won't cause any problems
  * There's room for a lot of metadata and we could add additional data over time if it's necessary
  * In theory, we could store the metadata file at the beginning of the archive and we could read that file by downloading just the first Kilobyte of the archive. I can't think of a real use case at the moment, but it might come in handy...

[details="Current format (v1)"]
#### Current format with uploads

```
discourse-2022-08-17-143232-v20220811170600.tar.gz
├── dump.sql.gz
└── uploads
    └── default
        └── original
            └── 1X
                ├── 90a59a0a7191a750d294c77374e7f56353678e14.png
                └── a00695665e457baec7c7e82df9da1d3bedca355d.png
```

#### Current format without uploads

```
discourse-2022-08-17-143232-v20220811170600.sql.gz
```
[/details]

[details="New format (v2)"]
#### New format with uploads

```
discourse-2022-08-22-141846.tar
├── meta.json
├── dump.sql.gz
└── uploads.tar.gz
```

#### New format without uploads

```
discourse-2022-08-22-141846.tar
├── meta.json
└── dump.sql.gz
```

#### Data stored in new `meta.json`
* Information about core
  * Git version and branch
  * DB migration version
* List of plugins with
  * Git version and branch 
  * DB migration version
* Values of settings that are needed during restore (some of them are currently stored in the `BackupMetadata` during backup)
  * base_url, cdn_url, s3_base_url, s3_cdn_url
  * db_name
  * multisite
* Information about uploads (which would allow us to show information about the backup _before_ we extract and restore the database)
  * total number of uploads, number of uploads included in the backup
  * total number of optimized images, number of optimized images included in the backup
[/details]


[1]: https://dev.discourse.org/t/backup-restore-to-our-hosting-failing-at-migrate-to-s3-step/58960/4?u=gerhard
[2]: https://dev.discourse.org/t/gears-of-war-uploads-causing-backup-restore-issue/66258/6?u=gerhard
[3]: https://meta.discourse.org/t/update-on-provisioning-of-new-anker-sites/231301/24?u=gerhard

---

It's time for a progress report: Before and after Copenhagen I worked on getting the code from my 1.5 year old branch working again. I also integrated some of the changes and bugfixes from the current backup code into the new code and added more specs.

#### Summary of the current changes in the [new-backup-restore](https://github.com/discourse/discourse/compare/main...new-backup-restore) branch:
* Adds a new CLI for backups (see [Streamlined CLI output](https://dev.discourse.org/t/improve-backups-and-restores/14951/17#streamlined-cli-output-priority-medium105x20upload3bcyofxhqsig8sqxq575gcqpcrnsvg-2))

* Implements a new backup archive format (see [New backup archive format](https://dev.discourse.org/t/improve-backups-and-restores/14951/17#introduce-new-backup-archive-format-priority-low79x20uploadr2kfmshuzknqlz2luizrc8wl3mvsvg-12))

* Adds lots of specs for backups -- there's currently 82% test coverage. Up until now we had hardly any tests for backups because most of the code wasn't written with testing and reusability in mind.

#### My next steps are:
1. Get test coverage for backups up to ~90-95%. There's a couple of important test scenarios that are still missing.

1. Improve log output in case of errors.

1. Copy the current code for restoring backups into the new `disco` CLI.

1. Merge the new CLI as experimental feature without interfering with the existing backup/restore code.

---

After that I intend to continuously merge all incremental changes while I:

5. Implement restore functionality for the new backup archive format.

1. Implement the various improvements based on the priorities defined in https://dev.discourse.org/t/improve-backups-and-restores/14951/17?u=gerhard.

---

I'm really happy with the current state of the new backup/restore functionality. It's already much more fun to use and as a developer I think it's easier to work on well structured pieces of code instead of having multiple thousand lines of code within 1 file. And the high test coverage should make it a lot less brittle and less challenging for other people to work on this part of Discourse in the future.
