if git fetch origin release 2> /dev/null; then
    files=$(git diff --name-only -z origin/release -- {articles,books}/*.md)
else
    files=$(find {articles,books} -name '*.md' -print0)
fi
files=(${(0)files})
for file in $files; do
    if $(sed -n 6p $file | cut -d \  -f 2); then
        echo "updated=${#files}" >> $GITHUB_ENV
        break
    fi
done
