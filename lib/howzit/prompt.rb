# frozen_string_literal: true

module Howzit
  module Prompt
  	def yn(prompt, default = true)
    	system 'stty cbreak'
    	yn = color_single_options(default ? %w[Y n] : %w[y N])
    	$stdout.syswrite "\e[1;37m#{prompt} #{yn}\e[1;37m? \e[0m"
    	res = $stdin.sysread 1
    	res.chomp!
    	puts
    	system 'stty cooked'
    	res =~ /y/i
    end
  end
end
