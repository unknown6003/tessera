# Recovered studies

Recovered from the 10 November 2026 Opus research workflow.
Status: source verification pending. This report is research, not a product spec.
No interviews or new participant study took place. Public posts are qualitative evidence only.

The research points one way. People rarely delete personal files. They see keeping as the safe default and deleting as a risk (prospect theory, Bergman et al. 2009). In self-reports, deletion is the least-used way people manage their files (Englefield & Beale 2025). So Rescue should not ask users to sort through their own documents. It should lead with the few large, low-value or re-creatable items that hold most of the bytes. The file-system studies back this. Bytes sit in a small number of large files and types: video, databases, disk images, VMs and backups (Agrawal et al. 2007). In 2009, half of all bytes were in files over 30 MB (Meyer & Bolosky 2011). These studies are strong but old, and they cover only corporate Windows PCs. The best macOS-era evidence is self-reported user-collection data (Dinneen & Nguyen 2021), and I found no recent large study of Mac disk composition. The PIM studies show that concrete items trigger decisions far better than abstract rules. Shown 10 of their own files, 83% of users wanted to delete at least one. In the abstract, only 32% thought automatic deletion would help (Khan et al. 2018). Last-modified date alone is a weak predictor of what users want to delete. Perceived usefulness matters more (Khan et al. 2021). Users split between wanting full control and accepting automation, and both groups prefer 'recommend, then I choose' over silent automatic deletion (Vitale et al. 2019). On safety, NN/g and Apple's HIG agree on two rules. Undoable actions such as Move to Trash should not get heavy confirmations. Irreversible ones need a specific confirmation that names the files. A preselected item is a strong push: in a 58-study meta-analysis, d = 0.68 and the preselected option is chosen about 27% more often. So preselect only the truly safe class. Most PIM and hoarding evidence is small and qualitative (12–100 participants) or self-reported. It is good for direction, not for exact thresholds.

## Findings

### People keep far more than they delete. 'Keep' is the default reference point, so deleting feels like a risky loss (prospect theory). Offering an intermediate 'demote' action raised total cleanup but halved outright deletion.

Evidence: GrayArea paper, CHI 2009, n=96 lab study. 'The decision to keep was already made when a file was first created... "to keep" is the default reference point, while "delete" is a new possible risky alternative.' Standard condition: 80% of files kept, 20% deleted. GrayArea condition: 67% kept, 10% deleted, 23% demoted; 33% cleaned vs 20%, t(77)=3.94, p<0.001. '81% of participants found it easier to demote than delete.' Evidence is moderate: one lab task on folders participants brought in, and old (2009).

Source: https://cutrell.org/papers/CHI09-BergmanEtal-GrayArea.pdf

Implication: Treat Move to Trash as Rescue's 'demote' step: reversible and low-stakes. But a soft action can take the place of real space recovery. Apple says Trash space 'doesn't become available until you empty the Trash'. So Rescue must say clearly whether GB is 'moved to Trash' or 'freed'. It should not add a third 'archive/hide' action that frees nothing.

### Boardman & Sasse coined the line 'Stuff goes into the computer and doesn't come out'. They classed items by usefulness: active, inactive, dormant, unassessed.

Evidence: CHI 2004 cross-tool longitudinal study of documents, email and bookmarks (pp. 583–590). It introduces 'information usefulness (active, inactive, dormant, and unassessed)'. The participant quote is repeated in GrayArea: 'Stuff goes in... it just builds up'. Evidence is qualitative, has a small sample (exact n unverified) and is 2004.

Source: https://dl.acm.org/doi/10.1145/985692.985766

Implication: A 'dormant' signal (not opened in a long time) is a valid way to surface candidates. It works as a label on an item ('Not opened since 2023'). It does not justify auto-selecting the item.

### Deletion is the least-used personal information management tactic. Heavier deleters report slightly worse retrieval.

Evidence: Englefield & Beale, BCS HCI 2025, n=51 knowledge workers, self-report scales. Median deletion score was 0.25 vs about 0.875 for Filing, Timeliness and Coverage. Deletion vs retrieval success ρ = −0.215. Authors: 'deletion is a high-cost, low-feedback, high-risk investment'. Evidence is weak: self-reported and correlational, the reported p-values do not match the sample size, and there are table inconsistencies.

