#!/bin/bash
set -eo pipefail

declare -A shebang=(
	[buster]='bash'
	[slim-buster]='bash'
	[alpine]='sh'
)

declare -A base=(
	[buster]='debian'
	[slim-buster]='debian'
	[alpine]='alpine'
)

declare -A compose=(
	[buster]='mariadb'
	[slim-buster]='mariadb'
	[alpine]='postgres'
)

declare -A compose=(
	[buster]='mariadb'
	[slim-buster]='mariadb'
	[alpine]='postgres'
)

variants=(
	buster
	slim-buster
	alpine
)


# version_greater_or_equal A B returns whether A >= B
function version_greater_or_equal() {
	[[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" || "$1" == "$2" ]];
}

min_versionFrappe=10

dockerRepo="monogramm/docker-frappe"
latestsFrappe=( $( curl -fsSL 'https://api.github.com/repos/frappe/frappe/tags' |tac|tac| \
	grep -oE '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+' | \
	sort -urV )
	10.x.x
	develop
)

#latestsBench=( 
#	master
#	4.1
#)

# Remove existing images
echo "reset docker images"
rm -rf ./images/
mkdir -p ./images

echo "update docker images"
travisEnv=
for latest in "${latestsFrappe[@]}"; do
	frappe=$(echo "$latest" | cut -d. -f1-2)
	major=$(echo "$latest" | cut -d. -f1-1)

	# Only add versions >= "$min_version"
	if version_greater_or_equal "$frappe" "$min_versionFrappe"; then

		# Define bench version for frappe
		case $frappe in
			#10.*) bench=4.1;;
			*) bench=master;;
		esac

		#for bench in "${latestsBench[@]}"; do

			for variant in "${variants[@]}"; do
				# Create the frappe-bench/variant directory with a Dockerfile.
				dir="images/$frappe-$bench/$variant"
				if [ -d "$dir" ]; then
					continue
				fi
				echo "generating frappe $latest [$frappe] / bench $bench ($variant)"
				mkdir -p "$dir"

				shortVariant=${variant/slim-/}

				# Copy the shell scripts
				for name in entrypoint.sh redis_cache.conf nginx.conf .env; do
					cp "docker-$name" "$dir/$name"
					chmod 755 "$dir/$name"
				done

				case $frappe in
					10.*|11.*) cp "docker-compose_mariadb.yml" "$dir/docker-compose.yml";;
					*) cp "docker-compose_${compose[$variant]}.yml" "$dir/docker-compose.yml";;
				esac

				template="Dockerfile-${base[$variant]}.template"
				cp "$template" "$dir/Dockerfile"

				cp ".dockerignore" "$dir/.dockerignore"
				cp -r "./hooks" "$dir/hooks"
				cp -r "./test" "$dir/"
				cp "docker-compose.test.yml" "$dir/docker-compose.test.yml"

				# Replace the variables.
				if [ "$major" = "10" ]; then
					sed -ri -e '
						s/%%VARIANT%%/'"$variant"'/g;
						s/%%SHORT_VARIANT%%/'"$shortVariant"'/g;
						s/%%PYTHON_VERSION%%/2/g;
						s/%%NODE_VERSION%%/8/g;
						s/%%PIP_VERSION%%//g;
						s/%%SHEBANG%%/'"${shebang[$variant]}"'/g;
					' "$dir/Dockerfile" "$dir/entrypoint.sh"
				elif [ "$major" = "11" ]; then
					sed -ri -e '
						s/%%VARIANT%%/'"$variant"'/g;
						s/%%SHORT_VARIANT%%/'"$shortVariant"'/g;
						s/%%PYTHON_VERSION%%/3/g;
						s/%%NODE_VERSION%%/8/g;
						s/%%PIP_VERSION%%/3/g;
						s/%%SHEBANG%%/'"${shebang[$variant]}"'/g;
					' "$dir/Dockerfile" "$dir/entrypoint.sh"
				else
					sed -ri -e '
						s/%%VARIANT%%/'"$variant"'/g;
						s/%%SHORT_VARIANT%%/'"$shortVariant"'/g;
						s/%%PYTHON_VERSION%%/3/g;
						s/%%NODE_VERSION%%/12/g;
						s/%%PIP_VERSION%%/3/g;
						s/%%SHEBANG%%/'"${shebang[$variant]}"'/g;
					' "$dir/Dockerfile" "$dir/entrypoint.sh"
				fi
				sed -ri -e '
					s/%%VARIANT%%/'"$variant"'/g;
				' "$dir/.env" "$dir/test/Dockerfile"

				if [ "$bench" = "4.1" ]; then
					sed -ri -e '
						s/%%BENCH_OPTIONS%%//g;
					' "$dir/Dockerfile"
				else
					sed -ri -e '
						s/%%BENCH_OPTIONS%%/--skip-redis-config-generation --no-backups/g;
					' "$dir/Dockerfile"
				fi

				if [ "$latest" = "develop" ]; then
					sed -ri -e '
						s/%%VERSION%%/'"$latest"'/g;
						s/%%BENCH_BRANCH%%/'"$bench"'/g;
						s/%%FRAPPE_VERSION%%/'"$major"'/g;
					' "$dir/Dockerfile" "$dir/docker-compose.yml" "$dir/.env" "$dir/test/Dockerfile"
				else
					sed -ri -e '
						s/%%VERSION%%/'"v$latest"'/g;
						s/%%BENCH_BRANCH%%/'"$bench"'/g;
						s/%%FRAPPE_VERSION%%/'"$major"'/g;
					' "$dir/Dockerfile" "$dir/docker-compose.yml" "$dir/.env" "$dir/test/Dockerfile"
				fi

				travisEnv='\n  - VERSION='"$frappe"' BENCH='"$bench"' VARIANT='"$variant$travisEnv"

				if [[ $1 == 'build' ]]; then
					tag="$frappe-$variant"
					echo "Build Dockerfile for ${tag}"
					docker build -t ${dockerRepo}:${tag} $dir
				fi
			done

		#done

	fi

done

# update .travis.yml
travis="$(awk -v 'RS=\n\n' '$1 == "env:" && $2 == "#" && $3 == "Environments" { $0 = "env: # Environments'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
