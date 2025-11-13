# Contributing to Engineering Log

First off, thank you for considering contributing to Engineering Log! It's people like you that make Engineering Log such a great tool.

## Where do I go from here?

If you've noticed a bug or have a feature request, [make one](https://github.com/alextorresruiz/stdlib/issues/new)! It's generally best if you get confirmation of your bug or approval for your feature request this way before starting to code.

### Fork & create a branch

If this is something you think you can fix, then [fork engineering-log](https://github.com/Excoriate/engineering-log/fork) and create a branch with a descriptive name.

A good branch name would be (where issue #38 is the ticket you're working on):

```sh
git checkout -b 38-add-awesome-new-feature
```

### Get the style right

Your patch should follow the same conventions & pass the same code quality checks as the rest of the project.

### Make a Pull Request

At this point, you should switch back to your main branch and make sure it's up to date with engineering-log's main branch:

```sh
git remote add upstream git@github.com:Excoriate/engineering-log.git
git checkout main
git pull upstream master
```

Then update your feature branch from your local copy of master, and push it!

```sh
git checkout 38-add-awesome-new-feature
git rebase main
git push --force-with-lease origin 38-add-awesome-new-feature
```

Finally, go to GitHub and [make a Pull Request](https://github.com/Excoriate/engineering-log/compare)

:D