Source: https://arxiv.org/html/2512.23907v1

Implication: Do not frame Rescue as 'tidy your files'. Aim it at bytes whose loss costs nothing later: caches, build products, installers, re-downloadable media, duplicate copies. Leave personal documents mostly alone.

### Users forget most stored files. When shown concrete items, most want to delete some. In the abstract, they distrust automatic deletion.

Evidence: Khan et al., CHI 2018, n=100 online participants, each shown 10 stratified files from their own Dropbox/Google Drive. 'Participants had forgotten that half of the files they saw'. '83% of participants wanted to delete at least one file'. File decisions: 58% keep, 35% delete, 7% encrypt. Only 32% agreed automatic deletion would help, vs 72% for automatic encryption. 14% of files were unrecognized, and users wanted to delete or encrypt 84% of those. Users remembered larger files and recently modified files better (p<.001). 41% of files were last accessed 1–5 years ago (self-report). Reasons for deleting: 91% 'no longer useful or causing clutter', 26% could not remember the file, 10% to clear space. Evidence is moderate: cloud data, not local disks, and a self-selected sample.

Source: https://www.blaseur.com/papers/chi18retrospectivecloud.pdf

Implication: Show real, named items with where they came from and when they were last opened. Do not lead with abstract rules ('delete files older than X'). Large files are more likely to be remembered, so big personal items need a clear origin label, not a 'safe' badge.

### File age and last-modified date are weak predictors of what users want to delete. Perceived usefulness and sensitivity dominate.

Evidence: Khan et al., USENIX Security 2021: 17 interviews, then 108 long-term cloud users and 3,525 labeled files. The model predicts keep/delete/protect with 79% accuracy, and delete decisions with 75%. Feature importance: predicted usefulness 0.40, sensitivity 0.11. Baselines using 'Last modified, file type' did far worse. Interviews: 'files that had been recently accessed or modified were more likely to be useful, yet some older files might also be needed for reference.' Labels: delete 40%, protect 8%, keep 52%. Evidence is moderate to strong for cloud files.

Source: https://www.usenix.org/system/files/sec21-khan-mohammad.pdf

Implication: Use last-used date as an explanation cue, not as the main sort key or the reason to preselect. Rank by reclaimable bytes within a safety class. Base safety on what the item is (cache, installer, build output, duplicate, app support for an app no longer installed), not on how old it is.

### On real disks, bytes concentrate in a few large files and types. Small files dominate the count but not the space. Disks get fuller every year because new files outpace deletions.

Evidence: Agrawal, Bolosky, Douceur, Lorch, FAST 2007. Yearly snapshots of over 60,000 Windows PC file systems at Microsoft, 2000–2004. 'most files are 4 KB or smaller' but 'the average file system had only 52 MB in files 4 KB or smaller'. Median weighted file size grew from 3 MB to 9 MB. 'most of the bytes in large files are in video, database, and blob files' (iso, vhd, bak, hiberfil). 'nine file-name extensions account for over 35% of the bytes'. '80% of file systems become fuller', by a mean of +14 points a year: new files +28, deletions −15. Evidence is strong in method but dated and comes from corporate Windows (it won the FAST Test of Time award).

Source: https://www.usenix.org/legacy/event/fast07/tech/full_papers/agrawal/agrawal_html/index.html

Implication: Open Rescue with a ranked 'biggest reclaimable' view and type rollups: disk images and VMs, video, archives, backups, app and dev caches. A long list of many small items wastes attention. Deletions only partly offset growth, so a periodic 'what grew' view is worth considering.

### In 2009, half of all desktop bytes were in files over 30 MB, up from 2 MB in 2000. Whole-file duplicates give about 3/4 of the savings of aggressive block-level dedup. Those duplicate bytes are mostly program binaries in smaller files.

