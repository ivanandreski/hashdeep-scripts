for d in */; do
  dir="${d%/}"   # remove trailing slash
  rsync -avh --progress "$dir" /run/media/ivan/THE_VAULT/4KMovies/
done
