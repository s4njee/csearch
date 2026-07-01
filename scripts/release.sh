#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

sha="${1:-$(git rev-parse HEAD)}"
sha="$(git rev-parse "$sha^{commit}")"
short_sha="$(git rev-parse --short "$sha")"

files=(
  "k8s/netcup-core/kustomization.yaml"
  "k8s/netcup-scraper/kustomization.yaml"
)

if ! git diff --quiet -- "${files[@]}"; then
  echo "Refusing to release with existing uncommitted netcup image tag changes." >&2
  git diff -- "${files[@]}" >&2
  exit 1
fi

update_tag() {
  local file="$1"
  local image="$2"

  IMAGE="$image" TAG="$sha" perl -0pi -e '
    my $image = $ENV{IMAGE};
    my $tag = $ENV{TAG};
    my $count = s/(  - name: \Q$image\E\n    newName: \Q$image\E\n)(?:    newTag: [^\n]+\n|    digest: [^\n]+\n)+/$1    newTag: $tag\n/g;
    die "image $image not found in $ARGV\n" unless $count == 1;
  ' "$file"
}

update_tag "k8s/netcup-core/kustomization.yaml" "registry.s8njee.com/csearch-fastapi"
update_tag "k8s/netcup-core/kustomization.yaml" "registry.s8njee.com/csearch-mcp"
update_tag "k8s/netcup-scraper/kustomization.yaml" "registry.s8njee.com/csearch-updater"
update_tag "k8s/netcup-scraper/kustomization.yaml" "registry.s8njee.com/csearch-tarp-updater"

if git diff --quiet -- "${files[@]}"; then
  echo "Netcup image tags already point at $sha."
  exit 0
fi

git diff --check -- "${files[@]}"
git add "${files[@]}"
git commit -m "Release netcup images $short_sha"

echo "Release commit created for $sha."