Evidence: Meyer & Bolosky, FAST 2011 (Best Paper), 857 Microsoft desktops over 4 weeks. 'half of all bytes are in files larger than 30MB (this figure was 2MB in 2000)'. 'whole-file deduplication achieves about three quarters of the space savings'. dll, lib, pdb, exe, cab, msp and msi 'together make up 58% of the saved space'. 'duplicate bytes tend to be in smaller files than bytes in general'. VHDs hold duplicate blocks but 'rarely have whole-file duplicates'. 15% of users had disks over 75% full. Mean utilization 43%. Evidence is strong in method but dated and covers Windows only.

Source: https://www.usenix.org/legacy/event/fast11/tech/full_papers/Meyer.pdf

Implication: Exact-duplicate finding is worthwhile, but much duplicate volume sits inside app and toolchain bundles that are not safe to remove. Rescue should exclude or hold bundle internals and show duplicate groups by reclaimable bytes (copies minus one). Unverified for macOS: APFS clones may mean some 'duplicates' use no extra space, so the reclaimable figure needs checking.

### In user-managed collections, files have grown more than tenfold in average size since the mid-2000s. Personal collections hold more large media files than work collections.

Evidence: Dinneen & Nguyen, ASIS&T 2021, 348 user collections, 49M files. Hidden and OS folders were excluded. 48% of collections were macOS. 'files below ~5 KB account for 50% of Mac and Linux collections'. 'personal collections contain more large files than most work collections'. Evidence is moderate: a volunteer sample of user-chosen folders.

Source: https://arxiv.org/pdf/2107.03272

Implication: On personal Macs, big user-owned bytes are often personal media, which people value emotionally. Media groups should default to 'Review first' and be sorted by size. Use thumbnails or previews, not path-only rows.

### Digital hoarding is common. It has two separate components: accumulating and difficulty deleting. Its drivers include anxiety, emotional attachment, keeping things as evidence, and time pressure.

Evidence: Sweeten, Sillence & Neave 2018 (Computers in Human Behavior 85:54–60): qualitative thematic analysis of about 45 people (another paper cites 43). It found over-accumulation, difficulty deleting and anxiety. Neave et al. 2019: UK workers, n=424 and n=203. The 10-item DHQ has two factors, 'difficulty deleting' (α=.905) and 'accumulating' (α=.824), and 'digital hoarding was common (with emails being the most commonly hoarded items)'. Sillence et al. 2023 list motivations: emotional attachment, keeping 'as evidence', and time pressures. Evidence: the qualitative work is small; the questionnaire work is moderate but workplace-focused.

Source: https://researchportal.northumbria.ac.uk/en/publications/digital-hoarding-behaviours-underlying-motivations-and-potential-/ ; https://researchportal.northumbria.ac.uk/ws/portalfiles/portal/18627725/Neave.pdf ; https://www.tandfonline.com/doi/full/10.1080/07370024.2023.2293001

Implication: Effort and anxiety block cleanup. Rescue should cut the number of decisions: batch the clearly safe group into one action, and avoid making users judge many personal items. Tone should be neutral and reassuring, not guilt-inducing.

### People sit on a spectrum from hoarders to minimalists. Tools should serve both ends.

Evidence: Vitale, Janzen & McGrenere, CHI 2018 (Best Paper), 23 interviews: 'hoarding (where participants accumulated large amounts of data, even if considered of little value) and minimalism (where they kept as little as possible, regularly cleaning their data)'. Evidence is qualitative, with a small sample.

Source: https://www.cs.ubc.ca/labs/edapt/papers/vitale2018.pdf

Implication: Give one fast path (the safe batch) for people who keep everything, and a detailed review for minimalists. Do not moralize about clutter.

### Users are split on automation, but most prefer recommendations they approve over automatic deletion. Some like deciding in advance with rules.

Evidence: Vitale, Odom & McGrenere, DIS 2019 (Honorable Mention): 16 interviews around 5 video prototypes. 'some wanted to retain full control... while others welcomed more automatic tools'. P7: 'I'd prefer to have them notify me or go through them and choose... much more comfortable with that vs having things automatically deleted.' P1 on an auto-expiring folder: 'I would be terrified'. Several 'preferred to decide in advance and not worry later'. Evidence is qualitative, with a small sample.

Source: https://www.cs.ubc.ca/labs/edapt/papers/vitale2019.pdf

Implication: Default to 'recommend, then stage': nothing leaves without the user's explicit action. Recurring rules (such as 'always clear build caches') could come later as an opt-in, never as the default.

