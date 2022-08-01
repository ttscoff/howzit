#!/usr/bin/env ruby

readme = IO.read('README.md')
blog_project = '/Users/ttscoff/Sites/dev/bt/source/_projects/howzit.md'
blog_changelog = '/Users/ttscoff/Sites/dev/bt/source/_projects/changelogs/howzit.md'

project = readme.match(/<!--BEGIN PROJECT-->(.*?)<!--END PROJECT-->/m)[0]
changelog = readme.match(/<!--BEGIN CHANGELOG-->(.*?)<!--END CHANGELOG-->/m)[1]
blog_project_content = IO.read(blog_project)
blog_project_content.sub!(/<!--BEGIN PROJECT-->(.*?)<!--END PROJECT-->/m, project)
File.open(blog_project, 'w') { |f| f.puts blog_project_content }
File.open(blog_changelog, 'w') { |f| f.puts changelog.strip }
puts "Updated project file and changelog for BrettTerpstra.com"
