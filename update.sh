#!/bin/bash
set -eo pipefail

declare -A base=(
	[stretch]='debian'
	[stretch-slim]='debian'
	[alpine]='alpine'
)

variants=(
	stretch
	stretch-slim
	alpine
)


# version_greater_or_equal A B returns whether A >= B
function version_greater_or_equal() {
	[[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" || "$1" == "$2" ]];
}

min_versionFrappe=10.1

dockerRepo="monogramm/docker-frappe"
latestsFrappe=( $( curl -fsSL 'https://api.github.com/repos/frappe/frappe/tags' |tac|tac| \
	grep -oE '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+' | \
	sort -urV ) 10.1.67 )

latestsBench=( 4.1 master )

# Remove existing images
echo "reset docker images"
rm -rf ./images/
mkdir -p ./images

echo "update docker images"
travisEnv=
for latest in "${latestsFrappe[@]}"; do
	version=$(echo "$latest" | cut -d. -f1-2)

	# Only add versions >= "$min_version"
	if version_greater_or_equal "$version" "$min_versionFrappe"; then

		for bench in "${latestsBench[@]}"; do

			for variant in "${variants[@]}"; do
				# Create the version+variant directory with a Dockerfile.
				dir="images/$version-$bench/$variant"
				if [ -d "$dir" ]; then
					continue
				fi
				echo "generating frappe $latest [$version] / bench $bench ($variant)"
				mkdir -p "$dir"

				template="Dockerfile-${base[$variant]}.template"
				cp "$template" "$dir/Dockerfile"

				# Replace the variables.
				sed -ri -e '
					s/%%VARIANT%%/'"$variant"'/g;
					s/%%VERSION%%/'"$latest"'/g;
					s/%%BRANCH%%/'"$bench"'/g;
				' "$dir/Dockerfile"

				# Copy the shell scripts
				for name in entrypoint; do
					cp "docker-$name.sh" "$dir/$name.sh"
					chmod 755 "$dir/$name.sh"
				done

				cp ".dockerignore" "$dir/.dockerignore"

				travisEnv='\n    - VERSION='"$version"' BENCH='"$bench"' VARIANT='"$variant$travisEnv"

				if [[ $1 == 'build' ]]; then
					tag="$version-$variant"
					echo "Build Dockerfile for ${tag}"
					docker build -t ${dockerRepo}:${tag} $dir
				fi
			done

		done

	fi

done

# update .travis.yml
travis="$(awk -v 'RS=\n\n' '$1 == "env:" && $2 == "#" && $3 == "Environments" { $0 = "env: # Environments'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