### A central cleanup overview needs explicit safety guarantees and plain language. Most existing tools just rank by size.

Evidence: Vitale, Chen, Odom & McGrenere, DIS 2020, 18 participants with the Data Dashboard prototype. 'centralizing data in a single management system blurs boundaries and requires safety guarantees. Customization options, instead, uphold boundaries and reinforce user control.' On existing tools: 'Most of these tools focus on freeing up space by finding items to discard based on their size.' Unclear terms ('Tracking data... what does it include?') hurt trust. Evidence is qualitative.

Source: https://www.cs.ubc.ca/labs/edapt/papers/vitale2020.pdf

Implication: State the guarantees in the Rescue header: local only, Trash by default, protected paths held. Use plain category names (avoid jargon such as 'System Data' or 'Containers' without a gloss). Let users hide or keep categories they never want suggested.

### Photo deletion decisions are subjective, so automatic flagging is problematic. Once people do delete, they report mostly positive feelings, and regret appears only afterwards.

Evidence: Wolters et al., CHI 2014 work-in-progress: people kept about two in three photos, and the authors say 'automatic tagging of photos for deletion is problematic; interfaces should instead make it easy for users to find and compare similar photos' (secondary summary). Hellmich & Dinneen, Journal of Documentation 81(7), 2025, n=12 think-aloud: 'participants experienced more positive affective aspects, especially after deleting'. Satisfaction was mentioned by every participant. Regret appeared only after deletion. 5 of 12 had restored photos at some point. 10 found deletion easier after time had passed. The authors recommend iterative rounds. Evidence is small and qualitative.

Source: https://dl.acm.org/doi/pdf/10.1145/2559206.2581287 ; https://www.emerald.com/jd/article/81/7/443/1302896/Challenging-but-satisfying-an-exploration-of-the

Implication: After an action, show a clear result ('Freed 23.4 GB') and a visible restore path. Support repeat sessions ('Since last time') rather than one big purge. Keep personal photos out of automatic selection.

### Users often fail to delete because they hold wrong mental models of sync folders, retention periods, levels of deletion and the deleted folder.

Evidence: Ramokapane, Rashid & Such, SOUPS 2017: '8 mental models that leads to failure to delete', mostly from misunderstanding 'sync folders, retention periods, levels of deletion and the deleted folder' (from the talk slides). Hellmich & Dinneen 2025 also found 3 of 12 unsure how deletion synced with the cloud.

Source: https://www.usenix.org/sites/default/files/conference/protected-files/soups17_slides_ramokapane.pdf ; https://eprints.lancs.ac.uk/id/eprint/86800/

Implication: For iCloud-synced or cloud-backed items, Rescue should say what Move to Trash does: whether it removes the item everywhere and whether it frees local space. After acting, verify actual free space (Tessera already has a 'verifying' phase) and explain any gap, such as Trash not emptied or purgeable space.

### Files by Google popularized size-labeled category cards with one action each. Its junk cleaning is permanent after one confirmation. Google reported about 1.1 GB freed per user on average.

Evidence: Google Help: 'On the "Junk files" card, tap Clean xx MB'. 'If you clear junk files or delete files using Files by Google, the data will be permanently deleted'. 'On the confirmation dialog, tap Clear.' Google blog (2018): 'more than 10 million people have installed it and cleaned up more than 1.1 gigabytes of space on average.' Other cards per secondary sources: duplicates, large files, screenshots, downloads, unused apps. The Google figure is self-reported, with no published method; I found no Google UX research paper.

Source: https://support.google.com/files/answer/9713869?hl=en ; https://blog.google/innovation-and-ai/technology/next-billion-users/files-go-three-new-features/

Implication: Copy the pattern of one card per category with the reclaimable size on the action button. Do not copy the permanent-delete default. Tessera's Trash default is the safer version of the same flow.

### Android Smart Storage deletes media automatically only once a backup is confirmed: after 60 days, or when free storage drops below 25%.

Evidence: Google Help: photos backed up in Google Photos are deleted 'if photos are saved for 60 days, or if your device's storage is less than 25%'. Only for Pixel on Android S and later. It removes only media Google Photos has confirmed as backed up.

