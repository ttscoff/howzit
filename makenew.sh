#!/usr/bin/env sh

set -e
set -u

find_replace () {
  git ls-files -z | xargs -0 sed -i "$1"
}

check_env () {
  test -d .git || (echo 'This is not a Git repository. Exiting.' && exit 1)
  for cmd in ${1}; do
    command -v ${cmd} >/dev/null 2>&1 || \
      (echo "Could not find '$cmd' which is required to continue." && exit 2)
  done
  echo
  echo 'Ready to bootstrap your new project!'
  echo
}

stage_env () {
  echo
  git rm -f makenew.sh
  echo
  echo 'Staging changes.'
  git add --all
  echo
  echo 'Done!'
  echo
}

makenew () {
  read -p '> Package title: ' mk_title
  read -p '> Gem name (slug): ' mk_slug
  read -p '> Gem description: ' mk_description
  read -p '> Gem summary: ' mk_summary
  read -p '> Version number: ' mk_version
  read -p '> Module name: ' mk_module
  read -p '> Module directory name: ' mk_module_dir
  read -p '> Class name: ' mk_class
  read -p '> Class file name (without .rb extension): ' mk_class_file
  read -p '> Author name: ' mk_author
  read -p '> Author email: ' mk_email
  read -p '> Copyright owner: ' mk_owner
  read -p '> Copyright year: ' mk_year
  read -p '> GitHub user or organization name: ' mk_user
  read -p '> GitHub repository name: ' mk_repo

  sed -i -e '12,110d;200,203d' README.md
  sed -i -e "12i ${mk_description}" README.md

  find_replace "s/VERSION =.*/VERSION = '${mk_version}'.freeze/g"
  find_replace "s/0\.0\.0\.\.\./${mk_version}.../g"
  find_replace "s/Ruby Gem Skeleton/${mk_title}/g"
  find_replace "s/Ruby gem skeleton\./${mk_description}/g"
  find_replace "s/Ruby gem skeleton from makenew\./${mk_summary}/g"
  find_replace "s/2016 Evan Sosenko/${mk_year} ${mk_owner}/g"
  find_replace "s/Evan Sosenko/${mk_author}/g"
  find_replace "s/razorx@evansosenko\.com/${mk_email}/g"
  find_replace "s/makenew\/ruby-gem/${mk_user}\/${mk_repo}/g"
  find_replace "s/makenew-ruby_gem/${mk_slug}/g"
  find_replace "s/Makenew/${mk_module}/g"
  find_replace "s/RubyGem/${mk_class}/g"
  find_replace "s/'makenew\/ruby_gem/'${mk_module_dir}\/${mk_class_file}/g"
  find_replace "s/'makenew/'${mk_module_dir}/g"
  find_replace "s/lib\/makenew/lib\/${mk_module_dir}/g"

  git mv makenew-ruby_gem.gemspec ${mk_slug}.gemspec
  git mv lib/makenew/ruby_gem.rb lib/makenew/${mk_class_file}.rb
  git mv lib/makenew.rb lib/${mk_module_dir}.rb
  git mv lib/makenew lib/${mk_module_dir}

  echo
  echo 'Replacing boilerplate.'
}

check_env 'git read sed xargs'
makenew
stage_env
exit
