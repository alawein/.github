# Local docs checks. Install just with: winget install Casey.Just
set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

default:
    @just --list

lint:
    npx --yes markdownlint-cli2@0.23.2 "**/*.md" "!.superpowers/**"

test:
    lychee --offline --no-progress './**/*.md'

build:
    @echo "Nothing to build."

check: lint test build

fix:
    npx --yes markdownlint-cli2@0.23.2 --fix "**/*.md" "!.superpowers/**"
