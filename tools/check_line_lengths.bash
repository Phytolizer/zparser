MAX_LENGTH=80
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
find ./src -type f | while read -r file; do
    awk -v max_length=$MAX_LENGTH -f "$DIR/offending_lines.awk" "$file"
done
