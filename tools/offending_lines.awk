{
    if (length($0) > max_length) {
        printf "%s:%s: %.*s", FILENAME, NR, max_length, $0
        system("tput setaf 1")
        printf "%.*s\n", length($0)-max_length, substr($0, max_length+1)
        system("tput sgr0")
    }
}