Source: https://support.google.com/files/answer/10862356?hl=en

Implication: 'A copy exists elsewhere' is the clearest safety rationale there is. Rescue can build its 'Safe' class from re-creatable or re-downloadable evidence (caches that rebuild, installers for apps already installed, build outputs) and say that reason in each row.

### macOS's own baseline is categories with info buttons, a Documents view with Large Files, Downloads and File Browser that sorts by Name, Kind, Last Accessed or Size, and three recommendations. macOS also clears safe caches and logs by itself when space is needed.

Evidence: Apple Support: 'You can sort files by clicking Name, Kind, Last Accessed or Size'. Recommendations are Store in iCloud, Optimize Storage, and Empty Trash automatically ('items that have been in the Trash for more than 30 days'). macOS clears 'caches and logs that are safe to delete' when space is needed. Trash: 'its storage space doesn't become available until you empty the Trash.' The current guide page shows macOS 27 in its version picker (not checked in the app).

Source: https://support.apple.com/guide/mac-help/find-and-delete-files-on-your-mac-syspf5a64aa6/mac ; https://support.apple.com/guide/mac-help/optimize-storage-space-sysp4ee93ca4/mac ; https://support.apple.com/en-us/102624

Implication: Rescue has to beat a free built-in tool that already sorts by size and last accessed. It adds value with groups Apple does not cover (developer caches, VMs, disk images, duplicates, leftovers from removed apps) and by explaining why each item is safe. Some cache gains may be temporary because macOS purges and rebuilds caches (inference, unverified).

### Windows 11 'Cleanup recommendations' uses four buckets: temporary files, large or unused files, files synced to the cloud, and unused apps.

Evidence: Microsoft Q&A answers (AI-generated) and third-party guides give the path Settings > System > Storage > Cleanup recommendations and the four categories. I did not reach Microsoft's own support page, so treat the exact labels as unverified.

Source: https://learn.microsoft.com/en-us/answers/questions/5806672/how-to-remove-old-windows-update-files-taking-up-s ; https://pureinfotech.com/free-up-space-windows-11/

Implication: Apple, Google and Microsoft land on a similar structure: junk or temp, large or unused, cloud-backed, unused apps. Users may already know that model, so Rescue groups can follow it.

### Use confirmation dialogs only for serious or irreversible actions. Make them specific (name the files, show thumbnails, use action-verb buttons). Overused dialogs get clicked through. Undo is the stronger safety net.

Evidence: Nielsen, NN/g, 2018, reviewed 2026: 'Do not use confirmation dialogs for routine actions.' 'Saying these 2 items doesn't tell users which files will be deleted.' Buttons should read 'Delete file' and 'Keep file'. 'if you warn people too much, they stop paying attention.' 'it's probably best not to have a default answer at all.' 'do go to great lengths to provide undo'. This is expert guidance, not a controlled study.

Source: https://www.nngroup.com/articles/confirmation-dialog/

Implication: Move to Trash for staged items needs no extra 'Are you sure?' modal beyond the path review the user opens. Permanent delete keeps a specific confirmation that names the count, total size and top items, with no default button. An Undo or 'Put back' action after a Trash move adds the most safety for the least friction.

### Apple's HIG: do not alert for common undoable destructive actions. Use the destructive button style only when the user did not deliberately choose the action. Do not make Cancel the default; to make people read, have no default button.

Evidence: HIG Alerts: 'Avoid displaying alerts for common, undoable actions, even when they're destructive.' 'Use the destructive style to identify a button that performs a destructive action people didn't deliberately choose.' 'you don't want to make a Cancel button the default button. If you want to encourage people to read an alert... avoid making any button the default button.' Aza Raskin (A List Apart, 2007) makes the same point: 'Never use a warning when you mean undo'.

Source: https://developer.apple.com/design/human-interface-guidelines/alerts ; https://en.wikipedia.org/wiki/Alert_dialog_box

Implication: The Trash path should be fast with a clear undo. Only the permanent-delete path should get an alert, with no default button. The button label should name the action and amount, for example 'Delete 4.2 GB permanently'.

### Defaults strongly steer choices. On average, the preselected option is chosen about 27% more often. The effect is stronger when users read the default as the designer's recommendation.

