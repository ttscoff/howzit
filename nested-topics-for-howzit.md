---
title: Nested topics for Howzit
layout: post
tags: [howzit, ruby, markdown, cli, automation]
categories: [Blog,Code]
post_class: 'code'
comments: true
---
[Howzit](https://github.com/ttscoff/howzit) has always split build notes into topics using Markdown headers. What it didn't do was care *which* header level you used. An `##` and a `###` were both just "a topic," and they all got flattened into one long list. As of version 2.1.44, that's changed: deeper headers now nest under the header above them, and that nesting affects both how notes display and what happens when you run them.

### The short version

A `###` following a `##` is now a subtopic of that `##`. A `####` under the `###` is a subtopic of the `###`, and so on down. The next header at the same level (or shallower) closes out the parent.

```markdown
## Deploy

@run(./scripts/preflight.sh) Preflight checks

### Build assets

@run(gulp) Build

### Upload

@run(gulp sync) Sync to server

## Package management
```

Here "Build assets" and "Upload" belong to "Deploy." "Package management" is back at the top level.

### Viewing a parent topic

When you pull up a parent topic, you now get the whole thing: the parent, followed by all of its subtopics.

```console
$ howzit deploy
```

Subtopic headers get a slightly lighter treatment (a dotted rule and a cyan title) so you can see where the nesting happens without it getting noisy. You can still ask for a subtopic directly:

```console
$ howzit upload
```

...and you'll get just that section.

### Running a parent topic

This is the part I actually wanted. Running a parent now runs everything under it:

```console
$ howzit -r deploy
```

That runs Deploy's own tasks first, then each subtopic's tasks in order, depth-first. So the example above runs preflight, then the build, then the sync. You get one combined summary at the end instead of a "Ran 1 task" line for every section.

A few details worth knowing:

- **Errors stop the run.** If a task fails, the remaining subtopics are skipped. Add `--force` if you want it to push through anyway.
- **`@before` and `@after` still work per topic.** Each topic shows its prerequisites before its own tasks run. A parent's `@after` block shows up once the parent *and* all of its subtopics are done, which is usually where you want that "don't forget to..." reminder.
- **Parents don't need tasks of their own.** A parent that's just an umbrella for a few subtopics runs fine, and it won't complain about "No @directive found."
- **Subtopics still run on their own.** `howzit -r upload` runs just the upload step.

### Includes get the whole tree too

If another topic does `@include(Deploy)`, it now runs Deploy and all of its subtopics, same as running it directly. Task counts in include notes and menus reflect the full tree, so you're not surprised by how much is about to happen.

### Listing and "show everything"

Running `howzit` with no arguments shows every topic. It now only prints top-level topics, since subtopics come along with their parents. No more seeing the same section twice.

`howzit -l` indents subtopics under their parents, so the list reflects the structure of your note:

```console
$ howzit -l
Topics:

- Deploy
  - Build assets
  - Upload
- Package management
```

Shell completions stay flat, so you can still tab-complete straight to a subtopic.

### One thing to check in your notes

If you've been using `###` headers under `##` purely as visual formatting, those are now real subtopics. Viewing the parent will include them (probably what you wanted anyway), and running the parent will run their tasks too. If you had a `###` section with tasks you *don't* want run as part of its parent, bump it up to `##`.

### Grab it

It's in 2.1.44:

```console
$ gem install howzit
```

The details are in the [build notes anatomy page](https://github.com/ttscoff/howzit/wiki/Anatomy-of-a-build-notes-file#subtopics) on the wiki. I've already started restructuring a few of my own notes around this. Having a single "Release" topic that fans out into build, test, and publish steps is a lot nicer than keeping them all at the same level and chaining them together with `@include`.
