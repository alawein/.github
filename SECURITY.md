# Security policy

How to report a vulnerability privately in any alawein repository, and what to expect.

## Report a vulnerability

Use GitHub private vulnerability reporting. On the repository page, open the
Security tab, choose "Report a vulnerability", and fill in the form. Only the
maintainer sees it.

Please do not open a public issue or pull request with details.

Include:

- The affected repository and version or commit.
- Steps to reproduce.
- What an attacker could do with it.

If the repository has no "Report a vulnerability" button, open a task issue
titled "Security contact request" and put no details in it. I will set up a
private channel.

## What to expect

This is a solo project, so timing is best effort. I aim to:

- Reply within 7 days.
- Fix the problem or explain why not within 90 days.
- Credit you in the release notes if you want that.

## Supported versions

The latest release gets fixes. A repository with no releases supports its
`main` branch only.

## Scope

In scope: code and configuration in the repository you are reporting on.

Out of scope: third-party services, other people's accounts or data, social
engineering, and denial-of-service testing. Please test only against your own
copy.