Evidence: Jachimowicz, Duncan, Weber & Johnson, Behavioural Public Policy 2019: meta-analysis of 58 studies, n=73,675, d=0.68 (95% CI 0.53–0.83), with wide variation. Endorsement moderator b=0.32, p=0.038. The authors' summary: the preselected option is chosen '27 percent more often'. NN/g (2005): 'people tend to stick to the defaults.' Evidence is strong (a meta-analysis), though few of the studies concern software.

Source: https://www.cambridge.org/core/journals/behavioural-public-policy/article/when-and-why-defaults-influence-decisions-a-metaanalysis-of-default-effects/67AF6972CFB52698A60B6BD94B70C2C0 ; https://behavioralscientist.org/defaults-are-not-the-same-by-default/ ; https://www.nngroup.com/articles/the-power-of-defaults/

Implication: Preselecting a row in Rescue is a recommendation users will mostly accept. Preselect only the 'Safe' class (re-creatable, with a stated reason). Never preselect 'Review first' or personal media. Show why the item is selected.

### Showing many options does not reliably hurt choice on its own. The average choice-overload effect is near zero.

Evidence: Scheibehenne, Greifeneder & Todd, Journal of Consumer Research 2010: meta-analysis of 50 experiments and 5,036 participants. The mean effect was 'virtually zero' (D≈0.02 per a secondary source). Chernev et al. dispute this, saying overload appears under specific conditions.

Source: https://pure.mpg.de/view/item_2099676

Implication: Rescue's problem is likely missing ranking and explanation, not too many items. A long list is acceptable if it is sorted by reclaimable bytes, with the top few emphasized and the long tail collapsed.

### Information scent: users judge where to go from the proximal cues (labels, titles), and leave when the scent weakens. Progressive disclosure: what appears first signals importance, and one secondary level is usually best.

Evidence: NN/g, Information Foraging (Pirolli & Card, PARC, late 1990s; Psychological Review 1999): each source emits a 'scent', 'a signal that tells the forager how likely it is that it contains what she needs'. Nielsen 2006: progressive disclosure 'defers advanced or rarely used features to a secondary screen'. If something is on the first screen, users take it as important. Multiple disclosure levels are 'rarely a good idea'. Evidence: a well-supported theory plus expert guidance.

Source: https://www.nngroup.com/articles/information-foraging/ ; https://www.nngroup.com/articles/progressive-disclosure/

Implication: Each Rescue group label should carry three cues at once: what it is, how big it is, and why it is safe or risky (for example 'Xcode build data · 18.2 GB · rebuilds when needed'). First level: a few groups. Second level: item rows. Full paths appear only in the review sheet.

### Glanceable displays let people take in information quickly through deliberate use of visual variables (color, shape, position, size). The research is on peripheral displays, not cleanup dashboards.

Evidence: Matthews, Forlizzi & Rohrbach, UC Berkeley tech report EECS-2006-113: 'users need to quickly glance at and read displayed information with minimal interruption'. A taxonomy of visual variables from designer interviews and a case study. Evidence is weak to moderate for this context.

Source: https://www2.eecs.berkeley.edu/Pubs/TechRpts/2006/EECS-2006-113.html

Implication: At the top of Rescue, use one headline number (reclaimable safely), one comparison bar (free now vs after Rescue, or vs the goal), and at most one accent color for the safe portion. That fits the cyan-on-dark theme.

### In a file-hierarchy task study, sunburst and treemap showed no significant difference in completion time. Users preferred sunburst for showing structure. A later study found the opposite preference.

Evidence: Stasko et al., IJHCS 2000: 'Performance trends were better, and preferences higher, with the Sunburst method'. A secondary summary reports no significant time differences. arXiv 1908.01277 found sunburst least preferred in its pilot. Evidence is old, with low-resolution displays.

Source: https://faculty.cc.gatech.edu/~john.stasko/papers/ijhcs00.pdf ; https://arxiv.org/pdf/1908.01277

Implication: The sunburst suits Explore, which is about structure. Rescue is about ranking magnitudes, so sorted rows with length-encoded bars suit it better. That last step is my inference from general perception guidance, not from this paper.

