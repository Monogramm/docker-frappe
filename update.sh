#!/bin/bash
set -eo pipefail

declare -A shebang=(
	[buster]='bash'
	[slim-buster]='bash'
	[alpine]='sh'
	[gitpod]='bash'
)

declare -A test_base=(
	[buster]='debian'
	[slim-buster]='debian-slim'
	[alpine]='alpine'
	[gitpod]='debian'
)

declare -A base=(
	[buster]='debian'
	[slim-buster]='debian'
	[alpine]='alpine'
	[gitpod]='gitpod'
)

declare -A compose=(
	[buster]='mariadb'
	[slim-buster]='mariadb'
	[alpine]='postgres'
	[gitpod]='mariadb'
)

declare -A compose=(
	[buster]='mariadb'
	[slim-buster]='mariadb'
	[alpine]='postgres'
	[gitpod]='mariadb'
)

variants=(
	buster
	slim-buster
	alpine
	#gitpod
)


# version_greater_or_equal A B returns whether A >= B
function version_greater_or_equal() {
	[[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" || "$1" == "$2" ]];
}

min_versionFrappe=11
dockerLatest='13.0.0-beta.10'
dockerDefaultVariant='alpine'

dockerRepo="monogramm/docker-frappe"
latestsFrappe=(
	develop
	13.0.0-beta.9
	$( curl -fsSL 'https://api.github.com/repos/frappe/frappe/tags' |tac|tac| \
	grep -oE '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+' | \
	sort -urV )
	version-11-hotfix
	#11.1.69
)

latestsBench=(
#	$( curl -fsSL 'https://api.github.com/repos/frappe/bench/tags' |tac|tac| \
#	grep -oE '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+' | \
#	sort -urV )
	master
	4.1
)

# Remove existing images
echo "reset docker images"
rm -rf ./images/
mkdir ./images/

echo "update docker images"
readmeTags=
githubEnv=
travisEnv=
for latest in "${latestsFrappe[@]}"; do
	version=$(echo "$latest" | cut -d. -f1-2)
	major=$(echo "$latest" | cut -d. -f1-1)
	if [ "$latest" = "version-11-hotfix" ]; then
		version=11.x
		major=11
	fi

	# Only add versions >= "$min_version"
	if version_greater_or_equal "$major" "$min_versionFrappe"; then

		# Define bench version for frappe
		case $version in
			#10.*) bench=4.1;;
			*) bench=${latestsBench[0]};;
		esac

		if [ ! -d "images/$major-$bench" ]; then
			# Add GitHub Actions env var
			githubEnv="'$major', $githubEnv"
		fi

		#for bench in "${latestsBench[@]}"; do

			for variant in "${variants[@]}"; do
				# Create the frappe-bench/variant directory with a Dockerfile.
				dir="images/$major-$bench/$variant"
				if [ -d "$dir" ]; then
					continue
				fi
				echo "generating frappe $latest [$version] / bench $bench ($variant)"
				mkdir -p "$dir"

				shortVariant=${variant/slim-/}

				# Copy the shell scripts
				for name in entrypoint.sh redis_cache.conf nginx.conf .env; do
					cp "template/$name" "$dir/$name"
					chmod 755 "$dir/$name"
					sed -i \
						-e 's/{{ NGINX_SERVER_NAME }}/localhost/g' \
						"$dir/$name"
				done

				if ! [ "$variant" = "gitpod" ]; then
					cp "template/entrypoint.sh" "$dir/entrypoint.sh"

					cp "template/docker-compose_mariadb.yml" "$dir/docker-compose.mariadb.yml"
					case $major in
						10|11) echo "Postgres not supported for $latest";;
						*) cp "template/docker-compose_postgres.yml" "$dir/docker-compose.postgres.yml";;
					esac
				fi

				template="template/Dockerfile.${base[$variant]}.template"
				cp "$template" "$dir/Dockerfile"

				cp "template/.dockerignore" "$dir/.dockerignore"
				cp -r "template/hooks" "$dir/hooks"
				cp -r "template/test" "$dir/"
				cp "template/docker-compose.test.yml" "$dir/docker-compose.test.yml"

				if [ "$variant" = "alpine" ]; then
					sed -ri -e '
						s/%%VARIANT%%/alpine3.10/g;
					' "$dir/Dockerfile"
				else
					sed -ri -e '
						s/%%VARIANT%%/'"$variant"'/g;
					' "$dir/Dockerfile"
				fi

				# Replace the variables.
				if [ "$major" = "10" ]; then
					sed -ri -e '
						s/%%SHORT_VARIANT%%/'"$shortVariant"'/g;
						s/%%PYTHON_VERSION%%/2/g;
						s/%%NODE_VERSION%%/8/g;
						s/%%PIP_VERSION%%//g;
						s/%%SHEBANG%%/'"${shebang[$variant]}"'/g;
					' "$dir/Dockerfile" "$dir/entrypoint.sh"
				elif [ "$major" = "11" ]; then

					if [ "$variant" = "alpine" ]; then
						sed -ri -e '
							s/%%PYTHON_VERSION%%/3.7/g;
						' "$dir/Dockerfile"
					else
						sed -ri -e '
							s/%%PYTHON_VERSION%%/3.7/g;
						' "$dir/Dockerfile"
					fi

					sed -ri -e '
						s/%%SHORT_VARIANT%%/'"$shortVariant"'/g;
						s/%%PYTHON_VERSION%%/3/g;
						s/%%NODE_VERSION%%/10/g;
						s/%%PIP_VERSION%%/3/g;
						s/%%SHEBANG%%/'"${shebang[$variant]}"'/g;
					' "$dir/Dockerfile" "$dir/entrypoint.sh"
				else
					sed -ri -e '
						s/%%PYTHON_VERSION%%/3.7/g;
					' "$dir/Dockerfile"

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
					s/%%VARIANT%%/'"${test_base[$variant]}"'/g;
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

				if [ "$latest" = "develop" ] || [ "$latest" = "version-11-hotfix" ]; then
					sed -ri -e '
						s/%%VERSION%%/'"$latest"'/g;
						s/%%BENCH_BRANCH%%/'"$bench"'/g;
						s/%%FRAPPE_VERSION%%/'"$major"'/g;
					' "$dir/Dockerfile" \
						"$dir"/docker-compose.*.yml \
						"$dir/.env" \
						"$dir/test/docker_test.sh" \
						"$dir/test/Dockerfile"
				else
					sed -ri -e '
						s/%%VERSION%%/'"v$latest"'/g;
						s/%%BENCH_BRANCH%%/'"$bench"'/g;
						s/%%FRAPPE_VERSION%%/'"$major"'/g;
					' "$dir/Dockerfile" \
						"$dir"/docker-compose.*.yml \
						"$dir/.env" \
						"$dir/test/docker_test.sh" \
						"$dir/test/Dockerfile"
				fi

				sed -ri -e '
					s|DOCKER_TAG=.*|DOCKER_TAG='"$major"'|g;
					s|DOCKER_REPO=.*|DOCKER_REPO='"$dockerRepo"'|g;
				' "$dir/hooks/run"

				# Create a list of "alias" tags for DockerHub post_push
				if [ "$version" = "$dockerLatest" ]; then
					if [ "$variant" = "$dockerDefaultVariant" ]; then
						export DOCKER_TAGS="$latest-$variant $version-$variant $major-$variant $variant $latest $version $major latest "
					else
						export DOCKER_TAGS="$latest-$variant $version-$variant $major-$variant $variant "
					fi
				elif [ "$version" = "$latest" ]; then
					if [ "$variant" = "$dockerDefaultVariant" ]; then
						export DOCKER_TAGS="$latest-$variant $latest "
					else
						export DOCKER_TAGS="$latest-$variant "
					fi
				else
					if [ "$variant" = "$dockerDefaultVariant" ]; then
						export DOCKER_TAGS="$latest-$variant $version-$variant $major-$variant $latest $version $major "
					else
						export DOCKER_TAGS="$latest-$variant $version-$variant $major-$variant "
					fi
				fi
				echo "${DOCKER_TAGS} " > "$dir/.dockertags"

				# Add README tags
				readmeTags="$readmeTags\n-   ${DOCKER_TAGS} (\`$dir/Dockerfile\`)"

				# Add Travis-CI env var
				travisEnv='\n  - VERSION='"$major"' BENCH='"$bench"' VARIANT='"$variant"' DATABASE=mariadb'"$travisEnv"
				case $major in
					10|11) echo "Postgres not supported for $latest";;
					*) travisEnv='\n  - VERSION='"$major"' BENCH='"$bench"' VARIANT='"$variant"' DATABASE=postgres'"$travisEnv";;
				esac

				if [[ $1 == 'build' ]]; then
					tag="$major-$variant"
					echo "Build Dockerfile for ${tag}"
					docker build -t "${dockerRepo}:${tag}" "$dir"
				fi
			done

		#done

	fi

done

# update README.md
sed '/^<!-- >Docker Tags -->/,/^<!-- <Docker Tags -->/{/^<!-- >Docker Tags -->/!{/^<!-- <Docker Tags -->/!d}}' README.md > README.md.tmp
sed -e "s|<!-- >Docker Tags -->|<!-- >Docker Tags -->\n$readmeTags\n|g" README.md.tmp > README.md
rm README.md.tmp

# update .github workflows
sed -i -e "s|version: \[.*\]|version: [${githubEnv}]|g" .github/workflows/hooks.yml

# update .travis.yml
travis="$(awk -v 'RS=\n\n' '$1 == "env:" && $2 == "#" && $3 == "Environments" { $0 = "env: # Environments'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