### I found no recent public dataset on what fills consumer Mac disks, by category.

Evidence: My searches returned only the Microsoft corporate Windows studies (2007, 2011) and the Dinneen user-collection study (2021). I did not find Backblaze or Apple publishing disk-composition data. Backblaze's public data is about drive reliability (unverified as irrelevant; not fetched).

Source: none

Implication: Tessera's own anonymous analytics could fill this gap and tune group order: the share of reclaimable bytes per category and the accept rate per category. The current ordering heuristics should be checked against real scans.

## patterns

- Size first, within safety tiers. Group into 'Safe' (re-creatable or copy exists, with the reason stated), 'Review first' (personal or ambiguous) and 'Held' (protected or stale). Inside each tier, sort by reclaimable bytes. Agrawal 2007 and Meyer 2011 show bytes concentrate in a few large items. GrayArea, Khan 2018 and Vitale 2019 show personal items need consent.
- Headline plus bar: one number for safe reclaimable space and one bar showing free now vs after Rescue (or vs the selected goal, such as 'Install an update: 4 GB'). Everything else sits one disclosure level down (glanceability, progressive disclosure).
- Every group label carries what / how big / why safe, for example 'iOS Simulator runtimes · 22 GB · re-downloadable from Xcode'. This is information scent, and 'a copy exists elsewhere' is the clearest safety rationale (Android Smart Storage).
- Preselect only the Safe tier and show the reason next to each checked item. Never preselect personal media or 'Review first' items. Defaults act as endorsements (Jachimowicz 2019, d=0.68).
- Last-used date is a supporting cue on each row ('Not opened since Mar 2024'), not the main sort key and not the reason to preselect (Khan 2021).
- No modal for Move to Trash of staged items. Offer Undo or Put Back after the move. Give a specific, no-default-button alert only for permanent delete, naming the count, total size and top items (NN/g 2018; Apple HIG Alerts).
- Report the result honestly: 'Moved 18 GB to Trash' vs 'Freed 18 GB'. Verify actual free space and explain any gap (Trash not emptied, iCloud sync, purgeable space). See Apple's Trash note and Ramokapane 2017.
- Cards per category with the size on the action button follow the convergent Files by Google, Windows and Apple pattern. Keep Trash as the default instead of Google's permanent junk delete.
- Show concrete items with origin and preview rather than abstract rules. Concrete items trigger decisions (Khan 2018: 83% wanted to delete at least one of 10 shown files; only 32% liked automatic deletion in the abstract).
- Support repeat sessions: 'New since last Rescue' and 'Grew since last scan'. Deletion gets easier over time and in rounds (Hellmich & Dinneen 2025), and disks refill about 14 points a year (Agrawal 2007).
- Avoid: guilt or decluttering language; jargon category names without a gloss ('System Data', 'Containers'); age-based auto-selection; a third 'archive/hide' action that frees no space (GrayArea showed demotion halved deletion); and long path lists on the first screen.

## open questions

- What fills a typical Mac disk today, by category? No current public dataset was found. Could Tessera's anonymous analytics record per-category reclaimable bytes and per-category accept rates to set the group order?
- On APFS, how much space do whole-file duplicates actually free, given clones and shared blocks? Meyer 2011's figures predate APFS. Does the duplicate finder report real reclaimable bytes?
- Do cache-category gains last, or does macOS or the app rebuild them within days? Apple says macOS already clears 'caches and logs that are safe to delete' when space is needed. Should Rescue down-rank volatile caches?
- Should Rescue report 'freed' only after the Trash is emptied, or offer 'Empty these items from Trash' as a separate explicit step? Apple: Trash space is not available until emptied.
- Does the current CleanupRisk (safe / review / protected) match a user-visible safety story with one-line reasons, or are the tiers internal only?
- Exact Boardman & Sasse 2004 sample size and the exact Sweeten 2018 participant count (45 vs 43) were not checked against the original papers.
- The exact labels of the Windows 11 Cleanup recommendations were not confirmed on Microsoft's own support page; only Q&A and third-party sources were reached.
- I found no published Google UX research behind Files Go cards; the 1.1 GB average comes from a Google blog post without a stated method.
